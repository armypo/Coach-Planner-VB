//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//

import Foundation
import Testing
@testable import PlaycoVideo

/// Fabrique d'événements de test (instants relatifs au début de la vidéo).
enum Fixtures {
    static let debutVideo = Date(timeIntervalSince1970: 1_000_000)

    static func evenement(
        a secondes: Double,
        etiquette: String = "Kill",
        resultat: ResultatEvenement? = .pourNous,
        joueurID: UUID? = nil,
        periode: Int = 1,
        rotation: Int? = 1,
        auService: Bool? = true
    ) -> EvenementMatch {
        EvenementMatch(
            horodatage: debutVideo.addingTimeInterval(secondes),
            etiquette: etiquette,
            resultat: resultat,
            joueurID: joueurID,
            periode: periode,
            rotation: rotation,
            auService: auService
        )
    }

    static func alignement(duree: Double = 600, decalage: Double = 0) -> AlignementVideo {
        AlignementVideo(dateDebutVideo: debutVideo, decalageSecondes: decalage, dureeVideo: duree)
    }
}

@Suite("IndexVideo — chapitres")
struct ChapitresTests {

    @Test("instantDansVideo applique le décalage")
    func instantAvecDecalage() {
        let a = Fixtures.alignement(decalage: -2.5)
        #expect(a.instantDansVideo(Fixtures.debutVideo.addingTimeInterval(100)) == 97.5)
    }

    @Test("fenêtre par défaut : 8 s avant le tap, 3 s après")
    func fenetreParDefaut() {
        let c = IndexVideo.chapitres([Fixtures.evenement(a: 100)], alignement: Fixtures.alignement())
        #expect(c.count == 1)
        #expect(c[0].instant == 100)
        #expect(c[0].debut == 92)
        #expect(c[0].fin == 103)
    }

    @Test("le clip est borné à [0, durée]")
    func bornes() {
        let c = IndexVideo.chapitres(
            [Fixtures.evenement(a: 3), Fixtures.evenement(a: 599)],
            alignement: Fixtures.alignement(duree: 600))
        #expect(c.map(\.debut) == [0, 591])
        #expect(c.map(\.fin) == [6, 600])
    }

    @Test("un événement saisi hors de l'enregistrement est écarté")
    func horsVideo() {
        let c = IndexVideo.chapitres(
            [Fixtures.evenement(a: -30), Fixtures.evenement(a: 650), Fixtures.evenement(a: 50)],
            alignement: Fixtures.alignement(duree: 600))
        #expect(c.map(\.instant) == [50])
    }

    @Test("un tap juste après la fin garde le rallye filmé")
    func tapApresFin() {
        let c = IndexVideo.chapitres([Fixtures.evenement(a: 605)], alignement: Fixtures.alignement(duree: 600))
        #expect(c.count == 1)
        #expect(c[0].debut == 597)
        #expect(c[0].fin == 600)
    }

    @Test("les chapitres sont triés chronologiquement")
    func tri() {
        let c = IndexVideo.chapitres(
            [Fixtures.evenement(a: 300), Fixtures.evenement(a: 100), Fixtures.evenement(a: 200)],
            alignement: Fixtures.alignement())
        #expect(c.map(\.instant) == [100, 200, 300])
    }

    @Test("une fenêtre personnalisée est respectée")
    func fenetrePersonnalisee() {
        let fenetre = FenetreClip(avant: 12, apres: 1, dureeMinimale: 2)
        let c = IndexVideo.chapitres([Fixtures.evenement(a: 100)], alignement: Fixtures.alignement(), fenetre: fenetre)
        #expect(c[0].debut == 88)
        #expect(c[0].fin == 101)
    }
}

@Suite("IndexVideo — filtres")
struct FiltresTests {

    private func chapitres(_ evenements: [EvenementMatch]) -> [ChapitreVideo] {
        IndexVideo.chapitres(evenements, alignement: Fixtures.alignement())
    }

    @Test("étiquettes et joueur")
    func etiquettesJoueur() {
        let joueur = UUID()
        let c = chapitres([
            Fixtures.evenement(a: 10, etiquette: "Kill", joueurID: joueur),
            Fixtures.evenement(a: 20, etiquette: "Kill"),
            Fixtures.evenement(a: 30, etiquette: "Ace", joueurID: joueur)
        ])
        let filtre = FiltreChapitres(etiquettes: ["Kill"], joueurID: joueur)
        #expect(IndexVideo.playlist(c, filtre: filtre).map(\.instant) == [10])
    }

    @Test("sideouts ratés : en réception ET point contre nous")
    func sideoutsRates() {
        let c = chapitres([
            Fixtures.evenement(a: 10, etiquette: "Kill adv.", resultat: .contreNous, auService: false),
            Fixtures.evenement(a: 20, etiquette: "Kill", resultat: .pourNous, auService: false),
            Fixtures.evenement(a: 30, etiquette: "Err. service", resultat: .contreNous, auService: true)
        ])
        let filtre = FiltreChapitres(resultat: .contreNous, phase: .enReception)
        #expect(IndexVideo.playlist(c, filtre: filtre).map(\.instant) == [10])
    }

    @Test("période et rotation")
    func periodeRotation() {
        let c = chapitres([
            Fixtures.evenement(a: 10, periode: 1, rotation: 4),
            Fixtures.evenement(a: 20, periode: 2, rotation: 4),
            Fixtures.evenement(a: 30, periode: 2, rotation: 1)
        ])
        let filtre = FiltreChapitres(periode: 2, rotation: 4)
        #expect(IndexVideo.playlist(c, filtre: filtre).map(\.instant) == [20])
    }

    @Test("une information inconnue n'est jamais devinée")
    func inconnuJamaisDevine() {
        let c = chapitres([Fixtures.evenement(a: 10, resultat: nil, auService: nil)])
        #expect(IndexVideo.playlist(c, filtre: FiltreChapitres()).count == 1)
        #expect(IndexVideo.playlist(c, filtre: FiltreChapitres(resultat: .pourNous)).isEmpty)
        #expect(IndexVideo.playlist(c, filtre: FiltreChapitres(phase: .auService)).isEmpty)
        #expect(IndexVideo.playlist(c, filtre: FiltreChapitres(phase: .enReception)).isEmpty)
    }
}

@Suite("PlanLecture — segments")
struct SegmentsTests {

    @Test("les clips qui se chevauchent fusionnent en un segment")
    func fusion() {
        // Clips [92,103] et [97,108] se chevauchent ; [192,203] est isolé.
        let c = IndexVideo.chapitres(
            [Fixtures.evenement(a: 100), Fixtures.evenement(a: 105), Fixtures.evenement(a: 200)],
            alignement: Fixtures.alignement())
        let s = PlanLecture.segments(c)
        #expect(s.count == 2)
        #expect(s[0].debut == 92)
        #expect(s[0].fin == 108)
        #expect(s[0].chapitres == [c[0].id, c[1].id])
        #expect(s[1].chapitres == [c[2].id])
        #expect(PlanLecture.dureeTotale(s) == 16 + 11)
    }

    @Test("un écart inférieur au seuil de fusion est comblé")
    func ecartComble() {
        // Clips [92,103] et [103.5,114.5] : écart 0,5 s < 1 s.
        let c = IndexVideo.chapitres(
            [Fixtures.evenement(a: 100), Fixtures.evenement(a: 111.5)],
            alignement: Fixtures.alignement())
        #expect(PlanLecture.segments(c, ecartFusion: 1).count == 1)
        #expect(PlanLecture.segments(c, ecartFusion: 0).count == 2)
    }

    @Test("aucun chapitre : aucun segment")
    func vide() {
        #expect(PlanLecture.segments([]).isEmpty)
    }
}
