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
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, allowsSave: true, groupContainer: .none, cloudKitDatabase: .none)
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
        #expect(user.numero == 7)
        #expect(user.posteRaw == "Passeur")
        // SÉCURITÉ v2.0.1 : aucun secret n'est importé depuis la base publique.
        #expect(user.motDePasseHash == "", "Le hash ne doit JAMAIS provenir du public DB")
        #expect(user.sel == nil, "Le sel ne doit JAMAIS provenir du public DB")
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

        // SÉCURITÉ v2.0.1 : la mise à jour depuis le public DB n'écrase JAMAIS
        // les secrets locaux (le hash/sel restent inchangés ; auth via SIWA).
        #expect(existant.motDePasseHash == "old", "Le hash local ne doit pas être écrasé par le public DB")
        #expect(existant.sel == nil, "Le sel local ne doit pas être modifié par le public DB")
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

// MARK: - Garde-fou régression : aucun secret publié

@Suite("CloudKitSharingService — Sécurité publication")
struct CloudKitSharingSecuriteTests {

    @Test("champsPublicsUtilisateur ne contient AUCUN secret")
    func aucunSecretPublie() {
        let u = Utilisateur(identifiant: "coach.test", motDePasseHash: "HASH_SECRET",
                            prenom: "Coach", nom: "Test", role: .coach)
        u.sel = "SEL_SECRET"
        u.iterations = 600_000
        u.appleUserID = "001234.abcdef"
        u.codeEquipe = "EQU-1"

        let champs = CloudKitSharingService.champsPublicsUtilisateur(u, codeEquipe: "EQU-1")

        // Les clés sensibles ne doivent JAMAIS être publiées.
        #expect(champs["motDePasseHash"] == nil)
        #expect(champs["sel"] == nil)
        #expect(champs["iterations"] == nil)
        // Les clés de mapping attendues sont présentes.
        #expect(champs["codeEquipe"] != nil)
        #expect(champs["appleUserID"] != nil)
        #expect(champs["codeInvitation"] != nil)
        #expect(champs["roleRaw"] != nil)
    }

    @Test("codeEquipe fallback sur le champ utilisateur si paramètre vide")
    func codeEquipeFallback() {
        let u = Utilisateur(identifiant: "x", motDePasseHash: "", prenom: "X", nom: "Y", role: .etudiant)
        u.codeEquipe = "EQU-FALLBACK"
        let champs = CloudKitSharingService.champsPublicsUtilisateur(u, codeEquipe: "")
        #expect((champs["codeEquipe"] as? String) == "EQU-FALLBACK")
    }

    @Test("champsPublicsJoueur ne contient AUCUN secret (champs legacy gelés)")
    func aucunSecretJoueurPublie() {
        let j = JoueurEquipe(nom: "Roy", prenom: "Alex", numero: 10, poste: .passeur)
        j.motDePasseHash = "HASH_LEGACY"
        j.sel = "SEL_LEGACY"

        let champs = CloudKitSharingService.champsPublicsJoueur(j)

        #expect(champs["motDePasseHash"] == nil)
        #expect(champs["sel"] == nil)
        #expect(champs["joueurID"] != nil)
        #expect(champs["codeEquipe"] != nil)
    }
}

// MARK: - Plan de sync par rôle (E4 — parité D6)

@Suite("CloudKitSharingService — planSync (E4)")
struct CloudKitSharingPlanSyncTests {

    @Test("tous les rôles coach importent ET publient (assistant = head coach)")
    func rolesCoachBidirectionnels() {
        for role in [RoleUtilisateur.admin, .coach, .assistantCoach] {
            let plan = CloudKitSharingService.planSync(role: role)
            #expect(plan.importe, "\(role.rawValue) doit importer")
            #expect(plan.publie, "\(role.rawValue) doit publier")
        }
    }

    @Test(".etudiant (legacy) importe seulement — jamais d'écriture publique")
    func etudiantLectureSeule() {
        let plan = CloudKitSharingService.planSync(role: .etudiant)
        #expect(plan.importe)
        #expect(!plan.publie)
    }
}

// MARK: - Mappings publics E1 (fonctions pures, parité assistant D6)

@Suite("CloudKitSharingService — Mappings publics (E1)")
@MainActor
struct CloudKitSharingMappingsTests {

    @Test("champsPublicsJoueur (E′ §7) : seul un BOOLÉEN de disponibilité transite — jamais le motif santé ni l'attestation")
    func joueurDisponibiliteEtAttestation() {
        let j = JoueurEquipe(nom: "Roy", prenom: "Alex", numero: 10, poste: .passeur)
        j.codeEquipe = "EQU1"
        j.statutDisponibilite = .blesse
        j.consentementParentalAtteste = true
        j.dateAttestationConsentement = Date(timeIntervalSince1970: 1_700_000_000)
        j.attesteParNom = "Coach Dionne"

        let champs = CloudKitSharingService.champsPublicsJoueur(j)

        #expect((champs["estDisponible"] as? Int) == 0)
        // GARDE DE RÉGRESSION PII (Public DB world-readable) : le motif
        // d'indisponibilité (donnée de santé, souvent de mineurs) et le
        // registre d'attestation parentale ne se publient JAMAIS.
        #expect(champs["statutDisponibiliteRaw"] == nil)
        #expect(champs["consentementParentalAtteste"] == nil)
        #expect(champs["dateAttestationConsentement"] == nil)
        #expect(champs["attesteParNom"] == nil)
    }

    @Test("champsPublicsJoueur : joueur disponible → estDisponible = 1")
    func joueurDisponibiliteDefauts() {
        let j = JoueurEquipe(nom: "Roy", prenom: "Alex", numero: 10, poste: .passeur)

        let champs = CloudKitSharingService.champsPublicsJoueur(j)

        #expect((champs["estDisponible"] as? Int) == 1)
        #expect(champs["statutDisponibiliteRaw"] == nil)
        #expect(champs["attesteParNom"] == nil)
    }

    @Test("champsPublicsJoueur mappe le roster et les stats cumulées")
    func joueurRosterEtStats() {
        let j = JoueurEquipe(nom: "Roy", prenom: "Alex", numero: 10, poste: .passeur)
        j.codeEquipe = "EQU1"
        j.identifiant = "alex.roy"
        j.aces = 12
        j.attaquesReussies = 45
        j.manchettes = 30
        j.dateModification = Date(timeIntervalSince1970: 1_800_000_000)

        let champs = CloudKitSharingService.champsPublicsJoueur(j)

        #expect((champs["joueurID"] as? String) == j.id.uuidString)
        #expect((champs["nom"] as? String) == "Roy")
        #expect((champs["numero"] as? Int) == 10)
        #expect((champs["codeEquipe"] as? String) == "EQU1")
        #expect((champs["aces"] as? Int) == 12)
        #expect((champs["attaquesReussies"] as? Int) == 45)
        #expect((champs["manchettes"] as? Int) == 30)
        #expect((champs["dateModification"] as? Date) == Date(timeIntervalSince1970: 1_800_000_000))
    }

    @Test("champsPublicsEquipe mappe les champs d'équipe avec dateModification")
    func equipeMapping() {
        let e = Equipe(nom: "Élans")
        e.codeEquipe = "ELANS001"
        e.categorieRaw = "Masculin"
        e.divisionRaw = "Division 1"
        e.saison = "2026-2027"
        e.dateModification = Date(timeIntervalSince1970: 1_800_000_000)

        let champs = CloudKitSharingService.champsPublicsEquipe(e)

        #expect((champs["codeEquipe"] as? String) == "ELANS001")
        #expect((champs["nom"] as? String) == "Élans")
        #expect((champs["categorieRaw"] as? String) == "Masculin")
        #expect((champs["divisionRaw"] as? String) == "Division 1")
        #expect((champs["saison"] as? String) == "2026-2027")
        #expect((champs["dateModification"] as? Date) == Date(timeIntervalSince1970: 1_800_000_000))
    }

    @Test("champsPublicsEtablissement mappe l'établissement sous le codeEquipe")
    func etablissementMapping() {
        let etab = Etablissement(nom: "Cégep Garneau", type: .cegep, ville: "Québec", province: "QC")

        let champs = CloudKitSharingService.champsPublicsEtablissement(etab, codeEquipe: "EQU1")

        #expect((champs["codeEquipe"] as? String) == "EQU1")
        #expect((champs["nom"] as? String) == "Cégep Garneau")
        #expect((champs["typeRaw"] as? String) == TypeEtablissement.cegep.rawValue)
        #expect((champs["ville"] as? String) == "Québec")
        #expect((champs["province"] as? String) == "QC")
    }

    @Test("champsPublicsSeance mappe les métadonnées de séance/match")
    func seanceMapping() {
        let s = Seance(nom: "Match vs Titans", date: Date(timeIntervalSince1970: 1_900_000_000), typeSeance: .match)
        s.codeEquipe = "EQU1"
        s.lieu = "Gymnase A"
        s.adversaire = "Titans"
        s.scoreEquipe = 3
        s.scoreAdversaire = 1
        s.estArchivee = false
        s.dateModification = Date(timeIntervalSince1970: 1_800_000_000)

        let champs = CloudKitSharingService.champsPublicsSeance(s)

        #expect((champs["seanceID"] as? String) == s.id.uuidString)
        #expect((champs["codeEquipe"] as? String) == "EQU1")
        #expect((champs["nom"] as? String) == "Match vs Titans")
        #expect((champs["typeSeanceRaw"] as? String) == TypeSeance.match.rawValue)
        #expect((champs["adversaire"] as? String) == "Titans")
        #expect((champs["scoreEquipe"] as? Int) == 3)
        #expect((champs["scoreAdversaire"] as? Int) == 1)
        #expect((champs["estArchivee"] as? Int) == 0)
        #expect((champs["dateModification"] as? Date) == Date(timeIntervalSince1970: 1_800_000_000))
    }
}
