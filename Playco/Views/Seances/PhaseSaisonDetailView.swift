//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Sheet éditeur pour créer ou modifier une phase de saison
struct PhaseSaisonDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var phase: PhaseSaison?
    let codeEquipe: String

    @State private var nom: String = ""
    @State private var typePhase: TypePhase = .preSaison
    @State private var dateDebut: Date = Date()
    @State private var dateFin: Date = Date().addingTimeInterval(7 * 86400)
    @State private var objectifs: String = ""
    @State private var volumeHebdo: Int = 0

    private var estEdition: Bool { phase != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Informations") {
                    TextField("Nom de la phase (optionnel)", text: $nom)

                    Picker("Type", selection: $typePhase) {
                        ForEach(TypePhase.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icone)
                                .tag(type)
                        }
                    }
                }

                Section("Dates") {
                    DatePicker("Début", selection: $dateDebut, displayedComponents: .date)
                    DatePicker("Fin", selection: $dateFin, in: dateDebut..., displayedComponents: .date)
                }

                Section("Volume d'entraînement") {
                    Stepper("Cible : \(volumeHebdo)h / semaine", value: $volumeHebdo, in: 0...40)
                }

                Section("Objectifs") {
                    TextEditor(text: $objectifs)
                        .frame(minHeight: 80)
                }

                if estEdition {
                    Section {
                        Button(role: .destructive) {
                            if let phase { modelContext.delete(phase) }
                            dismiss()
                        } label: {
                            Label("Supprimer cette phase", systemImage: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle(estEdition ? "Modifier la phase" : "Nouvelle phase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        sauvegarder()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let phase {
                    nom = phase.nom
                    typePhase = phase.typePhase
                    dateDebut = phase.dateDebut
                    dateFin = phase.dateFin
                    objectifs = phase.objectifs
                    volumeHebdo = phase.volumeHebdo
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func sauvegarder() {
        if let phase {
            phase.nom = nom
            phase.typePhase = typePhase
            phase.dateDebut = dateDebut
            phase.dateFin = dateFin
            phase.objectifs = objectifs
            phase.volumeHebdo = volumeHebdo
            phase.dateModification = Date()
        } else {
            let nouvelle = PhaseSaison(nom: nom, type: typePhase,
                                        dateDebut: dateDebut, dateFin: dateFin)
            nouvelle.objectifs = objectifs
            nouvelle.volumeHebdo = volumeHebdo
            nouvelle.codeEquipe = codeEquipe
            modelContext.insert(nouvelle)
        }
    }
}
