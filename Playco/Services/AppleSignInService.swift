//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  AppleSignInService — extraction du credential Sign in with Apple et
//  vérification de l'état (révocation). La présentation du bouton est gérée
//  par `SignInWithAppleButton` (AuthenticationServices SwiftUI) côté vue ;
//  ce service centralise le parsing du résultat et le contrôle de validité.
//

import Foundation
import AuthenticationServices
import os

/// Données non sensibles issues d'un Sign in with Apple réussi.
/// `user` est la clé durable stable (identique sur tous les appareils du même
/// Apple ID). `fullName`/`email` ne sont fournis QUE lors de la toute première
/// autorisation — à persister immédiatement.
struct AppleCredentials: Equatable {
    let user: String
    let fullName: PersonNameComponents?
    let email: String?

    /// Prénom/nom dérivés du `fullName` Apple (vides si non fournis).
    var prenom: String { fullName?.givenName ?? "" }
    var nom: String { fullName?.familyName ?? "" }
}

@MainActor
@Observable
final class AppleSignInService {

    private static let logger = Logger(subsystem: "com.origotech.playco", category: "AppleSignIn")

    /// Configure une requête SIWA (scopes nom + email demandés au 1er login).
    /// À passer au `onRequest` de `SignInWithAppleButton`.
    func configurerRequete(_ requete: ASAuthorizationAppleIDRequest) {
        requete.requestedScopes = [.fullName, .email]
    }

    /// Extrait les credentials d'un résultat `SignInWithAppleButton.onCompletion`.
    /// - Returns: `AppleCredentials` si succès, sinon `nil` (annulation/erreur loggée).
    func traiterResultat(_ resultat: Result<ASAuthorization, Error>) -> AppleCredentials? {
        switch resultat {
        case .success(let autorisation):
            guard let credential = autorisation.credential as? ASAuthorizationAppleIDCredential else {
                Self.logger.error("Credential SIWA de type inattendu")
                return nil
            }
            return AppleCredentials(
                user: credential.user,
                fullName: credential.fullName,
                email: credential.email
            )
        case .failure(let erreur):
            // L'annulation utilisateur n'est pas une erreur applicative.
            if (erreur as? ASAuthorizationError)?.code == .canceled {
                Self.logger.info("Sign in with Apple annulé par l'utilisateur")
            } else {
                Self.logger.error("Échec Sign in with Apple: \(erreur.localizedDescription)")
            }
            return nil
        }
    }

    /// Vérifie l'état d'un identifiant Apple (révocation/déconnexion système).
    /// À appeler au lancement pour révoquer une session dont l'Apple ID n'est plus autorisé.
    func verifierEtat(appleUserID: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
        guard !appleUserID.isEmpty else { return .notFound }
        return await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: appleUserID) { etat, _ in
                continuation.resume(returning: etat)
            }
        }
    }

    /// `true` si l'identité Apple n'est plus autorisée (révoquée ou introuvable).
    /// Helper Bool pour éviter d'exposer `AuthenticationServices` aux appelants.
    /// `.transferred` est traité comme encore valide (migration d'équipe de dev).
    func estRevoque(appleUserID: String) async -> Bool {
        let etat = await verifierEtat(appleUserID: appleUserID)
        return etat == .revoked || etat == .notFound
    }
}
