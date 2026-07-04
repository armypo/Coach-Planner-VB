//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Tests AuthService (SIWA strict v2.1) : restauration de session,
//  vérification d'état au foreground et déconnexion.
//  Les tests de connexion par mot de passe / verrouillage / création de
//  compte / migration de hash ont été retirés avec le flux correspondant —
//  Sign in with Apple est désormais l'unique méthode d'authentification.
//

import Testing
import Foundation
import SwiftData
@testable import Playco

/// Tests sérialisés : KeychainService est un store global iOS que nous ne pouvons
/// pas isoler par test. L'exécution séquentielle évite les collisions entre tests
/// qui écrivent/lisent la clé de session dans le Keychain.
@Suite("AuthService — session SIWA", .serialized)
@MainActor
struct AuthServiceTests {

    // MARK: - Helpers

    private func creerContexteEnMemoire() throws -> ModelContext {
        // Schéma avec fermeture de relations complète (Equipe référence aussi
        // CreneauRecurrent + MatchCalendrier).
        let schema = Schema([Utilisateur.self, JoueurEquipe.self, Equipe.self,
                             Etablissement.self, ProfilCoach.self, AssistantCoach.self,
                             CreneauRecurrent.self, MatchCalendrier.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, allowsSave: true, groupContainer: .none, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    /// Nettoie la session Keychain globale (le Keychain iOS n'est pas isolable
    /// par suite, d'où le nettoyage explicite avant chaque test).
    private func nettoyerKeychainGlobal() {
        KeychainService.supprimer(cle: SessionManager.cleKeychain)
    }

    /// AuthService avec UserDefaults isolé — conservé pour la migration
    /// session legacy UserDefaults → Keychain.
    private func creerAuthIsole() -> AuthService {
        nettoyerKeychainGlobal()
        let suite = UserDefaults(suiteName: "playco-test-\(UUID().uuidString)")!
        return AuthService(userDefaults: suite)
    }

    /// Crée un AuthService isolé ET retourne aussi la suite UserDefaults
    /// pour les tests qui doivent écrire dans le même store (migration legacy).
    private func creerAuthAvecSuite() -> (AuthService, UserDefaults) {
        nettoyerKeychainGlobal()
        let suite = UserDefaults(suiteName: "playco-test-\(UUID().uuidString)")!
        return (AuthService(userDefaults: suite), suite)
    }

    /// Insère un utilisateur actif lié à un Apple ID (sans secret — SIWA strict).
    private func insererUtilisateurApple(identifiant: String,
                                         appleUserID: String,
                                         role: RoleUtilisateur = .etudiant,
                                         context: ModelContext) throws -> Utilisateur {
        let user = Utilisateur(identifiant: identifiant, motDePasseHash: "",
                               prenom: "Test", nom: "User", role: role)
        user.appleUserID = appleUserID
        context.insert(user)
        try context.save()
        return user
    }

    // MARK: - Restauration de session

    @Test("restaurerSession — aucune session sauvegardée → no-op")
    func restaurerSessionSansSession() throws {
        // Arrange
        let auth = creerAuthIsole()
        let context = try creerContexteEnMemoire()

        // Act
        auth.restaurerSession(context: context)

        // Assert
        #expect(!auth.estConnecte, "Sans session sauvegardée, personne ne doit être connecté")
        #expect(auth.utilisateurConnecte == nil)
    }

    @Test("restaurerSession — session Keychain valide → utilisateur connecté")
    func restaurerSessionKeychainValide() throws {
        // Arrange
        let auth = creerAuthIsole()
        let context = try creerContexteEnMemoire()
        let user = try insererUtilisateurApple(identifiant: "session.keychain",
                                               appleUserID: "001.session", context: context)
        user.sessionCreeeLe = Date()
        try context.save()
        KeychainService.sauvegarder(cle: SessionManager.cleKeychain, valeur: user.id.uuidString)

        // Act
        auth.restaurerSession(context: context)

        // Assert
        #expect(auth.estConnecte)
        #expect(auth.utilisateurConnecte?.id == user.id)

        // Cleanup
        nettoyerKeychainGlobal()
    }

    @Test("restaurerSession — migration session legacy UserDefaults → Keychain")
    func restaurerSessionMigrationLegacy() throws {
        // Arrange
        let (auth, suite) = creerAuthAvecSuite()
        let context = try creerContexteEnMemoire()
        let user = try insererUtilisateurApple(identifiant: "session.legacy",
                                               appleUserID: "002.legacy", context: context)
        user.sessionCreeeLe = Date()
        try context.save()
        // Simuler une session legacy dans la suite injectée (non .standard !)
        suite.set(user.id.uuidString, forKey: "utilisateurConnecteID")

        // Act
        auth.restaurerSession(context: context)

        // Assert
        #expect(auth.estConnecte)
        #expect(auth.utilisateurConnecte?.id == user.id)
        #expect(auth.idSessionSauvegardee == user.id.uuidString,
                "La session legacy doit avoir été migrée vers le Keychain")
        #expect(suite.string(forKey: "utilisateurConnecteID") == nil,
                "L'entrée UserDefaults legacy doit être purgée après migration")

        // Cleanup
        suite.removeObject(forKey: "utilisateurConnecteID")
        nettoyerKeychainGlobal()
    }

    @Test("restaurerSession — utilisateur inactif → session supprimée")
    func restaurerSessionUtilisateurInactif() throws {
        // Arrange
        let auth = creerAuthIsole()
        let context = try creerContexteEnMemoire()
        let user = try insererUtilisateurApple(identifiant: "ex.athlete",
                                               appleUserID: "003.inactif", context: context)
        user.estActif = false
        try context.save()
        KeychainService.sauvegarder(cle: SessionManager.cleKeychain, valeur: user.id.uuidString)

        // Act
        auth.restaurerSession(context: context)

        // Assert
        #expect(!auth.estConnecte, "Un compte désactivé ne doit pas être restauré")
        #expect(auth.idSessionSauvegardee == nil, "La session orpheline doit être supprimée")
    }

    @Test("restaurerSession — session expirée (>30 jours) → erreur + déconnexion")
    func restaurerSessionExpiree() throws {
        // Arrange
        let auth = creerAuthIsole()
        let context = try creerContexteEnMemoire()
        let user = try insererUtilisateurApple(identifiant: "session.vieille",
                                               appleUserID: "004.expiree", context: context)
        user.sessionCreeeLe = Date(timeIntervalSinceNow: -SessionManager.dureeMaxSecondes - 3600)
        try context.save()
        KeychainService.sauvegarder(cle: SessionManager.cleKeychain, valeur: user.id.uuidString)

        // Act
        auth.restaurerSession(context: context)

        // Assert
        #expect(!auth.estConnecte, "Une session > 30 jours ne doit pas être restaurée")
        #expect(auth.erreur?.contains("expirée") == true)
        #expect(auth.idSessionSauvegardee == nil, "La session expirée doit être supprimée")
    }

    @Test("restaurerSession — amorce sessionCreeeLe pour les comptes migrés")
    func restaurerSessionAmorceCompteur() throws {
        // Arrange : compte migré = sessionCreeeLe absent (pré-versions)
        let auth = creerAuthIsole()
        let context = try creerContexteEnMemoire()
        let user = try insererUtilisateurApple(identifiant: "compte.migre",
                                               appleUserID: "005.migre", context: context)
        #expect(user.sessionCreeeLe == nil)
        KeychainService.sauvegarder(cle: SessionManager.cleKeychain, valeur: user.id.uuidString)

        // Act
        auth.restaurerSession(context: context)

        // Assert
        #expect(auth.estConnecte)
        #expect(user.sessionCreeeLe != nil,
                "Le compteur d'expiration doit être amorcé pour ne pas bypasser la règle 30 jours")

        // Cleanup
        nettoyerKeychainGlobal()
    }

    // MARK: - État session (foreground check)

    @Test("verifierEtatSession retourne .valide pour compte actif")
    func etatSessionValide() throws {
        // Arrange
        let auth = creerAuthIsole()
        let context = try creerContexteEnMemoire()
        _ = try insererUtilisateurApple(identifiant: "actif.user",
                                        appleUserID: "010.actif", context: context)
        let etatConnexion = auth.connexionApple(appleUserID: "010.actif", prenom: "", nom: "", context: context)
        guard case .connecte = etatConnexion else {
            Issue.record("La connexion SIWA devrait réussir")
            return
        }

        // Act
        let etat = auth.verifierEtatSession(context: context)

        // Assert
        #expect(etat == .valide)

        // Cleanup
        auth.deconnexion()
    }

    @Test("verifierEtatSession retourne .desactive si estActif = false")
    func etatSessionDesactive() throws {
        // Arrange
        let auth = creerAuthIsole()
        let context = try creerContexteEnMemoire()
        let user = try insererUtilisateurApple(identifiant: "ex.athlete",
                                               appleUserID: "011.desactive", context: context)
        _ = auth.connexionApple(appleUserID: "011.desactive", prenom: "", nom: "", context: context)
        #expect(auth.estConnecte)

        // Act : le coach désactive le compte en BD
        user.estActif = false
        try context.save()
        let etat = auth.verifierEtatSession(context: context)

        // Assert
        #expect(etat == .desactive)

        // Cleanup
        auth.deconnexion()
    }

    @Test("verifierEtatSession retourne .supprime si utilisateur absent")
    func etatSessionSupprime() throws {
        // Arrange
        let auth = creerAuthIsole()
        let context = try creerContexteEnMemoire()
        let user = try insererUtilisateurApple(identifiant: "fantome",
                                               appleUserID: "012.fantome", context: context)
        _ = auth.connexionApple(appleUserID: "012.fantome", prenom: "", nom: "", context: context)
        #expect(auth.estConnecte)

        // Act : suppression physique du compte
        context.delete(user)
        try context.save()
        let etat = auth.verifierEtatSession(context: context)

        // Assert
        #expect(etat == .supprime)

        // Cleanup
        auth.deconnexion()
    }

    @Test("verifierEtatSession retourne .valide si personne connecté")
    func etatSessionPasConnecte() throws {
        // Arrange
        let auth = creerAuthIsole()
        let context = try creerContexteEnMemoire()

        // Act
        let etat = auth.verifierEtatSession(context: context)

        // Assert
        #expect(etat == .valide, "Si aucun utilisateur connecté, pas de vérif à faire")
    }

    // MARK: - Déconnexion

    @Test("deconnexion efface l'utilisateur connecté et la session Keychain")
    func deconnexion() throws {
        // Arrange
        let auth = creerAuthIsole()
        let context = try creerContexteEnMemoire()
        _ = try insererUtilisateurApple(identifiant: "deco.test",
                                        appleUserID: "020.deco", context: context)
        _ = auth.connexionApple(appleUserID: "020.deco", prenom: "", nom: "", context: context)
        #expect(auth.estConnecte)
        #expect(auth.idSessionSauvegardee != nil)

        // Act
        auth.deconnexion()

        // Assert
        #expect(!auth.estConnecte)
        #expect(auth.utilisateurConnecte == nil)
        #expect(auth.idSessionSauvegardee == nil, "La session Keychain doit être supprimée")
    }
}
