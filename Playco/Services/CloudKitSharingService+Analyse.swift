//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  CloudKitSharingService+Analyse — E3 (parité assistant D6) : publication et
//  import des données d'analyse — box scores (StatsMatch), points live
//  (PointMatch, publication par LOTS à la sortie du live et incrémentale par
//  horodatage au sweep — jamais de re-sweep complet), formations personnalisées.
//
//  D6 mode déconnecté : pendant un match live il n'y a qu'UN preneur de stats ;
//  les PointMatch se publient à la SORTIE du live (`publierAnalyseMatch`),
//  jamais pendant (le sweep saute stats/points quand le mode match est actif).

import Foundation
import CloudKit
import SwiftData
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "CloudKitSharing")

extension CloudKitSharingService {

    // MARK: - StatsMatch (box score)

    /// Champs PUBLICS d'un box score joueur. Fonction pure testable — compteurs
    /// de jeu uniquement, pas de PII au-delà des IDs de mapping.
    static func champsPublicsStatsMatch(_ stat: StatsMatch) -> [String: CKRecordValue] {
        [
            "statsID": stat.id.uuidString as CKRecordValue,
            "seanceID": stat.seanceID.uuidString as CKRecordValue,
            "joueurID": stat.joueurID.uuidString as CKRecordValue,
            "codeEquipe": stat.codeEquipe as CKRecordValue,
            "kills": stat.kills as CKRecordValue,
            "erreursAttaque": stat.erreursAttaque as CKRecordValue,
            "tentativesAttaque": stat.tentativesAttaque as CKRecordValue,
            "aces": stat.aces as CKRecordValue,
            "erreursService": stat.erreursService as CKRecordValue,
            "servicesTotaux": stat.servicesTotaux as CKRecordValue,
            "blocsSeuls": stat.blocsSeuls as CKRecordValue,
            "blocsAssistes": stat.blocsAssistes as CKRecordValue,
            "erreursBloc": stat.erreursBloc as CKRecordValue,
            "receptionsReussies": stat.receptionsReussies as CKRecordValue,
            "erreursReception": stat.erreursReception as CKRecordValue,
            "receptionsTotales": stat.receptionsTotales as CKRecordValue,
            "passesDecisives": stat.passesDecisives as CKRecordValue,
            "manchettes": stat.manchettes as CKRecordValue,
            "setsJoues": stat.setsJoues as CKRecordValue,
            "dateModification": stat.dateModification as CKRecordValue
        ]
    }

    func publierStatsMatch(_ stat: StatsMatch) async throws {
        #if DEMO
        return
        #else
        let recordID = CKRecord.ID(recordName: "stats-\(stat.id.uuidString)")
        let record = await recordPublicAJour(type: RecordType.statsMatch, recordID: recordID)
        for (cle, valeur) in Self.champsPublicsStatsMatch(stat) {
            record[cle] = valeur
        }
        _ = try await publicDB.save(record)
        #endif
    }

    /// Importe un box score joueur (merge `dateModification`).
    func importerStatsMatch(from record: CKRecord, context: ModelContext) {
        guard let idString = record.chaineSecurisee("statsID"),
              let uuid = UUID(uuidString: idString) else { return }
        let remoteDateMod = record["dateModification"] as? Date ?? .distantPast

        let desc = FetchDescriptor<StatsMatch>(predicate: #Predicate { $0.id == uuid })
        if let existant = try? context.fetch(desc).first {
            guard remoteDateMod > existant.dateModification else { return }
            appliquerCompteursStatsMatch(record, sur: existant)
            existant.dateModification = remoteDateMod
            return
        }

        guard let seanceIDStr = record.chaineSecurisee("seanceID"),
              let seanceID = UUID(uuidString: seanceIDStr),
              let joueurIDStr = record.chaineSecurisee("joueurID"),
              let joueurID = UUID(uuidString: joueurIDStr) else { return }
        let stat = StatsMatch(seanceID: seanceID, joueurID: joueurID)
        stat.id = uuid
        stat.codeEquipe = record.chaineSecurisee("codeEquipe") ?? ""
        appliquerCompteursStatsMatch(record, sur: stat)
        stat.dateModification = remoteDateMod
        context.insert(stat)
    }

    private func appliquerCompteursStatsMatch(_ record: CKRecord, sur stat: StatsMatch) {
        stat.kills = record["kills"] as? Int ?? stat.kills
        stat.erreursAttaque = record["erreursAttaque"] as? Int ?? stat.erreursAttaque
        stat.tentativesAttaque = record["tentativesAttaque"] as? Int ?? stat.tentativesAttaque
        stat.aces = record["aces"] as? Int ?? stat.aces
        stat.erreursService = record["erreursService"] as? Int ?? stat.erreursService
        stat.servicesTotaux = record["servicesTotaux"] as? Int ?? stat.servicesTotaux
        stat.blocsSeuls = record["blocsSeuls"] as? Int ?? stat.blocsSeuls
        stat.blocsAssistes = record["blocsAssistes"] as? Int ?? stat.blocsAssistes
        stat.erreursBloc = record["erreursBloc"] as? Int ?? stat.erreursBloc
        stat.receptionsReussies = record["receptionsReussies"] as? Int ?? stat.receptionsReussies
        stat.erreursReception = record["erreursReception"] as? Int ?? stat.erreursReception
        stat.receptionsTotales = record["receptionsTotales"] as? Int ?? stat.receptionsTotales
        stat.passesDecisives = record["passesDecisives"] as? Int ?? stat.passesDecisives
        stat.manchettes = record["manchettes"] as? Int ?? stat.manchettes
        stat.setsJoues = record["setsJoues"] as? Int ?? stat.setsJoues
    }

    // MARK: - PointMatch (points live, immuables)

    /// Champs PUBLICS d'un point live. Fonction pure testable.
    static func champsPublicsPointMatch(_ point: PointMatch) -> [String: CKRecordValue] {
        var champs: [String: CKRecordValue] = [
            "pointID": point.id.uuidString as CKRecordValue,
            "seanceID": point.seanceID.uuidString as CKRecordValue,
            "codeEquipe": point.codeEquipe as CKRecordValue,
            "set": point.set as CKRecordValue,
            "scoreEquipeAuMoment": point.scoreEquipeAuMoment as CKRecordValue,
            "scoreAdversaireAuMoment": point.scoreAdversaireAuMoment as CKRecordValue,
            "typeActionRaw": point.typeActionRaw as CKRecordValue,
            "rotationAuMoment": point.rotationAuMoment as CKRecordValue,
            "rotationAdvAuMoment": point.rotationAdvAuMoment as CKRecordValue,
            "zone": point.zone as CKRecordValue,
            "zoneDepart": point.zoneDepart as CKRecordValue,
            "nousServionsAuMoment": (point.nousServionsAuMoment ? 1 : 0) as CKRecordValue,
            "serviceRenseigne": (point.serviceRenseigne ? 1 : 0) as CKRecordValue,
            "horodatage": point.horodatage as CKRecordValue
        ]
        if let joueurID = point.joueurID {
            champs["joueurID"] = joueurID.uuidString as CKRecordValue
        }
        return champs
    }

    /// Découpe un tableau en lots (CKModifyRecordsOperation plafonne à 400).
    static func lots<T>(_ elements: [T], taille: Int) -> [[T]] {
        guard taille > 0, !elements.isEmpty else { return elements.isEmpty ? [] : [elements] }
        return stride(from: 0, to: elements.count, by: taille).map {
            Array(elements[$0..<min($0 + taille, elements.count)])
        }
    }

    /// Taille max d'un lot CloudKit (limite serveur CKModifyRecordsOperation).
    static let tailleLotCloudKit = 400

    /// Publie des points live par LOTS (`modifyRecords`, savePolicy `.allKeys` :
    /// les points sont immuables — pas de fetch-puis-modifier, l'écrasement d'un
    /// record identique est un no-op). `supprimerFantomes` (sortie de live) :
    /// supprime aussi les records publiés qui n'existent plus localement pour
    /// cette séance (points annulés après une publication précédente).
    func publierPointsMatch(_ points: [PointMatch], seanceID: UUID?, supprimerFantomes: Bool) async throws {
        #if DEMO
        return
        #else
        var aSupprimer: [CKRecord.ID] = []
        if supprimerFantomes, let seanceID {
            // "seanceID" doit être QUERYABLE sur PointMatchPartage (action ASC).
            let predicate = NSPredicate(format: "seanceID == %@", seanceID.uuidString)
            let remoteRecords = try await fetchRecords(type: RecordType.pointMatch, predicate: predicate)
            let idsLocaux = Set(points.map { "point-\($0.id.uuidString)" })
            aSupprimer = remoteRecords.map(\.recordID).filter { !idsLocaux.contains($0.recordName) }
        }

        let records = points.map { point -> CKRecord in
            let record = CKRecord(recordType: RecordType.pointMatch,
                                  recordID: CKRecord.ID(recordName: "point-\(point.id.uuidString)"))
            for (cle, valeur) in Self.champsPublicsPointMatch(point) {
                record[cle] = valeur
            }
            return record
        }

        for lot in Self.lots(records, taille: Self.tailleLotCloudKit) {
            let (resultats, _) = try await publicDB.modifyRecords(
                saving: lot, deleting: [], savePolicy: .allKeys, atomically: false)
            // Un échec partiel doit faire échouer le sweep (le seuil n'avance
            // pas → les points seront représentés au prochain cycle).
            for (_, resultat) in resultats {
                if case .failure(let erreur) = resultat { throw erreur }
            }
        }
        for lot in Self.lots(aSupprimer, taille: Self.tailleLotCloudKit) {
            _ = try await publicDB.modifyRecords(saving: [], deleting: lot,
                                                 savePolicy: .allKeys, atomically: false)
        }
        #endif
    }

    /// Importe un point live (immuable : créé s'il est inconnu, jamais modifié).
    /// `idsExistants` évite un fetch par record sur les gros volumes.
    func importerPointMatch(from record: CKRecord, idsExistants: inout Set<UUID>, context: ModelContext) {
        guard let idString = record.chaineSecurisee("pointID"),
              let uuid = UUID(uuidString: idString),
              !idsExistants.contains(uuid) else { return }
        guard let seanceIDStr = record.chaineSecurisee("seanceID"),
              let seanceID = UUID(uuidString: seanceIDStr) else { return }
        // Données publiques non fiables : un type d'action hors enum est rejeté
        // (ne JAMAIS fabriquer un point par fallback).
        guard let raw = record.chaineSecurisee("typeActionRaw"),
              let typeAction = TypeActionPoint(rawValue: raw) else { return }

        let point = PointMatch(seanceID: seanceID,
                               set: record["set"] as? Int ?? 1,
                               joueurID: (record.chaineSecurisee("joueurID")).flatMap(UUID.init(uuidString:)),
                               typeAction: typeAction)
        point.id = uuid
        point.codeEquipe = record.chaineSecurisee("codeEquipe") ?? ""
        point.scoreEquipeAuMoment = record["scoreEquipeAuMoment"] as? Int ?? 0
        point.scoreAdversaireAuMoment = record["scoreAdversaireAuMoment"] as? Int ?? 0
        point.rotationAuMoment = record["rotationAuMoment"] as? Int ?? 1
        point.rotationAdvAuMoment = record["rotationAdvAuMoment"] as? Int ?? 1
        point.zone = record["zone"] as? Int ?? 0
        point.zoneDepart = record["zoneDepart"] as? Int ?? 0
        point.nousServionsAuMoment = (record["nousServionsAuMoment"] as? Int ?? 0) == 1
        point.serviceRenseigne = (record["serviceRenseigne"] as? Int ?? 0) == 1
        point.horodatage = record["horodatage"] as? Date ?? .distantPast
        context.insert(point)
        idsExistants.insert(uuid)
    }

    // MARK: - Formations personnalisées

    /// Champs PUBLICS d'une formation personnalisée. Fonction pure testable.
    static func champsPublicsFormation(_ formation: FormationPersonnalisee) -> [String: CKRecordValue] {
        [
            "formationID": formation.id.uuidString as CKRecordValue,
            "codeEquipe": formation.codeEquipe as CKRecordValue,
            "formationTypeRaw": formation.formationTypeRaw as CKRecordValue,
            "rotation": formation.rotation as CKRecordValue,
            "modeRaw": formation.modeRaw as CKRecordValue,
            "dateModification": formation.dateModification as CKRecordValue
        ]
    }

    func publierFormation(_ formation: FormationPersonnalisee) async throws {
        #if DEMO
        return
        #else
        let recordID = CKRecord.ID(recordName: "formation-\(formation.id.uuidString)")
        let record = await recordPublicAJour(type: RecordType.formation, recordID: recordID)
        for (cle, valeur) in Self.champsPublicsFormation(formation) {
            record[cle] = valeur
        }
        record["positionsJSON"] = formation.positionsJSON.map { $0 as CKRecordValue }
        _ = try await publicDB.save(record)
        #endif
    }

    /// Importe une formation personnalisée. Merge par id, sinon par CLÉ
    /// fonctionnelle (codeEquipe, type, rotation, mode) — deux coachs qui
    /// personnalisent la même rotation ne doivent pas créer de doublon
    /// (une seule formation par clé, dernier écrivain gagne).
    func importerFormation(from record: CKRecord, context: ModelContext) {
        guard let idString = record.chaineSecurisee("formationID"),
              let uuid = UUID(uuidString: idString) else { return }
        let remoteDateMod = record["dateModification"] as? Date ?? .distantPast

        let descParID = FetchDescriptor<FormationPersonnalisee>(predicate: #Predicate { $0.id == uuid })
        if let existante = try? context.fetch(descParID).first {
            guard remoteDateMod > existante.dateModification else { return }
            appliquerChampsFormation(record, sur: existante)
            existante.dateModification = remoteDateMod
            return
        }

        guard let typeRaw = record.chaineSecurisee("formationTypeRaw"),
              let type = FormationType(rawValue: typeRaw),
              let modeRaw = record.chaineSecurisee("modeRaw"),
              let mode = FormationMode(rawValue: modeRaw) else { return }
        let rotation = record["rotation"] as? Int ?? 0
        let codeEquipe = record.chaineSecurisee("codeEquipe") ?? ""

        // Dédup par clé fonctionnelle (id local différent → on merge dedans).
        let descParCle = FetchDescriptor<FormationPersonnalisee>(predicate: #Predicate {
            $0.codeEquipe == codeEquipe && $0.formationTypeRaw == typeRaw
                && $0.rotation == rotation && $0.modeRaw == modeRaw
        })
        if let memeCle = try? context.fetch(descParCle).first {
            guard remoteDateMod > memeCle.dateModification else { return }
            appliquerChampsFormation(record, sur: memeCle)
            memeCle.dateModification = remoteDateMod
            return
        }

        let formation = FormationPersonnalisee(formationType: type, rotation: rotation, mode: mode)
        formation.id = uuid
        formation.codeEquipe = codeEquipe
        appliquerChampsFormation(record, sur: formation)
        formation.dateModification = remoteDateMod
        context.insert(formation)
    }

    private func appliquerChampsFormation(_ record: CKRecord, sur formation: FormationPersonnalisee) {
        if let data = record["positionsJSON"] as? Data, data.count <= Self.tailleMaxChampBinaire {
            formation.positionsJSON = data
        }
    }

    // MARK: - Orchestration

    /// Publie l'analyse d'un match à la SORTIE du live (D6 : un seul preneur de
    /// stats pendant le match, sync à la sortie) : séance, box scores et points
    /// (avec purge des fantômes — points annulés après une publication).
    func publierAnalyseMatch(seance: Seance, context: ModelContext) async {
        #if DEMO
        return
        #else
        estEnCoursDePublication = true
        defer { estEnCoursDePublication = false }
        do {
            try await publierSeance(seance)
            let seanceID = seance.id
            let descStats = FetchDescriptor<StatsMatch>(predicate: #Predicate { $0.seanceID == seanceID })
            for stat in (try? context.fetch(descStats)) ?? [] {
                try await publierStatsMatch(stat)
            }
            let descPoints = FetchDescriptor<PointMatch>(predicate: #Predicate { $0.seanceID == seanceID })
            let points = (try? context.fetch(descPoints)) ?? []
            try await publierPointsMatch(points, seanceID: seanceID, supprimerFantomes: true)
            logger.info("Analyse du match publiée (\(points.count) points)")
        } catch {
            logger.error("publierAnalyseMatch: \(error.localizedDescription)")
            self.erreur = error.localizedDescription
        }
        #endif
    }

    /// Importe les données d'analyse d'une équipe. Les points sont récupérés
    /// INCRÉMENTALEMENT (horodatage > max local) — jamais de re-sweep complet.
    func importerAnalyse(codeEquipe: String, context: ModelContext) async throws {
        let statsRecords = try await fetchRecords(type: RecordType.statsMatch, codeEquipe: codeEquipe)
        for record in statsRecords { importerStatsMatch(from: record, context: context) }

        let formationRecords = try await fetchRecords(type: RecordType.formation, codeEquipe: codeEquipe)
        for record in formationRecords { importerFormation(from: record, context: context) }

        // Points : borne incrémentale = horodatage le plus récent déjà local.
        // "horodatage" doit être QUERYABLE/SORTABLE sur PointMatchPartage (ASC).
        var descDernier = FetchDescriptor<PointMatch>(
            predicate: #Predicate { $0.codeEquipe == codeEquipe },
            sortBy: [SortDescriptor(\.horodatage, order: .reverse)])
        descDernier.fetchLimit = 1
        let borne = (try? context.fetch(descDernier))?.first?.horodatage ?? .distantPast
        let predicate = NSPredicate(format: "codeEquipe == %@ AND horodatage > %@",
                                    codeEquipe, borne as NSDate)
        let pointRecords = try await fetchRecords(type: RecordType.pointMatch, predicate: predicate)

        let descIDs = FetchDescriptor<PointMatch>(predicate: #Predicate { $0.codeEquipe == codeEquipe })
        var idsExistants = Set(((try? context.fetch(descIDs)) ?? []).map(\.id))
        for record in pointRecords {
            importerPointMatch(from: record, idsExistants: &idsExistants, context: context)
        }
    }
}
