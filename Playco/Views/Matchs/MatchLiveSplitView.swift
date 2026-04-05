//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Mode split-screen iPad : Dashboard live (gauche) + Stats live saisie (droite)
/// Le ViewModel est créé ici et partagé entre les deux panneaux.
struct MatchLiveSplitView: View {
    @Bindable var seance: Seance

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.modelContext) private var modelContext
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Environment(CloudKitSyncService.self) private var syncService
    @Query(filter: #Predicate<JoueurEquipe> { $0.estActif == true },
           sort: \JoueurEquipe.numero) private var tousJoueurs: [JoueurEquipe]

    @State private var viewModel: MatchLiveViewModel?
    @State private var confirmerRepriseSync = false

    private var joueursEquipe: [JoueurEquipe] {
        tousJoueurs.filtreEquipe(codeEquipeActif)
    }

    var body: some View {
        Group {
            if let vm = viewModel {
                if sizeClass == .regular {
                    // iPad : côte à côte
                    HStack(spacing: 0) {
                        DashboardMatchLiveView(viewModel: vm)
                            .frame(maxWidth: .infinity)
                        Divider()
                        StatsLiveView(viewModel: vm)
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    // iPhone : tabs
                    TabView {
                        DashboardMatchLiveView(viewModel: vm)
                            .tabItem {
                                Label("Dashboard", systemImage: "chart.bar.fill")
                            }
                        StatsLiveView(viewModel: vm)
                            .tabItem {
                                Label("Saisie", systemImage: "bolt.fill")
                            }
                    }
                }
            } else {
                ProgressView("Chargement...")
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: sizeClass)
        .overlay(alignment: .top) {
            if syncService.modeMatchActif {
                HStack(spacing: 6) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 10, weight: .bold))
                    Text("SYNC PAUSÉE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(.orange.gradient, in: Capsule())
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if syncService.modeMatchActif {
                        confirmerRepriseSync = true
                    } else {
                        withAnimation(LiquidGlassKit.springDefaut) {
                            syncService.activerModeMatch(true)
                        }
                    }
                } label: {
                    Image(systemName: syncService.modeMatchActif ? "wifi.slash" : "wifi")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(syncService.modeMatchActif ? .orange : .secondary)
                }
            }
        }
        .alert("Reprendre la synchronisation ?", isPresented: $confirmerRepriseSync) {
            Button("Annuler", role: .cancel) { }
            Button("Reprendre") {
                withAnimation(LiquidGlassKit.springDefaut) {
                    syncService.activerModeMatch(false)
                }
            }
        } message: {
            Text("Les données du match seront synchronisées avec iCloud.")
        }
        .onAppear {
            if viewModel == nil {
                let vm = MatchLiveViewModel(
                    seance: seance,
                    modelContext: modelContext,
                    joueurs: joueursEquipe,
                    codeEquipe: codeEquipeActif
                )
                vm.syncService = syncService
                viewModel = vm
                // Activer mode match automatiquement
                syncService.activerModeMatch(true)
            }
        }
        .onDisappear {
            // Désactiver mode match quand on quitte le match live
            if syncService.modeMatchActif {
                syncService.activerModeMatch(false)
            }
        }
        .onChange(of: joueursEquipe) {
            viewModel?.mettreAJourJoueurs(joueursEquipe, codeEquipe: codeEquipeActif)
        }
        .onChange(of: codeEquipeActif) {
            viewModel?.mettreAJourJoueurs(joueursEquipe, codeEquipe: codeEquipeActif)
        }
    }
}
