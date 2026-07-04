//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Tableau de bord de l'équipe — instantané « Mon équipe » : chiffres clés,
/// matchs, stats globales et planification (kit CarteMetrique / EnTeteSection).
struct TableauBordView: View {
    let joueurs: [JoueurEquipe]
    let seances: [Seance]
    let strategies: [StrategieCollective]
    /// Navigation interne du hub Équipe (top performers → fiche joueur, etc.).
    var onNaviguer: ((EquipeView.EquipeNavItem) -> Void)? = nil

    @State private var matchSelectionne: Seance?
    @State private var afficherBoxScore = false

    // Données cachées — recalculées uniquement quand les données changent
    @State private var joueursActifs: [JoueurEquipe] = []
    @State private var matchs: [Seance] = []
    @State private var victoires = 0
    @State private var defaites = 0
    @State private var prochainesSeances: [Seance] = []
    @State private var statsCache = StatsEquipeCache()

    /// Seuil volleyball : un rendement attaque ≥ .250 d'équipe est considéré bon.
    private static let seuilBonRendement = 0.250

    /// Cache des stats agrégées — évite 8x .reduce() par render
    struct StatsEquipeCache {
        var kills = 0, erreursAtt = 0, tentativesAtt = 0
        var aces = 0, blocsSeuls = 0, blocsAssistes = 0
        var manchettes = 0, passes = 0
        var hittingPct: Double = 0
        var teamBlocs: Double = 0
        var aDesStats: Bool { tentativesAtt > 0 || aces > 0 }
    }

    private func recalculerCache() {
        joueursActifs = joueurs.filter(\.estActif)
        matchs = seances.filter { $0.estMatch }.sorted { $0.date > $1.date }
        victoires = matchs.filter { $0.resultat == .victoire }.count
        defaites = matchs.filter { $0.resultat == .defaite }.count
        prochainesSeances = seances.filter { $0.date > Date() }.sorted { $0.date < $1.date }

        var s = StatsEquipeCache()
        for j in joueursActifs {
            s.kills += j.attaquesReussies
            s.erreursAtt += j.erreursAttaque
            s.tentativesAtt += j.attaquesTotales
            s.aces += j.aces
            s.blocsSeuls += j.blocsSeuls
            s.blocsAssistes += j.blocsAssistes
            s.manchettes += j.manchettes
            s.passes += j.passesDecisives
        }
        s.hittingPct = s.tentativesAtt > 0
            ? Double(s.kills - s.erreursAtt) / Double(s.tentativesAtt) : 0
        s.teamBlocs = Double(s.blocsSeuls) + Double(s.blocsAssistes) * 0.5
        statsCache = s
    }

    var body: some View {
        ScrollView {
            VStack(spacing: LiquidGlassKit.espaceLG) {
                entete
                resumeChiffres
                sectionMatchs
                sectionStatsEquipe
                sectionSeancesAVenir
            }
            .padding()
        }
        .navigationTitle("Tableau de bord")
        .onAppear { recalculerCache() }
        .onChange(of: joueurs) { recalculerCache() }
        .onChange(of: seances) { recalculerCache() }
        .sheet(isPresented: $afficherBoxScore) {
            if let match = matchSelectionne {
                NavigationStack {
                    BoxScoreView(seance: match)
                }
            }
        }
    }

    // MARK: - En-tête

    private var entete: some View {
        EnTeteSection(titre: "Vue d'ensemble",
                      sousTitre: "Matchs, statistiques et planification")
    }

    // MARK: - Résumé chiffres

    private var resumeChiffres: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()), GridItem(.flexible()),
            GridItem(.flexible()), GridItem(.flexible())
        ], spacing: LiquidGlassKit.espaceSM + 4) {
            CarteMetrique(titre: "Joueurs",
                          valeur: "\(joueursActifs.count)",
                          teinte: PaletteMat.vert)
            CarteMetrique(titre: "Matchs",
                          valeur: "\(matchs.count)",
                          teinte: PaletteMat.negatif)
            Button {
                onNaviguer?(.analytics)
            } label: {
                CarteMetrique(titre: "V-D",
                              valeur: "\(victoires)-\(defaites)",
                              sousTitre: onNaviguer == nil ? nil : "Voir Analytics",
                              teinte: PaletteMat.orange)
            }
            .buttonStyle(GlassButtonStyle())
            .disabled(onNaviguer == nil)
            .accessibilityHint("Ouvre les analytics de la saison")
            CarteMetrique(titre: "À venir",
                          valeur: "\(prochainesSeances.count)",
                          teinte: PaletteMat.violet)
        }
    }

    // MARK: - Historique des matchs

    private var sectionMatchs: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM + 4) {
            EnTeteSection(
                titre: "Historique des matchs",
                sousTitre: matchs.isEmpty
                    ? nil
                    : "\(matchs.count) match\(matchs.count > 1 ? "s" : "") joué\(matchs.count > 1 ? "s" : "")"
            )

            if matchs.isEmpty {
                ContentUnavailableView(
                    "Aucun match joué",
                    systemImage: "flag",
                    description: Text("Créez un match dans la section Matchs : ses résultats apparaîtront ici.")
                )
            } else {
                ForEach(matchs.prefix(10)) { match in
                    Button {
                        matchSelectionne = match
                        afficherBoxScore = true
                    } label: {
                        ligneMatch(match)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .glassSection()
    }

    private func ligneMatch(_ match: Seance) -> some View {
        HStack(spacing: LiquidGlassKit.espaceSM + 4) {
            // Date
            VStack(spacing: 2) {
                Text(match.date.formatCourt())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(match.date.formatHeure())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 65)

            // Barre résultat
            RoundedRectangle(cornerRadius: 2)
                .fill(match.resultat?.couleur ?? Color(.systemGray4))
                .frame(width: 4, height: 36)

            // Nom + adversaire
            VStack(alignment: .leading, spacing: 2) {
                Text(match.nom)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                if !match.adversaire.isEmpty {
                    Text("vs \(match.adversaire)")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                if !match.lieu.isEmpty {
                    Text(match.lieu)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Score
            if match.scoreEquipe > 0 || match.scoreAdversaire > 0 {
                VStack(spacing: 2) {
                    Text("\(match.scoreEquipe) - \(match.scoreAdversaire)")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(match.resultat?.couleur ?? .primary)
                    if let resultat = match.resultat {
                        Text(resultat.label)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, LiquidGlassKit.espaceXS + 2)
                            .padding(.vertical, 2)
                            .background(resultat.couleur, in: Capsule())
                    }
                }
            }

            // Bouton Feuille de match — zone tactile >= 44 pt
            VStack(spacing: 2) {
                Image(systemName: "tablecells")
                    .font(.caption)
                Text("Feuille de match")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(.red)
            .padding(.horizontal, LiquidGlassKit.espaceSM)
            .frame(minWidth: 44, minHeight: 44)
            .background(Color.red.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMini * 2))
            .contentShape(Rectangle())
        }
        .padding(.vertical, LiquidGlassKit.espaceXS + 2)
    }

    // MARK: - Stats d'équipe globales

    private var sectionStatsEquipe: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM + 4) {
            EnTeteSection(titre: "Statistiques globales",
                          sousTitre: "Cumul saison des joueurs actifs")

            let s = statsCache

            if !s.aDesStats {
                ContentUnavailableView(
                    "Aucune statistique",
                    systemImage: "chart.bar",
                    description: Text("Saisissez des stats en match live ou dans la feuille de match pour alimenter le cumul d'équipe.")
                )
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())
                ], spacing: LiquidGlassKit.espaceSM + 4) {
                    CarteMetrique(
                        titre: "Rendement",
                        valeur: FormatMetriques.hittingVolley(s.hittingPct),
                        teinte: s.hittingPct >= Self.seuilBonRendement
                            ? PaletteMat.positif : PaletteMat.attention,
                        definition: MetriquesVolley.catalogue.first { $0.abreviation == "Rend." }
                    )
                    CarteMetrique(titre: "Kills",
                                  valeur: "\(s.kills)",
                                  teinte: PaletteMat.positif)
                    CarteMetrique(titre: "Aces",
                                  valeur: "\(s.aces)",
                                  teinte: PaletteMat.bleu)
                    CarteMetrique(titre: "Blocs",
                                  valeur: FormatMetriques.points(s.teamBlocs),
                                  teinte: PaletteMat.negatif)
                    CarteMetrique(titre: "Manchettes",
                                  valeur: "\(s.manchettes)",
                                  teinte: PaletteMat.violet)
                    CarteMetrique(titre: "Passes décisives",
                                  valeur: "\(s.passes)",
                                  teinte: PaletteMat.orange)
                }

                // Top 5 marqueurs
                if joueursActifs.contains(where: { $0.pointsCalcules > 0 }) {
                    sectionTopJoueurs
                }
            }
        }
        .glassSection()
    }

    // MARK: - Top joueurs

    private var sectionTopJoueurs: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Text("Meilleurs marqueurs")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, LiquidGlassKit.espaceXS)

            let topJoueurs = joueursActifs
                .filter { $0.pointsCalcules > 0 }
                .sorted { $0.pointsCalcules > $1.pointsCalcules }
                .prefix(5)

            ForEach(Array(topJoueurs.enumerated()), id: \.element.id) { index, joueur in
                Button {
                    onNaviguer?(.joueur(joueur.id))
                } label: {
                    HStack(spacing: LiquidGlassKit.espaceSM + 4) {
                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
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
                            .foregroundStyle(PaletteMat.textePrincipal)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(joueur.pointsCalcules) pts")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(PaletteMat.orange)
                            if joueur.attaquesTotales > 0 {
                                Text(FormatMetriques.hittingVolley(joueur.pourcentageAttaque))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if onNaviguer != nil {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, LiquidGlassKit.espaceXS)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(onNaviguer == nil)
            }
        }
    }

    // MARK: - Séances à venir

    private var sectionSeancesAVenir: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM + 4) {
            EnTeteSection(
                titre: "Séances à venir",
                sousTitre: prochainesSeances.isEmpty
                    ? nil
                    : "\(prochainesSeances.count) planifiée\(prochainesSeances.count > 1 ? "s" : "")"
            )

            if prochainesSeances.isEmpty {
                ContentUnavailableView(
                    "Aucune séance planifiée",
                    systemImage: "calendar",
                    description: Text("Planifiez une séance ou un match depuis le calendrier pour la voir apparaître ici.")
                )
            } else {
                ForEach(prochainesSeances.prefix(8)) { seance in
                    HStack(spacing: LiquidGlassKit.espaceSM + 4) {
                        // Barre type
                        RoundedRectangle(cornerRadius: 2)
                            .fill(seance.estMatch ? Color.red : PaletteMat.orange)
                            .frame(width: 4, height: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: LiquidGlassKit.espaceXS + 2) {
                                Text(seance.nom)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                                if seance.estMatch {
                                    Text("Match")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(.red, in: Capsule())
                                }
                            }
                            HStack(spacing: LiquidGlassKit.espaceXS + 2) {
                                Text(seance.date.formatJourSemaine())
                                    .font(.caption)
                                Text(seance.date.formatCourt())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if seance.estMatch && !seance.adversaire.isEmpty {
                                    Text("vs \(seance.adversaire)")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                        }

                        Spacer()

                        // Countdown
                        let jours = Calendar.current.dateComponents([.day],
                            from: Calendar.current.startOfDay(for: Date()),
                            to: Calendar.current.startOfDay(for: seance.date)).day ?? 0
                        VStack(spacing: 2) {
                            Text(seance.date.formatHeure())
                                .font(.caption.weight(.medium))
                                .foregroundStyle(seance.estMatch ? .red : PaletteMat.orange)
                            if jours == 0 {
                                Text("Aujourd'hui")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(seance.estMatch ? .red : PaletteMat.orange)
                            } else if jours == 1 {
                                Text("Demain")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(seance.estMatch ? .red : PaletteMat.orange)
                            } else {
                                Text("J-\(jours)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, LiquidGlassKit.espaceXS)
                }
            }
        }
        .glassSection()
    }
}
