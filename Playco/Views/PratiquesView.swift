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
    @State private var afficherCalendrier = false
    @State private var afficherPlanification = false

    /// Contenu masqué pour les athlètes si le coach l'a activé
    private var contenuMasque: Bool {
        guard authService.utilisateurConnecte?.role == .etudiant else { return false }
        return profils.first?.masquerPratiquesAthletes ?? false
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ListeSeancesView(seanceSelectionnee: $seanceSelectionnee)
                .navigationSplitViewColumnWidth(min: 380, ideal: 480, max: 580)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        boutonRetour
                    }
                    ToolbarItem(placement: .bottomBar) {
                        HStack(spacing: 24) {
                            Button {
                                afficherCalendrier = true
                            } label: {
                                Label("Calendrier", systemImage: "calendar")
                                    .font(.subheadline.weight(.medium))
                            }

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
                if contenuMasque {
                    ContenuMasqueView()
                } else if let seance = seanceSelectionnee {
                    ListeExercicesView(seance: seance)
                } else {
                    EtatVidePratiquesView()
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(.orange)
        .sheet(isPresented: $afficherCalendrier) {
            NavigationStack {
                CalendrierView()
            }
        }
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
        Button {
            retour()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                Image(systemName: "volleyball.fill")
                    .font(.system(size: 14))
                Text("Accueil")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.orange)
        }
    }
}

/// Contenu masqué par le coach — affiché aux athlètes
struct ContenuMasqueView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "eye.slash.fill")
                .font(.system(size: 60, weight: .thin))
                .foregroundStyle(.quaternary)
            Text("Contenu masqué")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
            Text("Votre coach a choisi de masquer le détail des séances.\nVous pouvez consulter les dates et horaires dans la liste.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
