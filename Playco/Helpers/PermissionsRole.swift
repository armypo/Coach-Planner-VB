//  Playco
//  Copyright (c) 2025 Christopher Dionne. Tous droits reserves.
//

import SwiftUI

/// S3 : Extension pour vérifier les permissions par rôle
extension RoleUtilisateur {
    /// Peut créer/modifier/supprimer des séances et exercices
    var peutModifierSeances: Bool {
        self == .coach || self == .admin
    }

    /// Peut créer/modifier/supprimer des stratégies
    var peutModifierStrategies: Bool {
        self == .coach || self == .admin
    }

    /// Peut gérer les joueurs de l'équipe (ajouter, modifier, supprimer)
    var peutGererEquipe: Bool {
        self == .coach || self == .admin
    }

    /// Peut prendre les présences et évaluer
    var peutEvaluer: Bool {
        self == .coach || self == .admin
    }

    /// Peut créer/gérer les programmes de musculation
    var peutGererProgrammes: Bool {
        self == .coach || self == .admin
    }

    /// Peut exporter/importer des données
    var peutExporter: Bool {
        self == .coach || self == .admin
    }

    /// Peut créer des comptes utilisateurs
    var peutCreerComptes: Bool {
        self == .coach || self == .admin
    }
}

/// Modifier qui cache un élément si l'utilisateur n'a pas la permission
struct PermissionModifier: ViewModifier {
    let autorise: Bool

    func body(content: Content) -> some View {
        if autorise {
            content
        }
    }
}

extension View {
    /// Cache la vue si la permission n'est pas accordée
    func siAutorise(_ autorise: Bool) -> some View {
        modifier(PermissionModifier(autorise: autorise))
    }
}
