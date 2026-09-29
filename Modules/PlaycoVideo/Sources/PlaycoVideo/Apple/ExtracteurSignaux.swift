//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Plateformes Apple — extraction des signaux que consomment les détecteurs
//  purs (DetecteurEchanges, DetecteurSifflets) :
//  - activité visuelle = différence moyenne de luminance entre images
//    échantillonnées (plan Y seulement, un pixel sur `pasPixels`), une fois
//    le mouvement de la caméra retiré et les coupures de montage ignorées ;
//  - audio mono rééchantillonné (11 025 Hz par défaut).
//  Tout se fait sur l'appareil, sans réseau.
//

#if canImport(AVFoundation)
import AVFoundation
import Foundation

public enum ExtracteurSignaux {

    // MARK: - Activité visuelle

    /// Signal d'activité à `frequence` Hz sur toute la vidéo.
    /// - Parameters:
    ///   - pasPixels: sous-échantillonnage spatial (8 ⇒ 1080p lu en 240×135).
    ///   - compenserCamera: retire les panoramiques/tremblements et ignore les
    ///     coupures de montage (vidéos du web, caméra tenue à la main).
    public static func activite(video url: URL, frequence: Double = 10, pasPixels: Int = 8,
                                compenserCamera: Bool = true) async throws -> SignalActivite {
        let asset = AVURLAsset(url: url)
        guard let piste = try await asset.loadTracks(withMediaType: .video).first else {
            throw ErreurVideo.aucunePisteVideo
        }
        let duree = try await asset.load(.duration).seconds
        let lecteur = try AVAssetReader(asset: asset)
        let sortie = AVAssetReaderTrackOutput(track: piste, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ])
        sortie.alwaysCopiesSampleData = false
        lecteur.add(sortie)
        guard lecteur.startReading() else {
            throw ErreurVideo.lectureImpossible(lecteur.error?.localizedDescription ?? "startReading")
        }

        let pas = max(1, pasPixels)
        let nombre = max(1, Int((duree * frequence).rounded(.up)))
        var valeurs = [Double](repeating: .nan, count: nombre)
        var precedente: GrilleLuminance?
        var prochainInstant = 0.0

        while let tampon = sortie.copyNextSampleBuffer() {
            let instant = CMSampleBufferGetPresentationTimeStamp(tampon).seconds
            guard instant.isFinite, instant + 1e-6 >= prochainInstant,
                  let image = CMSampleBufferGetImageBuffer(tampon) else { continue }
            prochainInstant = (instant * frequence + 1).rounded(.down) / frequence

            let courante = luminance(image, pas: pas)
            if let precedente, let mesure = CompensationCamera.mesurer(precedente, courante) {
                let index = min(nombre - 1, max(0, Int((instant * frequence).rounded(.down))))
                if compenserCamera {
                    // Coupure de montage : pas une mesure du jeu (comblée ensuite).
                    if !mesure.estCoupure { valeurs[index] = mesure.ecartResiduel }
                } else {
                    valeurs[index] = mesure.ecartBrut
                }
            }
            precedente = courante
        }
        if lecteur.status == .failed {
            throw ErreurVideo.lectureImpossible(lecteur.error?.localizedDescription ?? "lecture")
        }
        return SignalActivite(valeurs: combler(valeurs), frequence: frequence)
    }

    /// Plan Y sous-échantillonné (copie — le tampon est rendu aussitôt).
    static func luminance(_ image: CVImageBuffer, pas: Int) -> GrilleLuminance {
        CVPixelBufferLockBaseAddress(image, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(image, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddressOfPlane(image, 0) else {
            return GrilleLuminance(largeur: 0, hauteur: 0, valeurs: [])
        }
        let largeur = CVPixelBufferGetWidthOfPlane(image, 0)
        let hauteur = CVPixelBufferGetHeightOfPlane(image, 0)
        let ligne = CVPixelBufferGetBytesPerRowOfPlane(image, 0)
        let octets = base.assumingMemoryBound(to: UInt8.self)
        let colonnes = (largeur + pas - 1) / pas
        let rangees = (hauteur + pas - 1) / pas
        var resultat: [UInt8] = []
        resultat.reserveCapacity(colonnes * rangees)
        var y = 0
        while y < hauteur {
            var x = 0
            while x < largeur {
                resultat.append(octets[y * ligne + x])
                x += pas
            }
            y += pas
        }
        return GrilleLuminance(largeur: colonnes, hauteur: rangees, valeurs: resultat)
    }

    /// Cases sans image (cadence < fréquence demandée) : valeur précédente.
    static func combler(_ valeurs: [Double]) -> [Double] {
        var derniere = 0.0
        return valeurs.map { v in
            if v.isNaN { return derniere }
            derniere = v
            return v
        }
    }

    // MARK: - Audio

    /// Piste audio complète, mixée en mono, PCM flottant à `frequence` Hz.
    /// Mémoire : ~2,6 Mo par minute à 11 025 Hz — pour un match entier,
    /// préférer `sifflets(video:)` (flux, mémoire constante).
    public static func audio(video url: URL, frequence: Double = 11_025) async throws -> SignalAudio {
        var echantillons: [Float] = []
        try await parcourirAudio(video: url, frequence: frequence) { echantillons.append(contentsOf: $0) }
        return SignalAudio(echantillons: echantillons, frequenceEchantillonnage: frequence)
    }

    /// Sifflets de toute la piste audio, analysés au fil de la lecture.
    public static func sifflets(video url: URL, frequence: Double = 11_025,
                                parametres: ParametresSifflet = .parDefaut) async throws -> [SiffletDetecte] {
        guard var flux = AnalyseurSiffletsFlux(frequenceEchantillonnage: frequence, parametres: parametres) else {
            return []
        }
        try await parcourirAudio(video: url, frequence: frequence) { flux.ajouter($0) }
        return flux.terminer()
    }

    /// Lit la piste audio morceau par morceau (mono, PCM flottant).
    static func parcourirAudio(video url: URL, frequence: Double, _ traiter: ([Float]) -> Void) async throws {
        let asset = AVURLAsset(url: url)
        let pistes = try await asset.loadTracks(withMediaType: .audio)
        guard !pistes.isEmpty else { throw ErreurVideo.aucunePisteAudio }
        let lecteur = try AVAssetReader(asset: asset)
        let sortie = AVAssetReaderAudioMixOutput(audioTracks: pistes, audioSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: frequence,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ])
        lecteur.add(sortie)
        guard lecteur.startReading() else {
            throw ErreurVideo.lectureImpossible(lecteur.error?.localizedDescription ?? "startReading")
        }

        while let tampon = sortie.copyNextSampleBuffer() {
            guard let bloc = CMSampleBufferGetDataBuffer(tampon) else { continue }
            let nombre = CMBlockBufferGetDataLength(bloc) / MemoryLayout<Float>.size
            guard nombre > 0 else { continue }
            var morceau = [Float](repeating: 0, count: nombre)
            let statut = morceau.withUnsafeMutableBytes { octets -> OSStatus in
                guard let adresse = octets.baseAddress else { return kCMBlockBufferBadPointerParameterErr }
                return CMBlockBufferCopyDataBytes(bloc, atOffset: 0,
                                                  dataLength: nombre * MemoryLayout<Float>.size,
                                                  destination: adresse)
            }
            if statut == kCMBlockBufferNoErr { traiter(morceau) }
        }
        if lecteur.status == .failed {
            throw ErreurVideo.lectureImpossible(lecteur.error?.localizedDescription ?? "lecture")
        }
    }
}
#endif
