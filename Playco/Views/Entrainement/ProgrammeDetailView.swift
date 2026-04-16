//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Détail d'un programme — liste des exercices, configuration séries/reps/poids/repos, lancement
struct ProgrammeDetailView: View {
    @Bindable var programme: ProgrammeMuscu
    var onDemarrer: (ProgrammeMuscu) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Query(filter: #Predicate<JoueurEquipe> { $0.estActif == true },
           sort: \JoueurEquipe.nom) private var joueursActifs: [JoueurEquipe]
    @State private var exercices: [ExerciceProgramme] = []
    @State private var afficherAjout = false
    @State private var exerciceEdite: ExerciceProgramme?
    @State private var afficherAssignation = false
    @State private var joueursAssignes: [UUID] = []

    var body: some View {
        VStack(spacing: 0) {
            if exercices.isEmpty {
                etatVide
            } else {
                listeExercices
            }

            Divider()

            // Barre du bas
            HStack(spacing: 16) {
                Button { afficherAjout = true } label: {
                    Label("Ajouter", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(PaletteMat.violet)
                }

                Button { onDemarrer(programme) } label: {
                    Label("Démarrer", systemImage: "play.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(PaletteMat.violet, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                .disabled(exercices.isEmpty)
                .opacity(exercices.isEmpty ? 0.5 : 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGroupedBackground))
        }
        .navigationTitle(programme.nom)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if !joueursAssignes.isEmpty {
                    Text("\(joueursAssignes.count) joueur\(joueursAssignes.count > 1 ? "s" : "")")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PaletteMat.violet)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(PaletteMat.violet.opacity(0.1), in: Capsule())
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { afficherAjout = true } label: {
                        Label("Ajouter un exercice", systemImage: "plus")
                    }
                    if let role = authService.utilisateurConnecte?.role, role.peutGererProgrammes {
                        Button { afficherAssignation = true } label: {
                            Label("Assigner joueurs", systemImage: "person.3.fill")
                        }
                    }
                    Button(role: .destructive) {
                        exercices.removeAll()
                        sauvegarder()
                    } label: {
                        Label("Tout supprimer", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            exercices = programme.decoderExercices()
            joueursAssignes = programme.decoderJoueursAssignes()
        }
        .sheet(isPresented: $afficherAjout) {
            AjouterExerciceSheet(exercicesActuels: exercices) { nouveau in
                exercices.append(nouveau)
                sauvegarder()
            }
        }
        .sheet(item: $exerciceEdite) { exo in
            EditerExerciceSheet(exercice: exo) { modifie in
                if let idx = exercices.firstIndex(where: { $0.id == modifie.id }) {
                    exercices[idx] = modifie
                    sauvegarder()
                }
            }
        }
        .sheet(isPresented: $afficherAssignation) {
            AssignerJoueursSheet(joueursActifs: joueursActifs, selection: joueursAssignes) { ids in
                joueursAssignes = ids
                programme.encoderJoueursAssignes(ids)
                try? modelContext.save()
            }
        }
    }

    // MARK: - Liste exercices

    private var listeExercices: some View {
        List {
            ForEach(exercices) { exo in
                Button {
                    exerciceEdite = exo
                } label: {
                    carteExercice(exo)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        exercices.removeAll { $0.id == exo.id }
                        sauvegarder()
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                }
            }
            .onMove { from, to in
                exercices.move(fromOffsets: from, toOffset: to)
                recalculerOrdre()
                sauvegarder()
            }
        }
        .listStyle(.plain)
    }

    private func carteExercice(_ exo: ExerciceProgramme) -> some View {
        HStack(spacing: 14) {
            // Icône catégorie
            ZStack {
                Circle()
                    .fill(exo.categorie.couleur.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: exo.categorie.icone)
                    .font(.system(size: 16))
                    .foregroundStyle(exo.categorie.couleur)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(exo.exerciceNom)
                    .font(.subheadline.weight(.medium))

                HStack(spacing: 10) {
                    Label("\(exo.seriesCibles)×\(exo.repsCibles)", systemImage: "repeat")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if exo.poidsDefaut > 0 {
                        Label("\(Int(exo.poidsDefaut)) lbs", systemImage: "scalemass")
                            .font(.caption)
                            .foregroundStyle(PaletteMat.violet)
                    }

                    Label("\(exo.tempsRepos)s repos", systemImage: "timer")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }

    private var etatVide: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "dumbbell")
                .font(.system(size: 50))
                .foregroundStyle(.tertiary)
            Text("Aucun exercice")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button { afficherAjout = true } label: {
                Label("Ajouter un exercice", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(PaletteMat.violet.opacity(0.1), in: Capsule())
                    .foregroundStyle(PaletteMat.violet)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func sauvegarder() {
        programme.encoderExercices(exercices)
        try? modelContext.save()
    }

    private func recalculerOrdre() {
        for i in exercices.indices {
            exercices[i].ordre = i
        }
    }
}

// MARK: - Sheet ajouter exercice

struct AjouterExerciceSheet: View {
    let exercicesActuels: [ExerciceProgramme]
    var onAjouter: (ExerciceProgramme) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExerciceMuscu.nom) private var tousExercices: [ExerciceMuscu]
    @State private var recherche = ""
    @State private var categorieFiltree: CategorieMuscu?
    @State private var afficherCreation = false

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

    var body: some View {
        NavigationStack {
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

                List {
                    ForEach(exercicesFiltres) { exo in
                        Button {
                            ajouterExercice(exo)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: exo.categorie.icone)
                                    .font(.system(size: 16))
                                    .foregroundStyle(exo.categorie.couleur)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exo.nom)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    if !exo.notes.isEmpty {
                                        Text(exo.notes)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                // Déjà ajouté ?
                                if exercicesActuels.contains(where: { $0.exerciceID == exo.id }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Ajouter un exercice")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $recherche, prompt: "Rechercher")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { afficherCreation = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $afficherCreation) {
                EditerExerciceMusculationSheet(mode: .creation) { nom, categorie, notes in
                    let exo = ExerciceMuscu(nom: nom, categorie: categorie, notes: notes)
                    modelContext.insert(exo)
                    try? modelContext.save()
                }
            }
        }
    }

    private func boutonCategorie(_ cat: CategorieMuscu?, label: String) -> some View {
        Button {
            withAnimation(LiquidGlassKit.springDefaut) { categorieFiltree = cat }
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

    private func ajouterExercice(_ exo: ExerciceMuscu) {
        let nouveau = ExerciceProgramme(
            exerciceID: exo.id,
            exerciceNom: exo.nom,
            categorieRaw: exo.categorieRaw,
            ordre: exercicesActuels.count,
            seriesCibles: 3,
            repsCibles: 10,
            poidsDefaut: 0,
            tempsRepos: 90
        )
        onAjouter(nouveau)
        dismiss()
    }
}

// MARK: - Sheet éditer exercice

struct EditerExerciceSheet: View {
    @State var exercice: ExerciceProgramme
    var onSauvegarder: (ExerciceProgramme) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: exercice.categorie.icone)
                            .foregroundStyle(exercice.categorie.couleur)
                        Text(exercice.exerciceNom)
                            .font(.headline)
                    }
                }

                Section("Séries & Répétitions") {
                    Stepper("Séries : \(exercice.seriesCibles)", value: $exercice.seriesCibles, in: 1...10)
                    Stepper("Reps : \(exercice.repsCibles)", value: $exercice.repsCibles, in: 1...50)
                }

                Section("Charge") {
                    HStack {
                        Text("Poids par défaut")
                        Spacer()
                        TextField("0", value: $exercice.poidsDefaut, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("lbs")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Repos") {
                    Stepper("Repos : \(exercice.tempsRepos)s", value: $exercice.tempsRepos, in: 15...300, step: 15)

                    // Raccourcis repos
                    HStack(spacing: 8) {
                        ForEach([30, 60, 90, 120, 180], id: \.self) { sec in
                            Button {
                                exercice.tempsRepos = sec
                            } label: {
                                Text("\(sec)s")
                                    .font(.caption.weight(exercice.tempsRepos == sec ? .bold : .regular))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        exercice.tempsRepos == sec
                                            ? AnyShapeStyle(PaletteMat.violet)
                                            : AnyShapeStyle(Color.primary.opacity(0.06)),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(exercice.tempsRepos == sec ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Configurer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        onSauvegarder(exercice)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Sheet assigner joueurs à un programme

struct AssignerJoueursSheet: View {
    let joueursActifs: [JoueurEquipe]
    let selection: [UUID]
    var onSauvegarder: ([UUID]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectionLocale: Set<UUID> = []

    /// Joueurs groupés par poste
    private var joueursParPoste: [(PosteJoueur, [JoueurEquipe])] {
        let grouped = Dictionary(grouping: joueursActifs) { $0.poste }
        return PosteJoueur.allCases.compactMap { poste in
            guard let joueurs = grouped[poste], !joueurs.isEmpty else { return nil }
            return (poste, joueurs)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Résumé
                HStack {
                    Text("\(selectionLocale.count) joueur\(selectionLocale.count > 1 ? "s" : "") sélectionné\(selectionLocale.count > 1 ? "s" : "")")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(PaletteMat.violet)
                    Spacer()
                    Button {
                        if selectionLocale.count == joueursActifs.count {
                            selectionLocale.removeAll()
                        } else {
                            selectionLocale = Set(joueursActifs.map(\.id))
                        }
                    } label: {
                        Text(selectionLocale.count == joueursActifs.count ? "Tout désélectionner" : "Tout sélectionner")
                            .font(.caption.weight(.medium))
                    }
                }
                .padding(16)
                .background(Color(.systemGroupedBackground))

                Divider()

                List {
                    ForEach(joueursParPoste, id: \.0) { poste, joueurs in
                        Section {
                            ForEach(joueurs) { joueur in
                                Button {
                                    if selectionLocale.contains(joueur.id) {
                                        selectionLocale.remove(joueur.id)
                                    } else {
                                        selectionLocale.insert(joueur.id)
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(joueur.poste.couleur.opacity(0.15))
                                                .frame(width: 36, height: 36)
                                            Text(joueur.poste.abreviation)
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(joueur.poste.couleur)
                                        }

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(joueur.nomComplet)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(.primary)
                                            Text("#\(joueur.numero)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: selectionLocale.contains(joueur.id) ? "checkmark.circle.fill" : "circle")
                                            .font(.title3)
                                            .foregroundStyle(selectionLocale.contains(joueur.id) ? PaletteMat.violet : .secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Image(systemName: poste.icone)
                                    .foregroundStyle(poste.couleur)
                                Text(poste.rawValue)
                            }
                            .font(.subheadline.weight(.bold))
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Assigner joueurs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        onSauvegarder(Array(selectionLocale))
                        dismiss()
                    }
                }
            }
            .onAppear {
                selectionLocale = Set(selection)
            }
        }
    }
}
