//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Testing
import Foundation
@testable import Playco

@Suite("Equipe — génération et validation de code")
struct EquipeTests {

    @Test("genererCodeEquipe : format 8 caractères Base32 Crockford")
    func genererCodeEquipeFormat() {
        let code = Equipe.genererCodeEquipe()
        #expect(code.count == 8, "Code doit faire 8 caractères")
        let autorises = Set(Equipe.alphabetCodeEquipe)
        #expect(code.allSatisfy { autorises.contains($0) },
                "Code doit utiliser uniquement l'alphabet Base32 Crockford")
    }

    @Test("genererCodeEquipe : entropie suffisante (20 tirages uniques)")
    func genererCodeEquipeUnicite() {
        // 20 tirages successifs doivent être tous uniques (probabilité de collision
        // ~20²/2×31⁸ ≈ 2.3×10⁻¹⁰). Si on voit une collision, le CSPRNG est cassé.
        let codes = (0..<20).map { _ in Equipe.genererCodeEquipe() }
        #expect(Set(codes).count == 20, "20 codes doivent être tous uniques")
    }

    @Test("normaliserCodeEquipe : filtre alphabet + uppercase")
    func normaliserCodeEquipe() {
        #expect(Equipe.normaliserCodeEquipe("abcd2345") == "ABCD2345",
                "Doit passer en majuscules")
        #expect(Equipe.normaliserCodeEquipe("ab-cd 23 45") == "ABCD2345",
                "Doit filtrer espaces et tirets")
        #expect(Equipe.normaliserCodeEquipe("0O1IL") == "",
                "Doit filtrer les caractères ambigus (0/O/1/I/L)")
        #expect(Equipe.normaliserCodeEquipe("abcd23456789extra") == "ABCD23456789EXTRA",
                "Ne tronque pas — c'est l'UI qui limite à 8")
    }

    @Test("codeEquipeValide : accepte exactement 8 chars alphabet autorisé")
    func codeEquipeValideAccepte() {
        #expect(Equipe.codeEquipeValide("ABCD2345"))
        #expect(Equipe.codeEquipeValide("XYZ23456"))
        // Tous chiffres autorisés
        #expect(Equipe.codeEquipeValide("23456789"))
    }

    @Test("codeEquipeValide : refuse longueur ≠ 8 ou caractères interdits")
    func codeEquipeValideRefuse() {
        #expect(!Equipe.codeEquipeValide(""), "vide")
        #expect(!Equipe.codeEquipeValide("ABC2345"), "7 chars")
        #expect(!Equipe.codeEquipeValide("ABCD23456"), "9 chars")
        #expect(!Equipe.codeEquipeValide("ABCD0345"), "contient '0'")
        #expect(!Equipe.codeEquipeValide("ABCDO345"), "contient 'O'")
        #expect(!Equipe.codeEquipeValide("ABCD1345"), "contient '1'")
        #expect(!Equipe.codeEquipeValide("ABCDI345"), "contient 'I'")
        #expect(!Equipe.codeEquipeValide("ABCDL345"), "contient 'L'")
        #expect(!Equipe.codeEquipeValide("abcd2345"), "minuscules refusées")
    }
}
