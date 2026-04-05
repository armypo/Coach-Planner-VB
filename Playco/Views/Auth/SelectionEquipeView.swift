//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Sélection d'équipe si l'utilisateur a accès à plusieurs équipes
struct SelectionEquipeView: View {
    var onSelection: (Equipe) -> Void

    @Query private var equipes: [Equipe]
    @State private var animee = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)

                    VStack(spacing: 12) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(PaletteMat.vert)

                        Text("Choisir une équipe")
                            .font(.title2.weight(.bold))

                        Text("Vous avez accès à plusieurs équipes. Sélectionnez celle avec laquelle vous souhaitez travailler.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding(.bottom, 32)

                    VStack(spacing: 16) {
                        ForEach(Array(equipes.enumerated()), id: \.element.id) { index, equipe in
                            Button {
                                onSelection(equipe)
                            } label: {
                                carteEquipe(equipe)
                            }
                            .buttonStyle(.plain)
                            .opacity(animee ? 1 : 0)
                            .offset(y: animee ? 0 : 20)
                            .animation(.spring(response: 0.5).delay(Double(index) * 0.1), value: animee)
                        }
                    }
                    .frame(maxWidth: 500)
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 60)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            // Auto-sélection si une seule équipe
            if equipes.count == 1, let seule = equipes.first {
                onSelection(seule)
                return
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                animee = true
            }
        }
    }

    private func carteEquipe(_ equipe: Equipe) -> some View {
        HStack(spacing: 16) {
            // Couleurs de l'équipe
            VStack(spacing: 4) {
                Circle()
                    .fill(equipe.couleurPrincipale)
                    .frame(width: 24, height: 24)
                Circle()
                    .fill(equipe.couleurSecondaire)
                    .frame(width: 24, height: 24)
            }
            .padding(8)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(equipe.nom)
                    .font(.headline)
                    .foregroundStyle(.primary)
                HStack(spacing: 8) {
                    Text(equipe.categorie.rawValue)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    if !equipe.saison.isEmpty {
                        Text("•")
                            .foregroundStyle(.quaternary)
                        Text(equipe.saison)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    if let etablissement = equipe.etablissement {
                        Text("•")
                            .foregroundStyle(.quaternary)
                        Text(etablissement.nom)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                if !equipe.codeEquipe.isEmpty {
                    Text("Code : \(equipe.codeEquipe)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(PaletteMat.bleu)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}
