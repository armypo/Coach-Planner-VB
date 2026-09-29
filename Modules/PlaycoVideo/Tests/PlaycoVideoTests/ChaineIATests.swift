//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Chaîne IA de bout en bout sur des matchs simulés : détection des
//  échanges → calage automatique → fenêtre estimée → clips qui couvrent les
//  échanges. Aucune vidéo réelle : le signal d'activité est synthétique.
//

import Foundation
import Testing
@testable import PlaycoVideo

@Suite("DetecteurEchanges — signal d'activité")
struct DetecteurEchangesTests {

    @Test("retrouve chaque échange à ±1 s (début et fin)", arguments: [UInt64(1), 7, 42])
    func retrouveLesEchanges(graine: UInt64) {
        let match = MatchSimule(graine: graine)
        let detectes = DetecteurEchanges.detecter(match.signal)

        let fins = BancEssai.evaluer(
            predictions: detectes.map { EvenementDetecte(instant: $0.fin) },
            verite: match.echanges.map { VeriteTerrain(instant: $0.fin, etiquette: "fin") },
            tolerance: .symetrique(1))
        let debuts = BancEssai.evaluer(
            predictions: detectes.map { EvenementDetecte(instant: $0.debut) },
            verite: match.echanges.map { VeriteTerrain(instant: $0.debut, etiquette: "debut") },
            tolerance: .symetrique(1))

        #expect(fins.global.rappel >= 0.95)
        #expect(fins.global.precision >= 0.95)
        #expect(debuts.global.rappel >= 0.95)
    }

    @Test("un mouvement parasite court n'est pas un échange")
    func parasite() {
        var valeurs = Array(repeating: 0.1, count: 600)
        for i in 100..<105 { valeurs[i] = 2 }      // 0,5 s
        for i in 300..<400 { valeurs[i] = 1 }      // 10 s
        let detectes = DetecteurEchanges.detecter(SignalActivite(valeurs: valeurs, frequence: 10))
        #expect(detectes.count == 1)
        #expect(abs(detectes[0].debut - 30) <= 0.5)
        #expect(abs(detectes[0].fin - 40) <= 0.5)
    }

    @Test("une micro-coupure ne coupe pas l'échange")
    func microCoupure() {
        var valeurs = Array(repeating: 0.1, count: 600)
        for i in 200..<400 { valeurs[i] = 1 }
        for i in 300..<310 { valeurs[i] = 0.1 }    // 1 s de creux
        let detectes = DetecteurEchanges.detecter(SignalActivite(valeurs: valeurs, frequence: 10))
        #expect(detectes.count == 1)
    }

    @Test("signal plat ou vide : aucun échange")
    func plat() {
        #expect(DetecteurEchanges.detecter(SignalActivite(valeurs: Array(repeating: 0.5, count: 100), frequence: 10)).isEmpty)
        #expect(DetecteurEchanges.detecter(SignalActivite(valeurs: [], frequence: 10)).isEmpty)
        #expect(DetecteurEchanges.detecter(SignalActivite(valeurs: [1, 2], frequence: 0)).isEmpty)
    }

    @Test("fins d'échange → événements, confiance relative à l'intensité")
    func finsEnEvenements() {
        let e = DetecteurEchanges.finsEnEvenements([
            EchangeDetecte(debut: 0, fin: 5, intensite: 2),
            EchangeDetecte(debut: 10, fin: 15, intensite: 1)
        ])
        #expect(e.map(\.instant) == [5, 15])
        #expect(e.map(\.confiance) == [1, 0.5])
    }

    @Test("quantile et moyenne mobile")
    func outils() {
        #expect(DetecteurEchanges.quantile([1, 2, 3, 4, 5], 0.5) == 3)
        #expect(DetecteurEchanges.quantile([0, 10], 0.25) == 2.5)
        #expect(DetecteurEchanges.moyenneMobile([0, 3, 0], fenetre: 3) == [1.5, 1, 1.5])
    }
}

@Suite("CalageAutomatique — vidéo ↔ stats sans ancre")
struct CalageAutomatiqueTests {

    @Test("retrouve un décalage d'horloge de 37 s", arguments: [UInt64(3), 11, 99])
    func retrouveLeDecalage(graine: UInt64) throws {
        let match = MatchSimule(graine: graine)
        let finsDetectees = DetecteurEchanges.detecter(match.signal).map(\.fin)
        // Horloge de la caméra fausse : les taps semblent 37 s trop tôt.
        let taps = match.echanges.map { $0.tap - 37 }

        let r = try #require(CalageAutomatique.estimer(taps: taps, finsEchanges: finsDetectees))
        #expect(abs(r.decalage - 37) <= 4)
        #expect(r.couverture >= 0.95)
        #expect(r.estFiable)
    }

    @Test("sans correspondance possible : non fiable")
    func sansCorrespondance() throws {
        let r = try #require(CalageAutomatique.estimer(taps: [10, 20, 30, 40], finsEchanges: [5000], plage: 60))
        #expect(r.appariements == 0)
        #expect(!r.estFiable)
    }

    @Test("sans données : nil")
    func sansDonnees() {
        #expect(CalageAutomatique.estimer(taps: [], finsEchanges: [1]) == nil)
        #expect(CalageAutomatique.estimer(taps: [1], finsEchanges: []) == nil)
    }

    @Test("appliquer ajoute le décalage à l'alignement")
    func appliquer() {
        let r = ResultatCalage(decalage: 12, appariements: 10, couverture: 1, appariementsConcurrent: 0)
        let a = CalageAutomatique.appliquer(r, a: Fixtures.alignement(decalage: 3))
        #expect(a.decalageSecondes == 15)
    }
}

@Suite("Chaîne IA — match simulé de bout en bout")
struct ChaineIATests {

    @Test("détection → calage auto → fenêtre estimée : les clips couvrent ≥ 90 % des échanges",
          arguments: [UInt64(5), 23, 77])
    func boutEnBout(graine: UInt64) throws {
        let match = MatchSimule(graine: graine)
        let vraiDebut = Date(timeIntervalSince1970: 1_000_000)
        let evenements = match.evenements(debutVideo: vraiDebut)

        // Métadonnée du fichier fausse de 37 s (horloge de la caméra).
        let alignementInitial = AlignementVideo(
            dateDebutVideo: vraiDebut.addingTimeInterval(-37), dureeVideo: match.duree)

        let echanges = DetecteurEchanges.detecter(match.signal)
        let tapsInitiaux = evenements.map { alignementInitial.instantDansVideo($0.horodatage) }
        let calage = try #require(CalageAutomatique.estimer(taps: tapsInitiaux, finsEchanges: echanges.map(\.fin)))
        #expect(calage.estFiable)
        let alignement = CalageAutomatique.appliquer(calage, a: alignementInitial)

        let taps = evenements.map { alignement.instantDansVideo($0.horodatage) }
        let fenetre = try #require(EstimationFenetre.estimer(taps: taps, echanges: echanges))
        let chapitres = IndexVideo.chapitres(evenements, alignement: alignement, fenetre: fenetre)
        #expect(chapitres.count == match.echanges.count)

        let couverts = zip(chapitres, match.echanges).filter { c, e in
            c.debut <= e.debut + 0.5 && c.fin >= e.fin
        }.count
        #expect(Double(couverts) / Double(match.echanges.count) >= 0.9)
    }

    @Test("estimation de fenêtre : nil sous le minimum d'appariements")
    func fenetreMinimum() {
        let echanges = [EchangeDetecte(debut: 10, fin: 20, intensite: 1)]
        #expect(EstimationFenetre.estimer(taps: [22], echanges: echanges) == nil)
        #expect(EstimationFenetre.estimer(taps: [22], echanges: echanges, minimumAppariements: 1)?.avant == 13)
    }
}
