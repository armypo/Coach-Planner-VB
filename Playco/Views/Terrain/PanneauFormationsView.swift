//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Phase 5.1 — Panneau « Formations » du terrain de planification.
//  Accès en 2 taps : bouton Formations → tuile de rotation.
//  Remplace les 3 menus imbriqués de BarreOutilsDessin.
//  Onglet « Stratégies » : conserve le chargement des stratégies offensives.
//

import SwiftUI

// MARK: - Dernière formation posée (bouton « Reposer R# »)

/// Mémoire locale de la dernière formation posée depuis le panneau.
struct DerniereFormationPosee: Equatable {
    let type: FormationType
    let rotation: Int
    let mode: FormationMode

    /// Libellé court pour le bouton « Reposer » (R1…R6, ou nom beach).
    var labelCourt: String {
        type.estBeach ? type.rawValue : "R\(rotation + 1)"
    }
}

// MARK: - Panneau formations

struct PanneauFormationsView: View {
    var typeTerrain: TypeTerrain = .indoor
    var formationsPerso: [FormationPersonnalisee] = []
    var strategiesOffensives: [StrategieCollective] = []
    let onFormation: (FormationType, Int, FormationMode) -> Void
    var onStrategie: ((StrategieCollective) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    // MARK: Onglets

    private enum Onglet: String, CaseIterable {
        case formations = "Formations"
        case strategies = "Stratégies"
    }

    /// Système sélectionné dans le segmented (indoor + beach)
    private enum SystemeFormation: String, CaseIterable {
        case cinqUn     = "5-1"
        case quatreDeux = "4-2"
        case sixDeux    = "6-2"
        case beach      = "Beach"

        /// Type indoor associé — nil pour beach (3 types distincts)
        var formationTypeIndoor: FormationType? {
            switch self {
            case .cinqUn:     return .cinqUn
            case .quatreDeux: return .quatreDeux
            case .sixDeux:    return .sixDeux
            case .beach:      return nil
            }
        }
    }

    @State private var onglet: Onglet = .formations
    @State private var systeme: SystemeFormation = .cinqUn
    @State private var mode: FormationMode = .base

    private let typesBeach: [FormationType] = [.beachReception, .beachBloqueurDefenseur, .beachSplitBloc]
    private static let colonnesRotations = Array(
        repeating: GridItem(.flexible(), spacing: LiquidGlassKit.espaceSM), count: 3)

    /// Sur terrain beach : pas de segmented système, beach direct
    private var estTerrainBeach: Bool { typeTerrain == .beach }
    private var afficheBeach: Bool { estTerrainBeach || systeme == .beach }

    var body: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceMD) {
            // Onglets Formations / Stratégies (stratégies : indoor uniquement, parité menu retiré)
            if typeTerrain == .indoor {
                Picker("Onglet", selection: $onglet) {
                    ForEach(Onglet.allCases, id: \.self) { o in
                        Text(o.rawValue).tag(o)
                    }
                }
                .pickerStyle(.segmented)
            }

            switch onglet {
            case .formations: contenuFormations
            case .strategies: contenuStrategies
            }
        }
        .padding(LiquidGlassKit.espaceMD)
        .frame(width: 360)
        .presentationCompactAdaptation(.popover)
    }

    // MARK: - Onglet Formations

    @ViewBuilder
    private var contenuFormations: some View {
        // Segmented système — masqué sur terrain beach (beach imposé)
        if !estTerrainBeach {
            Picker("Système", selection: $systeme) {
                ForEach(SystemeFormation.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
        }

        if afficheBeach {
            tuilesBeach
        } else {
            // Segmented mode — indoor uniquement
            Picker("Mode", selection: $mode) {
                Text("Base").tag(FormationMode.base)
                Text("Réception").tag(FormationMode.reception)
                Text("Attaque").tag(FormationMode.attaque)
            }
            .pickerStyle(.segmented)

            grilleRotations
        }

        Divider()

        LegendePostesView(inclureBeach: afficheBeach)
    }

    // MARK: Grille des 6 rotations (indoor)

    @ViewBuilder
    private var grilleRotations: some View {
        if let type = systeme.formationTypeIndoor {
            LazyVGrid(columns: Self.colonnesRotations, spacing: LiquidGlassKit.espaceSM) {
                ForEach(0..<type.nombreRotations, id: \.self) { r in
                    tuileRotation(type: type, rotation: r)
                }
            }
        }
    }

    private func tuileRotation(type: FormationType, rotation: Int) -> some View {
        let estPerso = existePerso(type: type, rotation: rotation, mode: mode)
        return Button {
            onFormation(type, rotation, mode)
            dismiss()
        } label: {
            VStack(spacing: LiquidGlassKit.espaceXS) {
                ZStack {
                    MiniTerrainTuile()
                    Text("R\(rotation + 1)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                .frame(height: 56)
                .overlay(alignment: .topTrailing) {
                    if estPerso { badgePerso }
                }

                Text(type.descriptionRotation(rotation))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(LiquidGlassKit.espaceXS)
            .contentShape(RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Rotation \(rotation + 1), \(type.descriptionRotation(rotation))\(estPerso ? ", personnalisée" : "")")
        .accessibilityHint("Pose la formation \(type.rawValue) rotation \(rotation + 1) sur le terrain")
    }

    // MARK: Tuiles beach (3 types, pas de rotation ni mode)

    private var tuilesBeach: some View {
        VStack(spacing: LiquidGlassKit.espaceSM) {
            ForEach(typesBeach, id: \.self) { type in
                tuileBeach(type)
            }
        }
    }

    private func tuileBeach(_ type: FormationType) -> some View {
        Button {
            onFormation(type, 0, .base)
            dismiss()
        } label: {
            HStack(spacing: LiquidGlassKit.espaceMD) {
                MiniTerrainTuile()
                    .frame(width: 72, height: 44)

                Text(type.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: LiquidGlassKit.espaceXS) {
                    ForEach(type.lineup, id: \.self) { label in
                        JetonPoste(label: label)
                    }
                }
            }
            .padding(LiquidGlassKit.espaceSM)
            .frame(minHeight: 44)
            .background(
                PaletteMat.orange.opacity(LiquidGlassKit.teinteFond),
                in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Formation beach \(type.rawValue)")
        .accessibilityHint("Pose la formation \(type.rawValue) sur le terrain")
    }

    // MARK: Badge « perso »

    private var badgePerso: some View {
        Text("perso")
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, LiquidGlassKit.espaceXS + 1)
            .padding(.vertical, 1)
            .background(PaletteMat.attention, in: Capsule())
            .padding(2)
    }

    private func existePerso(type: FormationType, rotation: Int, mode: FormationMode) -> Bool {
        formationsPerso.contains {
            $0.formationTypeRaw == type.rawValue &&
            $0.rotation == rotation &&
            $0.modeRaw == mode.rawValue
        }
    }

    // MARK: - Onglet Stratégies

    @ViewBuilder
    private var contenuStrategies: some View {
        if strategiesOffensives.isEmpty {
            ContentUnavailableView(
                "Aucune stratégie",
                systemImage: "list.clipboard",
                description: Text("Créez des stratégies dans la section Stratégies pour les charger ici.")
            )
            .frame(minHeight: 180)
        } else {
            ScrollView {
                VStack(spacing: LiquidGlassKit.espaceXS) {
                    ForEach(strategiesOffensives, id: \.id) { strat in
                        boutonStrategie(strat)
                    }
                }
            }
            .frame(maxHeight: 320)
        }
    }

    private func boutonStrategie(_ strat: StrategieCollective) -> some View {
        Button {
            onStrategie?(strat)
            dismiss()
        } label: {
            HStack {
                Text(strat.nom)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, LiquidGlassKit.espaceMD)
            .padding(.vertical, LiquidGlassKit.espaceSM)
            .frame(minHeight: 44)
            .background(
                PaletteMat.bleu.opacity(LiquidGlassKit.teinteFond),
                in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Charge la stratégie \(strat.nom) sur le terrain")
    }
}

// MARK: - Mini-terrain stylisé (tuile)

/// Demi-terrain stylisé : parquet + ligne des 3 m + filet à droite.
private struct MiniTerrainTuile: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMini, style: .continuous)
                    .fill(PaletteMat.orange.opacity(0.12))
                RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMini, style: .continuous)
                    .stroke(PaletteMat.orange.opacity(0.35), lineWidth: 1)

                // Ligne des 3 m (attaque) — aux 2/3 du demi-terrain
                Rectangle()
                    .fill(PaletteMat.orange.opacity(0.35))
                    .frame(width: 1, height: geo.size.height - 2)
                    .position(x: geo.size.width * 2 / 3, y: geo.size.height / 2)

                // Filet — bord droit
                Rectangle()
                    .fill(PaletteMat.orange.opacity(0.55))
                    .frame(width: 2, height: geo.size.height - 2)
                    .position(x: geo.size.width - 2, y: geo.size.height / 2)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Jeton de poste

/// Pastille circulaire colorée par poste (source : FormationType.couleurPourLabel).
struct JetonPoste: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(FormationType.couleurPourLabel(label), in: Circle())
            .accessibilityHidden(true)
    }
}

// MARK: - Légende des postes

/// Légende compacte des postes (P = Passeur…) — utilisée dans le panneau
/// formations et dans FormationsView (bouton info → popover).
struct LegendePostesView: View {
    var inclureBeach: Bool = false

    private static let colonnes = Array(
        repeating: GridItem(.flexible(), alignment: .leading), count: 2)

    private var entrees: [(label: String, nom: String)] {
        if inclureBeach {
            return [("J1", "Joueur 1"), ("J2", "Joueur 2"),
                    ("B", "Bloqueur"), ("D", "Défenseur")]
        }
        return [("P", "Passeur"), ("C", "Central"),
                ("R", "Réceptionneur"), ("O", "Opposé"),
                ("L", "Libéro"), ("A", "Attaquant")]
    }

    var body: some View {
        LazyVGrid(columns: Self.colonnes, spacing: LiquidGlassKit.espaceXS + 2) {
            ForEach(entrees, id: \.label) { entree in
                HStack(spacing: LiquidGlassKit.espaceSM) {
                    JetonPoste(label: entree.label)
                    Text(entree.nom)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(entree.label) : \(entree.nom)")
            }
        }
    }
}
