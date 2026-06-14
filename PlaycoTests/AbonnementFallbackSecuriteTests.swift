//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Tests de la frontière de confiance du fallback abonnement Public DB
//  (`AbonnementService.statutDepuisSnapshotPublic`). La Public DB est inscriptible :
//  un record forgé ne doit PAS débloquer un tier. Voir docs/Securite_AbonnementPublicDB.md.
//

import Testing
import Foundation
@testable import Playco

@MainActor
@Suite("Abonnement — sécurité fallback Public DB")
struct AbonnementFallbackSecuriteTests {

    private func snap(tier: Tier, type: TypeAbonnement, exp: Date?) -> AbonnementPublicSnapshot {
        AbonnementPublicSnapshot(codeEquipe: "EQU-T", tier: tier, type: type,
                                 dateExpiration: exp, dateDernierSync: Date())
    }

    // MARK: - Rejets (records forgés / invraisemblables)

    @Test("Record sans expiration → rejeté (pas de déblocage)")
    func sansExpirationRejete() {
        let s = AbonnementService()
        #expect(s.statutDepuisSnapshotPublic(snap(tier: .club, type: .annuel, exp: nil)) == nil)
    }

    @Test("Expiration aberrante (>13 mois) → rejetée")
    func expirationAberranteRejetee() {
        let s = AbonnementService()
        let dans10ans = Calendar.current.date(byAdding: .year, value: 10, to: Date())!
        #expect(s.statutDepuisSnapshotPublic(snap(tier: .club, type: .annuel, exp: dans10ans)) == nil)
    }

    @Test("Tier aucun → nil")
    func tierAucunNil() {
        let s = AbonnementService()
        let dans1mois = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        #expect(s.statutDepuisSnapshotPublic(snap(tier: .aucun, type: .mensuel, exp: dans1mois)) == nil)
    }

    // MARK: - Acceptations légitimes

    @Test("Club annuel valide (exp +6 mois) → clubAnnuel")
    func clubAnnuelValide() {
        let s = AbonnementService()
        let dans6mois = Calendar.current.date(byAdding: .month, value: 6, to: Date())!
        guard case .clubAnnuel = s.statutDepuisSnapshotPublic(snap(tier: .club, type: .annuel, exp: dans6mois)) else {
            Issue.record("attendu .clubAnnuel"); return
        }
    }

    @Test("Pro mensuel périmé → expire (pas de déblocage)")
    func proMensuelPerimeExpire() {
        let s = AbonnementService()
        let hier = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        guard case .expire(let tier, _) = s.statutDepuisSnapshotPublic(snap(tier: .pro, type: .mensuel, exp: hier)) else {
            Issue.record("attendu .expire"); return
        }
        #expect(tier == .pro)
    }

    @Test("Essai valide (exp +10 j) → essaiActif avec jours restants")
    func essaiValide() {
        let s = AbonnementService()
        let dans10j = Calendar.current.date(byAdding: .day, value: 10, to: Date())!
        guard case .essaiActif(let tier, let jours) = s.statutDepuisSnapshotPublic(snap(tier: .pro, type: .essai, exp: dans10j)) else {
            Issue.record("attendu .essaiActif"); return
        }
        #expect(tier == .pro)
        #expect(jours >= 9 && jours <= 10)
    }
}
