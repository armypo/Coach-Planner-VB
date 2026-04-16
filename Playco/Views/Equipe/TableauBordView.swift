//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Tableau de bord de l'équipe — matchs, stats globales, séances à venir
struct TableauBordView: View {
    let joueurs: [JoueurEquipe]
    let seances: [Seance]
    let strategies: [StrategieCollective]

    @State private var matchSelectionne: Seance?
    @State private var afficherBoxScore = false

    // Données cachées — recalculées uniquement quand les données changent
    @State private var joueursActifs: [JoueurEquipe] = []
    @State private var matchs: [Seance] = []
    @State private var victoires = 0
    @State private var defaites = 0
    @State private var prochainesSeances: [Seance] = []
    @State private var statsCache = StatsEquipeCache()

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
            VStack(spacing: 24) {
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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Vue d'ensemble")
                    .font(.title.weight(.bold))
                Text("Matchs, statistiques et planification")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 32))
                .foregroundStyle(PaletteMat.vert.opacity(0.6))
        }
    }

    // MARK: - Résumé chiffres

    private var resumeChiffres: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()), GridItem(.flexible()),
            GridItem(.flexible()), GridItem(.flexible())
        ], spacing: 12) {
            chiffreCle("Joueurs", valeur: "\(joueursActifs.count)",
                       icone: "person.3.fill", couleur: PaletteMat.vert)
            chiffreCle("Matchs", valeur: "\(matchs.count)",
                       icone: "flag.fill", couleur: .red)
            chiffreCle("V-D", valeur: "\(victoires)-\(defaites)",
                       icone: "trophy.fill", couleur: .orange)
            chiffreCle("À venir", valeur: "\(prochainesSeances.count)",
                       icone: "clock.fill", couleur: PaletteMat.violet)
        }
    }

    private func chiffreCle(_ titre: String, valeur: String, icone: String, couleur: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icone)
                .font(.system(size: 22))
                .foregroundStyle(couleur)
            Text(valeur)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
            Text(titre)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .glassCard(cornerRadius: 14)
    }

    // MARK: - Historique des matchs

    private var sectionMatchs: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Historique des matchs", systemImage: "flag.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                if !matchs.isEmpty {
                    Text("\(matchs.count) match\(matchs.count > 1 ? "s" : "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if matchs.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "flag")
                            .font(.system(size: 28))
                            .foregroundStyle(.tertiary)
                        Text("Aucun match joué")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
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
        HStack(spacing: 12) {
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
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(resultat.couleur, in: Capsule())
                    }
                }
            }

            // Bouton Feuille de match
            VStack(spacing: 2) {
                Image(systemName: "tablecells")
                    .font(.caption)
                Text("Feuille de match")
                    .font(.system(size: 8, weight: .medium))
            }
            .foregroundStyle(.red)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(.vertical, 6)
    }

    // MARK: - Stats d'équipe globales

    private var sectionStatsEquipe: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Statistiques globales", systemImage: "chart.bar.fill")
                .font(.headline)

            let s = statsCache

            if !s.aDesStats {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 28))
                            .foregroundStyle(.tertiary)
                        Text("Aucune statistique")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()), GridItem(.flexible()),
                    GridItem(.flexible()), GridItem(.flexible())
                ], spacing: 12) {
                    statEquipe(label: "Kills", valeur: "\(s.kills)", couleur: .green)
                    statEquipe(label: "Hitting %", valeur: String(format: "%.3f", s.hittingPct),
                               couleur: s.hittingPct >= 0.250 ? .green : .orange)
                    statEquipe(label: "Aces", valeur: "\(s.aces)", couleur: .yellow)
                    statEquipe(label: "Blocs", valeur: String(format: "%.0f", s.teamBlocs), couleur: .red)
                }

                LazyVGrid(columns: [
                    GridItem(.flexible()), GridItem(.flexible()),
                    GridItem(.flexible()), GridItem(.flexible())
                ], spacing: 12) {
                    statEquipe(label: "Manchettes", valeur: "\(s.manchettes)", couleur: .teal)
                    statEquipe(label: "Passes déc.", valeur: "\(s.passes)", couleur: .cyan)
                    statEquipe(label: "Err. att.", valeur: "\(s.erreursAtt)", couleur: .red.opacity(0.7))
                    statEquipe(label: "Err. serv.", valeur: "\(joueursActifs.reduce(0) { $0 + $1.erreursService })", couleur: .red.opacity(0.7))
                }

                // Top 5 marqueurs
                if joueursActifs.contains(where: { $0.pointsCalcules > 0 }) {
                    sectionTopJoueurs
                }
            }
        }
        .glassSection()
    }

    private func statEquipe(label: String, valeur: String, couleur: Color) -> some View {
        VStack(spacing: 4) {
            Text(valeur)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(couleur)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(couleur.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Top joueurs

    private var sectionTopJoueurs: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Meilleurs marqueurs")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            let topJoueurs = joueursActifs
                .filter { $0.pointsCalcules > 0 }
                .sorted { $0.pointsCalcules > $1.pointsCalcules }
                .prefix(5)

            ForEach(Array(topJoueurs.enumerated()), id: \.element.id) { index, joueur in
                HStack(spacing: 12) {
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

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(joueur.pointsCalcules) pts")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(PaletteMat.orange)
                        if joueur.attaquesTotales > 0 {
                            Text(String(format: "%.3f hit%%", joueur.pourcentageAttaque))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Séances à venir

    private var sectionSeancesAVenir: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Séances à venir", systemImage: "calendar.badge.clock")
                    .font(.headline)
                Spacer()
                if !prochainesSeances.isEmpty {
                    Text("\(prochainesSeances.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PaletteMat.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(PaletteMat.orange.opacity(0.1), in: Capsule())
                }
            }

            if prochainesSeances.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 28))
                            .foregroundStyle(.tertiary)
                        Text("Aucune séance planifiée")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            } else {
                ForEach(prochainesSeances.prefix(8)) { seance in
                    HStack(spacing: 12) {
                        // Barre type
                        RoundedRectangle(cornerRadius: 2)
                            .fill(seance.estMatch ? Color.red : PaletteMat.orange)
                            .frame(width: 4, height: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
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
                            HStack(spacing: 6) {
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
                    .padding(.vertical, 4)
                }
            }
        }
        .glassSection()
    }
}

// MARK: - Box Score View (lecture des stats du match depuis StatsMatch)

struct BoxScoreView: View {
    let seance: Seance
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Query(sort: \JoueurEquipe.numero) private var tousJoueurs: [JoueurEquipe]
    private var joueurs: [JoueurEquipe] {
        tousJoueurs.filtreEquipe(codeEquipeActif)
    }

    @State private var statsMatch: [StatsMatch] = []

    private func chargerStats() {
        let seanceID = seance.id
        let descriptor = FetchDescriptor<StatsMatch>(
            predicate: #Predicate { $0.seanceID == seanceID }
        )
        statsMatch = (try? modelContext.fetch(descriptor)) ?? []
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                enTeteMatch

                if !seance.notesMatch.isEmpty {
                    sectionNotes
                }

                if statsMatch.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tablecells")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                        Text("Aucune statistique enregistrée")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Entrez les stats depuis la section Séances")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    sectionBoxScore
                }
            }
            .padding()
        }
        .navigationTitle("Feuille de match")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Fermer") { dismiss() }
            }
        }
        .onAppear { chargerStats() }
    }

    // MARK: - En-tête

    private var enTeteMatch: some View {
        VStack(spacing: 12) {
            Text(seance.nom)
                .font(.title2.weight(.bold))

            if !seance.adversaire.isEmpty {
                Text("vs \(seance.adversaire)")
                    .font(.title3)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 16) {
                Text(seance.date.formatFrancais())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !seance.lieu.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                        Text(seance.lieu)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                Text("\(seance.scoreEquipe)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(PaletteMat.vert)
                Text("-")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("\(seance.scoreAdversaire)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.red)
            }

            if let resultat = seance.resultat {
                Text(resultat.label)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(resultat.couleur, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Notes

    private var sectionNotes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notes", systemImage: "note.text")
                .font(.subheadline.weight(.bold))
            Text(seance.notesMatch)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
        }
        .glassSection()
    }

    // MARK: - Box score (lecture seule depuis StatsMatch)

    private var sectionBoxScore: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Feuille de match", systemImage: "tablecells")
                .font(.subheadline.weight(.bold))

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    // En-tête
                    HStack(spacing: 0) {
                        Text("Joueur")
                            .frame(width: 130, alignment: .leading)
                        colHeader("K")
                        colHeader("E")
                        colHeader("TA")
                        colHeader("Hit%")
                        colHeader("AC")
                        colHeader("SE")
                        colHeader("BS")
                        colHeader("BA")
                        colHeader("DG")
                        colHeader("SA")
                        colHeader("PTS")
                    }
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))

                    Divider()

                    // Lignes
                    let statsTries = statsMatch.sorted { $0.points > $1.points }
                    ForEach(statsTries) { stat in
                        if let joueur = joueurs.first(where: { $0.id == stat.joueurID }) {
                            ligneBoxScore(joueur: joueur, stat: stat)
                            Divider().padding(.leading, 8)
                        }
                    }

                    // Totaux
                    ligneTotaux
                }
            }
        }
        .glassSection()
    }

    private func colHeader(_ text: String) -> some View {
        Text(text).frame(width: 40)
    }

    private func ligneBoxScore(joueur: JoueurEquipe, stat: StatsMatch) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(joueur.poste.couleur.opacity(0.15))
                        .frame(width: 22, height: 22)
                    Text(joueur.poste.abreviation)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(joueur.poste.couleur)
                }
                Text("#\(joueur.numero) \(joueur.prenom)")
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(width: 130, alignment: .leading)

            cellule(stat.kills, couleur: .green)
            cellule(stat.erreursAttaque, couleur: .red)
            cellule(stat.tentativesAttaque, couleur: .primary)
            Text(stat.tentativesAttaque > 0 ? String(format: ".%03d", Int(stat.hittingPct * 1000)) : "—")
                .font(.caption2)
                .foregroundStyle(stat.hittingPct >= 0.250 ? .green : .orange)
                .frame(width: 40)
            cellule(stat.aces, couleur: .yellow)
            cellule(stat.erreursService, couleur: .red)
            cellule(stat.blocsSeuls, couleur: .red)
            cellule(stat.blocsAssistes, couleur: .orange)
            cellule(stat.manchettes, couleur: .teal)
            cellule(stat.passesDecisives, couleur: .cyan)
            Text("\(stat.points)")
                .font(.caption.weight(.bold))
                .foregroundStyle(PaletteMat.orange)
                .frame(width: 40)
        }
        .font(.caption)
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
    }

    private func cellule(_ valeur: Int, couleur: Color) -> some View {
        Text("\(valeur)")
            .font(.caption)
            .foregroundStyle(valeur > 0 ? couleur : Color.gray.opacity(0.4))
            .frame(width: 40)
    }

    private var ligneTotaux: some View {
        let totK = statsMatch.reduce(0) { $0 + $1.kills }
        let totE = statsMatch.reduce(0) { $0 + $1.erreursAttaque }
        let totTA = statsMatch.reduce(0) { $0 + $1.tentativesAttaque }
        let totAc = statsMatch.reduce(0) { $0 + $1.aces }
        let totSE = statsMatch.reduce(0) { $0 + $1.erreursService }
        let totBS = statsMatch.reduce(0) { $0 + $1.blocsSeuls }
        let totBA = statsMatch.reduce(0) { $0 + $1.blocsAssistes }
        let totDG = statsMatch.reduce(0) { $0 + $1.manchettes }
        let totSA = statsMatch.reduce(0) { $0 + $1.passesDecisives }
        let totPts = statsMatch.reduce(0) { $0 + $1.points }
        let hitPct: Double = totTA > 0 ? Double(totK - totE) / Double(totTA) : 0

        return HStack(spacing: 0) {
            Text("TOTAL")
                .font(.caption.weight(.bold))
                .frame(width: 130, alignment: .leading)
            Text("\(totK)").frame(width: 40)
            Text("\(totE)").frame(width: 40)
            Text("\(totTA)").frame(width: 40)
            Text(String(format: ".%03d", Int(hitPct * 1000))).frame(width: 40)
            Text("\(totAc)").frame(width: 40)
            Text("\(totSE)").frame(width: 40)
            Text("\(totBS)").frame(width: 40)
            Text("\(totBA)").frame(width: 40)
            Text("\(totDG)").frame(width: 40)
            Text("\(totSA)").frame(width: 40)
            Text("\(totPts)")
                .foregroundStyle(PaletteMat.orange)
                .frame(width: 40)
        }
        .font(.caption.weight(.bold))
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(Color(.systemGray6))
    }
}
