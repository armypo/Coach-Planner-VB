//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Tests de MetriquesVolley : source unique des formules statistiques (D1 :
//  ratios en 0-1 ; D3 : blocs pondérés ; D5 : reconstruction du service) et
//  de FormatMetriques (D2 : hitting « .350 », pourcentages français).
//

import Testing
import Foundation
@testable import Playco

@Suite("MetriquesVolley — formules")
struct MetriquesVolleyFormulesTests {

    // MARK: - Rendement attaque (hitting %)

    @Test("rendementAttaque — cas nominal : (12-4)/30 en fraction 0-1")
    func rendementAttaqueNominal() {
        let r = MetriquesVolley.rendementAttaque(kills: 12, erreurs: 4, tentatives: 30)
        #expect(abs(r - 8.0 / 30.0) < 0.0001)
    }

    @Test("rendementAttaque — zéro tentative retourne 0 (pas de division par zéro)")
    func rendementAttaqueDivisionZero() {
        #expect(MetriquesVolley.rendementAttaque(kills: 0, erreurs: 0, tentatives: 0) == 0)
    }

    @Test("rendementAttaque — peut être négatif : (2-5)/10 = -0,3")
    func rendementAttaqueNegatif() {
        let r = MetriquesVolley.rendementAttaque(kills: 2, erreurs: 5, tentatives: 10)
        #expect(abs(r - (-0.3)) < 0.0001)
    }

    // MARK: - Efficacité réception (D1 : fraction 0-1, PAS 0-100)

    @Test("efficaciteReception — (20-3)/25 = 0,68 en fraction 0-1")
    func efficaciteReceptionNominal() {
        let r = MetriquesVolley.efficaciteReception(reussies: 20, erreurs: 3, totales: 25)
        #expect(abs(r - 0.68) < 0.0001)
    }

    @Test("efficaciteReception — zéro réception retourne 0")
    func efficaciteReceptionDivisionZero() {
        #expect(MetriquesVolley.efficaciteReception(reussies: 0, erreurs: 0, totales: 0) == 0)
    }

    // MARK: - Kill %

    @Test("killPct — 12/30 = 0,4 ; zéro tentative = 0")
    func killPct() {
        #expect(abs(MetriquesVolley.killPct(kills: 12, tentatives: 30) - 0.4) < 0.0001)
        #expect(MetriquesVolley.killPct(kills: 0, tentatives: 0) == 0)
    }

    // MARK: - Points pondérés (D3 : seuls + 0,5 × assistés)

    @Test("points — 10 kills + 3 aces + 2 blocs seuls + 5 assistés = 17,5")
    func pointsPonderes() {
        let p = MetriquesVolley.points(kills: 10, aces: 3, blocsSeuls: 2, blocsAssistes: 5)
        #expect(abs(p - 17.5) < 0.0001)
    }

    @Test("parSet — 17,5 points sur 5 sets = 3,5 ; zéro set = 0")
    func parSet() {
        #expect(abs(MetriquesVolley.parSet(17.5, setsJoues: 5) - 3.5) < 0.0001)
        #expect(MetriquesVolley.parSet(17.5, setsJoues: 0) == 0)
    }

    // MARK: - Note de réception (0-3)

    @Test("noteReception — moyenne des qualités : [3,2,1] = 2,0")
    func noteReceptionNominale() {
        #expect(abs(MetriquesVolley.noteReception(qualites: [3, 2, 1]) - 2.0) < 0.0001)
    }

    @Test("noteReception — une erreur compte 0 : [3,3,0] = 2,0")
    func noteReceptionAvecErreur() {
        #expect(abs(MetriquesVolley.noteReception(qualites: [3, 3, 0]) - 2.0) < 0.0001)
    }

    @Test("noteReception — aucune réception retourne 0")
    func noteReceptionVide() {
        #expect(MetriquesVolley.noteReception(qualites: []) == 0)
    }
}

@Suite("MetriquesVolley — service, sideout et runs")
struct MetriquesVolleyServiceTests {

    // MARK: - Helpers

    /// Crée une séquence ordonnée de PointMatch (horodatages croissants déterministes).
    private func creerPoints(
        set: Int = 1, seanceID: UUID = UUID(), types: [TypeActionPoint]
    ) -> [PointMatch] {
        let base = Date(timeIntervalSince1970: 1_000_000)
        return types.enumerated().map { index, type in
            let p = PointMatch(seanceID: seanceID, set: set, typeAction: type)
            p.horodatage = base.addingTimeInterval(Double(set * 1000 + index))
            return p
        }
    }

    private func creerSeance(nousServonsEnPremier: Bool) -> Seance {
        let seance = Seance(nom: "Match test", typeSeance: .match)
        seance.nousServonsEnPremier = nousServonsEnPremier
        return seance
    }

    // MARK: - Reconstruction du serveur (D5)

    @Test("reconstruireService — set 1, nous servons en premier : premier rallye à nous")
    func serviceInitialSetImpair() {
        let points = creerPoints(types: [.kill])
        let seance = creerSeance(nousServonsEnPremier: true)

        let contexte = MetriquesVolley.reconstruireService(points: points, seance: seance)

        #expect(contexte[points[0].id] == true)
    }

    @Test("reconstruireService — set 1, l'adversaire sert en premier")
    func serviceInitialAdverse() {
        let points = creerPoints(types: [.kill])
        let seance = creerSeance(nousServonsEnPremier: false)

        let contexte = MetriquesVolley.reconstruireService(points: points, seance: seance)

        #expect(contexte[points[0].id] == false)
    }

    @Test("reconstruireService — set 2 (pair) : le service initial alterne")
    func serviceInitialSetPair() {
        let points = creerPoints(set: 2, types: [.kill])
        let seance = creerSeance(nousServonsEnPremier: true)

        let contexte = MetriquesVolley.reconstruireService(points: points, seance: seance)

        #expect(contexte[points[0].id] == false)
    }

    @Test("reconstruireService — set 5 (impair) : comme le set 1")
    func serviceInitialCinquiemeSet() {
        let points = creerPoints(set: 5, types: [.kill])
        let seance = creerSeance(nousServonsEnPremier: true)

        let contexte = MetriquesVolley.reconstruireService(points: points, seance: seance)

        #expect(contexte[points[0].id] == true)
    }

    @Test("reconstruireService — le gagnant du rallye sert le suivant")
    func gagnantServeEnsuite() {
        // Rallye 1 : nous servons, kill → nous gardons le service.
        // Rallye 2 : nous servons, point adverse → l'adversaire récupère le service.
        // Rallye 3 : l'adversaire sert.
        let points = creerPoints(types: [.kill, .killAdversaire, .kill])
        let seance = creerSeance(nousServonsEnPremier: true)

        let contexte = MetriquesVolley.reconstruireService(points: points, seance: seance)

        #expect(contexte[points[0].id] == true)
        #expect(contexte[points[1].id] == true)
        #expect(contexte[points[2].id] == false)
    }

    // MARK: - Sideout % et % au service

    @Test("sideoutPct — 1 sideout réussi sur 2 rallyes en réception = 0,5")
    func sideoutNominal() {
        // Nous servons d'abord : [kill (service), killAdv (service perdu),
        // killAdv (réception perdue), kill (sideout réussi)]
        let points = creerPoints(types: [.kill, .killAdversaire, .killAdversaire, .kill])
        let seance = creerSeance(nousServonsEnPremier: true)

        let sideout = MetriquesVolley.sideoutPct(points: points, seance: seance)
        let service = MetriquesVolley.pctAuService(points: points, seance: seance)

        #expect(abs(sideout - 0.5) < 0.0001)
        #expect(abs(service - 0.5) < 0.0001)
    }

    @Test("sideoutPct — aucun point retourne 0")
    func sideoutVide() {
        let seance = creerSeance(nousServonsEnPremier: true)
        #expect(MetriquesVolley.sideoutPct(points: [], seance: seance) == 0)
        #expect(MetriquesVolley.pctAuService(points: [], seance: seance) == 0)
    }

    // MARK: - Détection des runs

    @Test("detecterRuns — 3 points consécutifs pour nous = 1 run")
    func runPourNous() throws {
        let points = creerPoints(types: [.kill, .ace, .blocSeul, .killAdversaire, .kill])

        let runs = MetriquesVolley.detecterRuns(points: points, minimum: 3)

        #expect(runs.count == 1)
        let run = try #require(runs.first)
        #expect(run.pourNous == true)
        #expect(run.longueur == 3)
        #expect(run.debutIndex == 0)
    }

    @Test("detecterRuns — série trop courte : aucun run")
    func runTropCourt() {
        let points = creerPoints(types: [.kill, .kill, .killAdversaire])
        #expect(MetriquesVolley.detecterRuns(points: points, minimum: 3).isEmpty)
    }

    @Test("detecterRuns — run adverse détecté")
    func runAdverse() throws {
        let points = creerPoints(types: [.kill, .killAdversaire, .aceAdversaire, .blocAdversaire])

        let runs = MetriquesVolley.detecterRuns(points: points, minimum: 3)

        #expect(runs.count == 1)
        let run = try #require(runs.first)
        #expect(run.pourNous == false)
        #expect(run.longueur == 3)
    }
}

@Suite("FormatMetriques — formatage D2")
struct FormatMetriquesTests {

    @Test("hittingVolley — convention volleyball : 0,35 → « .350 »")
    func hittingConventionVolley() {
        #expect(FormatMetriques.hittingVolley(0.35) == ".350")
    }

    @Test("hittingVolley — zéro → « .000 », négatif → « -.050 », 1 → « 1.000 »")
    func hittingCasLimites() {
        #expect(FormatMetriques.hittingVolley(0.0) == ".000")
        #expect(FormatMetriques.hittingVolley(-0.05) == "-.050")
        #expect(FormatMetriques.hittingVolley(1.0) == "1.000")
    }

    @Test("pourcentage — fraction 0-1 → pourcentage français avec virgule")
    func pourcentageFrancais() {
        #expect(FormatMetriques.pourcentage(0.85) == "85,0 %")
        #expect(FormatMetriques.pourcentage(0.856) == "85,6 %")
    }

    @Test("pourcentage — 0 décimale sur demande")
    func pourcentageSansDecimale() {
        #expect(FormatMetriques.pourcentage(0.85, decimales: 0) == "85 %")
    }

    @Test("points — décimale seulement si nécessaire : 17,5 et 12")
    func pointsFormat() {
        #expect(FormatMetriques.points(17.5) == "17,5")
        #expect(FormatMetriques.points(12.0) == "12")
    }

    @Test("note — note de réception sur 3 : « 2,3 »")
    func noteFormat() {
        #expect(FormatMetriques.note(2.333) == "2,3")
    }
}

@Suite("MetriquesVolley — glossaire")
struct DefinitionMetriqueTests {

    @Test("catalogue — non vide et contient le rendement attaque et le sideout")
    func catalogueComplet() {
        let noms = MetriquesVolley.catalogue.map(\.nom)
        #expect(!MetriquesVolley.catalogue.isEmpty)
        #expect(noms.contains("Rendement attaque"))
        #expect(noms.contains("Sideout %"))
    }

    @Test("catalogue — chaque définition a un nom, une abréviation et une définition non vides")
    func catalogueChampsRemplis() {
        for def in MetriquesVolley.catalogue {
            #expect(!def.nom.isEmpty)
            #expect(!def.abreviation.isEmpty)
            #expect(!def.definition.isEmpty)
        }
    }
}
