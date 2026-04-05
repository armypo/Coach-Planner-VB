//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Section Équipe — joueurs, statistiques et tableau de bord
struct EquipeView: View {
    var retour: () -> Void

    @Environment(\.modelContext) private var contexte
    @Environment(AuthService.self) private var authService
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Query(sort: \JoueurEquipe.numero) private var tousJoueurs: [JoueurEquipe]
    @Query(filter: #Predicate<Seance> { $0.estArchivee == false },
           sort: \Seance.date, order: .reverse) private var toutesSeances: [Seance]
    @Query(filter: #Predicate<StrategieCollective> { $0.estArchivee == false })
    private var toutesStrategies: [StrategieCollective]
    @Query private var toutesEquipes: [Equipe]

    /// Données filtrées par équipe (cachées)
    @State private var joueurs: [JoueurEquipe] = []
    @State private var seances: [Seance] = []
    @State private var strategies: [StrategieCollective] = []

    private func recalculerDonnees() {
        joueurs = tousJoueurs.filtreEquipe(codeEquipeActif)
        seances = toutesSeances.filtreEquipe(codeEquipeActif)
        strategies = toutesStrategies.filtreEquipe(codeEquipeActif)
    }

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selection: EquipeNavItem?
    @State private var afficherAjout = false
    @State private var afficherExport = false
    @State private var recherche = ""

    enum EquipeNavItem: Hashable {
        case dashboard
        case analytics
        case palmares
        case joueur(UUID)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 380, ideal: 480, max: 580)
        } detail: {
            NavigationStack {
                switch selection {
                case .dashboard:
                    TableauBordView(joueurs: joueurs, seances: seances, strategies: strategies)
                case .analytics:
                    AnalyticsSaisonView()
                case .palmares:
                    PalmaresRecordsView()
                case .joueur(let id):
                    if let joueur = joueurs.first(where: { $0.id == id }) {
                        JoueurDetailView(joueur: joueur)
                    }
                case nil:
                    TableauBordView(joueurs: joueurs, seances: seances, strategies: strategies)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(.green)
        .sensoryFeedback(.success, trigger: joueurs.count)
        .sheet(isPresented: $afficherAjout) {
            NouveauJoueurView { joueur in
                joueur.codeEquipe = codeEquipeActif
                joueur.equipe = toutesEquipes.first { $0.codeEquipe == codeEquipeActif }
                contexte.insert(joueur)
            }
        }
        .sheet(isPresented: $afficherExport) {
            ExportStatsView()
        }
        .onAppear {
            if selection == nil { selection = .dashboard }
            recalculerDonnees()
        }
        .onChange(of: tousJoueurs) { recalculerDonnees() }
        .onChange(of: toutesSeances) { recalculerDonnees() }
        .onChange(of: toutesStrategies) { recalculerDonnees() }
        .onChange(of: codeEquipeActif) { recalculerDonnees() }
    }

    // MARK: - Sidebar
    private var sidebar: some View {
        List(selection: Binding(
            get: { selection },
            set: { selection = $0 }
        )) {
            // Tableau de bord
            Section {
                NavigationLink(value: EquipeNavItem.dashboard) {
                    Label("Tableau de bord", systemImage: "chart.bar.fill")
                        .font(.subheadline.weight(.medium))
                }
                NavigationLink(value: EquipeNavItem.analytics) {
                    Label("Analytics saison", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.subheadline.weight(.medium))
                }
                NavigationLink(value: EquipeNavItem.palmares) {
                    Label("Palmarès & records", systemImage: "trophy.fill")
                        .font(.subheadline.weight(.medium))
                }
            }

            // Joueurs par poste (filtrés par recherche)
            ForEach(PosteJoueur.allCases, id: \.self) { poste in
                let joueursPoste = joueurs.filter {
                    $0.posteRaw == poste.rawValue && $0.estActif &&
                    (recherche.isEmpty || $0.nomComplet.localizedCaseInsensitiveContains(recherche) ||
                     "\($0.numero)".contains(recherche))
                }
                if !joueursPoste.isEmpty {
                    Section {
                        ForEach(joueursPoste) { j in
                            NavigationLink(value: EquipeNavItem.joueur(j.id)) {
                                joueurRow(j)
                            }
                        }
                        .onDelete(perform: (authService.utilisateurConnecte?.role.peutGererEquipe ?? false) ? { indices in
                            let toDelete = indices.compactMap { i in
                                i < joueursPoste.count ? joueursPoste[i] : nil
                            }
                            for joueur in toDelete {
                                // Retirer de l'équipe sans supprimer le profil Utilisateur global
                                if let uid = joueur.utilisateurID {
                                    let descriptor = FetchDescriptor<Utilisateur>(
                                        predicate: #Predicate { $0.id == uid }
                                    )
                                    if let utilisateur = try? contexte.fetch(descriptor).first {
                                        utilisateur.joueurEquipeID = nil
                                    }
                                }
                                contexte.delete(joueur)
                            }
                        } : nil)
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: poste.icone)
                                .foregroundStyle(poste.couleur)
                            Text(poste.rawValue)
                        }
                        .font(.caption.weight(.semibold))
                    }
                }
            }

            // État vide si aucun joueur actif
            if joueurs.filter(\.estActif).isEmpty {
                ContentUnavailableView {
                    Label("Aucun joueur", systemImage: "person.badge.plus")
                } description: {
                    Text("Ajoutez des joueurs à votre équipe")
                } actions: {
                    if authService.utilisateurConnecte?.role.peutGererEquipe ?? false {
                        Button("Nouveau joueur", systemImage: "plus") {
                            afficherAjout = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }
            }

            // Joueurs inactifs
            let inactifs = joueurs.filter { !$0.estActif }
            if !inactifs.isEmpty {
                Section("Inactifs") {
                    ForEach(inactifs) { j in
                        NavigationLink(value: EquipeNavItem.joueur(j.id)) {
                            joueurRow(j)
                                .opacity(0.5)
                        }
                    }
                }
            }
        }
        .navigationTitle("Équipe")
        .searchable(text: $recherche, prompt: "Rechercher un joueur")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                boutonRetour
            }
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: LiquidGlassKit.espaceSM) {
                    Button { afficherExport = true } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Button { afficherAjout = true } label: {
                        Image(systemName: "plus")
                    }
                    .siAutorise(authService.utilisateurConnecte?.role.peutGererEquipe ?? false)
                }
            }
        }
    }

    // MARK: - Ligne joueur
    private func joueurRow(_ j: JoueurEquipe) -> some View {
        HStack(spacing: 12) {
            // Photo ou numéro
            ZStack {
                if let photoData = j.photoData, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(j.poste.couleur, lineWidth: 2)
                        )
                } else {
                    Circle()
                        .fill(j.poste.couleur.opacity(0.15))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text("#\(j.numero)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(j.poste.couleur)
                        )
                }

                // Badge position en bas à droite
                Text(j.poste.abreviation)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(j.poste.couleur, in: Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
                    .offset(x: 15, y: 15)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(j.nomComplet)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text("#\(j.numero)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(j.poste.couleur)
                    if j.matchsJoues > 0 {
                        Text("\(j.matchsJoues) matchs")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if j.pointsMarques > 0 {
                Text("\(j.pointsMarques) pts")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Bouton retour
    private var boutonRetour: some View {
        Button {
            retour()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                Image(systemName: "volleyball.fill")
                    .font(.system(size: 14))
                Text("Accueil")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.green)
        }
    }
}

