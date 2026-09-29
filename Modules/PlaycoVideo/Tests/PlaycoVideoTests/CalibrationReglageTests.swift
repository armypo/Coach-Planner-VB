//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//

import Foundation
import Testing
@testable import PlaycoVideo

@Suite("CalibrationTerrain — image ↔ terrain")
struct CalibrationTerrainTests {

    /// Caméra en perspective : terrain (m) → image normalisée.
    private let camera: [Double] = [0.05, 0.01, 0.05, 0.0, 0.06, 0.3, 0.0, 0.02, 1]

    private func projeter(_ p: PointTerrain) -> PointImage {
        let (u, v) = CalibrationTerrain.appliquer(camera, p.x, p.y) ?? (0, 0)
        return PointImage(x: u, y: v)
    }

    private func calibration() throws -> CalibrationTerrain {
        let coins = [PointTerrain(x: 0, y: 0), PointTerrain(x: 18, y: 0),
                     PointTerrain(x: 18, y: 9), PointTerrain(x: 0, y: 9)].map(projeter)
        return try #require(CalibrationTerrain(coinsImage: coins))
    }

    @Test("4 coins suffisent : tout point de l'image retombe à sa place sur le terrain")
    func allerRetour() throws {
        let c = try calibration()
        for x in stride(from: 0.0, through: 18, by: 1.5) {
            for y in stride(from: 0.0, through: 9, by: 1.5) {
                let image = projeter(PointTerrain(x: x, y: y))
                let terrain = try #require(c.versTerrain(image))
                #expect(abs(terrain.x - x) < 1e-6)
                #expect(abs(terrain.y - y) < 1e-6)
                let retour = try #require(c.versImage(terrain))
                #expect(abs(retour.x - image.x) < 1e-9)
                #expect(abs(retour.y - image.y) < 1e-9)
            }
        }
    }

    @Test("coins alignés ou mal ordonnés : calibration refusée")
    func degeneres() {
        let alignes = [PointImage(x: 0.1, y: 0.1), PointImage(x: 0.5, y: 0.5),
                       PointImage(x: 0.9, y: 0.9), PointImage(x: 0.1, y: 0.9)]
        let croises = [PointImage(x: 0.1, y: 0.1), PointImage(x: 0.9, y: 0.9),
                       PointImage(x: 0.9, y: 0.1), PointImage(x: 0.1, y: 0.9)]
        #expect(CalibrationTerrain(coinsImage: alignes) == nil)
        #expect(CalibrationTerrain(coinsImage: croises) == nil)
        #expect(CalibrationTerrain(coinsImage: Array(alignes.prefix(3))) == nil)
    }

    @Test("cellule de grille lue face au filet, par moitié ; hors terrain = nil")
    func cellules() throws {
        let c = try calibration()
        let proche = try #require(c.cellule(PointTerrain(x: 8.5, y: 1), colonnes: 3, rangees: 3))
        #expect(proche == (0, 0, 0))
        let enFace = try #require(c.cellule(PointTerrain(x: 9.5, y: 8), colonnes: 3, rangees: 3))
        #expect(enFace == (1, 0, 0))
        let fond = try #require(c.cellule(PointTerrain(x: 0.5, y: 4.5), colonnes: 3, rangees: 3))
        #expect(fond == (0, 1, 2))
        #expect(c.cellule(PointTerrain(x: -1, y: 4), colonnes: 3, rangees: 3) == nil)
        #expect(c.estSurTerrain(PointTerrain(x: -0.5, y: 4), marge: 1))
    }

    @Test("aller-retour JSON de la calibration")
    func codable() throws {
        let c = try calibration()
        let relu = try JSONDecoder().decode(CalibrationTerrain.self, from: JSONEncoder().encode(c))
        #expect(relu == c)
    }
}

@Suite("ReglageDetecteur — réglage automatique au banc d'essai")
struct ReglageDetecteurTests {

    private func annote(_ m: MatchSimule) -> MatchAnnote {
        MatchAnnote(signal: m.signal, finsEchanges: m.echanges.map(\.fin))
    }

    @Test("parasites longs (2,5 s) : le réglage bat les valeurs par défaut")
    func batLesDefauts() throws {
        let matchs = [UInt64(4), 8].map { annote(MatchSimule(graine: $0, dureeParasite: 2.5)) }
        let parDefaut = ReglageDetecteur.evaluer(.parDefaut, sur: matchs)
        let grille = GrilleReglage(lissages: [0.5], fractionsBas: [0.25], fractionsHaut: [0.6, 0.9],
                                   dureesMinimales: [2, 3.5], fusions: [1.5])
        let r = try #require(ReglageDetecteur.optimiser(sur: matchs, grille: grille))

        #expect(parDefaut.precision < 0.9)          // les parasites passent
        #expect(r.score.f1 > parDefaut.f1)
        #expect(r.score.f1 >= 0.95)
        #expect(r.combinaisonsEssayees == 4)

        // Validation sur un match qui n'a PAS servi au réglage.
        let validation = ReglageDetecteur.evaluer(r.parametres, sur: [annote(MatchSimule(graine: 15, dureeParasite: 2.5))])
        #expect(validation.f1 >= 0.95)
    }

    @Test("grille sans combinaison valide ou aucun match : nil")
    func vide() {
        let invalide = GrilleReglage(lissages: [0.5], fractionsBas: [0.8], fractionsHaut: [0.6],
                                     dureesMinimales: [2], fusions: [1])
        #expect(ReglageDetecteur.optimiser(sur: [annote(MatchSimule(graine: 1))], grille: invalide) == nil)
        #expect(ReglageDetecteur.optimiser(sur: []) == nil)
    }
}
