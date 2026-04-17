//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  SessionManager — persistance de l'ID de session dans le Keychain.
//  Extrait d'AuthService (suite modularisation après PasswordPolicy + LockoutManager).
//
//  Le Keychain est utilisé plutôt que UserDefaults pour que la session survive
//  à l'app mais pas à une réinstallation explicite (le Keychain peut être purgé
//  par l'utilisateur via Réglages). Migration one-shot depuis UserDefaults legacy.

import Foundation
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "SessionManager")

/// Gestionnaire de l'ID de session utilisateur persisté dans le Keychain.
/// Ne connait pas `Utilisateur` ni `ModelContext` — pure couche de persistance
/// avec une politique d'expiration. La restauration logique (fetch utilisateur,
/// vérifier `estActif`, connecter) reste dans `AuthService`.
final class SessionManager {

    /// Clé Keychain où est stocké l'UUID de session (v1.5+).
    static let cleKeychain = "playco_session_utilisateurConnecteID"

    /// Clé UserDefaults legacy (pré-v1.5) — lue une fois pour migration.
    private static let cleLegacy = "utilisateurConnecteID"

    /// Durée maximum d'une session avant réauthentification obligatoire (30 jours).
    /// NIST 800-63B section 7.2 recommande 30 jours pour AAL1.
    static let dureeMaxSecondes: TimeInterval = 30 * 24 * 3600

    private let userDefaults: UserDefaults

    /// - Parameter userDefaults: magasin UserDefaults pour la migration legacy.
    ///   Injectable pour isolation des tests.
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// UUID de session sauvegardé, ou `nil` si absent.
    /// Migre automatiquement l'entrée UserDefaults legacy vers Keychain au premier appel.
    var idSauvegarde: String? {
        // 1. Keychain (source de vérité)
        if let idKeychain = KeychainService.lire(cle: Self.cleKeychain) {
            return idKeychain
        }
        // 2. Migration one-shot depuis UserDefaults
        if let idLegacy = userDefaults.string(forKey: Self.cleLegacy) {
            KeychainService.sauvegarder(cle: Self.cleKeychain, valeur: idLegacy)
            userDefaults.removeObject(forKey: Self.cleLegacy)
            logger.info("Migration session UserDefaults → Keychain")
            return idLegacy
        }
        return nil
    }

    /// Sauvegarde l'ID d'un utilisateur comme session active.
    func sauvegarder(utilisateurID: UUID) {
        KeychainService.sauvegarder(cle: Self.cleKeychain, valeur: utilisateurID.uuidString)
    }

    /// Supprime la session courante (déconnexion).
    func supprimer() {
        KeychainService.supprimer(cle: Self.cleKeychain)
    }

    /// Vérifie si une session créée à `dateCreation` a dépassé `dureeMaxSecondes`.
    /// Pure fonction — pas d'accès au Keychain, facile à tester.
    static func estExpiree(dateCreation: Date, maintenant: Date = .now) -> Bool {
        maintenant.timeIntervalSince(dateCreation) > dureeMaxSecondes
    }
}
