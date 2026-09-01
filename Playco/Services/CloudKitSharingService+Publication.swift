//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  CloudKitSharingService+Publication — Publication des données d'équipe
//  vers la CloudKit Public Database (côté coach).

import Foundation
import CloudKit
import SwiftData
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "CloudKitSharing")

// MARK: - Publication (côté Coach)

extension CloudKitSharingService {

    /// Publie toutes les données d'une équipe vers le CloudKit public
    func publierEquipeComplete(
        equipe: Equipe,
        etablissement: Etablissement?,
        utilisateurs: [Utilisateur],
        joueurs: [JoueurEquipe],
        context: ModelContext
    ) async {
        estEnCoursDePublication = true
        erreur = nil

        do {
            // 1. Publier l'établissement
            if let etab = etablissement {
                try await publierEtablissement(etab, codeEquipe: equipe.codeEquipe)
            }

            // 2. Publier l'équipe
            try await publierEquipe(equipe)

            // 3. Publier les utilisateurs — échec par utilisateur n'interrompt pas la boucle,
            //    l'ID est enfilé pour re-publication automatique.
            var echecsUtilisateurs: [UUID] = []
            for utilisateur in utilisateurs {
                do {
                    try await publierUtilisateur(utilisateur, codeEquipe: equipe.codeEquipe)
                    await FileReplicationUtilisateur.shared.marquerPublie(utilisateur.id)
                } catch {
                    echecsUtilisateurs.append(utilisateur.id)
                    await FileReplicationUtilisateur.shared.enregistrer(utilisateur.id)
                    logger.warning("Publication échouée pour utilisateur \(utilisateur.id.uuidString, privacy: .private), enfilé : \(error.localizedDescription)")
                }
            }

            // 4. Publier les joueurs
            for joueur in joueurs {
                try await publierJoueur(joueur)
            }

            if echecsUtilisateurs.isEmpty {
                logger.info("Équipe \(equipe.codeEquipe, privacy: .private) publiée avec succès (\(utilisateurs.count) utilisateurs, \(joueurs.count) joueurs)")
            } else {
                logger.warning("Équipe \(equipe.codeEquipe, privacy: .private) publiée partiellement : \(echecsUtilisateurs.count)/\(utilisateurs.count) utilisateurs en attente de retry")
            }
        } catch {
            logger.error("Erreur publication équipe: \(error.localizedDescription)")
            self.erreur = error.localizedDescription
        }

        estEnCoursDePublication = false
    }

    /// Rejoue les utilisateurs en attente dans `FileReplicationUtilisateur`.
    /// Appelé depuis CloudKitSyncService quand le réseau revient en ligne.
    /// `context` sert à récupérer les @Model Utilisateur frais depuis SwiftData.
    func rejouerFileAttente(context: ModelContext) async {
        let ids = await FileReplicationUtilisateur.shared.listerPrets()
        guard !ids.isEmpty else { return }

        logger.info("Rejoue \(ids.count) utilisateur(s) en attente de publication")

        for id in ids {
            let descripteur = FetchDescriptor<Utilisateur>(
                predicate: #Predicate { $0.id == id }
            )
            guard let utilisateur = try? context.fetch(descripteur).first else {
                // Utilisateur supprimé localement entretemps → retirer de la file
                await FileReplicationUtilisateur.shared.marquerPublie(id)
                continue
            }

            do {
                try await publierUtilisateur(utilisateur, codeEquipe: utilisateur.codeEquipe)
                await FileReplicationUtilisateur.shared.marquerPublie(id)
            } catch {
                await FileReplicationUtilisateur.shared.planifierRetry(id)
                logger.warning("Retry publication utilisateur \(id.uuidString, privacy: .private) échoué : \(error.localizedDescription)")
            }
        }
    }

    /// Publie un seul utilisateur (quand le coach ajoute un athlète après la config
    /// initiale, ou régénère un code d'invitation). En cas d'échec, l'ID est enfilé
    /// dans `FileReplicationUtilisateur` pour re-publication automatique au retour
    /// réseau — sinon le membre resterait introuvable à la jointure (échec silencieux).
    func publierNouvelUtilisateur(_ utilisateur: Utilisateur, joueur: JoueurEquipe?, codeEquipe: String) async {
        do {
            try await publierUtilisateur(utilisateur, codeEquipe: codeEquipe)
            await FileReplicationUtilisateur.shared.marquerPublie(utilisateur.id)
            if let joueur {
                try await publierJoueur(joueur)
            }
            logger.info("Utilisateur \(utilisateur.identifiant, privacy: .private) publié")
        } catch {
            await FileReplicationUtilisateur.shared.enregistrer(utilisateur.id)
            logger.warning("Publication utilisateur \(utilisateur.id.uuidString, privacy: .private) échouée, enfilé pour retry : \(error.localizedDescription)")
        }
    }


    /// Sweep de publication côté coach : republie tout ce qui a changé depuis la
    /// dernière sync (équipe, établissement, utilisateurs, joueurs+stats, séances,
    /// matchs) pour un `codeEquipe`. DRY : un seul point d'appel (foreground coach)
    /// couvre toutes les créations/éditions sans triggers éparpillés.
    func publierMisesAJourCoach(codeEquipe: String, context: ModelContext) async {
        guard !codeEquipe.isEmpty else { return }
        estEnCoursDePublication = true
        defer { estEnCoursDePublication = false }
        let seuil = derniereSyncDate

        do {
            let descEq = FetchDescriptor<Equipe>(predicate: #Predicate { $0.codeEquipe == codeEquipe })
            if let equipe = try? context.fetch(descEq).first {
                if equipe.dateModification > seuil { try await publierEquipe(equipe) }
                if let etab = equipe.etablissement, etab.dateModification > seuil {
                    try await publierEtablissement(etab, codeEquipe: codeEquipe)
                }
            }
            let descU = FetchDescriptor<Utilisateur>(predicate: #Predicate { $0.codeEcole == codeEquipe })
            for u in (try? context.fetch(descU)) ?? [] where u.dateModification > seuil {
                try await publierUtilisateur(u, codeEquipe: codeEquipe)
            }
            let descJ = FetchDescriptor<JoueurEquipe>(predicate: #Predicate { $0.codeEquipe == codeEquipe })
            for j in (try? context.fetch(descJ)) ?? [] where j.dateModification > seuil {
                try await publierJoueur(j)
            }
            // E2 : les séances ARCHIVÉES se publient aussi (l'archivage bump
            // dateModification et doit se propager aux autres coachs — D6).
            let descS = FetchDescriptor<Seance>(predicate: #Predicate { $0.codeEquipe == codeEquipe })
            let seances = (try? context.fetch(descS)) ?? []
            for s in seances where s.dateModification > seuil {
                try await publierSeance(s)
            }
            // Les matchs sont publiés en tant que Seance (type=.match) ci-dessus.
            // MatchCalendrier n'est plus partagé (déprécié/dormant).

            // E2 — contenus de préparation (parité assistant D6).
            for s in seances {
                for exo in (s.exercices ?? []) where exo.dateModification > seuil {
                    try await publierExercice(exo, seanceID: s.id, codeEquipe: codeEquipe)
                }
            }
            let descStrat = FetchDescriptor<StrategieCollective>(predicate: #Predicate { $0.codeEquipe == codeEquipe })
            for strat in (try? context.fetch(descStrat)) ?? [] where strat.dateModification > seuil {
                try await publierStrategie(strat)
            }
            let descScout = FetchDescriptor<ScoutingReport>(predicate: #Predicate { $0.codeEquipe == codeEquipe })
            for rapport in (try? context.fetch(descScout)) ?? [] where rapport.dateModification > seuil {
                try await publierScouting(rapport)
            }
            // Bibliothèque : les items personnels des coachs de l'équipe
            // (codeCoach = Utilisateur.id). Les prédéfinis ne se publient pas.
            let idsCoachs = Set(
                ((try? context.fetch(descU)) ?? [])
                    .filter { $0.role != .etudiant }
                    .map { $0.id.uuidString }
            )
            let descBiblio = FetchDescriptor<ExerciceBibliotheque>(predicate: #Predicate { $0.estPredefini == false })
            for exo in (try? context.fetch(descBiblio)) ?? []
            where exo.dateModification > seuil && idsCoachs.contains(exo.codeCoach) {
                try await publierBibliotheque(exo, codeEquipe: codeEquipe)
            }
            derniereSyncDate = Date()
        } catch {
            logger.error("publierMisesAJourCoach: \(error.localizedDescription)")
            self.erreur = error.localizedDescription
        }
    }

    // MARK: - Fetch-puis-modifier (E1 — parité assistant)

    /// Recharge le record existant de la Public DB (ou en crée un neuf s'il
    /// n'existe pas encore). Revue 2.3 généralisée par E1 : un save de CKRecord
    /// NEUF sur un record déjà publié échoue en `serverRecordChanged` — les
    /// mises à jour (stats, scores, disponibilité…) n'atteignaient jamais la
    /// Public DB après la première publication.
    func recordPublicAJour(type: String, recordID: CKRecord.ID) async -> CKRecord {
        (try? await publicDB.record(for: recordID))
            ?? CKRecord(recordType: type, recordID: recordID)
    }

    /// Applique un dictionnaire de champs publics sur un record puis le sauvegarde.
    private func sauvegarder(champs: [String: CKRecordValue], sur record: CKRecord) async throws {
        for (cle, valeur) in champs {
            record[cle] = valeur
        }
        _ = try await publicDB.save(record)
    }

    // MARK: - Publication détaillée (privé)

    private func publierEquipe(_ equipe: Equipe) async throws {
        let recordID = CKRecord.ID(recordName: "equipe-\(equipe.codeEquipe)")
        let record = await recordPublicAJour(type: RecordType.equipe, recordID: recordID)
        try await sauvegarder(champs: Self.champsPublicsEquipe(equipe), sur: record)
    }

    /// Champs PUBLICS d'une équipe. Fonction pure testable (pattern
    /// `champsPublicsUtilisateur`) — aucun secret, pas de PII sensible.
    static func champsPublicsEquipe(_ equipe: Equipe) -> [String: CKRecordValue] {
        [
            "codeEquipe": equipe.codeEquipe as CKRecordValue,
            "nom": equipe.nom as CKRecordValue,
            "categorieRaw": equipe.categorieRaw as CKRecordValue,
            "divisionRaw": equipe.divisionRaw as CKRecordValue,
            "saison": equipe.saison as CKRecordValue,
            "couleurPrincipalHex": equipe.couleurPrincipalHex as CKRecordValue,
            "couleurSecondaireHex": equipe.couleurSecondaireHex as CKRecordValue,
            "dateModification": equipe.dateModification as CKRecordValue
        ]
    }

    private func publierEtablissement(_ etab: Etablissement, codeEquipe: String) async throws {
        let recordID = CKRecord.ID(recordName: "etab-\(codeEquipe)")
        let record = await recordPublicAJour(type: RecordType.etablissement, recordID: recordID)
        try await sauvegarder(champs: Self.champsPublicsEtablissement(etab, codeEquipe: codeEquipe), sur: record)
    }

    /// Champs PUBLICS d'un établissement. Fonction pure testable.
    static func champsPublicsEtablissement(_ etab: Etablissement, codeEquipe: String) -> [String: CKRecordValue] {
        [
            "codeEquipe": codeEquipe as CKRecordValue,
            "nom": etab.nom as CKRecordValue,
            "typeRaw": etab.typeRaw as CKRecordValue,
            "ville": etab.ville as CKRecordValue,
            "province": etab.province as CKRecordValue
        ]
    }

    /// Construit le dictionnaire de champs PUBLICS d'un utilisateur (sans aucun
    /// secret). Fonction pure exposée pour le garde-fou de régression de la faille
    /// (test : ne contient jamais motDePasseHash/sel/iterations).
    /// - Parameter codeEquipe: code de l'équipe propriétaire (fallback `utilisateur.codeEquipe`).
    static func champsPublicsUtilisateur(_ utilisateur: Utilisateur, codeEquipe: String) -> [String: CKRecordValue] {
        let code = codeEquipe.isEmpty ? utilisateur.codeEquipe : codeEquipe
        var champs: [String: CKRecordValue] = [
            "codeEquipe": code as CKRecordValue,
            "utilisateurID": utilisateur.id.uuidString as CKRecordValue,
            "identifiant": utilisateur.identifiant as CKRecordValue,
            "prenom": utilisateur.prenom as CKRecordValue,
            "nom": utilisateur.nom as CKRecordValue,
            "roleRaw": utilisateur.roleRaw as CKRecordValue,
            "codeEcole": utilisateur.codeEcole as CKRecordValue,
            "estActif": (utilisateur.estActif ? 1 : 0) as CKRecordValue,
            // Mapping SIWA non secret : appleUserID (vide = roster en attente) + codeInvitation.
            "appleUserID": utilisateur.appleUserID as CKRecordValue,
            "codeInvitation": utilisateur.codeInvitation as CKRecordValue,
            "dateModification": utilisateur.dateModification as CKRecordValue
        ]
        if let joueurID = utilisateur.joueurEquipeID {
            champs["joueurEquipeID"] = joueurID.uuidString as CKRecordValue
        }
        if utilisateur.numero > 0 {
            champs["numero"] = utilisateur.numero as CKRecordValue
        }
        if !utilisateur.posteRaw.isEmpty {
            champs["posteRaw"] = utilisateur.posteRaw as CKRecordValue
        }
        return champs
    }

    /// Publie un utilisateur de mapping d'équipe (sans aucun secret).
    /// SÉCURITÉ : ne JAMAIS publier motDePasseHash/sel/iterations dans la base
    /// CloudKit PUBLIQUE — auth déléguée à Sign in with Apple (cf. `champsPublicsUtilisateur`).
    private func publierUtilisateur(_ utilisateur: Utilisateur, codeEquipe: String) async throws {
        // Revue 2.3 (révocation fail-open) : fetch-puis-modifier — sans quoi la
        // régénération du code d'invitation n'atteignait jamais la Public DB
        // (l'ancien QR photographié restait valide, le nouveau échouait).
        let recordID = CKRecord.ID(recordName: "user-\(utilisateur.id.uuidString)")
        let record = await recordPublicAJour(type: RecordType.utilisateur, recordID: recordID)
        try await sauvegarder(champs: Self.champsPublicsUtilisateur(utilisateur, codeEquipe: codeEquipe), sur: record)
    }

    private func publierJoueur(_ joueur: JoueurEquipe) async throws {
        let recordID = CKRecord.ID(recordName: "joueur-\(joueur.id.uuidString)")
        let record = await recordPublicAJour(type: RecordType.joueur, recordID: recordID)
        try await sauvegarder(champs: Self.champsPublicsJoueur(joueur), sur: record)
    }

    /// Champs PUBLICS d'un joueur (roster + stats cumulées + disponibilité).
    /// Fonction pure testable. SÉCURITÉ : ne JAMAIS mapper les champs legacy
    /// `motDePasseHash`/`sel` du @Model (gelés au schéma, jamais publiés).
    static func champsPublicsJoueur(_ joueur: JoueurEquipe) -> [String: CKRecordValue] {
        var champs: [String: CKRecordValue] = [
            "joueurID": joueur.id.uuidString as CKRecordValue,
            "nom": joueur.nom as CKRecordValue,
            "prenom": joueur.prenom as CKRecordValue,
            "numero": joueur.numero as CKRecordValue,
            "posteRaw": joueur.posteRaw as CKRecordValue,
            "codeEquipe": joueur.codeEquipe as CKRecordValue,
            "identifiant": joueur.identifiant as CKRecordValue,
            "dateModification": joueur.dateModification as CKRecordValue
        ]
        if let utilisateurID = joueur.utilisateurID {
            champs["utilisateurID"] = utilisateurID.uuidString as CKRecordValue
        }
        // Stats cumulées. Pas de PII.
        champs["matchsJoues"] = joueur.matchsJoues as CKRecordValue
        champs["setsJoues"] = joueur.setsJoues as CKRecordValue
        champs["attaquesReussies"] = joueur.attaquesReussies as CKRecordValue
        champs["erreursAttaque"] = joueur.erreursAttaque as CKRecordValue
        champs["attaquesTotales"] = joueur.attaquesTotales as CKRecordValue
        champs["aces"] = joueur.aces as CKRecordValue
        champs["erreursService"] = joueur.erreursService as CKRecordValue
        champs["servicesTotaux"] = joueur.servicesTotaux as CKRecordValue
        champs["blocsSeuls"] = joueur.blocsSeuls as CKRecordValue
        champs["blocsAssistes"] = joueur.blocsAssistes as CKRecordValue
        champs["erreursBloc"] = joueur.erreursBloc as CKRecordValue
        champs["receptionsReussies"] = joueur.receptionsReussies as CKRecordValue
        champs["erreursReception"] = joueur.erreursReception as CKRecordValue
        champs["receptionsTotales"] = joueur.receptionsTotales as CKRecordValue
        champs["passesDecisives"] = joueur.passesDecisives as CKRecordValue
        champs["manchettes"] = joueur.manchettes as CKRecordValue
        // Disponibilité + attestation de consentement (E1 — parité assistant D6).
        champs["statutDisponibiliteRaw"] = joueur.statutDisponibiliteRaw as CKRecordValue
        champs["consentementParentalAtteste"] = (joueur.consentementParentalAtteste ? 1 : 0) as CKRecordValue
        champs["attesteParNom"] = joueur.attesteParNom as CKRecordValue
        if let dateAttestation = joueur.dateAttestationConsentement {
            champs["dateAttestationConsentement"] = dateAttestation as CKRecordValue
        }
        return champs
    }

    /// Publie une séance (pratique ou match) — parité entre coachs.
    func publierSeance(_ seance: Seance) async throws {
        let recordID = CKRecord.ID(recordName: "seance-\(seance.id.uuidString)")
        let record = await recordPublicAJour(type: RecordType.seance, recordID: recordID)
        try await sauvegarder(champs: Self.champsPublicsSeance(seance), sur: record)
    }

    /// Champs PUBLICS d'une séance (métadonnées). Fonction pure testable.
    static func champsPublicsSeance(_ seance: Seance) -> [String: CKRecordValue] {
        [
            "seanceID": seance.id.uuidString as CKRecordValue,
            "codeEquipe": seance.codeEquipe as CKRecordValue,
            "nom": seance.nom as CKRecordValue,
            "date": seance.date as CKRecordValue,
            "typeSeanceRaw": seance.typeSeanceRaw as CKRecordValue,
            "lieu": seance.lieu as CKRecordValue,
            "adversaire": seance.adversaire as CKRecordValue,
            "scoreEquipe": seance.scoreEquipe as CKRecordValue,
            "scoreAdversaire": seance.scoreAdversaire as CKRecordValue,
            "resultatRaw": seance.resultatRaw as CKRecordValue,
            "estArchivee": (seance.estArchivee ? 1 : 0) as CKRecordValue,
            "dateModification": seance.dateModification as CKRecordValue
        ]
    }
}
