//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  2.3.2 — Fabrique de matchs : match éclair (2 champs), promotion d'un
//  MatchCalendrier du wizard en vrai match, et composition persistante
//  (le 6 de départ du dernier match pré-remplit le suivant).
//  Logique pure et testable — les vues ne font que l'appeler.

import Foundation

enum FabriqueMatch {

    /// Match éclair : un match hors calendrier en 2 champs (adversaire + qui
    /// sert), daté de maintenant. L'appelant insère dans le contexte.
    static func matchEclair(adversaire: String, nousServons: Bool, codeEquipe: String) -> Seance {
        let nom = adversaire.trimmingCharacters(in: .whitespaces)
        let match = Seance(nom: nom.isEmpty ? "Match éclair" : "vs \(nom)", typeSeance: .match)
        match.adversaire = nom
        match.nousServonsEnPremier = nousServons
        match.codeEquipe = codeEquipe
        return match
    }

    /// Promotion d'un MatchCalendrier (wizard) en Seance de type match.
    /// La trace `matchCalendrierID` (CloudKit-safe) empêche la double promotion.
    static func promouvoir(_ mc: MatchCalendrier, codeEquipe: String) -> Seance {
        let match = Seance(nom: mc.adversaire.isEmpty ? "Match" : "vs \(mc.adversaire)",
                           date: mc.date, typeSeance: .match)
        match.adversaire = mc.adversaire
        match.lieu = mc.lieu
        match.codeEquipe = codeEquipe.isEmpty ? mc.codeEquipe : codeEquipe
        match.matchCalendrierID = mc.id.uuidString
        return match
    }

    /// Vrai si ce MatchCalendrier a déjà été promu en match.
    static func dejaPromu(_ mc: MatchCalendrier, parmi seances: [Seance]) -> Bool {
        let cible = mc.id.uuidString
        return seances.contains { $0.matchCalendrierID == cible }
    }

    /// Composition persistante : le 6 de départ (et le libéro) du match le plus
    /// récent de l'équipe qui en a un — l'état durable de l'équipe, pas un
    /// réglage par match. `avant` exclut le match en cours d'édition.
    static func derniereComposition(parmi seances: [Seance], codeEquipe: String,
                                    avant matchCourant: UUID) -> (partants: [PartantMatch], liberoID: String)? {
        let source = seances
            .filter { $0.estMatch && !$0.estArchivee && $0.codeEquipe == codeEquipe && $0.id != matchCourant }
            .filter { !$0.partants.isEmpty }
            .max(by: { $0.date < $1.date })
        guard let source else { return nil }
        return (source.partants, source.liberoID)
    }
}
