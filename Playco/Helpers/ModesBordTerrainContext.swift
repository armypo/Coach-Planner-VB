//  Playco
//  Copyright (c) 2025 Christopher Dionne. Tous droits reserves.
//

import SwiftUI

// MARK: - Mode bord de terrain (courtside)

/// Clé d'environnement pour le mode bord de terrain (UI simplifiée grands boutons)
private struct ModeBordDeTerrainKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

/// Clé d'environnement pour le thème haut contraste
private struct ThemeHautContrasteKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// Mode bord de terrain — interface simplifiée pour saisie rapide en match
    var modeBordDeTerrain: Bool {
        get { self[ModeBordDeTerrainKey.self] }
        set { self[ModeBordDeTerrainKey.self] = newValue }
    }

    /// Thème haut contraste — couleurs plus vives pour visibilité extérieure
    var themeHautContraste: Bool {
        get { self[ThemeHautContrasteKey.self] }
        set { self[ThemeHautContrasteKey.self] = newValue }
    }
}
