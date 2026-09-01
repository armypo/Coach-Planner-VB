//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  CloudKitSharingService+Preparation — E2 (parité assistant D6) : publication
//  et import des contenus de préparation via la Public DB — exercices de séance
//  (dessins inclus), stratégies collectives, rapports de scouting, bibliothèque
//  d'exercices des coachs de l'équipe.
//
//  Volumes : les dessins PencilKit (dessinData/etapesData) peuvent être lourds.
//  Un champ binaire > seuilAssetOctets part en CKAsset (limite CKRecord ~1 Mo),
//  sinon en bytes inline. L'import accepte les deux représentations.

import Foundation
import CloudKit
import SwiftData
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "CloudKitSharing")

extension CloudKitSharingService {

    // MARK: - Champs binaires (Data inline ou CKAsset)

    /// Au-delà de ce volume, un champ Data part en CKAsset.
    static let seuilAssetOctets = 500_000

    /// Taille max acceptée à l'import d'un champ binaire public (données
    /// externes non fiables — protège la mémoire contre un asset dégénéré).
    static let tailleMaxChampBinaire = 15_000_000

    /// Applique un champ binaire sur un record : bytes inline si léger,
    /// CKAsset (fichier temporaire) au-delà du seuil, nil si absent/vide.
    /// - Returns: l'URL temporaire à nettoyer APRÈS le save (cas CKAsset).
    static func appliquerChampBinaire(_ record: CKRecord, cle: String, data: Data?) -> URL? {
        guard let data, !data.isEmpty else {
            record[cle] = nil
            return nil
        }
        if data.count <= seuilAssetOctets {
            record[cle] = data as CKRecordValue
            return nil
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ck-asset-\(UUID().uuidString).bin")
        do {
            try data.write(to: url)
            record[cle] = CKAsset(fileURL: url)
            return url
        } catch {
            // Repli inline plutôt que perdre le champ en silence (le save
            // échouera au pire en taille de record — erreur remontée, retry).
            logger.warning("appliquerChampBinaire \(cle): écriture asset échouée, repli inline: \(error.localizedDescription)")
            record[cle] = data as CKRecordValue
            return nil
        }
    }

    /// Lit un champ binaire publié soit inline (Data) soit en CKAsset,
    /// plafonné à `tailleMaxChampBinaire`.
    static func lireChampBinaire(_ record: CKRecord, cle: String) -> Data? {
        if let data = record[cle] as? Data {
            return data.count <= tailleMaxChampBinaire ? data : nil
        }
        guard let asset = record[cle] as? CKAsset, let url = asset.fileURL else { return nil }
        let attributs = try? FileManager.default.attributesOfItem(atPath: url.path)
        if let taille = attributs?[.size] as? Int, taille > tailleMaxChampBinaire {
            logger.warning("lireChampBinaire \(cle): asset de \(taille) octets refusé (plafond)")
            return nil
        }
        return try? Data(contentsOf: url)
    }

    /// Sauvegarde un record après application des champs binaires, puis nettoie
    /// les fichiers temporaires CKAsset. DRY entre les 4 publierX de préparation.
    private func sauvegarderAvecBinaires(record: CKRecord,
                                         champs: [String: CKRecordValue],
                                         binaires: [String: Data?]) async throws {
        for (cle, valeur) in champs {
            record[cle] = valeur
        }
        var temporaires: [URL] = []
        for (cle, data) in binaires {
            if let url = Self.appliquerChampBinaire(record, cle: cle, data: data) {
                temporaires.append(url)
            }
        }
        defer {
            for url in temporaires { try? FileManager.default.removeItem(at: url) }
        }
        _ = try await publicDB.save(record)
    }

    // MARK: - Exercices de séance

    /// Champs PUBLICS (scalaires) d'un exercice de séance. Fonction pure testable.
    static func champsPublicsExercice(_ exercice: Exercice, seanceID: UUID, codeEquipe: String) -> [String: CKRecordValue] {
        [
            "exerciceID": exercice.id.uuidString as CKRecordValue,
            "seanceID": seanceID.uuidString as CKRecordValue,
            "codeEquipe": codeEquipe as CKRecordValue,
            "nom": exercice.nom as CKRecordValue,
            "notes": exercice.notes as CKRecordValue,
            "ordre": exercice.ordre as CKRecordValue,
            "duree": exercice.duree as CKRecordValue,
            "typeTerrain": exercice.typeTerrain as CKRecordValue,
            "estArchive": (exercice.estArchive ? 1 : 0) as CKRecordValue,
            "dateModification": exercice.dateModification as CKRecordValue
        ]
    }

    func publierExercice(_ exercice: Exercice, seanceID: UUID, codeEquipe: String) async throws {
        #if DEMO
        return
        #else
        let recordID = CKRecord.ID(recordName: "exercice-\(exercice.id.uuidString)")
        let record = await recordPublicAJour(type: RecordType.exercice, recordID: recordID)
        try await sauvegarderAvecBinaires(
            record: record,
            champs: Self.champsPublicsExercice(exercice, seanceID: seanceID, codeEquipe: codeEquipe),
            binaires: ["dessinData": exercice.dessinData,
                       "elementsData": exercice.elementsData,
                       "etapesData": exercice.etapesData])
        #endif
    }

    /// Importe un exercice (merge `dateModification`). La séance parente doit
    /// déjà exister localement (les séances sont importées AVANT — sinon
    /// l'exercice est repris au prochain cycle de sync).
    func importerExercice(from record: CKRecord, context: ModelContext) {
        guard let idString = record.chaineSecurisee("exerciceID"),
              let uuid = UUID(uuidString: idString) else { return }
        let remoteDateMod = record["dateModification"] as? Date ?? .distantPast

        let desc = FetchDescriptor<Exercice>(predicate: #Predicate { $0.id == uuid })
        if let existant = try? context.fetch(desc).first {
            guard remoteDateMod > existant.dateModification else { return }
            appliquerChampsExercice(record, sur: existant)
            existant.dateModification = remoteDateMod
            return
        }

        guard let seanceIDStr = record.chaineSecurisee("seanceID"),
              let seanceUUID = UUID(uuidString: seanceIDStr) else { return }
        let descSeance = FetchDescriptor<Seance>(predicate: #Predicate { $0.id == seanceUUID })
        guard let seance = try? context.fetch(descSeance).first else { return }

        let exercice = Exercice(nom: record.chaineSecurisee("nom") ?? "")
        exercice.id = uuid
        appliquerChampsExercice(record, sur: exercice)
        exercice.dateModification = remoteDateMod
        context.insert(exercice)
        // Piège #16 : Seance.exercices est optionnel (CloudKit).
        if seance.exercices == nil { seance.exercices = [] }
        seance.exercices?.append(exercice)
    }

    private func appliquerChampsExercice(_ record: CKRecord, sur exercice: Exercice) {
        exercice.nom = record.chaineSecurisee("nom") ?? exercice.nom
        exercice.notes = record.chaineSecurisee("notes") ?? exercice.notes
        exercice.ordre = record["ordre"] as? Int ?? exercice.ordre
        exercice.duree = record["duree"] as? Int ?? exercice.duree
        exercice.typeTerrain = record.chaineSecurisee("typeTerrain") ?? exercice.typeTerrain
        exercice.estArchive = (record["estArchive"] as? Int ?? (exercice.estArchive ? 1 : 0)) == 1
        exercice.dessinData = Self.lireChampBinaire(record, cle: "dessinData")
        exercice.elementsData = Self.lireChampBinaire(record, cle: "elementsData")
        // Piège #5 : etapesData TOUJOURS propagé.
        exercice.etapesData = Self.lireChampBinaire(record, cle: "etapesData")
    }

    // MARK: - Stratégies collectives

    /// Champs PUBLICS (scalaires) d'une stratégie. Fonction pure testable.
    static func champsPublicsStrategie(_ strategie: StrategieCollective) -> [String: CKRecordValue] {
        [
            "strategieID": strategie.id.uuidString as CKRecordValue,
            "codeEquipe": strategie.codeEquipe as CKRecordValue,
            "nom": strategie.nom as CKRecordValue,
            "categorieRaw": strategie.categorieRaw as CKRecordValue,
            "descriptionStrategie": strategie.descriptionStrategie as CKRecordValue,
            "notes": strategie.notes as CKRecordValue,
            "typeTerrain": strategie.typeTerrain as CKRecordValue,
            "estArchivee": (strategie.estArchivee ? 1 : 0) as CKRecordValue,
            "dateModification": strategie.dateModification as CKRecordValue
        ]
    }

    func publierStrategie(_ strategie: StrategieCollective) async throws {
        #if DEMO
        return
        #else
        let recordID = CKRecord.ID(recordName: "strategie-\(strategie.id.uuidString)")
        let record = await recordPublicAJour(type: RecordType.strategie, recordID: recordID)
        try await sauvegarderAvecBinaires(
            record: record,
            champs: Self.champsPublicsStrategie(strategie),
            binaires: ["dessinData": strategie.dessinData,
                       "elementsData": strategie.elementsData,
                       "etapesData": strategie.etapesData])
        #endif
    }

    /// Importe une stratégie collective (merge `dateModification`).
    func importerStrategie(from record: CKRecord, context: ModelContext) {
        guard let idString = record.chaineSecurisee("strategieID"),
              let uuid = UUID(uuidString: idString) else { return }
        let remoteDateMod = record["dateModification"] as? Date ?? .distantPast

        let desc = FetchDescriptor<StrategieCollective>(predicate: #Predicate { $0.id == uuid })
        if let existante = try? context.fetch(desc).first {
            guard remoteDateMod > existante.dateModification else { return }
            appliquerChampsStrategie(record, sur: existante)
            existante.dateModification = remoteDateMod
            return
        }

        let strategie = StrategieCollective(
            nom: record.chaineSecurisee("nom") ?? "",
            categorie: CategorieStrategie(rawValue: record.chaineSecurisee("categorieRaw") ?? "") ?? .attaque
        )
        strategie.id = uuid
        strategie.codeEquipe = record.chaineSecurisee("codeEquipe") ?? ""
        appliquerChampsStrategie(record, sur: strategie)
        strategie.dateModification = remoteDateMod
        context.insert(strategie)
    }

    private func appliquerChampsStrategie(_ record: CKRecord, sur strategie: StrategieCollective) {
        strategie.nom = record.chaineSecurisee("nom") ?? strategie.nom
        strategie.categorieRaw = record.chaineSecurisee("categorieRaw") ?? strategie.categorieRaw
        strategie.descriptionStrategie = record.chaineSecurisee("descriptionStrategie") ?? strategie.descriptionStrategie
        strategie.notes = record.chaineSecurisee("notes") ?? strategie.notes
        strategie.typeTerrain = record.chaineSecurisee("typeTerrain") ?? strategie.typeTerrain
        strategie.estArchivee = (record["estArchivee"] as? Int ?? (strategie.estArchivee ? 1 : 0)) == 1
        strategie.dessinData = Self.lireChampBinaire(record, cle: "dessinData")
        strategie.elementsData = Self.lireChampBinaire(record, cle: "elementsData")
        strategie.etapesData = Self.lireChampBinaire(record, cle: "etapesData")
    }

    // MARK: - Rapports de scouting

    /// Champs PUBLICS (scalaires) d'un rapport de scouting. Fonction pure testable.
    /// ARBITRAGE E2 (conservateur, cf. journal) : `joueursData` (évaluations
    /// nominatives de joueurs ADVERSES) n'est JAMAIS publié en Public DB
    /// world-readable — seul le contenu tactique d'équipe est partagé.
    static func champsPublicsScouting(_ rapport: ScoutingReport) -> [String: CKRecordValue] {
        var champs: [String: CKRecordValue] = [
            "scoutingID": rapport.id.uuidString as CKRecordValue,
            "codeEquipe": rapport.codeEquipe as CKRecordValue,
            "adversaire": rapport.adversaire as CKRecordValue,
            "dateMatch": rapport.dateMatch as CKRecordValue,
            "systemJeu": rapport.systemJeu as CKRecordValue,
            "styleJeu": rapport.styleJeu as CKRecordValue,
            "notes": rapport.notes as CKRecordValue,
            "adversaireObserve": rapport.adversaireObserve as CKRecordValue,
            "tendanceService": rapport.tendanceService as CKRecordValue,
            "tendanceAttaque": rapport.tendanceAttaque as CKRecordValue,
            "tendanceReception": rapport.tendanceReception as CKRecordValue,
            "tendanceBloc": rapport.tendanceBloc as CKRecordValue,
            "estArchive": (rapport.estArchive ? 1 : 0) as CKRecordValue,
            "dateModification": rapport.dateModification as CKRecordValue
        ]
        if let seanceID = rapport.seanceID {
            champs["seanceID"] = seanceID.uuidString as CKRecordValue
        }
        return champs
    }

    func publierScouting(_ rapport: ScoutingReport) async throws {
        #if DEMO
        return
        #else
        let recordID = CKRecord.ID(recordName: "scouting-\(rapport.id.uuidString)")
        let record = await recordPublicAJour(type: RecordType.scouting, recordID: recordID)
        try await sauvegarderAvecBinaires(
            record: record,
            champs: Self.champsPublicsScouting(rapport),
            binaires: ["forcesData": rapport.forcesData,
                       "faiblessesData": rapport.faiblessesData,
                       "strategiesData": rapport.strategiesData,
                       "tendancesZonalesData": rapport.tendancesZonalesData])
        #endif
    }

    /// Importe un rapport de scouting (merge `dateModification`).
    /// `joueursData` n'est jamais importé (jamais publié — cf. arbitrage E2) :
    /// la liste locale des joueurs adverses reste intacte.
    func importerScouting(from record: CKRecord, context: ModelContext) {
        guard let idString = record.chaineSecurisee("scoutingID"),
              let uuid = UUID(uuidString: idString) else { return }
        let remoteDateMod = record["dateModification"] as? Date ?? .distantPast

        let desc = FetchDescriptor<ScoutingReport>(predicate: #Predicate { $0.id == uuid })
        if let existant = try? context.fetch(desc).first {
            guard remoteDateMod > existant.dateModification else { return }
            appliquerChampsScouting(record, sur: existant)
            existant.dateModification = remoteDateMod
            return
        }

        let rapport = ScoutingReport()
        rapport.id = uuid
        rapport.codeEquipe = record.chaineSecurisee("codeEquipe") ?? ""
        appliquerChampsScouting(record, sur: rapport)
        rapport.dateModification = remoteDateMod
        context.insert(rapport)
    }

    private func appliquerChampsScouting(_ record: CKRecord, sur rapport: ScoutingReport) {
        rapport.adversaire = record.chaineSecurisee("adversaire") ?? rapport.adversaire
        rapport.dateMatch = record["dateMatch"] as? Date ?? rapport.dateMatch
        rapport.systemJeu = record.chaineSecurisee("systemJeu") ?? rapport.systemJeu
        rapport.styleJeu = record.chaineSecurisee("styleJeu") ?? rapport.styleJeu
        rapport.notes = record.chaineSecurisee("notes") ?? rapport.notes
        rapport.adversaireObserve = record.chaineSecurisee("adversaireObserve") ?? rapport.adversaireObserve
        rapport.tendanceService = record.chaineSecurisee("tendanceService") ?? rapport.tendanceService
        rapport.tendanceAttaque = record.chaineSecurisee("tendanceAttaque") ?? rapport.tendanceAttaque
        rapport.tendanceReception = record.chaineSecurisee("tendanceReception") ?? rapport.tendanceReception
        rapport.tendanceBloc = record.chaineSecurisee("tendanceBloc") ?? rapport.tendanceBloc
        rapport.estArchive = (record["estArchive"] as? Int ?? (rapport.estArchive ? 1 : 0)) == 1
        if let seanceIDStr = record.chaineSecurisee("seanceID") {
            rapport.seanceID = UUID(uuidString: seanceIDStr)
        }
        if let forces = Self.lireChampBinaire(record, cle: "forcesData") {
            rapport.forcesData = forces
        }
        if let faiblesses = Self.lireChampBinaire(record, cle: "faiblessesData") {
            rapport.faiblessesData = faiblesses
        }
        if let strategies = Self.lireChampBinaire(record, cle: "strategiesData") {
            rapport.strategiesData = strategies
        }
        if let zones = Self.lireChampBinaire(record, cle: "tendancesZonalesData") {
            rapport.tendancesZonalesData = zones
        }
    }

    // MARK: - Bibliothèque d'exercices des coachs

    /// Champs PUBLICS (scalaires) d'un exercice de bibliothèque. Fonction pure
    /// testable. `estFavori` (préférence personnelle) n'est pas synchronisé ;
    /// `codeEquipe` est la clé de requête (un record par couple item×équipe).
    static func champsPublicsBibliotheque(_ exercice: ExerciceBibliotheque, codeEquipe: String) -> [String: CKRecordValue] {
        [
            "exerciceID": exercice.id.uuidString as CKRecordValue,
            "codeEquipe": codeEquipe as CKRecordValue,
            "codeCoach": exercice.codeCoach as CKRecordValue,
            "nom": exercice.nom as CKRecordValue,
            "categorie": exercice.categorie as CKRecordValue,
            "descriptionExo": exercice.descriptionExo as CKRecordValue,
            "notes": exercice.notes as CKRecordValue,
            "notesCoach": exercice.notesCoach as CKRecordValue,
            "duree": exercice.duree as CKRecordValue,
            "typeTerrain": exercice.typeTerrain as CKRecordValue,
            "dateModification": exercice.dateModification as CKRecordValue
        ]
    }

    func publierBibliotheque(_ exercice: ExerciceBibliotheque, codeEquipe: String) async throws {
        #if DEMO
        return
        #else
        // Un record par couple item×équipe : un coach multi-équipes publie le
        // même item sous chaque code (sinon le champ codeEquipe « flotterait »
        // d'un sweep à l'autre et l'item disparaîtrait des requêtes assistants).
        let recordID = CKRecord.ID(recordName: "biblio-\(exercice.id.uuidString)-\(codeEquipe)")
        let record = await recordPublicAJour(type: RecordType.bibliotheque, recordID: recordID)
        try await sauvegarderAvecBinaires(
            record: record,
            champs: Self.champsPublicsBibliotheque(exercice, codeEquipe: codeEquipe),
            binaires: ["dessinData": exercice.dessinData,
                       "elementsData": exercice.elementsData,
                       "etapesData": exercice.etapesData])
        #endif
    }

    /// Importe un exercice de bibliothèque (merge `dateModification`, dédup par
    /// `exerciceID` — un même item peut être publié sous plusieurs équipes).
    func importerBibliotheque(from record: CKRecord, context: ModelContext) {
        guard let idString = record.chaineSecurisee("exerciceID"),
              let uuid = UUID(uuidString: idString) else { return }
        let remoteDateMod = record["dateModification"] as? Date ?? .distantPast

        let desc = FetchDescriptor<ExerciceBibliotheque>(predicate: #Predicate { $0.id == uuid })
        if let existant = try? context.fetch(desc).first {
            guard remoteDateMod > existant.dateModification else { return }
            appliquerChampsBibliotheque(record, sur: existant)
            existant.dateModification = remoteDateMod
            return
        }

        let exercice = ExerciceBibliotheque(
            nom: record.chaineSecurisee("nom") ?? "",
            categorie: record.chaineSecurisee("categorie") ?? ""
        )
        exercice.id = uuid
        exercice.estPredefini = false
        exercice.codeCoach = record.chaineSecurisee("codeCoach") ?? ""
        appliquerChampsBibliotheque(record, sur: exercice)
        exercice.dateModification = remoteDateMod
        context.insert(exercice)
    }

    private func appliquerChampsBibliotheque(_ record: CKRecord, sur exercice: ExerciceBibliotheque) {
        exercice.nom = record.chaineSecurisee("nom") ?? exercice.nom
        exercice.categorie = record.chaineSecurisee("categorie") ?? exercice.categorie
        exercice.descriptionExo = record.chaineSecurisee("descriptionExo") ?? exercice.descriptionExo
        exercice.notes = record.chaineSecurisee("notes") ?? exercice.notes
        exercice.notesCoach = record.chaineSecurisee("notesCoach") ?? exercice.notesCoach
        exercice.duree = record["duree"] as? Int ?? exercice.duree
        exercice.typeTerrain = record.chaineSecurisee("typeTerrain") ?? exercice.typeTerrain
        exercice.dessinData = Self.lireChampBinaire(record, cle: "dessinData")
        exercice.elementsData = Self.lireChampBinaire(record, cle: "elementsData")
        exercice.etapesData = Self.lireChampBinaire(record, cle: "etapesData")
    }
}
