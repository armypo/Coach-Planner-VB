//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI

// MARK: - Grains de sable pré-calculés (P0-04 — évite 100 calculs/frame)
private struct GrainSable {
    let x: CGFloat  // facteur 0-1 de la largeur
    let y: CGFloat  // facteur 0-1 de la hauteur
    let radius: CGFloat
    let estClair: Bool
}

private let grainsPreCalcules: [GrainSable] = (0..<100).map { i in
    let s1 = Double(i * 7 + 3)
    let s2 = Double(i * 13 + 7)
    return GrainSable(
        x: CGFloat((s1.truncatingRemainder(dividingBy: 97)) / 97.0),
        y: CGFloat((s2.truncatingRemainder(dividingBy: 89)) / 89.0),
        radius: CGFloat(1.0 + (s1.truncatingRemainder(dividingBy: 2.5))),
        estClair: i % 2 == 0
    )
}

struct TerrainVolleyView: View {
    var afficherZones: Bool = true
    var typeTerrain: TypeTerrain = .indoor

    var body: some View {
        Canvas { context, size in
            let W = size.width, H = size.height
            let estVertical = H > W * 1.2

            if estVertical {
                // Mode vertical : net horizontal, zones haut/bas
                let mx = W * 0.07, my = H * 0.04
                let cl = mx, cr = W - mx, ct = my, cb = H - my
                let cw = cr - cl, ch = cb - ct
                let ny = (ct + cb) / 2

                switch typeTerrain {
                case .indoor:
                    dessinerIndoorParquetVertical(context: &context,
                        W: W, H: H, mx: mx, my: my,
                        cl: cl, cr: cr, ct: ct, cb: cb,
                        cw: cw, ch: ch, ny: ny)
                case .beach:
                    dessinerBeachSableVertical(context: &context,
                        W: W, H: H, mx: mx, my: my,
                        cl: cl, cr: cr, ct: ct, cb: cb,
                        cw: cw, ch: ch, ny: ny)
                }
            } else {
                // Mode horizontal : net vertical, zones gauche/droite
                let mx = W * 0.04, my = H * 0.07
                let cl = mx, cr = W - mx, ct = my, cb = H - my
                let cw = cr - cl, ch = cb - ct
                let nx = (cl + cr) / 2

                switch typeTerrain {
                case .indoor:
                    dessinerIndoorParquet(context: &context,
                        W: W, H: H, mx: mx, my: my,
                        cl: cl, cr: cr, ct: ct, cb: cb,
                        cw: cw, ch: ch, nx: nx)
                case .beach:
                    dessinerBeachSable(context: &context,
                        W: W, H: H, mx: mx, my: my,
                        cl: cl, cr: cr, ct: ct, cb: cb,
                        cw: cw, ch: ch, nx: nx)
                }
            }
        }
    }

    // =========================================================================
    // MARK: - Indoor — Parquet, zone 3m brun foncé, reste beige, extérieur bleu
    // =========================================================================
    private func dessinerIndoorParquet(
        context: inout GraphicsContext,
        W: CGFloat, H: CGFloat, mx: CGFloat, my: CGFloat,
        cl: CGFloat, cr: CGFloat, ct: CGFloat, cb: CGFloat,
        cw: CGFloat, ch: CGFloat, nx: CGFloat
    ) {
        let courtRect = CGRect(x: cl, y: ct, width: cw, height: ch)
        let ad = cw / 6   // distance ligne 3m depuis le filet
        let alL = nx - ad  // ligne d'attaque gauche
        let alR = nx + ad  // ligne d'attaque droite

        // ── 1. Extérieur bleu
        let bleuExt = Color(hex: "#1E5599")
        var bg = Path(); bg.addRect(CGRect(x: 0, y: 0, width: W, height: H))
        context.fill(bg, with: .color(bleuExt))

        // ── 2. Surface complète beige clair (parquet)
        let beige = Color(hex: "#D4B87A")
        var surface = Path(); surface.addRect(courtRect)
        context.fill(surface, with: .color(beige))

        // ── 3. Texture parquet — lignes verticales fines
        let parquetLine = Color(hex: "#C4A868").opacity(0.5)
        let espacement: CGFloat = max(cw * 0.018, 8)
        for x in stride(from: cl, through: cr, by: espacement) {
            context.stroke(
                lignePath(x, ct, x, cb),
                with: .color(parquetLine),
                style: StrokeStyle(lineWidth: 0.5)
            )
        }

        // ── 4. Zones 3m — brun foncé (entre ligne d'attaque et filet)
        let brunFonce = Color(hex: "#6B3A1F")
        let zone3mGauche = CGRect(x: alL, y: ct, width: ad, height: ch)
        let zone3mDroite = CGRect(x: nx, y: ct, width: ad, height: ch)
        var z3g = Path(); z3g.addRect(zone3mGauche)
        var z3d = Path(); z3d.addRect(zone3mDroite)
        context.fill(z3g, with: .color(brunFonce))
        context.fill(z3d, with: .color(brunFonce))

        // Texture parquet dans zones 3m aussi
        let parquetLineDark = Color(hex: "#5A2E15").opacity(0.4)
        for x in stride(from: alL, through: alR, by: espacement) {
            context.stroke(
                lignePath(x, ct, x, cb),
                with: .color(parquetLineDark),
                style: StrokeStyle(lineWidth: 0.5)
            )
        }

        // ── 5. Lignes blanches
        let lw = max(cw * 0.003, 1.5)
        let netLw = max(cw * 0.009, 4.0)
        let blanc = Color.white

        // Contour
        context.stroke(Path(courtRect), with: .color(blanc), lineWidth: lw * 1.2)

        // Lignes d'attaque
        context.stroke(lignePath(alL, ct, alL, cb), with: .color(blanc), lineWidth: lw)
        context.stroke(lignePath(alR, ct, alR, cb), with: .color(blanc), lineWidth: lw)

        // Filet — blanc épais
        context.stroke(lignePath(nx, ct, nx, cb), with: .color(blanc), lineWidth: netLw)

        // ── 6. Numéros de zones
        if afficherZones {
            let fs = min(ch * 0.20, 30.0)
            let bA = (cl + alL) / 2, fA = (alL + nx) / 2
            let fB = (nx + alR) / 2, bB = (alR + cr) / 2
            let r1 = ct + ch / 6, r2 = ct + ch / 2, r3 = ct + ch * 5 / 6
            let zones: [(String, CGFloat, CGFloat)] = [
                ("5", bA, r1), ("6", bA, r2), ("1", bA, r3),
                ("4", fA, r1), ("3", fA, r2), ("2", fA, r3),
                ("2", fB, r1), ("3", fB, r2), ("4", fB, r3),
                ("1", bB, r1), ("6", bB, r2), ("5", bB, r3)
            ]
            for (txt, x, y) in zones {
                // Zones 3m : texte plus clair, zones arrière : texte plus foncé
                let estZone3m = (x > alL - 5 && x < alR + 5)
                let alpha: Double = estZone3m ? 0.20 : 0.15
                let couleurTxt = estZone3m ? Color.white : Color(hex: "#5A3A1A")
                context.draw(
                    Text(txt).font(.system(size: fs, weight: .heavy))
                        .foregroundStyle(couleurTxt.opacity(alpha)),
                    at: CGPoint(x: x, y: y)
                )
            }
        }

        // ── 7. Labels "3 m"
        let labelFS = min(ch * 0.09, 12.0)
        for ax in [alL, alR] {
            context.draw(
                Text("3 m").font(.system(size: labelFS, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.5)),
                at: CGPoint(x: ax, y: cb + my * 0.55)
            )
        }
    }

    // =========================================================================
    // MARK: - Beach — Sable beige/blanc, lignes bleues, extérieur même sable
    // =========================================================================
    private func dessinerBeachSable(
        context: inout GraphicsContext,
        W: CGFloat, H: CGFloat, mx: CGFloat, my: CGFloat,
        cl: CGFloat, cr: CGFloat, ct: CGFloat, cb: CGFloat,
        cw: CGFloat, ch: CGFloat, nx: CGFloat
    ) {
        let courtRect = CGRect(x: cl, y: ct, width: cw, height: ch)

        // ── 1. Fond sable uniforme (extérieur = même couleur que le terrain)
        let sable = Color(hex: "#E2D5B0")
        var bg = Path(); bg.addRect(CGRect(x: 0, y: 0, width: W, height: H))
        context.fill(bg, with: .color(sable))

        // ── 2. Surface de jeu — sable légèrement plus clair (beige/blanc)
        let sableClair = Color(hex: "#F0E8D0")
        var surface = Path(); surface.addRect(courtRect)
        context.fill(surface, with: .linearGradient(
            Gradient(colors: [sableClair, Color(hex: "#EDE3C8"), sableClair]),
            startPoint: CGPoint(x: cl, y: ct),
            endPoint: CGPoint(x: cr, y: cb)
        ))

        // ── 3. Texture sable — grains (P0-04 — positions pré-calculées)
        let grainClair = Color.white.opacity(0.25)
        let grainFonce = Color(hex: "#C8B888").opacity(0.3)
        for grain in grainsPreCalcules {
            let gx = grain.x * W
            let gy = grain.y * H
            let gr = grain.radius
            var path = Path()
            path.addEllipse(in: CGRect(x: gx - gr, y: gy - gr, width: gr * 2, height: gr * 2))
            context.fill(path, with: .color(grain.estClair ? grainClair : grainFonce))
        }

        // ── 4. Ondulations subtiles (effet sable)
        let ondulColor = Color(hex: "#D0C498").opacity(0.35)
        for j in 0..<6 {
            let oy = H * (0.10 + Double(j) * 0.16)
            var ondulation = Path()
            ondulation.move(to: CGPoint(x: 4, y: oy))
            let amp: CGFloat = 2.5
            let freq: CGFloat = W / 14
            for k in stride(from: CGFloat(0), through: W - 8, by: 2) {
                let ox = 4 + k
                let ody = oy + amp * sin(k / freq * .pi * 2 + CGFloat(j) * 1.8)
                ondulation.addLine(to: CGPoint(x: ox, y: ody))
            }
            context.stroke(ondulation, with: .color(ondulColor),
                           style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
        }

        // ── 5. Lignes bleues
        let lw = max(cw * 0.004, 1.8)
        let netLw = max(cw * 0.008, 3.5)
        let bleuLigne = Color(hex: "#2566CC")

        // Contour
        context.stroke(Path(courtRect), with: .color(bleuLigne), lineWidth: lw * 1.3)

        // Coins — pastilles bleues (ancres)
        let coinSize: CGFloat = max(lw * 3, 6)
        let coins = [
            CGPoint(x: cl, y: ct), CGPoint(x: cr, y: ct),
            CGPoint(x: cl, y: cb), CGPoint(x: cr, y: cb)
        ]
        for c in coins {
            var coin = Path()
            coin.addEllipse(in: CGRect(x: c.x - coinSize/2, y: c.y - coinSize/2,
                                        width: coinSize, height: coinSize))
            context.fill(coin, with: .color(bleuLigne))
        }

        // ── 6. Filet
        // Poteaux gris dépassant
        let poteauColor = Color(hex: "#888888")
        let poteauW: CGFloat = max(lw * 1.5, 3)
        context.stroke(
            lignePath(nx, ct - my * 0.2, nx, cb + my * 0.2),
            with: .color(poteauColor), lineWidth: poteauW
        )
        // Filet blanc
        context.stroke(
            lignePath(nx, ct, nx, cb),
            with: .color(.white), lineWidth: netLw
        )
        // Pastilles poteaux
        let pSize: CGFloat = max(coinSize * 0.8, 5)
        for py in [ct - my * 0.15, cb + my * 0.15] {
            var poteau = Path()
            poteau.addEllipse(in: CGRect(x: nx - pSize/2, y: py - pSize/2,
                                          width: pSize, height: pSize))
            context.fill(poteau, with: .color(poteauColor))
        }

        // ── 7. Label "Beach"
        let labelFS = min(ch * 0.09, 12.0)
        context.draw(
            Text("Beach").font(.system(size: labelFS, weight: .semibold))
                .foregroundStyle(Color(hex: "#A09060").opacity(0.5)),
            at: CGPoint(x: cl + cw * 0.08, y: cb + my * 0.55)
        )
    }

    // =========================================================================
    // MARK: - Indoor Vertical — Parquet, net horizontal, zones haut/bas
    // =========================================================================
    private func dessinerIndoorParquetVertical(
        context: inout GraphicsContext,
        W: CGFloat, H: CGFloat, mx: CGFloat, my: CGFloat,
        cl: CGFloat, cr: CGFloat, ct: CGFloat, cb: CGFloat,
        cw: CGFloat, ch: CGFloat, ny: CGFloat
    ) {
        let courtRect = CGRect(x: cl, y: ct, width: cw, height: ch)
        let ad = ch / 6   // distance ligne 3m depuis le filet (vertical)
        let alT = ny - ad  // ligne d'attaque haut (adversaire)
        let alB = ny + ad  // ligne d'attaque bas (nous)

        // ── 1. Extérieur bleu
        let bleuExt = Color(hex: "#1E5599")
        var bg = Path(); bg.addRect(CGRect(x: 0, y: 0, width: W, height: H))
        context.fill(bg, with: .color(bleuExt))

        // ── 2. Surface complète beige clair (parquet)
        let beige = Color(hex: "#D4B87A")
        var surface = Path(); surface.addRect(courtRect)
        context.fill(surface, with: .color(beige))

        // ── 3. Texture parquet — lignes horizontales
        let parquetLine = Color(hex: "#C4A868").opacity(0.5)
        let espacement: CGFloat = max(ch * 0.018, 8)
        for y in stride(from: ct, through: cb, by: espacement) {
            context.stroke(
                lignePath(cl, y, cr, y),
                with: .color(parquetLine),
                style: StrokeStyle(lineWidth: 0.5)
            )
        }

        // ── 4. Zones 3m — brun foncé (entre ligne d'attaque et filet)
        let brunFonce = Color(hex: "#6B3A1F")
        let zone3mHaut = CGRect(x: cl, y: alT, width: cw, height: ad)
        let zone3mBas = CGRect(x: cl, y: ny, width: cw, height: ad)
        var z3h = Path(); z3h.addRect(zone3mHaut)
        var z3b = Path(); z3b.addRect(zone3mBas)
        context.fill(z3h, with: .color(brunFonce))
        context.fill(z3b, with: .color(brunFonce))

        // Texture parquet dans zones 3m
        let parquetLineDark = Color(hex: "#5A2E15").opacity(0.4)
        for y in stride(from: alT, through: alB, by: espacement) {
            context.stroke(
                lignePath(cl, y, cr, y),
                with: .color(parquetLineDark),
                style: StrokeStyle(lineWidth: 0.5)
            )
        }

        // ── 5. Lignes blanches
        let lw = max(ch * 0.003, 1.5)
        let netLw = max(ch * 0.009, 4.0)
        let blanc = Color.white

        // Contour
        context.stroke(Path(courtRect), with: .color(blanc), lineWidth: lw * 1.2)

        // Lignes d'attaque (horizontales)
        context.stroke(lignePath(cl, alT, cr, alT), with: .color(blanc), lineWidth: lw)
        context.stroke(lignePath(cl, alB, cr, alB), with: .color(blanc), lineWidth: lw)

        // Filet — blanc épais (horizontal)
        context.stroke(lignePath(cl, ny, cr, ny), with: .color(blanc), lineWidth: netLw)

        // ── 6. Numéros de zones
        if afficherZones {
            let fs = min(cw * 0.20, 30.0)
            // Adversaire (haut) : zones vues depuis l'autre côté
            let aT1 = ct + (alT - ct) / 6, aT2 = ct + (alT - ct) / 2, aT3 = ct + (alT - ct) * 5 / 6
            let fT1 = alT + ad / 6, fT2 = alT + ad / 2, fT3 = alT + ad * 5 / 6
            let c1 = cl + cw / 6, c2 = cl + cw / 2, c3 = cl + cw * 5 / 6

            // Adversaire arrière (haut)
            let zonesAdvArr: [(String, CGFloat, CGFloat)] = [
                ("1", c1, aT2), ("6", c2, aT2), ("5", c3, aT2)
            ]
            // Adversaire avant (milieu haut)
            let zonesAdvAvt: [(String, CGFloat, CGFloat)] = [
                ("2", c1, fT2), ("3", c2, fT2), ("4", c3, fT2)
            ]

            // Notre équipe (bas)
            let fB1 = ny + ad / 6, fB2 = ny + ad / 2, fB3 = ny + ad * 5 / 6
            let bB1 = alB + (cb - alB) / 6, bB2 = alB + (cb - alB) / 2, bB3 = alB + (cb - alB) * 5 / 6

            // Nous avant (milieu bas)
            let zonesNousAvt: [(String, CGFloat, CGFloat)] = [
                ("4", c1, fB2), ("3", c2, fB2), ("2", c3, fB2)
            ]
            // Nous arrière (bas)
            let zonesNousArr: [(String, CGFloat, CGFloat)] = [
                ("5", c1, bB2), ("6", c2, bB2), ("1", c3, bB2)
            ]

            let toutesZones = zonesAdvArr + zonesAdvAvt + zonesNousAvt + zonesNousArr
            for (txt, x, y) in toutesZones {
                let estZone3m = (y > alT - 5 && y < alB + 5)
                let alpha: Double = estZone3m ? 0.20 : 0.15
                let couleurTxt = estZone3m ? Color.white : Color(hex: "#5A3A1A")
                context.draw(
                    Text(txt).font(.system(size: fs, weight: .heavy))
                        .foregroundStyle(couleurTxt.opacity(alpha)),
                    at: CGPoint(x: x, y: y)
                )
            }
        }

        // ── 7. Labels "3 m"
        let labelFS = min(cw * 0.09, 12.0)
        for ay in [alT, alB] {
            context.draw(
                Text("3 m").font(.system(size: labelFS, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.5)),
                at: CGPoint(x: cr + mx * 0.55, y: ay)
            )
        }
    }

    // =========================================================================
    // MARK: - Beach Vertical — Sable, net horizontal, zones haut/bas
    // =========================================================================
    private func dessinerBeachSableVertical(
        context: inout GraphicsContext,
        W: CGFloat, H: CGFloat, mx: CGFloat, my: CGFloat,
        cl: CGFloat, cr: CGFloat, ct: CGFloat, cb: CGFloat,
        cw: CGFloat, ch: CGFloat, ny: CGFloat
    ) {
        let courtRect = CGRect(x: cl, y: ct, width: cw, height: ch)

        // ── 1. Fond sable
        let sable = Color(hex: "#E2D5B0")
        var bg = Path(); bg.addRect(CGRect(x: 0, y: 0, width: W, height: H))
        context.fill(bg, with: .color(sable))

        // ── 2. Surface de jeu
        let sableClair = Color(hex: "#F0E8D0")
        var surface = Path(); surface.addRect(courtRect)
        context.fill(surface, with: .linearGradient(
            Gradient(colors: [sableClair, Color(hex: "#EDE3C8"), sableClair]),
            startPoint: CGPoint(x: cl, y: ct),
            endPoint: CGPoint(x: cr, y: cb)
        ))

        // ── 3. Texture sable
        let grainClair = Color.white.opacity(0.25)
        let grainFonce = Color(hex: "#C8B888").opacity(0.3)
        for grain in grainsPreCalcules {
            let gx = grain.x * W
            let gy = grain.y * H
            let gr = grain.radius
            var path = Path()
            path.addEllipse(in: CGRect(x: gx - gr, y: gy - gr, width: gr * 2, height: gr * 2))
            context.fill(path, with: .color(grain.estClair ? grainClair : grainFonce))
        }

        // ── 4. Ondulations verticales
        let ondulColor = Color(hex: "#D0C498").opacity(0.35)
        for j in 0..<6 {
            let ox = W * (0.10 + Double(j) * 0.16)
            var ondulation = Path()
            ondulation.move(to: CGPoint(x: ox, y: 4))
            let amp: CGFloat = 2.5
            let freq: CGFloat = H / 14
            for k in stride(from: CGFloat(0), through: H - 8, by: 2) {
                let oy = 4 + k
                let odx = ox + amp * sin(k / freq * .pi * 2 + CGFloat(j) * 1.8)
                ondulation.addLine(to: CGPoint(x: odx, y: oy))
            }
            context.stroke(ondulation, with: .color(ondulColor),
                           style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
        }

        // ── 5. Lignes bleues
        let lw = max(ch * 0.004, 1.8)
        let netLw = max(ch * 0.008, 3.5)
        let bleuLigne = Color(hex: "#2566CC")

        context.stroke(Path(courtRect), with: .color(bleuLigne), lineWidth: lw * 1.3)

        // Coins
        let coinSize: CGFloat = max(lw * 3, 6)
        let coins = [
            CGPoint(x: cl, y: ct), CGPoint(x: cr, y: ct),
            CGPoint(x: cl, y: cb), CGPoint(x: cr, y: cb)
        ]
        for c in coins {
            var coin = Path()
            coin.addEllipse(in: CGRect(x: c.x - coinSize/2, y: c.y - coinSize/2,
                                        width: coinSize, height: coinSize))
            context.fill(coin, with: .color(bleuLigne))
        }

        // ── 6. Filet horizontal
        let poteauColor = Color(hex: "#888888")
        let poteauW: CGFloat = max(lw * 1.5, 3)
        context.stroke(
            lignePath(cl - mx * 0.2, ny, cr + mx * 0.2, ny),
            with: .color(poteauColor), lineWidth: poteauW
        )
        context.stroke(
            lignePath(cl, ny, cr, ny),
            with: .color(.white), lineWidth: netLw
        )
        let pSize: CGFloat = max(coinSize * 0.8, 5)
        for px in [cl - mx * 0.15, cr + mx * 0.15] {
            var poteau = Path()
            poteau.addEllipse(in: CGRect(x: px - pSize/2, y: ny - pSize/2,
                                          width: pSize, height: pSize))
            context.fill(poteau, with: .color(poteauColor))
        }

        // ── 7. Label "Beach"
        let labelFS = min(cw * 0.09, 12.0)
        context.draw(
            Text("Beach").font(.system(size: labelFS, weight: .semibold))
                .foregroundStyle(Color(hex: "#A09060").opacity(0.5)),
            at: CGPoint(x: cr + mx * 0.55, y: ct + ch * 0.08)
        )
    }

    // MARK: - Helper
    private func lignePath(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: x1, y: y1))
        p.addLine(to: CGPoint(x: x2, y: y2))
        return p
    }
}

#Preview("Indoor Horizontal") {
    TerrainVolleyView(typeTerrain: .indoor)
        .aspectRatio(2.0, contentMode: .fit)
        .padding()
}

#Preview("Indoor Vertical") {
    TerrainVolleyView(typeTerrain: .indoor)
        .aspectRatio(0.5, contentMode: .fit)
        .padding()
}

#Preview("Beach Horizontal") {
    TerrainVolleyView(typeTerrain: .beach)
        .aspectRatio(2.0, contentMode: .fit)
        .padding()
}

#Preview("Beach Vertical") {
    TerrainVolleyView(typeTerrain: .beach)
        .aspectRatio(0.5, contentMode: .fit)
        .padding()
}
