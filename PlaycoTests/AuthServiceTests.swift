//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Testing
import Foundation
import SwiftData
import CryptoKit
@testable import Playco

/// Tests sérialisés : KeychainService est un store global iOS que nous ne pouvons
/// pas isoler par test. L'exécution séquentielle évite les collisions entre tests
/// qui écrivent/lisent la clé de session dans le Keychain.
@Suite("AuthService", .serialized)
struct AuthServiceTests {

    private func creerContexteEnMemoire() throws -> ModelContext {
        let schema = Schema([Utilisateur.self, JoueurEquipe.self, Equipe.self,
                             Etablissement.self, ProfilCoach.self, AssistantCoach.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    /// Nettoie l'état Keychain global (session + verrouillage) avant chaque test.
    /// Le Keychain iOS n'est pas isolable par suite, d'où le nettoyage explicite.
    @MainActor
    private func nettoyerKeychainGlobal() {
        KeychainService.supprimer(cle: SessionManager.cleKeychain)
        KeychainService.supprimer(cle: AuthService.cleEtatVerrouillage)
    }

    /// AuthService avec UserDefaults isolé — conservé pour la migration legacy
    /// UserDefaults → Keychain. Le verrouillage lui-même est en Keychain global.
    @MainActor
    private func creerAuthIsole() -> AuthService {
        nettoyerKeychainGlobal()
        let suite = UserDefaults(suiteName: "playco-test-\(UUID().uuidString)")!
        return AuthService(userDefaults: suite)
    }

    /// Crée un AuthService isolé ET retourne aussi la suite UserDefaults
    /// pour les tests qui doivent écrire dans le même store (ex: restaurerSession).
    @MainActor
    private func creerAuthAvecSuite() -> (AuthService, UserDefaults) {
        nettoyerKeychainGlobal()
        let suite = UserDefaults(suiteName: "playco-test-\(UUID().uuidString)")!
        return (AuthService(userDefaults: suite), suite)
    }

    // MARK: - Hash

    @Test("Hash déterministe avec sel")
    func hashDeterministe() {
        let auth = creerAuthIsole()
        let sel = "abc123"
        let h1 = auth.hashMotDePasse("monMotDePasse", sel: sel)
        let h2 = auth.hashMotDePasse("monMotDePasse", sel: sel)
        #expect(h1 == h2, "Le hash doit être déterministe")
        #expect(h1.count == 64, "SHA256 produit 64 caractères hex")
    }

    @Test("Hash différent avec sel différent")
    func hashDifferentAvecSelDifferent() {
        let auth = creerAuthIsole()
        let h1 = auth.hashMotDePasse("test", sel: "sel1")
        let h2 = auth.hashMotDePasse("test", sel: "sel2")
        #expect(h1 != h2, "Sels différents doivent produire des hash différents")
    }

    @Test("Connexion rétrocompatible — ancien hash sans sel")
    func connexionRetrocompatibleSansSel() throws {
        let auth = creerAuthIsole()
        let context = try creerContexteEnMemoire()

        // Simuler un ancien hash SHA256 sans sel (comme le faisait la version initiale)
        let motDePasse = "motdepasse"
        let donnees = Data(motDePasse.utf8)
        let hashAncien = SHA256.hash(data: donnees)
            .compactMap { String(format: "%02x", $0) }.joined()

        let user = Utilisateur(
            identifiant: "ancien.compte",
            motDePasseHash: hashAncien,
            prenom: "Ancien",
            nom: "Compte",
            role: .etudiant
        )
        // Pas de sel — simule un compte pré-migration
        context.insert(user)
        try context.save()

        auth.connexion(identifiant: "ancien.compte", motDePasse: motDePasse, context: context)
        #expect(auth.estConnecte, "Doit accepter un ancien hash sans sel (rétrocompatibilité)")

        // Après connexion réussie, le compte doit avoir été migré vers PBKDF2 600k
        #expect(user.iterations == AuthService.iterationsParDefaut,
                "Migration auto SHA256 → PBKDF2 au login")
        #expect((user.sel?.isEmpty ?? true) == false,
                "Migration a généré un sel aléatoire")
    }

    @Test("Migration hash v1.9 (SHA256+sel) → PBKDF2 au login")
    func connexionMigrationSHA256Sel() throws {
        let auth = creerAuthIsole()
        let context = try creerContexteEnMemoire()

        // Simuler un compte v1.9 : sel présent, hash = SHA256(sel + mdp), iterations = 1
        let motDePasse = "motdepassev19"
        let sel = "7f3a9b21d4c6e8f05a1b3c2d4e5f6789"
        let hashV19 = SHA256.hash(data: Data((sel + motDePasse).utf8))
            .compactMap { String(format: "%02x", $0) }.joined()

        let user = Utilisateur(
            identifiant: "v19.compte",
            motDePasseHash: hashV19,
            prenom: "Un",
            nom: "Neuf",
            role: .etudiant
        )
        user.sel = sel
        user.iterations = 1 // chemin legacy v1.9
        context.insert(user)
        try context.save()

        auth.connexion(identifiant: "v19.compte", motDePasse: motDePasse, context: context)
        #expect(auth.estConnecte, "Doit accepter un hash SHA256+sel legacy")

        // Migration vers PBKDF2 600k
        #expect(user.iterations == AuthService.iterationsParDefaut,
                "iterations doit être à 600k après migration")
        #expect(user.motDePasseHash != hashV19,
                "hash doit avoir changé (nouveau hash PBKDF2)")
        #expect(user.sel != sel,
                "sel doit avoir changé (migration régénère un sel)")

        // Se reconnecter avec le même mot de passe après migration doit fonctionner
        auth.deconnexion()
        auth.connexion(identifiant: "v19.compte", motDePasse: motDePasse, context: context)
        #expect(auth.estConnecte, "Le même mot de passe doit fonctionner post-migration")
    }

    @Test("Génération de sel unique")
    func genererSelUnique() {
        let auth = creerAuthIsole()
        let sel1 = auth.genererSel()
        let sel2 = auth.genererSel()
        #expect(sel1 != sel2, "Deux sels générés doivent être différents")
        #expect(sel1.count == 32, "Sel = 16 bytes = 32 hex chars")
    }

    // MARK: - Politique mot de passe NIST 800-63B

    @Test("Politique mdp : refuse < 12 caractères")
    func mdpTropCourt() {
        let erreur = PasswordPolicy.valider("court12345",
                                                    identifiant: "user",
                                                    prenom: "Jean",
                                                    nom: "Tremblay")
        #expect(erreur?.contains("12 caractères") == true)
    }

    @Test("Politique mdp : refuse mdp commun (blacklist)")
    func mdpCommunRefuse() {
        let erreur = PasswordPolicy.valider("motdepasse12",
                                                    identifiant: "user",
                                                    prenom: "Jean",
                                                    nom: "Tremblay")
        #expect(erreur?.contains("trop commun") == true)
    }

    @Test("Politique mdp : refuse contournement par suffixe")
    func mdpBlacklistContournementRefuse() {
        let erreur = PasswordPolicy.valider("volleyball123!",
                                                    identifiant: "user",
                                                    prenom: "Jean",
                                                    nom: "Tremblay")
        #expect(erreur?.contains("trop commun") == true)
    }

    @Test("Politique mdp : refuse si contient identifiant/prénom/nom")
    func mdpContientPII() {
        let erreur = PasswordPolicy.valider("SuperTremblay9!",
                                                    identifiant: "jean.tremblay",
                                                    prenom: "Jean",
                                                    nom: "Tremblay")
        #expect(erreur?.contains("identifiant") == true)
    }

    @Test("Politique mdp : accepte mdp valide unique")
    func mdpValideAccepte() {
        let erreur = PasswordPolicy.valider("Cheval-Sauvage-2026!",
                                                    identifiant: "jean.tremblay",
                                                    prenom: "Jean",
                                                    nom: "Tremblay")
        #expect(erreur == nil)
    }

    // MARK: - Lockout

    @Test("Verrouillage après 5 tentatives")
    func lockoutApres5Tentatives() {
        let auth = creerAuthIsole()
        #expect(!auth.estVerrouille)
        for _ in 0..<5 {
            auth.enregistrerEchec()
        }
        #expect(auth.estVerrouille, "Doit être verrouillé après 5 échecs")
        #expect(auth.tentativesEchouees == 5)
        #expect(auth.tempsRestantVerrouillage > 0)
    }

    @Test("Pas de verrouillage avant 5 tentatives")
    func pasLockoutAvant5() {
        let auth = creerAuthIsole()
        for _ in 0..<4 {
            auth.enregistrerEchec()
        }
        #expect(!auth.estVerrouille)
        #expect(auth.tentativesEchouees == 4)
    }

    // MARK: - Connexion

    @Test("Connexion réussie")
    func connexionReussie() throws {
        let auth = creerAuthIsole()
        let context = try creerContexteEnMemoire()

        let sel = auth.genererSel()
        let hash = auth.hashMotDePasse("secret123", sel: sel)
        let user = Utilisateur(identifiant: "chris.dionne", motDePasseHash: hash, prenom: "Chris", nom: "Dionne", role: .admin)
        user.sel = sel
        user.iterations = AuthService.iterationsParDefaut
        context.insert(user)
        try context.save()

        auth.connexion(identifiant: "chris.dionne", motDePasse: "secret123", context: context)
        #expect(auth.estConnecte, "Doit être connecté après connexion réussie")
        #expect(auth.utilisateurConnecte?.identifiant == "chris.dionne")
        #expect(auth.erreur == nil)
    }

    @Test("Connexion échouée — mauvais mot de passe")
    func connexionEchouee() throws {
        let auth = creerAuthIsole()
        let context = try creerContexteEnMemoire()

        let sel = auth.genererSel()
        let hash = auth.hashMotDePasse("correct", sel: sel)
        let user = Utilisateur(identifiant: "test.user", motDePasseHash: hash, prenom: "Test", nom: "User", role: .etudiant)
        user.sel = sel
        user.iterations = AuthService.iterationsParDefaut
        context.insert(user)
        try context.save()

        auth.connexion(identifiant: "test.user", motDePasse: "mauvais", context: context)
        #expect(!auth.estConnecte)
        #expect(auth.erreur != nil)
        #expect(auth.tentativesEchouees == 1)
    }

    @Test("Connexion bloquée quand verrouillé")
    func connexionBloquee() throws {
        let auth = creerAuthIsole()
        let context = try creerContexteEnMemoire()

        // Forcer le verrouillage
        for _ in 0..<5 { auth.enregistrerEchec() }

        auth.connexion(identifiant: "n'importe", motDePasse: "quoi", context: context)
        #expect(!auth.estConnecte)
        #expect(auth.erreur?.contains("verrouillé") == true)
    }

    // MARK: - Session

    @Test("Restauration de session")
    func restaurerSession() throws {
        let (auth, suite) = creerAuthAvecSuite()
        let context = try creerContexteEnMemoire()

        let sel = auth.genererSel()
        let hash = auth.hashMotDePasse("pass", sel: sel)
        let user = Utilisateur(identifiant: "session.test", motDePasseHash: hash, prenom: "S", nom: "T", role: .etudiant)
        user.sel = sel
        user.iterations = AuthService.iterationsParDefaut
        context.insert(user)
        try context.save()

        // Simuler une session legacy dans la suite injectée (non .standard !)
        suite.set(user.id.uuidString, forKey: "utilisateurConnecteID")

        let auth2 = AuthService(userDefaults: suite)
        auth2.restaurerSession(context: context)
        #expect(auth2.estConnecte)
        #expect(auth2.utilisateurConnecte?.id == user.id)

        // Cleanup
        suite.removeObject(forKey: "utilisateurConnecteID")
        KeychainService.supprimer(cle: SessionManager.cleKeychain)
    }

    // MARK: - État session (foreground check)

    @Test("verifierEtatSession retourne .valide pour compte actif")
    func etatSessionValide() throws {
        let auth = creerAuthIsole()
        let context = try creerContexteEnMemoire()

        let sel = auth.genererSel()
        let hash = auth.hashMotDePasse("pass", sel: sel)
        let user = Utilisateur(identifiant: "actif.user", motDePasseHash: hash,
                               prenom: "A", nom: "U", role: .etudiant)
        user.sel = sel
        user.iterations = AuthService.iterationsParDefaut
        context.insert(user)
        try context.save()

        auth.connexion(identifiant: "actif.user", motDePasse: "pass", context: context)
        #expect(auth.estConnecte)

        let etat = auth.verifierEtatSession(context: context)
        #expect(etat == .valide)
    }

    @Test("verifierEtatSession retourne .desactive si estActif = false")
    func etatSessionDesactive() throws {
        let auth = creerAuthIsole()
        let context = try creerContexteEnMemoire()

        let sel = auth.genererSel()
        let hash = auth.hashMotDePasse("pass", sel: sel)
        let user = Utilisateur(identifiant: "ex.athlete", motDePasseHash: hash,
                               prenom: "X", nom: "A", role: .etudiant)
        user.sel = sel
        user.iterations = AuthService.iterationsParDefaut
        context.insert(user)
        try context.save()

        auth.connexion(identifiant: "ex.athlete", motDePasse: "pass", context: context)
        #expect(auth.estConnecte)

        // Le coach désactive le compte en BD
        user.estActif = false
        try context.save()

        let etat = auth.verifierEtatSession(context: context)
        #expect(etat == .desactive)
    }

    @Test("verifierEtatSession retourne .supprime si utilisateur absent")
    func etatSessionSupprime() throws {
        let auth = creerAuthIsole()
        let context = try creerContexteEnMemoire()

        let sel = auth.genererSel()
        let hash = auth.hashMotDePasse("pass", sel: sel)
        let user = Utilisateur(identifiant: "fantome", motDePasseHash: hash,
                               prenom: "F", nom: "T", role: .etudiant)
        user.sel = sel
        user.iterations = AuthService.iterationsParDefaut
        context.insert(user)
        try context.save()

        auth.connexion(identifiant: "fantome", motDePasse: "pass", context: context)
        #expect(auth.estConnecte)

        // Suppression physique du compte
        context.delete(user)
        try context.save()

        let etat = auth.verifierEtatSession(context: context)
        #expect(etat == .supprime)
    }

    @Test("verifierEtatSession retourne .valide si personne connecté")
    func etatSessionPasConnecte() throws {
        let auth = creerAuthIsole()
        let context = try creerContexteEnMemoire()

        let etat = auth.verifierEtatSession(context: context)
        #expect(etat == .valide, "Si aucun utilisateur connecté, pas de vérif à faire")
    }

    // MARK: - Déconnexion

    @Test("Déconnexion")
    func deconnexion() throws {
        let auth = creerAuthIsole()
        let context = try creerContexteEnMemoire()

        let sel = auth.genererSel()
        let hash = auth.hashMotDePasse("pass", sel: sel)
        let user = Utilisateur(identifiant: "deco.test", motDePasseHash: hash, prenom: "D", nom: "T", role: .etudiant)
        user.sel = sel
        user.iterations = AuthService.iterationsParDefaut
        context.insert(user)
        try context.save()

        auth.connexion(identifiant: "deco.test", motDePasse: "pass", context: context)
        #expect(auth.estConnecte)

        auth.deconnexion()
        #expect(!auth.estConnecte)
        #expect(auth.utilisateurConnecte == nil)
    }
}
