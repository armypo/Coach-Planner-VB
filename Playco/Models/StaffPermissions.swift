//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftData

/// Permissions granulaires pour un membre du staff (assistant-coach, préparateur, etc.)
/// Par défaut, toutes les permissions sont activées (mêmes droits que l'entraîneur-chef).
/// L'entraîneur-chef peut restreindre les permissions individuellement.
@Model
final class StaffPermissions {
    var id: UUID = UUID()

    /// ID de l'assistant-coach concerné
    var assistantID: UUID = UUID()

    /// Code équipe — filtre multi-équipe
    var codeEquipe: String = ""

    /// Peut modifier les formations et compositions
    var peutModifierFormation: Bool = true

    /// Peut gérer les statistiques (saisie, modification, suppression)
    var peutGererStats: Bool = true

    /// Peut dessiner et modifier le terrain
    var peutModifierTerrain: Bool = true

    /// Peut ajouter, modifier et supprimer des joueurs
    var peutGererJoueurs: Bool = true

    /// Peut supprimer un match
    var peutSupprimerMatch: Bool = true

    /// Peut inviter d'autres membres du staff
    var peutInviterStaff: Bool = true

    /// Peut voir les identifiants et réinitialiser les mots de passe des joueurs
    var peutVoirIdentifiantsJoueurs: Bool = true

    var dateModification: Date = Date()

    init(assistantID: UUID, codeEquipe: String) {
        self.id = UUID()
        self.assistantID = assistantID
        self.codeEquipe = codeEquipe
    }
}

// MARK: - FiltreParEquipe

extension StaffPermissions: FiltreParEquipe { }
