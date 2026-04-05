//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI

/// Journal de synchronisation — affiche les événements sync récents
struct JournalSyncView: View {
    @Environment(CloudKitSyncService.self) private var syncService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if syncService.journalSync.isEmpty {
                    ContentUnavailableView(
                        "Aucun événement",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Les événements de synchronisation apparaîtront ici.")
                    )
                } else {
                    List {
                        ForEach(syncService.journalSync.reversed()) { evenement in
                            ligneEvenement(evenement)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Journal de sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !syncService.journalSync.isEmpty {
                        Button("Effacer", role: .destructive) {
                            syncService.effacerJournal()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    // MARK: - Ligne événement

    private func ligneEvenement(_ evenement: EvenementSync) -> some View {
        HStack(spacing: 12) {
            Image(systemName: evenement.type.icone)
                .font(.body)
                .foregroundStyle(couleurType(evenement))
                .frame(width: 28, height: 28)
                .background(couleurType(evenement).opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(evenement.type.label)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(couleurType(evenement))
                    if evenement.estErreur {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.red)
                    }
                }
                Text(evenement.message)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(evenement.date.formatHeure())
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    private func couleurType(_ evenement: EvenementSync) -> Color {
        if evenement.estErreur { return .red }
        switch evenement.type {
        case .importation: return PaletteMat.bleu
        case .exportation: return PaletteMat.vert
        case .setup: return PaletteMat.violet
        case .erreur: return .red
        case .connexion: return PaletteMat.vert
        case .pauseSync: return .orange
        case .repriseSync: return PaletteMat.bleu
        }
    }
}
