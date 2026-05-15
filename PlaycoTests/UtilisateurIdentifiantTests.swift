//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  Tests des générateurs `genererIdentifiantUnique` (format prenom.nom.XXXX)
//  et `genererMotDePasseAthlete` (format LLLLL_DD).
//

import Testing
import Foundation
import SwiftData
@testable import Playco

@Suite("Utilisateur — générateurs identifiant + mdp athlète")
@MainActor
struct UtilisateurIdentifiantTests {

    /// Container en mémoire isolé par test
    private func nouveauContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Utilisateur.self, AssistantCoach.self, CredentialAthlete.self,
            configurations: config
        )
    }

    @Test("Identifiant : format `prenom.nom.XXXX` (4 chiffres)")
    func formatIdentifiant() throws {
        let container = try nouveauContainer()
        let regex = #"^[a-z.-]+\.\d{4}$"#
        for _ in 0..<50 {
            let id = Utilisateur.genererIdentifiantUnique(
                prenom: "Jean", nom: "Dupont", context: container.mainContext
            )
            #expect(id.range(of: regex, options: .regularExpression) != nil,
                    "Identifiant \(id) ne matche pas \(regex)")
        }
    }

    @Test("Identifiant : résolution de collisions sur 10 utilisateurs identiques")
    func collisionsResolues() throws {
        let container = try nouveauContainer()
        var ids: Set<String> = []
        for _ in 0..<10 {
            let id = Utilisateur.genererIdentifiantUnique(
                prenom: "Jean", nom: "Dupont",
                context: container.mainContext, exclusions: ids
            )
            #expect(!ids.contains(id), "Collision pour \(id)")
            ids.insert(id)
            let user = Utilisateur(
                identifiant: id, motDePasseHash: "x",
                prenom: "Jean", nom: "Dupont", role: .etudiant
            )
            container.mainContext.insert(user)
        }
        #expect(ids.count == 10)
    }

    @Test("Identifiant : prénom+nom vides → fallback `user.XXXX`")
    func fallbackUserPrenomNomVides() throws {
        let container = try nouveauContainer()
        let id = Utilisateur.genererIdentifiantUnique(
            prenom: "", nom: "", context: container.mainContext
        )
        #expect(id.hasPrefix("user."), "Attendu prefix 'user.', reçu \(id)")
    }

    @Test("Mdp athlète : format `LLLLL_DD`")
    func formatMotDePasse() {
        let regex = #"^[A-Z]{5}_[0-9]{2}$"#
        for _ in 0..<100 {
            let mdp = Utilisateur.genererMotDePasseAthlete()
            #expect(mdp.range(of: regex, options: .regularExpression) != nil,
                    "Mdp \(mdp) ne matche pas \(regex)")
        }
    }

    @Test("Mdp athlète : aucun caractère ambigu (I/L/O/0/1)")
    func sansCaracteresAmbigus() {
        let ambigus: Set<Character> = ["I", "L", "O", "0", "1"]
        for _ in 0..<500 {
            let mdp = Utilisateur.genererMotDePasseAthlete()
            for c in mdp where ambigus.contains(c) {
                Issue.record("Caractère ambigu \(c) trouvé dans \(mdp)")
            }
        }
    }

    @Test("Rôle .assistantCoach existe et a label/icone définis")
    func roleAssistantCoach() {
        #expect(RoleUtilisateur.allCases.contains(.assistantCoach))
        #expect(RoleUtilisateur.assistantCoach.label == "Coach assistant")
        #expect(!RoleUtilisateur.assistantCoach.icone.isEmpty)
    }

    @Test("RoleLogin mapping vers RoleUtilisateur")
    func roleLoginMapping() {
        #expect(RoleLogin.coach.rolesValides.contains(.coach))
        #expect(RoleLogin.coach.rolesValides.contains(.admin))
        #expect(RoleLogin.assistant.rolesValides == [.assistantCoach])
        #expect(RoleLogin.athlete.rolesValides == [.etudiant])
        // Vérifier qu'aucun rôle ne chevauche deux tabs
        #expect(!RoleLogin.coach.rolesValides.contains(.etudiant))
        #expect(!RoleLogin.athlete.rolesValides.contains(.coach))
    }
}
