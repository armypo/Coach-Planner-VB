//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Type de phase

enum TypePhase: String, Codable, CaseIterable {
    case preSaison    = "Pré-saison"
    case competition  = "Compétition"
    case transition   = "Transition"
    case repos        = "Repos"
    case tournoi      = "Tournoi"

    var icone: String {
        switch self {
        case .preSaison:   return "figure.run"
        case .competition: return "trophy.fill"
        case .transition:  return "arrow.triangle.2.circlepath"
        case .repos:       return "bed.double.fill"
        case .tournoi:     return "flag.checkered"
        }
    }

    var couleur: Color {
        switch self {
        case .preSaison:   return PaletteMat.orange
        case .competition: return PaletteMat.bleu
        case .transition:  return PaletteMat.violet
        case .repos:       return .secondary
        case .tournoi:     return PaletteMat.vert
        }
    }
}

// MARK: - Modèle PhaseSaison

@Model
final class PhaseSaison {
    var id: UUID = UUID()
    var nom: String = ""
    var typePhaseRaw: String = TypePhase.preSaison.rawValue
    var dateDebut: Date = Date()
    var dateFin: Date = Date()
    var objectifs: String = ""
    var volumeHebdo: Int = 0 // heures cibles par semaine
    var codeEquipe: String = ""
    var dateCreation: Date = Date()
    var dateModification: Date = Date()

    var typePhase: TypePhase {
        get { TypePhase(rawValue: typePhaseRaw) ?? .preSaison }
        set { typePhaseRaw = newValue.rawValue }
    }

    init(nom: String = "", type: TypePhase = .preSaison,
         dateDebut: Date = Date(), dateFin: Date = Date()) {
        self.id = UUID()
        self.nom = nom
        self.typePhaseRaw = type.rawValue
        self.dateDebut = dateDebut
        self.dateFin = dateFin
        self.dateCreation = Date()
    }
}

// MARK: - FiltreParEquipe

extension PhaseSaison: FiltreParEquipe {}
