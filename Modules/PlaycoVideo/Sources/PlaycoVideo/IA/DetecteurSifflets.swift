//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  IA niveau 1 — détection des coups de sifflet dans la piste audio. Au
//  volleyball, l'arbitre siffle l'autorisation de servir et la fin de chaque
//  échange : c'est le repère le plus net des bornes d'un échange, même quand
//  l'image est encombrée. Traitement pur (FFT maison, fenêtre de Hann) :
//  un sifflet = pic tonal étroit dans la bande 2-4,5 kHz qui concentre
//  l'essentiel de l'énergie de la trame. L'extraction de l'audio (AVFoundation)
//  vit côté Apple ; ce détecteur est testable partout.
//

import Foundation

public struct SignalAudio: Hashable, Sendable {
    /// Échantillons mono.
    public var echantillons: [Float]
    /// Hz. ~11 kHz suffisent (bande utile ≤ 4,5 kHz).
    public var frequenceEchantillonnage: Double

    public init(echantillons: [Float], frequenceEchantillonnage: Double) {
        self.echantillons = echantillons
        self.frequenceEchantillonnage = frequenceEchantillonnage
    }
}

public struct SiffletDetecte: Hashable, Sendable {
    public var debut: Double
    public var fin: Double
    /// Fréquence dominante (Hz).
    public var frequence: Double
    /// Part moyenne de l'énergie concentrée dans le pic (0-1).
    public var tonalite: Double

    public var duree: Double { fin - debut }
}

public struct ParametresSifflet: Hashable, Sendable {
    public var bandeBasse: Double
    public var bandeHaute: Double
    /// Durée d'une trame d'analyse (arrondie à une puissance de 2 d'échantillons).
    public var trame: Double
    /// Part minimale de l'énergie de la trame dans le pic (± 1 case).
    public var seuilTonalite: Double
    /// Énergie RMS minimale d'une trame (évite de « détecter » dans le silence).
    public var energieMinimale: Double
    public var dureeMinimale: Double
    public var fusionEcart: Double

    /// Valeurs ESTIMÉES — à régler au banc d'essai sur de vrais gymnases.
    public static let parDefaut = ParametresSifflet()

    public init(bandeBasse: Double = 2000, bandeHaute: Double = 4500, trame: Double = 0.023,
                seuilTonalite: Double = 0.35, energieMinimale: Double = 0.01,
                dureeMinimale: Double = 0.12, fusionEcart: Double = 0.1) {
        self.bandeBasse = bandeBasse
        self.bandeHaute = bandeHaute
        self.trame = trame
        self.seuilTonalite = seuilTonalite
        self.energieMinimale = energieMinimale
        self.dureeMinimale = dureeMinimale
        self.fusionEcart = fusionEcart
    }
}

public enum DetecteurSifflets {

    public static func detecter(_ audio: SignalAudio, parametres: ParametresSifflet = .parDefaut) -> [SiffletDetecte] {
        let fs = audio.frequenceEchantillonnage
        guard fs > 0, parametres.bandeHaute < fs / 2 else { return [] }
        let taille = puissanceDeDeux(auMoins: Int(parametres.trame * fs))
        let pas = taille / 2
        guard audio.echantillons.count >= taille else { return [] }

        let hann = (0..<taille).map { 0.5 - 0.5 * cos(2 * Double.pi * Double($0) / Double(taille)) }
        let resolution = fs / Double(taille)
        let caseBasse = max(1, Int((parametres.bandeBasse / resolution).rounded(.down)))
        let caseHaute = min(taille / 2 - 2, Int((parametres.bandeHaute / resolution).rounded(.up)))
        guard caseBasse < caseHaute else { return [] }

        // Score par trame : (tonalité, fréquence) si sifflet plausible.
        var trames: [(instant: Double, tonalite: Double, frequence: Double)?] = []
        var debutTrame = 0
        while debutTrame + taille <= audio.echantillons.count {
            let bloc = audio.echantillons[debutTrame..<debutTrame + taille]
            var energie = 0.0
            var reel = [Double](repeating: 0, count: taille)
            for (i, x) in bloc.enumerated() {
                let v = Double(x)
                energie += v * v
                reel[i] = v * hann[i]
            }
            let rms = (energie / Double(taille)).squareRoot()
            var detection: (Double, Double, Double)?
            if rms >= parametres.energieMinimale {
                let puissance = spectrePuissance(reel)
                let total = puissance[1..<(taille / 2)].reduce(0, +)
                if total > 0, let pic = (caseBasse...caseHaute).max(by: { puissance[$0] < puissance[$1] }) {
                    let concentree = puissance[pic - 1] + puissance[pic] + puissance[pic + 1]
                    let tonalite = concentree / total
                    if tonalite >= parametres.seuilTonalite {
                        detection = (Double(debutTrame) / fs, tonalite, Double(pic) * resolution)
                    }
                }
            }
            trames.append(detection.map { (instant: $0.0, tonalite: $0.1, frequence: $0.2) })
            debutTrame += pas
        }

        // Regroupement des trames positives consécutives, fusion, durée minimale.
        let dureeTrame = Double(taille) / fs
        var sifflets: [SiffletDetecte] = []
        var courant: [(instant: Double, tonalite: Double, frequence: Double)] = []
        func clore() {
            guard let premier = courant.first, let dernier = courant.last else { return }
            let nouveau = SiffletDetecte(
                debut: premier.instant,
                fin: dernier.instant + dureeTrame,
                frequence: courant.map(\.frequence).reduce(0, +) / Double(courant.count),
                tonalite: courant.map(\.tonalite).reduce(0, +) / Double(courant.count))
            if let precedent = sifflets.last, nouveau.debut - precedent.fin <= parametres.fusionEcart {
                sifflets[sifflets.count - 1].fin = nouveau.fin
            } else {
                sifflets.append(nouveau)
            }
            courant = []
        }
        for trame in trames {
            if let trame { courant.append(trame) } else { clore() }
        }
        clore()
        return sifflets.filter { $0.duree >= parametres.dureeMinimale }
    }

    /// Sifflets en événements détectés (instant = fin du coup de sifflet).
    public static func enEvenements(_ sifflets: [SiffletDetecte]) -> [EvenementDetecte] {
        sifflets.map { EvenementDetecte(instant: $0.fin, etiquette: "sifflet", confiance: min(1, $0.tonalite)) }
    }

    // MARK: - FFT

    static func puissanceDeDeux(auMoins n: Int) -> Int {
        var p = 1
        while p < max(1, n) { p <<= 1 }
        return p
    }

    /// Spectre de puissance |X(k)|² d'un signal réel (FFT radix-2 itérative).
    /// La taille doit être une puissance de 2.
    static func spectrePuissance(_ signal: [Double]) -> [Double] {
        let n = signal.count
        var re = signal
        var im = [Double](repeating: 0, count: n)

        // Permutation par inversion des bits.
        var j = 0
        for i in 1..<n {
            var bit = n >> 1
            while j & bit != 0 {
                j ^= bit
                bit >>= 1
            }
            j |= bit
            if i < j {
                re.swapAt(i, j)
                im.swapAt(i, j)
            }
        }

        var longueur = 2
        while longueur <= n {
            let angle = -2 * Double.pi / Double(longueur)
            let (wr, wi) = (cos(angle), sin(angle))
            var debut = 0
            while debut < n {
                var (cr, ci) = (1.0, 0.0)
                for k in 0..<(longueur / 2) {
                    let a = debut + k, b = a + longueur / 2
                    let tr = re[b] * cr - im[b] * ci
                    let ti = re[b] * ci + im[b] * cr
                    re[b] = re[a] - tr
                    im[b] = im[a] - ti
                    re[a] += tr
                    im[a] += ti
                    (cr, ci) = (cr * wr - ci * wi, cr * wi + ci * wr)
                }
                debut += longueur
            }
            longueur <<= 1
        }
        return (0..<n).map { re[$0] * re[$0] + im[$0] * im[$0] }
    }
}
