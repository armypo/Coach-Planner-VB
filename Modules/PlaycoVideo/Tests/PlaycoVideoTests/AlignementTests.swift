//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//

import Foundation
import Testing
@testable import PlaycoVideo

@Suite("AlignementVideo — calage par ancres")
struct AlignementTests {

    private func ancre(reel: Double, video: Double) -> AncreAlignement {
        AncreAlignement(horodatage: Fixtures.debutVideo.addingTimeInterval(reel), instantVideo: video)
    }

    @Test("sans ancre : pas de calage")
    func sansAncre() {
        #expect(Fixtures.alignement().calee(sur: []) == nil)
    }

    @Test("une ancre corrige le décalage")
    func uneAncre() throws {
        let a = try #require(Fixtures.alignement().calee(sur: [ancre(reel: 100, video: 104.5)]))
        #expect(a.decalageSecondes == 4.5)
        #expect(a.facteurEchelle == 1)
        #expect(a.instantDansVideo(Fixtures.debutVideo.addingTimeInterval(300)) == 304.5)
    }

    @Test("ancres rapprochées : décalage seul, par la médiane (robuste à une ancre fausse)")
    func baseCourteMediane() throws {
        let a = try #require(Fixtures.alignement().calee(sur: [
            ancre(reel: 100, video: 103),
            ancre(reel: 150, video: 153),
            ancre(reel: 200, video: 230)   // ancre fausse
        ]))
        #expect(a.decalageSecondes == 3)
        #expect(a.facteurEchelle == 1)
    }

    @Test("ancres éloignées : décalage + dérive d'horloge")
    func deriveEstimee() throws {
        // Horloge caméra plus rapide de 200 ppm, décalage 2 s.
        let echelle = 1.0002
        let ancres = [0.0, 1800, 3600].map { ancre(reel: $0, video: echelle * $0 + 2) }
        let a = try #require(Fixtures.alignement(duree: 4000).calee(sur: ancres))
        #expect(abs(a.facteurEchelle - echelle) < 1e-9)
        #expect(abs(a.decalageSecondes - 2) < 1e-6)
        #expect(a.ecarts(ancres).allSatisfy { abs($0) < 1e-6 })
    }

    @Test("dérive implausible : rejetée, retour au décalage seul")
    func deriveImplausible() throws {
        // 1 % de dérive = ancre mal placée, pas une horloge.
        let ancres = [ancre(reel: 0, video: 0), ancre(reel: 1000, video: 1010)]
        let a = try #require(Fixtures.alignement(duree: 2000).calee(sur: ancres))
        #expect(a.facteurEchelle == 1)
        #expect(a.decalageSecondes == 5)
    }

    @Test("décodage tolérant : décalage et échelle absents prennent leurs défauts")
    func decodageTolerant() throws {
        let json = #"{"dateDebutVideo": 0, "dureeVideo": 120}"#
        let a = try JSONDecoder().decode(AlignementVideo.self, from: Data(json.utf8))
        #expect(a.decalageSecondes == 0)
        #expect(a.facteurEchelle == 1)
        #expect(a.dureeVideo == 120)
    }

    @Test("médiane : nombre pair et impair")
    func mediane() {
        #expect(AlignementVideo.mediane([3, 1, 2]) == 2)
        #expect(AlignementVideo.mediane([4, 1, 3, 2]) == 2.5)
        #expect(AlignementVideo.mediane([]) == 0)
    }
}
