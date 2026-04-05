//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI

/// Vue de modification de la rotation en cours de match live
/// Affiche un mini-terrain avec les positions 1-6 et permet de changer la rotation manuellement
struct RotationLiveView: View {
    var viewModel: MatchLiveViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: LiquidGlassKit.espaceLG) {
                // Rotation actuelle
                VStack(spacing: 4) {
                    Text("ROTATION ACTUELLE")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                    Text("R\(viewModel.rotationActuelle)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(PaletteMat.bleu)
                        .contentTransition(.numericText())
                }

                // Mini-terrain visuel
                terrainVisuel
                    .padding(.horizontal, LiquidGlassKit.espaceMD)

                // Sélecteur de rotation
                VStack(spacing: LiquidGlassKit.espaceSM) {
                    Text("CHANGER LA ROTATION")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)

                    HStack(spacing: LiquidGlassKit.espaceSM) {
                        ForEach(1...6, id: \.self) { rotation in
                            boutonRotation(rotation)
                        }
                    }
                }

                // Historique rotations du set
                historiqueRotations

                Spacer()
            }
            .padding(LiquidGlassKit.espaceMD)
            .navigationTitle("Rotation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    // MARK: - Mini-terrain visuel

    private var terrainVisuel: some View {
        let joueurs = viewModel.joueursActuellementSurTerrain

        return VStack(spacing: 0) {
            // Filet
            Rectangle()
                .fill(.white.opacity(0.6))
                .frame(height: 3)
                .padding(.horizontal, LiquidGlassKit.espaceMD)

            // Avant (postes 2, 3, 4)
            HStack(spacing: LiquidGlassKit.espaceMD) {
                cellulePoste(poste: 4, joueurs: joueurs)
                cellulePoste(poste: 3, joueurs: joueurs)
                cellulePoste(poste: 2, joueurs: joueurs)
            }
            .padding(.vertical, LiquidGlassKit.espaceMD)

            Divider().opacity(0.3)

            // Arrière (postes 5, 6, 1)
            HStack(spacing: LiquidGlassKit.espaceMD) {
                cellulePoste(poste: 5, joueurs: joueurs)
                cellulePoste(poste: 6, joueurs: joueurs)
                cellulePoste(poste: 1, joueurs: joueurs)
            }
            .padding(.vertical, LiquidGlassKit.espaceMD)
        }
        .padding(LiquidGlassKit.espaceMD)
        .background(PaletteMat.bleu.opacity(0.08), in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonGrand))
        .overlay {
            RoundedRectangle(cornerRadius: LiquidGlassKit.rayonGrand)
                .strokeBorder(PaletteMat.bleu.opacity(0.2), lineWidth: 1)
        }
    }

    private func cellulePoste(poste: Int, joueurs: [JoueurSurTerrain]) -> some View {
        let joueur = joueurs.first(where: { $0.poste == poste })

        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(PaletteMat.bleu.opacity(0.15))
                    .frame(width: 48, height: 48)

                if let j = joueur {
                    Text("#\(j.numero)")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(PaletteMat.bleu)
                } else {
                    Text("P\(poste)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            if let j = joueur {
                Text(j.prenom)
                    .font(.system(size: 9).weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text("Zone \(poste)")
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bouton rotation

    private func boutonRotation(_ rotation: Int) -> some View {
        let estActuelle = viewModel.rotationActuelle == rotation

        return Button {
            withAnimation(LiquidGlassKit.springDefaut) {
                viewModel.modifierRotation(nouvelleRotation: rotation)
            }
        } label: {
            Text("R\(rotation)")
                .font(.subheadline.weight(.bold))
                .frame(width: 48, height: 48)
                .background(
                    estActuelle ? PaletteMat.bleu : Color(.tertiarySystemFill),
                    in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit)
                )
                .foregroundStyle(estActuelle ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Historique rotations

    private var historiqueRotations: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Text("HISTORIQUE SET \(viewModel.setActuel)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            let historique = viewModel.seance.rotationsHistorique[viewModel.setActuel] ?? []
            if historique.isEmpty {
                Text("Aucune rotation enregistrée")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(historique.enumerated()), id: \.offset) { index, rotation in
                            Text("R\(rotation)")
                                .font(.caption2.weight(.medium).monospacedDigit())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    index == historique.count - 1 ? PaletteMat.bleu.opacity(0.15) : Color(.tertiarySystemFill),
                                    in: Capsule()
                                )
                                .foregroundStyle(index == historique.count - 1 ? PaletteMat.bleu : .secondary)
                        }
                    }
                }
            }
        }
        .padding(LiquidGlassKit.espaceMD)
        .glassSection()
    }
}
