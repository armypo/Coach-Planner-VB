//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "SaisieStatsMatchView")

/// Saisie des statistiques d'un match par joueur — sauvegarde + sync vers stats cumulées
struct SaisieStatsMatchView: View {
    @Bindable var seance: Seance

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Query(filter: #Predicate<JoueurEquipe> { $0.estActif == true },
           sort: \JoueurEquipe.numero) private var joueurs: [JoueurEquipe]
    @Query private var tousStatsMatch: [StatsMatch]

    @State private var joueurSelectionne: JoueurEquipe?
    @State private var confirmeSauvegarde = false
    @State private var afficherLegende = false

    private var joueursEquipe: [JoueurEquipe] {
        joueurs.filtreEquipe(codeEquipeActif)
    }

    /// Stats de ce match uniquement
    private var statsMatch: [StatsMatch] {
        tousStatsMatch.filter { $0.seanceID == seance.id }
    }

    /// Obtenir ou créer le StatsMatch pour un joueur
    private func stats(pour joueur: JoueurEquipe) -> StatsMatch {
        if let existant = statsMatch.first(where: { $0.joueurID == joueur.id }) {
            return existant
        }
        let nouveau = StatsMatch(seanceID: seance.id, joueurID: joueur.id)
        nouveau.codeEquipe = codeEquipeActif
        modelContext.insert(nouveau)
        return nouveau
    }

    var body: some View {
        VStack(spacing: 0) {
            // En-tête match
            enteteMatch

            Divider()

            if joueursEquipe.isEmpty {
                etatVide
            } else {
                // Sélecteur joueur
                selecteurJoueur

                Divider()

                // Formulaire stats du joueur sélectionné
                if let joueur = joueurSelectionne {
                    formulaireStats(joueur: joueur)
                } else {
                    ContentUnavailableView {
                        Text("Sélectionnez un joueur")
                            .font(.subheadline.weight(.semibold))
                    } description: {
                        Text("Touchez un joueur dans la bande ci-dessus pour saisir ses statistiques du match.")
                    }
                }
            }
        }
        .navigationTitle("Stats du match")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fermer") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Légende") { afficherLegende = true }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    sauvegarderEtSync()
                } label: {
                    Label("Sauvegarder", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .sheet(isPresented: $afficherLegende) {
            LegendeStatsSheet()
        }
        .alert("Stats sauvegardées", isPresented: $confirmeSauvegarde) {
            Button("OK") { dismiss() }
        } message: {
            Text("Les statistiques du match ont été enregistrées et synchronisées avec les profils des joueurs.")
        }
        .onAppear {
            joueurSelectionne = joueursEquipe.first
        }
    }

    // MARK: - En-tête

    private var enteteMatch: some View {
        HStack(spacing: LiquidGlassKit.espaceSM + 4) {
            VStack(alignment: .leading, spacing: 2) {
                Text(seance.nom)
                    .font(.subheadline.weight(.bold))
                if !seance.adversaire.isEmpty {
                    Text("vs \(seance.adversaire)")
                        .font(.caption)
                        .foregroundStyle(PaletteMat.negatif)
                }
            }
            Spacer()
            if seance.scoreEntre {
                Text("\(seance.scoreEquipe) - \(seance.scoreAdversaire)")
                    .font(.title3.weight(.bold))
                    .contentTransition(.numericText())
                if let r = seance.resultat {
                    Text(r.label)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(r.couleur, in: Capsule())
                }
            }
        }
        .padding(LiquidGlassKit.espaceMD)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Sélecteur joueur

    private var selecteurJoueur: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(joueursEquipe) { joueur in
                    let estSelectionne = joueurSelectionne?.id == joueur.id
                    let aDesStats = statsMatch.first(where: { $0.joueurID == joueur.id }).map { $0.points > 0 } ?? false

                    Button {
                        joueurSelectionne = joueur
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(estSelectionne ? joueur.poste.couleur : joueur.poste.couleur.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Text("#\(joueur.numero)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(estSelectionne ? .white : joueur.poste.couleur)
                            }
                            Text(joueur.prenom)
                                .font(.caption2)
                                .foregroundStyle(estSelectionne ? .primary : .secondary)
                                .lineLimit(1)
                            if aDesStats {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 5, height: 5)
                            }
                        }
                        .frame(width: 52)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, LiquidGlassKit.espaceMD)
            .padding(.vertical, LiquidGlassKit.espaceSM + 2)
        }
    }

    // MARK: - Formulaire stats

    private func formulaireStats(joueur: JoueurEquipe) -> some View {
        let s = stats(pour: joueur)
        return ScrollView {
            VStack(spacing: LiquidGlassKit.espaceMD) {
                // Général
                groupeStat(titre: "Général", icone: "sportscourt", couleur: PaletteMat.texteSecondaire) {
                    ligneStepper("Sets joués", valeur: Binding(get: { s.setsJoues }, set: { s.setsJoues = $0 }))
                }

                // Attaque — rendement affiché en convention volleyball (D2)
                groupeStat(titre: "Attaque", icone: "flame.fill", couleur: PaletteMat.orange,
                           detail: "Rendement " + FormatMetriques.hittingVolley(
                               MetriquesVolley.rendementAttaque(kills: s.kills,
                                                                erreurs: s.erreursAttaque,
                                                                tentatives: s.tentativesAttaque))) {
                    ligneStepper("Kills", valeur: Binding(get: { s.kills }, set: { s.kills = $0 }))
                    ligneStepper("Erreurs", valeur: Binding(get: { s.erreursAttaque }, set: { s.erreursAttaque = $0 }))
                    ligneStepper("Tentatives", valeur: Binding(get: { s.tentativesAttaque }, set: { s.tentativesAttaque = $0 }))
                }

                // Service
                groupeStat(titre: "Service", icone: "arrow.up.forward", couleur: PaletteMat.bleu) {
                    ligneStepper("Aces", valeur: Binding(get: { s.aces }, set: { s.aces = $0 }))
                    ligneStepper("Erreurs", valeur: Binding(get: { s.erreursService }, set: { s.erreursService = $0 }))
                    ligneStepper("Tentatives", valeur: Binding(get: { s.servicesTotaux }, set: { s.servicesTotaux = $0 }))
                }

                // Bloc
                groupeStat(titre: "Bloc", icone: "shield.fill", couleur: PaletteMat.violet) {
                    ligneStepper("Blocs seuls", valeur: Binding(get: { s.blocsSeuls }, set: { s.blocsSeuls = $0 }))
                    ligneStepper("Blocs assistés", valeur: Binding(get: { s.blocsAssistes }, set: { s.blocsAssistes = $0 }))
                    ligneStepper("Erreurs", valeur: Binding(get: { s.erreursBloc }, set: { s.erreursBloc = $0 }))
                }

                // Réception
                groupeStat(titre: "Réception", icone: "arrow.down.to.line", couleur: PaletteMat.vert,
                           detail: "Réc. eff. " + FormatMetriques.pourcentage(
                               MetriquesVolley.efficaciteReception(reussies: s.receptionsReussies,
                                                                   erreurs: s.erreursReception,
                                                                   totales: s.receptionsTotales))) {
                    ligneStepper("Réussies", valeur: Binding(get: { s.receptionsReussies }, set: { s.receptionsReussies = $0 }))
                    ligneStepper("Erreurs", valeur: Binding(get: { s.erreursReception }, set: { s.erreursReception = $0 }))
                    ligneStepper("Totales", valeur: Binding(get: { s.receptionsTotales }, set: { s.receptionsTotales = $0 }))
                }

                // Jeu
                groupeStat(titre: "Jeu", icone: "figure.volleyball", couleur: PaletteMat.attention) {
                    ligneStepper("Passes déc.", valeur: Binding(get: { s.passesDecisives }, set: { s.passesDecisives = $0 }))
                    ligneStepper("Manchettes", valeur: Binding(get: { s.manchettes }, set: { s.manchettes = $0 }))
                }
            }
            .padding(LiquidGlassKit.espaceMD)
        }
        .id(joueur.id) // force refresh quand on change de joueur
    }

    /// Groupe de champs par catégorie : en-tête coloré (icône de catégorie +
    /// titre) + lecture optionnelle de la métrique dérivée (D2) à droite.
    private func groupeStat(titre: String, icone: String, couleur: Color,
                            detail: String? = nil,
                            @ViewBuilder contenu: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            HStack {
                Label(titre, systemImage: icone)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(couleur)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if let detail {
                    Text(detail)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }
            contenu()
        }
        .padding(LiquidGlassKit.espaceSM + 4)
        .background(
            RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func ligneStepper(_ label: String, valeur: Binding<Int>) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            HStack(spacing: LiquidGlassKit.espaceSM) {
                Button {
                    if valeur.wrappedValue > 0 { valeur.wrappedValue -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Retirer, \(label)")

                Text("\(valeur.wrappedValue)")
                    .font(TypographieStats.valeurCarte)
                    .frame(minWidth: 40)
                    .multilineTextAlignment(.center)
                    .contentTransition(.numericText())
                    .animation(LiquidGlassKit.springDefaut, value: valeur.wrappedValue)

                Button {
                    valeur.wrappedValue += 1
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(PaletteMat.orange)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ajouter, \(label)")
            }
        }
    }

    // MARK: - État vide

    private var etatVide: some View {
        ContentUnavailableView {
            Label("Aucun joueur actif", systemImage: "person.3")
        } description: {
            Text("Ajoutez des joueurs à l'équipe depuis la section Équipe pour saisir leurs statistiques de match.")
        }
    }

    // MARK: - Sauvegarder et synchroniser

    private func sauvegarderEtSync() {
        // Resynchronisation idempotente (fix B2) : le cumul carrière est
        // RECALCULÉ depuis la somme des StatsMatch — re-taper « Sauvegarder »
        // ne double plus les stats et répare les cumuls déjà doublés.
        let statsEquipe = tousStatsMatch.filtreEquipe(codeEquipeActif)
        let joueursTouches = joueursEquipe.filter { joueur in
            statsMatch.contains { $0.joueurID == joueur.id }
        }
        AgregateurStatsMatch.resynchroniserCumul(joueurs: joueursTouches, statsMatch: statsEquipe)
        for joueur in joueursTouches {
            // Bump pour que le sweep coach republie les stats à jour vers la Public DB.
            joueur.dateModification = Date()
        }

        seance.statsEntrees = true
        seance.dateModification = Date()  // score/stats du match modifiés → republier la séance
        do {
            try modelContext.save()
            confirmeSauvegarde = true
        } catch {
            logger.error("Erreur sauvegarde stats match: \(error.localizedDescription)")
        }
    }
}
