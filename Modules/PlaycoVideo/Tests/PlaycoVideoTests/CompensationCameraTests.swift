//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//

import Foundation
import Testing
@testable import PlaycoVideo

/// Texture lisse (gradins, parquet flous) définie partout, pour simuler une
/// caméra qui se déplace dessus.
enum TextureTest {
    static func valeur(_ x: Double, _ y: Double, clair: Bool = false) -> UInt8 {
        let base = clair ? 200.0 : 120.0
        let v = base + 40 * sin(x / 9) + 30 * cos(y / 7) + 20 * sin((x + y) / 13)
        return UInt8(max(0, min(255, v)))
    }

    /// Grille vue par une caméra décalée de (ox, oy) : g(x, y) = T(x + ox, y + oy).
    static func grille(_ l: Int, _ h: Int, ox: Double = 0, oy: Double = 0, clair: Bool = false,
                       carre: (x: Int, y: Int)? = nil) -> GrilleLuminance {
        var v = [UInt8](repeating: 0, count: l * h)
        for y in 0..<h {
            for x in 0..<l {
                v[y * l + x] = valeur(Double(x) + ox, Double(y) + oy, clair: clair)
                if let c = carre, (c.x..<c.x + 8).contains(x), (c.y..<c.y + 8).contains(y) { v[y * l + x] = 255 }
            }
        }
        return GrilleLuminance(largeur: l, hauteur: h, valeurs: v)
    }
}

@Suite("CompensationCamera — vidéos du web (panoramiques, coupures)")
struct CompensationCameraTests {

    @Test("panoramique pur : déplacement retrouvé, écart résiduel nul")
    func panoramique() throws {
        // La caméra avance de 3 px à droite et monte de 2 px : le contenu
        // glisse de (−3, +2) → b(x, y) = a(x + 3, y − 2).
        let a = TextureTest.grille(64, 48)
        let b = TextureTest.grille(64, 48, ox: 3, oy: -2)
        let m = try #require(CompensationCamera.mesurer(a, b))
        #expect(m.dx == -3)
        #expect(m.dy == 2)
        #expect(m.ecartResiduel < 0.001)
        #expect(m.ecartBrut > 0.02)
        #expect(!m.estCoupure)
    }

    @Test("un joueur qui bouge pendant un panoramique reste visible")
    func joueurPendantPanoramique() throws {
        let a = TextureTest.grille(64, 48, carre: (10, 10))
        let b = TextureTest.grille(64, 48, ox: 2, carre: (20, 14))
        let m = try #require(CompensationCamera.mesurer(a, b))
        #expect(m.dx == -2)
        #expect(m.ecartResiduel > 0.01)
        #expect(m.ecartResiduel < m.ecartBrut)
    }

    @Test("caméra fixe : rien n'est « compensé »")
    func cameraFixe() throws {
        let a = TextureTest.grille(64, 48, carre: (10, 10))
        let b = TextureTest.grille(64, 48, carre: (30, 20))
        let m = try #require(CompensationCamera.mesurer(a, b))
        #expect(m.dx == 0 && m.dy == 0)
        #expect(m.ecartResiduel == m.ecartBrut)
    }

    @Test("coupure de montage détectée ; un panoramique n'en est pas une")
    func coupure() throws {
        let a = TextureTest.grille(64, 48)
        let b = TextureTest.grille(64, 48, clair: true)
        #expect(try #require(CompensationCamera.mesurer(a, b)).estCoupure)
        #expect(!(try #require(CompensationCamera.mesurer(a, TextureTest.grille(64, 48, ox: 4)))).estCoupure)
    }

    @Test("tailles différentes ou trop petites : pas de mesure")
    func tailles() {
        #expect(CompensationCamera.mesurer(TextureTest.grille(64, 48), TextureTest.grille(32, 48)) == nil)
        #expect(CompensationCamera.mesurer(TextureTest.grille(4, 4), TextureTest.grille(4, 4)) == nil)
    }

    @Test("réduction 2×2")
    func reduction() {
        let g = GrilleLuminance(largeur: 4, hauteur: 2, valeurs: [0, 4, 8, 8, 4, 0, 8, 8])
        let r = g.reduite()
        #expect(r.largeur == 2 && r.hauteur == 1)
        #expect(r.valeurs == [2, 8])
    }
}
