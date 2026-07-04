//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  MembreFactory — création unifiée d'un membre d'équipe (SIWA strict).
//

import Foundation
import SwiftData

/// Crée les entités d'un membre d'équipe (Utilisateur + CredentialAthlete
/// marqueur) SANS aucun secret : la connexion se fait exclusivement par
/// Sign in with Apple + code d'invitation (rattachement via `rejoindreEquipe`).
///
/// Utilisé par le wizard de configuration (assistants + joueurs) et par
/// AjoutUtilisateurView — remplace les trois copies divergentes de cette logique.
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
    ///   - joueur: `JoueurEquipe` à lier (athlètes) — reçoit `identifiant` + `utilisateurID`.
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
        joueur: JoueurEquipe? = nil,
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
        if let joueur {
            utilisateur.joueurEquipeID = joueur.id
            utilisateur.numero = joueur.numero
            utilisateur.posteRaw = joueur.poste.rawValue
        }
        context.insert(utilisateur)

        if let joueur {
            joueur.identifiant = identifiant
            joueur.utilisateurID = utilisateur.id
        }

        // CredentialAthlete = marqueur de membre (aucun mot de passe).
        let cred = CredentialAthlete(
            utilisateurID: utilisateur.id,
            joueurEquipeID: joueur?.id,
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
        joueur: JoueurEquipe? = nil,
        identifiantSouhaite: String? = nil,
        context: ModelContext
    ) -> Membre {
        var exclusions = Set<String>()
        return creerMembre(
            prenom: prenom, nom: nom, role: role, codeEquipe: codeEquipe,
            joueur: joueur, identifiantSouhaite: identifiantSouhaite,
            context: context, exclusions: &exclusions
        )
    }

    private static func libelleRole(_ role: RoleUtilisateur) -> String {
        switch role {
        case .etudiant: return "Athlète"
        case .assistantCoach: return "Assistant"
        default: return "Coach"
        }
    }
}
