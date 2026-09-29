//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Banc d'essai : mesure n'importe quel analyseur (signal, modèle on-device,
//  modèle cloud) contre la vérité terrain que produit le coaching (les points
//  saisis en live, situés dans la vidéo). C'est l'actif qui permet d'évaluer
//  un nouveau modèle en heures le jour de sa sortie.
//
//  Appariement un-pour-un sous tolérance temporelle : glouton « plus tôt
//  possible », optimal en cardinalité quand toutes les fenêtres ont la même
//  largeur (translatées d'une vérité à l'autre).
//

import Foundation

// MARK: - Types

/// Événement détecté par un analyseur, en temps VIDÉO (secondes).
public struct EvenementDetecte: Codable, Hashable, Sendable {
    public var instant: Double
    /// nil = détection sans classe (ex. fin d'échange).
    public var etiquette: String?
    /// Confiance 0-1.
    public var confiance: Double

    public init(instant: Double, etiquette: String? = nil, confiance: Double = 1) {
        self.instant = instant
        self.etiquette = etiquette
        self.confiance = confiance
    }
}

/// Interface commune à tout analyseur vidéo — on change de modèle sans
/// réécrire l'app.
public protocol AnalyseurVideo: Sendable {
    /// Identifiant stable et versionné (ex. « echanges-signal-v1 »).
    var identifiant: String { get }
    func analyser(video: URL) async throws -> [EvenementDetecte]
}

/// Événement de référence (vérité terrain) en temps vidéo.
public struct VeriteTerrain: Hashable, Sendable {
    public var instant: Double
    public var etiquette: String

    public init(instant: Double, etiquette: String) {
        self.instant = instant
        self.etiquette = etiquette
    }

    /// Vérité terrain issue des chapitres (l'instant du tap de saisie).
    public static func depuis(_ chapitres: [ChapitreVideo]) -> [VeriteTerrain] {
        chapitres.map { VeriteTerrain(instant: $0.instant, etiquette: $0.evenement.etiquette) }
    }
}

/// Fenêtre d'acceptation d'une prédiction autour d'une vérité :
/// prédiction ∈ [vérité − avant, vérité + après].
public struct ToleranceTemporelle: Hashable, Sendable {
    public var avant: Double
    public var apres: Double

    public init(avant: Double, apres: Double) {
        self.avant = avant
        self.apres = apres
    }

    public static func symetrique(_ secondes: Double) -> ToleranceTemporelle {
        ToleranceTemporelle(avant: secondes, apres: secondes)
    }
}

public struct ScoreDetection: Hashable, Sendable {
    public var vraisPositifs: Int
    public var fauxPositifs: Int
    public var fauxNegatifs: Int
    /// |Δt| moyen sur les appariements (secondes) ; nil sans appariement.
    public var erreurTemporelleMoyenne: Double?

    public var precision: Double {
        let total = vraisPositifs + fauxPositifs
        return total == 0 ? 0 : Double(vraisPositifs) / Double(total)
    }

    public var rappel: Double {
        let total = vraisPositifs + fauxNegatifs
        return total == 0 ? 0 : Double(vraisPositifs) / Double(total)
    }

    public var f1: Double {
        let somme = precision + rappel
        return somme == 0 ? 0 : 2 * precision * rappel / somme
    }

    static let vide = ScoreDetection(vraisPositifs: 0, fauxPositifs: 0, fauxNegatifs: 0, erreurTemporelleMoyenne: nil)

    static func + (a: ScoreDetection, b: ScoreDetection) -> ScoreDetection {
        let n = a.vraisPositifs + b.vraisPositifs
        let erreur: Double? = n == 0 ? nil
            : ((a.erreurTemporelleMoyenne ?? 0) * Double(a.vraisPositifs)
               + (b.erreurTemporelleMoyenne ?? 0) * Double(b.vraisPositifs)) / Double(n)
        return ScoreDetection(
            vraisPositifs: n,
            fauxPositifs: a.fauxPositifs + b.fauxPositifs,
            fauxNegatifs: a.fauxNegatifs + b.fauxNegatifs,
            erreurTemporelleMoyenne: erreur)
    }
}

public struct RapportBancEssai: Hashable, Sendable {
    public var global: ScoreDetection
    /// Vide si l'étiquette n'est pas exigée.
    public var parEtiquette: [String: ScoreDetection]
}

public struct PointCourbe: Hashable, Sendable {
    public var seuil: Double
    public var score: ScoreDetection
}

// MARK: - Évaluation

public enum BancEssai {

    /// Évalue des prédictions contre la vérité. Si `exigerEtiquette`, une
    /// prédiction ne compte que sur une vérité de même étiquette.
    public static func evaluer(
        predictions: [EvenementDetecte],
        verite: [VeriteTerrain],
        tolerance: ToleranceTemporelle,
        exigerEtiquette: Bool = false,
        seuilConfiance: Double = 0
    ) -> RapportBancEssai {
        let retenues = predictions.filter { $0.confiance >= seuilConfiance }
        guard exigerEtiquette else {
            return RapportBancEssai(
                global: apparier(retenues.map(\.instant), verite.map(\.instant), tolerance),
                parEtiquette: [:])
        }
        var parEtiquette: [String: ScoreDetection] = [:]
        let etiquettes = Set(verite.map(\.etiquette)).union(retenues.compactMap(\.etiquette))
        for etiquette in etiquettes {
            parEtiquette[etiquette] = apparier(
                retenues.filter { $0.etiquette == etiquette }.map(\.instant),
                verite.filter { $0.etiquette == etiquette }.map(\.instant),
                tolerance)
        }
        // Une prédiction sans étiquette ne peut rien apparier : faux positif.
        let sansEtiquette = retenues.filter { $0.etiquette == nil }.count
        var global = parEtiquette.values.reduce(ScoreDetection.vide, +)
        global.fauxPositifs += sansEtiquette
        return RapportBancEssai(global: global, parEtiquette: parEtiquette)
    }

    /// Score à chaque seuil de confiance (courbe précision/rappel).
    public static func courbe(
        predictions: [EvenementDetecte],
        verite: [VeriteTerrain],
        tolerance: ToleranceTemporelle,
        seuils: [Double],
        exigerEtiquette: Bool = false
    ) -> [PointCourbe] {
        seuils.sorted().map { seuil in
            PointCourbe(seuil: seuil, score: evaluer(
                predictions: predictions, verite: verite, tolerance: tolerance,
                exigerEtiquette: exigerEtiquette, seuilConfiance: seuil).global)
        }
    }

    /// Seuil au meilleur F1 (à égalité, le plus bas : plus de rappel).
    public static func meilleurSeuil(_ courbe: [PointCourbe]) -> PointCourbe? {
        courbe.max { a, b in
            a.score.f1 != b.score.f1 ? a.score.f1 < b.score.f1 : a.seuil > b.seuil
        }
    }

    /// Évalue un analyseur sur une vidéo dont la vérité est connue.
    public static func evaluer(
        _ analyseur: some AnalyseurVideo,
        video: URL,
        verite: [VeriteTerrain],
        tolerance: ToleranceTemporelle,
        exigerEtiquette: Bool = false
    ) async throws -> RapportBancEssai {
        let predictions = try await analyseur.analyser(video: video)
        return evaluer(predictions: predictions, verite: verite, tolerance: tolerance, exigerEtiquette: exigerEtiquette)
    }

    // MARK: - Appariement

    /// Appariement un-pour-un maximal : prédiction p appariable à la vérité v
    /// si v − avant ≤ p ≤ v + après.
    static func apparier(_ predictions: [Double], _ verites: [Double], _ tolerance: ToleranceTemporelle) -> ScoreDetection {
        let p = predictions.sorted()
        let v = verites.sorted()
        var j = 0
        var vraisPositifs = 0
        var sommeErreurs = 0.0
        for instant in v {
            // Trop tôt pour cette vérité = trop tôt pour toutes les suivantes.
            while j < p.count, p[j] < instant - tolerance.avant { j += 1 }
            if j < p.count, p[j] <= instant + tolerance.apres {
                vraisPositifs += 1
                sommeErreurs += abs(p[j] - instant)
                j += 1
            }
        }
        return ScoreDetection(
            vraisPositifs: vraisPositifs,
            fauxPositifs: p.count - vraisPositifs,
            fauxNegatifs: v.count - vraisPositifs,
            erreurTemporelleMoyenne: vraisPositifs == 0 ? nil : sommeErreurs / Double(vraisPositifs))
    }
}
