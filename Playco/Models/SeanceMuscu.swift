//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftData

// MARK: - Structures pour le log en temps réel

/// Série enregistrée pendant une séance live
struct SerieLog: Codable, Identifiable {
    var id: UUID = UUID()
    var numero: Int
    var reps: Int
    var poids: Double        // lbs
    var estComplete: Bool = false
}

/// Exercice log pendant une séance live
struct ExerciceLog: Codable, Identifiable {
    var id: UUID = UUID()
    var exerciceID: UUID
    var exerciceNom: String
    var categorieRaw: String
    var series: [SerieLog] = []

    var categorie: CategorieMuscu {
        CategorieMuscu(rawValue: categorieRaw) ?? .complet
    }
}

// MARK: - Séance de musculation complétée — historique

@Model
final class SeanceMuscu {
    var id: UUID = UUID()
    var programmeID: UUID = UUID()
    var programmeNom: String = ""
    var date: Date = Date()
    var dureeTotale: Int = 0          // secondes
    var estTerminee: Bool = false
    var exercicesData: Data? = nil
    var joueurID: UUID? = nil
    var codeEquipe: String = ""
    var notes: String = ""

    /// Volume total = somme (poids × reps) pour toutes les séries complètes
    var volumeTotal: Double {
        let exercices = decoderExercices()
        return exercices.reduce(0.0) { total, exo in
            total + exo.series.filter(\.estComplete).reduce(0.0) { $0 + $1.poids * Double($1.reps) }
        }
    }

    /// Nombre de séries complétées
    var seriesCompletees: Int {
        let exercices = decoderExercices()
        return exercices.reduce(0) { total, exo in
            total + exo.series.filter(\.estComplete).count
        }
    }

    func decoderExercices() -> [ExerciceLog] {
        guard let data = exercicesData else { return [] }
        return (try? JSONCoderCache.decoder.decode([ExerciceLog].self, from: data)) ?? []
    }

    func encoderExercices(_ exercices: [ExerciceLog]) {
        exercicesData = try? JSONCoderCache.encoder.encode(exercices)
    }

    init(programmeNom: String, programmeID: UUID, joueurID: UUID? = nil) {
        self.id = UUID()
        self.programmeNom = programmeNom
        self.programmeID = programmeID
        self.joueurID = joueurID
        self.date = Date()
    }
}
