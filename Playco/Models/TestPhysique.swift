//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - Types de tests physiques

enum TypeTestPhysique: String, Codable, CaseIterable {
    case squat1RM       = "Squat 1RM"
    case bench1RM       = "Bench Press 1RM"
    case deadlift1RM    = "Deadlift 1RM"
    case verticalJump   = "Saut vertical"
    case sprintTime     = "Sprint 20m"
    case beepTest       = "Test navette"
    case planche        = "Planche (durée)"
    case flexionsTronc  = "Flexions du tronc"

    var label: String { rawValue }

    var unite: String {
        switch self {
        case .squat1RM, .bench1RM, .deadlift1RM: return "lbs"
        case .verticalJump:   return "cm"
        case .sprintTime:     return "s"
        case .beepTest:       return "paliers"
        case .planche:        return "s"
        case .flexionsTronc:  return "reps"
        }
    }

    var icone: String {
        switch self {
        case .squat1RM:      return "figure.strengthtraining.traditional"
        case .bench1RM:      return "figure.arms.open"
        case .deadlift1RM:   return "figure.stand"
        case .verticalJump:  return "arrow.up"
        case .sprintTime:    return "figure.run"
        case .beepTest:      return "heart.fill"
        case .planche:       return "figure.core.training"
        case .flexionsTronc: return "figure.core.training"
        }
    }

    var couleur: Color {
        switch self {
        case .squat1RM:      return .red
        case .bench1RM:      return .blue
        case .deadlift1RM:   return .purple
        case .verticalJump:  return .green
        case .sprintTime:    return .orange
        case .beepTest:      return .pink
        case .planche:       return .teal
        case .flexionsTronc: return .yellow
        }
    }

    /// true si une valeur plus basse est meilleure (temps)
    var estTemps: Bool {
        self == .sprintTime
    }
}

// MARK: - Modèle test physique

@Model
final class TestPhysique {
    var id: UUID = UUID()
    var joueurID: UUID = UUID()
    var typeTestRaw: String = TypeTestPhysique.squat1RM.rawValue
    var valeur: Double = 0
    var date: Date = Date()
    var notes: String = ""

    var typeTest: TypeTestPhysique {
        get { TypeTestPhysique(rawValue: typeTestRaw) ?? .squat1RM }
        set { typeTestRaw = newValue.rawValue }
    }

    init(joueurID: UUID, typeTest: TypeTestPhysique, valeur: Double, date: Date = Date(), notes: String = "") {
        self.id = UUID()
        self.joueurID = joueurID
        self.typeTestRaw = typeTest.rawValue
        self.valeur = valeur
        self.date = date
        self.notes = notes
    }
}
