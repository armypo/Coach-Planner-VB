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

    /// Détection sur un signal complet (tests, courts extraits). Pour un match
    /// entier, préférer `AnalyseurSiffletsFlux` (mémoire constante).
    public static func detecter(_ audio: SignalAudio, parametres: ParametresSifflet = .parDefaut) -> [SiffletDetecte] {
        guard var flux = AnalyseurSiffletsFlux(frequenceEchantillonnage: audio.frequenceEchantillonnage,
                                               parametres: parametres) else { return [] }
        flux.ajouter(audio.echantillons)
        return flux.terminer()
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

    /// Spectre de puissance |X(k)|² d'un signal réel ; la taille doit être une
    /// puissance de 2.
    static func spectrePuissance(_ signal: [Double]) -> [Double] {
        var fft = FFTReelle(taille: signal.count)
        var sortie = [Double](repeating: 0, count: signal.count)
        fft.puissance(signal, dans: &sortie)
        return sortie
    }
}

// MARK: - Analyse en flux

/// Détecteur de sifflets à mémoire constante : on lui donne l'audio par
/// morceaux de taille quelconque (lecture AVFoundation d'un match de 90 min)
/// et il produit exactement le même résultat qu'une analyse d'un bloc.
public struct AnalyseurSiffletsFlux: Sendable {
    public let parametres: ParametresSifflet
    public let frequenceEchantillonnage: Double

    private let taille: Int
    private let pas: Int
    private let hann: [Double]
    private let caseBasse: Int
    private let caseHaute: Int
    private var fft: FFTReelle

    /// Échantillons pas encore consommés ; `tampon[lecture...]` est utile.
    private var tampon: [Float] = []
    private var lecture = 0
    /// Index global (depuis le début du flux) de la prochaine trame.
    private var indexTrame = 0

    private var reel: [Double]
    private var puissance: [Double]
    private var courant: [(instant: Double, tonalite: Double, frequence: Double)] = []
    private var sifflets: [SiffletDetecte] = []

    /// nil si la fréquence d'échantillonnage ne couvre pas la bande utile.
    public init?(frequenceEchantillonnage fs: Double, parametres: ParametresSifflet = .parDefaut) {
        guard fs > 0, parametres.bandeHaute < fs / 2 else { return nil }
        let taille = DetecteurSifflets.puissanceDeDeux(auMoins: Int(parametres.trame * fs))
        let resolution = fs / Double(taille)
        let caseBasse = max(1, Int((parametres.bandeBasse / resolution).rounded(.down)))
        let caseHaute = min(taille / 2 - 2, Int((parametres.bandeHaute / resolution).rounded(.up)))
        guard taille >= 8, caseBasse < caseHaute else { return nil }
        self.parametres = parametres
        self.frequenceEchantillonnage = fs
        self.taille = taille
        self.pas = taille / 2
        self.hann = (0..<taille).map { 0.5 - 0.5 * cos(2 * Double.pi * Double($0) / Double(taille)) }
        self.caseBasse = caseBasse
        self.caseHaute = caseHaute
        self.fft = FFTReelle(taille: taille)
        self.reel = [Double](repeating: 0, count: taille)
        self.puissance = [Double](repeating: 0, count: taille)
    }

    public mutating func ajouter<C: Collection>(_ echantillons: C) where C.Element == Float {
        tampon.append(contentsOf: echantillons)
        while tampon.count - lecture >= taille {
            analyserTrame(debut: lecture)
            lecture += pas
            indexTrame += pas
        }
        // Compactage : la partie consommée ne doit pas croître sans fin.
        if lecture >= 4 * taille {
            tampon.removeFirst(lecture)
            lecture = 0
        }
    }

    /// Clôt l'analyse et renvoie les sifflets (durée minimale appliquée).
    public mutating func terminer() -> [SiffletDetecte] {
        clore()
        return sifflets.filter { $0.duree >= parametres.dureeMinimale }
    }

    private mutating func analyserTrame(debut: Int) {
        var energie = 0.0
        for i in 0..<taille {
            let v = Double(tampon[debut + i])
            energie += v * v
            reel[i] = v * hann[i]
        }
        let rms = (energie / Double(taille)).squareRoot()
        guard rms >= parametres.energieMinimale else { clore(); return }

        fft.puissance(reel, dans: &puissance)
        var total = 0.0
        for k in 1..<(taille / 2) { total += puissance[k] }
        var pic = caseBasse
        for k in caseBasse...caseHaute where puissance[k] > puissance[pic] { pic = k }
        let tonalite = total > 0 ? (puissance[pic - 1] + puissance[pic] + puissance[pic + 1]) / total : 0
        guard tonalite >= parametres.seuilTonalite else { clore(); return }

        courant.append((
            instant: Double(indexTrame) / frequenceEchantillonnage,
            tonalite: tonalite,
            frequence: Double(pic) * frequenceEchantillonnage / Double(taille)))
    }

    /// Regroupe les trames positives consécutives ; fusionne avec le sifflet
    /// précédent si l'écart est sous `fusionEcart`.
    private mutating func clore() {
        guard let premier = courant.first, let dernier = courant.last else { return }
        let n = Double(courant.count)
        let nouveau = SiffletDetecte(
            debut: premier.instant,
            fin: dernier.instant + Double(taille) / frequenceEchantillonnage,
            frequence: courant.reduce(0) { $0 + $1.frequence } / n,
            tonalite: courant.reduce(0) { $0 + $1.tonalite } / n)
        if let precedent = sifflets.last, nouveau.debut - precedent.fin <= parametres.fusionEcart {
            sifflets[sifflets.count - 1].fin = nouveau.fin
        } else {
            sifflets.append(nouveau)
        }
        courant = []
    }
}

// MARK: - FFT réelle (tampons et facteurs précalculés)

struct FFTReelle: Sendable {
    let taille: Int
    private let inversion: [Int]
    private let cosinus: [Double]
    private let sinus: [Double]
    private var re: [Double]
    private var im: [Double]

    init(taille: Int) {
        self.taille = taille
        var bits = 0
        while (1 << bits) < taille { bits += 1 }
        inversion = (0..<taille).map { i in
            var r = 0
            for b in 0..<bits where i & (1 << b) != 0 { r |= 1 << (bits - 1 - b) }
            return r
        }
        cosinus = (0..<max(1, taille / 2)).map { cos(-2 * Double.pi * Double($0) / Double(taille)) }
        sinus = (0..<max(1, taille / 2)).map { sin(-2 * Double.pi * Double($0) / Double(taille)) }
        re = [Double](repeating: 0, count: taille)
        im = [Double](repeating: 0, count: taille)
    }

    /// |X(k)|² de `signal` (taille `taille`) écrit dans `sortie`.
    mutating func puissance(_ signal: [Double], dans sortie: inout [Double]) {
        for i in 0..<taille {
            re[inversion[i]] = signal[i]
            im[i] = 0
        }
        var longueur = 2
        while longueur <= taille {
            let demi = longueur / 2
            let saut = taille / longueur
            var debut = 0
            while debut < taille {
                for k in 0..<demi {
                    let (wr, wi) = (cosinus[k * saut], sinus[k * saut])
                    let a = debut + k, b = a + demi
                    let tr = re[b] * wr - im[b] * wi
                    let ti = re[b] * wi + im[b] * wr
                    re[b] = re[a] - tr
                    im[b] = im[a] - ti
                    re[a] += tr
                    im[a] += ti
                }
                debut += longueur
            }
            longueur <<= 1
        }
        for k in 0..<taille { sortie[k] = re[k] * re[k] + im[k] * im[k] }
    }
}
