//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Plateformes Apple — métadonnées d'un fichier vidéo : date de création
//  (point de départ du calage vidéo ↔ stats), durée, taille, cadence.
//  Une vidéo iPhone porte `com.apple.quicktime.creationdate` au format
//  « 2026-09-29T10:00:00-0400 » ; d'autres caméras n'en ont pas (→ ancres
//  ou calage automatique).
//

#if canImport(AVFoundation)
import AVFoundation
import Foundation

public struct MetadonneesVideo: Hashable, Sendable {
    public var dateCreation: Date?
    public var duree: Double
    public var largeur: Int
    public var hauteur: Int
    public var imagesParSeconde: Double
    public var aUnePisteAudio: Bool
}

public enum ErreurVideo: Error, Equatable {
    case aucunePisteVideo
    case aucunePisteAudio
    case lectureImpossible(String)
    case exportImpossible(String)
}

public enum LecteurMetadonneesVideo {

    public static func lire(_ url: URL) async throws -> MetadonneesVideo {
        let asset = AVURLAsset(url: url)
        let duree = try await asset.load(.duration).seconds
        guard let piste = try await asset.loadTracks(withMediaType: .video).first else {
            throw ErreurVideo.aucunePisteVideo
        }
        let taille = try await piste.load(.naturalSize)
        let cadence = try await piste.load(.nominalFrameRate)
        let audio = try await asset.loadTracks(withMediaType: .audio)
        return MetadonneesVideo(
            dateCreation: try await dateCreation(asset),
            duree: duree.isFinite ? duree : 0,
            largeur: Int(abs(taille.width)),
            hauteur: Int(abs(taille.height)),
            imagesParSeconde: Double(cadence),
            aUnePisteAudio: !audio.isEmpty)
    }

    /// Alignement initial depuis la date de création ; nil sans date.
    public static func alignementInitial(_ meta: MetadonneesVideo) -> AlignementVideo? {
        meta.dateCreation.map { AlignementVideo(dateDebutVideo: $0, dureeVideo: meta.duree) }
    }

    // MARK: - Date de création

    static func dateCreation(_ asset: AVURLAsset) async throws -> Date? {
        var candidats: [AVMetadataItem] = []
        if let item = try await asset.load(.creationDate) { candidats.append(item) }
        let metadonnees = try await asset.load(.metadata)
        candidats += metadonnees.filter {
            $0.identifier == .quickTimeMetadataCreationDate || $0.commonKey == .commonKeyCreationDate
        }
        for item in candidats {
            if let date = try await item.load(.dateValue) { return date }
            if let texte = try await item.load(.stringValue), let date = analyserDate(texte) { return date }
        }
        return nil
    }

    /// ISO 8601 avec ou sans « : » dans le fuseau, avec ou sans fractions.
    static func analyserDate(_ texte: String) -> Date? {
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: texte) { return date }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: texte) { return date }
        let formateur = DateFormatter()
        formateur.locale = Locale(identifier: "en_US_POSIX")
        for format in ["yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd HH:mm:ss Z"] {
            formateur.dateFormat = format
            if let date = formateur.date(from: texte) { return date }
        }
        return nil
    }
}
#endif
