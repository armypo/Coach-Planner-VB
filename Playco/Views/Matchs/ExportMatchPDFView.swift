//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Aperçu et partage du PDF de résumé de match
struct ExportMatchPDFView: View {
    let seance: Seance

    @Environment(\.dismiss) private var dismiss
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Query(filter: #Predicate<JoueurEquipe> { $0.estActif == true },
           sort: \JoueurEquipe.numero) private var joueurs: [JoueurEquipe]
    @Query private var tousStatsMatch: [StatsMatch]

    @State private var pdfData: Data?
    @State private var afficherPartage = false

    private var joueursEquipe: [JoueurEquipe] {
        joueurs.filtreEquipe(codeEquipeActif)
    }

    private var statsMatch: [StatsMatch] {
        tousStatsMatch.filter { $0.seanceID == seance.id }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Aperçu info
                VStack(spacing: 8) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 48))
                        .foregroundStyle(.red)

                    Text("Résumé de match")
                        .font(.title3.weight(.bold))

                    if !seance.adversaire.isEmpty {
                        Text("vs \(seance.adversaire)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text(seance.date.formatCourt())
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    if seance.scoreEntre {
                        HStack(spacing: 4) {
                            Text("\(seance.scoreEquipe) - \(seance.scoreAdversaire)")
                                .font(.title2.weight(.bold))
                            if let r = seance.resultat {
                                Text(r.label)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(r.couleur, in: Capsule())
                            }
                        }
                    }

                    // Contenu inclus
                    VStack(alignment: .leading, spacing: 4) {
                        contenuInclus("Score par set", present: !seance.sets.isEmpty)
                        contenuInclus("Feuille de match (\(statsMatch.count) joueurs)", present: !statsMatch.isEmpty)
                        contenuInclus("Notes de match", present: !seance.notesMatch.isEmpty)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }
                .padding()

                Spacer()

                // Bouton exporter
                Button {
                    pdfData = PDFExportService.genererPDFMatch(
                        seance: seance,
                        joueurs: joueursEquipe,
                        statsMatch: statsMatch
                    )
                    if pdfData != nil {
                        afficherPartage = true
                    }
                } label: {
                    Label("Exporter en PDF", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .navigationTitle("Export PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .sheet(isPresented: $afficherPartage) {
                if let data = pdfData {
                    let url = sauvegarderPDFTemporaire(data: data, nom: "Match_\(seance.adversaire.isEmpty ? "résumé" : seance.adversaire)")
                    ActivityViewController(activityItems: [url])
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func contenuInclus(_ label: String, present: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: present ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundStyle(present ? .green : Color.secondary.opacity(0.5))
            Text(label)
                .font(.caption)
                .foregroundStyle(present ? .primary : Color.secondary.opacity(0.5))
        }
    }

    private func sauvegarderPDFTemporaire(data: Data, nom: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(nom).pdf")
        try? data.write(to: url)
        return url
    }
}

// MARK: - UIActivityViewController wrapper

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
