//
//  EtatSyncEquipe.swift
//  Playco
//
//  E′ — État local de synchronisation, PAR ÉQUIPE (docs/Architecture_SyncEPrime.md §3).
//  Remplace la clé UserDefaults globale `derniereSyncPublic` et porte :
//  - le seuil de publication (capturé en DÉBUT de sweep, avancé seulement
//    sur succès complet hors mode match — fenêtres de perte fermées) ;
//  - les FILIGRANES anti-écho : dateModification telle qu'importée par entité —
//    le sweep ne republie jamais ce qui vient d'un autre écrivain ;
//  - les tombstones traités (suppressions appliquées, records ignorés ensuite) ;
//  - la borne d'import des points live (`publieLe` du dernier point importé).
//
//  Persistance : un fichier JSON par équipe dans Application Support.
//  Données par-appareil (pas de sync) : chaque appareil tient son propre état.
//

import Foundation
import os

@MainActor
final class EtatSyncEquipe {

    private let logger = Logger(subsystem: "com.origotech.playco", category: "EtatSyncEquipe")

    struct Etat: Codable {
        var seuilPublication: Date = .distantPast
        /// entiteID (uuidString) → dateModification importée (anti-écho E′).
        var filigranes: [String: Date] = [:]
        /// entiteID (uuidString) → horodatage du tombstone appliqué.
        var tombstones: [String: Date] = [:]
        /// Borne d'import incrémental des points live (champ `publieLe`).
        var bornePublieLePoints: Date = .distantPast
    }

    /// Cache mémoire par codeEquipe (relu du disque au premier accès).
    private var etats: [String: Etat] = [:]

    private func urlFichier(_ codeEquipe: String) throws -> URL {
        let dossier = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        // codeEquipe est alphanumérique (généré par l'app) — sanitisé par prudence.
        let nomSur = codeEquipe.filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return dossier.appendingPathComponent("playco-sync-\(nomSur).json")
    }

    func etat(_ codeEquipe: String) -> Etat {
        if let cache = etats[codeEquipe] { return cache }
        var charge = Etat()
        if let url = try? urlFichier(codeEquipe),
           let data = try? Data(contentsOf: url),
           let decode = try? JSONCoderCache.decoder.decode(Etat.self, from: data) {
            charge = decode
        }
        etats[codeEquipe] = charge
        return charge
    }

    func modifier(_ codeEquipe: String, _ bloc: (inout Etat) -> Void) {
        var courant = etat(codeEquipe)
        bloc(&courant)
        etats[codeEquipe] = courant
        do {
            let url = try urlFichier(codeEquipe)
            let data = try JSONCoderCache.encoder.encode(courant)
            try data.write(to: url, options: .atomic)
        } catch {
            logger.error("EtatSyncEquipe: échec de persistance pour \(codeEquipe, privacy: .private): \(error.localizedDescription)")
        }
    }

    // MARK: - Filigranes (anti-écho)

    /// À l'import : mémorise la version distante appliquée localement.
    func poserFiligrane(_ codeEquipe: String, entiteID: UUID, date: Date) {
        modifier(codeEquipe) { $0.filigranes[entiteID.uuidString] = date }
    }

    /// E′ : une entité se publie si SA version locale n'est pas celle qu'on a
    /// importée (dateModification ≠ filigrane) — fonction pure testable.
    static func doitPublier(dateModification: Date, seuil: Date, filigrane: Date?) -> Bool {
        guard dateModification > seuil else { return false }
        return dateModification != filigrane
    }

    func doitPublier(_ codeEquipe: String, entiteID: UUID, dateModification: Date, seuil: Date) -> Bool {
        Self.doitPublier(dateModification: dateModification,
                         seuil: seuil,
                         filigrane: etat(codeEquipe).filigranes[entiteID.uuidString])
    }

    // MARK: - Tombstones

    /// Applique-t-on ce tombstone à une entité locale ? (≥ : une suppression
    /// « en même temps » qu'une édition gagne — fonction pure testable.)
    static func tombstoneGagne(horodatageTombstone: Date, dateModificationLocale: Date) -> Bool {
        horodatageTombstone >= dateModificationLocale
    }

    func enregistrerTombstone(_ codeEquipe: String, entiteID: UUID, horodatage: Date) {
        modifier(codeEquipe) { etat in
            let cle = entiteID.uuidString
            if let existant = etat.tombstones[cle], existant >= horodatage { return }
            etat.tombstones[cle] = horodatage
            etat.filigranes.removeValue(forKey: cle)
        }
    }

    /// Un record d'entité est ignoré s'il est plus vieux (ou égal) qu'un
    /// tombstone connu — une RE-création postérieure gagne.
    func estSupprimee(_ codeEquipe: String, entiteID: UUID, dateModification: Date) -> Bool {
        guard let tomb = etat(codeEquipe).tombstones[entiteID.uuidString] else { return false }
        return dateModification <= tomb
    }
}
