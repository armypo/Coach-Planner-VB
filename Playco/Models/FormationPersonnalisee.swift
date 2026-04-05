//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "FormationPersonnalisee")

// MARK: - Position sérialisable pour formations personnalisées
struct FormationPositionData: Codable, Identifiable {
    var id = UUID()
    var label: String
    var x: Double
    var y: Double
}

// MARK: - Formation personnalisée par le coach
@Model
final class FormationPersonnalisee {
    var id: UUID = UUID()
    var formationTypeRaw: String = "5-1"  // FormationType.rawValue ("5-1", "4-2", "6-2")
    var rotation: Int = 0                  // 0-5
    var modeRaw: String = "Base"           // FormationMode.rawValue ("Base", "Réception", "Attaque")
    var positionsJSON: Data? = nil         // JSON [FormationPositionData]
    var dateModification: Date = Date()
    /// Code de l'équipe propriétaire
    var codeEquipe: String = ""

    var positions: [FormationPositionData] {
        get {
            guard let data = positionsJSON else { return [] }
            do {
                return try JSONCoderCache.decoder.decode([FormationPositionData].self, from: data)
            } catch {
                logger.warning("Échec décodage positionsJSON: \(error.localizedDescription)")
                return []
            }
        }
        set {
            do {
                positionsJSON = try JSONCoderCache.encoder.encode(newValue)
            } catch {
                logger.warning("Échec encodage positionsJSON: \(error.localizedDescription)")
            }
        }
    }

    /// P2-05 — Accesseurs enum type-safe
    var formationType: FormationType? {
        get { FormationType(rawValue: formationTypeRaw) }
        set { if let v = newValue { formationTypeRaw = v.rawValue } }
    }

    var mode: FormationMode? {
        get { FormationMode(rawValue: modeRaw) }
        set { if let v = newValue { modeRaw = v.rawValue } }
    }

    /// Validation métier (P1-06)
    var estValide: Bool {
        rotation >= 0 && rotation <= 5
    }

    init(formationType: FormationType, rotation: Int, mode: FormationMode) {
        self.id = UUID()
        self.formationTypeRaw = formationType.rawValue
        self.rotation = min(5, max(0, rotation))
        self.modeRaw = mode.rawValue
        self.dateModification = Date()
    }

    /// Clé unique pour retrouver cette formation
    var cle: String { "\(formationTypeRaw)_\(rotation)_\(modeRaw)" }
}
