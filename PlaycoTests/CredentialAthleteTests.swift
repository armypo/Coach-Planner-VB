//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Testing
import Foundation
import SwiftData
@testable import Playco

@Suite("CredentialAthlete — stockage mdp en clair + FiltreParEquipe")
struct CredentialAthleteTests {

    private func contexteEnMemoire() throws -> ModelContext {
        let schema = Schema([CredentialAthlete.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    @Test("Création avec tous les champs obligatoires (defaults pour CloudKit)")
    func creationAvecDefauts() throws {
        let userID = UUID()
        let cred = CredentialAthlete(
            utilisateurID: userID,
            joueurEquipeID: nil,
            identifiant: "jean.dupont.1234",
            motDePasseClair: "ABCDE_23",
            codeEquipe: "ELANS01"
        )
        #expect(cred.utilisateurID == userID)
        #expect(cred.joueurEquipeID == nil)
        #expect(cred.identifiant == "jean.dupont.1234")
        #expect(cred.motDePasseClair == "ABCDE_23")
        #expect(cred.codeEquipe == "ELANS01")
        // Timestamps par défaut
        #expect(abs(cred.dateCreation.timeIntervalSinceNow) < 1)
        #expect(abs(cred.dateModification.timeIntervalSinceNow) < 1)
    }

    @Test("Assistant : joueurEquipeID nil à la construction")
    func assistantSansJoueurEquipe() throws {
        let cred = CredentialAthlete(
            utilisateurID: UUID(),
            identifiant: "marc.lemieux.7788",
            motDePasseClair: "QRSTV_45",
            codeEquipe: "ELANS01"
        )
        #expect(cred.joueurEquipeID == nil)
    }

    @Test("Round-trip save/fetch in-memory conserve tous les champs")
    func roundTripSaveFetch() throws {
        let context = try contexteEnMemoire()
        let userID = UUID()
        let joueurID = UUID()
        let cred = CredentialAthlete(
            utilisateurID: userID,
            joueurEquipeID: joueurID,
            identifiant: "lea.martin.4821",
            motDePasseClair: "XYZAB_67",
            codeEquipe: "DIAB26"
        )
        context.insert(cred)
        try context.save()

        let all = try context.fetch(FetchDescriptor<CredentialAthlete>())
        #expect(all.count == 1)
        let recup = try #require(all.first)
        #expect(recup.utilisateurID == userID)
        #expect(recup.joueurEquipeID == joueurID)
        #expect(recup.identifiant == "lea.martin.4821")
        #expect(recup.motDePasseClair == "XYZAB_67")
        #expect(recup.codeEquipe == "DIAB26")
    }

    @Test("FiltreParEquipe isole les credentials par codeEquipe")
    func filtreParEquipeIsoleParCodeEquipe() throws {
        let context = try contexteEnMemoire()

        context.insert(CredentialAthlete(
            utilisateurID: UUID(),
            identifiant: "a.a.1111",
            motDePasseClair: "AAAAA_22",
            codeEquipe: "EQUIPE_A"
        ))
        context.insert(CredentialAthlete(
            utilisateurID: UUID(),
            identifiant: "b.b.2222",
            motDePasseClair: "BBBBB_33",
            codeEquipe: "EQUIPE_B"
        ))
        try context.save()

        let all = try context.fetch(FetchDescriptor<CredentialAthlete>())
        #expect(all.count == 2)

        let filtresA = all.filtreEquipe("EQUIPE_A")
        #expect(filtresA.count == 1)
        #expect(filtresA.first?.identifiant == "a.a.1111")

        let filtresB = all.filtreEquipe("EQUIPE_B")
        #expect(filtresB.count == 1)
        #expect(filtresB.first?.identifiant == "b.b.2222")
    }
}
