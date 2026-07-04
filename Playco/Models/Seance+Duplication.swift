//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftData

extension Seance {
    /// Duplique une séance avec ses exercices (terrain, étapes, notes).
    ///
    /// Copie `codeEquipe` : sans lui, la copie aurait un code vide et
    /// apparaîtrait dans TOUTES les équipes (`filtreEquipe` inclut les
    /// codes vides pour compat legacy).
    /// Volontairement minimal : date/lieu/adversaire/type ne sont pas copiés —
    /// une copie est une nouvelle pratique à planifier.
    static func dupliquer(_ source: Seance, dans context: ModelContext) -> Seance {
        let nouvelle = Seance(nom: "\(source.nom) (copie)")
        nouvelle.codeEquipe = source.codeEquipe
        context.insert(nouvelle)

        for ex in (source.exercices ?? []).sorted(by: { $0.ordre < $1.ordre }) {
            let copie = Exercice(nom: ex.nom, ordre: ex.ordre, duree: ex.duree)
            copie.seance = nouvelle
            copie.notes = ex.notes
            copierTerrain(de: ex, vers: copie) // P1-01 (inclut etapesData)
            context.insert(copie)
            if nouvelle.exercices == nil { nouvelle.exercices = [] }
            nouvelle.exercices?.append(copie)
        }
        return nouvelle
    }
}
