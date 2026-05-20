//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Tests pour le champ `Abonnement.codeEquipe` ajouté en v2.0.1 — permet
//  le fallback CloudKit Public DB quand le coach se reconnecte avec un
//  Apple ID différent.
//

import Testing
import Foundation
@testable import Playco

@Suite("Abonnement — scoping codeEquipe")
struct AbonnementCodeEquipeTests {

    @Test("init par défaut laisse codeEquipe vide")
    func codeEquipeDefautVide() {
        let abo = Abonnement(utilisateurID: UUID())
        #expect(abo.codeEquipe.isEmpty)
    }

    @Test("init avec codeEquipe le persiste")
    func codeEquipePersisteAuInit() {
        let abo = Abonnement(utilisateurID: UUID(), codeEquipe: "EQU-XYZ")
        #expect(abo.codeEquipe == "EQU-XYZ")
    }

    @Test("codeEquipe modifiable après init")
    func codeEquipeMutable() {
        let abo = Abonnement(utilisateurID: UUID())
        abo.codeEquipe = "EQU-MODIF"
        #expect(abo.codeEquipe == "EQU-MODIF")
    }

    @Test("tier et type initialisés correctement")
    func tierEtTypeInit() {
        let abo = Abonnement(utilisateurID: UUID(),
                             codeEquipe: "EQU-1",
                             tier: .pro,
                             type: .annuel,
                             produitIAPID: IdentifiantsIAP.proAnnuel,
                             appStoreTransactionID: "tx-123",
                             dateExpiration: .distantFuture)
        #expect(abo.tier == .pro)
        #expect(abo.type == .annuel)
        #expect(abo.codeEquipe == "EQU-1")
        #expect(abo.produitIAPID == IdentifiantsIAP.proAnnuel)
    }
}
