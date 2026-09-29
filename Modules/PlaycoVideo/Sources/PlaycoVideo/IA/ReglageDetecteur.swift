//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Réglage AUTOMATIQUE du détecteur d'échanges au banc d'essai : sur un ou
//  plusieurs matchs dont la vérité est connue (points saisis en live, calés),
//  on cherche la combinaison de paramètres au meilleur F1. Remplace les
//  valeurs ESTIMÉES par des valeurs MESURÉES dès qu'on a de vrais matchs.
//  ⚠️ Valider sur un match qui n'a pas servi au réglage (surapprentissage).
//

import Foundation

public struct GrilleReglage: Hashable, Sendable {
    public var lissages: [Double]
    public var fractionsBas: [Double]
    public var fractionsHaut: [Double]
    public var dureesMinimales: [Double]
    public var fusions: [Double]

    public static let parDefaut = GrilleReglage(
        lissages: [0.3, 0.5, 1.0],
        fractionsBas: [0.15, 0.25, 0.35],
        fractionsHaut: [0.5, 0.6, 0.75, 0.9],
        dureesMinimales: [2, 3, 4],
        fusions: [1, 1.5, 2.5])

    public init(lissages: [Double], fractionsBas: [Double], fractionsHaut: [Double],
                dureesMinimales: [Double], fusions: [Double]) {
        self.lissages = lissages
        self.fractionsBas = fractionsBas
        self.fractionsHaut = fractionsHaut
        self.dureesMinimales = dureesMinimales
        self.fusions = fusions
    }

    /// Combinaisons valides (seuil bas < seuil haut).
    var combinaisons: [ParametresDetecteur] {
        var resultat: [ParametresDetecteur] = []
        for lissage in lissages {
            for bas in fractionsBas {
                for haut in fractionsHaut where haut > bas {
                    for duree in dureesMinimales {
                        for fusion in fusions {
                            resultat.append(ParametresDetecteur(
                                lissage: lissage, fractionBas: bas, fractionHaut: haut,
                                dureeMinimale: duree, fusionEcart: fusion))
                        }
                    }
                }
            }
        }
        return resultat
    }
}

/// Un match annoté : son signal d'activité et les vraies fins d'échange.
public struct MatchAnnote: Sendable {
    public var signal: SignalActivite
    public var finsEchanges: [Double]

    public init(signal: SignalActivite, finsEchanges: [Double]) {
        self.signal = signal
        self.finsEchanges = finsEchanges
    }
}

public struct ResultatReglage: Hashable, Sendable {
    public var parametres: ParametresDetecteur
    /// Score cumulé sur tous les matchs annotés.
    public var score: ScoreDetection
    public var combinaisonsEssayees: Int
}

public enum ReglageDetecteur {

    /// Score des paramètres sur des matchs annotés (fins d'échange, tolérance donnée).
    public static func evaluer(_ parametres: ParametresDetecteur, sur matchs: [MatchAnnote],
                               tolerance: ToleranceTemporelle = .symetrique(1)) -> ScoreDetection {
        matchs.reduce(ScoreDetection.vide) { total, match in
            let fins = DetecteurEchanges.detecter(match.signal, parametres: parametres).map(\.fin)
            return total + BancEssai.apparier(fins, match.finsEchanges, tolerance)
        }
    }

    /// Meilleure combinaison de la grille (à égalité de F1, la plus proche
    /// des valeurs par défaut — premier trouvé dans l'ordre de la grille).
    public static func optimiser(sur matchs: [MatchAnnote],
                                 grille: GrilleReglage = .parDefaut,
                                 tolerance: ToleranceTemporelle = .symetrique(1)) -> ResultatReglage? {
        let combinaisons = grille.combinaisons
        guard !matchs.isEmpty, !combinaisons.isEmpty else { return nil }
        var meilleur: ResultatReglage?
        for parametres in combinaisons {
            let score = evaluer(parametres, sur: matchs, tolerance: tolerance)
            if let actuel = meilleur, actuel.score.f1 >= score.f1 { continue }
            meilleur = ResultatReglage(parametres: parametres, score: score, combinaisonsEssayees: combinaisons.count)
        }
        return meilleur
    }
}
