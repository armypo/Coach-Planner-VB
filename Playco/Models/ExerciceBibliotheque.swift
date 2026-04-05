//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftData

@Model
final class ExerciceBibliotheque: TerrainContent {
    var id: UUID = UUID()
    var nom: String = ""
    var categorie: String = ""
    var descriptionExo: String = ""
    var notes: String = ""
    var dessinData: Data?
    var elementsData: Data?
    /// true = exercice pré-intégré, false = créé par l'utilisateur
    var estPredefini: Bool = false
    var estFavori: Bool = false
    var duree: Int = 0         // durée suggérée en minutes (0 = non défini)
    var etapesData: Data? = nil  // JSON: [EtapeExercice]
    var notesCoach: String = "" // notes spécifiques au coach (visible sous le terrain)
    var typeTerrain: String = TypeTerrain.indoor.rawValue
    var dateCreation: Date = Date()
    /// Code du coach propriétaire de cet exercice
    var codeCoach: String = ""

    /// P2-05 — Accesseur enum type-safe pour typeTerrain
    var terrain: TypeTerrain {
        get { TypeTerrain(rawValue: typeTerrain) ?? .indoor }
        set { typeTerrain = newValue.rawValue }
    }

    /// P2-05 — Accesseur enum type-safe pour categorie
    var categorieBiblio: CategorieBibliotheque {
        get { CategorieBibliotheque(rawValue: categorie) ?? .echauffement }
        set { categorie = newValue.rawValue }
    }

    /// Validation métier (P1-06)
    var estValide: Bool {
        !nom.trimmingCharacters(in: .whitespaces).isEmpty && duree >= 0
    }

    init(nom: String, categorie: String, descriptionExo: String = "",
         notes: String = "", estPredefini: Bool = false, duree: Int = 0) {
        self.id = UUID()
        self.nom = nom
        self.categorie = categorie
        self.descriptionExo = descriptionExo
        self.notes = notes
        self.estPredefini = estPredefini
        self.estFavori = false
        self.duree = max(0, duree)
        self.dateCreation = Date()
        self.dessinData = nil
        self.elementsData = nil
    }
}
