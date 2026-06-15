//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftData

/// Match planifié dans le calendrier
@Model
final class MatchCalendrier {
    var id: UUID = UUID()
    var date: Date = Date()
    var adversaire: String = ""
    var lieu: String = ""
    var estDomicile: Bool = true

    /// Code équipe — filtre multi-équipe + clé de partage Public DB (athlètes cross-Apple-ID).
    var codeEquipe: String = ""
    /// Horodatage de dernière modification — merge Public DB.
    var dateModification: Date = Date()

    var equipe: Equipe? = nil

    init(date: Date = Date(), adversaire: String = "") {
        self.id = UUID()
        self.date = date
        self.adversaire = adversaire
    }
}
