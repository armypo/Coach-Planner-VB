//  Playco
//  Copyright (c) 2025 Christopher Dionne. Tous droits reserves.
//

import Foundation
import Security
import os

/// Service de stockage sécurisé dans le Keychain iOS.
/// Utilise `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` pour
/// s'assurer que les données ne quittent jamais l'appareil.
enum KeychainService {

    private static let logger = Logger(subsystem: "com.origotech.playco", category: "KeychainService")

    // MARK: - Sauvegarder

    /// Sauvegarde une valeur string dans le Keychain.
    /// Remplace la valeur existante si la clé existe déjà.
    @discardableResult
    static func sauvegarder(cle: String, valeur: String) -> Bool {
        guard let donnees = valeur.data(using: .utf8) else {
            logger.error("Impossible d'encoder la valeur pour la clé \(cle)")
            return false
        }

        // Supprimer l'entrée existante avant d'en créer une nouvelle (immutabilité)
        supprimer(cle: cle)

        let requete: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: cle,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData: donnees
        ]

        let statut = SecItemAdd(requete as CFDictionary, nil)
        if statut != errSecSuccess {
            logger.error("Erreur Keychain sauvegarder (\(cle)): statut \(statut)")
            return false
        }
        return true
    }

    // MARK: - Lire

    /// Lit une valeur string depuis le Keychain.
    /// Retourne `nil` si la clé n'existe pas ou en cas d'erreur.
    static func lire(cle: String) -> String? {
        let requete: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: cle,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var resultat: AnyObject?
        let statut = SecItemCopyMatching(requete as CFDictionary, &resultat)

        guard statut == errSecSuccess,
              let donnees = resultat as? Data,
              let valeur = String(data: donnees, encoding: .utf8) else {
            if statut != errSecItemNotFound {
                logger.error("Erreur Keychain lire (\(cle)): statut \(statut)")
            }
            return nil
        }
        return valeur
    }

    // MARK: - Supprimer

    /// Supprime une entrée du Keychain.
    @discardableResult
    static func supprimer(cle: String) -> Bool {
        let requete: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: cle
        ]
        let statut = SecItemDelete(requete as CFDictionary)
        if statut != errSecSuccess && statut != errSecItemNotFound {
            logger.error("Erreur Keychain supprimer (\(cle)): statut \(statut)")
            return false
        }
        return true
    }
}
