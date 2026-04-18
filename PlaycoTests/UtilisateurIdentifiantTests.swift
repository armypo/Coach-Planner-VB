//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Testing
import Foundation
import SwiftData
@testable import Playco

@Suite("Utilisateur — identifiant prenom.nom.XXXX + mot de passe athlète")
struct UtilisateurIdentifiantTests {

    private func contexteEnMemoire() throws -> ModelContext {
        let schema = Schema([Utilisateur.self, JoueurEquipe.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    // MARK: - Identifiant format prenom.nom.XXXX

    @Test("Format identifiant respecte la regex ^[a-z.-]+\\.\\d{4}$")
    func formatIdentifiantXXXX() throws {
        let context = try contexteEnMemoire()
        for _ in 0..<100 {
            let id = Utilisateur.genererIdentifiantUnique(
                prenom: "Jean", nom: "Dupont", context: context
            )
            #expect(
                id.range(of: #"^[a-z.-]+\.\d{4}$"#, options: .regularExpression) != nil,
                "Identifiant « \(id) » ne matche pas le format prenom.nom.XXXX"
            )
        }
    }

    @Test("10 créations consécutives Jean Dupont produisent 10 identifiants distincts")
    func collisionResolueParExclusions() throws {
        let context = try contexteEnMemoire()
        var idsUniques: Set<String> = []
        for _ in 0..<10 {
            let id = Utilisateur.genererIdentifiantUnique(
                prenom: "Jean", nom: "Dupont",
                context: context, exclusions: idsUniques
            )
            #expect(!idsUniques.contains(id), "Collision détectée sur « \(id) »")
            idsUniques.insert(id)
            let user = Utilisateur(
                identifiant: id, motDePasseHash: "x",
                prenom: "Jean", nom: "Dupont", role: .etudiant
            )
            context.insert(user)
        }
        #expect(idsUniques.count == 10)
    }

    @Test("Prénom et nom vides → fallback user.XXXX")
    func fallbackPrenomNomVides() throws {
        let context = try contexteEnMemoire()
        let id = Utilisateur.genererIdentifiantUnique(
            prenom: "", nom: "", context: context
        )
        #expect(id.hasPrefix("user."))
        #expect(id.range(of: #"^user\.\d{4}$"#, options: .regularExpression) != nil)
    }

    @Test("Accents et espaces sont foldés en ASCII kebab-case")
    func accentsEtEspacesNormalises() throws {
        let context = try contexteEnMemoire()
        let id = Utilisateur.genererIdentifiantUnique(
            prenom: "José María", nom: "Côté", context: context
        )
        #expect(id.hasPrefix("jose-maria.cote."),
                "Identifiant « \(id) » ne démarre pas par « jose-maria.cote. »")
    }

    // MARK: - Mot de passe ABCDE_23

    @Test("Format mdp athlète respecte la regex ^[A-Z]{5}_[0-9]{2}$")
    func formatMotDePasseAthlete() {
        for _ in 0..<100 {
            let mdp = Utilisateur.genererMotDePasseAthlete()
            #expect(
                mdp.range(of: #"^[A-Z]{5}_[0-9]{2}$"#, options: .regularExpression) != nil,
                "Mot de passe « \(mdp) » ne matche pas le format LLLLL_DD"
            )
        }
    }

    @Test("1000 mdp athlète ne contiennent jamais I/L/O ni 0/1 (caractères ambigus)")
    func motDePasseSansCaracteresAmbigus() {
        let caracteresInterdits: Set<Character> = ["I", "L", "O", "0", "1"]
        for _ in 0..<1000 {
            let mdp = Utilisateur.genererMotDePasseAthlete()
            for caractere in mdp {
                #expect(!caracteresInterdits.contains(caractere),
                        "Caractère ambigu « \(caractere) » trouvé dans « \(mdp) »")
            }
        }
    }

    // MARK: - Rôle assistantCoach

    @Test("Le rôle .assistantCoach existe et a les métadonnées attendues")
    func roleAssistantCoachExiste() {
        #expect(RoleUtilisateur.allCases.contains(.assistantCoach))
        #expect(RoleUtilisateur.assistantCoach.label == "Coach assistant")
        #expect(RoleUtilisateur.assistantCoach.icone == "person.badge.shield.checkmark")
        #expect(RoleUtilisateur.assistantCoach.couleurHex == "#4A8AF4")
    }

    @Test("Un assistantCoach hérite des permissions coach (peutGererEquipe, peutEvaluer, …)")
    func assistantCoachHeriteDesPermissions() {
        let role: RoleUtilisateur = .assistantCoach
        #expect(role.peutModifierSeances)
        #expect(role.peutModifierStrategies)
        #expect(role.peutGererEquipe)
        #expect(role.peutEvaluer)
        #expect(role.peutGererProgrammes)
        #expect(role.peutExporter)
        #expect(role.peutCreerComptes)
    }
}
