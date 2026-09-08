//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Tests du marqueur de reprise du match live (2.2.a — State Restoration).
//

import Testing
import Foundation
@testable import Playco

@Suite("MatchLiveRestauration — marqueur de reprise")
struct MatchLiveRestaurationTests {

    /// UserDefaults isolés par test (suite dédiée, purgée à la création).
    private func defaultsIsoles(_ nom: String) -> UserDefaults {
        let suite = "tests.matchLiveRestauration.\(nom)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    @Test("marquer puis lire retourne l'identifiant de la séance")
    func marquerPuisLire() {
        // Arrange
        let defaults = defaultsIsoles("lire")
        let id = UUID()

        // Act
        MatchLiveRestauration.marquer(seanceID: id, defaults: defaults)

        // Assert
        #expect(MatchLiveRestauration.seanceEnCours(defaults: defaults) == id)
        #expect(MatchLiveRestauration.correspond(a: id, defaults: defaults))
    }

    @Test("effacer supprime le marqueur")
    func effacerSupprime() {
        // Arrange
        let defaults = defaultsIsoles("effacer")
        MatchLiveRestauration.marquer(seanceID: UUID(), defaults: defaults)

        // Act
        MatchLiveRestauration.effacer(defaults: defaults)

        // Assert
        #expect(MatchLiveRestauration.seanceEnCours(defaults: defaults) == nil)
    }

    @Test("aucun marqueur : rien à reprendre")
    func aucunMarqueur() {
        let defaults = defaultsIsoles("vide")
        #expect(MatchLiveRestauration.seanceEnCours(defaults: defaults) == nil)
        #expect(!MatchLiveRestauration.correspond(a: UUID(), defaults: defaults))
    }

    @Test("un marqueur périmé (plus de 6 h) est ignoré et effacé")
    func marqueurPerime() {
        // Arrange
        let defaults = defaultsIsoles("perime")
        let id = UUID()
        MatchLiveRestauration.marquer(seanceID: id, defaults: defaults)

        // Act — lecture 7 heures plus tard
        let plusTard = Date().addingTimeInterval(7 * 3600)
        let lu = MatchLiveRestauration.seanceEnCours(defaults: defaults, maintenant: plusTard)

        // Assert — ignoré, et purgé au passage (lecture immédiate suivante nil aussi)
        #expect(lu == nil)
        #expect(MatchLiveRestauration.seanceEnCours(defaults: defaults) == nil)
    }

    @Test("marquer une nouvelle séance écrase la précédente")
    func marquerEcrase() {
        // Arrange
        let defaults = defaultsIsoles("ecrase")
        let ancien = UUID()
        let nouveau = UUID()
        MatchLiveRestauration.marquer(seanceID: ancien, defaults: defaults)

        // Act
        MatchLiveRestauration.marquer(seanceID: nouveau, defaults: defaults)

        // Assert
        #expect(MatchLiveRestauration.seanceEnCours(defaults: defaults) == nouveau)
        #expect(!MatchLiveRestauration.correspond(a: ancien, defaults: defaults))
    }

    @Test("correspond distingue la bonne séance")
    func correspondBonneSeance() {
        let defaults = defaultsIsoles("correspond")
        let id = UUID()
        MatchLiveRestauration.marquer(seanceID: id, defaults: defaults)

        #expect(MatchLiveRestauration.correspond(a: id, defaults: defaults))
        #expect(!MatchLiveRestauration.correspond(a: UUID(), defaults: defaults))
    }
}
