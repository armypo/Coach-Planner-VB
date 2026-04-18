//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Sections principales de l'application
enum SectionApp: Hashable {
    case pratiques
    case matchs
    case strategies
    case equipe
    case entrainement
}

/// Routeur principal — affiche le login ou l'interface avec dock
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Environment(AbonnementService.self) private var abonnementService
    @Environment(\.scenePhase) private var scenePhase
    @State private var sectionActive: SectionApp?
    @State private var afficherProfil: Bool = false
    @State private var afficherMessages: Bool = false
    @State private var afficherRecherche: Bool = false
    @State private var equipeSelectionnee: Equipe?
    @State private var selectionEquipeFaite = false
    @State private var afficherToastDesactivation = false
    @State private var toastTask: Task<Void, Never>?

    @Query private var equipes: [Equipe]
    @Query(sort: \MessageEquipe.dateEnvoi) private var tousMessages: [MessageEquipe]
    @AppStorage("modeSombre") private var modeSombre: Bool = false

    /// Messages non lus pour l'utilisateur courant
    private var nbMessagesNonLus: Int {
        guard let uid = authService.utilisateurConnecte?.id else { return 0 }
        let code = codeEquipeActif
        guard !code.isEmpty else { return 0 }
        return tousMessages.filter { $0.codeEquipe == code && !$0.estLuPar(uid) }.count
    }

    // Query pour détecter si une séance est prévue aujourd'hui
    @Query(filter: #Predicate<Seance> { $0.estArchivee == false },
           sort: \Seance.date) private var toutesSeances: [Seance]

    /// Badge orange si séance aujourd'hui
    private var seanceAujourdhui: Bool {
        toutesSeances.contains { Calendar.current.isDateInToday($0.date) }
    }

    /// Couleur du rôle connecté
    private var couleurRole: Color {
        authService.utilisateurConnecte?.role.couleur ?? PaletteMat.orange
    }

    /// Code équipe actif (sélectionné ou du profil utilisateur ou première équipe)
    private var codeEquipeActif: String {
        if let eq = equipeSelectionnee { return eq.codeEquipe }
        // Pour les athlètes, prioriser le codeEcole de leur profil
        if let code = authService.utilisateurConnecte?.codeEcole, !code.isEmpty {
            return code
        }
        if let eq = equipes.first { return eq.codeEquipe }
        return ""
    }

    var body: some View {
        Group {
            if !authService.estConnecte {
                LoginView()
                    .transition(.opacity)
            } else if equipes.count > 1 && !selectionEquipeFaite {
                SelectionEquipeView { equipe in
                    equipeSelectionnee = equipe
                    withAnimation { selectionEquipeFaite = true }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                contenuPrincipal
                    .onAppear {
                        // Auto-sélection si 1 seule équipe
                        if equipes.count <= 1 { selectionEquipeFaite = true }
                    }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: authService.estConnecte)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: selectionEquipeFaite)
        .preferredColorScheme(modeSombre ? .dark : .light)
        .onChange(of: authService.estConnecte) {
            if !authService.estConnecte {
                selectionEquipeFaite = false
                equipeSelectionnee = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .changerEquipe)) { _ in
            withAnimation {
                selectionEquipeFaite = false
                equipeSelectionnee = nil
                sectionActive = nil
            }
        }
        .onChange(of: scenePhase) { _, nouveau in
            guard nouveau == .active, authService.estConnecte else { return }
            Task { @MainActor in
                verifierEtatSessionForeground()
            }
        }
        .onChange(of: abonnementService.statut) { _, _ in
            // Gate runtime : si un athlète est connecté et que le tier du coach
            // tombe sous .club (ex: refund, revocation), déconnexion immédiate.
            guard let user = authService.utilisateurConnecte else { return }
            if user.role == .etudiant && abonnementService.tierActif != .club {
                authService.deconnexion()
                NotificationCenter.default.post(name: .allerChoixInitial, object: nil)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            BanniereAbonnementView()
        }
        .overlay(alignment: .top) {
            if afficherToastDesactivation {
                HStack(spacing: LiquidGlassKit.espaceSM) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Votre compte a été désactivé. Contactez votre coach.")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, LiquidGlassKit.espaceLG)
                .padding(.vertical, LiquidGlassKit.espaceSM)
                .background(.orange, in: Capsule(style: .continuous))
                .padding(.top, LiquidGlassKit.espaceLG)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(LiquidGlassKit.springDefaut, value: afficherToastDesactivation)
    }

    /// Au retour foreground, vérifie que l'utilisateur connecté est toujours
    /// actif. Déconnecte + toast si désactivé/supprimé côté coach.
    /// La logique métier vit dans AuthService — cette fonction ne gère que l'UI.
    private func verifierEtatSessionForeground() {
        let etat = authService.verifierEtatSession(context: modelContext)
        switch etat {
        case .valide:
            return
        case .desactive, .supprime:
            authService.deconnexion()
            afficherToastAvecDelai()
        }
    }

    /// Affiche le toast et programme sa disparition à 4s.
    /// Annule toute tâche précédente pour éviter un reset prématuré si la
    /// scène passe active→inactive→active rapidement.
    private func afficherToastAvecDelai() {
        toastTask?.cancel()
        afficherToastDesactivation = true
        toastTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            afficherToastDesactivation = false
        }
    }

    @ViewBuilder
    private var contenuPrincipal: some View {
        ZStack {
            // Contenu de la section ou accueil
            Group {
                if let section = sectionActive {
                    sectionView(section)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                } else {
                    AccueilView { section in
                        sectionActive = section
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity
                    ))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: sectionActive)

            // Dock bar flottant en overlay bas (visible seulement sur l'accueil)
            if sectionActive == nil {
                VStack {
                    Spacer()
                    DockBarView(
                        sectionActive: $sectionActive,
                        badgeMessages: nbMessagesNonLus > 0,
                        badgeSeanceAujourdhui: seanceAujourdhui,
                        onMessages: {
                            afficherMessages = true
                        },
                        onProfil: {
                            afficherProfil = true
                        },
                        onRecherche: {
                            afficherRecherche = true
                        }
                    )
                }
                .ignoresSafeArea(.keyboard)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: sectionActive)
        // Injecter la couleur du rôle et le code équipe dans l'environnement
        .environment(\.couleurRole, couleurRole)
        .environment(\.codeEquipeActif, codeEquipeActif)
        .environment(\.modeBordDeTerrain, UserDefaults.standard.bool(forKey: "modeBordDeTerrain"))
        .environment(\.themeHautContraste, UserDefaults.standard.bool(forKey: "themeHautContraste"))
        .sheet(isPresented: $afficherProfil) {
            vueProfil
        }
        .sheet(isPresented: $afficherMessages) {
            vueMessages
        }
        .sheet(isPresented: $afficherRecherche) {
            RechercheGlobaleView { section in
                withAnimation { sectionActive = section }
            }
        }
    }

    @ViewBuilder
    private func sectionView(_ section: SectionApp) -> some View {
        switch section {
        case .pratiques:
            PratiquesView { withAnimation { sectionActive = nil } }
        case .matchs:
            MatchsView { withAnimation { sectionActive = nil } }
        case .strategies:
            StrategiesView { withAnimation { sectionActive = nil } }
        case .equipe:
            if authService.utilisateurConnecte?.role == .etudiant {
                MonProfilAthleteView { withAnimation { sectionActive = nil } }
            } else {
                EquipeView { withAnimation { sectionActive = nil } }
            }
        case .entrainement:
            EntrainementView { withAnimation { sectionActive = nil } }
        }
    }

    /// Sheet messages — messagerie inter-équipe
    private var vueMessages: some View {
        MessagerieView()
    }

    /// Sheet profil — adapté selon le rôle
    private var vueProfil: some View {
        ProfilView()
    }
}
