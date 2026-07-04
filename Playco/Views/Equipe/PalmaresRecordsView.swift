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

    /// Callback de navigation injecté par EquipeView (même pattern que TableauBordView).
    var onNaviguer: ((EquipeView.EquipeNavItem) -> Void)? = nil

    @State private var matchsEquipe: [Seance] = []
    @State private var statsEquipe: [StatsMatch] = []
    @State private var joueursEquipe: [JoueurEquipe] = []

    // Caches @State des records — calculerRecords…() n'est plus appelé à chaque render
    @State private var recordsIndividuels: [RecordSaison] = []
    @State private var recordsEquipe: [RecordSaison] = []

    /// Minimum de tentatives d'attaque pour qualifier un record de rendement individuel.
    private static let minTentativesIndividuel = 10
    /// Minimum de tentatives d'attaque pour qualifier un record de rendement d'équipe.
    private static let minTentativesEquipe = 20

    /// Invalide le cache sur mutation in-place (score/stats saisis) — .onChange(collection) ne voit que les insertions/suppressions.
    private var signatureRecords: Int {
        seances.reduce(0) { $0 + $1.scoreEquipe + $1.scoreAdversaire }
            + statsMatchs.reduce(0) { $0 + $1.kills }
    }

    struct RecordSaison: Identifiable {
        let id = UUID()
        let titre: String
        let valeur: String
        let sousTitre: String
        /// Détenteur du record — permet la navigation vers la fiche joueur (nil pour les records d'équipe).
        let joueurID: UUID?
        let teinte: Color
        let definition: DefinitionMetrique?
    }

    var body: some View {
        ScrollView {
            VStack(spacing: LiquidGlassKit.espaceLG) {
                if recordsIndividuels.isEmpty && recordsEquipe.isEmpty {
                    ContentUnavailableView(
                        "Pas de records",
                        systemImage: "trophy",
                        description: Text("Jouez des matchs et entrez des stats pour voir le palmarès.")
                    )
                } else {
                    sectionRecordsIndividuels
                    sectionRecordsEquipe
                }
            }
            .padding(LiquidGlassKit.espaceLG)
        }
        .navigationTitle("Palmarès & records")
        .onAppear { mettreAJour() }
        .onChange(of: codeEquipeActif) { _, _ in mettreAJour() }
        .onChange(of: seances) { mettreAJour() }
        .onChange(of: statsMatchs) { mettreAJour() }
        .onChange(of: signatureRecords) { mettreAJour() }
        .onChange(of: joueurs) { mettreAJour() }
    }

    // MARK: - Records individuels

    private var sectionRecordsIndividuels: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceMD) {
            EnTeteSection(titre: "Records individuels",
                          sousTitre: "Meilleure performance dans un match")

            if recordsIndividuels.isEmpty {
                Text("Aucun record individuel — entrez les stats d'un match pour commencer.")
                    .font(.caption)
                    .foregroundStyle(PaletteMat.texteTertiaire)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                          spacing: LiquidGlassKit.espaceSM + 4) {
                    ForEach(recordsIndividuels) { record in
                        carteRecordIndividuel(record)
                    }
                }
            }
        }
        .padding(LiquidGlassKit.espaceMD)
        .glassCard(teinte: PaletteMat.orange, cornerRadius: LiquidGlassKit.rayonMoyen)
    }

    // MARK: - Records équipe

    private var sectionRecordsEquipe: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceMD) {
            EnTeteSection(titre: "Records d'équipe",
                          sousTitre: "Meilleure performance collective dans un match")

            if recordsEquipe.isEmpty {
                Text("Aucun record d'équipe — entrez les stats d'un match pour commencer.")
                    .font(.caption)
                    .foregroundStyle(PaletteMat.texteTertiaire)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                          spacing: LiquidGlassKit.espaceSM + 4) {
                    ForEach(recordsEquipe) { record in
                        carteMetrique(record)
                    }
                }
            }
        }
        .padding(LiquidGlassKit.espaceMD)
        .glassCard(teinte: PaletteMat.bleu, cornerRadius: LiquidGlassKit.rayonMoyen)
    }

    // MARK: - Cartes record

    /// Record individuel : cliquable vers la fiche joueur quand le câblage
    /// de navigation est présent et que le détenteur est identifiable.
    @ViewBuilder
    private func carteRecordIndividuel(_ record: RecordSaison) -> some View {
        if let onNaviguer, let joueurID = record.joueurID {
            Button {
                onNaviguer(.joueur(joueurID))
            } label: {
                carteMetrique(record)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .padding(LiquidGlassKit.espaceSM)
                    }
            }
            .buttonStyle(GlassButtonStyle())
            .accessibilityHint("Affiche la fiche du joueur")
        } else {
            carteMetrique(record)
        }
    }

    private func carteMetrique(_ record: RecordSaison) -> some View {
        CarteMetrique(titre: record.titre,
                      valeur: record.valeur,
                      sousTitre: record.sousTitre,
                      teinte: record.teinte,
                      definition: record.definition)
    }

    // MARK: - Calculs records individuels

    private func calculerRecordsIndividuels() -> [RecordSaison] {
        var results: [RecordSaison] = []

        // Record kills dans un match
        if let top = statsEquipe.max(by: { $0.kills < $1.kills }), top.kills > 0 {
            results.append(RecordSaison(
                titre: "Plus de kills",
                valeur: "\(top.kills)",
                sousTitre: sousTitreIndividuel(top),
                joueurID: top.joueurID,
                teinte: PaletteMat.orange,
                definition: definitionMetrique("K")
            ))
        }

        // Record aces dans un match
        if let top = statsEquipe.max(by: { $0.aces < $1.aces }), top.aces > 0 {
            results.append(RecordSaison(
                titre: "Plus d'aces",
                valeur: "\(top.aces)",
                sousTitre: sousTitreIndividuel(top),
                joueurID: top.joueurID,
                teinte: PaletteMat.bleu,
                definition: definitionMetrique("AC")
            ))
        }

        // Record blocs dans un match
        let topBlocs = statsEquipe.max(by: { ($0.blocsSeuls + $0.blocsAssistes) < ($1.blocsSeuls + $1.blocsAssistes) })
        if let top = topBlocs, (top.blocsSeuls + top.blocsAssistes) > 0 {
            results.append(RecordSaison(
                titre: "Plus de blocs",
                valeur: "\(top.blocsSeuls + top.blocsAssistes)",
                sousTitre: sousTitreIndividuel(top),
                joueurID: top.joueurID,
                teinte: PaletteMat.violet,
                definition: nil
            ))
        }

        // Meilleur rendement attaque dans un match (min 10 tentatives)
        let avecTA = statsEquipe.filter { $0.tentativesAttaque >= Self.minTentativesIndividuel }
        if let top = avecTA.max(by: { $0.hittingPct < $1.hittingPct }) {
            results.append(RecordSaison(
                titre: "Meilleur rendement",
                valeur: FormatMetriques.hittingVolley(top.hittingPct),
                sousTitre: sousTitreIndividuel(top),
                joueurID: top.joueurID,
                teinte: PaletteMat.vert,
                definition: definitionMetrique("Rend.")
            ))
        }

        // Record points dans un match
        if let top = statsEquipe.max(by: { $0.points < $1.points }), top.points > 0 {
            results.append(RecordSaison(
                titre: "Plus de points",
                valeur: "\(top.points)",
                sousTitre: sousTitreIndividuel(top),
                joueurID: top.joueurID,
                teinte: PaletteMat.orange,
                definition: definitionMetrique("Pts")
            ))
        }

        // Record passes décisives dans un match
        if let top = statsEquipe.max(by: { $0.passesDecisives < $1.passesDecisives }), top.passesDecisives > 0 {
            results.append(RecordSaison(
                titre: "Plus de passes décisives",
                valeur: "\(top.passesDecisives)",
                sousTitre: sousTitreIndividuel(top),
                joueurID: top.joueurID,
                teinte: PaletteMat.vert,
                definition: definitionMetrique("PD")
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
                sousTitre: nomMatch(top.seanceID),
                joueurID: nil,
                teinte: PaletteMat.orange,
                definition: definitionMetrique("Pts")
            ))
        }

        // Meilleur rendement attaque équipe dans un match (min 20 tentatives)
        var meilleurRendement: (seanceID: UUID, rendement: Double)? = nil
        for match in matchsEquipe {
            let stats = statsEquipe.filter { $0.seanceID == match.id }
            let ta = stats.reduce(0) { $0 + $1.tentativesAttaque }
            guard ta >= Self.minTentativesEquipe else { continue }
            let k = stats.reduce(0) { $0 + $1.kills }
            let e = stats.reduce(0) { $0 + $1.erreursAttaque }
            let rendement = MetriquesVolley.rendementAttaque(kills: k, erreurs: e, tentatives: ta)
            if rendement > (meilleurRendement?.rendement ?? -.infinity) {
                meilleurRendement = (match.id, rendement)
            }
        }
        if let top = meilleurRendement {
            results.append(RecordSaison(
                titre: "Meilleur rendement (équipe)",
                valeur: FormatMetriques.hittingVolley(top.rendement),
                sousTitre: nomMatch(top.seanceID),
                joueurID: nil,
                teinte: PaletteMat.vert,
                definition: definitionMetrique("Rend.")
            ))
        }

        // Plus grand écart de score en faveur
        if let top = matchsEquipe
            .filter({ $0.scoreEntre && $0.scoreEquipe > $0.scoreAdversaire })
            .max(by: { ($0.scoreEquipe - $0.scoreAdversaire) < ($1.scoreEquipe - $1.scoreAdversaire) }) {
            let ecart = top.scoreEquipe - top.scoreAdversaire
            let adversaire = top.adversaire.isEmpty ? "?" : top.adversaire
            results.append(RecordSaison(
                titre: "Plus grand écart (victoire)",
                valeur: "+\(ecart)",
                sousTitre: "\(top.scoreEquipe)-\(top.scoreAdversaire) vs \(adversaire) (\(top.date.formatCourt()))",
                joueurID: nil,
                teinte: PaletteMat.vert,
                definition: nil
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
                sousTitre: nomMatch(top.seanceID),
                joueurID: nil,
                teinte: PaletteMat.bleu,
                definition: definitionMetrique("AC")
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
                sousTitre: nomMatch(top.seanceID),
                joueurID: nil,
                teinte: PaletteMat.violet,
                definition: nil
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

    /// Sous-titre d'un record individuel : détenteur + contexte du match (adversaire, date) quand disponible.
    private func sousTitreIndividuel(_ stat: StatsMatch) -> String {
        let nom = nomJoueur(stat.joueurID)
        let match = nomMatch(stat.seanceID)
        return match.isEmpty ? nom : "\(nom) — \(match)"
    }

    private func definitionMetrique(_ abreviation: String) -> DefinitionMetrique? {
        MetriquesVolley.catalogue.first { $0.abreviation == abreviation }
    }

    // MARK: - Mise à jour

    private func mettreAJour() {
        matchsEquipe = seances.filtreEquipe(codeEquipeActif)
        statsEquipe = statsMatchs.filtreEquipe(codeEquipeActif)
        joueursEquipe = joueurs.filtreEquipe(codeEquipeActif)
        // Les calculs lisent les caches ci-dessus — ordre important
        recordsIndividuels = calculerRecordsIndividuels()
        recordsEquipe = calculerRecordsEquipe()
    }
}
