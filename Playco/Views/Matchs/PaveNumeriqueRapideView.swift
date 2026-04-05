//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI

/// Pavé numérique rapide pour la saisie courtside
/// Workflow : tap numéro joueur → pick action (Kill/Ace/Bloc/Erreur) → stat enregistrée
struct PaveNumeriqueRapideView: View {
    var viewModel: MatchLiveViewModel
    @Binding var estVisible: Bool

    @State private var joueurSelectionne: JoueurSurTerrain?
    @State private var triggerHaptique = 0

    private var joueursActifs: [JoueurSurTerrain] {
        viewModel.joueursActuellementSurTerrain
    }

    var body: some View {
        VStack(spacing: LiquidGlassKit.espaceMD) {
            // En-tête
            HStack {
                Text("SAISIE RAPIDE")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Spacer()
                Button {
                    withAnimation(LiquidGlassKit.springDefaut) {
                        estVisible = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            if let joueur = joueurSelectionne {
                // Étape 2 : sélection action pour le joueur
                pickerAction(joueur: joueur)
            } else {
                // Étape 1 : grille de numéros
                grilleNumeros
            }
        }
        .padding(LiquidGlassKit.espaceMD)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonGrand))
        .overlay {
            RoundedRectangle(cornerRadius: LiquidGlassKit.rayonGrand)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
        .sensoryFeedback(.impact(weight: .medium), trigger: triggerHaptique)
    }

    // MARK: - Grille de numéros

    private var grilleNumeros: some View {
        VStack(spacing: LiquidGlassKit.espaceSM) {
            Text("Touchez un numéro de joueur")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: LiquidGlassKit.espaceSM), count: 3), spacing: LiquidGlassKit.espaceSM) {
                ForEach(joueursActifs) { joueur in
                    Button {
                        withAnimation(LiquidGlassKit.springRebond) {
                            joueurSelectionne = joueur
                            triggerHaptique += 1
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text("#\(joueur.numero)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                            Text(joueur.prenom)
                                .font(.system(size: 10).weight(.medium))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: LiquidGlassKit.boutonCourtside)
                        .background(
                            joueur.estLibero ? PaletteMat.violet.opacity(0.12) : PaletteMat.bleu.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit)
                                .strokeBorder(
                                    joueur.estLibero ? PaletteMat.violet.opacity(0.3) : PaletteMat.bleu.opacity(0.2),
                                    lineWidth: 1
                                )
                        }
                        .foregroundStyle(joueur.estLibero ? PaletteMat.violet : PaletteMat.bleu)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Picker action (4 gros boutons)

    private func pickerAction(joueur: JoueurSurTerrain) -> some View {
        VStack(spacing: LiquidGlassKit.espaceMD) {
            // Joueur sélectionné
            HStack(spacing: 8) {
                Button {
                    withAnimation(LiquidGlassKit.springDefaut) {
                        joueurSelectionne = nil
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                Text("#\(joueur.numero) \(joueur.prenom) \(joueur.nom)")
                    .font(.subheadline.weight(.bold))
                Spacer()
            }

            // 4 actions rapides
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: LiquidGlassKit.espaceSM) {
                boutonAction(label: "Kill", icone: "flame.fill", action: .kill, couleur: PaletteMat.vert, joueurID: joueur.joueurID)
                boutonAction(label: "Ace", icone: "arrow.up.forward", action: .ace, couleur: PaletteMat.bleu, joueurID: joueur.joueurID)
                boutonAction(label: "Bloc", icone: "shield.fill", action: .blocSeul, couleur: PaletteMat.violet, joueurID: joueur.joueurID)
                boutonAction(label: "Erreur", icone: "exclamationmark.triangle", action: .erreurAttaque, couleur: .red, joueurID: joueur.joueurID)
            }
        }
    }

    private func boutonAction(label: String, icone: String, action: TypeActionPoint, couleur: Color, joueurID: UUID) -> some View {
        Button {
            withAnimation(LiquidGlassKit.springDefaut) {
                viewModel.enregistrerStat(action: action, joueurID: joueurID)
                joueurSelectionne = nil
                triggerHaptique += 1
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icone)
                    .font(.title2)
                Text(label)
                    .font(.subheadline.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: LiquidGlassKit.boutonCourtside + 10)
            .background(couleur.opacity(0.12), in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMoyen))
            .overlay {
                RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMoyen)
                    .strokeBorder(couleur.opacity(0.3), lineWidth: 1)
            }
            .foregroundStyle(couleur)
        }
        .buttonStyle(.plain)
    }
}
