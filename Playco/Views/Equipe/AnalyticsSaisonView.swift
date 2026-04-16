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
        case efficacite   = "Efficacité"
        case performances = "Performances"

        var icone: String {
            switch self {
            case .resultats:    return "trophy.fill"
            case .efficacite:   return "chart.line.uptrend.xyaxis"
            case .performances: return "star.fill"
            }
        }
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
                case .efficacite:
                    sectionEfficacite
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
        HStack {
            VStack(alignment: .leading, spacing: LiquidGlassKit.espaceXS) {
                Text("Analytics saison")
                    .font(.title.weight(.bold))
                Text("Tendances et progression de l'équipe")
                    .font(.subheadline)
                    .foregroundStyle(PaletteMat.texteSecondaire)
            }
            Spacer()
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 32))
                .foregroundStyle(PaletteMat.bleu.opacity(0.6))
                .symbolRenderingMode(.hierarchical)
        }
    }

    // MARK: - Sélecteur onglet

    private var selecteurOnglet: some View {
        Picker("Onglet", selection: $ongletSelectionne) {
            ForEach(OngletAnalytics.allCases, id: \.self) { onglet in
                Label(onglet.rawValue, systemImage: onglet.icone)
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
                            Label("\(phase.typePhase.rawValue)\(phase.nom.isEmpty ? "" : " — \(phase.nom)")",
                                  systemImage: phase.typePhase.icone)
                                .tag(phase.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(LiquidGlassKit.espaceSM + 2)
                .glassSection()
            }
        }
    }

    // MARK: - Résultats

    private var sectionResultats: some View {
        VStack(spacing: LiquidGlassKit.espaceMD) {
            // Bilan V-D
            bilanVictoiresDefaites

            // Graphique évolution W/L cumulatif
            if matchsFiltres.count >= 2 {
                graphiqueResultatsCumulatifs
            }

            // Séries
            seriesSection
        }
    }

    private var bilanVictoiresDefaites: some View {
        let victoires = matchsFiltres.filter { $0.resultat == .victoire }.count
        let defaites = matchsFiltres.filter { $0.resultat == .defaite }.count
        let total = matchsFiltres.count
        let pctVictoire = total > 0 ? Double(victoires) / Double(total) * 100 : 0

        return LazyVGrid(columns: [
            GridItem(.flexible()), GridItem(.flexible()),
            GridItem(.flexible()), GridItem(.flexible())
        ], spacing: LiquidGlassKit.espaceSM + 4) {
            carteChiffre("Matchs", "\(total)", PaletteMat.bleu, "sportscourt.fill")
            carteChiffre("Victoires", "\(victoires)", PaletteMat.vert, "checkmark.circle.fill")
            carteChiffre("Défaites", "\(defaites)", .red, "xmark.circle.fill")
            carteChiffre("% Victoire", String(format: "%.0f%%", pctVictoire),
                         pctVictoire >= 50 ? PaletteMat.vert : .orange, "percent")
        }
    }

    private var graphiqueResultatsCumulatifs: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Label("Évolution victoires / défaites", systemImage: "chart.xyaxis.line")
                .font(.headline.weight(.semibold))

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
                .foregroundStyle(.red)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
            }
            .chartYAxisLabel("Cumulatif")
            .chartXAxisLabel("Match #")
            .frame(height: 200)
        }
        .padding(LiquidGlassKit.espaceMD)
        .glassCard(teinte: PaletteMat.vert, cornerRadius: LiquidGlassKit.rayonMoyen)
    }

    private var seriesSection: some View {
        let (serieActuelle, type) = calculerSerieActuelle()
        let plusLongueSerie = calculerPlusLongueSerie()

        return HStack(spacing: LiquidGlassKit.espaceSM + 4) {
            VStack(spacing: LiquidGlassKit.espaceSM) {
                Text("Série actuelle")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(PaletteMat.texteSecondaire)
                Text("\(serieActuelle)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(type == .victoire ? PaletteMat.vert : (type == .defaite ? .red : PaletteMat.texteSecondaire))
                    .contentTransition(.numericText())
                Text(type?.label ?? "—")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(type?.couleur ?? PaletteMat.texteTertiaire)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, LiquidGlassKit.espaceMD)
            .glassCard(cornerRadius: LiquidGlassKit.rayonPetit)

            VStack(spacing: LiquidGlassKit.espaceSM) {
                Text("Plus longue série V")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(PaletteMat.texteSecondaire)
                Text("\(plusLongueSerie)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(PaletteMat.vert)
                    .contentTransition(.numericText())
                Text("victoire\(plusLongueSerie > 1 ? "s" : "")")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PaletteMat.vert)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, LiquidGlassKit.espaceMD)
            .glassCard(cornerRadius: LiquidGlassKit.rayonPetit)
        }
    }

    // MARK: - Efficacité

    private var sectionEfficacite: some View {
        VStack(spacing: LiquidGlassKit.espaceMD) {
            if matchsFiltres.count >= 2 {
                graphiqueEfficaciteAttaque
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

    private var graphiqueEfficaciteAttaque: some View {
        let donnees = donneesEfficaciteParMatch()

        return VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Label("Efficacité attaque par match", systemImage: "flame.fill")
                .font(.headline.weight(.semibold))

            if donnees.isEmpty {
                Text("Aucune donnée d'attaque disponible")
                    .font(.caption)
                    .foregroundStyle(PaletteMat.texteTertiaire)
            } else {
                Chart(donnees, id: \.index) { point in
                    BarMark(
                        x: .value("Match", point.label),
                        y: .value("Hit%", point.valeur)
                    )
                    .foregroundStyle(point.valeur >= 0.250 ? PaletteMat.vert : PaletteMat.orange)
                    .cornerRadius(LiquidGlassKit.rayonMini)

                    if donnees.count >= 3 {
                        RuleMark(y: .value("Objectif", 0.250))
                            .foregroundStyle(.red.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text(".250")
                                    .font(.caption2)
                                    .foregroundStyle(.red.opacity(0.6))
                            }
                    }
                }
                .chartYAxisLabel("Hitting %")
                .frame(height: 200)
            }
        }
        .padding(LiquidGlassKit.espaceMD)
        .glassCard(teinte: PaletteMat.orange, cornerRadius: LiquidGlassKit.rayonMoyen)
    }

    private var graphiquePointsParMatch: some View {
        let donnees = donneesPointsParMatch()

        return VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Label("Points marqués par match", systemImage: "flame.fill")
                .font(.headline.weight(.semibold))

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
                .chartYAxisLabel("Points")
                .chartXAxisLabel("Match #")
                .frame(height: 200)
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
            icone: "flame.fill",
            couleur: PaletteMat.orange,
            joueursTries: joueursEquipe
                .filter { $0.pointsCalcules > 0 }
                .sorted { $0.pointsCalcules > $1.pointsCalcules },
            valeurLabel: { "\($0.pointsCalcules) pts" },
            secondaireLabel: { j in
                j.attaquesTotales > 0 ? String(format: "%.3f hit%%", j.pourcentageAttaque) : nil
            }
        )
    }

    private var topAces: some View {
        classementView(
            titre: "Meilleurs serveurs",
            icone: "tennisball.fill",
            couleur: PaletteMat.bleu,
            joueursTries: joueursEquipe
                .filter { $0.aces > 0 }
                .sorted { $0.aces > $1.aces },
            valeurLabel: { "\($0.aces) aces" },
            secondaireLabel: { j in
                j.servicesTotaux > 0 ? String(format: "%.0f%% err", Double(j.erreursService) / Double(j.servicesTotaux) * 100) : nil
            }
        )
    }

    private var topBloqueurs: some View {
        classementView(
            titre: "Meilleurs bloqueurs",
            icone: "hand.raised.fill",
            couleur: PaletteMat.violet,
            joueursTries: joueursEquipe
                .filter { $0.blocsTotaux > 0 }
                .sorted { $0.blocsTotaux > $1.blocsTotaux },
            valeurLabel: { "\($0.blocsTotaux) blocs" },
            secondaireLabel: { "\($0.blocsSeuls) solo / \($0.blocsAssistes) ass." }
        )
    }

    private func classementView(
        titre: String,
        icone: String,
        couleur: Color,
        joueursTries: [JoueurEquipe],
        valeurLabel: @escaping (JoueurEquipe) -> String,
        secondaireLabel: @escaping (JoueurEquipe) -> String?
    ) -> some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Label(titre, systemImage: icone)
                .font(.headline.weight(.semibold))
                .foregroundStyle(couleur)

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

    // MARK: - Composants

    private func carteChiffre(_ titre: String, _ valeur: String, _ couleur: Color, _ icone: String) -> some View {
        VStack(spacing: LiquidGlassKit.espaceSM) {
            Image(systemName: icone)
                .font(.system(size: 22))
                .foregroundStyle(couleur)
                .symbolRenderingMode(.hierarchical)
            Text(valeur)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
            Text(titre)
                .font(.caption2.weight(.medium))
                .foregroundStyle(PaletteMat.texteSecondaire)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LiquidGlassKit.espaceSM + 4)
        .glassCard(cornerRadius: LiquidGlassKit.rayonPetit)
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

    private func donneesEfficaciteParMatch() -> [PointGraphique] {
        matchsFiltres.enumerated().compactMap { i, match in
            let stats = statsFiltrees.filter { $0.seanceID == match.id }
            let ta = stats.reduce(0) { $0 + $1.tentativesAttaque }
            guard ta > 0 else { return nil }
            let k = stats.reduce(0) { $0 + $1.kills }
            let e = stats.reduce(0) { $0 + $1.erreursAttaque }
            let hit = Double(k - e) / Double(ta)
            let label = match.adversaire.isEmpty ? "M\(i+1)" : String(match.adversaire.prefix(6))
            return PointGraphique(index: i + 1, label: label, valeur: hit)
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
