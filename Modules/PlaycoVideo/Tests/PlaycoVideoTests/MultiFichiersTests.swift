//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Match filmé en plusieurs fichiers (le coach coupe l'enregistrement entre
//  les sets) : chaque fichier a sa propre heure de début.
//

import Foundation
import Testing
@testable import PlaycoVideo

@Suite("Match en plusieurs fichiers")
struct MultiFichiersTests {

    /// Fichier A : réel [0, 600] ; fichier B : réel [700, 1300] (pause entre sets).
    private let fichierA = AlignementVideo(dateDebutVideo: Fixtures.debutVideo, dureeVideo: 600)
    private let fichierB = AlignementVideo(dateDebutVideo: Fixtures.debutVideo.addingTimeInterval(700), dureeVideo: 600)

    @Test("chaque événement est rattaché au bon fichier ; pendant la pause, écarté")
    func rattachement() {
        let c = IndexVideo.chapitres(
            [Fixtures.evenement(a: 800), Fixtures.evenement(a: 650), Fixtures.evenement(a: 100)],
            fichiers: [fichierA, fichierB])
        #expect(c.map(\.indexFichier) == [0, 1])
        #expect(c.map(\.instant) == [100, 100])
    }

    @Test("fichiers qui se chevauchent : le plus long clip l'emporte")
    func chevauchement() {
        let b = AlignementVideo(dateDebutVideo: Fixtures.debutVideo.addingTimeInterval(598), dureeVideo: 600)
        // Réel 601 : A → [593, 600] (7 s) ; B → [0, 6] (6 s).
        let c = IndexVideo.chapitres([Fixtures.evenement(a: 601)], fichiers: [fichierA, b])
        #expect(c.first?.indexFichier == 0)
        #expect(c.first?.duree == 7)
    }

    @Test("les segments ne fusionnent jamais entre deux fichiers")
    func segmentsParFichier() {
        let c = IndexVideo.chapitres(
            [Fixtures.evenement(a: 100), Fixtures.evenement(a: 800)],
            fichiers: [fichierA, fichierB])
        let s = PlanLecture.segments(c)
        #expect(s.map(\.indexFichier) == [0, 1])
        #expect(s.map(\.debut) == [92, 92])
    }

    @Test("manifeste v2 : aller-retour JSON à deux fichiers")
    func manifesteV2() throws {
        let m = try ManifesteVideoMatch(
            seanceID: UUID(), codeEquipe: "EQ1",
            fichiers: [FichierVideoMatch(alignement: fichierA, sourceAlignement: .metadonneeFichier),
                       FichierVideoMatch(alignement: fichierB, sourceAlignement: .automatique)],
            dateImport: Date(timeIntervalSince1970: 2_000_000))
        let relu = try ManifesteVideoMatch.decoder(m.encoder())
        #expect(relu == m)
        #expect(relu.versionSchema == 2)
        #expect(relu.alignements == [fichierA, fichierB])
    }

    @Test("manifeste v1 (un fichier à plat) relu en v2")
    func relectureV1() throws {
        let json = #"""
        {"versionSchema": 1, "seanceID": "\#(UUID().uuidString)", "nomFichierVideo": "match.mp4",
         "alignement": {"dateDebutVideo": 0, "dureeVideo": 90}, "sourceAlignement": "ancres",
         "ancres": [{"horodatage": 10, "instantVideo": 12}]}
        """#
        let m = try ManifesteVideoMatch.decoder(Data(json.utf8))
        #expect(m.fichiers.count == 1)
        #expect(m.nomFichierVideo == "match.mp4")
        #expect(m.sourceAlignement == .ancres)
        #expect(m.ancres.count == 1)
        #expect(m.versionSchema == ManifesteVideoMatch.versionSchemaActuelle)
    }

    @Test("un manifeste sans fichier est refusé")
    func sansFichier() {
        #expect(throws: ErreurManifeste.aucunFichier) {
            try ManifesteVideoMatch(seanceID: UUID(), codeEquipe: "", fichiers: [])
        }
        let json = #"{"seanceID": "\#(UUID().uuidString)", "fichiers": []}"#
        #expect(throws: ErreurManifeste.aucunFichier) {
            try ManifesteVideoMatch.decoder(Data(json.utf8))
        }
    }

    // MARK: - Stockage

    private func stockage() -> StockageVideoMatch {
        StockageVideoMatch(racine: FileManager.default.temporaryDirectory
            .appendingPathComponent("tests-multi-\(UUID().uuidString)", isDirectory: true))
    }

    private func source(_ contenu: String, _ ext: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("src-\(UUID().uuidString).\(ext)")
        try Data(contenu.utf8).write(to: url)
        return url
    }

    private func manifeste(_ id: UUID, fichiers: Int) throws -> ManifesteVideoMatch {
        try ManifesteVideoMatch(
            seanceID: id, codeEquipe: "EQ1",
            fichiers: (0..<fichiers).map { _ in FichierVideoMatch(alignement: fichierA, sourceAlignement: .manuel) })
    }

    @Test("import de deux fichiers puis ajout d'un troisième")
    func importEtAjout() throws {
        let s = stockage()
        let id = UUID()
        let m = try s.importer(videos: [source("A", "MOV"), source("B", "mp4")], manifeste: manifeste(id, fichiers: 2))
        #expect(m.fichiers.map(\.nomFichier) == ["match.mov", "match-2.mp4"])
        #expect(s.urlsVideos(seanceID: id).compactMap { $0 }.count == 2)

        let apres = try s.ajouter(video: source("C", "mov"),
                                  fichier: FichierVideoMatch(alignement: fichierB, sourceAlignement: .manuel),
                                  seanceID: id)
        #expect(apres.fichiers.map(\.nomFichier) == ["match.mov", "match-2.mp4", "match-3.mov"])
        let urls = s.urlsVideos(seanceID: id).compactMap { $0 }
        #expect(urls.count == 3)
        #expect(try Data(contentsOf: urls[2]) == Data("C".utf8))
        #expect(try s.manifeste(seanceID: id)?.fichiers.count == 3)
    }

    @Test("nombre de vidéos différent du manifeste : refusé")
    func nombreIncoherent() throws {
        #expect(throws: ErreurManifeste.nombreDeFichiersIncoherent) {
            try stockage().importer(videos: [source("A", "mov")], manifeste: manifeste(UUID(), fichiers: 2))
        }
    }

    @Test("ajouter à un match sans vidéo : erreur")
    func ajoutSansMatch() throws {
        let url = try source("A", "mov")
        #expect(throws: (any Error).self) {
            try stockage().ajouter(video: url,
                                   fichier: FichierVideoMatch(alignement: fichierA, sourceAlignement: .manuel),
                                   seanceID: UUID())
        }
    }

    @Test("jeu de données : chaque échantillon nomme son fichier")
    func jeuDonnees() throws {
        var m = try manifeste(UUID(), fichiers: 1)
        m.ajouter(FichierVideoMatch(nomFichier: "match-2.mov", alignement: fichierB, sourceAlignement: .manuel))
        m.consentementEntrainementIA = true
        let e = try JeuDonnees.echantillons(manifeste: m,
                                            evenements: [Fixtures.evenement(a: 100), Fixtures.evenement(a: 800)])
        #expect(e.map(\.fichierVideo) == ["match.mov", "match-2.mov"])
    }
}
