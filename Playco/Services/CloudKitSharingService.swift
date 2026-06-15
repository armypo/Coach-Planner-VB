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
        static let matchCalendrier = "MatchCalendrierPartagee"
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
                try await publierUtilisateur(u)
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
            let descM = FetchDescriptor<MatchCalendrier>(predicate: #Predicate { $0.codeEquipe == codeEquipe })
            for m in (try? context.fetch(descM)) ?? [] where m.dateModification > seuil {
                try await publierMatchCalendrier(m)
            }
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

        // 6. SÉCURITÉ : on n'importe PLUS les comptes Utilisateur (avec hash) depuis
        // la Public DB. Le compte du membre joignant est créé localement, le hash
        // dérivé du mot de passe saisi (cf. `creerCompteLocalJonction`). On ne
        // réplique jamais les credentials des autres membres sur cet appareil.

        // 7. Récupérer et importer les joueurs
        let joueurRecords = try await fetchRecords(type: RecordType.joueur, codeEquipe: codeEquipe)
        for record in joueurRecords {
            importerJoueur(from: record, context: context)
        }

        // 7b. Importer séances + matchs du calendrier (lecture seule athlète).
        let seanceRecords = try await fetchRecords(type: RecordType.seance, codeEquipe: codeEquipe)
        for record in seanceRecords { importerSeance(from: record, context: context) }
        let matchCalRecords = try await fetchRecords(type: RecordType.matchCalendrier, codeEquipe: codeEquipe)
        for record in matchCalRecords { importerMatchCalendrier(from: record, context: context) }

        // 8. Brancher le tier d'abonnement depuis AbonnementPartage (Public DB).
        // EquipePartagee ne porte PAS le tier (sécurité). Sans ça l'équipe importée
        // resterait .aucun → athlète d'un coach Club bloqué à tort (gate).
        if let snap = await CloudKitPublicSyncAbonnement.shared.lire(codeEquipe: codeEquipe) {
            let codeRech = codeEquipe
            let descEq = FetchDescriptor<Equipe>(predicate: #Predicate { $0.codeEquipe == codeRech })
            if let eqLocale = try? context.fetch(descEq).first, eqLocale.tierAbonnement != snap.tier {
                eqLocale.tierAbonnement = snap.tier
                logger.info("Tier importé pour \(codeEquipe, privacy: .private): \(snap.tier.rawValue, privacy: .public)")
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

    /// Crée le compte local du membre joignant en dérivant le hash LOCALEMENT à
    /// partir du mot de passe saisi — aucun matériel dérivé du mot de passe n'est
    /// jamais lu depuis la Public DB. Modèle « premier mdp tapé = le sien ».
    ///
    /// Le profil (prénom/nom/role/numéro/poste) provient du record `UtilisateurPartage`
    /// (non sensible). Le rôle est **clampé** via `roleJonctionAutorise` : jamais
    /// coach/admin accordé en aveugle depuis un record réseau (anti-escalade).
    /// À appeler après `recupererEtImporterEquipe`, avant `AuthService.connexion`.
    /// No-op si un compte avec cet UUID existe déjà localement.
    func creerCompteLocalJonction(
        codeEquipe: String,
        identifiant: String,
        motDePasse: String,
        context: ModelContext
    ) async throws {
        let codeNormalise = Equipe.normaliserCodeEquipe(codeEquipe)
        let idNormalise = identifiant.lowercased().trimmingCharacters(in: .whitespaces)

        let utilisateurRecords = try await fetchRecords(type: RecordType.utilisateur, codeEquipe: codeNormalise)
        guard let monRecord = utilisateurRecords.first(where: {
            ($0["identifiant"] as? String)?.lowercased() == idNormalise
        }) else {
            throw SharingError.utilisateurNonTrouve
        }

        // Clamp du rôle — jamais coach/admin via jonction.
        guard let roleAutorise = Self.roleJonctionAutorise(monRecord["roleRaw"] as? String ?? "") else {
            throw SharingError.roleNonAutorise
        }

        let uuid = (monRecord["utilisateurID"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()
        let descripteurUser = FetchDescriptor<Utilisateur>(predicate: #Predicate { $0.id == uuid })
        guard ((try? context.fetch(descripteurUser)) ?? []).isEmpty else { return }

        let sel = KeyDerivation.genererSel()
        let hash: String
        do {
            hash = try KeyDerivation.hashPBKDF2(motDePasse, sel: sel)
        } catch {
            logger.error("creerCompteLocalJonction: dérivation hash échouée: \(error.localizedDescription)")
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

        do {
            try context.save()
        } catch {
            logger.error("creerCompteLocalJonction: échec sauvegarde: \(error.localizedDescription)")
            throw SharingError.sauvegardeEchouee
        }
        logger.info("Compte local de jonction créé (rôle \(roleAutorise.rawValue, privacy: .public))")
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

            let matchCalRecords = try await fetchRecords(type: RecordType.matchCalendrier, codeEquipe: codeEquipe)
            for record in matchCalRecords { importerMatchCalendrier(from: record, context: context) }

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

    /// Construit le record `UtilisateurPartage` publié en Public DB.
    ///
    /// SÉCURITÉ : ne contient JAMAIS de matériel dérivé du mot de passe
    /// (`motDePasseHash` / `sel` / `iterations`) — la Public DB est world-readable.
    /// Le hash est dérivé localement au moment de la jonction
    /// (cf. `creerCompteLocalJonction`). Voir docs/Securite_AbonnementPublicDB.md.
    /// Exposé `internal` pour une garde de régression unitaire.
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
        _ = try await publicDB.save(Self.construireRecordUtilisateur(utilisateur))
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

    /// Publie un match du calendrier en lecture seule pour les athlètes.
    func publierMatchCalendrier(_ match: MatchCalendrier) async throws {
        let recordID = CKRecord.ID(recordName: "matchcal-\(match.id.uuidString)")
        let record = CKRecord(recordType: RecordType.matchCalendrier, recordID: recordID)
        record["matchID"] = match.id.uuidString as CKRecordValue
        record["codeEquipe"] = match.codeEquipe as CKRecordValue
        record["date"] = match.date as CKRecordValue
        record["adversaire"] = match.adversaire as CKRecordValue
        record["lieu"] = match.lieu as CKRecordValue
        record["estDomicile"] = (match.estDomicile ? 1 : 0) as CKRecordValue
        record["dateModification"] = match.dateModification as CKRecordValue
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

    // NOTE SÉCURITÉ : `importerUtilisateur` a été supprimé. On n'importe plus de
    // comptes Utilisateur (avec credentials) depuis la Public DB. Le compte du
    // membre joignant est créé localement avec un hash dérivé du mot de passe
    // saisi (`creerCompteLocalJonction`). Voir docs/Securite_AbonnementPublicDB.md.

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

    /// Importe un match du calendrier (merge `dateModification`). Lecture seule athlète.
    func importerMatchCalendrier(from record: CKRecord, context: ModelContext) {
        guard let idString = record["matchID"] as? String,
              let uuid = UUID(uuidString: idString) else { return }
        let remoteDateMod = record["dateModification"] as? Date ?? .distantPast
        let code = record["codeEquipe"] as? String ?? ""
        let descEq = FetchDescriptor<Equipe>(predicate: #Predicate { $0.codeEquipe == code })
        let equipeLocale = try? context.fetch(descEq).first
        let desc = FetchDescriptor<MatchCalendrier>(predicate: #Predicate { $0.id == uuid })
        if let existant = try? context.fetch(desc).first {
            guard remoteDateMod > existant.dateModification else { return }
            existant.date = record["date"] as? Date ?? existant.date
            existant.adversaire = record["adversaire"] as? String ?? existant.adversaire
            existant.lieu = record["lieu"] as? String ?? existant.lieu
            existant.estDomicile = (record["estDomicile"] as? Int ?? 1) == 1
            existant.equipe = existant.equipe ?? equipeLocale
            existant.dateModification = remoteDateMod
            return
        }
        let match = MatchCalendrier(date: record["date"] as? Date ?? Date(),
                                    adversaire: record["adversaire"] as? String ?? "")
        match.id = uuid
        match.codeEquipe = code
        match.lieu = record["lieu"] as? String ?? ""
        match.estDomicile = (record["estDomicile"] as? Int ?? 1) == 1
        match.equipe = equipeLocale
        match.dateModification = remoteDateMod
        context.insert(match)
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
