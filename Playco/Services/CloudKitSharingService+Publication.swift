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

    /// Publie uniquement les records modifiés depuis la dernière sync
    func publierModificationsEquipe(
        equipe: Equipe,
        etablissement: Etablissement?,
        utilisateurs: [Utilisateur],
        joueurs: [JoueurEquipe],
        context: ModelContext
    ) async {
        estEnCoursDePublication = true
        erreur = nil
        let seuil = derniereSyncDate

        do {
            // Équipe modifiée ?
            if equipe.dateModification > seuil {
                try await publierEquipe(equipe)
            }

            // Établissement modifié ?
            if let etab = etablissement, etab.dateModification > seuil {
                try await publierEtablissement(etab, codeEquipe: equipe.codeEquipe)
            }

            // Utilisateurs modifiés
            let usersModifies = utilisateurs.filter { $0.dateModification > seuil }
            for utilisateur in usersModifies {
                try await publierUtilisateur(utilisateur, codeEquipe: equipe.codeEquipe)
            }

            // Joueurs modifiés
            let joueursModifies = joueurs.filter { $0.dateModification > seuil }
            for joueur in joueursModifies {
                try await publierJoueur(joueur)
            }

            derniereSyncDate = Date()
            let totalPub = (equipe.dateModification > seuil ? 1 : 0) + usersModifies.count + joueursModifies.count
            logger.info("Sync incrémentale: \(totalPub) records publiés pour \(equipe.codeEquipe, privacy: .private)")
        } catch {
            logger.error("Erreur sync incrémentale: \(error.localizedDescription)")
            self.erreur = error.localizedDescription
        }

        estEnCoursDePublication = false
    }

    /// Sweep de publication côté coach : republie tout ce qui a changé depuis la
    /// dernière sync (équipe, établissement, utilisateurs, joueurs+stats, séances,
    /// matchs) pour un `codeEquipe`. DRY : un seul point d'appel (foreground coach)
    /// couvre toutes les créations/éditions sans triggers éparpillés.
    /// Respecte `masquerPratiquesAthletes` : les pratiques ne sont pas publiées si activé.
    func publierMisesAJourCoach(codeEquipe: String, context: ModelContext) async {
        guard !codeEquipe.isEmpty else { return }
        estEnCoursDePublication = true
        defer { estEnCoursDePublication = false }
        let seuil = derniereSyncDate

        let masquer = ((try? context.fetch(FetchDescriptor<ProfilCoach>()))?
            .first?.masquerPratiquesAthletes) ?? false

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
            let pratiqueRaw = TypeSeance.pratique.rawValue
            let descS = FetchDescriptor<Seance>(predicate: #Predicate { $0.codeEquipe == codeEquipe })
            for s in (try? context.fetch(descS)) ?? [] where s.dateModification > seuil && !s.estArchivee {
                if masquer && s.typeSeanceRaw == pratiqueRaw { continue }  // pratiques masquées
                try await publierSeance(s)
            }
            // Les matchs sont publiés en tant que Seance (type=.match) ci-dessus.
            // MatchCalendrier n'est plus partagé (déprécié/dormant).
            derniereSyncDate = Date()
        } catch {
            logger.error("publierMisesAJourCoach: \(error.localizedDescription)")
            self.erreur = error.localizedDescription
        }
    }

    // MARK: - Publication détaillée (privé)

    private func publierEquipe(_ equipe: Equipe) async throws {
        let recordID = CKRecord.ID(recordName: "equipe-\(equipe.codeEquipe)")
        let record = CKRecord(recordType: RecordType.equipe, recordID: recordID)

        record["codeEquipe"] = equipe.codeEquipe as CKRecordValue
        record["nom"] = equipe.nom as CKRecordValue
        record["categorieRaw"] = equipe.categorieRaw as CKRecordValue
        record["divisionRaw"] = equipe.divisionRaw as CKRecordValue
        record["saison"] = equipe.saison as CKRecordValue
        record["couleurPrincipalHex"] = equipe.couleurPrincipalHex as CKRecordValue
        record["couleurSecondaireHex"] = equipe.couleurSecondaireHex as CKRecordValue
        record["dateModification"] = equipe.dateModification as CKRecordValue

        _ = try await publicDB.save(record)
    }

    private func publierEtablissement(_ etab: Etablissement, codeEquipe: String) async throws {
        let recordID = CKRecord.ID(recordName: "etab-\(codeEquipe)")
        let record = CKRecord(recordType: RecordType.etablissement, recordID: recordID)

        record["codeEquipe"] = codeEquipe as CKRecordValue
        record["nom"] = etab.nom as CKRecordValue
        record["typeRaw"] = etab.typeRaw as CKRecordValue
        record["ville"] = etab.ville as CKRecordValue
        record["province"] = etab.province as CKRecordValue

        _ = try await publicDB.save(record)
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
        let recordID = CKRecord.ID(recordName: "user-\(utilisateur.id.uuidString)")
        let record = CKRecord(recordType: RecordType.utilisateur, recordID: recordID)
        for (cle, valeur) in Self.champsPublicsUtilisateur(utilisateur, codeEquipe: codeEquipe) {
            record[cle] = valeur
        }
        _ = try await publicDB.save(record)
    }

    private func publierJoueur(_ joueur: JoueurEquipe) async throws {
        let recordID = CKRecord.ID(recordName: "joueur-\(joueur.id.uuidString)")
        let record = CKRecord(recordType: RecordType.joueur, recordID: recordID)

        record["joueurID"] = joueur.id.uuidString as CKRecordValue
        record["nom"] = joueur.nom as CKRecordValue
        record["prenom"] = joueur.prenom as CKRecordValue
        record["numero"] = joueur.numero as CKRecordValue
        record["posteRaw"] = joueur.posteRaw as CKRecordValue
        record["codeEquipe"] = joueur.codeEquipe as CKRecordValue
        record["identifiant"] = joueur.identifiant as CKRecordValue

        if let utilisateurID = joueur.utilisateurID {
            record["utilisateurID"] = utilisateurID.uuidString as CKRecordValue
        }
        // Stats cumulées (lecture seule athlète). Pas de PII.
        record["matchsJoues"] = joueur.matchsJoues as CKRecordValue
        record["setsJoues"] = joueur.setsJoues as CKRecordValue
        record["attaquesReussies"] = joueur.attaquesReussies as CKRecordValue
        record["erreursAttaque"] = joueur.erreursAttaque as CKRecordValue
        record["attaquesTotales"] = joueur.attaquesTotales as CKRecordValue
        record["aces"] = joueur.aces as CKRecordValue
        record["erreursService"] = joueur.erreursService as CKRecordValue
        record["servicesTotaux"] = joueur.servicesTotaux as CKRecordValue
        record["blocsSeuls"] = joueur.blocsSeuls as CKRecordValue
        record["blocsAssistes"] = joueur.blocsAssistes as CKRecordValue
        record["erreursBloc"] = joueur.erreursBloc as CKRecordValue
        record["receptionsReussies"] = joueur.receptionsReussies as CKRecordValue
        record["erreursReception"] = joueur.erreursReception as CKRecordValue
        record["receptionsTotales"] = joueur.receptionsTotales as CKRecordValue
        record["passesDecisives"] = joueur.passesDecisives as CKRecordValue
        record["manchettes"] = joueur.manchettes as CKRecordValue
        record["dateModification"] = joueur.dateModification as CKRecordValue

        _ = try await publicDB.save(record)
    }

    /// Publie une séance (pratique ou match) en lecture seule pour les athlètes.
    func publierSeance(_ seance: Seance) async throws {
        let recordID = CKRecord.ID(recordName: "seance-\(seance.id.uuidString)")
        let record = CKRecord(recordType: RecordType.seance, recordID: recordID)
        record["seanceID"] = seance.id.uuidString as CKRecordValue
        record["codeEquipe"] = seance.codeEquipe as CKRecordValue
        record["nom"] = seance.nom as CKRecordValue
        record["date"] = seance.date as CKRecordValue
        record["typeSeanceRaw"] = seance.typeSeanceRaw as CKRecordValue
        record["lieu"] = seance.lieu as CKRecordValue
        record["adversaire"] = seance.adversaire as CKRecordValue
        record["scoreEquipe"] = seance.scoreEquipe as CKRecordValue
        record["scoreAdversaire"] = seance.scoreAdversaire as CKRecordValue
        record["resultatRaw"] = seance.resultatRaw as CKRecordValue
        record["estArchivee"] = (seance.estArchivee ? 1 : 0) as CKRecordValue
        record["dateModification"] = seance.dateModification as CKRecordValue
        _ = try await publicDB.save(record)
    }
}
