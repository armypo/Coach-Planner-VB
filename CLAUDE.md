# Playco — Contexte Claude Code

## Résumé du projet
Application iOS/iPadOS de coaching volleyball en **Swift/SwiftUI**, ciblant iPad Air avec Apple Pencil 2e gen. **5 sections principales** : Séances (pratiques/exercices), Matchs (résultats/box score/stats), Stratégies (systèmes de jeu), Équipe (joueurs/statistiques/tableau de bord), Entraînement (musculation/charges). Terrain de volleyball dessinable (PencilKit + éléments vectoriels overlay). Bibliothèque d'exercices. Calendrier unifié. Exercices multi-étapes. Formations personnalisables. Système d'authentification multi-rôles (coach/athlète). Multi-équipes. Messagerie inter-équipe. Sync CloudKit.

## Stack technique
- **Swift 5.9+ / SwiftUI** — NavigationSplitView (sidebar + detail avec NavigationStack)
- **SwiftData + CloudKit** — persistance locale + sync inter-appareil (ModelConfiguration cloudKitDatabase: .automatic)
- **PencilKit** — PKCanvasView via UIViewRepresentable pour dessin libre
- **Canvas API** — rendu du terrain de volleyball (indoor parquet + beach sable)
- **CryptoKit** — SHA256 hash des mots de passe avec sel
- **EventKit** — sync calendrier Apple (CalendarSyncService)
- **Combine** — auto-save debounce 3s (TerrainEditeurViewModel)
- **Aucune dépendance externe**

## Architecture de navigation

### Flux d'entrée
```
PlaycoApp
├── SplashScreenView → animation d'entrée
├── ChoixInitialView → "Créer mon équipe" OU "Rejoindre une équipe"
│   ├── ConfigurationView (wizard 6 étapes) → crée coach + équipe
│   └── RejoindreEquipeView → connexion avec code équipe + identifiants
├── LoginView → connexion (identifiant + mot de passe)
│   └── Bouton "Créer ou rejoindre une équipe" → retour ChoixInitialView
├── SelectionEquipeView → si multi-équipes
└── ContentView (routeur principal)
```

### Écran d'accueil → 5 sections
```
ContentView (routeur)
├── AccueilView (5 cartes : Séances / Matchs / Stratégies / Équipe / Entraînement)
├── PratiquesView → NavigationSplitView (séances pratiques + exercices)
├── MatchsView → NavigationSplitView (matchs + terrain/notes/stats)
├── StrategiesView → NavigationSplitView (stratégies collectives)
├── EquipeView / MonProfilAthleteView → NavigationSplitView (joueurs + tableau de bord)
└── EntrainementView → NavigationSplitView (musculation + programmes)
```
+ **DockBarView** flottant en bas (Messages + Profil)

- `SectionApp` enum : `.pratiques`, `.matchs`, `.strategies`, `.equipe`, `.entrainement`
- Transitions spring animées entre accueil et sections (.spring response: 0.4, dampingFraction: 0.85)
- Chaque section a un bouton « ← Accueil » (topBarLeading)

## Architecture des fichiers

### Point d'entrée
| Fichier | Description |
|---------|-------------|
| `PlaycoApp.swift` | @main, ModelContainer CloudKit (23 modèles), fallback local + fallback mémoire, écrans : splash → choix initial → config/rejoindre → login → sélection équipe → app |

### Modèles (`Models/`) — 23 @Model
| Fichier | Description |
|---------|-------------|
| `Seance.swift` | @Model : id, nom, date, exercices (cascade, **optionnel**), estArchivee, typeSeanceRaw (pratique/match), adversaire, lieu, scoreEquipe, scoreAdversaire, notesMatch, statsEntrees, codeEquipe, pagesMatch |
| `Exercice.swift` | @Model : id, nom, notes, dessinData, elementsData, ordre, duree, etapesData, typeTerrain, seance, estArchive |
| `ExerciceBibliotheque.swift` | @Model : id, nom, categorie, descriptionExo, notes, dessinData, elementsData, estPredefini, estFavori, duree, etapesData, notesCoach, typeTerrain, dateCreation, codeCoach |
| `ElementTerrain.swift` | Codable struct : types joueur/ballon/fleche/trajectoire/rotation, coordonnées normalisées 0-1, Bézier, couleur RGB. **+ TypeTerrain** enum. **+ EtapeExercice** struct |
| `JoueurEquipe.swift` | @Model : stats volleyball NCAA/FIVB (kills, aces, blocs, réception, passes, manchettes), identifiant, motDePasseHash, sel, codeEquipe, utilisateurID. **+ PosteJoueur** enum |
| `StrategieCollective.swift` | @Model : id, nom, categorieRaw, description, notes, dessinData, elementsData, etapesData, typeTerrain, estArchivee, codeEquipe. **+ CategorieStrategie** enum |
| `FormationTypes.swift` | FormationMode enum, FormationType enum (indoor 5-1/4-2/6-2, beach) |
| `FormationPersonnalisee.swift` | @Model : formationType, rotation, mode, positionsJSON, codeEquipe |
| `Utilisateur.swift` | @Model : identifiant, motDePasseHash, sel, prenom, nom, roleRaw (etudiant/coach/admin), codeEcole, codeInvitation, photoData, stats volleyball, données physiques, joueurEquipeID. **+ genererIdentifiantUnique()** |
| `StatsMatch.swift` | @Model : seanceID, joueurID, codeEquipe, kills, aces, blocs, réception, passes, manchettes, setsJoues |
| `Presence.swift` | @Model : joueurID, seanceID, estPresent, dateMarquee |
| `Evaluation.swift` | @Model : joueurID, seanceID, note, commentaire, dateEvaluation |
| `Etablissement.swift` | @Model : nom, type, ville, province, logo. **Relations inverses** : profils, equipes |
| `ProfilCoach.swift` | @Model : prenom, nom, courriel, telephone, sportRaw, roleRaw, photo, configurationCompletee, etablissement, masquerPratiquesAthletes |
| `Equipe.swift` | @Model : nom, categorieRaw, divisionRaw, saison, couleurs hex, codeEquipe, dateFinSaison, etablissement. **Relations inverses** : assistants, creneaux, matchsCalendrier |
| `AssistantCoach.swift` | @Model : prenom, nom, courriel, roleAssistant (assistant/préparateur/analyste/physio), identifiant, motDePasseHash, sel, codeEquipe |
| `ProgrammeMuscu.swift` | @Model : nom, description, exercices, joueursAssignes, estArchive, codeEquipe. **+ ExerciceMuscu** @Model |
| `SeanceMuscu.swift` | @Model : joueurID, programmeID, exercices JSON, estTerminee, codeEquipe |
| `TestPhysique.swift` | @Model : joueurID, typeTest, valeur, date |
| `CreneauRecurrent.swift` | @Model : jourSemaine, heureDebut, dureeMinutes, lieu, equipe |
| `MatchCalendrier.swift` | @Model : date, adversaire, lieu, estDomicile, equipe |
| `MessageEquipe.swift` | @Model : contenu, dateEnvoi, expediteurID, expediteurNom, expediteurRoleRaw, codeEquipe, lecteurIDs, estConversationPrivee, destinataireID |
| `PointMatch.swift` | @Model : id, seanceID, set, scoreEquipeAuMoment, scoreAdversaireAuMoment, joueurID, typeActionRaw, rotationAuMoment, codeEquipe, horodatage. **+ TypeActionPoint** enum (kill, ace, bloc, erreurAdv, erreurNous, etc.), computed estPointPourNous |
| `ScoutingReport.swift` | @Model : adversaire, date, systemeDeJeu, styleDeJeu, joueurs adverses (JSON), forces, faiblesses, tendances, stratégies recommandées, notes, codeEquipe, estArchive |
| `ObjectifJoueur.swift` | @Model : id, joueurID, codeEquipe, titre, categorieRaw, cible, unite, dateCreation, estAtteint, notes. **+ CategorieObjectif** enum (attaque/service/bloc/réception/jeu/physique) |
| `EvenementSync.swift` | Struct Codable (PAS @Model) : id, date, type (import/export/setup/erreur/connexion/pause/reprise), message, estErreur. **+ JournalSyncStorage** (UserDefaults buffer circulaire 50 entrées) |

### Services (`Services/`)
| Fichier | Description |
|---------|-------------|
| `AuthService.swift` | @Observable : connexion(identifiant + motDePasse), creerCompte(), deconnexion(), restaurerSession(), hashage SHA256 avec sel, verrouillage 5 tentatives, creerAdminParDefaut() |
| `CalendarSyncService.swift` | Sync EventKit : ajouterAuCalendrier(), demanderPermission() |
| `CloudKitSyncService.swift` | @Observable : statut sync (inactif/sync/syncPausee/erreur), vérification compte iCloud, NWPathMonitor connectivité réseau, journal sync (EvenementSync buffer 50 UserDefaults), mode match (pause/reprise sync), compteur modifications, indicateur visuel SyncIndicateurView |
| `PDFExportService.swift` | Enum statique : genererPDFMatch(seance:joueurs:statsMatch:) — résumé PDF match (score par set, box score, stats), format Letter UIGraphicsPDFRenderer |
| `CSVExportService.swift` | Enum statique : exporterStatsJoueurs(), exporterStatsParMatch(), exporterResultatsMatchs() — CSV séparateur point-virgule, compatible Excel/Numbers |
### Helpers (`Helpers/`)
| Fichier | Description |
|---------|-------------|
| `Extensions.swift` | Color(hex:), DateFormattersCache (.formatFrancais, .formatCourt, .formatHeure, .formatJourSemaine, .formatMoisAnnee, .formatYMD), JSONCoderCache |
| `ThemeCouleurRole.swift` | **Design System Liquid Glass v2** : PaletteMat (orange/bleu/vert/violet), GlassCard (highlight gradient + double shadow + teinte optionnelle), GlassSection (gradient + shadow), GlassChip, GlassButtonStyle (scale+opacity spring), couleurRole environment key |
| `FiltreEquipe.swift` | Protocole `FiltreParEquipe` + `.filtreEquipe()` — 12+ conformances (Seance, JoueurEquipe, StrategieCollective, PointMatch, etc.) |
| `EquipeContext.swift` | EnvironmentKey `codeEquipeActif` pour filtrage données par équipe |
| `PermissionsRole.swift` | `PermissionModifier` + `.siAutorise()` — masque UI selon le rôle |
| `ValidationService.swift` | Unicité numéro joueur + formation personnalisée |
| `BibliothequeDefauts.swift` | CategorieBibliotheque (8 catégories), peuplerSiVide() |
| `DiagrammesBibliotheque.swift` | Diagrammes pré-dessinés pour exercices par défaut |
| `LiquidGlassKit.swift` | Constantes Design System centralisées : rayons (12/16/22/28pt), espacement (système 4pt : XS 4/SM 8/MD 16/LG 24/XL 32/XXL 40), animations spring (défaut/rebond/douce), bordures glass, ombres (subtile/douce/moyenne), opacités, constantes courtside (bouton 60/grille 120/score 72/police 18) |
| `ModesBordTerrainContext.swift` | EnvironmentKey `modeBordDeTerrain` + `themeHautContraste` (même pattern que EquipeContext.swift) |
| `ExercicesMusculationDefauts.swift` | Exercices musculation par défaut |

### ViewModels (`ViewModels/`)
| Fichier | Description |
|---------|-------------|
| `TerrainEditeurViewModel.swift` | @Observable : undo/redo (pile 15), formations, étapes, auto-save debounce 3s Combine, deinit cleanup |

### Vues principales (`Views/`)
| Fichier | Description |
|---------|-------------|
| `ContentView.swift` | Routeur : SectionApp enum, DockBarView overlay, transitions spring, environment couleurRole + codeEquipeActif |
| `AccueilView.swift` | 5 cartes tinted glass (GlassButtonStyle), double RadialGradient fond, @State cachés + .filtreEquipe(), icons .symbolRenderingMode(.hierarchical), typo .rounded |
| `PratiquesView.swift` | NavigationSplitView séances pratiques uniquement (matchs séparés) |
| `SplashScreenView.swift` | Animation entrée avec gradient + ProgressView |

### Authentification (`Views/Auth/`)
| Fichier | Description |
|---------|-------------|
| `ChoixInitialView.swift` | Premier lancement : "Créer mon équipe" ou "Rejoindre une équipe" |
| `LoginView.swift` | Connexion identifiant + mot de passe (pas de code école), sélecteur Coach/Athlète, bouton vers ChoixInitialView |
| `RejoindreEquipeView.swift` | Connexion avec **code équipe** + identifiant + mot de passe, validation appartenance équipe |
| `SelectionEquipeView.swift` | Sélection d'équipe si accès multi-équipes, callback onSelection(Equipe) |

### Configuration / Onboarding (`Views/Configuration/`)
| Fichier | Description |
|---------|-------------|
| `ConfigurationView.swift` | Wizard 6 étapes : établissement → sport → profil coach → équipe → membres → calendrier. Finalisation : persist SwiftData + génère séances récurrentes + auto-login |
| `ConfigEtablissementView.swift` | Étape 1 : nom, type, ville, province |
| `ConfigSportView.swift` | Étape 2 : indoor / beach / les deux |
| `ConfigProfilCoachView.swift` | Étape 3 : prénom, nom, courriel, rôle, identifiant + mot de passe |
| `ConfigEquipeView.swift` | Étape 4 : nom, catégorie, division, saison, couleurs, date fin saison |
| `ConfigMembresView.swift` | Étape 5 : assistants (rôle sélectionnable) + joueurs avec identifiants auto-générés |
| `ConfigCalendrierView.swift` | Étape 6 (optionnelle) : créneaux récurrents + matchs |
| `ConfigHelpers.swift` | Composants réutilisables : titreEtape(), champTexte() |

### Matchs (`Views/Matchs/`)
| Fichier | Description |
|---------|-------------|
| `MatchsView.swift` | Section dédiée : sidebar (à venir / résultats), NouvelMatchSheet, suppression cascade (reverse stats joueurs + delete StatsMatch), tint rouge |
| `ScoutingReportView.swift` | Éditeur scouting report : joueurs adverses, forces/faiblesses, tendances, stratégies recommandées, notes |
| `ScoutingReportListView.swift` | Liste des scouting reports par équipe, création/suppression |
| `HeatmapTerrainView.swift` | Heatmap zones 1-6 par catégorie (attaque/réception/service/bloc), vue par joueur ou équipe, barres de distribution |
| `StatsParRotationView.swift` | Analyse performances par rotation 1-6 (PointMatch), graphiques efficacité + points pour/contre, meilleure/pire rotation, tableau détaillé, filtre par match |
| `CompositionMatchView.swift` | Sélection du 6 de départ + rotation, joueurs groupés par poste, sélection max 6 |
| `SetsScoreView.swift` | Saisie score par set (1 à 5 sets), ajout/suppression sets, struct SetScore |
| `StatsLiveView.swift` | Saisie point-par-point temps réel, PointMatch @Model, score/rotation auto, undo dernier point |
| `ExportMatchPDFView.swift` | Aperçu + partage PDF résumé match via PDFExportService, ShareLink |
| `SelecteurZoneView.swift` | Mini demi-terrain 6 zones tapables pour assigner une zone à un point (optionnel) |
| `MatchLiveSplitView.swift` | Mode split-screen iPad : Dashboard live (gauche) + Stats live saisie (droite), TabView iPhone, mode match auto (pause/reprise sync), capsule SYNC PAUSÉE |
| `PaveNumeriqueRapideView.swift` | Pavé numérique courtside : grille joueurs (#numéro) → 4 actions rapides (Kill/Ace/Bloc/Erreur), overlay flottant, toggle "#" |
| `RotationLiveView.swift` | Terrain visuel positions 1-6 avec joueurs, boutons rotation R1-R6, historique rotations par set |

### Séances (`Views/Seances/`)
| Fichier | Description |
|---------|-------------|
| `ListeSeancesView.swift` | Pratiques uniquement (matchs filtrés), .filtreEquipe() |
| `NouvelleSeanceView.swift` | Sheet création séance (nom + date) |
| `CalendrierView.swift` | Calendrier mensuel unifié (séances + matchs), sync Apple Calendar |
| `MatchDetailView.swift` | Terrain vierge + notes + pages pour matchs |
| `SaisieStatsMatchView.swift` | Box score : saisie stats par joueur, sync cumulatif |
| `PresencesView.swift` | Gestion présences par séance |
| `EvaluationView.swift` | Évaluation joueurs par séance |

### Équipe (`Views/Equipe/`)
| Fichier | Description |
|---------|-------------|
| `EquipeView.swift` | NavigationSplitView, @State cachés + .filtreEquipe() + .onChange(of: codeEquipeActif), tint vert |
| `NouveauJoueurView.swift` | Création joueur + Utilisateur lié, identifiant auto-généré (prenom.nom + suffixe si doublon) |
| `JoueurDetailView.swift` | Stats NCAA/FIVB par catégorie, présences, suivi muscu, tests physiques |
| `TableauBordView.swift` | Dashboard : StatsEquipeCache (reduce cachés en @State), GlassCard sur chiffreCle, .contentTransition(.numericText()), matchs + stats globales |
| `SuiviMusculationView.swift` | Graphiques évolution charges |
| `TestsPhysiquesView.swift` | Tests physiques + graphiques évolution |
| `MonProfilAthleteView.swift` | Vue athlète : stats personnelles, équipes |
| `EvolutionJoueurView.swift` | Graphiques Swift Charts : évolution stats par catégorie (attaque/service/bloc/réception/jeu), tendance hausse/baisse/stable, historique détaillé |
| `ComparaisonView.swift` | Comparaison joueur vs moyenne équipe, barres de progression, stats par catégorie |
| `AnalyticsSaisonView.swift` | Analytics saison : résultats cumulatifs V/D, efficacité attaque, séries, classements, Swift Charts |
| `ObjectifsJoueurView.swift` | Objectifs individuels par joueur : progression automatique, suggestions, NouvelObjectifView sheet |
| `ExportStatsView.swift` | Export CSV stats (joueurs/matchs/résultats), ShareLink, CSVFile Transferable |
| `PalmaresRecordsView.swift` | Palmarès et records saison : records individuels (kills, aces, blocs, hitting %, points, passes par match) et records d'équipe (points, aces, blocs, écart score, hitting % par match) |

### Profil & Aide (`Views/Profil/`)
| Fichier | Description |
|---------|-------------|
| `ProfilView.swift` | Paramètres coach : code équipe, visibilité, organisation, équipes, iCloud, tutoriel, déconnexion |
| `TutorielView.swift` | Tutoriel paginé 12 pages couvrant toutes les fonctionnalités : accueil, séances, matchs, terrain, stratégies, équipe, analytics, entraînement, messagerie, calendrier, export. @AppStorage pour premier lancement |
| `JournalSyncView.swift` | Journal de synchronisation : liste événements sync (import/export/erreur/pause/reprise), couleurs par type, bouton effacer |

### Profil & Messages (`Views/Profil/`, `Views/Messages/`, `Views/DockBar/`)
| Fichier | Description |
|---------|-------------|
| `ProfilView.swift` | Paramètres coach : code équipe, modifier organisation, créer nouvelle équipe, lier établissement, déconnexion. Notifications `.changerEquipe` et `.allerChoixInitial` |
| `AjoutUtilisateurView.swift` | Ajout utilisateur avec identifiant auto-généré |
| `ModifierUtilisateurView.swift` | Modification info élève par le coach : prénom, nom, identifiant, mot de passe, données physiques (taille pieds/pouces, poids, allonge, saut), numéro, poste, date naissance, stats, PhotosPicker |
| `AvatarEditableView.swift` | Avatar réutilisable : photo ou initiales, PhotosPicker si éditable, cercle coloré par rôle |
| `MessagerieView.swift` | Messagerie inter-équipe : conversations d'équipe + privées, badges non-lus |
| `DockBarView.swift` | Dock flottant : Messages + Profil, badges, spring animation (dampingFraction: 0.7) |

### Stratégies (`Views/Strategies/`)
| Fichier | Description |
|---------|-------------|
| `StrategiesView.swift` | Section stratégies : NavigationSplitView, liste par catégorie, création/suppression, tint bleu |
| `StrategieDetailView.swift` | Détail stratégie : terrain éditable + notes, chargement formations et joueurs |
| `FormationsView.swift` | Gestion formations personnalisées : sélection type (5-1/4-2/6-2/beach), rotation, mode (base/attaque/défense), FormationPersonnalisee CRUD |

### Bibliothèque (`Views/Bibliotheque/`)
| Fichier | Description |
|---------|-------------|
| `BibliothequeView.swift` | Bibliothèque d'exercices : recherche, filtre par catégorie, favoris, mode import vers séance, création/édition/suppression |
| `BibliothequeDetailView.swift` | Détail exercice bibliothèque : terrain éditable + notes + notes coach, PencilKit |

### Entraînement / Musculation (`Views/Entrainement/`)
| Fichier | Description |
|---------|-------------|
| `EntrainementView.swift` | Section musculation : programmes, séances live, .filtreEquipe() |
| `SeanceLiveView.swift` | Mode live musculation : chrono, exercices, séries, repos |
| `ProgrammeDetailView.swift` | Détail programme : exercices, joueurs assignés |
| `BibliothequeMusculationView.swift` | Bibliothèque exercices musculation : recherche, filtre par CategorieMuscu, CRUD exercices, permissions rôle |

### Terrain & dessin (`Views/Terrain/`)
| Fichier | Description |
|---------|-------------|
| `TerrainVolleyView.swift` | Canvas terrain 18m×9m (ratio 2:1), indoor parquet + beach sable |
| `CanvasDessinView.swift` | PKCanvasView + ModeDessin enum + CanvasController (weak var) |
| `BarreOutilsDessin.swift` | Toolbar complète : outils, formations, roster, couleurs, undo/redo |
| `OverlayDessinView.swift` | Overlay : drag, suppression, Bézier, verrouillage |
| `TerrainEditeurView.swift` | Composant partagé : terrain + canvas + overlay + toolbar + étapes + autosave |
| `TerrainMiniatureView.swift` | Miniature terrain pour listes |

## Conventions & patterns critiques

### Authentification
- **Connexion coach** : identifiant (prenom.nom) + mot de passe (LoginView)
- **Rejoindre équipe (athlète)** : code équipe + identifiant + mot de passe (RejoindreEquipeView) — valide que le code équipe existe ET que l'utilisateur appartient à cette équipe
- **Identifiant auto-généré** : `Utilisateur.genererIdentifiantUnique(prenom:nom:context:)` — `prenom.nom` sans accents, minuscules, suffixe numérique si doublon (prenom.nom2, prenom.nom3)
- **Hash** : SHA256 avec sel (CryptoKit), migration auto des anciens hash sans sel
- **Verrouillage** : 5 tentatives → blocage 5 minutes
- **Rôles** : `.admin` (coach créateur), `.coach` (assistant), `.etudiant` (athlète)
- **Permissions** : `PermissionsRole.swift` — `.siAutorise()` masque les éléments selon le rôle

### Multi-équipes & scoping données
- **`codeEquipeActif`** : EnvironmentKey injecté par ContentView, utilisé par toutes les vues
- **`FiltreParEquipe`** : protocole + `.filtreEquipe()` — remplace TOUT filtre manuel `$0.codeEquipe == codeEquipeActif || $0.codeEquipe.isEmpty`
- **Changement d'équipe** : Notification `.changerEquipe` → ContentView reset → SelectionEquipeView
- **Navigation vers config** : Notification `.allerChoixInitial` → PlaycoApp → ChoixInitialView

### Design System Liquid Glass v2
- **PaletteMat** : orange `#E8734A`, bleu `#4A8AF4`, vert `#34C785`, violet `#9B7AE8`
- **LiquidGlassKit** : constantes centralisées — rayons (petit 12/moyen 16/grand 22/XL 28), espacement système 4pt (XS 4→XXL 40), 3 springs (défaut 0.35/0.85, rebond 0.25/0.7, douce 0.45/0.9), ombres (subtile/douce/moyenne), opacités
- **GlassCard** : ultraThinMaterial + highlight gradient (blanc 0.12→transparent topLeading→bottomTrailing) + double shadow (tight 3px + soft 12px) + teinte optionnelle + bordure blanc 0.25
- **GlassSection** : thinMaterial + gradient subtil + shadow légère
- **GlassButtonStyle** : scale 0.97 + opacity 0.85 au press avec spring (response: 0.25, dampingFraction: 0.7)
- **Transitions** : `.spring(response: 0.4, dampingFraction: 0.85)` partout (pas de .easeInOut)
- **TOUJOURS utiliser `LiquidGlassKit`** pour les constantes (rayons, espacements, animations) — NE PAS écrire de magic numbers

### Performance — Caching
- **Computed properties lourdes** → `@State` + `.onAppear` + `.onChange(of:)` (AccueilView, EquipeView, TableauBordView)
- **StatsEquipeCache** : struct avec tous les reduce pré-calculés, mis à jour dans `.onChange(of: joueurs)`
- **`.contentTransition(.numericText())`** sur tous les compteurs/stats pour animation fluide
- **`.filtreEquipe()`** : une seule fois, résultat caché en @State

### DateFormatters & JSONCoderCache
- **NE JAMAIS créer un DateFormatter dans un computed property ou body** — utiliser `DateFormattersCache`
- **NE JAMAIS créer JSONDecoder()/JSONEncoder()** — utiliser `JSONCoderCache.decoder`/`.encoder`

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

### Système de matchs
- **Section dédiée MatchsView** — séparée des séances
- **Score** : scoreEquipe + scoreAdversaire → `.resultat` computed (victoire/défaite/nul)
- **Score par set** : SetsScoreView — 1 à 5 sets, struct SetScore, sets stockés en JSON sur Seance
- **Composition** : CompositionMatchView — 6 de départ par poste + rotation
- **Stats live** : StatsLiveView — saisie point-par-point temps réel, PointMatch @Model, rotation auto
- **Box Score** : SaisieStatsMatchView — stats par joueur sync avec cumulatif JoueurEquipe
- **Export PDF** : ExportMatchPDFView + PDFExportService — résumé match + box score en PDF partageable
- **Suppression cascade** : reverse stats joueurs + delete StatsMatch + delete PointMatch + soft delete match
- **Pages terrain** : pagesMatch JSON pour notes/diagrammes multi-pages
- **Scouting** : ScoutingReport + plan de match adversaire
- **Heatmap** : HeatmapTerrainView zones 1-6 par catégorie

### Musculation (Section Entraînement)
- **ProgrammeMuscu** : exercices + joueurs assignés (JSON)
- **SeanceMuscu** : joueur exécute un programme, enregistre charges/séries
- **Suivi** : graphiques évolution charges + tests physiques par joueur

## Commande build
```bash
cd "/Users/armypo/Documents/Coach Planner VB" && xcodebuild -scheme "Playco" -destination 'platform=iOS Simulator,name=iPad Air 13-inch (M3)' build
```

## État actuel — v1.8.0
- ✅ Build réussi — **0 erreur, 0 warning**
- ✅ **TestFlight fonctionnel** — app validée et prête à être distribuée
- ✅ CloudKit activé (sync inter-appareil) + indicateur hors-ligne (NWPathMonitor)
- ✅ **CloudKit compatible** — tous les @Model avec defaults, relations optionnelles + inverses, Seance.exercices optionnel
- ✅ **5 sections** : Séances (orange), Matchs (rouge), Stratégies (bleu), Équipe (vert), Entraînement (violet)
- ✅ **Authentification** : connexion identifiant + mot de passe, rôles coach/athlète/admin, verrouillage 5 tentatives
- ✅ **Rejoindre équipe** : code équipe + identifiant + mot de passe, validation appartenance
- ✅ **Onboarding wizard 6 étapes** : établissement → sport → profil → équipe → membres → calendrier (exemples Cégep Garneau)
- ✅ **Multi-équipes** : sélection équipe, données scopées par codeEquipe, changement d'équipe
- ✅ **Section Matchs complète** : création, composition 6 départ, score par set (1-5), stats live point-par-point, box score, export PDF, scouting report, heatmap, suppression cascade
- ✅ **Stats live temps réel** : PointMatch @Model, saisie point-par-point, rotation auto, undo dernier point
- ✅ **Export PDF** : PDFExportService — résumé match + box score, ShareLink
- ✅ **Scouting Report** : plan de match intelligent, joueurs adverses, forces/faiblesses, tendances, stratégies recommandées
- ✅ **Heatmap terrain avancé** : zones 1-6 réelles (PointMatch.zone), sélection de zone optionnelle lors de la saisie live, filtres par match/set/joueur/catégorie, fallback distribution simulée si pas de données zone
- ✅ **Graphiques d'évolution** : Swift Charts par joueur, 5 catégories stats, tendance hausse/baisse/stable
- ✅ **Comparaison joueur** : ComparaisonView — joueur vs moyenne équipe par catégorie stats
- ✅ **Section Stratégies** : StrategiesView + StrategieDetailView + FormationsView (5-1/4-2/6-2/beach), terrain éditable
- ✅ **Bibliothèque exercices** : BibliothequeView + BibliothequeDetailView, catégories, favoris, import vers séance
- ✅ **Section Musculation** : programmes, séances live, suivi charges, tests physiques, bibliothèque exercices muscu
- ✅ **Messagerie** : inter-équipe + conversations privées, badges non-lus
- ✅ **Profil étendu** : ModifierUtilisateurView (édition joueur complète), AvatarEditableView (photo + initiales), données physiques pieds/pouces
- ✅ **Design Liquid Glass v2** : LiquidGlassKit constantes centralisées, GlassCard teinté, GlassButtonStyle spring, double gradient fond, .numericText()
- ✅ **Performance** : @State cachés, StatsEquipeCache, .filtreEquipe(), spring transitions, Logger (pas de print)
- ✅ **Terrain dessinable** : PencilKit + overlay, multi-étapes, verrouillage, formations, auto-save
- ✅ **Calendrier unifié** : séances + matchs + entraînement, sync Apple Calendar
- ✅ **DockBar** : Messages + Profil + indicateur sync, badges, spring animation
- ✅ **Empty states** : ContentUnavailableView natif sur toutes les listes vides
- ✅ **Haptics** : .sensoryFeedback sur les créations d'éléments
- ✅ **App Store** : PlaycoInfo.plist (privacy keys, CFBundleIconName, ITSAppUsesNonExemptEncryption), entitlements CloudKit (iCloud.Origo.Playco), pas de fatalError
- ✅ **Analytics saison** : AnalyticsSaisonView — résultats cumulatifs, efficacité attaque par match, séries V/D, classements performances, Swift Charts, filtrage par phase de saison
- ✅ **Objectifs joueur** : ObjectifJoueur @Model — objectifs individuels par joueur avec suivi progression automatique, suggestions rapides, catégories stats
- ✅ **Mode Live split-screen** : MatchLiveSplitView — Dashboard + saisie stats côte à côte sur iPad, TabView sur iPhone
- ✅ **Export CSV** : CSVExportService — export stats joueurs/matchs/résultats en CSV, ShareLink, compatible Excel/Numbers
- ✅ **Stats par rotation** : StatsParRotationView — analyse efficacité par rotation 1-6, graphiques barres, meilleure/pire rotation, tableau détaillé
- ✅ **Palmarès & records** : PalmaresRecordsView — records individuels et d'équipe par match (kills, aces, blocs, hitting %, points, passes)
- ✅ **Mode présentation** : bouton "Présenter" accessible depuis MatchDetailView et StrategieDetailView, plein écran AirPlay
- ✅ **Tutoriel intégré** : TutorielView 12 pages paginées (TabView), affiché au premier lancement (@AppStorage), accessible depuis Paramètres → Voir le tutoriel
- ✅ **24 @Model SwiftData** : incluant PointMatch (avec zone) + ObjectifJoueur + PhaseSaison
- ✅ **Mode hors-ligne robuste** : journal de sync (EvenementSync, buffer 50 UserDefaults), mode match (pause sync auto pendant match live, toggle wifi.slash, capsule SYNC PAUSÉE), compteur modifications en attente branché sur enregistrerStat/substitution/TM/set
- ✅ **Mode bord de terrain** : interface courtside simplifiée (grands boutons 60pt, score 72pt, 6 stats essentielles), pavé numérique rapide (#→joueur→action), feedback haptique (impact/warning/success), mode lecture seule (StaffPermissions.peutGererStats), réglages ProfilView (@AppStorage)
- ✅ **Stats FIVB/NCAA complètes** : TypeActionRallye étendu (dig, tentativeAttaque, serviceEnJeu), hitting % amélioré, rotations historique par set, modification rotation manuelle (RotationLiveView)
- ✅ **Transitions portrait/landscape** : SwiftUI Environment sizeClass (plus de UIKit), spring animations sur changement d'orientation
- ✅ **Permissions granulaires** : StaffPermissions @Model (7 booleans), GestionStaffView, lecture seule en match live

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
| 1.4.0 | **TestFlight & CloudKit Fix** — Compatibilité CloudKit complète : defaults sur tous les attributs @Model (6 modèles), relations optionnelles (Seance.exercices → `[Exercice]?`), relations inverses (Equipe↔Etablissement, Equipe↔AssistantCoach/CreneauRecurrent/MatchCalendrier, Etablissement↔ProfilCoach), correction 19 références exercices optionnels (4 fichiers). StoreKit 2 retiré temporairement (AbonnementService, PaywallView, GestionAbonnementView supprimés). PlaycoInfo.plist à la racine (CFBundleIconName, ITSAppUsesNonExemptEncryption, privacy keys). AppIcon placeholder 1024×1024. RejoindreEquipeView : ajout champ code équipe + validation appartenance. Exemples configurateur : Cégep Garneau / Québec / Élans / Christopher Dionne. TestFlight validé et fonctionnel. |
| 1.5.0 | **Analytics, Objectifs, Split-screen & Export CSV** — Heatmap avancé : PointMatch.zone (1-6), SelecteurZoneView (mini-terrain tapable, sélection optionnelle), TypeActionPoint.categorieHeatmap, HeatmapEquipeView refactoré (données réelles PointMatch, filtres par match/set/joueur, fallback simulé). AnalyticsSaisonView (tendances saison : résultats cumulatifs V/D, efficacité attaque par match, séries, classements marqueurs/serveurs/bloqueurs, Swift Charts). ObjectifJoueur @Model (24e modèle) + ObjectifsJoueurView + NouvelObjectifView (objectifs individuels par joueur, progression automatique depuis stats, suggestions rapides, catégories, Gauge circulaire). MatchLiveSplitView (mode live split-screen : Dashboard + StatsLive côte à côte iPad, TabView iPhone, fullScreenCover). CSVExportService + ExportStatsView (export CSV stats joueurs/matchs/résultats, ShareLink, séparateur point-virgule compatible Excel/Numbers). |
| 1.6.0 | **Stats rotation, Palmarès, Phases saison & Mode présentation** — StatsParRotationView (analyse efficacité par rotation 1-6, graphiques barres efficacité + points pour/contre, meilleure/pire rotation, tableau détaillé, filtre par match, accessible depuis MatchsView bottomBar). PalmaresRecordsView (records individuels : plus de kills/aces/blocs/points/passes par match + meilleur hitting %; records d'équipe : plus de points/aces/blocs collectifs + meilleur hitting % équipe + plus grand écart, accessible depuis EquipeView sidebar). AnalyticsSaisonView : filtrage par PhaseSaison (toute la saison ou phase spécifique, appliqué à tous les graphiques et calculs). Mode présentation terrain : bouton "Présenter" ajouté dans MatchDetailView toolbar + StrategieDetailView toolbar, fullScreenCover PresentationTerrainView accessible en un tap. TutorielView : tutoriel paginé 12 pages couvrant toutes les fonctionnalités, TabView(.page), affiché automatiquement au premier lancement (@AppStorage "tutorielVu"), accessible depuis Paramètres → Aide → Voir le tutoriel, fond RadialGradient animé, indicateur dots colorés. |
| 1.7.0 | **Chantiers v1.7** — 8 chantiers : recherche globale (RechercheGlobaleView Spotlight-like), catégories exercices (CategorieExercice @Model), gestion suppression équipe (cascade manuelle 14 entités + confirmation nom), stats rallye (ActionRallye @Model, manchettes/passes/réceptions), permissions staff (StaffPermissions @Model 7 booleans, GestionStaffView), config match (ConfigMatch struct : subs max, TM, TTO, service), transitions portrait/landscape (SwiftUI sizeClass), stats FIVB complètes (dig/tentativeAttaque/serviceEnJeu, RotationLiveView, historique rotations) |
| 1.8.0 | **Mode hors-ligne robuste & Mode bord de terrain** — Journal sync (EvenementSync struct Codable buffer 50 UserDefaults, JournalSyncView liste colorée par type). Mode match (pause sync auto pendant match live, toggle wifi.slash dans toolbar MatchLiveSplitView, capsule SYNC PAUSÉE, confirmation reprise). Compteur modifications en attente (enregistrerStat/substitution/TM/set → syncService.enregistrerModificationLocale()). Mode bord de terrain courtside (EnvironmentKey modeBordDeTerrain + themeHautContraste, constantes LiquidGlassKit courtside). StatsLiveView courtside (score 72pt, 6 stats essentielles, panneau rallye masqué, bouton annuler simplifié). DashboardMatchLiveView courtside (4 cartes stats, tableau joueurs masqué avec toggle). Haptics match (sensoryFeedback impact/warning/success sur score/subs). PaveNumeriqueRapideView (overlay flottant #→joueur→action 4 boutons). Mode lecture seule (StaffPermissions.peutGererStats, badge LECTURE SEULE, boutons disabled). Réglages ProfilView (2 toggles @AppStorage). |
