//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Fil du match (worm chart, 3.3 refonte stats) : écart de score point par
//  point pour un set, séries de 3+ points surlignées, temps morts et
//  substitutions marqués. Données pré-calculées en @State (pattern perfo
//  projet) et sous-vue de graphique Equatable.
//

import SwiftUI
import SwiftData
import Charts

struct FilDuMatchView: View {
    let seance: Seance

    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Query private var tousPoints: [PointMatch]

    @State private var setSelectionne = 1
    @State private var donnees = DonneesFilMatch()

    var body: some View {
        ScrollView {
            VStack(spacing: LiquidGlassKit.espaceLG) {
                if donnees.setsDisponibles.count > 1 {
                    Picker("Set", selection: $setSelectionne) {
                        ForEach(donnees.setsDisponibles, id: \.self) { numero in
                            Text("Set \(numero)").tag(numero)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if donnees.points.isEmpty {
                    ContentUnavailableView(
                        "Pas de points enregistrés",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Saisissez le match en direct pour voir le fil du match point par point.")
                    )
                } else {
                    GraphiqueFilMatch(donnees: donnees)
                        .equatable()
                        .frame(height: 260)
                        .padding(LiquidGlassKit.espaceMD)
                        .glassSection()

                    legendeFil

                    if !donnees.runs.isEmpty {
                        sectionRuns
                    }
                }
            }
            .padding(LiquidGlassKit.espaceLG)
        }
        .navigationTitle("Fil du match")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { recalculer() }
        .onChange(of: setSelectionne) { _, _ in recalculer() }
        .onChange(of: tousPoints.count) { _, _ in recalculer() }
    }

    // MARK: - Légende et séries

    private var legendeFil: some View {
        HStack(spacing: LiquidGlassKit.espaceMD) {
            etiquette(couleur: PaletteMat.positif, texte: "Série pour nous (3+)")
            etiquette(couleur: PaletteMat.negatif, texte: "Série adverse (3+)")
            etiquette(couleur: PaletteMat.bleu, texte: "T = temps mort")
            Spacer()
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func etiquette(couleur: Color, texte: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(couleur.opacity(0.5)).frame(width: 8, height: 8)
            Text(texte)
        }
    }

    private var sectionRuns: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            EnTeteSection(titre: "Séries du set",
                          sousTitre: "Séquences de 3 points consécutifs ou plus")
            ForEach(donnees.runs) { run in
                HStack {
                    Text(run.pourNous ? "Nous" : "Adversaire")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(run.pourNous ? PaletteMat.positif : PaletteMat.negatif)
                    Text("\(run.longueur) points de suite")
                        .font(.caption)
                    Spacer()
                    Text("points \(run.debut + 1) à \(run.fin + 1)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(LiquidGlassKit.espaceMD)
        .glassSection()
    }

    // MARK: - Calcul (caché en @State)

    private func recalculer() {
        let pointsMatch = tousPoints
            .filter { $0.seanceID == seance.id }
            .sorted { $0.horodatage < $1.horodatage }

        let sets = Array(Set(pointsMatch.map(\.set))).sorted()
        if !sets.contains(setSelectionne), let premier = sets.first {
            setSelectionne = premier
        }

        let pointsDuSet = pointsMatch.filter { $0.set == setSelectionne }
        let runs = MetriquesVolley.detecterRuns(points: pointsDuSet, minimum: 3)

        var fil: [PointFilMatch] = []
        for (index, point) in pointsDuSet.enumerated() {
            fil.append(PointFilMatch(
                id: point.id,
                index: index,
                ecart: point.scoreEquipeAuMoment - point.scoreAdversaireAuMoment,
                pourNous: point.estPointPourNous
            ))
        }

        // Marqueurs : x = nombre de points joués au moment de l'événement.
        var marqueurs: [MarqueurFilMatch] = []
        for tm in seance.tempsMorts where tm.set == setSelectionne {
            marqueurs.append(MarqueurFilMatch(
                id: tm.id,
                index: min(tm.scoreNousAuMoment + tm.scoreAdvAuMoment, max(0, fil.count - 1)),
                estTempsMort: true,
                pourNous: tm.equipe == "nous"
            ))
        }
        for sub in seance.substitutions where sub.set == setSelectionne {
            marqueurs.append(MarqueurFilMatch(
                id: sub.id,
                index: min(sub.scoreNousAuMoment + sub.scoreAdvAuMoment, max(0, fil.count - 1)),
                estTempsMort: false,
                pourNous: true
            ))
        }

        donnees = DonneesFilMatch(
            points: fil,
            runs: runs.map { RunFilMatch(debut: $0.debutIndex,
                                         fin: $0.debutIndex + $0.longueur - 1,
                                         longueur: $0.longueur,
                                         pourNous: $0.pourNous) },
            marqueurs: marqueurs,
            setsDisponibles: sets
        )
    }
}

// MARK: - Données du fil (Equatable pour la sous-vue)

struct PointFilMatch: Identifiable, Equatable {
    let id: UUID
    let index: Int
    let ecart: Int
    let pourNous: Bool
}

struct RunFilMatch: Identifiable, Equatable {
    var id: Int { debut }
    let debut: Int
    let fin: Int
    let longueur: Int
    let pourNous: Bool
}

struct MarqueurFilMatch: Identifiable, Equatable {
    let id: UUID
    let index: Int
    let estTempsMort: Bool
    let pourNous: Bool
}

struct DonneesFilMatch: Equatable {
    var points: [PointFilMatch] = []
    var runs: [RunFilMatch] = []
    var marqueurs: [MarqueurFilMatch] = []
    var setsDisponibles: [Int] = []
}

// MARK: - Graphique (Equatable — ne se redessine que si les données changent)

struct GraphiqueFilMatch: View, Equatable {
    let donnees: DonneesFilMatch

    var body: some View {
        Chart {
            // Séries surlignées (fond)
            ForEach(donnees.runs) { run in
                RectangleMark(
                    xStart: .value("Début", run.debut),
                    xEnd: .value("Fin", run.fin)
                )
                .foregroundStyle((run.pourNous ? PaletteMat.positif : PaletteMat.negatif).opacity(0.10))
            }

            // Ligne zéro (égalité)
            RuleMark(y: .value("Égalité", 0))
                .foregroundStyle(.secondary.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

            // Écart de score point par point
            ForEach(donnees.points) { point in
                LineMark(
                    x: .value("Point", point.index),
                    y: .value("Écart", point.ecart)
                )
                .interpolationMethod(.stepEnd)
                .foregroundStyle(PaletteMat.bleu)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }

            // Temps morts et substitutions
            ForEach(donnees.marqueurs) { marqueur in
                RuleMark(x: .value("Événement", marqueur.index))
                    .foregroundStyle((marqueur.estTempsMort ? PaletteMat.bleu : PaletteMat.violet).opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .annotation(position: .top, alignment: .center, spacing: 2) {
                        Text(marqueur.estTempsMort ? "T" : "S")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(marqueur.estTempsMort ? PaletteMat.bleu : PaletteMat.violet)
                    }
            }
        }
        .chartYAxisLabel("Écart de score")
        .chartXAxisLabel("Points joués")
        .accessibilityLabel("Fil du match : écart de score point par point")
    }
}
