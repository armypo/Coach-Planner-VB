//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//

import Testing
import Foundation
import SwiftData
@testable import Playco

@Suite("Seance.sets — cache de décodage")
@MainActor
struct SeanceSetsCacheTests {

    private func creerSeance() throws -> Seance {
        let schema = Schema([Seance.self, Exercice.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, allowsSave: true, groupContainer: .none, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let seance = Seance(nom: "Match test", typeSeance: .match)
        ModelContext(container).insert(seance)
        return seance
    }

    @Test("set puis get retourne la même valeur et recalcule le score global")
    func setPuisGet() throws {
        let seance = try creerSeance()

        seance.sets = [
            SetScore(numero: 1, scoreEquipe: 25, scoreAdversaire: 20),
            SetScore(numero: 2, scoreEquipe: 25, scoreAdversaire: 23),
            SetScore(numero: 3, scoreEquipe: 18, scoreAdversaire: 25)
        ]

        #expect(seance.sets.count == 3)
        #expect(seance.sets[0].scoreEquipe == 25)
        #expect(seance.scoreEquipe == 2)      // sets gagnés
        #expect(seance.scoreAdversaire == 1)  // sets perdus
        #expect(seance.resultat == .victoire)
    }

    @Test("lectures répétées restent cohérentes (chemin caché)")
    func lecturesRepetees() throws {
        let seance = try creerSeance()
        seance.sets = [SetScore(numero: 1, scoreEquipe: 25, scoreAdversaire: 10)]

        // Plusieurs lectures successives (le cache doit servir la même valeur)
        for _ in 0..<5 {
            #expect(seance.sets.count == 1)
            #expect(seance.sets[0].scoreAdversaire == 10)
        }
    }

    @Test("mutation externe de setsData invalide le cache (simulation sync CloudKit)")
    func mutationExterneInvalideCache() throws {
        let seance = try creerSeance()
        seance.sets = [SetScore(numero: 1, scoreEquipe: 25, scoreAdversaire: 20)]
        #expect(seance.sets.count == 1) // amorce le cache

        // La sync CloudKit écrit setsData directement, sans passer par le setter
        let distant = [
            SetScore(numero: 1, scoreEquipe: 25, scoreAdversaire: 20),
            SetScore(numero: 2, scoreEquipe: 22, scoreAdversaire: 25)
        ]
        seance.setsData = try JSONCoderCache.encoder.encode(distant)

        #expect(seance.sets.count == 2) // le cache périmé ne doit PAS être servi
        #expect(seance.sets[1].scoreAdversaire == 25)
    }

    @Test("setsData nil retourne une liste vide")
    func setsDataNil() throws {
        let seance = try creerSeance()
        #expect(seance.sets.isEmpty)
    }
}
