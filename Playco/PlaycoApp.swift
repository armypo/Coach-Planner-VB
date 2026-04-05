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
    @AppStorage("tutorielVu") private var tutorielVu = false
    @State private var afficherTutorielInitial = false

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
        CategorieExercice.self, StaffPermissions.self
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
                container = (try? ModelContainer(for: schema, configurations: [memConfig]))!
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
        case choixInitial      // premier lancement : configurer ou rejoindre
        case configuration     // wizard 6 étapes
        case rejoindre         // connexion avec code équipe
        case app               // ContentView (login + sections)
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
                            onRejoindre: {
                                withAnimation { ecranActif = .rejoindre }
                            }
                        )
                        .environment(authService)
                        .environment(syncService)
                        .environment(sharingService)
                        .modelContainer(container)
                        .transition(.opacity)

                    case .configuration:
                        ConfigurationView(
                            onRetour: {
                                withAnimation { ecranActif = .choixInitial }
                            },
                            onTermine: {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    ecranActif = .app
                                }
                            }
                        )
                        .environment(authService)
                        .environment(sharingService)
                        .modelContainer(container)
                        .transition(.move(edge: .trailing).combined(with: .opacity))

                    case .rejoindre:
                        RejoindreEquipeView(
                            onRetour: {
                                withAnimation { ecranActif = .choixInitial }
                            },
                            onConnecte: {
                                withAnimation(.easeInOut(duration: 0.5)) {
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
                            .modelContainer(container)
                            .onAppear {
                                authService.restaurerSession(context: container.mainContext)
                                syncService.demarrerSuivi()
                                syncService.demarrerSurveillanceReseau()
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
            .animation(.easeInOut, value: splashTermine)
            .animation(.easeInOut, value: ecranActif)
        }
    }

    /// Vérifie si un ProfilCoach complété existe en base → route vers le bon écran
    private func verifierConfiguration() {
        let descriptor = FetchDescriptor<ProfilCoach>(
            predicate: #Predicate { $0.configurationCompletee == true }
        )
        let profils = (try? container.mainContext.fetch(descriptor)) ?? []

        if profils.isEmpty {
            // Premier lancement → choix initial
            ecranActif = .choixInitial
        } else {
            // Config déjà faite → app (login + sections)
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
