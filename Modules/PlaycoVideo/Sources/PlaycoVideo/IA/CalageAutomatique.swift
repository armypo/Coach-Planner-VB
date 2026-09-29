//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Calage AUTOMATIQUE vidéo ↔ stats : les points sont saisis juste APRÈS la
//  fin des échanges. On cherche le décalage qui fait tomber le plus de taps
//  dans la fenêtre [fin d'échange, fin d'échange + délai max] — plus besoin
//  d'ancre manuelle quand l'horloge de la caméra est fausse.
//  + estimation de la fenêtre de clip à partir des échanges appariés.
//

import Foundation

public struct ResultatCalage: Hashable, Sendable {
    /// Décalage à AJOUTER à l'alignement courant (secondes).
    public var decalage: Double
    /// Taps expliqués par un échange avec ce décalage.
    public var appariements: Int
    /// Part des taps expliqués (0-1).
    public var couverture: Double
    /// Meilleur score obtenu loin du décalage retenu (> 2 × délai max) :
    /// proche de `appariements` = calage ambigu (structure périodique).
    public var appariementsConcurrent: Int

    /// Calage fiable : couverture suffisante et pic net.
    public var estFiable: Bool {
        couverture >= 0.5 && Double(appariementsConcurrent) <= 0.7 * Double(appariements)
    }
}

public enum CalageAutomatique {

    /// - Parameters:
    ///   - taps: instants des points dans la vidéo selon l'alignement courant.
    ///   - finsEchanges: fins d'échange détectées (secondes vidéo).
    ///   - delaiMax: délai maximal entre la fin d'un échange et le tap de saisie.
    ///   - plage: décalages explorés, de −plage à +plage.
    ///   - pas: résolution de la recherche.
    /// - Returns: nil sans données.
    public static func estimer(
        taps: [Double],
        finsEchanges: [Double],
        delaiMax: Double = 8,
        plage: Double = 600,
        pas: Double = 0.5
    ) -> ResultatCalage? {
        guard !taps.isEmpty, !finsEchanges.isEmpty, pas > 0, plage >= 0 else { return nil }
        let tolerance = ToleranceTemporelle(avant: delaiMax, apres: 0)
        let n = Int((plage / pas).rounded())
        let candidats = (-n...n).map { Double($0) * pas }
        let scores = candidats.map { d in
            BancEssai.apparier(finsEchanges, taps.map { $0 + d }, tolerance).vraisPositifs
        }
        guard let meilleur = scores.max(), meilleur > 0, let premier = scores.firstIndex(of: meilleur) else {
            return ResultatCalage(decalage: 0, appariements: 0, couverture: 0, appariementsConcurrent: 0)
        }
        // Plateau du meilleur score autour du premier maximum : on retient son
        // centre (tout décalage du plateau explique autant de taps ; le délai
        // réel de saisie n'est connu qu'à cette largeur près).
        var dernier = premier
        while dernier + 1 < scores.count, scores[dernier + 1] == meilleur { dernier += 1 }
        let decalage = (candidats[premier] + candidats[dernier]) / 2

        let concurrent = zip(candidats, scores)
            .filter { abs($0.0 - decalage) > 2 * delaiMax }
            .map(\.1)
            .max() ?? 0

        return ResultatCalage(
            decalage: decalage,
            appariements: meilleur,
            couverture: Double(meilleur) / Double(taps.count),
            appariementsConcurrent: concurrent)
    }

    /// Alignement corrigé par un calage automatique.
    public static func appliquer(_ resultat: ResultatCalage, a alignement: AlignementVideo) -> AlignementVideo {
        var corrige = alignement
        corrige.decalageSecondes += resultat.decalage
        return corrige
    }
}

// MARK: - Estimation de la fenêtre de clip

public enum EstimationFenetre {

    /// Fenêtre qui couvre entièrement ~90 % des échanges appariés : chaque tap
    /// est rattaché à l'échange qui finit juste avant lui (≤ `delaiMax`).
    /// nil avec moins de `minimumAppariements` paires.
    public static func estimer(
        taps: [Double],
        echanges: [EchangeDetecte],
        delaiMax: Double = 8,
        marge: Double = 1,
        apres: Double = 1.5,
        minimumAppariements: Int = 5
    ) -> FenetreClip? {
        let tries = echanges.sorted { $0.fin < $1.fin }
        var reculs: [Double] = []
        for tap in taps {
            guard let echange = tries.last(where: { $0.fin <= tap }), tap - echange.fin <= delaiMax else { continue }
            reculs.append(tap - echange.debut)
        }
        guard reculs.count >= minimumAppariements else { return nil }
        let avant = DetecteurEchanges.quantile(reculs, 0.9) + marge
        return FenetreClip(avant: (avant * 10).rounded(.up) / 10, apres: apres)
    }
}
