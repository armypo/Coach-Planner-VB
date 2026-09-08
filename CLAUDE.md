# Playco — Contexte Claude Code

## Résumé du projet
Application iOS/iPadOS de coaching volleyball en **Swift/SwiftUI**, ciblant iPad Air avec Apple Pencil 2e gen. **GRATUITE et coach-first depuis le pivot 2026-08-26** : les seuls utilisateurs sont le staff (head coach + assistants, mêmes droits — D6) ; les athlètes sont des DONNÉES du roster (aucun compte, aucune surface). **5 sections** : Séances (pratiques/exercices), Matchs (scouting/live/box score/stats), Stratégies (systèmes de jeu/formations), Équipe (roster/hub statistiques), Entraînement (musculation/charges). Terrain de volleyball dessinable (PencilKit + éléments vectoriels overlay), multi-étapes, demi-terrain. Bibliothèque d'exercices. Calendrier unifié au Dock. Match éclair. PDF plan de pratique. Sync CloudKit (privée multi-appareils + miroir Public DB BIDIRECTIONNEL entre coachs — parité complète livrée par le chantier E : roster/disponibilité, séances+exercices avec dessins, stratégies, scouting, bibliothèque, box scores, points live, formations).

## Stack technique
- **Swift 5.9+ / SwiftUI** — NavigationSplitView (sidebar + detail avec NavigationStack), nuit par défaut (`.preferredColorScheme(.dark)` à la racine)
- **SwiftData + CloudKit** — persistance locale + sync inter-appareil (ModelConfiguration cloudKitDatabase: .automatic, fallbacks local puis mémoire)
- **PencilKit** — PKCanvasView via UIViewRepresentable (`overrideUserInterfaceStyle = .light` : fidélité des dessins sur fond nuit)
- **Canvas API** — rendu du terrain (indoor parquet, beach sable, demi-terrain 9×9)
- **AuthenticationServices** — Sign in with Apple, UNIQUE méthode de connexion (aucun mot de passe nulle part)
- **EventKit** — sync calendrier Apple (CalendarSyncService)
- **Combine** — auto-save debounce 3s (TerrainEditeurViewModel)
- **TelemetryDeck 2.14.1** (SPM, épinglée — seule dépendance externe) — analytics de rétention, no-op sous DEMO ; **MetricKit** — crash/hang natifs, rien ne quitte l'appareil

## Architecture de navigation

### Flux d'entrée
```
PlaycoApp
├── SplashScreenView → animation d'entrée
├── ChoixInitialView → « Créer mon équipe » / « Se connecter » (Coach · Assistant) / « Rejoindre avec un code » (Assistant)
│   ├── ConfigurationView (wizard 6 étapes) → crée coach + équipe (+ roster sans comptes, assistants avec codes)
│   └── LoginView → SIWA + sheet « Rejoindre mon équipe » (code équipe + code d'invitation — ASSISTANTS seulement)
├── SelectionEquipeView → si multi-équipes
└── ContentView (routeur principal)
```

### Écran d'accueil → 5 sections
```
ContentView (routeur)
├── AccueilView (5 cartes : Séances / Matchs / Stratégies / Équipe / Entraînement — fond MatNuit uni)
├── PratiquesView → NavigationSplitView (séances + exercices ; bottomBar : Bibliothèque · Planification)
├── MatchsView → NavigationSplitView (sidebar : Préparation/scouting + à venir/résultats ; toolbar match en 3 groupes)
├── StrategiesView → NavigationSplitView (sidebar : Formations + stratégies par catégorie)
├── EquipeView → NavigationSplitView (hub Statistiques 6 entrées + roster par poste)
└── EntrainementView → NavigationSplitView (programmes ; sélecteur de joueur avant séance live)
```
+ **DockBarView** flottant en bas, sur l'accueil : **Recherche · Calendrier · Profil** (persistance dans les sections = coquille 2.5a)

- `SectionApp` enum : `.pratiques`, `.matchs`, `.strategies`, `.equipe`, `.entrainement`
- Transitions spring animées ; chaque section a un `BoutonRetourAccueil` partagé (topBarLeading, teinté par section)

## Architecture des fichiers

### Point d'entrée
| Fichier | Description |
|---------|-------------|
| `PlaycoApp.swift` | @main, ModelContainer CloudKit (30 modèles, fallback local + mémoire → `EcranErreurBaseView`), écrans splash → choixInitial → config/login → app, nuit par défaut, révocation SIWA au lancement, `MigrationRoles` one-shot, MetricKit + `app_launched` unique, `onOpenURL` lien d'invitation (racine, hors DEMO) |

### Modèles (`Models/`) — 30 @Model
| Fichier | Description |
|---------|-------------|
| `Seance.swift` | @Model : id, nom, date, exercices (cascade, **optionnel**), estArchivee, typeSeanceRaw (pratique/match), adversaire, lieu, scores, notesMatch, statsEntrees, codeEquipe, pagesMatch, rotations historique (nous+adv), nousServonsEnPremier, sets JSON (cache @Transient), partants/liberoID, `dateModification` (sweep sync), `matchCalendrierID` (dormant). + `Seance+Duplication.swift` (copie AVEC codeEquipe) |
| `Exercice.swift` | @Model : id, nom, notes, dessinData, elementsData, ordre, duree, etapesData, typeTerrain, seance, estArchive, dateModification (E2 — sweep de publication) |
| `ExerciceBibliotheque.swift` | @Model : bibliothèque d'exercices (catégorie, favori, notesCoach, typeTerrain, codeCoach, dateModification E2). + `ExerciceBibliothequeExport.swift` (import/export JSON, pas un @Model) |
| `ElementTerrain.swift` | Codable struct : joueur/ballon/flèche/trajectoire/rotation, coordonnées normalisées 0-1, Bézier. + **TypeTerrain** enum (indoor/beach/**demiTerrain** 2.3.1 — rawValues = contrat de persistance, legacy `?? .indoor`) + **EtapeExercice** |
| `JoueurEquipe.swift` | @Model **donnée pure du roster** (aucun compte) : identité, numéro, poste, stats NCAA/FIVB cumulées, taille, **poidsKg** (pivot — ex-miroir Utilisateur), dateNaissance, photoData, codeEquipe, `dateModification`, **statutDisponibiliteRaw** (blessé/malade/suspendu — grise compo/muscu) + **consentement parental** (atteste/date/attesteParNom — base légale collecte/vidéo). Champs legacy gelés : identifiant, motDePasseHash, sel, utilisateurID. + **PosteJoueur** enum |
| `StrategieCollective.swift` | @Model : nom, categorieRaw, description, dessin/éléments/étapes, typeTerrain, estArchivee, codeEquipe. + **CategorieStrategie** |
| `FormationTypes.swift` | FormationMode, FormationType (5-1/4-2/6-2, beach), couleurPourLabel (jetons par poste) |
| `FormationPersonnalisee.swift` | @Model : formationType, rotation, mode, positionsJSON, codeEquipe |
| `Utilisateur.swift` | @Model **compte STAFF** (coach `.admin`, assistant `.assistantCoach`) : identifiant (affichage), prenom/nom, roleRaw, codeEcole/codeEquipe, **appleUserID** (SIWA), **codeInvitation** (jonction assistant), photoData, estActif, dateModification. `genererIdentifiantUnique()`, `genererCodeUniqueInvitation()`. Champs gelés au schéma : hash/sel/iterations, miroirs athlète (données physiques, stats, joueurEquipeID) — plus jamais écrits |
| `StatsMatch.swift` | @Model : stats par joueur par match (source du cumul carrière via resynchroniserCumul), dateModification (E3 — sweep de publication) |
| `Presence.swift` / `Evaluation.swift` / `TestPhysique.swift` | @Model clés par joueurID/seanceID — ⚠️ SANS codeEquipe (angle mort connu ; la cascade d'équipe les purge par joueurID) |
| `Etablissement.swift` / `ProfilCoach.swift` / `Equipe.swift` / `AssistantCoach.swift` | Organisation. `Equipe` : couleurs, codeEquipe, dateFinSaison, `sportID` (« volleyball », phase 0 SportPack), tierAbonnementRaw (gelé). `ProfilCoach.masquerPratiquesAthletes` gelé. `AssistantCoach` : rôle staff descriptif (assistant/préparateur/analyste/physio) |
| `ProgrammeMuscu.swift` (+ExerciceMuscu) / `SeanceMuscu.swift` | Musculation : programmes + joueurs assignés ; séances exécutées **au nom d'un joueur choisi par le coach** (D2) |
| `CreneauRecurrent.swift` / `MatchCalendrier.swift` | Créneaux du wizard → séances générées ; MatchCalendrier **dormant** (le wizard crée des Seance) |
| `MessageEquipe.swift` | @Model **GELÉ** (D1 : messagerie retirée de l'UI) — conservé au schéma + cascade |
| `PointMatch.swift` | @Model stats live point-par-point : scores/rotations (nous+adv) au moment, typeActionRaw (+ 5 actions adversaire), zone/zoneDepart, nousServionsAuMoment/serviceRenseigne, codeEquipe. + **TypeActionPoint** |
| `ScoutingReport.swift` | @Model : adversaire, seanceID (lien match), joueurs adverses JSON (JAMAIS publiés en Public DB), forces/faiblesses, tendances zonales (menace 0-3), stratégies recommandées, codeEquipe, dateModification (E2) |
| `ObjectifJoueur.swift` | @Model : objectifs fixés par le coach par joueur, progression auto. + **CategorieObjectif** |
| `Abonnement.swift` | @Model **GELÉ** (D3 : paywall supprimé) — conservé au schéma (+ enums Tier/TypeAbonnement) ; volontairement HORS cascade d'équipe |
| `ActionRallye.swift` / `CategorieExercice.swift` / `PhaseSaison.swift` | Stats non-marquantes du rallye ; catégories d'exercices perso ; phases de saison (filtre Analytics) |
| `CredentialAthlete.swift` | @Model **marqueur de membre du STAFF** (nom historique) : utilisateurID, identifiant, codeEquipe, joueurEquipeID toujours nil pour les nouveaux |
| `StaffPermissions.swift` | @Model **GELÉ** (D6 : mêmes droits pour tout le staff) — conservé au schéma, plus jamais lu/écrit |
| `MatchLiveModels.swift` / `EvenementSync.swift` | Structs (PAS @Model) : JoueurSurTerrain/SetScore/Substitution/ConfigMatch/DonneesHeatmap ; journal sync (buffer 50 UserDefaults) |

### Services (`Services/`)
| Fichier | Description |
|---------|-------------|
| `AuthService.swift` | @Observable **SIWA strict** : connexionApple(appleUserID:) → .connecte/.compteInconnu/.echec, restaurerSession(), deconnexion(), verifierEtatSession(). AUCUN mot de passe |
| `AppleSignInService.swift` / `SessionManager.swift` / `KeychainService.swift` | SIWA (révocation lancement + foreground), session Keychain |
| `MembreFactory.swift` | @MainActor : création unifiée d'un membre du **STAFF** (Utilisateur + CredentialAthlete marqueur, codeInvitation, AUCUN secret). Plus de paramètre `joueur:` (pivot) — le roster est créé à part |
| `MigrationRoles.swift` | One-shot hérité v2.0 : reclasse les anciens `.coach` assistants → `.assistantCoach` (flag UserDefaults `playco_abo_migration_roles_done`) |
| `CloudKitSharingService.swift` | Coquille (état, RecordType [10 types], SharingError, `CKRecord.chaineSecurisee`, `planSync(role:)` E4 — tous les coachs importent PUIS publient, `.etudiant` lecture seule). Extensions : `+Publication` (sweep incrémental `publierMisesAJourCoach` par dateModification ; les 5 `publierX` en FETCH-PUIS-MODIFIER via `recordPublicAJour` — E1), `+Import` (fetch paginé par curseur + variante à prédicat, `syncDepuisPublic`, orchestrateurs), `+Preparation` (E2 : exercices/stratégies/scouting/bibliothèque — binaires inline ≤ 500 Ko sinon CKAsset), `+Analyse` (E3 : StatsMatch, PointMatch par lots de 400, formations ; `publierAnalyseMatch` à la sortie du live), `+Jointure` (`rejoindreEquipe`/`reclamerMembreLocal` — **`roleJonctionAutorise` = `.assistantCoach` SEUL**) |
| `CloudKitSyncService.swift` | @Observable : statut sync privée, compte iCloud, NWPathMonitor, journal (EvenementSync batché), **mode match** (pause pendant le live — un seul preneur de stats, D6), compteur modifs |
| `FileReplicationUtilisateur.swift` | Actor : file de re-publication Public DB (backoff, abandon à 10, Keychain) |
| `AnalyticsService.swift` | TelemetryDeck : init paresseuse par clé plist `TelemetryDeckAppID` (vide = logger-only), no-op DEMO, filtrage PII clés+valeurs, événements produit (match_live_demarre = baseline GO/NO-GO vidéo). Plus d'événements paywall |
| `MetricKitService.swift` | Crash/hang/cpu natifs → Logger (nonisolated), idempotent, zéro donnée sortante |
| `AgregateurStatsMatch.swift` | Agrégation unique PointMatch/ActionRallye → compteurs ; `finaliserStats` ; `resynchroniserCumul` idempotent |
| `CalendarSyncService.swift` / `PDFExportService.swift` / `CSVExportService.swift` | EventKit ; PDF résumé match + plan de match scouting + **plan de pratique une page** (2.6.2, régénéré à chaque partage) ; CSV point-virgule |

### Helpers (`Helpers/`)
| Fichier | Description |
|---------|-------------|
| `ThemeCouleurRole.swift` | **Design System Mat Nuit (2.4)** : enum `MatNuit` (fond #0D0D0F, 3 encres, 5 tons d'espace neutres terre/brique/ardoise/sauge/lavande, sémantiques live/deltas, plafond verre 12 %, tokens bordure/reflet/ombre) — contrat WCAG exécutable (`MatNuitTests`). `PaletteMat` = alias vers les tons MatNuit (hex vifs morts). GlassCard/GlassSection/GlassChip (verre sombre 3.0, courtside préservé via env), GlassButtonStyle, couleurRole |
| `LiquidGlassKit.swift` | Constantes : rayons (12/16/22/28), espacement 4pt (XS→XXL), springs (défaut/rebond/douce), ombres, opacités, courtside |
| `FiltreEquipe.swift` | Protocole `FiltreParEquipe` + `.filtreEquipe()` — 12+ conformances |
| `EquipeContext.swift` / `ModesBordTerrainContext.swift` | EnvironmentKeys `codeEquipeActif`, `modeBordDeTerrain` + `themeHautContraste` |
| `MetriquesVolley.swift` | Formules stats D1 (fractions 0-1), sideout %/point scoring % avec contexte de service, note réception 0-3, runs, glossaire ; `FormatMetriques` (« .350 », « 85,0 % ») |
| `CartesStatsHelpers.swift` / `TableauStats.swift` | Kit UI stats : CarteMetrique, EnTeteSection, TypographieStats, LegendeStatsSheet, TableauStats (FiltresStats supprimé — code mort) |
| `FabriqueMatch.swift` | Match éclair (2 champs) + `derniereComposition` (compo héritée à la création, validée effectif actif+disponible) |
| `LienInvitation.swift` | Lien universel `https://playco.app/join/{codeEquipe}/{codeInvitation}` (analyse STRICTE https/ASCII) + QR CoreImage + rejeu avant login — sert la jonction ASSISTANT (dormant tant que domaine/AASA absents) |
| `MatchLiveRestauration.swift` | Marqueur UserDefaults expirable 6 h — reprise du match live après kill (2.2.a) |
| `Extensions.swift` / `AppConstants.swift` / `PlaycoUTTypes.swift` | Color(hex:), DateFormattersCache, JSONCoderCache ; URLs légales (placeholders) ; UTTypes export |
| `BibliothequeDefauts.swift` / `DiagrammesBibliotheque.swift` / `ExercicesMusculationDefauts.swift` | Contenus par défaut |

### ViewModels (`ViewModels/`)
| Fichier | Description |
|---------|-------------|
| `TerrainEditeurViewModel.swift` | @Observable : undo/redo **par étape** (clé UUID stable, 15/étape, budget global 60 snapshots), formations, duplication d'étape « Continuer », auto-save debounce 3s |
| `MatchLiveViewModel.swift` | Match live : scores/rotations nous+adv, sideout, subs/TM, `restaurerSetActuel()` (reprend au set le plus avancé, fetch borné) |

### Vues principales (`Views/`)
| Fichier | Description |
|---------|-------------|
| `ContentView.swift` | Routeur : SectionApp, DockBar (Recherche · Calendrier · Profil), sync partagée role-aware (assistants importent / coach publie), révocation SIWA foreground, toast désactivation. Plus AUCUNE branche athlète |
| `AccueilView.swift` | 5 cartes tinted glass, fond `MatNuit.fond` uni, caches @State + .filtreEquipe() |
| `PratiquesView.swift` / `SplashScreenView.swift` / `RechercheGlobaleView.swift` / `EcranErreurBaseView.swift` | Séances ; splash ; recherche globale (ouvre la section — deep-link différé 2.5a) ; écran d'erreur container |

### Authentification (`Views/Auth/`)
| Fichier | Description |
|---------|-------------|
| `ChoixInitialView.swift` | 3 cartes : Créer mon équipe / Se connecter (Coach · Assistant) / Rejoindre avec un code (Assistant) |
| `LoginView.swift` | **SIWA-only** + sheet « Rejoindre mon équipe » (code équipe + code d'invitation, confirmation anti-phishing « Rejoindre « X » ? ») — ASSISTANTS seulement |
| `SelectionEquipeView.swift` | Multi-équipes (agnostique au rôle) |

### Configuration / Onboarding (`Views/Configuration/`)
| Fichier | Description |
|---------|-------------|
| `ConfigurationView.swift` | Wizard 6 étapes : établissement → sport → coach (SIWA, anti-doublon) → équipe → membres → calendrier. Finalisation : persist + séances récurrentes + auto-login (plus de paywall de bienvenue) |
| `ConfigMembresView.swift` | Étape 5 : joueurs = ROSTER PUR (nom/numéro/poste, aucun identifiant) ; assistants avec identifiant auto + code d'invitation à la fin |
| `IdentifiantsRecapSheet.swift` | Récap des codes d'invitation (assistants), templates de partage |
| autres `Config*.swift` | Étapes 1-4/6 + helpers |

### Matchs (`Views/Matchs/`)
| Fichier | Description |
|---------|-------------|
| `MatchsView.swift` | Sidebar : section **Préparation** (rapports de scouting) + à venir/résultats, searchable ; toolbar : + / match éclair (bolt) ; **suppression de match CONFIRMÉE** (cascade destructive) ; tint MatNuit.brique |
| `MatchDetailView.swift` (dans Seances/) | Terrain match + toolbar en **3 groupes-menus** : Préparer (Composition + Scouting) · En direct (Mode live + Dashboard) · Après (Score/Finaliser/Analyse/Export) |
| `ScoutingReportListView.swift` / `ScoutingReportView.swift` / `ScoutingLectureView.swift` / `PlanMatchPanneau.swift` / `MiniTerrainZonesMenace.swift` / `CarteJoueurAdverseEditable.swift` | Scouting complet : liste, éditeur (tendances zonales), lecture une page + PDF plan de match, panneau live |
| `MatchLiveSplitView.swift` | Mode live split iPad (Dashboard ∥ StatsLive), mode match (pause sync), marqueur de reprise 2.2.a |
| `StatsLiveView.swift` / `DashboardMatchLiveView.swift` / `RotationLiveView.swift` / `SubstitutionsView.swift` / `FormationMatchLiveView.swift` / `PaveNumeriqueRapideView.swift` / `SelecteurZoneView.swift` | Saisie point-par-point (courtside), dashboard, rotations nous/adv, subs, pavé rapide, zones |
| `AnalyseMatchSheet.swift` / `FilDuMatchView.swift` / `SetsScoreView.swift` / `CompositionMatchView.swift` / `ExportMatchPDFView.swift` | Analyse pré-filtrée (BoxScore/Rotations/Heatmap/Fil), worm chart, score par set, 6 de départ (compo persistante, indisponibles grisés), export PDF |
| `HeatmapTerrainView.swift` | Contient HeatmapTerrainView ET HeatmapEquipeView (3 modes) — accès canonique : hub Équipe |
| `StatsParRotationView.swift` | Sideout %/6 cartes-terrain — accès canonique : hub Équipe |

### Séances (`Views/Seances/`)
| Fichier | Description |
|---------|-------------|
| `ListeSeancesView.swift` | Pratiques (.sidebar + searchable), présences via carte/contextMenu, soft delete |
| `CalendrierView.swift` | Calendrier unifié — accès RACINE (Dock), sync Apple Calendar, lien Planification |
| `PlanificationSaisonView.swift` / `PhaseSaisonDetailView.swift` | Phases de saison (filtre Analytics) |
| `PresencesView.swift` / `NouvelleSeanceView.swift` | Présences par séance ; création |

### Exercices (`Views/Exercices/`)
| Fichier | Description |
|---------|-------------|
| `ListeExercicesView.swift` | Exercices d'une séance ; toolbar : **Présences** (C7) + **Plan de pratique** PDF (2.6.2) + création (bibliothèque/vide) |
| `ExerciceDetailView.swift` / `NouvelExerciceView.swift` | TerrainEditeurView (étapes, présentation AirPlay) |

### Équipe (`Views/Equipe/`)
| Fichier | Description |
|---------|-------------|
| `EquipeView.swift` | Sidebar : hub **Statistiques** (Mon équipe / Analytics / Rotations / Heatmap / Palmarès / **Exports CSV**) + roster par poste + Inactifs |
| `JoueurDetailView.swift` | Fiche joueur : disponibilité + consentement parental (coach), résumé, présences, muscu, Picker Stats/Évolution/Comparaison (Objectifs incorporés). Plus de section identifiants |
| `NouveauJoueurView.swift` | **Formulaire JoueurEquipe pur** (donnée, sans compte) |
| `EditionJoueurView.swift` | Édition du joueur (poids sur `JoueurEquipe.poidsKg` — plus de miroir Utilisateur) |
| `TableauBordView.swift` / `AnalyticsSaisonView.swift` / `BoxScoreView.swift` / `EvolutionJoueurView.swift` / `ComparaisonView.swift` / `PalmaresRecordsView.swift` / `ObjectifsJoueurView.swift` / `ExportStatsView.swift` | Hub statistiques (kit CarteMetrique/TableauStats) |
| `SuiviMusculationView.swift` / `TestsPhysiquesView.swift` / `JoueurSuiviMuscuSection.swift` | Suivi charges (alimenté par la saisie coach D2) + tests physiques |

### Stratégies (`Views/Strategies/`)
| Fichier | Description |
|---------|-------------|
| `StrategiesView.swift` | Sidebar : entrée **Formations** nommée + stratégies par catégorie ; le scouting a déménagé dans Matchs (C1) |
| `StrategieDetailView.swift` / `FormationsView.swift` | Terrain éditable ; formations 5-1/4-2/6-2/beach + perso |

### Bibliothèque (`Views/Bibliotheque/`)
| `BibliothequeView` / `BibliothequeDetailView` / `BibliothequeSubViews` | Recherche, catégories perso, favoris, import vers séance, export JSON |

### Entraînement / Musculation (`Views/Entrainement/`)
| Fichier | Description |
|---------|-------------|
| `EntrainementView.swift` | Programmes (.sidebar + searchable, création en Form) ; **sélecteur « Pour quel joueur ? »** avant la séance live (D2 — assignés puis roster, indisponibles désactivés, option sans joueur) |
| `SeanceLiveView.swift` / `ProgrammeDetailView.swift` / `BibliothequeMusculationView.swift` | Mode live (chrono/séries/repos, SeanceMuscu au nom du joueur choisi), détail programme, bibliothèque muscu |

### Profil (`Views/Profil/`)
| Fichier | Description |
|---------|-------------|
| `ProfilView.swift` | Paramètres — visibles par TOUT le staff (D6, plus de distinction estCoach) : code équipe, Organisation (Ajouter un assistant, Identifiants de l'équipe), équipes (suppression = cascade complète : 14 entités + PhaseSaison/CredentialAthlete/comptes membres/Presence-Evaluation-TestPhysique par joueurID), bord de terrain, iCloud (JournalSync), tutoriel, légal, déconnexion |
| `AjoutUtilisateurView.swift` | **Assistant-only** : prénom/nom/identifiant → MembreFactory → récap code d'invitation + publication Public DB |
| `IdentifiantsEquipeView.swift` | Codes d'invitation des ASSISTANTS (copie/partage/régénération — republication fetch-puis-modifier) |
| `TutorielView.swift` | 11 pages (page messagerie retirée) |
| `AvatarEditableView.swift` / `ProfilSubViews.swift` / `JournalSyncView.swift` | Avatar (plus d'écriture croisée vers le joueur), NouvelleEquipeSheet, journal sync |

### Terrain & dessin (`Views/Terrain/`)
| `TerrainVolleyView` (18×9 + demi-terrain 9×9) / `CanvasDessinView` / `BarreOutilsDessin` / `OverlayDessinView` / `TerrainEditeurView` / `TerrainMiniatureView` / `PanneauFormationsView` / `PresentationTerrainView` | Terrain complet : dessin PencilKit + overlay vectoriel, formations 2 taps, étapes + duplication « Continuer », présentation AirPlay |

### DockBar (`Views/DockBar/`)
| `DockBarView` (Recherche · Calendrier · Profil, badge séance du jour) / `BoutonRetourAccueil` (composant partagé des 5 sections) |

## Conventions & patterns critiques

### Authentification & rôles — SIWA strict, coach-first (pivot 2026-08)
- **Sign in with Apple est l'UNIQUE méthode de connexion.** Aucun mot de passe nulle part (ni UI ni stockage).
- **Deux rôles actifs** : `.admin` (head coach, créé par le wizard) et `.assistantCoach` (créé par MembreFactory, rejoint par code d'invitation). **Mêmes droits partout (D6)** — la seule garde résiduelle est « session valide » (`authService.utilisateurConnecte != nil`).
- **`.etudiant` n'est plus jamais créé ni connecté** (le cas d'enum reste décodable — données legacy). **`.coach` est un rôle résiduel** : il ne peut pas rejoindre une équipe (c'est aussi le rôle du coach DÉMO sur `suivis/pr6`).
- **Jonction** : `roleJonctionAutorise` accepte `.assistantCoach` SEUL ; `rejoindreEquipe` → import équipe + `reclamerMembreLocal` (rattache l'appleUserID par code d'invitation) ; test de régression « jonction .etudiant REJETÉE » dans MultiUtilisateurTests.
- **PermissionsRole/StaffPermissions/estCoach n'existent plus dans l'UI** — ne pas réintroduire de gardes par rôle.
- **Révocation SIWA** vérifiée au lancement (PlaycoApp) + retour foreground (ContentView).

### Multi-équipes & scoping données
- **`codeEquipeActif`** : EnvironmentKey injecté par ContentView.
- **`.filtreEquipe()`** : remplace TOUT filtre manuel par codeEquipe.
- ⚠️ `Presence`/`Evaluation`/`TestPhysique` n'ont PAS de codeEquipe (angle mort historique) — clés joueurID/seanceID ; la cascade de suppression d'équipe les purge par joueurID capturés AVANT la suppression du roster.
- **Changement d'équipe** : Notification `.changerEquipe` ; navigation config : `.allerChoixInitial`.

### Design System — Mat Nuit (2.4 vague 1)
- **La nuit est LE mode** : `.preferredColorScheme(.dark)` à la racine, UN seul écrivain, aucun toggle.
- **`MatNuit`** (ThemeCouleurRole.swift) : fond #0D0D0F, encres (AAA/secondaire/décorative), 5 tons d'espace neutres (terre Séances, brique Matchs, ardoise Stratégies, sauge Équipe, lavande Entraînement), sémantiques (live, deltas), plafond verre 12 %, tokens bordure/reflet/ombre. **Contrat WCAG exécutable : `MatNuitTests`** — toute nouvelle couleur passe par un token testé.
- **`PaletteMat`** = alias vers les tons MatNuit (les hex vifs v2 sont morts) ; `MatNuit.brique` pour Matchs (pas de PaletteMat.rouge).
- **Kit verre sombre 3.0** : GlassCard/GlassSection/GlassChip — teinte ≤ 12 %, bordure 9 %, reflet, ombre nuit ; **courtside préservé** (env `modeBordDeTerrain` annule bordure/reflet/ombre).
- **PencilKit** : `overrideUserInterfaceStyle = .light` sur tout PKCanvasView (fidélité des dessins existants).
- **TOUJOURS `LiquidGlassKit`** pour rayons/espacements/springs — pas de magic numbers. Reste de la vague 1bis : échelle typo, purge .rounded/.hierarchical, empty states maison, unification des deux noirs.
- Uniformisation (chantier D vague 1) : `BoutonRetourAccueil` partagé, sidebars `.sidebar` + searchable, icône de création `plus` unique, créations en `Form`, suppression destructive TOUJOURS confirmée (confirmationDialog — modèle : suppression de match).

### Performance — Caching
- Computed lourdes → `@State` + `.onAppear`/`.onChange` ; `StatsEquipeCache` ; `.contentTransition(.numericText())` ; `.filtreEquipe()` une seule fois, caché.
- **DateFormattersCache** et **JSONCoderCache** obligatoires (jamais d'instanciation directe).

### ⚠️ Pièges connus (NE PAS répéter)
1. **CanvasController.canvasView** doit être `weak var`, JAMAIS `@Published`
2. **NavigationSplitView** : detail pane DOIT contenir un `NavigationStack`
3. **Coordonnées overlay** : normalisées 0-1, PAS en points absolus
4. **SwiftData migration** : nouveaux champs @Model DOIVENT avoir une valeur par défaut sur la déclaration
5. **etapesData** : toujours propager lors de copie/duplication/import/export
6. **typeTerrain** : stocké comme String, converti via `TypeTerrain(rawValue:) ?? .indoor`
7. **Soft delete** : Seance.estArchivee, Exercice.estArchive, StrategieCollective.estArchivee — TOUS les @Query doivent filtrer
8. **TerrainEditeurViewModel** : toute logique terrain passe par le ViewModel, plus directement dans la View
9. **JSONCoderCache** : NE JAMAIS créer `JSONDecoder()` / `JSONEncoder()` directement
10. **Auto-save** : debounce 3s via Combine, ViewModel deinit envoie `.finished` au subject
11. **Filtrage équipe** : TOUJOURS utiliser `.filtreEquipe(codeEquipeActif)`, JAMAIS filtre manuel
12. **Computed properties** : cacher en `@State` + `.onChange` si filtre/sort/reduce (surtout dans body)
13. **Pas de fichiers dupliqués** : vérifier avant de créer (Color(hex:) n'existe qu'une fois dans Extensions.swift)
14. **CloudKit** : ModelConfiguration(cloudKitDatabase: .automatic) avec fallback local + fallback mémoire
15. **CloudKit @Model** : TOUS les attributs doivent avoir une valeur par défaut, TOUTES les relations doivent être optionnelles (`[Type]?`), TOUTES les relations doivent avoir un inverse (`@Relationship(inverse:)` sur au moins un côté)
16. **Seance.exercices** : `[Exercice]?` (optionnel pour CloudKit) — TOUJOURS accéder via `seance.exercices ?? []`, append via `seance.exercices?.append()` avec guard `if seance.exercices == nil { seance.exercices = [] }`
17. **Pas de print()** : utiliser `Logger(subsystem:category:)` avec `import os`. Niveaux : `.info`, `.warning`, `.error`, `.critical`
18. **Info.plist** : `PlaycoInfo.plist` à la racine du projet (pas dans le dossier source) — y mettre toutes les privacy keys
19. **LiquidGlassKit** : TOUJOURS utiliser les constantes (rayons, espacements, animations) — NE PAS écrire de magic numbers
20. **PointMatch** : suppression cascade match doit aussi supprimer les PointMatch associés (filter par seanceID)
21. **PhotosPicker** : import PhotosUI, utiliser `@State photoItem: PhotosPickerItem?` + `.onChange(of: photoItem)` pour charger l'image
22. **SUPPRIMÉ (pivot coach-first, D3)** : le paywall StoreKit n'existe plus — ne réintroduire AUCUN code StoreKit/gate sans décision fondateur. Numéro conservé pour l'intégrité des références historiques.
23. **Abonnement/tierAbonnementRaw GELÉS** : `Abonnement` @Model + `Equipe.tierAbonnementRaw` restent au schéma CloudKit (suppression = migration destructive) mais ne sont plus jamais écrits ni lus. `Abonnement` est volontairement HORS de la cascade de suppression d'équipe (trace d'achat par utilisateur).
24. **Stats — source unique des formules** : toute formule statistique vit dans `Helpers/MetriquesVolley.swift` (fractions 0-1, D1) et tout formatage dans `FormatMetriques` (hitting en convention volleyball « .350 » via `.hittingVolley`, pourcentages français « 85,0 % » via `.pourcentage`). ⚠️ PIÈGE d'échelles hérité : `JoueurEquipe.efficaciteReception`/`efficaciteAttaque` et `StatsJoueur.hittingPct` (dashboard live) sont en 0-100 ; `pourcentageAttaque`/`StatsMatch.hittingPct` en 0-1 — NE JAMAIS re-multiplier par 100 (bug B1). L'agrégation PointMatch/ActionRallye → compteurs passe par `Services/AgregateurStatsMatch.swift` (JAMAIS de switch local) ; le cumul carrière = Σ StatsMatch via `resynchroniserCumul` (idempotent — JAMAIS d'addition `+=` au cumul, bug B2) ; la finalisation passe par `finaliserStats` (unit les StatsMatch créés dans l'appel). Contexte de service : `PointMatch.nousServionsAuMoment`/`serviceRenseigne` (posés dans `enregistrerStat` AVANT `gererSideout`) ; legacy reconstruit par `MetriquesVolley.reconstruireService`. Kit UI stats : `CarteMetrique`/`EnTeteSection`/`TableauStats`/`LegendeStatsSheet` (FiltresStats supprimé — code mort) — pas de cartes ad hoc. D6 : aucun émoji, aucun SF Symbol décoratif.
25. **Tests SwiftData** : les `ModelConfiguration` de test DOIVENT passer `cloudKitDatabase: .none` (sinon le mirroring CloudKit s'attache aux stores in-memory et crashe « No eligible connection available » quand le daemon comptes du simulateur est froid). Schéma = fermeture transitive des relations (pattern `MatchLiveViewModelTests`).
26. **CloudKit Public DB — JAMAIS de credentials ni PII sensible** : `CloudKitSharingService` publie un miroir d'équipe dans la **Public DB world-readable**. NE JAMAIS y écrire de secret — cf. `champsPublicsUtilisateur` + gardes de régression dans `CloudKitSharingServiceTests`/`CloudKitPartagePreparationTests` (étendues aux types E2/E3 : hash legacy `JoueurEquipe` jamais mappés, **`joueursData` du scouting JAMAIS publié ni importé** [PII de joueurs adverses], `estFavori` local). Étendre la garde à CHAQUE nouveau record type. La jonction multi-Apple-ID (`rejoindreEquipe`/`reclamerMembreLocal`) rattache l'`appleUserID` d'un ASSISTANT via le code d'invitation. Durcissement Dashboard (Security Roles) = action humaine (`docs/Securite_AbonnementPublicDB.md`).
27. **CKRecord existants — FETCH-PUIS-MODIFIER obligatoire** : créer un `CKRecord` neuf pour un recordID existant échoue en silence (`serverRecordChanged`) — la mise à jour n'atteint JAMAIS la Public DB (bug révocation de code, revue 2.3). Généralisé (E1) : TOUT `publierX` passe par `recordPublicAJour(type:recordID:)` (fetch-puis-modifier) — exception : `PointMatchPartage` (immuable, lots `modifyRecords` savePolicy `.allKeys`).
28. **Mode déconnecté du live (D6)** : pendant un match live, UN SEUL preneur de stats — le mode match pause la sync ; toute publication des données du live (PointMatch…) se déclenche à la SORTIE du live, jamais pendant.

### Système de matchs
- **Cycle du coach dans MatchsView** : Préparation (scouting en sidebar) → match (3 groupes-menus : Préparer · En direct · Après) → analyse (sheet pré-filtrée).
- **Match éclair** (bolt) : 2 champs, composition héritée À LA CRÉATION (validée effectif actif + disponible).
- **Score par set** (1-5, SetScore JSON) ; **stats live** point-par-point (PointMatch, rotations auto nous+adv, undo) ; **finalisation** via `AgregateurStatsMatch.finaliserStats`.
- **Suppression cascade CONFIRMÉE** (confirmationDialog) : reverse stats joueurs + delete StatsMatch/PointMatch + soft delete.
- **Reprise après kill** : `MatchLiveRestauration` (marqueur 6 h) → resélection + alerte « Reprendre ».
- Heatmap/Rotations : accès canonique = hub Statistiques d'Équipe ; versions pré-filtrées dans « Analyse » du match.

### Musculation (Section Entraînement)
- Le coach choisit le joueur AVANT la séance live (D2) — la `SeanceMuscu` porte son `joueurID` et alimente `SuiviMusculationView` ; option « séance d'équipe » sans joueur ; joueurs indisponibles (2.2.b) proposés mais désactivés.

## Commande build
```bash
cd "/Users/armypo/Documents/Origotech/Playco" && xcodebuild -scheme "Playco" -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
```
Tests (TOUJOURS en série — clones parallèles instables avec le host CloudKit) :
```bash
xcodebuild test -scheme Playco -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' -parallel-testing-enabled NO
```
Baseline : **310/310 tests, 47 suites** (2026-09-01, pivot chantiers A-E). Toolchain stable par défaut (`xcode-select`). Notes historiques : Xcode 27 beta via `DEVELOPER_DIR=~/Downloads/Xcode-beta.app/...` ; régression runtime simulateur iOS 27 beta (juil. 2026 : crashs SwiftData in-memory) → valider sur la toolchain stable.

## État actuel — pivot coach-first (branche `pivot/coach-first`, 2026-09-01)
- ✅ Build **0 erreur / 0 warning** ; **320/320 tests, 50 suites**
- ✅ **App GRATUITE** (D3) · **Coach-first** (D1-D6) · navigation (C) · uniformisation D vague 1 + 1bis partielle (Fermer, empty states, Forms)
- ✅ **Chantier E → E′** : sync inter-coachs REFONDUE après revue adversariale (records par écrivain, confiance par créateur transitive, tombstones, filigranes anti-écho, PII minimale, mode match étanche) — `docs/Architecture_SyncEPrime.md`. **Posture A + C** : résidu adversarial accepté et documenté (`docs/SyncEPrime_Residuel.md`), CKShare au backlog. ⚠️ Action Dashboard CloudKit avant prod : ACL créateur-seul + champs QUERYABLE (`codeEquipe` partout, `ecrivainID`, `seanceID`/`publieLe` [sortable] sur `PointMatchPartage`, `SuppressionPartagee`)
- 🔜 PR `pivot/coach-first` → `main` puis rebase de `suivis/pr6` (démo) ; D vague 1bis suite (kit stats, paddings) ; textes légaux ; action humaine `TelemetryDeckAppID`
- Docs de référence : `docs/Pivot_CoachFirst_Plan.md` · `docs/Journal_Pivot_CoachFirst.md` · `docs/Revue_Chantier_E.md` · `docs/Architecture_SyncEPrime.md` · `docs/SyncEPrime_Residuel.md`

## Langue
L'interface est entièrement en **français**. Noms de variables, commentaires et UI en français.

## Historique des patchs
| Patch | Description |
|-------|-------------|
| 0.1.0 | Projet initial : séances, exercices, bibliothèque, terrain dessinable, PencilKit, multi-étapes |
| 0.1.1 | Accueil 3 sections, modèles JoueurEquipe + StrategieCollective + FormationPersonnalisee, formations, terrain indoor/beach, catégories, verrouillage |
| 0.2.0 | Diagnostic & Optimisation — DateFormattersCache, PDFExportService, TerrainContent, auto-save, versionnement JSON |
| 0.3.0 | Correctifs & Refactoring — Undo/Redo snapshots, TerrainEditeurViewModel, ValidationService, soft delete |
| 0.4.0 | Performance — JSONCoderCache, auto-save debounce Combine, soft delete StrategieCollective |
| 0.5.0 | Statistiques volleyball NCAA/FIVB — 15+ champs stats, computed hitting%, TableauBordView agrégé |
| 0.6.0 | Section Entraînement — mode live, chrono, navigation exercices, présences + évaluation |
| 0.7.0 | **Section Matchs** — MatchsView dédiée séparée des séances, NouvelMatchSheet, box score SaisieStatsMatchView, suppression cascade stats, AccueilView 5 sections (3+2 grille) |
| 0.8.0 | **Authentification & Multi-équipes** — AuthService (connexion identifiant+mdp, hash SHA256+sel, verrouillage), Utilisateur model, LoginView, RejoindreEquipeView, ChoixInitialView, SelectionEquipeView, PermissionsRole (.siAutorise), codeEquipeActif EnvironmentKey, données scopées par équipe |
| 0.9.0 | **Onboarding Wizard** — ConfigurationView 6 étapes, modèles Etablissement/ProfilCoach/Equipe/AssistantCoach/CreneauRecurrent/MatchCalendrier, génération séances récurrentes, auto-login |
| 0.10.0 | **Musculation** — ProgrammeMuscu, SeanceMuscu, ExerciceMuscu, SeanceLiveView muscu, SuiviMusculationView graphiques charges, TestsPhysiquesView |
| 0.11.0 | **Messagerie** — MessagerieView inter-équipe + conversations privées, MessageEquipe model, badges non-lus DockBar |
| 0.12.0 | **Profil & Paramètres** — ProfilView (code équipe, organisation, créer équipe, déconnexion), DockBarView (Messages + Profil), MonProfilAthleteView, masquer pratiques athlètes |
| 1.0.0 | **Design Liquid Glass v2 & Performance** — GlassCard highlight gradient + double shadow + teinte, GlassButtonStyle spring, spring transitions (.spring 0.4/0.85), FiltreParEquipe protocole + .filtreEquipe() (12+ fichiers), @State cachés (AccueilView, EquipeView, TableauBordView), StatsEquipeCache (8 reduce→1), .contentTransition(.numericText()), AccueilView premium (double gradient, .symbolRenderingMode(.hierarchical), typo .rounded), suppression fichiers dupliqués |
| 1.0.1 | **CloudKit** — ModelConfiguration cloudKitDatabase: .automatic, fallback local, sync inter-appareil |
| 1.0.2 | **AXIS Audit** — Fix remettreANeuf(), filtre estArchivee ContentView, fix force unwrap ProfilView, error handling stats save, deinit ViewModel saveSubject, suppression OnboardingView/SeanceModel/ConfigurationViewHelpers/PaletteMat orphelins, suppression Color(hex:) dupliqué |
| 1.1.0 | **Fonctionnalités avancées** — ScoutingReport (plan de match adversaire), EvolutionJoueurView (graphiques Swift Charts), HeatmapTerrainView (zones 1-6), CloudKitSyncService (indicateur sync hors-ligne), ContentUnavailableView (empty states natifs), .sensoryFeedback (haptics), Logger remplace tous les print(), .filtreEquipe() sur tous les fichiers restants |
| 1.1.1 | **App Store Prep** — Info.plist privacy keys (calendrier + photos), entitlements CloudKit (iCloud + push + background), fatalError→fallback mémoire, .foregroundColor→.foregroundStyle, plists orphelins nettoyés, filtre estArchivee sur EvolutionJoueurView @Query, CLAUDE.md mis à jour (22 modèles) |
| 1.2.0 | **Match avancé & outils coach** — PointMatch @Model (stats live point-par-point), StatsLiveView (saisie temps réel, rotation auto, undo), CompositionMatchView (6 de départ par poste), SetsScoreView (score par set 1-5), ExportMatchPDFView + PDFExportService (résumé PDF partageable), ComparaisonView (joueur vs moyenne équipe), ModifierUtilisateurView (édition joueur complète par coach), AvatarEditableView (photo + initiales), LiquidGlassKit (constantes design centralisées), BibliothequeMusculationView (exercices muscu CRUD), StrategiesView/StrategieDetailView/FormationsView (section stratégies complète), BibliothequeView/BibliothequeDetailView (bibliothèque exercices), SelectionEquipeView (sélection multi-équipes) |
| 1.3.0 | **Rebranding** — Rebranding complet : Coach Planner VB → Playco (code, dossiers, pbxproj, bundle ID Origo.Playco, Logger com.origotech.playco) |
| 1.4.0 | **TestFlight & CloudKit Fix** — Compatibilité CloudKit complète : defaults sur tous les attributs @Model (6 modèles), relations optionnelles (Seance.exercices → `[Exercice]?`), relations inverses (Equipe↔Etablissement, Equipe↔AssistantCoach/CreneauRecurrent/MatchCalendrier, Etablissement↔ProfilCoach), correction 19 références exercices optionnels (4 fichiers). ⚠️ **Note historique obsolète** : StoreKit 2 a été retiré temporairement dans cette version puis **réintégré en v2.0.0** (login unifié + paywall StoreKit 2). PlaycoInfo.plist à la racine (CFBundleIconName, ITSAppUsesNonExemptEncryption, privacy keys). AppIcon placeholder 1024×1024. RejoindreEquipeView : ajout champ code équipe + validation appartenance. Exemples configurateur : Cégep Garneau / Québec / Élans / Christopher Dionne. TestFlight validé et fonctionnel. |
| 1.5.0 | **Analytics, Objectifs, Split-screen & Export CSV** — Heatmap avancé : PointMatch.zone (1-6), SelecteurZoneView (mini-terrain tapable, sélection optionnelle), TypeActionPoint.categorieHeatmap, HeatmapEquipeView refactoré (données réelles PointMatch, filtres par match/set/joueur, fallback simulé). AnalyticsSaisonView (tendances saison : résultats cumulatifs V/D, efficacité attaque par match, séries, classements marqueurs/serveurs/bloqueurs, Swift Charts). ObjectifJoueur @Model (24e modèle) + ObjectifsJoueurView + NouvelObjectifView (objectifs individuels par joueur, progression automatique depuis stats, suggestions rapides, catégories, Gauge circulaire). MatchLiveSplitView (mode live split-screen : Dashboard + StatsLive côte à côte iPad, TabView iPhone, fullScreenCover). CSVExportService + ExportStatsView (export CSV stats joueurs/matchs/résultats, ShareLink, séparateur point-virgule compatible Excel/Numbers). |
| 1.6.0 | **Stats rotation, Palmarès, Phases saison & Mode présentation** — StatsParRotationView (analyse efficacité par rotation 1-6, graphiques barres efficacité + points pour/contre, meilleure/pire rotation, tableau détaillé, filtre par match, accessible depuis MatchsView bottomBar). PalmaresRecordsView (records individuels : plus de kills/aces/blocs/points/passes par match + meilleur hitting %; records d'équipe : plus de points/aces/blocs collectifs + meilleur hitting % équipe + plus grand écart, accessible depuis EquipeView sidebar). AnalyticsSaisonView : filtrage par PhaseSaison (toute la saison ou phase spécifique, appliqué à tous les graphiques et calculs). Mode présentation terrain : bouton "Présenter" ajouté dans MatchDetailView toolbar + StrategieDetailView toolbar, fullScreenCover PresentationTerrainView accessible en un tap. TutorielView : tutoriel paginé 12 pages couvrant toutes les fonctionnalités, TabView(.page), affiché automatiquement au premier lancement (@AppStorage "tutorielVu"), accessible depuis Paramètres → Aide → Voir le tutoriel, fond RadialGradient animé, indicateur dots colorés. |
| 1.7.0 | **Chantiers v1.7** — 8 chantiers : recherche globale (RechercheGlobaleView Spotlight-like), catégories exercices (CategorieExercice @Model), gestion suppression équipe (cascade manuelle 14 entités + confirmation nom), stats rallye (ActionRallye @Model, manchettes/passes/réceptions), permissions staff (StaffPermissions @Model 7 booleans, GestionStaffView), config match (ConfigMatch struct : subs max, TM, TTO, service), transitions portrait/landscape (SwiftUI sizeClass), stats FIVB complètes (dig/tentativeAttaque/serviceEnJeu, RotationLiveView, historique rotations) |
| 1.8.0 | **Mode hors-ligne robuste & Mode bord de terrain** — Journal sync (EvenementSync struct Codable buffer 50 UserDefaults, JournalSyncView liste colorée par type). Mode match (pause sync auto pendant match live, toggle wifi.slash dans toolbar MatchLiveSplitView, capsule SYNC PAUSÉE, confirmation reprise). Compteur modifications en attente (enregistrerStat/substitution/TM/set → syncService.enregistrerModificationLocale()). Mode bord de terrain courtside (EnvironmentKey modeBordDeTerrain + themeHautContraste, constantes LiquidGlassKit courtside). StatsLiveView courtside (score 72pt, 6 stats essentielles, panneau rallye masqué, bouton annuler simplifié). DashboardMatchLiveView courtside (4 cartes stats, tableau joueurs masqué avec toggle). Haptics match (sensoryFeedback impact/warning/success sur score/subs). PaveNumeriqueRapideView (overlay flottant #→joueur→action 4 boutons). Mode lecture seule (StaffPermissions.peutGererStats, badge LECTURE SEULE, boutons disabled). Réglages ProfilView (2 toggles @AppStorage). |
| 1.9.0 | **Stats adversaire symétriques & Rotation adversaire** — 5 nouveaux TypeActionPoint (killAdversaire/aceAdversaire/blocAdversaire/erreurAttaqueAdversaire/erreurServiceAdversaire) + estStatAdversaire computed + mise à jour tous les switch (Seance.swift, MatchDetailView, DashboardMatchLiveView). DefinitionStat adversaire standard : statsAdversaireScoring (3 items point contre nous) + statsAdversaireErreurs (3 items point pour nous), remplace l'ancien statsAdversaire à 2 items. StatsLiveView : sections adversaire dédiées (Scoring rouge + Erreurs vert) avec boutons directs sans sélection joueur, mode courtside inclus. DashboardMatchLiveView : comparaison détaillée avec vraies valeurs adversaire (advKills/advAces/advBlocs/advErreurs), chip rotation adversaire. Rotation adversaire : rotationAdversaire + rotationAdvAuMoment (PointMatch), tournerAdversaire() auto sur sideout adverse, modifierRotationAdversaire() manuel, rotationsHistoriqueAdvData (Seance @Model), annuler point inverse rotation adv, reset rotation adv à 1 par set. RotationLiveView : Picker segmenté Nous/Adversaire, mini-terrain adversaire rouge simplifié (positions numérotées sans noms), boutons R1-R6 adversaire, historique rotations adversaire par set. Score area : rotation affichée "R1 · R1" (bleu nous + rouge adv). |
| 2.0.0 | **Login unifié + StoreKit 2 + correctifs App Store** — `feat(v2.0)` (PR #1, commit `d4cf08e`) : nouveau flow login unifié, paywall StoreKit 2 réintégré (4 product IDs `ca.origotech.playco.{pro,club}.{monthly,yearly}` + subscription group `playco.pro`), modèle `Abonnement` @Model, `Playco.storekit` config, `FeatureGating` (`bloqueSiNonPayant(source:)`), correctifs App Store divers. Sécurité auth renforcée : `PasswordPolicy` (longueur min 12 + check mots de passe communs), `KeyDerivation` PBKDF2-HMAC-SHA256 600k itérations (avec migration auto SHA256 legacy → PBKDF2), `LockoutManager` persistant Keychain, `SessionManager` extrait, `FileReplicationUtilisateur` actor (file de re-publication CloudKit Public DB avec backoff exponentiel + abandon après 10 tentatives), `KeychainService.sauvegarder` retourne `Bool`. Refacto auth 3 étapes (KeyDerivation → LockoutManager → SessionManager). |
| 2.0.1 | **Fix paywall TestFlight** — Symptôme reporté : bouton "S'abonner ·" tronqué + sans réaction au tap quand `storeKit.produits == []`. Cause racine code : `onAppear` forçait `produitSelectionneID = proAnnuel` mais `produits.first {…}` retournait `nil` → bouton `.disabled` invisible (LinearGradient ne grise pas). **Fix** : extraction `PaywallViewModel` @Observable (États `initial/chargement/pret/erreur`), `ctaLabel` switch dynamique sécurisé (`ctaAchatPrefixe + displayPrice`), bouton `.opacity(0.45)` quand inactif + spring animation, retrait pré-sélection auto (anti-achat involontaire B4), bouton "Réessayer" sur erreur (B5), restauration distingue rien-à-restaurer vs réseau (B3), log `StoreKitService` warning produits manquants ASC (B7). Liaison équipe : `Abonnement.codeEquipe` ajouté (CloudKit-safe default `""`), lookup automatique première équipe locale dans `persisterDansSwiftData`. Tests : 9 nouveaux Swift Testing (`AbonnementCodeEquipeTests` 4 + `PaywallTextesTests` 5), garde-fous régression sur préfixe CTA. Baseline 123 préservés. **Suivi staged PR ultérieure** : actor `CloudKitPublicSyncAbonnement` + fallback Public DB dans `rafraichir` (G2/G3) pour reconnexion sur Apple ID différent. **Action humaine requise (Phase 2 ASC)** : statut produits "Prêt à soumettre" + accords payants signés dans App Store Connect (sinon `Product.products(for:)` retourne `[]` en build TestFlight). |
| **2.0.1 / SIWA** (juin 2026) | **Sign in with Apple + sécurité + multi-appareils (direction retenue)** — Refonte auth : `AppleSignInService`, `AuthService.connexionApple`/`lierCompteExistant`, `Utilisateur.appleUserID`. Connexion primaire = SIWA ; **zéro mot de passe stocké** (`CredentialAthlete.motDePasseClair` vide) ; jonction cross-Apple-ID par **code d'invitation** (`rejoindreEquipe`/`reclamerMembreLocal`, surfaces coach affichent le code via `IdentifiantsRecapSheet`/`IdentifiantsEquipeView`). Paywall **role-aware** (`paywallDoitBloquer` — athlètes/assistants jamais bloqués). Sécurité : aucun secret en Public DB (`champsPublicsUtilisateur`), aucun accès accordé depuis données publiques non signées (fallback supprimé), révocation SIWA au lancement + foreground. Réconcilie le merge avec l'approche par mot de passe de `main` (PR #4/#5) — SIWA retenu, partage Séances/Matchs de main préservé. |
| **partage/connexion/paywall** (juin 2026) | **Partage coach→athlète + login cross-Apple-ID + paywall** — Correction de 3 bugs bloquants à l'intersection partage/login/paywall. (1) **Login athlète cross-Apple-ID** : recréation de `RejoindreEquipeView` (code+identifiant+mdp → `equipeExiste` → `recupererEtImporterEquipe` → `connexion` → vérif appartenance) + 3e carte `ChoixInitialView` + écran `.rejoindre` dans `PlaycoApp`. (2) **Tier dans la gate** : `EquipePartagee` ne porte pas le tier → `recupererEtImporterEquipe` + `appliquerGateTier` (rendue **async**) sourcent le tier depuis `CloudKitPublicSyncAbonnement.lire` (sinon athlète d'un coach Club bloqué). (3) **Paywall rafraîchi** : `rafraichir()` après achat/restore (PaywallView) + au foreground coach (ContentView). **Données partagées lecture seule** : record types `SeancePartagee` + `MatchCalendrierPartagee` + stats cumulées (~16) sur `JoueurPartage` (publier/importer + merge `dateModification`). **Sweep coach unique** `publierMisesAJourCoach` (foreground/appear, respecte `masquerPratiquesAthletes`) + `syncDepuisPublic` athlète câblé, via `ContentView.synchroniserDonneesPartagees()` role-aware. Champs CloudKit-safe ajoutés : `Seance.dateModification`, `MatchCalendrier.codeEquipe`+`dateModification`. Lecture seule athlète (`.siAutorise` sur création séance). **150/150 tests** série (18 nouveaux), build 0/0 iOS 27 + iOS 26.3. Sécurité : aucune PII sur les nouveaux types ; rôle d'écriture créateur-seul = action Dashboard (`docs/Securite_AbonnementPublicDB.md`). Détails : `docs/TODO_PartageConnexionPaywall.md`. |
| **audit/xcode27** (juin 2026) | **Audit Xcode 27 beta** — Build sous Xcode 27.0 beta (`27A5194q`, SDK iOS 27.0) via `DEVELOPER_DIR`, cible iOS 26.2 inchangée. **Résultat : 0 erreur / 0 warning, 132/132 tests (en série).** Concurrence : 12 warnings baseline corrigés sans risque (`JSONCoderCache`/`KeychainService`/`PolitiqueRetry` → `nonisolated` ; `_ = …save()`). **`SWIFT_STRICT_CONCURRENCY = complete` testé puis ABANDONNÉ** : force des `@Model nonisolated` qui crashent SwiftData+CloudKit au runtime iOS 27 (`NSManagedObjectContext.save()` / migration métadonnées) — diagnostic prouvé par bissection. Mode approachable conservé ; flip Swift 6 + strict reportés post-lancement. Correctness : force-unwraps URL éliminés (helper `AppConstants.url(_:)`). TelemetryDeck : placeholder nettoyé (logger-only volontaire). **Liquid Glass natif** : `GlassCard`/`GlassSection`/`GlassChip` → `.glassEffect(.regular.tint(:),in:)` (API iOS 26.0, compat cible 26.2 sans garde), 15 sites héritent. ⚠️ Tests parallèles instables sous Xcode 27 beta (clones + host CloudKit) → `-parallel-testing-enabled NO`. Détails : `docs/Audit_Xcode27_Synthese_Juin_2026.md` + `docs/TODO_Audit_Xcode27.md`. **NB v2.0.1/SIWA** : le `CloudKitPublicSyncAbonnement` de cette branche est remplacé par la version informationnelle SIWA (pas d'accès accordé depuis la Public DB). |
| **refonte/stats-equipe** (juillet 2026) | **Refonte statistiques, Équipe, formations & scouting** — Branche `CChristo/kind-dirac-f6548b` (~35 commits, base post-PR #9). **Fondations** : `MetriquesVolley` (formules D1 en fractions 0-1, sideout %/point scoring % avec contexte de service D5, note de réception 0-3, runs, glossaire 17 définitions) + `FormatMetriques` (convention volleyball « .350 » D2, pourcentages français) + `AgregateurStatsMatch` (agrégation unique, 3 switch dupliqués factorisés, `finaliserStats` testable, `resynchroniserCumul` idempotent). **Bugs corrigés** : B1 réception ×100 en double (4 sites → « 8500 % »), B2 double comptage des cumuls carrière à chaque sauvegarde du box score (+ CRITICAL revue : StatsMatch créés invisibles à la resync), formats hitting incohérents (3 variantes), 4 émojis 🏐 → volleyball.fill, touch targets 44 pt, tests coupés de CloudKit (`cloudKitDatabase: .none`, 49 crashs/run éliminés). **Hub stats** : sidebar Équipe → section Statistiques 5 entrées (Mon équipe/Analytics/Rotations/Heatmap/Palmarès), fiche joueur segmentée (Stats/Évolution/Comparaison incorporées), chip « Analyse » sur match finalisé (box score/rotations/heatmap/fil pré-filtrés), top 5 et records cliquables. **Nouvelles métriques** : `PointMatch.nousServionsAuMoment`+`serviceRenseigne`+`zoneDepart`, sideout %/% au service par rotation (`StatsParRotationView` façon VBStats : 6 cartes-terrain + filtre joueur), fil du match (worm chart runs+TM/subs, `FilDuMatchView`), heatmap 3 modes (volume/efficacité divergente/trajectoires), sélecteur de zone 2 étapes (arrivée→départ), `ConfigMatch.demanderZone`, zones des actions marquantes adverses (`categorieHeatmap`). **Refonte visuelle** (kit `CarteMetrique`/`EnTeteSection`/`TableauStats`/`FiltresStats`/`LegendeStatsSheet`/`TypographieStats`) : TableauBord, JoueurDetail (repère .300), Analytics (D4 : « Rendement attaque »), Comparaison (moyenne PAR POSTE + écarts %), Évolution (moyenne mobile 3 matchs), Palmarès, BoxScore extrait, Dashboard live (TableauStats groupé), StatsLive (3 blocs), SaisieStats (légende) — D6 zéro émoji/symbole décoratif. **Formations** : panneau 2 taps (`PanneauFormationsView` : tuiles de rotation + badge perso + beach + onglet stratégies), jetons colorés par poste (`FormationType.couleurPourLabel` central), liste des perso + alerte écrasement, outil rotation branché, duplication d'étape. **Scouting** : `seanceID` + tendances zonales (menace 0-3 par zone), éditeur repliable + mini-terrains tapables, vue lecture « une page » (`ScoutingLectureView`), duplication par adversaire, PDF plan de match, panneau live (`PlanMatchPanneau` dans le dashboard). **Tests : 253/253** (67 nouveaux), 0 warning. **Suivi post-merge** : Phase 7 démo (rebaser `suivis/pr6`, enrichir `DemoBootstrap` d'un jeu de données vitrine). |
| **audit/prelaunch** (mai 2026) | **Audit pré-lancement App Store** — Branche dédiée `audit/prelaunch` (7 commits). W1 inventaire : 30 @Model recensés (vs 23 dans doc), 8 fichiers > 600 lignes (splits justifiés reportés). W2 vérif `JSONCoderCache` propre. W3 design tokens : `.padding(24)` → `LiquidGlassKit.espaceLG` (6 occurrences mécaniques), 0 occurrence `.easeInOut`/`.foregroundColor(`. W4 a11y partiel : Canvas PencilKit (`UIViewRepresentable` traits + label dynamique selon mode), DockBar (`accessibilityValue` sur badges Messages/Profil), BarreOutilsDessin (`.accessibilityLabel/Hint` sur outils + menus formation). W5 tests : **+32 nouveaux tests passants** (`FiltreParEquipeTests` 7, `TypeActionPointTests` 12, `JoueurEquipeStatsTests` 13). **Fix `7fb4dd9` : 7 tests `MultiUtilisateurTests` pré-existants verts** — 3 causes racines identifiées : (1) `creerAuthIsole()` purgeait seulement `SessionManager.cleKeychain`, manquait `LockoutManager.cleKeychain` (isolation Keychain entre tests sérialisés), (2) `Utilisateur.iterations` par défaut = 1 → verifier choisissait branche SHA256 legacy au lieu de PBKDF2 600k → mismatch hash, (3) `motdepasse1` rejeté par nouvelle `PasswordPolicy` (12 chars min + check mots communs). **Tests : 123/123 ✅**. Items humains W6/W8 (sandbox StoreKit, VoiceOver iPad physique, AppIcon prod, TestFlight 48h, ASC assets) documentés dans `docs/Audit_Synthese_Pre_Launch_Mai_2026.md`. |
| **audit complet + SIWA strict** (juil. 2026) | **Audit complet du code + alignement SIWA strict (v2.1)** — 6 agents d'exploration (~115 trouvailles brutes), vérification adversariale (~25 faux positifs écartés). **Bugs corrigés** : `Seance.dupliquer` copiait sans `codeEquipe` (fuite inter-équipes — extraction `Seance+Duplication.swift` + tests) ; `equipeExiste` confondait hors-ligne et code invalide (→ `throws` + `SharingError.reseauIndisponible`) ; `PalmaresRecordsView` n'affichait JAMAIS les records (`@State records` jamais rempli) ; `TerrainEditeurViewModel.sauvegarderEtapeActive` → Bool + guards (perte de travail sur échec d'encodage) ; crash latent (AppleSignInService non injecté sur `.login`/`.configuration`) ; reset mdp « volleyball123 » hardcodé supprimé. **SIWA strict** : wizard étape 3 = SignInWithAppleButton (réutilisation du compte si même Apple ID), `MembreFactory` (création membre sans secret, DRY ×3), LoginView SIWA-only, TOUTES les surfaces mdp supprimées (`connexion()`/`creerCompte()`/`lierCompteExistant()`/`PasswordPolicy`/`LockoutManager`/`KeyDerivation` + leurs tests) ; champs hash conservés au schéma CloudKit. **Perf** : cache `@Transient` sur `Seance.sets` (invalidation par comparaison du Data — compatible sync CloudKit), suppression d'équipe par `#Predicate` (fini le fetch de toute la table), journal sync batché (write UserDefaults ~5 s/10 evts + flush background), pagination CloudKit par curseur (plafond 25 pages), caches @State (Calendrier/Messagerie [signature `lecteurIDsData` pour les non-lus]/Bibliothèque/Comparaison/Palmarès). **Robustesse** : sanitisation `CKRecord.chaineSecurisee` (50 lectures de records publics), dédup `Abonnement`, Keychain `SecItemUpdate` atomique, `publierStatut` distingue erreur réseau. **DRY** : `CloudKitSharingService` découpé (+Publication/+Import/+Jointure, signatures inchangées), `terrainPostes(estAdversaire:)` (RotationLive), `labelCelluleStat` (StatsLive), `GestionStaffView` ForEach, `routerVersApp()` (ex-appliquerGateTier). **Tests** : suites mdp supprimées, +9 suites nouvelles/refondues (SeanceDuplication, TerrainEditeurViewModel, SeanceSetsCache, MembreFactory, MatchLiveViewModel 15, PaywallViewModel 7 [statiques `ctaLabel`/`ctaEstActif` extraits], CSV 7, PDF 4, MultiUtilisateur refondu SIWA). Conventions hitting % documentées (fraction 0-1 modèles vs % 0-100 dashboard). NON retenus (risque > bénéfice) : découpage des 4 grosses vues, batch delete SwiftData, SKTestSession, migration SessionManager → appleUserID. |
| **vision/roadmap 3.0** (juil. 2026) | **Vision Playco 3.0 + roadmap en patchs v2.2.x→v3.x (documents seulement — AUCUN code applicatif modifié)** — 3 panels ultracode (16 agents, recherche web) : 5 visions + 2 critiques + synthèse, puis design « Playco Mat »/terrain-séances/intégration plateforme + contre-vérification C1-C11, puis revue adversariale nuit (25 amendements, recut budgétaire) + skills + optimisations. **Livrables** : `docs/Vision_Playco_3.0.md` (vision maître : thèse, design Mat sans-symbole 10 lois, 5 espaces par moment d'usage, backend hybride Supabase financé par le tier Élite, pricing 5 paliers + Élite 399 $/an, SportPack différé, PlayCast gelé) ; `docs/Roadmap_Playco_v2.2_v3.x.md` (référence d'exécution : H1 lancer/matifier/restructurer ~12 sem, H2 = LE PARI VIDÉO seul, début H3 vendre/durcir, backlog 3.x, politique démo, actions humaines, GO/NO-GO juin 2027 ; **Séances 2.0/Composer sortie de 2026-27 par le recut**) ; `docs/Vision_Playco_3.0_Annexes/` (16 documents, ~440k chars) ; `docs/Maquettes_Playco_Mat.html` (maquettes vivantes, artifact publié) ; 5 skills projet (`playco-patch`, `playco-mat-review`, `playco-demo-check`, `playco-video-securite`, `playco-roadmap-status` — dans `.claude/skills/`, non versionnés). **5 décisions fondateur en attente de ratification** (tableau en tête de la roadmap). **Révision fondateur design (même jour, commit `73131d9`)** : « Mat Nuit » — 5 couleurs d'espace en tons neutres sur fond nuit `#0D0D0F`, Liquid Glass 3.0 comme matière (fini le duo mat/chrome), interaction directe (la carte est le bouton), courtside refondu essence intouchable ; lois 2/4/5 réécrites. |
| **nuit 6-7 juil. 2026** | **Boucle de nuit autonome — 6 patchs roadmap livrés, 4 revues adversariales soldées (253 → 303/303, 47 suites)** : 2.2.b (consentement mineurs tracé + DM adulte↔mineur gatés AU POINT D'ENVOI, disponibilité joueur, TelemetryDeck 2.14.1 [1re dépendance SPM, épinglée, no-op DEMO], MetricKit) · 2.3.2 (match éclair + composition persistante validée — promotion MatchCalendrier RETIRÉE en revue, modèle dormant) · 2.3.1 complet (duplication « Continuer » + demi-terrain TypeTerrain.demiTerrain avec formations REMAPPÉES) · phase 0 SportPack (`Equipe.sportID`) · 2.6.2 (PDF plan de pratique régénéré à chaque partage) · 2.3 code (LienInvitation stricte + QR + « Inviter l'équipe » projetable [athlètes seulement] + jonction pré-remplie — revue sécurité : révocation Public DB rendue OPÉRANTE [fetch-puis-modifier], confirmation anti-phishing « Rejoindre « X » ? », rejeu du lien scanné avant login) · **2.4 Mat Nuit vague 1 noyau** (tokens MatNuit + CONTRAT de contraste WCAG exécutable [MatNuitTests], verre sombre 3.0 corps-sans-signatures, nuit par défaut [UN seul preferredColorScheme — toggle lune/soleil supprimé], PaletteMat remappée tons neutres, PencilKit overrideUserInterfaceStyle=.light [fidélité des dessins existants], courtside préservé via env modeBordDeTerrain). Glissées : 2.5a (fenêtre close), merge démo (permission requise). Suivis : vague 1bis Mat, 4 publierX à durcir, sync miroir Public DB. |
| **2.2.a** (juil. 2026) | **Patch roadmap 2.2.a — undo par étape + State Restoration match live** (commit `7cd6594`) : piles undo/redo du terrain PAR ÉTAPE (clé UUID stable — naviguer entre les étapes ne détruit plus l'historique ; reset au chargement de document, purge à la suppression d'étape) ; nouveau `Helpers/MatchLiveRestauration.swift` (marqueur UserDefaults expirable 6 h — posé/effacé par `MatchLiveSplitView`, effacé aussi à la finalisation), resélection auto du match dans `MatchsView`, alerte « Reprendre le match en direct ? » dans `MatchDetailView` (gardée par `!statsEntrees`), `MatchLiveViewModel.restaurerSetActuel()` (reprend au set le plus avancé — PointMatch max + SetScore max — au lieu du set 1). **Tests : 270/270** (+17), build 0/0 Xcode 26.6. **Revue multi-dimensions post-patch (18 agents, vérification adversariale)** : 8 trouvailles corrigées (commit `431a5e3`) dont HI-001 — la reprise live contournait le gate `peutModifier` ET `DashboardMatchLiveView.lectureSeule` était déclarée sans être appliquée (trou préexistant corrigé : rotation/subs/temps morts désormais `.disabled(lectureSeule)`) ; `restaurerSetActuel` en fetch borné (fetchLimit 1) ; budget global de 60 snapshots undo (`maxSnapshotsTotal`, l'étape active garde ses 15) ; constante `nombreMaxDeSets`. |

<!-- code-review-graph MCP tools -->| **pivot coach-first** (août 2026) | **Pivot fondateur 2026-08-26 : app GRATUITE + coach-only** (décisions D1-D6 actées 2026-08-29 — voir `docs/Pivot_CoachFirst_Plan.md` + `docs/Journal_Pivot_CoachFirst.md`). Branche `pivot/coach-first` (sur la boucle de nuit, merge intégral validé par revue diff-par-diff des 25 commits). **Chantier A** : suppression COMPLÈTE du paywall StoreKit (~2 100 l. — StoreKitService/AbonnementService/PaywallViewModel/6 vues/FeatureGating/TextesPaywall/IdentifiantsIAP/.storekit/framework ; `Abonnement` @Model + `Equipe.tierAbonnementRaw` restent au schéma ; `migrerAssistantsVersNouveauRole` extraite vers `Services/MigrationRoles.swift`) + retrait de la MESSAGERIE (D1 — MessagerieView/PolitiqueMessagerie/dock Messages ; `MessageEquipe` @Model conservé). **Chantier B** : les athlètes redeviennent des DONNÉES (plus aucun compte) — MembreFactory sans `joueur:` (assistants seuls), NouveauJoueurView = formulaire JoueurEquipe pur, wizard joueurs sans identifiants, `roleJonctionAutorise` → `.assistantCoach` SEUL, MonProfilAthleteView/masquerPratiquesAthletes/branches `.etudiant` supprimées, muscu saisie AU NOM d'un joueur (sélecteur D2), PermissionsRole SUPPRIMÉ + StaffPermissions/GestionStaffView hors UI + `estCoach` supprimé (D6 : assistant = head coach, mêmes droits ; gardes → « session valide »), cascade d'équipe complétée (PhaseSaison/CredentialAthlete/Utilisateur membres/Presence-Evaluation-TestPhysique par joueurID), fin des miroirs Utilisateur (nouveau champ `JoueurEquipe.poidsKg`), code mort purgé (EvaluationView, SaisieStatsMatchView, ModifierUtilisateurView, publierModificationsEquipe…). **Chantier C** : scouting → Matchs (sidebar « Préparation »), toolbar match 7 chips → 3 groupes (Préparer · En direct · Après), Heatmap/Rotations hors bottomBar Matchs, Calendrier au Dock, Formations nommées en sidebar, Présences dans l'écran d'exercices, Exports au hub. **Chantier D vague 1** : BoutonRetourAccueil partagé, CONFIRMATION sur suppression de match, sidebars .sidebar+searchable, icône « + » unique, création muscu en Form, FiltresStats supprimé. **Tests : 276/276** (43 suites — 3 suites paywall + 6 tests DM supprimés, MultiUtilisateur/MembreFactory/RejoindreEquipe refondus coach/assistant + garde « jonction .etudiant REJETÉE »), build 0/0. **Chantier E (parité de sync assistant, sept. 2026 — LIVRÉ E1-E4)** : miroir Public DB élargi et BIDIRECTIONNEL entre coachs — E1 fetch-puis-modifier généralisé aux 5 `publierX` + mappings extraits en fonctions pures (`champsPublicsX`) + disponibilité/attestation sur `JoueurPartage` ; E2 contenus de préparation (`ExercicePartage` avec dessins [binaires ≤ 500 Ko inline, sinon CKAsset ; plafond 15 Mo import], `StrategiePartagee`, `ScoutingPartage` [**`joueursData` JAMAIS publié** — PII adverses], `BibliothequePartagee` [record par item×équipe, `estFavori` local]) + `dateModification` additifs (Exercice/ExerciceBibliotheque/ScoutingReport/StatsMatch) + bumps d'édition/archivage (l'archivage se propage) ; E3 analyse (`StatsMatchPartage`, `PointMatchPartage` immuables par LOTS de 400 [.allKeys] + purge des fantômes à la SORTIE du live [D6 : le sweep saute stats/points si mode match actif], `FormationPartagee` dédup par clé fonctionnelle, `statsEntrees` au miroir séance) ; E4 écriture assistant (`planSync(role:)` — tous les coachs importent PUIS publient, LWW par `dateModification` STRICT [égalité = no-op → anti-boucle], baseline `derniereSyncDate` post-import initial). **310/310 tests (47 suites)**, build 0/0. ⚠️ Action Dashboard CloudKit avant prod : champs QUERYABLE des nouveaux types (`codeEquipe` partout, `seanceID`+`horodatage` sur PointMatchPartage). **Restent** : D vague 1bis (Fermer/empty states/kit stats/paddings), rebase `suivis/pr6`, refresh CLAUDE.md complet, PR différée (GitHub indisponible). ⚠️ Sections plus haut mentionnant paywall/messagerie/comptes athlètes = PÉRIMÉES jusqu'au refresh. |

## MCP Tools: code-review-graph

**IMPORTANT: This project has a knowledge graph. ALWAYS use the
code-review-graph MCP tools BEFORE using Grep/Glob/Read to explore
the codebase.** The graph is faster, cheaper (fewer tokens), and gives
you structural context (callers, dependents, test coverage) that file
scanning cannot.

### When to use graph tools FIRST

- **Exploring code**: `semantic_search_nodes` or `query_graph` instead of Grep
- **Understanding impact**: `get_impact_radius` instead of manually tracing imports
- **Code review**: `detect_changes` + `get_review_context` instead of reading entire files
- **Finding relationships**: `query_graph` with callers_of/callees_of/imports_of/tests_for
- **Architecture questions**: `get_architecture_overview` + `list_communities`

Fall back to Grep/Glob/Read **only** when the graph doesn't cover what you need.

### Key Tools

| Tool | Use when |
|------|----------|
| `detect_changes` | Reviewing code changes — gives risk-scored analysis |
| `get_review_context` | Need source snippets for review — token-efficient |
| `get_impact_radius` | Understanding blast radius of a change |
| `get_affected_flows` | Finding which execution paths are impacted |
| `query_graph` | Tracing callers, callees, imports, tests, dependencies |
| `semantic_search_nodes` | Finding functions/classes by name or keyword |
| `get_architecture_overview` | Understanding high-level codebase structure |
| `refactor_tool` | Planning renames, finding dead code |

### Workflow

1. The graph auto-updates on file changes (via hooks).
2. Use `detect_changes` for code review.
3. Use `get_affected_flows` to understand impact.
4. Use `query_graph` pattern="tests_for" to check coverage.
