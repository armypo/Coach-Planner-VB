//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  Tests du modèle CredentialAthlete (private CloudKit DB).
//

import Testing
import Foundation
import SwiftData
@testable import Playco

@Suite("CredentialAthlete — modèle privé")
@MainActor
struct CredentialAthleteTests {

    private func nouveauContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: CredentialAthlete.self, Utilisateur.self,
            configurations: config
        )
    }

    @Test("Création avec defaults")
    func creationAvecDefaults() throws {
        let cred = CredentialAthlete(
            utilisateurID: UUID(),
            identifiant: "jean.dupont.1234",
            motDePasseClair: "ABCDE_23",
            codeEquipe: "DIAB26"
        )
        #expect(cred.joueurEquipeID == nil)
        #expect(cred.identifiant == "jean.dupont.1234")
        #expect(cred.motDePasseClair == "ABCDE_23")
        #expect(cred.codeEquipe == "DIAB26")
    }

    @Test("Round-trip save/fetch via ModelContainer")
    func roundTrip() throws {
        let container = try nouveauContainer()
        let cred = CredentialAthlete(
            utilisateurID: UUID(),
            joueurEquipeID: UUID(),
            identifiant: "alice.martin.0042",
            motDePasseClair: "XYZAB_45",
            codeEquipe: "GARN26"
        )
        container.mainContext.insert(cred)
        try container.mainContext.save()

        let all = try container.mainContext.fetch(FetchDescriptor<CredentialAthlete>())
        #expect(all.count == 1)
        #expect(all.first?.identifiant == "alice.martin.0042")
    }

    @Test("filtreEquipe ne retourne que les creds de l'équipe demandée")
    func filtreEquipeActive() throws {
        let container = try nouveauContainer()
        let credA = CredentialAthlete(
            utilisateurID: UUID(), identifiant: "a", motDePasseClair: "X", codeEquipe: "A1"
        )
        let credB = CredentialAthlete(
            utilisateurID: UUID(), identifiant: "b", motDePasseClair: "Y", codeEquipe: "B2"
        )
        container.mainContext.insert(credA)
        container.mainContext.insert(credB)
        try container.mainContext.save()

        let all = try container.mainContext.fetch(FetchDescriptor<CredentialAthlete>())
        let filtered = all.filtreEquipe("A1")
        #expect(filtered.count == 1)
        #expect(filtered.first?.identifiant == "a")
    }
}
