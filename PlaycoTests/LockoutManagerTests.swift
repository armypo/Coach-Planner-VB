//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Testing
import Foundation
@testable import Playco

/// Tests sérialisés : LockoutManager partage le Keychain global avec AuthService.
/// Chaque test nettoie en entrée pour isolation.
@Suite("LockoutManager — verrouillage progressif", .serialized)
struct LockoutManagerTests {

    private func nettoyer() {
        KeychainService.supprimer(cle: LockoutManager.cleKeychain)
    }

    private func creerIsole() -> LockoutManager {
        nettoyer()
        let suite = UserDefaults(suiteName: "playco-lockout-test-\(UUID().uuidString)")!
        return LockoutManager(userDefaults: suite)
    }

    // MARK: - État initial

    @Test("Initial : tentatives 0, non verrouillé")
    func initial() {
        let lockout = creerIsole()
        #expect(lockout.tentatives == 0)
        #expect(lockout.verrouillageJusqua == nil)
        #expect(!lockout.estVerrouille)
        #expect(lockout.tempsRestant == 0)
    }

    // MARK: - enregistrerEchec

    @Test("Pas de verrouillage avant 5 tentatives")
    func pasLockoutAvant5() {
        let lockout = creerIsole()
        for _ in 0..<4 {
            let msg = lockout.enregistrerEchec()
            #expect(msg == nil, "Pas de message avant le palier 5")
        }
        #expect(lockout.tentatives == 4)
        #expect(!lockout.estVerrouille)
    }

    @Test("5 tentatives → lockout 5 minutes")
    func lockoutA5Tentatives() {
        let lockout = creerIsole()
        var message: String? = nil
        for _ in 0..<5 {
            message = lockout.enregistrerEchec()
        }
        #expect(lockout.tentatives == 5)
        #expect(lockout.estVerrouille)
        #expect(lockout.tempsRestant > 0)
        #expect(lockout.tempsRestant <= 5 * 60)
        #expect(message?.contains("5 minute") == true)
    }

    @Test("10 tentatives → lockout 15 minutes")
    func lockoutA10Tentatives() {
        let lockout = creerIsole()
        for _ in 0..<10 {
            _ = lockout.enregistrerEchec()
        }
        #expect(lockout.tentatives == 10)
        #expect(lockout.estVerrouille)
        // Durée de lockout est 15 min (palier 2)
        #expect(lockout.tempsRestant > 5 * 60)
        #expect(lockout.tempsRestant <= 15 * 60)
    }

    @Test("15 tentatives → lockout 1 heure (palier 3)")
    func lockoutA15Tentatives() {
        let lockout = creerIsole()
        for _ in 0..<15 {
            _ = lockout.enregistrerEchec()
        }
        #expect(lockout.tentatives == 15)
        #expect(lockout.estVerrouille)
        // Durée de lockout est 1h (palier 3, max)
        #expect(lockout.tempsRestant > 15 * 60)
        #expect(lockout.tempsRestant <= 60 * 60)
    }

    @Test("20+ tentatives → lockout reste à 1h (cap)")
    func lockoutAu25TentativesCapA1h() {
        let lockout = creerIsole()
        for _ in 0..<25 {
            _ = lockout.enregistrerEchec()
        }
        // Le palier 4 (25 tentatives) utilise l'index 3 qui est clampé à durees.count-1=2 → 1h
        #expect(lockout.tempsRestant <= 60 * 60)
    }

    // MARK: - reinitialiser

    @Test("reinitialiser : reset complet")
    func reinitialiserResetComplet() {
        let lockout = creerIsole()
        for _ in 0..<5 {
            _ = lockout.enregistrerEchec()
        }
        #expect(lockout.estVerrouille)

        lockout.reinitialiser()
        #expect(lockout.tentatives == 0)
        #expect(lockout.verrouillageJusqua == nil)
        #expect(!lockout.estVerrouille)
    }

    // MARK: - Persistance Keychain

    @Test("État persiste entre instances (Keychain)")
    func persistanceKeychain() {
        nettoyer()
        let suite = UserDefaults(suiteName: "playco-lockout-persist-\(UUID().uuidString)")!

        let lockout1 = LockoutManager(userDefaults: suite)
        for _ in 0..<5 {
            _ = lockout1.enregistrerEchec()
        }
        #expect(lockout1.estVerrouille)

        // Nouvelle instance → doit lire l'état depuis Keychain
        let lockout2 = LockoutManager(userDefaults: suite)
        #expect(lockout2.tentatives == 5)
        #expect(lockout2.estVerrouille)

        nettoyer()
    }

    // MARK: - Migration UserDefaults legacy

    @Test("Migration UserDefaults legacy → Keychain")
    func migrationLegacy() {
        nettoyer()
        let suite = UserDefaults(suiteName: "playco-lockout-legacy-\(UUID().uuidString)")!
        // Planter des données legacy dans UserDefaults
        suite.set(3, forKey: "playco_auth_tentatives")
        let futurLock = Date().addingTimeInterval(300).timeIntervalSince1970
        suite.set(futurLock, forKey: "playco_auth_verrouillage")

        // Premier init doit migrer
        let lockout = LockoutManager(userDefaults: suite)
        #expect(lockout.tentatives == 3)
        #expect(lockout.verrouillageJusqua != nil)

        // Les clés legacy doivent être supprimées
        #expect(suite.integer(forKey: "playco_auth_tentatives") == 0)
        #expect(suite.double(forKey: "playco_auth_verrouillage") == 0)

        // Le Keychain contient maintenant l'état
        #expect(KeychainService.lire(cle: LockoutManager.cleKeychain) != nil)

        nettoyer()
    }
}
