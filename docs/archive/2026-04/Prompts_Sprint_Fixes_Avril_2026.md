# Prompts optimisés — Sprint fixes Playco

**Date :** 15 avril 2026
**Usage :** copier-coller chaque prompt dans Claude Code pour exécuter une étape précise. Chaque prompt est auto-portant (ne dépend pas de cette conversation).

**Convention Playco à respecter dans TOUS les prompts :**
- Langue : français (noms de variables, commentaires, UI)
- Design : constantes `LiquidGlassKit` (pas de magic numbers)
- Logger : `os.Logger(subsystem:category:)`, jamais `print()`
- Cache : `DateFormattersCache`, `JSONCoderCache`
- Filtrage équipe : `.filtreEquipe(codeEquipeActif)`
- Soft delete : filtrer `estArchivee`/`estArchive` dans tous les `@Query`
- Immutabilité : nouvelles copies, pas de mutation
- Fichiers < 800 lignes, fonctions < 50 lignes

---

## Table des matières

### Sprint 1 — Bloqueurs critiques (5h, à faire en premier)
1. [Config projet (versions, aps-env, privacy key)](#prompt-1--config-projet)
2. [Fix memory leaks Timer × 3 fichiers](#prompt-2--fix-timer-leaks)
3. [Fix race condition restauration session auth](#prompt-3--fix-race-condition-auth)
4. [Fix collision identifiant wizard config](#prompt-4--fix-collision-identifiant)
5. [Fix try! PlaycoApp init gracieux](#prompt-5--fix-try-playcoapp)
6. [Push CloudKit schema production](#prompt-6--cloudkit-schema-prod)
7. [Build + validation complète](#prompt-7--build-validation)

### Sprint 2 — Conformité App Store (1-2 semaines)
8. [Privacy Policy + Terms URLs](#prompt-8--privacy-terms)
9. [Localisation strings anglaises → Loi 96](#prompt-9--localisation-strings)
10. [TelemetryDeck crash reporting](#prompt-10--telemetrydeck)
11. [Accessibility labels minimum viable](#prompt-11--accessibility-minimum)
12. [Découpage JoueurDetailView (974 → 3 vues)](#prompt-12--decoupage-joueurdetail)

### Sprint 3 — Polissage (1 semaine)
13. [Error handling user-facing sur saves critiques](#prompt-13--error-handling)
14. [Découpage ProfilView + BibliothequeView](#prompt-14--decoupage-profil-biblio)
15. [Edge cases auth (case-insensitive, session expiry, password strength)](#prompt-15--edge-cases-auth)
16. [Tests manuels 16 scénarios auth](#prompt-16--tests-manuels-auth)

---

## SPRINT 1 — Bloqueurs critiques

### Prompt 1 — Config projet

```
Contexte : Playco est une app iPadOS Swift/SwiftUI de coaching volleyball
(TestFlight v1.9.0, bundle Origo.Playco). Préparation du lancement App Store.

Objectif : corriger 5 bloqueurs de soumission App Store dans les fichiers de
configuration du projet. Ces erreurs provoquent un rejet automatique d'Apple.

Fichiers à modifier :
1. `Playco.xcodeproj/project.pbxproj` :
   - `MARKETING_VERSION = 1.0` → `MARKETING_VERSION = 1.9.0` (toutes les cibles)
   - `CURRENT_PROJECT_VERSION = 1` → `CURRENT_PROJECT_VERSION = 2`
   - Vérifier `IPHONEOS_DEPLOYMENT_TARGET` : si iOS 26 existe, laisser tel quel ;
     sinon corriger vers `17.0`
2. `Playco.entitlements` :
   - `aps-environment = development` → `aps-environment = production`
3. `PlaycoInfo.plist` (racine du projet, pas dans le dossier source) :
   - Ajouter `NSPhotoLibraryAddUsageDescription` avec texte français :
     "Playco utilise la photothèque pour enregistrer les photos de profil
     et les exports visuels."

Étapes :
1. Lire les 3 fichiers ci-dessus
2. Appliquer les 5 corrections
3. Lancer un build Xcode pour valider :
   xcodebuild -scheme "Playco" -destination 'platform=iOS Simulator,name=iPad Air 13-inch (M3)' build
4. Rapporter les versions corrigées + résultat du build

Critères de succès :
- MARKETING_VERSION affiche 1.9.0 dans toutes les cibles
- CURRENT_PROJECT_VERSION = 2
- aps-environment = production
- NSPhotoLibraryAddUsageDescription présent
- Build réussi, 0 erreur 0 warning
```

---

### Prompt 2 — Fix Timer leaks

```
Contexte : Playco est une app iPadOS Swift/SwiftUI de coaching volleyball.
3 fichiers ont des Timers qui ne sont pas invalidés quand la vue est détruite,
causant des memory leaks après 10-15 navigations rapides entre matchs.

Objectif : ajouter un cleanup explicite des Timers dans les 3 fichiers concernés
pour éliminer les leaks.

Fichiers et corrections :

1. `Playco/Views/Matchs/DashboardMatchLiveView.swift` (autour ligne 756-773)
   - La fonction `demarrerTimerTempsMort()` crée un `Timer` stocké dans `timerRef`
   - Problème : si la vue est détruite avant la fin du timer, le Timer retient la vue
   - Fix : ajouter `.onDisappear { timerRef?.invalidate(); timerRef = nil }`
     au niveau du `body` de la vue principale

2. `Playco/Views/Entrainement/SeanceLiveView.swift` (autour ligne 504-530)
   - La vue utilise `timerRepos` et `timerSeance`
   - Problème : invalidation conditionnelle seulement
   - Fix : ajouter `.onDisappear` qui invalide les deux timers systématiquement :
     .onDisappear {
         timerRepos?.invalidate()
         timerSeance?.invalidate()
         timerRepos = nil
         timerSeance = nil
     }

3. `Playco/PlaycoApp.swift` ligne 62 :
   - `try!` sur ModelContainer in-memory (cas limite de crash)
   - Fix : wrapper en do/catch avec logger.critical et fatalError descriptif

Étapes :
1. Lire chacun des 3 fichiers pour localiser précisément les Timer/try!
2. Appliquer les 3 corrections avec Edit (pas Write complet)
3. Lancer build Xcode :
   xcodebuild -scheme "Playco" -destination 'platform=iOS Simulator,name=iPad Air 13-inch (M3)' build
4. Rapporter les changements appliqués + résultat du build

Critères de succès :
- DashboardMatchLiveView : onDisappear invalide timerRef
- SeanceLiveView : onDisappear invalide timerRepos ET timerSeance
- PlaycoApp : try! remplacé par do/catch avec logger + fatalError gracieux
- Build 0 erreur 0 warning
```

---

### Prompt 3 — Fix race condition auth

```
Contexte : Playco utilise SwiftData + CloudKit sync. L'AuthService restaure la
session utilisateur au boot via `restaurerSession()`. Bug identifié : si l'app
est redémarrée avant que CloudKit ait fini sa sync initiale, le fetch de
l'Utilisateur échoue silencieusement et l'utilisateur est renvoyé au login.

Objectif : attendre la sync CloudKit avant de restaurer la session pour éviter
les logouts fantômes.

Fichiers concernés :
- `Playco/PlaycoApp.swift` (autour ligne 150-151) — appel à restaurerSession
- `Playco/Services/CloudKitSyncService.swift` — peut nécessiter l'ajout d'une
  méthode `attendreSyncInitiale() async throws`
- `Playco/Services/AuthService.swift` — vérifier que restaurerSession est async-safe

Étapes :
1. Lire PlaycoApp.swift autour de la ligne 150 pour comprendre le contexte actuel
2. Lire CloudKitSyncService.swift pour voir si une méthode d'attente existe déjà
3. Si non, ajouter une méthode `attendreSyncInitiale() async throws` qui :
   - Attend l'événement "initial sync complete" de CloudKit (max 10 sec timeout)
   - Retourne immédiatement si déjà synced
   - Log via logger.info le temps d'attente
4. Modifier le .onAppear de ContentView dans PlaycoApp.swift :
   .onAppear {
       Task {
           try? await syncService.attendreSyncInitiale()
           authService.restaurerSession(context: container.mainContext)
           // reste du code existant
       }
   }
5. Lancer build Xcode + tester : créer session, fermer app, rouvrir → session persistée

Critères de succès :
- Pas de logout fantôme au boot après sync CloudKit incomplète
- Timeout max 10 sec pour ne pas bloquer le boot si iCloud est down
- Logger capture le temps d'attente
- Build 0 erreur 0 warning

Convention : utiliser Logger(subsystem: "com.origotech.playco", category: "auth")
et respecter le pattern @Observable + @MainActor de CloudKitSyncService existant.
```

---

### Prompt 4 — Fix collision identifiant

```
Contexte : Playco a un wizard de configuration où le coach crée plusieurs joueurs.
`Utilisateur.genererIdentifiantUnique()` génère un identifiant unique (prenom.nom,
prenom.nom2, prenom.nom3...). Bug : si deux joueurs ont le même nom, la fonction
vérifie en base SwiftData (qui ne voit pas les insertions non-committées) et
génère 2x le même identifiant → conflit au save.

Objectif : maintenir un Set<String> des identifiants déjà attribués pendant le
wizard pour éviter les collisions en mémoire.

Fichiers concernés :
- `Playco/Views/Configuration/ConfigurationView.swift` (fonction `finaliser()`,
  autour ligne 324-352, 335)
- `Playco/Models/Utilisateur.swift` (fonction `genererIdentifiantUnique`,
  ligne 202-206)

Étapes :
1. Lire ConfigurationView.swift.finaliser() pour voir la boucle de création joueurs
2. Modifier la boucle pour maintenir un Set<String> local :
   var idsCreesEnMemoire = Set<String>()
   for j in joueursTemp {
       let base = Utilisateur.genererIdentifiantUnique(
           prenom: j.prenom, nom: j.nom, context: modelContext
       )
       var candidate = base
       var suffixe = 2
       while idsCreesEnMemoire.contains(candidate) {
           candidate = "\(base)\(suffixe)"
           suffixe += 1
       }
       idsCreesEnMemoire.insert(candidate)
       // créer Utilisateur avec `candidate`
   }
3. Optionnel : ajouter un paramètre `exclusions: Set<String> = []` à
   `Utilisateur.genererIdentifiantUnique()` pour éviter la double logique
4. Lancer build Xcode
5. Tester manuellement : wizard → créer 2 joueurs "Jean Dupont" → vérifier
   qu'ils reçoivent `jean.dupont` et `jean.dupont2`

Critères de succès :
- Pas de collision d'identifiant même avec noms identiques
- Build 0 erreur 0 warning
- Test manuel validé avec 2 joueurs même nom

Convention : code en français, pas de mutation, log via Logger si nécessaire.
```

---

### Prompt 5 — Fix try! PlaycoApp

```
Contexte : Playco initialise son ModelContainer SwiftData avec une cascade
de fallbacks : CloudKit → local → in-memory. Le dernier fallback utilise `try!`
à la ligne 62 de PlaycoApp.swift, ce qui crasherait l'app si même la mémoire
échoue (cas limite mais pas impossible).

Objectif : remplacer le `try!` par un do/catch gracieux qui log l'erreur
critique et affiche un message utilisateur clair avant fatalError.

Fichier concerné :
- `Playco/PlaycoApp.swift` ligne 62

Étapes :
1. Lire PlaycoApp.swift autour de la ligne 62 pour comprendre le contexte
2. Repérer le logger existant (probablement défini au top du fichier)
3. Remplacer :
   container = try! ModelContainer(
       for: Schema([]),
       configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
   )
   par :
   do {
       container = try ModelContainer(
           for: Schema([]),
           configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
       )
   } catch {
       logger.critical("Échec init ModelContainer en mémoire: \(error)")
       fatalError("Impossible d'initialiser la base de données. Merci de redémarrer l'app. Si le problème persiste, contactez le support.")
   }
4. Si pas de logger dans PlaycoApp, l'ajouter :
   private let logger = Logger(subsystem: "com.origotech.playco", category: "app")
5. Lancer build Xcode

Critères de succès :
- Aucun try! dans PlaycoApp.swift
- Logger importé (import os)
- Build 0 erreur 0 warning

Note : fatalError est acceptable dans ce cas car c'est le dernier fallback
d'une cascade et il n'y a littéralement rien d'autre à faire. Mais le message
doit être user-friendly.
```

---

### Prompt 6 — CloudKit schema prod

```
Contexte : Playco utilise SwiftData avec cloudKitDatabase: .automatic, ce qui
push automatiquement le schéma en développement CloudKit. Mais le schéma
production (qui sera utilisé par les utilisateurs App Store) doit être
explicitement déployé via le Dashboard CloudKit. Sans ça, les utilisateurs
n'auront ni données ni sync multi-device.

Objectif : déployer le schéma CloudKit actuel (24 @Model) de l'environnement
Development vers Production via Dashboard CloudKit, et documenter le processus.

Ce n'est PAS une tâche de code : c'est une action manuelle Apple Developer +
documentation.

Étapes à exécuter manuellement par le coach (documenter la procédure) :
1. Ouvrir https://icloud.developer.apple.com/dashboard/
2. Sélectionner le container iCloud.Origo.Playco
3. Onglet "Schema" → Development environment
4. Vérifier que les 24 types de record correspondent aux @Model actuels :
   - CD_Seance, CD_Exercice, CD_JoueurEquipe, CD_StrategieCollective,
     CD_Utilisateur, CD_Equipe, CD_Etablissement, CD_ProfilCoach,
     CD_AssistantCoach, CD_CreneauRecurrent, CD_MatchCalendrier,
     CD_MessageEquipe, CD_PointMatch, CD_ScoutingReport, CD_ObjectifJoueur,
     CD_ProgrammeMuscu, CD_ExerciceMuscu, CD_SeanceMuscu, CD_TestPhysique,
     CD_Presence, CD_Evaluation, CD_StatsMatch, CD_ExerciceBibliotheque,
     CD_FormationPersonnalisee
5. Bouton "Deploy Schema Changes to Production..." en haut à droite
6. Confirmer le deployment (irréversible)
7. Valider avec 2 devices iCloud différents que la sync fonctionne

Tâche Claude Code : créer un fichier
`docs/CloudKit_Schema_Deployment.md` qui documente cette procédure avec :
- Screenshots attendus à chaque étape (placeholders)
- Liste des 24 types de record attendus
- Commande de validation post-déploiement
- Rollback procedure (si possible via Reset Development Schema)
- Troubleshooting des erreurs communes

Critères de succès :
- Fichier docs/CloudKit_Schema_Deployment.md créé
- Liste exhaustive des 24 @Model documentée
- Procédure claire et numérotée
```

---

### Prompt 7 — Build validation

```
Contexte : Après application des fixes du Sprint 1 (config projet, Timer leaks,
race condition auth, collision identifiant, try!), il faut valider que tout
compile et que les tests manuels auth passent.

Objectif : lancer un build complet et exécuter les tests manuels critiques
pour valider que le Sprint 1 n'a rien cassé.

Étapes :
1. Lancer le build Xcode :
   cd "/Users/armypo/Documents/Coach Planner VB" && xcodebuild -scheme "Playco" \
     -destination 'platform=iOS Simulator,name=iPad Air 13-inch (M3)' build 2>&1 | tail -50
2. Rapporter résultat : 0 erreur 0 warning attendu
3. Si erreurs : les lister et proposer fix immédiat
4. Si succès : produire une checklist de tests manuels à exécuter sur l'iPad :

CHECKLIST AUTH (à exécuter sur iPad avant de valider le sprint) :
□ Créer nouvelle équipe avec wizard → 2 joueurs même nom → identifiants distincts
□ Se déconnecter → se reconnecter → session restaurée
□ Fermer l'app complètement → la relancer immédiatement → session restaurée
□ Login avec majuscules → doit fonctionner
□ 5 tentatives login échouées → verrouillage 5 min
□ Lancer 15 matchs live consécutifs → rouvrir le match live → pas de leak mémoire
□ Lancer 15 séances muscu consécutives → timer invalide bien à la sortie
□ Ouvrir le profil → vérifier affichage code équipe + sync
□ Changer d'équipe via profil → notifications OK
□ Déconnexion → retour ChoixInitialView

Critères de succès :
- Build 0 erreur 0 warning
- Checklist fournie au format markdown
- Aucun régression sur auth flow
```

---

## SPRINT 2 — Conformité App Store

### Prompt 8 — Privacy Terms

```
Contexte : Playco doit fournir une Privacy Policy URL et des Terms of Service
pour la soumission App Store. Marché primaire : Québec (PIPEDA + Loi 25),
secondaire : Canada anglophone.

Objectif : créer 2 pages Markdown légales conformes à la législation
québécoise + placeholder pour hébergement + ajouter liens dans l'app.

Fichiers à créer :
1. `docs/legal/privacy-policy-fr.md`
2. `docs/legal/privacy-policy-en.md`
3. `docs/legal/terms-of-service-fr.md`
4. `docs/legal/terms-of-service-en.md`

Contenu Privacy Policy (FR) à inclure :
- Qui collecte : Origo Technologies (fondateur Playco)
- Quelles données : identifiant, mot de passe hashé, photos de profil,
  statistiques volleyball, notes de coach, code équipe, messages inter-équipe
- Comment : saisie directe utilisateur, pas de tracking publicitaire
- Où stockées : localement sur l'appareil + Apple iCloud (CloudKit) —
  infrastructure Apple, chiffrement de bout en bout
- Durée conservation : tant que compte actif + 30 jours après suppression
- Droits utilisateur (Loi 25 QC / PIPEDA) :
  accès, rectification, effacement, portabilité, retrait consentement
- Contact Responsable : [EMAIL À REMPLIR]
- Base légale : consentement utilisateur lors création compte
- Pas de partage tiers, pas de vente
- Enfants < 14 ans : compte parent requis (RSEQ / milieu scolaire)

Contenu Terms of Service :
- Utilisation non-commerciale par coachs et athlètes
- Pas de garantie de sync CloudKit si iCloud down
- Responsabilité limitée
- Modifications des termes avec notification 30 jours
- Juridiction : Québec, Canada

Dans l'app, modifier `Views/Profil/ProfilView.swift` pour ajouter 2 liens :
- "Politique de confidentialité" → Link vers URL future (placeholder #)
- "Conditions d'utilisation" → Link vers URL future (placeholder #)

Étapes :
1. Créer les 4 fichiers .md
2. Rédiger en français québécois pour la version FR
3. Ajouter les liens dans ProfilView.swift (nouvelle section "Légal")
4. Build Xcode pour valider

⚠️ IMPORTANT : ces textes sont à faire valider par un avocat québécois avant
mise en ligne réelle. Le prompt ne remplace pas une révision légale.

Critères de succès :
- 4 fichiers créés
- Liens visibles dans ProfilView
- Build 0 erreur 0 warning
```

---

### Prompt 9 — Localisation strings

```
Contexte : Playco est destiné au marché québécois (Loi 96 rend obligatoire
le français pour tout produit vendu au Québec). L'audit a détecté plusieurs
strings anglaises hardcodées qui doivent être localisées.

Objectif : créer un Localizable.xcstrings et migrer les strings anglaises
identifiées vers des clés localisables français + anglais.

Strings anglaises à localiser (minimum identifié) :
1. "Box Score" (× 3 occurrences)
   - `Playco/Views/Equipe/TableauBordView.swift`
   - `Playco/Views/Seances/MatchDetailView.swift`
   - `Playco/Services/PDFExportService.swift`
2. "Mode Live" (probable dans TableauBordView)
3. Chercher d'autres strings anglaises avec Grep :
   grep -rn --include="*.swift" -E "Text\(\"[A-Z][a-z]+.*\"\)" Playco/Views/

Traductions proposées :
- "Box Score" → FR "Feuille de match" / EN "Box Score"
- "Mode Live" → FR "Mode en direct" / EN "Live Mode"

Étapes :
1. Créer/modifier `Playco/Resources/Localizable.xcstrings`
   (SwiftUI String Catalog, format Xcode 15+)
2. Ajouter les clés :
   - "box_score" : FR "Feuille de match", EN "Box Score"
   - "mode_live" : FR "Mode en direct", EN "Live Mode"
3. Remplacer les strings hardcodées dans les 3+ fichiers par :
   Text("box_score", comment: "Match box score header")
4. Faire un sweep complet avec grep pour identifier TOUT texte anglais hardcodé
5. Build Xcode pour valider

Bonus : ajouter dans les build settings la génération automatique des symbols
de strings : SWIFT_EMIT_LOC_STRINGS = YES (déjà présent selon CLAUDE.md).

Critères de succès :
- Localizable.xcstrings créé avec clés FR/EN
- Strings hardcodées "Box Score", "Mode Live" remplacées
- Grep final ne trouve plus de Text("...") en anglais dans les vues
- Build 0 erreur 0 warning

Convention : les clés en snake_case_minuscule, commentaires en anglais pour
les traducteurs futurs.
```

---

### Prompt 10 — TelemetryDeck

```
Contexte : Playco n'a aucun système de crash reporting ni d'analytics produit.
En production, les crashs seront invisibles et on ne saura pas comment les
coachs utilisent l'app.

Objectif : intégrer TelemetryDeck (privacy-first, Apple-native, gratuit jusqu'à
100k signaux/mois) pour capturer crashs + événements produit essentiels.

Pourquoi TelemetryDeck vs Sentry/Firebase :
- 100% privacy-first (pas d'IDFA, pas de tracking utilisateur)
- Conforme RGPD / Loi 25 Québec
- SDK Swift natif, pas de bloat Firebase
- Zéro configuration complexe

Étapes :
1. Ajouter TelemetryDeck via Swift Package Manager :
   URL: https://github.com/TelemetryDeck/SwiftSDK
   Version: up to next major
2. Créer un compte TelemetryDeck.com → obtenir App ID
3. Créer un fichier `Playco/Services/AnalyticsService.swift` :
   - @Observable class AnalyticsService
   - init() configure TelemetryDeck avec App ID
   - func suivre(evenement: String, metadonnees: [String: String] = [:])
   - Jamais capturer : identifiant, nom, prenom, mot de passe, codeEquipe
4. Initialiser dans PlaycoApp.swift au démarrage
5. Instrumenter 10 événements clés :
   - app_launched
   - utilisateur_connecte (sans données perso)
   - equipe_creee
   - seance_creee
   - match_cree
   - match_live_demarre
   - exercice_cree
   - erreur_critique (si ça arrive)
   - configuration_completee
   - export_pdf_genere
6. Build Xcode + test : lancer l'app, créer une équipe, vérifier dans le
   dashboard TelemetryDeck que les événements arrivent

Critères de succès :
- SPM TelemetryDeck ajouté
- AnalyticsService.swift créé
- 10 événements clés instrumentés
- Aucun PII (données personnelles) capturé
- Build 0 erreur 0 warning

Convention : un seul point d'entrée AnalyticsService, pas de TelemetryManager
direct ailleurs dans le code. Fonction `suivre()` en français.
```

---

### Prompt 11 — Accessibility minimum

```
Contexte : Audit Playco a trouvé 0 accessibilityLabel/accessibilityHint dans
tout le codebase. Apple peut rejeter l'app si VoiceOver est testé. Minimum
viable pour passer le review = les actions critiques du match live + les
boutons principaux.

Objectif : ajouter un minimum viable d'accessibilityLabel/Hint/Value sur les
composants critiques pour passer l'App Store review.

Zones prioritaires (ordre d'importance) :

1. Mode bord de terrain (Match Live) :
   - `Playco/Views/Matchs/PaveNumeriqueRapideView.swift`
   - `Playco/Views/Matchs/StatsLiveView.swift`
   - `Playco/Views/Matchs/DashboardMatchLiveView.swift`
   - `Playco/Views/Matchs/RotationLiveView.swift`
   Pour chaque bouton stat (Kill/Ace/Bloc/Erreur) :
   .accessibilityLabel("Ajouter un \(nomStat) pour \(joueurNom)")
   .accessibilityHint("Double-tapez pour enregistrer le point")

2. Actions de navigation principales (AccueilView, DockBarView)
   - Sections Séances, Matchs, Stratégies, Équipe, Entraînement
   .accessibilityLabel("Section \(nomSection)")
   .accessibilityHint("Double-tapez pour ouvrir")

3. Actions critiques création/suppression :
   - Boutons "Créer séance", "Nouveau match", "Ajouter joueur", etc.
   - Boutons de suppression avec confirmation
   .accessibilityLabel("Créer \(entite)")

4. Indicateurs temps réel (scores, rotations, sets) :
   .accessibilityValue("\(scoreEquipe) points contre \(scoreAdversaire)")

Étapes :
1. Lister avec Grep les fichiers des 4 zones prioritaires
2. Appliquer les modifications .accessibilityLabel/Hint/Value
3. Pour les Text() affichant des stats, utiliser .accessibilityLabel avec
   le contexte (ex: "42 kills sur 87 tentatives, efficacité 48%")
4. Tester brièvement avec VoiceOver sur iPad : mode bord de terrain +
   navigation principale doit être utilisable
5. Build Xcode

Critères de succès :
- Tous les boutons du Mode bord de terrain ont accessibilityLabel
- Les 5 sections principales (AccueilView) ont accessibilityLabel
- Les 10 actions critiques (créer/supprimer) ont accessibilityLabel
- VoiceOver peut naviguer un match live end-to-end sans se perdre
- Build 0 erreur 0 warning

Note : ceci est un MINIMUM VIABLE pour le review Apple, pas une
conformité WCAG 2.2 complète. Prévoir un sprint dédié plus tard pour
le reste de l'app.
```

---

### Prompt 12 — Découpage JoueurDetail

```
Contexte : JoueurDetailView.swift fait 974 lignes, bien au-dessus de la limite
des 800 lignes recommandées par CLAUDE.md. Ceci cause des frame drops lors
de la navigation vers la fiche d'un joueur.

Objectif : découper JoueurDetailView en 3 sous-vues cohérentes tout en
conservant 100% de la fonctionnalité actuelle.

Fichier à refactoriser :
- `Playco/Views/Equipe/JoueurDetailView.swift` (974 lignes)

Découpage proposé :
1. `JoueurDetailView.swift` → vue principale, conteneur + NavigationStack
   (< 200 lignes)
2. `JoueurEnteteView.swift` → photo, nom, numéro, poste, équipe
   (< 250 lignes)
3. `JoueurStatsView.swift` → stats NCAA/FIVB, graphiques, heatmap
   (< 300 lignes)
4. `JoueurMusculationView.swift` → charges, tests physiques, programmes muscu
   (< 250 lignes)

Étapes :
1. Lire JoueurDetailView.swift intégralement
2. Identifier les 3 blocs naturels (en-tête, stats, musculation)
3. Créer les 3 nouveaux fichiers dans `Playco/Views/Equipe/`
4. Extraire chaque bloc avec ses dépendances :
   - @State et @Binding appropriés
   - Passage de `joueur: JoueurEquipe` en paramètre
   - Préserver les LiquidGlassKit constants
   - Préserver les .contentTransition(.numericText())
5. Dans JoueurDetailView principale, réassembler via les 3 sous-vues
6. Vérifier qu'aucune logique n'est dupliquée
7. Build Xcode + test visuel sur simulateur

Règles de découpage :
- Immutabilité : pas de mutation de joueur, seulement affichage
- Chaque sous-vue reçoit ses données en paramètre, pas de @Query dedans
- Les @State locaux restent dans chaque sous-vue si scope limité
- LiquidGlassKit constants respectés partout
- Aucun magic number

Critères de succès :
- 4 fichiers (original + 3 sous-vues) chacun < 300 lignes
- 100% des fonctionnalités préservées (vérifier visuellement)
- 0 régression visuelle vs avant
- Build 0 erreur 0 warning
- Navigation vers un joueur reste fluide (subjective : 60 FPS stable)
```

---

## SPRINT 3 — Polissage

### Prompt 13 — Error handling

```
Contexte : Audit Playco a identifié que plusieurs `try? modelContext.save()`
et `try? JSONCoderCache.decoder.decode(...)` swallowent silencieusement les
erreurs sans feedback utilisateur. En production, un utilisateur peut perdre
son travail sans le savoir.

Objectif : remplacer les `try?` silencieux sur les opérations critiques
(save, decode) par un pattern do/catch avec logging ET feedback utilisateur
visible quand l'action est user-facing.

Fichiers concernés (liste initiale à étendre via Grep) :
- Tous les `Views/` qui contiennent `try? modelContext.save()`
- Tous les ViewModels qui décodent du JSON avec `try?`

Pattern à appliquer :

AVANT :
    try? modelContext.save()

APRÈS (dans une View) :
    do {
        try modelContext.save()
    } catch {
        logger.error("Erreur sauvegarde: \(error.localizedDescription)")
        messageErreur = "Impossible d'enregistrer. Vérifiez votre connexion iCloud."
        afficheErreur = true
    }

Avec dans la View :
    @State private var messageErreur = ""
    @State private var afficheErreur = false

Et un .alert :
    .alert("Erreur", isPresented: $afficheErreur) {
        Button("OK") { }
    } message: {
        Text(messageErreur)
    }

Pour les décodages JSON :

AVANT :
    if let dec = try? JSONCoderCache.decoder.decode([ElementTerrain].self, from: d) {
        elements = dec
    } else {
        elements = []
    }

APRÈS :
    do {
        elements = try JSONCoderCache.decoder.decode([ElementTerrain].self, from: d)
    } catch {
        logger.warning("Échec décodage éléments terrain: \(error.localizedDescription)")
        elements = []
    }

Étapes :
1. Grep pour trouver tous les `try? modelContext.save()` dans Views/
2. Grep pour tous les `try? JSONCoderCache` dans ViewModels et Services
3. Prioriser les 10 emplacements les plus critiques (match live, création
   séance, sauvegarde stats, exports)
4. Appliquer le pattern ci-dessus à ces 10 emplacements
5. Build Xcode + tests manuels des chemins critiques

Critères de succès :
- Les 10 saves critiques ont un logger.error + alert user-facing
- Les décodages JSON critiques ont un logger.warning
- Build 0 erreur 0 warning
- Test manuel : déconnecter iCloud → tenter sauvegarde → alerte affichée

Convention : utiliser Logger avec subsystem "com.origotech.playco" et
category approprié. Messages utilisateur en français, non-techniques.
```

---

### Prompt 14 — Découpage Profil Biblio

```
Contexte : Deux fichiers dépassent la limite de 800 lignes :
- ProfilView.swift (869 lignes)
- BibliothequeView.swift (896 lignes)

Objectif : découper ces 2 fichiers en sous-vues cohérentes.

Fichier 1 : `Playco/Views/Profil/ProfilView.swift` (869 lignes)
Découpage :
- ProfilView.swift (conteneur, < 150 lignes)
- `ProfilHeaderSection.swift` (identifiant, équipe, avatar, < 200 lignes)
- `ProfilSettingsSection.swift` (thème sombre, haut contraste, masquer
  pratiques athlètes, < 200 lignes)
- `ProfilSyncSection.swift` (statut iCloud, journal sync, mode match,
  < 200 lignes)
- `ProfilSuppressionSection.swift` (supprimer données, supprimer équipe,
  déconnexion, < 200 lignes)

Fichier 2 : `Playco/Views/Bibliotheque/BibliothequeView.swift` (896 lignes)
Découpage :
- BibliothequeView.swift (conteneur + navigation, < 200 lignes)
- `BibliothequeRechercheView.swift` (recherche + filtres catégorie,
  < 250 lignes)
- `BibliothequeListeView.swift` (grille d'exercices filtrés, < 250 lignes)
- `BibliothequeExerciceRow.swift` (ligne d'exercice individuelle,
  < 200 lignes)

Étapes :
1. Lire les 2 fichiers intégralement
2. Pour chacun, identifier les blocs naturels
3. Créer les sous-vues
4. Extraire les blocs avec dépendances (@State, @Query, @Environment)
5. Réassembler via les sous-vues dans le conteneur principal
6. Build Xcode + tests visuels

Règles :
- Immutabilité, pas de mutation d'état depuis une sous-vue sans @Binding
- LiquidGlassKit constants partout
- Pas de duplication de code
- Animations et transitions préservées

Critères de succès :
- Tous les fichiers < 300 lignes
- 100% des fonctionnalités préservées
- Build 0 erreur 0 warning
- Tests visuels : ouverture Profil + Bibliothèque fluide
```

---

### Prompt 15 — Edge cases auth

```
Contexte : L'audit auth a identifié 6 edge cases non gérés. Sprint 3 :
les corriger.

Edge cases à fixer :

1. Code équipe case-insensitive
   Fichier : `Playco/Views/Auth/RejoindreEquipeView.swift` (ligne ~193)
   Problème : RejoindreEquipeView normalise les espaces mais pas la casse
   Fix : ajouter .uppercased() sur codeEquipe avant la recherche

2. Sel vide string vs nil
   Fichier : `Playco/Services/AuthService.swift` (ligne ~108)
   Problème : vérifie `sel, !sel.isEmpty` mais Utilisateur.sel permet String?
   Fix : utiliser `sel?.isEmpty ?? true` partout pour détecter "pas de sel"

3. Session expiration (jamais implémentée)
   Fichier : `Playco/Models/Utilisateur.swift` + `AuthService.swift`
   Ajouter :
   - Utilisateur : `sessionCreeeLe: Date?`
   - AuthService : lors de restaurerSession, vérifier que
     `Date.now.timeIntervalSince(sessionCreeeLe) < 30 * 24 * 3600` (30 jours)
   - Sinon, auto-logout avec message "Session expirée, veuillez vous reconnecter"

4. Password strength > 6 chars
   Fichier : `Playco/Services/AuthService.swift` (ligne ~227)
   Problème : accepte "123456"
   Fix : exiger min 8 chars + au moins 1 chiffre :
   guard motDePasse.count >= 8,
         motDePasse.contains(where: { $0.isNumber }) else {
       throw AuthError.motDePasseFaible
   }
   Ajouter le cas AuthError.motDePasseFaible avec message user-friendly.

5. Wizard inachevé → 2e équipe possible
   Fichier : `Playco/Models/ProfilCoach.swift` + `ConfigurationView.swift`
   - Ajouter `configurationEnCours: Bool = false` à ProfilCoach
   - Au début du wizard, set = true
   - À la fin (finaliser()), set = false
   - Si l'app relance et trouve un ProfilCoach avec `configurationEnCours == true`,
     proposer "Reprendre la configuration" ou "Supprimer et recommencer"

6. Versioning hash pour future migration PBKDF2
   Fichier : `Playco/Models/Utilisateur.swift`
   Ajouter : `hashAlgorithme: String = "SHA256+salt"`
   Utiliser ce champ dans AuthService pour détecter l'algo à utiliser.

Étapes :
1. Appliquer les 6 fixes dans l'ordre
2. Pour chaque fix, lancer le build Xcode
3. Tester manuellement le cas correspondant
4. Ne PAS casser les anciennes sessions (migration transparente)

Critères de succès :
- Les 6 edge cases sont couverts
- Aucune régression sur les flows auth existants
- Migration transparente des utilisateurs existants (pas de forced logout)
- Build 0 erreur 0 warning

Convention : français, Logger pour chaque transition d'état importante,
messages user-friendly en français.
```

---

### Prompt 16 — Tests manuels auth

```
Contexte : Avant le lancement officiel de septembre 2026, il faut exécuter
les 16 tests manuels d'authentification sur iPad réel pour valider tous
les cas edge.

Objectif : produire un rapport de tests exécutés avec résultat pass/fail
pour chaque scénario.

Prérequis :
- iPad Air 13" M3 avec Playco v1.9.x installé
- Un compte iCloud de test actif
- Avoir appliqué les fixes des Sprints 1, 2, 3

Scénarios à exécuter (dans l'ordre) :

1. Créer équipe avec 2 athlètes même nom → identifiants distincts
   Attendu : `jean.dupont` et `jean.dupont2`

2. Wizard config fermé à mi-parcours → reprendre
   Attendu : propose "Reprendre la configuration" ou "Recommencer"

3. Login case-insensitive (`Prenom.Nom` → `prenom.nom`)
   Attendu : connexion réussie peu importe la casse

4. Multi-équipes (coach avec 2 équipes)
   Attendu : SelectionEquipeView affichée, choix permis, données scopées

5. Code équipe avec espaces et majuscules
   Attendu : normalisation, accepté si code valide

6. Athlète supprimé pendant session
   Attendu : déconnexion propre au prochain foreground

7. 5 tentatives échouées → verrouillage 5 min
   Attendu : message clair, pas possible de retenter pendant 5 min

8. Verrouillage persistant après fermeture app
   Attendu : UserDefaults retient le verrouillage

9. Mot de passe avec accents (é, à, ç)
   Attendu : hash correct, connexion OK

10. Identifiant avec emoji
    Attendu : rejeté ou filtré avec message

11. CloudKit sync multi-device
    Attendu : créer user device A → visible device B sous 30 sec

12. Race condition connexion → kill app → rouvre
    Attendu : session restaurée même si sync CloudKit pas finie

13. Wizard → auto-login → changement d'équipe → redéconnexion
    Attendu : séquence fluide, pas de crash

14. Session > 30 jours → auto-logout (fix Sprint 3)
    Attendu : au 31e jour, logout automatique + message

15. Mot de passe < 8 chars → rejeté
    Attendu : message user-friendly "Mot de passe trop faible"

16. Hash migration ancien compte sans sel
    Attendu : à la première connexion réussie, sel généré et hash migré,
    les prochaines connexions utilisent le nouveau hash

Étapes :
1. Préparer un document de test `docs/tests/auth-tests-avril-2026.md`
2. Pour chaque scénario :
   - [ ] Scénario
   - Résultat : PASS / FAIL
   - Notes / screenshots si FAIL
3. Si un test FAIL, créer un ticket dans `docs/tests/bugs-identifies.md`
4. Rapporter le résultat global : X/16 PASS

Critères de succès :
- 16/16 PASS ou bugs identifiés avec priorité
- Document de test archivé dans docs/tests/
- Pas de crash pendant l'exécution
- Blocker = 1 FAIL sur critère de sécurité (tests 7, 8, 10, 15, 16)
```

---

## Utilisation

Pour chaque étape du sprint, copier le prompt correspondant et le coller dans
Claude Code. Chaque prompt est auto-portant et contient tout le contexte
nécessaire.

**Ordre d'exécution recommandé :**

1. **Sprint 1** (bloqueurs) : Prompts 1 → 7, dans l'ordre, en une session
2. **Sprint 2** (conformité) : Prompts 8 → 12, peut être parallélisé
3. **Sprint 3** (polissage) : Prompts 13 → 16, dans l'ordre

**Gate de validation entre sprints :**
- Après Sprint 1 : build 0 erreur 0 warning + 16 tests auth PASS
- Après Sprint 2 : accessibility VoiceOver OK + TelemetryDeck captures les
  événements en dashboard + build propre
- Après Sprint 3 : 16/16 tests auth PASS + tests manuels UX sur iPad OK

---

*Prompts générés le 15 avril 2026 · Playco v1.9.0 · 16 étapes optimisées pour
Claude Code*
