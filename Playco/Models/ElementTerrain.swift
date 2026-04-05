//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftUI
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "ElementTerrain")

// MARK: - Élément terrain (P1-03 versionnement JSON + P1-04 Equatable)
struct ElementTerrain: Identifiable, Codable, Equatable {
    /// Version du schéma — incrémentée lors de changements structurels (P1-03)
    static let schemaVersion = 1
    var version: Int = Self.schemaVersion

    var id: UUID = UUID()
    var type: TypeElement
    var x: Double
    var y: Double
    var toX: Double?
    var toY: Double?
    var ctrlX: Double?        // point de contrôle Bézier (nil = ligne droite)
    var ctrlY: Double?
    var label: String = ""    // numéro joueur
    var texte: String = ""    // label optionnel sur flèche/trajectoire
    var estPointille: Bool = false
    var r: Double
    var g: Double
    var b: Double

    enum TypeElement: String, Codable {
        case joueur        // cercle avec numéro
        case ballon        // 🏐
        case fleche        // ligne droite + pointe
        case trajectoire   // arc Bézier pointillé + pointe (trajet ballon)
        case rotation      // flèche circulaire (rotation joueur)
    }

    var couleur: Color { Color(red: r, green: g, blue: b) }

    init(type: TypeElement,
         x: Double, y: Double,
         toX: Double? = nil, toY: Double? = nil,
         ctrlX: Double? = nil, ctrlY: Double? = nil,
         label: String = "",
         texte: String = "",
         estPointille: Bool = false,
         couleur: Color) {
        self.type  = type
        self.x = x; self.y = y
        self.toX = toX; self.toY = toY
        self.ctrlX = ctrlX; self.ctrlY = ctrlY
        self.label = label
        self.texte = texte
        self.estPointille = estPointille
        let ui = UIColor(couleur)
        var rr: CGFloat = 1, gg: CGFloat = 1, bb: CGFloat = 1, aa: CGFloat = 1
        ui.getRed(&rr, green: &gg, blue: &bb, alpha: &aa)
        self.r = Double(rr); self.g = Double(gg); self.b = Double(bb)
    }

    /// P2-02 v0.4.0 — Init interne avec RGB directs (évite conversion Color→UIColor→getRed)
    init(type: TypeElement, x: Double, y: Double,
         toX: Double? = nil, toY: Double? = nil,
         ctrlX: Double? = nil, ctrlY: Double? = nil,
         label: String = "", texte: String = "",
         estPointille: Bool = false,
         r: Double, g: Double, b: Double) {
        self.type = type
        self.x = x; self.y = y
        self.toX = toX; self.toY = toY
        self.ctrlX = ctrlX; self.ctrlY = ctrlY
        self.label = label; self.texte = texte
        self.estPointille = estPointille
        self.r = r; self.g = g; self.b = b
    }

    // MARK: Decodable avec migration (P1-03)
    enum CodingKeys: String, CodingKey {
        case version, id, type, x, y, toX, toY, ctrlX, ctrlY
        case label, texte, estPointille, r, g, b
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Version absente = v0 (données pré-migration) → on accepte quand même
        self.version = (try? c.decode(Int.self, forKey: .version)) ?? 0
        self.id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        self.type = try c.decode(TypeElement.self, forKey: .type)
        self.x = try c.decode(Double.self, forKey: .x)
        self.y = try c.decode(Double.self, forKey: .y)
        self.toX = try c.decodeIfPresent(Double.self, forKey: .toX)
        self.toY = try c.decodeIfPresent(Double.self, forKey: .toY)
        self.ctrlX = try c.decodeIfPresent(Double.self, forKey: .ctrlX)
        self.ctrlY = try c.decodeIfPresent(Double.self, forKey: .ctrlY)
        self.label = (try? c.decode(String.self, forKey: .label)) ?? ""
        self.texte = (try? c.decode(String.self, forKey: .texte)) ?? ""
        self.estPointille = (try? c.decode(Bool.self, forKey: .estPointille)) ?? false
        self.r = try c.decode(Double.self, forKey: .r)
        self.g = try c.decode(Double.self, forKey: .g)
        self.b = try c.decode(Double.self, forKey: .b)
    }

    // MARK: Equatable (P1-04 — limite les re-renders SwiftUI)
    static func == (lhs: ElementTerrain, rhs: ElementTerrain) -> Bool {
        lhs.id == rhs.id &&
        lhs.type == rhs.type &&
        lhs.x == rhs.x && lhs.y == rhs.y &&
        lhs.toX == rhs.toX && lhs.toY == rhs.toY &&
        lhs.ctrlX == rhs.ctrlX && lhs.ctrlY == rhs.ctrlY &&
        lhs.label == rhs.label && lhs.texte == rhs.texte &&
        lhs.estPointille == rhs.estPointille &&
        lhs.r == rhs.r && lhs.g == rhs.g && lhs.b == rhs.b
    }
}

// MARK: - Type de terrain
enum TypeTerrain: String, Codable, CaseIterable {
    case indoor = "Indoor"
    case beach  = "Beach"

    var label: String { rawValue }

    var icone: String {
        switch self {
        case .indoor: return "building.2"
        case .beach:  return "sun.max"
        }
    }
}

// MARK: - Étape d'exercice (terrain par étape) — P1-03 versionnement
struct EtapeExercice: Identifiable, Codable {
    static let schemaVersion = 1
    var version: Int = Self.schemaVersion

    var id: UUID = UUID()
    var nom: String = ""
    var dessinData: Data? = nil
    var elementsData: Data? = nil

    enum CodingKeys: String, CodingKey {
        case version, id, nom, dessinData, elementsData
    }

    init(nom: String = "", dessinData: Data? = nil, elementsData: Data? = nil) {
        self.nom = nom
        self.dessinData = dessinData
        self.elementsData = elementsData
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.version = (try? c.decode(Int.self, forKey: .version)) ?? 0
        self.id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        self.nom = (try? c.decode(String.self, forKey: .nom)) ?? ""
        self.dessinData = try c.decodeIfPresent(Data.self, forKey: .dessinData)
        self.elementsData = try c.decodeIfPresent(Data.self, forKey: .elementsData)
    }
}

// MARK: - Copie terrain entre modèles (P1-01)
/// Copie les données terrain d'un modèle source vers une destination
func copierTerrain(de source: any TerrainContent, vers dest: any TerrainContent) {
    dest.dessinData = source.dessinData
    dest.elementsData = source.elementsData
    dest.etapesData = source.etapesData
    dest.typeTerrain = source.typeTerrain
}

// MARK: - Protocole TerrainContent (P1-01 — élimine la duplication entre modèles)
protocol TerrainContent: AnyObject {
    var dessinData: Data? { get set }
    var elementsData: Data? { get set }
    var etapesData: Data? { get set }
    var typeTerrain: String { get set }
}

extension TerrainContent {
    /// Décode les éléments terrain avec gestion d'erreur (P2-07)
    func decoderElements() -> [ElementTerrain] {
        guard let data = elementsData else { return [] }
        do {
            return try JSONCoderCache.decoder.decode([ElementTerrain].self, from: data)
        } catch {
            logger.warning("Échec décodage elementsData: \(error.localizedDescription)")
            return []
        }
    }

    /// Décode les étapes avec gestion d'erreur (P2-07)
    func decoderEtapes() -> [EtapeExercice] {
        guard let data = etapesData else { return [] }
        do {
            return try JSONCoderCache.decoder.decode([EtapeExercice].self, from: data)
        } catch {
            logger.warning("Échec décodage etapesData: \(error.localizedDescription)")
            return []
        }
    }

}
