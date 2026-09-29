//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Tests de l'index vidéo ↔ stats live et du stockage local (vidéo phase 1,
//  flag VIDEO — compilés en Debug seulement).
//

#if VIDEO
import Testing
import Foundation
@testable import Playco

@Suite("IndexVideoMatch — chapitres, filtres, alignement")
struct IndexVideoMatchTests {

    private let debutVideo = Date(timeIntervalSince1970: 1_000_000)

    private func point(
        a secondes: Double,
        type: TypeActionPoint = .kill,
        joueurID: UUID? = nil,
        set: Int = 1,
        rotation: Int = 1,
        nousServions: Bool = true
    ) -> PointIndexable {
        PointIndexable(
            pointID: UUID(),
            horodatage: debutVideo.addingTimeInterval(secondes),
            set: set,
            typeActionRaw: type.rawValue,
            joueurID: joueurID,
            rotation: rotation,
            rotationAdversaire: 1,
            zone: 0,
            zoneDepart: 0,
            nousServions: nousServions,
            serviceRenseigne: true
        )
    }

    private func alignement(duree: Double = 600, decalage: Double = 0) -> AlignementVideo {
        AlignementVideo(dateDebutVideo: debutVideo, decalageSecondes: decalage, dureeVideo: duree)
    }

    // MARK: - Alignement

    @Test("instantDansVideo applique le décalage manuel")
    func instantAvecDecalage() {
        let a = alignement(decalage: -2.5)
        #expect(a.instantDansVideo(debutVideo.addingTimeInterval(100)) == 97.5)
    }

    // MARK: - Chapitres

    @Test("fenêtre : 8 s avant le tap, 3 s après")
    func fenetreParDefaut() {
        let chapitres = IndexVideoMatch.chapitres(points: [point(a: 100)], alignement: alignement())
        #expect(chapitres.count == 1)
        #expect(chapitres[0].instant == 100)
        #expect(chapitres[0].debut == 92)
        #expect(chapitres[0].fin == 103)
    }

    @Test("bornes : le clip est borné à [0, durée]")
    func bornesClampees() {
        let chapitres = IndexVideoMatch.chapitres(
            points: [point(a: 3), point(a: 599)], alignement: alignement(duree: 600))
        #expect(chapitres.map(\.debut) == [0, 591])
        #expect(chapitres.map(\.fin) == [6, 600])
    }

    @Test("un point saisi hors de l'enregistrement est écarté")
    func horsVideoEcarte() {
        let chapitres = IndexVideoMatch.chapitres(
            points: [point(a: -30), point(a: 650), point(a: 50)],
            alignement: alignement(duree: 600))
        #expect(chapitres.map(\.instant) == [50])
    }

    @Test("un tap juste après la fin garde le rallye filmé")
    func tapApresFinConserve() {
        // Rallye filmé [597, 600], tap à 605 : 3 s ≥ durée minimale (2 s).
        let chapitres = IndexVideoMatch.chapitres(
            points: [point(a: 605)], alignement: alignement(duree: 600))
        #expect(chapitres.count == 1)
        #expect(chapitres[0].debut == 597)
        #expect(chapitres[0].fin == 600)
    }

    @Test("les chapitres sont triés par horodatage")
    func triChronologique() {
        let chapitres = IndexVideoMatch.chapitres(
            points: [point(a: 300), point(a: 100), point(a: 200)], alignement: alignement())
        #expect(chapitres.map(\.instant) == [100, 200, 300])
    }

    // MARK: - Filtres

    @Test("filtre par types et par joueur")
    func filtreTypesJoueur() {
        let joueur = UUID()
        let points = [
            point(a: 10, type: .kill, joueurID: joueur),
            point(a: 20, type: .kill),
            point(a: 30, type: .ace, joueurID: joueur)
        ]
        let chapitres = IndexVideoMatch.chapitres(points: points, alignement: alignement())
        var filtre = FiltreChapitres()
        filtre.types = [.kill]
        filtre.joueurID = joueur
        #expect(IndexVideoMatch.playlist(chapitres, filtre: filtre).map(\.instant) == [10])
    }

    @Test("sideouts ratés : en réception ET point contre nous")
    func filtreSideoutsRates() {
        let points = [
            point(a: 10, type: .killAdversaire, nousServions: false),  // sideout raté
            point(a: 20, type: .kill, nousServions: false),            // sideout réussi
            point(a: 30, type: .erreurService, nousServions: true)     // au service
        ]
        let chapitres = IndexVideoMatch.chapitres(points: points, alignement: alignement())
        var filtre = FiltreChapitres()
        filtre.phase = .enReception
        filtre.resultat = .contreNous
        #expect(IndexVideoMatch.playlist(chapitres, filtre: filtre).map(\.instant) == [10])
    }

    @Test("filtre par set et rotation")
    func filtreSetRotation() {
        let points = [
            point(a: 10, set: 1, rotation: 4),
            point(a: 20, set: 2, rotation: 4),
            point(a: 30, set: 2, rotation: 1)
        ]
        let chapitres = IndexVideoMatch.chapitres(points: points, alignement: alignement())
        var filtre = FiltreChapitres()
        filtre.set = 2
        filtre.rotation = 4
        #expect(IndexVideoMatch.playlist(chapitres, filtre: filtre).map(\.instant) == [20])
    }

    @Test("type inconnu : gardé sans filtre, exclu dès qu'un filtre de résultat ou de type s'applique")
    func typeInconnuJamaisDevine() {
        var inconnu = point(a: 10)
        inconnu.typeActionRaw = "Type futur"
        let chapitres = IndexVideoMatch.chapitres(points: [inconnu], alignement: alignement())
        #expect(inconnu.typeAction == nil)
        #expect(IndexVideoMatch.playlist(chapitres, filtre: FiltreChapitres()).count == 1)

        var parResultat = FiltreChapitres()
        parResultat.resultat = .pourNous
        #expect(IndexVideoMatch.playlist(chapitres, filtre: parResultat).isEmpty)

        var parType = FiltreChapitres()
        parType.types = [.kill]
        #expect(IndexVideoMatch.playlist(chapitres, filtre: parType).isEmpty)
    }

    // MARK: - Depuis les PointMatch

    @Test("points(depuis:) reconstruit le contexte de service des points legacy")
    func pointsDepuisPointMatch() {
        let seance = Seance(nom: "Match test", typeSeance: .match)
        seance.nousServonsEnPremier = true
        let premier = PointMatch(seanceID: seance.id, set: 1, typeAction: .killAdversaire)
        premier.horodatage = debutVideo
        let second = PointMatch(seanceID: seance.id, set: 1, typeAction: .kill)
        second.horodatage = debutVideo.addingTimeInterval(30)

        let points = IndexVideoMatch.points(depuis: [premier, second], seance: seance)

        // Set 1, nous servons en premier ; l'adversaire gagne le 1er rallye → il sert le 2e.
        #expect(points.map(\.nousServions) == [true, false])
        #expect(points.allSatisfy { !$0.serviceRenseigne })
        #expect(points.map(\.pointID) == [premier.id, second.id])
    }
}

@Suite("VideoMatchStore — stockage local")
struct VideoMatchStoreTests {

    private func storeIsole() -> VideoMatchStore {
        let racine = FileManager.default.temporaryDirectory
            .appendingPathComponent("tests-video-\(UUID().uuidString)", isDirectory: true)
        return VideoMatchStore(racine: racine)
    }

    private func fichierVideo(_ contenu: String, extension ext: String = "MOV") throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("source-\(UUID().uuidString).\(ext)")
        try Data(contenu.utf8).write(to: url)
        return url
    }

    private func manifeste(seanceID: UUID) -> ManifesteVideoMatch {
        ManifesteVideoMatch(
            seanceID: seanceID,
            codeEquipe: "EQ1",
            alignement: AlignementVideo(dateDebutVideo: Date(timeIntervalSince1970: 1_000_000), dureeVideo: 600),
            sourceAlignement: .metadonneeFichier,
            dateImport: Date(timeIntervalSince1970: 2_000_000)
        )
    }

    @Test("importer copie la vidéo et relit le manifeste")
    func importerPuisRelire() throws {
        let store = storeIsole()
        let id = UUID()

        let importe = try store.importer(videoSource: try fichierVideo("A"), manifeste: manifeste(seanceID: id))

        #expect(importe.nomFichierVideo == "match.mov")
        #expect(store.manifeste(seanceID: id) == importe)
        let url = try #require(store.urlVideo(seanceID: id))
        #expect(try Data(contentsOf: url) == Data("A".utf8))
    }

    @Test("le consentement d'entraînement IA est NON par défaut")
    func consentementIANonParDefaut() {
        #expect(manifeste(seanceID: UUID()).consentementEntrainementIA == false)
    }

    @Test("réimporter remplace la vidéo du match")
    func reimporterRemplace() throws {
        let store = storeIsole()
        let id = UUID()
        try store.importer(videoSource: try fichierVideo("A"), manifeste: manifeste(seanceID: id))
        try store.importer(videoSource: try fichierVideo("B", extension: "mp4"), manifeste: manifeste(seanceID: id))

        let url = try #require(store.urlVideo(seanceID: id))
        #expect(url.lastPathComponent == "match.mp4")
        #expect(try Data(contentsOf: url) == Data("B".utf8))
    }

    @Test("un import échoué ne détruit pas la vidéo en place")
    func importEchoueConserveLExistant() throws {
        let store = storeIsole()
        let id = UUID()
        try store.importer(videoSource: try fichierVideo("A"), manifeste: manifeste(seanceID: id))
        let absente = FileManager.default.temporaryDirectory.appendingPathComponent("absente-\(UUID().uuidString).mov")

        #expect(throws: (any Error).self) {
            try store.importer(videoSource: absente, manifeste: manifeste(seanceID: id))
        }
        let url = try #require(store.urlVideo(seanceID: id))
        #expect(try Data(contentsOf: url) == Data("A".utf8))
    }

    @Test("enregistrer persiste une correction d'alignement")
    func enregistrerCorrection() throws {
        let store = storeIsole()
        let id = UUID()
        var m = try store.importer(videoSource: try fichierVideo("A"), manifeste: manifeste(seanceID: id))
        m.alignement.decalageSecondes = -1.5
        m.sourceAlignement = .manuel

        try store.enregistrer(m)

        #expect(store.manifeste(seanceID: id)?.alignement.decalageSecondes == -1.5)
        #expect(store.manifeste(seanceID: id)?.sourceAlignement == .manuel)
    }

    @Test("un nom de fichier altéré ne sort jamais du dossier du match")
    func nomFichierAltere() throws {
        let store = storeIsole()
        let id = UUID()
        var m = try store.importer(videoSource: try fichierVideo("A"), manifeste: manifeste(seanceID: id))
        m.nomFichierVideo = "../../match.mov"
        try store.enregistrer(m)

        let url = try #require(store.urlVideo(seanceID: id))
        #expect(url.deletingLastPathComponent().standardizedFileURL == store.dossier(seanceID: id).standardizedFileURL)
    }

    @Test("supprimer retire la vidéo ; no-op si absente")
    func supprimer() throws {
        let store = storeIsole()
        let id = UUID()
        try store.importer(videoSource: try fichierVideo("A"), manifeste: manifeste(seanceID: id))

        try store.supprimer(seanceID: id)
        try store.supprimer(seanceID: id)

        #expect(store.manifeste(seanceID: id) == nil)
        #expect(store.urlVideo(seanceID: id) == nil)
    }
}
#endif
