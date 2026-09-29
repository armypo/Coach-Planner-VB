//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//

import Foundation
import Testing
@testable import PlaycoVideo

@Suite("DetecteurSifflets — piste audio")
struct DetecteurSiffletsTests {

    private let fs = 11_025.0

    /// Bruit de gymnase + sons ajoutés sur des plages [début, fin[ (secondes).
    private func audio(
        duree: Double,
        bruit: Float = 0.1,
        tons: [(debut: Double, fin: Double, frequences: [Double], amplitude: Float)]
    ) -> SignalAudio {
        var rng = GenerateurDeterministe(graine: 2026)
        let n = Int(duree * fs)
        var x = (0..<n).map { _ in Float.random(in: -bruit...bruit, using: &rng) }
        for ton in tons {
            for i in Int(ton.debut * fs)..<min(n, Int(ton.fin * fs)) {
                let t = Double(i) / fs
                let somme = ton.frequences.reduce(0.0) { $0 + sin(2 * Double.pi * $1 * t) }
                x[i] += ton.amplitude * Float(somme / Double(ton.frequences.count))
            }
        }
        return SignalAudio(echantillons: x, frequenceEchantillonnage: fs)
    }

    @Test("deux coups de sifflet retrouvés, bornes à ±50 ms, fréquence estimée")
    func deuxSifflets() throws {
        let signal = audio(duree: 10, tons: [
            (2.0, 2.4, [3150], 0.5),
            (6.0, 6.8, [3150], 0.5)
        ])
        let s = DetecteurSifflets.detecter(signal)
        try #require(s.count == 2)
        #expect(abs(s[0].debut - 2.0) <= 0.05)
        #expect(abs(s[0].fin - 2.4) <= 0.05)
        #expect(abs(s[1].debut - 6.0) <= 0.05)
        #expect(abs(s[1].fin - 6.8) <= 0.05)
        #expect(abs(s[0].frequence - 3150) <= 50)
        #expect(s[0].tonalite > 0.8)
    }

    @Test("sifflet à deux tons (type Fox 40) détecté")
    func deuxTons() {
        let s = DetecteurSifflets.detecter(audio(duree: 5, tons: [(1.0, 1.5, [2800, 3400], 0.7)]))
        #expect(s.count == 1)
    }

    @Test("voix ou foule (grave, hors bande) : ignorées")
    func horsBande() {
        let s = DetecteurSifflets.detecter(audio(duree: 5, tons: [(1.0, 3.0, [500], 0.8)]))
        #expect(s.isEmpty)
    }

    @Test("bruit seul et silence : aucun sifflet")
    func bruitSeul() {
        #expect(DetecteurSifflets.detecter(audio(duree: 5, tons: [])).isEmpty)
        #expect(DetecteurSifflets.detecter(audio(duree: 5, bruit: 0, tons: [])).isEmpty)
    }

    @Test("un bip trop court n'est pas un sifflet")
    func tropCourt() {
        let s = DetecteurSifflets.detecter(audio(duree: 3, tons: [(1.0, 1.05, [3150], 0.5)]))
        #expect(s.isEmpty)
    }

    @Test("sifflets → événements (instant = fin du coup de sifflet)")
    func evenements() {
        let e = DetecteurSifflets.enEvenements([SiffletDetecte(debut: 1, fin: 1.4, frequence: 3000, tonalite: 0.9)])
        #expect(e == [EvenementDetecte(instant: 1.4, etiquette: "sifflet", confiance: 0.9)])
    }

    @Test("FFT : un ton pur tombe dans la bonne case")
    func fft() {
        let n = 256
        let k = 37
        let signal = (0..<n).map { sin(2 * Double.pi * Double(k) * Double($0) / Double(n)) }
        let p = DetecteurSifflets.spectrePuissance(signal)
        let pic = (1..<(n / 2)).max { p[$0] < p[$1] }
        #expect(pic == k)
        #expect(DetecteurSifflets.puissanceDeDeux(auMoins: 254) == 256)
        #expect(DetecteurSifflets.puissanceDeDeux(auMoins: 256) == 256)
    }

    @Test("fréquence d'échantillonnage trop basse pour la bande : aucun calcul")
    func frequenceTropBasse() {
        let signal = SignalAudio(echantillons: Array(repeating: 0.5, count: 10_000), frequenceEchantillonnage: 8000)
        #expect(DetecteurSifflets.detecter(signal).isEmpty)
    }
}
