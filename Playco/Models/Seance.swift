//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - Type de séance

enum TypeSeance: String, Codable, CaseIterable {
    case pratique = "Pratique"
    case match    = "Match"

    var label: String { rawValue }

    var icone: String {
        switch self {
        case .pratique: return "sportscourt.fill"
        case .match:    return "flag.fill"
        }
    }

    var couleur: Color {
        switch self {
        case .pratique: return Color(hex: "#E8734A")
        case .match:    return .red
        }
    }
}

// MARK: - Résultat match

enum ResultatMatch: String, Codable, CaseIterable {
    case victoire = "Victoire"
    case defaite  = "Défaite"
    case nul      = "Nul"

    var label: String { rawValue }

    var couleur: Color {
        switch self {
        case .victoire: return .green
        case .defaite:  return .red
        case .nul:      return .orange
        }
    }
}

// MARK: - Score par set

struct SetScore: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var numero: Int
    var scoreEquipe: Int = 0
    var scoreAdversaire: Int = 0

    var estTermine: Bool {
        let maxScore = max(scoreEquipe, scoreAdversaire)
        let minScore = min(scoreEquipe, scoreAdversaire)
        // Set standard (25) ou set décisif (15)
        let cible = numero >= 5 ? 15 : 25
        return maxScore >= cible && (maxScore - minScore) >= 2
    }

    var gagnant: String? {
        guard estTermine else { return nil }
        return scoreEquipe > scoreAdversaire ? "equipe" : "adversaire"
    }
}

// MARK: - Type d'action (stats live)

enum TypeActionPoint: String, Codable, CaseIterable {
    // MARK: Points pour nous
    case kill = "Kill"
    case ace = "Ace"
    case blocSeul = "Bloc seul"
    case blocAssiste = "Bloc assisté"
    case erreurAdversaire = "Erreur adv."

    // MARK: Points contre nous
    case erreurAttaque = "Err. attaque"
    case erreurService = "Err. service"
    case erreurBloc = "Err. bloc"
    case erreurReception = "Err. réception"
    case fauteJeu = "Faute de jeu"

    // MARK: Legacy (rétrocompatibilité anciennes données)
    case bloc = "Bloc"
    case erreurEquipe = "Erreur"

    /// Actions affichées dans l'interface (exclut les types legacy)
    static var actionsPointPourNous: [TypeActionPoint] {
        [.kill, .ace, .blocSeul, .blocAssiste, .erreurAdversaire]
    }

    static var actionsPointContre: [TypeActionPoint] {
        [.erreurAttaque, .erreurService, .erreurBloc, .erreurReception, .fauteJeu]
    }

    var icone: String {
        switch self {
        case .kill: return "flame.fill"
        case .ace: return "arrow.up.forward"
        case .blocSeul: return "shield.fill"
        case .blocAssiste: return "shield.lefthalf.filled"
        case .erreurAdversaire: return "xmark.circle"
        case .erreurAttaque: return "flame"
        case .erreurService: return "arrow.up.forward.circle"
        case .erreurBloc: return "shield.slash"
        case .erreurReception: return "arrow.down.left"
        case .fauteJeu: return "hand.raised"
        case .bloc: return "shield.fill"
        case .erreurEquipe: return "exclamationmark.triangle"
        }
    }

    var estPointPourNous: Bool {
        switch self {
        case .kill, .ace, .blocSeul, .blocAssiste, .bloc, .erreurAdversaire:
            return true
        case .erreurAttaque, .erreurService, .erreurBloc, .erreurReception,
             .fauteJeu, .erreurEquipe:
            return false
        }
    }

    /// Catégorie heatmap associée à cette action (nil = pas de zone pertinente)
    var categorieHeatmap: DonneesHeatmap.CategorieHeatmap? {
        switch self {
        case .kill, .erreurAttaque: return .attaque
        case .ace, .erreurService: return .service
        case .blocSeul, .blocAssiste, .bloc, .erreurBloc: return .bloc
        case .erreurReception: return .reception
        case .erreurAdversaire, .fauteJeu, .erreurEquipe: return nil
        }
    }

    /// Indique si cette action peut être associée à une zone du terrain
    var supportsZone: Bool { categorieHeatmap != nil }

    /// Indique si c'est un type de bloc (pour agrégation)
    var estBloc: Bool {
        switch self {
        case .blocSeul, .blocAssiste, .bloc: return true
        default: return false
        }
    }

    /// Indique si c'est une erreur de notre équipe (pour agrégation)
    var estErreurEquipe: Bool {
        switch self {
        case .erreurAttaque, .erreurService, .erreurBloc, .erreurReception,
             .fauteJeu, .erreurEquipe:
            return true
        default: return false
        }
    }
}

// MARK: - Type d'action rallye (non-marquante)

enum TypeActionRallye: String, Codable, CaseIterable {
    case manchette = "Manchette"
    case passeDecisive = "Passe déc."
    case reception = "Réception"
    case tentativeAttaque = "Tent. attaque"
    case serviceEnJeu = "Service en jeu"
    case dig = "Dig"

    var icone: String {
        switch self {
        case .manchette: return "hand.point.down.fill"
        case .passeDecisive: return "arrow.turn.up.right"
        case .reception: return "arrow.down.to.line"
        case .tentativeAttaque: return "flame.circle"
        case .serviceEnJeu: return "arrow.up.forward.app"
        case .dig: return "hand.point.down"
        }
    }

    var couleur: Color {
        switch self {
        case .manchette: return .teal
        case .passeDecisive: return .yellow
        case .reception: return .purple
        case .tentativeAttaque: return .orange
        case .serviceEnJeu: return .mint
        case .dig: return .cyan
        }
    }
}

@Model
final class Seance {
    var id: UUID = UUID()
    var nom: String = ""
    var date: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \Exercice.seance)
    var exercices: [Exercice]?

    /// P3-01 — Soft delete : archivée au lieu de supprimée
    var estArchivee: Bool = false

    /// Code équipe — filtre multi-équipe
    var codeEquipe: String = ""

    /// Type : pratique ou match
    var typeSeanceRaw: String = TypeSeance.pratique.rawValue

    /// Champs spécifiques aux matchs
    var adversaire: String = ""
    var lieu: String = ""
    var scoreEquipe: Int = 0
    var scoreAdversaire: Int = 0
    var resultatRaw: String = ""
    var notesMatch: String = ""
    var statsEntrees: Bool = false

    /// Score détaillé par set (JSON [SetScore])
    var setsData: Data? = nil

    /// Données de composition/lineup (JSON [UUID])
    var compositionData: Data? = nil

    /// Partants : joueurs assignés aux postes 1-6 (JSON [PartantMatch])
    var partantsData: Data? = nil

    /// ID du libéro (vide = pas de libéro)
    var liberoID: String = ""

    /// Historique des substitutions (JSON [SubstitutionRecord])
    var substitutionsData: Data? = nil

    /// Historique des temps morts (JSON [TempsMortRecord])
    var tempsMortsData: Data? = nil

    /// Configuration du match (JSON ConfigMatch)
    var configMatchData: Data? = nil

    /// Historique des rotations par set (JSON [[Int: Int]] — set → rotation)
    var rotationsHistoriqueData: Data? = nil

    /// Qui sert au début du match : true = nous, false = adversaire
    var nousServonsEnPremier: Bool = true

    /// Computed : score par set décodé
    var sets: [SetScore] {
        get {
            guard let d = setsData else { return [] }
            return (try? JSONCoderCache.decoder.decode([SetScore].self, from: d)) ?? []
        }
        set {
            setsData = try? JSONCoderCache.encoder.encode(newValue)
            // Recalculer le score global (sets gagnés/perdus)
            let gagnes = newValue.filter { $0.scoreEquipe > $0.scoreAdversaire }.count
            let perdus = newValue.filter { $0.scoreEquipe < $0.scoreAdversaire }.count
            scoreEquipe = gagnes
            scoreAdversaire = perdus
            // Résultat auto
            if gagnes > perdus { resultat = .victoire }
            else if gagnes < perdus { resultat = .defaite }
            else if gagnes == perdus && gagnes > 0 { resultat = .nul }
        }
    }

    /// Nombre total de sets joués
    var nombreSets: Int { sets.count }

    /// Partants décodés
    var partants: [PartantMatch] {
        get {
            guard let d = partantsData else { return [] }
            return (try? JSONCoderCache.decoder.decode([PartantMatch].self, from: d)) ?? []
        }
        set {
            partantsData = try? JSONCoderCache.encoder.encode(newValue)
        }
    }

    /// Libéro UUID (nil si pas de libéro)
    var liberoUUID: UUID? {
        get { UUID(uuidString: liberoID) }
        set { liberoID = newValue?.uuidString ?? "" }
    }

    /// Substitutions décodées
    var substitutions: [SubstitutionRecord] {
        get {
            guard let d = substitutionsData else { return [] }
            return (try? JSONCoderCache.decoder.decode([SubstitutionRecord].self, from: d)) ?? []
        }
        set {
            substitutionsData = try? JSONCoderCache.encoder.encode(newValue)
        }
    }

    /// Temps morts décodés
    var tempsMorts: [TempsMortRecord] {
        get {
            guard let d = tempsMortsData else { return [] }
            return (try? JSONCoderCache.decoder.decode([TempsMortRecord].self, from: d)) ?? []
        }
        set {
            tempsMortsData = try? JSONCoderCache.encoder.encode(newValue)
        }
    }

    /// Configuration match décodée
    var configMatch: ConfigMatch {
        get {
            guard let d = configMatchData else { return ConfigMatch() }
            return (try? JSONCoderCache.decoder.decode(ConfigMatch.self, from: d)) ?? ConfigMatch()
        }
        set {
            configMatchData = try? JSONCoderCache.encoder.encode(newValue)
        }
    }

    /// Historique des rotations par set (clé = numéro de set, valeur = liste de rotations)
    var rotationsHistorique: [Int: [Int]] {
        get {
            guard let d = rotationsHistoriqueData else { return [:] }
            return (try? JSONCoderCache.decoder.decode([Int: [Int]].self, from: d)) ?? [:]
        }
        set {
            rotationsHistoriqueData = try? JSONCoderCache.encoder.encode(newValue)
        }
    }

    /// Composition du match (IDs des joueurs titulaires)
    var compositionJoueurs: [UUID] {
        get {
            guard let d = compositionData else { return [] }
            return (try? JSONCoderCache.decoder.decode([UUID].self, from: d)) ?? []
        }
        set {
            compositionData = try? JSONCoderCache.encoder.encode(newValue)
        }
    }

    var typeSeance: TypeSeance {
        get { TypeSeance(rawValue: typeSeanceRaw) ?? .pratique }
        set { typeSeanceRaw = newValue.rawValue }
    }

    var resultat: ResultatMatch? {
        get { ResultatMatch(rawValue: resultatRaw) }
        set { resultatRaw = newValue?.rawValue ?? "" }
    }

    var estMatch: Bool { typeSeance == .match }
    var scoreEntre: Bool { scoreEquipe > 0 || scoreAdversaire > 0 }

    init(nom: String, date: Date = Date(), typeSeance: TypeSeance = .pratique) {
        self.id = UUID()
        self.nom = nom
        self.date = date
        self.exercices = []
        self.typeSeanceRaw = typeSeance.rawValue
    }
}
