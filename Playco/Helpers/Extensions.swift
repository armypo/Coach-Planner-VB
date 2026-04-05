//  Playco
//  Copyright (c) 2025 Christopher Dionne. Tous droits reserves.
//

import Foundation
import SwiftUI

// MARK: - Color
extension Color {
    /// Surcharge avec label `hex:` pour compatibilité
    init(hex: String) {
        self.init(hex)
    }

    /// Initialise une Color depuis une chaîne hexadécimale (3, 6 ou 8 caractères).
    /// Retourne un gris moyen si le format est invalide (P3-02).
    init(_ hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        let success = Scanner(string: cleaned).scanHexInt64(&int)

        guard success else {
            // Format invalide — fallback gris visible (pas noir silencieux)
            self.init(.sRGB, red: 0.5, green: 0.5, blue: 0.5, opacity: 1)
            return
        }

        let a, r, g, b: UInt64
        switch cleaned.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 128, 128, 128) // Gris — format non reconnu
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - JSON Encoder/Decoder cachés (P0-01 v0.4.0 — évite 14+ instanciations)
enum JSONCoderCache {
    static let decoder = JSONDecoder()
    static let encoder = JSONEncoder()
}

// MARK: - DateFormatters cachés (P0-01 — évite de recréer à chaque appel)
private enum DateFormattersCache {
    static let francais: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "fr_FR")
        df.dateFormat = "EEEE d MMMM yyyy"
        return df
    }()

    static let court: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "fr_FR")
        df.dateFormat = "d MMM yyyy"
        return df
    }()

    static let heure: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "fr_FR")
        df.dateFormat = "HH:mm"
        return df
    }()

    static let jourSemaine: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "fr_FR")
        df.dateFormat = "EEEE"
        return df
    }()

    static let moisAnnee: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "fr_FR")
        df.dateFormat = "MMMM yyyy"
        return df
    }()

    static let yyyyMMdd: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
}

// MARK: - Date
extension Date {
    func formatFrancais() -> String {
        let result = DateFormattersCache.francais.string(from: self)
        return result.prefix(1).uppercased() + result.dropFirst()
    }

    func formatCourt() -> String {
        DateFormattersCache.court.string(from: self)
    }

    func formatHeure() -> String {
        DateFormattersCache.heure.string(from: self)
    }

    func formatJourSemaine() -> String {
        let result = DateFormattersCache.jourSemaine.string(from: self)
        return result.prefix(1).uppercased() + result.dropFirst()
    }

    func formatMoisAnnee() -> String {
        let result = DateFormattersCache.moisAnnee.string(from: self)
        return result.prefix(1).uppercased() + result.dropFirst()
    }

    func formatYMD() -> String {
        DateFormattersCache.yyyyMMdd.string(from: self)
    }
}
