//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI

/// Étape 2 — Sélectionner le sport
struct ConfigSportView: View {
    @Binding var sportChoisi: SportType

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                titreEtape(numero: 2, titre: "Type de volleyball",
                           description: "Ce choix détermine le terrain par défaut et les formations disponibles.")

                VStack(spacing: 16) {
                    ForEach(SportType.allCases, id: \.self) { sport in
                        let estSelectionne = sportChoisi == sport
                        Button {
                            withAnimation(.spring(response: 0.3)) { sportChoisi = sport }
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: sport.icone)
                                    .font(.system(size: 32))
                                    .foregroundStyle(estSelectionne ? .white : PaletteMat.orange)
                                    .frame(width: 56, height: 56)
                                    .background(
                                        estSelectionne ? PaletteMat.orange : PaletteMat.orange.opacity(0.1),
                                        in: RoundedRectangle(cornerRadius: 14)
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(sport.rawValue)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(sport.description)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: estSelectionne ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundStyle(estSelectionne ? PaletteMat.orange : Color.gray.opacity(0.3))
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.secondarySystemGroupedBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(estSelectionne ? PaletteMat.orange : .clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(.vertical, 24)
        }
    }
}
