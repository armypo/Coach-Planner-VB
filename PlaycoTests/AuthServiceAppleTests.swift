//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Tests Sign in with Apple (SIWA strict v2.1) : connexion par appleUserID.
//  Le rattachement par mot de passe (lierCompteExistant) a été retiré — la
//  jonction cross-Apple-ID passe désormais par le code d'invitation
//  (voir RejoindreEquipeTests / reclamerMembreLocal).
//

import Testing
import Foundation
import SwiftData
@testable import Playco

/// Tests sérialisés : le Keychain de session est un store global iOS partagé.
@Suite("AuthService — Sign in with Apple", .serialized)
@MainActor
struct AuthServiceAppleTests {

    private func creerContexteEnMemoire() throws -> ModelContext {
        // Schéma avec fermeture de relations complète (Equipe référence aussi
        // CreneauRecurrent + MatchCalendrier).
        let schema = Schema([Utilisateur.self, JoueurEquipe.self, Equipe.self,
                             Etablissement.self, ProfilCoach.self, AssistantCoach.self,
                             CreneauRecurrent.self, MatchCalendrier.self,
                             CredentialAthlete.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func creerAuthIsole() -> AuthService {
        KeychainService.supprimer(cle: SessionManager.cleKeychain)
        let suite = UserDefaults(suiteName: "playco-test-\(UUID().uuidString)")!
        return AuthService(userDefaults: suite)
    }

    // MARK: - connexionApple

    @Test("connexionApple — appleUserID connu → .connecte + session sauvegardée")
    func connexionAppleMatch() throws {
        // Arrange
        let auth = creerAuthIsole()
        let context = try creerContexteEnMemoire()
        let user = Utilisateur(identifiant: "coach.x", motDePasseHash: "", prenom: "Coach", nom: "X", role: .coach)
        user.appleUserID = "001999.appleid"
        context.insert(user)
        try context.save()

        // Act
        let etat = auth.connexionApple(appleUserID: "001999.appleid", prenom: "", nom: "", context: context)

        // Assert
        guard case .connecte = etat else {
            Issue.record("Devrait être .connecte")
            return
        }
        #expect(auth.utilisateurConnecte?.id == user.id)
        #expect(auth.idSessionSauvegardee == user.id.uuidString,
                "La session doit être persistée dans le Keychain")
        #expect(user.sessionCreeeLe != nil,
                "Le compteur d'expiration 30 jours doit être (re)démarré à la connexion")

        // Cleanup
        auth.deconnexion()
    }

    @Test("connexionApple — appleUserID inconnu → .compteInconnu (routage jonction)")
    func connexionAppleInconnu() throws {
        // Arrange
        let auth = creerAuthIsole()
        let context = try creerContexteEnMemoire()

        // Act
        let etat = auth.connexionApple(appleUserID: "999.inconnu", prenom: "Jean", nom: "Neuf", context: context)

        // Assert
        guard case .compteInconnu(let id, let prenom, _) = etat else {
            Issue.record("Devrait être .compteInconnu")
            return
        }
        #expect(id == "999.inconnu")
        #expect(prenom == "Jean")
        #expect(auth.utilisateurConnecte == nil)
    }

    @Test("connexionApple — appleUserID vide ou blanc → .compteInconnu")
    func connexionAppleIDVide() throws {
        // Arrange
        let auth = creerAuthIsole()
        let context = try creerContexteEnMemoire()

        // Act
        let etatVide = auth.connexionApple(appleUserID: "", prenom: "A", nom: "B", context: context)
        let etatBlanc = auth.connexionApple(appleUserID: "   ", prenom: "A", nom: "B", context: context)

        // Assert
        guard case .compteInconnu = etatVide else {
            Issue.record("ID vide devrait donner .compteInconnu")
            return
        }
        guard case .compteInconnu = etatBlanc else {
            Issue.record("ID blanc (espaces) devrait donner .compteInconnu")
            return
        }
        #expect(auth.utilisateurConnecte == nil)
    }

    @Test("connexionApple — utilisateur inactif → .compteInconnu (compte révoqué)")
    func connexionAppleUtilisateurInactif() throws {
        // Arrange
        let auth = creerAuthIsole()
        let context = try creerContexteEnMemoire()
        let user = Utilisateur(identifiant: "ex.membre", motDePasseHash: "", prenom: "Ex", nom: "Membre", role: .etudiant)
        user.appleUserID = "003.revoque"
        user.estActif = false
        context.insert(user)
        try context.save()

        // Act
        let etat = auth.connexionApple(appleUserID: "003.revoque", prenom: "", nom: "", context: context)

        // Assert
        guard case .compteInconnu = etat else {
            Issue.record("Un compte désactivé ne doit pas se connecter — attendu .compteInconnu")
            return
        }
        #expect(auth.utilisateurConnecte == nil)
        #expect(auth.idSessionSauvegardee == nil, "Aucune session ne doit être créée pour un compte inactif")
    }
}
