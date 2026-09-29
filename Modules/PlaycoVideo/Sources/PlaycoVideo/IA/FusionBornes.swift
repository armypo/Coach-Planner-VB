//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Fusion image + son : l'activité visuelle trouve les échanges, le sifflet
//  de l'arbitre en donne la fin exacte (à la trame audio près, ~12 ms), là où
//  le mouvement retombe progressivement (joueurs qui se replacent).
//

import Foundation

public enum FusionBornes {

    /// Recale la fin de chaque échange sur le DÉBUT du coup de sifflet le plus
    /// proche (± `tolerance`). Chaque sifflet sert au plus une fois ; un
    /// sifflet antérieur au début de l'échange est ignoré ; un échange sans
    /// sifflet proche garde sa fin.
    public static func affiner(
        _ echanges: [EchangeDetecte],
        sifflets: [SiffletDetecte],
        tolerance: Double = 1.5
    ) -> [EchangeDetecte] {
        var disponibles = sifflets.sorted { $0.debut < $1.debut }
        return echanges.sorted { $0.debut < $1.debut }.map { echange in
            var meilleur: Int?
            for (index, sifflet) in disponibles.enumerated()
            where sifflet.debut > echange.debut && abs(sifflet.debut - echange.fin) <= tolerance {
                if let actuel = meilleur,
                   abs(disponibles[actuel].debut - echange.fin) <= abs(sifflet.debut - echange.fin) { continue }
                meilleur = index
            }
            guard let index = meilleur else { return echange }
            var affine = echange
            affine.fin = disponibles.remove(at: index).debut
            return affine
        }
    }
}
