//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Panneau compact de plan de match (Phase 6 — intégrations live) :
//  lecture seule du scouting le plus récent pour un adversaire donné.
//  Consommé par DashboardMatchLiveView (DisclosureGroup) et MatchDetailView (sheet).
//

import SwiftUI
import SwiftData

/// Panneau LECTURE du plan de match : lookup du `ScoutingReport` le plus
/// récent (non archivé) correspondant au nom d'adversaire, insensible à la
/// casse et aux espaces. Résultat caché en @State (pas de décodage JSON
/// dans le body).
struct PlanMatchPanneau: View {
    let adversaire: String

    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Query(filter: #Predicate<ScoutingReport> { $0.estArchive == false })
    private var tousRapports: [ScoutingReport]

    // Cache — recalculé sur apparition et changements (adversaire, équipe, rapports)
    @State private var rapport: ScoutingReport?
    @State private var strategiesPrioritaires: [StrategieRecommandee] = []
    @State private var joueursMenaces: [JoueurAdverse] = []

    /// Priorité « haute » d'une stratégie recommandée (échelle 1-3, 1 = haute).
    private static let prioriteHaute = 1
    /// Seuil de menace à partir duquel un joueur adverse est mis en avant.
    private static let seuilMenaceElevee = 4
    /// Niveau de menace maximal (échelle 1-5).
    private static let menaceMax = 5

    var body: some View {
        Group {
            if rapport != nil {
                contenuRapport
            } else {
                ContentUnavailableView(
                    "Aucun rapport de scouting pour cet adversaire",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Créez un rapport dans la section Scouting pour le retrouver ici.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, LiquidGlassKit.espaceSM)
            }
        }
        .onAppear { recalculer() }
        .onChange(of: adversaire) { recalculer() }
        .onChange(of: codeEquipeActif) { recalculer() }
        .onChange(of: tousRapports.count) { recalculer() }
    }

    // MARK: - Contenu

    private var contenuRapport: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceMD) {
            // Système / style de jeu en chips
            if let rapport, !rapport.systemJeu.isEmpty || !rapport.styleJeu.isEmpty {
                HStack(spacing: LiquidGlassKit.espaceSM) {
                    if !rapport.systemJeu.isEmpty {
                        chipInfo(label: "Système", valeur: rapport.systemJeu, teinte: PaletteMat.bleu)
                    }
                    if !rapport.styleJeu.isEmpty {
                        chipInfo(label: "Style", valeur: rapport.styleJeu, teinte: PaletteMat.violet)
                    }
                    Spacer(minLength: 0)
                }
            }

            // Stratégies priorité haute
            if !strategiesPrioritaires.isEmpty {
                VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
                    enTete("STRATÉGIES PRIORITAIRES")
                    ForEach(strategiesPrioritaires) { strategie in
                        ligneStrategie(strategie)
                    }
                }
            }

            // Joueurs adverses à menace élevée
            if !joueursMenaces.isEmpty {
                VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
                    enTete("JOUEURS À SURVEILLER")
                    ForEach(joueursMenaces) { joueur in
                        ligneJoueur(joueur)
                    }
                }
            }

            if strategiesPrioritaires.isEmpty && joueursMenaces.isEmpty {
                Text("Rapport trouvé, mais sans stratégie priorité haute ni joueur à menace élevée.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Sous-vues

    private func enTete(_ titre: String) -> some View {
        Text(titre)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .tracking(0.5)
    }

    private func chipInfo(label: String, valeur: String, teinte: Color) -> some View {
        HStack(spacing: LiquidGlassKit.espaceXS) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            Text(valeur)
                .font(.caption.weight(.semibold))
                .foregroundStyle(teinte)
        }
        .padding(.horizontal, LiquidGlassKit.espaceSM + LiquidGlassKit.espaceXS)
        .padding(.vertical, LiquidGlassKit.espaceXS + 2)
        .background(teinte.opacity(LiquidGlassKit.badgeFond), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) : \(valeur)")
    }

    private func ligneStrategie(_ strategie: StrategieRecommandee) -> some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceXS) {
            Text(strategie.titre)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            if !strategie.description.isEmpty {
                Text(strategie.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func ligneJoueur(_ joueur: JoueurAdverse) -> some View {
        HStack(spacing: LiquidGlassKit.espaceSM) {
            Text("#\(joueur.numero)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(PaletteMat.negatif)
            Text(joueur.nom)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            if !joueur.poste.isEmpty {
                Text(joueur.poste)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text("Menace \(joueur.menaceNiveau)/\(Self.menaceMax)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(PaletteMat.negatif)
                .padding(.horizontal, LiquidGlassKit.espaceSM)
                .padding(.vertical, LiquidGlassKit.espaceXS)
                .background(PaletteMat.negatif.opacity(LiquidGlassKit.badgeFond), in: Capsule())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Numéro \(joueur.numero), \(joueur.nom), menace \(joueur.menaceNiveau) sur \(Self.menaceMax)")
    }

    // MARK: - Lookup rapport

    /// Normalisation du nom d'adversaire : insensible à la casse et aux espaces.
    private static func normaliser(_ nom: String) -> String {
        nom.lowercased().filter { !$0.isWhitespace }
    }

    private func recalculer() {
        let cible = Self.normaliser(adversaire)
        guard !cible.isEmpty else {
            rapport = nil
            strategiesPrioritaires = []
            joueursMenaces = []
            return
        }

        let correspondant = tousRapports
            .filtreEquipe(codeEquipeActif)
            .filter { Self.normaliser($0.adversaire) == cible }
            .max { $0.dateCreation < $1.dateCreation }

        rapport = correspondant
        strategiesPrioritaires = correspondant?.strategies
            .filter { $0.priorite == Self.prioriteHaute } ?? []
        joueursMenaces = (correspondant?.joueurs
            .filter { $0.menaceNiveau >= Self.seuilMenaceElevee } ?? [])
            .sorted { $0.menaceNiveau > $1.menaceNiveau }
    }
}
