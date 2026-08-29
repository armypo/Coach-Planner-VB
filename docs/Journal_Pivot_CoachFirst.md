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

## Chantier E — Parité de sync assistant (D6) — À VENIR

Phasé E1→E4 (voir plan) : durcir les 4 `publierX` (fetch-puis-modifier), publier disponibilité/attestation, puis contenus de préparation, analyse, écriture assistant. Le plus gros chantier technique restant — session dédiée recommandée.

## Reste global

- Rebase de `suivis/pr6` (démo) après le retour de la branche sur `main` (PR différée — GitHub indisponible le 2026-08-29).
- Refresh complet de `CLAUDE.md` (sections paywall/messagerie/athlète périmées) — ligne d'historique ajoutée en attendant.
- Textes légaux externes (placeholders) à écrire sans athlètes ni abonnements ; reformulation complète attestation → collecte/vidéo.
- Action humaine n°1 : renseigner `TelemetryDeckAppID` (la rétention est le seul KPI de l'app gratuite).
