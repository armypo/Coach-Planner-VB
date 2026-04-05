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
