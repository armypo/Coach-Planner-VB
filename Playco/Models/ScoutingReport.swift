//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftData

// MARK: - Modèle principal

@Model
final class ScoutingReport {
    var id: UUID = UUID()
    var adversaire: String = ""
    var dateMatch: Date = Date()
    var codeEquipe: String = ""
    var estArchive: Bool = false
    var dateCreation: Date = Date()

    /// Lien optionnel vers le match (`Seance` de type .match) que ce rapport prépare.
    /// UUID simple (pas de relation SwiftData) : CloudKit-safe, nil par défaut.
    var seanceID: UUID? = nil

    // Infos générales
    var systemJeu: String = ""          // ex: "5-1", "6-2", "4-2"
    var styleJeu: String = ""           // ex: "Offensif", "Défensif", "Équilibré"
    var notes: String = ""

    /// Adversaire du match observé (contre qui jouait l'équipe scoutée)
    var adversaireObserve: String = ""

    // Joueurs clés adverses (JSON encoded array)
    var joueursData: Data = Data()      // [JoueurAdverse] encoded

    // Forces et faiblesses (JSON encoded)
    var forcesData: Data = Data()       // [String] encoded
    var faiblessesData: Data = Data()   // [String] encoded

    // Stratégies recommandées (JSON encoded)
    var strategiesData: Data = Data()   // [StrategieRecommandee] encoded

    // Tendances observées
    var tendanceService: String = ""     // ex: "Sert principalement zone 1 et 5"
    var tendanceAttaque: String = ""     // ex: "Attaque rapide au centre"
    var tendanceReception: String = ""   // ex: "Faiblesse en réception zone 6"
    var tendanceBloc: String = ""        // ex: "Bloc double sur l'extérieur"

    /// Tendances zonales service/attaque (JSON encoded `TendancesZonales`).
    /// Data() par défaut : CloudKit-safe, décode en tendances vides.
    var tendancesZonalesData: Data = Data()

    init() {}

    // MARK: - Computed properties (JSONCoderCache)

    var joueurs: [JoueurAdverse] {
        get { (try? JSONCoderCache.decoder.decode([JoueurAdverse].self, from: joueursData)) ?? [] }
        set { joueursData = (try? JSONCoderCache.encoder.encode(newValue)) ?? Data() }
    }

    var forces: [String] {
        get { (try? JSONCoderCache.decoder.decode([String].self, from: forcesData)) ?? [] }
        set { forcesData = (try? JSONCoderCache.encoder.encode(newValue)) ?? Data() }
    }

    var faiblesses: [String] {
        get { (try? JSONCoderCache.decoder.decode([String].self, from: faiblessesData)) ?? [] }
        set { faiblessesData = (try? JSONCoderCache.encoder.encode(newValue)) ?? Data() }
    }

    var strategies: [StrategieRecommandee] {
        get { (try? JSONCoderCache.decoder.decode([StrategieRecommandee].self, from: strategiesData)) ?? [] }
        set { strategiesData = (try? JSONCoderCache.encoder.encode(newValue)) ?? Data() }
    }

    var tendancesZonales: TendancesZonales {
        get { (try? JSONCoderCache.decoder.decode(TendancesZonales.self, from: tendancesZonalesData)) ?? TendancesZonales() }
        set { tendancesZonalesData = (try? JSONCoderCache.encoder.encode(newValue)) ?? Data() }
    }

    // MARK: - Duplication

    /// Copie un rapport existant pour préparer un nouveau match contre le même
    /// adversaire : reprend tout le contenu d'analyse (joueurs, forces/faiblesses,
    /// stratégies, tendances texte et zonales) mais repart avec une nouvelle
    /// identité (id, dates du jour) et AUCUN match lié (`seanceID` nil).
    /// Retourne un nouvel objet — l'original n'est jamais muté.
    static func dupliquer(_ source: ScoutingReport) -> ScoutingReport {
        let copie = ScoutingReport()
        copie.adversaire = source.adversaire
        copie.codeEquipe = source.codeEquipe
        copie.systemJeu = source.systemJeu
        copie.styleJeu = source.styleJeu
        copie.notes = source.notes
        copie.adversaireObserve = source.adversaireObserve
        copie.joueursData = source.joueursData
        copie.forcesData = source.forcesData
        copie.faiblessesData = source.faiblessesData
        copie.strategiesData = source.strategiesData
        copie.tendanceService = source.tendanceService
        copie.tendanceAttaque = source.tendanceAttaque
        copie.tendanceReception = source.tendanceReception
        copie.tendanceBloc = source.tendanceBloc
        copie.tendancesZonalesData = source.tendancesZonalesData
        copie.dateMatch = Date()
        copie.dateCreation = Date()
        copie.seanceID = nil
        return copie
    }
}

// MARK: - FiltreParEquipe

extension ScoutingReport: FiltreParEquipe {}

// MARK: - Structs Codable

struct JoueurAdverse: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var numero: Int = 0
    var nom: String = ""
    var poste: String = ""          // Libre text: "Attaquant", "Passeur", etc.
    var pointsForts: String = ""
    var pointsFaibles: String = ""
    var menaceNiveau: Int = 1       // 1-5 threat level
}

struct StrategieRecommandee: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var titre: String = ""
    var description: String = ""
    var priorite: Int = 1           // 1=haute, 2=moyenne, 3=basse
    var categorie: String = ""      // "Service", "Attaque", "Bloc", "Réception", "Général"
}

/// Tendances zonales : niveau de menace 0-3 par zone volley (1-6) pour le
/// service adverse et l'attaque adverse. `nonisolated` : struct valeur pure
/// utilisable hors MainActor (SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor).
nonisolated struct TendancesZonales: Codable, Equatable, Sendable {
    /// Zone (1-6) → niveau de menace (0 aucune … 3 forte) au service adverse.
    var service: [Int: Int] = [:]
    /// Zone (1-6) → niveau de menace (0 aucune … 3 forte) à l'attaque adverse.
    var attaque: [Int: Int] = [:]

    /// Bornes du niveau de menace zonal.
    static let niveauMin = 0
    static let niveauMax = 3

    /// Niveau suivant dans le cycle 0 → 1 → 2 → 3 → 0 (tap sur une zone).
    static func niveauSuivant(_ niveau: Int) -> Int {
        niveau >= niveauMax ? niveauMin : niveau + 1
    }
}
