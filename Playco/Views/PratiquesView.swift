//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Section Séances — pratiques & matchs (anciennement ContentView)
struct PratiquesView: View {
    var retour: () -> Void

    @Environment(AuthService.self) private var authService
    @Query private var profils: [ProfilCoach]

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var seanceSelectionnee: Seance?
    @State private var afficherBibliotheque = false
    @State private var afficherPlanification = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ListeSeancesView(seanceSelectionnee: $seanceSelectionnee)
                .navigationSplitViewColumnWidth(min: 380, ideal: 480, max: 580)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        boutonRetour
                    }
                    // C4 (pivot) : le calendrier a un accès racine (Dock) —
                    // plus de double porte modale par section.
                    ToolbarItem(placement: .bottomBar) {
                        HStack(spacing: 24) {
                            Button {
                                afficherBibliotheque = true
                            } label: {
                                Label("Bibliothèque", systemImage: "books.vertical.fill")
                                    .font(.subheadline.weight(.medium))
                            }

                            Button {
                                afficherPlanification = true
                            } label: {
                                Label("Planification", systemImage: "chart.bar.xaxis")
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                    }
                }
        } detail: {
            NavigationStack {
                if let seance = seanceSelectionnee {
                    ListeExercicesView(seance: seance)
                } else {
                    EtatVidePratiquesView()
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(PaletteMat.orange)
        .sheet(isPresented: $afficherPlanification) {
            NavigationStack {
                PlanificationSaisonView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Fermer") { afficherPlanification = false }
                                .foregroundStyle(.secondary)
                        }
                    }
            }
        }
        .sheet(isPresented: $afficherBibliotheque) {
            NavigationStack {
                BibliothequeView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Fermer") { afficherBibliotheque = false }
                                .foregroundStyle(.secondary)
                        }
                    }
            }
        }
    }

    private var boutonRetour: some View {
        BoutonRetourAccueil(couleur: PaletteMat.orange) { retour() }
    }
}


private struct EtatVidePratiquesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.volleyball")
                .font(.system(size: 80, weight: .thin))
                .foregroundStyle(.quaternary)
            Text("Sélectionnez une séance")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
            Text("ou créez-en une nouvelle avec +")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
