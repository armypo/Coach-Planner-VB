//  Playco
//  Copyright (c) 2025 Christopher Dionne. Tous droits reserves.
//

import Foundation
import SwiftUI
import SwiftData

/// Catégories d'exercices de volleyball prédéfinies
enum CategorieBibliotheque: String, CaseIterable {
    case attaque      = "Attaque"
    case service      = "Service"
    case reception    = "Réception"
    case bloc         = "Bloc"
    case defense      = "Défense"
    case echauffement = "Échauffement"
    case collectif    = "Collectif"

    var icone: String {
        switch self {
        case .attaque:      return "bolt.fill"
        case .service:      return "arrow.up.forward"
        case .reception:    return "hand.raised.fill"
        case .bloc:         return "shield.fill"
        case .defense:      return "figure.flexibility"
        case .echauffement: return "flame.fill"
        case .collectif:    return "person.3.fill"
        }
    }

    var couleur: String {
        switch self {
        case .attaque:      return "#DC2626"
        case .service:      return "#FF6B35"
        case .reception:    return "#2563EB"
        case .bloc:         return "#7C3AED"
        case .defense:      return "#059669"
        case .echauffement: return "#FF9500"
        case .collectif:    return "#D97706"
        }
    }
}

/// Helper pour résoudre icône et couleur d'une catégorie (prédéfinie ou personnalisée)
struct CategorieHelper {
    /// Retourne (icône, couleur hex) pour un nom de catégorie
    static func infos(pour nom: String, personnalisees: [CategorieExercice] = []) -> (icone: String, couleur: String) {
        // Chercher dans les catégories prédéfinies
        if let cat = CategorieBibliotheque(rawValue: nom) {
            return (cat.icone, cat.couleur)
        }
        // Chercher dans les catégories personnalisées
        if let custom = personnalisees.first(where: { $0.nom == nom }) {
            return (custom.icone, custom.couleurHex)
        }
        // Fallback
        return ("tag.fill", "#8E8E93")
    }
}

struct BibliothequeDefauts {

    /// Bibliothèque vide — les coachs créent leurs propres exercices
    static let exercices: [(categorie: String, nom: String, description: String)] = []

    /// Insère les exercices prédéfinis s'ils n'existent pas encore
    static func peuplerSiVide(contexte: ModelContext) {
        let descriptor = FetchDescriptor<ExerciceBibliotheque>(
            predicate: #Predicate { $0.estPredefini == true }
        )
        let count = (try? contexte.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        for exo in exercices {
            let e = ExerciceBibliotheque(
                nom: exo.nom,
                categorie: exo.categorie,
                descriptionExo: exo.description,
                notes: exo.description,
                estPredefini: true
            )
            e.elementsData = DiagrammesBibliotheque.elementsData(pour: exo.nom)
            contexte.insert(e)
        }
        try? contexte.save()
    }
}
