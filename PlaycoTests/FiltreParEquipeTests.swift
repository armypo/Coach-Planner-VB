//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//

import Testing
import Foundation
@testable import Playco

@Suite("FiltreParEquipe — scoping multi-équipes")
struct FiltreParEquipeTests {

    private func seance(nom: String, code: String) -> Seance {
        let s = Seance(nom: nom, date: .now, typeSeance: .pratique)
        s.codeEquipe = code
        return s
    }

    @Test("filtreEquipe retourne uniquement les éléments du codeEquipe actif")
    func filtreCodeActif() {
        let s1 = seance(nom: "P1", code: "AAAA2345")
        let s2 = seance(nom: "P2", code: "BBBB2345")
        let s3 = seance(nom: "P3", code: "AAAA2345")

        let resultat = [s1, s2, s3].filtreEquipe("AAAA2345")
        #expect(resultat.count == 2)
        #expect(resultat.allSatisfy { $0.codeEquipe == "AAAA2345" })
    }

    @Test("filtreEquipe inclut les éléments sans codeEquipe (legacy)")
    func filtreCodeVide() {
        let s1 = seance(nom: "Legacy", code: "")
        let s2 = seance(nom: "Active", code: "ZZZZ9876")
        let s3 = seance(nom: "Other", code: "XXXX5432")

        let resultat = [s1, s2, s3].filtreEquipe("ZZZZ9876")
        #expect(resultat.count == 2, "Legacy (vide) + équipe active")
        #expect(resultat.contains { $0.nom == "Legacy" })
        #expect(resultat.contains { $0.nom == "Active" })
        #expect(!resultat.contains { $0.nom == "Other" })
    }

    @Test("filtreEquipe avec code actif vide ne retourne que les vides")
    func filtreCodeActifVide() {
        let s1 = seance(nom: "A", code: "AAAA2345")
        let s2 = seance(nom: "Vide", code: "")

        let resultat = [s1, s2].filtreEquipe("")
        #expect(resultat.count == 1)
        #expect(resultat.first?.nom == "Vide")
    }

    @Test("filtreEquipe sur tableau vide retourne tableau vide")
    func filtreTableauVide() {
        let vide: [Seance] = []
        #expect(vide.filtreEquipe("ANY23456").isEmpty)
    }

    @Test("filtreEquipe préserve l'ordre original")
    func preserveOrdre() {
        let s1 = seance(nom: "Z", code: "AAAA2345")
        let s2 = seance(nom: "A", code: "AAAA2345")
        let s3 = seance(nom: "M", code: "AAAA2345")

        let resultat = [s1, s2, s3].filtreEquipe("AAAA2345")
        #expect(resultat.map(\.nom) == ["Z", "A", "M"])
    }

    @Test("FiltreParEquipe — JoueurEquipe conformance")
    func conformanceJoueur() {
        let j1 = JoueurEquipe(nom: "Dupont", prenom: "Alice", numero: 1, poste: .recepteur)
        j1.codeEquipe = "TEAMAAAA"
        let j2 = JoueurEquipe(nom: "Martin", prenom: "Bob", numero: 2, poste: .recepteur)
        j2.codeEquipe = "TEAMBBBB"

        let resultat = [j1, j2].filtreEquipe("TEAMAAAA")
        #expect(resultat.count == 1)
        #expect(resultat.first?.prenom == "Alice")
    }

    @Test("FiltreParEquipe — PointMatch conformance")
    func conformancePointMatch() {
        let p1 = PointMatch(seanceID: UUID(), set: 1, typeAction: .kill)
        p1.codeEquipe = "TEAM2345"
        let p2 = PointMatch(seanceID: UUID(), set: 1, typeAction: .killAdversaire)
        p2.codeEquipe = "TEAM6789"

        let resultat = [p1, p2].filtreEquipe("TEAM2345")
        #expect(resultat.count == 1)
    }
}
