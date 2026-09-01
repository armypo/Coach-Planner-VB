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
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, allowsSave: true, groupContainer: .none, cloudKitDatabase: .none)
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

    // MARK: - Disponibilité (E′ §7 — PII minimale : booléen seul)

    @Test("Importer un joueur indisponible pose le statut GÉNÉRIQUE — jamais de motif santé ni d'attestation depuis la Public DB")
    func importerJoueurDisponibilite() throws {
        let service = CloudKitSharingService()
        let ctx = try contexte()
        let id = UUID()
        let record = CKRecord(recordType: "JoueurPartage")
        record["joueurID"] = id.uuidString
        record["nom"] = "Roy"
        record["prenom"] = "Alex"
        record["estDisponible"] = 0
        // Champs pré-E′ (ou forgés) : ne doivent JAMAIS être appliqués.
        record["statutDisponibiliteRaw"] = "blesse"
        record["consentementParentalAtteste"] = 1
        record["dateAttestationConsentement"] = Date(timeIntervalSince1970: 1_700_000_000)
        record["attesteParNom"] = "Coach Dionne"

        service.importerJoueur(from: record, context: ctx)
        try ctx.save()

        let j = try #require(try ctx.fetch(FetchDescriptor<JoueurEquipe>()).first)
        #expect(j.statutDisponibilite == .indisponible, "Motif générique — la santé ne transite pas")
        #expect(!j.consentementParentalAtteste, "L'attestation ne s'importe JAMAIS (registre légal local)")
        #expect(j.dateAttestationConsentement == nil)
        #expect(j.attesteParNom.isEmpty)
    }

    @Test("Merge joueur : disponible côté remote plus récent vide le statut ; un motif local n'est pas dégradé par un booléen")
    func mergeJoueurDisponibilite() throws {
        let service = CloudKitSharingService()
        let ctx = try contexte()
        let id = UUID()

        let local = JoueurEquipe(nom: "Roy", prenom: "Alex", numero: 10, poste: .passeur)
        local.id = id
        local.statutDisponibilite = .malade
        local.dateModification = Date(timeIntervalSince1970: 1_000_000_000)
        ctx.insert(local)
        try ctx.save()

        // Remote plus récent : redevenu disponible → statut vidé.
        let record = CKRecord(recordType: "JoueurPartage")
        record["joueurID"] = id.uuidString
        record["estDisponible"] = 1
        record["dateModification"] = Date(timeIntervalSince1970: 2_000_000_000)
        service.importerJoueur(from: record, context: ctx)
        try ctx.save()
        #expect(local.statutDisponibilite == .disponible)

        // Motif local reposé PUIS booléen indisponible distant plus récent :
        // le motif local (plus riche) est conservé, pas dégradé en générique.
        local.statutDisponibilite = .suspendu
        local.dateModification = Date(timeIntervalSince1970: 2_500_000_000)
        let record2 = CKRecord(recordType: "JoueurPartage")
        record2["joueurID"] = id.uuidString
        record2["estDisponible"] = 0
        record2["dateModification"] = Date(timeIntervalSince1970: 3_000_000_000)
        service.importerJoueur(from: record2, context: ctx)
        try ctx.save()
        #expect(local.statutDisponibilite == .suspendu)
        #expect(!local.estDisponible)
    }

    // MARK: - Anti-boucle E4 (réimport de sa propre publication)

    @Test("Anti-boucle : un remote de dateModification ÉGALE est un no-op")
    func antiBoucleEgaliteNoOp() throws {
        let service = CloudKitSharingService()
        let ctx = try contexte()
        let id = UUID()
        let meme = Date(timeIntervalSince1970: 1_500_000_000)

        // Simule sa propre publication réimportée : même id, même horodatage.
        let local = JoueurEquipe(nom: "Roy", prenom: "Alex", numero: 10, poste: .passeur)
        local.id = id
        local.aces = 5
        local.dateModification = meme
        ctx.insert(local)
        try ctx.save()

        let record = CKRecord(recordType: "JoueurPartage")
        record["joueurID"] = id.uuidString
        record["aces"] = 999
        record["dateModification"] = meme

        service.importerJoueur(from: record, context: ctx)

        #expect(local.aces == 5, "un écho de sa propre publication ne doit rien changer")

        // Même garantie côté séance.
        let seanceID = UUID()
        let seanceLocale = Seance(nom: "Ma séance", date: Date())
        seanceLocale.id = seanceID
        seanceLocale.dateModification = meme
        ctx.insert(seanceLocale)
        try ctx.save()

        let recordSeance = CKRecord(recordType: "SeancePartagee")
        recordSeance["seanceID"] = seanceID.uuidString
        recordSeance["nom"] = "Écho remote"
        recordSeance["dateModification"] = meme

        service.importerSeance(from: recordSeance, context: ctx)
        #expect(seanceLocale.nom == "Ma séance")
    }

    @Test("Un statut de disponibilité inconnu (record public corrompu) est rejeté")
    func statutDisponibiliteInconnuRejete() throws {
        let service = CloudKitSharingService()
        let ctx = try contexte()
        let id = UUID()
        let record = CKRecord(recordType: "JoueurPartage")
        record["joueurID"] = id.uuidString
        record["nom"] = "Roy"
        record["statutDisponibiliteRaw"] = "en_vacances" // hors enum

        service.importerJoueur(from: record, context: ctx)
        try ctx.save()

        let j = try #require(try ctx.fetch(FetchDescriptor<JoueurEquipe>()).first)
        #expect(j.statutDisponibiliteRaw.isEmpty, "un raw hors enum ne doit pas être persisté")
    }
}
