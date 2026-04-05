//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

// MARK: - Catégorie de stratégie
enum CategorieStrategie: String, CaseIterable {
    case attaque     = "Système d'attaque"
    case blocDefense = "Bloc-Défense"
    case transition  = "Transition"
    case sideOut     = "Side-out"

    var icone: String {
        switch self {
        case .attaque:     return "bolt.fill"
        case .blocDefense: return "shield.fill"
        case .transition:  return "arrow.left.arrow.right"
        case .sideOut:     return "arrow.uturn.right"
        }
    }

    var couleur: Color {
        switch self {
        case .attaque:     return Color(hex: "#EF4444")
        case .blocDefense: return Color(hex: "#2563EB")
        case .transition:  return Color(hex: "#8B5CF6")
        case .sideOut:     return Color(hex: "#10B981")
        }
    }
}

// MARK: - Modèle stratégie collective
@Model
final class StrategieCollective: TerrainContent {
    var id: UUID = UUID()
    var nom: String = ""
    var categorieRaw: String = CategorieStrategie.attaque.rawValue  // CategorieStrategie.rawValue
    var descriptionStrategie: String = ""
    var notes: String = ""
    var dessinData: Data?
    var elementsData: Data?
    var etapesData: Data? = nil    // JSON [EtapeExercice]
    var typeTerrain: String = TypeTerrain.indoor.rawValue
    var dateCreation: Date = Date()
    var dateModification: Date = Date()
    var estArchivee: Bool = false  // P2-01 v0.4.0 — Soft delete (cohérence Seance/Exercice)

    /// Code équipe — filtre multi-équipe
    var codeEquipe: String = ""

    var categorie: CategorieStrategie {
        get { CategorieStrategie(rawValue: categorieRaw) ?? .attaque }
        set { categorieRaw = newValue.rawValue }
    }

    /// Validation métier (P1-06)
    var estValide: Bool {
        !nom.trimmingCharacters(in: .whitespaces).isEmpty
    }

    init(nom: String, categorie: CategorieStrategie, descriptionStrategie: String = "", notes: String = "") {
        self.id = UUID()
        self.nom = nom
        self.categorieRaw = categorie.rawValue
        self.descriptionStrategie = descriptionStrategie
        self.notes = notes
        self.dateCreation = Date()
        self.dateModification = Date()
    }
}
