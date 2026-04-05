//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftData

/// Action non-marquante enregistrée pendant un rallye (manchette, passe décisive, réception)
@Model
final class ActionRallye {
    var id: UUID = UUID()
    var seanceID: UUID = UUID()
    var set: Int = 1
    var joueurID: UUID = UUID()
    var typeRaw: String = TypeActionRallye.manchette.rawValue
    /// Qualité (réception uniquement) : 0=N/A, 1=mauvaise, 2=bonne, 3=parfaite
    var qualite: Int = 0
    var codeEquipe: String = ""
    var horodatage: Date = Date()
    /// Lien optionnel vers le PointMatch que cette action a précédé
    var pointMatchID: UUID? = nil

    var typeAction: TypeActionRallye {
        get { TypeActionRallye(rawValue: typeRaw) ?? .manchette }
        set { typeRaw = newValue.rawValue }
    }

    init(seanceID: UUID, set: Int, joueurID: UUID, typeAction: TypeActionRallye) {
        self.id = UUID()
        self.seanceID = seanceID
        self.set = set
        self.joueurID = joueurID
        self.typeRaw = typeAction.rawValue
        self.horodatage = Date()
    }
}
