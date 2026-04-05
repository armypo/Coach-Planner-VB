//  Playco
//  Copyright (c) 2025 Christopher Dionne. Tous droits reserves.
//

import SwiftUI
import Foundation

/// Diagrammes pré-dessinés pour les exercices de la bibliothèque.
/// Bibliothèque vidée — les coachs créent leurs propres exercices et diagrammes.
struct DiagrammesBibliotheque {

    /// Retourne les éléments de terrain pour un exercice donné (nil si aucun)
    static func elements(pour nom: String) -> [ElementTerrain]? {
        return nil
    }

    /// Encode les éléments en Data JSON pour stocker dans elementsData
    static func elementsData(pour nom: String) -> Data? {
        guard let elems = elements(pour: nom), !elems.isEmpty else { return nil }
        return try? JSONCoderCache.encoder.encode(elems)
    }
}
