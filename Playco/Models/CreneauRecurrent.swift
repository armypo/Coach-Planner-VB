//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftData

/// Créneau d'entraînement récurrent (ex: mardi 18h-20h)
@Model
final class CreneauRecurrent {
    var id: UUID = UUID()
    /// 1=lundi, 2=mardi ... 7=dimanche
    var jourSemaine: Int = 1
    var heureDebut: Date = Date()
    var dureeMinutes: Int = 120
    var lieu: String = ""

    var equipe: Equipe? = nil

    /// Label jour lisible
    var jourLabel: String {
        switch jourSemaine {
        case 1: return "Lundi"
        case 2: return "Mardi"
        case 3: return "Mercredi"
        case 4: return "Jeudi"
        case 5: return "Vendredi"
        case 6: return "Samedi"
        case 7: return "Dimanche"
        default: return "Jour \(jourSemaine)"
        }
    }

    /// Label durée
    var dureeLabel: String {
        let h = dureeMinutes / 60
        let m = dureeMinutes % 60
        if m == 0 { return "\(h)h" }
        return "\(h)h\(m)"
    }

    init(jourSemaine: Int = 1, dureeMinutes: Int = 120) {
        self.id = UUID()
        self.jourSemaine = jourSemaine
        self.dureeMinutes = dureeMinutes
    }
}
