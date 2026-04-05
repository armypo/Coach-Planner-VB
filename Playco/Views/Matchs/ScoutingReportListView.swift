//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Liste des rapports de scouting avec création/suppression
struct ScoutingReportListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<ScoutingReport> { $0.estArchive == false },
           sort: \ScoutingReport.dateMatch, order: .reverse) private var tousRapports: [ScoutingReport]

    @State private var rapportSelectionne: ScoutingReport?

    private var rapports: [ScoutingReport] {
        tousRapports.filtreEquipe(codeEquipeActif)
    }

    var body: some View {
        List {
            if rapports.isEmpty {
                ContentUnavailableView {
                    Label("Aucun rapport", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text("Créez un rapport pour analyser un adversaire.")
                } actions: {
                    Button("Nouveau rapport") {
                        creerRapport()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            ForEach(rapports) { rapport in
                NavigationLink {
                    ScoutingReportView(rapport: rapport)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(rapport.adversaire.isEmpty ? "Sans nom" : "vs \(rapport.adversaire)")
                            .font(.headline)
                        if !rapport.adversaireObserve.isEmpty {
                            Text("contre \(rapport.adversaireObserve)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        HStack(spacing: 8) {
                            Text(rapport.dateMatch.formatCourt())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !rapport.systemJeu.isEmpty {
                                Text(rapport.systemJeu)
                                    .font(.caption2.weight(.medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.red.opacity(0.1), in: Capsule())
                                    .foregroundStyle(.red)
                            }
                            if !rapport.joueurs.isEmpty {
                                Text("\(rapport.joueurs.count) joueurs")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        rapport.estArchive = true
                        try? modelContext.save()
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("Rapports")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Fermer") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { creerRapport() } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private func creerRapport() {
        let rapport = ScoutingReport()
        rapport.codeEquipe = codeEquipeActif
        rapport.dateMatch = Date()
        modelContext.insert(rapport)
        rapportSelectionne = rapport
    }
}
