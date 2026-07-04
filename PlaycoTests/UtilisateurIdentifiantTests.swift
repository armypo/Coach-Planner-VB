//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  Tests des générateurs `genererIdentifiantUnique` (format prenom.nom.XXXX)
//  et des codes d'invitation. Les tests de `genererMotDePasseAthlete` et de
//  `RoleLogin` ont été retirés avec le flux mot de passe (SIWA strict v2.1).
//

import Testing
import Foundation
import SwiftData
@testable import Playco

@Suite("Utilisateur — générateurs identifiant + code d'invitation")
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
                identifiant: id, motDePasseHash: "",
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

    @Test("identifiantDisponible : faux si l'identifiant est déjà pris")
    func identifiantDisponible() throws {
        let container = try nouveauContainer()
        let user = Utilisateur(identifiant: "pris.deja.0001", motDePasseHash: "",
                               prenom: "Pris", nom: "Deja", role: .etudiant)
        container.mainContext.insert(user)
        try container.mainContext.save()

        #expect(!Utilisateur.identifiantDisponible("pris.deja.0001", context: container.mainContext))
        #expect(Utilisateur.identifiantDisponible("libre.encore.0002", context: container.mainContext))
    }

    @Test("Code d'invitation unique : 6 caractères sans I/O/1/0")
    func codeInvitationUnique() throws {
        let container = try nouveauContainer()
        let interdits = Set("IO10")
        for _ in 0..<50 {
            let code = Utilisateur.genererCodeUniqueInvitation(context: container.mainContext)
            #expect(code.count == 6)
            for char in code {
                #expect(!interdits.contains(char), "Le code ne doit pas contenir \(char)")
            }
        }
    }

    @Test("Rôle .assistantCoach existe et a label/icone définis")
    func roleAssistantCoach() {
        #expect(RoleUtilisateur.allCases.contains(.assistantCoach))
        #expect(RoleUtilisateur.assistantCoach.label == "Coach assistant")
        #expect(!RoleUtilisateur.assistantCoach.icone.isEmpty)
    }
}
