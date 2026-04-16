//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI

/// Vue formation temps réel montrant les numéros de maillot sur le terrain.
/// Se met à jour automatiquement avec les rotations et substitutions.
struct FormationMatchLiveView: View {
    var viewModel: MatchLiveViewModel

    /// Taille compacte (pour intégration dans le dashboard)
    var compact: Bool = false

    private var joueurs: [JoueurSurTerrain] {
        viewModel.joueursActuellementSurTerrain
    }

    /// Joueurs en zone avant (postes 2, 3, 4)
    private var zoneAvant: [JoueurSurTerrain] {
        joueurs.filter { [2, 3, 4].contains($0.poste) }
            .sorted { $0.poste > $1.poste } // 4, 3, 2 de gauche à droite
    }

    /// Joueurs en zone arrière (postes 1, 5, 6)
    private var zoneArriere: [JoueurSurTerrain] {
        joueurs.filter { [1, 5, 6].contains($0.poste) }
            .sorted {
                // Ordre : 5 (gauche), 6 (centre), 1 (droite)
                let ordre: [Int: Int] = [5: 0, 6: 1, 1: 2]
                return (ordre[$0.poste] ?? 0) < (ordre[$1.poste] ?? 0)
            }
    }

    /// Libéro (poste 0)
    private var libero: JoueurSurTerrain? {
        joueurs.first(where: { $0.estLibero })
    }

    /// Détecte l'orientation portrait de l'appareil
    private var estPortrait: Bool {
        guard !compact else { return false } // compact = toujours horizontal
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return false }
        return scene.effectiveGeometry.interfaceOrientation.isPortrait
    }

    var body: some View {
        VStack(spacing: compact ? 4 : LiquidGlassKit.espaceSM) {
            // Indicateur service
            if !compact {
                HStack {
                    Text("R\(viewModel.rotationActuelle)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PaletteMat.bleu)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "volleyball.fill")
                            .font(.system(size: 10))
                        Text(viewModel.nousServons ? "Notre service" : "Service adv.")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(viewModel.nousServons ? .green : .red)
                }
            }

            // Terrain
            if estPortrait {
                terrainFormationVertical
                    .aspectRatio(0.5, contentMode: .fit)
            } else {
                terrainFormation
                    .aspectRatio(2.0, contentMode: .fit)
            }

            // Libéro en dessous
            if let lib = libero {
                HStack(spacing: 6) {
                    Image(systemName: "shield.checkered")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text("L")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.green)
                    Text("#\(lib.numero) \(lib.prenom)")
                        .font(.caption2)
                }
            }
        }
    }

    // MARK: - Terrain formation

    private var terrainFormation: some View {
        GeometryReader { geo in
            ZStack {
                // Fond terrain
                RoundedRectangle(cornerRadius: compact ? 6 : 10)
                    .fill(Color(red: 0.95, green: 0.85, blue: 0.65).opacity(0.3))
                    .overlay {
                        RoundedRectangle(cornerRadius: compact ? 6 : 10)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    }

                // Ligne médiane (filet)
                Rectangle()
                    .fill(Color.primary.opacity(0.15))
                    .frame(height: 2)
                    .offset(y: -geo.size.height * 0.1)

                // Ligne d'attaque (3m)
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 1)
                    .offset(y: geo.size.height * 0.1)

                // Zone avant (postes 4, 3, 2) — entre le filet et la ligne d'attaque
                HStack(spacing: 0) {
                    ForEach(zoneAvant) { joueur in
                        cercleJoueur(joueur: joueur, taille: geo.size)
                            .frame(maxWidth: .infinity)
                    }
                }
                .offset(y: -geo.size.height * 0.05)

                // Zone arrière (postes 5, 6, 1)
                HStack(spacing: 0) {
                    ForEach(zoneArriere) { joueur in
                        cercleJoueur(joueur: joueur, taille: geo.size)
                            .frame(maxWidth: .infinity)
                    }
                }
                .offset(y: geo.size.height * 0.28)

                // Indicateur poste 1 = service
                if viewModel.nousServons, joueurs.contains(where: { $0.poste == 1 }) {
                    Text("🏐")
                        .font(.system(size: compact ? 8 : 12))
                        .position(x: geo.size.width * 0.88, y: geo.size.height * 0.85)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: compact ? 6 : 10))
    }

    private func cercleJoueur(joueur: JoueurSurTerrain, taille: CGSize) -> some View {
        let tailleCercle: CGFloat = compact ? 28 : 40

        return VStack(spacing: 1) {
            ZStack {
                Circle()
                    .fill(couleurPoste(joueur.poste).opacity(0.85))
                    .frame(width: tailleCercle, height: tailleCercle)
                    .shadow(color: couleurPoste(joueur.poste).opacity(0.3), radius: 3, y: 1)
                Circle()
                    .stroke(.white.opacity(0.5), lineWidth: 1)
                    .frame(width: tailleCercle, height: tailleCercle)
                Text("#\(joueur.numero)")
                    .font(.system(size: compact ? 10 : 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            if !compact {
                Text("P\(joueur.poste)")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Terrain formation vertical

    private var terrainFormationVertical: some View {
        GeometryReader { geo in
            ZStack {
                // Fond terrain
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.95, green: 0.85, blue: 0.65).opacity(0.3))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    }

                // Filet (horizontal au milieu)
                Rectangle()
                    .fill(Color.primary.opacity(0.15))
                    .frame(width: geo.size.width, height: 2)
                    .offset(y: -geo.size.height * 0.02)

                // Ligne d'attaque (3m sous le filet pour nous)
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: geo.size.width, height: 1)
                    .offset(y: geo.size.height * 0.15)

                // Label "ADV" en haut
                Text("ADV")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.red.opacity(0.3))
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.08)

                // Zone avant (postes 4, 3, 2) — entre le filet et la ligne d'attaque
                HStack(spacing: 0) {
                    ForEach(zoneAvant) { joueur in
                        cercleJoueur(joueur: joueur, taille: geo.size)
                            .frame(maxWidth: .infinity)
                    }
                }
                .offset(y: geo.size.height * 0.12)

                // Zone arrière (postes 5, 6, 1)
                HStack(spacing: 0) {
                    ForEach(zoneArriere) { joueur in
                        cercleJoueur(joueur: joueur, taille: geo.size)
                            .frame(maxWidth: .infinity)
                    }
                }
                .offset(y: geo.size.height * 0.32)

                // Indicateur poste 1 = service
                if viewModel.nousServons, joueurs.contains(where: { $0.poste == 1 }) {
                    Text("🏐")
                        .font(.system(size: 12))
                        .position(x: geo.size.width * 0.88, y: geo.size.height * 0.90)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func couleurPoste(_ poste: Int) -> Color {
        switch poste {
        case 1: return .red            // Arrière droit (service)
        case 2: return Color(hex: "#2563EB")  // Avant droit
        case 3: return .purple         // Avant centre
        case 4: return Color(hex: "#FF6B35")  // Avant gauche
        case 5: return .teal           // Arrière gauche
        case 6: return .yellow         // Arrière centre
        default: return .green         // Libéro
        }
    }
}
