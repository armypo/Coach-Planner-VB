//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  CloudKitSharingService — Sync équipe via CloudKit Public Database
//  Permet au coach de publier les données d'équipe et aux athlètes de les récupérer
//  via le code d'équipe, même sur des comptes iCloud différents.

import Foundation
import CloudKit
import SwiftData
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "CloudKitSharing")

/// Service de partage inter-utilisateurs via CloudKit Public Database
@MainActor
@Observable
final class CloudKitSharingService {

    // MARK: - État

    var estEnCoursDePublication = false
    var estEnCoursDeRecuperation = false
    var erreur: String?

    /// Date de la dernière sync réussie (persistée en UserDefaults)
    private var derniereSyncDate: Date {
        get { UserDefaults.standard.object(forKey: "derniereSyncPublic") as? Date ?? .distantPast }
        set { UserDefaults.standard.set(newValue, forKey: "derniereSyncPublic") }
    }

    // MARK: - CloudKit

    private let container = CKContainer(identifier: "iCloud.Origo.Playco")
    private var publicDB: CKDatabase { container.publicCloudDatabase }

    // MARK: - Types d'enregistrement CloudKit

    private enum RecordType {
        static let equipe = "EquipePartagee"
        static let utilisateur = "UtilisateurPartage"
        static let joueur = "JoueurPartage"
        static let etablissement = "EtablissementPartage"
        static let seance = "SeancePartagee"
    }

    // MARK: - Publication (côté Coach)

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

    // MARK: - Récupération (côté Athlète)

    /// Vérifie si un code d'équipe existe dans le CloudKit public
    func equipeExiste(codeEquipe: String) async -> Bool {
        let predicate = NSPredicate(format: "codeEquipe == %@", codeEquipe)
        let query = CKQuery(recordType: RecordType.equipe, predicate: predicate)

        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)
            return !results.isEmpty
        } catch {
            logger.error("Erreur vérification équipe: \(error.localizedDescription)")
            return false
        }
    }

    /// Récupère et importe toutes les données d'une équipe dans le SwiftData local
    func recupererEtImporterEquipe(codeEquipe: String, context: ModelContext) async throws {
        estEnCoursDeRecuperation = true
        erreur = nil

        defer { estEnCoursDeRecuperation = false }

        // 1. Récupérer l'équipe
        let equipeRecords = try await fetchRecords(type: RecordType.equipe, codeEquipe: codeEquipe)
        guard let equipeRecord = equipeRecords.first else {
            throw SharingError.equipeNonTrouvee
        }

        // Vérifier si l'équipe existe déjà en local
        let codeRecherche = codeEquipe
        let descripteurEquipe = FetchDescriptor<Equipe>(
            predicate: #Predicate { $0.codeEquipe == codeRecherche }
        )
        let equipesLocales = (try? context.fetch(descripteurEquipe)) ?? []

        if equipesLocales.isEmpty {
            // 2. Récupérer l'établissement
            let etabRecords = try await fetchRecords(type: RecordType.etablissement, codeEquipe: codeEquipe)

            // 3. Créer l'établissement local
            var etablissementLocal: Etablissement?
            if let etabRecord = etabRecords.first {
                etablissementLocal = importerEtablissement(from: etabRecord, context: context)
            }

            // 4. Créer l'équipe locale
            importerEquipe(from: equipeRecord, etablissement: etablissementLocal, context: context)

            // 5. Créer un ProfilCoach minimal (pour que configurationCompletee = true)
            let profilDescriptor = FetchDescriptor<ProfilCoach>(
                predicate: #Predicate { $0.configurationCompletee == true }
            )
            let profilsExistants = (try? context.fetch(profilDescriptor)) ?? []
            if profilsExistants.isEmpty {
                let profil = ProfilCoach()
                profil.configurationCompletee = true
                context.insert(profil)
            }
        }

        // 6. Importer les Utilisateur de mapping d'équipe (SANS secret — cf.
        // `champsPublicsUtilisateur`). Requis pour la jointure SIWA : `reclamerMembreLocal`
        // retrouve la ligne de roster par code d'invitation puis y rattache l'appleUserID.
        let utilisateurRecords = try await fetchRecords(type: RecordType.utilisateur, codeEquipe: codeEquipe)
        for record in utilisateurRecords {
            importerUtilisateur(from: record, context: context)
        }

        // 7. Récupérer et importer les joueurs
        let joueurRecords = try await fetchRecords(type: RecordType.joueur, codeEquipe: codeEquipe)
        for record in joueurRecords {
            importerJoueur(from: record, context: context)
        }

        // 7b. Importer les séances (incl. matchs type=.match — lecture seule athlète).
        let seanceRecords = try await fetchRecords(type: RecordType.seance, codeEquipe: codeEquipe)
        for record in seanceRecords { importerSeance(from: record, context: context) }

        // 8. Tier d'équipe INFORMATIONNEL depuis AbonnementPartage (Public DB).
        // SÉCURITÉ : cette valeur (non signée) ne sert QU'À l'affichage — elle
        // n'accorde aucun accès et ne bloque aucune connexion (cf. appliquerGateTier
        // role-aware, et paywallDoitBloquer côté coach uniquement).
        if let snap = await CloudKitPublicSyncAbonnement.shared.lireStatut(codeEquipe: codeEquipe),
           let tier = Tier(rawValue: snap.tierRaw) {
            let codeRech = codeEquipe
            let descEq = FetchDescriptor<Equipe>(predicate: #Predicate { $0.codeEquipe == codeRech })
            if let eqLocale = try? context.fetch(descEq).first, eqLocale.tierAbonnement != tier {
                eqLocale.tierAbonnement = tier
                logger.info("Tier équipe (informationnel) pour \(codeEquipe, privacy: .private): \(tier.rawValue, privacy: .public)")
            }
        }

        do {
            try context.save()
        } catch {
            logger.error("importerEquipeDepuisPublic: échec sauvegarde SwiftData: \(error.localizedDescription)")
            throw SharingError.sauvegardeEchouee
        }

        logger.info("Équipe \(codeEquipe, privacy: .private) importée: \(joueurRecords.count) joueurs (comptes non répliqués)")
    }

    /// Rôles autorisés à rejoindre via le flux public (anti-escalade).
    /// Seuls `.etudiant` / `.assistantCoach` ; `.coach` / `.admin` rejetés
    /// (le coach est le créateur de l'équipe, jamais un joignant).
    static func roleJonctionAutorise(_ roleRaw: String) -> RoleUtilisateur? {
        guard let role = RoleUtilisateur(rawValue: roleRaw) else { return nil }
        switch role {
        case .etudiant, .assistantCoach: return role
        case .coach, .admin: return nil
        }
    }

    // MARK: - Sync incrémentale

    /// Synchronise les nouvelles données depuis le public DB (appel périodique)
    func syncDepuisPublic(codeEquipe: String, context: ModelContext) async {
        do {
            // SÉCURITÉ : pas d'import de comptes Utilisateur (credentials). On ne
            // rafraîchit que les données non sensibles (roster, séances, calendrier).
            let joueurRecords = try await fetchRecords(type: RecordType.joueur, codeEquipe: codeEquipe)
            for record in joueurRecords {
                importerJoueur(from: record, context: context)
            }

            let seanceRecords = try await fetchRecords(type: RecordType.seance, codeEquipe: codeEquipe)
            for record in seanceRecords { importerSeance(from: record, context: context) }

            do {
                try context.save()
                logger.info("Sync incrémentale terminée pour \(codeEquipe, privacy: .private)")
            } catch {
                logger.error("syncDepuisPublic: échec sauvegarde SwiftData: \(error.localizedDescription)")
                // Ne pas relancer — la sync échouée sera retentée au prochain cycle
            }
        } catch {
            logger.error("Erreur sync incrémentale: \(error.localizedDescription)")
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
        try await publicDB.save(record)
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

    // MARK: - Import vers SwiftData

    func importerEquipe(from record: CKRecord, etablissement: Etablissement?, context: ModelContext) {
        let equipe = Equipe(nom: record["nom"] as? String ?? "")
        equipe.codeEquipe = record["codeEquipe"] as? String ?? ""
        equipe.categorieRaw = record["categorieRaw"] as? String ?? ""
        equipe.divisionRaw = record["divisionRaw"] as? String ?? ""
        equipe.saison = record["saison"] as? String ?? ""
        equipe.couleurPrincipalHex = record["couleurPrincipalHex"] as? String ?? "#E8734A"
        equipe.couleurSecondaireHex = record["couleurSecondaireHex"] as? String ?? "#4A8AF4"
        equipe.etablissement = etablissement
        context.insert(equipe)
    }

    func importerEtablissement(from record: CKRecord, context: ModelContext) -> Etablissement {
        let etab = Etablissement(
            nom: record["nom"] as? String ?? "",
            type: TypeEtablissement(rawValue: record["typeRaw"] as? String ?? "") ?? .universite,
            ville: record["ville"] as? String ?? "",
            province: record["province"] as? String ?? ""
        )
        context.insert(etab)
        return etab
    }

    func importerUtilisateur(from record: CKRecord, context: ModelContext) {
        guard let idString = record["utilisateurID"] as? String,
              let uuid = UUID(uuidString: idString) else { return }

        // Vérifier si cet utilisateur existe déjà
        let descripteur = FetchDescriptor<Utilisateur>(
            predicate: #Predicate { $0.id == uuid }
        )
        if let existant = try? context.fetch(descripteur).first {
            // Comparer dateModification — ne mettre à jour que si le remote est plus récent
            let remoteDateMod = record["dateModification"] as? Date ?? .distantPast
            guard remoteDateMod > existant.dateModification else { return }

            // Mettre à jour les champs mutables
            existant.estActif = (record["estActif"] as? Int ?? 1) == 1
            existant.dateModification = remoteDateMod
            // SÉCURITÉ : plus aucun secret (hash/sel/iterations) en base publique.
            // L'auth passe par Sign in with Apple ; ces champs ne transitent plus.
            // Mapping SIWA : ne JAMAIS écraser ces champs sur une ligne DÉJÀ réclamée
            // (appleUserID non vide) — sinon un record public pourrait corrompre
            // l'identité/le code d'un membre déjà rattaché.
            if existant.appleUserID.isEmpty {
                if let appleID = record["appleUserID"] as? String {
                    existant.appleUserID = appleID
                }
                if let invite = record["codeInvitation"] as? String, !invite.isEmpty {
                    existant.codeInvitation = invite
                }
            }
            if let code = record["codeEquipe"] as? String, !code.isEmpty {
                existant.codeEquipe = code
            }
            if let prenom = record["prenom"] as? String {
                existant.prenom = prenom
            }
            if let nom = record["nom"] as? String {
                existant.nom = nom
            }
            if let numero = record["numero"] as? Int {
                existant.numero = numero
            }
            if let posteRaw = record["posteRaw"] as? String {
                existant.posteRaw = posteRaw
            }
            return
        }

        // Créer le nouvel utilisateur de mapping d'équipe. SÉCURITÉ : aucun secret
        // n'est importé depuis la base publique — l'authentification est déléguée à
        // Sign in with Apple (motDePasseHash reste vide ; le rattachement se fait
        // via appleUserID lors du flux « Rejoindre une équipe »).
        let utilisateur = Utilisateur(
            identifiant: record["identifiant"] as? String ?? "",
            motDePasseHash: "",
            prenom: record["prenom"] as? String ?? "",
            nom: record["nom"] as? String ?? "",
            role: RoleUtilisateur(rawValue: record["roleRaw"] as? String ?? "Étudiant") ?? .etudiant,
            codeEcole: record["codeEcole"] as? String ?? ""
        )
        // Forcer le même UUID que la source
        utilisateur.id = uuid
        utilisateur.estActif = (record["estActif"] as? Int ?? 1) == 1
        // Mapping SIWA / jointure d'équipe (jeton non secret).
        utilisateur.appleUserID = record["appleUserID"] as? String ?? ""
        utilisateur.codeEquipe = record["codeEquipe"] as? String ?? ""
        utilisateur.codeInvitation = record["codeInvitation"] as? String ?? ""

        if let joueurIDStr = record["joueurEquipeID"] as? String {
            utilisateur.joueurEquipeID = UUID(uuidString: joueurIDStr)
        }
        if let numero = record["numero"] as? Int {
            utilisateur.numero = numero
        }
        if let posteRaw = record["posteRaw"] as? String {
            utilisateur.posteRaw = posteRaw
        }

        context.insert(utilisateur)
    }

    func importerJoueur(from record: CKRecord, context: ModelContext) {
        guard let idString = record["joueurID"] as? String,
              let uuid = UUID(uuidString: idString) else { return }

        // Vérifier si ce joueur existe déjà
        let descripteur = FetchDescriptor<JoueurEquipe>(
            predicate: #Predicate { $0.id == uuid }
        )
        if let existant = try? context.fetch(descripteur).first {
            // Comparer dateModification — ne mettre à jour que si le remote est plus récent
            let remoteDateMod = record["dateModification"] as? Date ?? .distantPast
            guard remoteDateMod > existant.dateModification else { return }
            existant.nom = record["nom"] as? String ?? existant.nom
            existant.prenom = record["prenom"] as? String ?? existant.prenom
            existant.numero = record["numero"] as? Int ?? existant.numero
            existant.posteRaw = record["posteRaw"] as? String ?? existant.posteRaw
            appliquerStats(record, sur: existant)
            existant.dateModification = remoteDateMod
            return
        }

        let joueur = JoueurEquipe(
            nom: record["nom"] as? String ?? "",
            prenom: record["prenom"] as? String ?? "",
            numero: record["numero"] as? Int ?? 0,
            poste: PosteJoueur(rawValue: record["posteRaw"] as? String ?? "") ?? .recepteur
        )
        joueur.id = uuid
        joueur.codeEquipe = record["codeEquipe"] as? String ?? ""
        joueur.identifiant = record["identifiant"] as? String ?? ""

        if let utilisateurIDStr = record["utilisateurID"] as? String {
            joueur.utilisateurID = UUID(uuidString: utilisateurIDStr)
        }
        appliquerStats(record, sur: joueur)

        context.insert(joueur)
    }

    // MARK: - Rejoindre une équipe (Sign in with Apple, cross-Apple-ID)

    /// Rejoint une équipe via son code + un code d'invitation, et RATTACHE
    /// l'identité Sign in with Apple à la ligne de roster correspondante.
    /// - Returns: l'`Utilisateur` local réclamé (à connecter via `AuthService.connexionApple`).
    /// - Throws: `SharingError` si équipe/invitation introuvable ou déjà réclamée.
    func rejoindreEquipe(codeEquipe: String, codeInvitation: String, appleUserID: String, context: ModelContext) async throws -> Utilisateur {
        let code = codeEquipe.trimmingCharacters(in: .whitespaces).uppercased()
        let invite = codeInvitation.trimmingCharacters(in: .whitespaces).uppercased()
        let appleID = appleUserID.trimmingCharacters(in: .whitespaces)

        guard !code.isEmpty, !invite.isEmpty, !appleID.isEmpty else {
            throw SharingError.equipeNonTrouvee
        }

        // 1-2. Vérifier l'existence puis importer le roster localement.
        guard await equipeExiste(codeEquipe: code) else { throw SharingError.equipeNonTrouvee }
        try await recupererEtImporterEquipe(codeEquipe: code, context: context)

        // 3-4. Réclamer la ligne de roster non liée (logique locale testable).
        guard let membre = reclamerMembreLocal(codeEquipe: code, codeInvitation: invite, appleUserID: appleID, context: context) else {
            throw SharingError.invitationInvalide
        }
        do {
            try context.save()
        } catch {
            logger.error("rejoindreEquipe: échec sauvegarde: \(error.localizedDescription)")
            throw SharingError.sauvegardeEchouee
        }
        await publierNouvelUtilisateur(membre, joueur: nil, codeEquipe: code)
        logger.info("Membre rattaché à l'équipe \(code, privacy: .private) via invitation")
        return membre
    }

    // MARK: - Réclamation locale (testable, sans CloudKit)

    /// Trouve la ligne de roster non liée correspondant au code d'invitation et
    /// lui rattache `appleUserID`. Logique purement locale (SwiftData) extraite
    /// de `rejoindreEquipe` pour être testable sans CloudKit.
    /// - Returns: l'`Utilisateur` réclamé (appleUserID renseigné, NON sauvegardé),
    ///   ou `nil` si aucune ligne libre ne correspond.
    func reclamerMembreLocal(codeEquipe: String, codeInvitation: String, appleUserID: String, context: ModelContext) -> Utilisateur? {
        let code = codeEquipe.trimmingCharacters(in: .whitespaces).uppercased()
        let invite = codeInvitation.trimmingCharacters(in: .whitespaces).uppercased()
        let appleID = appleUserID.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty, !invite.isEmpty, !appleID.isEmpty else { return nil }

        // Idempotence + anti-doublon : si cet Apple ID est DÉJÀ lié à un membre actif
        // de cette équipe, le retourner tel quel — ne JAMAIS créer un second
        // rattachement (évite les doublons en cas de double-clic / course).
        let descDejaLie = FetchDescriptor<Utilisateur>(
            predicate: #Predicate {
                $0.codeEquipe == code && $0.appleUserID == appleID && $0.estActif == true
            }
        )
        if let dejaLie = try? context.fetch(descDejaLie).first {
            return dejaLie
        }

        let descripteur = FetchDescriptor<Utilisateur>(
            predicate: #Predicate {
                $0.codeEquipe == code &&
                $0.codeInvitation == invite &&
                $0.appleUserID == "" &&
                $0.estActif == true
            }
        )
        guard let membre = try? context.fetch(descripteur).first else { return nil }
        // Anti-escalade : on ne réclame JAMAIS une ligne coach/admin via jointure
        // (seuls .etudiant/.assistantCoach rejoignent ; le coach crée l'équipe).
        guard Self.roleJonctionAutorise(membre.roleRaw) != nil else { return nil }
        membre.appleUserID = appleID
        membre.dateModification = Date()
        return membre
    }

    // MARK: - Partage Séances / Matchs (coach → athlète, lecture seule)

    /// Applique les stats cumulées d'un CKRecord JoueurPartage sur un JoueurEquipe.
    /// DRY — partagé par les branches update + création de `importerJoueur`.
    private func appliquerStats(_ record: CKRecord, sur joueur: JoueurEquipe) {
        joueur.matchsJoues = record["matchsJoues"] as? Int ?? joueur.matchsJoues
        joueur.setsJoues = record["setsJoues"] as? Int ?? joueur.setsJoues
        joueur.attaquesReussies = record["attaquesReussies"] as? Int ?? joueur.attaquesReussies
        joueur.erreursAttaque = record["erreursAttaque"] as? Int ?? joueur.erreursAttaque
        joueur.attaquesTotales = record["attaquesTotales"] as? Int ?? joueur.attaquesTotales
        joueur.aces = record["aces"] as? Int ?? joueur.aces
        joueur.erreursService = record["erreursService"] as? Int ?? joueur.erreursService
        joueur.servicesTotaux = record["servicesTotaux"] as? Int ?? joueur.servicesTotaux
        joueur.blocsSeuls = record["blocsSeuls"] as? Int ?? joueur.blocsSeuls
        joueur.blocsAssistes = record["blocsAssistes"] as? Int ?? joueur.blocsAssistes
        joueur.erreursBloc = record["erreursBloc"] as? Int ?? joueur.erreursBloc
        joueur.receptionsReussies = record["receptionsReussies"] as? Int ?? joueur.receptionsReussies
        joueur.erreursReception = record["erreursReception"] as? Int ?? joueur.erreursReception
        joueur.receptionsTotales = record["receptionsTotales"] as? Int ?? joueur.receptionsTotales
        joueur.passesDecisives = record["passesDecisives"] as? Int ?? joueur.passesDecisives
        joueur.manchettes = record["manchettes"] as? Int ?? joueur.manchettes
    }

    /// Importe une séance (merge `dateModification`). Lecture seule athlète.
    func importerSeance(from record: CKRecord, context: ModelContext) {
        guard let idString = record["seanceID"] as? String,
              let uuid = UUID(uuidString: idString) else { return }
        let remoteDateMod = record["dateModification"] as? Date ?? .distantPast
        let desc = FetchDescriptor<Seance>(predicate: #Predicate { $0.id == uuid })
        if let existant = try? context.fetch(desc).first {
            guard remoteDateMod > existant.dateModification else { return }
            existant.nom = record["nom"] as? String ?? existant.nom
            existant.date = record["date"] as? Date ?? existant.date
            existant.typeSeanceRaw = record["typeSeanceRaw"] as? String ?? existant.typeSeanceRaw
            existant.lieu = record["lieu"] as? String ?? existant.lieu
            existant.adversaire = record["adversaire"] as? String ?? existant.adversaire
            existant.scoreEquipe = record["scoreEquipe"] as? Int ?? existant.scoreEquipe
            existant.scoreAdversaire = record["scoreAdversaire"] as? Int ?? existant.scoreAdversaire
            existant.resultatRaw = record["resultatRaw"] as? String ?? existant.resultatRaw
            existant.estArchivee = (record["estArchivee"] as? Int ?? 0) == 1
            existant.dateModification = remoteDateMod
            return
        }
        let seance = Seance(nom: record["nom"] as? String ?? "",
                            date: record["date"] as? Date ?? Date(),
                            typeSeance: TypeSeance(rawValue: record["typeSeanceRaw"] as? String ?? "") ?? .pratique)
        seance.id = uuid
        seance.codeEquipe = record["codeEquipe"] as? String ?? ""
        seance.lieu = record["lieu"] as? String ?? ""
        seance.adversaire = record["adversaire"] as? String ?? ""
        seance.scoreEquipe = record["scoreEquipe"] as? Int ?? 0
        seance.scoreAdversaire = record["scoreAdversaire"] as? Int ?? 0
        seance.resultatRaw = record["resultatRaw"] as? String ?? ""
        seance.estArchivee = (record["estArchivee"] as? Int ?? 0) == 1
        seance.dateModification = remoteDateMod
        context.insert(seance)
    }

    // MARK: - Helpers CloudKit

    /// Prédicat de recherche public (extrait pour test du backward-compat OR).
    /// UtilisateurPartage : `codeEquipe OR codeEcole` (records v<2.0.1 indexés par
    /// codeEcole). Les autres types : `codeEquipe` uniquement.
    static func predicatRecherche(estUtilisateur: Bool, codeEquipe: String) -> NSPredicate {
        estUtilisateur
            ? NSPredicate(format: "codeEquipe == %@ OR codeEcole == %@", codeEquipe, codeEquipe)
            : NSPredicate(format: "%K == %@", "codeEquipe", codeEquipe)
    }

    private func fetchRecords(type: String, codeEquipe: String) async throws -> [CKRecord] {
        // Les deux champs (codeEquipe ET codeEcole) doivent être QUERYABLE dans le
        // schéma CloudKit public pour UtilisateurPartage (action humaine ASC).
        let predicate = Self.predicatRecherche(estUtilisateur: type == RecordType.utilisateur, codeEquipe: codeEquipe)
        let query = CKQuery(recordType: type, predicate: predicate)

        var allRecords: [CKRecord] = []
        let (results, _) = try await publicDB.records(matching: query, resultsLimit: 200)

        for (_, result) in results {
            if case .success(let record) = result {
                allRecords.append(record)
            }
        }

        return allRecords
    }

    // MARK: - Erreurs

    enum SharingError: LocalizedError {
        case equipeNonTrouvee
        case importEchoue
        case sauvegardeEchouee
        case invitationInvalide

        var errorDescription: String? {
            switch self {
            case .equipeNonTrouvee: return "Aucune équipe trouvée avec ce code."
            case .importEchoue: return "Impossible d'importer les données de l'équipe."
            case .sauvegardeEchouee: return "Impossible de sauvegarder les données importées."
            case .invitationInvalide: return "Code d'invitation invalide ou déjà utilisé. Vérifie avec ton coach."
            }
        }
    }
}
