//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Plateformes Apple — export d'un clip (un point) ou d'un MONTAGE (une liste
//  de clips façon « cutup » : tous les sideouts ratés en R4, les kills d'un
//  joueur…) en un seul fichier MP4 partageable. Ré-encodage (coupe précise à
//  l'image, pas à l'image clé). Sur l'appareil, sans réseau.
//

#if canImport(AVFoundation)
import AVFoundation
import Foundation

public enum ExporteurClip {

    /// Exporte `debut...fin` (secondes) de la vidéo vers `destination` (MP4).
    public static func exporter(video url: URL, debut: Double, fin: Double, vers destination: URL) async throws {
        try await exporterMontage(sources: [url], plages: [(0, debut, fin)], vers: destination)
    }

    /// Exporte des segments de lecture bout à bout. `videos[i]` est le fichier
    /// `i` du match (les segments portent leur `indexFichier`).
    public static func exporter(videos: [URL], segments: [SegmentLecture], vers destination: URL) async throws {
        try await exporterMontage(sources: videos,
                                  plages: segments.map { ($0.indexFichier, $0.debut, $0.fin) },
                                  vers: destination)
    }

    /// Montage : plages (fichier, début, fin) mises bout à bout dans l'ordre
    /// donné, bornées à leur fichier.
    static func exporterMontage(sources: [URL], plages: [(Int, Double, Double)], vers destination: URL) async throws {
        let echelle: CMTimeScale = 600
        let composition = AVMutableComposition()
        guard let cibleVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw ErreurVideo.exportImpossible("piste vidéo")
        }
        var cibleAudio: AVMutableCompositionTrack?
        var transformPosee = false

        var curseur = CMTime.zero
        for (index, debut, fin) in plages {
            guard sources.indices.contains(index) else { continue }
            let source = AVURLAsset(url: sources[index])
            guard let pisteVideo = try await source.loadTracks(withMediaType: .video).first else {
                throw ErreurVideo.aucunePisteVideo
            }
            if !transformPosee {
                cibleVideo.preferredTransform = try await pisteVideo.load(.preferredTransform)
                transformPosee = true
            }
            let duree = try await source.load(.duration)
            let a = CMTime(seconds: max(0, debut), preferredTimescale: echelle)
            let b = CMTimeMinimum(CMTime(seconds: fin, preferredTimescale: echelle), duree)
            guard b > a else { continue }
            let plage = CMTimeRange(start: a, end: b)
            try cibleVideo.insertTimeRange(plage, of: pisteVideo, at: curseur)
            if let pisteAudio = try await source.loadTracks(withMediaType: .audio).first {
                if cibleAudio == nil {
                    cibleAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                }
                try cibleAudio?.insertTimeRange(plage, of: pisteAudio, at: curseur)
            }
            curseur = curseur + plage.duration
        }
        guard curseur > .zero else { throw ErreurVideo.exportImpossible("aucune plage dans la vidéo") }

        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw ErreurVideo.exportImpossible("session")
        }
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try await session.export(to: destination, as: .mp4)
    }
}
#endif
