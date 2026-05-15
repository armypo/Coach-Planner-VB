//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  EcranErreurBaseView — affiché uniquement si TOUS les fallbacks ModelContainer
//  ont échoué lors du démarrage (situation extrêmement rare).
//  Remplace le fatalError précédent par un écran d'erreur lisible.

import SwiftUI

struct EcranErreurBaseView: View {
    let message: String

    var body: some View {
        ZStack {
            // Fond dégradé sobre
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGroupedBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: LiquidGlassKit.espaceLG) {
                Spacer()

                // Icône d'erreur
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(PaletteMat.orange)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: LiquidGlassKit.espaceMD) {
                    Text("Erreur de démarrage")
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, LiquidGlassKit.espaceXL)
                }

                Spacer()

                VStack(spacing: LiquidGlassKit.espaceSM) {
                    // Bouton contacter le support
                    Link(destination: AppConstants.mailtoSupportErreurDemarrage) {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                            Text("Contacter le support")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: 320)
                        .padding(.vertical, 14)
                        .background(PaletteMat.orange, in: Capsule())
                    }

                    Text("Si le problème persiste après un redémarrage, désinstalle et réinstalle l'application.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, LiquidGlassKit.espaceXL)
                }
                .padding(.bottom, LiquidGlassKit.espaceXL)
            }
        }
    }
}
