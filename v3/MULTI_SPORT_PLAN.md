# Playco v3 — Plan technique multi-sport

> Statut : **proposition validée** (mai 2026) — implémentation cible v3.0 (août-septembre 2026)
> Voir aussi : [SAAS_MODEL.md](./SAAS_MODEL.md)

## Contexte

Playco v2.0.1 est en TestFlight (volleyball seul, FR). Origotech vise v3.0 sur App Store **août-septembre 2026** pour capter le cycle d'achat scolaire (saison 2026-2027) avec deux ambitions :

1. **Élargir le marché** : transformer Playco en plateforme multi-sport. Volley + basket + hockey + soccer en v3.0 ; football US / baseball / tennis / badminton / rugby en roadmap v3.1+.
2. **Combler la dette pré-App Store** : W4 a11y partiel, W6 sandbox StoreKit, paywall G2 (CloudKit Public DB) staged, pas d'observabilité, pas de CI.

### Audit du couplage volleyball (mai 2026)

~45 références volleyball **concentrées dans 6 enums + 3 structs**. Le reste (22/30 @Model) est déjà agnostique.

| Couplage | Localisation |
|---|---|
| `PosteJoueur` enum | `Models/JoueurEquipe.swift:9-45` |
| `TypeActionPoint` enum | `Models/Seance.swift:74-188` |
| `TypeActionRallye` enum | `Models/Seance.swift:192-221` |
| `TypeTerrain` enum | `Models/ElementTerrain.swift` |
| `FormationType` enum | `Models/FormationTypes.swift:14-62` |
| `CategorieBibliotheque` enum | `Helpers/BibliothequeDefauts.swift:10-42` |
| `SetScore` struct | `Models/Seance.swift:52-70` |
| `ConfigMatch` struct | `Models/MatchLiveModels.swift:79-86` |
| Dimensions terrain hardcodées | `Views/Terrain/TerrainVolleyView.swift:26-72` |

---

## Phase A — Fondations multi-sport (4-6 semaines)

### A.1 SportPack protocol (strategy pattern)

```swift
// Sports/SportPack.swift
protocol SportPack {
    static var id: SportID { get }                  // .volleyball, .basketball, .soccer, .hockey
    static var nomAffichage: String { get }
    static var icone: String { get }                // SF Symbol
    static var couleurPrimaire: Color { get }

    // Personnel
    static var postes: [PosteDefinition] { get }

    // Stats catalog (remplace les enums hardcodés)
    static var actionsPoint: [ActionDefinition] { get }
    static var actionsRallye: [ActionDefinition] { get }
    static var statsAffichees: [StatColonne] { get }

    // Règles
    static var reglesMatch: ReglesMatch { get }     // nb périodes, score cible, durée, subs max

    // Terrain
    static var variantes: [VarianteTerrain] { get } // indoor/beach, gazon/synthétique, glace/dek...
    static func dessinerTerrain(_ ctx: GraphicsContext, taille: CGSize, variante: VarianteTerrain)

    // Tactique
    static var formations: [FormationDefinition] { get }

    // Bibliothèque
    static var categoriesBibliotheque: [CategorieBibliotheque] { get }
    static func exercicesParDefaut() -> [ExerciceBibliothequeTemplate]

    // Capabilities (le protocole supporte les divergences entre sports)
    static var aRotation: Bool { get }              // volley oui, basket non
    static var aLignes: Bool { get }                // hockey oui, volley non
    static var aPeriodesChronométrees: Bool { get } // basket/soccer/hockey oui, volley non
}
```

**Nouveaux fichiers** :
- `Sports/SportPack.swift`
- `Sports/SportID.swift`
- `Sports/SportRegistry.swift` (lookup + persistance + sport actif)
- `Sports/Packs/VolleyballPack.swift`
- `Sports/Packs/BasketballPack.swift`
- `Sports/Packs/SoccerPack.swift`
- `Sports/Packs/HockeyPack.swift`
- `Sports/Definitions/PosteDefinition.swift`
- `Sports/Definitions/ActionDefinition.swift`
- `Sports/Definitions/FormationDefinition.swift`
- `Sports/Definitions/ReglesMatch.swift`
- `Sports/Definitions/VarianteTerrain.swift`
- `Sports/Definitions/StatColonne.swift`
- `Sports/Definitions/CategorieBibliotheque.swift`
- `Sports/Definitions/ExerciceBibliothequeTemplate.swift`

### A.2 Refactor enums → IDs string

| Existant (hardcodé volley) | Cible v3 |
|---|---|
| `PosteJoueur` enum (`JoueurEquipe.swift:9-45`) | `posteID: String` résolu via `SportPack.postes` |
| `TypeActionPoint` enum (`Seance.swift:74-188`) | `actionID: String` via `SportPack.actionsPoint` |
| `TypeActionRallye` enum (`Seance.swift:192-221`) | `actionID: String` via `SportPack.actionsRallye` |
| `TypeTerrain` enum (`ElementTerrain.swift`) | `varianteTerrainID: String` |
| `FormationType` enum (`FormationTypes.swift:14-62`) | `formationID: String` via `SportPack.formations` |
| `CategorieBibliotheque` (`BibliothequeDefauts.swift`) | `categorieID: String` par sport |
| `SetScore` struct (`Seance.swift:52-70`) | `PeriodeScore` paramétré (cible, diff requis) |
| `ConfigMatch` (`MatchLiveModels.swift:79-86`) | Étendu + `ReglesMatch` du SportPack |

**Migration CloudKit-safe** :
- Tous les champs @Model ont une valeur par défaut `""` (compatibilité CloudKit obligatoire)
- RawValues actuels conservés comme IDs (`"libero"`, `"kill"`, `"ace"`, `"indoor"`, etc.) → **zéro perte de données**
- `MigrationV3Service` au premier launch v3.0 : mappe les anciens enums vers les nouveaux IDs string

### A.3 Quatre sport packs en v3.0

#### 1. `VolleyballPack` (refactor référence)

- Postes : libéro, passeur, central, réceptionneur, opposé
- Actions point : kill, ace, bloc seul, bloc assisté, erreur attaque, erreur service, erreur bloc, erreur réception, faute jeu, + 5 symétriques adversaire
- Actions rallye : manchette, passe décisive, réception, tentative attaque, service en jeu, dig
- Règles : 5 sets max, set à 25 (set 5 à 15), diff 2 pts, 6 subs/set, 2 TM/set
- Terrain : 18 × 9 m, zones 1-6, filet horizontal/vertical, variantes indoor parquet + beach sable
- Formations : 5-1, 4-2, 6-2 + variantes beach
- aRotation = true · aLignes = false · aPeriodesChronométrees = false

#### 2. `BasketballPack`

- Postes : PG (meneur), SG (arrière), SF (ailier), PF (ailier fort), C (pivot)
- Actions point : tir 2 pts, tir 3 pts, lancer franc, rebond off/déf, passe décisive, interception, contre, faute, perte de balle
- Règles : 4 quarts × 10 min (NBA) ou 4 × 12 min (NCAA configurable), pas de rotation
- Terrain : 28 × 15 m, raquette, arc 3 pts, ligne lancer franc, milieu
- Formations : man-to-man, zone 2-3, zone 3-2, press
- aRotation = false · aLignes = false · aPeriodesChronométrees = true

#### 3. `SoccerPack`

- Postes : GK, DEF (CB/LB/RB), MID (CM/DM/AM), ATT (LW/RW/ST)
- Actions point : but, passe décisive, tir cadré, tir non cadré, carton jaune, carton rouge, hors-jeu, faute
- Règles : 2 × 45 min + arrêts de jeu, 5 subs (3 windows)
- Terrain : 105 × 68 m, surface réparation, surface but, point de penalty, rond central
- Formations : 4-3-3, 4-4-2, 4-2-3-1, 3-5-2, 5-3-2
- aRotation = false · aLignes = false · aPeriodesChronométrees = true

#### 4. `HockeyPack`

- Postes : G (gardien), D (défenseur), C (centre), AG (ailier gauche), AD (ailier droit)
- Actions point : but, passe (1ère/2e), +/- automatique, mise au jeu gagnée, PIM (minutes pénalité), tir au but, save (gardien)
- Règles : 3 périodes × 20 min, lignes 1ère/2e/3e/4e, situations spéciales PP/PK
- Terrain : patinoire 200 × 85 ft (NHL), zones offensive/neutre/défensive, ronds de mise au jeu
- Formations : 1-2-2, 2-1-2 (forecheck), neutral zone trap, box (PK), umbrella (PP)
- aRotation = false · aLignes = true · aPeriodesChronométrees = true

**Roadmap v3.1+** : football US (downs/playbook), baseball (innings/box score), tennis/badminton (1v1, scoring différent), rugby (mêlée/touche).

### A.4 UI multi-sport

- `Views/Configuration/ConfigSportView.swift` étendu : grille sports avec icônes + sélection variantes (indoor/beach, 5/7/11 soccer, dek/glace hockey)
- `Models/Equipe.swift` : nouveau champ `sportID: String = "volleyball"` (CloudKit-safe default)
- `Views/ContentView.swift` : routage des 5 sections selon sport actif
- `Views/AccueilView.swift` : couleurs/icônes via `SportPack.couleurPrimaire`
- `Views/Terrain/TerrainGenericView.swift` (nouveau) : remplace `TerrainVolleyView`, délègue le rendu au SportPack
- `Views/Matchs/{StatsLive,DashboardMatchLive,RotationLive}View.swift` : données via SportPack, rotation cachée si `!aRotation`, lignes affichées si `aLignes`

---

## Phase B — Hardening pré-lancement (3-4 semaines, parallèle)

### B.1 CI / TestFlight (priorité 1)

- **[fastlane/fastlane](https://github.com/fastlane/fastlane)** : `Fastfile` avec lanes `beta` (upload TestFlight auto), `screenshots` (iPad Air 11" / 13" / iPad Pro × 4 sports), `release` (metadata App Store). Cycle release 1 h → 5 min.
- GitHub Actions : tests + `xcodebuild` sur chaque PR.

### B.2 Observabilité

- **[getsentry/sentry-cocoa](https://github.com/getsentry/sentry-cocoa)** ~8k★ : capture crashs SwiftData / CloudKit + erreurs `PaywallViewModel`. Free tier 5k events/mois. Déclarer dans privacy nutrition label.
- **[TelemetryDeck/SwiftClient](https://github.com/TelemetryDeck/SwiftClient)** ~400★ : signaux clés à instrumenter :
  - `match_live_started`
  - `paywall_shown` / `paywall_purchased`
  - `cloudkit_sync_paused` / `cloudkit_sync_resumed`
  - `sport_selected:{id}` (mesurer adoption multi-sport)
  - `seuil_atteint:{trigger}` (cf. SAAS_MODEL.md § Seuils)
  - `upgrade_suggere` / `upgrade_accepte` / `upgrade_refuse`
  Conforme Loi 25 QC (pas d'IDFA), self-hostable.
- **[ggruen/CloudKitSyncMonitor](https://github.com/ggruen/CloudKitSyncMonitor)** ~580★ : remplacer/compléter `CloudKitSyncService.swift` — events natifs `NSPersistentCloudKitContainer` au lieu du journal UserDefaults 50 entrées.

### B.3 Tests & A11y

- **[pointfreeco/swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)** ~4k★ : snapshots de `TerrainGenericView` × 4 sports + `PaywallView` + `MatchLiveSplitView` (portrait / landscape). Git LFS pour assets iPad. Compatible Swift Testing (baseline 123 préservée).
- **[cashapp/AccessibilitySnapshot](https://github.com/cashapp/AccessibilitySnapshot)** ~2k★ : snapshots annotés VoiceOver — couvre exactement le W4 partiel (Canvas PencilKit, DockBar, BarreOutilsDessin) sans iPad physique.
- **[cvs-health/ios-swiftui-accessibility-techniques](https://github.com/cvs-health/ios-swiftui-accessibility-techniques)** 316★ (maj 20 mai 2026) : checklist VoiceOver pré-soumission App Store, démos "good vs bad" testables.

### B.4 Paywall finalisation

- Implémenter actor `CloudKitPublicSyncAbonnement` (G2 staged dans v2.0.1) — reconnexion Pro sur Apple ID différent via CloudKit Public DB lookup par `Abonnement.codeEquipe`.
- Tests sandbox StoreKit complets (W6) sur compte testeur Apple — **bloquant App Store**.
- 4 nouveaux product IDs v3 (`entraineur.*` + `pro.*` renommé depuis `pro.*` v2.0.1).
- `Services/SeuilUpgradeService.swift` + UI banners + télémétrie seuils.

---

## Phase C — Post-lancement (hors scope v3.0, roadmap documentée)

- **[RevenueCat/purchases-ios](https://github.com/RevenueCat/purchases-ios)** ~3k★ et **[FlineDev/FreemiumKit](https://github.com/FlineDev/FreemiumKit)** : lire pour valider patterns paywall (pas intégrer — vendor lock-in / bus factor).
- **[superwall/Superwall-iOS](https://github.com/superwall/Superwall-iOS)** : remote-config paywall (itérer copy/prix sans rebuild App Store).
- **[tldraw/tldraw](https://github.com/tldraw/tldraw)** ~47k★ et **[excalidraw](https://github.com/excalidraw/excalidraw)** ~123k★ : inspiration terrain v3 (zoom infini, frames = étapes d'exercice). TS/React → portage Swift à terme.
- **[simonbs/InfiniteCanvas](https://github.com/simonbs/InfiniteCanvas)** 103★ : POC zoom terrain pour grands sports (soccer 105 × 68 m, hockey 200 ft).
- **[sk1gl4a/LiquidGlass-SwiftUI-Showcase](https://github.com/sk1gl4a/LiquidGlass-SwiftUI-Showcase)** : migration `GlassCard` / `GlassButtonStyle` vers APIs natives `glassEffect` / `glassEffectID` dès iOS 26 GA.

---

## Fichiers à créer / modifier

### Nouveaux

```
Sports/
├── SportPack.swift
├── SportID.swift
├── SportRegistry.swift
├── Packs/
│   ├── VolleyballPack.swift
│   ├── BasketballPack.swift
│   ├── SoccerPack.swift
│   └── HockeyPack.swift
└── Definitions/
    ├── PosteDefinition.swift
    ├── ActionDefinition.swift
    ├── FormationDefinition.swift
    ├── ReglesMatch.swift
    ├── VarianteTerrain.swift
    ├── StatColonne.swift
    ├── CategorieBibliotheque.swift
    └── ExerciceBibliothequeTemplate.swift

Views/Terrain/TerrainGenericView.swift   (remplace TerrainVolleyView)
Services/AnalyticsService.swift          (wrapper TelemetryDeck)
Services/CrashReportingService.swift     (wrapper Sentry)
Services/SeuilUpgradeService.swift       (suggestion upgrade/downgrade)
Services/MigrationV3Service.swift        (mapping enums legacy → IDs string)
Fastfile
.github/workflows/ci.yml
```

### Refactor

- `Models/JoueurEquipe.swift` — `PosteJoueur` enum → `posteID: String`, stats volley → `statsParSport: Data` (JSON par sport)
- `Models/Seance.swift` — `TypeActionPoint` / `TypeActionRallye` enums → `actionID: String` + `sportID` sur Seance
- `Models/FormationTypes.swift` — `FormationType` enum supprimé au profit de `FormationDefinition` (table dans SportPack)
- `Models/ElementTerrain.swift` — `TypeTerrain` → `varianteTerrainID: String`
- `Models/MatchLiveModels.swift` — `ConfigMatch` étendu, `SetScore` → `PeriodeScore`
- `Models/Equipe.swift` — ajouter `sportID: String = "volleyball"`
- `Models/Etablissement.swift` — ajouter `adminUtilisateurID: String = ""`, `palierAbonnement: String = ""`
- `Models/Utilisateur.swift` — nouveau cas `adminOrganisation` dans `RoleUtilisateur`
- `Models/Abonnement.swift` — champs `palier: String`, `nbEquipesAutorisees: Int`, `nbHeadCoachsAutorisees: Int`, `sportsAutorises: [String]` (JSON Data)
- `Helpers/BibliothequeDefauts.swift` — catégories déplacées dans chaque SportPack
- `Views/Configuration/ConfigSportView.swift` — sélecteur multi-sport
- `PlaycoApp.swift` — init `SportRegistry` + `AnalyticsService` + `CrashReportingService` au démarrage
- `Views/Matchs/StatsLiveView.swift` / `DashboardMatchLiveView.swift` / `RotationLiveView.swift` — données via SportPack, rotation cachée si sport sans rotation
- `Services/PaywallViewModel.swift` — 4 product IDs v3 + logique seuils via `SeuilUpgradeService`
- `Services/StoreKitService.swift` — alias migration `pro.*` v2 → `pro.*` v3 (même nom mais nouveau prix), nouveaux IDs `entraineur.*`

### Réutilisations confirmées (zéro changement)

`Services/AuthService.swift`, `Services/CalendarSyncService.swift`, `Services/PDFExportService.swift`, `Services/CSVExportService.swift`, `Models/MessageEquipe.swift`, `Models/CredentialAthlete.swift`, `Helpers/FiltreEquipe.swift`, `Helpers/LiquidGlassKit.swift`, `Helpers/PermissionsRole.swift`, `Helpers/Extensions.swift`, `ViewModels/TerrainEditeurViewModel.swift`.

---

## Migration données v2.0.1 → v3.0

1. **Ajout de champs** : `sportID = "volleyball"` sur toutes les `Equipe` existantes (default CloudKit-safe).
2. **MigrationV3Service au premier launch** : mappe les enums legacy vers string IDs :
   - `PosteJoueur.libero` → `"libero"` (raw value identique)
   - `TypeActionPoint.kill` → `"kill"`
   - `TypeTerrain.indoor` → `"indoor"`
   - `FormationType.cinqUn` → `"5-1"`
   - etc. — **zéro perte de données** car raw values conservés
3. **JoueurEquipe stats volley** : conservées telles quelles (champs existants restent), exposées uniquement quand `sportID == "volleyball"`. Les nouveaux sports stockent leurs stats dans `statsParSport: Data` (JSON).
4. **Tests** : `MigrationV3Tests` doit garantir 0 perte de données sur dataset CloudKit existant (équipe volley → reste volley après migration).

---

## Planning indicatif (sprints 2 semaines)

| Sprint | Période | Livrable |
|---|---|---|
| **S1** | début juin 2026 | Phase B.1 (Fastlane CI) + B.2 (Sentry / TelemetryDeck) — débloque télémétrie sur v2.0.1 |
| **S2** | mi-juin | Phase A.1 + A.2 — SportPack protocol + refactor enums (volley seul) + MigrationV3Service. **Tests baseline 123 verts.** |
| **S3** | début juillet | Phase A.3 — BasketballPack + SoccerPack + UI sélecteur sport |
| **S4** | mi-juillet | Phase A.3 — HockeyPack + bibliothèques exercices par sport |
| **S5** | début août | Phase B.3 (snapshot tests 4 sports) + B.4 (CloudKitPublicSyncAbonnement + sandbox StoreKit) + SeuilUpgradeService |
| **S6** | mi-août | Bug bash, App Store assets multi-sport, beta TestFlight élargie, écoles pilotes |

**Cible release v3.0** : TestFlight fin **août 2026**, App Store **septembre 2026** (avant le début de saison scolaire).

---

## Verification

- **Tests** : baseline 123 verts + nouveaux :
  - `SportPackTests` (4 sports × postes / actions / règles / formations)
  - `MigrationV3Tests` (0 perte sur dataset v2.0.1)
  - `SeuilUpgradeServiceTests` (6 triggers upgrade + 3 downgrade)
  - Snapshot tests visuels 4 terrains + 2 paliers paywall
- **Build** : `xcodebuild -scheme Playco -destination 'platform=iOS Simulator,name=iPad Air 13-inch (M3)' build` — 0 erreur, 0 warning
- **CloudKit migration** : tester sur compte sandbox avec dataset v2.0.1 (équipe volley) → v3.0 reste volley sans perte
- **A11y** : `AccessibilitySnapshot` sur 4 vues `TerrainGenericView` + checklist `cvs-health/ios-swiftui-accessibility-techniques`
- **Paywall** : test sandbox complet sur 4 product IDs (achat / restore / Apple ID différent via CloudKit Public DB)
- **TestFlight** : 4 builds livrés via Fastlane sans intervention manuelle
- **Télémétrie** : `sport_selected:{id}`, `seuil_atteint:{trigger}`, `upgrade_accepte` visibles dans dashboard TelemetryDeck 24 h après release beta

---

## Risques & mitigations

| Risque | Mitigation |
|---|---|
| Refactor enums casse CloudKit sync existant | RawValues conservés comme IDs (`"libero"`, `"kill"`), tests migration obligatoires avant merge |
| Sport packs trop divergents (hockey lignes ≠ volley rotations) | Capabilities optionnelles dans protocole (`aRotation`, `aLignes`, `aPeriodesChronométrees`) |
| App Store rejette repositionnement multi-sport | Garder bundle ID / nom Playco, présenter en metadata comme "Playco — Coaching multi-sport", pas un nouvel App Store listing |
| Garde-fou Pro contourné par head coachs multiples | Vérification Apple ID + device principal, blocage propre à la 2e invitation head coach (cf. SAAS_MODEL.md § Garde-fou Pro) |
| Charge dev pour 4 sports en parallèle | Livrer Volley + Basket en v3.0.0, Soccer + Hockey en v3.0.1 si retard (release étalée août → octobre) |
| Bibliothèque exercices volley polluée par sports inconnus | Filtrer `ExerciceBibliotheque` par `sportID` (protocole `FiltreParSport` similaire à `FiltreParEquipe`) |
| Coût Sentry / TelemetryDeck dépasse free tier | Sampling 100 % en bêta → 10 % post-release ; self-host TelemetryDeck si budget contraint |
| Cycle d'achat scolaire raté (août-sept) | Release v3.0 visée avant le 15 août 2026 pour capter saison 2026-2027 |
