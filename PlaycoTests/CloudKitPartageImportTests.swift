//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Tests d'import des données partagées (calendrier + stats) ajoutées au partage
//  coach→athlète : SeancePartagee, MatchCalendrierPartagee, et les stats cumulées
//  sur JoueurPartage. Purs : CKRecord construit en mémoire → import → assert SwiftData.
//

import Testing
import Foundation
import SwiftData
import CloudKit
@testable import Playco

@Suite("CloudKitSharing — Import calendrier & stats")
struct CloudKitPartageImportTests {

    private func contexte() throws -> ModelContext {
        let schema = Schema([Equipe.self, Seance.self, MatchCalendrier.self, JoueurEquipe.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    // MARK: - Séance

    @Test("Importer une séance crée la séance avec ses champs")
    func importerSeance() throws {
        let service = CloudKitSharingService()
        let ctx = try contexte()
        let id = UUID()
        let record = CKRecord(recordType: "SeancePartagee")
        record["seanceID"] = id.uuidString
        record["codeEquipe"] = "EQU1"
        record["nom"] = "Match vs Titans"
        record["date"] = Date(timeIntervalSince1970: 1_900_000_000)
        record["typeSeanceRaw"] = TypeSeance.match.rawValue
        record["lieu"] = "Gymnase A"
        record["adversaire"] = "Titans"
        record["scoreEquipe"] = 3
        record["scoreAdversaire"] = 1
        record["estArchivee"] = 0
        record["dateModification"] = Date(timeIntervalSince1970: 1_800_000_000)

        service.importerSeance(from: record, context: ctx)
        try ctx.save()

        let seances = try ctx.fetch(FetchDescriptor<Seance>())
        #expect(seances.count == 1)
        let s = try #require(seances.first)
        #expect(s.id == id)
        #expect(s.nom == "Match vs Titans")
        #expect(s.codeEquipe == "EQU1")
        #expect(s.adversaire == "Titans")
        #expect(s.scoreEquipe == 3)
        #expect(s.typeSeanceRaw == TypeSeance.match.rawValue)
    }

    @Test("Merge séance : un remote plus ancien n'écrase pas le local")
    func mergeSeanceAncienIgnore() throws {
        let service = CloudKitSharingService()
        let ctx = try contexte()
        let id = UUID()

        let locale = Seance(nom: "Local récent", date: Date())
        locale.id = id
        locale.dateModification = Date(timeIntervalSince1970: 2_000_000_000) // récent
        ctx.insert(locale)
        try ctx.save()

        let record = CKRecord(recordType: "SeancePartagee")
        record["seanceID"] = id.uuidString
        record["nom"] = "Remote ancien"
        record["dateModification"] = Date(timeIntervalSince1970: 1_000_000_000) // ancien

        service.importerSeance(from: record, context: ctx)
        try ctx.save()

        let s = try #require(try ctx.fetch(FetchDescriptor<Seance>()).first)
        #expect(s.nom == "Local récent", "le local plus récent doit être préservé")
    }

    // NB v2.0.1/SIWA : le partage MatchCalendrier a été retiré (déprécié/dormant).
    // Les matchs sont partagés en tant que Seance (type=.match) — cf. test importerSeance.

    // MARK: - Stats cumulées sur le joueur

    @Test("Importer un joueur applique les stats cumulées")
    func importerJoueurStats() throws {
        let service = CloudKitSharingService()
        let ctx = try contexte()
        let id = UUID()
        let record = CKRecord(recordType: "JoueurPartage")
        record["joueurID"] = id.uuidString
        record["nom"] = "Roy"
        record["prenom"] = "Alex"
        record["numero"] = 10
        record["posteRaw"] = PosteJoueur.passeur.rawValue
        record["codeEquipe"] = "EQU1"
        record["identifiant"] = "alex.roy.1"
        record["aces"] = 12
        record["attaquesReussies"] = 45
        record["manchettes"] = 30
        record["matchsJoues"] = 8
        record["dateModification"] = Date(timeIntervalSince1970: 1_900_000_000)

        service.importerJoueur(from: record, context: ctx)
        try ctx.save()

        let j = try #require(try ctx.fetch(FetchDescriptor<JoueurEquipe>()).first)
        #expect(j.id == id)
        #expect(j.aces == 12)
        #expect(j.attaquesReussies == 45)
        #expect(j.manchettes == 30)
        #expect(j.matchsJoues == 8)
    }
}
