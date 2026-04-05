//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Bibliothèque d'exercices de musculation — création, édition, suppression
struct BibliothequeMusculationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Query(sort: \ExerciceMuscu.nom) private var tousExercices: [ExerciceMuscu]

    @State private var recherche = ""
    @State private var categorieFiltree: CategorieMuscu?
    @State private var afficherCreation = false
    @State private var exerciceEdite: ExerciceMuscu?

    private var peutModifier: Bool {
        authService.utilisateurConnecte?.role.peutGererProgrammes ?? false
    }

    private var exercicesFiltres: [ExerciceMuscu] {
        var result = tousExercices
        if let cat = categorieFiltree {
            result = result.filter { $0.categorieRaw == cat.rawValue }
        }
        if !recherche.isEmpty {
            result = result.filter { $0.nom.localizedCaseInsensitiveContains(recherche) }
        }
        return result
    }

    /// Exercices groupés par catégorie
    private var exercicesParCategorie: [(CategorieMuscu, [ExerciceMuscu])] {
        let grouped = Dictionary(grouping: exercicesFiltres) { $0.categorie }
        return CategorieMuscu.allCases.compactMap { cat in
            guard let exos = grouped[cat], !exos.isEmpty else { return nil }
            return (cat, exos)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filtre catégories
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    boutonCategorie(nil, label: "Tous")
                    ForEach(CategorieMuscu.allCases, id: \.self) { cat in
                        boutonCategorie(cat, label: cat.rawValue)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            // Compteur
            HStack {
                Text("\(exercicesFiltres.count) exercice\(exercicesFiltres.count > 1 ? "s" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)

            // Liste
            if exercicesFiltres.isEmpty {
                etatVide
            } else {
                List {
                    ForEach(exercicesParCategorie, id: \.0) { cat, exos in
                        Section {
                            ForEach(exos) { exo in
                                Button {
                                    if peutModifier { exerciceEdite = exo }
                                } label: {
                                    ligneExercice(exo)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing) {
                                    if peutModifier {
                                        Button(role: .destructive) {
                                            modelContext.delete(exo)
                                            try? modelContext.save()
                                        } label: {
                                            Label("Supprimer", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Image(systemName: cat.icone)
                                    .foregroundStyle(cat.couleur)
                                Text(cat.rawValue)
                            }
                            .font(.subheadline.weight(.bold))
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Bibliothèque muscu")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $recherche, prompt: "Rechercher un exercice")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { afficherCreation = true } label: {
                    Image(systemName: "plus")
                }
                .siAutorise(peutModifier)
            }
        }
        .sheet(isPresented: $afficherCreation) {
            EditerExerciceMusculationSheet(mode: .creation) { nom, categorie, notes in
                let exo = ExerciceMuscu(nom: nom, categorie: categorie, notes: notes)
                modelContext.insert(exo)
                try? modelContext.save()
            }
        }
        .sheet(item: $exerciceEdite) { exo in
            EditerExerciceMusculationSheet(
                mode: .edition,
                nomInitial: exo.nom,
                categorieInitiale: exo.categorie,
                notesInitiales: exo.notes
            ) { nom, categorie, notes in
                exo.nom = nom
                exo.categorie = categorie
                exo.notes = notes
                try? modelContext.save()
            }
        }
    }

    // MARK: - Ligne exercice

    private func ligneExercice(_ exo: ExerciceMuscu) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(exo.categorie.couleur.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: exo.categorie.icone)
                    .font(.system(size: 14))
                    .foregroundStyle(exo.categorie.couleur)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(exo.nom)
                    .font(.subheadline.weight(.medium))
                if !exo.notes.isEmpty {
                    Text(exo.notes)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Filtre catégorie

    private func boutonCategorie(_ cat: CategorieMuscu?, label: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { categorieFiltree = cat }
        } label: {
            Text(label)
                .font(.caption.weight(categorieFiltree == cat ? .bold : .regular))
                .foregroundStyle(categorieFiltree == cat ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    categorieFiltree == cat
                        ? AnyShapeStyle(cat?.couleur ?? PaletteMat.violet)
                        : AnyShapeStyle(Color.primary.opacity(0.06)),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - État vide

    private var etatVide: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "dumbbell")
                .font(.system(size: 50))
                .foregroundStyle(.tertiary)
            Text("Aucun exercice trouvé")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if peutModifier {
                Button { afficherCreation = true } label: {
                    Label("Créer un exercice", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(PaletteMat.violet.opacity(0.1), in: Capsule())
                        .foregroundStyle(PaletteMat.violet)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Sheet création / édition exercice musculation

struct EditerExerciceMusculationSheet: View {
    enum Mode { case creation, edition }

    let mode: Mode
    var nomInitial: String = ""
    var categorieInitiale: CategorieMuscu = .complet
    var notesInitiales: String = ""
    var onSauvegarder: (String, CategorieMuscu, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var nom: String = ""
    @State private var categorie: CategorieMuscu = .complet
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Informations") {
                    TextField("Nom de l'exercice", text: $nom)

                    Picker("Catégorie", selection: $categorie) {
                        ForEach(CategorieMuscu.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icone)
                                .tag(cat)
                        }
                    }
                }

                Section("Notes") {
                    TextField("Description, conseils, muscles ciblés…", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(mode == .creation ? "Nouvel exercice" : "Modifier l'exercice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode == .creation ? "Créer" : "OK") {
                        let nomTrimmed = nom.trimmingCharacters(in: .whitespaces)
                        guard !nomTrimmed.isEmpty else { return }
                        onSauvegarder(nomTrimmed, categorie, notes)
                        dismiss()
                    }
                    .disabled(nom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                nom = nomInitial
                categorie = categorieInitiale
                notes = notesInitiales
            }
        }
    }
}
