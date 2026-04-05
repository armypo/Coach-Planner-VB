//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftData

// MARK: - Type d'établissement

enum TypeEtablissement: String, Codable, CaseIterable {
    case universite      = "Université"
    case cegep           = "Cégep"
    case college         = "Collège"
    case ecoleSecondaire = "École secondaire"
    case club            = "Club"
    case autre           = "Autre"
}

// MARK: - Modèle Établissement

@Model
final class Etablissement {
    var id: UUID = UUID()
    var nom: String = ""
    var typeRaw: String = TypeEtablissement.universite.rawValue
    var ville: String = ""
    var province: String = "QC"
    @Attribute(.externalStorage) var logo: Data? = nil
    var dateCreation: Date = Date()
    var dateModification: Date = Date()

    // Relations inverses (CloudKit exige un inverse pour chaque relation)
    @Relationship(inverse: \ProfilCoach.etablissement)
    var profils: [ProfilCoach]? = nil
    var equipes: [Equipe]? = nil

    var typeEtablissement: TypeEtablissement {
        get { TypeEtablissement(rawValue: typeRaw) ?? .universite }
        set { typeRaw = newValue.rawValue }
    }

    init(nom: String = "", type: TypeEtablissement = .universite, ville: String = "", province: String = "QC") {
        self.id = UUID()
        self.nom = nom
        self.typeRaw = type.rawValue
        self.ville = ville
        self.province = province
        self.dateCreation = Date()
    }
}
