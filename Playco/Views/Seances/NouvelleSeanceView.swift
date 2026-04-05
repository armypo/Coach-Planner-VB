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
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    // Nom
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NOM DE LA SÉANCE")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)
                        TextField("ex : Entraînement lundi matin", text: $nom)
                            .font(.title3)
                            .padding(14)
                            .background(Color(.secondarySystemBackground),
                                        in: RoundedRectangle(cornerRadius: 12))
                            .focused($focused)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit { valider() }
                    }

                    // Date
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DATE DE LA SÉANCE")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)
                        DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "fr_FR"))
                            .tint(.orange)
                    }
                }
                .padding(24)

                Spacer()
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
