//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Match simulé déterministe : échanges, taps de saisie après chaque échange,
//  et signal d'activité bruité (bruit de fond, mouvements parasites courts,
//  micro-creux pendant les échanges). Sert à tester la chaîne IA hors de
//  l'app, sans vidéo réelle.
//

import Foundation
@testable import PlaycoVideo

/// Générateur pseudo-aléatoire reproductible (SplitMix64).
struct GenerateurDeterministe: RandomNumberGenerator {
    private var etat: UInt64

    init(graine: UInt64) { etat = graine }

    mutating func next() -> UInt64 {
        etat &+= 0x9E37_79B9_7F4A_7C15
        var z = etat
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

struct MatchSimule {
    struct Echange {
        var debut: Double
        var fin: Double
        /// Instant du tap de saisie (secondes vidéo, vérité).
        var tap: Double
    }

    let echanges: [Echange]
    let duree: Double
    let signal: SignalActivite

    init(graine: UInt64, nombreEchanges: Int = 40, frequence: Double = 10,
         delaiSaisie: ClosedRange<Double> = 1...4) {
        var rng = GenerateurDeterministe(graine: graine)
        var echanges: [Echange] = []
        var t = 5.0
        for _ in 0..<nombreEchanges {
            let debut = t + Double.random(in: 8...20, using: &rng)
            let fin = debut + Double.random(in: 4...14, using: &rng)
            echanges.append(Echange(debut: debut, fin: fin, tap: fin + Double.random(in: delaiSaisie, using: &rng)))
            t = fin
        }
        let duree = (echanges.last?.tap ?? 0) + 15
        let n = Int(duree * frequence)

        var valeurs = (0..<n).map { _ in 0.1 + 0.1 * Double.random(in: 0...1, using: &rng) }
        for e in echanges {
            let a = Int(e.debut * frequence), b = min(n, Int(e.fin * frequence))
            for i in a..<b { valeurs[i] = 1.0 + 0.3 * Double.random(in: 0...1, using: &rng) }
            // Micro-creux de 0,4 s au milieu de l'échange (ballon hors champ).
            let milieu = (a + b) / 2
            for i in milieu..<min(b, milieu + Int(0.4 * frequence)) { valeurs[i] = 0.15 }
        }
        // Mouvements parasites courts (0,5 s) pendant les temps morts.
        for (k, e) in echanges.enumerated() where k % 3 == 0 {
            let a = Int((e.debut - 5) * frequence)
            for i in max(0, a)..<max(0, a + Int(0.5 * frequence)) { valeurs[i] = 0.9 }
        }

        self.echanges = echanges
        self.duree = duree
        self.signal = SignalActivite(valeurs: valeurs, frequence: frequence)
    }

    /// Événements saisis, horodatés par rapport au VRAI début de la vidéo.
    func evenements(debutVideo: Date) -> [EvenementMatch] {
        echanges.enumerated().map { k, e in
            EvenementMatch(
                horodatage: debutVideo.addingTimeInterval(e.tap),
                etiquette: k % 2 == 0 ? "Kill" : "Err. service",
                resultat: k % 2 == 0 ? .pourNous : .contreNous,
                periode: 1 + k / 20,
                rotation: 1 + k % 6,
                auService: k % 3 == 0)
        }
    }
}
