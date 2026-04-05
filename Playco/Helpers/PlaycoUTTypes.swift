//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import UniformTypeIdentifiers

extension UTType {
    /// Type personnalisé pour les fichiers d'export Playco (.playco)
    static let playcoExercices = UTType(exportedAs: "com.origotech.playco.exercices",
                                         conformingTo: .json)
}
