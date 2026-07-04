//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  CloudKitSharingService+Jointure — Jointure d'équipe cross-Apple-ID :
//  rattachement d'une identité Sign in with Apple à une ligne de roster
//  via le code d'équipe + code d'invitation. Code sensible (sécurité SIWA).

import Foundation
import CloudKit
import SwiftData
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "CloudKitSharing")

extension CloudKitSharingService {

    /// Rôles autorisés à rejoindre via le flux public (anti-escalade).
    /// Seuls `.etudiant` / `.assistantCoach` ; `.coach` / `.admin` rejetés
    /// (le coach est le créateur de l'équipe, jamais un joignant).
    static func roleJonctionAutorise(_ roleRaw: String) -> RoleUtilisateur? {
        guard let role = RoleUtilisateur(rawValue: roleRaw) else { return nil }
        switch role {
        case .etudiant, .assistantCoach: return role
        case .coach, .admin: return nil
        }
    }

    // MARK: - Rejoindre une équipe (Sign in with Apple, cross-Apple-ID)

    /// Rejoint une équipe via son code + un code d'invitation, et RATTACHE
    /// l'identité Sign in with Apple à la ligne de roster correspondante.
    /// - Returns: l'`Utilisateur` local réclamé (à connecter via `AuthService.connexionApple`).
    /// - Throws: `SharingError` si équipe/invitation introuvable ou déjà réclamée.
    func rejoindreEquipe(codeEquipe: String, codeInvitation: String, appleUserID: String, context: ModelContext) async throws -> Utilisateur {
        let code = codeEquipe.trimmingCharacters(in: .whitespaces).uppercased()
        let invite = codeInvitation.trimmingCharacters(in: .whitespaces).uppercased()
        let appleID = appleUserID.trimmingCharacters(in: .whitespaces)

        guard !code.isEmpty, !invite.isEmpty, !appleID.isEmpty else {
            throw SharingError.equipeNonTrouvee
        }

        // 1-2. Vérifier l'existence puis importer le roster localement.
        guard try await equipeExiste(codeEquipe: code) else { throw SharingError.equipeNonTrouvee }
        try await recupererEtImporterEquipe(codeEquipe: code, context: context)

        // 3-4. Réclamer la ligne de roster non liée (logique locale testable).
        guard let membre = reclamerMembreLocal(codeEquipe: code, codeInvitation: invite, appleUserID: appleID, context: context) else {
            throw SharingError.invitationInvalide
        }
        do {
            try context.save()
        } catch {
            logger.error("rejoindreEquipe: échec sauvegarde: \(error.localizedDescription)")
            throw SharingError.sauvegardeEchouee
        }
        await publierNouvelUtilisateur(membre, joueur: nil, codeEquipe: code)
        logger.info("Membre rattaché à l'équipe \(code, privacy: .private) via invitation")
        return membre
    }

    // MARK: - Réclamation locale (testable, sans CloudKit)

    /// Trouve la ligne de roster non liée correspondant au code d'invitation et
    /// lui rattache `appleUserID`. Logique purement locale (SwiftData) extraite
    /// de `rejoindreEquipe` pour être testable sans CloudKit.
    /// - Returns: l'`Utilisateur` réclamé (appleUserID renseigné, NON sauvegardé),
    ///   ou `nil` si aucune ligne libre ne correspond.
    func reclamerMembreLocal(codeEquipe: String, codeInvitation: String, appleUserID: String, context: ModelContext) -> Utilisateur? {
        let code = codeEquipe.trimmingCharacters(in: .whitespaces).uppercased()
        let invite = codeInvitation.trimmingCharacters(in: .whitespaces).uppercased()
        let appleID = appleUserID.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty, !invite.isEmpty, !appleID.isEmpty else { return nil }

        // Idempotence + anti-doublon : si cet Apple ID est DÉJÀ lié à un membre actif
        // de cette équipe, le retourner tel quel — ne JAMAIS créer un second
        // rattachement (évite les doublons en cas de double-clic / course).
        let descDejaLie = FetchDescriptor<Utilisateur>(
            predicate: #Predicate {
                $0.codeEquipe == code && $0.appleUserID == appleID && $0.estActif == true
            }
        )
        if let dejaLie = try? context.fetch(descDejaLie).first {
            return dejaLie
        }

        let descripteur = FetchDescriptor<Utilisateur>(
            predicate: #Predicate {
                $0.codeEquipe == code &&
                $0.codeInvitation == invite &&
                $0.appleUserID == "" &&
                $0.estActif == true
            }
        )
        guard let membre = try? context.fetch(descripteur).first else { return nil }
        // Anti-escalade : on ne réclame JAMAIS une ligne coach/admin via jointure
        // (seuls .etudiant/.assistantCoach rejoignent ; le coach crée l'équipe).
        guard Self.roleJonctionAutorise(membre.roleRaw) != nil else { return nil }
        membre.appleUserID = appleID
        membre.dateModification = Date()
        return membre
    }
}
