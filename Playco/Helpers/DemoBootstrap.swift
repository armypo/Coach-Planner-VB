//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Mode DÉMO : provisionne un coach + une équipe démo VIDES et ouvre une
//  session, pour un build vitrine sans login ni paywall. Compilé uniquement
//  sous la condition `DEMO` (absent des binaires Debug/Release de prod).
//

#if DEMO
import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "DemoBootstrap")

enum DemoBootstrap {
    /// Identifiant stable du coach démo (create-if-absent, idempotent).
    static let identifiantCoach = "demo.coach"

    /// Ouvre la session démo : récupère le coach démo existant ou le crée
    /// (avec son équipe vide), puis marque la session comme connectée.
    @MainActor
    static func demarrer(authService: AuthService, context: ModelContext) {
        let coach = coachExistant(context: context) ?? creer(context: context)
        authService.utilisateurConnecte = coach
    }

    @MainActor
    private static func coachExistant(context: ModelContext) -> Utilisateur? {
        let identifiant = identifiantCoach
        let descripteur = FetchDescriptor<Utilisateur>(
            predicate: #Predicate { $0.identifiant == identifiant && $0.estActif == true }
        )
        do {
            return try context.fetch(descripteur).first
        } catch {
            // Échec de lecture : on retombe sur la création d'un coach démo neuf.
            logger.error("Fetch du coach démo échoué: \(error.localizedDescription)")
            return nil
        }
    }

    /// Crée l'ensemble minimal cohérent : établissement + équipe (code généré)
    /// + profil coach (configurationCompletee) + utilisateur coach.
    @MainActor
    private static func creer(context: ModelContext) -> Utilisateur {
        let etablissement = Etablissement(nom: "Club Démo")
        context.insert(etablissement)

        let equipe = Equipe(nom: "Équipe Démo")
        equipe.codeEquipe = Equipe.genererCodeEquipe()
        equipe.etablissement = etablissement
        context.insert(equipe)

        let profil = ProfilCoach()
        profil.prenom = "Coach"
        profil.nom = "Démo"
        profil.configurationCompletee = true
        profil.etablissement = etablissement
        context.insert(profil)

        let coach = Utilisateur(
            identifiant: identifiantCoach,
            motDePasseHash: "",
            prenom: "Coach",
            nom: "Démo",
            role: .coach,
            codeEcole: equipe.codeEquipe
        )
        coach.estActif = true
        coach.sessionCreeeLe = Date()
        context.insert(coach)

        do {
            try context.save()
        } catch {
            // Le coach reste utilisable dans le contexte en mémoire pour la session
            // en cours ; seule la persistance a échoué.
            logger.error("Sauvegarde du bootstrap démo échouée: \(error.localizedDescription)")
        }
        return coach
    }
}
#endif
