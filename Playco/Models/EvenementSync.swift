//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation

// MARK: - Événement de synchronisation (journal)

/// Événement enregistré dans le journal de sync — PAS un @Model (évite la sync récursive)
/// Stocké dans UserDefaults via JSONCoderCache, buffer circulaire de 50 entrées
struct EvenementSync: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var date: Date = Date()
    var type: TypeEvenementSync
    var message: String
    var estErreur: Bool = false

    enum TypeEvenementSync: String, Codable {
        case importation = "import"
        case exportation = "export"
        case setup = "setup"
        case erreur = "erreur"
        case connexion = "connexion"
        case pauseSync = "pause"
        case repriseSync = "reprise"

        var icone: String {
            switch self {
            case .importation: return "arrow.down.icloud"
            case .exportation: return "arrow.up.icloud"
            case .setup: return "gearshape.icloud"
            case .erreur: return "exclamationmark.icloud"
            case .connexion: return "checkmark.icloud"
            case .pauseSync: return "pause.circle"
            case .repriseSync: return "play.circle"
            }
        }

        var label: String {
            switch self {
            case .importation: return "Import"
            case .exportation: return "Export"
            case .setup: return "Configuration"
            case .erreur: return "Erreur"
            case .connexion: return "Connexion"
            case .pauseSync: return "Pause"
            case .repriseSync: return "Reprise"
            }
        }
    }
}

// MARK: - Stockage journal (UserDefaults)

enum JournalSyncStorage {
    private static let cleJournal = "com.origotech.playco.journalSync"
    private static let tailleMax = 50

    static func charger() -> [EvenementSync] {
        guard let data = UserDefaults.standard.data(forKey: cleJournal) else { return [] }
        return (try? JSONCoderCache.decoder.decode([EvenementSync].self, from: data)) ?? []
    }

    static func sauvegarder(_ journal: [EvenementSync]) {
        // Buffer circulaire : garder les 50 plus récents
        let journalTronque = Array(journal.suffix(tailleMax))
        guard let data = try? JSONCoderCache.encoder.encode(journalTronque) else { return }
        UserDefaults.standard.set(data, forKey: cleJournal)
    }

    static func effacer() {
        UserDefaults.standard.removeObject(forKey: cleJournal)
    }
}
