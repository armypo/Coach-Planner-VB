//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//

import Foundation
import Testing
@testable import PlaycoVideo

@Suite("BancEssai — mesure des analyseurs")
struct BancEssaiTests {

    private func v(_ instant: Double, _ etiquette: String = "Kill") -> VeriteTerrain {
        VeriteTerrain(instant: instant, etiquette: etiquette)
    }

    private func p(_ instant: Double, _ etiquette: String? = nil, confiance: Double = 1) -> EvenementDetecte {
        EvenementDetecte(instant: instant, etiquette: etiquette, confiance: confiance)
    }

    @Test("détection parfaite : précision = rappel = F1 = 1")
    func parfaite() {
        let r = BancEssai.evaluer(predictions: [p(10), p(20)], verite: [v(10), v(20)], tolerance: .symetrique(1))
        #expect(r.global.vraisPositifs == 2)
        #expect(r.global.precision == 1)
        #expect(r.global.rappel == 1)
        #expect(r.global.f1 == 1)
        #expect(r.global.erreurTemporelleMoyenne == 0)
    }

    @Test("faux positifs, faux négatifs et erreur temporelle")
    func comptes() {
        let r = BancEssai.evaluer(
            predictions: [p(10.5), p(50)],
            verite: [v(10), v(30)],
            tolerance: .symetrique(1))
        #expect(r.global.vraisPositifs == 1)
        #expect(r.global.fauxPositifs == 1)
        #expect(r.global.fauxNegatifs == 1)
        #expect(r.global.precision == 0.5)
        #expect(r.global.rappel == 0.5)
        #expect(r.global.erreurTemporelleMoyenne == 0.5)
    }

    @Test("un-pour-un : deux prédictions sur une vérité = 1 VP + 1 FP")
    func unPourUn() {
        let r = BancEssai.evaluer(predictions: [p(9.8), p(10.2)], verite: [v(10)], tolerance: .symetrique(1))
        #expect(r.global.vraisPositifs == 1)
        #expect(r.global.fauxPositifs == 1)
    }

    @Test("appariement maximal quand les fenêtres se chevauchent")
    func maximal() {
        // Vérités 10 et 11, tolérance ±1 : 10,9 → 10 et 11,5 → 11.
        let r = BancEssai.evaluer(predictions: [p(11.5), p(10.9)], verite: [v(10), v(11)], tolerance: .symetrique(1))
        #expect(r.global.vraisPositifs == 2)
    }

    @Test("tolérance asymétrique : fin d'échange AVANT le tap")
    func asymetrique() {
        let tolerance = ToleranceTemporelle(avant: 8, apres: 0)
        let avant = BancEssai.evaluer(predictions: [p(95)], verite: [v(100)], tolerance: tolerance)
        let apres = BancEssai.evaluer(predictions: [p(100.5)], verite: [v(100)], tolerance: tolerance)
        #expect(avant.global.vraisPositifs == 1)
        #expect(apres.global.vraisPositifs == 0)
    }

    @Test("étiquette exigée : mauvaise classe = FP + FN, sans classe = FP")
    func etiquettes() {
        let r = BancEssai.evaluer(
            predictions: [p(10, "Kill"), p(20, "Ace"), p(30, nil)],
            verite: [v(10, "Kill"), v(20, "Kill"), v(30, "Ace")],
            tolerance: .symetrique(1),
            exigerEtiquette: true)
        #expect(r.global.vraisPositifs == 1)
        #expect(r.global.fauxPositifs == 2)
        #expect(r.global.fauxNegatifs == 2)
        #expect(r.parEtiquette["Kill"]?.rappel == 0.5)
        #expect(r.parEtiquette["Ace"]?.vraisPositifs == 0)
    }

    @Test("seuil de confiance, courbe et meilleur seuil")
    func courbe() {
        let predictions = [p(10, confiance: 0.9), p(20, confiance: 0.8), p(35, confiance: 0.3)]
        let verite = [v(10), v(20)]
        let bas = BancEssai.evaluer(predictions: predictions, verite: verite, tolerance: .symetrique(1), seuilConfiance: 0)
        let haut = BancEssai.evaluer(predictions: predictions, verite: verite, tolerance: .symetrique(1), seuilConfiance: 0.5)
        #expect(bas.global.fauxPositifs == 1)
        #expect(haut.global.fauxPositifs == 0)

        let c = BancEssai.courbe(predictions: predictions, verite: verite, tolerance: .symetrique(1), seuils: [0.95, 0, 0.5])
        #expect(c.map(\.seuil) == [0, 0.5, 0.95])
        #expect(BancEssai.meilleurSeuil(c)?.seuil == 0.5)
    }

    @Test("aucune donnée : scores nuls sans division par zéro")
    func vide() {
        let r = BancEssai.evaluer(predictions: [], verite: [], tolerance: .symetrique(1))
        #expect(r.global.precision == 0)
        #expect(r.global.rappel == 0)
        #expect(r.global.f1 == 0)
        #expect(r.global.erreurTemporelleMoyenne == nil)
    }

    @Test("vérité terrain issue des chapitres")
    func depuisChapitres() {
        let c = IndexVideo.chapitres(
            [Fixtures.evenement(a: 100, etiquette: "Ace")], alignement: Fixtures.alignement())
        #expect(VeriteTerrain.depuis(c) == [VeriteTerrain(instant: 100, etiquette: "Ace")])
    }

    struct AnalyseurFactice: AnalyseurVideo {
        let identifiant = "factice-v1"
        let reponse: [EvenementDetecte]
        func analyser(video: URL) async throws -> [EvenementDetecte] { reponse }
    }

    @Test("un analyseur se branche sur le banc d'essai par le protocole")
    func analyseur() async throws {
        let analyseur = AnalyseurFactice(reponse: [p(10), p(40)])
        let r = try await BancEssai.evaluer(
            analyseur, video: URL(fileURLWithPath: "/dev/null"),
            verite: [v(10), v(20)], tolerance: .symetrique(1))
        #expect(r.global.vraisPositifs == 1)
        #expect(r.global.f1 == 0.5)
    }
}
