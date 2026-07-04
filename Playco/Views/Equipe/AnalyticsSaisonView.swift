//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData
import Charts

/// Tableau de bord analytics — tendances sur la saison
struct AnalyticsSaisonView: View {
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Query(filter: #Predicate<Seance> { $0.typeSeanceRaw == "Match" && $0.estArchivee == false },
           sort: \Seance.date) private var seances: [Seance]
    @Query private var statsMatchs: [StatsMatch]
    @Query(filter: #Predicate<JoueurEquipe> { $0.estActif == true },
           sort: \JoueurEquipe.numero) private var joueurs: [JoueurEquipe]
    @Query(sort: \PhaseSaison.dateDebut) private var toutesPhaseSaison: [PhaseSaison]

    @State private var matchsEquipe: [Seance] = []
    @State private var statsEquipe: [StatsMatch] = []
    @State private var joueursEquipe: [JoueurEquipe] = []
    @State private var phasesEquipe: [PhaseSaison] = []
    @State private var phaseSelectionneeID: UUID? = nil
    @State private var ongletSelectionne: OngletAnalytics = .resultats

    /// Matchs filtrés par phase de saison sélectionnée
    private var matchsFiltres: [Seance] {
        guard let phaseID = phaseSelectionneeID,
              let phase = phasesEquipe.first(where: { $0.id == phaseID }) else {
            return matchsEquipe
        }
        return matchsEquipe.filter { $0.date >= phase.dateDebut && $0.date <= phase.dateFin }
    }

    /// Stats filtrées par les matchs de la phase sélectionnée
    private var statsFiltrees: [StatsMatch] {
        let ids = Set(matchsFiltres.map(\.id))
        return statsEquipe.filter { ids.contains($0.seanceID) }
    }

    enum OngletAnalytics: String, CaseIterable {
        case resultats    = "Résultats"
        case attaque      = "Attaque"
        case performances = "Performances"
    }

    /// Seuils métier de la vue (pas de magic numbers dans le body).
    private enum SeuilsAnalytics {
        /// Objectif de rendement attaque par match (convention volleyball « .250 »).
        static let objectifRendement = 0.250
        /// Bilan équilibré : au moins une victoire sur deux.
        static let ratioVictoiresEquilibre = 0.5
        /// Nombre minimal de matchs pour tracer une tendance.
        static let minMatchsTendance = 2
        /// Nombre minimal de matchs pour afficher la ligne d'objectif.
        static let minMatchsObjectif = 3
        /// Hauteur uniforme des graphiques Swift Charts.
        static let hauteurGraphique: CGFloat = 200
    }

    var body: some View {
        ScrollView {
            VStack(spacing: LiquidGlassKit.espaceLG) {
                entete
                filtrePhase
                selecteurOnglet

                switch ongletSelectionne {
                case .resultats:
                    sectionResultats
                case .attaque:
                    sectionAttaque
                case .performances:
                    sectionPerformances
                }
            }
            .padding(LiquidGlassKit.espaceLG)
        }
        .navigationTitle("Analytics saison")
        .onAppear { mettreAJour() }
        .onChange(of: codeEquipeActif) { _, _ in mettreAJour() }
    }

    // MARK: - En-tête

    private var entete: some View {
        EnTeteSection(
            titre: "Analytics saison",
            sousTitre: "Tendances et progression de l'équipe"
        )
    }

    // MARK: - Sélecteur onglet

    private var selecteurOnglet: some View {
        Picker("Onglet", selection: $ongletSelectionne) {
            ForEach(OngletAnalytics.allCases, id: \.self) { onglet in
                Text(onglet.rawValue)
                    .tag(onglet)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Filtre phase

    private var filtrePhase: some View {
        Group {
            if !phasesEquipe.isEmpty {
                HStack(spacing: LiquidGlassKit.espaceSM) {
                    Text("Phase")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PaletteMat.texteSecondaire)
                    Picker("Phase", selection: $phaseSelectionneeID) {
                        Text("Toute la saison")
                            .tag(nil as UUID?)
                        ForEach(phasesEquipe) { phase in
                            Text("\(phase.typePhase.rawValue)\(phase.nom.isEmpty ? "" : " — \(phase.nom)")")
                                .tag(phase.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(minHeight: 44)
                }
                .glassSection()
            }
        }
    }

    // MARK: - Résultats

    private var sectionResultats: some View {
        Group {
            if matchsFiltres.isEmpty {
                ContentUnavailableView(
                    "Aucun match",
                    systemImage: "sportscourt",
                    description: Text("Créez un match dans la section Matchs pour suivre les résultats de la saison.")
                )
            } else {
                VStack(spacing: LiquidGlassKit.espaceMD) {
                    // Bilan V-D
                    bilanVictoiresDefaites

                    // Graphique évolution W/L cumulatif
                    if matchsFiltres.count >= SeuilsAnalytics.minMatchsTendance {
                        graphiqueResultatsCumulatifs
                    }

                    // Séries
                    seriesSection
                }
            }
        }
    }

    private var bilanVictoiresDefaites: some View {
        let victoires = matchsFiltres.filter { $0.resultat == .victoire }.count
        let defaites = matchsFiltres.filter { $0.resultat == .defaite }.count
        let total = matchsFiltres.count
        let ratioVictoires = total > 0 ? Double(victoires) / Double(total) : 0

        return LazyVGrid(columns: [
            GridItem(.flexible()), GridItem(.flexible()),
            GridItem(.flexible()), GridItem(.flexible())
        ], spacing: LiquidGlassKit.espaceSM + 4) {
            CarteMetrique(titre: "Matchs", valeur: "\(total)", teinte: PaletteMat.bleu)
            CarteMetrique(titre: "Victoires", valeur: "\(victoires)", teinte: PaletteMat.positif)
            CarteMetrique(titre: "Défaites", valeur: "\(defaites)", teinte: PaletteMat.negatif)
            CarteMetrique(
                titre: "% victoires",
                valeur: FormatMetriques.pourcentage(ratioVictoires, decimales: 0),
                teinte: ratioVictoires >= SeuilsAnalytics.ratioVictoiresEquilibre
                    ? PaletteMat.positif : PaletteMat.attention
            )
        }
    }

    private var graphiqueResultatsCumulatifs: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            EnTeteSection(
                titre: "Évolution victoires / défaites",
                sousTitre: "Victoires en vert, défaites en rouge pointillé"
            )

            let donnees = donneesResultatsCumulatifs()

            Chart(donnees, id: \.index) { point in
                LineMark(
                    x: .value("Match", point.index),
                    y: .value("Victoires", point.victoires)
                )
                .foregroundStyle(PaletteMat.vert)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Match", point.index),
                    y: .value("Victoires", point.victoires)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [PaletteMat.vert.opacity(0.2), PaletteMat.vert.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Match", point.index),
                    y: .value("Défaites", point.defaites)
                )
                .foregroundStyle(PaletteMat.negatif)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
            }
            .chartYAxisLabel("Total cumulé")
            .chartXAxisLabel("Nº de match")
            .frame(height: SeuilsAnalytics.hauteurGraphique)
        }
        .padding(LiquidGlassKit.espaceMD)
        .glassCard(teinte: PaletteMat.vert, cornerRadius: LiquidGlassKit.rayonMoyen)
    }

    private var seriesSection: some View {
        let (serieActuelle, type) = calculerSerieActuelle()
        let plusLongueSerie = calculerPlusLongueSerie()

        return HStack(spacing: LiquidGlassKit.espaceSM + 4) {
            CarteMetrique(
                titre: "Série actuelle",
                valeur: "\(serieActuelle)",
                sousTitre: type.map { "\($0.label)\(serieActuelle > 1 ? "s" : "") de suite" } ?? "—",
                teinte: couleurSerie(type)
            )
            CarteMetrique(
                titre: "Meilleure série de victoires",
                valeur: "\(plusLongueSerie)",
                sousTitre: "victoire\(plusLongueSerie > 1 ? "s" : "") de suite",
                teinte: PaletteMat.positif
            )
        }
    }

    /// Couleur sémantique d'une série selon son type (jamais de .red/.orange système).
    private func couleurSerie(_ type: ResultatMatch?) -> Color {
        switch type {
        case .victoire: return PaletteMat.positif
        case .defaite:  return PaletteMat.negatif
        case .nul:      return PaletteMat.attention
        case nil:       return PaletteMat.texteTertiaire
        }
    }

    // MARK: - Attaque

    private var sectionAttaque: some View {
        VStack(spacing: LiquidGlassKit.espaceMD) {
            if matchsFiltres.count >= SeuilsAnalytics.minMatchsTendance {
                graphiqueRendementAttaque
                graphiquePointsParMatch
            } else {
                ContentUnavailableView(
                    "Pas assez de données",
                    systemImage: "chart.line.downtrend.xyaxis",
                    description: Text("Au moins 2 matchs sont nécessaires pour afficher les tendances.")
                )
            }
        }
    }

    private var graphiqueRendementAttaque: some View {
        let donnees = donneesRendementParMatch()

        return VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            EnTeteSection(
                titre: "Rendement attaque par match",
                sousTitre: "Objectif \(FormatMetriques.hittingVolley(SeuilsAnalytics.objectifRendement))"
            )

            if donnees.isEmpty {
                Text("Aucune donnée d'attaque disponible")
                    .font(.caption)
                    .foregroundStyle(PaletteMat.texteTertiaire)
            } else {
                Chart(donnees, id: \.index) { point in
                    BarMark(
                        x: .value("Match", point.label),
                        y: .value("Rendement attaque", point.valeur)
                    )
                    .foregroundStyle(point.valeur >= SeuilsAnalytics.objectifRendement
                                     ? PaletteMat.positif : PaletteMat.attention)
                    .cornerRadius(LiquidGlassKit.rayonMini)

                    if donnees.count >= SeuilsAnalytics.minMatchsObjectif {
                        RuleMark(y: .value("Objectif", SeuilsAnalytics.objectifRendement))
                            .foregroundStyle(PaletteMat.negatif.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text(FormatMetriques.hittingVolley(SeuilsAnalytics.objectifRendement))
                                    .font(.caption2)
                                    .foregroundStyle(PaletteMat.negatif.opacity(0.6))
                            }
                    }
                }
                .chartYAxisLabel("Rendement attaque")
                .chartXAxisLabel("Match")
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let ratio = value.as(Double.self) {
                                Text(FormatMetriques.hittingVolley(ratio))
                            }
                        }
                    }
                }
                .frame(height: SeuilsAnalytics.hauteurGraphique)
            }
        }
        .padding(LiquidGlassKit.espaceMD)
        .glassCard(teinte: PaletteMat.orange, cornerRadius: LiquidGlassKit.rayonMoyen)
    }

    private var graphiquePointsParMatch: some View {
        let donnees = donneesPointsParMatch()

        return VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            EnTeteSection(titre: "Points marqués par match")

            if donnees.isEmpty {
                Text("Aucune donnée disponible")
                    .font(.caption)
                    .foregroundStyle(PaletteMat.texteTertiaire)
            } else {
                Chart(donnees, id: \.index) { point in
                    LineMark(
                        x: .value("Match", point.index),
                        y: .value("Points", point.valeur)
                    )
                    .foregroundStyle(PaletteMat.bleu)
                    .interpolationMethod(.catmullRom)
                    .symbol(Circle())

                    AreaMark(
                        x: .value("Match", point.index),
                        y: .value("Points", point.valeur)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [PaletteMat.bleu.opacity(0.2), PaletteMat.bleu.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .chartYAxisLabel("Points marqués")
                .chartXAxisLabel("Nº de match")
                .frame(height: SeuilsAnalytics.hauteurGraphique)
            }
        }
        .padding(LiquidGlassKit.espaceMD)
        .glassCard(teinte: PaletteMat.bleu, cornerRadius: LiquidGlassKit.rayonMoyen)
    }

    // MARK: - Performances

    private var sectionPerformances: some View {
        VStack(spacing: LiquidGlassKit.espaceMD) {
            topMarqueurs
            topAces
            topBloqueurs
        }
    }

    private var topMarqueurs: some View {
        classementView(
            titre: "Meilleurs marqueurs",
            couleur: PaletteMat.orange,
            joueursTries: joueursEquipe
                .filter { $0.pointsCalcules > 0 }
                .sorted { $0.pointsCalcules > $1.pointsCalcules },
            valeurLabel: { "\($0.pointsCalcules) pts" },
            secondaireLabel: { j in
                j.attaquesTotales > 0
                    ? "Rendement \(FormatMetriques.hittingVolley(j.pourcentageAttaque))"
                    : nil
            }
        )
    }

    private var topAces: some View {
        classementView(
            titre: "Meilleurs serveurs",
            couleur: PaletteMat.bleu,
            joueursTries: joueursEquipe
                .filter { $0.aces > 0 }
                .sorted { $0.aces > $1.aces },
            valeurLabel: { "\($0.aces) aces" },
            secondaireLabel: { j in
                guard j.servicesTotaux > 0 else { return nil }
                let ratioErreurs = Double(j.erreursService) / Double(j.servicesTotaux)
                return "\(FormatMetriques.pourcentage(ratioErreurs, decimales: 0)) err. service"
            }
        )
    }

    private var topBloqueurs: some View {
        classementView(
            titre: "Meilleurs bloqueurs",
            couleur: PaletteMat.violet,
            joueursTries: joueursEquipe
                .filter { $0.blocsTotaux > 0 }
                .sorted { $0.blocsTotaux > $1.blocsTotaux },
            valeurLabel: { "\(FormatMetriques.points($0.blocsTotaux)) blocs" },
            secondaireLabel: { "\($0.blocsSeuls) seuls · \($0.blocsAssistes) assistés" }
        )
    }

    private func classementView(
        titre: String,
        couleur: Color,
        joueursTries: [JoueurEquipe],
        valeurLabel: @escaping (JoueurEquipe) -> String,
        secondaireLabel: @escaping (JoueurEquipe) -> String?
    ) -> some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            EnTeteSection(titre: titre)

            if joueursTries.isEmpty {
                Text("Aucune donnée")
                    .font(.caption)
                    .foregroundStyle(PaletteMat.texteTertiaire)
                    .padding(.vertical, LiquidGlassKit.espaceSM)
            } else {
                ForEach(Array(joueursTries.prefix(5).enumerated()), id: \.element.id) { index, joueur in
                    HStack(spacing: LiquidGlassKit.espaceSM + 4) {
                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(PaletteMat.texteSecondaire)
                            .frame(width: 20)

                        ZStack {
                            Circle()
                                .fill(joueur.poste.couleur.opacity(0.1))
                                .frame(width: 32, height: 32)
                            Text("#\(joueur.numero)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(joueur.poste.couleur)
                        }

                        Text(joueur.nomComplet)
                            .font(.subheadline)
                            .lineLimit(1)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(valeurLabel(joueur))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(couleur)
                            if let sec = secondaireLabel(joueur) {
                                Text(sec)
                                    .font(.caption2)
                                    .foregroundStyle(PaletteMat.texteSecondaire)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(LiquidGlassKit.espaceMD)
        .glassCard(teinte: couleur, cornerRadius: LiquidGlassKit.rayonMoyen)
    }

    // MARK: - Données graphiques

    private struct PointCumulatif {
        let index: Int
        let victoires: Int
        let defaites: Int
    }

    private struct PointGraphique {
        let index: Int
        let label: String
        let valeur: Double
    }

    private func donneesResultatsCumulatifs() -> [PointCumulatif] {
        var v = 0, d = 0
        return matchsFiltres.enumerated().map { i, match in
            if match.resultat == .victoire { v += 1 }
            else if match.resultat == .defaite { d += 1 }
            return PointCumulatif(index: i + 1, victoires: v, defaites: d)
        }
    }

    private func donneesRendementParMatch() -> [PointGraphique] {
        matchsFiltres.enumerated().compactMap { i, match in
            let stats = statsFiltrees.filter { $0.seanceID == match.id }
            let tentatives = stats.reduce(0) { $0 + $1.tentativesAttaque }
            guard tentatives > 0 else { return nil }
            let kills = stats.reduce(0) { $0 + $1.kills }
            let erreurs = stats.reduce(0) { $0 + $1.erreursAttaque }
            let rendement = MetriquesVolley.rendementAttaque(
                kills: kills, erreurs: erreurs, tentatives: tentatives
            )
            let label = match.adversaire.isEmpty ? "M\(i+1)" : String(match.adversaire.prefix(6))
            return PointGraphique(index: i + 1, label: label, valeur: rendement)
        }
    }

    private func donneesPointsParMatch() -> [PointGraphique] {
        matchsFiltres.enumerated().compactMap { i, match in
            let stats = statsFiltrees.filter { $0.seanceID == match.id }
            let pts = stats.reduce(0) { $0 + $1.points }
            guard pts > 0 else { return nil }
            return PointGraphique(index: i + 1, label: "M\(i+1)", valeur: Double(pts))
        }
    }

    // MARK: - Calculs séries

    private func calculerSerieActuelle() -> (Int, ResultatMatch?) {
        let triee = matchsFiltres.sorted { $0.date > $1.date }
        guard let premier = triee.first?.resultat else { return (0, nil) }
        var count = 0
        for match in triee {
            if match.resultat == premier { count += 1 }
            else { break }
        }
        return (count, premier)
    }

    private func calculerPlusLongueSerie() -> Int {
        var maxSerie = 0, serie = 0
        for match in matchsFiltres {
            if match.resultat == .victoire {
                serie += 1
                maxSerie = max(maxSerie, serie)
            } else {
                serie = 0
            }
        }
        return maxSerie
    }

    // MARK: - Mise à jour

    private func mettreAJour() {
        matchsEquipe = seances.filtreEquipe(codeEquipeActif)
        statsEquipe = statsMatchs.filtreEquipe(codeEquipeActif)
        joueursEquipe = joueurs.filtreEquipe(codeEquipeActif)
        phasesEquipe = toutesPhaseSaison.filtreEquipe(codeEquipeActif)
    }
}
