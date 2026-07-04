//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Tests MembreFactory — création unifiée d'un membre d'équipe (SIWA strict) :
//  aucun secret stocké, code d'invitation généré, liaison JoueurEquipe et
//  gestion des exclusions en mémoire (lot du wizard).
//

import Testing
import Foundation
import SwiftData
@testable import Playco

@Suite("MembreFactory — création de membres SIWA")
@MainActor
struct MembreFactoryTests {

    // MARK: - Helpers

    private func creerContexteEnMemoire() throws -> ModelContext {
        let schema = Schema([Utilisateur.self, JoueurEquipe.self, CredentialAthlete.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, allowsSave: true, groupContainer: .none, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func fetchCredentials(_ context: ModelContext) throws -> [CredentialAthlete] {
        try context.fetch(FetchDescriptor<CredentialAthlete>())
    }

    // MARK: - Utilisateur créé sans secret

    @Test("creerMembre crée un Utilisateur sans secret, avec code d'invitation et codeEquipe")
    func creerMembreSansSecret() throws {
        // Arrange
        let context = try creerContexteEnMemoire()
        var exclusions: Set<String> = []

        // Act
        let membre = MembreFactory.creerMembre(
            prenom: "Jean", nom: "Tremblay", role: .etudiant,
            codeEquipe: "ELANS01", context: context, exclusions: &exclusions
        )
        try context.save()

        // Assert
        #expect(membre.utilisateur.motDePasseHash.isEmpty,
                "SIWA strict : aucun hash de mot de passe ne doit être stocké")
        #expect(!membre.utilisateur.codeInvitation.isEmpty,
                "Un code d'invitation doit être généré pour la jonction SIWA")
        #expect(membre.utilisateur.codeEquipe == "ELANS01")
        #expect(membre.utilisateur.codeEcole == "ELANS01")
        #expect(membre.utilisateur.role == .etudiant)
        #expect(membre.utilisateur.prenom == "Jean")
        #expect(membre.utilisateur.nom == "Tremblay")

        // Le récap reflète les codes de jonction
        #expect(membre.recap.codeInvitation == membre.utilisateur.codeInvitation)
        #expect(membre.recap.codeEquipe == "ELANS01")
        #expect(membre.recap.identifiant == membre.utilisateur.identifiant)
    }

    // MARK: - CredentialAthlete marqueur

    @Test("creerMembre crée un CredentialAthlete lié, SANS mot de passe en clair")
    func credentialLieSansMotDePasse() throws {
        // Arrange
        let context = try creerContexteEnMemoire()
        var exclusions: Set<String> = []

        // Act
        let membre = MembreFactory.creerMembre(
            prenom: "Alice", nom: "Martin", role: .etudiant,
            codeEquipe: "GARN26", context: context, exclusions: &exclusions
        )
        try context.save()

        // Assert
        let creds = try fetchCredentials(context)
        #expect(creds.count == 1)
        let cred = try #require(creds.first)
        #expect(cred.utilisateurID == membre.utilisateur.id)
        #expect(cred.identifiant == membre.utilisateur.identifiant)
        #expect(cred.codeEquipe == "GARN26")
        #expect(cred.motDePasseClair.isEmpty,
                "Invariant sécurité : jamais de mot de passe en clair (SIWA strict)")
        #expect(cred.joueurEquipeID == nil, "Sans joueur fourni, pas de liaison roster")
    }

    // MARK: - Liaison JoueurEquipe

    @Test("creerMembre lie le JoueurEquipe (identifiant + utilisateurID croisés)")
    func liaisonJoueurEquipe() throws {
        // Arrange
        let context = try creerContexteEnMemoire()
        let joueur = JoueurEquipe(nom: "Tremblay", prenom: "Jean", numero: 7, poste: .passeur)
        joueur.codeEquipe = "ELANS01"
        context.insert(joueur)
        var exclusions: Set<String> = []

        // Act
        let membre = MembreFactory.creerMembre(
            prenom: "Jean", nom: "Tremblay", role: .etudiant,
            codeEquipe: "ELANS01", joueur: joueur,
            context: context, exclusions: &exclusions
        )
        try context.save()

        // Assert — liens croisés Utilisateur ↔ JoueurEquipe
        #expect(joueur.identifiant == membre.utilisateur.identifiant)
        #expect(joueur.utilisateurID == membre.utilisateur.id)
        #expect(membre.utilisateur.joueurEquipeID == joueur.id)
        #expect(membre.utilisateur.numero == 7, "Le numéro de maillot doit être recopié")
        #expect(membre.utilisateur.posteRaw == PosteJoueur.passeur.rawValue)

        // Le marqueur CredentialAthlete pointe aussi vers le joueur
        let cred = try #require(try fetchCredentials(context).first)
        #expect(cred.joueurEquipeID == joueur.id)
    }

    // MARK: - Identifiant souhaité

    @Test("identifiantSouhaite est respecté (minuscules, sans espaces)")
    func identifiantSouhaiteRespecte() throws {
        // Arrange
        let context = try creerContexteEnMemoire()
        var exclusions: Set<String> = []

        // Act
        let membre = MembreFactory.creerMembre(
            prenom: "Jean", nom: "Perso", role: .etudiant,
            codeEquipe: "EQ1", identifiantSouhaite: " Jean.Perso ",
            context: context, exclusions: &exclusions
        )

        // Assert
        #expect(membre.utilisateur.identifiant == "jean.perso",
                "L'identifiant souhaité doit être normalisé (minuscules, trim)")
        #expect(exclusions.contains("jean.perso"),
                "L'identifiant choisi doit être réservé dans les exclusions")
    }

    @Test("identifiantSouhaite vide → auto-génération prenom.nom.XXXX")
    func identifiantSouhaiteVideAutoGenere() throws {
        // Arrange
        let context = try creerContexteEnMemoire()
        var exclusions: Set<String> = []

        // Act
        let membre = MembreFactory.creerMembre(
            prenom: "Marie", nom: "Roy", role: .etudiant,
            codeEquipe: "EQ1", identifiantSouhaite: "   ",
            context: context, exclusions: &exclusions
        )

        // Assert
        #expect(membre.utilisateur.identifiant.hasPrefix("marie.roy."),
                "Souhait vide → fallback auto-génération")
    }

    // MARK: - Exclusions (lot du wizard)

    @Test("exclusions évitent les doublons en mémoire — 2 créations même prénom/nom → identifiants différents")
    func exclusionsEvitentDoublons() throws {
        // Arrange
        let context = try creerContexteEnMemoire()
        var exclusions: Set<String> = []

        // Act — deux membres homonymes créés dans le même lot, sans save intermédiaire
        let m1 = MembreFactory.creerMembre(
            prenom: "Jean", nom: "Dupont", role: .etudiant,
            codeEquipe: "EQ1", context: context, exclusions: &exclusions
        )
        let m2 = MembreFactory.creerMembre(
            prenom: "Jean", nom: "Dupont", role: .etudiant,
            codeEquipe: "EQ1", context: context, exclusions: &exclusions
        )

        // Assert
        #expect(m1.utilisateur.identifiant != m2.utilisateur.identifiant,
                "Deux homonymes du même lot doivent recevoir des identifiants différents")
        #expect(exclusions.contains(m1.utilisateur.identifiant))
        #expect(exclusions.contains(m2.utilisateur.identifiant))
        #expect(exclusions.count == 2)
        #expect(m1.utilisateur.codeInvitation != m2.utilisateur.codeInvitation,
                "Chaque membre reçoit son propre code d'invitation")
    }

    // MARK: - Libellé de rôle

    @Test("Libellé de rôle dans le récap : Athlète / Assistant / Coach")
    func libelleRoleRecap() throws {
        // Arrange
        let context = try creerContexteEnMemoire()
        var exclusions: Set<String> = []

        // Act
        let athlete = MembreFactory.creerMembre(
            prenom: "A", nom: "Thlete", role: .etudiant,
            codeEquipe: "EQ1", context: context, exclusions: &exclusions
        )
        let assistant = MembreFactory.creerMembre(
            prenom: "B", nom: "Assist", role: .assistantCoach,
            codeEquipe: "EQ1", context: context, exclusions: &exclusions
        )
        let coach = MembreFactory.creerMembre(
            prenom: "C", nom: "Oach", role: .coach,
            codeEquipe: "EQ1", context: context, exclusions: &exclusions
        )

        // Assert
        #expect(athlete.recap.role == "Athlète")
        #expect(assistant.recap.role == "Assistant")
        #expect(coach.recap.role == "Coach")
    }
}
