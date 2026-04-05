//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData
import Charts

/// Suivi musculation d'un joueur — programmes assignés, séances, graphique charges
struct SuiviMusculationView: View {
    let joueur: JoueurEquipe

    @Query(filter: #Predicate<ProgrammeMuscu> { $0.estArchive == false },
           sort: \ProgrammeMuscu.dateCreation, order: .reverse) private var tousProgrammes: [ProgrammeMuscu]
    @Query(sort: \SeanceMuscu.date, order: .reverse) private var toutesSeances: [SeanceMuscu]

    @State private var exerciceFiltre: String? = nil

    private var programmesAssignes: [ProgrammeMuscu] {
        tousProgrammes.filter { $0.decoderJoueursAssignes().contains(joueur.id) }
    }

    private var seancesJoueur: [SeanceMuscu] {
        toutesSeances.filter { $0.joueurID == joueur.id && $0.estTerminee }
    }

    // MARK: - Données graphique

    private struct PointCharge: Identifiable {
        let id = UUID()
        let date: Date
        let exerciceNom: String
        let poids: Double
    }

    private var donneesCharge: [PointCharge] {
        var points: [PointCharge] = []
        for seance in seancesJoueur {
            let exos = seance.decoderExercices()
            for exo in exos {
                let maxPoids = exo.series
                    .filter(\.estComplete)
                    .map(\.poids)
                    .max() ?? 0
                if maxPoids > 0 {
                    points.append(PointCharge(date: seance.date, exerciceNom: exo.exerciceNom, poids: maxPoids))
                }
            }
        }
        return points
    }

    private var donneesChargeFiltrees: [PointCharge] {
        guard let filtre = exerciceFiltre else { return donneesCharge }
        return donneesCharge.filter { $0.exerciceNom == filtre }
    }

    private var nomsExercices: [String] {
        Array(Set(donneesCharge.map(\.exerciceNom))).sorted()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Programmes assignés
                sectionProgrammes

                // Graphique charges
                if !donneesCharge.isEmpty {
                    sectionGraphique
                }

                // Séances récentes
                sectionSeances
            }
            .padding(16)
        }
        .navigationTitle("Suivi muscu")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Programmes assignés

    private var sectionProgrammes: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Programmes assignés", systemImage: "dumbbell.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PaletteMat.violet)

            if programmesAssignes.isEmpty {
                Text("Aucun programme assigné")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(programmesAssignes) { prog in
                            let exos = prog.decoderExercices()
                            VStack(alignment: .leading, spacing: 6) {
                                Text(prog.nom)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                HStack(spacing: 6) {
                                    Label("\(exos.count) ex.", systemImage: "list.bullet")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    ForEach(Array(Set(exos.map(\.categorieRaw))).prefix(2), id: \.self) { catRaw in
                                        if let cat = CategorieMuscu(rawValue: catRaw) {
                                            Image(systemName: cat.icone)
                                                .font(.caption2)
                                                .foregroundStyle(cat.couleur)
                                        }
                                    }
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemGroupedBackground))
                            )
                        }
                    }
                }
            }
        }
        .glassSection()
    }

    // MARK: - Graphique charges

    private var sectionGraphique: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Évolution des charges", systemImage: "chart.line.uptrend.xyaxis")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PaletteMat.violet)

            // Filtre exercice
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        exerciceFiltre = nil
                    } label: {
                        Text("Tous")
                            .font(.caption.weight(exerciceFiltre == nil ? .bold : .regular))
                            .foregroundStyle(exerciceFiltre == nil ? .white : .primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                exerciceFiltre == nil
                                    ? AnyShapeStyle(PaletteMat.violet)
                                    : AnyShapeStyle(Color.primary.opacity(0.06)),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)

                    ForEach(nomsExercices, id: \.self) { nom in
                        Button {
                            exerciceFiltre = nom
                        } label: {
                            Text(nom)
                                .font(.caption.weight(exerciceFiltre == nom ? .bold : .regular))
                                .foregroundStyle(exerciceFiltre == nom ? .white : .primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    exerciceFiltre == nom
                                        ? AnyShapeStyle(PaletteMat.violet)
                                        : AnyShapeStyle(Color.primary.opacity(0.06)),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Chart(donneesChargeFiltrees) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Charge (lbs)", point.poids)
                )
                .foregroundStyle(by: .value("Exercice", point.exerciceNom))

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Charge (lbs)", point.poids)
                )
                .foregroundStyle(by: .value("Exercice", point.exerciceNom))
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 220)
        }
        .glassSection()
    }

    // MARK: - Séances récentes

    private var sectionSeances: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Séances récentes", systemImage: "clock.arrow.circlepath")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PaletteMat.violet)

            if seancesJoueur.isEmpty {
                Text("Aucune séance complétée")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                ForEach(seancesJoueur.prefix(10)) { seance in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(seance.programmeNom)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            Text(seance.date.formatCourt())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if seance.volumeTotal > 0 {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(Int(seance.volumeTotal)) lbs")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(PaletteMat.violet)
                                Text("\(seance.seriesCompletees) séries")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if seance.dureeTotale > 0 {
                            Text("\(seance.dureeTotale / 60) min")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.blue.opacity(0.1), in: Capsule())
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                }
            }
        }
        .glassSection()
    }
}
