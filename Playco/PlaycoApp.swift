//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "App")

@main
struct PlaycoApp: App {
    let container: ModelContainer
    @State private var authService = AuthService()
    @State private var syncService = CloudKitSyncService()
    @State private var sharingService = CloudKitSharingService()
    @State private var analyticsService = AnalyticsService()
    @State private var storeKitService = StoreKitService()
    @State private var abonnementService = AbonnementService()
    @State private var observerTransactionsTask: Task<Void, Never>? = nil
    @AppStorage("tutorielVu") private var tutorielVu = false
    @AppStorage("playco_wizard_en_cours") private var wizardEnCours = false
    @State private var afficherTutorielInitial = false
    @State private var afficherReprendreWizard = false
    /// Message d'erreur critique affiché si aucun des 4 fallbacks ModelContainer ne réussit.
    /// Initialisé dans `init()` via `_erreurInitialisation = State(initialValue:)`.
    @State private var erreurInitialisation: String? = nil
    /// Message d'erreur de la gate paywall (athlète bloqué, assistant bloqué).
    /// Affiché en alert sur ChoixInitialView après déconnexion forcée.
    @State private var erreurGate: String? = nil

    /// Liste des types @Model pour éviter la répétition
    private static let modeles: [any PersistentModel.Type] = [
        Seance.self, Exercice.self, ExerciceBibliotheque.self,
        JoueurEquipe.self, StrategieCollective.self,
        FormationPersonnalisee.self, Utilisateur.self,
        Presence.self, Evaluation.self,
        ExerciceMuscu.self, ProgrammeMuscu.self, SeanceMuscu.self,
        TestPhysique.self, StatsMatch.self,
        Etablissement.self, ProfilCoach.self, Equipe.self,
        AssistantCoach.self, CreneauRecurrent.self, MatchCalendrier.self,
        MessageEquipe.self, ScoutingReport.self, PointMatch.self, ActionRallye.self,
        PhaseSaison.self, ObjectifJoueur.self,
        CategorieExercice.self, StaffPermissions.self,
        CredentialAthlete.self,
        Abonnement.self
    ]

    init() {
        // Tentative 1 — CloudKit (sync inter-appareil via container nommé)
        do {
            let schema = Schema(PlaycoApp.modeles)
            let cloudConfig = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .automatic
            )
            container = try ModelContainer(for: schema, configurations: [cloudConfig])
            logger.info("ModelContainer CloudKit initialisé")
        } catch {
            // Tentative 2 — Local uniquement (pas de sync)
            logger.warning("CloudKit indisponible: \(error.localizedDescription). Passage en mode local.")
            do {
                let schema = Schema(PlaycoApp.modeles)
                let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                container = try ModelContainer(for: schema, configurations: [localConfig])
                logger.info("ModelContainer local initialisé (fallback)")
            } catch {
                // Tentative 3 — Mémoire (dernier recours, données non persistées)
                logger.critical("Impossible de créer le ModelContainer local: \(error.localizedDescription). Passage en mémoire.")
                let schema = Schema(PlaycoApp.modeles)
                let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                do {
                    container = try ModelContainer(for: schema, configurations: [memConfig])
                } catch {
                    logger.critical("ModelContainer mémoire échoué: \(error.localizedDescription)")
                    // Tentative 4 — Schéma vide en mémoire (ultime fallback)
                    do {
                        // Tentative 4 — Schéma vide en mémoire (ultime fallback)
                        // Si ça réussit : l'app fonctionne sans données, un écran
                        // d'erreur sera affiché dans body via erreurInitialisation.
                        let schemaVide = Schema([])
                        let configVide = ModelConfiguration(isStoredInMemoryOnly: true)
                        container = try ModelContainer(for: schemaVide, configurations: [configVide])
                        _erreurInitialisation = State(initialValue:
                            "Impossible d'initialiser la base de données. " +
                            "Redémarre l'application ou contacte le support si le problème persiste."
                        )
                        logger.critical("Toutes les tentatives ModelContainer ont échoué — écran d'erreur affiché")
                    } catch {
                        // Dernière tentative échouée — le runtime Swift est dans un état fatal.
                        // fatalError acceptable ici : Schema([]) + isStoredInMemoryOnly ne peut
                        // pas échouer en conditions normales (pas de disque, pas de réseau).
                        logger.critical("Échec init ModelContainer schéma vide: \(error.localizedDescription)")
                        fatalError("Impossible d'initialiser la base de données (schema vide). Erreur système critique.")
                    }
                }
            }
        }
        // Peupler les exercices de musculation par défaut
        ExercicesMusculationDefauts.peuplerSiVide(context: container.mainContext)
    }

    @State private var splashTermine = false
    @State private var configurationTerminee: Bool? = nil
    @State private var ecranActif: EcranLancement = .chargement

    /// Écrans du flux de lancement
    enum EcranLancement {
        case chargement
        case choixInitial      // premier lancement : configurer ou login
        case configuration     // wizard 6 étapes
        case login             // login unifié (Coach / Assistant / Athlète)
        case app               // ContentView (sections)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                // Écran d'erreur critique — affiché si TOUS les fallbacks ModelContainer ont échoué.
                // Dans ce cas l'app ne peut pas fonctionner, on guide l'utilisateur.
                if let erreur = erreurInitialisation {
                    EcranErreurBaseView(message: erreur)
                } else if !splashTermine {
                    SplashScreenView {
                        splashTermine = true
                    }
                    .transition(.opacity)
                } else {
                    switch ecranActif {
                    case .chargement:
                        Color.clear.onAppear { verifierConfiguration() }

                    case .choixInitial:
                        ChoixInitialView(
                            onConfigurer: {
                                withAnimation { ecranActif = .configuration }
                            },
                            onConnexion: {
                                withAnimation { ecranActif = .login }
                            }
                        )
                        .environment(authService)
                        .environment(syncService)
                        .environment(sharingService)
                        .modelContainer(container)
                        .transition(.opacity)
                        .alert("Configuration interrompue", isPresented: $afficherReprendreWizard) {
                            Button("Reprendre", role: .none) {
                                afficherReprendreWizard = false
                                withAnimation { ecranActif = .configuration }
                            }
                            Button("Recommencer", role: .destructive) {
                                wizardEnCours = false
                                afficherReprendreWizard = false
                            }
                        } message: {
                            Text("Un wizard de configuration a été commencé mais non terminé. Voulez-vous reprendre ou recommencer ? Les saisies précédentes ne sont pas conservées.")
                        }
                        .alert("Accès bloqué", isPresented: Binding(
                            get: { erreurGate != nil },
                            set: { if !$0 { erreurGate = nil } }
                        )) {
                            Button("OK", role: .cancel) { erreurGate = nil }
                        } message: {
                            Text(erreurGate ?? "")
                        }

                    case .configuration:
                        ConfigurationView(
                            onRetour: {
                                withAnimation { ecranActif = .choixInitial }
                            },
                            onTermine: {
                                withAnimation(LiquidGlassKit.springDefaut) {
                                    ecranActif = .app
                                }
                            }
                        )
                        .environment(authService)
                        .environment(sharingService)
                        .environment(analyticsService)
                        .environment(storeKitService)
                        .environment(abonnementService)
                        .modelContainer(container)
                        .transition(.move(edge: .trailing).combined(with: .opacity))

                    case .login:
                        LoginView(
                            onRetour: {
                                withAnimation { ecranActif = .choixInitial }
                            },
                            onConnecte: {
                                // Appliquer la gate centrale avant de passer à .app
                                appliquerGateTier()
                                if authService.utilisateurConnecte != nil {
                                    withAnimation(LiquidGlassKit.springDefaut) {
                                        ecranActif = .app
                                    }
                                }
                            }
                        )
                        .environment(authService)
                        .environment(syncService)
                        .environment(sharingService)
                        .modelContainer(container)
                        .transition(.move(edge: .trailing).combined(with: .opacity))

                    case .app:
                        ContentView()
                            .environment(authService)
                            .environment(syncService)
                            .environment(sharingService)
                            .environment(analyticsService)
                            .environment(storeKitService)
                            .environment(abonnementService)
                            .modelContainer(container)
                            .onAppear {
                                analyticsService.initialiser()
                                analyticsService.suivre(evenement: EvenementAnalytics.appLancee)
                                syncService.demarrerSuivi()
                                syncService.demarrerSurveillanceReseau()
                                // Brancher le rejeu automatique de la file de publication
                                // d'utilisateurs quand le réseau revient en ligne.
                                // Capture explicite des références pour clarté sémantique.
                                let sharing = sharingService
                                let containerRef = container
                                syncService.onReseauRestaure = { @Sendable in
                                    await sharing.rejouerFileAttente(context: containerRef.mainContext)
                                }
                                Task {
                                    await syncService.attendreSyncInitiale()
                                    authService.restaurerSession(context: container.mainContext)
                                    if authService.utilisateurConnecte != nil {
                                        analyticsService.suivre(
                                            evenement: EvenementAnalytics.utilisateurConnecte,
                                            metadonnees: ["role": authService.utilisateurConnecte?.role.rawValue ?? "inconnu"]
                                        )
                                    }
                                    // Paywall v2.0 : migration rôles + chargement produits + rafraîchir statut
                                    abonnementService.migrerAssistantsVersNouveauRole(context: container.mainContext)
                                    try? await storeKitService.chargerProduits()
                                    await abonnementService.rafraichir(
                                        utilisateur: authService.utilisateurConnecte,
                                        context: container.mainContext,
                                        storeKit: storeKitService
                                    )
                                    // Appliquer la gate (athlète bloqué si tier coach != .club)
                                    appliquerGateTier()
                                    // Observer transactions Apple en continu (renouvellements, refunds)
                                    if observerTransactionsTask == nil {
                                        observerTransactionsTask = storeKitService.observerTransactions()
                                    }
                                }
                                if !tutorielVu {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                        afficherTutorielInitial = true
                                    }
                                }
                            }
                            .fullScreenCover(isPresented: $afficherTutorielInitial) {
                                TutorielView()
                            }
                            .onReceive(NotificationCenter.default.publisher(for: .allerChoixInitial)) { _ in
                                authService.deconnexion()
                                withAnimation { ecranActif = .choixInitial }
                            }
                            .transition(.opacity)
                    }
                }
            }
            .animation(LiquidGlassKit.springDefaut, value: splashTermine)
            .animation(LiquidGlassKit.springDefaut, value: ecranActif)
        }
    }

/// Gate centrale paywall : applique les règles tier sur l'utilisateur connecté.
    /// Appelée après chaque connexion réussie + au démarrage après restaurerSession.
    ///
    /// Logique :
    /// - Athlète : tier équipe doit être `.club` — sinon déconnexion immédiate
    /// - Assistant : tier équipe doit être `.pro` ou `.club` — sinon déconnexion
    /// - Coach/Admin : pas de gate (gérés par bannière + feature gating)
    private func appliquerGateTier() {
        guard let user = authService.utilisateurConnecte else { return }
        let code = user.codeEcole
        let desc = FetchDescriptor<Equipe>(predicate: #Predicate { $0.codeEquipe == code })
        let tier = (try? container.mainContext.fetch(desc).first)?.tierAbonnement ?? .aucun

        switch user.role {
        case .etudiant:
            if tier != .club {
                authService.deconnexion()
                erreurGate = TextesPaywall.erreurAthleteBloque
                withAnimation { ecranActif = .choixInitial }
            }
        case .assistantCoach:
            if tier == .aucun {
                authService.deconnexion()
                erreurGate = TextesPaywall.erreurAssistantBloque
                withAnimation { ecranActif = .choixInitial }
            }
        case .coach, .admin:
            break  // pas de gate tier pour eux
        }
    }

    /// Vérifie si un ProfilCoach complété existe en base → route vers le bon écran
    private func verifierConfiguration() {
        let descriptor = FetchDescriptor<ProfilCoach>(
            predicate: #Predicate { $0.configurationCompletee == true }
        )
        let profils = (try? container.mainContext.fetch(descriptor)) ?? []

        if profils.isEmpty {
            // Premier lancement → choix initial.
            // Si un wizard avait été entamé puis interrompu, demander à l'utilisateur quoi faire.
            if wizardEnCours {
                afficherReprendreWizard = true
            }
            ecranActif = .choixInitial
        } else {
            // Config déjà faite → nettoyer un éventuel flag orphelin
            wizardEnCours = false
            ecranActif = .app
        }
    }

    // MARK: - Remise à neuf complète

    /// Supprime la base SwiftData et tous les UserDefaults
    static func remettreANeuf() {
        // 1. Vider UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }

        // 2. Supprimer les fichiers SwiftData (default.store)
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }

        let extensions = ["store", "store-shm", "store-wal"]
        let fichier = "default"
        for ext in extensions {
            let url = appSupport.appendingPathComponent("\(fichier).\(ext)")
            try? fm.removeItem(at: url)
        }
        logger.info("Application remise à neuf — toutes les données supprimées")
    }
}
