//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Feuille de match (box score) — extraite de TableauBordView (Phase 4
//  refonte) : lecture des StatsMatch persistés d'un match + note de
//  réception. Accessible depuis le tableau de bord et l'analyse de match.
//

import SwiftUI
import SwiftData

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
    @State private var noteReceptionMatch: Double = 0
    @State private var nbReceptionsNoteesMatch = 0

    private func chargerStats() {
        let seanceID = seance.id
        let descriptor = FetchDescriptor<StatsMatch>(
            predicate: #Predicate { $0.seanceID == seanceID }
        )
        statsMatch = (try? modelContext.fetch(descriptor)) ?? []

        // Note de réception du match (3.2) : qualités saisies en live + erreurs à 0.
        let descripteurActions = FetchDescriptor<ActionRallye>(
            predicate: #Predicate { $0.seanceID == seanceID }
        )
        let actions = (try? modelContext.fetch(descripteurActions)) ?? []
        let descripteurPoints = FetchDescriptor<PointMatch>(
            predicate: #Predicate { $0.seanceID == seanceID }
        )
        let points = (try? modelContext.fetch(descripteurPoints)) ?? []

        let qualites = actions.filter { $0.typeAction == .reception }.map(\.qualite)
            + points.filter { $0.typeAction == .erreurReception }.map { _ in 0 }
        nbReceptionsNoteesMatch = qualites.count
        noteReceptionMatch = MetriquesVolley.noteReception(qualites: qualites)
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
                    if nbReceptionsNoteesMatch > 0 {
                        CarteMetrique(
                            titre: "Note de réception du match",
                            valeur: "\(FormatMetriques.note(noteReceptionMatch)) / 3",
                            sousTitre: "\(nbReceptionsNoteesMatch) réceptions notées",
                            teinte: .purple,
                            definition: MetriquesVolley.catalogue.first { $0.abreviation == "Note réc." }
                        )
                    }
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
            Text(stat.tentativesAttaque > 0 ? FormatMetriques.hittingVolley(stat.hittingPct) : "—")
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
            Text(FormatMetriques.hittingVolley(hitPct)).frame(width: 40)
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

