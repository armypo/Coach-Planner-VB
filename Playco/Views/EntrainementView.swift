//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Section Entraînement — programmes de musculation, suivi des charges, historique
struct EntrainementView: View {
    var onRetour: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selectionSidebar: SelectionEntrainement?
    @State private var afficherNouveauProgramme = false
    @State private var nomNouveauProgramme = ""
    @State private var afficherBibliotheque = false
    @State private var afficherHistorique = false

    @Query(filter: #Predicate<ProgrammeMuscu> { $0.estArchive == false },
           sort: \ProgrammeMuscu.dateCreation, order: .reverse) private var programmes: [ProgrammeMuscu]
    @Query(sort: \SeanceMuscu.date, order: .reverse) private var seances: [SeanceMuscu]
    @Query private var tousJoueurs: [JoueurEquipe]

    /// D2 (pivot coach-first) : le coach saisit la séance live AU NOM d'un
    /// joueur — choisi juste avant de lancer (alimente SuiviMusculationView).
    private enum ChoixJoueurLive: Hashable {
        case joueur(UUID)
        case sansJoueur
        var joueurID: UUID? {
            if case .joueur(let id) = self { return id }
            return nil
        }
    }
    @State private var choixJoueurLive: ChoixJoueurLive?

    enum SelectionEntrainement: Hashable {
        case programme(ProgrammeMuscu)
        case seanceLive(ProgrammeMuscu)
    }

    private var role: RoleUtilisateur {
        authService.utilisateurConnecte?.role ?? .etudiant
    }

    /// Données filtrées cachées
    @State private var programmesFiltres: [ProgrammeMuscu] = []
    @State private var seancesEquipe: [SeanceMuscu] = []

    private func recalculerDonnees() {
        programmesFiltres = programmes.filtreEquipe(codeEquipeActif)
        seancesEquipe = seances.filtreEquipe(codeEquipeActif)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 380, ideal: 480, max: 580)
                .navigationTitle("Entraînement")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        boutonRetour
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button { afficherNouveauProgramme = true } label: {
                            Image(systemName: "plus")
                        }
                        .siAutorise(role.peutGererProgrammes)
                    }
                    ToolbarItem(placement: .bottomBar) {
                        HStack(spacing: 24) {
                            Button {
                                afficherHistorique = true
                            } label: {
                                Label("Historique", systemImage: "clock.arrow.circlepath")
                                    .font(.subheadline.weight(.medium))
                            }

                            Button {
                                afficherBibliotheque = true
                            } label: {
                                Label("Bibliothèque", systemImage: "books.vertical.fill")
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                    }
                }
        } detail: {
            NavigationStack {
                detailContent
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(PaletteMat.violet)
        .onAppear { recalculerDonnees() }
        .onChange(of: programmes) { recalculerDonnees() }
        .onChange(of: seances) { recalculerDonnees() }
        .onChange(of: codeEquipeActif) { recalculerDonnees() }
        .onChange(of: selectionSidebar) { choixJoueurLive = nil }
        .sensoryFeedback(.success, trigger: programmesFiltres.count)
        .alert("Nouveau programme", isPresented: $afficherNouveauProgramme) {
            TextField("Nom du programme", text: $nomNouveauProgramme)
            Button("Annuler", role: .cancel) { nomNouveauProgramme = "" }
            Button("Créer") { creerProgramme() }
        } message: {
            Text("Entrez un nom pour votre programme d'entraînement.")
        }
        .sheet(isPresented: $afficherBibliotheque) {
            NavigationStack {
                BibliothequeMusculationView()
            }
        }
        .sheet(isPresented: $afficherHistorique) {
            NavigationStack {
                HistoriqueView(seances: seancesEquipe)
            }
        }
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        List(selection: $selectionSidebar) {
            // Section programmes
            Section {
                ForEach(programmesFiltres) { prog in
                    NavigationLink(value: SelectionEntrainement.programme(prog)) {
                        ligneProgramme(prog)
                    }
                    .swipeActions(edge: .trailing) {
                        if role.peutGererProgrammes {
                            Button(role: .destructive) {
                                prog.estArchive = true
                                try? modelContext.save()
                            } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                        }
                    }
                }

                if programmesFiltres.isEmpty {
                    ContentUnavailableView {
                        Label("Aucun programme", systemImage: "dumbbell")
                    } description: {
                        Text("Appuyez sur + pour créer un programme")
                    } actions: {
                        if role.peutGererProgrammes {
                            Button("Nouveau programme", systemImage: "plus") {
                                afficherNouveauProgramme = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(PaletteMat.violet)
                        }
                    }
                }
            } header: {
                Label("Programmes", systemImage: "dumbbell.fill")
                    .font(.subheadline.weight(.bold))
            }

        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Ligne programme

    private func ligneProgramme(_ prog: ProgrammeMuscu) -> some View {
        let exercices = prog.decoderExercices()
        return VStack(alignment: .leading, spacing: 4) {
            Text(prog.nom)
                .font(.subheadline.weight(.medium))

            HStack(spacing: 8) {
                Label("\(exercices.count) ex.", systemImage: "list.bullet")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                // Catégories uniques
                let cats = Set(exercices.map(\.categorieRaw))
                ForEach(Array(cats.prefix(3)), id: \.self) { catRaw in
                    if let cat = CategorieMuscu(rawValue: catRaw) {
                        Image(systemName: cat.icone)
                            .font(.caption2)
                            .foregroundStyle(cat.couleur)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailContent: some View {
        if let selection = selectionSidebar {
            switch selection {
            case .programme(let prog):
                ProgrammeDetailView(programme: prog) { prog in
                    selectionSidebar = .seanceLive(prog)
                }
            case .seanceLive(let prog):
                if let choix = choixJoueurLive {
                    SeanceLiveView(programme: prog, joueurID: choix.joueurID) {
                        choixJoueurLive = nil
                        selectionSidebar = .programme(prog)
                    }
                } else {
                    selecteurJoueurLive(prog)
                }
            }
        } else {
            etatVide
        }
    }

    private var etatVide: some View {
        ContentUnavailableView {
            Label("Sélectionnez un programme", systemImage: "dumbbell")
        } description: {
            Text("ou créez-en un nouveau avec +")
        }
    }

    // MARK: - Sélecteur de joueur (D2 — le coach saisit au nom d'un athlète)

    /// Joueurs assignés au programme, puis le reste du roster actif.
    /// Un joueur indisponible (2.2.b) est proposé mais désactivé.
    private func selecteurJoueurLive(_ programme: ProgrammeMuscu) -> some View {
        let actifs = tousJoueurs.filtreEquipe(codeEquipeActif)
            .filter { $0.estActif }
            .sorted { $0.numero < $1.numero }
        let assignesIDs = Set(programme.decoderJoueursAssignes())
        let assignes = actifs.filter { assignesIDs.contains($0.id) }
        let autres = actifs.filter { !assignesIDs.contains($0.id) }

        return List {
            Section {
                Text("La séance sera enregistrée au nom du joueur choisi et alimentera son suivi des charges.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }
            if !assignes.isEmpty {
                Section("Assignés au programme") {
                    ForEach(assignes) { joueur in
                        ligneJoueurLive(joueur)
                    }
                }
            }
            if !autres.isEmpty {
                Section(assignes.isEmpty ? "Joueurs" : "Autres joueurs") {
                    ForEach(autres) { joueur in
                        ligneJoueurLive(joueur)
                    }
                }
            }
            Section {
                Button {
                    choixJoueurLive = .sansJoueur
                } label: {
                    Label("Séance d'équipe (sans joueur)", systemImage: "person.3")
                }
            }
        }
        .navigationTitle("Pour quel joueur ?")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func ligneJoueurLive(_ joueur: JoueurEquipe) -> some View {
        let indisponible = !joueur.estDisponible
        return Button {
            choixJoueurLive = .joueur(joueur.id)
        } label: {
            HStack {
                Text("#\(joueur.numero)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .leading)
                Text("\(joueur.prenom) \(joueur.nom)")
                Spacer()
                if indisponible {
                    Text(joueur.statutDisponibilite.libelle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .disabled(indisponible)
        .opacity(indisponible ? 0.5 : 1)
    }

    // MARK: - Actions

    private func creerProgramme() {
        let nom = nomNouveauProgramme.trimmingCharacters(in: .whitespaces)
        guard !nom.isEmpty else { nomNouveauProgramme = ""; return }
        let prog = ProgrammeMuscu(nom: nom)
        prog.codeEquipe = codeEquipeActif
        modelContext.insert(prog)
        try? modelContext.save()
        nomNouveauProgramme = ""
        selectionSidebar = .programme(prog)
    }

    private var boutonRetour: some View {
        Button {
            onRetour()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                Image(systemName: "volleyball.fill")
                    .font(.system(size: 14))
                Text("Accueil")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(PaletteMat.violet)
        }
    }
}

// MARK: - Vue historique complète

struct HistoriqueView: View {
    let seances: [SeanceMuscu]

    var body: some View {
        Group {
            if seances.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock")
                        .font(.system(size: 50))
                        .foregroundStyle(.tertiary)
                    Text("Aucun entraînement complété")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(seances) { seance in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(seance.programmeNom)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(seance.date.formatFrancais())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 16) {
                                Label("\(seance.seriesCompletees) séries", systemImage: "checkmark.circle")
                                    .font(.caption)
                                    .foregroundStyle(.green)

                                if seance.volumeTotal > 0 {
                                    Label("\(Int(seance.volumeTotal)) lbs", systemImage: "scalemass")
                                        .font(.caption)
                                        .foregroundStyle(PaletteMat.violet)
                                }

                                if seance.dureeTotale > 0 {
                                    Label("\(seance.dureeTotale / 60) min", systemImage: "clock")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                            }

                            // Détail exercices
                            let exercices = seance.decoderExercices()
                            if !exercices.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(exercices) { exo in
                                        let meilleureCharge = exo.series
                                            .filter(\.estComplete)
                                            .max(by: { $0.poids < $1.poids })

                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(exo.categorie.couleur)
                                                .frame(width: 6, height: 6)
                                            Text(exo.exerciceNom)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            if let meilleure = meilleureCharge {
                                                Text("\(Int(meilleure.poids)) lbs x \(meilleure.reps)")
                                                    .font(.caption2.weight(.medium))
                                                    .foregroundStyle(PaletteMat.violet)
                                            }
                                        }
                                    }
                                }
                                .padding(.top, 2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Historique")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// ProgrammeMuscu already conforms to Hashable via PersistentModel
