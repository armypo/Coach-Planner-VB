//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Catégorie d'équipe

enum CategorieEquipe: String, Codable, CaseIterable {
    case masculin = "Masculin"
    case feminin  = "Féminin"
}

// MARK: - Division d'équipe

enum DivisionEquipe: String, Codable, CaseIterable {
    case division1  = "Division 1"
    case division2  = "Division 2"
    case division3  = "Division 3"
    case recreatif  = "Récréatif"
    case autre      = "Autre"
}

// MARK: - Modèle Équipe

@Model
final class Equipe {
    var id: UUID = UUID()
    var nom: String = ""
    var categorieRaw: String = CategorieEquipe.masculin.rawValue
    var divisionRaw: String = DivisionEquipe.division1.rawValue
    var saison: String = ""
    var couleurPrincipalHex: String = "#FF6B35"
    var couleurSecondaireHex: String = "#2563EB"
    var dateCreation: Date = Date()

    /// Code partageable pour rejoindre l'équipe (= codeEcole dans Utilisateur)
    var codeEquipe: String = ""
    var dateModification: Date = Date()

    // Relations
    @Relationship(inverse: \Etablissement.equipes)
    var etablissement: Etablissement? = nil

    // Relations inverses (CloudKit exige un inverse pour chaque relation)
    @Relationship(deleteRule: .cascade, inverse: \AssistantCoach.equipe)
    var assistants: [AssistantCoach]? = nil
    @Relationship(deleteRule: .cascade, inverse: \CreneauRecurrent.equipe)
    var creneaux: [CreneauRecurrent]? = nil
    @Relationship(deleteRule: .cascade, inverse: \MatchCalendrier.equipe)
    var matchsCalendrier: [MatchCalendrier]? = nil

    @Relationship(deleteRule: .nullify, inverse: \JoueurEquipe.equipe)
    var joueurs: [JoueurEquipe]? = nil

    var categorie: CategorieEquipe {
        get { CategorieEquipe(rawValue: categorieRaw) ?? .masculin }
        set { categorieRaw = newValue.rawValue }
    }

    var division: DivisionEquipe {
        get { DivisionEquipe(rawValue: divisionRaw) ?? .division1 }
        set { divisionRaw = newValue.rawValue }
    }

    var couleurPrincipale: Color {
        Color(hex: couleurPrincipalHex)
    }

    var couleurSecondaire: Color {
        Color(hex: couleurSecondaireHex)
    }

    init(nom: String = "") {
        self.id = UUID()
        self.nom = nom
        self.dateCreation = Date()
    }
}
