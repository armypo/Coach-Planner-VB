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
                    Text("Sélectionnez un joueur")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .navigationTitle("Stats du match")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fermer") { dismiss() }
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
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(seance.nom)
                    .font(.subheadline.weight(.bold))
                if !seance.adversaire.isEmpty {
                    Text("vs \(seance.adversaire)")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            Spacer()
            if seance.scoreEntre {
                Text("\(seance.scoreEquipe) - \(seance.scoreAdversaire)")
                    .font(.title3.weight(.bold))
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
        .padding(16)
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
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Formulaire stats

    private func formulaireStats(joueur: JoueurEquipe) -> some View {
        let s = stats(pour: joueur)
        return ScrollView {
            VStack(spacing: 16) {
                // Général
                groupeStat(titre: "Général", icone: "sportscourt", couleur: .blue) {
                    ligneStepper("Sets joués", valeur: Binding(get: { s.setsJoues }, set: { s.setsJoues = $0 }))
                }

                // Attaque
                groupeStat(titre: "Attaque", icone: "flame.fill", couleur: .green) {
                    ligneStepper("Kills", valeur: Binding(get: { s.kills }, set: { s.kills = $0 }))
                    ligneStepper("Erreurs", valeur: Binding(get: { s.erreursAttaque }, set: { s.erreursAttaque = $0 }))
                    ligneStepper("Tentatives", valeur: Binding(get: { s.tentativesAttaque }, set: { s.tentativesAttaque = $0 }))
                }

                // Service
                groupeStat(titre: "Service", icone: "arrow.up.forward", couleur: .yellow) {
                    ligneStepper("Aces", valeur: Binding(get: { s.aces }, set: { s.aces = $0 }))
                    ligneStepper("Erreurs", valeur: Binding(get: { s.erreursService }, set: { s.erreursService = $0 }))
                    ligneStepper("Tentatives", valeur: Binding(get: { s.servicesTotaux }, set: { s.servicesTotaux = $0 }))
                }

                // Bloc
                groupeStat(titre: "Bloc", icone: "hand.raised.fill", couleur: .red) {
                    ligneStepper("Blocs seuls", valeur: Binding(get: { s.blocsSeuls }, set: { s.blocsSeuls = $0 }))
                    ligneStepper("Blocs assistés", valeur: Binding(get: { s.blocsAssistes }, set: { s.blocsAssistes = $0 }))
                    ligneStepper("Erreurs", valeur: Binding(get: { s.erreursBloc }, set: { s.erreursBloc = $0 }))
                }

                // Réception
                groupeStat(titre: "Réception", icone: "arrow.down.to.line", couleur: .purple) {
                    ligneStepper("Réussies", valeur: Binding(get: { s.receptionsReussies }, set: { s.receptionsReussies = $0 }))
                    ligneStepper("Erreurs", valeur: Binding(get: { s.erreursReception }, set: { s.erreursReception = $0 }))
                    ligneStepper("Totales", valeur: Binding(get: { s.receptionsTotales }, set: { s.receptionsTotales = $0 }))
                }

                // Jeu
                groupeStat(titre: "Jeu", icone: "figure.volleyball", couleur: .teal) {
                    ligneStepper("Passes déc.", valeur: Binding(get: { s.passesDecisives }, set: { s.passesDecisives = $0 }))
                    ligneStepper("Manchettes", valeur: Binding(get: { s.manchettes }, set: { s.manchettes = $0 }))
                }
            }
            .padding(16)
        }
        .id(joueur.id) // force refresh quand on change de joueur
    }

    private func groupeStat(titre: String, icone: String, couleur: Color, @ViewBuilder contenu: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(titre, systemImage: icone)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(couleur)
            contenu()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func ligneStepper(_ label: String, valeur: Binding<Int>) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            HStack(spacing: 12) {
                Button {
                    if valeur.wrappedValue > 0 { valeur.wrappedValue -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Text("\(valeur.wrappedValue)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .frame(width: 36)
                    .multilineTextAlignment(.center)

                Button {
                    valeur.wrappedValue += 1
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(PaletteMat.orange)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - État vide

    private var etatVide: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "person.3")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Aucun joueur actif")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sauvegarder et synchroniser

    private func sauvegarderEtSync() {
        // Sync : ajouter les stats du match aux stats cumulées des joueurs
        for stat in statsMatch {
            guard let joueur = joueursEquipe.first(where: { $0.id == stat.joueurID }) else { continue }

            joueur.matchsJoues += 1
            joueur.setsJoues += stat.setsJoues

            joueur.attaquesReussies += stat.kills
            joueur.erreursAttaque += stat.erreursAttaque
            joueur.attaquesTotales += stat.tentativesAttaque

            joueur.aces += stat.aces
            joueur.erreursService += stat.erreursService
            joueur.servicesTotaux += stat.servicesTotaux

            joueur.blocsSeuls += stat.blocsSeuls
            joueur.blocsAssistes += stat.blocsAssistes
            joueur.erreursBloc += stat.erreursBloc

            joueur.receptionsReussies += stat.receptionsReussies
            joueur.erreursReception += stat.erreursReception
            joueur.receptionsTotales += stat.receptionsTotales

            joueur.passesDecisives += stat.passesDecisives
            joueur.manchettes += stat.manchettes
        }

        seance.statsEntrees = true
        do {
            try modelContext.save()
            confirmeSauvegarde = true
        } catch {
            logger.error("Erreur sauvegarde stats match: \(error.localizedDescription)")
        }
    }
}
