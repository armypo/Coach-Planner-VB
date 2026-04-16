//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "SeanceLive")

/// Mode live d'entraînement — log séries/reps/poids, chrono repos, progression
struct SeanceLiveView: View {
    let programme: ProgrammeMuscu
    var joueurID: UUID? = nil
    var onTerminer: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Query(sort: \SeanceMuscu.date, order: .reverse) private var toutesSeancesMuscu: [SeanceMuscu]
    private var historiqueSeances: [SeanceMuscu] {
        toutesSeancesMuscu.filtreEquipe(codeEquipeActif)
    }

    // État de la séance
    @State private var exercicesLog: [ExerciceLog] = []
    @State private var indexExercice: Int = 0
    @State private var tempsDebut: Date = Date()

    // Chrono repos
    @State private var reposActif = false
    @State private var tempsReposRestant: Int = 0
    @State private var tempsReposTotal: Int = 90
    @State private var timerRepos: Timer?

    // Chrono global
    @State private var tempsSeance: TimeInterval = 0
    @State private var timerSeance: Timer?

    // Confirmation fin
    @State private var afficherConfirmation = false

    private var exercicesProgramme: [ExerciceProgramme] {
        programme.decoderExercices()
    }

    private var exerciceActuel: ExerciceLog? {
        guard exercicesLog.indices.contains(indexExercice) else { return nil }
        return exercicesLog[indexExercice]
    }

    /// Dernière séance de ce programme pour afficher la progression
    private var derniereSeance: SeanceMuscu? {
        historiqueSeances.first { $0.programmeID == programme.id && $0.estTerminee }
    }

    /// Charge précédente pour un exercice donné
    private func chargesPrecedentes(exerciceID: UUID) -> [SerieLog] {
        guard let derniere = derniereSeance else { return [] }
        let exos = derniere.decoderExercices()
        return exos.first(where: { $0.exerciceID == exerciceID })?.series ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            // Barre d'info
            barreInfo

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    // Navigation exercices
                    barreNavExercices

                    // En-tête exercice
                    if let exo = exerciceActuel {
                        enteteExercice(exo)
                    }

                    // Timer repos
                    if reposActif {
                        timerReposView
                    }

                    // Séries
                    if let exo = exerciceActuel {
                        sectionSeries(exo)
                    }
                }
                .padding()
            }

            Divider()

            // Barre du bas
            barreBas
        }
        .navigationTitle("Entraînement")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            initialiserSeance()
            demarrerChronoSeance()
        }
        .onDisappear {
            timerRepos?.invalidate()
            timerSeance?.invalidate()
            timerRepos = nil
            timerSeance = nil
        }
        .alert("Terminer l'entraînement ?", isPresented: $afficherConfirmation) {
            Button("Annuler", role: .cancel) {}
            Button("Terminer") { sauvegarderEtTerminer() }
        } message: {
            let completees = exercicesLog.reduce(0) { $0 + $1.series.filter(\.estComplete).count }
            Text("\(completees) séries complétées — \(formatTemps(tempsSeance))")
        }
        .alert("Erreur", isPresented: $afficherErreur) {
            Button("OK") { afficherErreur = false }
        } message: {
            Text(messageErreur)
        }
    }

    // MARK: - Barre info

    private var barreInfo: some View {
        HStack(spacing: 16) {
            // Chrono séance
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .foregroundStyle(PaletteMat.violet)
                Text(formatTemps(tempsSeance))
                    .font(.subheadline.weight(.bold).monospacedDigit())
            }

            Spacer()

            // Volume total
            let vol = exercicesLog.reduce(0.0) { total, exo in
                total + exo.series.filter(\.estComplete).reduce(0.0) { $0 + $1.poids * Double($1.reps) }
            }
            if vol > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "scalemass")
                        .foregroundStyle(.orange)
                    Text("\(Int(vol)) lbs")
                        .font(.caption.weight(.bold))
                }
            }

            // Séries complétées
            let completees = exercicesLog.reduce(0) { $0 + $1.series.filter(\.estComplete).count }
            let totales = exercicesLog.reduce(0) { $0 + $1.series.count }
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.green)
                Text("\(completees)/\(totales)")
                    .font(.caption.weight(.bold))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Navigation exercices

    private var barreNavExercices: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(exercicesLog.indices, id: \.self) { i in
                    let exo = exercicesLog[i]
                    let toutComplete = exo.series.allSatisfy(\.estComplete)
                    let auMoinsUn = exo.series.contains(where: \.estComplete)

                    Button { indexExercice = i } label: {
                        VStack(spacing: 4) {
                            Image(systemName: exo.categorie.icone)
                                .font(.system(size: 14))
                            Text(exo.exerciceNom)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .frame(width: 70)
                        .padding(.vertical, 8)
                        .background(
                            i == indexExercice
                                ? AnyShapeStyle(PaletteMat.violet.opacity(0.15))
                                : toutComplete
                                    ? AnyShapeStyle(Color.green.opacity(0.08))
                                    : AnyShapeStyle(Color.primary.opacity(0.04)),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    i == indexExercice ? PaletteMat.violet : .clear,
                                    lineWidth: 2
                                )
                        )
                        .foregroundStyle(
                            toutComplete ? .green : (auMoinsUn ? PaletteMat.violet : .primary)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - En-tête exercice

    private func enteteExercice(_ exo: ExerciceLog) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(exo.categorie.couleur.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: exo.categorie.icone)
                    .font(.title3)
                    .foregroundStyle(exo.categorie.couleur)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(exo.exerciceNom)
                    .font(.title3.weight(.bold))

                let completees = exo.series.filter(\.estComplete).count
                Text("\(completees)/\(exo.series.count) séries")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Bouton ajouter série
            Button {
                ajouterSerie()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(PaletteMat.violet)
            }
        }
        .glassSection()
    }

    // MARK: - Timer repos

    private var timerReposView: some View {
        VStack(spacing: 12) {
            Text("Repos")
                .font(.caption.weight(.bold))
                .foregroundStyle(.blue)

            Text("\(tempsReposRestant)")
                .font(.system(size: 48, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tempsReposRestant <= 5 ? .red : .blue)

            // Barre de progression
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.blue)
                        .frame(width: geo.size.width * (Double(tempsReposRestant) / Double(max(tempsReposTotal, 1))))
                }
            }
            .frame(height: 6)

            HStack(spacing: 12) {
                Button { ajusterRepos(-15) } label: {
                    Text("-15s")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                }

                Button {
                    arreterRepos()
                } label: {
                    Text("Passer")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(.blue, in: Capsule())
                }

                Button { ajusterRepos(15) } label: {
                    Text("+15s")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                }
            }
        }
        .padding(16)
        .background(.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Section séries

    private func sectionSeries(_ exo: ExerciceLog) -> some View {
        VStack(spacing: 0) {
            // En-tête tableau
            HStack {
                Text("SÉRIE")
                    .frame(width: 50)
                Text("PRÉCÉDENT")
                    .frame(maxWidth: .infinity)
                Text("POIDS")
                    .frame(width: 80)
                Text("REPS")
                    .frame(width: 60)
                Text("")
                    .frame(width: 44)
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Séries
            ForEach(exo.series.indices, id: \.self) { serieIdx in
                ligneSerie(exerciceIdx: indexExercice, serieIdx: serieIdx)
                if serieIdx < exo.series.count - 1 {
                    Divider().padding(.leading, 12)
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    private func ligneSerie(exerciceIdx: Int, serieIdx: Int) -> some View {
        let serie = exercicesLog[exerciceIdx].series[serieIdx]
        let precedentes = chargesPrecedentes(exerciceID: exercicesLog[exerciceIdx].exerciceID)
        let precedente = serieIdx < precedentes.count ? precedentes[serieIdx] : nil

        return HStack {
            // Numéro
            Text("\(serie.numero)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(serie.estComplete ? .green : .primary)
                .frame(width: 50)

            // Précédent
            if let prec = precedente, prec.estComplete {
                Text("\(Int(prec.poids)) × \(prec.reps)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            } else {
                Text("—")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }

            // Poids
            TextField("0", value: Binding(
                get: { exercicesLog[exerciceIdx].series[serieIdx].poids },
                set: { exercicesLog[exerciceIdx].series[serieIdx].poids = $0 }
            ), format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .font(.subheadline.weight(.medium))
            .frame(width: 80)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))

            // Reps
            TextField("0", value: Binding(
                get: { exercicesLog[exerciceIdx].series[serieIdx].reps },
                set: { exercicesLog[exerciceIdx].series[serieIdx].reps = $0 }
            ), format: .number)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.subheadline.weight(.medium))
            .frame(width: 60)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))

            // Check
            Button {
                toggleSerie(exerciceIdx: exerciceIdx, serieIdx: serieIdx)
            } label: {
                Image(systemName: serie.estComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(serie.estComplete ? .green : .secondary)
            }
            .frame(width: 44)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(serie.estComplete ? Color.green.opacity(0.04) : .clear)
    }

    // MARK: - Barre du bas

    private var barreBas: some View {
        HStack(spacing: 16) {
            // Exercice précédent
            Button {
                if indexExercice > 0 { indexExercice -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.medium))
                    .frame(width: 44, height: 44)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(indexExercice > 0 ? .primary : .tertiary)
            }
            .disabled(indexExercice == 0)

            // Terminer
            Button {
                afficherConfirmation = true
            } label: {
                Label("Terminer l'entraînement", systemImage: "flag.checkered")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(PaletteMat.violet, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }

            // Exercice suivant
            Button {
                if indexExercice < exercicesLog.count - 1 { indexExercice += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.medium))
                    .frame(width: 44, height: 44)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(indexExercice < exercicesLog.count - 1 ? .primary : .tertiary)
            }
            .disabled(indexExercice >= exercicesLog.count - 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Actions

    private func initialiserSeance() {
        let exosProgramme = exercicesProgramme
        exercicesLog = exosProgramme.map { exoProg in
            // Charger les poids de la dernière séance si disponibles
            let precedentes = chargesPrecedentes(exerciceID: exoProg.exerciceID)

            let series = (0..<exoProg.seriesCibles).map { i in
                let poidsPrecedent = i < precedentes.count ? precedentes[i].poids : exoProg.poidsDefaut
                let repsPrecedents = i < precedentes.count ? precedentes[i].reps : exoProg.repsCibles
                return SerieLog(
                    numero: i + 1,
                    reps: repsPrecedents,
                    poids: poidsPrecedent
                )
            }

            return ExerciceLog(
                exerciceID: exoProg.exerciceID,
                exerciceNom: exoProg.exerciceNom,
                categorieRaw: exoProg.categorieRaw,
                series: series
            )
        }
        tempsDebut = Date()
    }

    private func toggleSerie(exerciceIdx: Int, serieIdx: Int) {
        let wasComplete = exercicesLog[exerciceIdx].series[serieIdx].estComplete
        exercicesLog[exerciceIdx].series[serieIdx].estComplete.toggle()

        // Lancer le repos si on vient de cocher
        if !wasComplete {
            let tempsRepos = exercicesProgramme.indices.contains(exerciceIdx)
                ? exercicesProgramme[exerciceIdx].tempsRepos : 90
            demarrerRepos(duree: tempsRepos)
        }
    }

    private func ajouterSerie() {
        guard exercicesLog.indices.contains(indexExercice) else { return }
        let nbSeries = exercicesLog[indexExercice].series.count
        let derniereSerie = exercicesLog[indexExercice].series.last
        let nouvelleSerie = SerieLog(
            numero: nbSeries + 1,
            reps: derniereSerie?.reps ?? 10,
            poids: derniereSerie?.poids ?? 0
        )
        exercicesLog[indexExercice].series.append(nouvelleSerie)
    }

    // MARK: - Repos

    private func demarrerRepos(duree: Int) {
        arreterRepos()
        tempsReposTotal = duree
        tempsReposRestant = duree
        reposActif = true
        timerRepos = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if tempsReposRestant > 0 {
                tempsReposRestant -= 1
            } else {
                arreterRepos()
            }
        }
    }

    private func arreterRepos() {
        reposActif = false
        timerRepos?.invalidate()
        timerRepos = nil
    }

    private func ajusterRepos(_ delta: Int) {
        tempsReposRestant = max(0, tempsReposRestant + delta)
        tempsReposTotal = max(tempsReposTotal, tempsReposRestant)
    }

    // MARK: - Chrono séance

    private func demarrerChronoSeance() {
        timerSeance = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            tempsSeance = Date().timeIntervalSince(tempsDebut)
        }
    }

    @State private var messageErreur: String = ""
    @State private var afficherErreur: Bool = false

    // MARK: - Sauvegarder

    private func sauvegarderEtTerminer() {
        let seance = SeanceMuscu(programmeNom: programme.nom, programmeID: programme.id, joueurID: joueurID)
        seance.dureeTotale = Int(tempsSeance)
        seance.estTerminee = true
        seance.codeEquipe = codeEquipeActif
        seance.encoderExercices(exercicesLog)

        modelContext.insert(seance)
        do {
            try modelContext.save()
        } catch {
            logger.error("Erreur sauvegarde séance muscu: \(error.localizedDescription)")
            messageErreur = "Impossible d'enregistrer votre séance. Vérifiez votre connexion iCloud et réessayez."
            afficherErreur = true
            return
        }

        timerSeance?.invalidate()
        timerRepos?.invalidate()
        onTerminer()
    }

    private func formatTemps(_ secondes: TimeInterval) -> String {
        let mins = Int(secondes) / 60
        let secs = Int(secondes) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
