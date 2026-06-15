//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Tests Sign in with Apple (v2.0.1) : connexion par appleUserID et
//  rattachement d'un compte existant (qui efface les secrets).
//

import Testing
import Foundation
import SwiftData
@testable import Playco

@Suite("AuthService — Sign in with Apple", .serialized)
struct AuthServiceAppleTests {

    private func creerContexteEnMemoire() throws -> ModelContext {
        let schema = Schema([Utilisateur.self, JoueurEquipe.self, Equipe.self,
                             Etablissement.self, ProfilCoach.self, AssistantCoach.self,
                             CredentialAthlete.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    @MainActor
    private func creerAuthIsole() -> AuthService {
        KeychainService.supprimer(cle: SessionManager.cleKeychain)
        KeychainService.supprimer(cle: AuthService.cleEtatVerrouillage)
        let suite = UserDefaults(suiteName: "playco-test-\(UUID().uuidString)")!
        return AuthService(userDefaults: suite)
    }

    // MARK: - connexionApple

    @Test("connexionApple connecte un compte lié par appleUserID")
    @MainActor
    func connexionAppleMatch() throws {
        let auth = creerAuthIsole()
        let context = try creerContexteEnMemoire()

        let user = Utilisateur(identifiant: "coach.x", motDePasseHash: "", prenom: "Coach", nom: "X", role: .coach)
        user.appleUserID = "001999.appleid"
        context.insert(user)
        try context.save()

        let etat = auth.connexionApple(appleUserID: "001999.appleid", prenom: "", nom: "", context: context)

        guard case .connecte = etat else {
            Issue.record("Devrait être .connecte")
            return
        }
        #expect(auth.utilisateurConnecte?.id == user.id)
    }

    @Test("connexionApple → compteInconnu si aucun appleUserID ne correspond")
    @MainActor
    func connexionAppleInconnu() throws {
        let auth = creerAuthIsole()
        let context = try creerContexteEnMemoire()

        let etat = auth.connexionApple(appleUserID: "999.inconnu", prenom: "Jean", nom: "Neuf", context: context)

        guard case .compteInconnu(let id, let prenom, _) = etat else {
            Issue.record("Devrait être .compteInconnu")
            return
        }
        #expect(id == "999.inconnu")
        #expect(prenom == "Jean")
        #expect(auth.utilisateurConnecte == nil)
    }

    // MARK: - lierCompteExistant

    @Test("lierCompteExistant rattache l'Apple ID et EFFACE les secrets")
    @MainActor
    func lierCompteEffaceSecrets() throws {
        let auth = creerAuthIsole()
        let context = try creerContexteEnMemoire()

        // Compte legacy avec mot de passe PBKDF2.
        let sel = auth.genererSel()
        let hash = auth.hashMotDePasse("MotDePasseSolide12", sel: sel)
        let user = Utilisateur(identifiant: "legacy.coach", motDePasseHash: hash, prenom: "Leg", nom: "Acy", role: .coach)
        user.sel = sel
        user.iterations = AuthService.iterationsParDefaut
        context.insert(user)
        try context.save()

        let erreur = auth.lierCompteExistant(appleUserID: "002.newapple",
                                             identifiant: "legacy.coach",
                                             motDePasse: "MotDePasseSolide12",
                                             context: context)

        #expect(erreur == nil, "Le rattachement doit réussir")
        #expect(user.appleUserID == "002.newapple")
        #expect(user.motDePasseHash == "", "Le hash doit être effacé après rattachement")
        #expect(user.sel == nil, "Le sel doit être effacé")
        #expect(auth.utilisateurConnecte?.id == user.id)
    }

    @Test("lierCompteExistant échoue avec un mauvais mot de passe")
    @MainActor
    func lierCompteMauvaisMdp() throws {
        let auth = creerAuthIsole()
        let context = try creerContexteEnMemoire()

        let sel = auth.genererSel()
        let hash = auth.hashMotDePasse("MotDePasseSolide12", sel: sel)
        let user = Utilisateur(identifiant: "legacy.coach", motDePasseHash: hash, prenom: "Leg", nom: "Acy", role: .coach)
        user.sel = sel
        user.iterations = AuthService.iterationsParDefaut
        context.insert(user)
        try context.save()

        let erreur = auth.lierCompteExistant(appleUserID: "002.newapple",
                                             identifiant: "legacy.coach",
                                             motDePasse: "MAUVAIS_MDP",
                                             context: context)

        #expect(erreur != nil, "Doit échouer avec un mauvais mot de passe")
        #expect(user.appleUserID == "", "Aucun rattachement sur échec")
        #expect(user.motDePasseHash == hash, "Le hash ne doit pas être effacé sur échec")
    }
}
