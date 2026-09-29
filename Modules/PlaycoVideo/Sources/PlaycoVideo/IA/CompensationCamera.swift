//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Vidéos « du web » (YouTube, diffusions) : la caméra bouge. Un panoramique
//  fait changer toute l'image sans qu'aucun joueur ne bouge, et une coupure
//  de montage change tout d'un coup. Pour que l'activité mesure le JEU et
//  non la caméra :
//  - on estime le déplacement global entre deux images (recherche grossière
//    sur une grille réduite, puis affinage) et on ne garde que l'écart
//    RÉSIDUEL une fois ce déplacement retiré ;
//  - on repère les coupures (histogrammes de luminance très différents) et
//    on ne les compte pas comme de l'activité.
//  Logique pure, testable partout ; l'extraction des images vit côté Apple.
//

import Foundation

/// Image en niveaux de gris, sous-échantillonnée (plan de luminance).
public struct GrilleLuminance: Hashable, Sendable {
    public var largeur: Int
    public var hauteur: Int
    /// Ligne par ligne, `largeur × hauteur` valeurs.
    public var valeurs: [UInt8]

    public init(largeur: Int, hauteur: Int, valeurs: [UInt8]) {
        self.largeur = largeur
        self.hauteur = hauteur
        self.valeurs = valeurs
    }

    @inline(__always) func valeur(_ x: Int, _ y: Int) -> UInt8 { valeurs[y * largeur + x] }

    /// Moitié de la résolution (moyenne de blocs 2×2).
    func reduite() -> GrilleLuminance {
        let l = largeur / 2, h = hauteur / 2
        var sortie = [UInt8](repeating: 0, count: l * h)
        for y in 0..<h {
            for x in 0..<l {
                let somme = Int(valeur(2 * x, 2 * y)) + Int(valeur(2 * x + 1, 2 * y))
                    + Int(valeur(2 * x, 2 * y + 1)) + Int(valeur(2 * x + 1, 2 * y + 1))
                sortie[y * l + x] = UInt8(somme / 4)
            }
        }
        return GrilleLuminance(largeur: l, hauteur: h, valeurs: sortie)
    }
}

public struct MesureMouvement: Hashable, Sendable {
    /// Écart moyen (0-1) une fois le déplacement de la caméra retiré.
    public var ecartResiduel: Double
    /// Écart moyen (0-1) brut, sans compensation.
    public var ecartBrut: Double
    /// Déplacement global estimé (pixels de la grille) : b(x, y) ≈ a(x − dx, y − dy).
    public var dx: Int
    public var dy: Int
    /// Changement de plan (coupure de montage) : l'écart ne mesure pas le jeu.
    public var estCoupure: Bool
}

public enum CompensationCamera {

    /// Seuil de coupure : distance entre histogrammes (0-1). ESTIMÉ.
    public static let seuilCoupure = 0.4

    /// Mouvement entre deux images successives de même taille.
    /// - Parameter rayon: déplacement maximal cherché, en pixels de la grille RÉDUITE.
    public static func mesurer(_ a: GrilleLuminance, _ b: GrilleLuminance, rayon: Int = 3) -> MesureMouvement? {
        guard a.largeur == b.largeur, a.hauteur == b.hauteur, a.largeur >= 8, a.hauteur >= 8,
              a.valeurs.count == a.largeur * a.hauteur, b.valeurs.count == b.largeur * b.hauteur else { return nil }
        let brut = ecartMoyen(a, b, 0, 0)
        let coupure = distanceHistogrammes(a, b) > seuilCoupure

        // Grossier sur la grille réduite, puis affinage ±1 à pleine résolution.
        let (ra, rb) = (a.reduite(), b.reduite())
        var meilleur = (dx: 0, dy: 0, ecart: Double.infinity)
        for dy in -rayon...rayon {
            for dx in -rayon...rayon {
                let e = ecartMoyen(ra, rb, dx, dy)
                if e < meilleur.ecart { meilleur = (dx, dy, e) }
            }
        }
        var fin = (dx: 2 * meilleur.dx, dy: 2 * meilleur.dy, ecart: Double.infinity)
        let centre = fin
        for dy in (centre.dy - 1)...(centre.dy + 1) {
            for dx in (centre.dx - 1)...(centre.dx + 1) {
                let e = ecartMoyen(a, b, dx, dy)
                if e < fin.ecart { fin = (dx, dy, e) }
            }
        }
        // Le résiduel ne dépasse jamais le brut (pas de compensation fantôme).
        let residuel = min(fin.ecart, brut)
        return MesureMouvement(ecartResiduel: residuel, ecartBrut: brut,
                               dx: residuel < brut ? fin.dx : 0, dy: residuel < brut ? fin.dy : 0,
                               estCoupure: coupure)
    }

    /// Écart absolu moyen (0-1) entre b(x, y) et a(x − dx, y − dy) sur la zone
    /// commune ; +∞ si la zone commune couvre moins de la moitié de l'image.
    static func ecartMoyen(_ a: GrilleLuminance, _ b: GrilleLuminance, _ dx: Int, _ dy: Int) -> Double {
        let x0 = max(0, dx), x1 = min(b.largeur, a.largeur + dx)
        let y0 = max(0, dy), y1 = min(b.hauteur, a.hauteur + dy)
        guard x1 > x0, y1 > y0 else { return .infinity }
        let n = (x1 - x0) * (y1 - y0)
        guard 2 * n >= b.largeur * b.hauteur else { return .infinity }
        var somme = 0
        for y in y0..<y1 {
            let ligneB = y * b.largeur, ligneA = (y - dy) * a.largeur - dx
            for x in x0..<x1 {
                somme += abs(Int(b.valeurs[ligneB + x]) - Int(a.valeurs[ligneA + x]))
            }
        }
        return Double(somme) / Double(n) / 255
    }

    /// Distance entre histogrammes de luminance (32 cases), 0 = identiques, 1 = disjoints.
    static func distanceHistogrammes(_ a: GrilleLuminance, _ b: GrilleLuminance) -> Double {
        func histogramme(_ g: GrilleLuminance) -> [Double] {
            var h = [Double](repeating: 0, count: 32)
            for v in g.valeurs { h[Int(v) >> 3] += 1 }
            let total = Double(max(1, g.valeurs.count))
            return h.map { $0 / total }
        }
        let (ha, hb) = (histogramme(a), histogramme(b))
        return zip(ha, hb).reduce(0) { $0 + abs($1.0 - $1.1) } / 2
    }
}
