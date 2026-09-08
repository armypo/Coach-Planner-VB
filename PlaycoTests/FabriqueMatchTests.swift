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
            codeEquipe: Self.code, avant: nouveau.id,
            joueursValides: Set(joueurs))

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
            parmi: [autreEquipe, courant], codeEquipe: Self.code, avant: courant.id,
            joueursValides: [])

        #expect(compo == nil)
    }

    @Test("composition : les joueurs partis/indisponibles sont filtrés, un match futur est ignoré")
    func compositionValideeEtJamaisFuture() {
        let valide = UUID()
        let parti = UUID()

        let joue = Seance(nom: "vs J", date: Date(timeIntervalSinceNow: -86_400), typeSeance: .match)
        joue.codeEquipe = Self.code
        joue.partants = [PartantMatch(poste: 1, joueurID: valide),
                         PartantMatch(poste: 2, joueurID: parti)]
        joue.liberoID = parti.uuidString

        let futur = Seance(nom: "vs F", date: Date(timeIntervalSinceNow: 86_400), typeSeance: .match)
        futur.codeEquipe = Self.code
        futur.partants = [PartantMatch(poste: 1, joueurID: parti)]

        let nouveau = Seance(nom: "vs N", typeSeance: .match)
        nouveau.codeEquipe = Self.code

        let compo = FabriqueMatch.derniereComposition(
            parmi: [joue, futur, nouveau], codeEquipe: Self.code, avant: nouveau.id,
            joueursValides: [valide])

        #expect(compo?.partants.count == 1) // le joueur parti est filtré
        #expect(compo?.partants.first?.joueurID == valide)
        #expect(compo?.liberoID == "") // libéro parti → pas de libéro hérité
    }
}
