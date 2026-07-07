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

    /// Composition persistante : le 6 de départ (et le libéro) du dernier match
    /// JOUÉ de l'équipe (revue 2.3.2 : jamais un match futur), validé contre
    /// l'effectif fourni (revue : pas d'UUID fantôme ni de joueur indisponible).
    /// `avant` exclut le match en cours d'édition.
    static func derniereComposition(parmi seances: [Seance], codeEquipe: String,
                                    avant matchCourant: UUID,
                                    joueursValides: Set<UUID>,
                                    maintenant: Date = Date()) -> (partants: [PartantMatch], liberoID: String)? {
        let source = seances
            .filter { $0.estMatch && !$0.estArchivee && $0.id != matchCourant }
            .filter { $0.codeEquipe == codeEquipe || $0.codeEquipe.isEmpty }
            .filter { $0.date <= maintenant }
            .filter { !$0.partants.isEmpty }
            .max(by: { $0.date < $1.date })
        guard let source else { return nil }

        let partants = source.partants.filter { joueursValides.contains($0.joueurID) }
        guard !partants.isEmpty else { return nil }
        let libero = UUID(uuidString: source.liberoID).flatMap { joueursValides.contains($0) ? source.liberoID : nil } ?? ""
        return (partants, libero)
    }
}
