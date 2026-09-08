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
            // D vague 1bis : création en Form — pattern unique des sheets.
            Form {
                Section("Exercice") {
                    TextField("ex : Service en flottant", text: $nom)
                        .focused($focused)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { valider() }
                }
                Section("Type de terrain") {
                    Picker("Terrain", selection: $typeTerrain) {
                        ForEach(TypeTerrain.allCases, id: \.self) { t in
                            Label(t.label, systemImage: t.icone).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }
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
