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

    /// Tier d'abonnement propagé depuis le coach propriétaire. Public via CloudKit
    /// pour que les athlètes (potentiellement sur un autre Apple ID) puissent
    /// vérifier l'éligibilité Club avant de se connecter.
    var tierAbonnementRaw: String = Tier.aucun.rawValue

    /// Tier typé (accesseur computed).
    var tierAbonnement: Tier {
        get { Tier(rawValue: tierAbonnementRaw) ?? .aucun }
        set { tierAbonnementRaw = newValue.rawValue }
    }

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

    // MARK: - Génération code équipe haute entropie

    /// Alphabet Base32 Crockford sans caractères ambigus (0/O/1/I/L).
    /// 31 symboles × 8 positions ≈ 40 bits d'entropie.
    static let alphabetCodeEquipe = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"

    /// Génère un code équipe de 8 caractères via CSPRNG.
    static func genererCodeEquipe() -> String {
        var rng = SystemRandomNumberGenerator()
        let alphabet = Array(alphabetCodeEquipe)
        let n = UInt64(alphabet.count)
        return String((0..<8).map { _ in
            alphabet[Int(rng.next() % n)]
        })
    }

    /// Normalise une saisie utilisateur (uppercase + filtre alphabet).
    static func normaliserCodeEquipe(_ saisie: String) -> String {
        let majuscule = saisie.uppercased()
        let autorises = Set(alphabetCodeEquipe)
        return String(majuscule.filter { autorises.contains($0) })
    }

    /// Vérifie qu'un code respecte le format 8-char alphabet restreint.
    static func codeEquipeValide(_ code: String) -> Bool {
        guard code.count == 8 else { return false }
        let autorises = Set(alphabetCodeEquipe)
        return code.allSatisfy { autorises.contains($0) }
    }
}
