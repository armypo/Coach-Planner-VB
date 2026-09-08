//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Tests E2 (parité assistant D6) : partage des contenus de préparation —
//  exercices de séance (dessins inclus), stratégies, scoutings, bibliothèque.
//  Purs : mappings champ→record, champs binaires (Data inline vs CKAsset),
//  et import CKRecord → SwiftData en mémoire (cloudKitDatabase: .none — piège #25).
//

import Testing
import Foundation
import SwiftData
import CloudKit
@testable import Playco

@Suite("CloudKitSharing — Préparation (E2)")
struct CloudKitPartagePreparationTests {

    private func contexte() throws -> ModelContext {
        let schema = Schema([Seance.self, Exercice.self, StrategieCollective.self,
                             ScoutingReport.self, ExerciceBibliotheque.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, allowsSave: true, groupContainer: .none, cloudKitDatabase: .none)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    // MARK: - Champs binaires (Data inline vs CKAsset)

    @Test("Un champ binaire léger part en Data inline (pas d'asset)")
    func binaireLegerInline() {
        let record = CKRecord(recordType: "ExercicePartage")
        let data = Data("dessin léger".utf8)

        let urlTemporaire = CloudKitSharingService.appliquerChampBinaire(record, cle: "dessinData", data: data)

        #expect(urlTemporaire == nil)
        #expect((record["dessinData"] as? Data) == data)
    }

    @Test("Un champ binaire > 500 Ko part en CKAsset (fichier temporaire)")
    func binaireLourdEnAsset() throws {
        let record = CKRecord(recordType: "ExercicePartage")
        let data = Data(count: CloudKitSharingService.seuilAssetOctets + 1)

        let urlTemporaire = CloudKitSharingService.appliquerChampBinaire(record, cle: "dessinData", data: data)

        let url = try #require(urlTemporaire)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(record["dessinData"] is CKAsset)
        // Round-trip via la lecture unifiée (tri-état E′).
        guard case .donnees(let lue) = CloudKitSharingService.lireChampBinaire(record, cle: "dessinData") else {
            Issue.record("Lecture attendue en .donnees")
            return
        }
        #expect(lue == data)
    }

    @Test("Un champ binaire nil ou vide efface la clé du record")
    func binaireAbsent() {
        let record = CKRecord(recordType: "ExercicePartage")
        record["dessinData"] = Data("ancien".utf8) as CKRecordValue

        _ = CloudKitSharingService.appliquerChampBinaire(record, cle: "dessinData", data: nil)
        #expect(record["dessinData"] == nil)

        record["dessinData"] = Data("ancien".utf8) as CKRecordValue
        _ = CloudKitSharingService.appliquerChampBinaire(record, cle: "dessinData", data: Data())
        #expect(record["dessinData"] == nil)
    }

    @Test("lireChampBinaire accepte les deux représentations (Data et CKAsset)")
    func lireLesDeuxRepresentations() throws {
        let record = CKRecord(recordType: "ExercicePartage")
        let data = Data("contenu".utf8)

        record["inline"] = data as CKRecordValue
        guard case .donnees(let inline) = CloudKitSharingService.lireChampBinaire(record, cle: "inline") else {
            Issue.record("inline attendu en .donnees")
            return
        }
        #expect(inline == data)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-asset-\(UUID().uuidString).bin")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        record["asset"] = CKAsset(fileURL: url)
        guard case .donnees(let asset) = CloudKitSharingService.lireChampBinaire(record, cle: "asset") else {
            Issue.record("asset attendu en .donnees")
            return
        }
        #expect(asset == data)

        // E′ §5 : ABSENT (champ vide légitime) ≠ ILLISIBLE (échec — jamais
        // d'écrasement local).
        guard case .absente = CloudKitSharingService.lireChampBinaire(record, cle: "absent") else {
            Issue.record("clé manquante attendue en .absente")
            return
        }
        record["troplourd"] = Data(count: CloudKitSharingService.tailleMaxChampBinaire + 1) as CKRecordValue
        guard case .illisible = CloudKitSharingService.lireChampBinaire(record, cle: "troplourd") else {
            Issue.record("binaire au-delà du plafond attendu en .illisible")
            return
        }
        // Le lot entier est refusé si UN champ est illisible (entité intacte, retry).
        #expect(CloudKitSharingService.lireChampsBinaires(record, cles: ["inline", "troplourd"]) == nil)
        let lot = CloudKitSharingService.lireChampsBinaires(record, cles: ["inline", "absent"])
        #expect(lot?["inline"] as? Data == data)
        #expect((lot?["absent"] ?? nil) == nil)
    }

    // MARK: - Mappings publics

    @Test("champsPublicsExercice mappe scalaires + clés de rattachement")
    func exerciceMapping() {
        let exo = Exercice(nom: "Attaque R4", notes: "3 vagues", ordre: 2, duree: 15)
        exo.estArchive = true
        exo.dateModification = Date(timeIntervalSince1970: 1_800_000_000)
        let seanceID = UUID()

        let champs = CloudKitSharingService.champsPublicsExercice(exo, seanceID: seanceID, codeEquipe: "EQU1")

        #expect((champs["exerciceID"] as? String) == exo.id.uuidString)
        #expect((champs["seanceID"] as? String) == seanceID.uuidString)
        #expect((champs["codeEquipe"] as? String) == "EQU1")
        #expect((champs["nom"] as? String) == "Attaque R4")
        #expect((champs["notes"] as? String) == "3 vagues")
        #expect((champs["ordre"] as? Int) == 2)
        #expect((champs["duree"] as? Int) == 15)
        #expect((champs["estArchive"] as? Int) == 1)
        #expect((champs["dateModification"] as? Date) == Date(timeIntervalSince1970: 1_800_000_000))
    }

    @Test("champsPublicsScouting ne publie JAMAIS joueursData (PII adverses)")
    func scoutingSansJoueursData() {
        let rapport = ScoutingReport()
        rapport.adversaire = "Titans"
        rapport.codeEquipe = "EQU1"
        rapport.joueurs = [JoueurAdverse()]

        let champs = CloudKitSharingService.champsPublicsScouting(rapport)

        // ARBITRAGE E2 : évaluations nominatives de joueurs adverses jamais
        // en Public DB world-readable.
        #expect(champs["joueursData"] == nil)
        #expect((champs["adversaire"] as? String) == "Titans")
        #expect((champs["codeEquipe"] as? String) == "EQU1")
    }

    @Test("champsPublicsBibliotheque : estFavori (préférence perso) non synchronisé")
    func bibliothequeSansFavori() {
        let exo = ExerciceBibliotheque(nom: "Passe-attaque", categorie: "Attaque")
        exo.estFavori = true
        exo.codeCoach = "coach-uuid"

        let champs = CloudKitSharingService.champsPublicsBibliotheque(exo, codeEquipe: "EQU1")

        #expect(champs["estFavori"] == nil)
        #expect(champs["estPredefini"] == nil)
        #expect((champs["codeEquipe"] as? String) == "EQU1")
        #expect((champs["codeCoach"] as? String) == "coach-uuid")
    }

    // MARK: - Import exercice

    private func recordExercice(id: UUID, seanceID: UUID, dateMod: Date) -> CKRecord {
        let record = CKRecord(recordType: "ExercicePartage")
        record["exerciceID"] = id.uuidString
        record["seanceID"] = seanceID.uuidString
        record["codeEquipe"] = "EQU1"
        record["nom"] = "Défense zone 6"
        record["notes"] = "Notes exo"
        record["ordre"] = 1
        record["duree"] = 10
        record["typeTerrain"] = TypeTerrain.indoor.rawValue
        record["estArchive"] = 0
        record["dessinData"] = Data("dessin".utf8)
        record["etapesData"] = Data("etapes".utf8)
        record["dateModification"] = dateMod
        return record
    }

    @Test("Importer un exercice le rattache à sa séance (piège #16)")
    func importerExerciceRattache() throws {
        let service = CloudKitSharingService()
        let ctx = try contexte()
        let seance = Seance(nom: "Pratique mardi", date: Date())
        ctx.insert(seance)
        try ctx.save()

        let exoID = UUID()
        service.importerExercice(from: recordExercice(id: exoID, seanceID: seance.id,
                                                      dateMod: Date(timeIntervalSince1970: 1_800_000_000)),
                                 context: ctx)
        try ctx.save()

        let exo = try #require(try ctx.fetch(FetchDescriptor<Exercice>()).first)
        #expect(exo.id == exoID)
        #expect(exo.nom == "Défense zone 6")
        #expect(exo.duree == 10)
        #expect(exo.dessinData == Data("dessin".utf8))
        #expect(exo.etapesData == Data("etapes".utf8), "piège #5 : etapesData toujours propagé")
        #expect((seance.exercices ?? []).contains { $0.id == exoID })
    }

    @Test("Importer un exercice dont la séance est absente : no-op (repris au prochain cycle)")
    func importerExerciceSansSeance() throws {
        let service = CloudKitSharingService()
        let ctx = try contexte()

        service.importerExercice(from: recordExercice(id: UUID(), seanceID: UUID(), dateMod: Date()),
                                 context: ctx)
        try ctx.save()

        #expect(try ctx.fetch(FetchDescriptor<Exercice>()).isEmpty)
    }

    @Test("Merge exercice : un remote plus ancien n'écrase pas le local")
    func mergeExerciceAncienIgnore() throws {
        let service = CloudKitSharingService()
        let ctx = try contexte()
        let exoID = UUID()
        let local = Exercice(nom: "Local récent")
        local.id = exoID
        local.dateModification = Date(timeIntervalSince1970: 2_000_000_000)
        ctx.insert(local)
        try ctx.save()

        service.importerExercice(from: recordExercice(id: exoID, seanceID: UUID(),
                                                      dateMod: Date(timeIntervalSince1970: 1_000_000_000)),
                                 context: ctx)

        #expect(local.nom == "Local récent")
    }

    // MARK: - Import stratégie

    @Test("Importer une stratégie applique champs + estArchivee")
    func importerStrategie() throws {
        let service = CloudKitSharingService()
        let ctx = try contexte()
        let id = UUID()
        let record = CKRecord(recordType: "StrategiePartagee")
        record["strategieID"] = id.uuidString
        record["codeEquipe"] = "EQU1"
        record["nom"] = "Side-out A"
        record["categorieRaw"] = CategorieStrategie.sideOut.rawValue
        record["notes"] = "Notes stratégie"
        record["estArchivee"] = 1
        record["elementsData"] = Data("elements".utf8)
        record["dateModification"] = Date(timeIntervalSince1970: 1_800_000_000)

        service.importerStrategie(from: record, context: ctx)
        try ctx.save()

        let strat = try #require(try ctx.fetch(FetchDescriptor<StrategieCollective>()).first)
        #expect(strat.id == id)
        #expect(strat.nom == "Side-out A")
        #expect(strat.categorie == .sideOut)
        #expect(strat.codeEquipe == "EQU1")
        #expect(strat.estArchivee, "l'archivage doit se propager entre coachs")
        #expect(strat.elementsData == Data("elements".utf8))
    }

    // MARK: - Import scouting

    @Test("Importer un scouting applique le contenu tactique, jamais joueursData")
    func importerScouting() throws {
        let service = CloudKitSharingService()
        let ctx = try contexte()
        let id = UUID()
        let seanceLiee = UUID()
        let record = CKRecord(recordType: "ScoutingPartage")
        record["scoutingID"] = id.uuidString
        record["codeEquipe"] = "EQU1"
        record["adversaire"] = "Titans"
        record["systemJeu"] = "5-1"
        record["tendanceService"] = "Sert zones 1 et 5"
        record["seanceID"] = seanceLiee.uuidString
        record["forcesData"] = Data("[\"Bloc central\"]".utf8)
        // Un record public malveillant/ancien pourrait porter joueursData :
        // il ne doit jamais être importé.
        record["joueursData"] = Data("intrusion".utf8)
        record["dateModification"] = Date(timeIntervalSince1970: 1_800_000_000)

        service.importerScouting(from: record, context: ctx)
        try ctx.save()

        let rapport = try #require(try ctx.fetch(FetchDescriptor<ScoutingReport>()).first)
        #expect(rapport.id == id)
        #expect(rapport.adversaire == "Titans")
        #expect(rapport.systemJeu == "5-1")
        #expect(rapport.tendanceService == "Sert zones 1 et 5")
        #expect(rapport.seanceID == seanceLiee)
        #expect(rapport.forces == ["Bloc central"])
        #expect(rapport.joueursData == Data(), "joueursData ne s'importe JAMAIS depuis la Public DB")
    }

    // MARK: - Import bibliothèque

    @Test("Bibliothèque : dédup par exerciceID (records multi-équipes) + jamais prédéfini")
    func importerBibliothequeDedup() throws {
        let service = CloudKitSharingService()
        let ctx = try contexte()
        let id = UUID()

        func record(codeEquipe: String, dateMod: Date) -> CKRecord {
            let r = CKRecord(recordType: "BibliothequePartagee")
            r["exerciceID"] = id.uuidString
            r["codeEquipe"] = codeEquipe
            r["codeCoach"] = "coach-uuid"
            r["nom"] = "Passe-attaque"
            r["categorie"] = "Attaque"
            r["notesCoach"] = "Variante rapide"
            r["duree"] = 12
            r["dateModification"] = dateMod
            return r
        }

        service.importerBibliotheque(from: record(codeEquipe: "EQU1", dateMod: Date(timeIntervalSince1970: 1_000)), context: ctx)
        service.importerBibliotheque(from: record(codeEquipe: "EQU2", dateMod: Date(timeIntervalSince1970: 2_000)), context: ctx)
        try ctx.save()

        let items = try ctx.fetch(FetchDescriptor<ExerciceBibliotheque>())
        #expect(items.count == 1, "un même item publié sous deux équipes reste UN item local")
        let item = try #require(items.first)
        #expect(item.nom == "Passe-attaque")
        #expect(item.notesCoach == "Variante rapide")
        #expect(item.codeCoach == "coach-uuid")
        #expect(!item.estPredefini)
        #expect(!item.estFavori, "estFavori reste une préférence locale")
    }
}
