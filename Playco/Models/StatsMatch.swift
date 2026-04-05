//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftData

/// Statistiques d'un joueur pour un match spécifique
@Model
final class StatsMatch {
    var id: UUID = UUID()
    var seanceID: UUID = UUID()
    var joueurID: UUID = UUID()

    /// Code équipe — filtre multi-équipe
    var codeEquipe: String = ""

    // Attaque
    var kills: Int = 0
    var erreursAttaque: Int = 0
    var tentativesAttaque: Int = 0

    // Service
    var aces: Int = 0
    var erreursService: Int = 0
    var servicesTotaux: Int = 0

    // Bloc
    var blocsSeuls: Int = 0
    var blocsAssistes: Int = 0
    var erreursBloc: Int = 0

    // Réception
    var receptionsReussies: Int = 0
    var erreursReception: Int = 0
    var receptionsTotales: Int = 0

    // Jeu
    var passesDecisives: Int = 0
    var manchettes: Int = 0

    // Sets joués dans ce match
    var setsJoues: Int = 0

    // Computed
    var points: Int {
        kills + aces + blocsSeuls + Int(Double(blocsAssistes) * 0.5)
    }

    var hittingPct: Double {
        guard tentativesAttaque > 0 else { return 0 }
        return Double(kills - erreursAttaque) / Double(tentativesAttaque)
    }

    init(seanceID: UUID, joueurID: UUID) {
        self.id = UUID()
        self.seanceID = seanceID
        self.joueurID = joueurID
    }
}
