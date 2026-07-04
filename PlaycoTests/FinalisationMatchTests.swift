//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Tests d'intégration de la finalisation de match (revue Phase 1, finding
//  CRITICAL) : les StatsMatch créés PENDANT la finalisation doivent être
//  inclus dans la resynchronisation du cumul carrière — un @Query snapshot
//  ne les voit pas, le service doit les unir lui-même.
//

import Testing
import Foundation
import SwiftData
@testable import Playco

@Suite("Finalisation de match — cumuls incluant les nouveaux StatsMatch")
@MainActor
struct FinalisationMatchTests {

    private static let codeEquipe = "EQ_FINAL"

    /// Schéma = fermeture transitive complète des relations (même pattern que
    /// MatchLiveViewModelTests — un schéma partiel fait crasher les saves).
    private func creerContexte() throws -> ModelContext {
        let schema = Schema([
            Seance.self, Exercice.self, PointMatch.self, ActionRallye.self,
            StatsMatch.self, JoueurEquipe.self, Equipe.self, Etablissement.self,
            ProfilCoach.self, AssistantCoach.self, CreneauRecurrent.self,
            MatchCalendrier.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, allowsSave: true, groupContainer: .none, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func creerMatchLive() throws -> (contexte: ModelContext, seance: Seance,
                                             joueur: JoueurEquipe, points: [PointMatch]) {
        let contexte = try creerContexte()

        let seance = Seance(nom: "Match final", typeSeance: .match)
        seance.codeEquipe = Self.codeEquipe
        contexte.insert(seance)

        let joueur = JoueurEquipe(nom: "Roy", prenom: "Camille", numero: 9, poste: .recepteur)
        joueur.codeEquipe = Self.codeEquipe
        contexte.insert(joueur)

        // 3 kills + 1 erreur d'attaque en live — AUCUN StatsMatch préexistant.
        var points: [PointMatch] = []
        for type in [TypeActionPoint.kill, .kill, .kill, .erreurAttaque] {
            let p = PointMatch(seanceID: seance.id, set: 1, joueurID: joueur.id, typeAction: type)
            p.codeEquipe = Self.codeEquipe
            contexte.insert(p)
            points.append(p)
        }
        try contexte.save()
        return (contexte, seance, joueur, points)
    }

    @Test("finaliserStats — premier match live : le cumul carrière inclut le match finalisé")
    func premierMatchLiveCumulCorrect() throws {
        let (contexte, seance, joueur, points) = try creerMatchLive()

        // statsExistants simule le snapshot @Query AVANT insertion (vide).
        AgregateurStatsMatch.finaliserStats(
            seance: seance, points: points, actions: [],
            statsExistants: [], joueurs: [joueur],
            codeEquipe: Self.codeEquipe, contexte: contexte
        )

        #expect(joueur.attaquesReussies == 3)
        #expect(joueur.erreursAttaque == 1)
        #expect(joueur.attaquesTotales == 4)
        #expect(joueur.matchsJoues == 1)
        #expect(seance.statsEntrees == true)

        // Le StatsMatch créé porte bien le codeEquipe.
        let stats = try contexte.fetch(FetchDescriptor<StatsMatch>())
        #expect(stats.count == 1)
        #expect(stats.first?.codeEquipe == Self.codeEquipe)
    }

    @Test("finaliserStats — déjà finalisé : aucun double comptage (guard statsEntrees)")
    func dejaFinaliseInerte() throws {
        let (contexte, seance, joueur, points) = try creerMatchLive()

        AgregateurStatsMatch.finaliserStats(
            seance: seance, points: points, actions: [],
            statsExistants: [], joueurs: [joueur],
            codeEquipe: Self.codeEquipe, contexte: contexte
        )
        let statsApresPremiere = try contexte.fetch(FetchDescriptor<StatsMatch>())
        AgregateurStatsMatch.finaliserStats(
            seance: seance, points: points, actions: [],
            statsExistants: statsApresPremiere, joueurs: [joueur],
            codeEquipe: Self.codeEquipe, contexte: contexte
        )

        #expect(joueur.attaquesReussies == 3)
        #expect(joueur.matchsJoues == 1)
    }

    @Test("finaliserStats — cumul additionné sur un StatsMatch manuel préexistant")
    func statsManuellesPreexistantes() throws {
        let (contexte, seance, joueur, points) = try creerMatchLive()

        // Le coach avait saisi un box score partiel avant de finaliser.
        let manuel = StatsMatch(seanceID: seance.id, joueurID: joueur.id)
        manuel.codeEquipe = Self.codeEquipe
        manuel.aces = 2
        manuel.servicesTotaux = 2
        contexte.insert(manuel)
        try contexte.save()

        AgregateurStatsMatch.finaliserStats(
            seance: seance, points: points, actions: [],
            statsExistants: [manuel], joueurs: [joueur],
            codeEquipe: Self.codeEquipe, contexte: contexte
        )

        // Comportement historique : les compteurs live s'AJOUTENT au manuel.
        #expect(joueur.attaquesReussies == 3)
        #expect(joueur.aces == 2)
        let stats = try contexte.fetch(FetchDescriptor<StatsMatch>())
        #expect(stats.count == 1)
    }
}
