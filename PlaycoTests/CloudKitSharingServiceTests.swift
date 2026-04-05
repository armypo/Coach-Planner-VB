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

    // MARK: - Import Utilisateur

    @Test("Importer un utilisateur depuis CKRecord")
    func importerUtilisateur() throws {
        let service = CloudKitSharingService()
        let context = try creerContexteEnMemoire()

        let record = CKRecord(recordType: "PlaycoUtilisateur")
        let uuid = UUID()
        record["utilisateurID"] = uuid.uuidString
        record["identifiant"] = "test.import"
        record["motDePasseHash"] = "abc123hash"
        record["sel"] = "sel456"
        record["prenom"] = "Jean"
        record["nom"] = "Tremblay"
        record["roleRaw"] = "Étudiant"
        record["codeEcole"] = "EQUIPE001"
        record["estActif"] = 1
        record["numero"] = 7
        record["posteRaw"] = "Passeur"

        service.importerUtilisateur(from: record, context: context)
        try context.save()

        let desc = FetchDescriptor<Utilisateur>()
        let users = try context.fetch(desc)
        #expect(users.count == 1)

        let user = users[0]
        #expect(user.id == uuid)
        #expect(user.identifiant == "test.import")
        #expect(user.prenom == "Jean")
        #expect(user.nom == "Tremblay")
        #expect(user.sel == "sel456")
        #expect(user.numero == 7)
        #expect(user.posteRaw == "Passeur")
    }

    @Test("Import utilisateur existant — met à jour si remote plus récent")
    func importerUtilisateurMiseAJour() throws {
        let service = CloudKitSharingService()
        let context = try creerContexteEnMemoire()

        let uuid = UUID()
        let existant = Utilisateur(identifiant: "existant", motDePasseHash: "old", prenom: "Old", nom: "Name", role: .etudiant)
        existant.id = uuid
        existant.dateModification = Date(timeIntervalSince1970: 1000)
        context.insert(existant)
        try context.save()

        let record = CKRecord(recordType: "PlaycoUtilisateur")
        record["utilisateurID"] = uuid.uuidString
        record["identifiant"] = "existant"
        record["motDePasseHash"] = "newhash"
        record["sel"] = "newsel"
        record["prenom"] = "Old"
        record["nom"] = "Name"
        record["roleRaw"] = "Étudiant"
        record["codeEcole"] = ""
        record["estActif"] = 1
        record["dateModification"] = Date(timeIntervalSince1970: 2000)

        service.importerUtilisateur(from: record, context: context)

        #expect(existant.motDePasseHash == "newhash")
        #expect(existant.sel == "newsel")
    }

    @Test("Import utilisateur existant — ignore si local plus récent")
    func importerUtilisateurIgnore() throws {
        let service = CloudKitSharingService()
        let context = try creerContexteEnMemoire()

        let uuid = UUID()
        let existant = Utilisateur(identifiant: "local", motDePasseHash: "localhash", prenom: "L", nom: "N", role: .etudiant)
        existant.id = uuid
        existant.dateModification = Date(timeIntervalSince1970: 3000)
        context.insert(existant)
        try context.save()

        let record = CKRecord(recordType: "PlaycoUtilisateur")
        record["utilisateurID"] = uuid.uuidString
        record["identifiant"] = "local"
        record["motDePasseHash"] = "remotehash"
        record["sel"] = "remotesel"
        record["prenom"] = "L"
        record["nom"] = "N"
        record["roleRaw"] = "Étudiant"
        record["codeEcole"] = ""
        record["estActif"] = 1
        record["dateModification"] = Date(timeIntervalSince1970: 1000) // Plus ancien

        service.importerUtilisateur(from: record, context: context)

        #expect(existant.motDePasseHash == "localhash", "Ne doit pas être écrasé")
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
