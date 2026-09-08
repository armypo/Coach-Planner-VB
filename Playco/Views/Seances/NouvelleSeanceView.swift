//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI

struct NouvelleSeanceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var nom = ""
    @State private var date = Date()
    @FocusState private var focused: Bool
    let onCreer: (String, Date) -> Void

    var body: some View {
        NavigationStack {
            // D vague 1bis : création en Form — le pattern unique des sheets
            // de création (modèle : NouvelleStrategieView).
            Form {
                Section("Séance") {
                    TextField("ex : Entraînement lundi matin", text: $nom)
                        .focused($focused)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { valider() }
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .environment(\.locale, Locale(identifier: "fr_FR"))
                        .tint(PaletteMat.orange)
                }
            }
            .navigationTitle("Nouvelle séance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") { valider() }
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
        onCreer(n.isEmpty ? "Séance du \(date.formatCourt())" : n, date)
        dismiss()
    }
}
