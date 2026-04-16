//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI

/// Onglet sélectionné dans la vue rotation
private enum OngletRotation: String, CaseIterable {
    case nous = "Nous"
    case adversaire = "Adversaire"
}

/// Vue de modification de la rotation en cours de match live
/// Affiche un mini-terrain avec les positions 1-6 et permet de changer la rotation manuellement
struct RotationLiveView: View {
    var viewModel: MatchLiveViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var ongletActif: OngletRotation = .nous

    var body: some View {
        NavigationStack {
            VStack(spacing: LiquidGlassKit.espaceLG) {
                // Picker segmenté Nous / Adversaire
                Picker("Équipe", selection: $ongletActif) {
                    ForEach(OngletRotation.allCases, id: \.self) { onglet in
                        Text(onglet.rawValue).tag(onglet)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, LiquidGlassKit.espaceMD)

                if ongletActif == .nous {
                    contenuNous
                } else {
                    contenuAdversaire
                }

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

    // MARK: - Onglet Nous

    private var contenuNous: some View {
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
        }
    }

    // MARK: - Onglet Adversaire

    private var contenuAdversaire: some View {
        VStack(spacing: LiquidGlassKit.espaceLG) {
            // Rotation adversaire actuelle
            VStack(spacing: 4) {
                Text("ROTATION ADVERSAIRE")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Text("R\(viewModel.rotationAdversaire)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.red)
                    .contentTransition(.numericText())
            }

            // Mini-terrain adversaire simplifié (6 positions numérotées, pas de noms)
            terrainAdversaire
                .padding(.horizontal, LiquidGlassKit.espaceMD)

            // Sélecteur de rotation adversaire
            VStack(spacing: LiquidGlassKit.espaceSM) {
                Text("CHANGER LA ROTATION")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                HStack(spacing: LiquidGlassKit.espaceSM) {
                    ForEach(1...6, id: \.self) { rotation in
                        boutonRotationAdversaire(rotation)
                    }
                }
            }

            // Historique rotations adversaire du set
            historiqueRotationsAdversaire
        }
    }

    // MARK: - Mini-terrain visuel (nous)

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

    // MARK: - Mini-terrain adversaire (simplifié, numéros seulement)

    private var terrainAdversaire: some View {
        VStack(spacing: 0) {
            // Avant adversaire (postes 2, 3, 4)
            HStack(spacing: LiquidGlassKit.espaceMD) {
                cellulePosteAdversaire(poste: 4)
                cellulePosteAdversaire(poste: 3)
                cellulePosteAdversaire(poste: 2)
            }
            .padding(.vertical, LiquidGlassKit.espaceMD)

            Divider().opacity(0.3)

            // Arrière adversaire (postes 5, 6, 1)
            HStack(spacing: LiquidGlassKit.espaceMD) {
                cellulePosteAdversaire(poste: 5)
                cellulePosteAdversaire(poste: 6)
                cellulePosteAdversaire(poste: 1)
            }
            .padding(.vertical, LiquidGlassKit.espaceMD)

            // Filet
            Rectangle()
                .fill(.white.opacity(0.6))
                .frame(height: 3)
                .padding(.horizontal, LiquidGlassKit.espaceMD)
        }
        .padding(LiquidGlassKit.espaceMD)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonGrand))
        .overlay {
            RoundedRectangle(cornerRadius: LiquidGlassKit.rayonGrand)
                .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
        }
    }

    private func cellulePosteAdversaire(poste: Int) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 48, height: 48)

                Text("P\(poste)")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(.red)
            }

            Text("Zone \(poste)")
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Boutons rotation

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
        .accessibilityLabel("Rotation \(rotation) de notre équipe")
        .accessibilityHint(estActuelle ? "Rotation actuellement sélectionnée" : "Double-tapez pour passer à cette rotation")
        .accessibilityAddTraits(estActuelle ? .isSelected : [])
    }

    private func boutonRotationAdversaire(_ rotation: Int) -> some View {
        let estActuelle = viewModel.rotationAdversaire == rotation

        return Button {
            withAnimation(LiquidGlassKit.springDefaut) {
                viewModel.modifierRotationAdversaire(nouvelleRotation: rotation)
            }
        } label: {
            Text("R\(rotation)")
                .font(.subheadline.weight(.bold))
                .frame(width: 48, height: 48)
                .background(
                    estActuelle ? Color.red : Color(.tertiarySystemFill),
                    in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit)
                )
                .foregroundStyle(estActuelle ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Rotation \(rotation) de l'adversaire")
        .accessibilityHint(estActuelle ? "Rotation actuellement sélectionnée" : "Double-tapez pour modifier la rotation adversaire")
        .accessibilityAddTraits(estActuelle ? .isSelected : [])
    }

    // MARK: - Historique rotations (nous)

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

    // MARK: - Historique rotations adversaire

    private var historiqueRotationsAdversaire: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Text("HISTORIQUE ADV. SET \(viewModel.setActuel)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            let historique = viewModel.seance.rotationsHistoriqueAdv[viewModel.setActuel] ?? []
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
                                    index == historique.count - 1 ? Color.red.opacity(0.15) : Color(.tertiarySystemFill),
                                    in: Capsule()
                                )
                                .foregroundStyle(index == historique.count - 1 ? .red : .secondary)
                        }
                    }
                }
            }
        }
        .padding(LiquidGlassKit.espaceMD)
        .glassSection()
    }
}
