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
    @AppStorage("tutorielVu") private var tutorielVu = false
    @AppStorage("playco_wizard_en_cours") private var wizardEnCours = false
    @State private var afficherTutorielInitial = false
    @State private var afficherReprendreWizard = false

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
        CredentialAthlete.self
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
                        let schemaVide = Schema([])
                        let configVide = ModelConfiguration(isStoredInMemoryOnly: true)
                        container = try ModelContainer(for: schemaVide, configurations: [configVide])
                    } catch {
                        logger.critical("Échec init ModelContainer en mémoire: \(error.localizedDescription)")
                        fatalError("Impossible d'initialiser la base de données. Merci de redémarrer l'app. Si le problème persiste, contactez le support.")
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
        case choixInitial      // premier lancement : configurer ou se connecter
        case configuration     // wizard 6 étapes
        case login             // connexion unifiée (Coach / Assistant / Athlète)
        case app               // ContentView (sections)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !splashTermine {
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
                        .modelContainer(container)
                        .transition(.move(edge: .trailing).combined(with: .opacity))

                    case .login:
                        LoginView(
                            onRetour: {
                                withAnimation { ecranActif = .choixInitial }
                            },
                            onConnecte: {
                                withAnimation(LiquidGlassKit.springDefaut) {
                                    ecranActif = .app
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
