//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI

/// Miniature du terrain avec les éléments overlay dessinés (pas de PencilKit, trop lourd en miniature)
/// P1-01 v0.4.0 — Décodage JSON en @State (évite re-décodage à chaque render)
struct TerrainMiniatureView: View {
    let elementsData: Data?
    var taille: CGFloat = 60
    var typeTerrain: TypeTerrain = .indoor

    @State private var elements: [ElementTerrain] = []

    var body: some View {
        ZStack {
            // Terrain simplifié
            RoundedRectangle(cornerRadius: 4)
                .fill(typeTerrain == .beach ? Color(hex: "#E8D68C") : Color(hex: "#D4A96A"))
            RoundedRectangle(cornerRadius: 4)
                .stroke(typeTerrain == .beach ? Color.red.opacity(0.5) : Color.white.opacity(0.5), lineWidth: 0.5)

            // Filet vertical
            Rectangle()
                .fill(Color.white.opacity(0.6))
                .frame(width: 1.5)

            // Lignes d'attaque (indoor uniquement)
            if typeTerrain == .indoor {
                HStack {
                    Spacer()
                        .frame(width: taille * 0.165)
                    Rectangle().fill(Color.white.opacity(0.3)).frame(width: 0.5)
                    Spacer()
                    Rectangle().fill(Color.white.opacity(0.3)).frame(width: 0.5)
                    Spacer()
                        .frame(width: taille * 0.165)
                }
            }

            // Éléments overlay en miniature
            GeometryReader { geo in
                let s = geo.size
                ForEach(elements) { elem in
                    switch elem.type {
                    case .joueur:
                        Circle()
                            .fill(elem.couleur)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Color.white, lineWidth: 0.5))
                            .position(x: elem.x * s.width, y: elem.y * s.height)
                    case .ballon:
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: 5, height: 5)
                            .position(x: elem.x * s.width, y: elem.y * s.height)
                    case .fleche:
                        if let tx = elem.toX, let ty = elem.toY {
                            Path { p in
                                p.move(to: CGPoint(x: elem.x * s.width, y: elem.y * s.height))
                                p.addLine(to: CGPoint(x: tx * s.width, y: ty * s.height))
                            }
                            .stroke(elem.couleur, lineWidth: 1)
                        }
                    case .trajectoire:
                        if let tx = elem.toX, let ty = elem.toY {
                            Path { p in
                                let from = CGPoint(x: elem.x * s.width, y: elem.y * s.height)
                                let to = CGPoint(x: tx * s.width, y: ty * s.height)
                                p.move(to: from)
                                if let cx = elem.ctrlX, let cy = elem.ctrlY {
                                    p.addQuadCurve(to: to,
                                                   control: CGPoint(x: cx * s.width, y: cy * s.height))
                                } else {
                                    p.addLine(to: to)
                                }
                            }
                            .stroke(elem.couleur, style: elem.estPointille
                                    ? StrokeStyle(lineWidth: 0.8, dash: [3, 2])
                                    : StrokeStyle(lineWidth: 0.8))
                        }
                    case .rotation:
                        Circle()
                            .stroke(elem.couleur, lineWidth: 0.8)
                            .frame(width: 6, height: 6)
                            .position(x: elem.x * s.width, y: elem.y * s.height)
                    }
                }
            }
        }
        .frame(width: taille, height: taille / 2)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .onAppear {
            guard let d = elementsData,
                  let dec = try? JSONCoderCache.decoder.decode([ElementTerrain].self, from: d)
            else { return }
            elements = dec
        }
    }
}
