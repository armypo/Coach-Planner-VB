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
    /// Moyenne mobile (fenêtre glissante) de la valeur principale — renseignée
    /// à partir du 3e match seulement (fenêtre complète).
    var moyenneMobile: Double? = nil
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
        case .hausse: return PaletteMat.positif
        case .baisse: return PaletteMat.negatif
        case .stable: return PaletteMat.bleu
        }
    }
}

// MARK: - Vue principale

struct EvolutionJoueurView: View {
    let joueur: JoueurEquipe
    /// Vrai quand la vue est incorporée dans la fiche joueur (pas de ScrollView propre).
    var estIncorporee: Bool = false

    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Query private var toutesStats: [StatsMatch]
    @Query(filter: #Predicate<Seance> { $0.estArchivee == false },
           sort: \Seance.date) private var toutesSeances: [Seance]

    @State private var categorieSelectionnee: CategorieStats = .attaque
    @State private var pointsDonnees: [PointEvolution] = []
    @State private var apparition = false

    // MARK: - Constantes

    /// Taille de la fenêtre de la moyenne mobile (en matchs).
    private static let fenetreMoyenneMobile = 3
    /// Le rendement (fraction 0-1) est porté ×100 sur le graphique pour
    /// partager l'échelle des kills ; `efficaciteReception` est déjà en 0-100.
    private static let echellePourcentage = 100.0
    private static let hauteurGraphique: CGFloat = 280
    private static let hauteurEtatVide: CGFloat = 260
    private static let largeurColonneDate: CGFloat = 120
    private static let largeurColonneSecondaire: CGFloat = 70
    /// Seuils de détection de tendance (écart relatif / absolu).
    private static let seuilTendanceRelatif = 0.1
    private static let seuilTendanceAbsolu = 0.5

    // MARK: - Body

    var body: some View {
        Group {
            if estIncorporee {
                // Incorporée dans la fiche joueur (segmenté 2.3) : le parent
                // fournit déjà le ScrollView et le padding.
                contenu
            } else {
                ScrollView {
                    contenu
                        .padding(LiquidGlassKit.espaceLG)
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Évolution — \(joueur.prenom)")
                .navigationBarTitleDisplayMode(.large)
            }
        }
        .onAppear {
            calculerPoints()
            withAnimation(LiquidGlassKit.springDefaut) {
                apparition = true
            }
        }
        .onChange(of: categorieSelectionnee) { calculerPoints() }
        .onChange(of: toutesStats) { calculerPoints() }
        .onChange(of: codeEquipeActif) { calculerPoints() }
    }

    private var contenu: some View {
        VStack(spacing: LiquidGlassKit.espaceLG) {
            selecteurCategorie
            graphiquePrincipal
            resumeStatistiques
            historiqueDetaille
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
        .padding(.horizontal, LiquidGlassKit.espaceXS)
    }

    // MARK: - Graphique principal

    private var graphiquePrincipal: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM + 4) {
            EnTeteSection(titre: categorieSelectionnee.rawValue,
                          sousTitre: libelleMatchs(pointsDonnees.count))

            if pointsDonnees.isEmpty {
                ContentUnavailableView(
                    "Aucune donnée",
                    systemImage: "chart.line.downtrend.xyaxis",
                    description: Text("Saisissez des statistiques de match (box score ou stats en direct) pour suivre l'évolution de \(joueur.prenom).")
                )
                .frame(height: Self.hauteurEtatVide)
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

                        // Ligne secondaire (rendement attaque, fraction ×100
                        // pour partager l'échelle des kills)
                        if let secondaire = point.valeurSecondaire, let labelSec = point.labelSecondaire {
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value(labelSec, secondaire * Self.echellePourcentage)
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

                        // Moyenne mobile (fenêtre glissante de 3 matchs)
                        if let moyenneMobile = point.moyenneMobile {
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Moyenne mobile", moyenneMobile)
                            )
                            .foregroundStyle(PaletteMat.texteSecondaire)
                            .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 4]))
                            .interpolationMethod(.catmullRom)
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
                .frame(height: Self.hauteurGraphique)
                .padding(.top, LiquidGlassKit.espaceSM)
                .opacity(apparition ? 1 : 0)
                .offset(y: apparition ? 0 : 20)

                // Légende personnalisée
                legendeGraphique
            }
        }
        .padding(LiquidGlassKit.espaceMD)
        .glassCard(teinte: categorieSelectionnee.couleurPrincipale)
    }

    private var axeXStride: Int {
        let count = pointsDonnees.count
        if count <= 5 { return 1 }
        if count <= 12 { return 2 }
        return 4
    }

    private var aMoyenneMobile: Bool {
        pointsDonnees.contains { $0.moyenneMobile != nil }
    }

    private var legendeGraphique: some View {
        HStack(spacing: LiquidGlassKit.espaceMD) {
            HStack(spacing: LiquidGlassKit.espaceXS + 2) {
                Circle().fill(PaletteMat.bleu).frame(width: 8, height: 8)
                Text(labelPrincipalCategorie)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if aLigneSecondaire {
                HStack(spacing: LiquidGlassKit.espaceXS + 2) {
                    Circle().stroke(PaletteMat.orange, lineWidth: 2).frame(width: 8, height: 8)
                    Text(labelSecondaireCategorie)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if aMoyenneMobile {
                HStack(spacing: LiquidGlassKit.espaceXS + 2) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(PaletteMat.texteSecondaire)
                        .frame(width: 14, height: 2)
                    Text("Moyenne mobile (\(Self.fenetreMoyenneMobile) matchs)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Résumé statistiques

    private var resumeStatistiques: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM + 4) {
            EnTeteSection(titre: "Résumé", sousTitre: labelPrincipalCategorie)

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
                ], spacing: LiquidGlassKit.espaceSM + 4) {
                    CarteMetrique(titre: "Min", valeur: formaterValeur(minimum), teinte: PaletteMat.negatif)
                    CarteMetrique(titre: "Max", valeur: formaterValeur(maximum), teinte: PaletteMat.positif)
                    CarteMetrique(titre: "Moyenne", valeur: formaterValeur(moyenne), teinte: PaletteMat.bleu)
                    carteTendance(tendance: tendance)
                }
            }
        }
        .glassSection()
        .opacity(apparition ? 1 : 0)
        .offset(y: apparition ? 0 : 15)
    }

    /// Carte tendance alignée sur le style plat de `CarteMetrique` — l'icône
    /// de tendance est conservée (icône porteuse de sens, D6).
    private func carteTendance(tendance: Tendance) -> some View {
        VStack(spacing: LiquidGlassKit.espaceXS + 2) {
            HStack(spacing: LiquidGlassKit.espaceXS) {
                Image(systemName: tendance.icone)
                    .font(.subheadline.weight(.bold))
                Text(tendance.label)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .foregroundStyle(tendance.couleur)
            Text("Tendance")
                .font(TypographieStats.labelMetrique)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, LiquidGlassKit.espaceSM + 4)
        .background(
            tendance.couleur.opacity(LiquidGlassKit.badgeFond),
            in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit, style: .continuous)
        )
    }

    // MARK: - Historique détaillé

    private var historiqueDetaille: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM + 4) {
            EnTeteSection(titre: "Historique des matchs",
                          sousTitre: libelleMatchs(pointsDonnees.count))

            if pointsDonnees.isEmpty {
                Text("Aucun match enregistré")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .padding(.vertical, LiquidGlassKit.espaceMD)
                    .frame(maxWidth: .infinity)
            } else {
                LazyVStack(spacing: LiquidGlassKit.espaceSM) {
                    ForEach(pointsDonnees.reversed()) { point in
                        ligneHistorique(point: point)
                    }
                }
            }
        }
        .glassSection()
        .opacity(apparition ? 1 : 0)
        .offset(y: apparition ? 0 : 10)
    }

    private func ligneHistorique(point: PointEvolution) -> some View {
        HStack(spacing: LiquidGlassKit.espaceSM + 4) {
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
            .frame(minWidth: Self.largeurColonneDate, alignment: .leading)

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

            // Valeur secondaire (rendement attaque, convention « .350 »)
            if let secondaire = point.valeurSecondaire, let labelSec = point.labelSecondaire {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formaterValeurSecondaire(secondaire))
                        .font(.body.weight(.semibold).monospacedDigit())
                        .foregroundStyle(PaletteMat.orange)
                    Text(labelSec)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: Self.largeurColonneSecondaire, alignment: .trailing)
            }
        }
        .padding(.horizontal, LiquidGlassKit.espaceSM + 4)
        .padding(.vertical, LiquidGlassKit.espaceSM + 2)
        .glassCard(cornerRadius: LiquidGlassKit.rayonPetit, ombre: false)
    }

    // MARK: - Labels par catégorie

    private var labelPrincipalCategorie: String {
        switch categorieSelectionnee {
        case .attaque:   return "Kills"
        case .service:   return "Aces"
        case .bloc:      return "Blocs totaux"
        case .reception: return "Efficacité réception"
        case .jeu:       return "Passes décisives"
        }
    }

    private var labelSecondaireCategorie: String {
        switch categorieSelectionnee {
        case .attaque:   return "Rendement"
        default:         return ""
        }
    }

    private var aLigneSecondaire: Bool {
        categorieSelectionnee == .attaque
    }

    private func libelleMatchs(_ nombre: Int) -> String {
        nombre > 1 ? "\(nombre) matchs" : "\(nombre) match"
    }

    // MARK: - Calculs

    private func calculerPoints() {
        // Filtre défensif par équipe : les @Query sont globales à la base
        let statsJoueur = toutesStats.filtreEquipe(codeEquipeActif).filter { $0.joueurID == joueur.id }

        // Construire un dictionnaire seanceID → Seance pour lookup rapide
        let seancesDict = Dictionary(uniqueKeysWithValues: toutesSeances.filtreEquipe(codeEquipeActif).compactMap { s -> (UUID, Seance)? in
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
        let points = paires.map { paire -> PointEvolution in
            let s = paire.stats
            let seance = paire.seance

            switch categorieSelectionnee {
            case .attaque:
                return PointEvolution(
                    date: seance.date,
                    valeurPrincipale: Double(s.kills),
                    // Fraction 0-1 (D1) — portée ×100 sur le graphique,
                    // formatée « .350 » (D2) dans l'historique.
                    valeurSecondaire: s.hittingPct,
                    adversaire: seance.adversaire,
                    labelPrincipal: "Kills",
                    labelSecondaire: "Rendement"
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
                    ? Double(s.receptionsReussies - s.erreursReception) / Double(s.receptionsTotales) * Self.echellePourcentage
                    : 0
                return PointEvolution(
                    date: seance.date,
                    valeurPrincipale: efficacite,
                    valeurSecondaire: nil,
                    adversaire: seance.adversaire,
                    labelPrincipal: "Efficacité réception",
                    labelSecondaire: nil
                )
            case .jeu:
                return PointEvolution(
                    date: seance.date,
                    valeurPrincipale: Double(s.passesDecisives),
                    valeurSecondaire: nil,
                    adversaire: seance.adversaire,
                    labelPrincipal: "Passes décisives",
                    labelSecondaire: nil
                )
            }
        }

        pointsDonnees = appliquerMoyenneMobile(points)
    }

    /// Moyenne mobile sur fenêtre glissante complète : renseignée à partir du
    /// `fenetreMoyenneMobile`-ième match (copies immuables, pas de mutation).
    private func appliquerMoyenneMobile(_ points: [PointEvolution]) -> [PointEvolution] {
        guard points.count >= Self.fenetreMoyenneMobile else { return points }
        let valeurs = points.map(\.valeurPrincipale)
        return points.enumerated().map { index, point in
            guard index >= Self.fenetreMoyenneMobile - 1 else { return point }
            let fenetre = valeurs[(index - Self.fenetreMoyenneMobile + 1)...index]
            var copie = point
            copie.moyenneMobile = fenetre.reduce(0, +) / Double(Self.fenetreMoyenneMobile)
            return copie
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
        let seuil = max(moyennePremiere * Self.seuilTendanceRelatif, Self.seuilTendanceAbsolu)

        if ecart > seuil { return .hausse }
        if ecart < -seuil { return .baisse }
        return .stable
    }

    /// Formatage de la valeur principale selon la catégorie (D2) :
    /// réception = pourcentage (valeur portée en 0-100), sinon compteur.
    private func formaterValeur(_ valeur: Double) -> String {
        switch categorieSelectionnee {
        case .reception:
            return FormatMetriques.pourcentage(valeur / Self.echellePourcentage)
        default:
            return FormatMetriques.points(valeur)
        }
    }

    /// D2 : le rendement attaque (seule valeur secondaire, fraction 0-1)
    /// s'affiche en convention volleyball « .350 » — jamais en pourcentage.
    private func formaterValeurSecondaire(_ valeur: Double) -> String {
        switch categorieSelectionnee {
        case .attaque: return FormatMetriques.hittingVolley(valeur)
        default:       return formaterValeur(valeur)
        }
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
