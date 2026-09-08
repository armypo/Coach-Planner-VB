//
//  MigrationRoles.swift
//  Playco
//
//  Migration one-shot héritée de v2.0 : reclasser les anciens utilisateurs
//  marqués `.coach` qui étaient en réalité des assistants. Extraite
//  d'AbonnementService lors du retrait du paywall (pivot coach-first) —
//  indépendante de la monétisation, elle doit survivre à sa suppression.
//

import Foundation
import SwiftData
import os

enum MigrationRoles {

    private static let logger = Logger(subsystem: "com.origotech.playco", category: "MigrationRoles")

    /// Clé UserDefaults idempotente (héritée de v2.0 — ne pas renommer,
    /// des appareils TestFlight l'ont déjà posée).
    static let cleMigrationRolesDone = "playco_abo_migration_roles_done"

    /// Reclasse les anciens utilisateurs marqués `.coach` présents dans
    /// AssistantCoach vers `.assistantCoach`. À appeler une fois au lancement
    /// (flag UserDefaults idempotent).
    static func migrerAssistantsVersNouveauRole(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: cleMigrationRolesDone) else {
            return
        }

        let descAssistants = FetchDescriptor<AssistantCoach>()
        let descCoaches = FetchDescriptor<Utilisateur>(
            predicate: #Predicate { $0.roleRaw == "coach" }
        )
        let assistants = (try? context.fetch(descAssistants)) ?? []
        let coaches = (try? context.fetch(descCoaches)) ?? []
        let idsAssistants = Set(assistants.map { $0.identifiant })

        var nbReclasses = 0
        for user in coaches where idsAssistants.contains(user.identifiant) {
            user.role = .assistantCoach
            nbReclasses += 1
        }

        if nbReclasses > 0 {
            do {
                try context.save()
                logger.info("Migration rôles : \(nbReclasses) utilisateurs reclassés .coach → .assistantCoach")
            } catch {
                logger.error("Migration rôles : échec sauvegarde \(error.localizedDescription)")
                return  // ne pas poser le flag si l'échec
            }
        }

        UserDefaults.standard.set(true, forKey: cleMigrationRolesDone)
    }
}
