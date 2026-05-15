# Playco — Paywall v2.0 (Prompts d'implémentation)

> Chaque prompt est **auto-suffisant** : copiable dans une nouvelle session Claude Code. Exécuter dans l'ordre. Sauvegarde future : `/Users/armypo/Documents/Origotech/Playco/paywall/PROMPTS.md`.

**Contexte à rappeler à Claude au besoin** :
- Projet : Playco iOS/iPadOS (SwiftUI + SwiftData + CloudKit), Swift 5.9+
- Working dir : `/Users/armypo/Documents/Origotech/Playco`
- Plan complet : `/Users/armypo/Documents/Origotech/Playco/paywall/PLAN.md`
- CLAUDE.md projet pour les conventions
- Build : `cd "/Users/armypo/Documents/Origotech/Playco" && xcodebuild -scheme "Playco" -destination 'platform=iOS Simulator,name=iPad Air 13-inch (M3)' build`
- Qualité : **0 erreur, 0 warning**

---

## 🟩 P1 — Rôle `.assistantCoach` + Permissions

**Objectif** : Ajouter un rôle utilisateur `.assistantCoach` avec permissions complètes, qui se connecte via code équipe (comme athlètes) mais sans déclencher de paywall.

**Fichiers à modifier** :
- `Playco/Models/Utilisateur.swift` : ajouter `case assistantCoach` dans enum `RoleUtilisateur`. Mettre à jour `label` ("Coach assistant"), `icone` ("person.badge.shield.checkmark"), `couleurHex` ("#4A8AF4")
- `Playco/Helpers/PermissionsRole.swift` : étendre les 7 `var peutXxx: Bool` (peutModifierSeances, peutModifierStrategies, peutGererEquipe, peutEvaluer, peutGererProgrammes, peutExporter, peutCreerComptes) pour inclure `.assistantCoach` comme `.coach`/`.admin`

**Critères d'acceptation** :
- `RoleUtilisateur.allCases.count == 4`
- Aucune régression dans les `#Predicate` SwiftData (ils comparent `roleRaw == "coach"` — les coachs existants restent inchangés pour le moment, la migration vient en P3)
- Build 0 erreur 0 warning

**Pièges** :
- NE PAS supprimer `.coach` (rôle coach payant)
- Utiliser `.assistantCoach` casing strictement cohérent partout

**Tests à écrire** :
- `RoleUtilisateurTests.swift` : 4 cases, labels distincts, couleurs distinctes
- `PermissionsRoleTests.swift` : les 7 permissions retournent true pour `.assistantCoach`

---

## 🟩 P2 — Modèle Abonnement + Equipe.tierAbonnementRaw + Constantes

**Objectif** : Créer le modèle `Abonnement` (cache CloudKit du statut), ajouter `tierAbonnementRaw` à `Equipe` (clé pour la gate athlète multi-Apple-ID), créer les 2 fichiers de constantes.

**Fichiers à créer** :

1. `Playco/Models/Abonnement.swift` :
   - enum `Tier: String, Codable { case aucun, pro, club }`
   - enum `TypeAbonnement: String, Codable { case aucun, essai, mensuel, annuel, gracePeriode, expire }`
   - `@Model final class Abonnement` avec attributs : `id`, `utilisateurID`, `tierRaw`, `typeAbonnementRaw`, `produitIAPID`, `appStoreTransactionID`, `dateDernierSync`, `dateExpiration` (optionnel)
   - **TOUS attributs avec default** (CloudKit piège #15)
   - Computed `tier: Tier` et `type: TypeAbonnement` (get/set)
   - init complet
   - **PAS de `FiltreParEquipe`** (un coach = 1 abo, pas par équipe)

2. `Playco/Helpers/IdentifiantsIAP.swift` :
   - 4 static let pour les product IDs (proMensuel, proAnnuel, clubMensuel, clubAnnuel)
   - `groupeAbonnement = "playco.pro"`
   - `tous: [String]`
   - `static func tier(pour produitID: String) -> Tier`
   - `static func estAnnuel(_ produitID: String) -> Bool`
   - Clés UserDefaults : cleCacheStatut, cleCachePeutEcrire, cleCachePeutConnecterAthletes, cleMigrationRolesDone

3. `Playco/Helpers/TextesPaywall.swift` :
   - enum avec toutes les chaînes FR
   - Titres : "Playco Pro", "Playco Club", "Bienvenue dans Playco"
   - Sous-titres tier Pro : "L'outil complet pour toi et ton staff"
   - Sous-titres tier Club : "Playco Pro + accès app pour tes athlètes"
   - Features Pro : ["Stats live point-par-point", "Export PDF & CSV", "Analytics saison"]
   - Features Club : ["Tout Pro + accès athlètes", "Messagerie coach-athlète", "MonProfilAthleteView"]
   - CTA, badges, bannières, mention auto-renouvellement (**obligatoire App Store**)
   - Messages d'erreur :
     - `erreurAthleteBloque = "Ton coach doit activer Playco Club pour que tu puisses te connecter. Demande-lui de passer au plan Club dans Paramètres → Mon abonnement."`
     - `erreurAssistantBloque = "Ton coach doit renouveler son abonnement Playco pour que tu puisses te connecter."`
   - CTA conditionnel :
     - `ctaEssaiEligible = "Commencer l'essai 14 jours"`
     - `ctaAchatDirect = "S'abonner · "` (préfixe, concaténé avec displayPrice)
   - Badges :
     - `badge14JoursOfferts = "14 jours offerts"`
     - `badgeAnnuelEconomie = "-17 %"`

**Fichier à modifier** :
- `Playco/Models/Equipe.swift` : ajouter `var tierAbonnementRaw: String = Tier.aucun.rawValue` + computed `var tierAbonnement: Tier { get { Tier(rawValue: tierAbonnementRaw) ?? .aucun } set { tierAbonnementRaw = newValue.rawValue } }`

**Critères d'acceptation** :
- `Abonnement.self` compile mais pas encore enregistré dans `PlaycoApp.modeles` (fait en P8)
- `Equipe.tierAbonnementRaw` avec default — CloudKit safe, aucune migration forcée
- Aucun magic string dans les vues futures — tout via `TextesPaywall`

**Pièges** :
- CloudKit piège #15 : defaults partout, pas de relation obligatoire
- Piège #19 : pas de magic number — les prix viennent uniquement de `Product.displayPrice` (StoreKit)

**Tests** :
- `AbonnementModelTests` : création, round-trip tier+type
- `IdentifiantsIAPTests` : `tier(pour:)` retourne .pro/.club/.aucun correctement pour les 4 IDs + 1 inconnu

---

## 🟩 P3 — AbonnementService (sans StoreKit)

**Objectif** : Service @Observable qui expose le statut, le cache UserDefaults, détection coach payant, migration rôles. Stubbe `rafraichir()` pour retourner `.aucun` en attendant P5. Ajoute la propagation tier → Equipe via CloudKitSharingService.

**Fichier à créer** : `Playco/Services/AbonnementService.swift`

Détails :
- `@MainActor @Observable final class AbonnementService`
- enum `Statut` avec les 10 cases listés dans le plan (chargement, aucun, essaiActif(tier, joursRestants), proMensuel/Annuel, clubMensuel/Annuel, gracePeriode(tier, date), essaiExpire, expire(tier, depuis))
- Computed :
  - `var tierActif: Tier` — retourne .club pour club*, .pro pour pro*/essaiActif(.pro, _), .aucun sinon
  - `var peutEcrire: Bool` — true pour tous tiers actifs + grace ; fallback cache pendant .chargement
  - `var peutConnecterAthletes: Bool` — true uniquement si `tierActif == .club` (y compris essaiActif(.club, _), gracePeriode(.club, _))
  - `var joursRestantsEssai: Int?`
  - `var doitAfficherBanniere: Bool`
- Cache UserDefaults lu dans `init()` (lire `cleCacheStatut` JSON via `JSONCoderCache`), écrit après chaque refresh via `persisterCache()`
- `func estCoachPayant(utilisateur: Utilisateur) -> Bool` : `utilisateur.role == .coach || utilisateur.role == .admin`
- `func migrerAssistantsVersNouveauRole(context: ModelContext)` :
  - Guard flag UserDefaults `cleMigrationRolesDone`
  - FetchDescriptor Utilisateur roleRaw == "coach"
  - Pour chaque : fetch AssistantCoach identifiant match → si match, reclasse vers `.assistantCoach`
  - Save + poser flag
- `func propagerTierAuxEquipes(context: ModelContext, sharingService: CloudKitSharingService) async` :
  - FetchDescriptor Equipe (toutes)
  - Pour chaque dont etablissement.profilCoach.id match → set `equipe.tierAbonnement = tierActif`
  - try save
  - `await sharingService.republierEquipes(...)` (voir intégration P8/sharingService)
- Stub `func rafraichir(utilisateur: Utilisateur?, context: ModelContext, storeKit: Any) async` : retourne `.aucun` pour non-coach, `.essaiExpire` pour coach (placeholder jusqu'à P5)
- Logger category "abonnement"

**Critères** :
- `peutEcrire` pendant `.chargement` retourne valeur cachée UserDefaults (pas false par défaut)
- `peutConnecterAthletes` retourne false pour tier .pro et .aucun
- Migration idempotente

**Pièges** :
- `@MainActor` requis (lu par vues SwiftUI)
- Utiliser `JSONCoderCache.encoder/decoder` si sérialisation UserDefaults
- Logger jamais print

**Tests** :
- `AbonnementServiceTests` (UserDefaults suite isolée) : estCoachPayant, migration, peutEcrire cache, peutConnecterAthletes par tier

---

## 🟩 P4 — StoreKitService + Playco.storekit config

**Objectif** : Service StoreKit 2 natif (4 produits), chargement, achat, restauration, observation `Transaction.updates`. Créer le fichier de config StoreKit pour tests sandbox.

**Fichier à créer** : `Playco/Services/StoreKitService.swift`
- `@MainActor @Observable final class StoreKitService`
- `var produits: [Product] = []` peuplé via `Product.products(for: IdentifiantsIAP.tous)`
- `func chargerProduits() async throws`
- `func acheter(_ produit: Product) async throws -> Transaction` :
  - `let result = try await produit.purchase()`
  - `.success(.verified(let tx))` → `await tx.finish()` + return tx
  - `.success(.unverified)` → throw `StoreKitError.unverified` + log critical
  - `.userCancelled` → throw custom `StoreKitError.userCancelled`
  - `.pending` → throw custom `StoreKitError.pending`
- `func restaurer() async throws` : `try await AppStore.sync()` + émettre notification refresh
- `func observerTransactions() -> Task<Void, Never>` : Task.detached itérant `Transaction.updates`, traite .verified, finish, log
- `func statutSouscriptionActif() async -> (produit: Product, status: Product.SubscriptionInfo.Status)?` :
  - Itère `Transaction.currentEntitlements`
  - Filtre .verified + productID in IdentifiantsIAP.tous
  - Pour le dernier : retrouve le Product, récupère `product.subscription?.status.first`
  - Return tuple
- Logger category "storekit"

**Fichier à créer via Xcode UI** : `Playco/Playco.storekit`
- Via Xcode : File → New → File → StoreKit Configuration File
- Subscription Group "Playco Pro"
- Level 1 : Club mensuel 25.00 CAD + Club annuel 250.00 CAD — Introductory Offer Free 2 weeks (First-time only)
- Level 2 : Pro mensuel 14.99 CAD + Pro annuel 149.99 CAD — Introductory Offer Free 2 weeks
- Family Sharing OFF sur les 4
- Référencer dans Scheme → Run → Options → StoreKit Configuration

**Critères** :
- `chargerProduits()` → `produits.count == 4`
- Achat sandbox simulable avec le fichier storekit
- `acheter()` avec Cancel → throw spécifique
- `observerTransactions()` Task ne se termine jamais tant que l'app tourne

**Pièges** :
- `.verified` obligatoire — jamais accorder Pro à `.unverified`
- `transaction.finish()` APRÈS persistence, pas avant
- `observerTransactions` doit être lancé au démarrage avant le chargement UI (sinon on rate les renewals)

**Tests** : `StoreKitServiceTests` avec `StoreKitTest` framework et `testSession` pointant sur Playco.storekit

---

## 🟩 P5 — Brancher rafraichir() sur StoreKitService

**Objectif** : Remplacer le stub P3 par le mapping complet des 4 produits × états Apple vers la `Statut` enum.

**Fichier à modifier** : `Playco/Services/AbonnementService.swift` — réécrire `rafraichir(utilisateur:context:storeKit:)` :

```swift
func rafraichir(utilisateur: Utilisateur?, context: ModelContext, storeKit: StoreKitService) async {
    let ancienStatut = statut
    guard let user = utilisateur, estCoachPayant(utilisateur: user) else {
        statut = .aucun
        persisterCache()
        return
    }
    guard let infoSubscription = await storeKit.statutSouscriptionActif() else {
        statut = determinerStatutSansEntitlement(contexte: context, utilisateur: user)
        persisterCache()
        return
    }
    let produit = infoSubscription.produit
    let status = infoSubscription.status
    let tier = IdentifiantsIAP.tier(pour: produit.id)
    let annuel = IdentifiantsIAP.estAnnuel(produit.id)
    let expDate = status.transaction.unsafePayloadValue.expirationDate

    switch status.state {
    case .inTrial:
        let jours = max(0, Calendar.current.dateComponents([.day], from: Date(), to: expDate ?? Date()).day ?? 0)
        statut = .essaiActif(tier: tier, joursRestants: jours)
    case .subscribed:
        switch (tier, annuel) {
        case (.pro, true): statut = .proAnnuel(dateRenouvellement: expDate ?? Date())
        case (.pro, false): statut = .proMensuel(dateRenouvellement: expDate ?? Date())
        case (.club, true): statut = .clubAnnuel(dateRenouvellement: expDate ?? Date())
        case (.club, false): statut = .clubMensuel(dateRenouvellement: expDate ?? Date())
        default: statut = .aucun
        }
    case .inGracePeriod, .inBillingRetryPeriod:
        statut = .gracePeriode(tier: tier, dateExpirationAttendue: expDate ?? Date())
    case .expired:
        statut = .expire(tier: tier, depuis: expDate ?? Date())
    case .revoked:
        let revDate = status.transaction.unsafePayloadValue.revocationDate ?? Date()
        statut = .expire(tier: tier, depuis: revDate)
    default:
        statut = .essaiExpire
    }

    persisterCache()
    persisterDansSwiftData(context: context, utilisateur: user, produit: produit)
    if tierActif != tierAvant(statut: ancienStatut) {
        await propagerTierAuxEquipes(context: context, sharingService: /* injected */)
    }
    detecterEvenementsAnalytics(ancien: ancienStatut, nouveau: statut)
}
```

**Critères** :
- 8 états StoreKit mappés (inTrial, subscribed, inGracePeriod, inBillingRetryPeriod, expired, revoked, + fallback)
- Tier correctement déduit du productID
- Cache SwiftData persisté avec produitIAPID + dateExpiration
- Propagation tier vers Equipe uniquement si tier a changé (éviter spam CloudKit)
- Analytics events émis sur transitions (essai_demarre, essai_expire)

**Pièges** :
- `unsafePayloadValue` contourne la vérification — à utiliser seulement si on a déjà check .verified avant
- Dates Apple : `.expired` peut avoir expDate passé, c'est normal
- Calcul joursRestants arrondi au supérieur, min 0

**Tests** :
- Mock StoreKitService retournant chaque état → assert bon Statut
- Transition essai → expire → event analytics émis une fois

---

## 🟩 P6 — UI Paywall base : Composants + PaywallView

**Objectif** : Composants DRY + vue canonique PaywallView avec 2 PricingCard (Pro/Club), toggle mensuel/annuel, style TutorielView.

**Fichiers à créer** :

1. `Playco/Views/Paywall/ComposantsPaywall.swift` :
   - `struct FeatureRow(icone: String, titre: String)` — SF Symbol hierarchical blanc + texte blanc 0.85
   - `struct PricingCard(produit: Product, estSelectionne: Bool, badge: String?, couleurTier: Color)` — GlassCard teinté, prix `produit.displayPrice`, période, équivalent /mois calculé
   - `struct SelecteurPeriode(selection: Binding<Periode>)` où `enum Periode { case mensuel, annuel }` — segmented style
   - `struct BadgeStatut(statut: AbonnementService.Statut)` — capsule colorée selon tier/état
   - `struct BanniereEssai(statut:)` — texte TextesPaywall approprié

2. `Playco/Views/Paywall/PaywallView.swift` :
   - `enum ModePaywall { case welcome, bloquant, gestion }`
   - `@Environment(StoreKitService.self)`, `@Environment(AbonnementService.self)`, `@Environment(AnalyticsService.self)`
   - `@State var periode: Periode = .annuel` (annuel par défaut = meilleur deal)
   - `@State var produitSelectionne: Product?` (initialisé au **Pro annuel** au `onAppear`)
   - `@State var eligibiliteParProduit: [String: Bool] = [:]` peuplé dans `onAppear` via `await produit.subscription?.isEligibleForIntroOffer`
   - Fond noir + RadialGradient orange animé (cf. TutorielView.swift)
   - ScrollView :
     - Header : "Playco" logo + titre selon mode (TextesPaywall.titreWelcome/Bloquant/Gestion)
     - SelecteurPeriode (toggle mensuel/annuel)
     - 2 PricingCard côte à côte iPad / empilés iPhone :
       - Pro (couleur orange) avec 3 features TextesPaywall.featuresPro
       - Club (couleur violet) avec "Tout Pro +" + 3 features TextesPaywall.featuresClub
       - Chaque card lit `eligibiliteParProduit[produit.id]` → affiche "14 jours offerts" badge si eligible, rien si pas eligible
     - CTA primaire dynamique :
       - Si `eligibiliteParProduit[produitSelectionne.id] == true` → "Commencer l'essai 14 jours"
       - Sinon → "S'abonner · \(produitSelectionne.displayPrice)"
     - Bouton "Restaurer mes achats"
     - Mention auto-renouvellement en small
     - Links CGU + Privacy
   - Action CTA : `try await storeKit.acheter(produitSelectionne)` → sur success dismiss ; sur cancel toast
   - `onAppear` : analytics paywall_affiche + charger éligibilité des 4 produits + pré-sélectionner Pro annuel
   - `onDisappear` (mode != bloquant) : paywall_ferme

**Critères** :
- 4 produits affichés selon la période sélectionnée (2 à la fois)
- Toggle mensuel/annuel fluide avec spring animation
- Prix viennent de Product.displayPrice (localisés)
- iPad paysage : 2 cards côte à côte bien centrées, max width 650
- iPad portrait / iPhone : cards empilées

**Pièges** :
- Piège #19 : LiquidGlassKit pour rayons/espaces/animations
- Aucune string en dur — TextesPaywall partout
- Respecter iPad-first pour layout

---

## 🟩 P7 — UI Paywall variants : Bienvenue + Gestion + Bloquant + Bannière

**Objectif** : 4 wrappers autour de PaywallView gérant les cas d'usage.

**Fichiers à créer** :

1. `Playco/Views/Paywall/BienvenuePaywallView.swift` :
   - Wrapper `PaywallView(mode: .welcome)` dans NavigationStack
   - `interactiveDismissDisabled(true)` sur le sheet parent (pas de swipe)
   - Titre : TextesPaywall.titreWelcome ("Bienvenue dans Playco · 14 jours offerts")
   - Sous-titre : "Choisis le plan qui correspond à ta façon de coacher"
   - 3 issues callback `onTermine`:
     1. Essai démarré → toast "Ton essai Pro/Club a commencé · 14j offerts"
     2. Achat direct → toast "Abonnement Pro/Club activé"
     3. Cancel Apple dialog → dismiss + toast "Tu peux t'abonner plus tard · Mode lecture seule"

2. `Playco/Views/Paywall/GestionAbonnementView.swift` :
   - Push NavigationLink depuis ProfilView
   - BadgeStatut + infos tier actif + date renouv formatée `DateFormattersCache.formatFrancais`
   - Bouton "Gérer mon abonnement Apple" → openURL `https://apps.apple.com/account/subscriptions`
   - Si tier == .pro : NavigationLink "Passer à Club" → push PaywallView(.gestion) avec Club pré-sélectionné
   - Si tier == .club : texte "Tu as accès à toutes les fonctionnalités"
   - Bouton "Restaurer mes achats"

3. `Playco/Views/Paywall/PaywallBloquantView.swift` :
   - Wrapper `PaywallView(mode: .bloquant)` en fullScreenCover
   - `interactiveDismissDisabled(true)` + pas de X
   - Titre : "Abonne-toi pour continuer à créer"

4. `Playco/Views/Paywall/BanniereAbonnementView.swift` :
   - HStack compact, couleur selon gravité (orange essai, jaune grace, rouge expire)
   - Textes TextesPaywall.banniere* selon statut
   - Tap → sheet PaywallView(.bloquant)
   - Hidden si `!abonnementService.doitAfficherBanniere` OU si user.role != coach/admin

**Critères** :
- Les 4 vues réutilisent PaywallView (zéro duplication layout)
- BienvenuePaywallView vraiment non-dismissable
- Bannière jamais affichée pour assistants/athlètes

---

## 🟩 P8 — Intégration PlaycoApp + CloudKitSharingService

**Objectif** : Injecter services, ajouter Abonnement au schema, lancer migration + chargement au démarrage. Étendre CloudKitSharingService pour publier le tier.

**Fichiers à modifier** :

1. `Playco/PlaycoApp.swift` :
   - `@State private var storeKitService = StoreKitService()`
   - `@State private var abonnementService = AbonnementService()`
   - `@State private var observerTask: Task<Void, Never>? = nil`
   - Ajouter `Abonnement.self` dans `PlaycoApp.modeles`
   - Case `.app` onAppear :
     ```swift
     Task {
         await syncService.attendreSyncInitiale()
         authService.restaurerSession(context: container.mainContext)
         abonnementService.migrerAssistantsVersNouveauRole(context: container.mainContext)
         try? await storeKitService.chargerProduits()
         await abonnementService.rafraichir(
             utilisateur: authService.utilisateurConnecte,
             context: container.mainContext,
             storeKit: storeKitService,
             sharingService: sharingService
         )
         observerTask = storeKitService.observerTransactions()
     }
     ```
   - `.environment(storeKitService)` + `.environment(abonnementService)` sur ContentView, ConfigurationView

2. `Playco/Services/CloudKitSharingService.swift` (à lire pour comprendre l'API existante) :
   - Étendre `publierEquipeComplete(...)` ou ajouter `func republierEquipes(_ equipes: [Equipe]) async` pour propager `tierAbonnementRaw` dans les records publics CloudKit
   - Logger la republication

**Critères** :
- Build 0 erreur
- Abonnement.self dans schema → CloudKit OK (defaults partout)
- Migration rôles au premier launch v2.0 une seule fois
- Observer task tourne en continu
- `propagerTierAuxEquipes` met à jour publiquement les Equipe via sharingService

**Pièges** :
- Ordre critique : restaurerSession → migrer → charger → rafraichir → observer
- Annuler observerTask quand app backgrounded si nécessaire (ou laisser tourner)

---

## 🟩 P9 — Intégration ConfigurationView + RejoindreEquipeView

**Objectif** : Sheet bloquant welcome à la fin du wizard, gate Club pour athlètes, accepter assistantCoach.

**Fichiers à modifier** :

1. `Playco/Views/Configuration/ConfigurationView.swift` :
   - `@State var afficherBienvenuePaywall = false`
   - `@Environment(AbonnementService.self)`, `@Environment(StoreKitService.self)`
   - Modifier `finaliser()` : au lieu de `onTermine()` direct, set `afficherBienvenuePaywall = true`
   - `.sheet(isPresented: $afficherBienvenuePaywall) { BienvenuePaywallView(onTermine: onTermine) }.interactiveDismissDisabled(true)`
   - **AVANT le sheet** : appeler `await abonnementService.rafraichir(...)` pour actualiser le statut
   - Ligne 324 (création assistants) : `role: .coach` → `role: .assistantCoach`

2. `Playco/Views/Auth/RejoindreEquipeView.swift` :
   - Accepter les users `.assistantCoach` comme on accepte `.coach` et `.etudiant`
   - **Remplacer la gate inline par un appel à la gate centrale** (définie dans PlaycoApp) — RejoindreEquipeView appelle simplement `onConnecte()` en success, et PlaycoApp applique la gate centralement.

3. `Playco/PlaycoApp.swift` — **Gate sécurité centrale** :
   - Nouveau helper `appliquerGateTier()` dans PlaycoApp appelé :
     - Après chaque `onConnecte` de LoginView et RejoindreEquipeView
     - Dans le `onAppear` de case `.app` APRÈS `restaurerSession`
     - Via `onChange(of: abonnementService.statut)` dans ContentView : si role == .etudiant ET tier != .club → déconnexion immédiate
   - Logique :
     ```swift
     @State private var erreurGate: String? = nil

     private func appliquerGateTier(context: ModelContext) {
         guard let user = authService.utilisateurConnecte else { return }
         let equipe = fetchEquipeActive(user: user, context: context)
         let tier = equipe?.tierAbonnement ?? .aucun

         switch user.role {
         case .etudiant:
             if tier != .club {
                 authService.deconnexion()
                 erreurGate = TextesPaywall.erreurAthleteBloque
                 ecranActif = .choixInitial
             }
         case .assistantCoach:
             if tier == .aucun {
                 authService.deconnexion()
                 erreurGate = TextesPaywall.erreurAssistantBloque
                 ecranActif = .choixInitial
             }
             // Si tier == .pro ou .club → OK login (lecture seule si coach expire se gère via peutEcrire)
         default:
             break // coach/admin : pas de gate tier pour eux-mêmes
         }
     }

     private func fetchEquipeActive(user: Utilisateur, context: ModelContext) -> Equipe? {
         let code = user.codeEcole
         let desc = FetchDescriptor<Equipe>(predicate: #Predicate { $0.codeEquipe == code })
         return try? context.fetch(desc).first
     }
     ```
   - Alert pour `erreurGate` affiché dans case `.choixInitial`

**Critères** :
- Nouveau coach finit wizard → sheet bloquant apparaît
- Les 3 issues du sheet déclenchent onTermine
- Assistants ont bien role .assistantCoach après wizard
- Athlète tente login (via RejoindreEquipeView OU LoginView bypass) avec code équipe dont coach a tier .pro → **gate centrale** → déconnecté automatiquement + message
- Athlète tente login avec code équipe dont coach a tier .club → succès
- Assistant tente login avec coach expiré (tier .aucun) → déconnexion + message "ton coach doit renouveler"
- Pendant session active : athlète connecté, tier drop .club → .pro → **déconnexion immédiate** via onChange dans ContentView
- Pendant session active : assistant connecté, coach expire → reste connecté en lecture seule (peutEcrire=false)

**Pièges** :
- `finaliser()` n'est pas async — utiliser `Task { }` pour rafraichir
- La gate centrale doit couvrir LoginView, RejoindreEquipeView, et restaurerSession (3 chemins)
- Pour l'athlète : déconnexion immédiate = strict ; pour assistant : lecture seule = doux. Logique différenciée par role

---

## 🟩 P10 — Intégration ProfilView + ContentView

**Objectif** : Section "Mon abonnement" dans ProfilView (coach), bannière dans ContentView (coach).

**Fichiers à modifier** :

1. `Playco/Views/Profil/ProfilView.swift` :
   - `@Environment(AbonnementService.self)`
   - Créer `sectionAbonnement` : Label + BadgeStatut + tier + date renouv + NavigationLink vers GestionAbonnementView
   - Insérer entre `sectionCodeEquipe` et `sectionVisibilite`
   - `.siAutorise(estCoach)` pour masquer aux athlètes/assistants

2. `Playco/Views/ContentView.swift` :
   - `@Environment(AbonnementService.self)` et propager aux sous-vues
   - `.safeAreaInset(edge: .top) { if abonnementService.doitAfficherBanniere && authService.utilisateurConnecte?.role == .coach || .admin { BanniereAbonnementView() } }`
   - Animation spring pour apparition/disparition

**Critères** :
- ProfilView coach affiche tier actuel + date ; ProfilView athlète ne l'affiche pas
- Bannière visible pour coachs en essai J-3/J-1/expiré/grace uniquement
- Pas de flash au launch (cache fait foi pendant rafraichir initial)

---

## 🟩 P11 — Feature gating `.bloqueSiNonPayant()`

**Objectif** : Modifier réutilisable + application sur ~10 vues write.

**Fichier à créer** : `Playco/Helpers/FeatureGating.swift`
```swift
struct BloqueSiNonPayant: ViewModifier {
    @Environment(AbonnementService.self) private var service
    @State private var afficherPaywall = false
    let source: String

    func body(content: Content) -> some View {
        if service.peutEcrire {
            content
        } else {
            content
                .allowsHitTesting(false)
                .opacity(0.5)
                .overlay {
                    Button { afficherPaywall = true } label: { Color.clear }
                }
                .fullScreenCover(isPresented: $afficherPaywall) {
                    PaywallBloquantView(source: source)
                }
        }
    }
}
extension View {
    func bloqueSiNonPayant(source: String) -> some View { modifier(BloqueSiNonPayant(source: source)) }
}
```

**Fichiers à modifier** (appliquer `.bloqueSiNonPayant(source:)`) :
1. `Playco/Views/Matchs/MatchsView.swift` — bouton "+ Nouveau match" (source: "matchs_create")
2. `Playco/Views/Seances/ListeSeancesView.swift` ou PratiquesView — bouton nouvelle séance (source: "seances_create")
3. `Playco/Views/Strategies/StrategiesView.swift` — nouvelle stratégie (source: "strategies_create")
4. `Playco/Views/Equipe/EquipeView.swift` — nouveau joueur (source: "joueur_create")
5. `Playco/Views/Entrainement/EntrainementView.swift` — nouveau programme (source: "programme_create")
6. `Playco/Views/Matchs/ExportMatchPDFView.swift` — ShareLink (source: "export_pdf")
7. `Playco/Views/Equipe/ExportStatsView.swift` — ShareLink (source: "export_csv")
8. `Playco/Views/Matchs/SaisieStatsMatchView.swift` — bouton enregistrer (source: "stats_write")
9. `Playco/Views/Matchs/StatsLiveView.swift` — enregistrer point (source: "stats_live")
10. `Playco/Views/Profil/ModifierUtilisateurView.swift` — enregistrer modifs (source: "user_edit")

**Critères** :
- Coach essai actif : tous boutons OK
- Coach expiré : paywall au tap
- Assistant coach/athlète : boutons OK (peutEcrire true car non-coach-payant côté tier logic — attention: assistant ne doit PAS être bloqué par le paywall même si son coach n'a pas payé, car son coach l'a dans AssistantCoach → coach gère le paiement)

**Pièges** :
- La logique "qui paie" vs "qui peut écrire" : un assistant d'un coach Pro peut écrire (coach paie), un assistant d'un coach expiré ne peut pas écrire (coach bloqué, toute l'équipe bloquée)
- Cela nécessite que AbonnementService vérifie le tier du **coach propriétaire** de l'équipe que l'assistant édite, pas son propre rôle
- **Décision simplifiée pour v2.0** : le service lit le tier via le `codeEquipeActif` (EnvironmentKey existante) → fetch `Equipe` → lit `tierAbonnement` publique. Si tier != .pro/.club alors `peutEcrire = false`.
- À ajuster dans AbonnementService.peutEcrire selon le contexte user (coach payant → son propre Abonnement ; assistant → tier de l'équipe active)

---

## 🟩 P12 — Analytics 8 événements

**Objectif** : Brancher les 8 événements dans `AnalyticsService`.

**Fichier à modifier** : chercher `EvenementAnalytics` dans Services/ (probablement dans `AnalyticsService.swift`)

Ajouter 8 constantes :
```swift
static let paywallAffiche     = "paywall_affiche"
static let paywallFerme       = "paywall_ferme"
static let essaiDemarre       = "essai_demarre"
static let essaiExpire        = "essai_expire"
static let achatInitie        = "achat_initie"
static let achatReussi        = "achat_reussi"
static let achatEchoue        = "achat_echoue"
static let restaurationTentee = "restauration_tentee"
```

Sites d'appel :
- PaywallView.onAppear → paywall_affiche metadata: ["source": mode.rawValue]
- PaywallView.onDisappear (mode != .bloquant) → paywall_ferme
- StoreKitService.acheter début → achat_initie ["produit": p.id, "tier": tier.rawValue]
- StoreKitService.acheter succès → achat_reussi ["produit": p.id, "tier": ..., "prix": p.displayPrice]
- StoreKitService.acheter erreur → achat_echoue ["raison": description]
- StoreKitService.restaurer début → restauration_tentee
- AbonnementService.rafraichir transition .aucun → essaiActif → essai_demarre ["tier": tier.rawValue]
- AbonnementService.rafraichir transition essaiActif → .essaiExpire → essai_expire ["tier": ...]

**Critères** :
- Pas de double émission sur rafraichir répété avec même état
- Metadata toujours string:string

---

## 🟩 P13 — Entitlements + StoreKit config Xcode

**Objectif** : Activer IAP capability + référencer Playco.storekit dans scheme.

**Fichier à modifier** : `Playco/Playco.entitlements` — ajouter avant `</dict>` :
```xml
<key>com.apple.developer.in-app-purchase</key>
<array/>
```

**Manuel Xcode** (hors code) :
1. Target Playco → Signing & Capabilities → + Capability → "In-App Purchase"
2. Scheme Playco → Edit Scheme → Run → Options → StoreKit Configuration → sélectionner Playco.storekit

**Critères** :
- Build 0 erreur
- Run simulateur : paywall affiche 4 produits avec prix CAD
- Achat sandbox fonctionnel

---

## 🟩 P14 — Validation finale

**Objectif** : Build propre + 16 scénarios manuels + code review MCP + checklist App Store Connect.

**Actions** :

1. **Build** :
```bash
cd "/Users/armypo/Documents/Origotech/Playco" && xcodebuild -scheme "Playco" -destination 'platform=iOS Simulator,name=iPad Air 13-inch (M3)' build
```
Cible : 0 erreur, 0 warning.

2. **Tests unitaires** : `xcodebuild test` → tous les tests P1-P5 verts.

3. **16 scénarios manuels** (liste complète dans le plan — Partie 1 section "Tests manuels iPad").

4. **Code review MCP** :
   - `detect_changes_tool` sur les fichiers principaux modifiés
   - `get_impact_radius_tool` sur `peutEcrire` et `peutConnecterAthletes`

5. **Checklist App Store Connect** (hors code, user à faire) :
   - [ ] Subscription Group "Playco Pro" créé
   - [ ] 4 produits créés (Pro/Club × mensuel/annuel) avec bons prix CAD
   - [ ] Introductory Offer Free 14 days sur les 4 (First-time only)
   - [ ] Family Sharing DÉSACTIVÉ sur les 4
   - [ ] Descriptions FR + EN
   - [ ] Screenshots paywall pour review
   - [ ] Notes reviewer expliquant création comptes test

6. **Mise à jour CLAUDE.md** : ajouter entrée patch v2.0 dans l'historique.

**Critères d'acceptation finaux** :
- 0 erreur / 0 warning
- 16/16 scénarios passent
- AbonnementService ≥ 80% coverage
- Commit : `feat: paywall v2.0 Playco Pro + Club (2 tiers)`
- TestFlight v2.0 uploaded

---

