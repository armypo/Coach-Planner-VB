//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Couche Apple testée sur de VRAIS fichiers générés à la volée : vidéo H.264
//  (fond fixe + carré mobile pendant les « échanges ») et audio WAV (bruit de
//  gymnase + coups de sifflet). Exécutés sur le runner macOS de la CI.
//

#if canImport(AVFoundation)
import AVFoundation
import Foundation
import Testing
@testable import PlaycoVideo

enum FabriqueMedia {
    static let largeur = 160
    static let hauteur = 96

    static func fichierTemporaire(_ extensionFichier: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("media-\(UUID().uuidString).\(extensionFichier)")
    }

    /// Vidéo H.264 à `fps` images/s : fond texturé fixe ; pendant les plages
    /// actives, un carré blanc se déplace à chaque image.
    static func video(duree: Double, fps: Int32 = 10, actives: [ClosedRange<Double>],
                      dateCreation: String? = nil) async throws -> URL {
        let url = fichierTemporaire("mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        if let dateCreation {
            let item = AVMutableMetadataItem()
            item.identifier = .quickTimeMetadataCreationDate
            item.value = dateCreation as NSString
            item.dataType = kCMMetadataBaseDataType_UTF8 as String
            writer.metadata = [item]
        }
        let entree = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: largeur,
            AVVideoHeightKey: hauteur
        ])
        entree.expectsMediaDataInRealTime = false
        let adaptateur = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: entree, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: largeur,
            kCVPixelBufferHeightKey as String: hauteur
        ])
        writer.add(entree)
        guard writer.startWriting() else { throw writer.error ?? ErreurVideo.exportImpossible("startWriting") }
        writer.startSession(atSourceTime: .zero)

        var rng = GenerateurDeterministe(graine: 99)
        let fond = (0..<(largeur * hauteur)).map { _ in UInt8.random(in: 60...90, using: &rng) }
        for i in 0..<Int(duree * Double(fps)) {
            let t = Double(i) / Double(fps)
            while !entree.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(2)) }
            guard let pool = adaptateur.pixelBufferPool else { throw ErreurVideo.exportImpossible("pool") }
            var sortie: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &sortie)
            guard let tampon = sortie else { throw ErreurVideo.exportImpossible("pixel buffer") }

            CVPixelBufferLockBaseAddress(tampon, [])
            guard let base = CVPixelBufferGetBaseAddress(tampon)?.assumingMemoryBound(to: UInt8.self) else {
                CVPixelBufferUnlockBaseAddress(tampon, [])
                throw ErreurVideo.exportImpossible("base address")
            }
            let ligne = CVPixelBufferGetBytesPerRow(tampon)
            let actif = actives.contains { $0.contains(t) }
            let cx = (i * 7) % (largeur - 20), cy = (i * 5) % (hauteur - 20)
            for y in 0..<hauteur {
                for x in 0..<largeur {
                    var v = fond[y * largeur + x]
                    if actif, (cx..<cx + 20).contains(x), (cy..<cy + 20).contains(y) { v = 255 }
                    let p = y * ligne + x * 4
                    base[p] = v; base[p + 1] = v; base[p + 2] = v; base[p + 3] = 255
                }
            }
            CVPixelBufferUnlockBaseAddress(tampon, [])
            adaptateur.append(tampon, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: fps))
        }
        entree.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? ErreurVideo.exportImpossible("finishWriting") }
        return url
    }

    /// Vidéo « du web » : la caméra panoramique en continu sur une texture
    /// lisse (`pixelsParImage` px par image), un joueur bouge pendant les
    /// plages actives, et une coupure de montage change de plan à `coupure`.
    static func videoPanoramique(duree: Double, fps: Int32 = 10, actives: [ClosedRange<Double>],
                                 pixelsParImage: Double = 4, coupure: Double? = nil) async throws -> URL {
        let url = fichierTemporaire("mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let entree = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: largeur,
            AVVideoHeightKey: hauteur
        ])
        entree.expectsMediaDataInRealTime = false
        let adaptateur = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: entree, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: largeur,
            kCVPixelBufferHeightKey as String: hauteur
        ])
        writer.add(entree)
        guard writer.startWriting() else { throw writer.error ?? ErreurVideo.exportImpossible("startWriting") }
        writer.startSession(atSourceTime: .zero)

        for i in 0..<Int(duree * Double(fps)) {
            let t = Double(i) / Double(fps)
            while !entree.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(2)) }
            guard let pool = adaptateur.pixelBufferPool else { throw ErreurVideo.exportImpossible("pool") }
            var sortie: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &sortie)
            guard let tampon = sortie else { throw ErreurVideo.exportImpossible("pixel buffer") }
            CVPixelBufferLockBaseAddress(tampon, [])
            guard let base = CVPixelBufferGetBaseAddress(tampon)?.assumingMemoryBound(to: UInt8.self) else {
                CVPixelBufferUnlockBaseAddress(tampon, [])
                throw ErreurVideo.exportImpossible("base address")
            }
            let ligne = CVPixelBufferGetBytesPerRow(tampon)
            let actif = actives.contains { $0.contains(t) }
            let clair = coupure.map { t >= $0 } ?? false
            let decalage = Double(i) * pixelsParImage
            let cx = (i * 7) % (largeur - 20), cy = (i * 5) % (hauteur - 20)
            for y in 0..<hauteur {
                for x in 0..<largeur {
                    var v = TextureTest.valeur(Double(x) + decalage, Double(y), clair: clair)
                    if actif, (cx..<cx + 20).contains(x), (cy..<cy + 20).contains(y) { v = 255 }
                    let p = y * ligne + x * 4
                    base[p] = v; base[p + 1] = v; base[p + 2] = v; base[p + 3] = 255
                }
            }
            CVPixelBufferUnlockBaseAddress(tampon, [])
            adaptateur.append(tampon, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: fps))
        }
        entree.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? ErreurVideo.exportImpossible("finishWriting") }
        return url
    }

    /// Audio WAV mono : bruit de fond + sifflets à 3 150 Hz sur les plages données.
    static func audio(duree: Double, frequence: Double = 44_100, sifflets: [ClosedRange<Double>]) throws -> URL {
        let url = fichierTemporaire("wav")
        guard let format = AVAudioFormat(standardFormatWithSampleRate: frequence, channels: 1) else {
            throw ErreurVideo.exportImpossible("format audio")
        }
        let n = AVAudioFrameCount(duree * frequence)
        guard let tampon = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: n),
              let canal = tampon.floatChannelData?[0] else {
            throw ErreurVideo.exportImpossible("tampon audio")
        }
        tampon.frameLength = n
        var rng = GenerateurDeterministe(graine: 7)
        for i in 0..<Int(n) {
            let t = Double(i) / frequence
            var v = Float.random(in: -0.05...0.05, using: &rng)
            if sifflets.contains(where: { $0.contains(t) }) { v += 0.5 * Float(sin(2 * Double.pi * 3150 * t)) }
            canal[i] = v
        }
        try ecrire(tampon, format: format, vers: url)
        return url
    }

    /// Portée dédiée : le fichier est fermé (deinit) à la sortie.
    private static func ecrire(_ tampon: AVAudioPCMBuffer, format: AVAudioFormat, vers url: URL) throws {
        let fichier = try AVAudioFile(forWriting: url, settings: format.settings)
        try fichier.write(from: tampon)
    }
}

@Suite("Apple — métadonnées, signaux, export (vrais fichiers)")
struct AppleMediaTests {

    @Test("date de création iPhone relue ; durée, taille et cadence")
    func metadonnees() async throws {
        let url = try await FabriqueMedia.video(duree: 3, actives: [], dateCreation: "2026-09-29T10:00:00-0400")
        let meta = try await LecteurMetadonneesVideo.lire(url)
        let attendue = try #require(ISO8601DateFormatter().date(from: "2026-09-29T14:00:00Z"))
        let date = try #require(meta.dateCreation)
        #expect(abs(date.timeIntervalSince(attendue)) < 1)
        #expect(meta.origineDate == .cameraQuickTime)
        #expect(meta.dateFiable)
        #expect(abs(meta.duree - 3) < 0.2)
        #expect(meta.largeur == FabriqueMedia.largeur)
        #expect(meta.hauteur == FabriqueMedia.hauteur)
        #expect(!meta.aUnePisteAudio)
        #expect(LecteurMetadonneesVideo.alignementInitial(meta)?.dateDebutVideo == date)
    }

    @Test("sans clé caméra : date de l'en-tête (écriture du fichier), signalée non fiable")
    func sansCleCamera() async throws {
        let url = try await FabriqueMedia.video(duree: 2, actives: [])
        let meta = try await LecteurMetadonneesVideo.lire(url)
        // AVFoundation date quand même le fichier : l'instant où il a été écrit.
        if let date = meta.dateCreation {
            #expect(abs(date.timeIntervalSinceNow) < 600)
            #expect(meta.origineDate == .enTeteConteneur)
        }
        #expect(!meta.dateFiable)
    }

    @Test("formats de date acceptés")
    func formatsDate() {
        #expect(LecteurMetadonneesVideo.analyserDate("2026-09-29T10:00:00-0400") != nil)
        #expect(LecteurMetadonneesVideo.analyserDate("2026-09-29T10:00:00-04:00") != nil)
        #expect(LecteurMetadonneesVideo.analyserDate("2026-09-29T14:00:00.250Z") != nil)
        #expect(LecteurMetadonneesVideo.analyserDate("pas une date") == nil)
    }

    @Test("vidéo réelle → signal d'activité → échanges retrouvés à ±0,5 s")
    func activiteVersEchanges() async throws {
        let actives: [ClosedRange<Double>] = [5...9, 13...16]
        let url = try await FabriqueMedia.video(duree: 20, actives: actives)
        let signal = try await ExtracteurSignaux.activite(video: url, frequence: 10, pasPixels: 2)
        #expect(abs(signal.duree - 20) < 0.5)

        let echanges = DetecteurEchanges.detecter(signal)
        try #require(echanges.count == 2)
        for (echange, attendu) in zip(echanges, actives) {
            #expect(abs(echange.debut - attendu.lowerBound) <= 0.5)
            #expect(abs(echange.fin - attendu.upperBound) <= 0.5)
        }
    }

    @Test("audio réel (WAV 44,1 kHz) → rééchantillonné 11 kHz → sifflets retrouvés")
    func audioVersSifflets() async throws {
        let url = try FabriqueMedia.audio(duree: 6, sifflets: [1.0...1.4, 4.0...4.6])
        let audio = try await ExtracteurSignaux.audio(video: url)
        #expect(audio.frequenceEchantillonnage == 11_025)
        #expect(abs(Double(audio.echantillons.count) / 11_025 - 6) < 0.1)

        let sifflets = DetecteurSifflets.detecter(audio)
        try #require(sifflets.count == 2)
        #expect(abs(sifflets[0].debut - 1.0) <= 0.06)
        #expect(abs(sifflets[1].fin - 4.6) <= 0.06)
    }

    @Test("AnalyseurEchanges sur vraie vidéo, mesuré au banc d'essai")
    func analyseurConcret() async throws {
        let actives: [ClosedRange<Double>] = [3...7, 11...15]
        let url = try await FabriqueMedia.video(duree: 18, actives: actives)
        let rapport = try await BancEssai.evaluer(
            AnalyseurEchanges(pasPixels: 2), video: url,
            verite: actives.map { VeriteTerrain(instant: $0.upperBound, etiquette: "fin") },
            tolerance: .symetrique(0.5))
        #expect(rapport.global.rappel == 1)
        #expect(rapport.global.precision == 1)
    }

    @Test("sifflets en flux depuis un fichier audio (mémoire constante)")
    func siffletsFlux() async throws {
        let url = try FabriqueMedia.audio(duree: 6, sifflets: [1.0...1.4, 4.0...4.6])
        let enFlux = try await ExtracteurSignaux.sifflets(video: url)
        let enBloc = DetecteurSifflets.detecter(try await ExtracteurSignaux.audio(video: url))
        #expect(enFlux == enBloc)
        #expect(enFlux.count == 2)
    }

    @Test("vidéo du web (panoramique continu + coupure) : échanges retrouvés grâce à la compensation")
    func videoDuWeb() async throws {
        let actives: [ClosedRange<Double>] = [5...9, 13...16]
        let url = try await FabriqueMedia.videoPanoramique(duree: 20, actives: actives, coupure: 10.5)

        let compense = try await ExtracteurSignaux.activite(video: url, frequence: 10, pasPixels: 2)
        let brut = try await ExtracteurSignaux.activite(video: url, frequence: 10, pasPixels: 2, compenserCamera: false)

        // Temps mort (1-4 s) : le panoramique seul gonfle l'activité brute.
        let mortCompense = compense.valeurs[10..<40].reduce(0, +) / 30
        let mortBrut = brut.valeurs[10..<40].reduce(0, +) / 30
        #expect(mortBrut > 3 * mortCompense)

        // Après la coupure, le plan est plus clair : le joueur y produit ~2,5×
        // moins d'activité → seuils locaux (fenêtre à l'échelle de ces 20 s).
        let echanges = DetecteurEchanges.detecter(compense, parametres: ParametresDetecteur(fenetreLocale: 6))
        try #require(echanges.count == 2)
        for (echange, attendu) in zip(echanges, actives) {
            #expect(abs(echange.debut - attendu.lowerBound) <= 0.7)
            #expect(abs(echange.fin - attendu.upperBound) <= 0.7)
        }
    }

    @Test("vidéo sans piste audio : erreur explicite")
    func sansAudio() async throws {
        let url = try await FabriqueMedia.video(duree: 1, actives: [])
        await #expect(throws: ErreurVideo.aucunePisteAudio) {
            _ = try await ExtracteurSignaux.audio(video: url)
        }
    }

    @Test("export d'un clip et d'un montage : durées attendues")
    func export() async throws {
        let url = try await FabriqueMedia.video(duree: 20, actives: [5...9, 13...16])

        let clip = FabriqueMedia.fichierTemporaire("mp4")
        try await ExporteurClip.exporter(video: url, debut: 5, fin: 9, vers: clip)
        let dureeClip = try await LecteurMetadonneesVideo.lire(clip).duree
        #expect(abs(dureeClip - 4) < 0.25)

        let montage = FabriqueMedia.fichierTemporaire("mp4")
        let segments = [SegmentLecture(debut: 5, fin: 9), SegmentLecture(debut: 13, fin: 16)]
        try await ExporteurClip.exporter(videos: [url], segments: segments, vers: montage)
        let dureeMontage = try await LecteurMetadonneesVideo.lire(montage).duree
        #expect(abs(dureeMontage - 7) < 0.3)
    }

    @Test("montage à travers deux fichiers du même match (un par set)")
    func montageMultiFichiers() async throws {
        let set1 = try await FabriqueMedia.video(duree: 6, actives: [1...3])
        let set2 = try await FabriqueMedia.video(duree: 6, actives: [2...5])
        let montage = FabriqueMedia.fichierTemporaire("mp4")
        let segments = [SegmentLecture(indexFichier: 0, debut: 1, fin: 3),
                        SegmentLecture(indexFichier: 1, debut: 2, fin: 5)]
        try await ExporteurClip.exporter(videos: [set1, set2], segments: segments, vers: montage)
        let duree = try await LecteurMetadonneesVideo.lire(montage).duree
        #expect(abs(duree - 5) < 0.3)
    }

    @Test("export hors de la vidéo : erreur explicite")
    func exportHorsVideo() async throws {
        let url = try await FabriqueMedia.video(duree: 2, actives: [])
        await #expect(throws: ErreurVideo.self) {
            try await ExporteurClip.exporter(video: url, debut: 50, fin: 60, vers: FabriqueMedia.fichierTemporaire("mp4"))
        }
    }
}
#endif
