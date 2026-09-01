# Journal d'exécution — Pivot Coach-First

> Trace de chaque opération du pivot (branche `pivot/coach-first`), pour la revue de PR différée (GitHub indisponible au moment de l'exécution — décision fondateur 2026-08-29 : « continue et on va PR plus tard, garde des traces »). Plan de référence : [Pivot_CoachFirst_Plan.md](./Pivot_CoachFirst_Plan.md).

## 2026-08-29 — Mise en place

- **Analyse** (2026-08-26/29) : 7 agents d'exploration + critique de complétude sur `suivis/pr6` ; décisions fondateur D1-D6 actées ; revue diff-par-diff des 25 commits de la boucle de nuit (8 groupes) → verdict : merge intégral.
- **Branche** : `pivot/coach-first` créée sur `c233bb6` (tête de `CChristo/agitated-mcnulty-c2cefa` = main v2.2 + boucle de nuit des 6-7 juil.). Le « merge de la nuit » est donc porté par cette branche ; la PR vers `main` (nuit + pivot) se fera au retour de GitHub. `suivis/pr6` (démo) sera rebasée après ce retour sur `main`.
- **Docs** : bandeaux ARCHIVE PRÉ-PIVOT posés sur `Vision_Playco_3.0.md` et `Roadmap_Playco_v2.2_v3.x.md` ; plan chantiers A-E versionné (`Pivot_CoachFirst_Plan.md`) ; ce journal créé.

## Chantier A — Suppression paywall + messagerie ✅ 2026-08-29

- `ed5a1aa` **feat(pivot-A): app gratuite — suppression complète du paywall StoreKit (D3)** — ~2 100 lignes supprimées (services, ViewModel, 6 vues, helpers, .storekit, framework, 10 gates, bannière, paywall de bienvenue, section abonnement, erreurGate, 8 événements analytics, lecture AbonnementPartage). `migrerAssistantsVersNouveauRole` extraite vers `Services/MigrationRoles.swift`. `Abonnement` @Model + `Equipe.tierAbonnementRaw` conservés au schéma. Tests supprimés : PaywallViewModelTests, PaywallTextesTests, FeatureGatingTests ; AbonnementCodeEquipeTests adaptée.
- `ac6a5ac` **feat(pivot-A): retrait de la messagerie (D1) + fix warnings MetricKit** — MessagerieView, PolitiqueMessagerie (+6 tests), item Messages du Dock, badges/non-lus, page tutoriel messagerie. `MessageEquipe` @Model conservé (schéma + cascade). Fix annexe : 5 warnings d'isolation MetricKitService (toolchain courante).
- **Vérification** : build 0 erreur / 0 warning (iPad Pro 13-inch M5) ; **275/275 tests, 43 suites** (base nuit 303 − 28 tests paywall/messagerie supprimés).

## Chantier B — Retrait athlète ✅ 2026-08-29

- `6edc08b` **B1 comptes & jonction** — MembreFactory sans `joueur:` ; NouveauJoueurView réécrite (JoueurEquipe pur) ; wizard étape 5 joueurs sans identifiants ; AjoutUtilisateurView assistant-only ; `roleJonctionAutorise` → `.assistantCoach` seul ; libellés ChoixInitial/Login/IdentifiantsEquipe recentrés assistants ; grille QR projetable + section Identifiants de la fiche joueur supprimées.
- `9887942` **B3 surfaces + muscu (D2)** — MonProfilAthleteView supprimée ; branches `.etudiant` de ContentView/AccueilView retirées ; `masquerPratiquesAthletes` hors UI (champ gelé) ; **sélecteur « Pour quel joueur ? »** avant la séance muscu live (le coach saisit au nom d'un athlète, indisponibles 2.2.b désactivés).
- `5408484` **B4 permissions (D6)** — PermissionsRole supprimé (~40 sites balayés, gardes → « session valide ») ; GestionStaffView + lecture seule du live supprimées ; distinction `estCoach` de ProfilView supprimée ; `StaffPermissions` @Model gelé.
- `6b7e401` **B5 nettoyages** — cascade de suppression d'équipe complétée (PhaseSaison, CredentialAthlete, Utilisateur membres, Presence/Evaluation/TestPhysique par joueurID capturés avant suppression ; Abonnement volontairement exclu) ; fin des écritures miroir (EditionJoueurView → nouveau champ `JoueurEquipe.poidsKg` additif, AvatarEditableView) ; code mort purgé (EvaluationView, SaisieStatsMatchView, ModifierUtilisateurView + clusters ProfilSubViews, StatsLiveSheetWrapper, publierModificationsEquipe).
- `fdbc671` **B6 tests** — MultiUtilisateur/MembreFactory/RejoindreEquipe refondus coach/assistant + test de régression « jonction .etudiant rejetée ».
- **Vérification** : build 0/0 ; **276/276 tests, 43 suites**.
- **Différé** : reformulation « collecte de données / vidéo » complète des textes d'attestation + retention-fr (fait a minima : mention messagerie retirée) ; textes légaux externes (placeholders).

## Chantier C — Déplacements navigation ✅ 2026-08-29

- `2fef2bc` — 7 déplacements : **C1** scouting → Matchs (section « Préparation » en sidebar, retiré de Stratégies) ; **C2** toolbar match 7 chips → 3 groupes-menus (Préparer · En direct · Après) ; **C3** Heatmap/Rotations hors du bottomBar Matchs (hub Équipe canonique) ; **C4** Calendrier au Dock (4e item) + retiré des bottomBars + Planification accessible depuis le calendrier ; **C6** Formations en entrée de sidebar nommée ; **C7** Présences dans l'écran d'exercices ; **C8** Exports CSV dans le hub Statistiques.
- **Écarts (différés à la coquille 2.5a)** : C5 dock persistant dans les sections + recherche deep-link (collision avec les bottomBars restants sans refonte) ; C1 en push plutôt qu'en sheet.
- **Vérification** : build 0/0 ; 276/276 tests.

## Chantier D — Uniformisation, vague 1 ✅ 2026-08-29

- `bed47f5` — BoutonRetourAccueil partagé (5 copies remplacées) ; **confirmation sur la suppression de match** (cascade destructive au swipe corrigée) ; sidebars homogènes (.sidebar + searchable Matchs/Entraînement) ; icône « + » unique ; création programme muscu alert → Form ; tints alignés palette mate ; FiltresStats (code mort) supprimé.
- **Vague 1bis (à faire, avec Mat Nuit)** : « Fermer » standardisé (~20 sites), ~20 empty states ad hoc → ContentUnavailableView, kit stats généralisé, campagne paddings/rayons (8 pires fichiers), formulaires VStack custom → Form, purge .rounded/.hierarchical, échelle typo.

## Chantier E — Parité de sync assistant (D6) ✅ 2026-09-01

Phasé E1→E4 (voir plan) : plomberie durcie, contenus de préparation, analyse, écriture assistant — livrés en 4 commits (un par phase, chacun build 0/0 + tests verts). **Action humaine à la première mise en production du miroir élargi : passer les nouveaux champs en QUERYABLE dans le Dashboard CloudKit** (voir E3 — `seanceID`/`horodatage` sur `PointMatchPartage`, `codeEquipe` sur les 7 nouveaux types).

### E1 — Plomberie durcie ✅ 2026-09-01

- **feat(pivot-E1)** — fetch-puis-modifier généralisé aux 5 `publierX` : helper `recordPublicAJour(type:recordID:)` (recharge le record existant, sinon record neuf) + `sauvegarder(champs:sur:)` ; sans ça, tout save d'un record DÉJÀ publié échouait en `serverRecordChanged` (mises à jour de stats/scores/roster silencieusement perdues — seul `publierUtilisateur` était corrigé depuis la revue 2.3).
- **Mappings extraits en fonctions pures testables** (pattern `champsPublicsUtilisateur`) : `champsPublicsEquipe`, `champsPublicsEtablissement`, `champsPublicsJoueur`, `champsPublicsSeance` — la construction des records est désormais couverte par les tests sans appel CloudKit.
- **Périmètre `JoueurPartage` élargi (D6)** : publication + import de `statutDisponibiliteRaw` (validé contre l'enum à l'import — records publics non fiables), `consentementParentalAtteste`, `dateAttestationConsentement`, `attesteParNom`. Import via `appliquerDisponibilite` (branches update + création).
- **Tests** : +10 (suite `CloudKitSharingMappingsTests` 6 — dont garde « champsPublicsJoueur ne publie JAMAIS motDePasseHash/sel legacy » ; imports disponibilité 3 dans `CloudKitPartageImportTests` ; garde secret joueur 1 dans la suite sécurité). **286/286, 44 suites** ; build 0/0.

### E2 — Contenus de préparation ✅ 2026-09-01

- **feat(pivot-E2)** — 4 nouveaux record types Public DB : `ExercicePartage` (exercices de séance AVEC dessins/éléments/étapes), `StrategiePartagee`, `ScoutingPartage`, `BibliothequePartagee`. Nouveau fichier `CloudKitSharingService+Preparation.swift` (mappings purs + publier/importer, `#if DEMO return` sur chaque publierX).
- **Volumes (PencilKit)** : champ binaire ≤ 500 Ko → bytes inline ; > 500 Ko → `CKAsset` (fichier temporaire nettoyé après save) ; l'import accepte les deux représentations, plafond 15 Mo à la lecture (`lireChampBinaire`).
- **Sweep coach élargi** (`publierMisesAJourCoach`) : exercices des séances (via `seance.exercices`, incrémental par la nouvelle `Exercice.dateModification`), stratégies, scoutings, bibliothèque (items non prédéfinis des coachs de l'équipe, record par couple item×équipe — un coach multi-équipes publie sous chaque code). Import via `importerContenusPreparation` (APRÈS les séances, pour le rattachement des exercices — orphelin = repris au cycle suivant).
- **`dateModification` additifs CloudKit-safe** : `Exercice`, `ExerciceBibliotheque`, `ScoutingReport` (+ bumps aux points d'édition : signatures de contenu `onChange` dans ExerciceDetailView/BibliothequeDetailView/ScoutingReportView/StrategieDetailView [le terrain n'était PAS couvert par les bumps existants], `persisterTout` scouting). **L'archivage bump désormais** (4 sites : séances, matchs, stratégies, scoutings) et le sweep publie aussi les archivées → l'archivage se propage entre coachs (le filtre `!estArchivee` du sweep Seance est retiré).
- **Bibliothèque côté lecture** : le filtre de `BibliothequeView` montre aussi les items des AUTRES coachs de l'équipe active (la bibliothèque d'équipe = les bibliothèques de ses coachs).
- **Arbitrages (conservateurs)** : (1) **`joueursData` du scouting JAMAIS publié** — évaluations nominatives de joueurs adverses = PII évaluative en base world-readable ; seul le contenu tactique d'équipe se partage (forces/faiblesses/stratégies/tendances/zones). Un record public portant `joueursData` n'est pas importé (test de régression). À revisiter si chiffrement ou partage privé. (2) **`estFavori` non synchronisé** (préférence personnelle). (3) `pagesMatch` (notes terrain de match) hors périmètre E2 — non listé au plan.
- **Limite connue** : le bump par signature `onChange` peut ré-horodater un contenu réimporté pendant que sa vue est ouverte (écho borné, contenu identique) — les règles de merge E4 documenteront.
- **Tests** : +13 (`CloudKitPartagePreparationTests` — binaires inline/asset/round-trip, mappings, gardes joueursData/estFavori, rattachement exercice piège #16, orphelin no-op, merges, dédup bibliothèque multi-équipes). **299/299, 45 suites** ; build 0/0.

### E3 — Analyse ✅ 2026-09-01

- **feat(pivot-E3)** — 3 nouveaux record types : `StatsMatchPartage` (box scores, fetch-puis-modifier + merge `dateModification` via nouveau champ additif `StatsMatch.dateModification`), `PointMatchPartage` (points live IMMUABLES — création seule à l'import, type d'action validé contre l'enum, jamais de fallback fabriqué), `FormationPartagee` (formations perso, **dédup par clé fonctionnelle** type×rotation×mode×équipe : deux coachs qui personnalisent la même rotation ne créent pas de doublon, dernier écrivain gagne). Nouveau fichier `CloudKitSharingService+Analyse.swift`.
- **Volumes PointMatch (jamais de re-sweep complet)** : publication par LOTS de 400 (`modifyRecords`, savePolicy `.allKeys` — points immuables, écrasement idempotent, échec partiel ⇒ le sweep échoue et le seuil n'avance pas) ; sweep incrémental par `horodatage > seuil` ; import incrémental borné au `horodatage` max local (requête `codeEquipe + horodatage`) avec pré-chargement des IDs locaux (pas un fetch par record).
- **D6 mode déconnecté respecté** : le sweep saute stats+points quand `modeMatchActif` (paramètre passé par ContentView depuis `CloudKitSyncService`) ; la publication in-game se fait à la SORTIE du live — `publierAnalyseMatch` appelé au `onDisappear` de `MatchLiveSplitView` et à la finalisation (`MatchDetailView`), avec **purge des fantômes** (points annulés après une publication précédente : diff remote/local par seanceID → suppressions). Gate rôle coach/admin pour l'instant (E4 étendra aux assistants).
- **`statsEntrees` ajouté au miroir `SeancePartagee`** (l'assistant voit le chip « Analyse » d'un match finalisé) ; `finaliserStats` bump désormais `stat/joueur/seance.dateModification` ; la cascade de suppression de match (MatchsView) bump `joueur.dateModification` (cumuls corrigés republiés).
- **Refactor** : `fetchRecords(type:predicate:)` extrait (interne au service) pour les requêtes par seanceID/horodatage.
- **Actions schéma CloudKit (ASC, au premier déploiement)** : `seanceID` QUERYABLE sur `PointMatchPartage` (purge fantômes), `horodatage` QUERYABLE/SORTABLE sur `PointMatchPartage` (import incrémental), `codeEquipe` QUERYABLE sur les 7 nouveaux types E2/E3.
- **Limites connues (documentées)** : un fantôme déjà importé par l'assistant avant sa purge remote reste local (rare : annulation APRÈS une publication ; réconciliation par diff = E4+) ; les StatsMatch/PointMatch d'un match supprimé côté coach restent en Public DB (le match archivé se propage et les masque).
- **Tests** : +8 (`CloudKitPartageAnalyseTests` 7 — lots, mappings stats/points, immuabilité + rejet type inconnu, formations dédup par clé ; `FinalisationMatchTests` +1 — bumps E3). **307/307, 46 suites** ; build 0/0.

### E4 — Écriture assistant ✅ 2026-09-01

- **feat(pivot-E4)** — `CloudKitSharingService.planSync(role:)` (fonction pure) : TOUS les rôles coach (`.admin`/`.coach`/`.assistantCoach`) **importent PUIS publient** par les MÊMES chemins (`syncDepuisPublic` → `publierMisesAJourCoach`) ; `.etudiant` (legacy) reste lecture seule. `ContentView.synchroniserDonneesPartagees` refondu sur ce plan — le head coach IMPORTE désormais aussi (il reçoit les modifications de ses assistants). Gates de sortie de live (`MatchLiveSplitView`/`MatchDetailView`) étendus : le preneur de stats publie l'analyse quel que soit son rôle coach.
- **Règles de merge (documentées, D6 « dernier écrivain gagne »)** :
  1. **LWW par `dateModification`**, comparaison STRICTE (`remote > local`) — l'égalité est un no-op, ce qui neutralise le réimport de ses propres publications (anti-boucle, testé).
  2. **Import avant publication** dans chaque cycle : on tire le remote d'abord, on ne pousse que ce qui reste plus récent localement.
  3. **Baseline** : `derniereSyncDate = Date()` après l'import initial complet (`recupererEtImporterEquipe`) — le premier sweep d'un appareil qui vient d'importer ne re-téléverse pas l'équipe entière.
  4. **PointMatch immuables** : pas de LWW — création seule à l'import ; les fantômes (annulations) sont purgés par le preneur de stats à la sortie du live.
  5. **Horloges locales** : le LWW dépend des horloges d'appareils (skew possible) — assumé pré-lancement, à revisiter si litiges réels (horodatage serveur CloudKit).
- **Hors périmètre (notés)** : les lignes `Utilisateur` ne transitent qu'à l'import initial + publication (posture sécurité conservée — pas de rafraîchissement incrémental des comptes) ; le module Entraînement (ProgrammeMuscu/SeanceMuscu/TestPhysique) n'est pas dans le miroir (non listé au plan E) — suivi ultérieur si la parité muscu devient réclamée.
- **Tests** : +3 (`CloudKitSharingPlanSyncTests` 2 — rôles bidirectionnels/lecture seule ; anti-boucle égalité joueur+séance 1). **310/310, 47 suites** ; build 0/0.

## 2026-09-01 — Revue adversariale du chantier E ⚠️

- Vérification indépendante de la livraison E : build 0/0 et **310/310 tests confirmés** — MAIS revue adversariale (5 lentilles × réfutation, 64 agents) : **54 trouvailles confirmées, 3 CRITIQUES, ~20 HAUTES** (spec complète : [Revue_Chantier_E.md](./Revue_Chantier_E.md)). Les tests passent car purs (mappings in-memory) — aucun n'exerce les ACL CloudKit, la concurrence multi-appareils ni les suppressions.
- Problème architectural central : E4 fait écrire tous les coachs sur les MÊMES records Public DB, incompatible avec les ACL (créateur-seul) — sweeps assistants en échec permanent OU ouverture au tampering mondial. + résurrections (aucune suppression propagée), PII de mineurs world-readable (santé/attestation, E1), purge des fantômes destructrice, fenêtres du seuil global.
- **Chantier E GELÉ en attente de décision fondateur** (kill-switch vs revert vs fix-forward). La PR vers main attend cette décision.
- Pendant la revue : D vague 1bis avancée — `8cf1e08` (« Fermer » .cancellationAction ×14, 4 empty states pleine-zone en ContentUnavailableView) + `aea55a8` (3 formulaires de création en Form). 310/310 maintenus.

## 2026-09-01 — E′ : refonte de la sync (fix-forward, option C) ✅ noyau livré

- Décision fondateur : **option C** — corriger l'architecture avant la PR. Design figé : [Architecture_SyncEPrime.md](./Architecture_SyncEPrime.md) (7 sections), spec des problèmes : [Revue_Chantier_E.md](./Revue_Chantier_E.md).
- `bfc739f` **feat(pivot-E′)** — records PAR ÉCRIVAIN (`-w{ecrivainID}`, ancres equipe/etab mono-écrivain `.admin`) ; **chaîne de confiance par créateur** (`creatorUserRecordID` infalsifiable, racine = créateur de `equipe-<code>`, membres via couples invitation émis par la racine) ; **`EtatSyncEquipe`** (seuil par équipe capturé en début de sweep, avancé sur cycle complet seulement ; filigranes anti-écho ; borne `publieLe` des points) ; **tombstones `SuppressionPartagee`** publiés par les 6 cascades de suppression dure, appliqués en premier à l'import ; **binaires tri-état** (un échec CKAsset ne détruit plus jamais un dessin local) ; **mode match étanche** (aucune sync pendant le live, kill compris ; purge des fantômes restreinte à ses records) ; **PII minimale** (booléen `estDisponible` seul — motif santé + attestation parentale ne quittent plus l'appareil ; statut générique `.indisponible` à l'import) ; `#if DEMO` généralisé ; clamps + dédup StatsMatch par clé fonctionnelle.
- Les 3 CRITIQUES de la revue sont adressées (ACL multi-écrivains, résurrections de match, purge destructrice du live) + les familles HAUTES (écho, fenêtres de seuil, binaires, spoofing, PII).
- **Vérification** : build 0/0 ; **319/319 tests, 50 suites** (+9 SyncEPrimeTests : confiance, filigranes, tombstones, bornes, statut générique ; tests disponibilité/attestation réécrits en gardes PII inverses).
- **Contre-revue adversariale ciblée en cours** (4 axes) — corrections à suivre avant de déclarer E′ complet.
- ⚠️ Dashboard CloudKit (action humaine, mise à jour) : + type `SuppressionPartagee` (`codeEquipe` QUERYABLE) ; + `publieLe` QUERYABLE/SORTABLE sur `PointMatchPartage`.

## 2026-09-01 — E′ contre-revue & correctifs round 2

- Contre-revue adversariale ciblée (4 axes) de la refonte E′ → 45 trouvailles brutes (beaucoup en doublon inter-axes), **~11 bugs concrets distincts** + 1 cluster fondamental.
- `c5a3cea` **round 2** : correctifs CLEANEMENT résolubles — racine par recordID (anti-spoof), tombstones respectés pour joueurs/stats/formations/points, points filigranés, horodatage plafonné, identité d'écrivain à tous les sites de publication, ancres publiables par .coach, garde de taille totale du record (CKAsset), IO différée d'EtatSyncEquipe, **confiance transitive** (D6 — assistant ajouté par assistant), symétrie d'effacement des binaires scouting. **320/320, 50 suites**.
- **RÉSIDU documenté → décision fondateur requise** : [SyncEPrime_Residuel.md](./SyncEPrime_Residuel.md). Le cas coopératif est sain ; il reste un cluster ADVERSARIAL inhérent à la Public DB world-readable (le code d'invitation est un secret AU PORTEUR : qui a le code d'équipe peut usurper/altérer par LWW). Ne se corrige pas dans la Public DB (CKShare = migration Core Data). 3 postures : A accepter+durcir (reco PR), B rétrécir D6 (écriture assistant ciblée), C CKShare backlog.

## 2026-09-01 — Posture A + C actée, durcissements, PR

- **Décision fondateur : A + C.** Résidu adversarial accepté (documenté) ; CKShare au backlog du plan.
- Durcissements posture A : détection de **squat de l'ancre** `equipe-<code>` (créateur ≠ moi après save, ou `permissionFailure` sous ACL créateur-seul) → signalé au coach (`ancreUsurpee` + message), jamais un échec de sweep répété ; **pas de régénération de code** pour un assistant déjà rattaché (UI + garde).
- PR `pivot/coach-first` → `main` ouverte (voir lien dans le journal git / GitHub).

## Reste global

- **Action humaine (Dashboard CloudKit, avant prod du miroir élargi)** : champs QUERYABLE des nouveaux record types E2/E3 (`codeEquipe` partout ; `seanceID` + `horodatage` sur `PointMatchPartage`) + rôle d'écriture créateur-seul sur les nouveaux types (même posture que `docs/Securite_AbonnementPublicDB.md`).
- Rebase de `suivis/pr6` (démo) après le retour de la branche sur `main` (PR différée — GitHub indisponible le 2026-08-29).
- ✅ 2026-08-29 : refresh complet de `CLAUDE.md` — toutes les sections descriptives réécrites à l'état pivot (résumé, stack, navigation, tables de fichiers, conventions auth/rôles D6, design Mat Nuit, pièges 22/23/26 réécrits + 27 fetch-puis-modifier + 28 mode déconnecté, build/tests, état actuel) ; historique des patchs et section MCP préservés tels quels.
- Textes légaux externes (placeholders) à écrire sans athlètes ni abonnements ; reformulation complète attestation → collecte/vidéo.
- Action humaine n°1 : renseigner `TelemetryDeckAppID` (la rétention est le seul KPI de l'app gratuite).
