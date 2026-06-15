//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Testing
import Foundation
import SwiftData
import CloudKit
@testable import Playco

@Suite("CloudKitSharingService — Import")
struct CloudKitSharingServiceTests {

    private func creerContexteEnMemoire() throws -> ModelContext {
        let schema = Schema([Utilisateur.self, JoueurEquipe.self, Equipe.self,
                             Etablissement.self, ProfilCoach.self, AssistantCoach.self,
                             CreneauRecurrent.self, MatchCalendrier.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    // MARK: - SÉCURITÉ : aucun credential publié en Public DB

    @Test("publierUtilisateur n'émet AUCUN matériel dérivé du mot de passe")
    func publicationSansCredentials() throws {
        let user = Utilisateur(
            identifiant: "marie.tremblay.1234",
            motDePasseHash: "HASH_SECRET_NE_DOIT_PAS_FUIR",
            prenom: "Marie",
            nom: "Tremblay",
            role: .etudiant,
            codeEcole: "EQ001"
        )
        user.sel = "SEL_SECRET"
        user.iterations = 600_000
        user.numero = 7
        user.posteRaw = "Passeur"

        let record = CloudKitSharingService.construireRecordUtilisateur(user)

        // Garde de régression : ces clés ne doivent JAMAIS atterrir en Public DB.
        #expect(record["motDePasseHash"] == nil, "Le hash ne doit jamais être publié")
        #expect(record["sel"] == nil, "Le sel ne doit jamais être publié")
        #expect(record["iterations"] == nil, "Les itérations ne doivent jamais être publiées")

        // Profil non sensible attendu, lui, présent.
        #expect((record["identifiant"] as? String) == "marie.tremblay.1234")
        #expect((record["prenom"] as? String) == "Marie")
        #expect((record["roleRaw"] as? String) == RoleUtilisateur.etudiant.rawValue)
        #expect((record["numero"] as? Int) == 7)
    }

    // MARK: - SÉCURITÉ : clamp de rôle à la jonction

    @Test("roleJonctionAutorise — étudiant et assistant autorisés")
    func roleJonctionAutoriseOK() {
        #expect(CloudKitSharingService.roleJonctionAutorise(RoleUtilisateur.etudiant.rawValue) == .etudiant)
        #expect(CloudKitSharingService.roleJonctionAutorise(RoleUtilisateur.assistantCoach.rawValue) == .assistantCoach)
    }

    @Test("roleJonctionAutorise — coach/admin rejetés (anti-escalade)")
    func roleJonctionAutoriseRejet() {
        #expect(CloudKitSharingService.roleJonctionAutorise(RoleUtilisateur.coach.rawValue) == nil)
        #expect(CloudKitSharingService.roleJonctionAutorise(RoleUtilisateur.admin.rawValue) == nil)
        #expect(CloudKitSharingService.roleJonctionAutorise("RoleInexistant") == nil)
        #expect(CloudKitSharingService.roleJonctionAutorise("") == nil)
    }

    // MARK: - Import Joueur

    @Test("Importer un joueur depuis CKRecord")
    func importerJoueur() throws {
        let service = CloudKitSharingService()
        let context = try creerContexteEnMemoire()

        let uuid = UUID()
        let record = CKRecord(recordType: "PlaycoJoueur")
        record["joueurID"] = uuid.uuidString
        record["nom"] = "Durand"
        record["prenom"] = "Marie"
        record["numero"] = 12
        record["posteRaw"] = "Libéro"
        record["codeEquipe"] = "EQ001"
        record["identifiant"] = "marie.durand"
        record["motDePasseHash"] = "hash789"
        record["sel"] = "sel789"

        service.importerJoueur(from: record, context: context)
        try context.save()

        let desc = FetchDescriptor<JoueurEquipe>()
        let joueurs = try context.fetch(desc)
        #expect(joueurs.count == 1)

        let joueur = joueurs[0]
        #expect(joueur.id == uuid)
        #expect(joueur.nom == "Durand")
        #expect(joueur.prenom == "Marie")
        #expect(joueur.numero == 12)
        #expect(joueur.posteRaw == "Libéro")
    }

    // MARK: - Import Équipe

    @Test("Importer une équipe depuis CKRecord")
    func importerEquipe() throws {
        let service = CloudKitSharingService()
        let context = try creerContexteEnMemoire()

        let record = CKRecord(recordType: "PlaycoEquipe")
        record["nom"] = "Élans"
        record["codeEquipe"] = "ELANS001"
        record["categorieRaw"] = "Masculin"
        record["divisionRaw"] = "Division 1"
        record["saison"] = "2025-2026"
        record["couleurPrincipalHex"] = "#FF6B35"
        record["couleurSecondaireHex"] = "#2563EB"

        service.importerEquipe(from: record, etablissement: nil, context: context)
        try context.save()

        let desc = FetchDescriptor<Equipe>()
        let equipes = try context.fetch(desc)
        #expect(equipes.count == 1)

        let equipe = equipes[0]
        #expect(equipe.nom == "Élans")
        #expect(equipe.codeEquipe == "ELANS001")
        #expect(equipe.categorieRaw == "Masculin")
    }

    // MARK: - Import Établissement

    @Test("Importer un établissement depuis CKRecord")
    func importerEtablissement() throws {
        let service = CloudKitSharingService()
        let context = try creerContexteEnMemoire()

        let record = CKRecord(recordType: "PlaycoEtablissement")
        record["nom"] = "Cégep Garneau"
        record["typeRaw"] = "Cégep"
        record["ville"] = "Québec"
        record["province"] = "QC"

        let etab = service.importerEtablissement(from: record, context: context)
        try context.save()

        #expect(etab.nom == "Cégep Garneau")
        #expect(etab.typeEtablissement == .cegep)
        #expect(etab.ville == "Québec")
    }

    // MARK: - Import Équipe avec Établissement

    @Test("Importer une équipe liée à un établissement")
    func importerEquipeAvecEtablissement() throws {
        let service = CloudKitSharingService()
        let context = try creerContexteEnMemoire()

        let etab = Etablissement(nom: "Test Uni", type: .universite, ville: "Montréal")
        context.insert(etab)

        let record = CKRecord(recordType: "PlaycoEquipe")
        record["nom"] = "Carabins"
        record["codeEquipe"] = "CAR001"
        record["categorieRaw"] = "Féminin"
        record["divisionRaw"] = "Division 1"
        record["saison"] = "2025"
        record["couleurPrincipalHex"] = "#0000FF"
        record["couleurSecondaireHex"] = "#FFFFFF"

        service.importerEquipe(from: record, etablissement: etab, context: context)
        try context.save()

        let desc = FetchDescriptor<Equipe>()
        let equipes = try context.fetch(desc)
        #expect(equipes.count == 1)
        #expect(equipes[0].etablissement?.nom == "Test Uni")
    }
}
