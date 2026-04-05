//  Playco
//  Copyright (c) 2025 Christopher Dionne. Tous droits reserves.
//

import SwiftUI

// MARK: - Code équipe actif dans l'environnement

/// Clé d'environnement pour le code d'équipe sélectionné
private struct CodeEquipeKey: EnvironmentKey {
    static let defaultValue: String = ""
}

extension EnvironmentValues {
    /// Code équipe actif — utilisé pour filtrer les données par équipe
    var codeEquipeActif: String {
        get { self[CodeEquipeKey.self] }
        set { self[CodeEquipeKey.self] = newValue }
    }
}
