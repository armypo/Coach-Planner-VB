//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftData

/// DÉPRÉCIÉ (v2.0.1/SIWA) — modèle DORMANT, conservé dans le schéma uniquement
/// pour éviter une migration SwiftData+CloudKit destructive. N'est plus créé, ni
/// publié, ni importé : les matchs sont représentés par `Seance` (type=.match),
/// seule source lue par l'UI (coach + athlète). Suppression complète = étape de
/// migration séparée (test réinstallation propre).
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
