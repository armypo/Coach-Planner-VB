//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Tests E3 (parité assistant D6) : partage des données d'analyse — box scores
//  (StatsMatch), points live (PointMatch, lots + immuabilité), formations
//  personnalisées (dédup par clé fonctionnelle). Purs : mappings + import
//  CKRecord → SwiftData en mémoire (cloudKitDatabase: .none — piège #25).
//

import Testing
import Foundation
import SwiftData
import CloudKit
@testable import Playco

@Suite("CloudKitSharing — Analyse (E3)")
struct CloudKitPartageAnalyseTests {

    private func contexte() throws -> ModelContext {
        let schema = Schema([StatsMatch.self, PointMatch.self, FormationPersonnalisee.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, allowsSave: true, groupContainer: .none, cloudKitDatabase: .none)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    // MARK: - Lots

    @Test("lots() découpe au plafond CloudKit sans perdre d'éléments")
    func decoupageEnLots() {
        let elements = Array(0..<850)
        let lots = CloudKitSharingService.lots(elements, taille: 400)
        #expect(lots.map(\.count) == [400, 400, 50])
        #expect(lots.flatMap { $0 } == elements)
        #expect(CloudKitSharingService.lots([Int](), taille: 400).isEmpty)
    }

    // MARK: - StatsMatch

    @Test("champsPublicsStatsMatch mappe compteurs + IDs de rattachement")
    func statsMatchMapping() {
        let stat = StatsMatch(seanceID: UUID(), joueurID: UUID())
        stat.codeEquipe = "EQU1"
        stat.kills = 9
        stat.receptionsTotales = 22
        stat.setsJoues = 4
        stat.dateModification = Date(timeIntervalSince1970: 1_800_000_000)

        let champs = CloudKitSharingService.champsPublicsStatsMatch(stat)

        #expect((champs["statsID"] as? String) == stat.id.uuidString)
        #expect((champs["seanceID"] as? String) == stat.seanceID.uuidString)
        #expect((champs["joueurID"] as? String) == stat.joueurID.uuidString)
        #expect((champs["codeEquipe"] as? String) == "EQU1")
        #expect((champs["kills"] as? Int) == 9)
        #expect((champs["receptionsTotales"] as? Int) == 22)
        #expect((champs["setsJoues"] as? Int) == 4)
        #expect((champs["dateModification"] as? Date) == Date(timeIntervalSince1970: 1_800_000_000))
    }

    @Test("Importer un box score : création puis merge dateModification")
    func importerStatsMatch() throws {
        let service = CloudKitSharingService()
        let ctx = try contexte()
        let id = UUID(), seanceID = UUID(), joueurID = UUID()

        func record(kills: Int, dateMod: Date) -> CKRecord {
            let r = CKRecord(recordType: "StatsMatchPartage")
            r["statsID"] = id.uuidString
            r["seanceID"] = seanceID.uuidString
            r["joueurID"] = joueurID.uuidString
            r["codeEquipe"] = "EQU1"
            r["kills"] = kills
            r["dateModification"] = dateMod
            return r
        }

        service.importerStatsMatch(from: record(kills: 7, dateMod: Date(timeIntervalSince1970: 2_000)), context: ctx)
        try ctx.save()

        let stat = try #require(try ctx.fetch(FetchDescriptor<StatsMatch>()).first)
        #expect(stat.id == id)
        #expect(stat.seanceID == seanceID)
        #expect(stat.kills == 7)

        // Remote plus ancien → ignoré.
        service.importerStatsMatch(from: record(kills: 99, dateMod: Date(timeIntervalSince1970: 1_000)), context: ctx)
        #expect(stat.kills == 7)

        // Remote plus récent → appliqué.
        service.importerStatsMatch(from: record(kills: 11, dateMod: Date(timeIntervalSince1970: 3_000)), context: ctx)
        #expect(stat.kills == 11)
        #expect(try ctx.fetch(FetchDescriptor<StatsMatch>()).count == 1)
    }

    // MARK: - PointMatch

    @Test("champsPublicsPointMatch mappe le contexte complet du point")
    func pointMatchMapping() {
        let point = PointMatch(seanceID: UUID(), set: 3, joueurID: UUID(), typeAction: .ace)
        point.codeEquipe = "EQU1"
        point.scoreEquipeAuMoment = 18
        point.scoreAdversaireAuMoment = 15
        point.rotationAuMoment = 4
        point.rotationAdvAuMoment = 2
        point.zone = 5
        point.zoneDepart = 1
        point.nousServionsAuMoment = true
        point.serviceRenseigne = true
        point.horodatage = Date(timeIntervalSince1970: 1_800_000_000)

        let champs = CloudKitSharingService.champsPublicsPointMatch(point)

        #expect((champs["pointID"] as? String) == point.id.uuidString)
        #expect((champs["set"] as? Int) == 3)
        #expect((champs["typeActionRaw"] as? String) == TypeActionPoint.ace.rawValue)
        #expect((champs["scoreEquipeAuMoment"] as? Int) == 18)
        #expect((champs["rotationAuMoment"] as? Int) == 4)
        #expect((champs["rotationAdvAuMoment"] as? Int) == 2)
        #expect((champs["zone"] as? Int) == 5)
        #expect((champs["zoneDepart"] as? Int) == 1)
        #expect((champs["nousServionsAuMoment"] as? Int) == 1)
        #expect((champs["serviceRenseigne"] as? Int) == 1)
        #expect((champs["horodatage"] as? Date) == Date(timeIntervalSince1970: 1_800_000_000))
        #expect(champs["joueurID"] != nil)
    }

    @Test("Importer un point : création unique (immuable) + rejet des types inconnus")
    func importerPointMatch() throws {
        let service = CloudKitSharingService()
        let ctx = try contexte()
        let id = UUID(), seanceID = UUID()

        let record = CKRecord(recordType: "PointMatchPartage")
        record["pointID"] = id.uuidString
        record["seanceID"] = seanceID.uuidString
        record["codeEquipe"] = "EQU1"
        record["set"] = 2
        record["typeActionRaw"] = TypeActionPoint.kill.rawValue
        record["nousServionsAuMoment"] = 1
        record["serviceRenseigne"] = 1
        record["horodatage"] = Date(timeIntervalSince1970: 1_800_000_000)

        var idsExistants = Set<UUID>()
        service.importerPointMatch(from: record, idsExistants: &idsExistants, context: ctx)
        try ctx.save()

        let point = try #require(try ctx.fetch(FetchDescriptor<PointMatch>()).first)
        #expect(point.id == id)
        #expect(point.set == 2)
        #expect(point.typeAction == .kill)
        #expect(point.nousServionsAuMoment)
        #expect(point.serviceRenseigne)
        #expect(idsExistants.contains(id))

        // Ré-import du même id : ignoré (immuable).
        service.importerPointMatch(from: record, idsExistants: &idsExistants, context: ctx)
        #expect(try ctx.fetch(FetchDescriptor<PointMatch>()).count == 1)

        // Type d'action hors enum : rejeté (jamais de fallback fabriqué).
        let corrompu = CKRecord(recordType: "PointMatchPartage")
        corrompu["pointID"] = UUID().uuidString
        corrompu["seanceID"] = seanceID.uuidString
        corrompu["typeActionRaw"] = "action_inconnue"
        service.importerPointMatch(from: corrompu, idsExistants: &idsExistants, context: ctx)
        #expect(try ctx.fetch(FetchDescriptor<PointMatch>()).count == 1)
    }

    // MARK: - Formations personnalisées

    private func recordFormation(id: UUID, codeEquipe: String = "EQU1",
                                 rotation: Int = 2, dateMod: Date,
                                 positions: Data? = nil) -> CKRecord {
        let r = CKRecord(recordType: "FormationPartagee")
        r["formationID"] = id.uuidString
        r["codeEquipe"] = codeEquipe
        r["formationTypeRaw"] = FormationType.cinqUn.rawValue
        r["rotation"] = rotation
        r["modeRaw"] = FormationMode.base.rawValue
        r["positionsJSON"] = positions
        r["dateModification"] = dateMod
        return r
    }

    @Test("Importer une formation : création avec positions")
    func importerFormation() throws {
        let service = CloudKitSharingService()
        let ctx = try contexte()
        let id = UUID()
        let positions = Data("positions-json".utf8)

        service.importerFormation(from: recordFormation(id: id, dateMod: Date(timeIntervalSince1970: 2_000), positions: positions), context: ctx)
        try ctx.save()

        let formation = try #require(try ctx.fetch(FetchDescriptor<FormationPersonnalisee>()).first)
        #expect(formation.id == id)
        #expect(formation.formationTypeRaw == FormationType.cinqUn.rawValue)
        #expect(formation.rotation == 2)
        #expect(formation.codeEquipe == "EQU1")
        #expect(formation.positionsJSON == positions)
    }

    @Test("Formation : dédup par clé fonctionnelle (id différent, même rotation)")
    func formationDedupParCle() throws {
        let service = CloudKitSharingService()
        let ctx = try contexte()

        // Formation locale existante pour la même clé (5-1, rotation 2, Base).
        let locale = FormationPersonnalisee(formationType: .cinqUn, rotation: 2, mode: .base)
        locale.codeEquipe = "EQU1"
        locale.positionsJSON = Data("locales".utf8)
        locale.dateModification = Date(timeIntervalSince1970: 1_000)
        ctx.insert(locale)
        try ctx.save()

        // Un AUTRE coach a publié la même clé sous un autre UUID, plus récent.
        let positionsRemote = Data("remote".utf8)
        service.importerFormation(from: recordFormation(id: UUID(), dateMod: Date(timeIntervalSince1970: 2_000), positions: positionsRemote), context: ctx)
        try ctx.save()

        let formations = try ctx.fetch(FetchDescriptor<FormationPersonnalisee>())
        #expect(formations.count == 1, "une seule formation par clé (type, rotation, mode, équipe)")
        #expect(formations.first?.positionsJSON == positionsRemote, "dernier écrivain gagne")

        // Remote plus ancien pour la même clé : ignoré.
        service.importerFormation(from: recordFormation(id: UUID(), dateMod: Date(timeIntervalSince1970: 500), positions: Data("vieux".utf8)), context: ctx)
        #expect(try ctx.fetch(FetchDescriptor<FormationPersonnalisee>()).count == 1)
        #expect(formations.first?.positionsJSON == positionsRemote)
    }
}
