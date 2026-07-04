//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Analyse d'un match terminé (liens croisés 2.4 de la refonte stats) :
//  feuille de match, rotations et heatmap pré-filtrées sur ce match.
//  Accessible depuis MatchDetailView dès que les stats sont finalisées.
//

import SwiftUI

struct AnalyseMatchSheet: View {
    let seance: Seance
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        BoxScoreView(seance: seance)
                    } label: {
                        ligne(titre: "Feuille de match",
                              sousTitre: "Box score complet par joueur",
                              icone: "tablecells", teinte: .red)
                    }

                    NavigationLink {
                        StatsParRotationView(seanceID: seance.id)
                    } label: {
                        ligne(titre: "Rotations",
                              sousTitre: "Performance par rotation 1 à 6",
                              icone: "arrow.triangle.2.circlepath", teinte: PaletteMat.bleu)
                    }

                    NavigationLink {
                        HeatmapEquipeView(seanceID: seance.id)
                    } label: {
                        ligne(titre: "Heatmap terrain",
                              sousTitre: "Actions par zone du terrain",
                              icone: "square.grid.3x2.fill", teinte: PaletteMat.orange)
                    }
                } header: {
                    Text(seance.adversaire.isEmpty ? seance.nom : "vs \(seance.adversaire)")
                }
            }
            .navigationTitle("Analyse du match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private func ligne(titre: String, sousTitre: String, icone: String, teinte: Color) -> some View {
        HStack(spacing: LiquidGlassKit.espaceMD) {
            Image(systemName: icone)
                .font(.system(size: 17))
                .foregroundStyle(teinte)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(titre)
                    .font(.subheadline.weight(.medium))
                Text(sousTitre)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
