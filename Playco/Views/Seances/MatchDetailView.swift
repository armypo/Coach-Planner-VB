//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "MatchDetail")

/// Détail d'un match — terrain vierge avec pages (étapes), notes, infos match (score, résultat)
struct MatchDetailView: View {
    @Bindable var seance: Seance

    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Query(filter: #Predicate<StrategieCollective> { $0.categorieRaw == "Système d'attaque" && $0.estArchivee == false })
    private var strategiesOffensives: [StrategieCollective]
    @Query(filter: #Predicate<JoueurEquipe> { $0.estActif == true },
           sort: \JoueurEquipe.numero)
    private var joueurs: [JoueurEquipe]
    @Query private var toutesFormationsPerso: [FormationPersonnalisee]
    @Query private var tousPoints: [PointMatch]
    @Query private var toutesActionsRallye: [ActionRallye]
    @Query private var tousStatsMatch: [StatsMatch]
    private var formationsPerso: [FormationPersonnalisee] {
        toutesFormationsPerso.filtreEquipe(codeEquipeActif)
    }

    @State private var afficherInfoMatch = false
    @State private var afficherComposition = false
    @State private var afficherExportPDF = false
    @State private var afficherDashboardLive = false
    @State private var afficherModeLive = false
    @State private var afficherConfirmationFinaliser = false
    @State private var confirmeFinalisation = false

    /// Exercice conteneur pour le terrain — stocké en @State pour éviter la recréation
    @State private var exerciceTerrain: Exercice?

    private var peutModifier: Bool {
        authService.utilisateurConnecte?.role.peutModifierSeances ?? false
    }

    /// Cherche ou crée l'exercice terrain lié à cette séance
    private func chargerExerciceTerrain() {
        // 1. Chercher dans la relation directe
        if let existant = (seance.exercices ?? []).first(where: { !$0.estArchive }) {
            exerciceTerrain = existant
            return
        }

        // 2. Fallback : query par nom + seance
        let seanceID = seance.id
        let descriptor = FetchDescriptor<Exercice>(
            predicate: #Predicate { $0.nom == "Terrain match" && $0.estArchive == false }
        )
        if let exercices = try? modelContext.fetch(descriptor),
           let existant = exercices.first(where: { $0.seance?.id == seanceID }) {
            exerciceTerrain = existant
            return
        }

        // 3. Créer un nouvel exercice conteneur
        let exo = Exercice(nom: "Terrain match", ordre: 0)
        exo.seance = seance
        modelContext.insert(exo)
        if seance.exercices == nil { seance.exercices = [] }
        seance.exercices?.append(exo)
        do {
            try modelContext.save()
        } catch {
            logger.error("Erreur sauvegarde exercice terrain: \(error.localizedDescription)")
        }
        exerciceTerrain = exo
    }

    var body: some View {
        VStack(spacing: 0) {
            // Info match en haut
            barreInfoMatch

            Divider()

            if let exo = exerciceTerrain {
                // Terrain avec pages (étapes)
                TerrainEditeurView(
                    dessinData: Binding(
                        get: { exo.dessinData },
                        set: { exo.dessinData = $0 }
                    ),
                    elementsData: Binding(
                        get: { exo.elementsData },
                        set: { exo.elementsData = $0 }
                    ),
                    notes: Binding(
                        get: { exo.notes },
                        set: { exo.notes = $0 }
                    ),
                    etapesData: Binding(
                        get: { exo.etapesData },
                        set: { exo.etapesData = $0 }
                    ),
                    typeTerrain: .indoor,
                    afficherNotes: true,
                    labelEtape: "Set",
                    strategiesOffensives: strategiesOffensives,
                    joueursBD: joueurs,
                    formationsPerso: formationsPerso
                )
            } else {
                ProgressView("Chargement du terrain…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { chargerExerciceTerrain() }
        .navigationTitle(seance.nom)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if peutModifier {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 8) {
                        // Composition
                        Button { afficherComposition = true } label: {
                            Image(systemName: "person.3.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1), in: Capsule())
                        }

                        // Dashboard live
                        Button { afficherDashboardLive = true } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.caption)
                                Text("Dashboard")
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundStyle(PaletteMat.vert)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(PaletteMat.vert.opacity(0.1), in: Capsule())
                        }

                        // Finaliser le match (auto box score)
                        if !seance.statsEntrees {
                            Button { afficherConfirmationFinaliser = true } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.caption)
                                    Text("Finaliser")
                                        .font(.caption.weight(.medium))
                                }
                                .foregroundStyle(PaletteMat.vert)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(PaletteMat.vert.opacity(0.15), in: Capsule())
                            }
                        } else {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption)
                                Text("Finalisé")
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                        }

                        // Mode live split-screen
                        Button { afficherModeLive = true } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "rectangle.split.2x1.fill")
                                    .font(.caption)
                                Text("Mode en direct")
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.1), in: Capsule())
                        }

                        // Score / Info match
                        Button { afficherInfoMatch = true } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "flag.fill")
                                    .font(.caption)
                                Text(resumeScore)
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundStyle(.red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.1), in: Capsule())
                        }

                        // Export PDF
                        Button { afficherExportPDF = true } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color(.tertiarySystemFill), in: Capsule())
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $afficherInfoMatch) {
            InfoMatchSheet(seance: seance)
        }
        .sheet(isPresented: $afficherComposition) {
            NavigationStack {
                ScrollView {
                    CompositionMatchView(seance: seance)
                        .padding()
                }
                .navigationTitle("Partants & Composition")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("OK") { afficherComposition = false }
                    }
                }
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $afficherDashboardLive) {
            NavigationStack {
                DashboardLiveSheetWrapper(seance: seance)
                    .navigationTitle("Dashboard Live")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Fermer") { afficherDashboardLive = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $afficherExportPDF) {
            ExportMatchPDFView(seance: seance)
        }
        .fullScreenCover(isPresented: $afficherModeLive) {
            NavigationStack {
                MatchLiveSplitView(seance: seance)
                    .navigationTitle("Mode en direct — \(seance.nom)")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Fermer") { afficherModeLive = false }
                        }
                    }
            }
        }
        .alert("Finaliser le match ?", isPresented: $afficherConfirmationFinaliser) {
            Button("Finaliser", role: .destructive) { finaliserMatch() }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("Les statistiques seront générées automatiquement à partir des données live et synchronisées avec les profils des joueurs. Cette action est irréversible.")
        }
        .alert("Match finalisé", isPresented: $confirmeFinalisation) {
            Button("OK") { }
        } message: {
            Text("Les statistiques ont été générées et synchronisées avec les profils des joueurs.")
        }
    }

    // MARK: - Barre info match

    private var resumeScore: String {
        if seance.scoreEquipe > 0 || seance.scoreAdversaire > 0 {
            return "\(seance.scoreEquipe) - \(seance.scoreAdversaire)"
        }
        return "Score"
    }

    private var barreInfoMatch: some View {
        HStack(spacing: 16) {
            // Adversaire
            if !seance.adversaire.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                    Text("vs \(seance.adversaire)")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.red)
            }

            // Lieu
            if !seance.lieu.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.caption2)
                    Text(seance.lieu)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Date
            Text(seance.date.formatCourt())
                .font(.caption)
                .foregroundStyle(.secondary)

            // Score
            if seance.scoreEquipe > 0 || seance.scoreAdversaire > 0 {
                HStack(spacing: 4) {
                    Text("\(seance.scoreEquipe) - \(seance.scoreAdversaire)")
                        .font(.subheadline.weight(.bold))
                    if let resultat = seance.resultat {
                        Text(resultat.label)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(resultat.couleur, in: Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Finaliser match (auto box score)

    private func finaliserMatch() {
        guard !seance.statsEntrees else { return }

        let joueursEquipe = joueurs.filtreEquipe(codeEquipeActif)
        let pointsMatch = tousPoints.filter { $0.seanceID == seance.id }
        let actionsMatch = toutesActionsRallye.filter { $0.seanceID == seance.id }

        // Collecter tous les joueurs impliqués
        var joueursIDs = Set<UUID>()
        for p in pointsMatch { if let jid = p.joueurID { joueursIDs.insert(jid) } }
        for a in actionsMatch { joueursIDs.insert(a.joueurID) }

        for joueurID in joueursIDs {
            // Trouver ou créer StatsMatch
            let stat: StatsMatch
            if let existant = tousStatsMatch.first(where: { $0.seanceID == seance.id && $0.joueurID == joueurID }) {
                stat = existant
            } else {
                stat = StatsMatch(seanceID: seance.id, joueurID: joueurID)
                stat.codeEquipe = codeEquipeActif
                modelContext.insert(stat)
            }

            // Agrégation PointMatch
            let pointsJoueur = pointsMatch.filter { $0.joueurID == joueurID }
            for point in pointsJoueur {
                switch point.typeAction {
                case .kill:
                    stat.kills += 1
                    stat.tentativesAttaque += 1
                case .erreurAttaque:
                    stat.erreursAttaque += 1
                    stat.tentativesAttaque += 1
                case .ace:
                    stat.aces += 1
                    stat.servicesTotaux += 1
                case .erreurService:
                    stat.erreursService += 1
                    stat.servicesTotaux += 1
                case .blocSeul, .bloc:
                    stat.blocsSeuls += 1
                case .blocAssiste:
                    stat.blocsAssistes += 1
                case .erreurBloc:
                    stat.erreursBloc += 1
                case .erreurReception:
                    stat.erreursReception += 1
                    stat.receptionsTotales += 1
                case .erreurAdversaire, .fauteJeu, .erreurEquipe,
                     .killAdversaire, .aceAdversaire, .blocAdversaire,
                     .erreurAttaqueAdversaire, .erreurServiceAdversaire:
                    break
                }
            }

            // Agrégation ActionRallye
            let actionsJoueur = actionsMatch.filter { $0.joueurID == joueurID }
            for action in actionsJoueur {
                switch action.typeAction {
                case .manchette:
                    stat.manchettes += 1
                case .passeDecisive:
                    stat.passesDecisives += 1
                case .reception:
                    stat.receptionsTotales += 1
                    if action.qualite >= 2 {
                        stat.receptionsReussies += 1
                    }
                case .tentativeAttaque:
                    stat.tentativesAttaque += 1
                case .serviceEnJeu, .dig:
                    break
                }
            }

            // Sets joués = nombre de sets distincts où le joueur apparaît
            var setsJoueur = Set<Int>()
            for p in pointsJoueur { setsJoueur.insert(p.set) }
            for a in actionsJoueur { setsJoueur.insert(a.set) }
            stat.setsJoues = setsJoueur.count

            // Sync vers JoueurEquipe cumulatif
            guard let joueur = joueursEquipe.first(where: { $0.id == joueurID }) else { continue }

            joueur.matchsJoues += 1
            joueur.setsJoues += stat.setsJoues

            joueur.attaquesReussies += stat.kills
            joueur.erreursAttaque += stat.erreursAttaque
            joueur.attaquesTotales += stat.tentativesAttaque

            joueur.aces += stat.aces
            joueur.erreursService += stat.erreursService
            joueur.servicesTotaux += stat.servicesTotaux

            joueur.blocsSeuls += stat.blocsSeuls
            joueur.blocsAssistes += stat.blocsAssistes
            joueur.erreursBloc += stat.erreursBloc

            joueur.receptionsReussies += stat.receptionsReussies
            joueur.erreursReception += stat.erreursReception
            joueur.receptionsTotales += stat.receptionsTotales

            joueur.passesDecisives += stat.passesDecisives
            joueur.manchettes += stat.manchettes
        }

        seance.statsEntrees = true
        do {
            try modelContext.save()
            confirmeFinalisation = true
            logger.info("Match finalisé: \(seance.nom) — \(joueursIDs.count) joueurs")
        } catch {
            logger.error("Erreur finalisation match: \(error.localizedDescription)")
        }
    }
}

// MARK: - Sheet info match (score, résultat, adversaire, lieu, notes)

struct InfoMatchSheet: View {
    @Bindable var seance: Seance
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Adversaire") {
                    TextField("Nom de l'équipe adverse", text: $seance.adversaire)
                    TextField("Lieu", text: $seance.lieu)
                }

                Section("Score par set") {
                    SetsScoreView(seance: seance)
                }

                Section("Score global (sets gagnés)") {
                    HStack {
                        Text("Nous")
                        Spacer()
                        Text("\(seance.scoreEquipe)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.green)
                            .contentTransition(.numericText())
                    }
                    HStack {
                        Text("Adversaire")
                        Spacer()
                        Text("\(seance.scoreAdversaire)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.red)
                            .contentTransition(.numericText())
                    }
                    if seance.scoreEntre {
                        HStack {
                            Text("Résultat")
                            Spacer()
                            if let r = seance.resultat {
                                Text(r.label)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(r.couleur)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(r.couleur.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                }

                Section("Notes du match") {
                    TextField("Observations, ajustements…", text: $seance.notesMatch, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle("Infos du match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // Note: Le résultat est maintenant calculé automatiquement par Seance.sets setter
}

// MARK: - Wrappers pour sheets standalone (créent leur propre ViewModel)

/// Wrapper pour StatsLiveView en sheet standalone (hors MatchLiveSplitView)
struct StatsLiveSheetWrapper: View {
    @Bindable var seance: Seance

    @Environment(\.modelContext) private var modelContext
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Query(filter: #Predicate<JoueurEquipe> { $0.estActif == true },
           sort: \JoueurEquipe.numero) private var tousJoueurs: [JoueurEquipe]

    @State private var viewModel: MatchLiveViewModel?

    private var joueursEquipe: [JoueurEquipe] {
        tousJoueurs.filtreEquipe(codeEquipeActif)
    }

    var body: some View {
        Group {
            if let vm = viewModel {
                StatsLiveView(viewModel: vm)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = MatchLiveViewModel(
                    seance: seance,
                    modelContext: modelContext,
                    joueurs: joueursEquipe,
                    codeEquipe: codeEquipeActif
                )
            }
        }
    }
}

/// Wrapper pour DashboardMatchLiveView en sheet standalone
struct DashboardLiveSheetWrapper: View {
    @Bindable var seance: Seance

    @Environment(\.modelContext) private var modelContext
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Query(filter: #Predicate<JoueurEquipe> { $0.estActif == true },
           sort: \JoueurEquipe.numero) private var tousJoueurs: [JoueurEquipe]

    @State private var viewModel: MatchLiveViewModel?

    private var joueursEquipe: [JoueurEquipe] {
        tousJoueurs.filtreEquipe(codeEquipeActif)
    }

    var body: some View {
        Group {
            if let vm = viewModel {
                DashboardMatchLiveView(viewModel: vm)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = MatchLiveViewModel(
                    seance: seance,
                    modelContext: modelContext,
                    joueurs: joueursEquipe,
                    codeEquipe: codeEquipeActif
                )
            }
        }
    }
}
