//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Testing
import Foundation
import SwiftData
@testable import Playco

@Suite("AuthService")
struct AuthServiceTests {

    private func creerContexteEnMemoire() throws -> ModelContext {
        let schema = Schema([Utilisateur.self, JoueurEquipe.self, Equipe.self,
                             Etablissement.self, ProfilCoach.self, AssistantCoach.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    // MARK: - Hash

    @Test("Hash déterministe avec sel")
    func hashDeterministe() {
        let auth = AuthService()
        let sel = "abc123"
        let h1 = auth.hashMotDePasse("monMotDePasse", sel: sel)
        let h2 = auth.hashMotDePasse("monMotDePasse", sel: sel)
        #expect(h1 == h2, "Le hash doit être déterministe")
        #expect(h1.count == 64, "SHA256 produit 64 caractères hex")
    }

    @Test("Hash différent avec sel différent")
    func hashDifferentAvecSelDifferent() {
        let auth = AuthService()
        let h1 = auth.hashMotDePasse("test", sel: "sel1")
        let h2 = auth.hashMotDePasse("test", sel: "sel2")
        #expect(h1 != h2, "Sels différents doivent produire des hash différents")
    }

    @Test("Hash sans sel — rétrocompatibilité")
    func hashSansSel() {
        let auth = AuthService()
        let h1 = auth.hashMotDePasse("motdepasse")
        let h2 = auth.hashMotDePasse("motdepasse")
        #expect(h1 == h2)
        #expect(h1.count == 64)
    }

    @Test("Génération de sel unique")
    func genererSelUnique() {
        let auth = AuthService()
        let sel1 = auth.genererSel()
        let sel2 = auth.genererSel()
        #expect(sel1 != sel2, "Deux sels générés doivent être différents")
        #expect(sel1.count == 32, "Sel = 16 bytes = 32 hex chars")
    }

    // MARK: - Lockout

    @Test("Verrouillage après 5 tentatives")
    func lockoutApres5Tentatives() {
        let auth = AuthService()
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
        let auth = AuthService()
        for _ in 0..<4 {
            auth.enregistrerEchec()
        }
        #expect(!auth.estVerrouille)
        #expect(auth.tentativesEchouees == 4)
    }

    // MARK: - Connexion

    @Test("Connexion réussie")
    func connexionReussie() throws {
        let auth = AuthService()
        let context = try creerContexteEnMemoire()

        let sel = auth.genererSel()
        let hash = auth.hashMotDePasse("secret123", sel: sel)
        let user = Utilisateur(identifiant: "chris.dionne", motDePasseHash: hash, prenom: "Chris", nom: "Dionne", role: .admin)
        user.sel = sel
        context.insert(user)
        try context.save()

        auth.connexion(identifiant: "chris.dionne", motDePasse: "secret123", context: context)
        #expect(auth.estConnecte, "Doit être connecté après connexion réussie")
        #expect(auth.utilisateurConnecte?.identifiant == "chris.dionne")
        #expect(auth.erreur == nil)
    }

    @Test("Connexion échouée — mauvais mot de passe")
    func connexionEchouee() throws {
        let auth = AuthService()
        let context = try creerContexteEnMemoire()

        let sel = auth.genererSel()
        let hash = auth.hashMotDePasse("correct", sel: sel)
        let user = Utilisateur(identifiant: "test.user", motDePasseHash: hash, prenom: "Test", nom: "User", role: .etudiant)
        user.sel = sel
        context.insert(user)
        try context.save()

        auth.connexion(identifiant: "test.user", motDePasse: "mauvais", context: context)
        #expect(!auth.estConnecte)
        #expect(auth.erreur != nil)
        #expect(auth.tentativesEchouees == 1)
    }

    @Test("Connexion bloquée quand verrouillé")
    func connexionBloquee() throws {
        let auth = AuthService()
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
        let auth = AuthService()
        let context = try creerContexteEnMemoire()

        let sel = auth.genererSel()
        let hash = auth.hashMotDePasse("pass", sel: sel)
        let user = Utilisateur(identifiant: "session.test", motDePasseHash: hash, prenom: "S", nom: "T", role: .etudiant)
        user.sel = sel
        context.insert(user)
        try context.save()

        // Simuler sauvegarde de session
        UserDefaults.standard.set(user.id.uuidString, forKey: "utilisateurConnecteID")

        let auth2 = AuthService()
        auth2.restaurerSession(context: context)
        #expect(auth2.estConnecte)
        #expect(auth2.utilisateurConnecte?.id == user.id)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "utilisateurConnecteID")
    }

    // MARK: - Déconnexion

    @Test("Déconnexion")
    func deconnexion() throws {
        let auth = AuthService()
        let context = try creerContexteEnMemoire()

        let sel = auth.genererSel()
        let hash = auth.hashMotDePasse("pass", sel: sel)
        let user = Utilisateur(identifiant: "deco.test", motDePasseHash: hash, prenom: "D", nom: "T", role: .etudiant)
        user.sel = sel
        context.insert(user)
        try context.save()

        auth.connexion(identifiant: "deco.test", motDePasse: "pass", context: context)
        #expect(auth.estConnecte)

        auth.deconnexion()
        #expect(!auth.estConnecte)
        #expect(auth.utilisateurConnecte == nil)
    }
}
