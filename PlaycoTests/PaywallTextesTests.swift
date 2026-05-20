//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Tests pour les chaînes UI paywall v2.0.1. Garde-fous régression sur le
//  préfixe CTA (qui avait causé le bouton "S'abonner ·" tronqué en v2.0.0).
//

import Testing
import Foundation
@testable import Playco

@Suite("TextesPaywall — garde-fous v2.0.1")
struct PaywallTextesTests {

    @Test("ctaAchatPrefixe se termine par une espace pour concaténation displayPrice")
    func prefixeCTAEspace() {
        #expect(TextesPaywall.ctaAchatPrefixe.hasSuffix(" "))
        #expect(TextesPaywall.ctaAchatPrefixe.contains("·"))
    }

    @Test("ctaChoisirPlan est non vide et explicite")
    func ctaChoisirPlanExiste() {
        #expect(!TextesPaywall.ctaChoisirPlan.isEmpty)
        #expect(TextesPaywall.ctaChoisirPlan.count > 3)
    }

    @Test("ctaChargement et ctaReessayer définis")
    func ctaEtatsDefinis() {
        #expect(!TextesPaywall.ctaChargement.isEmpty)
        #expect(!TextesPaywall.ctaReessayer.isEmpty)
    }

    @Test("messages d'erreur restauration distinguent rien-à-restaurer vs réseau")
    func messagesErreurDistincts() {
        #expect(TextesPaywall.erreurAucunAchatARestaurer != TextesPaywall.erreurRestaurationReseau)
        #expect(TextesPaywall.erreurAucunAchatARestaurer.contains("restaurer"))
        #expect(TextesPaywall.erreurRestaurationReseau.contains("connexion") ||
                TextesPaywall.erreurRestaurationReseau.contains("Connexion"))
    }

    @Test("concaténation ctaAchatPrefixe + displayPrice forme une chaîne propre")
    func concatenationPropre() {
        let label = "\(TextesPaywall.ctaAchatPrefixe)14,99 $"
        #expect(label == "S'abonner · 14,99 $")
        #expect(!label.hasSuffix("·"))    // garde-fou contre B2
        #expect(!label.hasSuffix("· "))   // garde-fou contre B2
    }
}
