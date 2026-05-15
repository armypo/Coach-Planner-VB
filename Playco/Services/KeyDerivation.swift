//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  KeyDerivation — dérivation de clés mots de passe (PBKDF2 + SHA256 legacy).
//  Extrait d'AuthService (4e étape modularisation après PasswordPolicy,
//  LockoutManager, SessionManager).
//
//  Pure fonctionnel : aucun état, namespace `enum` avec méthodes statiques.
//  Testable en isolation, réutilisable hors d'AuthService si besoin.

import Foundation
import CryptoKit
import CommonCrypto
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "KeyDerivation")

// MARK: - Erreurs

/// Erreurs possibles lors de la dérivation de clés.
/// Conforme à `Equatable` pour permettre `#expect(throws: KeyDerivationError.X)` en tests.
enum KeyDerivationError: LocalizedError, Equatable {
    /// Mot de passe vide transmis à la dérivation — guard-fou développeur.
    case motDePasseVide
    /// CommonCrypto a retourné un statut non-kCCSuccess — défaillance système.
    case echecCrypto(Int32)

    var errorDescription: String? {
        switch self {
        case .motDePasseVide:
            return "Le mot de passe ne peut pas être vide."
        case .echecCrypto(let statut):
            return "Erreur cryptographique (statut CommonCrypto \(statut)). Redémarre l'application."
        }
    }
}

// MARK: - Namespace

/// Namespace pour toutes les opérations cryptographiques liées au mot de passe.
enum KeyDerivation {

    /// Nombre d'itérations PBKDF2 pour les nouveaux comptes (OWASP 2024 : ≥ 600 000).
    static let iterationsParDefaut: Int = 600_000

    // MARK: - Génération de sel

    /// Génère un sel aléatoire de 16 bytes (encodé en hex, 32 caractères).
    /// Utilise `UInt8.random` qui délègue à `arc4random` (CSPRNG système).
    static func genererSel() -> String {
        let bytes = (0..<16).map { _ in UInt8.random(in: 0...255) }
        return Data(bytes).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Dérivation PBKDF2

    /// Hash du mot de passe avec PBKDF2-HMAC-SHA256 + sel.
    /// Utilise `iterationsParDefaut` (600 000) pour tous les nouveaux comptes.
    /// Sortie : 32 bytes → 64 caractères hex.
    /// - Throws: `KeyDerivationError.motDePasseVide` si le mot de passe est vide.
    /// - Throws: `KeyDerivationError.echecCrypto` si CommonCrypto échoue.
    static func hashPBKDF2(_ motDePasse: String, sel: String) throws -> String {
        try deriverCle(motDePasse: motDePasse, sel: sel, iterations: iterationsParDefaut)
    }

    /// Dérive une clé avec PBKDF2-HMAC-SHA256. Paramètre `iterations` exposé
    /// pour la vérification des comptes legacy (migration progressive).
    /// - Throws: `KeyDerivationError.motDePasseVide` si le mot de passe est vide.
    /// - Throws: `KeyDerivationError.echecCrypto` si CommonCrypto échoue.
    static func deriverCle(motDePasse: String, sel: String, iterations: Int) throws -> String {
        // Garde-fou : pointeur nil + count=0 sur CCKeyDerivationPBKDF est UB.
        guard !motDePasse.isEmpty else {
            logger.error("deriverCle appelé avec motDePasse vide — refus")
            throw KeyDerivationError.motDePasseVide
        }
        // Utilise Data.utf8 pour compter tous les bytes (tolère les NUL éventuels,
        // contrairement à strlen).
        let mdpData = Data(motDePasse.utf8)
        let selData = Data(sel.utf8)
        var derivee = [UInt8](repeating: 0, count: 32)

        let statut: Int32 = mdpData.withUnsafeBytes { mdpBuf in
            selData.withUnsafeBytes { selBuf in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    mdpBuf.baseAddress?.assumingMemoryBound(to: CChar.self),
                    mdpData.count,
                    selBuf.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    selData.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(iterations),
                    &derivee, derivee.count
                )
            }
        }

        guard statut == kCCSuccess else {
            logger.critical("CCKeyDerivationPBKDF échec statut \(statut) — défaillance crypto")
            throw KeyDerivationError.echecCrypto(statut)
        }

        return derivee.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Chemins legacy (rétrocompatibilité)

    /// Hash SHA256+sel d'origine (v1.0 → v1.9) — vérification des comptes pré-PBKDF2.
    /// Ne JAMAIS utiliser pour de nouveaux comptes.
    static func hashLegacySHA256AvecSel(_ motDePasse: String, sel: String) -> String {
        let donnees = Data((sel + motDePasse).utf8)
        let hash = SHA256.hash(data: donnees)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Hash SHA256 sans sel (v0.x) — préhistoire, uniquement pour la compat.
    static func hashLegacySHA256SansSel(_ motDePasse: String) -> String {
        let donnees = Data(motDePasse.utf8)
        let hash = SHA256.hash(data: donnees)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Vérification

    /// Vérifie le mot de passe en choisissant l'algorithme selon les métadonnées
    /// du compte. Trois chemins :
    ///   • sel absent           → SHA256 brut (pré-v0.6)
    ///   • iterations ≤ 1 + sel → SHA256+sel (v0.6 → v1.9)
    ///   • iterations ≥ 2       → PBKDF2 avec le nombre d'itérations stocké
    ///
    /// Comparaison constant-time via `egaliteConstante` pour éviter timing attacks.
    /// Retourne `false` (et non un throw) si la dérivation échoue : l'échec crypto
    /// est loggué `.critical`, et refuser l'accès est le comportement sûr par défaut.
    static func verifier(_ motDePasse: String,
                         hash: String,
                         sel: String?,
                         iterations: Int) -> Bool {
        guard let sel = sel, !sel.isEmpty else {
            return egaliteConstante(hashLegacySHA256SansSel(motDePasse), hash)
        }
        let candidat: String
        if iterations <= 1 {
            candidat = hashLegacySHA256AvecSel(motDePasse, sel: sel)
        } else {
            do {
                candidat = try deriverCle(motDePasse: motDePasse, sel: sel, iterations: iterations)
            } catch {
                logger.critical("verifier: échec dérivation PBKDF2 — accès refusé: \(error.localizedDescription)")
                return false
            }
        }
        return egaliteConstante(candidat, hash)
    }

    /// Comparaison constant-time de deux strings (XOR byte-level).
    /// Évite les timing attacks qui exploitent le short-circuit de `==`.
    static func egaliteConstante(_ a: String, _ b: String) -> Bool {
        let aBytes = Array(a.utf8)
        let bBytes = Array(b.utf8)
        guard aBytes.count == bBytes.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<aBytes.count {
            diff |= aBytes[i] ^ bBytes[i]
        }
        return diff == 0
    }
}
