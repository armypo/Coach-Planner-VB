# Pivot Coach-First — plan d'exécution (chantiers A-E)

> **Statut : approuvé fondateur (décisions D1-D6 actées le 2026-08-29).** Issu de l'analyse du 2026-08-26/29 (7 agents d'exploration + critique de complétude sur `suivis/pr6`, puis revue diff-par-diff des 25 commits de la boucle de nuit). Journal d'exécution : [Journal_Pivot_CoachFirst.md](./Journal_Pivot_CoachFirst.md). Remplace comme référence d'exécution la partie H1 restante de [Roadmap_Playco_v2.2_v3.x.md](./Roadmap_Playco_v2.2_v3.x.md) (archivée pré-pivot) ; le pari vidéo H2 reste valable, rejugé à la rétention seule.

## Le pivot (décision fondateur 2026-08-26)

1. **App gratuite « pour l'instant »** — plus de paywall. Fidélisation d'abord.
2. **Plus de comptes athlètes** — les athlètes redeviennent des DONNÉES (`JoueurEquipe`). Se connectent : head coach (`.admin`) + assistants (`.assistantCoach`), mêmes droits (D6).
3. Chaque écran se rejuge au critère unique : « qu'est-ce que ça donne au coach ? »

## Décisions fondateur actées (2026-08-29)

| # | Décision |
|---|---|
| D1 | Messagerie **retirée** (pas de repli « notes de staff »). `MessageEquipe` reste au schéma. |
| D2 | Suivi muscu par joueur **conservé** — sélecteur de joueur dans le mode live (le coach saisit au nom d'un athlète). |
| D3 | Paywall : **suppression complète** du code StoreKit (~2 100 l.). Restent au schéma : `Abonnement` @Model + `Equipe.tierAbonnementRaw`. |
| D4 | Boucle de nuit : **merge intégral** (tri diff-par-diff exécuté — aucun commit écarté, nettoyage ~1-1,5 j absorbé par A/B/D). |
| D5 | **Pas de campagne** d'invalidation des comptes athlètes publiés (pré-lancement). Seul verrou : `roleJonctionAutorise` → `.assistantCoach`. |
| D6 | **Assistant = head coach** : mêmes droits, seul le titre diffère → couche de différenciation supprimée (PermissionsRole, StaffPermissions UI, `estCoach`) ; **parité complète des données** entre coachs (chantier E), sauf pendant la prise de stats in-game (mode déconnecté = mode match existant). |

## Quatre réalités du code (garde-fous d'exécution)

1. **Les assistants sont `.assistantCoach`**, pas `.coach` (`.coach` = rôle résiduel, ne peut pas rejoindre une équipe ; rôle du coach DÉMO — `DemoBootstrap`). `.etudiant` reste décodable au schéma.
2. **La jonction athlète EST la jonction assistant** (MembreFactory → codeInvitation → Public DB → SIWA → `reclamerMembreLocal`) : on restreint, on ne supprime pas.
3. **Rien ne se supprime au schéma CloudKit** — 30 @Model conservés (`CredentialAthlete`, `Abonnement`, `MessageEquipe`, `StaffPermissions`, champs miroir de `Utilisateur`…). On cesse d'écrire.
4. **La porte athlète est côté client** — risque résiduel assumé par D5 (vieux builds + codes publiés).

## Chantier A — Suppression paywall + messagerie (3-4 j)

- **Supprimer** : `StoreKitService`, `AbonnementService` (extraire d'abord `migrerAssistantsVersNouveauRole`), `CloudKitPublicSyncAbonnement`, `PaywallViewModel`, `Views/Paywall/` (6 fichiers), `FeatureGating`, `TextesPaywall`, `IdentifiantsIAP`, `Playco.storekit` + références schemes + `StoreKit.framework` (pbxproj), les 10 sites de gate (`.bloqueSiNonPayant` ×9 dont `match_eclair`, `.bloqueSiNonClub` ×1), `BanniereAbonnementView`/`BienvenuePaywallView`/`sectionAbonnement`, `erreurGate` (code mort), les 8 événements analytics paywall, le bloc lecture `AbonnementPartage` de `+Import`.
- **Messagerie (D1)** : `MessagerieView`, `PolitiqueMessagerie` (+ 6 tests), bouton Messages du Dock + badges + `nbMessagesNonLus`.
- **Tests** : supprimer `PaywallViewModelTests`, `PaywallTextesTests`, `FeatureGatingTests` ; conserver `AbonnementCodeEquipeTests`.

## Chantier B — Retrait athlète (≈ 2 sem)

- **B1 comptes & jonction** : `MembreFactory` sans `joueur:` ; `NouveauJoueurView` → formulaire `JoueurEquipe` pur ; wizard étape 5 joueurs sans identifiants ; `roleJonctionAutorise` → `.assistantCoach` seul ; libellés LoginView/ChoixInitial « Assistant » ; `IdentifiantsEquipeView` réduit aux assistants ; section identifiants de `JoueurDetailView` retirée (avec son QR).
- **B2** : (réduit par D5) restriction de jonction seulement.
- **B3 surfaces** : `MonProfilAthleteView`, branches `.etudiant` (ContentView routing/sync, AccueilView), `masquerPratiquesAthletes` (+`ContenuMasqueView`+filtre publication), textes tutoriel ; **muscu (D2)** : sélecteur de joueur dans `SeanceLiveView`, retrait du gate « muscu suspendue » et du filtre « programmes assignés à moi ».
- **B4 permissions (D6)** : supprimer `PermissionsRole` (~45 sites), `StaffPermissions`/`GestionStaffView` côté UI, distinction `ProfilView.estCoach`, repli lecture seule du live. Prévoir « Inviter un assistant » dans ProfilView (via `LienInvitation`). Le coach DÉMO (`.coach`) doit continuer de fonctionner.
- **B5 nettoyages** : cascade suppression d'équipe complétée (Utilisateur, CredentialAthlete, Abonnement, PhaseSaison ; noter : Presence/Evaluation/TestPhysique sans `codeEquipe`) ; `EditionJoueurView`/`AvatarEditableView` cessent d'écrire les miroirs ; purge code mort (EvaluationView, SaisieStatsMatchView, clusters ProfilSubViews + ModifierUtilisateurView, StatsLiveSheetWrapper, publierModificationsEquipe) ; QR fiche joueur + grille projetable « Inviter l'équipe » (athlètes-only, commit 2.3).
- **B6 tests** : ~10 suites à refondre (RejoindreEquipe, CredentialAthlete, MultiUtilisateur, MembreFactory, CloudKitSharing ×2, UtilisateurIdentifiant…). Garde « jamais de secret en Public DB » conservée.
- **2.2.b conservés** : disponibilité joueur (pur coach), attestation parentale (base légale de la captation vidéo H2 — reformuler 2 textes), TelemetryDeck/MetricKit (la rétention est LE KPI de l'app gratuite).

## Chantier C — Déplacements navigation (≈ 1 sem)

| # | Déplacement |
|---|---|
| C1 | **Scouting → Matchs** (sidebar « Préparation », push ; « Préparer ce match » sur match à venir) |
| C2 | Toolbar match : 7 chips → 3 groupes (Préparer / En direct / Après) |
| C3 | Heatmap + Rotations quittent le bottomBar Matchs (hub Statistiques Équipe canonique ; versions pré-filtrées dans Analyse) |
| C4 | Calendrier → racine (Dock ou carte « Aujourd'hui ») ; Planification saison à côté |
| C5 | Dock persistant dans les sections + recherche en deep-link vers l'élément |
| C6 | Formations : entrée sidebar nommée dans Stratégies |
| C7 | Présences : bouton visible dans l'écran d'exercices de la séance |
| C8 | Exports regroupés dans le hub Statistiques |

## Chantier D — Uniformisation Mat Nuit (1-1,5 sem)

Top 10 (ordre) : 1. `BoutonRetourAccueil` extrait (6 duplications) · 2. **confirmation suppression de match** (cascade destructive au swipe !) · 3. « Fermer » standardisé (~20 sites) · 4. tints sections alignés (brique Matchs posée en 2.4) · 5. icône « + » unique (~46 sites) · 6. empty states → `ContentUnavailableView` (~20 ad hoc) · 7. sidebars homogènes (listStyle + searchable) · 8. formulaires de création → `Form` · 9. kit stats généralisé (`TableauStats`, `FiltresStats` branché ou supprimé) · 10. campagne paddings/rayons (8 pires fichiers, trancher l'échelle 10/14). Règle d'or : retraits (B) avant polissage.

## Chantier E — Parité de sync assistant — D6 ✅ E′ livré (2026-09-01), posture A + C

> **Issue** : la livraison E initiale a été invalidée par revue adversariale (54 trouvailles) → refonte E′ (option C fix-forward, [Architecture_SyncEPrime.md](./Architecture_SyncEPrime.md)) + contre-revue round 2. **Posture fondateur A + C** : le résidu adversarial ([SyncEPrime_Residuel.md](./SyncEPrime_Residuel.md) — code d'invitation = secret au porteur dans une Public DB world-readable, menace bornée par « connaît le code d'équipe ») est ACCEPTÉ et documenté, avec ACL créateur-seul (action Dashboard) + 2 durcissements (détection de squat de l'ancre `equipe-<code>`, pas de régénération de code pour un assistant rattaché) ; **CKShare (migration Core Data) inscrit au backlog** comme correctif inviolable post-lancement. Ne pas relancer de ronde de durcissement Public DB : plafond atteint par construction.

_(Plan d'origine ci-dessous, conservé pour trace.)_

Cible : tous les coachs voient et modifient les mêmes données, sauf pendant le live (un seul preneur de stats, mode match, sync à la sortie). SwiftData `.automatic` ne traverse pas les Apple ID ; CKShare non supporté par SwiftData → **élargir le miroir Public DB record type par record type, en bidirectionnel** (merge `dateModification`, pattern en place).

- **E1** : durcir la plomberie — généraliser le fetch-puis-modifier de `publierUtilisateur` aux 4 autres `publierX` (sinon les mises à jour de records existants échouent en silence) ; publier disponibilité + attestation.
- **E2** : contenus de préparation (exercices + dessins, stratégies, scouting, bibliothèque).
- **E3** : analyse (StatsMatch, PointMatch, formations perso).
- **E4** : écriture assistant (publication par les mêmes chemins) + règles de merge.
- Invariants : aucun secret en Public DB, volumes surveillés (PencilKit lourd), DÉMO isolée.

## Backlog (post-lancement)

- **CKShare / base partagée CloudKit** — le seul correctif INVIOLABLE au résidu E′ (écriture contrôlée par le serveur, membres invités par partage signé). Exige une migration SwiftData → Core Data (`NSPersistentCloudKitContainer` + partage) : chantier dédié, à planifier avec le backend vidéo H2. Tant qu'il n'est pas fait, la posture A s'applique.

## Séquence

1. ✅ Merge boucle de nuit (intégral — tri validé) → branche `pivot/coach-first` + annotation archives Vision/Roadmap.
2. Chantier A → 3. Chantier B → 4. Chantier C → 5. Chantier D → 6. Chantier E (E1 peut démarrer dès la fin de B).
Total ≈ 7-9 sem brutes (convention ×2). Rebase de `suivis/pr6` (démo) après le retour sur `main`. Action humaine n°1 : renseigner `TelemetryDeckAppID`.

## Risques suivis

1. Taxonomie des rôles (`.assistantCoach` vs `.coach` DÉMO). 2. Portes résiduelles côté données (assumé D5). 3. Migration CloudKit destructive par excès de zèle. 4. Sweep permissions → veiller au coach DÉMO et aux gardes « utilisateur connecté ». 5. Données orphelines (cascade équipe, comptes détachés).
