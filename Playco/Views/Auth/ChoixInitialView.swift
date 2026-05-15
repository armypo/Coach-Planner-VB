//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI

/// Premier lancement — choix entre configurer une équipe ou rejoindre avec un code
struct ChoixInitialView: View {
    var onConfigurer: () -> Void
    var onConnexion: () -> Void

    @State private var animee = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 80)

                    // Logo + titre
                    VStack(spacing: 12) {
                        Image(systemName: "volleyball.fill")
                            .font(.system(size: 56, weight: .bold))
                            .foregroundStyle(PaletteMat.orange)
                            .scaleEffect(animee ? 1 : 0.5)
                            .opacity(animee ? 1 : 0)

                        Text("Playco")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .opacity(animee ? 1 : 0)

                        Text("Comment souhaitez-vous commencer ?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .opacity(animee ? 1 : 0)
                    }
                    .padding(.bottom, 48)

                    // 2 cartes
                    VStack(spacing: 20) {
                        // Créer mon équipe
                        Button { onConfigurer() } label: {
                            carteChoix(
                                icone: "figure.volleyball",
                                titre: "Créer mon équipe",
                                description: "Configurez votre établissement, équipe, joueurs et calendrier en quelques étapes.",
                                couleur: PaletteMat.orange,
                                badge: "Coach"
                            )
                        }
                        .buttonStyle(.plain)
                        .offset(x: animee ? 0 : -60)
                        .opacity(animee ? 1 : 0)

                        // Connexion (Coach / Assistant / Athlète)
                        Button { onConnexion() } label: {
                            carteChoix(
                                icone: "person.fill.badge.plus",
                                titre: "Connexion",
                                description: "Connectez-vous avec vos identifiants. Sélectionnez ensuite votre type de compte.",
                                couleur: PaletteMat.bleu,
                                badge: "Coach · Assistant · Athlète"
                            )
                        }
                        .buttonStyle(.plain)
                        .offset(x: animee ? 0 : 60)
                        .opacity(animee ? 1 : 0)
                    }
                    .frame(maxWidth: 480)

                    Spacer().frame(height: 60)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                animee = true
            }
        }
    }

    private func carteChoix(icone: String, titre: String, description: String, couleur: Color, badge: String) -> some View {
        HStack(spacing: 20) {
            Image(systemName: icone)
                .font(.system(size: 40))
                .foregroundStyle(couleur)
                .frame(width: 64, height: 64)
                .background(couleur.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(titre)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(badge)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(couleur)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(couleur.opacity(0.1), in: Capsule())
                }
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(couleur.opacity(0.15), lineWidth: 1)
        )
    }
}
