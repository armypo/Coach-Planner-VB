//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Analyse des performances par rotation (1-6) — refonte 3.4 façon VBStats :
//  sideout % et % au service par rotation (contexte de service D5), grille de
//  6 cartes-terrain, filtre par joueur, vue condensée en graphiques.
//  Terminologie D4 : « % points gagnés » remplace l'ancienne « efficacité ».
//

import SwiftUI
import SwiftData
import Charts

struct StatsParRotationView: View {
    /// Pré-filtre optionnel sur un match (liens croisés depuis MatchDetailView).
    init(seanceID: UUID? = nil) {
        _seanceSelectionneeID = State(initialValue: seanceID)
    }

    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Query private var tousPoints: [PointMatch]
    @Query(filter: #Predicate<Seance> { $0.typeSeanceRaw == "Match" && $0.estArchivee == false },
           sort: \Seance.date, order: .reverse) private var seances: [Seance]
    @Query(filter: #Predicate<JoueurEquipe> { $0.estActif == true },
           sort: \JoueurEquipe.numero) private var tousJoueurs: [JoueurEquipe]

    @State private var pointsEquipe: [PointMatch] = []
    @State private var seancesEquipe: [Seance] = []
    @State private var joueursEquipe: [JoueurEquipe] = []
    @State private var seanceSelectionneeID: UUID? = nil
    @State private var joueurSelectionneID: UUID? = nil
    @State private var statsRotations: [StatsRotation] = []
    @State private var modeAffichage: ModeAffichage = .terrains

    enum ModeAffichage: String, CaseIterable {
        case terrains = "Terrains"
        case graphiques = "Graphiques"
    }

    struct StatsRotation: Identifiable, Equatable {
        let id: Int // rotation 1-6
        var pointsPour: Int = 0
        var pointsContre: Int = 0
        var kills: Int = 0
        var aces: Int = 0
        var blocs: Int = 0
        var erreurs: Int = 0
        // Contexte de service (D5)
        var sideoutGagnes: Int = 0
        var sideoutTotal: Int = 0
        var serviceGagnes: Int = 0
        var serviceTotal: Int = 0

        var totalPoints: Int { pointsPour + pointsContre }
        /// % points gagnés (D4 — ex-« efficacité »), fraction 0-1.
        var pctPointsGagnes: Double {
            guard totalPoints > 0 else { return 0 }
            return Double(pointsPour) / Double(totalPoints)
        }
        /// Sideout % : rallyes gagnés en réception, fraction 0-1.
        var sideoutPct: Double {
            guard sideoutTotal > 0 else { return 0 }
            return Double(sideoutGagnes) / Double(sideoutTotal)
        }
        /// % au service : rallyes gagnés à notre service, fraction 0-1.
        var pctAuService: Double {
            guard serviceTotal > 0 else { return 0 }
            return Double(serviceGagnes) / Double(serviceTotal)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: LiquidGlassKit.espaceLG) {
                entete
                filtres

                if statsRotations.contains(where: { $0.totalPoints > 0 }) {
                    Picker("Affichage", selection: $modeAffichage) {
                        ForEach(ModeAffichage.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch modeAffichage {
                    case .terrains:
                        grilleTerrains
                    case .graphiques:
                        graphiqueSideoutService
                        graphiqueDetails
                    }

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
        .onChange(of: joueurSelectionneID) { _, _ in recalculer() }
        .onChange(of: tousPoints.count) { _, _ in mettreAJour() }
    }

    // MARK: - En-tête

    private var entete: some View {
        EnTeteSection(
            titre: "Stats par rotation",
            sousTitre: joueurSelectionneID == nil
                ? "Sideout % et % au service en rotations 1 à 6"
                : "Points attribués au joueur sélectionné, par rotation"
        )
    }

    // MARK: - Filtres

    private var filtres: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: LiquidGlassKit.espaceSM) {
                Picker("Match", selection: $seanceSelectionneeID) {
                    Text("Tous les matchs").tag(nil as UUID?)
                    ForEach(seancesEquipe) { s in
                        Text(s.adversaire.isEmpty ? s.nom : "vs \(s.adversaire)")
                            .tag(s.id as UUID?)
                    }
                }
                .pickerStyle(.menu)

                Picker("Joueur", selection: $joueurSelectionneID) {
                    Text("Toute l'équipe").tag(nil as UUID?)
                    ForEach(joueursEquipe) { j in
                        Text("#\(j.numero) \(j.nom)").tag(j.id as UUID?)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    // MARK: - Grille de 6 terrains (façon VBStats)

    private var grilleTerrains: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                  spacing: LiquidGlassKit.espaceSM + 4) {
            ForEach(statsRotations) { stat in
                carteTerrainRotation(stat)
            }
        }
    }

    private func carteTerrainRotation(_ stat: StatsRotation) -> some View {
        VStack(spacing: LiquidGlassKit.espaceSM) {
            // Mini-terrain stylisé : demi-terrain avec ligne des 3 mètres
            ZStack {
                RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMini)
                    .fill(couleurPctGagnes(stat.pctPointsGagnes).opacity(stat.totalPoints > 0 ? 0.14 : 0.05))
                RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMini)
                    .stroke(couleurPctGagnes(stat.pctPointsGagnes).opacity(0.5), lineWidth: 1.5)
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(couleurPctGagnes(stat.pctPointsGagnes).opacity(0.4))
                        .frame(height: 1)
                        .padding(.top, 18)
                    Spacer()
                }
                Text("R\(stat.id)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(couleurPctGagnes(stat.pctPointsGagnes))
            }
            .frame(height: 64)
            .accessibilityHidden(true)

            if stat.totalPoints > 0 {
                VStack(spacing: 2) {
                    ligneMetrique("SO%", stat.sideoutTotal > 0
                                  ? FormatMetriques.pourcentage(stat.sideoutPct, decimales: 0) : "—")
                    ligneMetrique("PS%", stat.serviceTotal > 0
                                  ? FormatMetriques.pourcentage(stat.pctAuService, decimales: 0) : "—")
                    HStack(spacing: 3) {
                        Text("\(stat.pointsPour)")
                            .foregroundStyle(PaletteMat.positif)
                        Text("/")
                            .foregroundStyle(.tertiary)
                        Text("\(stat.pointsContre)")
                            .foregroundStyle(PaletteMat.negatif)
                    }
                    .font(.caption2.weight(.semibold).monospacedDigit())
                }
            } else {
                Text("Aucun point")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(LiquidGlassKit.espaceSM)
        .glassCard(cornerRadius: LiquidGlassKit.rayonPetit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibiliteRotation(stat))
    }

    private func ligneMetrique(_ label: String, _ valeur: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(valeur)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.caption2)
    }

    private func accessibiliteRotation(_ stat: StatsRotation) -> String {
        guard stat.totalPoints > 0 else { return "Rotation \(stat.id) : aucun point" }
        return "Rotation \(stat.id) : sideout \(FormatMetriques.pourcentage(stat.sideoutPct, decimales: 0)), " +
               "au service \(FormatMetriques.pourcentage(stat.pctAuService, decimales: 0)), " +
               "\(stat.pointsPour) points pour, \(stat.pointsContre) contre"
    }

    // MARK: - Graphiques (vue condensée)

    private var graphiqueSideoutService: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Label("Sideout % et % au service", systemImage: "chart.bar.fill")
                .font(.headline.weight(.semibold))

            Chart {
                ForEach(statsRotations.filter { $0.sideoutTotal > 0 }) { stat in
                    BarMark(
                        x: .value("Rotation", "R\(stat.id)"),
                        y: .value("Pourcentage", stat.sideoutPct * 100)
                    )
                    .position(by: .value("Métrique", "Sideout %"))
                    .foregroundStyle(PaletteMat.bleu)
                    .cornerRadius(LiquidGlassKit.espaceXS)
                }
                ForEach(statsRotations.filter { $0.serviceTotal > 0 }) { stat in
                    BarMark(
                        x: .value("Rotation", "R\(stat.id)"),
                        y: .value("Pourcentage", stat.pctAuService * 100)
                    )
                    .position(by: .value("Métrique", "% au service"))
                    .foregroundStyle(PaletteMat.violet)
                    .cornerRadius(LiquidGlassKit.espaceXS)
                }
            }
            .chartYScale(domain: 0...100)
            .chartYAxisLabel("%")
            .frame(height: 200)

            HStack(spacing: LiquidGlassKit.espaceMD) {
                legendeItem(couleur: PaletteMat.bleu, texte: "Sideout % (en réception)")
                legendeItem(couleur: PaletteMat.violet, texte: "% au service")
            }
            .font(.caption2)
        }
        .padding(LiquidGlassKit.espaceMD)
        .glassCard(teinte: PaletteMat.bleu, cornerRadius: LiquidGlassKit.rayonMoyen)
    }

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
                    .foregroundStyle(PaletteMat.negatif.opacity(0.7))
                }
            }
            .chartYAxisLabel("Points pour / contre")
            .frame(height: 180)

            HStack(spacing: LiquidGlassKit.espaceMD) {
                legendeItem(couleur: PaletteMat.vert, texte: "Points pour nous")
                legendeItem(couleur: PaletteMat.negatif.opacity(0.7), texte: "Points contre")
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
        let meilleure = avecDonnees.max(by: { $0.pctPointsGagnes < $1.pctPointsGagnes })
        let pire = avecDonnees.min(by: { $0.pctPointsGagnes < $1.pctPointsGagnes })

        return HStack(spacing: LiquidGlassKit.espaceSM + 4) {
            if let m = meilleure {
                carteRotation(
                    titre: "Rotation la plus efficace",
                    rotation: m.id,
                    pct: m.pctPointsGagnes,
                    couleur: PaletteMat.vert,
                    icone: "arrow.up.circle.fill"
                )
            }
            if let p = pire, meilleure?.id != pire?.id {
                carteRotation(
                    titre: "Rotation la moins efficace",
                    rotation: p.id,
                    pct: p.pctPointsGagnes,
                    couleur: PaletteMat.negatif,
                    icone: "arrow.down.circle.fill"
                )
            }
        }
    }

    private func carteRotation(titre: String, rotation: Int, pct: Double, couleur: Color, icone: String) -> some View {
        VStack(spacing: LiquidGlassKit.espaceSM) {
            Image(systemName: icone)
                .font(.title2)
                .foregroundStyle(couleur)
                .symbolRenderingMode(.hierarchical)
            Text("R\(rotation)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(couleur)
            Text(FormatMetriques.pourcentage(pct, decimales: 0))
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

            TableauStats(
                groupes: [
                    GroupeColonnesStats(titre: "Rallyes", colonnes: ["Pts+", "Pts-", "PG%"],
                                        teinte: PaletteMat.vert),
                    GroupeColonnesStats(titre: "Service (D5)", colonnes: ["SO%", "PS%"],
                                        teinte: PaletteMat.bleu),
                    GroupeColonnesStats(titre: "Actions", colonnes: ["K", "AC", "B", "E"],
                                        teinte: PaletteMat.orange),
                ],
                lignes: statsRotations.map { stat in
                    LigneTableauStats(
                        id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", stat.id)) ?? UUID(),
                        libelle: "R\(stat.id)",
                        valeurs: [
                            "\(stat.pointsPour)",
                            "\(stat.pointsContre)",
                            stat.totalPoints > 0 ? FormatMetriques.pourcentage(stat.pctPointsGagnes, decimales: 0) : "—",
                            stat.sideoutTotal > 0 ? FormatMetriques.pourcentage(stat.sideoutPct, decimales: 0) : "—",
                            stat.serviceTotal > 0 ? FormatMetriques.pourcentage(stat.pctAuService, decimales: 0) : "—",
                            "\(stat.kills)", "\(stat.aces)", "\(stat.blocs)", "\(stat.erreurs)",
                        ],
                        couleurs: [PaletteMat.positif, PaletteMat.negatif,
                                   couleurPctGagnes(stat.pctPointsGagnes),
                                   nil, nil, nil, nil, nil,
                                   stat.erreurs > 0 ? PaletteMat.negatif : nil]
                    )
                },
                largeurLibelle: 48
            )
        }
        .padding(LiquidGlassKit.espaceMD)
        .glassCard(cornerRadius: LiquidGlassKit.rayonMoyen)
    }

    // MARK: - Helpers

    private func couleurPctGagnes(_ pct: Double) -> Color {
        if pct >= 0.55 { return PaletteMat.vert }
        if pct >= 0.45 { return PaletteMat.orange }
        return PaletteMat.negatif
    }

    // MARK: - Logique

    private func mettreAJour() {
        pointsEquipe = tousPoints.filtreEquipe(codeEquipeActif)
        seancesEquipe = seances.filtreEquipe(codeEquipeActif)
        joueursEquipe = tousJoueurs.filtreEquipe(codeEquipeActif)
        recalculer()
    }

    private func recalculer() {
        var points = pointsEquipe

        if let seanceID = seanceSelectionneeID {
            points = points.filter { $0.seanceID == seanceID }
        }

        // Contexte de service par point (D5) — fusionné match par match, car
        // la reconstruction dépend du serveur initial de chaque set.
        var contexte: [UUID: Bool] = [:]
        let parSeance = Dictionary(grouping: points, by: \.seanceID)
        for (seanceID, pointsSeance) in parSeance {
            guard let seance = seancesEquipe.first(where: { $0.id == seanceID }) else { continue }
            contexte.merge(MetriquesVolley.reconstruireService(points: pointsSeance, seance: seance)) { a, _ in a }
        }

        // Filtre joueur (après le contexte : le contexte se calcule sur la
        // séquence complète du match, pas sur le sous-ensemble filtré).
        if let joueurID = joueurSelectionneID {
            points = points.filter { $0.joueurID == joueurID }
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

            // Contexte service → sideout et point scoring par rotation
            if let nousServions = contexte[point.id] {
                if nousServions {
                    rotations[idx].serviceTotal += 1
                    if point.estPointPourNous { rotations[idx].serviceGagnes += 1 }
                } else {
                    rotations[idx].sideoutTotal += 1
                    if point.estPointPourNous { rotations[idx].sideoutGagnes += 1 }
                }
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

        withAnimation(LiquidGlassKit.springDefaut) {
            statsRotations = rotations
        }
    }
}
