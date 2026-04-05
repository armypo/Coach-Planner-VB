//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftData

/// Évaluation d'un joueur après une séance (par le coach)
@Model
final class Evaluation {
    var id: UUID = UUID()
    var joueurID: UUID = UUID()
    var seanceID: UUID = UUID()
    var dateEvaluation: Date = Date()

    // Notes sur 5
    var noteEffort: Int = 0       // 1 à 5
    var noteTechnique: Int = 0    // 1 à 5
    var noteAttitude: Int = 0     // 1 à 5
    var commentaire: String = ""

    // Noms pour affichage
    var joueurPrenom: String = ""
    var joueurNom: String = ""
    var seanceNom: String = ""

    var moyenneGenerale: Double {
        let total = noteEffort + noteTechnique + noteAttitude
        return total > 0 ? Double(total) / 3.0 : 0
    }

    init(joueurID: UUID, seanceID: UUID, seanceNom: String, joueurPrenom: String, joueurNom: String) {
        self.id = UUID()
        self.joueurID = joueurID
        self.seanceID = seanceID
        self.seanceNom = seanceNom
        self.dateEvaluation = Date()
        self.joueurPrenom = joueurPrenom
        self.joueurNom = joueurNom
    }
}
