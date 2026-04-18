//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "MatchsView")

/// Section Matchs — liste des matchs, détail terrain/notes, stats
struct MatchsView: View {
    var onRetour: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Query(filter: #Predicate<Seance> { $0.estArchivee == false },
           sort: \Seance.date, order: .reverse) private var toutesSeances: [Seance]

    @Query private var tousStatsMatch: [StatsMatch]
    @Query private var tousPoints: [PointMatch]
    @Query private var toutesActionsRallye: [ActionRallye]
    @Query(filter: #Predicate<JoueurEquipe> { $0.estActif == true },
           sort: \JoueurEquipe.numero) private var joueurs: [JoueurEquipe]

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var matchSelectionne: Seance?
    @State private var afficherNouveauMatch = false
    @State private var afficherCalendrier = false
    @State private var afficherHeatmap = false
    @State private var afficherStatsRotation = false

    /// Données filtrées cachées
    @State private var matchs: [Seance] = []
    @State private var matchsAVenir: [Seance] = []
    @State private var matchsPasses: [Seance] = []

    private func recalculerMatchs() {
        matchs = toutesSeances.filtreEquipe(codeEquipeActif).filter { $0.estMatch }
        matchsAVenir = matchs.filter { $0.date > Date() }.sorted { $0.date < $1.date }
        matchsPasses = matchs.filter { $0.date <= Date() }.sorted { $0.date > $1.date }
    }

    private var peutModifier: Bool {
        authService.utilisateurConnecte?.role.peutModifierSeances ?? false
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 380, ideal: 480, max: 580)
                .navigationTitle("Matchs")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        boutonRetour
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button { afficherNouveauMatch = true } label: {
                            Image(systemName: "plus")
                        }
                        .siAutorise(peutModifier)
                        .bloqueSiNonPayant(source: "matchs_create")
                        .accessibilityLabel("Nouveau match")
                        .accessibilityHint("Créer un match avec composition, score et saisie stats en direct")
                    }
                    ToolbarItem(placement: .bottomBar) {
                        HStack(spacing: 20) {
                            Button {
                                afficherCalendrier = true
                            } label: {
                                Label("Calendrier", systemImage: "calendar")
                                    .font(.subheadline.weight(.medium))
                            }
                            Button {
                                afficherHeatmap = true
                            } label: {
                                Label("Heatmap", systemImage: "square.grid.3x3.fill")
                                    .font(.subheadline.weight(.medium))
                            }
                            Button {
                                afficherStatsRotation = true
                            } label: {
                                Label("Rotations", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                    }
                }
        } detail: {
            NavigationStack {
                if let match = matchSelectionne {
                    MatchDetailView(seance: match)
                } else {
                    etatVide
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(.red)
        .sheet(isPresented: $afficherNouveauMatch) {
            NouvelMatchSheet { nom, date, adversaire, lieu in
                let match = Seance(nom: nom, date: date, typeSeance: .match)
                match.adversaire = adversaire
                match.lieu = lieu
                match.codeEquipe = codeEquipeActif
                modelContext.insert(match)
                matchSelectionne = match
            }
        }
        .onAppear { recalculerMatchs() }
        .onChange(of: toutesSeances) { recalculerMatchs() }
        .onChange(of: codeEquipeActif) { recalculerMatchs() }
        .sensoryFeedback(.success, trigger: matchs.count)
        .sheet(isPresented: $afficherCalendrier) {
            NavigationStack {
                CalendrierView()
            }
        }
        .sheet(isPresented: $afficherHeatmap) {
            NavigationStack {
                HeatmapEquipeView()
                    .navigationTitle("Heatmap terrain")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Fermer") { afficherHeatmap = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $afficherStatsRotation) {
            NavigationStack {
                StatsParRotationView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Fermer") { afficherStatsRotation = false }
                        }
                    }
            }
        }
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        List(selection: $matchSelectionne) {
            // Matchs à venir
            if !matchsAVenir.isEmpty {
                Section {
                    ForEach(matchsAVenir) { match in
                        NavigationLink(value: match) {
                            ligneMatch(match)
                        }
                        .swipeActions(edge: .trailing) {
                            if peutModifier {
                                Button(role: .destructive) {
                                    supprimerMatch(match)
                                } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    Label("À venir", systemImage: "calendar.badge.clock")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.red)
                }
            }

            // Matchs passés
            if !matchsPasses.isEmpty {
                Section {
                    ForEach(matchsPasses) { match in
                        NavigationLink(value: match) {
                            ligneMatch(match)
                        }
                        .swipeActions(edge: .trailing) {
                            if peutModifier {
                                Button(role: .destructive) {
                                    supprimerMatch(match)
                                } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    Label("Résultats", systemImage: "flag.checkered")
                        .font(.subheadline.weight(.bold))
                }
            }

            if matchs.isEmpty {
                ContentUnavailableView {
                    Label("Aucun match", systemImage: "flag")
                } description: {
                    Text("Appuyez sur + pour créer un match")
                } actions: {
                    if peutModifier {
                        Button("Nouveau match", systemImage: "plus") {
                            afficherNouveauMatch = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Ligne match

    private func ligneMatch(_ match: Seance) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(match.nom)
                    .font(.subheadline.weight(.medium))
                Spacer()
                if match.scoreEntre {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(match.scoreEquipe)-\(match.scoreAdversaire)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(match.resultat?.couleur ?? .primary)
                        // Détail sets
                        if !match.sets.isEmpty {
                            Text(match.sets.map { "\($0.scoreEquipe)-\($0.scoreAdversaire)" }.joined(separator: " · "))
                                .font(.system(size: 9, weight: .medium).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Text(match.date.formatCourt())
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if !match.adversaire.isEmpty {
                    Text("vs \(match.adversaire)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.red)
                }

                if !match.lieu.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "mappin")
                            .font(.system(size: 8))
                        Text(match.lieu)
                            .font(.caption2)
                    }
                    .foregroundStyle(.tertiary)
                }
            }

        }
        .padding(.vertical, 4)
    }

    // MARK: - État vide

    private var etatVide: some View {
        ContentUnavailableView {
            Label("Sélectionnez un match", systemImage: "flag.fill")
        } description: {
            if peutModifier {
                Text("ou créez-en un nouveau avec +")
            }
        }
    }

    // MARK: - Bouton retour

    // MARK: - Suppression match (cascade stats)

    private func supprimerMatch(_ match: Seance) {
        if matchSelectionne?.id == match.id { matchSelectionne = nil }

        // Si stats déjà entrées → retirer les stats cumulées des joueurs
        if match.statsEntrees {
            let statsASupprimer = tousStatsMatch.filter { $0.seanceID == match.id }
            for stat in statsASupprimer {
                if let joueur = joueurs.first(where: { $0.id == stat.joueurID }) {
                    joueur.matchsJoues = max(0, joueur.matchsJoues - 1)
                    joueur.setsJoues = max(0, joueur.setsJoues - stat.setsJoues)

                    joueur.attaquesReussies = max(0, joueur.attaquesReussies - stat.kills)
                    joueur.erreursAttaque = max(0, joueur.erreursAttaque - stat.erreursAttaque)
                    joueur.attaquesTotales = max(0, joueur.attaquesTotales - stat.tentativesAttaque)

                    joueur.aces = max(0, joueur.aces - stat.aces)
                    joueur.erreursService = max(0, joueur.erreursService - stat.erreursService)
                    joueur.servicesTotaux = max(0, joueur.servicesTotaux - stat.servicesTotaux)

                    joueur.blocsSeuls = max(0, joueur.blocsSeuls - stat.blocsSeuls)
                    joueur.blocsAssistes = max(0, joueur.blocsAssistes - stat.blocsAssistes)
                    joueur.erreursBloc = max(0, joueur.erreursBloc - stat.erreursBloc)

                    joueur.receptionsReussies = max(0, joueur.receptionsReussies - stat.receptionsReussies)
                    joueur.erreursReception = max(0, joueur.erreursReception - stat.erreursReception)
                    joueur.receptionsTotales = max(0, joueur.receptionsTotales - stat.receptionsTotales)

                    joueur.passesDecisives = max(0, joueur.passesDecisives - stat.passesDecisives)
                    joueur.manchettes = max(0, joueur.manchettes - stat.manchettes)
                }
                // Supprimer la ligne StatsMatch
                modelContext.delete(stat)
            }
        }

        // Supprimer les PointMatch associés (données live point-par-point)
        let pointsASupprimer = tousPoints.filter { $0.seanceID == match.id }
        for point in pointsASupprimer {
            modelContext.delete(point)
        }

        // Supprimer les ActionRallye associées
        let actionsASupprimer = toutesActionsRallye.filter { $0.seanceID == match.id }
        for action in actionsASupprimer {
            modelContext.delete(action)
        }

        // Soft delete du match
        match.estArchivee = true
        do {
            try modelContext.save()
        } catch {
            logger.error("Erreur suppression match: \(error.localizedDescription)")
        }
    }

    private var boutonRetour: some View {
        Button {
            onRetour()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                Image(systemName: "volleyball.fill")
                    .font(.system(size: 14))
                Text("Accueil")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.red)
        }
    }
}

// MARK: - Sheet nouveau match

struct NouvelMatchSheet: View {
    var onCreer: (String, Date, String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var nom = ""
    @State private var date = Date()
    @State private var adversaire = ""
    @State private var lieu = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ADVERSAIRE")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                    TextField("Nom de l'équipe adverse", text: $adversaire)
                        .font(.title3)
                        .padding(14)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        .focused($focused)
                        .autocorrectionDisabled()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("NOM DU MATCH (optionnel)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                    TextField("ex : Demi-finale", text: $nom)
                        .padding(14)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        .autocorrectionDisabled()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("DATE DU MATCH")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                    DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "fr_FR"))
                        .tint(.red)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("LIEU")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                    TextField("ex : Domicile, Gymnase XYZ", text: $lieu)
                        .padding(14)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        .autocorrectionDisabled()
                }

                Spacer()
            }
            .padding(24)
            .navigationTitle("Nouveau match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") {
                        let nomFinal = nom.trimmingCharacters(in: .whitespaces).isEmpty
                            ? "Match vs \(adversaire.isEmpty ? "?" : adversaire)"
                            : nom
                        onCreer(nomFinal, date, adversaire, lieu)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear { focused = true }
    }
}
