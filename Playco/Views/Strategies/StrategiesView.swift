//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Section Stratégies — base de données de systèmes collectifs
struct StrategiesView: View {
    var retour: () -> Void

    @Environment(\.modelContext) private var contexte
    @Environment(AuthService.self) private var authService
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Query(filter: #Predicate<StrategieCollective> { $0.estArchivee == false },
           sort: \StrategieCollective.dateModification, order: .reverse)
    private var strategies: [StrategieCollective]

    @State private var strategieSelectionnee: StrategieCollective?
    @State private var afficherCreation = false
    @State private var afficherFormations = false
    @State private var afficherRapports = false
    @State private var recherche = ""
    @State private var categorieFiltre: CategorieStrategie?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private var strategiesFiltrees: [StrategieCollective] {
        var liste = strategies.filtreEquipe(codeEquipeActif)
        if let cat = categorieFiltre {
            liste = liste.filter { $0.categorieRaw == cat.rawValue }
        }
        if !recherche.isEmpty {
            liste = liste.filter {
                $0.nom.localizedCaseInsensitiveContains(recherche) ||
                $0.descriptionStrategie.localizedCaseInsensitiveContains(recherche)
            }
        }
        return liste
    }

    private var parCategorie: [(CategorieStrategie, [StrategieCollective])] {
        let groupes = Dictionary(grouping: strategiesFiltrees) { s in
            CategorieStrategie(rawValue: s.categorieRaw) ?? .attaque
        }
        return CategorieStrategie.allCases.compactMap { cat in
            guard let items = groupes[cat], !items.isEmpty else { return nil }
            return (cat, items)
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 380, ideal: 480, max: 580)
        } detail: {
            NavigationStack {
                if let strategie = strategieSelectionnee {
                    StrategieDetailView(strategie: strategie)
                } else {
                    etatVide
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(PaletteMat.bleu)
        .sheet(isPresented: $afficherCreation) {
            NouvelleStrategieView { nouvelle in
                nouvelle.codeEquipe = codeEquipeActif
                contexte.insert(nouvelle)
                strategieSelectionnee = nouvelle
            }
        }
        .sensoryFeedback(.success, trigger: strategies.count)
        .sheet(isPresented: $afficherFormations) {
            NavigationStack {
                FormationsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Fermer") { afficherFormations = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $afficherRapports) {
            NavigationStack {
                ScoutingReportListView()
            }
        }
    }

    // MARK: - Sidebar
    private var sidebar: some View {
        List(selection: $strategieSelectionnee) {
            // Section Rapports (Scouting)
            Section {
                Button {
                    afficherRapports = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.body)
                            .foregroundStyle(.red)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rapports")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Text("Analyse des adversaires")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            } header: {
                Label("Scouting", systemImage: "binoculars.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }

            // Filtre par catégorie
            filtreCategories

            // Liste groupée
            ForEach(parCategorie, id: \.0) { cat, items in
                Section {
                    ForEach(items) { strategie in
                        NavigationLink(value: strategie) {
                            strategieRow(strategie)
                        }
                    }
                    .onDelete(perform: (authService.utilisateurConnecte?.role.peutModifierStrategies ?? false) ? { indices in
                        let toDelete = indices.compactMap { i in
                            i < items.count ? items[i] : nil
                        }
                        for s in toDelete {
                            if strategieSelectionnee?.id == s.id { strategieSelectionnee = nil }
                            s.estArchivee = true
                        }
                    } : nil)
                } header: {
                    Label(cat.rawValue, systemImage: cat.icone)
                        .foregroundStyle(cat.couleur)
                        .font(.caption.weight(.semibold))
                }
            }
        }
        .searchable(text: $recherche, prompt: "Rechercher une stratégie")
        .navigationTitle("Stratégies")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                boutonRetour
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    afficherCreation = true
                } label: {
                    Image(systemName: "plus")
                }
                .siAutorise(authService.utilisateurConnecte?.role.peutModifierStrategies ?? false)
                .bloqueSiNonPayant(source: "strategies_create")
            }
            // Rapports accessible via sidebar
            ToolbarItem(placement: .primaryAction) {
                Button {
                    afficherFormations = true
                } label: {
                    Image(systemName: "person.3.fill")
                }
                .help("Mes formations")
                .siAutorise(authService.utilisateurConnecte?.role.peutModifierStrategies ?? false)
            }
        }
    }

    // MARK: - Filtre catégories (menu déroulant)
    private var filtreCategories: some View {
        Section {
            Menu {
                Button {
                    withAnimation { categorieFiltre = nil }
                } label: {
                    Label("Toutes les catégories", systemImage: "square.grid.2x2")
                }

                Divider()

                ForEach(CategorieStrategie.allCases, id: \.self) { cat in
                    Button {
                        withAnimation { categorieFiltre = cat }
                    } label: {
                        HStack {
                            Label(cat.rawValue, systemImage: cat.icone)
                            if categorieFiltre == cat {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    if let cat = categorieFiltre {
                        Image(systemName: cat.icone)
                            .foregroundStyle(cat.couleur)
                        Text(cat.rawValue)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(cat.couleur)
                    } else {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundStyle(.secondary)
                        Text("Toutes les catégories")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Ligne stratégie
    private func strategieRow(_ s: StrategieCollective) -> some View {
        HStack(spacing: 12) {
            // Miniature terrain
            TerrainMiniatureView(
                elementsData: s.elementsData,
                typeTerrain: TypeTerrain(rawValue: s.typeTerrain) ?? .indoor
            )
            .frame(width: 60, height: 30)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text(s.nom)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                if !s.descriptionStrategie.isEmpty {
                    Text(s.descriptionStrategie)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Badge catégorie
            let cat = s.categorie
            Image(systemName: cat.icone)
                .font(.caption2)
                .foregroundStyle(cat.couleur)
        }
    }

    // MARK: - État vide
    private var etatVide: some View {
        ContentUnavailableView {
            Label("Sélectionnez une stratégie", systemImage: "sportscourt.fill")
        } description: {
            Text("ou créez-en une nouvelle avec +")
        } actions: {
            Button("Nouvelle stratégie", systemImage: "plus") {
                afficherCreation = true
            }
            .buttonStyle(.borderedProminent)
            .tint(PaletteMat.bleu)
        }
    }

    // MARK: - Bouton retour
    private var boutonRetour: some View {
        Button {
            retour()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                Image(systemName: "volleyball.fill")
                    .font(.system(size: 14))
                Text("Accueil")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(PaletteMat.bleu)
        }
    }
}

// MARK: - Sheet création
struct NouvelleStrategieView: View {
    var onCreate: (StrategieCollective) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var nom = ""
    @State private var categorie: CategorieStrategie = .attaque
    @State private var description_ = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Informations") {
                    TextField("Nom de la stratégie", text: $nom)
                    Picker("Catégorie", selection: $categorie) {
                        ForEach(CategorieStrategie.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icone).tag(cat)
                        }
                    }
                    TextField("Description (optionnel)", text: $description_, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Nouvelle stratégie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") {
                        let s = StrategieCollective(nom: nom, categorie: categorie,
                                                     descriptionStrategie: description_)
                        onCreate(s)
                        dismiss()
                    }
                    .disabled(nom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
