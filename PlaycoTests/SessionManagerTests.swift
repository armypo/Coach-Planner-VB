//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Testing
import Foundation
@testable import Playco

/// Tests sérialisés : SessionManager utilise le Keychain global iOS.
@Suite("SessionManager — persistance + expiration", .serialized)
struct SessionManagerTests {

    private func nettoyer() {
        KeychainService.supprimer(cle: SessionManager.cleKeychain)
    }

    private func creerIsole() -> SessionManager {
        nettoyer()
        let suite = UserDefaults(suiteName: "playco-session-test-\(UUID().uuidString)")!
        return SessionManager(userDefaults: suite)
    }

    // MARK: - Expiration (pure fonction)

    @Test("estExpiree : faux juste après création")
    func estExpireeFauxJusteApresCreation() {
        let maintenant = Date()
        let dateCreation = maintenant.addingTimeInterval(-60) // il y a 1 min
        #expect(!SessionManager.estExpiree(dateCreation: dateCreation, maintenant: maintenant))
    }

    @Test("estExpiree : vrai après 30 jours + 1 seconde")
    func estExpireeApres30Jours() {
        let maintenant = Date()
        let trente_jours_1s = SessionManager.dureeMaxSecondes + 1
        let dateCreation = maintenant.addingTimeInterval(-trente_jours_1s)
        #expect(SessionManager.estExpiree(dateCreation: dateCreation, maintenant: maintenant))
    }

    @Test("estExpiree : faux à exactement 30 jours (frontière strict)")
    func estExpireeFrontiere() {
        let maintenant = Date()
        let dateCreation = maintenant.addingTimeInterval(-SessionManager.dureeMaxSecondes)
        // `>` strict, pas `>=` → à exactement 30j, pas encore expiré
        #expect(!SessionManager.estExpiree(dateCreation: dateCreation, maintenant: maintenant))
    }

    // MARK: - Persistance

    @Test("idSauvegarde : nil quand rien stocké")
    func idSauvegardeNilInitial() {
        let session = creerIsole()
        #expect(session.idSauvegarde == nil)
    }

    @Test("sauvegarder + idSauvegarde : round-trip Keychain")
    func sauvegarderRoundTrip() {
        let session = creerIsole()
        let id = UUID()
        session.sauvegarder(utilisateurID: id)
        #expect(session.idSauvegarde == id.uuidString)
    }

    @Test("supprimer : efface l'entrée Keychain")
    func supprimer() {
        let session = creerIsole()
        let id = UUID()
        session.sauvegarder(utilisateurID: id)
        session.supprimer()
        #expect(session.idSauvegarde == nil)
    }

    @Test("Migration UserDefaults legacy → Keychain au premier accès")
    func migrationLegacy() {
        nettoyer()
        let suite = UserDefaults(suiteName: "playco-session-test-\(UUID().uuidString)")!
        // Planter une entrée legacy dans UserDefaults
        suite.set("LEGACY-UUID-VALUE", forKey: "utilisateurConnecteID")

        let session = SessionManager(userDefaults: suite)
        // Premier accès lit le legacy, le migre, et retourne la valeur
        #expect(session.idSauvegarde == "LEGACY-UUID-VALUE")
        // La clé legacy doit avoir été supprimée de UserDefaults
        #expect(suite.string(forKey: "utilisateurConnecteID") == nil)
        // Le Keychain contient maintenant la valeur
        #expect(KeychainService.lire(cle: SessionManager.cleKeychain) == "LEGACY-UUID-VALUE")

        // Cleanup
        nettoyer()
    }
}
