//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Vidéo phase 1 — stockage LOCAL des vidéos de match (HORS SORTIE : flag VIDEO).
//
//  Application Support/VideosMatch/{seanceID}/ : le fichier vidéo + un manifeste
//  JSON. JAMAIS CloudKit (un match 1080p pèse plusieurs Go — quota iCloud et
//  sync s'écrouleraient) ; dossier exclu de la sauvegarde iCloud. Aucun @Model :
//  zéro changement de schéma CloudKit tant que la vidéo n'est pas livrée.
//

#if VIDEO
import Foundation
import os

// MARK: - Manifeste

/// Manifeste d'une vidéo de match, stocké À CÔTÉ du fichier. Sert aussi de
/// fichier d'étiquettes pour l'IA — format versionné.
nonisolated struct ManifesteVideoMatch: Codable, Equatable, Sendable {
    static let versionSchemaActuelle = 1

    var versionSchema: Int = ManifesteVideoMatch.versionSchemaActuelle
    var seanceID: UUID
    var codeEquipe: String
    /// Posé par `VideoMatchStore.importer` (nom interne, jamais un chemin).
    var nomFichierVideo: String = "match.mov"
    var alignement: AlignementVideo
    var sourceAlignement: SourceAlignement
    var fenetre: FenetreClip = .parDefaut
    /// Usage de la vidéo pour entraîner l'IA : finalité DISTINCTE du coaching
    /// (Loi 25 — consentement propre à la finalité). Opt-in, NON par défaut.
    var consentementEntrainementIA: Bool = false
    var dateImport: Date = Date()
}

// MARK: - Store

nonisolated struct VideoMatchStore {

    static let nomManifeste = "manifeste.json"
    private static let logger = Logger(subsystem: "com.origotech.playco", category: "VideoMatchStore")

    let racine: URL

    init(racine: URL) {
        self.racine = racine
    }

    /// Emplacement de l'app : Application Support/VideosMatch.
    static func parDefaut() throws -> VideoMatchStore {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        return VideoMatchStore(racine: support.appendingPathComponent("VideosMatch", isDirectory: true))
    }

    func dossier(seanceID: UUID) -> URL {
        racine.appendingPathComponent(seanceID.uuidString, isDirectory: true)
    }

    /// Copie la vidéo dans le dossier du match et écrit le manifeste. Remplace
    /// la vidéo existante du même match. La copie passe par un dossier de
    /// transit : un échec de copie ne détruit jamais la vidéo déjà en place.
    @discardableResult
    func importer(videoSource: URL, manifeste: ManifesteVideoMatch) throws -> ManifesteVideoMatch {
        let fm = FileManager.default
        try preparerRacine()

        var copie = manifeste
        copie.nomFichierVideo = "match.\(extensionSure(videoSource.pathExtension))"

        let transit = racine.appendingPathComponent(".import-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: transit, withIntermediateDirectories: true)
        do {
            try fm.copyItem(at: videoSource, to: transit.appendingPathComponent(copie.nomFichierVideo))
            let data = try JSONCoderCache.encoder.encode(copie)
            try data.write(to: transit.appendingPathComponent(Self.nomManifeste), options: .atomic)

            let destination = dossier(seanceID: copie.seanceID)
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.moveItem(at: transit, to: destination)
        } catch {
            try? fm.removeItem(at: transit)
            Self.logger.error("Import vidéo échoué : \(error.localizedDescription, privacy: .public)")
            throw error
        }
        return copie
    }

    /// Réécrit le manifeste (ex. : correction manuelle de l'alignement).
    func enregistrer(_ manifeste: ManifesteVideoMatch) throws {
        let dossier = dossier(seanceID: manifeste.seanceID)
        guard FileManager.default.fileExists(atPath: dossier.path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try JSONCoderCache.encoder.encode(manifeste)
        try data.write(to: dossier.appendingPathComponent(Self.nomManifeste), options: .atomic)
    }

    func manifeste(seanceID: UUID) -> ManifesteVideoMatch? {
        let url = dossier(seanceID: seanceID).appendingPathComponent(Self.nomManifeste)
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONCoderCache.decoder.decode(ManifesteVideoMatch.self, from: data)
        } catch {
            Self.logger.error("Manifeste vidéo illisible : \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// URL du fichier vidéo du match, nil si absent.
    func urlVideo(seanceID: UUID) -> URL? {
        guard let manifeste = manifeste(seanceID: seanceID) else { return nil }
        // lastPathComponent : un manifeste altéré ne sort jamais du dossier du match.
        let nom = (manifeste.nomFichierVideo as NSString).lastPathComponent
        let url = dossier(seanceID: seanceID).appendingPathComponent(nom)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Supprime la vidéo et le manifeste du match (no-op si absent).
    func supprimer(seanceID: UUID) throws {
        let dossier = dossier(seanceID: seanceID)
        guard FileManager.default.fileExists(atPath: dossier.path) else { return }
        try FileManager.default.removeItem(at: dossier)
    }

    // MARK: - Privé

    private func preparerRacine() throws {
        try FileManager.default.createDirectory(at: racine, withIntermediateDirectories: true)
        var url = racine
        var valeurs = URLResourceValues()
        valeurs.isExcludedFromBackup = true
        try url.setResourceValues(valeurs)
    }

    /// Extension ASCII alphanumérique seulement, `mov` par défaut.
    private func extensionSure(_ brute: String) -> String {
        let propre = brute.lowercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        return propre.isEmpty ? "mov" : propre
    }
}
#endif
