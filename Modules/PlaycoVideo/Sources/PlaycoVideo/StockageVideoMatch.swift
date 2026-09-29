//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Stockage LOCAL des vidéos de match : {racine}/{seanceID}/ = le ou les
//  fichiers vidéo (un match peut être filmé en plusieurs fichiers) + un
//  manifeste JSON. JAMAIS CloudKit (un match 1080p pèse plusieurs Go) ;
//  racine exclue de la sauvegarde iCloud sur les plateformes Apple. Le
//  manifeste sert aussi de fichier d'étiquettes pour l'IA — format versionné,
//  décodage tolérant.
//

import Foundation

// MARK: - Manifeste

/// Un fichier vidéo du match (un match peut être filmé en plusieurs fichiers,
/// ex. un par set) et son propre alignement.
public struct FichierVideoMatch: Codable, Hashable, Sendable {
    /// Posé par `StockageVideoMatch` (nom interne, jamais un chemin).
    public var nomFichier: String
    public var alignement: AlignementVideo
    public var sourceAlignement: SourceAlignement
    public var ancres: [AncreAlignement]

    public init(nomFichier: String = "match.mov", alignement: AlignementVideo,
                sourceAlignement: SourceAlignement, ancres: [AncreAlignement] = []) {
        self.nomFichier = nomFichier
        self.alignement = alignement
        self.sourceAlignement = sourceAlignement
        self.ancres = ancres
    }

    private enum CodingKeys: String, CodingKey { case nomFichier, alignement, sourceAlignement, ancres }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nomFichier = try c.decodeIfPresent(String.self, forKey: .nomFichier) ?? "match.mov"
        alignement = try c.decode(AlignementVideo.self, forKey: .alignement)
        sourceAlignement = try c.decodeIfPresent(SourceAlignement.self, forKey: .sourceAlignement) ?? .manuel
        ancres = try c.decodeIfPresent([AncreAlignement].self, forKey: .ancres) ?? []
    }
}

public enum ErreurManifeste: Error, Equatable {
    /// Un manifeste décrit toujours au moins un fichier.
    case aucunFichier
    /// Autant de vidéos que de fichiers décrits par le manifeste.
    case nombreDeFichiersIncoherent
}

public struct ManifesteVideoMatch: Codable, Hashable, Sendable {
    /// v2 : plusieurs fichiers par match. Le v1 (un fichier) se relit.
    public static let versionSchemaActuelle = 2

    public var versionSchema: Int
    public var seanceID: UUID
    public var codeEquipe: String
    /// Toujours au moins un fichier (invariant garanti à l'init et au décodage).
    public private(set) var fichiers: [FichierVideoMatch]
    public var fenetre: FenetreClip
    /// Usage de la vidéo pour entraîner l'IA : finalité DISTINCTE du coaching
    /// (Loi 25 — consentement propre à la finalité). Opt-in, NON par défaut.
    public var consentementEntrainementIA: Bool
    public var dateImport: Date

    public init(
        seanceID: UUID,
        codeEquipe: String,
        fichiers: [FichierVideoMatch],
        fenetre: FenetreClip = .parDefaut,
        consentementEntrainementIA: Bool = false,
        dateImport: Date = Date()
    ) throws {
        guard !fichiers.isEmpty else { throw ErreurManifeste.aucunFichier }
        self.versionSchema = Self.versionSchemaActuelle
        self.seanceID = seanceID
        self.codeEquipe = codeEquipe
        self.fichiers = fichiers
        self.fenetre = fenetre
        self.consentementEntrainementIA = consentementEntrainementIA
        self.dateImport = dateImport
    }

    /// Match en un seul fichier.
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
        self.fichiers = [FichierVideoMatch(alignement: alignement, sourceAlignement: sourceAlignement, ancres: ancres)]
        self.fenetre = fenetre
        self.consentementEntrainementIA = consentementEntrainementIA
        self.dateImport = dateImport
    }

    // MARK: Accès au premier fichier (match en un fichier)

    public var nomFichierVideo: String {
        get { fichiers[0].nomFichier }
        set { fichiers[0].nomFichier = newValue }
    }

    public var alignement: AlignementVideo {
        get { fichiers[0].alignement }
        set { fichiers[0].alignement = newValue }
    }

    public var sourceAlignement: SourceAlignement {
        get { fichiers[0].sourceAlignement }
        set { fichiers[0].sourceAlignement = newValue }
    }

    public var ancres: [AncreAlignement] {
        get { fichiers[0].ancres }
        set { fichiers[0].ancres = newValue }
    }

    /// Alignements de tous les fichiers, dans l'ordre (pour `IndexVideo`).
    public var alignements: [AlignementVideo] { fichiers.map(\.alignement) }

    // MARK: Modification des fichiers

    public mutating func ajouter(_ fichier: FichierVideoMatch) {
        fichiers.append(fichier)
    }

    /// Modifie le fichier `index` (ex. recalage) ; sans effet hors bornes.
    public mutating func modifierFichier(_ index: Int, _ modification: (inout FichierVideoMatch) -> Void) {
        guard fichiers.indices.contains(index) else { return }
        modification(&fichiers[index])
    }

    // MARK: Codable (v2, relecture du v1)

    private enum CodingKeys: String, CodingKey {
        case versionSchema, seanceID, codeEquipe, fichiers, fenetre, consentementEntrainementIA, dateImport
        // v1
        case nomFichierVideo, alignement, sourceAlignement, ancres
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        seanceID = try c.decode(UUID.self, forKey: .seanceID)
        codeEquipe = try c.decodeIfPresent(String.self, forKey: .codeEquipe) ?? ""
        if let fichiers = try c.decodeIfPresent([FichierVideoMatch].self, forKey: .fichiers) {
            guard !fichiers.isEmpty else { throw ErreurManifeste.aucunFichier }
            self.fichiers = fichiers
        } else {
            // Manifeste v1 : un seul fichier décrit à plat.
            self.fichiers = [FichierVideoMatch(
                nomFichier: try c.decodeIfPresent(String.self, forKey: .nomFichierVideo) ?? "match.mov",
                alignement: try c.decode(AlignementVideo.self, forKey: .alignement),
                sourceAlignement: try c.decodeIfPresent(SourceAlignement.self, forKey: .sourceAlignement) ?? .manuel,
                ancres: try c.decodeIfPresent([AncreAlignement].self, forKey: .ancres) ?? [])]
        }
        versionSchema = Self.versionSchemaActuelle
        fenetre = try c.decodeIfPresent(FenetreClip.self, forKey: .fenetre) ?? .parDefaut
        // Absent = NON : le consentement ne se présume jamais.
        consentementEntrainementIA = try c.decodeIfPresent(Bool.self, forKey: .consentementEntrainementIA) ?? false
        dateImport = try c.decodeIfPresent(Date.self, forKey: .dateImport) ?? Date(timeIntervalSince1970: 0)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(versionSchema, forKey: .versionSchema)
        try c.encode(seanceID, forKey: .seanceID)
        try c.encode(codeEquipe, forKey: .codeEquipe)
        try c.encode(fichiers, forKey: .fichiers)
        try c.encode(fenetre, forKey: .fenetre)
        try c.encode(consentementEntrainementIA, forKey: .consentementEntrainementIA)
        try c.encode(dateImport, forKey: .dateImport)
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
        try importer(videos: [videoSource], manifeste: manifeste)
    }

    /// Import d'un match filmé en plusieurs fichiers : `videos[i]` correspond
    /// à `manifeste.fichiers[i]` (même nombre exigé). Remplace le match existant.
    @discardableResult
    public func importer(videos: [URL], manifeste: ManifesteVideoMatch) throws -> ManifesteVideoMatch {
        guard videos.count == manifeste.fichiers.count else { throw ErreurManifeste.nombreDeFichiersIncoherent }
        let fm = FileManager.default
        try preparerRacine()

        var copie = manifeste
        let transit = racine.appendingPathComponent(".import-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: transit, withIntermediateDirectories: true)
        do {
            for (index, source) in videos.enumerated() {
                let nom = Self.nomFichier(index: index, extension: source.pathExtension)
                copie.modifierFichier(index) { $0.nomFichier = nom }
                try fm.copyItem(at: source, to: transit.appendingPathComponent(nom))
            }
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

    /// Ajoute un fichier (ex. le set suivant) à un match déjà importé.
    @discardableResult
    public func ajouter(video source: URL, fichier: FichierVideoMatch, seanceID: UUID) throws -> ManifesteVideoMatch {
        guard var manifeste = try manifeste(seanceID: seanceID) else { throw CocoaError(.fileNoSuchFile) }
        var nouveau = fichier
        nouveau.nomFichier = Self.nomFichier(index: manifeste.fichiers.count, extension: source.pathExtension)
        let destination = dossier(seanceID: seanceID).appendingPathComponent(nouveau.nomFichier)
        try FileManager.default.copyItem(at: source, to: destination)
        manifeste.ajouter(nouveau)
        do {
            try enregistrer(manifeste)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
        return manifeste
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

    /// URL du premier fichier vidéo du match ; nil si absent ou si le manifeste est illisible.
    public func urlVideo(seanceID: UUID) -> URL? {
        urlsVideos(seanceID: seanceID).first ?? nil
    }

    /// URL de chaque fichier du match, dans l'ordre du manifeste (nil = fichier manquant).
    public func urlsVideos(seanceID: UUID) -> [URL?] {
        guard let manifeste = try? manifeste(seanceID: seanceID) else { return [] }
        return manifeste.fichiers.map { fichier in
            guard let nom = Self.nomSur(fichier.nomFichier) else { return nil }
            let url = dossier(seanceID: seanceID).appendingPathComponent(nom)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
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

    /// « match.mov » pour le premier fichier, « match-2.mov », « match-3.mov »… ensuite.
    static func nomFichier(index: Int, extension brute: String) -> String {
        let ext = extensionSure(brute)
        return index == 0 ? "match.\(ext)" : "match-\(index + 1).\(ext)"
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
