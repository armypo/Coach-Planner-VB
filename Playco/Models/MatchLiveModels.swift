//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftUI

// MARK: - Partant (joueur assigné à un poste pour le match)

struct PartantMatch: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    /// Poste sur le terrain (1 à 6)
    var poste: Int
    /// ID du joueur assigné à ce poste
    var joueurID: UUID

    init(poste: Int, joueurID: UUID) {
        self.id = UUID()
        self.poste = poste
        self.joueurID = joueurID
    }
}

// MARK: - Joueur actuellement sur le terrain (calculé à partir des partants + subs)

struct JoueurSurTerrain: Identifiable, Equatable {
    var id: UUID { joueurID }
    var poste: Int          // 1-6
    var joueurID: UUID
    var numero: Int
    var prenom: String
    var nom: String
    var estLibero: Bool = false
}

// MARK: - Substitution

struct SubstitutionRecord: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var set: Int
    var joueurSortantID: UUID
    var joueurEntrantID: UUID
    var scoreNousAuMoment: Int = 0
    var scoreAdvAuMoment: Int = 0
    var horodatage: Date = Date()

    init(set: Int, joueurSortantID: UUID, joueurEntrantID: UUID) {
        self.id = UUID()
        self.set = set
        self.joueurSortantID = joueurSortantID
        self.joueurEntrantID = joueurEntrantID
        self.horodatage = Date()
    }
}

// MARK: - Temps mort

struct TempsMortRecord: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var set: Int
    /// "nous" ou "adversaire"
    var equipe: String
    var scoreNousAuMoment: Int = 0
    var scoreAdvAuMoment: Int = 0
    var horodatage: Date = Date()

    init(set: Int, equipe: String) {
        self.id = UUID()
        self.set = set
        self.equipe = equipe
        self.horodatage = Date()
    }
}

// MARK: - Configuration match

/// Configuration non-isolée pour permettre l'encodage/décodage depuis n'importe quel contexte
/// (notamment lors de la désérialisation depuis SwiftData / JSONCoderCache nonisolated).
nonisolated struct ConfigMatch: Codable, Equatable, Sendable {
    /// Nombre max de substitutions par set (FIVB: 6)
    var subsMaxParSet: Int = 6
    /// Temps morts techniques activés (8 et 16 pts, sets 1-4)
    var ttoActifs: Bool = false
    /// Nombre de temps morts par set par équipe (FIVB: 2)
    var tempsMortsParSetParEquipe: Int = 2
}

// MARK: - Catégorie de statistique (pour le mapping score)

enum CategorieStatistique: String, Codable {
    case pointPourNous = "Point pour nous"
    case pointContre = "Point adversaire"
    case neutre = "Neutre"
}

// MARK: - Définition d'une statistique affichable

struct DefinitionStat: Identifiable, Equatable {
    var id: String { action.rawValue }
    let action: TypeActionPoint
    let label: String
    let icone: String
    let categorie: CategorieStatistique
    let couleur: Color

    static let toutesStats: [DefinitionStat] = [
        // Points pour nous (actions de NOS joueurs)
        DefinitionStat(action: .kill, label: "Kill", icone: "flame.fill", categorie: .pointPourNous, couleur: .green),
        DefinitionStat(action: .ace, label: "Ace", icone: "arrow.up.forward", categorie: .pointPourNous, couleur: .green),
        DefinitionStat(action: .blocSeul, label: "Bloc seul", icone: "shield.fill", categorie: .pointPourNous, couleur: .green),
        DefinitionStat(action: .blocAssiste, label: "Bloc assisté", icone: "shield.lefthalf.filled", categorie: .pointPourNous, couleur: .green),

        // Points contre nous
        DefinitionStat(action: .erreurAttaque, label: "Err. attaque", icone: "flame", categorie: .pointContre, couleur: .red),
        DefinitionStat(action: .erreurService, label: "Err. service", icone: "arrow.up.forward.circle", categorie: .pointContre, couleur: .red),
        DefinitionStat(action: .erreurBloc, label: "Err. bloc", icone: "shield.slash", categorie: .pointContre, couleur: .red),
        DefinitionStat(action: .erreurReception, label: "Err. réception", icone: "arrow.down.left", categorie: .pointContre, couleur: .red),
        DefinitionStat(action: .fauteJeu, label: "Faute de jeu", icone: "hand.raised", categorie: .pointContre, couleur: .red),
    ]

    static let statsPourNous: [DefinitionStat] = toutesStats.filter { $0.categorie == .pointPourNous }

    static let statsContre: [DefinitionStat] = toutesStats.filter { $0.categorie == .pointContre }

    /// Stats adversaire : leurs actions marquantes (point contre nous)
    static let statsAdversaireScoring: [DefinitionStat] = [
        DefinitionStat(action: .killAdversaire, label: "Kill adv.", icone: "flame.fill", categorie: .pointContre, couleur: .red),
        DefinitionStat(action: .aceAdversaire, label: "Ace adv.", icone: "arrow.up.forward", categorie: .pointContre, couleur: .red),
        DefinitionStat(action: .blocAdversaire, label: "Bloc adv.", icone: "shield.fill", categorie: .pointContre, couleur: .red),
    ]

    /// Stats adversaire : leurs erreurs (point pour nous)
    static let statsAdversaireErreurs: [DefinitionStat] = [
        DefinitionStat(action: .erreurAdversaire, label: "Erreur adv.", icone: "xmark.circle", categorie: .pointPourNous, couleur: .green),
        DefinitionStat(action: .erreurAttaqueAdversaire, label: "Err. att. adv.", icone: "flame", categorie: .pointPourNous, couleur: .green),
        DefinitionStat(action: .erreurServiceAdversaire, label: "Err. serv. adv.", icone: "arrow.up.forward.circle", categorie: .pointPourNous, couleur: .green),
    ]

    /// Toutes les stats adversaire combinées (scoring + erreurs)
    static let statsAdversaire: [DefinitionStat] = statsAdversaireScoring + statsAdversaireErreurs
}
