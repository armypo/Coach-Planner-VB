//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Mini-terrain 6 zones pour les tendances zonales du scouting (Phase 6).
//  Chaque zone porte un niveau de menace 0-3 ; en mode interactif un tap
//  CYCLE le niveau (0 → 1 → 2 → 3 → 0). Style visuel aligné sur
//  SelecteurZoneView (demi-terrain, zones 4-3-2 avant / 5-6-1 arrière).
//

import SwiftUI

struct MiniTerrainZonesMenace: View {
    let titre: String
    /// Zone (1-6) → niveau de menace 0-3 (absente = 0).
    let niveaux: [Int: Int]
    /// true : tap sur une zone cycle le niveau ; false : lecture seule.
    let estInteractif: Bool
    /// Appelé avec le numéro de zone tapée (mode interactif seulement).
    var onCycleZone: ((Int) -> Void)? = nil

    /// Légende commune des niveaux (affichée une seule fois par section).
    static let legendeNiveaux = "Menace : 0 aucune · 1 faible · 2 moyenne · 3 forte"

    /// Opacités de la teinte PaletteMat.attention par niveau 0-3.
    private static let opacitesNiveau: [Double] = [0.0, 0.30, 0.55, 0.85]

    var body: some View {
        VStack(spacing: LiquidGlassKit.espaceSM) {
            Text(titre)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            terrain
                .aspectRatio(1.0, contentMode: .fit)
                .frame(maxWidth: 260, maxHeight: 260)
                .clipShape(RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMoyen, style: .continuous))
        }
    }

    private func niveauZone(_ zone: Int) -> Int {
        min(max(niveaux[zone] ?? 0, TendancesZonales.niveauMin), TendancesZonales.niveauMax)
    }

    private func couleurNiveau(_ niveau: Int) -> Color {
        PaletteMat.attention.opacity(Self.opacitesNiveau[niveau])
    }

    // MARK: - Terrain

    private var terrain: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            let mx = W * 0.04, my = H * 0.04
            let cl = mx, cr = W - mx, ct = my, cb = H - my
            let cw = cr - cl, ch = cb - ct
            let ligneAttaqueY = ct + ch * (1.0 / 3.0)
            let tiers = cw / 3.0
            let hautAvant = ligneAttaqueY - ct
            let hautArriere = cb - ligneAttaqueY

            let zonesRects: [(Int, CGRect)] = [
                (4, CGRect(x: cl,             y: ct,             width: tiers, height: hautAvant)),
                (3, CGRect(x: cl + tiers,     y: ct,             width: tiers, height: hautAvant)),
                (2, CGRect(x: cl + tiers * 2, y: ct,             width: tiers, height: hautAvant)),
                (5, CGRect(x: cl,             y: ligneAttaqueY,  width: tiers, height: hautArriere)),
                (6, CGRect(x: cl + tiers,     y: ligneAttaqueY,  width: tiers, height: hautArriere)),
                (1, CGRect(x: cl + tiers * 2, y: ligneAttaqueY,  width: tiers, height: hautArriere)),
            ]

            ZStack {
                // Fond terrain (mêmes teintes que SelecteurZoneView)
                RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit)
                    .fill(Color(hex: "#1E5599"))

                Canvas { context, _ in
                    let fondCourt = Color(hex: "#D4B87A")
                    let courtRect = CGRect(x: cl, y: ct, width: cw, height: ch)
                    var courtPath = Path(); courtPath.addRect(courtRect)
                    context.fill(courtPath, with: .color(fondCourt))

                    // Zone avant (3m)
                    let zone3m = CGRect(x: cl, y: ct, width: cw, height: hautAvant)
                    var z3Path = Path(); z3Path.addRect(zone3m)
                    context.fill(z3Path, with: .color(Color(hex: "#6B3A1F")))

                    // Lignes
                    let lw: CGFloat = max(cw * 0.004, 1.5)
                    context.stroke(Path(courtRect), with: .color(.white), lineWidth: lw * 1.2)

                    var laPath = Path()
                    laPath.move(to: CGPoint(x: cl, y: ligneAttaqueY))
                    laPath.addLine(to: CGPoint(x: cr, y: ligneAttaqueY))
                    context.stroke(laPath, with: .color(.white), lineWidth: lw)

                    // Séparateurs verticaux
                    for i in 1..<3 {
                        let x = cl + tiers * CGFloat(i)
                        var sep = Path()
                        sep.move(to: CGPoint(x: x, y: ct))
                        sep.addLine(to: CGPoint(x: x, y: cb))
                        context.stroke(sep, with: .color(.white.opacity(0.3)),
                                       style: StrokeStyle(lineWidth: lw * 0.7, dash: [5, 3]))
                    }

                    // Filet
                    let netLw = max(cw * 0.008, 3.0)
                    var filetPath = Path()
                    filetPath.move(to: CGPoint(x: cl - mx * 0.3, y: ct))
                    filetPath.addLine(to: CGPoint(x: cr + mx * 0.3, y: ct))
                    context.stroke(filetPath, with: .color(.white), lineWidth: netLw)
                }

                // Zones (bouton interactif ou cellule lecture seule)
                ForEach(zonesRects, id: \.0) { zone, rect in
                    celluleZone(zone: zone, rect: rect)
                        .position(x: rect.midX, y: rect.midY)
                }
            }
        }
    }

    @ViewBuilder
    private func celluleZone(zone: Int, rect: CGRect) -> some View {
        let niveau = niveauZone(zone)
        let contenu = VStack(spacing: 2) {
            Text("Z\(zone)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            Text("\(niveau)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(niveau > 0 ? .white : .white.opacity(0.35))
                .contentTransition(.numericText())
        }
        .frame(width: rect.width, height: rect.height)
        .background(
            RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit)
                .fill(couleurNiveau(niveau))
        )
        .contentShape(Rectangle())
        .accessibilityLabel("Zone \(zone), menace \(niveau) sur \(TendancesZonales.niveauMax)")

        if estInteractif {
            Button {
                withAnimation(LiquidGlassKit.springRebond) {
                    onCycleZone?(zone)
                }
            } label: {
                contenu
            }
            .buttonStyle(ZoneMenaceTapStyle())
            .accessibilityHint("Touchez pour passer au niveau de menace suivant")
        } else {
            contenu
        }
    }
}

// MARK: - Style bouton zone

private struct ZoneMenaceTapStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(LiquidGlassKit.springRebond, value: configuration.isPressed)
    }
}
