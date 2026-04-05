//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftData

/// Catégorie d'exercice personnalisée créée par un coach
@Model
final class CategorieExercice {
    var id: UUID = UUID()
    var nom: String = ""
    var icone: String = "folder.fill"
    var couleurHex: String = "#FF9500"
    var codeEquipe: String = ""
    var dateCreation: Date = Date()

    init(nom: String, icone: String = "folder.fill", couleurHex: String = "#FF9500") {
        self.id = UUID()
        self.nom = nom
        self.icone = icone
        self.couleurHex = couleurHex
        self.dateCreation = Date()
    }
}
