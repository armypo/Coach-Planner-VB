//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import PencilKit
import Combine

/// Composant partagé : terrain de volleyball + canvas PencilKit + overlay vectoriel + barre d'outils + notes + étapes
/// Utilisé par ExerciceDetailView et BibliothequeDetailView
/// P1-05 — État déplacé vers TerrainEditeurViewModel (@Observable)
struct TerrainEditeurView: View {
    @Binding var dessinData: Data?
    @Binding var elementsData: Data?
    @Binding var notes: String
    @Binding var etapesData: Data?
    var typeTerrain: TypeTerrain = .indoor

    var afficherNotes: Bool = true
    var labelEtape: String = "Étape"
    var strategiesOffensives: [StrategieCollective] = []
    var joueursBD: [JoueurEquipe] = []
    var formationsPerso: [FormationPersonnalisee] = []

    // MARK: - ViewModel (P1-05)
    @State private var vm = TerrainEditeurViewModel()

    @State private var afficherPresentation = false
    @FocusState private var notesFocused: Bool

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Binding vers le verrouillage dans le ViewModel
    private var verrouilleBinding: Binding<Bool> {
        Binding(
            get: { vm.verrouille },
            set: { _ in vm.toggleVerrouillage() }
        )
    }

    /// Détecte l'orientation portrait via SwiftUI size classes
    private var orientationPortrait: Bool {
        verticalSizeClass == .regular && horizontalSizeClass == .compact
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Toolbar
                barreOutils
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                    .padding(.bottom, 4)

                // Terrain + Canvas + Overlay
                ZStack {
                    TerrainVolleyView(afficherZones: vm.afficherZones, typeTerrain: typeTerrain)

                    if vm.afficherDessinLibre {
                        CanvasDessinView(
                            drawing: $vm.drawing, mode: vm.modeActif,
                            couleurOutil: UIColor(vm.couleur), epaisseurOutil: vm.epaisseur,
                            controller: vm.canvasCtrl
                        )
                    }

                    OverlayDessinView(
                        elements: $vm.elements, mode: vm.modeActif,
                        couleur: vm.couleur, prochainNumero: $vm.prochainNumero,
                        verrouille: vm.verrouille,
                        onEtatChange: { vm.enregistrerEtat() }
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1))
                .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
                .padding(.horizontal, 10)
                .aspectRatio(orientationPortrait ? 0.5 : 2.0, contentMode: .fit)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: orientationPortrait)

                // Barre d'étapes — toujours visible sous le terrain
                barreEtapes
                    .padding(.horizontal, 10)
                    .padding(.top, 6)

                Spacer(minLength: 0)
            }

            // Bulle de notes
            if afficherNotes {
                bulleNotes
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
            }

            // Indicateur sauvegarde
            if let date = vm.derniereSauvegarde {
                indicateurSauvegarde(date: date)
                    .padding(.leading, 16)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
        .onAppear {
            vm.charger(dessinData: dessinData, elementsData: elementsData, etapesData: etapesData)
        }
        .onDisappear { sauvegarder() }
        // P0-03 v0.4.0 — Debounce 3s au lieu de Timer fixe 10s (élimine race condition)
        .onChange(of: vm.elements) { _, _ in vm.planifierSauvegarde() }
        .onChange(of: vm.drawing) { _, _ in vm.planifierSauvegarde() }
        .onReceive(vm.debounceSave) { _ in
            sauvegarder()
        }
        .fullScreenCover(isPresented: $afficherPresentation) {
            PresentationTerrainView(
                dessinData: dessinData,
                elementsData: elementsData,
                etapesData: etapesData,
                typeTerrain: typeTerrain
            )
        }
    }

    // MARK: - Sauvegarde (écrit bindings)
    private func sauvegarder() {
        vm.sauvegarder(dessinData: &dessinData, elementsData: &elementsData, etapesData: &etapesData)
    }

    // MARK: - Barre d'outils
    private var barreOutils: some View {
        BarreOutilsDessin(
            modeActif: $vm.modeActif, couleur: $vm.couleur,
            epaisseur: $vm.epaisseur, drawing: $vm.drawing,
            elements: $vm.elements, afficherZones: $vm.afficherZones,
            afficherDessinLibre: $vm.afficherDessinLibre,
            clipboardElements: $vm.clipboardElements,
            verrouille: verrouilleBinding,
            typeTerrain: typeTerrain,
            controller: vm.canvasCtrl,
            onUndo: { vm.annuler() }, onRedo: { vm.retablir() },
            peutAnnuler: vm.peutAnnuler, peutRetablir: vm.peutRetablir,
            onFormation: { formation, rotation, mode in
                vm.ajouterFormation(formation, rotation: rotation, mode: mode,
                                    formationsPerso: formationsPerso)
            },
            strategiesOffensives: strategiesOffensives,
            onStrategieOffensive: { strat in
                vm.chargerStrategie(strat)
            },
            joueursBD: joueursBD,
            onPlacerJoueur: { joueur in
                vm.placerJoueurBD(joueur)
            },
            onEffacerTout: {
                vm.effacerTout()
            },
            onPresentation: {
                sauvegarder()
                afficherPresentation = true
            }
        )
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }

    // MARK: - Barre d'étapes
    private var barreEtapes: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // Étape principale
                etapeBouton(index: 0, label: "\(labelEtape) 1")

                // Étapes supplémentaires
                ForEach(vm.etapes.indices, id: \.self) { i in
                    etapeBouton(index: i + 1,
                                label: vm.etapes[i].nom.isEmpty ? "\(labelEtape) \(i + 2)" : vm.etapes[i].nom)
                }

                // Bouton ajouter
                Button {
                    vm.ajouterEtape(dessinData: &dessinData, elementsData: &elementsData)
                    etapesData = vm.sauvegarderEtapes()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text(labelEtape)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .frame(height: 40)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func etapeBouton(index: Int, label: String) -> some View {
        let estActive = vm.etapeActive == index
        let estVerrouillee = vm.etapesVerrouillees.contains(index)
        return Button {
            vm.changerEtape(index: index, dessinData: &dessinData, elementsData: &elementsData)
        } label: {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption.weight(estActive ? .bold : .regular))
                if estVerrouillee {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8))
                }
            }
            .foregroundStyle(estActive ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(estActive ? Color.orange : Color.primary.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 8))
        }
        .contextMenu {
            if index > 0 {
                Button {
                    vm.renommerEtape(index: index)
                    etapesData = vm.sauvegarderEtapes()
                } label: {
                    Label("Renommer", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    vm.supprimerEtape(index: index, dessinData: dessinData, elementsData: elementsData)
                    etapesData = vm.sauvegarderEtapes()
                } label: {
                    Label("Supprimer", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Bulle de notes rétractable
    @ViewBuilder
    private var bulleNotes: some View {
        if vm.notesDeployees {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "note.text")
                        .foregroundStyle(.orange).font(.caption)
                    Text("Notes").font(.caption.weight(.semibold))
                    Spacer()
                    Button {
                        withAnimation(LiquidGlassKit.springDefaut) {
                            notesFocused = false
                            vm.notesDeployees = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 6)

                TextEditor(text: $notes)
                    .font(.callout).padding(8)
                    .scrollContentBackground(.hidden)
                    .focused($notesFocused)
                    .overlay(alignment: .topLeading) {
                        if notes.isEmpty {
                            Text("Ajoutez vos notes…")
                                .foregroundStyle(.tertiary)
                                .font(.callout)
                                .padding(.leading, 12).padding(.top, 16)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(height: 160)

                Divider().padding(.horizontal, 8)

                Text("\(notes.count) caractères")
                    .font(.caption2).foregroundStyle(.tertiary)
                    .padding(.horizontal, 12).padding(.vertical, 6)
            }
            .frame(width: 280)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
            .transition(.scale(scale: 0.5, anchor: .bottomTrailing)
                .combined(with: .opacity))
        } else {
            Button {
                withAnimation(LiquidGlassKit.springDefaut) { vm.notesDeployees = true }
            } label: {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        Image(systemName: "note.text")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.orange)
                    }
                    .frame(width: 48, height: 48)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)

                    if !notes.isEmpty {
                        Circle()
                            .fill(.orange)
                            .frame(width: 10, height: 10)
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .transition(.scale(scale: 0.5, anchor: .bottomTrailing)
                .combined(with: .opacity))
        }
    }

    // MARK: - Indicateur sauvegarde
    private func indicateurSauvegarde(date: Date) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green.opacity(0.7))
            Text("Sauvegardé")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .opacity(Date().timeIntervalSince(date) < 3 ? 1 : 0)
        .animation(LiquidGlassKit.springDefaut, value: vm.derniereSauvegarde)
    }

    /// Accès externe aux éléments pour PDF, etc.
    var elementsActuels: [ElementTerrain] { vm.elements }
    var drawingActuel: PKDrawing { vm.drawing }

    /// P3-03 — Indique si des modifications non sauvegardées existent
    var aDesModificationsNonSauvegardees: Bool { vm.aDesModifications }
}

// FormationType et FormationMode → Models/FormationTypes.swift (P2-04)
