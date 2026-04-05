//  Playco
//  Copyright (c) 2025 Christopher Dionne. Tous droits reserves.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import os

struct BibliothequeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Query(sort: \ExerciceBibliotheque.nom) private var tousExercicesBD: [ExerciceBibliotheque]
    @Query(sort: \CategorieExercice.nom) private var toutesCategoriesPerso: [CategorieExercice]

    @State private var recherche = ""
    @State private var categorieSelectionnee: String? = nil
    @State private var filtrerFavoris = false
    @State private var afficherAjout = false
    @State private var exerciceAModifier: ExerciceBibliotheque?
    @State private var confirmerSuppression: ExerciceBibliotheque?
    @State private var exercicePourSeance: ExerciceBibliotheque?
    @State private var afficherExport = false
    @State private var afficherImport = false
    @State private var selectionExport: Set<UUID> = []
    @State private var modeSelection = false
    @State private var exercicesImportes: [ExerciceExportItem] = []
    @State private var afficherPreviewImport = false
    @State private var afficherNouvelleCategorie = false

    private let logger = Logger(subsystem: "com.origotech.playco", category: "Bibliotheque")
    @Query(filter: #Predicate<Seance> { $0.estArchivee == false },
           sort: \Seance.date, order: .reverse) private var seances: [Seance]

    /// Si non-nil, on est en mode "import" et on appelle ce callback
    var onImporter: ((ExerciceBibliotheque) -> Void)? = nil

    /// Exercices filtrés par coach connecté
    private var tousExercices: [ExerciceBibliotheque] {
        let codeCoach = authService.utilisateurConnecte?.id.uuidString ?? ""
        return tousExercicesBD.filter { $0.codeCoach == codeCoach || $0.codeCoach.isEmpty }
    }

    /// Catégories personnalisées de l'équipe
    private var categoriesPerso: [CategorieExercice] {
        toutesCategoriesPerso.filtreEquipe(codeEquipeActif)
    }

    /// Toutes les catégories (prédéfinies + personnalisées)
    private var categories: [String] {
        let predefinies = CategorieBibliotheque.allCases.map(\.rawValue)
        let perso = categoriesPerso.map(\.nom)
        // Ajouter aussi les catégories orphelines (exercices avec catégorie inconnue)
        let toutes = Set(predefinies + perso)
        let orphelines = Set(tousExercices.map(\.categorie)).subtracting(toutes)
        return predefinies + perso.sorted() + orphelines.sorted()
    }

    private var exercicesFiltres: [ExerciceBibliotheque] {
        var result = tousExercices
        if filtrerFavoris {
            result = result.filter { $0.estFavori }
        }
        if let cat = categorieSelectionnee {
            result = result.filter { $0.categorie == cat }
        }
        if !recherche.isEmpty {
            result = result.filter {
                $0.nom.localizedCaseInsensitiveContains(recherche) ||
                $0.descriptionExo.localizedCaseInsensitiveContains(recherche) ||
                $0.categorie.localizedCaseInsensitiveContains(recherche)
            }
        }
        return result
    }

    private var exercicesParCategorie: [(String, [ExerciceBibliotheque])] {
        let grouped = Dictionary(grouping: exercicesFiltres, by: \.categorie)
        return categories.compactMap { cat in
            guard let exos = grouped[cat], !exos.isEmpty else { return nil }
            return (cat, exos.sorted { $0.nom < $1.nom })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            filtreCategories
                .padding(.top, 8)

            if exercicesFiltres.isEmpty {
                vueVide
            } else {
                listeExercices
            }
        }
        .navigationTitle("Bibliothèque")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $recherche, prompt: "Rechercher un exercice")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    if modeSelection {
                        Button {
                            exporterSelection()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.caption)
                                Text("Exporter (\(selectionExport.count))")
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundStyle(PaletteMat.bleu)
                        }
                        .disabled(selectionExport.isEmpty)

                        Button {
                            modeSelection = false
                            selectionExport.removeAll()
                        } label: {
                            Text("Annuler")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Menu {
                            Button {
                                afficherNouvelleCategorie = true
                            } label: {
                                Label("Nouvelle catégorie", systemImage: "plus.rectangle.on.folder")
                            }

                            Divider()

                            Button {
                                modeSelection = true
                            } label: {
                                Label("Exporter des exercices", systemImage: "square.and.arrow.up")
                            }
                            Button {
                                afficherImport = true
                            } label: {
                                Label("Importer (.playco)", systemImage: "square.and.arrow.down")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                        }

                        Button { afficherAjout = true } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $afficherAjout) {
            EditerExerciceBibliothequeView(
                categoriesPerso: categoriesPerso,
                onSave: { nom, cat, desc in
                    let e = ExerciceBibliotheque(nom: nom, categorie: cat, descriptionExo: desc, notes: desc)
                    e.codeCoach = authService.utilisateurConnecte?.id.uuidString ?? ""
                    modelContext.insert(e)
                }
            )
        }
        .sheet(item: $exerciceAModifier) { exo in
            EditerExerciceBibliothequeView(
                nomInitial: exo.nom,
                categorieInitiale: exo.categorie,
                descriptionInitiale: exo.descriptionExo,
                categoriesPerso: categoriesPerso,
                onSave: { nom, cat, desc in
                    exo.nom = nom
                    exo.categorie = cat
                    exo.descriptionExo = desc
                }
            )
        }
        .sheet(isPresented: $afficherNouvelleCategorie) {
            NouvelleCategorieExerciceView(codeEquipe: codeEquipeActif)
        }
        .confirmationDialog(
            "Supprimer cet exercice de la bibliothèque ?",
            isPresented: Binding(
                get: { confirmerSuppression != nil },
                set: { if !$0 { confirmerSuppression = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                if let exo = confirmerSuppression { modelContext.delete(exo) }
                confirmerSuppression = nil
            }
            Button("Annuler", role: .cancel) { confirmerSuppression = nil }
        } message: {
            Text("Cette action est irréversible.")
        }
        .fileExporter(
            isPresented: $afficherExport,
            document: PlaycoDocument(exercices: exercicesSelectionnesPourExport()),
            contentType: .playcoExercices,
            defaultFilename: "exercices-playco"
        ) { result in
            switch result {
            case .success(let url):
                logger.info("Export réussi : \(url.lastPathComponent)")
            case .failure(let error):
                logger.error("Erreur export : \(error.localizedDescription)")
            }
            modeSelection = false
            selectionExport.removeAll()
        }
        .fileImporter(
            isPresented: $afficherImport,
            allowedContentTypes: [.playcoExercices, .json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importerFichier(url: url)
            case .failure(let error):
                logger.error("Erreur import : \(error.localizedDescription)")
            }
        }
        .sheet(isPresented: $afficherPreviewImport) {
            PreviewImportView(exercices: exercicesImportes) { selection in
                let codeCoach = authService.utilisateurConnecte?.id.uuidString ?? ""
                for item in selection {
                    let exo = item.versExerciceBibliotheque(codeCoach: codeCoach)
                    modelContext.insert(exo)
                }
                logger.info("\(selection.count) exercice(s) importé(s)")
                exercicesImportes = []
            }
        }
    }

    // MARK: - Filtre catégories
    private var filtreCategories: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Favoris
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { filtrerFavoris.toggle() }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: filtrerFavoris ? "star.fill" : "star")
                            .font(.caption2.weight(.semibold))
                        Text("Favoris")
                            .font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(filtrerFavoris ? Color.yellow : Color(.tertiarySystemFill), in: Capsule())
                    .foregroundStyle(filtrerFavoris ? .black : .primary)
                }

                boutonCategorie(nil, "Tout", "square.grid.2x2.fill", "#8E8E93")

                // Catégories prédéfinies
                ForEach(CategorieBibliotheque.allCases, id: \.self) { cat in
                    boutonCategorie(cat.rawValue, cat.rawValue, cat.icone, cat.couleur)
                }

                // Catégories personnalisées
                ForEach(categoriesPerso) { cat in
                    boutonCategorie(cat.nom, cat.nom, cat.icone, cat.couleurHex)
                }

                // Bouton ajouter catégorie
                Button {
                    afficherNouvelleCategorie = true
                } label: {
                    Image(systemName: "plus")
                        .font(.caption2.weight(.bold))
                        .padding(8)
                        .background(Color(.tertiarySystemFill), in: Circle())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private func boutonCategorie(_ valeur: String?, _ label: String, _ icone: String, _ couleurHex: String) -> some View {
        let estActif = categorieSelectionnee == valeur
        let couleur = Color(hex: couleurHex)
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                categorieSelectionnee = valeur
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icone)
                    .font(.caption2.weight(.semibold))
                Text(label)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(estActif ? couleur : Color(.tertiarySystemFill),
                        in: Capsule(style: .continuous))
            .foregroundStyle(estActif ? .white : .primary)
        }
    }

    // MARK: - Liste
    private var listeExercices: some View {
        List {
            ForEach(exercicesParCategorie, id: \.0) { categorie, exercices in
                Section {
                    ForEach(exercices) { exo in
                        boutonExercice(exo)
                    }
                } header: {
                    headerCategorie(categorie, count: exercices.count)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func boutonExercice(_ exo: ExerciceBibliotheque) -> some View {
        let row = ligneExercice(exo)

        if modeSelection {
            Button {
                if selectionExport.contains(exo.id) {
                    selectionExport.remove(exo.id)
                } else {
                    selectionExport.insert(exo.id)
                }
            } label: {
                HStack {
                    Image(systemName: selectionExport.contains(exo.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectionExport.contains(exo.id) ? PaletteMat.bleu : .secondary)
                        .font(.title3)
                    row
                }
            }
            .buttonStyle(.plain)
        } else if onImporter != nil {
            Button {
                onImporter?(exo)
                dismiss()
            } label: { row }
            .buttonStyle(.plain)
        } else {
            NavigationLink(destination: BibliothequeDetailView(exercice: exo)) {
                row
            }
        }
    }

    private func ligneExercice(_ exo: ExerciceBibliotheque) -> some View {
        let infos = CategorieHelper.infos(pour: exo.categorie, personnalisees: categoriesPerso)
        return HStack(spacing: 12) {
            if exo.elementsData != nil {
                TerrainMiniatureView(elementsData: exo.elementsData, taille: 50,
                                     typeTerrain: TypeTerrain(rawValue: exo.typeTerrain) ?? .indoor)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(hex: infos.couleur).opacity(0.08))
                        .frame(width: 50, height: 25)
                    Image(systemName: infos.icone)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(hex: infos.couleur))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(exo.nom)
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if exo.estFavori {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                    if exo.estPredefini {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange.opacity(0.6))
                    }
                }
                if !exo.descriptionExo.isEmpty {
                    Text(exo.descriptionExo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if onImporter != nil {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.orange)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button {
                exo.estFavori.toggle()
            } label: {
                Label(exo.estFavori ? "Retirer des favoris" : "Favori",
                      systemImage: exo.estFavori ? "star.slash" : "star.fill")
            }

            // Changer de catégorie directement depuis le menu contextuel
            menuCategories(pour: exo)

            Button {
                exerciceAModifier = exo
            } label: { Label("Modifier infos", systemImage: "pencil") }

            if !seances.isEmpty && onImporter == nil {
                Divider()
                Menu {
                    ForEach(seances) { seance in
                        Button {
                            ajouterASeance(exo: exo, seance: seance)
                        } label: {
                            Label(seance.nom, systemImage: "calendar")
                        }
                    }
                } label: {
                    Label("Ajouter à une séance", systemImage: "arrow.right.doc.on.clipboard")
                }
            }

            if !exo.estPredefini {
                Divider()
                Button(role: .destructive) {
                    confirmerSuppression = exo
                } label: { Label("Supprimer", systemImage: "trash") }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !exo.estPredefini {
                Button(role: .destructive) {
                    confirmerSuppression = exo
                } label: { Label("Supprimer", systemImage: "trash") }
            }
            Button {
                exerciceAModifier = exo
            } label: { Label("Modifier", systemImage: "pencil") }
            .tint(.blue)
        }
    }

    /// Menu pour changer la catégorie d'un exercice
    @ViewBuilder
    private func menuCategories(pour exo: ExerciceBibliotheque) -> some View {
        Menu {
            ForEach(CategorieBibliotheque.allCases, id: \.self) { cat in
                Button {
                    exo.categorie = cat.rawValue
                } label: {
                    if exo.categorie == cat.rawValue {
                        Label(cat.rawValue, systemImage: "checkmark")
                    } else {
                        Label(cat.rawValue, systemImage: cat.icone)
                    }
                }
            }
            if !categoriesPerso.isEmpty {
                Divider()
                ForEach(categoriesPerso) { cat in
                    Button {
                        exo.categorie = cat.nom
                    } label: {
                        if exo.categorie == cat.nom {
                            Label(cat.nom, systemImage: "checkmark")
                        } else {
                            Label(cat.nom, systemImage: cat.icone)
                        }
                    }
                }
            }
        } label: {
            Label("Catégorie : \(exo.categorie)", systemImage: "tag")
        }
    }

    private func headerCategorie(_ categorie: String, count: Int) -> some View {
        let infos = CategorieHelper.infos(pour: categorie, personnalisees: categoriesPerso)
        return HStack {
            Image(systemName: infos.icone)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color(hex: infos.couleur))
            Text(categorie)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(nil)
            Spacer()
            Text("\(count)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Ajouter à une séance
    private func ajouterASeance(exo: ExerciceBibliotheque, seance: Seance) {
        let exercice = Exercice(nom: exo.nom, notes: exo.descriptionExo,
                                 ordre: (seance.exercices ?? []).count, duree: exo.duree)
        exercice.seance = seance
        exercice.dessinData = exo.dessinData
        exercice.elementsData = exo.elementsData
        exercice.etapesData = exo.etapesData
        exercice.typeTerrain = exo.typeTerrain
        modelContext.insert(exercice)
        if seance.exercices == nil { seance.exercices = [] }
        seance.exercices?.append(exercice)
    }

    // MARK: - Export / Import

    private func exercicesSelectionnesPourExport() -> [ExerciceExportItem] {
        tousExercices
            .filter { selectionExport.contains($0.id) }
            .map { ExerciceExportItem(from: $0) }
    }

    private func exporterSelection() {
        guard !selectionExport.isEmpty else { return }
        afficherExport = true
    }

    private func importerFichier(url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let data = try Data(contentsOf: url)
            let bundle = try JSONCoderCache.decoder.decode(PlaycoExportBundle.self, from: data)
            exercicesImportes = bundle.exercices
            afficherPreviewImport = true
        } catch {
            logger.error("Erreur décodage import : \(error.localizedDescription)")
        }
    }

    // MARK: - Vue vide
    private var vueVide: some View {
        Group {
            if recherche.isEmpty {
                ContentUnavailableView {
                    Label("Bibliothèque vide", systemImage: "books.vertical")
                } description: {
                    Text("Les exercices prédéfinis apparaîtront ici")
                } actions: {
                    Button("Nouvel exercice", systemImage: "plus") {
                        afficherAjout = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PaletteMat.orange)
                }
            } else {
                ContentUnavailableView.search(text: recherche)
            }
        }
    }
}

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
