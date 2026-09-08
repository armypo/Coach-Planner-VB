//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  MembreFactory — création unifiée d'un membre d'équipe (SIWA strict).
//

import Foundation
import SwiftData

/// Crée les entités d'un membre du STAFF (Utilisateur + CredentialAthlete
/// marqueur) SANS aucun secret : la connexion se fait exclusivement par
/// Sign in with Apple + code d'invitation (rattachement via `rejoindreEquipe`).
///
/// Depuis le pivot coach-first, seuls les assistants coachs passent par cette
/// factory — les joueurs du roster sont des données pures (JoueurEquipe), sans
/// compte. Utilisée par le wizard de configuration et AjoutUtilisateurView.
@MainActor
enum MembreFactory {

    struct Membre {
        let utilisateur: Utilisateur
        let recap: CredentialRecap
        /// Marqueur de membre inséré par la factory — exposé pour permettre un
        /// rollback complet (delete) si la sauvegarde échoue côté appelant.
        let credential: CredentialAthlete
    }

    /// - Parameters:
    ///   - identifiantSouhaite: identifiant choisi manuellement. L'UNICITÉ doit être
    ///     validée par l'appelant ; si nil/vide, un identifiant unique est auto-généré.
    ///   - exclusions: identifiants déjà réservés en mémoire dans la même session
    ///     (SwiftData ne voit pas les insertions non commitées).
    @discardableResult
    static func creerMembre(
        prenom: String,
        nom: String,
        role: RoleUtilisateur,
        codeEquipe: String,
        identifiantSouhaite: String? = nil,
        context: ModelContext,
        exclusions: inout Set<String>
    ) -> Membre {
        let identifiant: String
        if let souhaite = identifiantSouhaite?.lowercased().trimmingCharacters(in: .whitespaces),
           !souhaite.isEmpty {
            identifiant = souhaite
        } else {
            identifiant = Utilisateur.genererIdentifiantUnique(
                prenom: prenom, nom: nom, context: context, exclusions: exclusions
            )
        }
        exclusions.insert(identifiant)

        let utilisateur = Utilisateur(
            identifiant: identifiant,
            motDePasseHash: "",   // SIWA strict : aucun secret stocké
            prenom: prenom.trimmingCharacters(in: .whitespaces),
            nom: nom.trimmingCharacters(in: .whitespaces),
            role: role,
            codeEcole: codeEquipe
        )
        utilisateur.codeInvitation = Utilisateur.genererCodeUniqueInvitation(context: context)
        utilisateur.codeEquipe = codeEquipe
        context.insert(utilisateur)

        // CredentialAthlete = marqueur de membre (aucun mot de passe).
        let cred = CredentialAthlete(
            utilisateurID: utilisateur.id,
            joueurEquipeID: nil,
            identifiant: identifiant,
            codeEquipe: codeEquipe
        )
        context.insert(cred)

        let recap = CredentialRecap(
            nomComplet: "\(prenom) \(nom)",
            identifiant: identifiant,
            codeEquipe: codeEquipe,
            codeInvitation: utilisateur.codeInvitation,
            role: libelleRole(role)
        )
        return Membre(utilisateur: utilisateur, recap: recap, credential: cred)
    }

    /// Surcharge de commodité pour la création d'un membre isolé : gère son
    /// propre Set d'exclusions (le wizard multi-membres utilise la variante `inout`).
    @discardableResult
    static func creerMembre(
        prenom: String,
        nom: String,
        role: RoleUtilisateur,
        codeEquipe: String,
        identifiantSouhaite: String? = nil,
        context: ModelContext
    ) -> Membre {
        var exclusions = Set<String>()
        return creerMembre(
            prenom: prenom, nom: nom, role: role, codeEquipe: codeEquipe,
            identifiantSouhaite: identifiantSouhaite,
            context: context, exclusions: &exclusions
        )
    }

    private static func libelleRole(_ role: RoleUtilisateur) -> String {
        role == .assistantCoach ? "Assistant" : "Coach"
    }
}
