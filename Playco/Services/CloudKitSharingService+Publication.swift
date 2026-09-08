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
        #if DEMO
        return
        #else
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
        #endif
    }

    /// Rejoue les utilisateurs en attente dans `FileReplicationUtilisateur`.
    /// Appelé depuis CloudKitSyncService quand le réseau revient en ligne.
    /// `context` sert à récupérer les @Model Utilisateur frais depuis SwiftData.
    func rejouerFileAttente(context: ModelContext) async {
        #if DEMO
        return
        #endif
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
        #if DEMO
        return
        #endif
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


    /// Sweep de publication : republie ce que CET ÉCRIVAIN a modifié depuis le
    /// dernier sweep réussi. E′ :
    /// - seuil PAR ÉQUIPE capturé en DÉBUT de sweep, avancé SEULEMENT si zéro
    ///   échec et hors mode match (fenêtres de perte fermées — retry idempotent) ;
    /// - FILIGRANES anti-écho : une entité dont la version locale vient d'un
    ///   import (dateModification == filigrane) n'est JAMAIS republiée — chaque
    ///   coach ne pousse que ses propres modifications, vers SES records ;
    /// - isolation par item : un échec n'avorte pas le reste du sweep.
    /// - Parameter estAdmin: seules les ancres mono-écrivain equipe/etablissement
    ///   sont réservées au head coach (E′ §1).
    /// - Parameter modeMatchActif: D6 — stats/points in-game jamais publiés
    ///   pendant un live (et le seuil n'avance pas : rattrapage à la sortie).
    func publierMisesAJourCoach(codeEquipe: String, context: ModelContext,
                                estAdmin: Bool = true, modeMatchActif: Bool = false) async {
        #if DEMO
        return
        #else
        guard !codeEquipe.isEmpty, ecrivainID?.isEmpty == false else { return }
        estEnCoursDePublication = true
        defer { estEnCoursDePublication = false }

        // E′ : le nouveau seuil est capturé AVANT le travail — une modification
        // faite PENDANT le sweep reste > seuil et part au cycle suivant.
        let seuil = etatSync.etat(codeEquipe).seuilPublication
        let nouveauSeuil = Date()
        var nbEchecs = 0

        /// Publie une entité si (dateModification > seuil) ET (≠ filigrane
        /// d'import). Isole l'échec : le sweep continue, le seuil n'avance pas.
        func publierSiModifie(_ entiteID: UUID, _ dateModification: Date,
                              _ publication: () async throws -> Void) async {
            guard etatSync.doitPublier(codeEquipe, entiteID: entiteID,
                                       dateModification: dateModification, seuil: seuil) else { return }
            do {
                try await publication()
            } catch {
                nbEchecs += 1
                logger.warning("Sweep \(codeEquipe, privacy: .private): échec sur \(entiteID.uuidString, privacy: .private): \(error.localizedDescription)")
            }
        }

        // Ancres mono-écrivain (E′ §1) : head coach seulement.
        if estAdmin {
            let descEq = FetchDescriptor<Equipe>(predicate: #Predicate { $0.codeEquipe == codeEquipe })
            if let equipe = try? context.fetch(descEq).first {
                await publierSiModifie(equipe.id, equipe.dateModification) {
                    try await self.publierEquipe(equipe)
                }
                if let etab = equipe.etablissement {
                    await publierSiModifie(etab.id, etab.dateModification) {
                        try await self.publierEtablissement(etab, codeEquipe: codeEquipe)
                    }
                }
            }
        }

        let descU = FetchDescriptor<Utilisateur>(predicate: #Predicate { $0.codeEcole == codeEquipe })
        for u in (try? context.fetch(descU)) ?? [] {
            await publierSiModifie(u.id, u.dateModification) {
                try await self.publierUtilisateur(u, codeEquipe: codeEquipe)
            }
        }
        let descJ = FetchDescriptor<JoueurEquipe>(predicate: #Predicate { $0.codeEquipe == codeEquipe })
        for j in (try? context.fetch(descJ)) ?? [] {
            await publierSiModifie(j.id, j.dateModification) {
                try await self.publierJoueur(j)
            }
        }
        // E2 : les séances ARCHIVÉES se publient aussi (l'archivage bump
        // dateModification et doit se propager aux autres coachs — D6).
        let descS = FetchDescriptor<Seance>(predicate: #Predicate { $0.codeEquipe == codeEquipe })
        let seances = (try? context.fetch(descS)) ?? []
        for seance in seances {
            await publierSiModifie(seance.id, seance.dateModification) {
                try await self.publierSeance(seance)
            }
        }

        // E2 — contenus de préparation (parité assistant D6).
        for seance in seances {
            for exo in (seance.exercices ?? []) {
                await publierSiModifie(exo.id, exo.dateModification) {
                    try await self.publierExercice(exo, seanceID: seance.id, codeEquipe: codeEquipe)
                }
            }
        }
        let descStrat = FetchDescriptor<StrategieCollective>(predicate: #Predicate { $0.codeEquipe == codeEquipe })
        for strat in (try? context.fetch(descStrat)) ?? [] {
            await publierSiModifie(strat.id, strat.dateModification) {
                try await self.publierStrategie(strat)
            }
        }
        let descScout = FetchDescriptor<ScoutingReport>(predicate: #Predicate { $0.codeEquipe == codeEquipe })
        for rapport in (try? context.fetch(descScout)) ?? [] {
            await publierSiModifie(rapport.id, rapport.dateModification) {
                try await self.publierScouting(rapport)
            }
        }
        // Bibliothèque : les items personnels des coachs de l'équipe
        // (codeCoach = Utilisateur.id). Les prédéfinis ne se publient pas.
        let idsCoachs = Set(
            ((try? context.fetch(descU)) ?? [])
                .filter { $0.role != .etudiant }
                .map { $0.id.uuidString }
        )
        let descBiblio = FetchDescriptor<ExerciceBibliotheque>(predicate: #Predicate { $0.estPredefini == false })
        for exo in ((try? context.fetch(descBiblio)) ?? []) where idsCoachs.contains(exo.codeCoach) {
            await publierSiModifie(exo.id, exo.dateModification) {
                try await self.publierBibliotheque(exo, codeEquipe: codeEquipe)
            }
        }

        // E3 — analyse. Formations toujours ; stats/points JAMAIS pendant un
        // match live (D6 : publiés à la sortie via publierAnalyseMatch — et le
        // seuil n'avance pas tant que le live est actif, filet réel).
        let descForm = FetchDescriptor<FormationPersonnalisee>(predicate: #Predicate { $0.codeEquipe == codeEquipe })
        for formation in (try? context.fetch(descForm)) ?? [] {
            await publierSiModifie(formation.id, formation.dateModification) {
                try await self.publierFormation(formation)
            }
        }
        if !modeMatchActif {
            let descStats = FetchDescriptor<StatsMatch>(predicate: #Predicate { $0.codeEquipe == codeEquipe })
            for stat in (try? context.fetch(descStats)) ?? [] {
                await publierSiModifie(stat.id, stat.dateModification) {
                    try await self.publierStatsMatch(stat)
                }
            }
            // Points : immuables, filigranés à l'import (jamais republiés).
            let descPoints = FetchDescriptor<PointMatch>(predicate: #Predicate { $0.codeEquipe == codeEquipe })
            let filigranes = etatSync.etat(codeEquipe).filigranes
            let pointsNouveaux = ((try? context.fetch(descPoints)) ?? []).filter {
                $0.horodatage > seuil && filigranes[$0.id.uuidString] == nil
            }
            if !pointsNouveaux.isEmpty {
                do {
                    try await publierPointsMatch(pointsNouveaux, seanceID: nil, supprimerFantomes: false)
                } catch {
                    nbEchecs += 1
                    logger.warning("Sweep points \(codeEquipe, privacy: .private): \(error.localizedDescription)")
                }
            }
        }

        // E′ : le seuil n'avance que sur cycle COMPLET — un échec ou un live en
        // cours laissent tout re-candidater au prochain sweep (idempotent).
        if nbEchecs == 0 && !modeMatchActif {
            etatSync.modifier(codeEquipe) { $0.seuilPublication = nouveauSeuil }
        } else if nbEchecs > 0 {
            self.erreur = "Synchronisation partielle — nouvel essai au prochain cycle."
        }
        #endif
    }

    // MARK: - Identité d'écrivain & tombstones (E′)

    enum ErreurEcrivain: Error { case ecrivainAbsent }

    /// Pose le champ `ecrivainID` sur un record sortant. AUCUNE publication sans
    /// identité d'écrivain (E′ §1 — l'import ignore les records anonymes).
    func appliquerIdentiteEcrivain(_ record: CKRecord) throws -> String {
        guard let ecrivain = ecrivainID, !ecrivain.isEmpty else {
            throw ErreurEcrivain.ecrivainAbsent
        }
        record["ecrivainID"] = ecrivain as CKRecordValue
        return ecrivain
    }

    /// E′ §4 — publie un TOMBSTONE de suppression et tente (best-effort) de
    /// supprimer SON propre record de l'entité. Les copies des autres écrivains
    /// sont neutralisées par le tombstone à l'import. Fire-and-forget : un échec
    /// n'interrompt jamais la suppression locale (retenté au prochain appel si
    /// la cascade republie).
    func publierSuppression(typeCible: String, prefixeRecord: String?, entiteID: UUID, codeEquipe: String) async {
        #if DEMO
        return
        #else
        guard let ecrivain = ecrivainID, !ecrivain.isEmpty, !codeEquipe.isEmpty else { return }
        let horodatage = Date()
        // Mémoriser localement d'abord : même hors-ligne, cet appareil n'importera
        // plus les copies périmées de l'entité supprimée.
        etatSync.enregistrerTombstone(codeEquipe, entiteID: entiteID, horodatage: horodatage)
        do {
            let nom = Self.nomRecord("tomb", id: entiteID.uuidString, ecrivain: ecrivain)
            let record = await recordPublicAJour(type: RecordType.suppression,
                                                 recordID: CKRecord.ID(recordName: nom))
            record["codeEquipe"] = codeEquipe as CKRecordValue
            record["typeCible"] = typeCible as CKRecordValue
            record["entiteID"] = entiteID.uuidString as CKRecordValue
            record["horodatage"] = horodatage as CKRecordValue
            record["ecrivainID"] = ecrivain as CKRecordValue
            _ = try await publicDB.save(record)
            if let prefixe = prefixeRecord {
                let mien = CKRecord.ID(recordName: Self.nomRecord(prefixe, id: entiteID.uuidString, ecrivain: ecrivain))
                _ = try? await publicDB.deleteRecord(withID: mien)
            }
        } catch {
            logger.warning("publierSuppression \(typeCible) \(entiteID.uuidString, privacy: .private): \(error.localizedDescription)")
        }
        #endif
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

    /// Applique un dictionnaire de champs publics sur un record, pose l'identité
    /// d'écrivain (E′), puis sauvegarde.
    func sauvegarder(champs: [String: CKRecordValue], sur record: CKRecord) async throws {
        for (cle, valeur) in champs {
            record[cle] = valeur
        }
        _ = try appliquerIdentiteEcrivain(record)
        _ = try await publicDB.save(record)
    }

    // MARK: - Publication détaillée (privé)

    /// Publie l'ANCRE d'équipe `equipe-<code>` (mono-écrivain, racine de la
    /// chaîne de confiance E′ §2). Durcissement posture A (SyncEPrime_Residuel)
    /// : détecte un squat de l'ancre — créateur ≠ moi après save (ACL ouverte)
    /// ou `permissionFailure` (ACL créateur-seul) — et le SIGNALE au coach au
    /// lieu de faire échouer le sweep à chaque cycle (seuil gelé à vie).
    private func publierEquipe(_ equipe: Equipe) async throws {
        let recordID = CKRecord.ID(recordName: "equipe-\(equipe.codeEquipe)")
        let record = await recordPublicAJour(type: RecordType.equipe, recordID: recordID)
        for (cle, valeur) in Self.champsPublicsEquipe(equipe) {
            record[cle] = valeur
        }
        _ = try appliquerIdentiteEcrivain(record)
        do {
            let sauve = try await publicDB.save(record)
            if let createur = sauve.creatorUserRecordID?.recordName,
               createur != ConfianceEquipe.proprietaireLocal {
                signalerAncreUsurpee(codeEquipe: equipe.codeEquipe)
            } else {
                ancreUsurpee = false
            }
        } catch let erreurCK as CKError where erreurCK.code == .permissionFailure {
            signalerAncreUsurpee(codeEquipe: equipe.codeEquipe)
        }
    }

    /// L'ancre `equipe-<code>` appartient à un AUTRE compte iCloud : les
    /// assistants ne pourront jamais faire confiance à ce coach (racine ≠ lui).
    /// Cause typique : équipe créée hors-ligne, code partagé avant la 1re
    /// publication, ancre créée par un tiers entre-temps. Remède : nouvelle
    /// équipe (nouveau code). Signalé, jamais silencieux.
    private func signalerAncreUsurpee(codeEquipe: String) {
        ancreUsurpee = true
        logger.error("Ancre equipe-\(codeEquipe, privacy: .private) détenue par un autre compte iCloud — chaîne de confiance impossible")
        erreur = "Le code d'équipe « \(codeEquipe) » est déjà réclamé dans le cloud par un autre compte. Vos assistants ne pourront pas synchroniser avec vous : créez une nouvelle équipe (nouveau code) et réinvitez-les."
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
        guard let ecrivain = ecrivainID, !ecrivain.isEmpty else { throw ErreurEcrivain.ecrivainAbsent }
        let recordID = CKRecord.ID(recordName: Self.nomRecord("user", id: utilisateur.id.uuidString, ecrivain: ecrivain))
        let record = await recordPublicAJour(type: RecordType.utilisateur, recordID: recordID)
        try await sauvegarder(champs: Self.champsPublicsUtilisateur(utilisateur, codeEquipe: codeEquipe), sur: record)
    }

    private func publierJoueur(_ joueur: JoueurEquipe) async throws {
        guard let ecrivain = ecrivainID, !ecrivain.isEmpty else { throw ErreurEcrivain.ecrivainAbsent }
        let recordID = CKRecord.ID(recordName: Self.nomRecord("joueur", id: joueur.id.uuidString, ecrivain: ecrivain))
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
        // E′ §7 — PII minimale : la Public DB est world-readable. Le MOTIF
        // d'indisponibilité (blessé/malade = donnée de santé, souvent de mineurs)
        // et l'attestation parentale (registre légal nominatif) ne transitent
        // JAMAIS — seul un booléen de disponibilité est partagé (la composition
        // des autres coachs grise le joueur, sans savoir pourquoi).
        champs["estDisponible"] = (joueur.estDisponible ? 1 : 0) as CKRecordValue
        return champs
    }

    /// Publie une séance (pratique ou match) — parité entre coachs.
    func publierSeance(_ seance: Seance) async throws {
        guard let ecrivain = ecrivainID, !ecrivain.isEmpty else { throw ErreurEcrivain.ecrivainAbsent }
        let recordID = CKRecord.ID(recordName: Self.nomRecord("seance", id: seance.id.uuidString, ecrivain: ecrivain))
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
            // E3 — l'assistant doit savoir qu'un match est finalisé (chip Analyse).
            "statsEntrees": (seance.statsEntrees ? 1 : 0) as CKRecordValue,
            "dateModification": seance.dateModification as CKRecordValue
        ]
    }
}
