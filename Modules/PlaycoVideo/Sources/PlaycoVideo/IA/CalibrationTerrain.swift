//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  IA niveau 2 (fondation) — calibration du terrain : le coach touche les 4
//  coins du terrain sur une image de la vidéo ; une homographie relie alors
//  tout point de l'image au terrain réel (mètres). N'importe quel détecteur
//  (ballon, joueurs) devient ainsi une position sur le terrain → zones,
//  trajectoires, heatmaps depuis la vidéo. Sport-agnostique : dimensions du
//  terrain en paramètre ; l'app traduit les positions en zones de son sport.
//

import Foundation

/// Point de l'image, coordonnées normalisées 0-1 (origine en haut à gauche).
public struct PointImage: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

/// Point du terrain en mètres : x le long du terrain (0 → longueur),
/// y en largeur (0 → largeur).
public struct PointTerrain: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

public struct CalibrationTerrain: Codable, Hashable, Sendable {
    public var longueur: Double
    public var largeur: Double
    /// Coins dans l'image, dans l'ordre : (0,0), (longueur,0), (longueur,largeur), (0,largeur).
    public var coinsImage: [PointImage]
    /// Homographie image → terrain (3×3, ligne par ligne).
    public private(set) var versTerrainH: [Double]
    /// Homographie terrain → image.
    public private(set) var versImageH: [Double]

    /// nil si les coins sont dégénérés (confondus, alignés, mal ordonnés).
    public init?(coinsImage: [PointImage], longueur: Double = 18, largeur: Double = 9) {
        guard coinsImage.count == 4, longueur > 0, largeur > 0, Self.estConvexe(coinsImage) else { return nil }
        let coinsTerrain = [PointTerrain(x: 0, y: 0), PointTerrain(x: longueur, y: 0),
                            PointTerrain(x: longueur, y: largeur), PointTerrain(x: 0, y: largeur)]
        guard let directe = Self.homographie(de: coinsImage.map { ($0.x, $0.y) }, vers: coinsTerrain.map { ($0.x, $0.y) }),
              let inverse = Self.inverser(directe) else { return nil }
        self.longueur = longueur
        self.largeur = largeur
        self.coinsImage = coinsImage
        self.versTerrainH = directe
        self.versImageH = inverse
    }

    public func versTerrain(_ p: PointImage) -> PointTerrain? {
        Self.appliquer(versTerrainH, p.x, p.y).map { PointTerrain(x: $0.0, y: $0.1) }
    }

    public func versImage(_ p: PointTerrain) -> PointImage? {
        Self.appliquer(versImageH, p.x, p.y).map { PointImage(x: $0.0, y: $0.1) }
    }

    /// Vrai si le point (avec `marge` en mètres) est sur le terrain.
    public func estSurTerrain(_ p: PointTerrain, marge: Double = 0) -> Bool {
        p.x >= -marge && p.x <= longueur + marge && p.y >= -marge && p.y <= largeur + marge
    }

    /// Cellule d'une grille `colonnes` × `rangees` posée sur UNE moitié du
    /// terrain (0 = moitié x < longueur/2), mesurée depuis le filet :
    /// rangée 0 = la plus proche du filet. nil hors terrain.
    public func cellule(_ p: PointTerrain, colonnes: Int, rangees: Int) -> (moitie: Int, colonne: Int, rangee: Int)? {
        guard colonnes > 0, rangees > 0, estSurTerrain(p) else { return nil }
        let demi = longueur / 2
        let moitie = p.x < demi ? 0 : 1
        let distanceFilet = moitie == 0 ? demi - p.x : p.x - demi
        let rangee = min(rangees - 1, Int(distanceFilet / (demi / Double(rangees))))
        // Colonnes lues face au filet : la gauche du joueur dépend de la moitié.
        let travers = moitie == 0 ? p.y : largeur - p.y
        let colonne = min(colonnes - 1, Int(travers / (largeur / Double(colonnes))))
        return (moitie, colonne, rangee)
    }

    // MARK: - Calcul

    /// Quadrilatère convexe parcouru dans un seul sens (sinon coins mal
    /// ordonnés ou alignés : la vue d'un rectangle est toujours convexe).
    static func estConvexe(_ p: [PointImage]) -> Bool {
        let produits = (0..<4).map { i -> Double in
            let a = p[i], b = p[(i + 1) % 4], c = p[(i + 2) % 4]
            return (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)
        }
        return produits.allSatisfy { $0 > 1e-9 } || produits.allSatisfy { $0 < -1e-9 }
    }

    /// Homographie H (h33 = 1) telle que H·(x, y, 1) ∝ (u, v, 1), par
    /// résolution du système 8×8 (élimination de Gauss à pivot partiel).
    static func homographie(de source: [(Double, Double)], vers cible: [(Double, Double)]) -> [Double]? {
        guard source.count == 4, cible.count == 4 else { return nil }
        var a = [[Double]]()
        var b = [Double]()
        for ((x, y), (u, v)) in zip(source, cible) {
            a.append([x, y, 1, 0, 0, 0, -u * x, -u * y]); b.append(u)
            a.append([0, 0, 0, x, y, 1, -v * x, -v * y]); b.append(v)
        }
        guard let h = resoudre(a, b) else { return nil }
        return h + [1]
    }

    static func resoudre(_ matrice: [[Double]], _ second: [Double]) -> [Double]? {
        var a = matrice
        var b = second
        let n = b.count
        for colonne in 0..<n {
            var pivot = colonne
            for ligne in colonne..<n where abs(a[ligne][colonne]) > abs(a[pivot][colonne]) { pivot = ligne }
            guard abs(a[pivot][colonne]) > 1e-12 else { return nil }
            a.swapAt(colonne, pivot)
            b.swapAt(colonne, pivot)
            for ligne in (colonne + 1)..<n {
                let facteur = a[ligne][colonne] / a[colonne][colonne]
                guard facteur != 0 else { continue }
                for k in colonne..<n { a[ligne][k] -= facteur * a[colonne][k] }
                b[ligne] -= facteur * b[colonne]
            }
        }
        var x = [Double](repeating: 0, count: n)
        for ligne in stride(from: n - 1, through: 0, by: -1) {
            var somme = b[ligne]
            for k in (ligne + 1)..<n { somme -= a[ligne][k] * x[k] }
            x[ligne] = somme / a[ligne][ligne]
        }
        return x.allSatisfy(\.isFinite) ? x : nil
    }

    static func inverser(_ h: [Double]) -> [Double]? {
        let (a, b, c, d, e, f, g, i, j) = (h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7], h[8])
        let det = a * (e * j - f * i) - b * (d * j - f * g) + c * (d * i - e * g)
        guard abs(det) > 1e-12 else { return nil }
        let inv = [e * j - f * i, c * i - b * j, b * f - c * e,
                   f * g - d * j, a * j - c * g, c * d - a * f,
                   d * i - e * g, b * g - a * i, a * e - b * d]
        return inv.map { $0 / det }
    }

    static func appliquer(_ h: [Double], _ x: Double, _ y: Double) -> (Double, Double)? {
        let w = h[6] * x + h[7] * y + h[8]
        guard abs(w) > 1e-12 else { return nil }
        return ((h[0] * x + h[1] * y + h[2]) / w, (h[3] * x + h[4] * y + h[5]) / w)
    }
}
