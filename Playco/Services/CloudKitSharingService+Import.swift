//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  CloudKitSharingService+Import — Récupération et import des données d'équipe
//  depuis la CloudKit Public Database (côté athlète/assistant).

import Foundation
import CloudKit
import SwiftData
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "CloudKitSharing")

extension CloudKitSharingService {

    // MARK: - Récupération (côté Athlète)

    /// Vérifie si un code d'équipe existe dans le CloudKit public.
    /// - Throws: `SharingError.reseauIndisponible` si la vérification n'a pas pu
    ///   aboutir (hors-ligne, quota…) — à distinguer d'un code réellement inconnu,
    ///   sinon l'utilisateur hors-ligne voit « code invalide » à tort.
    func equipeExiste(codeEquipe: String) async throws -> Bool {
        let predicate = NSPredicate(format: "codeEquipe == %@", codeEquipe)
        let query = CKQuery(recordType: RecordType.equipe, predicate: predicate)

        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)
            return !results.isEmpty
        } catch {
            logger.error("Erreur vérification équipe: \(error.localizedDescription)")
            throw SharingError.reseauIndisponible
        }
    }

    /// Nom PUBLIC de l'équipe (lecture seule, sanitisé) — affiché à l'athlète
    /// AVANT le rattachement de son Apple ID (revue 2.3 : anti-phishing QR).
    func nomEquipePublique(codeEquipe: String) async throws -> String? {
        let predicate = NSPredicate(format: "codeEquipe == %@", codeEquipe)
        let query = CKQuery(recordType: RecordType.equipe, predicate: predicate)
        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)
            guard let record = try results.first?.1.get() else { return nil }
            return record.chaineSecurisee("nom")
        } catch {
            logger.error("Erreur lecture nom équipe: \(error.localizedDescription)")
            throw SharingError.reseauIndisponible
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

        // E′ §2 — chaîne de confiance par créateur, construite AVANT tout import.
        let confiance = try await construireConfianceEquipe(codeEquipe: codeEquipe)

        // E′ §4 — tombstones appliqués en PREMIER (les suppressions gagnent
        // sur les records d'entité périmés).
        try await importerTombstones(codeEquipe: codeEquipe, confiance: confiance, context: context)

        // 6. Importer les Utilisateur de mapping d'équipe (SANS secret — cf.
        // `champsPublicsUtilisateur`). Requis pour la jointure SIWA : `reclamerMembreLocal`
        // retrouve la ligne de roster par code d'invitation puis y rattache l'appleUserID.
        let utilisateurRecords = try await fetchRecords(type: RecordType.utilisateur, codeEquipe: codeEquipe)
        for record in utilisateurRecords where accepterRecord(record, confiance: confiance, codeEquipe: codeEquipe) {
            if let (entiteID, date) = importerUtilisateur(from: record, context: context) {
                etatSync.poserFiligrane(codeEquipe, entiteID: entiteID, date: date)
            }
        }

        // 7. Récupérer et importer les joueurs
        let joueurRecords = try await fetchRecords(type: RecordType.joueur, codeEquipe: codeEquipe)
        for record in joueurRecords where accepterRecord(record, confiance: confiance, codeEquipe: codeEquipe) {
            if let (entiteID, date) = importerJoueur(from: record, context: context),
               !etatSync.estSupprimee(codeEquipe, entiteID: entiteID, dateModification: date) {
                etatSync.poserFiligrane(codeEquipe, entiteID: entiteID, date: date)
            }
        }

        // 7b. Importer les séances (incl. matchs type=.match).
        let seanceRecords = try await fetchRecords(type: RecordType.seance, codeEquipe: codeEquipe)
        for record in seanceRecords where accepterRecord(record, confiance: confiance, codeEquipe: codeEquipe) {
            if let (entiteID, date) = importerSeance(from: record, context: context) {
                etatSync.poserFiligrane(codeEquipe, entiteID: entiteID, date: date)
            }
        }

        // 7c. E2 — contenus de préparation (APRÈS les séances : les exercices
        // se rattachent à leur séance parente).
        try await importerContenusPreparation(codeEquipe: codeEquipe, confiance: confiance, context: context)

        // 7d. E3 — analyse (box scores, points live incrémentaux, formations).
        try await importerAnalyse(codeEquipe: codeEquipe, confiance: confiance, context: context)

        do {
            try context.save()
        } catch {
            logger.error("importerEquipeDepuisPublic: échec sauvegarde SwiftData: \(error.localizedDescription)")
            throw SharingError.sauvegardeEchouee
        }

        // E4 — baseline de publication : après un import initial complet, tout
        // le contenu local vient du remote (et filigrané) — le premier sweep de
        // cet appareil ne re-téléverse pas l'équipe. Seuil PAR ÉQUIPE (E′).
        etatSync.modifier(codeEquipe) { $0.seuilPublication = Date() }

        logger.info("Équipe \(codeEquipe, privacy: .private) importée: \(joueurRecords.count) joueurs (comptes non répliqués)")
    }


    // MARK: - Sync incrémentale

    /// Synchronise les nouvelles données depuis le public DB (appel périodique)
    func syncDepuisPublic(codeEquipe: String, context: ModelContext) async {
        #if DEMO
        return
        #endif
        do {
            // E′ §2/§4 : confiance par créateur puis tombstones, avant tout import.
            let confiance = try await construireConfianceEquipe(codeEquipe: codeEquipe)
            try await importerTombstones(codeEquipe: codeEquipe, confiance: confiance, context: context)

            // SÉCURITÉ : pas d'import de comptes Utilisateur (credentials). On ne
            // rafraîchit que les données non sensibles (roster, séances, calendrier).
            let joueurRecords = try await fetchRecords(type: RecordType.joueur, codeEquipe: codeEquipe)
            for record in joueurRecords where accepterRecord(record, confiance: confiance, codeEquipe: codeEquipe) {
                if let (entiteID, date) = importerJoueur(from: record, context: context),
                   !etatSync.estSupprimee(codeEquipe, entiteID: entiteID, dateModification: date) {
                    etatSync.poserFiligrane(codeEquipe, entiteID: entiteID, date: date)
                }
            }

            let seanceRecords = try await fetchRecords(type: RecordType.seance, codeEquipe: codeEquipe)
            for record in seanceRecords where accepterRecord(record, confiance: confiance, codeEquipe: codeEquipe) {
                if let (entiteID, date) = importerSeance(from: record, context: context) {
                    etatSync.poserFiligrane(codeEquipe, entiteID: entiteID, date: date)
                }
            }

            // E2 — contenus de préparation (après les séances pour le rattachement).
            try await importerContenusPreparation(codeEquipe: codeEquipe, confiance: confiance, context: context)

            // E3 — analyse (box scores, points live incrémentaux, formations).
            try await importerAnalyse(codeEquipe: codeEquipe, confiance: confiance, context: context)

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



    // MARK: - Import contenus de préparation (E2 — parité assistant D6)

    /// Importe exercices de séance, stratégies, scoutings et bibliothèque.
    /// Appelé APRÈS l'import des séances (rattachement des exercices).
    /// E′ : confiance par créateur, tombstones respectés, filigranes posés.
    func importerContenusPreparation(codeEquipe: String, confiance: ConfianceEquipe, context: ModelContext) async throws {
        func integrer(_ resultat: (UUID, Date)?) {
            guard let (entiteID, date) = resultat,
                  !etatSync.estSupprimee(codeEquipe, entiteID: entiteID, dateModification: date) else { return }
            etatSync.poserFiligrane(codeEquipe, entiteID: entiteID, date: date)
        }
        func supprimee(_ record: CKRecord, cleID: String) -> Bool {
            guard let idStr = record.chaineSecurisee(cleID), let id = UUID(uuidString: idStr) else { return true }
            let date = record["dateModification"] as? Date ?? .distantPast
            return etatSync.estSupprimee(codeEquipe, entiteID: id, dateModification: date)
        }

        let exerciceRecords = try await fetchRecords(type: RecordType.exercice, codeEquipe: codeEquipe)
        for record in exerciceRecords
        where accepterRecord(record, confiance: confiance, codeEquipe: codeEquipe) && !supprimee(record, cleID: "exerciceID") {
            integrer(importerExercice(from: record, context: context))
        }

        let strategieRecords = try await fetchRecords(type: RecordType.strategie, codeEquipe: codeEquipe)
        for record in strategieRecords
        where accepterRecord(record, confiance: confiance, codeEquipe: codeEquipe) && !supprimee(record, cleID: "strategieID") {
            integrer(importerStrategie(from: record, context: context))
        }

        let scoutingRecords = try await fetchRecords(type: RecordType.scouting, codeEquipe: codeEquipe)
        for record in scoutingRecords
        where accepterRecord(record, confiance: confiance, codeEquipe: codeEquipe) && !supprimee(record, cleID: "scoutingID") {
            integrer(importerScouting(from: record, context: context))
        }

        let biblioRecords = try await fetchRecords(type: RecordType.bibliotheque, codeEquipe: codeEquipe)
        for record in biblioRecords
        where accepterRecord(record, confiance: confiance, codeEquipe: codeEquipe) && !supprimee(record, cleID: "exerciceID") {
            integrer(importerBibliotheque(from: record, context: context))
        }
    }

    // MARK: - Confiance par créateur (E′ §2)

    /// Construit l'ensemble de confiance d'une équipe depuis la Public DB :
    /// racine = créateur du record `equipe-<code>` (recordName unique,
    /// infalsifiable), membres = racine + assistants dont la copie
    /// UtilisateurPartage revendique un couple (utilisateurID, codeInvitation)
    /// émis par la racine.
    func construireConfianceEquipe(codeEquipe: String) async throws -> ConfianceEquipe {
        let equipeRecords = try await fetchRecords(type: RecordType.equipe, codeEquipe: codeEquipe)
        let racine = equipeRecords.first?.creatorUserRecordID?.recordName
        let utilisateurRecords = try await fetchRecords(type: RecordType.utilisateur, codeEquipe: codeEquipe)
        let lignes: [(createur: String, utilisateurID: String, codeInvitation: String)] =
            utilisateurRecords.compactMap { record in
                guard let createur = record.creatorUserRecordID?.recordName,
                      let utilisateurID = record.chaineSecurisee("utilisateurID") else { return nil }
                return (createur, utilisateurID, record.chaineSecurisee("codeInvitation") ?? "")
            }
        return Self.construireConfiance(racine: racine, lignes: lignes)
    }

    /// E′ §1-2 : un record n'est importé que s'il (1) porte une identité
    /// d'écrivain (les records legacy pré-E′ sont inertes), (2) vient d'un
    /// créateur de confiance (métadonnée serveur, infalsifiable), (3) revendique
    /// la bonne équipe.
    func accepterRecord(_ record: CKRecord, confiance: ConfianceEquipe, codeEquipe: String) -> Bool {
        guard let ecrivain = record.chaineSecurisee("ecrivainID"), !ecrivain.isEmpty else { return false }
        guard confiance.accepte(createur: record.creatorUserRecordID?.recordName) else { return false }
        return record.chaineSecurisee("codeEquipe") == codeEquipe
    }

    // MARK: - Tombstones (E′ §4)

    /// Importe et applique les tombstones de suppression AVANT tout le reste :
    /// entité locale supprimée si le tombstone est au moins aussi récent que sa
    /// dateModification ; les records d'entité plus vieux sont ensuite ignorés
    /// (`EtatSyncEquipe.estSupprimee`). Une re-création postérieure gagne.
    func importerTombstones(codeEquipe: String, confiance: ConfianceEquipe, context: ModelContext) async throws {
        let records = try await fetchRecords(type: RecordType.suppression, codeEquipe: codeEquipe)
        for record in records where accepterRecord(record, confiance: confiance, codeEquipe: codeEquipe) {
            guard let idStr = record.chaineSecurisee("entiteID"),
                  let entiteID = UUID(uuidString: idStr),
                  let typeCible = record.chaineSecurisee("typeCible"),
                  let horodatage = record["horodatage"] as? Date else { continue }
            etatSync.enregistrerTombstone(codeEquipe, entiteID: entiteID, horodatage: horodatage)
            appliquerTombstone(typeCible: typeCible, entiteID: entiteID,
                               horodatage: horodatage, context: context)
        }
    }

    /// Supprime localement l'entité visée si le tombstone gagne le LWW.
    private func appliquerTombstone(typeCible: String, entiteID: UUID, horodatage: Date, context: ModelContext) {
        func supprimer<T: PersistentModel>(_ desc: FetchDescriptor<T>, date: (T) -> Date) {
            guard let entite = try? context.fetch(desc).first,
                  EtatSyncEquipe.tombstoneGagne(horodatageTombstone: horodatage,
                                                dateModificationLocale: date(entite)) else { return }
            context.delete(entite)
        }
        switch typeCible {
        case RecordType.exercice:
            supprimer(FetchDescriptor<Exercice>(predicate: #Predicate { $0.id == entiteID }),
                      date: { $0.dateModification })
        case RecordType.bibliotheque:
            supprimer(FetchDescriptor<ExerciceBibliotheque>(predicate: #Predicate { $0.id == entiteID }),
                      date: { $0.dateModification })
        case RecordType.formation:
            supprimer(FetchDescriptor<FormationPersonnalisee>(predicate: #Predicate { $0.id == entiteID }),
                      date: { $0.dateModification })
        case RecordType.joueur:
            supprimer(FetchDescriptor<JoueurEquipe>(predicate: #Predicate { $0.id == entiteID }),
                      date: { $0.dateModification })
        case RecordType.scouting:
            supprimer(FetchDescriptor<ScoutingReport>(predicate: #Predicate { $0.id == entiteID }),
                      date: { $0.dateModification })
        case RecordType.statsMatch:
            supprimer(FetchDescriptor<StatsMatch>(predicate: #Predicate { $0.id == entiteID }),
                      date: { $0.dateModification })
        case Self.typeCiblePointsSeance:
            // Portée séance : purge tous les points locaux du match supprimé
            // antérieurs au tombstone (le preneur de stats qui recrée gagne).
            let points = (try? context.fetch(
                FetchDescriptor<PointMatch>(predicate: #Predicate { $0.seanceID == entiteID }))) ?? []
            for point in points where point.horodatage <= horodatage {
                context.delete(point)
            }
        default:
            break
        }
    }

    // MARK: - Import vers SwiftData

    func importerEquipe(from record: CKRecord, etablissement: Etablissement?, context: ModelContext) {
        let equipe = Equipe(nom: record.chaineSecurisee("nom") ?? "")
        equipe.codeEquipe = record.chaineSecurisee("codeEquipe") ?? ""
        equipe.categorieRaw = record.chaineSecurisee("categorieRaw") ?? ""
        equipe.divisionRaw = record.chaineSecurisee("divisionRaw") ?? ""
        equipe.saison = record.chaineSecurisee("saison") ?? ""
        equipe.couleurPrincipalHex = record.chaineSecurisee("couleurPrincipalHex") ?? "#E8734A"
        equipe.couleurSecondaireHex = record.chaineSecurisee("couleurSecondaireHex") ?? "#4A8AF4"
        equipe.etablissement = etablissement
        context.insert(equipe)
    }

    func importerEtablissement(from record: CKRecord, context: ModelContext) -> Etablissement {
        let etab = Etablissement(
            nom: record.chaineSecurisee("nom") ?? "",
            type: TypeEtablissement(rawValue: record.chaineSecurisee("typeRaw") ?? "") ?? .universite,
            ville: record.chaineSecurisee("ville") ?? "",
            province: record.chaineSecurisee("province") ?? ""
        )
        context.insert(etab)
        return etab
    }

    @discardableResult
    func importerUtilisateur(from record: CKRecord, context: ModelContext) -> (UUID, Date)? {
        guard let idString = record.chaineSecurisee("utilisateurID"),
              let uuid = UUID(uuidString: idString) else { return nil }

        // Vérifier si cet utilisateur existe déjà
        let descripteur = FetchDescriptor<Utilisateur>(
            predicate: #Predicate { $0.id == uuid }
        )
        if let existant = try? context.fetch(descripteur).first {
            // Comparer dateModification — ne mettre à jour que si le remote est plus récent
            let remoteDateMod = record["dateModification"] as? Date ?? .distantPast
            guard remoteDateMod > existant.dateModification else { return nil }

            // Mettre à jour les champs mutables
            existant.estActif = (record["estActif"] as? Int ?? 1) == 1
            existant.dateModification = remoteDateMod
            // SÉCURITÉ : plus aucun secret (hash/sel/iterations) en base publique.
            // L'auth passe par Sign in with Apple ; ces champs ne transitent plus.
            // Mapping SIWA : ne JAMAIS écraser ces champs sur une ligne DÉJÀ réclamée
            // (appleUserID non vide) — sinon un record public pourrait corrompre
            // l'identité/le code d'un membre déjà rattaché.
            if existant.appleUserID.isEmpty {
                if let appleID = record.chaineSecurisee("appleUserID") {
                    existant.appleUserID = appleID
                }
                if let invite = record.chaineSecurisee("codeInvitation"), !invite.isEmpty {
                    existant.codeInvitation = invite
                }
            }
            if let code = record.chaineSecurisee("codeEquipe"), !code.isEmpty {
                existant.codeEquipe = code
            }
            if let prenom = record.chaineSecurisee("prenom") {
                existant.prenom = prenom
            }
            if let nom = record.chaineSecurisee("nom") {
                existant.nom = nom
            }
            if let numero = record["numero"] as? Int {
                existant.numero = numero
            }
            if let posteRaw = record.chaineSecurisee("posteRaw") {
                existant.posteRaw = posteRaw
            }
            return (uuid, remoteDateMod)
        }

        // Créer le nouvel utilisateur de mapping d'équipe. SÉCURITÉ : aucun secret
        // n'est importé depuis la base publique — l'authentification est déléguée à
        // Sign in with Apple (motDePasseHash reste vide ; le rattachement se fait
        // via appleUserID lors du flux « Rejoindre une équipe »).
        let utilisateur = Utilisateur(
            identifiant: record.chaineSecurisee("identifiant") ?? "",
            motDePasseHash: "",
            prenom: record.chaineSecurisee("prenom") ?? "",
            nom: record.chaineSecurisee("nom") ?? "",
            role: RoleUtilisateur(rawValue: record.chaineSecurisee("roleRaw") ?? "Étudiant") ?? .etudiant,
            codeEcole: record.chaineSecurisee("codeEcole") ?? ""
        )
        // Forcer le même UUID que la source
        utilisateur.id = uuid
        utilisateur.estActif = (record["estActif"] as? Int ?? 1) == 1
        // Mapping SIWA / jointure d'équipe (jeton non secret).
        utilisateur.appleUserID = record.chaineSecurisee("appleUserID") ?? ""
        utilisateur.codeEquipe = record.chaineSecurisee("codeEquipe") ?? ""
        utilisateur.codeInvitation = record.chaineSecurisee("codeInvitation") ?? ""

        if let joueurIDStr = record.chaineSecurisee("joueurEquipeID") {
            utilisateur.joueurEquipeID = UUID(uuidString: joueurIDStr)
        }
        if let numero = record["numero"] as? Int {
            utilisateur.numero = numero
        }
        if let posteRaw = record.chaineSecurisee("posteRaw") {
            utilisateur.posteRaw = posteRaw
        }
        // E′ (revue : inflation de timestamp) — la branche CRÉATION adopte la
        // dateModification DISTANTE, comme la branche update (anti-écho).
        let remoteDateMod = record["dateModification"] as? Date ?? .distantPast
        utilisateur.dateModification = remoteDateMod

        context.insert(utilisateur)
        return (uuid, remoteDateMod)
    }

    @discardableResult
    func importerJoueur(from record: CKRecord, context: ModelContext) -> (UUID, Date)? {
        guard let idString = record.chaineSecurisee("joueurID"),
              let uuid = UUID(uuidString: idString) else { return nil }

        // Vérifier si ce joueur existe déjà
        let descripteur = FetchDescriptor<JoueurEquipe>(
            predicate: #Predicate { $0.id == uuid }
        )
        if let existant = try? context.fetch(descripteur).first {
            // Comparer dateModification — ne mettre à jour que si le remote est plus récent
            let remoteDateMod = record["dateModification"] as? Date ?? .distantPast
            guard remoteDateMod > existant.dateModification else { return nil }
            existant.nom = record.chaineSecurisee("nom") ?? existant.nom
            existant.prenom = record.chaineSecurisee("prenom") ?? existant.prenom
            existant.numero = record["numero"] as? Int ?? existant.numero
            existant.posteRaw = record.chaineSecurisee("posteRaw") ?? existant.posteRaw
            appliquerStats(record, sur: existant)
            appliquerDisponibilite(record, sur: existant)
            existant.dateModification = remoteDateMod
            return (uuid, remoteDateMod)
        }

        let joueur = JoueurEquipe(
            nom: record.chaineSecurisee("nom") ?? "",
            prenom: record.chaineSecurisee("prenom") ?? "",
            numero: record["numero"] as? Int ?? 0,
            poste: PosteJoueur(rawValue: record.chaineSecurisee("posteRaw") ?? "") ?? .recepteur
        )
        joueur.id = uuid
        joueur.codeEquipe = record.chaineSecurisee("codeEquipe") ?? ""
        joueur.identifiant = record.chaineSecurisee("identifiant") ?? ""

        if let utilisateurIDStr = record.chaineSecurisee("utilisateurID") {
            joueur.utilisateurID = UUID(uuidString: utilisateurIDStr)
        }
        appliquerStats(record, sur: joueur)
        appliquerDisponibilite(record, sur: joueur)
        // E′ — la branche création adopte la dateModification distante (anti-écho).
        let remoteDateMod = record["dateModification"] as? Date ?? .distantPast
        joueur.dateModification = remoteDateMod

        context.insert(joueur)
        return (uuid, remoteDateMod)
    }

    /// E′ §7 — PII minimale : seul un BOOLÉEN de disponibilité transite par la
    /// Public DB. Le motif (santé) et l'attestation parentale restent locaux au
    /// compte qui les a saisis. Indisponible distant → statut générique
    /// `.indisponible` (sans écraser un motif local plus riche) ; disponible
    /// distant → statut vidé.
    private func appliquerDisponibilite(_ record: CKRecord, sur joueur: JoueurEquipe) {
        guard let dispo = record["estDisponible"] as? Int else { return }
        if dispo == 1 {
            joueur.statutDisponibiliteRaw = ""
        } else if joueur.estDisponible {
            joueur.statutDisponibilite = .indisponible
        }
    }

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

    /// Importe une séance (merge `dateModification`).
    /// - Returns: (entiteID, dateModification appliquée) pour le filigrane, nil si ignoré.
    @discardableResult
    func importerSeance(from record: CKRecord, context: ModelContext) -> (UUID, Date)? {
        guard let idString = record.chaineSecurisee("seanceID"),
              let uuid = UUID(uuidString: idString) else { return nil }
        let remoteDateMod = record["dateModification"] as? Date ?? .distantPast
        let desc = FetchDescriptor<Seance>(predicate: #Predicate { $0.id == uuid })
        if let existant = try? context.fetch(desc).first {
            guard remoteDateMod > existant.dateModification else { return nil }
            existant.nom = record.chaineSecurisee("nom") ?? existant.nom
            existant.date = record["date"] as? Date ?? existant.date
            existant.typeSeanceRaw = record.chaineSecurisee("typeSeanceRaw") ?? existant.typeSeanceRaw
            existant.lieu = record.chaineSecurisee("lieu") ?? existant.lieu
            existant.adversaire = record.chaineSecurisee("adversaire") ?? existant.adversaire
            existant.scoreEquipe = record["scoreEquipe"] as? Int ?? existant.scoreEquipe
            existant.scoreAdversaire = record["scoreAdversaire"] as? Int ?? existant.scoreAdversaire
            existant.resultatRaw = record.chaineSecurisee("resultatRaw") ?? existant.resultatRaw
            existant.estArchivee = (record["estArchivee"] as? Int ?? 0) == 1
            existant.statsEntrees = (record["statsEntrees"] as? Int ?? (existant.statsEntrees ? 1 : 0)) == 1
            existant.dateModification = remoteDateMod
            return (uuid, remoteDateMod)
        }
        let seance = Seance(nom: record.chaineSecurisee("nom") ?? "",
                            date: record["date"] as? Date ?? Date(),
                            typeSeance: TypeSeance(rawValue: record.chaineSecurisee("typeSeanceRaw") ?? "") ?? .pratique)
        seance.id = uuid
        seance.codeEquipe = record.chaineSecurisee("codeEquipe") ?? ""
        seance.lieu = record.chaineSecurisee("lieu") ?? ""
        seance.adversaire = record.chaineSecurisee("adversaire") ?? ""
        seance.scoreEquipe = record["scoreEquipe"] as? Int ?? 0
        seance.scoreAdversaire = record["scoreAdversaire"] as? Int ?? 0
        seance.resultatRaw = record.chaineSecurisee("resultatRaw") ?? ""
        seance.estArchivee = (record["estArchivee"] as? Int ?? 0) == 1
        seance.statsEntrees = (record["statsEntrees"] as? Int ?? 0) == 1
        seance.dateModification = remoteDateMod
        context.insert(seance)
        return (uuid, remoteDateMod)
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

    /// Nombre max de pages suivies par curseur (25 × 200 = 5 000 records) —
    /// garde-fou contre une requête dégénérée, jamais atteint en usage normal.
    private static let maxPagesFetch = 25

    func fetchRecords(type: String, codeEquipe: String) async throws -> [CKRecord] {
        // Les deux champs (codeEquipe ET codeEcole) doivent être QUERYABLE dans le
        // schéma CloudKit public pour UtilisateurPartage (action humaine ASC).
        let predicate = Self.predicatRecherche(estUtilisateur: type == RecordType.utilisateur, codeEquipe: codeEquipe)
        return try await fetchRecords(type: type, predicate: predicate)
    }

    /// Variante à prédicat libre (E3 : requêtes par seanceID/publieLe).
    /// Interne au service (partagé entre extensions), paginé par curseur.
    func fetchRecords(type: String, predicate: NSPredicate,
                      tri: [NSSortDescriptor]? = nil) async throws -> [CKRecord] {
        let query = CKQuery(recordType: type, predicate: predicate)
        if let tri { query.sortDescriptors = tri }

        var allRecords: [CKRecord] = []
        var (results, curseur) = try await publicDB.records(matching: query, resultsLimit: 200)
        var pages = 1

        while true {
            for (_, result) in results {
                if case .success(let record) = result {
                    allRecords.append(record)
                }
            }
            guard let suite = curseur else { break }
            guard pages < Self.maxPagesFetch else {
                logger.warning("fetchRecords \(type): plafond de \(Self.maxPagesFetch) pages atteint — résultats tronqués")
                break
            }
            (results, curseur) = try await publicDB.records(continuingMatchFrom: suite, resultsLimit: 200)
            pages += 1
        }

        return allRecords
    }

}
