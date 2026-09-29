//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Relie le temps réel des événements au temps du fichier vidéo :
//  instant = facteurEchelle × (horodatage − début) + décalage.
//  Le calage part de la métadonnée du fichier, puis se corrige par des ANCRES
//  (le coach repère un point connu dans la vidéo) : 1 ancre = décalage ;
//  plusieurs ancres éloignées = décalage + dérive d'horloge (moindres carrés).
//

import Foundation

/// Comment l'alignement a été obtenu.
public enum SourceAlignement: String, Codable, Hashable, Sendable {
    /// Métadonnée de création du fichier (vidéo iPhone/iPad).
    case metadonneeFichier
    /// Saisi à la main par le coach.
    case manuel
    /// Recalé sur des ancres posées par le coach.
    case ancres
    /// Recalé automatiquement (corrélation échanges détectés ↔ points).
    case automatique
}

/// Un événement connu repéré à la main dans la vidéo.
public struct AncreAlignement: Codable, Hashable, Sendable {
    /// Instant réel de l'événement (horodatage du point).
    public var horodatage: Date
    /// Position où le coach l'a repéré dans la vidéo (secondes).
    public var instantVideo: Double

    public init(horodatage: Date, instantVideo: Double) {
        self.horodatage = horodatage
        self.instantVideo = instantVideo
    }
}

public struct AlignementVideo: Codable, Hashable, Sendable {
    /// Instant réel supposé du début de l'enregistrement.
    public var dateDebutVideo: Date
    /// Correction en secondes (+ = les événements arrivent plus tard dans la vidéo).
    public var decalageSecondes: Double
    /// Dérive entre l'horloge de la caméra et celle de l'appareil de saisie (1 = aucune).
    public var facteurEchelle: Double
    /// Durée du fichier vidéo en secondes.
    public var dureeVideo: Double

    /// Écart de base minimal entre ancres pour estimer une dérive (en deçà, le
    /// bruit de repérage domine : on ne corrige que le décalage).
    public static let baseMinimaleDerive: Double = 600
    /// Dérive maximale plausible (0,1 % ≈ 3,6 s/h) — au-delà, une ancre est fausse.
    public static let deriveMaximale: Double = 0.001

    public init(dateDebutVideo: Date, decalageSecondes: Double = 0, facteurEchelle: Double = 1, dureeVideo: Double) {
        self.dateDebutVideo = dateDebutVideo
        self.decalageSecondes = decalageSecondes
        self.facteurEchelle = facteurEchelle
        self.dureeVideo = dureeVideo
    }

    /// Position d'un instant réel dans la vidéo (secondes, peut sortir de [0, durée]).
    public func instantDansVideo(_ date: Date) -> Double {
        facteurEchelle * date.timeIntervalSince(dateDebutVideo) + decalageSecondes
    }

    /// Écart (secondes) entre la position prédite et la position repérée, par ancre.
    public func ecarts(_ ancres: [AncreAlignement]) -> [Double] {
        ancres.map { instantDansVideo($0.horodatage) - $0.instantVideo }
    }

    /// Alignement recalé sur des ancres ; nil sans ancre. Décalage seul (médiane,
    /// robuste à une ancre fausse) si la base est trop courte ou la dérive
    /// implausible ; sinon décalage + dérive par moindres carrés.
    public func calee(sur ancres: [AncreAlignement]) -> AlignementVideo? {
        guard !ancres.isEmpty else { return nil }
        let x = ancres.map { $0.horodatage.timeIntervalSince(dateDebutVideo) }
        let y = ancres.map(\.instantVideo)

        var resultat = self
        let base = (x.max() ?? 0) - (x.min() ?? 0)
        if ancres.count >= 2, base >= Self.baseMinimaleDerive,
           let ajustement = Self.moindresCarres(x: x, y: y),
           abs(ajustement.pente - 1) <= Self.deriveMaximale {
            resultat.facteurEchelle = ajustement.pente
            resultat.decalageSecondes = ajustement.ordonnee
        } else {
            resultat.facteurEchelle = 1
            resultat.decalageSecondes = Self.mediane(zip(x, y).map { $1 - $0 })
        }
        return resultat
    }

    // MARK: - Décodage tolérant (champs ajoutés après la v1 du manifeste)

    private enum CodingKeys: String, CodingKey {
        case dateDebutVideo, decalageSecondes, facteurEchelle, dureeVideo
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dateDebutVideo = try c.decode(Date.self, forKey: .dateDebutVideo)
        dureeVideo = try c.decode(Double.self, forKey: .dureeVideo)
        decalageSecondes = try c.decodeIfPresent(Double.self, forKey: .decalageSecondes) ?? 0
        facteurEchelle = try c.decodeIfPresent(Double.self, forKey: .facteurEchelle) ?? 1
    }

    // MARK: - Calcul

    static func moindresCarres(x: [Double], y: [Double]) -> (pente: Double, ordonnee: Double)? {
        let n = Double(x.count)
        guard x.count == y.count, x.count >= 2 else { return nil }
        let mx = x.reduce(0, +) / n
        let my = y.reduce(0, +) / n
        var sxx = 0.0, sxy = 0.0
        for (xi, yi) in zip(x, y) {
            sxx += (xi - mx) * (xi - mx)
            sxy += (xi - mx) * (yi - my)
        }
        guard sxx > 0 else { return nil }
        let pente = sxy / sxx
        return (pente, my - pente * mx)
    }

    static func mediane(_ valeurs: [Double]) -> Double {
        let tries = valeurs.sorted()
        guard !tries.isEmpty else { return 0 }
        let milieu = tries.count / 2
        return tries.count % 2 == 1 ? tries[milieu] : (tries[milieu - 1] + tries[milieu]) / 2
    }
}
