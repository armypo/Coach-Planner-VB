//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Filtres unifiés des vues de statistiques (Phase 1.5 refonte) : une seule
//  rangée de menus (match / set / joueur / phase) partagée par Analytics,
//  Rotations, Heatmap et Évolution — fini les filtres ad hoc par vue.
//  Chaque menu n'apparaît que si des données lui sont fournies.
//

import SwiftUI

/// État partagé des filtres — injecter via @State et passer aux calculs.
@Observable
final class FiltresStatsModel {
    var seanceID: UUID?
    var set: Int?
    var joueurID: UUID?
    var phaseID: UUID?

    /// Applique les filtres match/set/joueur à une liste de points.
    /// Le filtre de PHASE ne s'applique PAS ici (il porte sur les matchs) :
    /// passer `seancesDeLaPhase` pour restreindre aussi par phase.
    func filtrer(_ points: [PointMatch], seancesDeLaPhase: Set<UUID>? = nil) -> [PointMatch] {
        points.filter { point in
            (seanceID == nil || point.seanceID == seanceID)
                && (set == nil || point.set == set)
                && (joueurID == nil || point.joueurID == joueurID)
                && (seancesDeLaPhase == nil || seancesDeLaPhase!.contains(point.seanceID))
        }
    }

    /// Applique les filtres match + phase à une liste de matchs.
    /// Les bornes de phase sont élargies à la journée entière (l'heure de
    /// création de la PhaseSaison ne doit pas exclure des matchs limites).
    func filtrer(_ matchs: [Seance], phases: [PhaseSaison]) -> [Seance] {
        var resultat = matchs
        if let seanceID {
            resultat = resultat.filter { $0.id == seanceID }
        }
        if let phaseID, let phase = phases.first(where: { $0.id == phaseID }) {
            let calendrier = Calendar.current
            let debut = calendrier.startOfDay(for: phase.dateDebut)
            let finJour = calendrier.startOfDay(for: phase.dateFin)
            let fin = calendrier.date(byAdding: .day, value: 1, to: finJour) ?? phase.dateFin
            resultat = resultat.filter { $0.date >= debut && $0.date < fin }
        }
        return resultat
    }
}

/// Rangée de filtres du kit stats. Fournir uniquement les collections
/// pertinentes pour la vue — les menus vides sont masqués.
struct FiltresStats: View {
    @Bindable var modele: FiltresStatsModel
    var matchs: [Seance] = []
    var setsDisponibles: [Int] = []
    var joueurs: [JoueurEquipe] = []
    var phases: [PhaseSaison] = []

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: LiquidGlassKit.espaceSM) {
                if !matchs.isEmpty {
                    menuFiltre(
                        label: libelleMatch,
                        estActif: modele.seanceID != nil
                    ) {
                        Button("Tous les matchs") { modele.seanceID = nil }
                        ForEach(matchs) { match in
                            Button(titreMatch(match)) { modele.seanceID = match.id }
                        }
                    }
                }

                if !setsDisponibles.isEmpty {
                    menuFiltre(
                        label: modele.set.map { "Set \($0)" } ?? "Tous les sets",
                        estActif: modele.set != nil
                    ) {
                        Button("Tous les sets") { modele.set = nil }
                        ForEach(setsDisponibles, id: \.self) { numero in
                            Button("Set \(numero)") { modele.set = numero }
                        }
                    }
                }

                if !joueurs.isEmpty {
                    menuFiltre(
                        label: libelleJoueur,
                        estActif: modele.joueurID != nil
                    ) {
                        Button("Toute l'équipe") { modele.joueurID = nil }
                        ForEach(joueurs) { joueur in
                            Button("#\(joueur.numero) \(joueur.prenom) \(joueur.nom)") {
                                modele.joueurID = joueur.id
                            }
                        }
                    }
                }

                if !phases.isEmpty {
                    menuFiltre(
                        label: libellePhase,
                        estActif: modele.phaseID != nil
                    ) {
                        Button("Toute la saison") { modele.phaseID = nil }
                        ForEach(phases) { phase in
                            Button(phase.nom) { modele.phaseID = phase.id }
                        }
                    }
                }
            }
            .padding(.horizontal, 1)
        }
    }

    // MARK: - Libellés

    private var libelleMatch: String {
        guard let id = modele.seanceID,
              let match = matchs.first(where: { $0.id == id }) else { return "Tous les matchs" }
        return titreMatch(match)
    }

    private var libelleJoueur: String {
        guard let id = modele.joueurID,
              let joueur = joueurs.first(where: { $0.id == id }) else { return "Toute l'équipe" }
        return "#\(joueur.numero) \(joueur.nom)"
    }

    private var libellePhase: String {
        guard let id = modele.phaseID,
              let phase = phases.first(where: { $0.id == id }) else { return "Toute la saison" }
        return phase.nom
    }

    private func titreMatch(_ match: Seance) -> String {
        match.adversaire.isEmpty ? match.nom : "vs \(match.adversaire)"
    }

    // MARK: - Style

    private func menuFiltre<Contenu: View>(
        label: String, estActif: Bool, @ViewBuilder contenu: () -> Contenu
    ) -> some View {
        Menu {
            contenu()
        } label: {
            HStack(spacing: LiquidGlassKit.espaceXS) {
                Text(label)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(estActif ? .white : PaletteMat.textePrincipal)
            .padding(.horizontal, LiquidGlassKit.espaceSM + 4)
            .frame(minHeight: 44)
            .contentShape(Capsule())
            .background(
                estActif ? AnyShapeStyle(PaletteMat.bleu) : AnyShapeStyle(.ultraThinMaterial),
                in: Capsule()
            )
        }
        .accessibilityLabel("Filtre : \(label)")
    }
}
