//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftData

/// Présence d'un joueur à une séance
@Model
final class Presence {
    var id: UUID = UUID()
    var joueurID: UUID = UUID()
    var seanceID: UUID = UUID()
    var estPresent: Bool = true
    var dateMarquee: Date = Date()

    // Noms stockés pour affichage rapide
    var joueurPrenom: String = ""
    var joueurNom: String = ""

    init(joueurID: UUID, seanceID: UUID, estPresent: Bool, joueurPrenom: String, joueurNom: String) {
        self.id = UUID()
        self.joueurID = joueurID
        self.seanceID = seanceID
        self.estPresent = estPresent
        self.dateMarquee = Date()
        self.joueurPrenom = joueurPrenom
        self.joueurNom = joueurNom
    }
}
