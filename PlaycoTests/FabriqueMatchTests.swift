//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Tests 2.3.2 : match éclair, promotion MatchCalendrier→Seance,
//  composition persistante (dernier 6 de départ).
//

import Testing
import Foundation
@testable import Playco

@Suite("FabriqueMatch — éclair, promotion, composition persistante (2.3.2)")
@MainActor
struct FabriqueMatchTests {

    private static let code = "EQ_FABRIQUE"

    @Test("match éclair : 2 champs suffisent, match bien formé")
    func matchEclair() {
        let m = FabriqueMatch.matchEclair(adversaire: "Sherbrooke", nousServons: false, codeEquipe: Self.code)
        #expect(m.estMatch)
        #expect(m.adversaire == "Sherbrooke")
        #expect(m.nom == "vs Sherbrooke")
        #expect(m.nousServonsEnPremier == false)
        #expect(m.codeEquipe == Self.code)
        #expect(m.matchCalendrierID.isEmpty)
    }

    @Test("match éclair sans adversaire : nom de repli, pas de nom vide")
    func matchEclairSansAdversaire() {
        let m = FabriqueMatch.matchEclair(adversaire: "  ", nousServons: true, codeEquipe: Self.code)
        #expect(m.nom == "Match éclair")
        #expect(m.adversaire.isEmpty)
    }

    @Test("promotion : copie adversaire/lieu/date et pose la trace anti-doublon")
    func promotion() {
        let mc = MatchCalendrier(date: Date(timeIntervalSince1970: 1_000_000), adversaire: "Lévis")
        mc.lieu = "Gymnase A"
        mc.codeEquipe = Self.code

        let m = FabriqueMatch.promouvoir(mc, codeEquipe: Self.code)

        #expect(m.estMatch)
        #expect(m.adversaire == "Lévis")
        #expect(m.lieu == "Gymnase A")
        #expect(m.date == mc.date)
        #expect(m.matchCalendrierID == mc.id.uuidString)
        #expect(FabriqueMatch.dejaPromu(mc, parmi: [m]))

        let autre = MatchCalendrier(date: Date(), adversaire: "Québec")
        #expect(!FabriqueMatch.dejaPromu(autre, parmi: [m]))
    }

    @Test("composition persistante : le match le plus récent AVEC partants gagne")
    func derniereComposition() {
        let joueurs = (1...6).map { _ in UUID() }

        let vieux = Seance(nom: "vs A", date: Date(timeIntervalSince1970: 1_000), typeSeance: .match)
        vieux.codeEquipe = Self.code
        vieux.partants = (1...6).map { PartantMatch(poste: $0, joueurID: joueurs[$0 - 1]) }

        let recentSansCompo = Seance(nom: "vs B", date: Date(timeIntervalSince1970: 5_000), typeSeance: .match)
        recentSansCompo.codeEquipe = Self.code

        let recent = Seance(nom: "vs C", date: Date(timeIntervalSince1970: 3_000), typeSeance: .match)
        recent.codeEquipe = Self.code
        recent.partants = (1...6).map { PartantMatch(poste: $0, joueurID: joueurs[(($0) % 6)]) }
        recent.liberoID = joueurs[0].uuidString

        let nouveau = Seance(nom: "vs D", typeSeance: .match)
        nouveau.codeEquipe = Self.code

        let compo = FabriqueMatch.derniereComposition(
            parmi: [vieux, recentSansCompo, recent, nouveau],
            codeEquipe: Self.code, avant: nouveau.id)

        #expect(compo != nil)
        #expect(compo?.partants.count == 6)
        #expect(compo?.partants.first(where: { $0.poste == 1 })?.joueurID == joueurs[1]) // celle de « vs C »
        #expect(compo?.liberoID == joueurs[0].uuidString)
    }

    @Test("composition persistante : autre équipe et match courant exclus")
    func derniereCompositionScopee() {
        let autreEquipe = Seance(nom: "vs X", typeSeance: .match)
        autreEquipe.codeEquipe = "AUTRE"
        autreEquipe.partants = [PartantMatch(poste: 1, joueurID: UUID())]

        let courant = Seance(nom: "vs Y", typeSeance: .match)
        courant.codeEquipe = Self.code
        courant.partants = [PartantMatch(poste: 1, joueurID: UUID())]

        let compo = FabriqueMatch.derniereComposition(
            parmi: [autreEquipe, courant], codeEquipe: Self.code, avant: courant.id)

        #expect(compo == nil)
    }
}
