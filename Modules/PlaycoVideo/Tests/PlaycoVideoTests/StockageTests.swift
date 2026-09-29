//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//

import Foundation
import Testing
@testable import PlaycoVideo

@Suite("StockageVideoMatch — stockage local et manifeste")
struct StockageTests {

    private func stockageIsole() -> StockageVideoMatch {
        StockageVideoMatch(racine: FileManager.default.temporaryDirectory
            .appendingPathComponent("tests-video-\(UUID().uuidString)", isDirectory: true))
    }

    private func fichierVideo(_ contenu: String, extension ext: String = "MOV") throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("source-\(UUID().uuidString).\(ext)")
        try Data(contenu.utf8).write(to: url)
        return url
    }

    private func manifeste(_ seanceID: UUID) -> ManifesteVideoMatch {
        ManifesteVideoMatch(
            seanceID: seanceID,
            codeEquipe: "EQ1",
            alignement: Fixtures.alignement(),
            sourceAlignement: .metadonneeFichier,
            dateImport: Date(timeIntervalSince1970: 2_000_000)
        )
    }

    @Test("importer copie la vidéo et relit le manifeste")
    func importer() throws {
        let s = stockageIsole()
        let id = UUID()
        let importe = try s.importer(videoSource: fichierVideo("A"), manifeste: manifeste(id))

        #expect(importe.nomFichierVideo == "match.mov")
        #expect(try s.manifeste(seanceID: id) == importe)
        let url = try #require(s.urlVideo(seanceID: id))
        #expect(try Data(contentsOf: url) == Data("A".utf8))
        #expect(try s.seancesAvecVideo() == [id])
    }

    @Test("le consentement IA est NON par défaut, et absent du JSON = NON")
    func consentement() throws {
        #expect(manifeste(UUID()).consentementEntrainementIA == false)
        let id = UUID()
        let json = #"{"seanceID": "\#(id.uuidString)", "alignement": {"dateDebutVideo": 0, "dureeVideo": 60}}"#
        let m = try ManifesteVideoMatch.decoder(Data(json.utf8))
        #expect(m.consentementEntrainementIA == false)
        #expect(m.fenetre == .parDefaut)
        #expect(m.ancres.isEmpty)
    }

    @Test("réimporter remplace la vidéo du match")
    func reimporter() throws {
        let s = stockageIsole()
        let id = UUID()
        try s.importer(videoSource: fichierVideo("A"), manifeste: manifeste(id))
        try s.importer(videoSource: fichierVideo("B", extension: "mp4"), manifeste: manifeste(id))

        let url = try #require(s.urlVideo(seanceID: id))
        #expect(url.lastPathComponent == "match.mp4")
        #expect(try Data(contentsOf: url) == Data("B".utf8))
    }

    @Test("un import échoué ne détruit pas la vidéo en place")
    func importEchoue() throws {
        let s = stockageIsole()
        let id = UUID()
        try s.importer(videoSource: fichierVideo("A"), manifeste: manifeste(id))
        let absente = FileManager.default.temporaryDirectory.appendingPathComponent("absente-\(UUID().uuidString).mov")

        #expect(throws: (any Error).self) {
            try s.importer(videoSource: absente, manifeste: manifeste(id))
        }
        let url = try #require(s.urlVideo(seanceID: id))
        #expect(try Data(contentsOf: url) == Data("A".utf8))
    }

    @Test("enregistrer persiste une correction d'alignement")
    func enregistrer() throws {
        let s = stockageIsole()
        let id = UUID()
        var m = try s.importer(videoSource: fichierVideo("A"), manifeste: manifeste(id))
        m.alignement.decalageSecondes = -1.5
        m.sourceAlignement = .ancres
        try s.enregistrer(m)

        #expect(try s.manifeste(seanceID: id)?.alignement.decalageSecondes == -1.5)
        #expect(try s.manifeste(seanceID: id)?.sourceAlignement == .ancres)
    }

    @Test("enregistrer sans vidéo importée échoue")
    func enregistrerSansImport() {
        #expect(throws: (any Error).self) {
            try stockageIsole().enregistrer(manifeste(UUID()))
        }
    }

    @Test("un nom de fichier altéré ne sort jamais du dossier du match")
    func nomAltere() throws {
        let s = stockageIsole()
        let id = UUID()
        var m = try s.importer(videoSource: fichierVideo("A"), manifeste: manifeste(id))
        m.nomFichierVideo = "../../match.mov"
        try s.enregistrer(m)

        let url = try #require(s.urlVideo(seanceID: id))
        #expect(url.deletingLastPathComponent().standardizedFileURL.path
                == s.dossier(seanceID: id).standardizedFileURL.path)
        #expect(StockageVideoMatch.nomSur("..") == nil)
        #expect(StockageVideoMatch.nomSur("") == nil)
    }

    @Test("manifeste illisible : erreur (pas confondu avec l'absence)")
    func manifesteIllisible() throws {
        let s = stockageIsole()
        let id = UUID()
        try s.importer(videoSource: fichierVideo("A"), manifeste: manifeste(id))
        try Data("pas du json".utf8).write(to: s.dossier(seanceID: id).appendingPathComponent(StockageVideoMatch.nomManifeste))

        #expect(throws: (any Error).self) { try s.manifeste(seanceID: id) }
        #expect(s.urlVideo(seanceID: id) == nil)
        #expect(try s.manifeste(seanceID: UUID()) == nil)
    }

    @Test("supprimer retire la vidéo ; no-op si absente")
    func supprimer() throws {
        let s = stockageIsole()
        let id = UUID()
        try s.importer(videoSource: fichierVideo("A"), manifeste: manifeste(id))
        try s.supprimer(seanceID: id)
        try s.supprimer(seanceID: id)

        #expect(try s.manifeste(seanceID: id) == nil)
        #expect(try s.seancesAvecVideo().isEmpty)
    }

    @Test("extension de fichier assainie")
    func extensionSure() {
        #expect(StockageVideoMatch.extensionSure("MOV") == "mov")
        #expect(StockageVideoMatch.extensionSure("m p/4") == "mp4")
        #expect(StockageVideoMatch.extensionSure("") == "mov")
    }
}
