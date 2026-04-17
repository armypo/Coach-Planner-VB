//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Testing
import Foundation
import CryptoKit
@testable import Playco

@Suite("KeyDerivation — PBKDF2 + legacy SHA256 + constant-time")
struct KeyDerivationTests {

    @Test("genererSel : 32 chars hex uniques")
    func genererSelFormat() {
        let sel1 = KeyDerivation.genererSel()
        let sel2 = KeyDerivation.genererSel()
        #expect(sel1.count == 32, "16 bytes → 32 hex chars")
        #expect(sel1 != sel2, "CSPRNG doit donner des valeurs différentes")
        #expect(sel1.allSatisfy { $0.isHexDigit }, "uniquement caractères hex")
    }

    @Test("hashPBKDF2 : déterministe + 64 chars hex")
    func hashPBKDF2Deterministe() {
        let sel = "7f3a9b21d4c6e8f05a1b3c2d4e5f6789"
        let h1 = KeyDerivation.hashPBKDF2("MonSuperMotDePasse12", sel: sel)
        let h2 = KeyDerivation.hashPBKDF2("MonSuperMotDePasse12", sel: sel)
        #expect(h1 == h2, "PBKDF2 déterministe pour mêmes inputs")
        #expect(h1.count == 64, "32 bytes → 64 hex chars")
        #expect(h1 != sel, "output ≠ input")
    }

    @Test("deriverCle : iterations différent → hash différent")
    func deriverCleIterationsDifferent() {
        let h1 = KeyDerivation.deriverCle(motDePasse: "pass12345678", sel: "sel", iterations: 1000)
        let h2 = KeyDerivation.deriverCle(motDePasse: "pass12345678", sel: "sel", iterations: 2000)
        #expect(h1 != h2, "iterations différent doit produire des hash différents")
    }

    @Test("deriverCle : mot de passe vide retourne string vide (refus)")
    func deriverCleMotDePasseVide() {
        let result = KeyDerivation.deriverCle(motDePasse: "", sel: "sel", iterations: 600_000)
        #expect(result.isEmpty, "Garde-fou : mot de passe vide rejeté")
    }

    @Test("verifier : chemin legacy SHA256 brut (sel absent)")
    func verifierLegacySHA256SansSel() {
        let motDePasse = "passwordv0"
        let hash = SHA256.hash(data: Data(motDePasse.utf8))
            .compactMap { String(format: "%02x", $0) }.joined()

        #expect(KeyDerivation.verifier(motDePasse, hash: hash, sel: nil, iterations: 1))
        #expect(KeyDerivation.verifier(motDePasse, hash: hash, sel: "", iterations: 1))
        #expect(!KeyDerivation.verifier("wrong", hash: hash, sel: nil, iterations: 1))
    }

    @Test("verifier : chemin legacy SHA256+sel (iterations ≤ 1)")
    func verifierLegacySHA256AvecSel() {
        let motDePasse = "passwordv19"
        let sel = "abc123def456"
        let hash = SHA256.hash(data: Data((sel + motDePasse).utf8))
            .compactMap { String(format: "%02x", $0) }.joined()

        #expect(KeyDerivation.verifier(motDePasse, hash: hash, sel: sel, iterations: 1))
        #expect(!KeyDerivation.verifier("wrong", hash: hash, sel: sel, iterations: 1))
    }

    @Test("verifier : chemin PBKDF2 (iterations ≥ 2)")
    func verifierPBKDF2() {
        let motDePasse = "securePassword123"
        let sel = KeyDerivation.genererSel()
        let hash = KeyDerivation.deriverCle(motDePasse: motDePasse, sel: sel, iterations: 1000)

        #expect(KeyDerivation.verifier(motDePasse, hash: hash, sel: sel, iterations: 1000))
        #expect(!KeyDerivation.verifier("wrong", hash: hash, sel: sel, iterations: 1000))
        // Wrong iterations → wrong hash → refusé
        #expect(!KeyDerivation.verifier(motDePasse, hash: hash, sel: sel, iterations: 2000))
    }

    @Test("egaliteConstante : vraies strings égales, différentes longueurs refusées")
    func egaliteConstanteBasics() {
        #expect(KeyDerivation.egaliteConstante("abc", "abc"))
        #expect(!KeyDerivation.egaliteConstante("abc", "abd"))
        #expect(!KeyDerivation.egaliteConstante("abc", "abcd"), "Longueurs différentes")
        #expect(KeyDerivation.egaliteConstante("", ""), "Strings vides égales")
        #expect(!KeyDerivation.egaliteConstante("abc", ""), "Vide vs non-vide")
    }
}
