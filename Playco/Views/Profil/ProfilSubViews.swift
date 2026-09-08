//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

// MARK: - Sheet création nouvelle équipe

struct NouvelleEquipeSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var etablissements: [Etablissement]

    @State private var nom = ""
    @State private var categorie: CategorieEquipe = .masculin
    @State private var division: DivisionEquipe = .division1
    @State private var saison = ""

    // Établissement
    @State private var choixEtablissement: ChoixEtablissement = .existant
    @State private var etablissementSelectionne: Etablissement?
    @State private var nouveauNomEtablissement = ""
    @State private var nouveauTypeEtablissement: TypeEtablissement = .universite
    @State private var nouvelleVille = ""
    @State private var nouvelleProvince = "QC"

    enum ChoixEtablissement: String, CaseIterable {
        case existant = "Existant"
        case nouveau = "Nouveau"
    }

    private let provinces = [
        "QC", "ON", "BC", "AB", "SK", "MB", "NB", "NS", "PE", "NL", "NT", "YT", "NU"
    ]

    private var formulaireValide: Bool {
        let nomOk = !nom.trimmingCharacters(in: .whitespaces).isEmpty
        if choixEtablissement == .nouveau {
            return nomOk && !nouveauNomEtablissement.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return nomOk
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nom de l'équipe") {
                    TextField("Ex: Diablos B", text: $nom)
                }
                Section("Catégorie") {
                    Picker("Catégorie", selection: $categorie) {
                        ForEach(CategorieEquipe.allCases, id: \.self) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Division") {
                    Picker("Division", selection: $division) {
                        ForEach(DivisionEquipe.allCases, id: \.self) { d in
                            Text(d.rawValue).tag(d)
                        }
                    }
                }
                Section("Saison") {
                    TextField("Ex: 2025-2026", text: $saison)
                }

                // Établissement
                Section("Établissement") {
                    if !etablissements.isEmpty {
                        Picker("", selection: $choixEtablissement) {
                            ForEach(ChoixEtablissement.allCases, id: \.self) { c in
                                Text(c.rawValue).tag(c)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    if choixEtablissement == .existant && !etablissements.isEmpty {
                        ForEach(etablissements) { etab in
                            Button {
                                etablissementSelectionne = etab
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(etab.nom)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.primary)
                                        Text("\(etab.typeEtablissement.rawValue) — \(etab.ville.isEmpty ? etab.province : "\(etab.ville), \(etab.province)")")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if etablissementSelectionne?.id == etab.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(PaletteMat.vert)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        TextField("Nom de l'établissement", text: $nouveauNomEtablissement)
                        Picker("Type", selection: $nouveauTypeEtablissement) {
                            ForEach(TypeEtablissement.allCases, id: \.self) { t in
                                Text(t.rawValue).tag(t)
                            }
                        }
                        HStack {
                            TextField("Ville", text: $nouvelleVille)
                            Picker("Province", selection: $nouvelleProvince) {
                                ForEach(provinces, id: \.self) { p in
                                    Text(p).tag(p)
                                }
                            }
                            .frame(width: 90)
                        }
                    }
                }
            }
            .navigationTitle("Nouvelle équipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") { creerEquipe() }
                        .disabled(!formulaireValide)
                }
            }
            .onAppear {
                // Pré-sélectionner le premier établissement
                if etablissementSelectionne == nil {
                    etablissementSelectionne = etablissements.first
                }
                if etablissements.isEmpty {
                    choixEtablissement = .nouveau
                }
            }
        }
    }

    private func creerEquipe() {
        // Établissement
        let etab: Etablissement
        if choixEtablissement == .nouveau || etablissements.isEmpty {
            etab = Etablissement(
                nom: nouveauNomEtablissement,
                type: nouveauTypeEtablissement,
                ville: nouvelleVille,
                province: nouvelleProvince
            )
            modelContext.insert(etab)
        } else {
            guard let etabExistant = etablissementSelectionne ?? etablissements.first else { return }
            etab = etabExistant
        }

        let equipe = Equipe(nom: nom)
        equipe.categorie = categorie
        equipe.division = division
        equipe.saison = saison
        equipe.etablissement = etab
        equipe.codeEquipe = Equipe.genererCodeEquipe()
        modelContext.insert(equipe)
        try? modelContext.save()
        dismiss()
    }
}
