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
                    try await publierUtilisateur(utilisateur)
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
                try await publierUtilisateur(utilisateur)
                await FileReplicationUtilisateur.shared.marquerPublie(id)
            } catch {
                await FileReplicationUtilisateur.shared.planifierRetry(id)
                logger.warning("Retry publication utilisateur \(id.uuidString, privacy: .private) échoué : \(error.localizedDescription)")
            }
        }
    }

    /// Publie un seul utilisateur (quand le coach ajoute un athlète après la config initiale)
    func publierNouvelUtilisateur(_ utilisateur: Utilisateur, joueur: JoueurEquipe?) async {
        do {
            try await publierUtilisateur(utilisateur)
            if let joueur {
                try await publierJoueur(joueur)
            }
            logger.info("Utilisateur \(utilisateur.identifiant, privacy: .private) publié")
        } catch {
            logger.error("Erreur publication utilisateur: \(error.localizedDescription)")
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
                try await publierUtilisateur(utilisateur)
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

    /// Rôles autorisés à rejoindre une équipe via le flux public.
    ///
    /// SÉCURITÉ : le rôle n'est JAMAIS accordé en aveugle depuis un record
    /// world-readable (et potentiellement forgeable). Seuls `.etudiant` et
    /// `.assistantCoach` peuvent rejoindre — un `roleRaw` résolvant en `.coach`
    /// ou `.admin` est rejeté (le coach est le créateur de l'équipe, jamais un
    /// joignant). Défense en profondeur avec les CloudKit Security Roles.
    static func roleJonctionAutorise(_ roleRaw: String) -> RoleUtilisateur? {
        guard let role = RoleUtilisateur(rawValue: roleRaw) else { return nil }
        switch role {
        case .etudiant, .assistantCoach: return role
        case .coach, .admin: return nil
        }
    }

    /// Rejoint une équipe depuis un autre Apple ID : importe les données d'équipe
    /// publiques puis crée le compte local du membre en **dérivant le hash
    /// localement** à partir du mot de passe saisi. Aucun matériel dérivé du mot
    /// de passe n'est jamais lu depuis la Public DB.
    ///
    /// Modèle « premier mdp tapé = le sien » : le membre choisit/saisit son mot
    /// de passe à la jonction ; il devient son credential local (cf. plan).
    func rejoindreEquipe(
        codeEquipe: String,
        identifiant: String,
        motDePasse: String,
        context: ModelContext
    ) async throws {
        estEnCoursDeRecuperation = true
        erreur = nil
        defer { estEnCoursDeRecuperation = false }

        // Normalisation canonique (uppercase + filtre alphabet Base32) — gère
        // les codes collés avec espaces/tirets. Cohérent avec la génération.
        let codeNormalise = Equipe.normaliserCodeEquipe(codeEquipe)
        let idNormalise = identifiant.lowercased().trimmingCharacters(in: .whitespaces)

        // 1. Récupérer l'équipe (sinon code invalide)
        let equipeRecords = try await fetchRecords(type: RecordType.equipe, codeEquipe: codeNormalise)
        guard let equipeRecord = equipeRecords.first else {
            throw SharingError.equipeNonTrouvee
        }

        // 2. Trouver le profil du membre joignant (sans credentials)
        let utilisateurRecords = try await fetchRecords(type: RecordType.utilisateur, codeEquipe: codeNormalise)
        guard let monRecord = utilisateurRecords.first(where: {
            ($0["identifiant"] as? String)?.lowercased() == idNormalise
        }) else {
            throw SharingError.utilisateurNonTrouve
        }

        // 3. Clamp du rôle — jamais coach/admin via jonction
        guard let roleAutorise = Self.roleJonctionAutorise(monRecord["roleRaw"] as? String ?? "") else {
            throw SharingError.roleNonAutorise
        }

        // 4. Importer l'équipe + établissement localement si absents
        let descripteurEquipe = FetchDescriptor<Equipe>(
            predicate: #Predicate { $0.codeEquipe == codeNormalise }
        )
        let equipesLocales = (try? context.fetch(descripteurEquipe)) ?? []
        if equipesLocales.isEmpty {
            let etabRecords = try await fetchRecords(type: RecordType.etablissement, codeEquipe: codeNormalise)
            var etablissementLocal: Etablissement?
            if let etabRecord = etabRecords.first {
                etablissementLocal = importerEtablissement(from: etabRecord, context: context)
            }
            importerEquipe(from: equipeRecord, etablissement: etablissementLocal, context: context)

            // ProfilCoach minimal pour que configurationCompletee = true
            let profilDescriptor = FetchDescriptor<ProfilCoach>(
                predicate: #Predicate { $0.configurationCompletee == true }
            )
            if ((try? context.fetch(profilDescriptor)) ?? []).isEmpty {
                let profil = ProfilCoach()
                profil.configurationCompletee = true
                context.insert(profil)
            }
        }

        // 5. Importer le roster (JoueurEquipe) — données non sensibles
        let joueurRecords = try await fetchRecords(type: RecordType.joueur, codeEquipe: codeNormalise)
        for record in joueurRecords {
            importerJoueur(from: record, context: context)
        }

        // 6. Créer le compte local en dérivant le hash localement (jamais publié)
        let uuid = (monRecord["utilisateurID"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()
        let descripteurUser = FetchDescriptor<Utilisateur>(
            predicate: #Predicate { $0.id == uuid }
        )
        if ((try? context.fetch(descripteurUser)) ?? []).isEmpty {
            let sel = KeyDerivation.genererSel()
            let hash: String
            do {
                hash = try KeyDerivation.hashPBKDF2(motDePasse, sel: sel)
            } catch {
                logger.error("rejoindreEquipe: dérivation hash échouée: \(error.localizedDescription)")
                throw SharingError.sauvegardeEchouee
            }

            let utilisateur = Utilisateur(
                identifiant: monRecord["identifiant"] as? String ?? idNormalise,
                motDePasseHash: hash,
                prenom: monRecord["prenom"] as? String ?? "",
                nom: monRecord["nom"] as? String ?? "",
                role: roleAutorise,
                codeEcole: codeNormalise
            )
            utilisateur.id = uuid
            utilisateur.sel = sel
            utilisateur.iterations = KeyDerivation.iterationsParDefaut
            utilisateur.estActif = (monRecord["estActif"] as? Int ?? 1) == 1
            if let joueurIDStr = monRecord["joueurEquipeID"] as? String {
                utilisateur.joueurEquipeID = UUID(uuidString: joueurIDStr)
            }
            if let numero = monRecord["numero"] as? Int { utilisateur.numero = numero }
            if let posteRaw = monRecord["posteRaw"] as? String { utilisateur.posteRaw = posteRaw }
            context.insert(utilisateur)
        }

        do {
            try context.save()
        } catch {
            logger.error("rejoindreEquipe: échec sauvegarde SwiftData: \(error.localizedDescription)")
            throw SharingError.sauvegardeEchouee
        }

        logger.info("Jonction réussie à l'équipe \(codeNormalise, privacy: .private) (rôle \(roleAutorise.rawValue, privacy: .public))")
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
        // Tier d'abonnement (non sensible) : permet à la gate de laisser entrer
        // les membres qui rejoignent sur un autre Apple ID quand le coach est
        // abonné (l'Abonnement lui-même n'est pas synchronisé cross-Apple-ID).
        record["tierAbonnementRaw"] = equipe.tierAbonnementRaw as CKRecordValue
        record["dateModification"] = equipe.dateModification as CKRecordValue

        try await publicDB.save(record)
    }

    private func publierEtablissement(_ etab: Etablissement, codeEquipe: String) async throws {
        let recordID = CKRecord.ID(recordName: "etab-\(codeEquipe)")
        let record = CKRecord(recordType: RecordType.etablissement, recordID: recordID)

        record["codeEquipe"] = codeEquipe as CKRecordValue
        record["nom"] = etab.nom as CKRecordValue
        record["typeRaw"] = etab.typeRaw as CKRecordValue
        record["ville"] = etab.ville as CKRecordValue
        record["province"] = etab.province as CKRecordValue

        try await publicDB.save(record)
    }

    /// Construit le record `UtilisateurPartage` publié en Public DB.
    ///
    /// SÉCURITÉ : ne contient JAMAIS de matériel dérivé du mot de passe
    /// (`motDePasseHash` / `sel` / `iterations`) — la Public DB est world-readable.
    /// Le hash est dérivé localement sur l'appareil du membre au moment de la
    /// jonction (cf. `rejoindreEquipe`). Voir docs/Securite_AbonnementPublicDB.md.
    /// Exposé `internal` pour permettre une garde de régression unitaire.
    static func construireRecordUtilisateur(_ utilisateur: Utilisateur) -> CKRecord {
        let recordID = CKRecord.ID(recordName: "user-\(utilisateur.id.uuidString)")
        let record = CKRecord(recordType: RecordType.utilisateur, recordID: recordID)

        record["utilisateurID"] = utilisateur.id.uuidString as CKRecordValue
        record["identifiant"] = utilisateur.identifiant as CKRecordValue
        record["prenom"] = utilisateur.prenom as CKRecordValue
        record["nom"] = utilisateur.nom as CKRecordValue
        record["roleRaw"] = utilisateur.roleRaw as CKRecordValue
        record["codeEcole"] = utilisateur.codeEcole as CKRecordValue
        record["estActif"] = (utilisateur.estActif ? 1 : 0) as CKRecordValue

        if let joueurID = utilisateur.joueurEquipeID {
            record["joueurEquipeID"] = joueurID.uuidString as CKRecordValue
        }
        if utilisateur.numero > 0 {
            record["numero"] = utilisateur.numero as CKRecordValue
        }
        if !utilisateur.posteRaw.isEmpty {
            record["posteRaw"] = utilisateur.posteRaw as CKRecordValue
        }
        record["dateModification"] = utilisateur.dateModification as CKRecordValue

        return record
    }

    private func publierUtilisateur(_ utilisateur: Utilisateur) async throws {
        let record = Self.construireRecordUtilisateur(utilisateur)
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
        record["dateModification"] = joueur.dateModification as CKRecordValue

        try await publicDB.save(record)
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
        // Tier d'abonnement (défaut .aucun si record antérieur à l'ajout du champ)
        if let tierRaw = record["tierAbonnementRaw"] as? String, !tierRaw.isEmpty {
            equipe.tierAbonnementRaw = tierRaw
        }
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

        context.insert(joueur)
    }

    // MARK: - Helpers CloudKit

    private func fetchRecords(type: String, codeEquipe: String) async throws -> [CKRecord] {
        let champ = type == RecordType.utilisateur ? "codeEcole" : "codeEquipe"
        let predicate = NSPredicate(format: "%K == %@", champ, codeEquipe)
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
        case utilisateurNonTrouve
        case roleNonAutorise
        case importEchoue
        case sauvegardeEchouee

        var errorDescription: String? {
            switch self {
            case .equipeNonTrouvee: return "Aucune équipe trouvée avec ce code."
            case .utilisateurNonTrouve: return "Aucun membre trouvé avec cet identifiant dans cette équipe."
            case .roleNonAutorise: return "Ce compte ne peut pas rejoindre une équipe de cette façon. Contacte ton coach."
            case .importEchoue: return "Impossible d'importer les données de l'équipe."
            case .sauvegardeEchouee: return "Impossible de sauvegarder les données importées."
            }
        }
    }
}
