//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftData

// MARK: - Rôle assistant

enum RoleAssistant: String, Codable, CaseIterable {
    case assistantCoach      = "Assistant coach"
    case preparateurPhysique = "Préparateur physique"
    case analyste            = "Analyste"
    case physio              = "Physio"
}

// MARK: - Modèle Assistant Coach

@Model
final class AssistantCoach {
    var id: UUID = UUID()
    var prenom: String = ""
    var nom: String = ""
    var courriel: String = ""
    var roleRaw: String = RoleAssistant.assistantCoach.rawValue
    var identifiant: String = ""
    var motDePasseHash: String = ""
    var sel: String = ""
    var codeEquipe: String = ""
    var dateCreation: Date = Date()

    var equipe: Equipe? = nil

    var roleAssistant: RoleAssistant {
        get { RoleAssistant(rawValue: roleRaw) ?? .assistantCoach }
        set { roleRaw = newValue.rawValue }
    }

    var nomComplet: String { "\(prenom) \(nom)" }

    init(prenom: String = "", nom: String = "") {
        self.id = UUID()
        self.prenom = prenom
        self.nom = nom
        self.dateCreation = Date()
    }
}
