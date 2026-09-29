//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Plateformes Apple — extraction des signaux que consomment les détecteurs
//  purs (DetecteurEchanges, DetecteurSifflets) :
//  - activité visuelle = différence moyenne de luminance entre images
//    échantillonnées (plan Y seulement, un pixel sur `pasPixels`) ;
//  - audio mono rééchantillonné (11 025 Hz par défaut).
//  Tout se fait sur l'appareil, sans réseau.
//

#if canImport(AVFoundation)
import AVFoundation
import Foundation

public enum ExtracteurSignaux {

    // MARK: - Activité visuelle

    /// Signal d'activité à `frequence` Hz sur toute la vidéo.
    /// - Parameter pasPixels: sous-échantillonnage spatial (8 ⇒ 1080p lu en 240×135).
    public static func activite(video url: URL, frequence: Double = 10, pasPixels: Int = 8) async throws -> SignalActivite {
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
        var precedente: [UInt8]?
        var prochainInstant = 0.0

        while let tampon = sortie.copyNextSampleBuffer() {
            let instant = CMSampleBufferGetPresentationTimeStamp(tampon).seconds
            guard instant.isFinite, instant + 1e-6 >= prochainInstant,
                  let image = CMSampleBufferGetImageBuffer(tampon) else { continue }
            prochainInstant = (instant * frequence + 1).rounded(.down) / frequence

            let courante = luminance(image, pas: pas)
            if let precedente, precedente.count == courante.count, !courante.isEmpty {
                var somme = 0
                for i in courante.indices { somme += abs(Int(courante[i]) - Int(precedente[i])) }
                let index = min(nombre - 1, max(0, Int((instant * frequence).rounded(.down))))
                valeurs[index] = Double(somme) / Double(courante.count) / 255
            }
            precedente = courante
        }
        if lecteur.status == .failed {
            throw ErreurVideo.lectureImpossible(lecteur.error?.localizedDescription ?? "lecture")
        }
        return SignalActivite(valeurs: combler(valeurs), frequence: frequence)
    }

    /// Plan Y sous-échantillonné (copie — le tampon est rendu aussitôt).
    static func luminance(_ image: CVImageBuffer, pas: Int) -> [UInt8] {
        CVPixelBufferLockBaseAddress(image, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(image, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddressOfPlane(image, 0) else { return [] }
        let largeur = CVPixelBufferGetWidthOfPlane(image, 0)
        let hauteur = CVPixelBufferGetHeightOfPlane(image, 0)
        let ligne = CVPixelBufferGetBytesPerRowOfPlane(image, 0)
        let octets = base.assumingMemoryBound(to: UInt8.self)
        var resultat: [UInt8] = []
        resultat.reserveCapacity((largeur / pas + 1) * (hauteur / pas + 1))
        var y = 0
        while y < hauteur {
            var x = 0
            while x < largeur {
                resultat.append(octets[y * ligne + x])
                x += pas
            }
            y += pas
        }
        return resultat
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

    /// Piste audio mixée en mono, PCM flottant à `frequence` Hz.
    /// Mémoire : ~2,6 Mo par minute à 11 025 Hz.
    public static func audio(video url: URL, frequence: Double = 11_025) async throws -> SignalAudio {
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

        var echantillons: [Float] = []
        while let tampon = sortie.copyNextSampleBuffer() {
            guard let bloc = CMSampleBufferGetDataBuffer(tampon) else { continue }
            let longueur = CMBlockBufferGetDataLength(bloc)
            let nombre = longueur / MemoryLayout<Float>.size
            guard nombre > 0 else { continue }
            let debut = echantillons.count
            echantillons.append(contentsOf: repeatElement(0, count: nombre))
            let statut = echantillons.withUnsafeMutableBytes { tamponOctets -> OSStatus in
                guard let adresse = tamponOctets.baseAddress else { return kCMBlockBufferBadPointerParameterErr }
                return CMBlockBufferCopyDataBytes(
                    bloc, atOffset: 0, dataLength: nombre * MemoryLayout<Float>.size,
                    destination: adresse.advanced(by: debut * MemoryLayout<Float>.size))
            }
            if statut != kCMBlockBufferNoErr { echantillons.removeLast(nombre) }
        }
        if lecteur.status == .failed {
            throw ErreurVideo.lectureImpossible(lecteur.error?.localizedDescription ?? "lecture")
        }
        return SignalAudio(echantillons: echantillons, frequenceEchantillonnage: frequence)
    }
}
#endif
