//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  2.2.b — Consentement mineurs : les conversations privées adulte↔mineur
//  sont désactivées par défaut. Elles ne s'ouvrent que si le coach a attesté
//  le consentement parental sur la fiche du joueur (JoueurDetailView).
//  Règle pure et testable — la vue (MessagerieView) ne fait que l'appliquer.

import Foundation

enum PolitiqueMessagerie {

    /// Vrai si une conversation privée entre ces deux personnes est autorisée.
    ///
    /// Le blocage ne vise QUE la paire adulte (coach/admin) ↔ athlète mineur
    /// CONNU (date de naissance renseignée) sans consentement parental attesté.
    /// - Deux adultes : toujours autorisé.
    /// - Deux athlètes (mineurs ou non) : autorisé (comportement existant).
    /// - Mineur inconnu (pas de date de naissance) : pas de faux positif,
    ///   autorisé — l'attestation reste proposée au coach sur la fiche.
    static func dmPriveAutorise(
        roleExpediteur: RoleUtilisateur,
        expediteurEstMineur: Bool,
        roleDestinataire: RoleUtilisateur,
        destinataireEstMineur: Bool,
        consentementAtteste: Bool
    ) -> Bool {
        let expediteurEstAdulteStaff = roleExpediteur != .etudiant
        let destinataireEstAdulteStaff = roleDestinataire != .etudiant

        let paireAdulteMineur =
            (expediteurEstAdulteStaff && roleDestinataire == .etudiant && destinataireEstMineur) ||
            (destinataireEstAdulteStaff && roleExpediteur == .etudiant && expediteurEstMineur)

        guard paireAdulteMineur else { return true }
        return consentementAtteste
    }
}
