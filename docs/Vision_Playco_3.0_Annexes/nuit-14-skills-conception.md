# Skills projet Playco — outillage d'exécution de la roadmap v2.2.x → v3.x

**Livrable** : 5 skills projet (format `.claude/skills/<nom>/SKILL.md`, frontmatter `name` + `description`), ancrés dans le code réel du repo et la roadmap `/Users/armypo/.claude/plans/si-tu-avait-a-typed-rossum.md` (future `docs/Roadmap_Playco_v2.3_v3.x.md`). Format calqué sur les skills existants (`diagnose/SKILL.md` du worktree, `playco-release.md` d'Origotech) : impératif, checklists cochables, « Règles token » en fin de fichier.

**Architecture retenue** (pourquoi ces 5 et pas d'autres) :

| Skill | Rôle dans le cycle | Fréquence d'usage |
|---|---|---|
| `playco-patch` | Le **moteur** — dérouler un patch de la roadmap de bout en bout | À chaque patch (~30×/an) |
| `playco-mat-review` | La **gate design** — les 10 lois vérifiables, appelée par playco-patch dès v2.4 | À chaque patch touchant l'UI |
| `playco-demo-check` | La **gate démo** — politique DÉMO transversale de la roadmap | Post-merge de chaque patch |
| `playco-video-securite` | La **gate sécurité** du seul domaine serveur (v2.7→v2.11) | Chaque patch vidéo + chaque déploiement de policy |
| `playco-roadmap-status` | La **boussole** — réancrage inter-session sur des mois | Début de session |

**Non retenus** (jugement) : un skill i18n séparé (3 vérifs → intégré à `playco-patch` §checklist) ; un skill « supabase-migrate » (absorbé par `playco-video-securite` qui gate chaque déploiement) ; un skill onboarding-contexte générique (CLAUDE.md + auto-memory le font déjà ; `playco-roadmap-status` couvre le seul manque réel : *où en est-on*). Voir aussi la **mise à jour recommandée de `playco-release`** en fin de document.

---

## 1. `.claude/skills/playco-patch/SKILL.md`

````markdown
---
name: playco-patch
description: Exécuter un patch de la roadmap Playco (v2.2.x → v3.x) de bout en bout — prérequis, branche, périmètre, checklist de sortie (build 0/0, tests série, DEMO, CloudKit-safe, i18n, rebase suivis/pr6). Utiliser quand on dit « exécute le patch 2.x », « attaque v2.4 », « prochain patch de la roadmap ».
---

# Playco Patch

Déroule UN patch de la roadmap. Un patch = livrable seul, testable seul, baseline de tests préservée. Ne jamais mélanger deux patchs dans une branche.

## Phase 0 — Charger le patch

1. Lire la fiche du patch dans `docs/Roadmap_Playco_v2.3_v3.x.md` (tant que ce fichier n'existe pas : `/Users/armypo/.claude/plans/si-tu-avait-a-typed-rossum.md`). Extraire : **périmètre exact**, effort estimé, ligne « Impact démo ».
2. Vérifier les **dépendances explicites** de la roadmap : 2.8 avant 2.8.2 · 2.7 avant 2.8.1 · 2.10 après 2.9. Si le prérequis n'est pas mergé dans `main`, STOP — proposer le patch prérequis à la place.
3. Vérifier le **périmètre contre la liste « Coupés définitivement »** de la roadmap (anti-scope-creep). Si la demande déborde du périmètre du patch : refuser le débord, le noter pour un futur 2.x.y.
4. Gouvernance solo-dev : estimation roadmap ×2 déjà appliquée. Si en cours de route l'effort réel dépasse ~1,5× l'estimation → STOP, découper en sous-patch 2.x.y livrable, replanifier le reste (les garde-fous roadmap autorisent l'éjection de 2.6/2.7 vers H2).

## Phase 1 — Préparer

1. `main` à jour, worktree propre, baseline verte AVANT de commencer (commande en Phase 3 — le nombre attendu est dans CLAUDE.md, dernière ligne d'historique ; v2.2 : 253/253 sur main).
2. Créer la branche depuis `main` (une branche par patch).
3. **Relire les pièges CLAUDE.md pertinents au domaine touché** (section « ⚠️ Pièges connus ») :
   - Nouveau champ/@Model SwiftData → pièges **#4, #15, #16** (défauts obligatoires, relations optionnelles + inverses, `Seance.exercices ?? []`)
   - Stats/métriques → piège **#24** (`MetriquesVolley` source unique, échelles 0-1 vs 0-100, `AgregateurStatsMatch`, D6 zéro émoji)
   - Tests SwiftData → piège **#25** (`ModelConfiguration(cloudKitDatabase: .none)` sinon crash « No eligible connection available »)
   - CloudKit Public DB → piège **#26** (JAMAIS de credentials/PII ; `champsPublicsUtilisateur`)
   - Paywall/StoreKit → pièges **#22, #23** (états `PaywallViewModel`, `ctaAchatPrefixe`, `Abonnement.codeEquipe`)
   - UI/terrain → pièges **#2, #3, #12, #19** (kit de constantes — `LiquidGlassKit` aujourd'hui, kit Mat dès v2.4)
   - Logging → piège **#17** (`Logger`, jamais `print()`)
4. Si le patch touche l'UI et qu'on est ≥ v2.4 : garder `/playco-mat-review` pour la Phase 3.

## Phase 2 — Exécuter

- **TDD** : test d'abord quand une couture correcte existe (Swift Testing, pattern `MatchLiveViewModelTests` — schéma = fermeture transitive des relations, `cloudKitDatabase: .none`).
- **Migration CloudKit-safe** (règle absolue, pré-lancement ou pas) : tout nouveau champ `@Model` a une valeur par défaut SUR la déclaration ; on n'ENLÈVE jamais un champ du schéma (précédent : les champs `motDePasseHash/sel/iterations` conservés vides après SIWA strict) ; toute relation nouvelle est optionnelle avec inverse.
- **i18n (règle active dès v2.3)** : zéro chaîne UI en dur dans tout écran touché — les chaînes passent par `Playco/Resources/Localizable.xcstrings` (String Catalogs). Vérif rapide : relire les `Text("…")`/labels ajoutés dans le diff.
- **Gel du couplage volley (phase 0 SportPack, dès v2.3)** : aucune nouvelle référence volleyball en dur hors des 6 enums recensés au patch 2.3 (liste figée dans la roadmap/règle de lint à ce patch) ; les intitulés d'espaces restent sport-neutres.
- Commits conventionnels `<type>: <description>` (feat/fix/refactor/docs/test/chore/perf), sans attribution.

## Phase 3 — Checklist de sortie (TOUT doit passer avant PR)

- [ ] **Build 0 erreur / 0 warning** (toolchain stable Xcode 26.6, `xcode-select` par défaut) :
  ```bash
  cd "/Users/armypo/Documents/Origotech/Playco" && xcodebuild build -scheme Playco \
    -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5'
  ```
- [ ] **Tests : baseline + nouveaux, EN SÉRIE, sur la toolchain stable** (⚠️ ne PAS valider sur le runtime iOS 27 beta — régression SwiftData in-memory connue, CLAUDE.md) :
  ```bash
  xcodebuild test -scheme Playco \
    -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5' \
    -parallel-testing-enabled NO
  ```
- [ ] (Optionnel, si demandé) build croisé Xcode 27 beta via `DEVELOPER_DIR="/Users/armypo/Downloads/Xcode-beta.app/Contents/Developer"` — build seulement, pas les tests.
- [ ] **`/playco-mat-review`** sur les fichiers modifiés (dès v2.4). Avant v2.4 : piège #19 (constantes LiquidGlassKit, pas de magic numbers).
- [ ] **`/code-review`** ; **`/security-review`** si le patch touche auth, CloudKit public, paiement, ou le domaine vidéo (dans ce dernier cas : `/playco-video-securite`).
- [ ] **Impact démo traité** : relire la ligne « Impact démo » de la fiche patch et faire exactement ce qu'elle dit (inclusion vitrine, exclusion `#if DEMO`, masquage UI). Le détail s'exécute en Phase 4.
- [ ] `CLAUDE.md` : ligne d'historique ajoutée + sections impactées (modèles, vues, pièges si nouveau piège découvert).

## Phase 4 — Post-merge (politique DÉMO transversale)

1. Merger `main` dans **`suivis/pr6`** (la variante DEMO vit LÀ, pas dans main). En cas de conflit sur `CloudKitSharingService+Publication.swift` : garder la version pr6 (elle porte les gardes `#if DEMO`).
2. Lancer **`/playco-demo-check`** (compile Demo 0/0 + garde-fous).
3. Mettre à jour le statut du patch dans `docs/Roadmap_Playco_v2.3_v3.x.md` (✅ + date + écarts).

## Règles token
- La fiche patch de la roadmap fait foi pour le périmètre — ne pas relire les 330k chars d'annexes.
- CLAUDE.md pour l'architecture — ne pas re-explorer le codebase complet ; utiliser le graphe (`semantic_search_nodes`, `get_impact_radius`) avant Grep/Read.
````

---

## 2. `.claude/skills/playco-mat-review/SKILL.md`

````markdown
---
name: playco-mat-review
description: Audit design « Playco Mat » — vérifier les 10 lois (image fonctionnelle, accent unique, chiffres tabulaires, verre-chrome, papier, styles nommés, ombre unique, calme, redondance, gymnase AAA) sur les fichiers modifiés. Utiliser après tout patch UI dès v2.4, quand on dit « revue design », « audit Mat », « vérifie les lois ».
---

# Playco Mat Review

Vérifie les **10 lois de Playco Mat** (spec passe 2, juillet 2026 — reprises in extenso ci-dessous) sur les fichiers Swift modifiés. Les lois sont conçues pour être vérifiables mécaniquement en revue de code.

## Portée

- **Dès v2.4 (vague 1)** : s'applique à TOUT fichier touché par le patch courant. Le legacy non touché n'est PAS flaggé (migration progressive, jamais from scratch) — sauf demande de purge explicite.
- **À v3.0 (vague 2)** : s'applique à toute l'app, y compris courtside/terrain.
- **Avant v2.4** : ce skill ne s'applique pas — utiliser le piège #19 (LiquidGlassKit).
- Source des tokens : le kit central (`Playco/Helpers/LiquidGlassKit.swift` + `ThemeCouleurRole.swift` aujourd'hui ; le kit Mat qui rebase leurs corps **sans changer les signatures** dès v2.4 — tokens `fond/surface/surfaceCreuse/encre/encre2/encre3/filet`, accent `#3D5A80` par défaut). La liste canonique des glyphes vit dans `docs/Vision_Playco_3.0.md` §Playco Mat.

## Méthode

1. `git diff --name-only main...HEAD -- '*.swift'` → liste des fichiers à auditer.
2. Passer chaque loi ci-dessous : le grep donne les candidats, la lecture du contexte tranche (un grep-hit n'est pas automatiquement un défaut — ex. `Material` dans un commentaire).
3. Rapport final : tableau `Loi | Fichier:ligne | Constat | Sévérité | Correction proposée`. Sévérité : **BLOQUANT** = lois 1, 2, 4, 10 (explicitement bloquantes dans la spec) ; **HIGH** = les autres. Aucun merge avec un BLOQUANT ouvert.

## Les 10 lois (in extenso) + vérification

### Loi 1 — L'image fonctionnelle **[BLOQUANT]**
Toute `Image` est soit l'un des glyphes **fonctionnels** de la liste fermée, soit l'un des **8 glyphes d'outils d'éditeur** (BarreOutilsDessin — arbitrage C2), soit l'un des **5 glyphes de tab bar** maison. Toute autre occurrence (dont tout symbole accolé à un titre, toute icône d'état vide) est un défaut bloquant.
- Noyau de la liste fermée (12) : `chevron` (disclosure), `croix` (fermer), `plus` (créer), `partage`, `lecture/pause`, `recherche`, `coche`, `poubelle` (toujours avec le mot), `flèche retour`, `œil`, `cadenas` (verrouillage terrain), `personne` (avatar de secours) — extensions arbitrées C2 jusqu'à ~16 : liste canonique dans la Vision. Tout AJOUT à la liste passe par une revue de design, pas par un commit.
- Tab bar (5, symboles custom mono-trait 1,5 pt) : point du jour (Aujourd'hui), plan 2×3 (Préparer), terrain 2:1 (Coacher), trois ticks (Analyser), six points de rotation (Équipe) — toujours étiquetés.
- Rendu : `.symbolRenderingMode(.monochrome)` uniquement — le `.hierarchical` décoratif est déprécié.
- Vérif : `grep -n "Image(systemName:" <fichiers>` → chaque hit doit appartenir aux listes. `grep -n "symbolRenderingMode(.hierarchical)"` → défaut. Test mental : « masque l'image ; si l'écran perd une action, elle reste ; s'il reste compréhensible, elle disparaît ».

### Loi 2 — L'accent unique **[BLOQUANT]**
Aucune référence à `PaletteMat.orange/bleu/vert/violet` ni couleur hex inline dans une vue ; la seule couleur non neutre du contenu est `accentEquipe` (couleur d'équipe matifiée : saturation ≤ ~62 %, contraste ≥ 4,5:1 garanti) ; le rouge n'apparaît que via les tokens `live` (#D9382E) et `deltaNegatif`.
- **Exception C1 (la seule)** : les couleurs de poste sur les **jetons du terrain uniquement**, via `FormationType.couleurPourLabel` (central), matifiées + redondées par une forme. Toute couleur de poste hors terrain = défaut.
- Vérif : `grep -n "PaletteMat\.\|Color(hex:\|couleurRole" <fichiers Views/>` ; hits `couleurPourLabel` acceptés seulement sous `Views/Terrain/` et les mini-terrains.

### Loi 3 — Le chiffre tabulaire
Tout nombre susceptible d'être comparé à un autre (tableau, score, compteur, delta) porte `.monospacedDigit()` et s'aligne à droite dans les colonnes.
- Vérif : dans les vues stats/score modifiées, chaque `Text` affichant une valeur numérique passe par le token « Donnée »/« Score » du kit (ou `TypographieStats` existant) ; `grep -n "monospacedDigit" <fichiers>` pour confirmer la présence là où des colonnes existent.

### Loi 4 — Le verre-chrome **[BLOQUANT]**
`.glassEffect` et les `Material` sont interdits sur toute surface de **contenu** ; seuls la tab bar, les toolbars et les présentations système en portent.
- Vérif : `grep -n "\.glassEffect\|ultraThinMaterial\|thinMaterial\|regularMaterial" <fichiers>` → tout hit hors chrome système = défaut. (Rappel : les corps de `GlassCard`/`GlassSection`/`GlassChip` sont rebasés en surfaces opaques à v2.4 — un hit DANS le kit pendant la transition se juge sur le composant cible.)

### Loi 5 — Le papier
Aucun `Color.white`/`Color.black` direct ni gradient de fond dans les vues : uniquement les tokens `fond` (#F6F4F1 clair / #121110 sombre), `surface`, `surfaceCreuse` ; toute `surface` posée sur `fond` porte le filet 0,5 pt (`filet`, #E4E1DB / #2E2C28).
- Vérif : `grep -n "Color.white\|Color.black\|RadialGradient\|LinearGradient" <fichiers>` — les doubles RadialGradient d'ambiance (pattern AccueilView v2) doivent disparaître des écrans touchés. Exception : courtside utilise le noir pur DU TOKEN (loi 10).

### Loi 6 — Le style nommé
Aucun `.font(.system(size:))` hors du kit typographique ; chaque texte utilise un des 11 tokens (Affiche 40/44 · Score 76/76 · Titre 1 28/34 · Titre 2 22/28 · Corps 17/24 · Corps fort · Détail 15/20 · Donnée 15/20 tabulaire · Note 13/18 · Étiquette 11/13 MAJUSCULES +0,6 pt · Code SF Mono 15/20) ; `.rounded` et `.uppercased()` manuel sont interdits (les majuscules passent par le token Étiquette).
- Vérif : `grep -n "\.font(.system(size:\|design: .rounded\|\.uppercased()" <fichiers>`. SF Mono réservé aux codes équipe/invitation.

### Loi 7 — L'ombre unique
Seuls les éléments de niveau **flottant** (modales, popovers, pavé live) portent une ombre (`0.10/24/10`) ; toute autre `shadow` est un défaut (la profondeur vient du contraste papier + filet, ombre de surface quasi nulle `0.04/8/2` intégrée au kit).
- Vérif : `grep -n "\.shadow(" <fichiers>` → hors kit et hors flottant = défaut. Les doubles ombres de l'ancien GlassCard ne doivent pas réapparaître.

### Loi 8 — Le calme
Aucun `repeatForever`, parallaxe ou effet ambiant ; toute animation utilise l'un des trois springs du kit (défaut 0.35/0.85 · rebond 0.25/0.7 · douce 0.45/0.9) et **répond à une action** ; les valeurs changent par `.contentTransition(.numericText())`.
- Vérif : `grep -n "repeatForever\|\.easeInOut\|autoreverses" <fichiers>` ; toute `withAnimation` sans déclencheur utilisateur = défaut.

### Loi 9 — La redondance (daltonisme)
Aucune information portée par la couleur seule : nous/adversaire = **plein/contour**, victoire/défaite = pastille pleine/creuse **+ lettre V/D**, deltas = signes `+`/`−` **imprimés**, live = le mot « **DIRECT** ».
- Vérif : lecture manuelle des vues stats/match modifiées — chaque encodage couleur doit avoir son doublon de forme/signe/mot. Pas de grep fiable : c'est la revue humaine du skill.

### Loi 10 — Le gymnase **[BLOQUANT]**
En mode courtside : fond opaque **pur** (#000), contraste ≥ **7:1 (AAA)**, aucune opacité < 1, cibles ≥ **60 pt** (`LiquidGlassKit.boutonCourtside`), boutons **typographiques** (mots, ≥ 18-20 pt) — toute violation est bloquante avant merge.
- Vérif : dans les vues sous `modeBordDeTerrain` (`ModesBordTerrainContext.swift`) : `grep -n "opacity(0\.\|Material" <fichiers courtside>` = défaut ; contrôler les frames vs 60 pt ; à v3.0 le Score courtside passe à 96 pt.

## Règles token
- Auditer UNIQUEMENT le diff (+ le kit si modifié). La spec complète vit dans `docs/Vision_Playco_3.0.md` — ne la relire que pour trancher un cas limite.
````

---

## 3. `.claude/skills/playco-demo-check/SKILL.md`

````markdown
---
name: playco-demo-check
description: Checklist du build DÉMO Playco (branche suivis/pr6, flag compile-time DEMO) — compilation, bypass login/paywall/gates, isolation CloudKit, exclusions vidéo/Supabase, démo VIDE, garde-fou review. Utiliser après chaque merge dans main, avant tout TestFlight démo, quand on dit « vérifie la démo », « build démo ».
---

# Playco Demo Check

Le build DÉMO = vitrine bêta coachs, **sans login ni paywall, démarre VIDE** (décision Christopher 2026-07-04). Il vit sur la branche **`suivis/pr6`** (PAS dans main), condition de compilation Swift `DEMO`, config Xcode `Demo` (clone de Release, `SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEMO $(inherited)"`), scheme local « Playco Démo » (git-ignoré), même bundle id `Origo.Playco`, build number réservé `CURRENT_PROJECT_VERSION = 9004`.

## Étape 1 — Synchroniser

1. `git checkout suivis/pr6` puis merger `main` (c'est LE mécanisme pour que les fixes atteignent la démo). Conflit connu : `CloudKitSharingService+Publication.swift` → garder la version pr6 (gardes `#if DEMO`).
2. Inventorier les sites du flag : `grep -rn "#if DEMO\|#if !DEMO" Playco --include="*.swift"` — comparer à la liste attendue ci-dessous ; tout écart s'explique ou se corrige.

## Étape 2 — Compiler (les DEUX configs, 0 erreur / 0 warning)

```bash
cd "/Users/armypo/Documents/Origotech/Playco" && xcodebuild build -scheme Playco \
  -configuration Demo \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5'
xcodebuild build -scheme Playco \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5'
```
Tests en série sur pr6 (baseline pr6 ≥ baseline main ; v2.2 : 257/257) : même commande `test` avec `-parallel-testing-enabled NO`. Archive éventuelle : **Xcode 26.6 CLI uniquement** (blocage ASC sous Xcode beta — mémoire `playco-submission-macos27-beta`).

## Étape 3 — Les garde-fous mécaniques (vérifier chacun dans le code)

- [ ] **Login off** : `Playco/Helpers/DemoBootstrap.swift` (`#if DEMO`) crée-si-absent le coach `demo.coach` + équipe vide et route direct `.app` dans `PlaycoApp.verifierConfiguration()` ; la `Task` d'auth du `.onAppear` de `.app` est sous `#if !DEMO` (sinon `restaurerSession` écrase la session démo). `DemoBootstrap` reste compatible SIWA strict : `motDePasseHash: ""`, `appleUserID` vide (les checks de révocation passent par leurs guards `!appleID.isEmpty`).
- [ ] **Paywall off** : `AbonnementService.init()/rafraichir()` forcent `statut = .clubAnnuel(.distantFuture)` sous `#if DEMO` — contrat verrouillé par les 4 tests `AbonnementStatutClubTests` dans `PlaycoTests/FeatureGatingTests.swift`. Ils DOIVENT être verts.
- [ ] **Gates bypassées** : `.bloqueSiNonPayant(source:)` et `.bloqueSiNonClub(source:)` (`Playco/Helpers/FeatureGating.swift`) passent via le statut Club forcé (`peutEcrire`/`peutConnecterAthletes` true). **Dès v2.10** : le nouveau `bloqueSiNonElite(source:)` doit être couvert par le MÊME mécanisme — soit le statut forcé inclut le tier Élite, soit garde `#if DEMO` explicite + test contractuel ajouté à `FeatureGatingTests`. Les nouveaux produits StoreKit ne doivent pas casser la compilation Demo (StoreKit hors Embed Frameworks — piège connu PR #8).
- [ ] **Isolation CloudKit TOTALE** (commit `b94f5b8`) : ModelContainer **local pur** (sans `cloudKitDatabase`) sous `#if DEMO` ; `demarrerSuivi`/surveillance réseau/`synchroniserDonneesPartagees` gardés ; early-return `#if DEMO` sur les **6 points d'entrée** de `CloudKitSharingService+Publication.swift`. ⚠️ Tout NOUVEAU point d'entrée de publication ajouté par un patch doit recevoir sa garde (défense en profondeur — précédent : `publierNouvelUtilisateur` restait atteignable via « ajouter un membre »).
- [ ] **Exclusions backend/vidéo (dès v2.7)** : aucun appel `BackendService`/Supabase ni SDK vidéo actif en DEMO ; entrées UI vidéo masquées ; clés plist caméra/micro tolérées mais aucune capture accessible. Rapport web (3.0.1) et Live Activity (3.0.2) exclus. Vérif : `grep -rn "BackendService\|supabase" Playco --include="*.swift"` → chaque site est gardé ou hors cible Demo.
- [ ] **Démo VIDE** : AUCUN seed de données (le jeu vitrine `DemoBootstrap+Donnees.swift` de `a39aa76` a été **reverté en `a5aa24e`** — ne PAS re-seeder sans demande explicite). Conséquence : les **empty states sont la première impression** — au premier lancement simulateur, chaque section affiche un état vide soigné (dès v2.4.1 : empty states maison « phrase + bouton », plus de ContentUnavailableView avec image).
- [ ] **Chrome démo** : badge « DÉMO » dans `ProfilView.sectionAbonnement` ; déconnexion masquée (cul-de-sac sans Apple ID) ; tutoriel = comportement standard premier lancement (le forçage à chaque lancement a été retiré, commit `e2f653d`).

## Étape 4 — Smoke test simulateur (5 min)

Lancer la config Demo : arrivée directe sur l'app sans login → créer un joueur, une séance, un match éclair → aucune capsule d'erreur sync, aucun paywall, aucune entrée vidéo visible.

## 🛑 GARDE-FOU ABSOLU

Le build DEMO ne va **JAMAIS en review App Store publique** (sans login ni paywall → rejet + risque compte). **TestFlight uniquement.** Le « compte démo review » exigé par App Review est un compte seedé sur build de **PRODUCTION** — distinction contre-vérifiée, ne pas confondre.

## Règles token
- La mémoire `playco-build-demo` et ce skill font foi ; ne pas re-deriver le mécanisme depuis le code.
````

---

## 4. `.claude/skills/playco-video-securite/SKILL.md`

````markdown
---
name: playco-video-securite
description: Revue sécurité du domaine vidéo Supabase/Cloudflare Stream (patchs v2.7 → v2.11) — matrice RLS par rôle, PII minimale, signed URLs, mineurs/UGC 1.2, purge 30 j, quotas/kill-switch. Utiliser avant TOUT déploiement de policy/migration/Edge Function, à chaque patch vidéo, quand on dit « revue sécurité vidéo », « check RLS ».
---

# Playco Vidéo — Revue sécurité

Le domaine vidéo est le SEUL domaine serveur de Playco (principe roadmap : « un domaine n'obtient un serveur que si une ligne de revenus le finance » — ici le tier Élite 399 $/an, quota ~300 min/mois par abonnement). Il touche des **vidéos de mineurs** : le niveau d'exigence est maximal. Verdict binaire : **GO** ou **BLOQUANT** (tout BLOQUANT gèle le déploiement).

Périmètre matériel : dossier `supabase/` (migrations SQL : tables `membres`, `videos`, `video_tags`, `video_clips`, `video_annotations` — sport-agnostiques ; Edge Functions `demande-upload` + `webhook-stream` ; pg_cron), façade `Services/BackendService` (SPM supabase-swift, session SIWA→JWT), `CloudflareStreamService`, `FileAttenteUploadVideo`. Les invariants contractuels de la roadmap : **offline gymnase absolu · autorité de calcul = l'app · frontière pédagogique en RLS · PII minimale**.

## 1. RLS — deny-by-default + matrice par rôle (le cœur)

- [ ] `ROW LEVEL SECURITY` activé sur CHAQUE table du schéma ; **aucune** policy `USING (true)` permissive ; le rôle `anon` n'a AUCUN accès aux tables vidéo.
- [ ] Exécuter la **matrice de tests RLS automatisés** (exigence roadmap 2.11 : « exécutés avant chaque déploiement de policy » — dès 2.7, ne pas attendre 2.11 pour l'écrire) :

| Acteur ↓ / Ressource → | membres (équipe A) | videos A | video_tags A | video_clips A | video_annotations A |
|---|---|---|---|---|---|
| Coach équipe A | R/W | R/W | R/W | R/W | R/W |
| Athlète de A | R (lui-même) | **R : SES clips seulement** | R : SES tags | R : SES clips | R : annotations sur SES clips |
| Coach équipe B (« étranger ») | **DENY** | **DENY** | **DENY** | **DENY** | **DENY** |
| Anonyme (sans JWT) | **DENY** | **DENY** | **DENY** | **DENY** | **DENY** |

  La ligne athlète EST la « frontière pédagogique en RLS » (phase 7, `PartageJoueurVideoView`) : un athlète ne voit JAMAIS les clips/tags/annotations des autres. Tester avec de vrais JWT des trois rôles, pas avec le service role.
- [ ] **Vérification serveur du code d'invitation** : la jonction à la table `membres` se valide côté serveur (Edge Function), jamais par confiance du client. Aucun accès accordé depuis des données non signées (principe déjà appliqué côté CloudKit — `docs/Securite_AbonnementPublicDB.md`).

## 2. PII minimale

- [ ] La table `membres` porte le minimum : identifiant technique + `codeEquipe` + rôle. **Jamais** : date de naissance, photo, données physiques, courriel des athlètes (tout ça reste dans CloudKit/SwiftData). Rappel du précédent : piège CLAUDE.md #26 (les hash avaient fui en Public DB — ne pas reproduire côté Supabase).
- [ ] Aucune PII dans les métadonnées Cloudflare Stream ni dans les noms de fichiers uploadés.
- [ ] Logs Edge Functions : pas de JWT ni d'identifiants en clair.

## 3. Accès aux médias

- [ ] Lecture via **signed URLs / signed tokens courte durée** Cloudflare Stream — jamais d'URL publique persistée en base ni « requireSignedURLs = false ».
- [ ] `demande-upload` : authentifiée (JWT SIWA), vérifie le **quota** (~300 min/mois par abonnement) AVANT de signer un upload TUS.
- [ ] `webhook-stream` : valide la **signature du webhook** (secret partagé) — sinon n'importe qui forge des statuts de traitement.
- [ ] Secrets (service role, tokens Stream, secret webhook) : variables d'environnement Supabase/CI, JAMAIS dans le repo ni dans l'app (l'app ne détient que la clé anon).

## 4. Mineurs & UGC (App Store guideline 1.2 — vidéos de mineurs)

- [ ] Chaîne de consentement branchée sur 2.2.3 : attestation coach horodatée à la création d'un profil <18, avis parent par lien, page de rétention publiée.
- [ ] **Signalement / retrait / blocage** opérationnels (exigence 2.11) : un athlète ou parent peut signaler une vidéo ; le retrait est effectif (suppression Stream + lignes SQL) ; blocage d'utilisateur abusif possible ; contact publié.
- [ ] **Purge 30 j** : job pg_cron actif ET suppression effective côté Cloudflare Stream (les deux systèmes — vérifier qu'une purge SQL seule ne laisse pas la vidéo vivante chez Stream).

## 5. Robustesse économique & kill-switch

- [ ] Quota par abonnement appliqué serveur (pas seulement UI) ; **kill-switch upload** global actionnable sans release App Store ; alertes de facturation Stream/Supabase configurées (santé infra ≤ 40 % du delta Élite−Pro = critère GO/NO-GO du pilote).
- [ ] Offline gymnase absolu : AUCUN chemin critique de coaching (stats live, terrain, séances) ne dépend du backend — la file `FileAttenteUploadVideo` (pattern JournalSyncStorage) absorbe les coupures, plafond FIFO respecté.
- [ ] Build DEMO : aucun appel Supabase, SDK inerte (`/playco-demo-check` §exclusions).

## Sortie

Rapport : tableau `Section | Vérification | Statut (GO/BLOQUANT/N-A) | Preuve (fichier/test/capture)`. Consigner les actions humaines (Dashboard Supabase, Cloudflare, ASC) dans un doc `docs/Securite_Video.md` sur le modèle de `docs/Securite_AbonnementPublicDB.md`. Terminer par `/security-review` général si le patch touche aussi du code hors vidéo.

## Règles token
- Ce skill ne s'applique qu'à partir de v2.7 (si `supabase/` n'existe pas encore : le dire et s'arrêter).
````

---

## 5. `.claude/skills/playco-roadmap-status/SKILL.md`

````markdown
---
name: playco-roadmap-status
description: Situer l'exécution de la roadmap Playco v2.2.x→v3.x — dernier patch livré, patch en cours, prochain patch + prérequis, santé (baseline tests, retard démo, budget horizon). Utiliser en début de session roadmap, quand on dit « où en est-on », « statut roadmap », « prochain patch ».
---

# Playco Roadmap Status

Réancre une session sur l'état réel d'exécution. Lecture seule, ~2 minutes, sortie = un tableau de bord texte.

## Collecte (dans cet ordre, rien de plus)

1. **Roadmap** : `docs/Roadmap_Playco_v2.3_v3.x.md` (fallback : `/Users/armypo/.claude/plans/si-tu-avait-a-typed-rossum.md`) — liste des patchs + statuts annotés.
2. **Dernier livré** : dernière ligne du tableau « Historique des patchs » de `CLAUDE.md` + `git log --oneline -5 main`.
3. **En cours** : `git branch` (branches locales hors main/suivis/pr6) + worktrees `.claude/worktrees/` — associer chaque branche à son patch.
4. **Santé démo** : `git log --oneline suivis/pr6 -3` + `git log --oneline suivis/pr6..main | wc -l` → nombre de commits de main pas encore dans la démo (0 = à jour ; >0 = rebase dû, politique DÉMO §2).
5. **Baseline tests** : nombre attendu = dernière valeur « Tests : N/N » de CLAUDE.md. Ne PAS lancer les tests ici (c'est le rôle de playco-patch) — juste rappeler le nombre.
6. **Actions humaines en attente** : balayer `docs/TODO_*.md` + les fiches patch pour les items « action humaine » (ASC produits Élite, Dashboard CloudKit, projet Supabase, Cloudflare, pilote 5-10 équipes…).

## Sortie (format fixe)

```
## Playco — statut roadmap (date)
| | |
|---|---|
| Version livrée | v2.x (patch …, mergé le …) |
| Patch en cours | v2.x — branche …, périmètre restant : … |
| Prochain patch | v2.x — prérequis : … (satisfaits ? oui/non) |
| Démo (suivis/pr6) | à jour / en retard de N commits |
| Baseline tests | N/N attendus (toolchain stable Xcode 26.6) |
| Horizon | H1/H2/H3 — ~X sem consommées / budget Y |

### Alertes gouvernance
- (dépassement ×1,5 sur un patch, deuxième pari >6 sem qui se profile, patch entamé sans prérequis, démo en retard >1 patch, action humaine bloquante non faite)

### Prochaines actions (3 max)
1. …
```

## Rappels de gouvernance à vérifier À CHAQUE statut

- **25-30 semaines effectives/an** ; effort roadmap déjà ×2 — ne pas re-multiplier.
- **UN seul pari >6 sem/an** : 2026-2027 = la vidéo (v2.7→v2.11). Si un deuxième chantier >6 sem apparaît en cours d'année → ALERTE, il attend v3.2.
- Garde-fous d'éjection : 2.6 et 2.7 peuvent glisser en H2 ; la décision v3.2 est une DÉCISION, pas une exécution.
- La fenêtre 2.2.5+ (correctifs post-lancement) est réservée — ne pas la remplir de features.

## Règles token
- Ce skill LIT et SYNTHÉTISE ; il ne lance ni build ni tests, ne modifie rien. Pour exécuter : `/playco-patch`.
````

---

## Mise à jour recommandée (hors quota) : `playco-release`

Le skill existant `~/Documents/Origotech/.claude/skills/playco-release.md` reste la référence release, mais trois ajouts deviennent nécessaires au fil de la roadmap (à faire au moment du patch concerné, pas avant) :

1. **v2.10** : ajouter aux gates ASC les produits `entraineur.{monthly,yearly}` + `elite.{monthly,yearly}` (groupe `playco.pro` conservé), retrait de `club.*` de la vente, et le **quota minutes chiffré dans la fiche ASC avant soumission** (exigence roadmap).
2. **v2.7+** : gate « secrets Supabase/Stream configurés + `/playco-video-securite` GO » avant toute soumission contenant le domaine vidéo.
3. **Transversal** : renvoi explicite vers `/playco-demo-check` avec le garde-fou « le build DEMO ne va jamais en review publique » (aujourd'hui seulement en mémoire auto, pas dans le skill release).

## Notes d'implémentation (à l'exécution, hors de ce livrable en lecture seule)

- Emplacement : `Playco/.claude/skills/<nom>/SKILL.md` (répertoire déjà peuplé de skills au même format).
- `playco-mat-review` cite les hex et tokens de la spec passe 2 ; à la création de `docs/Vision_Playco_3.0.md`, vérifier la concordance (le doc de vision devient canonique, le skill garde les listes pour être autoportant en revue).
- Les greps des lois 1-8 et 10 sont volontairement sur-inclusifs : le skill impose la lecture du contexte avant de flagger — c'est écrit dans sa méthode.
- Dépendances entre skills : `playco-patch` appelle `playco-mat-review` (Phase 3) et `playco-demo-check` (Phase 4) ; `playco-video-securite` est appelé par `playco-patch` sur les patchs 2.7-2.11 ; `playco-roadmap-status` est autonome. Aucun cycle.

