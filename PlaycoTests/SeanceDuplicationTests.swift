//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//

import Testing
import Foundation
import SwiftData
@testable import Playco

@Suite("Duplication de séance")
@MainActor
struct SeanceDuplicationTests {

    private func creerContexteEnMemoire() throws -> ModelContext {
        let schema = Schema([Seance.self, Exercice.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    @Test("La copie conserve le codeEquipe de la source (anti-fuite inter-équipes)")
    func copieConserveCodeEquipe() throws {
        let context = try creerContexteEnMemoire()
        let source = Seance(nom: "Attaque R1")
        source.codeEquipe = "AAAA2345"
        context.insert(source)

        let copie = Seance.dupliquer(source, dans: context)

        #expect(copie.codeEquipe == "AAAA2345")
        #expect(copie.nom == "Attaque R1 (copie)")
        #expect(copie.id != source.id)
    }

    @Test("La copie n'apparaît pas dans les listes d'une autre équipe")
    func copieInvisiblePourAutreEquipe() throws {
        let context = try creerContexteEnMemoire()
        let source = Seance(nom: "Défense")
        source.codeEquipe = "AAAA2345"
        context.insert(source)

        let copie = Seance.dupliquer(source, dans: context)

        // filtreEquipe inclut les codeEquipe vides (compat legacy) : un
        // codeEquipe non copié ferait apparaître la copie dans TOUTES les équipes.
        let toutes = [source, copie]
        #expect(toutes.filtreEquipe("BBBB9999").isEmpty)
        #expect(toutes.filtreEquipe("AAAA2345").count == 2)
    }

    @Test("Les exercices sont copiés avec ordre, notes, durée et données terrain")
    func exercicesCopies() throws {
        let context = try creerContexteEnMemoire()
        let source = Seance(nom: "Service-réception")
        source.codeEquipe = "AAAA2345"
        context.insert(source)

        let exo = Exercice(nom: "Papillon", ordre: 2, duree: 10)
        exo.notes = "3 ballons par vague"
        exo.etapesData = Data([0x01, 0x02])
        exo.seance = source
        context.insert(exo)
        source.exercices = [exo]

        let copie = Seance.dupliquer(source, dans: context)
        let exercices = copie.exercices ?? []

        #expect(exercices.count == 1)
        let copieExo = try #require(exercices.first)
        #expect(copieExo.nom == "Papillon")
        #expect(copieExo.ordre == 2)
        #expect(copieExo.duree == 10)
        #expect(copieExo.notes == "3 ballons par vague")
        #expect(copieExo.etapesData == Data([0x01, 0x02]))
        #expect(copieExo.id != exo.id)
    }
}
