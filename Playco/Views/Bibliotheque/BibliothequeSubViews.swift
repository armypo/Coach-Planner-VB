//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Formulaire ajout / modification exercice
struct EditerExerciceBibliothequeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var nom: String
    @State private var categorie: String
    @State private var descriptionExo: String
    @FocusState private var nomFocused: Bool

    let categoriesPerso: [CategorieExercice]
    let onSave: (String, String, String) -> Void

    init(nomInitial: String = "", categorieInitiale: String = CategorieBibliotheque.attaque.rawValue,
         descriptionInitiale: String = "", categoriesPerso: [CategorieExercice] = [],
         onSave: @escaping (String, String, String) -> Void) {
        _nom = State(initialValue: nomInitial)
        _categorie = State(initialValue: categorieInitiale)
        _descriptionExo = State(initialValue: descriptionInitiale)
        self.categoriesPerso = categoriesPerso
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Informations") {
                    TextField("Nom de l'exercice", text: $nom)
                        .focused($nomFocused)

                    Picker("Catégorie", selection: $categorie) {
                        ForEach(CategorieBibliotheque.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icone)
                                .tag(cat.rawValue)
                        }
                        if !categoriesPerso.isEmpty {
                            Section("Personnalisées") {
                                ForEach(categoriesPerso) { cat in
                                    Label(cat.nom, systemImage: cat.icone)
                                        .tag(cat.nom)
                                }
                            }
                        }
                    }
                }

                Section("Description") {
                    TextEditor(text: $descriptionExo)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle(nom.isEmpty ? "Nouvel exercice" : "Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        let n = nom.trimmingCharacters(in: .whitespaces)
                        guard !n.isEmpty else { return }
                        onSave(n, categorie, descriptionExo)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(nom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear { nomFocused = true }
    }
}

// MARK: - Formulaire nouvelle catégorie personnalisée

struct NouvelleCategorieExerciceView: View {
    let codeEquipe: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var nom = ""
    @State private var iconeSelectionnee = "folder.fill"
    @State private var couleurSelectionnee = "#FF9500"
    @FocusState private var nomFocused: Bool

    private let iconesDisponibles = [
        "folder.fill", "tag.fill", "star.fill", "heart.fill",
        "flame.fill", "bolt.fill", "shield.fill", "flag.fill",
        "target", "trophy.fill", "figure.run", "figure.volleyball",
        "person.3.fill", "hand.raised.fill", "arrow.up.forward",
        "figure.flexibility", "sportscourt.fill", "timer",
        "chart.bar.fill", "brain.head.profile"
    ]

    private let couleursDisponibles = [
        "#DC2626", "#FF6B35", "#FF9500", "#D97706",
        "#059669", "#10B981", "#2563EB", "#4A8AF4",
        "#7C3AED", "#9B7AE8", "#EC4899", "#6366F1"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Nom de la catégorie") {
                    TextField("Ex: Transition, Jeu rapide…", text: $nom)
                        .focused($nomFocused)
                }

                Section("Icône") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                        ForEach(iconesDisponibles, id: \.self) { icone in
                            Button {
                                iconeSelectionnee = icone
                            } label: {
                                Image(systemName: icone)
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        iconeSelectionnee == icone
                                            ? Color(hex: couleurSelectionnee).opacity(0.15)
                                            : Color(.tertiarySystemFill),
                                        in: RoundedRectangle(cornerRadius: 10)
                                    )
                                    .foregroundStyle(
                                        iconeSelectionnee == icone
                                            ? Color(hex: couleurSelectionnee)
                                            : .secondary
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(
                                                iconeSelectionnee == icone
                                                    ? Color(hex: couleurSelectionnee)
                                                    : .clear,
                                                lineWidth: 2
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Couleur") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(couleursDisponibles, id: \.self) { hex in
                            Button {
                                couleurSelectionnee = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle().strokeBorder(.white, lineWidth: couleurSelectionnee == hex ? 3 : 0)
                                    )
                                    .overlay(
                                        couleurSelectionnee == hex
                                            ? Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white)
                                            : nil
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Aperçu
                Section("Aperçu") {
                    HStack(spacing: 10) {
                        Image(systemName: iconeSelectionnee)
                            .font(.title3)
                            .foregroundStyle(Color(hex: couleurSelectionnee))
                            .frame(width: 36, height: 36)
                            .background(Color(hex: couleurSelectionnee).opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                        Text(nom.isEmpty ? "Nom de la catégorie" : nom)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(nom.isEmpty ? .tertiary : .primary)
                    }
                }
            }
            .navigationTitle("Nouvelle catégorie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") {
                        let cat = CategorieExercice(
                            nom: nom.trimmingCharacters(in: .whitespaces),
                            icone: iconeSelectionnee,
                            couleurHex: couleurSelectionnee
                        )
                        cat.codeEquipe = codeEquipe
                        modelContext.insert(cat)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(nom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear { nomFocused = true }
    }
}

// MARK: - FileDocument pour export .playco

struct PlaycoDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.playcoExercices] }
    static var writableContentTypes: [UTType] { [.playcoExercices] }

    let data: Data

    @MainActor
    init(exercices: [ExerciceExportItem]) {
        let bundle = PlaycoExportBundle(exercices: exercices)
        self.data = (try? JSONCoderCache.encoder.encode(bundle)) ?? Data()
    }

    init(configuration: ReadConfiguration) throws {
        guard let fileData = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = fileData
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Preview import

struct PreviewImportView: View {
    @Environment(\.dismiss) private var dismiss
    let exercices: [ExerciceExportItem]
    let onConfirmer: ([ExerciceExportItem]) -> Void

    @State private var selection: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List(exercices) { exo in
                Button {
                    if selection.contains(exo.id) {
                        selection.remove(exo.id)
                    } else {
                        selection.insert(exo.id)
                    }
                } label: {
                    HStack {
                        Image(systemName: selection.contains(exo.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selection.contains(exo.id) ? PaletteMat.vert : .secondary)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(exo.nom)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                            if !exo.categorie.isEmpty {
                                Text(exo.categorie)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if exo.duree > 0 {
                            Text("\(exo.duree) min")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Importer (\(exercices.count) exercices)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if selection.isEmpty {
                            selection = Set(exercices.map(\.id))
                        }
                    } label: {
                        Text(selection.count == exercices.count ? "Tout désélectionner" : "Tout sélectionner")
                            .font(.caption)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Importer (\(selection.count))") {
                        let items = exercices.filter { selection.contains($0.id) }
                        onConfirmer(items)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selection.isEmpty)
                }
            }
            .onAppear {
                selection = Set(exercices.map(\.id))
            }
        }
    }
}
