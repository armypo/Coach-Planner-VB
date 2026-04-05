//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Palmarès et records de la saison — records individuels et d'équipe par match
struct PalmaresRecordsView: View {
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Query(filter: #Predicate<Seance> { $0.typeSeanceRaw == "Match" && $0.estArchivee == false },
           sort: \Seance.date) private var seances: [Seance]
    @Query private var statsMatchs: [StatsMatch]
    @Query(filter: #Predicate<JoueurEquipe> { $0.estActif == true },
           sort: \JoueurEquipe.numero) private var joueurs: [JoueurEquipe]

    @State private var matchsEquipe: [Seance] = []
    @State private var statsEquipe: [StatsMatch] = []
    @State private var joueursEquipe: [JoueurEquipe] = []
    @State private var records: [RecordSaison] = []

    struct RecordSaison: Identifiable {
        let id = UUID()
        let titre: String
        let valeur: String
        let detail: String
        let icone: String
        let couleur: Color
    }

    var body: some View {
        ScrollView {
            VStack(spacing: LiquidGlassKit.espaceLG) {
                entete

                if records.isEmpty {
                    ContentUnavailableView(
                        "Pas de records",
                        systemImage: "trophy",
                        description: Text("Jouez des matchs et entrez des stats pour voir le palmarès.")
                    )
                } else {
                    recordsIndividuels
                    recordsEquipe
                }
            }
            .padding(LiquidGlassKit.espaceLG)
        }
        .navigationTitle("Palmarès & records")
        .onAppear { mettreAJour() }
        .onChange(of: codeEquipeActif) { _, _ in mettreAJour() }
    }

    // MARK: - En-tête

    private var entete: some View {
        HStack {
            VStack(alignment: .leading, spacing: LiquidGlassKit.espaceXS) {
                Text("Palmarès & records")
                    .font(.title.weight(.bold))
                Text("Records individuels et d'équipe cette saison")
                    .font(.subheadline)
                    .foregroundStyle(PaletteMat.texteSecondaire)
            }
            Spacer()
            Image(systemName: "trophy.fill")
                .font(.system(size: 32))
                .foregroundStyle(PaletteMat.orange.opacity(0.6))
                .symbolRenderingMode(.hierarchical)
        }
    }

    // MARK: - Records individuels

    private var recordsIndividuels: some View {
        let individuels = calculerRecordsIndividuels()

        return VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Label("Records individuels (par match)", systemImage: "person.fill")
                .font(.headline.weight(.semibold))

            if individuels.isEmpty {
                Text("Aucun record individuel")
                    .font(.caption)
                    .foregroundStyle(PaletteMat.texteTertiaire)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                          spacing: LiquidGlassKit.espaceSM + 4) {
                    ForEach(individuels) { record in
                        carteRecord(record)
                    }
                }
            }
        }
        .padding(LiquidGlassKit.espaceMD)
        .glassCard(teinte: PaletteMat.orange, cornerRadius: LiquidGlassKit.rayonMoyen)
    }

    // MARK: - Records équipe

    private var recordsEquipe: some View {
        let equipe = calculerRecordsEquipe()

        return VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Label("Records d'équipe (par match)", systemImage: "person.3.fill")
                .font(.headline.weight(.semibold))

            if equipe.isEmpty {
                Text("Aucun record d'équipe")
                    .font(.caption)
                    .foregroundStyle(PaletteMat.texteTertiaire)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                          spacing: LiquidGlassKit.espaceSM + 4) {
                    ForEach(equipe) { record in
                        carteRecord(record)
                    }
                }
            }
        }
        .padding(LiquidGlassKit.espaceMD)
        .glassCard(teinte: PaletteMat.bleu, cornerRadius: LiquidGlassKit.rayonMoyen)
    }

    // MARK: - Carte record

    private func carteRecord(_ record: RecordSaison) -> some View {
        VStack(spacing: LiquidGlassKit.espaceSM) {
            Image(systemName: record.icone)
                .font(.title3)
                .foregroundStyle(record.couleur)
                .symbolRenderingMode(.hierarchical)
            Text(record.valeur)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(record.couleur)
                .contentTransition(.numericText())
            Text(record.titre)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(record.detail)
                .font(.caption2)
                .foregroundStyle(PaletteMat.texteSecondaire)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LiquidGlassKit.espaceMD)
        .glassCard(cornerRadius: LiquidGlassKit.rayonPetit)
    }

    // MARK: - Calculs records individuels

    private func calculerRecordsIndividuels() -> [RecordSaison] {
        var results: [RecordSaison] = []

        // Record kills dans un match
        if let top = statsEquipe.max(by: { $0.kills < $1.kills }), top.kills > 0 {
            let nom = nomJoueur(top.joueurID)
            let match = nomMatch(top.seanceID)
            results.append(RecordSaison(
                titre: "Plus de kills",
                valeur: "\(top.kills)",
                detail: "\(nom) — \(match)",
                icone: "flame.fill",
                couleur: PaletteMat.orange
            ))
        }

        // Record aces dans un match
        if let top = statsEquipe.max(by: { $0.aces < $1.aces }), top.aces > 0 {
            let nom = nomJoueur(top.joueurID)
            let match = nomMatch(top.seanceID)
            results.append(RecordSaison(
                titre: "Plus d'aces",
                valeur: "\(top.aces)",
                detail: "\(nom) — \(match)",
                icone: "tennisball.fill",
                couleur: PaletteMat.bleu
            ))
        }

        // Record blocs dans un match
        let topBlocs = statsEquipe.max(by: { ($0.blocsSeuls + $0.blocsAssistes) < ($1.blocsSeuls + $1.blocsAssistes) })
        if let top = topBlocs, (top.blocsSeuls + top.blocsAssistes) > 0 {
            let nom = nomJoueur(top.joueurID)
            let match = nomMatch(top.seanceID)
            results.append(RecordSaison(
                titre: "Plus de blocs",
                valeur: "\(top.blocsSeuls + top.blocsAssistes)",
                detail: "\(nom) — \(match)",
                icone: "hand.raised.fill",
                couleur: PaletteMat.violet
            ))
        }

        // Meilleur hitting % dans un match (min 10 tentatives)
        let avecTA = statsEquipe.filter { $0.tentativesAttaque >= 10 }
        if let top = avecTA.max(by: { $0.hittingPct < $1.hittingPct }) {
            let nom = nomJoueur(top.joueurID)
            let match = nomMatch(top.seanceID)
            results.append(RecordSaison(
                titre: "Meilleur hitting %",
                valeur: String(format: "%.3f", top.hittingPct),
                detail: "\(nom) — \(match)",
                icone: "chart.bar.fill",
                couleur: PaletteMat.vert
            ))
        }

        // Record points dans un match
        if let top = statsEquipe.max(by: { $0.points < $1.points }), top.points > 0 {
            let nom = nomJoueur(top.joueurID)
            let match = nomMatch(top.seanceID)
            results.append(RecordSaison(
                titre: "Plus de points",
                valeur: "\(top.points)",
                detail: "\(nom) — \(match)",
                icone: "star.fill",
                couleur: PaletteMat.orange
            ))
        }

        // Record passes dans un match
        if let top = statsEquipe.max(by: { $0.passesDecisives < $1.passesDecisives }), top.passesDecisives > 0 {
            let nom = nomJoueur(top.joueurID)
            let match = nomMatch(top.seanceID)
            results.append(RecordSaison(
                titre: "Plus de passes",
                valeur: "\(top.passesDecisives)",
                detail: "\(nom) — \(match)",
                icone: "arrow.triangle.branch",
                couleur: PaletteMat.vert
            ))
        }

        return results
    }

    // MARK: - Calculs records équipe

    private func calculerRecordsEquipe() -> [RecordSaison] {
        var results: [RecordSaison] = []

        // Plus de points marqués par l'équipe dans un match
        var meilleursPoints: (seanceID: UUID, points: Int)? = nil
        for match in matchsEquipe {
            let stats = statsEquipe.filter { $0.seanceID == match.id }
            let pts = stats.reduce(0) { $0 + $1.points }
            if pts > 0 && pts > (meilleursPoints?.points ?? 0) {
                meilleursPoints = (match.id, pts)
            }
        }
        if let top = meilleursPoints {
            results.append(RecordSaison(
                titre: "Plus de points (équipe)",
                valeur: "\(top.points)",
                detail: nomMatch(top.seanceID),
                icone: "flame.circle.fill",
                couleur: PaletteMat.orange
            ))
        }

        // Meilleur hitting % équipe dans un match (min 20 tentatives)
        var meilleurHit: (seanceID: UUID, pct: Double)? = nil
        for match in matchsEquipe {
            let stats = statsEquipe.filter { $0.seanceID == match.id }
            let ta = stats.reduce(0) { $0 + $1.tentativesAttaque }
            guard ta >= 20 else { continue }
            let k = stats.reduce(0) { $0 + $1.kills }
            let e = stats.reduce(0) { $0 + $1.erreursAttaque }
            let pct = Double(k - e) / Double(ta)
            if pct > (meilleurHit?.pct ?? -.infinity) {
                meilleurHit = (match.id, pct)
            }
        }
        if let top = meilleurHit {
            results.append(RecordSaison(
                titre: "Meilleur hitting % équipe",
                valeur: String(format: "%.3f", top.pct),
                detail: nomMatch(top.seanceID),
                icone: "chart.line.uptrend.xyaxis",
                couleur: PaletteMat.vert
            ))
        }

        // Plus grand écart de score en faveur
        if let top = matchsEquipe
            .filter({ $0.scoreEntre && $0.scoreEquipe > $0.scoreAdversaire })
            .max(by: { ($0.scoreEquipe - $0.scoreAdversaire) < ($1.scoreEquipe - $1.scoreAdversaire) }) {
            let ecart = top.scoreEquipe - top.scoreAdversaire
            results.append(RecordSaison(
                titre: "Plus grand écart (V)",
                valeur: "+\(ecart)",
                detail: "\(top.scoreEquipe)-\(top.scoreAdversaire) vs \(top.adversaire.isEmpty ? "?" : top.adversaire)",
                icone: "arrow.up.right",
                couleur: PaletteMat.vert
            ))
        }

        // Plus d'aces équipe dans un match
        var meilleursAces: (seanceID: UUID, aces: Int)? = nil
        for match in matchsEquipe {
            let total = statsEquipe.filter { $0.seanceID == match.id }.reduce(0) { $0 + $1.aces }
            if total > 0 && total > (meilleursAces?.aces ?? 0) {
                meilleursAces = (match.id, total)
            }
        }
        if let top = meilleursAces {
            results.append(RecordSaison(
                titre: "Plus d'aces (équipe)",
                valeur: "\(top.aces)",
                detail: nomMatch(top.seanceID),
                icone: "tennisball.fill",
                couleur: PaletteMat.bleu
            ))
        }

        // Plus de blocs équipe dans un match
        var meilleursBlocs: (seanceID: UUID, blocs: Int)? = nil
        for match in matchsEquipe {
            let total = statsEquipe.filter { $0.seanceID == match.id }.reduce(0) { $0 + $1.blocsSeuls + $1.blocsAssistes }
            if total > 0 && total > (meilleursBlocs?.blocs ?? 0) {
                meilleursBlocs = (match.id, total)
            }
        }
        if let top = meilleursBlocs {
            results.append(RecordSaison(
                titre: "Plus de blocs (équipe)",
                valeur: "\(top.blocs)",
                detail: nomMatch(top.seanceID),
                icone: "hand.raised.fill",
                couleur: PaletteMat.violet
            ))
        }

        return results
    }

    // MARK: - Helpers

    private func nomJoueur(_ id: UUID) -> String {
        joueursEquipe.first(where: { $0.id == id })?.nomComplet ?? "Inconnu"
    }

    private func nomMatch(_ seanceID: UUID) -> String {
        guard let match = matchsEquipe.first(where: { $0.id == seanceID }) else { return "" }
        let adversaire = match.adversaire.isEmpty ? "?" : match.adversaire
        return "vs \(adversaire) (\(match.date.formatCourt()))"
    }

    // MARK: - Mise à jour

    private func mettreAJour() {
        matchsEquipe = seances.filtreEquipe(codeEquipeActif)
        statsEquipe = statsMatchs.filtreEquipe(codeEquipeActif)
        joueursEquipe = joueurs.filtreEquipe(codeEquipeActif)
    }
}
