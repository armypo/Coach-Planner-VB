//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import UIKit

// MARK: - Overlay principal
struct OverlayDessinView: View {
    @Binding var elements: [ElementTerrain]
    let mode: ModeDessin
    let couleur: Color
    @Binding var prochainNumero: Int
    var verrouille: Bool = false
    var onEtatChange: (() -> Void)? = nil

    @State private var dragDebut: CGPoint?
    @State private var dragActuel: CGPoint?
    @State private var elementEnDeplacement: UUID?

    // P1-04 v0.4.0 — Filtres pré-calculés (évite .filter() inline dans ForEach à chaque render)
    private var labelsVecteurs: [ElementTerrain] {
        elements.filter { ($0.type == .fleche || $0.type == .trajectoire) && !$0.texte.isEmpty }
    }
    private var vecteursAvecHandles: [ElementTerrain] {
        elements.filter { $0.type == .fleche || $0.type == .trajectoire || $0.type == .rotation }
    }
    private var vecteursAvecFin: [ElementTerrain] {
        elements.filter { ($0.type == .fleche || $0.type == .trajectoire) && $0.toX != nil }
    }
    private var marqueurs: [ElementTerrain] {
        elements.filter { $0.type == .joueur || $0.type == .ballon }
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                // Couche vectorielle (flèches, trajectoires, rotations)
                CoucheVecteurs(
                    elements: elements,
                    previewDebut: dragDebut,
                    previewFin: dragActuel,
                    modeActif: mode,
                    couleurPreview: couleur
                )

                // Labels texte sur les flèches/trajectoires
                ForEach(labelsVecteurs) { elem in
                    let mid = midPoint(elem: elem, size: size)
                    Text(elem.texte)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(elem.couleur.opacity(0.8), in: Capsule())
                        .position(mid)
                        .allowsHitTesting(false)
                }

                // Handles de contrôle des trajectoires/flèches — draggables sauf verrouillé
                if !verrouille {
                    ForEach(vecteursAvecFin) { elem in
                        if elem.toX != nil, elem.toY != nil {
                            let handlePt = handlePosition(elem: elem, size: size)
                            Circle()
                                .fill(elem.couleur.opacity(0.9))
                                .frame(width: 16, height: 16)
                                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                                .shadow(color: .black.opacity(0.3), radius: 2)
                                .position(handlePt)
                                .gesture(
                                    DragGesture(minimumDistance: 3)
                                        .onChanged { val in
                                            if elementEnDeplacement == nil {
                                                onEtatChange?()
                                                elementEnDeplacement = elem.id
                                                hapticLight()
                                            }
                                            if let idx = elements.firstIndex(where: { $0.id == elem.id }) {
                                                elements[idx].ctrlX = val.location.x / size.width
                                                elements[idx].ctrlY = val.location.y / size.height
                                            }
                                        }
                                        .onEnded { _ in elementEnDeplacement = nil }
                                )
                        }
                    }
                }

                // ── Mode curseur : handles sur les extrémités des vecteurs
                if mode == .curseur && !verrouille {
                    // Handles de début — flèches, trajectoires, rotations
                    ForEach(vecteursAvecHandles) { elem in
                        handleVecteur(elem: elem, size: size, endpoint: .debut)
                    }
                    // Handles de fin — flèches, trajectoires
                    ForEach(vecteursAvecFin) { elem in
                        handleVecteur(elem: elem, size: size, endpoint: .fin)
                    }
                    // Handle central pour translater toute la flèche/trajectoire
                    ForEach(vecteursAvecFin) { elem in
                        handleTranslation(elem: elem, size: size)
                    }
                }

                // ── Mode suppression : badges X sur les vecteurs
                if mode == .suppression {
                    ForEach(vecteursAvecHandles) { elem in
                        let pos = midPoint(elem: elem, size: size)
                        boutonSuppression(elemId: elem.id)
                            .position(pos)
                    }
                }

                // Marqueurs interactifs (joueurs, ballons)
                ForEach(marqueurs) { elem in
                    ZStack {
                        marqueurView(elem: elem)

                        // Badge verrouillage
                        if verrouille && mode != .suppression {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.white)
                                .padding(3)
                                .background(Circle().fill(.gray.opacity(0.7)))
                                .offset(x: 14, y: -14)
                        }

                        // Badge suppression en mode suppression
                        if mode == .suppression {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white)
                                .background(Circle().fill(.red).frame(width: 20, height: 20))
                                .offset(x: 14, y: -14)
                        }
                    }
                    .position(x: elem.x * size.width, y: elem.y * size.height)
                    .gesture(verrouille && mode != .suppression ? nil : gestePourMarqueur(elem: elem, size: size))
                    .simultaneousGesture(
                        mode != .suppression && !verrouille
                        ? LongPressGesture(minimumDuration: 0.6)
                            .onEnded { _ in
                                onEtatChange?()
                                hapticMedium()
                                elements.removeAll { $0.id == elem.id }
                            }
                        : nil
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .allowsHitTesting(!mode.estDessinLibre)
            .gesture(
                elementEnDeplacement == nil && mode != .curseur && mode != .suppression
                ? DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        if dragDebut == nil { dragDebut = val.startLocation }
                        dragActuel = val.location
                    }
                    .onEnded { val in
                        gererFin(val: val, size: size)
                        dragDebut = nil; dragActuel = nil
                    }
                : nil
            )
        }
    }

    // MARK: - Geste par mode pour les marqueurs
    private func gestePourMarqueur(elem: ElementTerrain, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: mode == .suppression ? 0 : 5)
            .onChanged { val in
                if mode == .suppression { return }
                if elementEnDeplacement == nil {
                    onEtatChange?()
                    elementEnDeplacement = elem.id
                    hapticLight()
                }
                if let idx = elements.firstIndex(where: { $0.id == elem.id }) {
                    elements[idx].x = min(1, max(0, val.location.x / size.width))
                    elements[idx].y = min(1, max(0, val.location.y / size.height))
                }
            }
            .onEnded { val in
                if mode == .suppression {
                    let dist = sqrt(pow(val.location.x - val.startLocation.x, 2) +
                                    pow(val.location.y - val.startLocation.y, 2))
                    if dist < 10 {
                        onEtatChange?()
                        hapticMedium()
                        elements.removeAll { $0.id == elem.id }
                    }
                }
                elementEnDeplacement = nil
            }
    }

    // MARK: - Bouton suppression pour vecteurs
    private func boutonSuppression(elemId: UUID) -> some View {
        Button {
            onEtatChange?()
            hapticMedium()
            elements.removeAll { $0.id == elemId }
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.white, .red)
                .shadow(color: .black.opacity(0.3), radius: 2)
        }
    }

    // MARK: - Gestion fin de geste
    private func gererFin(val: DragGesture.Value, size: CGSize) {
        let s = val.startLocation, e = val.location
        let xN = s.x / size.width, yN = s.y / size.height
        let dx = e.x - s.x, dy = e.y - s.y
        let dist = sqrt(dx*dx + dy*dy)

        switch mode {
        case .joueur:
            onEtatChange?()
            hapticLight()
            elements.append(ElementTerrain(type: .joueur, x: xN, y: yN,
                                           label: "\(prochainNumero)", couleur: couleur))
            prochainNumero += 1
        case .ballon:
            onEtatChange?()
            hapticLight()
            elements.append(ElementTerrain(type: .ballon, x: xN, y: yN, couleur: .yellow))
        case .trajectoire:
            guard dist > 15 else { break }
            onEtatChange?()
            elements.append(ElementTerrain(type: .trajectoire, x: xN, y: yN,
                                           toX: e.x / size.width, toY: e.y / size.height,
                                           couleur: couleur))
        case .pointille:
            guard dist > 15 else { break }
            onEtatChange?()
            elements.append(ElementTerrain(type: .trajectoire, x: xN, y: yN,
                                           toX: e.x / size.width, toY: e.y / size.height,
                                           estPointille: true, couleur: couleur))
        case .rotation:
            onEtatChange?()
            hapticLight()
            elements.append(ElementTerrain(type: .rotation, x: xN, y: yN, couleur: couleur))
        default: break
        }
    }

    // MARK: - Handle translation (déplacer toute la flèche/trajectoire)
    @ViewBuilder
    private func handleTranslation(elem: ElementTerrain, size: CGSize) -> some View {
        let mid = midPoint(elem: elem, size: size)
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.white.opacity(0.7))
            .frame(width: 18, height: 18)
            .overlay(
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(elem.couleur)
            )
            .shadow(color: .black.opacity(0.25), radius: 2)
            .position(mid)
            .gesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { val in
                        if elementEnDeplacement == nil {
                            onEtatChange?()
                            elementEnDeplacement = elem.id
                            hapticLight()
                        }
                        if let idx = elements.firstIndex(where: { $0.id == elem.id }) {
                            _ = val.translation.width / size.width
                            _ = val.translation.height / size.height
                            // Appliquer delta depuis la position originale
                            // On utilise val.startLocation comme référence
                            let origMidX = (elem.x + (elem.toX ?? elem.x)) / 2
                            let origMidY = (elem.y + (elem.toY ?? elem.y)) / 2
                            let newMidX = val.location.x / size.width
                            let newMidY = val.location.y / size.height
                            let deltaX = newMidX - origMidX
                            let deltaY = newMidY - origMidY
                            elements[idx].x = elem.x + deltaX
                            elements[idx].y = elem.y + deltaY
                            if let tx = elem.toX, let ty = elem.toY {
                                elements[idx].toX = tx + deltaX
                                elements[idx].toY = ty + deltaY
                            }
                            if let cx = elem.ctrlX, let cy = elem.ctrlY {
                                elements[idx].ctrlX = cx + deltaX
                                elements[idx].ctrlY = cy + deltaY
                            }
                        }
                    }
                    .onEnded { _ in elementEnDeplacement = nil }
            )
    }

    // MARK: - Endpoint des vecteurs (curseur)
    private enum Endpoint { case debut, fin }

    @ViewBuilder
    private func handleVecteur(elem: ElementTerrain, size: CGSize, endpoint: Endpoint) -> some View {
        let pos: CGPoint = {
            switch endpoint {
            case .debut:
                return CGPoint(x: elem.x * size.width, y: elem.y * size.height)
            case .fin:
                return CGPoint(x: (elem.toX ?? elem.x) * size.width,
                               y: (elem.toY ?? elem.y) * size.height)
            }
        }()

        Circle()
            .fill(Color.white.opacity(0.85))
            .frame(width: 14, height: 14)
            .overlay(Circle().stroke(elem.couleur, lineWidth: 2))
            .shadow(color: .black.opacity(0.25), radius: 2)
            .position(pos)
            .gesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { val in
                        if elementEnDeplacement == nil {
                            onEtatChange?()
                            elementEnDeplacement = elem.id
                            hapticLight()
                        }
                        if let idx = elements.firstIndex(where: { $0.id == elem.id }) {
                            let nx = val.location.x / size.width
                            let ny = val.location.y / size.height
                            switch endpoint {
                            case .debut:
                                elements[idx].x = nx
                                elements[idx].y = ny
                            case .fin:
                                elements[idx].toX = nx
                                elements[idx].toY = ny
                            }
                        }
                    }
                    .onEnded { _ in elementEnDeplacement = nil }
            )
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.6)
                    .onEnded { _ in
                        onEtatChange?()
                        hapticMedium()
                        elements.removeAll { $0.id == elem.id }
                    }
            )
    }

    // MARK: - Points milieu / contrôle
    private func midPoint(elem: ElementTerrain, size: CGSize) -> CGPoint {
        if elem.type == .rotation {
            return CGPoint(x: elem.x * size.width, y: elem.y * size.height)
        }
        let tx = elem.toX ?? elem.x
        let ty = elem.toY ?? elem.y
        if let cx = elem.ctrlX, let cy = elem.ctrlY {
            // Point sur la courbe Bézier à t=0.5
            let mx = 0.25 * elem.x + 0.5 * cx + 0.25 * tx
            let my = 0.25 * elem.y + 0.5 * cy + 0.25 * ty
            return CGPoint(x: mx * size.width, y: my * size.height)
        }
        return CGPoint(x: (elem.x + tx) / 2 * size.width,
                       y: (elem.y + ty) / 2 * size.height)
    }

    private func handlePosition(elem: ElementTerrain, size: CGSize) -> CGPoint {
        if let cx = elem.ctrlX, let cy = elem.ctrlY {
            return CGPoint(x: cx * size.width, y: cy * size.height)
        }
        let tx = elem.toX ?? elem.x
        let ty = elem.toY ?? elem.y
        return CGPoint(x: (elem.x + tx) / 2 * size.width,
                       y: (elem.y + ty) / 2 * size.height)
    }

    // MARK: - Vue marqueur
    @ViewBuilder
    private func marqueurView(elem: ElementTerrain) -> some View {
        let enDeplacement = elementEnDeplacement == elem.id
        Group {
            switch elem.type {
            case .joueur:
                ZStack {
                    Circle().fill(elem.couleur)
                    Circle().stroke(Color.white, lineWidth: 2)
                    Text(elem.label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 34, height: 34)
                .shadow(color: .black.opacity(0.4), radius: 3)
            case .ballon:
                Text("🏐").font(.system(size: 26))
                    .shadow(color: .black.opacity(0.3), radius: 2)
            default:
                EmptyView()
            }
        }
        .scaleEffect(enDeplacement ? 1.2 : 1.0)
        .animation(LiquidGlassKit.springDefaut, value: enDeplacement)
    }

    // MARK: - Haptics
    private func hapticLight() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func hapticMedium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

// MARK: - Couche vectorielle (Path)
struct CoucheVecteurs: View {
    let elements: [ElementTerrain]
    let previewDebut: CGPoint?
    let previewFin: CGPoint?
    let modeActif: ModeDessin
    let couleurPreview: Color

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                ForEach(elements.filter({ $0.type == .fleche || $0.type == .trajectoire || $0.type == .rotation })) { elem in
                    elemVecteur(elem, size: size)
                }
                preview(size: size)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func elemVecteur(_ elem: ElementTerrain, size: CGSize) -> some View {
        let c = elem.couleur
        let from = CGPoint(x: elem.x * size.width, y: elem.y * size.height)

        switch elem.type {
        case .fleche, .trajectoire:
            if let tx = elem.toX, let ty = elem.toY {
                let ctrlPt: CGPoint? = {
                    if let cx = elem.ctrlX, let cy = elem.ctrlY {
                        return CGPoint(x: cx * size.width, y: cy * size.height)
                    }
                    return nil
                }()
                TrajectoireShape(from: from,
                                 to: CGPoint(x: tx * size.width, y: ty * size.height),
                                 couleur: c, ctrl: ctrlPt,
                                 estPointille: elem.estPointille)
            }
        case .rotation:
            RotationShape(centre: from, couleur: c)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func preview(size: CGSize) -> some View {
        if let debut = previewDebut, let fin = previewFin {
            switch modeActif {
            case .trajectoire:
                TrajectoireShape(from: debut, to: fin, couleur: couleurPreview.opacity(0.5))
            case .pointille:
                TrajectoireShape(from: debut, to: fin, couleur: couleurPreview.opacity(0.5),
                                 estPointille: true)
            case .rotation:
                RotationShape(centre: debut, couleur: couleurPreview.opacity(0.5))
            default:
                EmptyView()
            }
        }
    }
}

// MARK: - Flèche droite
struct FlecheShape: View {
    let from: CGPoint, to: CGPoint, couleur: Color
    private let lw: CGFloat = 3, headLen: CGFloat = 16, headAngle: CGFloat = 0.45

    var body: some View {
        ZStack {
            Path { p in p.move(to: from); p.addLine(to: to) }
                .stroke(couleur, lineWidth: lw)
            Path { p in
                let angle = atan2(to.y - from.y, to.x - from.x)
                p.move(to: to)
                p.addLine(to: CGPoint(x: to.x - headLen * cos(angle - headAngle),
                                      y: to.y - headLen * sin(angle - headAngle)))
                p.move(to: to)
                p.addLine(to: CGPoint(x: to.x - headLen * cos(angle + headAngle),
                                      y: to.y - headLen * sin(angle + headAngle)))
            }
            .stroke(couleur, style: StrokeStyle(lineWidth: lw, lineCap: .round))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Trajectoire (droite ou courbe Bézier selon point de contrôle)
struct TrajectoireShape: View {
    let from: CGPoint, to: CGPoint, couleur: Color
    var ctrl: CGPoint?
    var estPointille: Bool = false
    private let lw: CGFloat = 2.5, headLen: CGFloat = 14, headAngle: CGFloat = 0.45

    private var pointAvantFin: CGPoint { ctrl ?? from }

    var body: some View {
        ZStack {
            Path { p in
                p.move(to: from)
                if let c = ctrl {
                    p.addQuadCurve(to: to, control: c)
                } else {
                    p.addLine(to: to)
                }
            }
            .stroke(couleur, style: estPointille
                    ? StrokeStyle(lineWidth: lw, dash: [10, 6])
                    : StrokeStyle(lineWidth: lw))

            Path { p in
                let ref = pointAvantFin
                let angle = atan2(to.y - ref.y, to.x - ref.x)
                p.move(to: to)
                p.addLine(to: CGPoint(x: to.x - headLen * cos(angle - headAngle),
                                      y: to.y - headLen * sin(angle - headAngle)))
                p.move(to: to)
                p.addLine(to: CGPoint(x: to.x - headLen * cos(angle + headAngle),
                                      y: to.y - headLen * sin(angle + headAngle)))
            }
            .stroke(couleur, style: StrokeStyle(lineWidth: lw, lineCap: .round))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Flèche de rotation (arc ~290°)
struct RotationShape: View {
    let centre: CGPoint, couleur: Color
    private let radius: CGFloat = 22
    private let lw: CGFloat = 3, headLen: CGFloat = 12, headAngle: CGFloat = 0.5

    var body: some View {
        ZStack {
            Path { p in
                p.addArc(center: centre, radius: radius,
                         startAngle: .degrees(40), endAngle: .degrees(330),
                         clockwise: false)
            }
            .stroke(couleur, style: StrokeStyle(lineWidth: lw, lineCap: .round))

            Path { p in
                let endAngle = CGFloat(330) * .pi / 180
                let ex = centre.x + radius * cos(endAngle)
                let ey = centre.y + radius * sin(endAngle)
                let tangent = endAngle + .pi / 2
                p.move(to: CGPoint(x: ex, y: ey))
                p.addLine(to: CGPoint(x: ex - headLen * cos(tangent - headAngle),
                                      y: ey - headLen * sin(tangent - headAngle)))
                p.move(to: CGPoint(x: ex, y: ey))
                p.addLine(to: CGPoint(x: ex - headLen * cos(tangent + headAngle),
                                      y: ey - headLen * sin(tangent + headAngle)))
            }
            .stroke(couleur, style: StrokeStyle(lineWidth: lw, lineCap: .round))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
