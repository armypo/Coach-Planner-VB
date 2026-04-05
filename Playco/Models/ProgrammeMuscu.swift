//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - Catégories de musculation

enum CategorieMuscu: String, Codable, CaseIterable {
    case poitrine   = "Poitrine"
    case dos        = "Dos"
    case epaules    = "Épaules"
    case bras       = "Bras"
    case jambes     = "Jambes"
    case abdos      = "Abdos"
    case cardio     = "Cardio"
    case complet    = "Complet"

    var icone: String {
        switch self {
        case .poitrine: return "figure.arms.open"
        case .dos:      return "figure.stand"
        case .epaules:  return "figure.wave"
        case .bras:     return "figure.strengthtraining.traditional"
        case .jambes:   return "figure.run"
        case .abdos:    return "figure.core.training"
        case .cardio:   return "heart.fill"
        case .complet:  return "figure.cross.training"
        }
    }

    var couleur: Color {
        switch self {
        case .poitrine: return .red
        case .dos:      return .blue
        case .epaules:  return .orange
        case .bras:     return .purple
        case .jambes:   return .green
        case .abdos:    return .yellow
        case .cardio:   return .pink
        case .complet:  return .teal
        }
    }
}

// MARK: - Exercice de musculation (bibliothèque, @Model)

@Model
final class ExerciceMuscu {
    var id: UUID = UUID()
    var nom: String = ""
    var categorieRaw: String = CategorieMuscu.complet.rawValue
    var notes: String = ""
    var dateCreation: Date = Date()

    var categorie: CategorieMuscu {
        get { CategorieMuscu(rawValue: categorieRaw) ?? .complet }
        set { categorieRaw = newValue.rawValue }
    }

    init(nom: String, categorie: CategorieMuscu, notes: String = "") {
        self.id = UUID()
        self.nom = nom
        self.categorieRaw = categorie.rawValue
        self.notes = notes
        self.dateCreation = Date()
    }
}

// MARK: - Exercice dans un programme (Codable, stocké dans ProgrammeMuscu.exercicesData)

struct ExerciceProgramme: Codable, Identifiable {
    var id: UUID = UUID()
    var exerciceID: UUID          // Lien vers ExerciceMuscu
    var exerciceNom: String
    var categorieRaw: String
    var ordre: Int = 0
    var seriesCibles: Int = 3
    var repsCibles: Int = 10
    var poidsDefaut: Double = 0   // lbs
    var tempsRepos: Int = 90      // secondes

    var categorie: CategorieMuscu {
        CategorieMuscu(rawValue: categorieRaw) ?? .complet
    }

    /// Séries enregistrées lors d'une séance live (utilisé dans SeanceMuscu)
    var series: [SerieMuscu] = []
}

// MARK: - Série de musculation

struct SerieMuscu: Codable, Identifiable {
    var id: UUID = UUID()
    var numero: Int
    var reps: Int
    var poids: Double        // lbs
    var estComplete: Bool = false
}

// MARK: - Programme de musculation

@Model
final class ProgrammeMuscu {
    var id: UUID = UUID()
    var nom: String = ""
    var descriptionProgramme: String = ""
    var exercicesData: Data? = nil
    var joueursAssignesData: Data? = nil
    var estArchive: Bool = false
    var codeEquipe: String = ""
    var dateCreation: Date = Date()
    var dateModification: Date = Date()

    func decoderExercices() -> [ExerciceProgramme] {
        guard let data = exercicesData else { return [] }
        return (try? JSONCoderCache.decoder.decode([ExerciceProgramme].self, from: data)) ?? []
    }

    func encoderExercices(_ exercices: [ExerciceProgramme]) {
        exercicesData = try? JSONCoderCache.encoder.encode(exercices)
        dateModification = Date()
    }

    func decoderJoueursAssignes() -> [UUID] {
        guard let data = joueursAssignesData else { return [] }
        return (try? JSONCoderCache.decoder.decode([UUID].self, from: data)) ?? []
    }

    func encoderJoueursAssignes(_ ids: [UUID]) {
        joueursAssignesData = try? JSONCoderCache.encoder.encode(ids)
        dateModification = Date()
    }

    init(nom: String) {
        self.id = UUID()
        self.nom = nom
        self.dateCreation = Date()
        self.dateModification = Date()
    }
}
