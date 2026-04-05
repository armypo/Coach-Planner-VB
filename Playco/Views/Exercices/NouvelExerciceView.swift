//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI

struct NouvelExerciceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var nom = ""
    @State private var typeTerrain: TypeTerrain = .indoor
    @FocusState private var focused: Bool
    let onCreer: (String, TypeTerrain) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Champ de saisie
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NOM DE L'EXERCICE")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)
                        TextField("ex : Service en flottant", text: $nom)
                            .font(.title3)
                            .padding(14)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                            .focused($focused)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit { valider() }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("TYPE DE TERRAIN")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)
                        Picker("Terrain", selection: $typeTerrain) {
                            ForEach(TypeTerrain.allCases, id: \.self) { t in
                                Label(t.label, systemImage: t.icone).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(24)

                Spacer()
            }
            .navigationTitle("Nouvel exercice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") { valider() }
                        .fontWeight(.semibold)
                        .disabled(nom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear { focused = true }
    }

    private func valider() {
        let n = nom.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        onCreer(n, typeTerrain)
        dismiss()
    }
}
