//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Tests de caractérisation d'AgregateurStatsMatch : la sémantique de
//  référence est le switch de MatchDetailView.finaliserMatch (agrégation
//  PointMatch + ActionRallye → compteurs par joueur). Écrits AVANT le
//  refactor pour verrouiller le comportement des 3 copies existantes.
//

import Testing
import Foundation
@testable import Playco

@Suite("AgregateurStatsMatch — caractérisation")
struct AgregateurStatsMatchTests {

    private let seanceID = UUID()
    private let joueurA = UUID()
    private let joueurB = UUID()

    // MARK: - Helpers

    private func point(_ type: TypeActionPoint, joueur: UUID?, set: Int = 1) -> PointMatch {
        PointMatch(seanceID: seanceID, set: set, joueurID: joueur, typeAction: type)
    }

    private func action(_ type: TypeActionRallye, joueur: UUID, set: Int = 1,
                        qualite: Int = 0) -> ActionRallye {
        let a = ActionRallye(seanceID: seanceID, set: set, joueurID: joueur, typeAction: type)
        a.qualite = qualite
        return a
    }

    // MARK: - Agrégation PointMatch (sémantique finaliserMatch)

    @Test("agreger — kill et erreur d'attaque incrémentent aussi les tentatives")
    func agregationAttaque() {
        let points = [
            point(.kill, joueur: joueurA),
            point(.kill, joueur: joueurA),
            point(.erreurAttaque, joueur: joueurA),
        ]

        let compteurs = AgregateurStatsMatch.agreger(points: points, actions: [])

        let a = compteurs[joueurA]
        #expect(a?.kills == 2)
        #expect(a?.erreursAttaque == 1)
        #expect(a?.tentativesAttaque == 3)
    }

    @Test("agreger — ace et erreur de service comptent dans les services totaux")
    func agregationService() {
        let points = [
            point(.ace, joueur: joueurA),
            point(.erreurService, joueur: joueurA),
            point(.ace, joueur: joueurA),
        ]

        let compteurs = AgregateurStatsMatch.agreger(points: points, actions: [])

        let a = compteurs[joueurA]
        #expect(a?.aces == 2)
        #expect(a?.erreursService == 1)
        #expect(a?.servicesTotaux == 3)
    }

    @Test("agreger — blocs : seul et legacy .bloc → blocsSeuls, assisté séparé")
    func agregationBlocs() {
        let points = [
            point(.blocSeul, joueur: joueurA),
            point(.bloc, joueur: joueurA),
            point(.blocAssiste, joueur: joueurA),
            point(.erreurBloc, joueur: joueurA),
        ]

        let compteurs = AgregateurStatsMatch.agreger(points: points, actions: [])

        let a = compteurs[joueurA]
        #expect(a?.blocsSeuls == 2)
        #expect(a?.blocsAssistes == 1)
        #expect(a?.erreursBloc == 1)
    }

    @Test("agreger — erreur de réception : erreur + réception totale, pas de réussie")
    func agregationErreurReception() {
        let points = [point(.erreurReception, joueur: joueurA)]

        let compteurs = AgregateurStatsMatch.agreger(points: points, actions: [])

        let a = compteurs[joueurA]
        #expect(a?.erreursReception == 1)
        #expect(a?.receptionsTotales == 1)
        #expect(a?.receptionsReussies == 0)
    }

    @Test("agreger — actions adverses et fautes d'équipe ignorées")
    func agregationIgnoreAdversaire() {
        let points = [
            point(.killAdversaire, joueur: joueurA),
            point(.aceAdversaire, joueur: joueurA),
            point(.blocAdversaire, joueur: joueurA),
            point(.erreurAttaqueAdversaire, joueur: joueurA),
            point(.erreurServiceAdversaire, joueur: joueurA),
            point(.erreurAdversaire, joueur: joueurA),
            point(.fauteJeu, joueur: joueurA),
            point(.erreurEquipe, joueur: joueurA),
        ]

        let compteurs = AgregateurStatsMatch.agreger(points: points, actions: [])

        // Le joueur apparaît (sets joués) mais aucun compteur de stat ne bouge.
        let a = compteurs[joueurA]
        #expect(a != nil)
        #expect(a?.kills == 0)
        #expect(a?.aces == 0)
        #expect(a?.blocsSeuls == 0)
        #expect(a?.tentativesAttaque == 0)
        #expect(a?.servicesTotaux == 0)
    }

    // MARK: - Agrégation ActionRallye (sémantique finaliserMatch)

    @Test("agreger — réception : totale toujours, réussie si qualité >= 2")
    func agregationReceptionQualite() {
        let actions = [
            action(.reception, joueur: joueurA, qualite: 3),
            action(.reception, joueur: joueurA, qualite: 2),
            action(.reception, joueur: joueurA, qualite: 1),
        ]

        let compteurs = AgregateurStatsMatch.agreger(points: [], actions: actions)

        let a = compteurs[joueurA]
        #expect(a?.receptionsTotales == 3)
        #expect(a?.receptionsReussies == 2)
    }

    @Test("agreger — manchette, passe décisive et tentative d'attaque comptées ; dig et service en jeu ignorés")
    func agregationRallyeAutres() {
        let actions = [
            action(.manchette, joueur: joueurA),
            action(.passeDecisive, joueur: joueurA),
            action(.tentativeAttaque, joueur: joueurA),
            action(.dig, joueur: joueurA),
            action(.serviceEnJeu, joueur: joueurA),
        ]

        let compteurs = AgregateurStatsMatch.agreger(points: [], actions: actions)

        let a = compteurs[joueurA]
        #expect(a?.manchettes == 1)
        #expect(a?.passesDecisives == 1)
        #expect(a?.tentativesAttaque == 1)
    }

    @Test("agreger — qualités de réception collectées pour la note 0-3 (erreur de réception = 0)")
    func agregationQualitesPourNote() {
        let actions = [
            action(.reception, joueur: joueurA, qualite: 3),
            action(.reception, joueur: joueurA, qualite: 2),
        ]
        let points = [point(.erreurReception, joueur: joueurA)]

        let compteurs = AgregateurStatsMatch.agreger(points: points, actions: actions)

        #expect(compteurs[joueurA]?.qualitesReception.sorted() == [0, 2, 3])
    }

    @Test("agreger — fautes, digs et services en jeu comptés (dashboard live)")
    func agregationCompteursDashboard() {
        let points = [
            point(.fauteJeu, joueur: joueurA),
            point(.erreurEquipe, joueur: joueurA),
        ]
        let actions = [
            action(.dig, joueur: joueurA),
            action(.serviceEnJeu, joueur: joueurA),
            action(.serviceEnJeu, joueur: joueurA),
        ]

        let compteurs = AgregateurStatsMatch.agreger(points: points, actions: actions)

        let a = compteurs[joueurA]
        #expect(a?.fautes == 2)
        #expect(a?.digs == 1)
        #expect(a?.servicesEnJeu == 2)
        // Ces compteurs ne touchent PAS les stats persistées (sémantique finaliserMatch).
        #expect(a?.erreursAttaque == 0)
        #expect(a?.servicesTotaux == 0)
    }

    // MARK: - Sets joués et multi-joueurs

    @Test("agreger — sets joués = sets distincts entre points et actions")
    func setsJoues() {
        let points = [
            point(.kill, joueur: joueurA, set: 1),
            point(.kill, joueur: joueurA, set: 1),
            point(.kill, joueur: joueurA, set: 3),
        ]
        let actions = [action(.manchette, joueur: joueurA, set: 2)]

        let compteurs = AgregateurStatsMatch.agreger(points: points, actions: actions)

        #expect(compteurs[joueurA]?.setsJoues == 3)
    }

    @Test("agreger — plusieurs joueurs séparés, point sans joueur ignoré")
    func multiJoueurs() {
        let points = [
            point(.kill, joueur: joueurA),
            point(.ace, joueur: joueurB),
            point(.erreurAdversaire, joueur: nil),
        ]

        let compteurs = AgregateurStatsMatch.agreger(points: points, actions: [])

        #expect(compteurs.count == 2)
        #expect(compteurs[joueurA]?.kills == 1)
        #expect(compteurs[joueurB]?.aces == 1)
    }
}

@Suite("AgregateurStatsMatch — resynchronisation des cumuls (B2)")
struct SyncCumulJoueurTests {

    private func creerJoueur() -> JoueurEquipe {
        JoueurEquipe(nom: "Test", prenom: "Joueur", numero: 7, poste: .recepteur)
    }

    private func creerStat(seanceID: UUID, joueurID: UUID,
                           kills: Int, setsJoues: Int) -> StatsMatch {
        let stat = StatsMatch(seanceID: seanceID, joueurID: joueurID)
        stat.kills = kills
        stat.tentativesAttaque = kills
        stat.setsJoues = setsJoues
        return stat
    }

    @Test("resynchroniserCumul — le cumul = somme des StatsMatch du joueur")
    func cumulDepuisStatsMatch() {
        let joueur = creerJoueur()
        let stats = [
            creerStat(seanceID: UUID(), joueurID: joueur.id, kills: 10, setsJoues: 3),
            creerStat(seanceID: UUID(), joueurID: joueur.id, kills: 5, setsJoues: 2),
        ]

        AgregateurStatsMatch.resynchroniserCumul(joueurs: [joueur], statsMatch: stats)

        #expect(joueur.attaquesReussies == 15)
        #expect(joueur.attaquesTotales == 15)
        #expect(joueur.setsJoues == 5)
        #expect(joueur.matchsJoues == 2)
    }

    @Test("resynchroniserCumul — idempotent : double appel, cumul identique (bug B2)")
    func idempotence() {
        let joueur = creerJoueur()
        let stats = [creerStat(seanceID: UUID(), joueurID: joueur.id, kills: 10, setsJoues: 3)]

        AgregateurStatsMatch.resynchroniserCumul(joueurs: [joueur], statsMatch: stats)
        AgregateurStatsMatch.resynchroniserCumul(joueurs: [joueur], statsMatch: stats)

        #expect(joueur.attaquesReussies == 10)
        #expect(joueur.matchsJoues == 1)
        #expect(joueur.setsJoues == 3)
    }

    @Test("resynchroniserCumul — corrige un cumul déjà doublé (réparation B2)")
    func reparationCumulDouble() {
        let joueur = creerJoueur()
        // État corrompu par l'ancien bug : valeurs doublées.
        joueur.attaquesReussies = 20
        joueur.matchsJoues = 2
        joueur.setsJoues = 6
        let stats = [creerStat(seanceID: UUID(), joueurID: joueur.id, kills: 10, setsJoues: 3)]

        AgregateurStatsMatch.resynchroniserCumul(joueurs: [joueur], statsMatch: stats)

        #expect(joueur.attaquesReussies == 10)
        #expect(joueur.matchsJoues == 1)
        #expect(joueur.setsJoues == 3)
    }

    @Test("resynchroniserCumul — les StatsMatch d'autres joueurs n'affectent pas le cumul")
    func isolationParJoueur() {
        let joueur = creerJoueur()
        let autre = creerJoueur()
        let stats = [
            creerStat(seanceID: UUID(), joueurID: joueur.id, kills: 10, setsJoues: 3),
            creerStat(seanceID: UUID(), joueurID: autre.id, kills: 99, setsJoues: 5),
        ]

        AgregateurStatsMatch.resynchroniserCumul(joueurs: [joueur], statsMatch: stats)

        #expect(joueur.attaquesReussies == 10)
        #expect(joueur.matchsJoues == 1)
    }
}
