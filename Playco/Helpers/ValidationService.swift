//  Playco
//  Copyright (c) 2025 Christopher Dionne. Tous droits reserves.
//

import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "ValidationService")

/// P2-03 — Service de validation d'unicité (SwiftData ne supporte pas @Attribute(.unique) sur Int)
enum ValidationService {

    /// Vérifie qu'un numéro de joueur n'est pas déjà utilisé
    /// - Returns: true si le numéro est disponible
    static func numeroDisponible(_ numero: Int, pourJoueur joueurId: UUID? = nil,
                                  dans context: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<JoueurEquipe>(
            predicate: #Predicate<JoueurEquipe> { $0.numero == numero }
        )
        descriptor.fetchLimit = 1

        do {
            let existants = try context.fetch(descriptor)
            // Si aucun résultat → disponible
            guard let existant = existants.first else { return true }
            // Si c'est le même joueur → disponible (on modifie le joueur existant)
            return existant.id == joueurId
        } catch {
            logger.warning("Échec vérification unicité numéro: \(error.localizedDescription)")
            return true // En cas d'erreur, on laisse passer
        }
    }

    /// Vérifie qu'une formation personnalisée n'existe pas déjà pour cette clé
    /// - Returns: la formation existante si trouvée, nil sinon
    static func formationExistante(type: String, rotation: Int, mode: String,
                                    dans context: ModelContext) -> FormationPersonnalisee? {
        let descriptor = FetchDescriptor<FormationPersonnalisee>(
            predicate: #Predicate<FormationPersonnalisee> {
                $0.formationTypeRaw == type &&
                $0.rotation == rotation &&
                $0.modeRaw == mode
            }
        )

        do {
            return try context.fetch(descriptor).first
        } catch {
            logger.warning("Échec recherche formation: \(error.localizedDescription)")
            return nil
        }
    }
}
