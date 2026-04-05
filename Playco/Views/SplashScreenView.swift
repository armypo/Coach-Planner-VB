//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI

/// Écran de démarrage animé — volleyball qui rebondit + titre fade-in
struct SplashScreenView: View {
    var onTermine: () -> Void

    @State private var balleOffset: CGFloat = -200
    @State private var balleRebond: Bool = false
    @State private var opaciteTitre: Double = 0
    @State private var opaciteSousTitre: Double = 0
    @State private var echelleBalle: CGFloat = 0.5

    var body: some View {
        ZStack {
            // Fond uniforme Liquid Glass
            Color(.systemBackground)
                .ignoresSafeArea()

            // Lueur ambiante douce
            RadialGradient(
                colors: [PaletteMat.orange.opacity(0.06), .clear],
                center: .center,
                startRadius: 50,
                endRadius: 400
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Volleyball animé — style mat
                Image(systemName: "volleyball.fill")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(PaletteMat.orange)
                    .scaleEffect(echelleBalle)
                    .offset(y: balleOffset)
                    .shadow(color: PaletteMat.orange.opacity(0.15), radius: balleRebond ? 24 : 8, y: balleRebond ? 8 : 2)

                // Titre
                Text("Playco")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .opacity(opaciteTitre)

                // Sous-titre
                Text("Volleyball")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                    .opacity(opaciteSousTitre)

                Spacer()

                // Indicateur de chargement — mat
                ProgressView()
                    .tint(PaletteMat.orange)
                    .opacity(opaciteSousTitre)
                    .padding(.bottom, 60)
            }
        }
        .task {
            // Animation 1 : balle tombe et rebondit (spring)
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5, blendDuration: 0.2)) {
                balleOffset = 0
                echelleBalle = 1.0
                balleRebond = true
            }

            // Animation 2 : titre fade-in après 0.5s
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation(.easeOut(duration: 0.5)) {
                opaciteTitre = 1.0
            }

            // Animation 3 : sous-titre fade-in après 0.8s
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.easeOut(duration: 0.4)) {
                opaciteSousTitre = 1.0
            }

            // Transition vers l'app après 2s total
            try? await Task.sleep(for: .milliseconds(1200))
            withAnimation(.easeInOut(duration: 0.4)) {
                onTermine()
            }
        }
    }
}
