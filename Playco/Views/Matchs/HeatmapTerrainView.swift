//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

// MARK: - Modele de donnees Heatmap

struct DonneesHeatmap {
    var zones: [Int: Int]  // numero de zone (1-6) -> nombre d'actions
    var categorie: CategorieHeatmap

    enum CategorieHeatmap: String, CaseIterable {
        case attaque   = "Attaque"
        case reception = "Réception"
        case service   = "Service"
        case bloc      = "Bloc"

        var icone: String {
            switch self {
            case .attaque:   return "flame.fill"
            case .reception: return "arrow.down.to.line"
            case .service:   return "arrow.up.forward"
            case .bloc:      return "hand.raised.fill"
            }
        }

        var couleurAccent: Color {
            switch self {
            case .attaque:   return PaletteMat.orange
            case .reception: return PaletteMat.bleu
            case .service:   return PaletteMat.violet
            case .bloc:      return PaletteMat.vert
            }
        }
    }

    /// Total de toutes les zones
    var total: Int {
        zones.values.reduce(0, +)
    }

    /// Valeur maximale parmi les zones
    var maxZone: Int {
        zones.values.max() ?? 0
    }

    /// Donnees vides pour placeholder
    static var vide: DonneesHeatmap {
        DonneesHeatmap(zones: [:], categorie: .attaque)
    }
}

// MARK: - HeatmapTerrainView

struct HeatmapTerrainView: View {
    @Binding var donnees: DonneesHeatmap
    @State private var categorieSelectionnee: DonneesHeatmap.CategorieHeatmap = .attaque

    var body: some View {
        VStack(spacing: 16) {
            // Selecteur de categorie
            selecteurCategorie

            // Terrain heatmap (demi-terrain, ratio ~1:1 pour un seul cote)
            terrainHeatmap
                .aspectRatio(1.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .glassCard(teinte: categorieSelectionnee.couleurAccent, cornerRadius: 16)

            // Legende
            legendeCouleur
        }
    }

    // MARK: - Selecteur categorie

    private var selecteurCategorie: some View {
        Picker("Catégorie", selection: $categorieSelectionnee) {
            ForEach(DonneesHeatmap.CategorieHeatmap.allCases, id: \.self) { cat in
                Label(cat.rawValue, systemImage: cat.icone)
                    .tag(cat)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: categorieSelectionnee) { _, nouvelle in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                donnees.categorie = nouvelle
            }
        }
    }

    // MARK: - Terrain Canvas (demi-terrain)

    private var terrainHeatmap: some View {
        Canvas { context, size in
            let W = size.width, H = size.height
            let mx = W * 0.05, my = H * 0.05
            let cl = mx, cr = W - mx, ct = my, cb = H - my
            let cw = cr - cl, ch = cb - ct

            // Filet en haut
            let filetY = ct
            // Ligne d'attaque a 1/3 du terrain (3m sur 9m)
            let ligneAttaqueY = ct + ch * (1.0 / 3.0)

            // --- Fond terrain (parquet simplifie) ---
            let fondCourt = Color(hex: "#D4B87A")
            var bgPath = Path(); bgPath.addRect(CGRect(x: 0, y: 0, width: W, height: H))
            context.fill(bgPath, with: .color(Color(hex: "#1E5599")))

            let courtRect = CGRect(x: cl, y: ct, width: cw, height: ch)
            var courtPath = Path(); courtPath.addRect(courtRect)
            context.fill(courtPath, with: .color(fondCourt))

            // Zone 3m (avant) plus foncee
            let brunFonce = Color(hex: "#6B3A1F")
            let zone3m = CGRect(x: cl, y: ct, width: cw, height: ligneAttaqueY - ct)
            var z3Path = Path(); z3Path.addRect(zone3m)
            context.fill(z3Path, with: .color(brunFonce))

            // Texture parquet
            let parquetLine = Color(hex: "#C4A868").opacity(0.35)
            let espacement = max(cw * 0.025, 8)
            for x in stride(from: cl, through: cr, by: espacement) {
                var lp = Path()
                lp.move(to: CGPoint(x: x, y: ct))
                lp.addLine(to: CGPoint(x: x, y: cb))
                context.stroke(lp, with: .color(parquetLine), style: StrokeStyle(lineWidth: 0.5))
            }

            // --- Heatmap zones ---
            let maxVal = max(donnees.maxZone, 1)

            // Positions des 6 zones (demi-terrain vu du dessus, filet en haut)
            // Zone 4: avant-gauche, Zone 3: avant-centre, Zone 2: avant-droite
            // Zone 5: arriere-gauche, Zone 6: arriere-centre, Zone 1: arriere-droite
            let tiers = cw / 3.0
            let hautAvant = ligneAttaqueY - ct
            let hautArriere = cb - ligneAttaqueY

            let zonesRects: [(Int, CGRect)] = [
                (4, CGRect(x: cl,             y: ct,             width: tiers, height: hautAvant)),
                (3, CGRect(x: cl + tiers,     y: ct,             width: tiers, height: hautAvant)),
                (2, CGRect(x: cl + tiers * 2, y: ct,             width: tiers, height: hautAvant)),
                (5, CGRect(x: cl,             y: ligneAttaqueY,  width: tiers, height: hautArriere)),
                (6, CGRect(x: cl + tiers,     y: ligneAttaqueY,  width: tiers, height: hautArriere)),
                (1, CGRect(x: cl + tiers * 2, y: ligneAttaqueY,  width: tiers, height: hautArriere)),
            ]

            for (zone, rect) in zonesRects {
                let count = donnees.zones[zone] ?? 0
                let intensite = Double(count) / Double(maxVal)

                // Gradient de couleur: vert -> jaune -> orange -> rouge
                let couleur = couleurHeatmap(intensite: intensite)
                let opacite = count > 0 ? 0.25 + intensite * 0.50 : 0.0

                var zonePath = Path(); zonePath.addRect(rect)
                context.fill(zonePath, with: .color(couleur.opacity(opacite)))

                // Nombre d'actions au centre de la zone
                let centre = CGPoint(x: rect.midX, y: rect.midY)
                if count > 0 {
                    let taillePolice = min(rect.width * 0.30, 36.0)
                    context.draw(
                        Text("\(count)")
                            .font(.system(size: taillePolice, weight: .bold, design: .rounded))
                            .foregroundStyle(.white),
                        at: centre
                    )
                }

                // Label de zone (coin superieur gauche)
                let tailleLabel = min(rect.width * 0.16, 14.0)
                let coinLabel = CGPoint(x: rect.minX + tailleLabel, y: rect.minY + tailleLabel)
                let estAvant = (zone == 2 || zone == 3 || zone == 4)
                let couleurLabel: Color = estAvant ? .white.opacity(0.45) : Color(hex: "#5A3A1A").opacity(0.35)
                context.draw(
                    Text("Z\(zone)")
                        .font(.system(size: tailleLabel, weight: .semibold, design: .rounded))
                        .foregroundStyle(couleurLabel),
                    at: coinLabel
                )
            }

            // --- Lignes blanches ---
            let lw = max(cw * 0.004, 1.5)

            // Contour
            context.stroke(Path(courtRect), with: .color(.white), lineWidth: lw * 1.2)

            // Ligne d'attaque 3m
            var laPath = Path()
            laPath.move(to: CGPoint(x: cl, y: ligneAttaqueY))
            laPath.addLine(to: CGPoint(x: cr, y: ligneAttaqueY))
            context.stroke(laPath, with: .color(.white), lineWidth: lw)

            // Separateurs de zones (verticaux, subtils)
            for i in 1..<3 {
                let x = cl + tiers * CGFloat(i)
                var sep = Path()
                sep.move(to: CGPoint(x: x, y: ct))
                sep.addLine(to: CGPoint(x: x, y: cb))
                context.stroke(sep, with: .color(.white.opacity(0.35)),
                               style: StrokeStyle(lineWidth: lw * 0.7, dash: [6, 4]))
            }

            // Filet (en haut)
            let netLw = max(cw * 0.010, 5.0)
            var filetPath = Path()
            filetPath.move(to: CGPoint(x: cl - mx * 0.3, y: filetY))
            filetPath.addLine(to: CGPoint(x: cr + mx * 0.3, y: filetY))
            context.stroke(filetPath, with: .color(.white), lineWidth: netLw)

            // Label "Filet"
            let labelFS = min(ch * 0.05, 11.0)
            context.draw(
                Text("Filet")
                    .font(.system(size: labelFS, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55)),
                at: CGPoint(x: W / 2, y: filetY - my * 0.5)
            )

            // Label "3 m"
            context.draw(
                Text("3 m")
                    .font(.system(size: labelFS, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.40)),
                at: CGPoint(x: cr + mx * 0.55, y: ligneAttaqueY)
            )
        }
    }

    // MARK: - Legende

    private var legendeCouleur: some View {
        HStack(spacing: 12) {
            Text("Intensité :")
                .font(.caption.weight(.medium))
                .foregroundStyle(PaletteMat.texteSecondaire)

            HStack(spacing: 3) {
                ForEach(0..<20, id: \.self) { i in
                    let intensite = Double(i) / 19.0
                    RoundedRectangle(cornerRadius: 2)
                        .fill(couleurHeatmap(intensite: intensite))
                        .frame(width: 10, height: 16)
                }
            }
            .clipShape(Capsule())

            HStack(spacing: 16) {
                Text("Faible")
                    .font(.caption2)
                    .foregroundStyle(PaletteMat.texteTertiaire)
                Spacer()
                Text("Élevée")
                    .font(.caption2)
                    .foregroundStyle(PaletteMat.texteTertiaire)
            }
            .frame(maxWidth: 100)
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Couleur heatmap selon intensite (0.0 -> 1.0)

    private func couleurHeatmap(intensite: Double) -> Color {
        let i = max(0, min(1, intensite))
        if i < 0.33 {
            // Vert -> Jaune
            let t = i / 0.33
            return Color(
                red: t,
                green: 0.75 + t * 0.25,
                blue: 0.2 * (1 - t)
            )
        } else if i < 0.66 {
            // Jaune -> Orange
            let t = (i - 0.33) / 0.33
            return Color(
                red: 1.0,
                green: 1.0 - t * 0.4,
                blue: 0
            )
        } else {
            // Orange -> Rouge
            let t = (i - 0.66) / 0.34
            return Color(
                red: 1.0,
                green: 0.6 - t * 0.5,
                blue: t * 0.05
            )
        }
    }
}

// MARK: - HeatmapEquipeView

struct HeatmapEquipeView: View {
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Query private var joueurs: [JoueurEquipe]
    @Query private var statsMatchs: [StatsMatch]
    @Query private var tousPoints: [PointMatch]
    @Query(filter: #Predicate<Seance> { $0.typeSeanceRaw == "Match" && $0.estArchivee == false },
           sort: \Seance.date, order: .reverse) private var seances: [Seance]

    @State private var joueurSelectionneID: UUID? = nil
    @State private var seanceSelectionneeID: UUID? = nil
    @State private var setSelectionne: Int? = nil
    @State private var donneesHeatmap: DonneesHeatmap = .vide
    @State private var joueursEquipe: [JoueurEquipe] = []
    @State private var pointsEquipe: [PointMatch] = []
    @State private var statsEquipe: [StatsMatch] = []
    @State private var seancesEquipe: [Seance] = []

    var body: some View {
        ScrollView {
            VStack(spacing: LiquidGlassKit.espaceLG) {
                titreSection
                filtresSection
                HeatmapTerrainView(donnees: $donneesHeatmap)
                    .padding(.horizontal, LiquidGlassKit.espaceXS)
                resumeStats
            }
            .padding(LiquidGlassKit.espaceLG)
        }
        .onAppear { mettreAJour() }
        .onChange(of: codeEquipeActif) { _, _ in mettreAJour() }
        .onChange(of: joueurSelectionneID) { _, _ in recalculerAvecAnimation() }
        .onChange(of: seanceSelectionneeID) { _, _ in recalculerAvecAnimation() }
        .onChange(of: setSelectionne) { _, _ in recalculerAvecAnimation() }
        .onChange(of: donneesHeatmap.categorie) { _, _ in recalculerAvecAnimation() }
    }

    // MARK: - Titre

    private var titreSection: some View {
        HStack {
            Image(systemName: "map.fill")
                .font(.title2)
                .foregroundStyle(PaletteMat.orange)
                .symbolRenderingMode(.hierarchical)
            Text("Heatmap terrain")
                .font(.title2.weight(.bold))
            Spacer()
        }
    }

    // MARK: - Filtres

    private var filtresSection: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            // Filtre match
            HStack(spacing: LiquidGlassKit.espaceSM) {
                filtreLabel("Match")
                Picker("Match", selection: $seanceSelectionneeID) {
                    Text("Tous les matchs")
                        .tag(nil as UUID?)
                    ForEach(seancesEquipe) { seance in
                        Text("\(seance.nom) — \(seance.date.formatCourt())")
                            .tag(seance.id as UUID?)
                    }
                }
                .pickerStyle(.menu)
            }

            HStack(spacing: LiquidGlassKit.espaceMD) {
                // Filtre joueur
                HStack(spacing: LiquidGlassKit.espaceSM) {
                    filtreLabel("Joueur")
                    Picker("Joueur", selection: $joueurSelectionneID) {
                        Text("Équipe complète")
                            .tag(nil as UUID?)
                        ForEach(joueursEquipe.sorted(by: { $0.numero < $1.numero })) { joueur in
                            Text("#\(joueur.numero) \(joueur.prenom)")
                                .tag(joueur.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Filtre set
                HStack(spacing: LiquidGlassKit.espaceSM) {
                    filtreLabel("Set")
                    Picker("Set", selection: $setSelectionne) {
                        Text("Tous")
                            .tag(nil as Int?)
                        ForEach(1...5, id: \.self) { s in
                            Text("Set \(s)")
                                .tag(s as Int?)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .padding(LiquidGlassKit.espaceSM + 2)
        .glassSection()
    }

    private func filtreLabel(_ texte: String) -> some View {
        Text(texte)
            .font(.caption.weight(.semibold))
            .foregroundStyle(PaletteMat.texteSecondaire)
    }

    // MARK: - Resume stats

    private var resumeStats: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM + 4) {
            Text("Résumé — \(donneesHeatmap.categorie.rawValue)")
                .font(.headline.weight(.semibold))
                .foregroundStyle(PaletteMat.textePrincipal)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: LiquidGlassKit.espaceSM + 4) {
                carteResume(titre: "Total", valeur: "\(donneesHeatmap.total)", icone: "sum")
                carteResume(titre: "Zone max", valeur: zoneMaxLabel, icone: "arrow.up.circle.fill")
                carteResume(titre: "Zone min", valeur: zoneMinLabel, icone: "arrow.down.circle.fill")
            }

            if donneesHeatmap.total > 0 {
                repartitionZones
            }
        }
        .padding(LiquidGlassKit.espaceMD)
        .glassCard(teinte: donneesHeatmap.categorie.couleurAccent, cornerRadius: LiquidGlassKit.rayonMoyen)
    }

    private func carteResume(titre: String, valeur: String, icone: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icone)
                .font(.title3)
                .foregroundStyle(donneesHeatmap.categorie.couleurAccent)
                .symbolRenderingMode(.hierarchical)
            Text(valeur)
                .font(.title3.weight(.bold))
                .contentTransition(.numericText())
            Text(titre)
                .font(.caption.weight(.medium))
                .foregroundStyle(PaletteMat.texteSecondaire)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .glassSection()
    }

    private var repartitionZones: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Text("Répartition par zone")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PaletteMat.texteSecondaire)

            ForEach(1...6, id: \.self) { zone in
                let count = donneesHeatmap.zones[zone] ?? 0
                let pct = donneesHeatmap.total > 0
                    ? Double(count) / Double(donneesHeatmap.total) : 0

                HStack(spacing: 10) {
                    Text("Zone \(zone)")
                        .font(.caption.weight(.semibold))
                        .frame(width: 55, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.12))

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            donneesHeatmap.categorie.couleurAccent.opacity(0.6),
                                            donneesHeatmap.categorie.couleurAccent
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * pct)
                                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: pct)
                        }
                    }
                    .frame(height: 14)

                    Text("\(count)")
                        .font(.caption.weight(.bold))
                        .frame(width: 30, alignment: .trailing)
                        .contentTransition(.numericText())

                    Text("\(Int(pct * 100))%")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(PaletteMat.texteSecondaire)
                        .frame(width: 35, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Computed labels

    private var zoneMaxLabel: String {
        guard donneesHeatmap.total > 0 else { return "—" }
        let maxEntry = donneesHeatmap.zones.max(by: { $0.value < $1.value })
        return maxEntry.map { "Z\($0.key) (\($0.value))" } ?? "—"
    }

    private var zoneMinLabel: String {
        guard donneesHeatmap.total > 0 else { return "—" }
        let zonesAvecDonnees = donneesHeatmap.zones.filter { $0.value > 0 }
        guard !zonesAvecDonnees.isEmpty else { return "—" }
        let minEntry = zonesAvecDonnees.min(by: { $0.value < $1.value })
        return minEntry.map { "Z\($0.key) (\($0.value))" } ?? "—"
    }

    // MARK: - Logique de mise a jour

    private func mettreAJour() {
        joueursEquipe = joueurs.filtreEquipe(codeEquipeActif).filter { $0.estActif }
        pointsEquipe = tousPoints.filtreEquipe(codeEquipeActif)
        statsEquipe = statsMatchs.filtreEquipe(codeEquipeActif)
        seancesEquipe = seances.filtreEquipe(codeEquipeActif)
        recalculerHeatmap()
    }

    private func recalculerAvecAnimation() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            recalculerHeatmap()
        }
    }

    /// Recalcule les données du heatmap à partir des vrais PointMatch.
    /// Fallback sur distribution simulée si aucun point n'a de zone assignée.
    private func recalculerHeatmap() {
        let categorie = donneesHeatmap.categorie

        // Filtrer les PointMatch selon les critères
        var pointsFiltres = pointsEquipe

        // Filtre par match
        if let seanceID = seanceSelectionneeID {
            pointsFiltres = pointsFiltres.filter { $0.seanceID == seanceID }
        }

        // Filtre par set
        if let set = setSelectionne {
            pointsFiltres = pointsFiltres.filter { $0.set == set }
        }

        // Filtre par joueur
        if let joueurID = joueurSelectionneID {
            pointsFiltres = pointsFiltres.filter { $0.joueurID == joueurID }
        }

        // Filtre par catégorie heatmap (ne garder que les actions correspondantes)
        let pointsCategorie = pointsFiltres.filter { $0.typeAction.categorieHeatmap == categorie }

        // Points avec zone assignée (zone > 0)
        let pointsAvecZone = pointsCategorie.filter { $0.zone > 0 && $0.zone <= 6 }

        var zones: [Int: Int] = [:]

        if !pointsAvecZone.isEmpty {
            // Données réelles : compter par zone
            for point in pointsAvecZone {
                zones[point.zone, default: 0] += 1
            }
        } else {
            // Fallback : distribution simulée à partir des stats cumulatives
            let statsFiltrees: [StatsMatch]
            if let joueurID = joueurSelectionneID {
                statsFiltrees = statsEquipe.filter { $0.joueurID == joueurID }
            } else {
                statsFiltrees = statsEquipe
            }

            let totalStat = totalPourCategorie(stats: statsFiltrees, categorie: categorie)
            if totalStat > 0 {
                let distribution = distributionParDefaut(categorie: categorie)
                for (zone, poids) in distribution {
                    zones[zone] = Int(round(Double(totalStat) * poids))
                }
            }
        }

        donneesHeatmap.zones = zones
        donneesHeatmap.categorie = categorie
    }

    private func totalPourCategorie(stats: [StatsMatch], categorie: DonneesHeatmap.CategorieHeatmap) -> Int {
        stats.reduce(0) { acc, s in
            switch categorie {
            case .attaque:   return acc + s.kills + s.erreursAttaque
            case .reception: return acc + s.receptionsReussies + s.erreursReception
            case .service:   return acc + s.aces + s.erreursService
            case .bloc:      return acc + s.blocsSeuls + s.blocsAssistes + s.erreursBloc
            }
        }
    }

    /// Distribution simulée par zone selon la catégorie (fallback quand pas de données zone)
    private func distributionParDefaut(categorie: DonneesHeatmap.CategorieHeatmap) -> [Int: Double] {
        switch categorie {
        case .attaque:
            return [1: 0.05, 2: 0.22, 3: 0.18, 4: 0.35, 5: 0.05, 6: 0.15]
        case .reception:
            return [1: 0.30, 2: 0.05, 3: 0.03, 4: 0.02, 5: 0.30, 6: 0.30]
        case .service:
            return [1: 0.50, 2: 0.10, 3: 0.05, 4: 0.05, 5: 0.15, 6: 0.15]
        case .bloc:
            return [1: 0.02, 2: 0.30, 3: 0.38, 4: 0.28, 5: 0.01, 6: 0.01]
        }
    }
}

// MARK: - Previews

#Preview("Heatmap Terrain") {
    struct PreviewWrapper: View {
        @State var donnees = DonneesHeatmap(
            zones: [1: 15, 2: 28, 3: 22, 4: 35, 5: 8, 6: 12],
            categorie: .attaque
        )
        var body: some View {
            HeatmapTerrainView(donnees: $donnees)
                .padding()
                .frame(maxWidth: 500)
        }
    }
    return PreviewWrapper()
}

#Preview("Heatmap Equipe") {
    HeatmapEquipeView()
        .frame(maxWidth: 600)
}
