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
| `PlaycoApp.swift` | @main, ModelContainer CloudKit (30 modèles), fallback local + fallback mémoire, écrans : splash → choix initial → config/rejoindre → login → sélection équipe → app |

### Modèles (`Models/`) — 30 @Model
| Fichier | Description |
|---------|-------------|
| `Seance.swift` | @Model : id, nom, date, exercices (cascade, **optionnel**), estArchivee, typeSeanceRaw (pratique/match), adversaire, lieu, scoreEquipe, scoreAdversaire, notesMatch, statsEntrees, codeEquipe, pagesMatch, rotationsHistoriqueData, rotationsHistoriqueAdvData, nousServonsEnPremier |
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
| `PointMatch.swift` | @Model : id, seanceID, set, scoreEquipeAuMoment, scoreAdversaireAuMoment, joueurID, typeActionRaw, rotationAuMoment, rotationAdvAuMoment, codeEquipe, horodatage. **+ TypeActionPoint** enum (kill, ace, bloc, erreurAdv, erreurNous, killAdversaire, aceAdversaire, blocAdversaire, erreurAttaqueAdversaire, erreurServiceAdversaire, etc.), computed estPointPourNous, estStatAdversaire |
| `ScoutingReport.swift` | @Model : adversaire, date, systemeDeJeu, styleDeJeu, joueurs adverses (JSON), forces, faiblesses, tendances, stratégies recommandées, notes, codeEquipe, estArchive |
| `ObjectifJoueur.swift` | @Model : id, joueurID, codeEquipe, titre, categorieRaw, cible, unite, dateCreation, estAtteint, notes. **+ CategorieObjectif** enum (attaque/service/bloc/réception/jeu/physique) |
| `Abonnement.swift` | @Model : id, userID, productID (StoreKit), tier (pro/club), periode (monthly/yearly), dateAchat, dateExpiration, estActif. Lié au paywall StoreKit 2 |
| `ActionRallye.swift` | @Model : seanceID, joueurID, codeEquipe, typeActionRaw (manchette/passe/réception/dig/tentativeAttaque/serviceEnJeu), set, horodatage. Stats non-marquantes du rallye |
| `CategorieExercice.swift` | @Model : nom, codeEquipe, ordre, couleurHex. Permet aux coachs de créer leurs propres catégories d'exercices |
| `CredentialAthlete.swift` | @Model (modèle privé Keychain-backed) : id, joueurID, hashMotDePasse, sel. Identifiants athlète scopés équipe |
| `PhaseSaison.swift` | @Model : nom, dateDebut, dateFin, codeEquipe, ordre. Découpage saison (pré-saison / saison régulière / playoffs) pour filtrer Analytics |
| `StaffPermissions.swift` | @Model : 7 booleans (peutGererStats, peutModifierSeances, etc.), assistantID, codeEquipe. Permissions granulaires par assistant |
| `MatchLiveModels.swift` | Structs (PAS @Model) : `JoueurSurTerrain`, `SetScore`, `Substitution`, `ConfigMatch`, `DonneesHeatmap`. Utilisés par `MatchLiveViewModel` |
| `ExerciceBibliothequeExport.swift` | Helpers JSON pour import/export de la bibliothèque exercices (pas un @Model) |
| `EvenementSync.swift` | Struct Codable (PAS @Model) : id, date, type (import/export/setup/erreur/connexion/pause/reprise), message, estErreur. **+ JournalSyncStorage** (UserDefaults buffer circulaire 50 entrées) |

### Services (`Services/`)
| Fichier | Description |
|---------|-------------|
| `AuthService.swift` | @Observable **SIWA strict (v2.1)** : connexionApple(appleUserID:) → .connecte/.compteInconnu/.echec, restaurerSession(), deconnexion(), verifierEtatSession(). AUCUN mot de passe (PasswordPolicy/LockoutManager/KeyDerivation SUPPRIMÉS — champs hash conservés vides dans les @Model pour le schéma CloudKit) |
| `MembreFactory.swift` | @MainActor enum : creerMembre(prenom:nom:role:codeEquipe:joueur:identifiantSouhaite:context:exclusions:) — création unifiée Utilisateur + CredentialAthlete SANS secret (codeInvitation généré). Utilisé par wizard, AjoutUtilisateurView, NouveauJoueurView |
| `CloudKitSharingService.swift` | Coquille (état, RecordType, SharingError avec .reseauIndisponible, extension CKRecord.chaineSecurisee — sanitisation des records publics). Découpé en : `+Publication.swift` (côté coach), `+Import.swift` (côté athlète, fetchRecords paginé par curseur), `+Jointure.swift` (rejoindreEquipe/reclamerMembreLocal SIWA) |
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
| `BibliothequeDefauts.swift` | CategorieBibliotheque (8 catégories), peuplerSiVide() |
| `DiagrammesBibliotheque.swift` | Diagrammes pré-dessinés pour exercices par défaut |
| `LiquidGlassKit.swift` | Constantes Design System centralisées : rayons (12/16/22/28pt), espacement (système 4pt : XS 4/SM 8/MD 16/LG 24/XL 32/XXL 40), animations spring (défaut/rebond/douce), bordures glass, ombres (subtile/douce/moyenne), opacités, constantes courtside (bouton 60/grille 120/score 72/police 18) |
| `ModesBordTerrainContext.swift` | EnvironmentKey `modeBordDeTerrain` + `themeHautContraste` (même pattern que EquipeContext.swift) |
| `ExercicesMusculationDefauts.swift` | Exercices musculation par défaut |

### ViewModels (`ViewModels/`)
| Fichier | Description |
|---------|-------------|
| `TerrainEditeurViewModel.swift` | @Observable : undo/redo (pile 15), formations, étapes, auto-save debounce 3s Combine, deinit cleanup |
| `PaywallViewModel.swift` | @Observable @MainActor : machine d'états `initial/chargement/pret/erreur`, produits filtrés par période, sélection produit, éligibilité essai, `acheter()`/`restaurer()` avec gestion erreur fine (rien-à-restaurer vs réseau), retry idempotent via `chargerSiNecessaire()`, `ctaLabel` dynamique sécurisé contre B2 |

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
| `ChoixInitialView.swift` | Premier lancement : "Créer mon équipe", "Se connecter" ou "Rejoindre une équipe" |
| `LoginView.swift` | **SIWA-only** : bouton Sign in with Apple + sheet « Rejoindre mon équipe » (code équipe + code d'invitation) si Apple ID inconnu, lien « Créer ou rejoindre une équipe ». Plus aucun formulaire identifiant/mot de passe |
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
| `RotationLiveView.swift` | Terrain visuel positions 1-6 avec joueurs, boutons rotation R1-R6, historique rotations par set, onglet Nous/Adversaire (Picker segmenté), mini-terrain adversaire rouge, boutons R1-R6 adversaire, historique rotations adversaire |

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

### Authentification — SIWA STRICT (v2.1)
- **Sign in with Apple est l'UNIQUE méthode de connexion.** Aucun identifiant+mot de passe nulle part dans l'UI. Les comptes legacy par mot de passe ne peuvent plus se connecter (décision assumée, pré-lancement).
- **Coach (wizard étape 3)** : bouton SIWA dans `ConfigProfilCoachView` → `appleUserID` capturé + pré-remplissage prénom/nom/courriel Apple ; finalisation crée (ou RÉUTILISE si même Apple ID — anti-doublon multi-équipes) l'Utilisateur coach sans hash + auto-login `connexionApple`.
- **Athlète/assistant** : créés via `MembreFactory` (wizard, AjoutUtilisateurView, NouveauJoueurView) — identifiant auto + `codeInvitation`, AUCUN mot de passe. Jonction : LoginView → SIWA → « Rejoindre mon équipe » (code équipe + code d'invitation) → `rejoindreEquipe`/`reclamerMembreLocal` rattache l'appleUserID.
- **Code d'invitation** : affiché dans IdentifiantsRecapSheet (wizard), IdentifiantsEquipeView (profil) et la fiche joueur (JoueurDetailView — remplace l'ancien reset de mot de passe).
- **Identifiant auto-généré** : `Utilisateur.genererIdentifiantUnique(prenom:nom:context:exclusions:)` — username d'affichage uniquement (plus de connexion par identifiant), minuscules.
- **Champs hash conservés au schéma** : `motDePasseHash/sel/iterations/motDePasseClair` restent dans les @Model (suppression = migration CloudKit destructive) mais ne sont JAMAIS écrits ni lus.
- **Révocation SIWA** : vérifiée au lancement (PlaycoApp) + retour foreground (ContentView) → déconnexion forcée.
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
22. **Paywall StoreKit** : NE JAMAIS pré-sélectionner un produit dans `onAppear` si `storeKit.produits.isEmpty` (bouton apparaîtra disabled sans feedback visuel — bug B6). Le `PaywallViewModel` doit gérer explicitement les états `chargement`/`erreur`/`pret`. CTA label : utiliser `TextesPaywall.ctaAchatPrefixe + p.displayPrice` (NE PLUS utiliser `ctaAchatDirect` supprimé en v2.0.1 — il contenait un suffixe traînant `· ` qui causait le tronquage B2 quand `displayPrice` était vide).
23. **Abonnement.codeEquipe** : depuis v2.0.1, le modèle `Abonnement` stocke `codeEquipe` (string vide par défaut pour migration CloudKit safe). Renseigné automatiquement dans `persisterDansSwiftData` depuis la première `Equipe` locale. Clé de fallback CloudKit Public DB pour reconnexion sur Apple ID différent (Phase 1.5 G2 staged pour PR ultérieure : actor `CloudKitPublicSyncAbonnement` non implémenté en v2.0.1).
24. **Stats — source unique des formules** : toute formule statistique vit dans `Helpers/MetriquesVolley.swift` (fractions 0-1, D1) et tout formatage dans `FormatMetriques` (hitting en convention volleyball « .350 » via `.hittingVolley`, pourcentages français « 85,0 % » via `.pourcentage`). ⚠️ PIÈGE d'échelles hérité : `JoueurEquipe.efficaciteReception`/`efficaciteAttaque` et `StatsJoueur.hittingPct` (dashboard live) sont en 0-100 ; `pourcentageAttaque`/`StatsMatch.hittingPct` en 0-1 — NE JAMAIS re-multiplier par 100 (bug B1). L'agrégation PointMatch/ActionRallye → compteurs passe par `Services/AgregateurStatsMatch.swift` (JAMAIS de switch local) ; le cumul carrière = Σ StatsMatch via `resynchroniserCumul` (idempotent — JAMAIS d'addition `+=` au cumul, bug B2) ; la finalisation passe par `finaliserStats` (unit les StatsMatch créés dans l'appel). Contexte de service : `PointMatch.nousServionsAuMoment`/`serviceRenseigne` (posés dans `enregistrerStat` AVANT `gererSideout`) ; legacy reconstruit par `MetriquesVolley.reconstruireService`. Kit UI stats : `CarteMetrique`/`EnTeteSection`/`TableauStats`/`FiltresStats`/`LegendeStatsSheet` — pas de cartes ad hoc. D6 : aucun émoji, aucun SF Symbol décoratif.
25. **Tests SwiftData** : les `ModelConfiguration` de test DOIVENT passer `cloudKitDatabase: .none` (sinon le mirroring CloudKit s'attache aux stores in-memory et crashe « No eligible connection available » quand le daemon comptes du simulateur est froid). Schéma = fermeture transitive des relations (pattern `MatchLiveViewModelTests`).
26. **CloudKit Public DB — JAMAIS de credentials** : `CloudKitSharingService` publie un miroir d'équipe dans la **Public DB world-readable**. NE JAMAIS y écrire `motDePasseHash`/`sel`/`iterations` (ni aucun secret) — cf. `champsPublicsUtilisateur` + garde de régression dans `CloudKitSharingServiceTests`. Depuis v2.0.1 l'authentification est **Sign in with Apple** : la jonction multi-Apple-ID (`rejoindreEquipe`/`reclamerMembreLocal`, déclenchée depuis `LoginView`) rattache l'`appleUserID` à une ligne de roster via le **code d'invitation** (aucun mot de passe transmis ; `CredentialAthlete.motDePasseClair` toujours vide). Durcissement Dashboard (Security Roles creator-write + scrub des hash existants) = **action humaine** documentée dans `docs/Securite_AbonnementPublicDB.md`.

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
cd "/Users/armypo/Documents/Origotech/Playco" && xcodebuild -scheme "Playco" -destination 'platform=iOS Simulator,name=iPad Air 13-inch (M3)' build
```

### Build sous Xcode 27 beta (toolchain non par défaut)
Xcode 27.0 beta est dans `~/Downloads/Xcode-beta.app` (pas le `xcode-select` global = Xcode 26.3). L'invoquer via `DEVELOPER_DIR` sans toucher au global :
```bash
DEVELOPER_DIR="/Users/armypo/Downloads/Xcode-beta.app/Contents/Developer" \
xcodebuild build -scheme Playco -destination 'platform=iOS Simulator,name=iPad Air 13-inch (M4),OS=27.0'
```
⚠️ **Tests sous Xcode 27 beta** : lancer avec `-parallel-testing-enabled NO` — les clones de test parallèles font crasher le host CloudKit du simulateur iOS 27 beta (cascade de faux échecs 0.000 s).

🛑 **RÉGRESSION runtime simulateur iOS 27 beta (constatée 2026-07-03, runtime `24A5355p`)** : TOUS les tests SwiftData in-memory crashent au premier `context.save()` avec `NSInternalInconsistencyException: No eligible connection available` — y compris sur `main` NON modifié et simulateur vierge (bissection prouvée ; Xcode beta inchangé `27A5194q`, c'est le runtime qui s'est mis à jour). **Valider les tests sur la toolchain stable** :
```bash
# Xcode 26.6 (xcode-select par défaut) — 181/181 verts (2026-07-03)
xcodebuild test -scheme Playco \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5' \
  -parallel-testing-enabled NO
```
(Plus d'iPad Air dans les runtimes 26.x installés — utiliser iPad Pro 13-inch M5.)

## État actuel — v1.9.0
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
- ✅ **30 @Model SwiftData** : incluant PointMatch (avec zone) + ObjectifJoueur + PhaseSaison + Abonnement + ActionRallye + CategorieExercice + CredentialAthlete + StaffPermissions
- ✅ **Accessibilité** : `accessibilityLabel/Hint` sur Canvas PencilKit (UIViewRepresentable a11y traits + accessibilityValue dynamique selon mode), DockBar (badges → accessibilityValue), BarreOutilsDessin (outils dessin + menus formation + sélecteur joueurs BD). Tests humains à compléter : VoiceOver flow complet sur iPad physique + Dynamic Type xxxLarge + contraste WCAG AA mode courtside
- ✅ **StoreKit 2 (Playco Pro)** : `StoreKitService` + `AbonnementService` (4 product IDs `ca.origotech.playco.{pro,club}.{monthly,yearly}`, subscription group `playco.pro`), modèle `Abonnement` @Model, `Playco.storekit` config, 5 vues paywall, `FeatureGating` modifier `.bloqueSiNonPayant(source:)`. Validation sandbox + restore : action humaine W6 (compte testeur Apple requis)
- ✅ **Mode hors-ligne robuste** : journal de sync (EvenementSync, buffer 50 UserDefaults), mode match (pause sync auto pendant match live, toggle wifi.slash, capsule SYNC PAUSÉE), compteur modifications en attente branché sur enregistrerStat/substitution/TM/set
- ✅ **Mode bord de terrain** : interface courtside simplifiée (grands boutons 60pt, score 72pt, 6 stats essentielles), pavé numérique rapide (#→joueur→action), feedback haptique (impact/warning/success), mode lecture seule (StaffPermissions.peutGererStats), réglages ProfilView (@AppStorage)
- ✅ **Stats FIVB/NCAA complètes** : TypeActionRallye étendu (dig, tentativeAttaque, serviceEnJeu), hitting % amélioré, rotations historique par set, modification rotation manuelle (RotationLiveView)
- ✅ **Transitions portrait/landscape** : SwiftUI Environment sizeClass (plus de UIKit), spring animations sur changement d'orientation
- ✅ **Permissions granulaires** : StaffPermissions @Model (7 booleans), GestionStaffView, lecture seule en match live
- ✅ **Stats adversaire symétriques** : 5 nouveaux TypeActionPoint (killAdversaire, aceAdversaire, blocAdversaire, erreurAttaqueAdversaire, erreurServiceAdversaire), DefinitionStat adversaire standard (scoring + erreurs), StatsLiveView sections adversaire dédiées, DashboardMatchLiveView comparaison détaillée (vraies valeurs adversaire)
- ✅ **Rotation adversaire** : rotationAdversaire dans MatchLiveViewModel, rotation auto sur sideout adversaire, modification manuelle R1-R6, RotationLiveView onglet Nous/Adversaire (Picker segmenté, mini-terrain adversaire rouge), historique rotations adversaire par set, rotationAdvAuMoment sur PointMatch, affichage rotation adversaire dans score area + info chips dashboard

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
| **2.2.a** (juil. 2026) | **Patch roadmap 2.2.a — undo par étape + State Restoration match live** (commit `7cd6594`) : piles undo/redo du terrain PAR ÉTAPE (clé UUID stable — naviguer entre les étapes ne détruit plus l'historique ; reset au chargement de document, purge à la suppression d'étape) ; nouveau `Helpers/MatchLiveRestauration.swift` (marqueur UserDefaults expirable 6 h — posé/effacé par `MatchLiveSplitView`, effacé aussi à la finalisation), resélection auto du match dans `MatchsView`, alerte « Reprendre le match en direct ? » dans `MatchDetailView` (gardée par `!statsEntrees`), `MatchLiveViewModel.restaurerSetActuel()` (reprend au set le plus avancé — PointMatch max + SetScore max — au lieu du set 1). **Tests : 270/270** (+17), build 0/0 Xcode 26.6. **Revue multi-dimensions post-patch (18 agents, vérification adversariale)** : 8 trouvailles corrigées (commit `431a5e3`) dont HI-001 — la reprise live contournait le gate `peutModifier` ET `DashboardMatchLiveView.lectureSeule` était déclarée sans être appliquée (trou préexistant corrigé : rotation/subs/temps morts désormais `.disabled(lectureSeule)`) ; `restaurerSetActuel` en fetch borné (fetchLimit 1) ; budget global de 60 snapshots undo (`maxSnapshotsTotal`, l'étape active garde ses 15) ; constante `nombreMaxDeSets`. |

<!-- code-review-graph MCP tools -->
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
