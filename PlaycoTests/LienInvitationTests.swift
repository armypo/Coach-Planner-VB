//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Tests 2.3 : lien universel d'invitation — construction, analyse stricte, QR.
//

import Testing
import Foundation
@testable import Playco

@Suite("LienInvitation — lien universel de jonction (2.3)")
struct LienInvitationTests {

    @Test("aller-retour : construire puis analyser rend les codes")
    func allerRetour() {
        let url = LienInvitation.construire(codeEquipe: "ELANS-7K2M", codeInvitation: "ABC123")
        #expect(url?.absoluteString == "https://playco.app/join/ELANS-7K2M/ABC123")
        let codes = LienInvitation.analyser(url!)
        #expect(codes?.codeEquipe == "ELANS-7K2M")
        #expect(codes?.codeInvitation == "ABC123")
    }

    @Test("hôte étranger, chemin incomplet ou trop profond : rejetés")
    func rejets() {
        #expect(LienInvitation.analyser(URL(string: "https://evil.com/join/A/B")!) == nil)
        #expect(LienInvitation.analyser(URL(string: "https://playco.app/join/SEUL")!) == nil)
        #expect(LienInvitation.analyser(URL(string: "https://playco.app/autre/A/B")!) == nil)
        #expect(LienInvitation.analyser(URL(string: "https://playco.app/join/A/B/C")!) == nil)
    }

    @Test("codes invalides (vides, trop longs, caractères hors jeu) : ni construits ni analysés")
    func codesInvalides() {
        #expect(LienInvitation.construire(codeEquipe: "", codeInvitation: "X") == nil)
        #expect(LienInvitation.construire(codeEquipe: String(repeating: "A", count: 40), codeInvitation: "X") == nil)
        #expect(LienInvitation.construire(codeEquipe: "A/B", codeInvitation: "X") == nil)
        #expect(LienInvitation.analyser(URL(string: "https://playco.app/join/A%20B/C")!) == nil)
    }

    @Test("le QR se génère pour des codes valides")
    func qr() {
        let image = LienInvitation.genererQR(codeEquipe: "EQ1", codeInvitation: "INV1", echelle: 4)
        #expect(image != nil)
        #expect((image?.size.width ?? 0) > 0)
    }
}
