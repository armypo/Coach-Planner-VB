//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftData

/// Point individuel enregistré en temps réel pendant un match
@Model
final class PointMatch {
    var id: UUID = UUID()
    var seanceID: UUID = UUID()
    var set: Int = 1
    var scoreEquipeAuMoment: Int = 0
    var scoreAdversaireAuMoment: Int = 0
    var joueurID: UUID? = nil
    var typeActionRaw: String = TypeActionPoint.kill.rawValue
    var rotationAuMoment: Int = 1
    var rotationAdvAuMoment: Int = 1
    var codeEquipe: String = ""
    var horodatage: Date = Date()
    /// Zone du terrain (1-6) où l'action a eu lieu. 0 = non assignée.
    var zone: Int = 0
    /// Zone de départ (1-6) pour les trajectoires service/attaque. 0 = non assignée.
    var zoneDepart: Int = 0
    /// Vrai si NOUS servions au début de ce rallye (sideout %, D5).
    var nousServionsAuMoment: Bool = false
    /// Vrai si `nousServionsAuMoment` a été renseigné à la saisie — les
    /// anciens matchs (false) passent par la reconstruction déterministe.
    var serviceRenseigne: Bool = false

    var typeAction: TypeActionPoint {
        get { TypeActionPoint(rawValue: typeActionRaw) ?? .kill }
        set { typeActionRaw = newValue.rawValue }
    }

    var estPointPourNous: Bool { typeAction.estPointPourNous }

    init(seanceID: UUID, set: Int, joueurID: UUID? = nil, typeAction: TypeActionPoint) {
        self.id = UUID()
        self.seanceID = seanceID
        self.set = set
        self.joueurID = joueurID
        self.typeActionRaw = typeAction.rawValue
        self.horodatage = Date()
    }
}
