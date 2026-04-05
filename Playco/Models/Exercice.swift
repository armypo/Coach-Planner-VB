//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftData

@Model
final class Exercice: TerrainContent {
    var id: UUID = UUID()
    var nom: String = ""
    var notes: String = ""
    var dessinData: Data?
    var elementsData: Data?   // JSON sérialisé de [ElementTerrain]
    var ordre: Int = 0
    var duree: Int = 0        // durée en minutes (0 = non défini)
    var etapesData: Data? = nil  // JSON: [EtapeExercice]
    var typeTerrain: String = TypeTerrain.indoor.rawValue
    var seance: Seance? = nil

    /// P3-01 — Soft delete : archivé au lieu de supprimé
    var estArchive: Bool = false

    /// P2-05 — Accesseur enum type-safe pour typeTerrain
    var terrain: TypeTerrain {
        get { TypeTerrain(rawValue: typeTerrain) ?? .indoor }
        set { typeTerrain = newValue.rawValue }
    }

    /// Validation métier (P1-06)
    var estValide: Bool {
        !nom.trimmingCharacters(in: .whitespaces).isEmpty &&
        duree >= 0 && ordre >= 0
    }

    init(nom: String, notes: String = "", ordre: Int = 0, duree: Int = 0) {
        self.id = UUID()
        self.nom = nom
        self.notes = notes
        self.ordre = max(0, ordre)
        self.duree = max(0, duree)
        self.dessinData = nil
        self.elementsData = nil
    }
}
