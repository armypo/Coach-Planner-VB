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
    @Environment(CloudKitSharingService.self) private var sharingService
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
    @State private var afficherRepriseLive = false
    @State private var afficherConfirmationFinaliser = false
    @State private var confirmeFinalisation = false
    @State private var afficherAnalyseMatch = false
    @State private var afficherPlanMatch = false

    /// Exercice conteneur pour le terrain — stocké en @State pour éviter la recréation
    @State private var exerciceTerrain: Exercice?

    private var peutModifier: Bool {
        authService.utilisateurConnecte != nil
    }

    /// Cherche ou crée l'exercice terrain lié à cette séance
    private func chargerExerciceTerrain() {
        guard exerciceTerrain == nil else { return }
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
        .onAppear {
            chargerExerciceTerrain()
            // 2.2.a — State Restoration : si l'app a été tuée pendant le live
            // de CE match (marqueur encore présent), proposer la reprise.
            // Gardée par le rôle (revue HI-001) : le mode live est réservé aux
            // rôles qui peuvent modifier les séances — même gate que la toolbar.
            if peutModifier, !seance.statsEntrees, MatchLiveRestauration.correspond(a: seance.id) {
                afficherRepriseLive = true
            }
        }
        // La vue peut être réutilisée pour une autre séance (sélection sidebar) :
        // sans reset, le terrain resterait figé sur l'exercice du match précédent.
        .onChange(of: seance.id) {
            exerciceTerrain = nil
            chargerExerciceTerrain()
        }
        .navigationTitle(seance.nom)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if peutModifier {
                ToolbarItem(placement: .primaryAction) {
                    // C2 (pivot) : 7 chips → 3 groupes, le cycle temporel réel
                    // d'un match pour un coach : Préparer · En direct · Après.
                    HStack(spacing: 8) {
                        Menu {
                            Button { afficherComposition = true } label: {
                                Label("Composition", systemImage: "person.3.fill")
                            }
                            if !seance.adversaire.isEmpty {
                                Button { afficherPlanMatch = true } label: {
                                    Label("Plan de match (scouting)", systemImage: "binoculars.fill")
                                }
                            }
                        } label: {
                            chipGroupe("Préparer", icone: "person.3.fill", couleur: PaletteMat.bleu)
                        }

                        Menu {
                            Button { afficherModeLive = true } label: {
                                Label("Mode en direct", systemImage: "rectangle.split.2x1.fill")
                            }
                            Button { afficherDashboardLive = true } label: {
                                Label("Dashboard", systemImage: "chart.bar.fill")
                            }
                        } label: {
                            chipGroupe("En direct", icone: "dot.radiowaves.left.and.right", couleur: MatNuit.live)
                        }

                        Menu {
                            Button { afficherInfoMatch = true } label: {
                                Label("Score & infos · \(resumeScore)", systemImage: "flag.fill")
                            }
                            if !seance.statsEntrees {
                                Button { afficherConfirmationFinaliser = true } label: {
                                    Label("Finaliser le match", systemImage: "checkmark.seal.fill")
                                }
                            } else {
                                Button { afficherAnalyseMatch = true } label: {
                                    Label("Analyse du match", systemImage: "chart.xyaxis.line")
                                }
                            }
                            Button { afficherExportPDF = true } label: {
                                Label("Exporter en PDF", systemImage: "square.and.arrow.up")
                            }
                        } label: {
                            chipGroupe(seance.statsEntrees ? "Finalisé · \(resumeScore)" : "Après",
                                       icone: seance.statsEntrees ? "checkmark.seal.fill" : "flag.fill",
                                       couleur: MatNuit.brique)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $afficherInfoMatch) {
            InfoMatchSheet(seance: seance)
        }
        .sheet(isPresented: $afficherAnalyseMatch) {
            AnalyseMatchSheet(seance: seance)
        }
        .sheet(isPresented: $afficherPlanMatch) {
            NavigationStack {
                ScrollView {
                    PlanMatchPanneau(adversaire: seance.adversaire)
                        .padding(LiquidGlassKit.espaceMD)
                }
                .navigationTitle("Plan de match")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Fermer") { afficherPlanMatch = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
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
                        ToolbarItem(placement: .cancellationAction) {
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
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Fermer") { afficherModeLive = false }
                        }
                    }
            }
        }
        .alert("Reprendre le match en direct ?", isPresented: $afficherRepriseLive) {
            Button("Reprendre") { afficherModeLive = true }
            Button("Non", role: .cancel) { MatchLiveRestauration.effacer() }
        } message: {
            Text("La saisie de ce match était en cours. Le score, les rotations et le service seront restaurés là où vous étiez rendu.")
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

    /// Chip-menu de la toolbar match (C2) : libellé + icône teintés.
    private func chipGroupe(_ titre: String, icone: String, couleur: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icone)
                .font(.caption)
            Text(titre)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(couleur)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(couleur.opacity(0.1), in: Capsule())
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

        // 2.2.a — un match finalisé ne doit plus proposer de reprise live
        if MatchLiveRestauration.correspond(a: seance.id) {
            MatchLiveRestauration.effacer()
        }

        let joueursEquipe = joueurs.filtreEquipe(codeEquipeActif)
        let pointsMatch = tousPoints.filter { $0.seanceID == seance.id }
        let actionsMatch = toutesActionsRallye.filter { $0.seanceID == seance.id }
        let joueursIDs = Set(pointsMatch.compactMap(\.joueurID))
            .union(actionsMatch.map(\.joueurID))

        // Agrégation + StatsMatch + resynchronisation du cumul carrière,
        // centralisées dans le service (couvre l'union des StatsMatch créés
        // pendant l'appel — cf. FinalisationMatchTests). Pose statsEntrees.
        AgregateurStatsMatch.finaliserStats(
            seance: seance,
            points: pointsMatch,
            actions: actionsMatch,
            statsExistants: tousStatsMatch.filtreEquipe(codeEquipeActif),
            joueurs: joueursEquipe,
            codeEquipe: codeEquipeActif,
            contexte: modelContext
        )
        do {
            try modelContext.save()
            confirmeFinalisation = true
            logger.info("Match finalisé: \(seance.nom) — \(joueursIDs.count) joueurs")
            // E3/E4 (D6) : publier immédiatement l'analyse du match finalisé
            // (box scores + points + statsEntrees) — le sweep sert de filet.
            // Tout rôle coach publie (assistant = head coach).
            if let user = authService.utilisateurConnecte,
               CloudKitSharingService.planSync(role: user.role).publie {
                sharingService.ecrivainID = user.id.uuidString
                let seanceFinalisee = seance
                let contexte = modelContext
                Task { await sharingService.publierAnalyseMatch(seance: seanceFinalisee, context: contexte) }
            }
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
