//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Tests 2.4 (Mat Nuit, étape A) : les contrastes WCAG des tokens sont un
//  CONTRAT — toute dérive des hex casse la suite (lois 5/10 exécutables).
//

import Testing
import Foundation
@testable import Playco

@Suite("Mat Nuit — contrastes WCAG des tokens (2.4)")
struct MatNuitTests {

    /// Luminance relative WCAG 2.1 d'un hex "#RRGGBB".
    private func luminance(_ hex: String) -> Double {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        func canal(_ i: Int) -> Double {
            let debut = h.index(h.startIndex, offsetBy: i * 2)
            let valeur = Double(Int(h[debut..<h.index(debut, offsetBy: 2)], radix: 16) ?? 0) / 255
            return valeur <= 0.03928 ? valeur / 12.92 : pow((valeur + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * canal(0) + 0.7152 * canal(1) + 0.0722 * canal(2)
    }

    private func contraste(_ a: String, _ b: String) -> Double {
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    @Test("l'encre principale atteint AAA (≥ 7:1) sur la nuit")
    func encreSurNuit() {
        #expect(contraste(MatNuit.encreHex, MatNuit.fondHex) >= 7.0)
        #expect(contraste(MatNuit.encre2Hex, MatNuit.fondHex) >= 4.5)
    }

    @Test("les 5 tons d'espace tiennent ≥ 4,5:1 sur la nuit")
    func tonsSurNuit() {
        for ton in [MatNuit.terreHex, MatNuit.briqueHex, MatNuit.ardoiseHex,
                    MatNuit.saugeHex, MatNuit.lavandeHex] {
            #expect(contraste(ton, MatNuit.fondHex) >= 4.5, "ton \(ton) sous 4,5:1")
        }
    }

    @Test("les sémantiques (live, deltas) tiennent ≥ 4,5:1 sur la nuit")
    func semantiquesSurNuit() {
        for hex in [MatNuit.liveHex, MatNuit.deltaPositifHex, MatNuit.deltaNegatifHex] {
            #expect(contraste(hex, MatNuit.fondHex) >= 4.5, "\(hex) sous 4,5:1")
        }
    }

    @Test("encre3 est bien SOUS 4,5:1 — décoratif seulement, jamais porteur d'information")
    func encre3Decoratif() {
        #expect(contraste(MatNuit.encre3Hex, MatNuit.fondHex) < 4.5)
    }

    @Test("la teinte de verre d'espace est plafonnée à 12 % (loi 4)")
    func teinteVerrePlafonnee() {
        #expect(MatNuit.teinteVerreMax <= 0.12)
    }
}
