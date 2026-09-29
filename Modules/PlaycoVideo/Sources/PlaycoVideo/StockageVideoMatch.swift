//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Stockage LOCAL des vidéos de match : {racine}/{seanceID}/ = le fichier vidéo
//  + un manifeste JSON. JAMAIS CloudKit (un match 1080p pèse plusieurs Go) ;
//  racine exclue de la sauvegarde iCloud sur les plateformes Apple. Le
//  manifeste sert aussi de fichier d'étiquettes pour l'IA — format versionné,
//  décodage tolérant.
//

import Foundation

// MARK: - Manifeste

public struct ManifesteVideoMatch: Codable, Hashable, Sendable {
    public static let versionSchemaActuelle = 1

    public var versionSchema: Int
    public var seanceID: UUID
    public var codeEquipe: String
    /// Posé par `StockageVideoMatch.importer` (nom interne, jamais un chemin).
    public var nomFichierVideo: String
    public var alignement: AlignementVideo
    public var sourceAlignement: SourceAlignement
    public var ancres: [AncreAlignement]
    public var fenetre: FenetreClip
    /// Usage de la vidéo pour entraîner l'IA : finalité DISTINCTE du coaching
    /// (Loi 25 — consentement propre à la finalité). Opt-in, NON par défaut.
    public var consentementEntrainementIA: Bool
    public var dateImport: Date

    public init(
        seanceID: UUID,
        codeEquipe: String,
        alignement: AlignementVideo,
        sourceAlignement: SourceAlignement,
        ancres: [AncreAlignement] = [],
        fenetre: FenetreClip = .parDefaut,
        consentementEntrainementIA: Bool = false,
        dateImport: Date = Date()
    ) {
        self.versionSchema = Self.versionSchemaActuelle
        self.seanceID = seanceID
        self.codeEquipe = codeEquipe
        self.nomFichierVideo = "match.mov"
        self.alignement = alignement
        self.sourceAlignement = sourceAlignement
        self.ancres = ancres
        self.fenetre = fenetre
        self.consentementEntrainementIA = consentementEntrainementIA
        self.dateImport = dateImport
    }

    private enum CodingKeys: String, CodingKey {
        case versionSchema, seanceID, codeEquipe, nomFichierVideo, alignement,
             sourceAlignement, ancres, fenetre, consentementEntrainementIA, dateImport
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        versionSchema = try c.decodeIfPresent(Int.self, forKey: .versionSchema) ?? 1
        seanceID = try c.decode(UUID.self, forKey: .seanceID)
        codeEquipe = try c.decodeIfPresent(String.self, forKey: .codeEquipe) ?? ""
        nomFichierVideo = try c.decodeIfPresent(String.self, forKey: .nomFichierVideo) ?? "match.mov"
        alignement = try c.decode(AlignementVideo.self, forKey: .alignement)
        sourceAlignement = try c.decodeIfPresent(SourceAlignement.self, forKey: .sourceAlignement) ?? .manuel
        ancres = try c.decodeIfPresent([AncreAlignement].self, forKey: .ancres) ?? []
        fenetre = try c.decodeIfPresent(FenetreClip.self, forKey: .fenetre) ?? .parDefaut
        // Absent = NON : le consentement ne se présume jamais.
        consentementEntrainementIA = try c.decodeIfPresent(Bool.self, forKey: .consentementEntrainementIA) ?? false
        dateImport = try c.decodeIfPresent(Date.self, forKey: .dateImport) ?? Date(timeIntervalSince1970: 0)
    }

    /// Encodage déterministe (clés triées) — fichiers comparables d'une version à l'autre.
    public func encoder() throws -> Data {
        let encodeur = JSONEncoder()
        encodeur.outputFormatting = [.sortedKeys]
        return try encodeur.encode(self)
    }

    public static func decoder(_ data: Data) throws -> ManifesteVideoMatch {
        try JSONDecoder().decode(ManifesteVideoMatch.self, from: data)
    }
}

// MARK: - Stockage

public struct StockageVideoMatch: Sendable {

    public static let nomManifeste = "manifeste.json"

    public let racine: URL

    public init(racine: URL) {
        self.racine = racine
    }

    public func dossier(seanceID: UUID) -> URL {
        racine.appendingPathComponent(seanceID.uuidString, isDirectory: true)
    }

    /// Copie la vidéo dans le dossier du match et écrit le manifeste. Remplace
    /// la vidéo existante du même match. La copie passe par un dossier de
    /// transit : un échec de copie ne détruit jamais la vidéo déjà en place.
    @discardableResult
    public func importer(videoSource: URL, manifeste: ManifesteVideoMatch) throws -> ManifesteVideoMatch {
        let fm = FileManager.default
        try preparerRacine()

        var copie = manifeste
        copie.nomFichierVideo = "match.\(Self.extensionSure(videoSource.pathExtension))"

        let transit = racine.appendingPathComponent(".import-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: transit, withIntermediateDirectories: true)
        do {
            try fm.copyItem(at: videoSource, to: transit.appendingPathComponent(copie.nomFichierVideo))
            try copie.encoder().write(to: transit.appendingPathComponent(Self.nomManifeste), options: .atomic)

            let destination = dossier(seanceID: copie.seanceID)
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.moveItem(at: transit, to: destination)
        } catch {
            try? fm.removeItem(at: transit)
            throw error
        }
        return copie
    }

    /// Réécrit le manifeste (ex. : correction de l'alignement, consentement).
    public func enregistrer(_ manifeste: ManifesteVideoMatch) throws {
        let dossier = dossier(seanceID: manifeste.seanceID)
        guard FileManager.default.fileExists(atPath: dossier.path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        try manifeste.encoder().write(to: dossier.appendingPathComponent(Self.nomManifeste), options: .atomic)
    }

    /// Manifeste du match ; nil si absent. Un manifeste illisible lève une erreur
    /// (la distinguer de l'absence évite d'écraser une vidéo par erreur).
    public func manifeste(seanceID: UUID) throws -> ManifesteVideoMatch? {
        let url = dossier(seanceID: seanceID).appendingPathComponent(Self.nomManifeste)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try ManifesteVideoMatch.decoder(Data(contentsOf: url))
    }

    /// URL du fichier vidéo du match ; nil si absent ou si le manifeste est illisible.
    public func urlVideo(seanceID: UUID) -> URL? {
        guard let manifeste = try? manifeste(seanceID: seanceID),
              let nom = Self.nomSur(manifeste.nomFichierVideo) else { return nil }
        let url = dossier(seanceID: seanceID).appendingPathComponent(nom)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Supprime la vidéo et le manifeste du match (no-op si absent).
    public func supprimer(seanceID: UUID) throws {
        let dossier = dossier(seanceID: seanceID)
        guard FileManager.default.fileExists(atPath: dossier.path) else { return }
        try FileManager.default.removeItem(at: dossier)
    }

    /// Matchs ayant une vidéo stockée (dossiers nommés par un UUID valide).
    public func seancesAvecVideo() throws -> [UUID] {
        guard FileManager.default.fileExists(atPath: racine.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(atPath: racine.path)
            .compactMap(UUID.init(uuidString:))
            .sorted { $0.uuidString < $1.uuidString }
    }

    // MARK: - Privé

    private func preparerRacine() throws {
        try FileManager.default.createDirectory(at: racine, withIntermediateDirectories: true)
        #if canImport(Darwin)
        var url = racine
        var valeurs = URLResourceValues()
        valeurs.isExcludedFromBackup = true
        try url.setResourceValues(valeurs)
        #endif
    }

    /// Extension ASCII alphanumérique seulement, `mov` par défaut.
    static func extensionSure(_ brute: String) -> String {
        let propre = brute.lowercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        return propre.isEmpty ? "mov" : propre
    }

    /// Dernier composant seulement : un manifeste altéré ne sort jamais du dossier du match.
    static func nomSur(_ brut: String) -> String? {
        let nom = brut.split(separator: "/").last.map(String.init) ?? ""
        guard !nom.isEmpty, nom != ".", nom != ".." else { return nil }
        return nom
    }
}
