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
        guard let ecrivain = ecrivainID, !ecrivain.isEmpty else { throw ErreurEcrivain.ecrivainAbsent }
        let recordID = CKRecord.ID(recordName: Self.nomRecord("stats", id: stat.id.uuidString, ecrivain: ecrivain))
        let record = await recordPublicAJour(type: RecordType.statsMatch, recordID: recordID)
        for (cle, valeur) in Self.champsPublicsStatsMatch(stat) {
            record[cle] = valeur
        }
        _ = try appliquerIdentiteEcrivain(record)
        _ = try await publicDB.save(record)
        #endif
    }

    /// Importe un box score joueur (merge `dateModification`). Dédup par id
    /// PUIS par clé fonctionnelle (seanceID+joueurID) — deux finalisations
    /// concurrentes du même match ne créent pas de doublon (E′).
    /// - Returns: (entiteID, dateModification appliquée) pour le filigrane, nil si ignoré.
    @discardableResult
    func importerStatsMatch(from record: CKRecord, context: ModelContext) -> (UUID, Date)? {
        guard let idString = record.chaineSecurisee("statsID"),
              let uuid = UUID(uuidString: idString) else { return nil }
        let remoteDateMod = record["dateModification"] as? Date ?? .distantPast

        let desc = FetchDescriptor<StatsMatch>(predicate: #Predicate { $0.id == uuid })
        if let existant = try? context.fetch(desc).first {
            guard remoteDateMod > existant.dateModification else { return nil }
            appliquerCompteursStatsMatch(record, sur: existant)
            existant.dateModification = remoteDateMod
            return (uuid, remoteDateMod)
        }

        guard let seanceIDStr = record.chaineSecurisee("seanceID"),
              let seanceID = UUID(uuidString: seanceIDStr),
              let joueurIDStr = record.chaineSecurisee("joueurID"),
              let joueurID = UUID(uuidString: joueurIDStr) else { return nil }

        // Clé fonctionnelle : un seul box score par (match, joueur).
        let descCle = FetchDescriptor<StatsMatch>(predicate: #Predicate {
            $0.seanceID == seanceID && $0.joueurID == joueurID
        })
        if let memeCle = try? context.fetch(descCle).first {
            guard remoteDateMod > memeCle.dateModification else { return nil }
            appliquerCompteursStatsMatch(record, sur: memeCle)
            memeCle.dateModification = remoteDateMod
            return (memeCle.id, remoteDateMod)
        }

        let stat = StatsMatch(seanceID: seanceID, joueurID: joueurID)
        stat.id = uuid
        stat.codeEquipe = record.chaineSecurisee("codeEquipe") ?? ""
        appliquerCompteursStatsMatch(record, sur: stat)
        stat.dateModification = remoteDateMod
        context.insert(stat)
        return (uuid, remoteDateMod)
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

    /// Champs PUBLICS d'un point live. Fonction pure testable. Le champ
    /// `publieLe` (borne d'import E′ — moment de PUBLICATION, pas d'événement)
    /// et `ecrivainID` sont posés par `publierPointsMatch`.
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

    /// Borne un entier importé au domaine attendu. Fonction pure testable.
    static func borner(_ valeur: Int, _ domaine: ClosedRange<Int>) -> Int {
        min(max(valeur, domaine.lowerBound), domaine.upperBound)
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
        guard let ecrivain = ecrivainID, !ecrivain.isEmpty else { throw ErreurEcrivain.ecrivainAbsent }
        var aSupprimer: [CKRecord.ID] = []
        if supprimerFantomes, let seanceID {
            // "seanceID" doit être QUERYABLE sur PointMatchPartage (action ASC).
            // E′ (revue : CRITIQUE purge) — un appareil ne purge que SES PROPRES
            // records (suffixe -w{ecrivain}) : ouvrir puis fermer le live sans
            // être le preneur de stats ne détruit plus les points des autres.
            let predicate = NSPredicate(format: "seanceID == %@", seanceID.uuidString)
            let remoteRecords = try await fetchRecords(type: RecordType.pointMatch, predicate: predicate)
            let idsLocaux = Set(points.map { Self.nomRecord("point", id: $0.id.uuidString, ecrivain: ecrivain) })
            aSupprimer = remoteRecords.map(\.recordID).filter {
                $0.recordName.hasSuffix("-w\(ecrivain)") && !idsLocaux.contains($0.recordName)
            }
        }

        let publieLe = Date()
        let records = points.map { point -> CKRecord in
            let record = CKRecord(recordType: RecordType.pointMatch,
                                  recordID: CKRecord.ID(recordName: Self.nomRecord("point", id: point.id.uuidString, ecrivain: ecrivain)))
            for (cle, valeur) in Self.champsPublicsPointMatch(point) {
                record[cle] = valeur
            }
            // E′ : borne d'import monotone — une publication TARDIVE de vieux
            // points reste rattrapée (publieLe frais, horodatage ancien).
            record["publieLe"] = publieLe as CKRecordValue
            record["ecrivainID"] = ecrivain as CKRecordValue
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
            let (_, suppressions) = try await publicDB.modifyRecords(
                saving: [], deleting: lot, savePolicy: .allKeys, atomically: false)
            for (_, resultat) in suppressions {
                if case .failure(let erreur) = resultat { throw erreur }
            }
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

        // E′ : entiers BORNÉS au domaine (records publics non fiables — des
        // valeurs dégénérées pollueraient les agrégations et les heatmaps).
        let point = PointMatch(seanceID: seanceID,
                               set: Self.borner(record["set"] as? Int ?? 1, 1...5),
                               joueurID: (record.chaineSecurisee("joueurID")).flatMap(UUID.init(uuidString:)),
                               typeAction: typeAction)
        point.id = uuid
        point.codeEquipe = record.chaineSecurisee("codeEquipe") ?? ""
        point.scoreEquipeAuMoment = Self.borner(record["scoreEquipeAuMoment"] as? Int ?? 0, 0...99)
        point.scoreAdversaireAuMoment = Self.borner(record["scoreAdversaireAuMoment"] as? Int ?? 0, 0...99)
        point.rotationAuMoment = Self.borner(record["rotationAuMoment"] as? Int ?? 1, 1...6)
        point.rotationAdvAuMoment = Self.borner(record["rotationAdvAuMoment"] as? Int ?? 1, 1...6)
        point.zone = Self.borner(record["zone"] as? Int ?? 0, 0...6)
        point.zoneDepart = Self.borner(record["zoneDepart"] as? Int ?? 0, 0...6)
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
        guard let ecrivain = ecrivainID, !ecrivain.isEmpty else { throw ErreurEcrivain.ecrivainAbsent }
        let recordID = CKRecord.ID(recordName: Self.nomRecord("formation", id: formation.id.uuidString, ecrivain: ecrivain))
        let record = await recordPublicAJour(type: RecordType.formation, recordID: recordID)
        for (cle, valeur) in Self.champsPublicsFormation(formation) {
            record[cle] = valeur
        }
        record["positionsJSON"] = formation.positionsJSON.map { $0 as CKRecordValue }
        _ = try appliquerIdentiteEcrivain(record)
        _ = try await publicDB.save(record)
        #endif
    }

    /// Importe une formation personnalisée. Merge par id, sinon par CLÉ
    /// fonctionnelle (codeEquipe, type, rotation, mode) — deux coachs qui
    /// personnalisent la même rotation ne doivent pas créer de doublon
    /// (une seule formation par clé, dernier écrivain gagne).
    /// - Returns: (entiteID, dateModification appliquée) pour le filigrane, nil si ignoré.
    @discardableResult
    func importerFormation(from record: CKRecord, context: ModelContext) -> (UUID, Date)? {
        guard let idString = record.chaineSecurisee("formationID"),
              let uuid = UUID(uuidString: idString) else { return nil }
        let remoteDateMod = record["dateModification"] as? Date ?? .distantPast

        let descParID = FetchDescriptor<FormationPersonnalisee>(predicate: #Predicate { $0.id == uuid })
        if let existante = try? context.fetch(descParID).first {
            guard remoteDateMod > existante.dateModification else { return nil }
            appliquerChampsFormation(record, sur: existante)
            existante.dateModification = remoteDateMod
            return (uuid, remoteDateMod)
        }

        guard let typeRaw = record.chaineSecurisee("formationTypeRaw"),
              let type = FormationType(rawValue: typeRaw),
              let modeRaw = record.chaineSecurisee("modeRaw"),
              let mode = FormationMode(rawValue: modeRaw) else { return nil }
        let rotation = record["rotation"] as? Int ?? 0
        let codeEquipe = record.chaineSecurisee("codeEquipe") ?? ""

        // Dédup par clé fonctionnelle (id local différent → on merge dedans).
        let descParCle = FetchDescriptor<FormationPersonnalisee>(predicate: #Predicate {
            $0.codeEquipe == codeEquipe && $0.formationTypeRaw == typeRaw
                && $0.rotation == rotation && $0.modeRaw == modeRaw
        })
        if let memeCle = try? context.fetch(descParCle).first {
            guard remoteDateMod > memeCle.dateModification else { return nil }
            appliquerChampsFormation(record, sur: memeCle)
            memeCle.dateModification = remoteDateMod
            return (memeCle.id, remoteDateMod)
        }

        let formation = FormationPersonnalisee(formationType: type, rotation: rotation, mode: mode)
        formation.id = uuid
        formation.codeEquipe = codeEquipe
        appliquerChampsFormation(record, sur: formation)
        formation.dateModification = remoteDateMod
        context.insert(formation)
        return (uuid, remoteDateMod)
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
            // E′ : les points filigranés viennent d'un AUTRE écrivain (import) —
            // on ne publie que les siens, la purge ne touche que ses records.
            let filigranes = etatSync.etat(seance.codeEquipe).filigranes
            let points = ((try? context.fetch(descPoints)) ?? [])
                .filter { filigranes[$0.id.uuidString] == nil }
            try await publierPointsMatch(points, seanceID: seanceID, supprimerFantomes: true)
            logger.info("Analyse du match publiée (\(points.count) points)")
        } catch {
            logger.error("publierAnalyseMatch: \(error.localizedDescription)")
            self.erreur = error.localizedDescription
        }
        #endif
    }

    /// Importe les données d'analyse d'une équipe. E′ : les points sont bornés
    /// par `publieLe` (moment de PUBLICATION — une publication tardive de vieux
    /// points est rattrapée, contrairement à une borne sur l'horodatage
    /// d'événement), triés croissants, borne avancée au fil de l'eau (une
    /// troncature de page reprend exactement où elle s'est arrêtée).
    func importerAnalyse(codeEquipe: String, confiance: ConfianceEquipe, context: ModelContext) async throws {
        let statsRecords = try await fetchRecords(type: RecordType.statsMatch, codeEquipe: codeEquipe)
        for record in statsRecords where accepterRecord(record, confiance: confiance, codeEquipe: codeEquipe) {
            if let (entiteID, date) = importerStatsMatch(from: record, context: context) {
                etatSync.poserFiligrane(codeEquipe, entiteID: entiteID, date: date)
            }
        }

        let formationRecords = try await fetchRecords(type: RecordType.formation, codeEquipe: codeEquipe)
        for record in formationRecords where accepterRecord(record, confiance: confiance, codeEquipe: codeEquipe) {
            if let (entiteID, date) = importerFormation(from: record, context: context) {
                etatSync.poserFiligrane(codeEquipe, entiteID: entiteID, date: date)
            }
        }

        // Points : borne persistée sur publieLe ("publieLe" QUERYABLE + SORTABLE
        // sur PointMatchPartage — action ASC).
        let borne = etatSync.etat(codeEquipe).bornePublieLePoints
        let predicate = NSPredicate(format: "codeEquipe == %@ AND publieLe > %@",
                                    codeEquipe, borne as NSDate)
        let tri = [NSSortDescriptor(key: "publieLe", ascending: true)]
        let pointRecords = try await fetchRecords(type: RecordType.pointMatch,
                                                  predicate: predicate, tri: tri)

        let descIDs = FetchDescriptor<PointMatch>(predicate: #Predicate { $0.codeEquipe == codeEquipe })
        var idsExistants = Set(((try? context.fetch(descIDs)) ?? []).map(\.id))
        var nouvelleBorne = borne
        for record in pointRecords where accepterRecord(record, confiance: confiance, codeEquipe: codeEquipe) {
            importerPointMatch(from: record, idsExistants: &idsExistants, context: context)
            if let publieLe = record["publieLe"] as? Date, publieLe > nouvelleBorne {
                nouvelleBorne = publieLe
            }
        }
        if nouvelleBorne > borne {
            etatSync.modifier(codeEquipe) { $0.bornePublieLePoints = nouvelleBorne }
        }
    }
}
