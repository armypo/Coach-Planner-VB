//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI

/// Mini demi-terrain avec 6 zones tapables pour assigner une zone à un point
struct SelecteurZoneView: View {
    let categorieHeatmap: DonneesHeatmap.CategorieHeatmap?
    let onZoneSelectionnee: (Int) -> Void
    let onPasser: () -> Void

    private let couleurAccent: Color

    init(
        categorieHeatmap: DonneesHeatmap.CategorieHeatmap?,
        onZoneSelectionnee: @escaping (Int) -> Void,
        onPasser: @escaping () -> Void
    ) {
        self.categorieHeatmap = categorieHeatmap
        self.onZoneSelectionnee = onZoneSelectionnee
        self.onPasser = onPasser
        self.couleurAccent = categorieHeatmap?.couleurAccent ?? PaletteMat.orange
    }

    var body: some View {
        VStack(spacing: LiquidGlassKit.espaceMD) {
            HStack {
                Image(systemName: "square.grid.3x3.fill")
                    .foregroundStyle(couleurAccent)
                Text("Zone de l'action")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("Passer") {
                    onPasser()
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PaletteMat.texteSecondaire)
            }

            // Mini terrain 6 zones
            miniTerrain
                .aspectRatio(1.0, contentMode: .fit)
                .frame(maxWidth: 280, maxHeight: 280)
                .clipShape(RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMoyen, style: .continuous))
        }
        .padding(LiquidGlassKit.espaceMD)
    }

    // MARK: - Mini terrain

    private var miniTerrain: some View {
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
                // Fond terrain
                RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit)
                    .fill(Color(hex: "#1E5599"))

                // Court
                Canvas { context, size in
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

                    // Separateurs verticaux
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

                // Boutons zones
                ForEach(zonesRects, id: \.0) { zone, rect in
                    Button {
                        onZoneSelectionnee(zone)
                    } label: {
                        VStack(spacing: 2) {
                            Text("Z\(zone)")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(couleurAccent)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .frame(width: rect.width, height: rect.height)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(ZoneTapStyle(couleur: couleurAccent))
                    .position(x: rect.midX, y: rect.midY)
                }
            }
        }
    }
}

// MARK: - Style bouton zone

private struct ZoneTapStyle: ButtonStyle {
    let couleur: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit)
                    .fill(couleur.opacity(configuration.isPressed ? 0.25 : 0.08))
            )
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(LiquidGlassKit.springRebond, value: configuration.isPressed)
    }
}
