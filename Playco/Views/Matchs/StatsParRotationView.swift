//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData
import Charts

/// Analyse des performances par rotation (1-6) basée sur les PointMatch
struct StatsParRotationView: View {
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Query private var tousPoints: [PointMatch]
    @Query(filter: #Predicate<Seance> { $0.typeSeanceRaw == "Match" && $0.estArchivee == false },
           sort: \Seance.date, order: .reverse) private var seances: [Seance]

    @State private var pointsEquipe: [PointMatch] = []
    @State private var seancesEquipe: [Seance] = []
    @State private var seanceSelectionneeID: UUID? = nil
    @State private var statsRotations: [StatsRotation] = []

    struct StatsRotation: Identifiable {
        let id: Int // rotation 1-6
        var pointsPour: Int = 0
        var pointsContre: Int = 0
        var kills: Int = 0
        var aces: Int = 0
        var blocs: Int = 0
        var erreurs: Int = 0
        var totalPoints: Int { pointsPour + pointsContre }
        var efficacite: Double {
            guard totalPoints > 0 else { return 0 }
            return Double(pointsPour) / Double(totalPoints) * 100
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: LiquidGlassKit.espaceLG) {
                entete
                filtreMatch

                if statsRotations.contains(where: { $0.totalPoints > 0 }) {
                    graphiqueEfficacite
                    graphiqueDetails
                    meilleureEtPireRotation
                    tableauDetaille
                } else {
                    ContentUnavailableView(
                        "Pas de données",
                        systemImage: "arrow.triangle.2.circlepath",
                        description: Text("Enregistrez des points via la saisie live pour voir les stats par rotation.")
                    )
                }
            }
            .padding(LiquidGlassKit.espaceLG)
        }
        .navigationTitle("Stats par rotation")
        .onAppear { mettreAJour() }
        .onChange(of: codeEquipeActif) { _, _ in mettreAJour() }
        .onChange(of: seanceSelectionneeID) { _, _ in recalculer() }
    }

    // MARK: - En-tête

    private var entete: some View {
        HStack {
            VStack(alignment: .leading, spacing: LiquidGlassKit.espaceXS) {
                Text("Stats par rotation")
                    .font(.title.weight(.bold))
                Text("Performance de l'équipe en rotations 1 à 6")
                    .font(.subheadline)
                    .foregroundStyle(PaletteMat.texteSecondaire)
            }
            Spacer()
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 32))
                .foregroundStyle(PaletteMat.bleu.opacity(0.6))
                .symbolRenderingMode(.hierarchical)
        }
    }

    // MARK: - Filtre

    private var filtreMatch: some View {
        HStack(spacing: LiquidGlassKit.espaceSM) {
            Text("Match")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PaletteMat.texteSecondaire)
            Picker("Match", selection: $seanceSelectionneeID) {
                Text("Tous les matchs")
                    .tag(nil as UUID?)
                ForEach(seancesEquipe) { s in
                    Text("\(s.nom) — \(s.date.formatCourt())")
                        .tag(s.id as UUID?)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(LiquidGlassKit.espaceSM + 2)
        .glassSection()
    }

    // MARK: - Graphique efficacité

    private var graphiqueEfficacite: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Label("Efficacité par rotation", systemImage: "chart.bar.fill")
                .font(.headline.weight(.semibold))

            Chart(statsRotations.filter { $0.totalPoints > 0 }) { stat in
                BarMark(
                    x: .value("Rotation", "R\(stat.id)"),
                    y: .value("Efficacité", stat.efficacite)
                )
                .foregroundStyle(couleurEfficacite(stat.efficacite))
                .cornerRadius(LiquidGlassKit.espaceXS)
                .annotation(position: .top) {
                    Text(String(format: "%.0f%%", stat.efficacite))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(couleurEfficacite(stat.efficacite))
                }
            }
            .chartYScale(domain: 0...100)
            .chartYAxisLabel("% Points gagnés")
            .frame(height: 200)
        }
        .padding(LiquidGlassKit.espaceMD)
        .glassCard(teinte: PaletteMat.bleu, cornerRadius: LiquidGlassKit.rayonMoyen)
    }

    // MARK: - Graphique détails (stacked)

    private var graphiqueDetails: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Label("Points par rotation", systemImage: "chart.bar.xaxis")
                .font(.headline.weight(.semibold))

            Chart {
                ForEach(statsRotations.filter { $0.totalPoints > 0 }) { stat in
                    BarMark(
                        x: .value("Rotation", "R\(stat.id)"),
                        y: .value("Points", stat.pointsPour)
                    )
                    .foregroundStyle(PaletteMat.vert)

                    BarMark(
                        x: .value("Rotation", "R\(stat.id)"),
                        y: .value("Points", -stat.pointsContre)
                    )
                    .foregroundStyle(Color.red.opacity(0.7))
                }
            }
            .chartYAxisLabel("Points pour / contre")
            .frame(height: 180)

            HStack(spacing: LiquidGlassKit.espaceMD) {
                legendeItem(couleur: PaletteMat.vert, texte: "Points pour nous")
                legendeItem(couleur: .red.opacity(0.7), texte: "Points contre")
            }
            .font(.caption2)
        }
        .padding(LiquidGlassKit.espaceMD)
        .glassCard(teinte: PaletteMat.vert, cornerRadius: LiquidGlassKit.rayonMoyen)
    }

    private func legendeItem(couleur: Color, texte: String) -> some View {
        HStack(spacing: LiquidGlassKit.espaceXS) {
            Circle().fill(couleur).frame(width: 8, height: 8)
            Text(texte).foregroundStyle(PaletteMat.texteSecondaire)
        }
    }

    // MARK: - Meilleure / pire rotation

    private var meilleureEtPireRotation: some View {
        let avecDonnees = statsRotations.filter { $0.totalPoints > 0 }
        let meilleure = avecDonnees.max(by: { $0.efficacite < $1.efficacite })
        let pire = avecDonnees.min(by: { $0.efficacite < $1.efficacite })

        return HStack(spacing: LiquidGlassKit.espaceSM + 4) {
            if let m = meilleure {
                carteRotation(
                    titre: "Meilleure rotation",
                    rotation: m.id,
                    efficacite: m.efficacite,
                    couleur: PaletteMat.vert,
                    icone: "arrow.up.circle.fill"
                )
            }
            if let p = pire, meilleure?.id != pire?.id {
                carteRotation(
                    titre: "Pire rotation",
                    rotation: p.id,
                    efficacite: p.efficacite,
                    couleur: .red,
                    icone: "arrow.down.circle.fill"
                )
            }
        }
    }

    private func carteRotation(titre: String, rotation: Int, efficacite: Double, couleur: Color, icone: String) -> some View {
        VStack(spacing: LiquidGlassKit.espaceSM) {
            Image(systemName: icone)
                .font(.title2)
                .foregroundStyle(couleur)
                .symbolRenderingMode(.hierarchical)
            Text("R\(rotation)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(couleur)
            Text(String(format: "%.0f%%", efficacite))
                .font(.subheadline.weight(.semibold))
                .contentTransition(.numericText())
            Text(titre)
                .font(.caption2.weight(.medium))
                .foregroundStyle(PaletteMat.texteSecondaire)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LiquidGlassKit.espaceMD)
        .glassCard(teinte: couleur, cornerRadius: LiquidGlassKit.rayonMoyen)
    }

    // MARK: - Tableau détaillé

    private var tableauDetaille: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Label("Détails par rotation", systemImage: "tablecells")
                .font(.headline.weight(.semibold))

            // En-tête
            HStack(spacing: 0) {
                Text("Rot.").frame(width: 40, alignment: .leading)
                Text("Pts+").frame(width: 45)
                Text("Pts-").frame(width: 45)
                Text("Eff.").frame(width: 50)
                Text("K").frame(width: 35)
                Text("A").frame(width: 35)
                Text("B").frame(width: 35)
                Text("Err").frame(width: 35)
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(PaletteMat.texteSecondaire)
            .padding(.horizontal, LiquidGlassKit.espaceSM)

            Divider()

            ForEach(statsRotations) { stat in
                HStack(spacing: 0) {
                    Text("R\(stat.id)")
                        .font(.caption.weight(.bold))
                        .frame(width: 40, alignment: .leading)
                    Text("\(stat.pointsPour)")
                        .foregroundStyle(PaletteMat.vert)
                        .frame(width: 45)
                    Text("\(stat.pointsContre)")
                        .foregroundStyle(.red)
                        .frame(width: 45)
                    Text(stat.totalPoints > 0 ? String(format: "%.0f%%", stat.efficacite) : "—")
                        .foregroundStyle(couleurEfficacite(stat.efficacite))
                        .fontWeight(.semibold)
                        .frame(width: 50)
                    Text("\(stat.kills)").frame(width: 35)
                    Text("\(stat.aces)").frame(width: 35)
                    Text("\(stat.blocs)").frame(width: 35)
                    Text("\(stat.erreurs)")
                        .foregroundStyle(stat.erreurs > 0 ? .red : .primary)
                        .frame(width: 35)
                }
                .font(.caption.monospacedDigit())
                .padding(.horizontal, LiquidGlassKit.espaceSM)
                .padding(.vertical, 3)
                .contentTransition(.numericText())
            }
        }
        .padding(LiquidGlassKit.espaceMD)
        .glassCard(cornerRadius: LiquidGlassKit.rayonMoyen)
    }

    // MARK: - Helpers

    private func couleurEfficacite(_ eff: Double) -> Color {
        if eff >= 55 { return PaletteMat.vert }
        if eff >= 45 { return PaletteMat.orange }
        return .red
    }

    // MARK: - Logique

    private func mettreAJour() {
        pointsEquipe = tousPoints.filtreEquipe(codeEquipeActif)
        seancesEquipe = seances.filtreEquipe(codeEquipeActif)
        recalculer()
    }

    private func recalculer() {
        var points = pointsEquipe

        if let seanceID = seanceSelectionneeID {
            points = points.filter { $0.seanceID == seanceID }
        }

        var rotations = (1...6).map { StatsRotation(id: $0) }

        for point in points {
            let idx = point.rotationAuMoment - 1
            guard idx >= 0 && idx < 6 else { continue }

            if point.estPointPourNous {
                rotations[idx].pointsPour += 1
            } else {
                rotations[idx].pointsContre += 1
            }

            switch point.typeAction {
            case .kill: rotations[idx].kills += 1
            case .ace: rotations[idx].aces += 1
            case .blocSeul, .blocAssiste, .bloc: rotations[idx].blocs += 1
            case .erreurAdversaire: break
            default:
                if point.typeAction.estErreurEquipe { rotations[idx].erreurs += 1 }
            }
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            statsRotations = rotations
        }
    }
}
