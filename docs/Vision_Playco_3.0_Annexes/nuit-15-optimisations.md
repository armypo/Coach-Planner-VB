# Optimisations de la roadmap Playco v2.2.x → v3.x

Analyse en lecture seule du repo (worktree `agitated-mcnulty-c2cefa`, base v2.2 PR #10) + roadmap `/Users/armypo/.claude/plans/si-tu-avait-a-typed-rossum.md` + `v3/MULTI_SPORT_PLAN.md` (commit `9912059`, Phase B) + branche `suivis/pr6` (flag DEMO).

---

## 1. Infrastructure qualité manquante — verdicts

### 1.1 Télémétrie produit (TelemetryDeck) — INDISPENSABLE, et beaucoup moins cher que prévu

**Découverte clé du repo** : `Playco/Services/AnalyticsService.swift` existe déjà — service `@Observable @MainActor` en mode logger-only volontaire, avec **17 événements catalogués** (`EvenementAnalytics` : `app_launched`, `paywall_affiche/ferme`, `achat_initie/reussi/echoue`, `essai_demarre/expire`, `restauration_tentee`, `equipe_creee`, `seance_creee`, `match_live_demarre`, `export_pdf_genere`, `erreur_critique`…), **9 call-sites déjà branchés** (PlaycoApp, PaywallViewModel, PaywallView, ConfigurationView), garde-fous Loi 25 codés (`clesInterdites` — jamais de nom, code équipe, courriel). Le commentaire d'en-tête dit explicitement : « le point d'injection est `initialiser()` / `suivre(...)` — un seul appel à brancher ».

- **Effort réel : 1-2 j** (SPM TelemetryDeck/SwiftClient + App ID + 1 ligne dans `initialiser()` + mise à jour du privacy nutrition label ASC + no-op garanti sous flag DEMO).
- **Où** : **2.2.x, AVANT le lancement App Store** (nouveau patch **2.2.0** ou premier item de 2.2.1). Argument décisif : le GO/NO-GO de 2.11 exige la **rétention pilote** — la rétention se mesure en cohortes sur des mois. Branché seulement en 2.11, tu n'as ni baseline pré-vidéo ni historique. Branché au lancement (juillet 2026), tu as 6+ mois de baseline quand la décision tombe (mars-avril 2027).
- **Coût récurrent** : gratuit jusqu'à 100 000 signaux/mois (une base de dizaines de coachs en consomme <5 %). Pas d'IDFA, conforme Loi 25 — cohérent avec le service existant.
- **Note doctrine** : c'est la première dépendance externe, mais la doctrine « zéro dépendance » tombe de toute façon en 2.7 (supabase-swift). L'en-tête d'AnalyticsService qualifie déjà ce branchement de « décision produit, pas dette de code ».

### 1.2 Crash reporting — INDISPENSABLE en version légère, Sentry REPORTABLE à 2.7

Aucun MetricKit/Sentry/Crashlytics dans le repo.

- **Au lancement (2.2.x, 1-2 j)** : `MetricKit` natif (`MXCrashDiagnostic`) — zéro dépendance, wrapper de ~80 lignes qui logge les diagnostics dans un buffer style `JournalSyncStorage` + les remonte via `AnalyticsService.suivre(erreurCritique)`. Complète Xcode Organizer (crashs opt-in des utilisateurs TestFlight/App Store), qui existe déjà gratuitement — pour un pilote de 5-10 équipes c'est suffisant.
- **À 2.7 (décision différée)** : réévaluer sentry-cocoa quand Supabase entre (le pipeline vidéo a des modes d'échec silencieux : upload, webhook, Realtime — et les Edge Functions peuvent rapporter au même projet Sentry). Free tier 5k events/mois. Ne pas l'ajouter avant : la doctrine zéro-dép pré-lancement tient encore, et l'app n'a pas de crash connu (253 tests verts).

### 1.3 CI (GitHub Actions ou Xcode Cloud) — INDISPENSABLE en version minimale

État du repo : **aucun `.github/workflows`, aucun `fastlane/`, et aucun scheme partagé** (`Playco.xcodeproj/xcshareddata/xcschemes` vide — le scheme « Playco » est dans xcuserdata : c'est un pré-requis bloquant de 5 minutes avant toute CI).

- **Périmètre minimal (2-3 j, patch 2.3 « fondations discrètes » — c'est littéralement une fondation discrète)** :
  1. Partager le scheme.
  2. Un workflow PR : `xcodebuild build` + `xcodebuild test -parallel-testing-enabled NO` sur simulateur iPad (toolchain stable 26.x — la commande exacte et validée est déjà dans CLAUDE.md).
  3. **Build de la configuration DEMO dans le même workflow** — la roadmap exige « test de compilation DEMO dans la checklist de chaque release » (politique démo §2) et trois patchs portent des risques de compilation DEMO explicites (2.3 « vérifier que le flag DEMO compile le chemin », 2.7 « compiler les cibles sans SDK actifs », 2.10 « ne pas casser la compilation DEMO »). La CI transforme cette checklist manuelle récurrente en garde automatique — c'est le meilleur retour sur investissement de toute l'infra qualité vu le nombre de rebases de `suivis/pr6` prévus (un par patch mineur).
- **Choix de plateforme** : deux options valables — (a) **Xcode Cloud** : 25 h de calcul/mois incluses dans l'adhésion Apple Developer, signing/TestFlight intégrés, zéro secret à gérer ; (b) **GitHub Actions macOS** : runners à multiplicateur ×10 sur les minutes gratuites (~200 min macOS effectives/mois en privé, soit ~10 runs) puis ~0,08 $/min. Recommandation solo-dev : **Xcode Cloud pour la lane TestFlight, rien d'autre** — ou GH Actions si tu veux tout au même endroit que les PR. Un seul système, pas les deux.
- **Fastlane : REPORTABLE** (rejeté pour l'instant, voir §7) — les lanes screenshots/metadata ne paient qu'au multi-sport (matrice d'appareils × sports), exactement là où MULTI_SPORT_PLAN B.1 le proposait.
- **Coût récurrent** : 0 $ dans les deux options aux volumes solo-dev.

### 1.4 Snapshot tests — UTILE, ciblé, arrimé à 2.4 (pas avant)

Nuance importante : enregistrer des baselines AVANT la refonte Mat n'a aucun sens — 2.4 change intentionnellement tous les écrans, 100 % des snapshots casseraient « normalement ». La bonne mécanique :

- **Pendant 2.4 (nouveau patch 2.4.2, 3-4 j)** : poser pointfreeco/swift-snapshot-testing (compatible Swift Testing, déjà identifié dans MULTI_SPORT_PLAN B.3), enregistrer la baseline **post-Mat** sur 10-15 écrans clés (Aujourd'hui/hub, PaywallView, TableauBord, StatsLive courtside, JoueurDetail, Composer quand il existera…), simulateur épinglé (iPad Pro 13" OS 26.5, celui des tests actuels), `perceptualPrecision ~0.98`, portrait+paysage + 2 tailles Dynamic Type. Ces baselines protègent ensuite 2.5, 2.6 et la vague 2 (3.0) contre les régressions non intentionnelles — précisément les patchs qui « réorganisent sans réécrire ».
- **En complément quasi gratuit, dans 2.4 lui-même** : des **tests unitaires de contraste sur les tokens** (`TokensMatTests` : ratio WCAG calculé en Swift pur, encre/papier ≥ 4,5:1, courtside ≥ 7:1, 2 modes Papier/Ardoise). La roadmap exige « 10 lois vérifiables en revue » et « audit contraste 2 modes » — un test unitaire est la forme la plus vérifiable qui soit, zéro dépendance, ~1 j.
- **AccessibilitySnapshot : REJETÉ** — bibliothèque UIKit-centrique ; préférer `XCUIApplication.performAccessibilityAudit()` natif (Xcode 15+) sur 3-4 flows si un target UI tests est créé un jour, sinon garder l'audit VoiceOver humain déjà planifié (reliquat W4).
- **Pas de Git LFS** tant que les PNG restent < quelques Mo (précision perceptuelle réduit leur poids).

**Budget infra qualité total : ~7-10 j.** Financement : les 3-4 j économisés au §5 (efforts surestimés) + la fenêtre « 2.2.5+ correctifs au fil de l'eau » qui absorbe les items 2.2.x. Net sur H1 : ~+1 semaine, à prendre sur la marge d'éjection de 2.6/2.7 déjà prévue.

---

## 2. Ordonnancement — chemin critique et parallélisations

**Chemin critique actuel vers le GO/NO-GO** : 2.7 → 2.7.1 → 2.8 (prérequis C4) → 2.8.2 → 2.9 → 2.9.2 → 2.10 → 2.11 (pilote). Trois optimisations le raccourcissent ou le sécurisent :

1. **Découpler le pilote du paywall (gain : 1,5-2 sem de données pilote)**. Le GO/NO-GO mesure rétention + minutes filmées + coût infra — aucune de ces métriques n'exige que le paywall Élite soit en vente. **Démarrer le pilote dès la fin de 2.9.2** avec la vidéo offerte aux équipes pilotes (TestFlight + flag), et livrer 2.10 EN PARALLÈLE du pilote qui tourne. 2.11 (durcissement) reste avant tout élargissement au-delà des pilotes.
2. **Shift-left des tests RLS : de 2.11 vers 2.7.** Écrire les « tests RLS automatisés par rôle » en même temps que les policies (Phase 0, deny-by-default), pas 4 patchs plus tard. Une policy écrite sans son test en 2.7 et corrigée en 2.11 = re-travail + fenêtre d'exposition pendant tout le pilote. Coût nul (le même travail, déplacé) ; 2.11 garde le pen-test/`/security-review` et l'UGC.
3. **Sortir les actions humaines Supabase/Cloudflare de 2.7** (voir §6) : ce sont des tâches de compte/DNS/secrets sans code, à faire pendant 2.4-2.5 pour que 2.7 démarre sans attente. Bonus : le compte **Cloudflare sert dès 2.3** — le QR/lien universel `playco.app/join/...` exige un fichier AASA servi avec le bon content-type sur playco.app, et l'entitlement `com.apple.developer.associated-domains` est **absent de l'entitlements actuel** (vérifié). Le site docs/ est un Jekyll (GitHub Pages), qui sert mal les AASA : mettre Cloudflare devant le domaine règle 2.3 ET prépare 2.7.

**Parallélisations confirmées (tâches « design/contenu » pendant les patchs « code »)** :
- **Glyphes 2.4 dessinés pendant 2.3** : les 5 glyphes tab bar (2-4 j de dessin sur grille optique SF) sont du travail de design sans dépendance au code de 2.3 — les avoir prêts fait de 2.4 un patch d'intégration pure.
- **2.6.4 (25 exercices) démarre immédiatement**, pas à 2.6 : c'est du contenu (diagrammes + textes), c'est la fondation de la démo vide, et c'est parfait pour les semaines fragmentées de 2.2.5+. **Contrainte technique à imposer dès maintenant : auteur les 25 diagrammes en éléments vectoriels uniquement (elementsData), zéro encre PencilKit** — ainsi ils héritent automatiquement du rendu « Le Trait » en 3.0 au lieu d'être redessinés.
- **Recrutement pilote pendant 2.6-2.7** (voir §6 — le consentement parental vidéo a le plus long lead time de toute la roadmap).
- **Ordre 2.4 ↔ 2.5 : ne pas toucher.** L'inversion ne gagne rien (les composants Mat gardent leurs signatures, donc 2.5 hériterait du look de toute façon), et construire la nav dans l'ancien langage visuel créerait du churn.
- **Micro-réordonnancement H2** : 2.8.1 (lecteur) ne dépend que de 2.7.1, pas de 2.8 — si le mode exécution glisse, livrer la lecture d'abord (testée sur vidéos importées) garde le pipeline vidéo sur le chemin critique.

---

## 3. Instrumentation du GO/NO-GO — les signaux à poser

Le GO/NO-GO 2.11 = « rétention pilote + infra ≤ 40 % du delta Élite−Pro ». Deux canaux distincts :

**Canal 1 — TelemetryDeck (comportement).** 8 signaux, dans l'ordre où les patchs les créent :

| # | Signal | Métadonnées (agrégées, jamais de PII) | Patch |
|---|---|---|---|
| 1 | `app_lancee` (déjà câblé) → rétention J1/J7/J30 auto par TelemetryDeck | rôle (coach/athlète), demo=false | **2.2.x** (branchement du backend) |
| 2 | `seance_creee` / `match_live_demarre` (déjà catalogués) → activation coeur | — | 2.2.x |
| 3 | `execution_demarree` / `execution_terminee` | durée min arrondie, nb exercices cochés/sautés | 2.8 |
| 4 | `video_capture_terminee` | minutes arrondies (→ « minutes filmées », l'axe quota) | 2.7.1 |
| 5 | `video_upload_reussi` / `video_upload_echoue` | classe de taille, nb reprises, wifi/cellulaire | 2.7.1 |
| 6 | `clip_lu_coach` | source (Aujourd'hui/fiche exercice) | 2.8.1 / 2.9 |
| 7 | `clip_vu_athlete` / `clip_partage` | — (la métrique de VALEUR : filmer sans que personne regarde = churn assuré) | 2.9.2 |
| 8 | `paywall_elite_affiche` / `achat_elite_reussi` / `quota_minutes_atteint` | trigger (`SeuilUpgradeService`) | 2.10 |

Critères chiffrés suggérés pour 2.11 : ≥ 60 % des équipes pilotes filment ≥ 2 pratiques/sem après 4 semaines ; ≥ 50 % des clips ont ≥ 1 vue athlète ; rétention coach J30 pilote ≥ baseline non-vidéo.

**Canal 2 — coût infra (côté serveur, PAS TelemetryDeck).** À poser dans les migrations SQL de 2.7 Phase 0 : table `usage_mensuel` + job `pg_cron` mensuel qui agrège minutes stockées/streamées par abonnement (API Cloudflare Stream + usage Supabase). Le ratio santé (coût/abonné ÷ (399−249)) devient une requête SQL, pas une lecture manuelle de deux dashboards en mars 2027. Coût : ~0,5 j dans un patch qui écrit déjà des migrations et un pg_cron de purge.

---

## 4. Dérisquage précoce — spikes ≤ 1 semaine

| Spike | Quand | Durée | Ce qu'il dérisque |
|---|---|---|---|
| **S1 — TUS upload background réel sur iPad** | avant 2.7.1 (idéalement fenêtre 2.6) | 3-4 j | LE risque n°1 du pari : URLSession background + TUS maison vers Cloudflare Stream, app tuée/écran verrouillé/wifi de gymnase faible, fichier HEVC de 60-90 min. Inclut 90 min de capture AVFoundation continue sur iPad physique (thermique, espace disque, interruptions). Si échec → le produit devient « importer à la maison », le pitch et le quota changent — il faut le savoir AVANT d'écrire `FileAttenteUploadVideo`. |
| **S2 — AASA / lien universel** | avant 2.3 | 0,5-1 j | playco.app sert-il un `apple-app-site-association` valide (hébergement Jekyll/GitHub Pages actuel = douteux) ? Entitlement associated-domains absent aujourd'hui. QR → SIWA → jonction en 1 geste validé sur iPad physique. |
| **S3 — 2 glyphes maison bout-en-bout** | pendant 2.3 | 1-2 j | La chaîne complète (dessin grille SF → SF Symbol custom → tab bar réelle → Dynamic Type/poids) sur 2 glyphes avant de s'engager sur les ~13 de la doctrine. C'est le début naturel du travail de dessin parallélisé (§2). |
| **S4 — rendu « Le Trait » sur le Canvas existant** | opportuniste (fenêtre 2.4-2.5) | 2 j | Prototype du rendu plan d'architecte derrière le même `TypeTerrain` (TerrainVolleyView est un Canvas API pur, 26-72 = dimensions hardcodées identifiées) : lisibilité des jetons pleins/contour, perf. Double usage : matériel marketing/maquettes 3.0. |
| **S5 — latence Realtime en conditions gymnase** | replié DANS 2.7 Phase 1 | 1 j | Webhook Stream → Realtime → app sur LTE/wifi partagé ; calibre le fallback polling de 2.8.1. Pas un spike séparé : un critère d'acceptation de 2.7. |

S1 est non négociable ; S2 conditionne le contenu de 2.3 ; S3-S4 sont des paris à 2 jours qui évitent des semaines de refonte.

---

## 5. Réutilisation — corrections d'effort fondées sur le code réel

| Patch | Constat repo | Correction |
|---|---|---|
| **2.3.1** duplication d'étape « Continuer » | `TerrainEditeurViewModel.dupliquerEtapeActive` **existe déjà** (livré v2.2, ligne 267). Reste : le preset demi-terrain + la variante « arrivées→départs » sur les trajectoires | **4 j → 2-3 j** (surestimé) |
| **2.5.2** recherche globale | `RechercheGlobaleView.swift` : 271 lignes, complète — confirmé « déjà codée, invisible » | 3 j confirmé |
| **2.6.2** PDF plan de pratique | `PDFExportService` 345 lignes, 2 formats déjà livrés (match + plan de match scouting v2.2), pattern UIGraphicsPDFRenderer rodé, testé (`PDFExportServiceTests`) | **4 j → 2-3 j** (surestimé) |
| **2.8** mode exécution | Réutilisation massive non créditée : `SeanceLiveView` (574 lignes — chrono double timer, progression, navigation exercices, exactement le squelette demandé), `PresencesView` (196 lignes, présences en entrée), constantes courtside `LiquidGlassKit` | 2 sem devient confortable ; réutiliser SeanceLiveView comme gabarit explicite dans le patch |
| **2.8.2** tagging live | `PaveNumeriqueRapideView` (162 lignes) = le pattern exact cité | 1,5 sem confirmé |
| **2.9.1** annotation | `CanvasDessinView` (111) + `OverlayDessinView` (582) réutilisés sur frame figée | 1 sem confirmé |
| **2.7.1** file d'upload | **SOUS-ESTIMÉ.** Le « pattern JournalSyncStorage » est un buffer circulaire UserDefaults de 50 entrées — inadapté à une file d'uploads multi-Go reprennables : il faut des fichiers sur disque + index + reprise TUS après relance + gestion espace disque. C'est le morceau le plus dur du pari, compressé dans un patch de 1,5 sem qui contient AUSSI la capture AVFoundation et le service Stream | **1,5 sem → 2-2,5 sem**, OU maintenir 1,5 sem si le spike S1 a déjà produit le prototype TUS (l'argument pour S1) |
| **2.3** règle i18n | `Localizable.xcstrings` existe déjà (131 Ko) — l'outillage String Catalogs est en place, la « règle active » est de la discipline, pas de l'infra | 0 j d'infra |
| **2.10** paywall Élite | `Playco.storekit` + `PaywallViewModel` à états + `FeatureGating` + pièges #22 documentés : tout le harnais existe | 1,5 sem confirmé |
| **2.5.1** roster par collage | `CSVExportService` est **export-only** — le parsing d'import est à écrire (petit, mais ne pas croire qu'il existe) | inchangé |
| **2.6.3** migration Catégories→tags | Migration de données CloudKit-safe sur `CategorieExercice` existant + scoping codeEquipe : plausible mais c'est une VRAIE migration de données — prévoir le test de non-perte | 1,5 sem, marge fine |

Net : ~3-4 j économisés en H1, ~+0,5-1 sem à provisionner sur 2.7.1 (ou neutralisé par S1).

---

## 6. Actions humaines consolidées (seul Christopher peut les faire)

Classées par date limite ; les faire EN AVANCE de leur patch pour ne jamais bloquer un sprint en cours.

| # | Action | Requis pour | Date limite | Lead time |
|---|---|---|---|---|
| H1 | Vérifier accords payants ASC signés + statut produits v2 « Prêt à soumettre » (reliquat v2.0.1) | Lancement | immédiat | heures |
| H2 | Action Dashboard CloudKit : Security Roles creator-write (documentée `docs/Securite_AbonnementPublicDB.md`) | Lancement | immédiat | heures |
| H3 | Compte TelemetryDeck + App ID (si retenu §1.1) | 2.2.x | avant le lancement | 15 min |
| H4 | Choix CI : activer Xcode Cloud dans ASC OU secrets GH Actions | 2.3 | début 2.3 | 1 h |
| H5 | Domaine playco.app : DNS derrière Cloudflare (compte gratuit) + AASA hébergé ; même compte réutilisé pour Stream en 2.7 | 2.3 (QR) puis 2.7.1 | avant 2.3 | 0,5 j |
| H6 | Entitlement associated-domains ajouté au provisioning (portail développeur) | 2.3 | avec H5 | 1 h |
| H7 | Page de rétention/consentement mineurs publiée sur le site docs (Jekyll existant, `docs/legal/`) | 2.2.3 | avec 2.2.3 | 0,5 j |
| H8 | Projet Supabase prod + provider Apple (Service ID + clé .p8) + org | 2.7 | pendant 2.4-2.5 | 0,5 j |
| H9 | Cloudflare Stream activé + facturation + clé API + secret webhook | 2.7/2.7.1 | pendant 2.4-2.5 | 0,5 j |
| H10 | Coffre de secrets (xcconfig non versionné / CI secrets) : clés Supabase anon, Stream, webhook | 2.7 | avant 2.7 | 0,5 j |
| H11 | **Recrutement pilote 5-10 équipes + formulaires de consentement parental vidéo (mineurs)** — le plus long lead time de la roadmap : écoles/clubs, saison, parents. Matériel bêta existant réutilisable (`docs/beta/onboarding-email.md`, `formulaire-nps.md`) | 2.11 (pilote), démarrage effectif dès 2.9.2 (§2.1) | **entamer à 2.6, signé avant décembre 2026** | semaines→mois |
| H12 | iPad physique : capture 90 min (thermique/disque, spike S1), scan QR réel (S2), VoiceOver reliquat W4 + Dynamic Type sur le look Mat | S1/S2/2.4 | fenêtres des spikes | 1 j cumulé |
| H13 | Produits ASC `entraineur.*` + `elite.*` + quota minutes décidé + fiches/screenshots + message grandfathering early adopters | 2.10 | créer dès 2.9 (latence review ASC) | 1 j + latence Apple |
| H14 | Compte Sentry (si décision 2.7 positive, §1.2) | 2.7 | début 2.7 | 15 min |
| H15 | DUNS/Stripe/contrat club | 2.10.1 | **aucune** — n'ouvre qu'au premier contrat réel (déjà la doctrine) | — |

---

## 7. Synthèse

### Optimisations retenues

| # | Optimisation | Patch cible |
|---|---|---|
| R1 | Brancher TelemetryDeck sur l'`AnalyticsService` existant (1-2 j, 9 call-sites déjà câblés) — baseline rétention indispensable au GO/NO-GO | **2.2.x avant lancement** |
| R2 | Crash reporting minimal MetricKit natif (zéro dépendance, 1-2 j) | 2.2.x |
| R3 | CI minimale : scheme partagé + build/test PR + **build de la config DEMO** (remplace la checklist manuelle de compilation DEMO répétée à chaque patch) | 2.3 |
| R4 | Snapshot tests ciblés (10-15 écrans, baseline POST-Mat) + tests unitaires de contraste des tokens (les « 10 lois » rendues exécutables) | 2.4.2 (nouveau) + 2.4 |
| R5 | Pilote découplé du paywall : démarre dès 2.9.2 avec vidéo offerte aux pilotes ; 2.10 livré en parallèle (+1,5-2 sem de données pilote) | 2.9.2 / 2.10 |
| R6 | Tests RLS écrits AVEC les policies (shift-left de 2.11 vers 2.7) | 2.7 |
| R7 | Actions humaines Supabase/Cloudflare avancées à la fenêtre 2.4-2.5 ; Cloudflare dès 2.3 (AASA du QR — entitlement et hébergement absents aujourd'hui, vérifié) | 2.3 / 2.4-2.5 |
| R8 | Spike S1 TUS/capture background sur iPad physique (3-4 j) avant d'écrire 2.7.1 — risque n°1 du pari | fenêtre 2.6 |
| R9 | Spikes S2 (AASA, 1 j), S3 (2 glyphes bout-en-bout, pendant 2.3), S4 (Le Trait, 2 j opportuniste) | 2.3 / 2.4-2.5 |
| R10 | 2.6.4 démarre immédiatement + contrainte « diagrammes 100 % vectoriels, zéro encre PencilKit » pour re-skin automatique par Le Trait en 3.0 | continu dès 2.2.x |
| R11 | Recrutement pilote + consentements parentaux entamés à 2.6 (lead time le plus long de la roadmap) | 2.6 → 2.11 |
| R12 | 8 signaux GO/NO-GO posés au fil des patchs (tableau §3) + table `usage_mensuel` et pg_cron coût infra dans les migrations 2.7 Phase 0 (le ratio ≤ 40 % devient une requête SQL) | 2.2.x → 2.10 |
| R13 | Corrections d'effort : 2.3.1 → 2-3 j, 2.6.2 → 2-3 j (surestimés) ; 2.7.1 → +0,5-1 sem OU couvert par S1 (sous-estimé) ; réutiliser explicitement `SeanceLiveView` comme gabarit de 2.8 | 2.3.1 / 2.6.2 / 2.7.1 / 2.8 |

### Optimisations rejetées

| # | Rejet | Raison |
|---|---|---|
| X1 | Fastlane complet (lanes screenshots/metadata/release) | YAGNI solo-dev mono-sport : l'upload ASC manuel prend 15 min/release ; ne paie qu'à la matrice multi-sport (là où MULTI_SPORT_PLAN B.1 le plaçait). Réévaluer au signal d'achat multi-sport. |
| X2 | Sentry dès le lancement | Doctrine zéro-dépendance encore valable pré-2.7 ; Organizer + MetricKit suffisent pour un pilote ; décision différée à 2.7 (H14). |
| X3 | CloudKitSyncMonitor (remplacement du journal sync) | Le `JournalSyncStorage` maison vient d'être durci (batché v2.1) et fonctionne ; remplacer = risque sans gain utilisateur. |
| X4 | AccessibilitySnapshot | UIKit-centrique ; `performAccessibilityAudit()` natif ou audit humain W4 couvrent mieux SwiftUI, à coût nul en dépendances. |
| X5 | Snapshots exhaustifs de tous les écrans / baselines pré-2.4 | 100 % des baselines pré-Mat cassent intentionnellement à 2.4 ; la maintenance des snapshots pendant une refonte active coûte plus qu'elle ne protège. Ciblé post-Mat seulement (R4). |
| X6 | Inverser 2.4 et 2.5 | Gain nul (signatures des composants préservées = la nav hérite du look dans les deux ordres) ; construirait la nav dans l'ancien langage visuel. |
| X7 | Runner CI self-hosted sur le Mac de dev | Fragilité (même machine que le dev + builds Xcode concurrents) ; les quotas gratuits hosted suffisent au volume solo. Option de repli si dépassement seulement. |
| X8 | Git LFS pour les snapshots | Inutile sous quelques Mo de PNG ; complexité de clone pour rien. |
| X9 | Avancer la vidéo (2.7) avant 2.5/2.6 pour allonger le pilote | Violerait le garde-fou « démarre seulement si le lancement est stable » et le budget UN pari/an ; le gain de données pilote est déjà obtenu par R5 sans toucher à H1. |
| X10 | Télémétrie hand-rolled (POST direct API TelemetryDeck sans SDK) pour préserver la doctrine zéro-dép | Réinvention d'un client batché/retry éprouvé pour ~3 mois de pureté doctrinale que 2.7 abolit de toute façon. |

**Impact budget** : +7-10 j d'infra qualité en H1, financés par ~3-4 j d'efforts surestimés (R13) + la fenêtre 2.2.5+ ; H2 inchangé (R5/R6 déplacent sans ajouter) ; le chemin critique vidéo gagne 1,5-2 semaines de données pilote et perd son plus gros inconnu technique (S1) avant d'écrire la moindre ligne de la file d'upload.
