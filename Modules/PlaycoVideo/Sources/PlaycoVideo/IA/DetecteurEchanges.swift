//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  IA niveau 1 — détection des échanges (rallyes) sur un SIGNAL D'ACTIVITÉ
//  échantillonné (énergie de mouvement image à image, énergie audio…).
//  L'extraction du signal dépend de la plateforme (Vision/AVFoundation) ; la
//  segmentation, elle, est pure et testable : lissage, seuils automatiques
//  LOCAUX (fenêtre glissante, plancher) entre niveau de repos et niveau actif,
//  hystérésis, fusion des micro-coupures, durée minimale.
//

import Foundation

public struct SignalActivite: Hashable, Sendable {
    public var valeurs: [Double]
    /// Échantillons par seconde.
    public var frequence: Double

    public init(valeurs: [Double], frequence: Double) {
        self.valeurs = valeurs
        self.frequence = frequence
    }

    public var duree: Double { frequence > 0 ? Double(valeurs.count) / frequence : 0 }
}

public struct EchangeDetecte: Codable, Hashable, Sendable {
    public var debut: Double
    public var fin: Double
    /// Activité moyenne lissée pendant l'échange.
    public var intensite: Double

    public var duree: Double { fin - debut }
}

public struct ParametresDetecteur: Hashable, Sendable {
    /// Fenêtre de la moyenne mobile (secondes).
    public var lissage: Double
    /// Niveau de repos et niveau actif = quantiles du signal lissé. Le niveau
    /// actif est pris haut (q97) : il reste dans les échanges même quand le
    /// jeu n'occupe qu'une petite part de la vidéo (temps morts, pauses).
    public var quantileRepos: Double
    public var quantileActif: Double
    /// Seuils d'hystérésis, en fraction de l'écart repos → actif.
    public var fractionBas: Double
    public var fractionHaut: Double
    /// Un échange plus court est écarté (secondes).
    public var dureeMinimale: Double
    /// Deux échanges séparés de moins de cet écart fusionnent (secondes).
    public var fusionEcart: Double
    /// Seuils LOCAUX calculés sur une fenêtre glissante (secondes) : suit les
    /// changements de plan, de zoom ou d'éclairage (vidéos du web). nil =
    /// seuils globaux sur toute la vidéo.
    public var fenetreLocale: Double?
    /// Le niveau actif local ne descend jamais sous cette part du niveau actif
    /// global : une pause (temps mort, entre-sets) n'invente pas d'échange.
    public var plancherActif: Double

    /// Valeurs ESTIMÉES — à régler au banc d'essai sur vraie vidéo.
    public static let parDefaut = ParametresDetecteur()

    public init(lissage: Double = 0.5, quantileRepos: Double = 0.3, quantileActif: Double = 0.97,
                fractionBas: Double = 0.25, fractionHaut: Double = 0.6,
                dureeMinimale: Double = 2, fusionEcart: Double = 1.5,
                fenetreLocale: Double? = 60, plancherActif: Double = 0.25) {
        self.lissage = lissage
        self.quantileRepos = quantileRepos
        self.quantileActif = quantileActif
        self.fractionBas = fractionBas
        self.fractionHaut = fractionHaut
        self.dureeMinimale = dureeMinimale
        self.fusionEcart = fusionEcart
        self.fenetreLocale = fenetreLocale
        self.plancherActif = plancherActif
    }
}

public enum DetecteurEchanges {

    public static func detecter(_ signal: SignalActivite, parametres: ParametresDetecteur = .parDefaut) -> [EchangeDetecte] {
        guard signal.frequence > 0, !signal.valeurs.isEmpty else { return [] }
        let lisse = moyenneMobile(signal.valeurs, fenetre: max(1, Int((parametres.lissage * signal.frequence).rounded())))
        guard let niveaux = seuils(lisse, frequence: signal.frequence, parametres: parametres) else {
            return []   // signal plat : rien à segmenter
        }
        let (bas, haut) = (niveaux.bas, niveaux.haut)

        // Hystérésis : entre au-dessus de `haut`, sort sous `bas`. Le début
        // recule jusqu'au dernier échantillon sous `bas` (front de montée).
        var plages: [(debut: Int, fin: Int)] = []
        var debut: Int?
        for (i, v) in lisse.enumerated() {
            if let d = debut {
                if v < bas[i] {
                    plages.append((d, i))
                    debut = nil
                }
            } else if v >= haut[i] {
                var d = i
                while d > 0, lisse[d - 1] >= bas[d - 1] { d -= 1 }
                if let derniere = plages.last, d < derniere.fin { d = derniere.fin }
                debut = d
            }
        }
        if let d = debut { plages.append((d, lisse.count)) }

        // Fusion des micro-coupures, puis durée minimale.
        let ecartFusion = Int((parametres.fusionEcart * signal.frequence).rounded())
        var fusionnees: [(debut: Int, fin: Int)] = []
        for plage in plages {
            if let derniere = fusionnees.last, plage.debut - derniere.fin < ecartFusion {
                fusionnees[fusionnees.count - 1].fin = plage.fin
            } else {
                fusionnees.append(plage)
            }
        }

        return fusionnees.compactMap { plage in
            let debut = Double(plage.debut) / signal.frequence
            let fin = Double(plage.fin) / signal.frequence
            guard fin - debut >= parametres.dureeMinimale else { return nil }
            let tranche = lisse[plage.debut..<plage.fin]
            return EchangeDetecte(debut: debut, fin: fin, intensite: tranche.reduce(0, +) / Double(tranche.count))
        }
    }

    /// Fins d'échange en événements détectés (confiance = intensité relative).
    public static func finsEnEvenements(_ echanges: [EchangeDetecte]) -> [EvenementDetecte] {
        let maximum = echanges.map(\.intensite).max() ?? 0
        return echanges.map {
            EvenementDetecte(instant: $0.fin, etiquette: nil,
                             confiance: maximum > 0 ? min(1, max(0, $0.intensite / maximum)) : 0)
        }
    }

    // MARK: - Seuils

    /// Seuils bas/haut par échantillon : globaux, ou locaux par blocs (quart
    /// de fenêtre) avec un plancher sur le niveau actif. nil si signal plat.
    static func seuils(_ lisse: [Double], frequence: Double,
                       parametres p: ParametresDetecteur) -> (bas: [Double], haut: [Double])? {
        let n = lisse.count
        let reposGlobal = quantile(lisse, p.quantileRepos)
        let actifGlobal = quantile(lisse, p.quantileActif)
        guard actifGlobal > reposGlobal else { return nil }

        func niveaux(_ repos: Double, _ actif: Double) -> (Double, Double) {
            (repos + p.fractionBas * (actif - repos), repos + p.fractionHaut * (actif - repos))
        }

        guard let fenetre = p.fenetreLocale, fenetre > 0 else {
            let (b, h) = niveaux(reposGlobal, actifGlobal)
            return (Array(repeating: b, count: n), Array(repeating: h, count: n))
        }
        let largeur = max(2, Int(fenetre * frequence))
        let bloc = max(1, largeur / 4)
        let plancher = reposGlobal + p.plancherActif * (actifGlobal - reposGlobal)
        var bas = [Double](repeating: 0, count: n)
        var haut = [Double](repeating: 0, count: n)
        var debut = 0
        while debut < n {
            let fin = min(n, debut + bloc)
            let centre = (debut + fin) / 2
            let tranche = Array(lisse[max(0, centre - largeur / 2)..<min(n, centre + largeur / 2 + 1)])
            let repos = min(quantile(tranche, p.quantileRepos), plancher)
            let actif = max(quantile(tranche, p.quantileActif), plancher)
            let (b, h) = niveaux(repos, max(actif, repos + 1e-9))
            for i in debut..<fin { bas[i] = b; haut[i] = h }
            debut = fin
        }
        return (bas, haut)
    }

    // MARK: - Outils

    /// Moyenne mobile centrée (bords : fenêtre tronquée).
    static func moyenneMobile(_ valeurs: [Double], fenetre: Int) -> [Double] {
        guard fenetre > 1, !valeurs.isEmpty else { return valeurs }
        var cumul = [0.0]
        cumul.reserveCapacity(valeurs.count + 1)
        for v in valeurs { cumul.append(cumul[cumul.count - 1] + v) }
        let demi = fenetre / 2
        return valeurs.indices.map { i in
            let a = max(0, i - demi)
            let b = min(valeurs.count, i - demi + fenetre)
            return (cumul[b] - cumul[a]) / Double(b - a)
        }
    }

    /// Quantile par interpolation linéaire (q ∈ [0, 1]).
    static func quantile(_ valeurs: [Double], _ q: Double) -> Double {
        let tries = valeurs.sorted()
        guard !tries.isEmpty else { return 0 }
        let position = min(max(q, 0), 1) * Double(tries.count - 1)
        let i = Int(position.rounded(.down))
        let fraction = position - Double(i)
        return i + 1 < tries.count ? tries[i] + fraction * (tries[i + 1] - tries[i]) : tries[i]
    }
}
