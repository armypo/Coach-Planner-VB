//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Vue de gestion des formations personnalisées du coach
struct FormationsView: View {
    @Environment(\.modelContext) private var contexte
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Query private var toutesPersonnalisees: [FormationPersonnalisee]

    private var personnalisees: [FormationPersonnalisee] {
        toutesPersonnalisees.filtreEquipe(codeEquipeActif)
    }

    @State private var formationSelectionnee: FormationType = .cinqUn
    @State private var rotationSelectionnee: Int = 0
    @State private var modeSelectionne: FormationMode = .base

    // Phase 5.3b — confirmation avant écrasement d'une formation existante
    @State private var confirmerRemplacement = false
    @State private var positionsEnAttente: [FormationPositionData]? = nil

    // Phase 5.2 — légende des postes (bouton info → popover)
    @State private var afficherLegende = false

    /// Formations indoor uniquement
    private let formationsIndoor: [FormationType] = [.cinqUn, .quatreDeux, .sixDeux]

    /// Retrouve la formation personnalisée pour la sélection actuelle
    private var formationPerso: FormationPersonnalisee? {
        personnalisees.first {
            $0.formationTypeRaw == formationSelectionnee.rawValue &&
            $0.rotation == rotationSelectionnee &&
            $0.modeRaw == modeSelectionne.rawValue
        }
    }

    private var estPersonnalisee: Bool { formationPerso != nil }

    var body: some View {
        VStack(spacing: 0) {
            // Phase 5.3a — formations personnalisées existantes de l'équipe
            if !personnalisees.isEmpty {
                sectionPersonnalisees
                    .padding(.horizontal)
                    .padding(.top, LiquidGlassKit.espaceSM)
            }

            // Sélecteurs en haut
            selecteurs
                .padding(.horizontal)
                .padding(.top, 8)

            // Éditeur terrain
            FormationTerrainEditeur(
                formationType: formationSelectionnee,
                rotation: rotationSelectionnee,
                mode: modeSelectionne,
                formationPerso: formationPerso,
                onSave: { positions in
                    sauvegarder(positions)
                },
                onReset: {
                    reinitialiser()
                }
            )
            .padding()
        }
        .navigationTitle("Mes formations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                boutonLegende
            }
        }
        .alert("Remplacer la formation existante ?", isPresented: $confirmerRemplacement) {
            Button("Remplacer", role: .destructive) { remplacerExistante() }
            Button("Annuler", role: .cancel) { positionsEnAttente = nil }
        } message: {
            Text("Une formation personnalisée existe déjà pour \(formationSelectionnee.rawValue) · R\(rotationSelectionnee + 1) · \(modeSelectionne.rawValue). Elle sera écrasée.")
        }
    }

    // MARK: - Section formations personnalisées (Phase 5.3a)

    private var sectionPersonnalisees: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            EnTeteSection(
                titre: "Mes formations personnalisées",
                sousTitre: "Touchez pour ouvrir — appui long pour supprimer"
            )
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LiquidGlassKit.espaceSM) {
                    ForEach(personnaliseesTriees, id: \.id) { perso in
                        cartePerso(perso)
                    }
                }
            }
        }
    }

    private var personnaliseesTriees: [FormationPersonnalisee] {
        personnalisees.sorted {
            ($0.formationTypeRaw, $0.rotation, $0.modeRaw) < ($1.formationTypeRaw, $1.rotation, $1.modeRaw)
        }
    }

    private func cartePerso(_ perso: FormationPersonnalisee) -> some View {
        Button {
            if let type = perso.formationType { formationSelectionnee = type }
            rotationSelectionnee = min(5, max(0, perso.rotation))
            if let mode = perso.mode { modeSelectionne = mode }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(perso.formationTypeRaw)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                HStack(spacing: LiquidGlassKit.espaceXS) {
                    Text("R\(perso.rotation + 1)")
                    Text("·")
                    Text(perso.modeRaw)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, LiquidGlassKit.espaceSM + LiquidGlassKit.espaceXS)
            .padding(.vertical, LiquidGlassKit.espaceSM)
            .frame(minHeight: 44)
            .background(
                Color.orange.opacity(LiquidGlassKit.badgeFond),
                in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                contexte.delete(perso)
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
        .accessibilityLabel("Formation personnalisée \(perso.formationTypeRaw), rotation \(perso.rotation + 1), \(perso.modeRaw)")
        .accessibilityHint("Ouvre cette formation dans l'éditeur. Appui long pour supprimer.")
    }

    // MARK: - Légende des postes (Phase 5.2)

    private var boutonLegende: some View {
        Button {
            afficherLegende = true
        } label: {
            Image(systemName: "info.circle")
        }
        .accessibilityLabel("Légende des postes")
        .popover(isPresented: $afficherLegende) {
            LegendePostesView()
                .padding(LiquidGlassKit.espaceMD)
                .frame(maxWidth: 320)
                .presentationCompactAdaptation(.popover)
        }
    }

    // MARK: - Sélecteurs
    private var selecteurs: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                // Formation type
                VStack(alignment: .leading, spacing: 2) {
                    Text("Formation").font(.caption2).foregroundStyle(.secondary)
                    Picker("Formation", selection: $formationSelectionnee) {
                        ForEach(formationsIndoor, id: \.self) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Rotation
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rotation").font(.caption2).foregroundStyle(.secondary)
                    Picker("Rotation", selection: $rotationSelectionnee) {
                        ForEach(0..<6, id: \.self) { r in
                            Text("R\(r + 1)").tag(r)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            HStack(spacing: 12) {
                // Mode
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mode").font(.caption2).foregroundStyle(.secondary)
                    Picker("Mode", selection: $modeSelectionne) {
                        Text("Base").tag(FormationMode.base)
                        Text("Réception").tag(FormationMode.reception)
                        Text("Attaque").tag(FormationMode.attaque)
                    }
                    .pickerStyle(.segmented)
                }

                // Indicateur personnalisé
                if estPersonnalisee {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundStyle(.orange)
                        Text("Personnalisée")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.orange.opacity(0.1), in: Capsule())
                }
            }

            // Description rotation
            Text(formationSelectionnee.descriptionRotation(rotationSelectionnee))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Sauvegarder
    /// Phase 5.3b — demande confirmation si une personnalisation existe déjà
    /// pour la clé (type, rotation, mode) avant de l'écraser.
    private func sauvegarder(_ positions: [FormationPositionData]) {
        if formationPerso != nil {
            positionsEnAttente = positions
            confirmerRemplacement = true
        } else {
            let nouvelle = FormationPersonnalisee(
                formationType: formationSelectionnee,
                rotation: rotationSelectionnee,
                mode: modeSelectionne
            )
            nouvelle.positions = positions
            nouvelle.codeEquipe = codeEquipeActif
            contexte.insert(nouvelle)
        }
    }

    /// Remplace la personnalisation existante après confirmation.
    private func remplacerExistante() {
        defer { positionsEnAttente = nil }
        guard let positions = positionsEnAttente, let existante = formationPerso else { return }
        existante.positions = positions
        existante.dateModification = Date()
    }

    // MARK: - Réinitialiser (supprimer la personnalisation)
    private func reinitialiser() {
        if let existante = formationPerso {
            contexte.delete(existante)
        }
    }
}

// MARK: - Éditeur terrain simplifié pour formations
struct FormationTerrainEditeur: View {
    let formationType: FormationType
    let rotation: Int
    let mode: FormationMode
    let formationPerso: FormationPersonnalisee?
    let onSave: ([FormationPositionData]) -> Void
    let onReset: () -> Void

    @State private var positions: [FormationPositionData] = []
    @State private var dragIndex: Int? = nil
    @State private var confirmerReset = false

    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass) private var vSizeClass

    /// Portrait iPad = regular/regular mais height > width détectable par la scene
    private var estPortrait: Bool {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return false }
        return scene.effectiveGeometry.interfaceOrientation.isPortrait
    }

    var body: some View {
        VStack(spacing: 12) {
            // Terrain avec joueurs déplaçables
            GeometryReader { geo in
                ZStack {
                    TerrainVolleyView(afficherZones: true, typeTerrain: .indoor)

                    // Joueurs déplaçables
                    ForEach(positions.indices, id: \.self) { i in
                        joueurDraggable(index: i, taille: geo.size)
                    }
                }
            }
            .aspectRatio(estPortrait ? 0.5 : 2.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1))
            .shadow(color: .black.opacity(0.05), radius: 6, y: 2)

            // Boutons d'action
            HStack(spacing: 16) {
                Button(role: .destructive) {
                    confirmerReset = true
                } label: {
                    Label("Réinitialiser", systemImage: "arrow.counterclockwise")
                        .font(.subheadline.weight(.medium))
                }
                .disabled(formationPerso == nil)
                .confirmationDialog("Rétablir les positions par défaut ?",
                                    isPresented: $confirmerReset, titleVisibility: .visible) {
                    Button("Réinitialiser", role: .destructive) {
                        onReset()
                        chargerDefauts()
                    }
                }

                Spacer()

                Button {
                    onSave(positions)
                } label: {
                    Label("Sauvegarder", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding(.horizontal, 4)
        }
        .onAppear { chargerPositions() }
        .onChange(of: formationType) { _, _ in chargerPositions() }
        .onChange(of: rotation) { _, _ in chargerPositions() }
        .onChange(of: mode) { _, _ in chargerPositions() }
    }

    // MARK: - Joueur déplaçable
    private func joueurDraggable(index: Int, taille: CGSize) -> some View {
        let pos = positions[index]
        // Phase 5.2 — source unique des couleurs de poste
        let couleurPoste = FormationType.couleurPourLabel(pos.label)
        let px = pos.x * taille.width
        let py = pos.y * taille.height

        return ZStack {
            Circle()
                .fill(couleurPoste.opacity(0.85))
                .frame(width: 36, height: 36)
                .shadow(color: couleurPoste.opacity(0.4), radius: 4, y: 2)
            Circle()
                .stroke(.white.opacity(0.5), lineWidth: 1.5)
                .frame(width: 36, height: 36)
            Text(pos.label)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .position(x: px, y: py)
        .gesture(
            DragGesture()
                .onChanged { v in
                    let nx = max(0.02, min(0.98, v.location.x / taille.width))
                    let ny = max(0.02, min(0.98, v.location.y / taille.height))
                    positions[index].x = nx
                    positions[index].y = ny
                }
        )
    }

    // MARK: - Chargement
    private func chargerPositions() {
        if let perso = formationPerso, !perso.positions.isEmpty {
            positions = perso.positions
        } else {
            chargerDefauts()
        }
    }

    private func chargerDefauts() {
        let defauts = formationType.positions(rotation: rotation, mode: mode)
        positions = defauts.map { FormationPositionData(label: $0.label, x: $0.x, y: $0.y) }
    }
}
