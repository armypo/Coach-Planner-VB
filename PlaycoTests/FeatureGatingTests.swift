//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Tests de la décision pure `paywallDoitBloquer` (v2.0.1) — garantit que
//  les athlètes et assistants ne sont JAMAIS bloqués par le paywall du coach.
//

import Testing
@testable import Playco

@Suite("FeatureGating — gate paywall role-aware")
struct FeatureGatingTests {

    // MARK: - Rôle payeur (.coach / .admin)

    @Test("Coach sans abonnement → bloqué")
    func coachSansAboBloque() {
        #expect(paywallDoitBloquer(role: .coach, peutEcrire: false) == true)
    }

    @Test("Admin sans abonnement → bloqué")
    func adminSansAboBloque() {
        #expect(paywallDoitBloquer(role: .admin, peutEcrire: false) == true)
    }

    @Test("Coach avec abonnement → autorisé")
    func coachAvecAboAutorise() {
        #expect(paywallDoitBloquer(role: .coach, peutEcrire: true) == false)
    }

    @Test("Admin avec abonnement → autorisé")
    func adminAvecAboAutorise() {
        #expect(paywallDoitBloquer(role: .admin, peutEcrire: true) == false)
    }

    // MARK: - Rôles non payeurs (JAMAIS bloqués) — exigence critique

    @Test("Athlète → JAMAIS bloqué, même sans abonnement")
    func athleteJamaisBloque() {
        #expect(paywallDoitBloquer(role: .etudiant, peutEcrire: false) == false)
        #expect(paywallDoitBloquer(role: .etudiant, peutEcrire: true) == false)
    }

    @Test("Assistant coach → JAMAIS bloqué (le coach paie pour son staff)")
    func assistantJamaisBloque() {
        #expect(paywallDoitBloquer(role: .assistantCoach, peutEcrire: false) == false)
        #expect(paywallDoitBloquer(role: .assistantCoach, peutEcrire: true) == false)
    }

    @Test("Rôle absent (nil) → non bloqué")
    func roleNilNonBloque() {
        #expect(paywallDoitBloquer(role: nil, peutEcrire: false) == false)
    }
}
