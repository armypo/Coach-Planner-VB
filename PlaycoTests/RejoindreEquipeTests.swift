//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Tests de la logique de jointure d'équipe (réclamation locale par code
//  d'invitation) et du prédicat de recherche rétrocompatible v2.0.1.
//

import Testing
import Foundation
import SwiftData
@testable import Playco

@Suite("CloudKitSharingService — Réclamation locale (jointure SIWA)")
@MainActor
struct RejoindreEquipeTests {

    private func contexte() throws -> ModelContext {
        let schema = Schema([Utilisateur.self, JoueurEquipe.self, Equipe.self,
                             Etablissement.self, ProfilCoach.self, AssistantCoach.self,
                             CreneauRecurrent.self, MatchCalendrier.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    private func membreRoster(codeEquipe: String, codeInvitation: String, context: ModelContext) -> Utilisateur {
        let u = Utilisateur(identifiant: "rost.er", motDePasseHash: "", prenom: "Ros", nom: "Ter", role: .etudiant)
        u.codeEquipe = codeEquipe
        u.codeInvitation = codeInvitation
        u.appleUserID = ""   // ligne non réclamée
        context.insert(u)
        return u
    }

    @Test("Réclame la ligne libre correspondante et y rattache l'appleUserID")
    func reclameSucces() throws {
        let service = CloudKitSharingService()
        let context = try contexte()
        let membre = membreRoster(codeEquipe: "EQU1", codeInvitation: "ABC123", context: context)
        try context.save()

        let reclame = service.reclamerMembreLocal(codeEquipe: "EQU1", codeInvitation: "ABC123",
                                                  appleUserID: "001.apple", context: context)
        #expect(reclame?.id == membre.id)
        #expect(reclame?.appleUserID == "001.apple")
    }

    @Test("Insensible à la casse et aux espaces sur les codes")
    func reclameNormalise() throws {
        let service = CloudKitSharingService()
        let context = try contexte()
        _ = membreRoster(codeEquipe: "EQU1", codeInvitation: "ABC123", context: context)
        try context.save()

        let reclame = service.reclamerMembreLocal(codeEquipe: " equ1 ", codeInvitation: "abc123",
                                                  appleUserID: "001.apple", context: context)
        #expect(reclame != nil)
        #expect(reclame?.appleUserID == "001.apple")
    }

    @Test("Aucune ligne si le code d'invitation ne correspond pas")
    func reclameAucunMatch() throws {
        let service = CloudKitSharingService()
        let context = try contexte()
        _ = membreRoster(codeEquipe: "EQU1", codeInvitation: "ABC123", context: context)
        try context.save()

        #expect(service.reclamerMembreLocal(codeEquipe: "EQU1", codeInvitation: "ZZZ999",
                                            appleUserID: "001.apple", context: context) == nil)
    }

    @Test("Ne réclame pas une ligne déjà liée à un autre Apple ID")
    func reclameDejaLiee() throws {
        let service = CloudKitSharingService()
        let context = try contexte()
        let membre = membreRoster(codeEquipe: "EQU1", codeInvitation: "ABC123", context: context)
        membre.appleUserID = "autre.apple"   // déjà réclamée
        try context.save()

        #expect(service.reclamerMembreLocal(codeEquipe: "EQU1", codeInvitation: "ABC123",
                                            appleUserID: "001.apple", context: context) == nil)
    }

    @Test("Idempotent : Apple ID déjà lié dans l'équipe → retourne le membre existant (pas de doublon)")
    func reclameIdempotent() throws {
        let service = CloudKitSharingService()
        let context = try contexte()
        // Membre A déjà réclamé par cet Apple ID.
        let dejaLie = membreRoster(codeEquipe: "EQU1", codeInvitation: "AAA111", context: context)
        dejaLie.appleUserID = "001.apple"
        // Membre B libre dans la même équipe (autre invitation).
        let libre = membreRoster(codeEquipe: "EQU1", codeInvitation: "BBB222", context: context)
        try context.save()

        // Tenter de réclamer la ligne B avec le MÊME Apple ID → doit renvoyer A, pas B.
        let reclame = service.reclamerMembreLocal(codeEquipe: "EQU1", codeInvitation: "BBB222",
                                                  appleUserID: "001.apple", context: context)
        #expect(reclame?.id == dejaLie.id, "Doit renvoyer le membre déjà lié")
        #expect(libre.appleUserID == "", "La ligne libre ne doit PAS être réclamée (pas de doublon)")
    }

    @Test("Anti-escalade : refuse de réclamer une ligne coach/admin")
    func reclameAntiEscalade() throws {
        let service = CloudKitSharingService()
        let context = try contexte()
        // Ligne de roster avec rôle coach (ne doit JAMAIS être réclamable via jointure).
        let coachLine = membreRoster(codeEquipe: "EQU1", codeInvitation: "COA111", context: context)
        coachLine.role = .coach
        let adminLine = membreRoster(codeEquipe: "EQU1", codeInvitation: "ADM222", context: context)
        adminLine.role = .admin
        try context.save()

        #expect(service.reclamerMembreLocal(codeEquipe: "EQU1", codeInvitation: "COA111",
                                            appleUserID: "001.apple", context: context) == nil,
                "Ne doit pas réclamer une ligne coach")
        #expect(service.reclamerMembreLocal(codeEquipe: "EQU1", codeInvitation: "ADM222",
                                            appleUserID: "002.apple", context: context) == nil,
                "Ne doit pas réclamer une ligne admin")
        #expect(coachLine.appleUserID == "", "La ligne coach ne doit pas être rattachée")
    }

    @Test("Codes vides → nil")
    func reclameCodesVides() throws {
        let service = CloudKitSharingService()
        let context = try contexte()
        _ = membreRoster(codeEquipe: "EQU1", codeInvitation: "ABC123", context: context)
        try context.save()

        #expect(service.reclamerMembreLocal(codeEquipe: "", codeInvitation: "ABC123",
                                            appleUserID: "001.apple", context: context) == nil)
        #expect(service.reclamerMembreLocal(codeEquipe: "EQU1", codeInvitation: "",
                                            appleUserID: "001.apple", context: context) == nil)
        #expect(service.reclamerMembreLocal(codeEquipe: "EQU1", codeInvitation: "ABC123",
                                            appleUserID: "", context: context) == nil)
    }
}

@Suite("CloudKitSharingService — Prédicat rétrocompatible v2.0.1")
struct PredicatRechercheTests {

    @Test("UtilisateurPartage requête codeEquipe ET codeEcole (backward-compat)")
    func predicatUtilisateurOR() {
        let p = CloudKitSharingService.predicatRecherche(estUtilisateur: true, codeEquipe: "EQU1")
        let format = p.predicateFormat
        #expect(format.contains("codeEquipe"))
        #expect(format.contains("codeEcole"), "Doit inclure codeEcole pour trouver les records pré-v2.0.1")
    }

    @Test("Autres types requêtent uniquement codeEquipe")
    func predicatAutresCodeEquipe() {
        let p = CloudKitSharingService.predicatRecherche(estUtilisateur: false, codeEquipe: "EQU1")
        let format = p.predicateFormat
        #expect(format.contains("codeEquipe"))
        #expect(!format.contains("codeEcole"))
    }
}

@Suite("CredentialRecap — codes d'invitation (v2.0.1)")
struct CredentialRecapTests {

    @Test("Porte le code d'équipe et le code d'invitation (plus de mot de passe)")
    func porteLesCodes() {
        let r = CredentialRecap(nomComplet: "Jo Hueur", identifiant: "jo.hueur",
                                codeEquipe: "EQU1", codeInvitation: "ABC123", role: "Athlète")
        #expect(r.codeEquipe == "EQU1")
        #expect(r.codeInvitation == "ABC123")
        #expect(r.role == "Athlète")
    }
}
