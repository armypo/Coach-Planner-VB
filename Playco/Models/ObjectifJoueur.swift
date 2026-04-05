//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftUI
import SwiftData

/// Objectif individuel assigné à un joueur par le coach
@Model
final class ObjectifJoueur {
    var id: UUID = UUID()
    var joueurID: UUID = UUID()
    var codeEquipe: String = ""
    var titre: String = ""
    var categorieRaw: String = CategorieObjectif.attaque.rawValue
    var cible: Double = 0
    var unite: String = ""
    var dateCreation: Date = Date()
    var dateEcheance: Date? = nil
    var estAtteint: Bool = false
    var notes: String = ""

    var categorie: CategorieObjectif {
        get { CategorieObjectif(rawValue: categorieRaw) ?? .attaque }
        set { categorieRaw = newValue.rawValue }
    }

    init(joueurID: UUID, titre: String, categorie: CategorieObjectif, cible: Double, unite: String) {
        self.id = UUID()
        self.joueurID = joueurID
        self.titre = titre
        self.categorieRaw = categorie.rawValue
        self.cible = cible
        self.unite = unite
        self.dateCreation = Date()
    }
}

// MARK: - Catégorie objectif

enum CategorieObjectif: String, Codable, CaseIterable, Identifiable {
    case attaque   = "Attaque"
    case service   = "Service"
    case bloc      = "Bloc"
    case reception = "Réception"
    case jeu       = "Jeu"
    case physique  = "Physique"

    var id: String { rawValue }

    var icone: String {
        switch self {
        case .attaque:   return "flame.fill"
        case .service:   return "tennisball.fill"
        case .bloc:      return "hand.raised.fill"
        case .reception: return "arrow.down.to.line"
        case .jeu:       return "arrow.triangle.branch"
        case .physique:  return "figure.strengthtraining.traditional"
        }
    }

    var couleur: Color {
        switch self {
        case .attaque:   return PaletteMat.orange
        case .service:   return PaletteMat.bleu
        case .bloc:      return PaletteMat.violet
        case .reception: return PaletteMat.vert
        case .jeu:       return PaletteMat.bleu
        case .physique:  return PaletteMat.violet
        }
    }
}

// MARK: - FiltreParEquipe

extension ObjectifJoueur: FiltreParEquipe {}
