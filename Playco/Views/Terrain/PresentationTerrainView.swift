//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import PencilKit

/// Mode présentation terrain — plein écran, lecture seule, navigation par swipe entre étapes
/// Conçu pour projection AirPlay en gymnase
struct PresentationTerrainView: View {
    let dessinData: Data?
    let elementsData: Data?
    let etapesData: Data?
    var typeTerrain: TypeTerrain = .indoor

    @Environment(\.dismiss) private var dismiss

    @State private var etapeActive = 0
    @State private var etapes: [EtapeExercice] = []
    @State private var drawingActuel = PKDrawing()
    @State private var elementsActuels: [ElementTerrain] = []

    /// Nombre total d'étapes (principale + supplémentaires)
    private var totalEtapes: Int { 1 + etapes.count }

    /// Détecte l'orientation portrait
    private var estPortrait: Bool {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return false }
        return scene.effectiveGeometry.interfaceOrientation.isPortrait
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                // Terrain + overlay (lecture seule)
                ZStack {
                    TerrainVolleyView(afficherZones: false, typeTerrain: typeTerrain)

                    // Dessin PencilKit en lecture seule
                    PKDrawingReadOnlyView(drawing: drawingActuel)

                    // Overlay vectoriel verrouillé
                    OverlayDessinView(
                        elements: .constant(elementsActuels),
                        mode: .curseur,
                        couleur: .white,
                        prochainNumero: .constant(1),
                        verrouille: true
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMoyen))
                .aspectRatio(estPortrait ? 0.5 : 2.0, contentMode: .fit)
                .padding(.horizontal, LiquidGlassKit.espaceLG)

                // Indicateur d'étapes
                if totalEtapes > 1 {
                    indicateurEtapes
                        .padding(.top, LiquidGlassKit.espaceMD)
                }
                Spacer()
            }

            // Navigation par tap (tiers gauche / tiers droit)
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { etapePrecedente() }
                Color.clear
                    .contentShape(Rectangle())
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { etapeSuivante() }
            }

            // Bouton fermer (au-dessus des gestures de navigation)
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(LiquidGlassKit.espaceMD)
                }
                Spacer()
            }
        }
        .statusBarHidden(true)
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width < -50 {
                        etapeSuivante()
                    } else if value.translation.width > 50 {
                        etapePrecedente()
                    }
                }
        )
        .onAppear { chargerDonnees() }
        .onChange(of: etapeActive) { _, _ in chargerEtapeActive() }
    }

    // MARK: - Indicateur d'étapes

    private var indicateurEtapes: some View {
        HStack(spacing: LiquidGlassKit.espaceSM) {
            ForEach(0..<totalEtapes, id: \.self) { index in
                Capsule()
                    .fill(index == etapeActive ? PaletteMat.orange : Color.white.opacity(0.3))
                    .frame(width: index == etapeActive ? 24 : 8, height: 8)
                    .animation(LiquidGlassKit.springDefaut, value: etapeActive)
            }
        }
    }

    // MARK: - Navigation

    private func etapeSuivante() {
        guard etapeActive < totalEtapes - 1 else { return }
        withAnimation(LiquidGlassKit.springDefaut) {
            etapeActive += 1
        }
    }

    private func etapePrecedente() {
        guard etapeActive > 0 else { return }
        withAnimation(LiquidGlassKit.springDefaut) {
            etapeActive -= 1
        }
    }

    // MARK: - Chargement données

    private func chargerDonnees() {
        if let data = etapesData,
           let decoded = try? JSONCoderCache.decoder.decode([EtapeExercice].self, from: data) {
            etapes = decoded
        }
        chargerEtapeActive()
    }

    private func chargerEtapeActive() {
        if etapeActive == 0 {
            if let data = dessinData {
                drawingActuel = (try? PKDrawing(data: data)) ?? PKDrawing()
            } else {
                drawingActuel = PKDrawing()
            }
            if let data = elementsData,
               let decoded = try? JSONCoderCache.decoder.decode([ElementTerrain].self, from: data) {
                elementsActuels = decoded
            } else {
                elementsActuels = []
            }
        } else {
            let index = etapeActive - 1
            guard index < etapes.count else { return }
            let etape = etapes[index]
            if let data = etape.dessinData {
                drawingActuel = (try? PKDrawing(data: data)) ?? PKDrawing()
            } else {
                drawingActuel = PKDrawing()
            }
            if let data = etape.elementsData,
               let decoded = try? JSONCoderCache.decoder.decode([ElementTerrain].self, from: data) {
                elementsActuels = decoded
            } else {
                elementsActuels = []
            }
        }
    }
}

// MARK: - PKDrawing lecture seule (UIViewRepresentable)

private struct PKDrawingReadOnlyView: UIViewRepresentable {
    let drawing: PKDrawing

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.isUserInteractionEnabled = false
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.drawing = drawing
    }
}
