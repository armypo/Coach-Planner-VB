# Playco — Paywall v2.0 (Plan)


# Partie 1 — PLAN

## Context

Playco v1.9.0 sur TestFlight, sans paywall. Objectif v2.0 : introduire **2 tiers d'abonnement** avec essai 14 jours Apple natif :
- **Playco Pro** : coach admin + assistant(s) coach. Outil solo/staff. Pas d'accès athlètes via app.
- **Playco Club** : Pro + connexion athlètes + MonProfilAthleteView + messagerie athlète-coach.

Tout le monde paie (pas de grandfathering). Assistants coachs accèdent gratuitement via code équipe (leur coach est abonné Pro minimum).

## Décisions business validées

| Décision | Choix |
|---|---|
| **Tiers** | 2 tiers cumulatifs : Pro (coach + staff) et Club (Pro + athlètes) |
| **Type d'essai** | Apple natif Introductory Offer — 14 jours. **1 seul essai par Apple ID** pour tout le Subscription Group. |
| **Prix Pro** | **14,99 $ CAD / mois** · **149,99 $ CAD / an (-17%)** |
| **Prix Club** | **25,00 $ CAD / mois** · **250,00 $ CAD / an (-17%)** |
| **Cible payante** | Coach admin uniquement (`role in [.coach, .admin]`). Assistants (`.assistantCoach`) + athlètes (`.etudiant`) gratuits côté user. |
| **Différenciation Pro vs Club** | **Seule différence : athlètes peuvent se connecter via RejoindreEquipeView** si coach a Club. Assistants + staff accèdent dans les 2 tiers. Les données (stats, matchs, etc.) sont créées pareillement dans les deux. |
| **Post-essai** | Lecture seule (consultation OK, création/modif/export bloqués). Bannière permanente + paywall sur action write. Identique pour Pro et Club. |
| **Family Sharing** | Non sur les 2 tiers (`isFamilyShareable: false`) |
| **Rappels pré-expiration** | Bannière in-app J-3 et J-1 |
| **Localisation v2.0** | FR seulement (Québec/France) |
| **Grandfathering** | Aucun |
| **Upgrade Pro → Club** | Supporté nativement par Apple (même Subscription Group, levels différents) |
| **Migration rôle** | `.assistantCoach` ajouté. Migration one-shot reclasse les `.coach` existants qui sont dans `AssistantCoach` vers `.assistantCoach`. |
| **Welcome UX** | Sheet bloquant après wizard, présente les 2 tiers côte à côte avec toggle mensuel/annuel. **Pro annuel pré-sélectionné**. Cancel Apple dialog → lecture seule. |
| **États StoreKit** | Mapping Apple standard : `.inGracePeriod`/`.inBillingRetryPeriod` → actif ; `.revoked` → expire immédiat. |
| **Gate sécurité bypass** | Centrale dans `PlaycoApp` : après chaque login (LoginView OU RejoindreEquipeView) ET à chaque `restaurerSession`, si `user.role == .etudiant` ET tier équipe != `.club` → déconnexion immédiate + message. Impossible de contourner via LoginView. |
| **Assistant coach si coach expire** | Login OK + mode lecture seule. Bannière visible. Jamais déconnecté. |
| **Athlète si tier drop pendant session** | **Déconnexion automatique immédiate** + écran login + message. Plus strict que pour assistant (accès athlète = feature premium Club). |
| **Affichage "14 jours offerts"** | Conditionnel par produit via `Product.SubscriptionInfo.isEligibleForIntroOffer`. Si non-éligible (repeat user) → pas de badge "14j", CTA "S'abonner" au lieu de "Commencer l'essai". |

## Matrice de fonctionnalités

| Fonctionnalité | Non-abonné (post-essai) | Pro | Club |
|---|---|---|---|
| Consultation matchs/stats/séances existants | ✅ lecture seule | ✅ | ✅ |
| Créer matchs / séances / stratégies | ❌ paywall | ✅ | ✅ |
| Saisie stats temps réel | ❌ paywall | ✅ | ✅ |
| Export PDF / CSV | ❌ paywall | ✅ | ✅ |
| Multi-équipes | ❌ paywall | ✅ | ✅ |
| Scouting reports + Heatmap + Analytics | ❌ paywall | ✅ | ✅ |
| **Connexion assistant coach** (`.assistantCoach`) via code équipe | ✅ | ✅ | ✅ |
| **Connexion athlète** (`.etudiant`) via code équipe | ❌ | ❌ | ✅ |
| MonProfilAthleteView (côté athlète) | ❌ | ❌ | ✅ |
| Messagerie avec athlètes | ❌ | ❌ | ✅ |

**Observation clé** : côté UI du coach, Pro et Club sont **identiques**. La seule différence visible est la capacité de ses athlètes à se connecter à l'app. Le coach choisit Club s'il veut que ses athlètes aient accès à leur profil/stats/messagerie.

## Architecture technique

### 1. Modèles

**`Playco/Models/Abonnement.swift`** (nouveau)
```swift
enum Tier: String, Codable { case aucun, pro, club }
enum TypeAbonnement: String, Codable {
    case aucun, essai, mensuel, annuel, gracePeriode, expire
}

@Model final class Abonnement {
    var id: UUID = UUID()
    var utilisateurID: UUID = UUID()
    var tierRaw: String = Tier.aucun.rawValue
    var typeAbonnementRaw: String = TypeAbonnement.aucun.rawValue
    var produitIAPID: String = ""
    var appStoreTransactionID: String = ""
    var dateDernierSync: Date = Date()
    var dateExpiration: Date? = nil    // essai OU renouvellement
}
```
Tous les attributs avec défaut, pas de relation (piège CLAUDE.md #15). Pas de conformance `FiltreParEquipe`.

**`Playco/Models/Utilisateur.swift`** (modifier)
- Ajouter `.assistantCoach` dans `RoleUtilisateur` enum avec label "Coach assistant", icône "person.badge.shield.checkmark", couleurHex "#4A8AF4".

**`Playco/Models/Equipe.swift`** (modifier) — CRITIQUE pour la gate athlète
- Ajouter `var tierAbonnementRaw: String = Tier.aucun.rawValue` (default)
- Computed `var tierAbonnement: Tier { get / set }`
- Ce champ est synchronisé publiquement via `CloudKitSharingService.publierEquipeComplete` → permet à l'app de l'athlète (Apple ID différent) de lire le tier du coach propriétaire du code équipe.

### 2. Helpers & constantes

**`Playco/Helpers/IdentifiantsIAP.swift`** (nouveau)
```swift
enum IdentifiantsIAP {
    // Tier 1 — Pro
    static let proMensuel = "com.origo.playco.pro.mensuel"
    static let proAnnuel  = "com.origo.playco.pro.annuel"
    // Tier 2 — Club
    static let clubMensuel = "com.origo.playco.club.mensuel"
    static let clubAnnuel  = "com.origo.playco.club.annuel"

    static let groupeAbonnement = "playco.pro"
    static let tous = [proMensuel, proAnnuel, clubMensuel, clubAnnuel]

    // Tier lookup
    static func tier(pour produitID: String) -> Tier {
        if produitID == proMensuel || produitID == proAnnuel { return .pro }
        if produitID == clubMensuel || produitID == clubAnnuel { return .club }
        return .aucun
    }
    static func estAnnuel(_ produitID: String) -> Bool {
        produitID == proAnnuel || produitID == clubAnnuel
    }

    // UserDefaults keys
    static let cleCacheStatut = "playco_cache_statut_abo"
    static let cleCachePeutEcrire = "playco_cache_peut_ecrire"
    static let cleCachePeutConnecterAthletes = "playco_cache_peut_athletes"
    static let cleMigrationRolesDone = "playco_migration_roles_v2_done"
}
```

**`Playco/Helpers/TextesPaywall.swift`** (nouveau) — toutes les chaînes FR centralisées, avec section spécifique pour chaque tier.

### 3. Services

**`Playco/Services/StoreKitService.swift`** (nouveau, @Observable @MainActor)
- Charge les 4 produits via `Product.products(for: IdentifiantsIAP.tous)`
- `acheter(_ produit: Product) async throws -> Transaction`
- `restaurer() async throws`
- `observerTransactions() -> Task<Void, Never>` sur `Transaction.updates`
- `statutSouscriptionActif() async -> (produit: Product, status: Product.SubscriptionInfo.Status)?`
- Check `.verified` strict, rejette `.unverified`

**`Playco/Services/AbonnementService.swift`** (nouveau, @Observable @MainActor)
```swift
enum Statut {
    case chargement
    case aucun
    case essaiActif(tier: Tier, joursRestants: Int)
    case proMensuel(dateRenouvellement: Date)
    case proAnnuel(dateRenouvellement: Date)
    case clubMensuel(dateRenouvellement: Date)
    case clubAnnuel(dateRenouvellement: Date)
    case gracePeriode(tier: Tier, dateExpirationAttendue: Date)
    case essaiExpire
    case expire(tier: Tier, depuis: Date)
}

var statut: Statut = .chargement

var tierActif: Tier  // computed : .club si clubX/essaiActif(.club), .pro si proX/essaiActif(.pro), .aucun sinon
var peutEcrire: Bool  // true pour tous les tiers actifs + grace ; cache pendant chargement
var peutConnecterAthletes: Bool  // true uniquement si tierActif == .club
var joursRestantsEssai: Int?
var doitAfficherBanniere: Bool

func rafraichir(utilisateur: Utilisateur?, context: ModelContext, storeKit: StoreKitService) async
func estCoachPayant(utilisateur: Utilisateur) -> Bool  // role .coach ou .admin
func migrerAssistantsVersNouveauRole(context: ModelContext)
func propagerTierAuxEquipes(context: ModelContext, sharingService: CloudKitSharingService) async
    // Met à jour Equipe.tierAbonnementRaw pour toutes les équipes du coach + republie via CloudKit
```

**Logique `rafraichir`** :
1. Si `utilisateur` = nil ou `!estCoachPayant` → `.aucun`, persister cache, return
2. Lire `storeKit.statutSouscriptionActif()` → `(produit, status)`
3. Extraire tier via `IdentifiantsIAP.tier(pour: produit.id)` + annuel vs mensuel
4. Mapper `status.state` vers `Statut` :
   - `.inTrial` → `.essaiActif(tier: tier, joursRestants: calcul)`
   - `.subscribed` + Pro annuel → `.proAnnuel(dateRenouvellement:)`
   - `.subscribed` + Pro mensuel → `.proMensuel(...)`
   - `.subscribed` + Club annuel → `.clubAnnuel(...)`
   - `.subscribed` + Club mensuel → `.clubMensuel(...)`
   - `.inGracePeriod`, `.inBillingRetryPeriod` → `.gracePeriode(tier:, dateExpirationAttendue:)`
   - `.expired` → `.expire(tier:, depuis:)`
   - `.revoked` → `.expire(tier:, depuis: revocationDate ?? now)`
   - Sinon → `.essaiExpire` si historique, sinon `.aucun`
5. Persister cache UserDefaults (`cleCacheStatut`, `cleCachePeutEcrire`, `cleCachePeutConnecterAthletes`)
6. Persister dans `Abonnement` SwiftData (cloud sync)
7. Si tier a changé depuis dernier refresh → appeler `propagerTierAuxEquipes()`
8. Émettre analytics sur transitions pertinentes (essai_demarre, essai_expire)

### 4. Vues paywall (`Playco/Views/Paywall/`)

**Style** : fond noir + RadialGradient orange animé (cf. `TutorielView.swift` L.360-400), typo `.rounded`, `GlassCard` tinted.

| Fichier | Rôle |
|---|---|
| `ComposantsPaywall.swift` | `FeatureRow`, `PricingCard`, `BadgeStatut`, `BanniereEssai`, `SelecteurPeriode` (toggle mensuel/annuel) |
| `PaywallView.swift` | Vue canonique — mode `.welcome / .bloquant / .gestion`. Affiche 2 PricingCard (Pro à gauche, Club à droite) avec toggle mensuel/annuel en haut. Le coach sélectionne tier+période. CTA unique "Commencer l'essai 14 jours" (welcome) ou "S'abonner" (autres modes). |
| `BienvenuePaywallView.swift` | Wrapper `PaywallView(mode: .welcome)` + `interactiveDismissDisabled(true)`. 3 issues : essai démarré / achat direct / cancel Apple → lecture seule. |
| `GestionAbonnementView.swift` | Depuis ProfilView : BadgeStatut + date renouv + tier actuel + CTA "Gérer mon abonnement" (openURL Apple Settings) + "Voir les plans" (push PaywallView .gestion pour upgrade Pro→Club) + "Restaurer". |
| `PaywallBloquantView.swift` | fullScreenCover sur action write sans abonnement. `interactiveDismissDisabled(true)`. |
| `BanniereAbonnementView.swift` | Bandeau top d'écran dans ContentView, tap → PaywallView sheet. Affiché si `doitAfficherBanniere`. |

**PricingCard avec 2 tiers** : chaque card affiche :
- Nom du tier (Pro / Club)
- Prix du mois ou de l'année (via `Product.displayPrice`)
- Liste courte features clés (Pro : 3 bullets coach ; Club : "Tout Pro +" + 3 bullets athlète)
- Check si sélectionné
- Badge "-17%" si annuel
- **Badge "14 jours offerts" visible seulement si `produit.subscription?.isEligibleForIntroOffer == true`** (via `await produit.subscription?.isEligibleForIntroOffer`)

**Pre-selection** : à l'ouverture du paywall, `produitSelectionne = Pro annuel` par défaut.

**CTA dynamique** :
- Si produit sélectionné ÉLIGIBLE essai → "Commencer l'essai 14 jours"
- Si produit sélectionné NON-ÉLIGIBLE → "S'abonner · \(produit.displayPrice)/\(période)"

### 5. Intégrations

**`PlaycoApp.swift`** :
- Injecter `StoreKitService` + `AbonnementService` via `.environment`
- Ajouter `Abonnement.self` dans `modeles`
- Au démarrage case `.app` : migration rôles → chargerProduits → rafraichir → observerTransactions (Task racine)

**`ConfigurationView.swift`** :
- Fin du wizard → `BienvenuePaywallView` sheet bloquant
- Ligne 324 (assistants) : créer avec `role: .assistantCoach` au lieu de `.coach`

**`ProfilView.swift`** :
- Section "Mon abonnement" entre CodeEquipe et Visibilite, `.siAutorise(estCoach)`
- Affiche tier actif + date renouv + NavigationLink vers `GestionAbonnementView`

**`ContentView.swift`** :
- `BanniereAbonnementView()` en `.safeAreaInset(edge: .top)` si `doitAfficherBanniere`
- Injection service vers sous-vues

**`RejoindreEquipeView.swift`** — **CRITIQUE pour la gate tier Club** :
- Actuellement : accepte `.coach` + `.etudiant` via code équipe
- Modifier : accepter aussi `.assistantCoach`
- **Nouveau** : avant d'accepter un user `.etudiant`, charger `Equipe` correspondant au code équipe ET vérifier `equipe.tierAbonnement == .club`. Sinon afficher erreur "Ton coach doit activer l'abonnement Club pour que tu puisses te connecter. Demande-lui de passer au plan Club dans Paramètres → Mon abonnement."
- Les users `.coach`, `.admin`, `.assistantCoach` peuvent toujours se connecter même si tier == .pro (assistants bloqués **seulement** si tier == .aucun)

**`PlaycoApp.swift`** — **Gate sécurité centrale** (post-login + restaurerSession) :
```swift
private func appliquerGateTier() {
    guard let user = authService.utilisateurConnecte else { return }
    // Athlète : requiert tier .club
    if user.role == .etudiant {
        let equipe = fetchEquipeDeLUtilisateur(user)
        if equipe?.tierAbonnement != .club {
            authService.deconnexion()
            afficherErreurGate = "Ton coach doit activer l'abonnement Club pour que tu puisses te connecter."
            ecranActif = .choixInitial
        }
    }
    // Assistant : requiert tier .pro OU .club (pas .aucun)
    if user.role == .assistantCoach {
        let equipe = fetchEquipeDeLUtilisateur(user)
        if equipe?.tierAbonnement == .aucun {
            authService.deconnexion()
            afficherErreurGate = "Ton coach doit renouveler son abonnement Playco Pro."
            ecranActif = .choixInitial
        }
    }
}
```
Appelée :
- Après succès de `LoginView.onConnecte()` et `RejoindreEquipeView.onConnecte()`
- Dans le `onAppear` de case `.app`, après `restaurerSession`
- Déclenchée aussi par un observateur sur `abonnementService.statut` : si un athlète est connecté ET tier passe à != .club → déconnexion immédiate via `NotificationCenter` ou re-check direct dans `ContentView.onChange(of: abonnementService.statut)`

**`PermissionsRole.swift`** :
- Étendre les 7 permissions à `.assistantCoach` (même droits que `.coach`)

**`Playco.entitlements`** : ajouter `com.apple.developer.in-app-purchase`

**`Playco.storekit`** (nouveau Xcode config file) : 4 produits dans Subscription Group "playco.pro" :
- Level 1 (meilleur) : Club mensuel + Club annuel · 14-day free trial
- Level 2 : Pro mensuel + Pro annuel · 14-day free trial (trial partagé au niveau groupe)
- Référencé dans Scheme → Run → Options → StoreKit Configuration

### 6. Feature gating

**Modifier `.bloqueSiNonPayant(source:)` (`Playco/Helpers/FeatureGating.swift`)** :
- `@Environment(AbonnementService.self)` → lit `peutEcrire`
- Si `!peutEcrire` : remplace le contenu par overlay tappable qui ouvre `PaywallBloquantView`
- Appliqué sur ~10 vues write (boutons create/save/export)

**Modifier spécifique `.bloqueSiPasClub()` (même fichier)** :
- Utilisé uniquement dans `RejoindreEquipeView` pour les athlètes
- Guard explicite avant login

**Matrice d'application du gating** :
- `peutEcrire` (Pro OU Club) → 10 vues write listées dans les prompts
- `peutConnecterAthletes` (Club only) → RejoindreEquipeView pour `.etudiant` uniquement

### 7. Analytics

**8 événements dans `AnalyticsService`** (constantes `EvenementAnalytics`) :
- `paywall_affiche` · metadata: source (welcome/profile/bloquant)
- `paywall_ferme`
- `essai_demarre` · metadata: tier
- `essai_expire` · metadata: tier
- `achat_initie` · metadata: produit, tier
- `achat_reussi` · metadata: produit, tier, prix
- `achat_echoue` · metadata: raison
- `restauration_tentee`

## Fichiers — récapitulatif

### À créer (12)
- `Playco/Models/Abonnement.swift`
- `Playco/Helpers/IdentifiantsIAP.swift`
- `Playco/Helpers/TextesPaywall.swift`
- `Playco/Helpers/FeatureGating.swift`
- `Playco/Services/StoreKitService.swift`
- `Playco/Services/AbonnementService.swift`
- `Playco/Views/Paywall/ComposantsPaywall.swift`
- `Playco/Views/Paywall/PaywallView.swift`
- `Playco/Views/Paywall/BienvenuePaywallView.swift`
- `Playco/Views/Paywall/GestionAbonnementView.swift`
- `Playco/Views/Paywall/PaywallBloquantView.swift`
- `Playco/Views/Paywall/BanniereAbonnementView.swift`
- `Playco/Playco.storekit` (via Xcode UI)

### À modifier (≥14)
- `Playco/PlaycoApp.swift`
- `Playco/Playco.entitlements`
- `Playco/Models/Utilisateur.swift` (ajout `.assistantCoach`)
- `Playco/Models/Equipe.swift` (ajout `tierAbonnementRaw`)
- `Playco/Helpers/PermissionsRole.swift`
- `Playco/Services/CloudKitSharingService.swift` (propager tier au publish)
- `Playco/Views/Auth/RejoindreEquipeView.swift` (gate tier Club pour athlètes)
- `Playco/Views/Configuration/ConfigurationView.swift` (sheet bloquant + rôle assistant)
- `Playco/Views/Profil/ProfilView.swift` (section abonnement)
- `Playco/Views/ContentView.swift` (bannière)
- `Playco/Services/AnalyticsService.swift` (8 événements)
- `Playco/Views/Matchs/MatchsView.swift`
- `Playco/Views/Seances/ListeSeancesView.swift`
- `Playco/Views/Strategies/StrategiesView.swift`
- `Playco/Views/Equipe/EquipeView.swift`
- `Playco/Views/Entrainement/EntrainementView.swift`
- `Playco/Views/Matchs/ExportMatchPDFView.swift`, `Playco/Views/Equipe/ExportStatsView.swift`
- `Playco/Views/Matchs/SaisieStatsMatchView.swift`, `StatsLiveView.swift`
- `Playco/Views/Profil/ModifierUtilisateurView.swift`

## Vérification end-to-end

### Tests unitaires (cible ≥80%)
- `AbonnementServiceTests` : tierActif pour chaque Statut, peutEcrire / peutConnecterAthletes, migration rôles, rafraichir avec mocks StoreKit
- `StoreKitServiceTests` : chargement 4 produits, achat simulé Pro/Club, trial partagé groupe
- `TierDetectionTests` : `IdentifiantsIAP.tier(pour:)` et `estAnnuel(_:)` pour les 4 IDs

### Tests manuels iPad (iPad Air 13" M3)
1. **Nouveau coach Pro** : wizard → sheet bloquant → sélectionne Pro annuel → essai 14j → app Pro → ProfilView affiche "Essai Pro · 14j"
2. **Nouveau coach Club** : wizard → sheet bloquant → sélectionne Club annuel → essai 14j → app Club
3. **Cancel Apple dialog** : wizard → sheet → "Commencer l'essai" → Apple → Cancel → sheet ferme, lecture seule
4. **Upgrade Pro → Club** : coach Pro actif → ProfilView → GestionAbonnementView → "Voir les plans" → sélectionne Club → Apple upgrade dialog → proration → statut passe Club, `Equipe.tierAbonnement` propagé publiquement
5. **Athlète bloqué (coach Pro)** : coach en essai Pro crée équipe + athlète → athlète tente RejoindreEquipeView → erreur "Ton coach doit activer Club"
6. **Athlète accepté (coach Club)** : coach Club crée équipe → athlète se connecte → MonProfilAthleteView accessible
7. **Assistant coach** (coach Pro OU Club) : connexion via RejoindreEquipeView avec rôle `.assistantCoach` → accès complet permissions coach, aucun paywall
8. **Migration rôles v2.0** : BD seed assistant role "coach" + AssistantCoach match → premier launch → reclasse vers `.assistantCoach`
9. **Essai J-3** : avance clock 11j → bannière orange apparaît
10. **Essai expiré** : avance clock 14j → bannière rouge, paywall bloquant sur create
11. **Grace period** : simuler renewal échoué → bannière jaune, accès maintenu
12. **Revoked (refund)** : `StoreKit Config > Refund Transaction` → `Transaction.updates` → statut .expire immédiat
13. **Loading cache** : quit+relaunch user Pro → pas de flash paywall (cache UserDefaults)
14. **Multi-appareils Pro** : achat Pro iPad A → lancement iPad B même Apple ID → statut Pro récupéré via `Transaction.currentEntitlements`
15. **Multi-appareils Club athlète** : coach Club publie Equipe → athlète autre Apple ID → tier Club visible dans l'Equipe publique → login OK
16. **Restauration** : désinstall/réinstall → "Restaurer" → retrouve statut

### Build
```
cd "/Users/armypo/Documents/Origotech/Playco" && xcodebuild -scheme "Playco" -destination 'platform=iOS Simulator,name=iPad Air 13-inch (M3)' build
```
Cible : 0 erreur, 0 warning.

### Code review MCP
- `detect_changes_tool` sur PlaycoApp, ConfigurationView, ProfilView, ContentView, RejoindreEquipeView
- `get_impact_radius_tool` sur `peutEcrire` et `peutConnecterAthletes`

## Utilitaires réutilisés (DRY)

- `LiquidGlassKit` (rayons, espaces, animations)
- `PaletteMat` (orange Pro, violet Club pour différencier)
- `GlassCard`, `GlassSection`, `GlassButtonStyle`, `GlassChip`
- `DateFormattersCache.formatFrancais`
- `JSONCoderCache` (si cache UserDefaults sérialisé)
- `Logger(subsystem: "com.origotech.playco", category: "storekit"/"abonnement")`
- `PermissionsRole.siAutorise(_:)`
- `AnalyticsService.suivre(evenement:metadonnees:)`
- `CloudKitSharingService.publierEquipeComplete` (à étendre pour propager tier)
- `FiltreParEquipe` pour les vues (pas sur Abonnement)

## Ce que v2.0 NE contient PAS

- Traduction EN (v2.1)
- Notifications push pré-expiration (v2.1)
- Analytics funnel détaillé (v2.1)
- Pages légales hébergées (utilisateur à faire hors scope)
- Promo codes / offres rétention (v2.2)

## App Store Connect (manuel, hors code)

Créer dans App Store Connect :
- Subscription Group "Playco Pro" (ID à reporter dans `IdentifiantsIAP.groupeAbonnement`)
- Level 1 (meilleur) :
  - `com.origo.playco.club.mensuel` · 25 CAD/mois · Free Trial 14 days (First-time only)
  - `com.origo.playco.club.annuel` · 250 CAD/an · Free Trial 14 days
- Level 2 :
  - `com.origo.playco.pro.mensuel` · 14,99 CAD/mois · Free Trial 14 days
  - `com.origo.playco.pro.annuel` · 149,99 CAD/an · Free Trial 14 days
- **Family Sharing DÉSACTIVÉ** sur les 4
- Descriptions FR + EN (EN minimal pour reviewer)
- Screenshots paywall
- Notes reviewer : expliquer que les comptes test coach peuvent être créés via le wizard, athlètes via code équipe du coach test

---

