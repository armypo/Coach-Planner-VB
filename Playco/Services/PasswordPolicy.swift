//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  PasswordPolicy — politique de mot de passe NIST 800-63B.
//  Extrait de AuthService pour permettre la testabilité isolée et réduire
//  la surface d'AuthService. Pure fonctionnel, aucun état.

import Foundation

/// Politique de validation des mots de passe — conforme NIST 800-63B.
enum PasswordPolicy {

    /// Longueur minimale d'un mot de passe (NIST 800-63B section 5.1.1.2).
    static let longueurMinimale = 12

    /// Mots de passe interdits (liste noire). Comprend :
    /// - Termes contextuels Playco (playco, coach, equipe, volleyball, garneau…)
    /// - Patterns clavier communs (azerty, qwerty, 123456789012)
    /// - Mots de passe par défaut historiques
    ///
    /// La vérification utilise `contains` pour refuser les contournements par
    /// suffixe (ex: "motdepasse123" rejeté, pas juste "motdepasse").
    static let motsDePasseInterdits: Set<String> = [
        "motdepasse", "password", "passe1234", "volleyball", "volleyball123",
        "playco", "playco123", "garneau", "equipe", "coach", "admin",
        "123456789012", "azertyuiopqs", "qwertyuiopas", "aaaaaaaaaaaa",
        "000000000000", "111111111111"
    ]

    /// Valide un mot de passe selon la politique NIST 800-63B.
    /// - Returns: `nil` si valide, sinon le message d'erreur spécifique
    ///   à afficher à l'UI (en français).
    ///
    /// Règles appliquées :
    /// 1. Longueur ≥ `longueurMinimale` (12)
    /// 2. Ne contient aucun terme de `motsDePasseInterdits` (sous-chaîne, case-insensitive)
    /// 3. Ne contient pas l'identifiant, prénom ou nom de l'utilisateur (≥ 3 chars)
    static func valider(_ motDePasse: String,
                        identifiant: String,
                        prenom: String,
                        nom: String) -> String? {
        guard motDePasse.count >= longueurMinimale else {
            return "Le mot de passe doit contenir au moins \(longueurMinimale) caractères."
        }
        let mdpBas = motDePasse.lowercased()
        // `contains` pour éviter le contournement trivial par suffixe
        // ("motdepasse123" serait accepté par une égalité stricte).
        for interdit in motsDePasseInterdits where mdpBas.contains(interdit) {
            return "Ce mot de passe est trop commun. Choisissez-en un autre."
        }
        // Refuser si contient identifiant, prénom ou nom (≥ 3 car, insensible casse)
        let interditsContextuels = [identifiant, prenom, nom]
            .map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
            .filter { $0.count >= 3 }
        for terme in interditsContextuels where mdpBas.contains(terme) {
            return "Le mot de passe ne peut pas contenir votre identifiant, prénom ou nom."
        }
        return nil
    }
}
