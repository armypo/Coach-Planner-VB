//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Plateformes Apple — premier analyseur concret (IA niveau 1, sans modèle
//  appris) : activité visuelle → échanges, bornes affinées par les sifflets
//  quand la vidéo a du son. Conforme à `AnalyseurVideo` : il se mesure au
//  banc d'essai comme n'importe quel futur modèle.
//

#if canImport(AVFoundation)
import Foundation

public struct AnalyseurEchanges: AnalyseurVideo {
    public let identifiant = "echanges-signal-v1"
    public var parametres: ParametresDetecteur
    public var parametresSifflet: ParametresSifflet
    /// Cadence du signal d'activité (Hz) et sous-échantillonnage spatial.
    public var frequence: Double
    public var pasPixels: Int

    public init(parametres: ParametresDetecteur = .parDefaut,
                parametresSifflet: ParametresSifflet = .parDefaut,
                frequence: Double = 10,
                pasPixels: Int = 8) {
        self.parametres = parametres
        self.parametresSifflet = parametresSifflet
        self.frequence = frequence
        self.pasPixels = pasPixels
    }

    /// Échanges de la vidéo (utiles aussi à `EstimationFenetre`).
    public func echanges(video: URL) async throws -> [EchangeDetecte] {
        let signal = try await ExtracteurSignaux.activite(video: video, frequence: frequence, pasPixels: pasPixels)
        let echanges = DetecteurEchanges.detecter(signal, parametres: parametres)
        guard try await LecteurMetadonneesVideo.lire(video).aUnePisteAudio else { return echanges }
        let sifflets = try await ExtracteurSignaux.sifflets(video: video, parametres: parametresSifflet)
        return FusionBornes.affiner(echanges, sifflets: sifflets)
    }

    /// Fins d'échange (ce que le calage automatique et le banc d'essai consomment).
    public func analyser(video: URL) async throws -> [EvenementDetecte] {
        let trouves = try await echanges(video: video)
        return DetecteurEchanges.finsEnEvenements(trouves)
    }
}
#endif
