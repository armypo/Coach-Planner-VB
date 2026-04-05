//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Catégorie de statistiques

enum CategorieStats: String, CaseIterable, Identifiable {
    case attaque   = "Attaque"
    case service   = "Service"
    case bloc      = "Bloc"
    case reception = "Réception"
    case jeu       = "Jeu"

    var id: String { rawValue }

    var icone: String {
        switch self {
        case .attaque:   return "flame.fill"
        case .service:   return "tennisball.fill"
        case .bloc:      return "hand.raised.fill"
        case .reception: return "arrow.down.to.line"
        case .jeu:       return "arrow.triangle.branch"
        }
    }

    var couleurPrincipale: Color {
        switch self {
        case .attaque:   return PaletteMat.orange
        case .service:   return PaletteMat.bleu
        case .bloc:      return PaletteMat.violet
        case .reception: return PaletteMat.vert
        case .jeu:       return PaletteMat.bleu
        }
    }
}

// MARK: - Point de données pour le graphique

struct PointEvolution: Identifiable {
    let id = UUID()
    let date: Date
    let valeurPrincipale: Double
    let valeurSecondaire: Double?
    let adversaire: String
    let labelPrincipal: String
    let labelSecondaire: String?
}

// MARK: - Tendance

enum Tendance {
    case hausse, baisse, stable

    var label: String {
        switch self {
        case .hausse: return "En hausse"
        case .baisse: return "En baisse"
        case .stable: return "Stable"
        }
    }

    var icone: String {
        switch self {
        case .hausse: return "arrow.up.right"
        case .baisse: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }

    var couleur: Color {
        switch self {
        case .hausse: return PaletteMat.vert
        case .baisse: return .red
        case .stable: return PaletteMat.bleu
        }
    }
}

// MARK: - Vue principale

struct EvolutionJoueurView: View {
    let joueur: JoueurEquipe

    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Query private var toutesStats: [StatsMatch]
    @Query(filter: #Predicate<Seance> { $0.estArchivee == false },
           sort: \Seance.date) private var toutesSeances: [Seance]

    @State private var categorieSelectionnee: CategorieStats = .attaque
    @State private var pointsDonnees: [PointEvolution] = []
    @State private var apparition = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                selecteurCategorie
                graphiquePrincipal
                resumeStatistiques
                historiqueDetaille
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Évolution — \(joueur.prenom)")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            calculerPoints()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                apparition = true
            }
        }
        .onChange(of: categorieSelectionnee) { _, _ in
            calculerPoints()
        }
    }

    // MARK: - Sélecteur de catégorie

    private var selecteurCategorie: some View {
        Picker("Catégorie", selection: $categorieSelectionnee) {
            ForEach(CategorieStats.allCases) { cat in
                Label(cat.rawValue, systemImage: cat.icone)
                    .tag(cat)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 4)
    }

    // MARK: - Graphique principal

    private var graphiquePrincipal: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: categorieSelectionnee.icone)
                    .foregroundStyle(categorieSelectionnee.couleurPrincipale)
                Text(categorieSelectionnee.rawValue)
                    .font(.headline.weight(.semibold))
                Spacer()
                Text("\(pointsDonnees.count) matchs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if pointsDonnees.isEmpty {
                ContentUnavailableView(
                    "Aucune donnée",
                    systemImage: "chart.line.downtrend.xyaxis",
                    description: Text("Aucune statistique de match enregistrée pour ce joueur.")
                )
                .frame(height: 260)
            } else {
                Chart {
                    ForEach(pointsDonnees) { point in
                        // Zone de remplissage dégradé
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value(point.labelPrincipal, point.valeurPrincipale)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    categorieSelectionnee.couleurPrincipale.opacity(0.25),
                                    categorieSelectionnee.couleurPrincipale.opacity(0.02)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        // Ligne principale
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value(point.labelPrincipal, point.valeurPrincipale)
                        )
                        .foregroundStyle(PaletteMat.bleu)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .interpolationMethod(.catmullRom)
                        .symbol {
                            Circle()
                                .fill(PaletteMat.bleu)
                                .frame(width: 7, height: 7)
                        }

                        // Ligne secondaire (si applicable)
                        if let sec = point.valeurSecondaire, let labelSec = point.labelSecondaire {
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value(labelSec, sec)
                            )
                            .foregroundStyle(PaletteMat.orange)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 4]))
                            .interpolationMethod(.catmullRom)
                            .symbol {
                                Circle()
                                    .stroke(PaletteMat.orange, lineWidth: 2)
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                            .foregroundStyle(.secondary.opacity(0.3))
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: axeXStride)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                            .foregroundStyle(.secondary.opacity(0.3))
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
                            .font(.caption2)
                    }
                }
                .chartLegend(position: .top, alignment: .trailing)
                .frame(height: 280)
                .padding(.top, 8)
                .opacity(apparition ? 1 : 0)
                .offset(y: apparition ? 0 : 20)

                // Légende personnalisée
                legendeGraphique
            }
        }
        .padding(16)
        .glassCard(teinte: categorieSelectionnee.couleurPrincipale)
    }

    private var axeXStride: Int {
        let count = pointsDonnees.count
        if count <= 5 { return 1 }
        if count <= 12 { return 2 }
        return 4
    }

    private var legendeGraphique: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Circle().fill(PaletteMat.bleu).frame(width: 8, height: 8)
                Text(labelPrincipalCategorie)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if aLigneSecondaire {
                HStack(spacing: 6) {
                    Circle().stroke(PaletteMat.orange, lineWidth: 2).frame(width: 8, height: 8)
                    Text(labelSecondaireCategorie)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Résumé statistiques

    private var resumeStatistiques: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Résumé")
                .font(.headline.weight(.semibold))

            if pointsDonnees.isEmpty {
                Text("Aucune donnée disponible")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                let valeurs = pointsDonnees.map(\.valeurPrincipale)
                let minimum = valeurs.min() ?? 0
                let maximum = valeurs.max() ?? 0
                let moyenne = valeurs.reduce(0, +) / Double(valeurs.count)
                let tendance = calculerTendance(valeurs)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    carteResume(titre: "Min", valeur: formaterValeur(minimum), couleur: .red)
                    carteResume(titre: "Max", valeur: formaterValeur(maximum), couleur: PaletteMat.vert)
                    carteResume(titre: "Moyenne", valeur: formaterValeur(moyenne), couleur: PaletteMat.bleu)
                    carteTendance(tendance: tendance)
                }
            }
        }
        .padding(16)
        .glassSection()
        .opacity(apparition ? 1 : 0)
        .offset(y: apparition ? 0 : 15)
    }

    private func carteResume(titre: String, valeur: String, couleur: Color) -> some View {
        VStack(spacing: 6) {
            Text(titre)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(valeur)
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(couleur)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .glassCard(teinte: couleur, cornerRadius: 12, ombre: false)
    }

    private func carteTendance(tendance: Tendance) -> some View {
        VStack(spacing: 6) {
            Text("Tendance")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Image(systemName: tendance.icone)
                    .font(.caption.weight(.bold))
                Text(tendance.label)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(tendance.couleur)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .glassCard(teinte: tendance.couleur, cornerRadius: 12, ombre: false)
    }

    // MARK: - Historique détaillé

    private var historiqueDetaille: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Historique des matchs")
                    .font(.headline.weight(.semibold))
                Spacer()
                Text("\(pointsDonnees.count)")
                    .font(.subheadline.weight(.medium))
                    .glassChip(couleur: categorieSelectionnee.couleurPrincipale)
            }

            if pointsDonnees.isEmpty {
                Text("Aucun match enregistré")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(pointsDonnees.reversed()) { point in
                        ligneHistorique(point: point)
                    }
                }
            }
        }
        .padding(16)
        .glassSection()
        .opacity(apparition ? 1 : 0)
        .offset(y: apparition ? 0 : 10)
    }

    private func ligneHistorique(point: PointEvolution) -> some View {
        HStack(spacing: 14) {
            // Date
            VStack(alignment: .leading, spacing: 2) {
                Text(point.date.formatCourt())
                    .font(.subheadline.weight(.medium))
                if !point.adversaire.isEmpty {
                    Text("vs \(point.adversaire)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 120, alignment: .leading)

            Spacer()

            // Valeur principale
            VStack(alignment: .trailing, spacing: 2) {
                Text(formaterValeur(point.valeurPrincipale))
                    .font(.body.weight(.bold).monospacedDigit())
                    .foregroundStyle(categorieSelectionnee.couleurPrincipale)
                Text(point.labelPrincipal)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Valeur secondaire (si applicable)
            if let sec = point.valeurSecondaire, let labelSec = point.labelSecondaire {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formaterValeur(sec))
                        .font(.body.weight(.semibold).monospacedDigit())
                        .foregroundStyle(PaletteMat.orange)
                    Text(labelSec)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 70, alignment: .trailing)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassCard(cornerRadius: 12, ombre: false)
    }

    // MARK: - Labels par catégorie

    private var labelPrincipalCategorie: String {
        switch categorieSelectionnee {
        case .attaque:   return "Kills"
        case .service:   return "Aces"
        case .bloc:      return "Blocs totaux"
        case .reception: return "Efficacité %"
        case .jeu:       return "Passes décisives"
        }
    }

    private var labelSecondaireCategorie: String {
        switch categorieSelectionnee {
        case .attaque:   return "Hitting %"
        default:         return ""
        }
    }

    private var aLigneSecondaire: Bool {
        categorieSelectionnee == .attaque
    }

    // MARK: - Calculs

    private func calculerPoints() {
        let statsJoueur = toutesStats.filter { $0.joueurID == joueur.id }

        // Construire un dictionnaire seanceID → Seance pour lookup rapide
        let seancesDict = Dictionary(uniqueKeysWithValues: toutesSeances.compactMap { s -> (UUID, Seance)? in
            guard s.estMatch, !s.estArchivee else { return nil }
            return (s.id, s)
        })

        // Associer chaque StatsMatch à sa Seance et trier par date
        var paires: [(stats: StatsMatch, seance: Seance)] = statsJoueur.compactMap { stat in
            guard let seance = seancesDict[stat.seanceID] else { return nil }
            return (stat, seance)
        }
        paires.sort { $0.seance.date < $1.seance.date }

        // Mapper vers des points de données selon la catégorie
        pointsDonnees = paires.map { paire in
            let s = paire.stats
            let seance = paire.seance

            switch categorieSelectionnee {
            case .attaque:
                return PointEvolution(
                    date: seance.date,
                    valeurPrincipale: Double(s.kills),
                    valeurSecondaire: s.hittingPct * 100,
                    adversaire: seance.adversaire,
                    labelPrincipal: "Kills",
                    labelSecondaire: "Hitting %"
                )
            case .service:
                return PointEvolution(
                    date: seance.date,
                    valeurPrincipale: Double(s.aces),
                    valeurSecondaire: nil,
                    adversaire: seance.adversaire,
                    labelPrincipal: "Aces",
                    labelSecondaire: nil
                )
            case .bloc:
                let total = Double(s.blocsSeuls) + Double(s.blocsAssistes) * 0.5
                return PointEvolution(
                    date: seance.date,
                    valeurPrincipale: total,
                    valeurSecondaire: nil,
                    adversaire: seance.adversaire,
                    labelPrincipal: "Blocs totaux",
                    labelSecondaire: nil
                )
            case .reception:
                let efficacite: Double = s.receptionsTotales > 0
                    ? Double(s.receptionsReussies - s.erreursReception) / Double(s.receptionsTotales) * 100
                    : 0
                return PointEvolution(
                    date: seance.date,
                    valeurPrincipale: efficacite,
                    valeurSecondaire: nil,
                    adversaire: seance.adversaire,
                    labelPrincipal: "Efficacité %",
                    labelSecondaire: nil
                )
            case .jeu:
                return PointEvolution(
                    date: seance.date,
                    valeurPrincipale: Double(s.passesDecisives),
                    valeurSecondaire: nil,
                    adversaire: seance.adversaire,
                    labelPrincipal: "Passes déc.",
                    labelSecondaire: nil
                )
            }
        }
    }

    private func calculerTendance(_ valeurs: [Double]) -> Tendance {
        guard valeurs.count >= 3 else { return .stable }

        // Comparer la moyenne de la première moitié vs la seconde moitié
        let milieu = valeurs.count / 2
        let premierePartie = Array(valeurs.prefix(milieu))
        let secondePartie = Array(valeurs.suffix(milieu))

        let moyennePremiere = premierePartie.reduce(0, +) / Double(premierePartie.count)
        let moyenneSeconde = secondePartie.reduce(0, +) / Double(secondePartie.count)

        let ecart = moyenneSeconde - moyennePremiere
        let seuil = max(moyennePremiere * 0.1, 0.5)

        if ecart > seuil { return .hausse }
        if ecart < -seuil { return .baisse }
        return .stable
    }

    private func formaterValeur(_ valeur: Double) -> String {
        if valeur == valeur.rounded() && abs(valeur) < 1000 {
            return String(format: "%.0f", valeur)
        }
        return String(format: "%.1f", valeur)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EvolutionJoueurView(
            joueur: JoueurEquipe(nom: "Tremblay", prenom: "Alexis", numero: 7, poste: .recepteur)
        )
    }
    .modelContainer(for: [StatsMatch.self, Seance.self, JoueurEquipe.self], inMemory: true)
}
