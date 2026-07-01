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

@Suite("FeatureGating — gate Club (connexion athlètes)")
struct ClubGateTests {

    @Test("Coach sans Club → bloqué")
    func coachSansClubBloque() {
        #expect(clubRequisDoitBloquer(role: .coach, peutConnecterAthletes: false) == true)
    }

    @Test("Admin sans Club → bloqué")
    func adminSansClubBloque() {
        #expect(clubRequisDoitBloquer(role: .admin, peutConnecterAthletes: false) == true)
    }

    @Test("Coach avec Club → autorisé")
    func coachClubAutorise() {
        #expect(clubRequisDoitBloquer(role: .coach, peutConnecterAthletes: true) == false)
    }

    @Test("Athlète / assistant / nil → jamais ce gate")
    func autresRolesNonConcernes() {
        #expect(clubRequisDoitBloquer(role: .etudiant, peutConnecterAthletes: false) == false)
        #expect(clubRequisDoitBloquer(role: .assistantCoach, peutConnecterAthletes: false) == false)
        #expect(clubRequisDoitBloquer(role: nil, peutConnecterAthletes: false) == false)
    }
}

/// Verrouille le contrat dont dépend le build EXPOSITION : sous `#if EXPOSITION`,
/// `AbonnementService` force `statut = .clubAnnuel`. Un tier Club actif DOIT donner
/// tout débloqué et aucune bannière. Si une refonte future casse ce mapping, elle
/// casse aussi la démo partenaire — ces tests l'attrapent (compilés en Debug).
@Suite("AbonnementService — contrat statut Club (invariant EXPOSITION)")
@MainActor
struct AbonnementStatutClubTests {

    private func serviceClub() -> AbonnementService {
        let service = AbonnementService()
        service.statut = .clubAnnuel(dateRenouvellement: .distantFuture)
        return service
    }

    @Test("Club annuel → peut écrire")
    func clubPeutEcrire() {
        #expect(serviceClub().peutEcrire == true)
    }

    @Test("Club annuel → peut connecter des athlètes")
    func clubPeutConnecterAthletes() {
        #expect(serviceClub().peutConnecterAthletes == true)
    }

    @Test("Club annuel → tier actif = Club")
    func clubTierActif() {
        #expect(serviceClub().tierActif == .club)
    }

    @Test("Club annuel → aucune bannière d'abonnement")
    func clubAucuneBanniere() {
        #expect(serviceClub().doitAfficherBanniere == false)
    }
}
