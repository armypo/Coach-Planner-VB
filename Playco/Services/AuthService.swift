//  Playco
//  Copyright (c) 2025 Christopher Dionne. Tous droits reserves.
//
//  AuthService — authentification SIWA strict (v2.1).
//  Sign in with Apple est l'UNIQUE méthode de connexion : le flux
//  identifiant + mot de passe (connexion, creerCompte, lierCompteExistant,
//  PasswordPolicy, LockoutManager, KeyDerivation) a été retiré. Les champs
//  motDePasseHash/sel/iterations restent dans les @Model uniquement pour la
//  compatibilité du schéma CloudKit — ils ne sont plus ni écrits ni lus.
//

import Foundation
import SwiftData
import os

// MARK: - AuthService (MainActor — thread safety)
@MainActor
@Observable
final class AuthService {

    private static let logger = Logger(subsystem: "com.origotech.playco", category: "AuthService")

    var utilisateurConnecte: Utilisateur?
    var estConnecte: Bool { utilisateurConnecte != nil }
    var erreur: String?

    /// Store UserDefaults injectable — conservé pour migration session legacy.
    private let userDefaults: UserDefaults

    // MARK: - Session (délégué à SessionManager)

    /// Gestionnaire de session (persistance Keychain + expiration 30j).
    private let session: SessionManager

    /// UUID de session sauvegardé, ou `nil` (délégué à `session`).
    var idSessionSauvegardee: String? { session.idSauvegarde }

    // MARK: - init

    /// - Parameter userDefaults: magasin UserDefaults pour la migration legacy.
    ///   Injectable pour isolation des tests.
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.session = SessionManager(userDefaults: userDefaults)
    }

    // MARK: - Restauration de session

    /// Tente de restaurer la session précédente à partir du UUID stocké dans le
    /// Keychain. À appeler au démarrage de l'app après `attendreSyncInitiale()`
    /// pour éviter les faux-négatifs si CloudKit n'a pas encore rapatrié l'utilisateur.
    /// - Parameter context: contexte SwiftData pour fetch l'Utilisateur par id.
    ///
    /// Comportements :
    /// - Pas de session sauvegardée → no-op
    /// - Session > 30 jours → supprimée + `erreur` = "Session expirée"
    /// - Utilisateur absent/inactif → session supprimée, `utilisateurConnecte` reste nil
    /// - Session valide → `utilisateurConnecte` défini
    func restaurerSession(context: ModelContext) {
        guard let idString = session.idSauvegarde,
              let id = UUID(uuidString: idString) else { return }

        let descripteur = FetchDescriptor<Utilisateur>(
            predicate: #Predicate { $0.id == id && $0.estActif == true }
        )

        guard let utilisateur = try? context.fetch(descripteur).first else {
            session.supprimer()
            return
        }

        // Vérifier l'expiration de session (30 jours max)
        if let sessionCreee = utilisateur.sessionCreeeLe,
           SessionManager.estExpiree(dateCreation: sessionCreee) {
            Self.logger.info("Session expirée après 30 jours — déconnexion automatique")
            session.supprimer()
            erreur = "Session expirée, veuillez vous reconnecter."
            return
        }

        // Amorcer le compteur pour les comptes migrés (sessionCreeeLe == nil avant cette version)
        // Sans ça, les anciens comptes bypasseraient indéfiniment la règle 30 jours
        if utilisateur.sessionCreeeLe == nil {
            utilisateur.sessionCreeeLe = Date()
            do {
                try context.save()
            } catch {
                Self.logger.warning("Impossible d'amorcer sessionCreeeLe: \(error.localizedDescription)")
            }
        }

        utilisateurConnecte = utilisateur
    }

    // MARK: - Connexion par Sign in with Apple

    /// Résultat d'une tentative de connexion via Sign in with Apple.
    enum EtatConnexionApple {
        /// Compte trouvé et connecté.
        case connecte
        /// Aucun compte lié à cet `appleUserID` — l'UI doit router vers
        /// rejoindre-une-équipe (code d'invitation) ou onboarding coach.
        case compteInconnu(appleUserID: String, prenom: String, nom: String)
        /// Compte trouvé mais la session n'a pas pu être persistée — l'UI
        /// affiche le message et l'utilisateur réessaie.
        case echec(message: String)
    }

    /// Connecte l'utilisateur dont `appleUserID` correspond, sinon signale un
    /// compte inconnu (l'authentification a déjà été faite par Apple — aucun
    /// mot de passe n'est vérifié ici).
    /// - Parameters:
    ///   - appleUserID: `ASAuthorizationAppleIDCredential.user` (clé durable).
    ///   - prenom/nom: fournis par Apple au 1er login uniquement (sinon vides).
    func connexionApple(appleUserID: String, prenom: String, nom: String, context: ModelContext) -> EtatConnexionApple {
        erreur = nil
        let id = appleUserID.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty else {
            return .compteInconnu(appleUserID: appleUserID, prenom: prenom, nom: nom)
        }

        let descripteur = FetchDescriptor<Utilisateur>(
            predicate: #Predicate { $0.appleUserID == id && $0.estActif == true }
        )

        guard let utilisateur = try? context.fetch(descripteur).first else {
            return .compteInconnu(appleUserID: id, prenom: prenom, nom: nom)
        }

        utilisateur.sessionCreeeLe = Date()
        do {
            try context.save()
        } catch {
            Self.logger.error("connexionApple: impossible de persister la session: \(error.localizedDescription)")
            let message = "Impossible d'enregistrer ta session. Réessaie."
            erreur = message
            return .echec(message: message)
        }

        utilisateurConnecte = utilisateur
        session.sauvegarder(utilisateurID: utilisateur.id)
        return .connecte
    }

    // MARK: - Déconnexion

    func deconnexion() {
        utilisateurConnecte = nil
        session.supprimer()
    }

    // MARK: - Vérification état utilisateur (foreground check)

    /// Résultat de la vérification de l'état de l'utilisateur connecté.
    enum EtatSession {
        /// Utilisateur toujours actif et valide.
        case valide
        /// Utilisateur désactivé par le coach depuis la dernière connexion.
        case desactive
        /// Utilisateur supprimé de la BD depuis la dernière connexion.
        case supprime
    }

    /// Vérifie que l'utilisateur connecté est toujours valide dans la BD.
    /// À appeler au retour foreground (scenePhase = .active) pour révoquer
    /// rapidement les comptes désactivés par le coach.
    /// NE modifie PAS l'état — le caller décide de la déconnexion.
    func verifierEtatSession(context: ModelContext) -> EtatSession {
        guard let utilisateurID = utilisateurConnecte?.id else { return .valide }
        let descripteur = FetchDescriptor<Utilisateur>(
            predicate: #Predicate { $0.id == utilisateurID }
        )
        guard let utilisateur = try? context.fetch(descripteur).first else {
            return .supprime
        }
        return utilisateur.estActif ? .valide : .desactive
    }

}
