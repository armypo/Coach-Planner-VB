//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftData

// MARK: - Rôle du coach

enum RoleCoach: String, Codable, CaseIterable {
    case entraineurChef       = "Entraîneur-chef"
    case entraineurAdjoint    = "Entraîneur adjoint"
    case entraineurTechnique  = "Entraîneur technique"
    case preparateurPhysique  = "Préparateur physique"
    case analyste             = "Analyste"
}

// MARK: - Type de sport

enum SportType: String, Codable, CaseIterable {
    case indoor = "Volleyball intérieur"
    case beach  = "Volleyball de plage"
    case lesDeux = "Les deux"

    var icone: String {
        switch self {
        case .indoor:  return "sportscourt.fill"
        case .beach:   return "sun.max.fill"
        case .lesDeux: return "arrow.triangle.2.circlepath"
        }
    }

    var description: String {
        switch self {
        case .indoor:  return "6 contre 6, terrain indoor"
        case .beach:   return "2 contre 2, terrain beach"
        case .lesDeux: return "Indoor et beach combinés"
        }
    }
}

// MARK: - Modèle Profil Coach

@Model
final class ProfilCoach {
    var id: UUID = UUID()
    var prenom: String = ""
    var nom: String = ""
    var courriel: String = ""
    var telephone: String = ""
    var sportRaw: String = SportType.indoor.rawValue
    var roleRaw: String = RoleCoach.entraineurChef.rawValue
    @Attribute(.externalStorage) var photo: Data? = nil
    var configurationCompletee: Bool = false
    var dateCreation: Date = Date()

    /// Masquer le contenu des pratiques pour les athlètes
    var masquerPratiquesAthletes: Bool = false

    // Relation
    var etablissement: Etablissement? = nil

    var sport: SportType {
        get { SportType(rawValue: sportRaw) ?? .indoor }
        set { sportRaw = newValue.rawValue }
    }

    var roleCoach: RoleCoach {
        get { RoleCoach(rawValue: roleRaw) ?? .entraineurChef }
        set { roleRaw = newValue.rawValue }
    }

    var nomComplet: String { "\(prenom) \(nom)" }

    init() {
        self.id = UUID()
        self.dateCreation = Date()
    }
}
