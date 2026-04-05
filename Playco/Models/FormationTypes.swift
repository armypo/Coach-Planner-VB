//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation

// MARK: - Mode de formation (P2-04 — extrait de TerrainEditeurView)
enum FormationMode: String {
    case base      = "Base"
    case reception = "Réception"
    case attaque   = "Attaque"
}

// MARK: - Formations volleyball (P2-04 — extrait de TerrainEditeurView)
enum FormationType: String, CaseIterable {
    // Indoor
    case cinqUn     = "5-1"
    case quatreDeux = "4-2"
    case sixDeux    = "6-2"
    // Beach
    case beachReception = "Réception"
    case beachBloqueurDefenseur = "Bloqueur / Défenseur"
    case beachSplitBloc = "Split bloc"

    var estBeach: Bool {
        switch self {
        case .beachReception, .beachBloqueurDefenseur, .beachSplitBloc: return true
        default: return false
        }
    }

    struct Position {
        let x: Double, y: Double
        let label: String  // Première lettre du poste (P, C, R, O, etc.)
    }

    /// Coordonnées des zones (1-6) sur le demi-terrain gauche, normalisées 0-1
    static let zonesIndoor: [(x: Double, y: Double)] = [
        (0.12, 0.80),  // Zone 1
        (0.38, 0.80),  // Zone 2
        (0.38, 0.50),  // Zone 3
        (0.38, 0.20),  // Zone 4
        (0.12, 0.20),  // Zone 5
        (0.12, 0.50),  // Zone 6
    ]

    /// Indices des zones avant (front row) : zones 2, 3, 4
    private static let frontIndices: Set<Int> = [1, 2, 3]

    /// Lineup de base : postes dans l'ordre des zones (1→6)
    var lineup: [String] {
        switch self {
        case .cinqUn:     return ["P", "R", "C", "O", "R", "C"]
        case .quatreDeux: return ["P", "A", "C", "P", "A", "C"]
        case .sixDeux:    return ["P", "A", "C", "P", "A", "C"]
        case .beachReception:           return ["J1", "J2"]
        case .beachBloqueurDefenseur:   return ["B", "D"]
        case .beachSplitBloc:           return ["J1", "J2"]
        }
    }

    var nombreRotations: Int { estBeach ? 1 : 6 }

    /// Génère les positions avec le label du poste pour une rotation et un mode donnés
    func positions(rotation: Int = 0, mode: FormationMode = .base) -> [Position] {
        if estBeach { return positionsBeach() }

        let l = lineup
        let r = ((rotation % 6) + 6) % 6  // P3-01 v0.4.0 — safe modulo négatif

        if mode == .base {
            return (0..<6).map { i in
                let poste = l[(i - r + 6) % 6]
                let estAvant = Self.frontIndices.contains(i)
                let label = (poste == "C" && !estAvant) ? "L" : poste
                return Position(x: Self.zonesIndoor[i].x,
                                y: Self.zonesIndoor[i].y,
                                label: label)
            }
        }

        return (0..<6).map { i in
            let poste = l[(i - r + 6) % 6]
            let estAvant = Self.frontIndices.contains(i)
            let actif = estPasseurActif(poste, estAvant: estAvant)
            let label = (poste == "C" && !estAvant) ? "L" : poste
            let rolePos = (poste == "C" && !estAvant) ? "L" : poste
            let pos = mode == .reception
                ? posReception(rolePos, estAvant: estAvant, passeurActif: actif)
                : posAttaque(rolePos, estAvant: estAvant, passeurActif: actif)
            return Position(x: pos.0, y: pos.1, label: label)
        }
    }

    // MARK: - Passeur actif
    private func estPasseurActif(_ label: String, estAvant: Bool) -> Bool {
        guard label == "P" else { return false }
        switch self {
        case .cinqUn:     return true
        case .quatreDeux: return estAvant
        case .sixDeux:    return !estAvant
        default:          return false
        }
    }

    // MARK: - Positions réception
    private func posReception(_ role: String, estAvant: Bool, passeurActif: Bool) -> (Double, Double) {
        if passeurActif { return (0.43, 0.68) }

        switch role {
        case "P": return estAvant ? (0.32, 0.50) : (0.10, 0.65)
        case "C": return estAvant ? (0.36, 0.45) : (0.10, 0.50)
        case "L": return (0.10, 0.50)
        case "R": return estAvant ? (0.30, 0.18) : (0.10, 0.28)
        case "O": return estAvant ? (0.30, 0.82) : (0.10, 0.78)
        case "A": return estAvant ? (0.30, 0.30) : (0.10, 0.40)
        default:  return (0.25, 0.50)
        }
    }

    // MARK: - Positions attaque
    private func posAttaque(_ role: String, estAvant: Bool, passeurActif: Bool) -> (Double, Double) {
        if passeurActif { return (0.45, 0.65) }

        switch role {
        case "P": return estAvant ? (0.44, 0.50) : (0.15, 0.65)
        case "C": return estAvant ? (0.44, 0.45) : (0.15, 0.50)
        case "L": return (0.15, 0.50)
        case "R": return estAvant ? (0.44, 0.15) : (0.22, 0.28)
        case "O": return estAvant ? (0.44, 0.85) : (0.22, 0.78)
        case "A": return estAvant ? (0.44, 0.25) : (0.22, 0.40)
        default:  return (0.25, 0.50)
        }
    }

    private func positionsBeach() -> [Position] {
        switch self {
        case .beachReception:
            return [
                Position(x: 0.25, y: 0.30, label: "J1"),
                Position(x: 0.25, y: 0.70, label: "J2"),
            ]
        case .beachBloqueurDefenseur:
            return [
                Position(x: 0.40, y: 0.50, label: "B"),
                Position(x: 0.10, y: 0.50, label: "D"),
            ]
        case .beachSplitBloc:
            return [
                Position(x: 0.38, y: 0.35, label: "J1"),
                Position(x: 0.38, y: 0.65, label: "J2"),
            ]
        default: return []
        }
    }

    /// Description de la rotation pour le menu
    func descriptionRotation(_ rotation: Int) -> String {
        let l = lineup
        let r = ((rotation % 6) + 6) % 6  // P3-01 v0.4.0 — safe modulo négatif
        for i in 0..<6 {
            if l[(i - r + 6) % 6] == "P" {
                return "P en zone \(i + 1)"
            }
        }
        return "Rotation \(rotation + 1)"
    }
}
