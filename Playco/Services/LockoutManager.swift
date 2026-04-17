//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  LockoutManager — verrouillage progressif persisté dans le Keychain.
//  Extrait d'AuthService pour permettre la testabilité isolée et réduire
//  la surface d'AuthService.
//
//  Politique : 5 tentatives → 5 min, 10 tentatives → 15 min, 15+ → 1h.
//  Persistance : Keychain (survit à la réinstallation) + migration one-shot
//  depuis UserDefaults (format legacy v1.0 → v1.9).

import Foundation
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "LockoutManager")

/// Gestionnaire du verrouillage après échecs répétés de connexion.
@Observable
final class LockoutManager {

    /// Clé Keychain (v1.11+).
    static let cleKeychain = "playco_auth_state"

    /// Clés legacy UserDefaults — lues une fois pour migration puis supprimées.
    private static let cleTentativesLegacy = "playco_auth_tentatives"
    private static let cleVerrouillageLegacy = "playco_auth_verrouillage"

    /// Durées de verrouillage progressif : 5 min → 15 min → 1h (puis cap).
    private static let dureesVerrouillage: [TimeInterval] = [
        5 * 60,      // 5 minutes
        15 * 60,     // 15 minutes
        60 * 60      // 1 heure
    ]

    /// Nombre d'échecs consécutifs avant lockout.
    private static let seuilTentatives = 5

    /// État sérialisable persisté dans le Keychain.
    /// Versionné pour évolution future sans invalider les entrées existantes.
    private struct EtatVerrouillage: Codable {
        var version: Int = 1
        var tentatives: Int
        var jusqua: TimeInterval?
    }

    private(set) var tentatives: Int
    private(set) var verrouillageJusqua: Date?

    private let userDefaults: UserDefaults

    /// - Parameter userDefaults: magasin UserDefaults pour la migration legacy.
    ///   Le verrouillage lui-même est stocké dans le Keychain global iOS.
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        // 1. Tentative lecture Keychain (source de vérité)
        if let json = KeychainService.lire(cle: Self.cleKeychain),
           let data = json.data(using: .utf8),
           let etat = try? JSONCoderCache.decoder.decode(EtatVerrouillage.self, from: data) {
            self.tentatives = etat.tentatives
            self.verrouillageJusqua = etat.jusqua.map { Date(timeIntervalSince1970: $0) }
            return
        }

        // 2. Fallback : migration depuis UserDefaults legacy
        let tentativesLegacy = userDefaults.integer(forKey: Self.cleTentativesLegacy)
        let intervalLegacy = userDefaults.double(forKey: Self.cleVerrouillageLegacy)
        self.tentatives = tentativesLegacy
        self.verrouillageJusqua = intervalLegacy > 0
            ? Date(timeIntervalSince1970: intervalLegacy)
            : nil

        if tentativesLegacy > 0 || intervalLegacy > 0 {
            persister()
            userDefaults.removeObject(forKey: Self.cleTentativesLegacy)
            userDefaults.removeObject(forKey: Self.cleVerrouillageLegacy)
            logger.info("Migration état verrouillage UserDefaults → Keychain")
        }
    }

    /// `true` si un lockout est actuellement actif.
    var estVerrouille: Bool {
        guard let jusqua = verrouillageJusqua else { return false }
        return Date() < jusqua
    }

    /// Secondes restantes avant fin du lockout (0 si non verrouillé).
    var tempsRestant: Int {
        guard let jusqua = verrouillageJusqua else { return 0 }
        return max(0, Int(jusqua.timeIntervalSince(Date())))
    }

    /// Reset complet après connexion réussie.
    func reinitialiser() {
        tentatives = 0
        verrouillageJusqua = nil
        persister()
    }

    /// Incrémente le compteur de tentatives et applique un lockout si un palier
    /// est atteint (5/10/15+ tentatives).
    /// - Returns: message à afficher si lockout déclenché, sinon `nil`.
    func enregistrerEchec() -> String? {
        tentatives += 1

        let cycleActuel = tentatives / Self.seuilTentatives
        let reste = tentatives % Self.seuilTentatives

        var message: String? = nil
        if reste == 0 && cycleActuel >= 1 {
            let indexDuree = min(cycleActuel - 1, Self.dureesVerrouillage.count - 1)
            let duree = Self.dureesVerrouillage[indexDuree]
            verrouillageJusqua = Date().addingTimeInterval(duree)
            let minutes = Int(duree / 60)
            message = "Trop de tentatives. Compte verrouillé pendant \(minutes) minute(s)."
        }

        persister()
        return message
    }

    // MARK: - Persistance Keychain

    private func persister() {
        let etat = EtatVerrouillage(
            tentatives: tentatives,
            jusqua: verrouillageJusqua?.timeIntervalSince1970
        )
        do {
            let data = try JSONCoderCache.encoder.encode(etat)
            guard let json = String(data: data, encoding: .utf8) else { return }
            KeychainService.sauvegarder(cle: Self.cleKeychain, valeur: json)
        } catch {
            logger.error("Échec encodage état verrouillage: \(error.localizedDescription)")
        }
    }
}
