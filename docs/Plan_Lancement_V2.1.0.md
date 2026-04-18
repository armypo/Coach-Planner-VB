# Plan de lancement Playco v2.1.0 — App Store

**Date de rédaction** : 17 avril 2026
**État de départ** : branche `claude/admiring-bohr-4a25b3` sur `179fc66` (login v2.0 + paywall v2.0 pushés)
**Cible** : soumission App Store après beta TestFlight validée
**Chemin critique** : ~4-6 semaines (limité par beta + ASC + marketing, pas par code)

## Légende des responsabilités
- 🤖 **Moi seul** (Claude Code, code pur, je livre un commit)
- 🤝 **Conjoint** (je prépare le contenu / code, tu fais une manipulation Xcode ou ASC)
- 👤 **Toi seul** (action externe : achat domaine, recrutement beta, App Review, etc.)
- 📦 **Livrable** à la fin de l'étape

---

## Vue d'ensemble — 5 sprints

| Sprint | Nom | Durée | Responsable | Bloquant suivant |
|---|---|---|---|---|
| **S1** | Dette code finalisée | 1 jour | 🤖 | — |
| **S2** | Infra + App Store Connect | 3-5 jours | 🤝 | S4 |
| **S3** | Content fiche App Store | 2-3 jours | 🤝 | S4 |
| **S4** | TestFlight beta interne | 2-3 semaines | 👤 + 🤖 (itérations) | S5 |
| **S5** | Soumission + review | 1-2 jours code, 2-7 jours review | 🤝 | ship |

On peut paralléliser S2 et S3 pendant que je tourne S1.

---

## 🔬 Code Review Excellence — findings v2.1.0

Revue formelle des commits `0f076bb` (login v2.0) + `179fc66` (paywall v2.0) avec le framework **code-review-excellence** (sévérité 🔴 BLOCKING / 🟡 IMPORTANT / 🟢 LOW, question approach, suggest-don't-command).

### 🔴 BLOCKING — à fixer dans S1 avant toute release

| # | Item | Fichier · ligne | Fix |
|---|---|---|---|
| **B1** | `propagerTierAuxEquipes` **n'écrit jamais** dans la CloudKit public DB → gate athlète multi-Apple-ID non fonctionnelle (feature Club cassée) | [AbonnementService.swift:161-193](../Playco/Services/AbonnementService.swift) | Ajouter `republierEquipeComplete(equipe:)` à [CloudKitSharingService.swift](../Playco/Services/CloudKitSharingService.swift) + appeler depuis `propagerTierAuxEquipes` |
| **B2** | `Statut` Equatable avec Date fluctuante → `onChange` trigger en boucle → risque de déconnexion athlète répétée | [AbonnementService.swift:25-37](../Playco/Services/AbonnementService.swift) + [ContentView.swift:109](../Playco/Views/ContentView.swift) | Custom `Equatable` qui compare seulement (tier, type-de-cas) en ignorant les Date |

### 🟡 IMPORTANT — à inclure dans S1

| # | Item | Fichier · ligne | Fix |
|---|---|---|---|
| **I2** | `statutSouscriptionActif` retourne le dernier match (non-déterministe) → bug pendant upgrade Pro→Club | [StoreKitService.swift:110-118](../Playco/Services/StoreKitService.swift) | Sort par `transaction.purchaseDate` decroissant, prendre `.first` |
| **I4** | `regenererMdp` `try? save()` silencieux → si échec, mdp UI ≠ mdp BD | [IdentifiantsEquipeView.swift:107-119](../Playco/Views/Profil/IdentifiantsEquipeView.swift) | `do/catch` + alert coach |

### 🟡 IMPORTANT — S5 (dette technique post-launch, non-bloquant)

| # | Item | Fichier | Fix proposé |
|---|---|---|---|
| **I1** | `observerTransactionsTask` jamais cancellé | [PlaycoApp.swift:20](../Playco/PlaycoApp.swift) | Annuler dans `.onDisappear` de `ContentView` |
| **I3** | `rafraichir` ~80 lignes monolithique | [AbonnementService.swift:200-244](../Playco/Services/AbonnementService.swift) | Découper en helpers testables (déjà partiellement fait) |

### 🟢 LOW / NITS — backlog S5

- **L1** · `IdentifiantsIAP.tous` Array → Set pour O(1) `contains`
- **L2** · `genererMotDePasseAthlete` compactMap avec optional → guard explicite
- **L3** · `PaywallView.layoutCartes` : `UIDevice.current.userInterfaceIdiom` non réactif Stage Manager → `@Environment(\.horizontalSizeClass)`
- **L4** · `PaywallView.chargerInitial` : requêtes éligibilité séquentielles → `TaskGroup` parallèle
- **L5** · `ConfigMembresView.autoIdJoueur/autoIdAssistant` dupliqués → helper générique
- **L6** · `AjoutUtilisateurView.creerCompte` ~90 lignes → découper

---

## 🚀 SPRINT 1 — Finir la dette code (🤖, ~1 jour)

Objectif : tous les items code-side résiduels résolus, build clean iPad physique, commit + push.

### S1.0 · Fix B1 — Propagation tier vers CloudKit public (~45 min)
**Fichiers** :
- [Playco/Services/CloudKitSharingService.swift](../Playco/Services/CloudKitSharingService.swift) — ajouter `func republierEquipeComplete(equipe: Equipe) async` qui met à jour le record public `EquipePartagee` avec `tierAbonnementRaw`
- [Playco/Services/AbonnementService.swift](../Playco/Services/AbonnementService.swift) — injecter `sharingService` dans `propagerTierAuxEquipes`, l'appeler pour chaque équipe modifiée
- [Playco/PlaycoApp.swift](../Playco/PlaycoApp.swift) — passer `sharingService` à `rafraichir` (enchainement onAppear case `.app`)

**Critère** : Grep `republierEquipeComplete` → au moins 2 matches (définition + appel). Pas de « Republication CloudKit sera faite en P8 » restant.

### S1.0.1 · Fix B2 — Statut custom Equatable (~20 min)
**Fichier** : [Playco/Services/AbonnementService.swift](../Playco/Services/AbonnementService.swift)
- Supprimer `: Equatable` auto-synthétisé
- Implémenter `static func == (lhs: Statut, rhs: Statut) -> Bool` qui compare uniquement la forme (tier + type de cas), ignorant les Date associées
- Test : `AbonnementServiceStatutTests` vérifiant que `.proAnnuel(date: d1) == .proAnnuel(date: d2)` avec d1≠d2

**Critère** : `onChange(of: abonnementService.statut)` dans ContentView ne trigger plus sur simple refresh StoreKit si la forme logique est identique.

### S1.0.2 · Fix I2 — statutSouscriptionActif déterministe (~10 min)
**Fichier** : [Playco/Services/StoreKitService.swift:110-118](../Playco/Services/StoreKitService.swift)
- Collecter tous les `(produit, status, purchaseDate)` candidats
- Retourner celui avec `purchaseDate` le plus récent (ou via `renewalInfo` expiration, au choix)

**Critère** : Lors d'un upgrade Pro→Club, l'API retourne le Club (dernier achat) pas le Pro.

### S1.0.3 · Fix I4 — regenererMdp error handling (~15 min)
**Fichier** : [Playco/Views/Profil/IdentifiantsEquipeView.swift](../Playco/Views/Profil/IdentifiantsEquipeView.swift)
- Remplacer `try? modelContext.save()` par `do/catch`
- Si échec : `logger.error` + `afficherErreurMdp = true` + revert `cred.motDePasseClair` à l'ancien
- Nouvel état `@State var erreurRegeneration: String?` + alert

**Critère** : Désactiver Wi-Fi + tester régénération → alert affiché, mdp UI ≠ affichage confus.

### S1.1 · Bump de version (15 min)
**Fichiers** : `Playco.xcodeproj/project.pbxproj`
- `MARKETING_VERSION` → `2.1.0` (4 occurrences)
- `CURRENT_PROJECT_VERSION` → `3` (3 occurrences)
- Vérifier que le scheme n'a pas de hardcoded override

**📦 Livrable** : commit `chore: bump version 2.1.0 (build 3)`

### S1.2 · Paywall feature gating sur les 7 vues write restantes (~1h)
Appliquer `.bloqueSiNonPayant(source: "…")` (modifier défini dans [FeatureGating.swift](../Playco/Helpers/FeatureGating.swift)) sur :

| Vue | Ligne à gater | Source analytics |
|---|---|---|
| [StrategiesView.swift](../Playco/Views/Strategies/StrategiesView.swift) | bouton « + nouvelle stratégie » | `strategies_create` |
| [EquipeView.swift](../Playco/Views/Equipe/EquipeView.swift) | bouton « ajouter joueur » | `joueur_create` |
| [EntrainementView.swift](../Playco/Views/Entrainement/EntrainementView.swift) | bouton « nouveau programme » | `programme_create` |
| [SaisieStatsMatchView.swift](../Playco/Views/Matchs/SaisieStatsMatchView.swift) | bouton enregistrer | `stats_write` |
| [StatsLiveView.swift](../Playco/Views/Matchs/StatsLiveView.swift) | boutons de saisie point | `stats_live` |
| [ModifierUtilisateurView.swift](../Playco/Views/Profil/ModifierUtilisateurView.swift) | bouton enregistrer | `user_edit` |
| [ExportMatchPDFView.swift](../Playco/Views/Matchs/ExportMatchPDFView.swift) | ShareLink PDF | `export_pdf` |

**📦 Livrable** : commit `feat(paywall): gate 7 vues write restantes`

### S1.3 · Accessibility labels — batch 2 (~1-2h)
Étendre les `accessibilityLabel` / `accessibilityHint` / `accessibilityValue` sur les vues non encore couvertes.

Déjà couvert : StatsLiveView, PaveNumeriqueRapideView, AccueilView, DashboardMatchLiveView, RotationLiveView (21 labels).

**À ajouter** :
- [LoginView.swift](../Playco/Views/Auth/LoginView.swift) — picker 3 tabs + champs + bouton Connexion
- [ChoixInitialView.swift](../Playco/Views/Auth/ChoixInitialView.swift) — 2 boutons principaux
- [MatchsView.swift](../Playco/Views/Matchs/MatchsView.swift) — bouton +, barre outils
- [EquipeView.swift](../Playco/Views/Equipe/EquipeView.swift) — liste joueurs + tableau bord
- [BienvenuePaywallView.swift](../Playco/Views/Paywall/BienvenuePaywallView.swift) — cartes tier + CTA
- [BanniereAbonnementView.swift](../Playco/Views/Paywall/BanniereAbonnementView.swift) — bouton bannière
- [IdentifiantsEquipeView.swift](../Playco/Views/Profil/IdentifiantsEquipeView.swift) — régénérer + copier + partager
- Scores et compteurs : `.accessibilityValue("\(scoreEquipe) points contre \(scoreAdv)")`

Cible : ~20 labels supplémentaires pour que VoiceOver puisse naviguer le flow principal de bout en bout.

**📦 Livrable** : commit `feat(a11y): accessibilityLabels pour auth + paywall + navigation`

### S1.4 · Scaffold TelemetryDeck — préparation (~30 min)
[AnalyticsService.swift](../Playco/Services/AnalyticsService.swift) contient déjà le scaffold (mode `logger-only`) avec `_placeholderAppID`. Je laisse tel quel pour l'instant — l'intégration complète se fait en S2.6 avec l'App ID que tu auras créé.

### S1.5 · Build iPad physique + vérifications (~15 min)
```bash
cd "/Users/armypo/Documents/Origotech/Playco/.claude/worktrees/admiring-bohr-4a25b3" && \
xcodebuild -scheme "Playco" \
  -destination 'platform=iOS,id=00008103-0001050814D3C01E' \
  clean build
```
Cible : 0 erreur, 0 warning nouveau.

### S1.6 · Tests Swift Testing (~10 min)
Relancer les 12 tests login v2.0 :
```bash
xcodebuild test -scheme "Playco" \
  -destination 'platform=iOS,id=00008103-0001050814D3C01E' \
  -only-testing:PlaycoTests/UtilisateurIdentifiantTests \
  -only-testing:PlaycoTests/CredentialAthleteTests
```

### S1.7 · Commit + push
Message : `feat(v2.1): gating paywall complet + a11y navigation + bump 2.1.0`

**📦 Livrable S1** : branche poussée, prête pour Archive dès que S2 fournit l'environnement IAP.

---

## 🏗 SPRINT 2 — Infrastructure + App Store Connect (🤝, 3-5 jours)

Objectif : tout l'environnement externe prêt (domaine, email, pages légales, ASC IAP, CloudKit prod).

### S2.1 · Domaine + email support (👤, ~30 min)
**Recommandations** :
- **Domaine** : `playco.ca` chez [Hover](https://www.hover.com) (14 $/an, registrar canadien) ou [Namecheap](https://www.namecheap.com)
- **Email** : [Google Workspace](https://workspace.google.com) (6 $/mois) OU [Zoho Mail](https://zoho.com/mail) gratuit 1 domaine
- Adresses : `support@playco.ca`, `hello@playco.ca`, `legal@playco.ca`

**📦 Livrable** : domaine enregistré, MX records configurés, 1 boîte mail fonctionnelle.

### S2.2 · Hébergement pages légales (🤝, ~2h)
Les 4 fichiers Markdown existent déjà : [privacy-policy-fr.md](legal/privacy-policy-fr.md), [privacy-policy-en.md](legal/privacy-policy-en.md), [terms-of-service-fr.md](legal/terms-of-service-fr.md), [terms-of-service-en.md](legal/terms-of-service-en.md).

**Options d'hébergement** (choisir 1) :
1. **Vercel** + GitHub repo séparé `playco-legal` — déploiement auto, HTTPS gratuit, ~30 min setup
2. **GitHub Pages** sur ce repo (depuis `docs/legal/`) — gratuit, `https://armypo.github.io/Coach-Planner-VB/privacy-policy-fr.html`
3. **Site Origo existant** (si `origotech.com` actif) — URLs `origotech.com/playco/privacy` déjà référencées dans [ProfilView.swift:449-450](../Playco/Views/Profil/ProfilView.swift)

Pour Vercel/GitHub Pages : convertir les `.md` en `.html` (pandoc ou simple template HTML wrapper). Je peux t'écrire le wrapper HTML + workflow GitHub Actions si tu veux.

**⚠️ Validation juridique** : fais relire par un avocat québécois (~300-500 $) — les textes actuels sont un point de départ solide mais pas validés Loi 25 + PIPEDA formellement.

**🤖 Je peux** : écrire le workflow GitHub Actions + wrapper HTML si tu choisis GitHub Pages.
**👤 Tu dois** : choisir l'option, publier, valider avocat.

**📦 Livrable** : 4 URLs HTTPS publiques. URL finales mises à jour dans [ProfilView.swift:449-450](../Playco/Views/Profil/ProfilView.swift) (petit PR après). [PlaycoInfo.plist](../PlaycoInfo.plist) n'a pas besoin de les référencer (liens dans l'app suffisent).

### S2.3 · CloudKit schema production (👤, ~30 min)
Suivre la procédure déjà documentée dans [CloudKit_Schema_Deployment.md](CloudKit_Schema_Deployment.md).

1. [icloud.developer.apple.com/dashboard](https://icloud.developer.apple.com/dashboard)
2. Container `iCloud.Origo.Playco`
3. Schema → Development → vérifier **26 record types CD_***
4. Bouton « Deploy Schema Changes to Production… » (irréversible, mais ajouts OK)
5. Valider sync avec 2 Apple IDs différents (comptes de test)

**📦 Livrable** : schema prod déployé, sync inter-device validée.

### S2.4 · App Store Connect — Subscription Group + 4 IAP (👤, ~1h)
[appstoreconnect.apple.com](https://appstoreconnect.apple.com) → App Playco → Features → Subscriptions.

**Subscription Group** :
- Reference Name : `Playco Pro`
- Group ID : `playco.pro` (exactement — lu par [IdentifiantsIAP.swift](../Playco/Helpers/IdentifiantsIAP.swift))

**4 produits** (ordre + Level important) :

| Product ID | Display Name | Level | Durée | Prix CAD | Family Sharing | Trial |
|---|---|---|---|---|---|---|
| `com.origo.playco.club.mensuel` | Playco Club Mensuel | **1** | 1 Month | 25,00 | ❌ OFF | Free 2 weeks (First-time only) |
| `com.origo.playco.club.annuel` | Playco Club Annuel | **1** | 1 Year | 250,00 | ❌ OFF | Free 2 weeks |
| `com.origo.playco.pro.mensuel` | Playco Pro Mensuel | **2** | 1 Month | 14,99 | ❌ OFF | Free 2 weeks |
| `com.origo.playco.pro.annuel` | Playco Pro Annuel | **2** | 1 Year | 149,99 | ❌ OFF | Free 2 weeks |

**Descriptions FR** (pour chaque produit, ~50-200 caractères) :
- **Pro Mensuel** : « Playco Pro Mensuel — outil complet pour toi et ton staff : stats live, export PDF/CSV, analytics saison. »
- **Pro Annuel** : « Playco Pro Annuel — économise 17% sur le plan Pro. Stats live, export, analytics, multi-équipes. »
- **Club Mensuel** : « Playco Club Mensuel — Pro + accès app pour tes athlètes, messagerie coach-athlète, profil individuel. »
- **Club Annuel** : « Playco Club Annuel — économise 17% sur le plan Club. Pro + accès athlètes + messagerie. »

**Descriptions EN** (reviewer + futurs anglophones) :
- **Pro Monthly** : « Playco Pro Monthly — complete toolkit for you and your staff: live stats, PDF/CSV export, season analytics. »
- **Pro Yearly** : « Playco Pro Yearly — save 17% on the Pro plan. Live stats, export, analytics, multi-team support. »
- **Club Monthly** : « Playco Club Monthly — Pro + athlete app access, coach-athlete messaging, individual profiles. »
- **Club Yearly** : « Playco Club Yearly — save 17% on the Club plan. Pro + athlete access + messaging. »

**📦 Livrable** : 4 produits en statut « Ready to Submit » (attendre 5-15 min de validation auto).

### S2.5 · App Privacy questionnaire (👤, ~2h)
Dans ASC → App → App Privacy → Get Started.

**Réponses attendues** (validé d'après le code Playco) :
- **Contact info** : email (collecté pour support)
- **User ID** : oui (identifiant + codeInvitation)
- **Sensitive info** : mots de passe hashés (pas en clair côté serveur ; CredentialAthlete en clair mais **private DB uniquement**)
- **Usage data** : oui (analytics `AnalyticsService`, pas encore actif TelemetryDeck)
- **Diagnostics** : oui (crash reports via Xcode)

Pour chaque catégorie : `Used to track you` = **NO** (pas de tracking cross-app/site).

**📦 Livrable** : Privacy « Ready to Submit » dans ASC.

### S2.6 · TelemetryDeck package + App ID (🤝, ~30 min)
1. **👤 Tu** : créer compte [telemetrydeck.com](https://telemetrydeck.com) (gratuit jusqu'à 100k signaux/mois) → obtenir App ID (UUID)
2. **🤖 Je** : Xcode → File → Add Package Dependencies → `https://github.com/TelemetryDeck/SwiftSDK` → Up to Next Major → ajouter à la target Playco
3. **🤖 Je** : dans [AnalyticsService.swift](../Playco/Services/AnalyticsService.swift), remplacer `REMPLACER-PAR-APP-ID-TELEMETRYDECK` + décommenter les 2 lignes TODO + rebuilder

**📦 Livrable** : commit `feat(analytics): active TelemetryDeck avec App ID production`

### S2.7 · Xcode In-App Purchase capability (👤, ~5 min)
1. Target `Playco` → Signing & Capabilities
2. `+ Capability` → **In-App Purchase**

Rien n'est ajouté dans le fichier `.entitlements` (Apple gère côté provisioning profile). Pas d'impact code.

**📦 Livrable** : capability IAP activée.

### S2.8 · (Optionnel) `Playco.storekit` pour tests Debug locaux (👤, ~20 min)
Utile si tu veux tester sans passer par TestFlight sandbox. **Pas bloquant** — TestFlight suffit.

1. File → New → File from Template → **StoreKit Configuration File**
2. Nom : `Playco.storekit`, emplacement `Playco/`
3. Dans le fichier : créer Subscription Group `playco.pro`, puis 4 produits avec les mêmes IDs + prix + Free Trial 14j First-time + Family Sharing OFF
4. Scheme `Playco` → Edit Scheme → Run → Options → StoreKit Configuration → sélectionner `Playco.storekit`

**📦 Livrable** (optionnel) : fichier `.storekit` committé dans `Playco/`, scheme updated.

### S2.9 · Tests manuels iPad physique sur `Ipad christo` (🤝, ~3-4h)
Une fois S2.4 + S2.7 faits, uploader une build TestFlight puis dérouler :

**12 scénarios login v2.0** — ChoixInitial, wizard avec 3 athlètes + 1 assistant, sheet récap bloquante, login 3 tabs (Coach/Assistant/Athlète), role mismatch, IdentifiantsEquipeView copier/partager/régénérer mdp, users pré-v2.0.

**16 scénarios paywall v2.0** — wizard → BienvenuePaywallView → essai Pro/Club (durée sandbox raccourcie : 14j ≈ 3 min), upgrade Pro→Club, cancel Apple dialog, gate athlète (coach Pro → athlète rejeté, coach Club → athlète OK), gate assistant (coach expiré → déconnexion), expire/grace/revoked via sandbox manipulation, restauration, multi-device.

**📦 Livrable** : rapport `docs/tests/beta-v2.1.0-avril-2026.md` avec X/28 PASS.

---

## 🎨 SPRINT 3 — Content fiche App Store (🤝, 2-3 jours)

En parallèle de S2.

### S3.1 · Screenshots (👤, ~3h)
**Tailles requises iPad** (obligatoires pour submission) :
- **iPad Pro 13" (M5)** : 2064 × 2752 px (portrait) ou 2752 × 2064 (paysage) — 3-10 images
- **iPad Pro 11" (M5)** : 1668 × 2388 ou 2388 × 1668

**Script de captures recommandé** (sur `Ipad christo` iPad Air 13") :
1. AccueilView avec 5 cartes (sections)
2. Wizard étape 5 (Membres) avec mdp auto-générés visibles
3. IdentifiantsRecapSheet après wizard (4 credentials)
4. BienvenuePaywallView (Pro + Club côte à côte)
5. Mode bord de terrain — match live avec StatsLiveView courtside
6. DashboardMatchLiveView — comparaison stats nous/adversaire
7. ProfilView — section « Mon abonnement » + « Identifiants de l'équipe »
8. TableauBordView — graphiques Swift Charts + PalmaresRecords

Pour chaque screenshot : utiliser `Cmd+Shift+3` sur le Mac pendant que l'iPad mirror via QuickTime (ou `xcrun simctl io booted screenshot` si simulator auto).

**Bonnes pratiques** :
- Captures en français uniquement (version anglaise optionnelle post-launch)
- Ajouter un overlay texte de promotion (Figma / Canva) sur les 2-3 premières — « Le volleyball qui se gère de ton iPad », « Stats live, analytics, multi-équipes », etc.

**🤖 Je peux** : te donner un briefing visuel détaillé (prompts pour les overlays, copy FR).
**👤 Tu fais** : les captures + mise en forme (Figma/Canva).

**📦 Livrable** : 5-10 images PNG uploadées dans ASC.

### S3.2 · Description App Store (🤝, ~2h)

**🤖 Je te propose cette base à adapter** :

```
Titre de l'app (30 chars max) : Playco — Coaching volleyball

Sous-titre (30 chars max) : Stats live · Match · Équipe

Description (4000 chars max) :

Playco est l'application iPad conçue par et pour les coachs de volleyball au Québec.

Gère ton équipe complète — séances, matchs, stratégies, musculation, statistiques — depuis une seule app pensée pour l'iPad avec Apple Pencil.

⚡ STATISTIQUES EN DIRECT
Saisis les points en temps réel pendant le match. Mode bord de terrain courtside optimisé pour l'action. Rotation auto, heatmap zones 1-6, export PDF après chaque match.

📊 ANALYTICS COMPLÈTES
Suivi saison avec graphiques Swift Charts. Hitting %, kills, aces, blocs, palmarès et records d'équipe. Objectifs individuels par joueur avec progression automatique.

🏐 TERRAIN DESSINABLE
Dessine tes exercices et stratégies directement sur un terrain de volleyball indoor ou beach. Multi-étapes, formations 5-1/4-2/6-2, bibliothèque d'exercices pré-faits.

👥 MULTI-ÉQUIPES + MESSAGERIE
Gère plusieurs équipes depuis un seul compte. Messagerie intégrée coach-athlète (plan Club). Identifiants auto-générés pour tes athlètes et assistants.

☁️ SYNC iCLOUD AUTOMATIQUE
Toutes tes données synchronisées entre tes appareils. Fonctionne hors ligne avec rejeu automatique.

🔒 CONFIDENTIALITÉ
Aucun tracking publicitaire. Données stockées dans ton iCloud privé, chiffrées bout-en-bout par Apple. Conforme Loi 25 Québec et PIPEDA.

💎 ABONNEMENTS
• Playco Pro (14,99 $/mois ou 149,99 $/an) : coach + assistants, stats, analytics, exports.
• Playco Club (25 $/mois ou 250 $/an) : Pro + athlètes peuvent accéder à leur profil et messagerie.
• Essai 14 jours gratuit sur chaque plan.

Conçu au Québec. Support en français.
```

**Keywords (100 chars max)** :
```
volleyball,coach,iPad,stats,équipe,match,Québec,Apple Pencil,analytics,entraînement
```

**Promotional Text (170 chars, modifiable sans review)** :
```
Nouveau : login unifié, identifiants auto-générés pour tes athlètes et essai 14 jours sur Playco Pro et Club. Le coaching volleyball qui se gère de ton iPad.
```

**📦 Livrable** : description + keywords + promotional text dans ASC.

### S3.3 · Reviewer notes + compte test (🤝, ~1h)

**🤖 Je te prépare ce template** :

```
Notes for Reviewer — Playco v2.1.0

Dear Apple Review Team,

Playco is a volleyball coaching app designed for iPad, primarily for the Quebec/Canadian market. The app is 100% in French (Loi 96 compliance).

=== TEST ACCOUNT ===
Identifier: reviewer.apple.2026
Password: [CRÉER avec PasswordPolicy ≥ 12 chars]
Tier: Playco Club (trial active)
Role: Coach (full permissions)

=== HOW TO TEST ===
1. Open app → splash → ChoixInitialView → tap "Connexion"
2. In the LoginView, select the "Coach" tab
3. Enter the credentials above → access the app

Alternatively, to test the full onboarding:
1. Tap "Créer mon équipe" → complete the 6-step wizard
2. Create a few players + 1 assistant at step 5 (credentials auto-generated)
3. Confirm in the sheet récap
4. BienvenuePaywallView will offer the 14-day trial (Apple sandbox)

=== FEATURES TO VERIFY ===
- Live match stats (Matchs → create → composition → StatsLiveView courtside mode)
- Drawing on volleyball court (Stratégies → new → draw with Apple Pencil)
- Team management (Équipe → players list + dashboard + stats)
- Multi-language: only French is supported in v2.1 (Loi 96). English minimum is provided for reviewer via Localizable.xcstrings.

=== SUBSCRIPTIONS ===
4 IAP products in Subscription Group "playco.pro":
- com.origo.playco.club.{mensuel,annuel} (tier Club)
- com.origo.playco.pro.{mensuel,annuel} (tier Pro)
All with 14-day free trial, First-time only, Family Sharing OFF.

=== PRIVACY ===
Privacy Policy: https://[final URL]/privacy
Terms: https://[final URL]/terms

No tracking, no third-party SDKs except TelemetryDeck (privacy-first, no PII).

Contact: support@playco.ca
```

**📦 Livrable** : reviewer notes collées dans ASC, compte test créé dans l'app (via wizard avant beta).

### S3.4 · Press kit / landing page minimale (🤝, 1-3 jours)
**Landing page `playco.ca`** — 1 page simple :
- Hero : screenshot app + tagline « Le volleyball qui se gère de ton iPad »
- Features : 4-5 sections (stats live, terrain, équipe, analytics, sync iCloud)
- Pricing : Pro vs Club
- Testimonials : citations de 2-3 coachs beta (à collecter S4)
- CTA : « Télécharger sur App Store » (greyed out jusqu'à release)
- Footer : email support, liens légaux

**🤖 Je peux** : écrire le HTML/CSS complet statique en 1 page (déployable Vercel/Netlify/GitHub Pages).
**👤 Tu fais** : fournir logo + screenshots finaux + testimonials, publier.

**📦 Livrable** : `playco.ca` en ligne avec page d'accueil + liens légaux.

---

## 🧪 SPRINT 4 — TestFlight beta interne (2-3 semaines)

Objectif : valider que l'app fonctionne en conditions réelles avec 5-10 coachs Volleyball Québec / RSEQ avant soumission App Store.

### S4.1 · Upload build TestFlight (🤝, ~30 min)
1. **🤖 Je** : `xcodebuild archive` + export IPA (je peux le faire via devicectl + altool)
2. **👤 Tu** : upload via Xcode → Window → Organizer → Archives → Distribute App → TestFlight Internal
3. Attendre validation Apple (~10-30 min)
4. Activer TestFlight Internal testing

**📦 Livrable** : build v2.1.0 (3) disponible sur TestFlight pour 25 internes.

### S4.2 · Recrutement 5-10 coachs beta (👤, 1 semaine)
Cibles :
- **Volleyball Québec** — contact fédération
- **RSEQ** (Réseau du sport étudiant du Québec) — contact cégep/univ
- **Cégep Garneau** — ton réseau initial (fondateur cité dans CLAUDE.md)
- Réseau personnel coachs volleyball

Pour chaque testeur :
1. Inviter via email TestFlight (ASC → TestFlight → Internal Testing → add tester)
2. Envoyer **onboarding beta** (template ci-dessous)

**🤖 Template email onboarding beta** :

```
Sujet : Beta privée Playco — ton feedback compte

Salut [Prénom],

Merci d'accepter d'essayer Playco en beta avant la sortie App Store officielle !

INSTALLATION (5 min) :
1. Télécharge TestFlight sur ton iPad : https://apps.apple.com/app/testflight/id899247664
2. Ouvre ce lien d'invitation : [URL TestFlight]
3. Accepte l'invitation → installe Playco

PREMIER USAGE (15 min) :
1. Ouvre l'app → "Créer mon équipe"
2. Complète le wizard (6 étapes : établissement, sport, profil coach, équipe, joueurs, calendrier)
3. Note les identifiants auto-générés dans la sheet récap finale
4. Choisis ton plan paywall (essai 14 jours, pas de carte requise en TestFlight)

TESTS DEMANDÉS (2-3 semaines) :
- Ajoute tes vrais matchs et saisis stats live pendant un match réel
- Partage l'identifiant d'un athlète pour qu'il se connecte (plan Club)
- Teste export PDF/CSV, heatmap, analytics saison

FEEDBACK :
Signale bugs et suggestions via ce formulaire : [Google Form URL]
OU directement à support@playco.ca

Note importante : en TestFlight, les durées Apple sont accélérées (14j = 3 min, 1 mois = 5 min) pour tester rapidement les cycles.

Merci de faire partie de la première vague Playco !

[Prénom fondateur]
Origo Technologies
```

**🤖 Je peux** : créer le Google Form template avec les bonnes questions NPS.

**📦 Livrable** : 5-10 coachs actifs en beta avec feedback form rempli.

### S4.3 · Itérations sur bugs remontés (🤖 + 🤝, 1-2 semaines)
Pour chaque bug critique remonté :
1. Reproduction sur `Ipad christo`
2. Fix + tests
3. Build incrémentale TestFlight (v2.1.1, 2.1.2…)

**🤖 Je fais** : les fixes code + commits.
**👤 Tu fais** : dispatch des builds TestFlight + comm avec beta testeurs.

### S4.4 · Gate NPS > 40 pour passer S5
À la fin de 2-3 semaines beta :
- Envoyer sondage NPS : « De 0 à 10, tu recommanderais Playco à un autre coach ? »
- Compter % Promoteurs (9-10) - % Détracteurs (0-6) = NPS
- Cible ≥ 40 pour submission
- Si < 40 : prolonger beta + adresser les gros irritants

---

## 📤 SPRINT 5 — Soumission App Store + review (1-2 jours + 2-7 jours review)

### S5.1 · Build de release (🤝, ~1h)
1. **🤖 Je** : vérifier que tous les TODOs sont résolus, bump éventuel à v2.1.1+ si beta a nécessité des fixes
2. **🤝 On** : `xcodebuild archive` + Distribute App → App Store Connect
3. Validation auto Apple (~30 min)

### S5.2 · Configuration submission ASC (👤, ~30 min)
- App → Pricing : gratuit (IAP assure la monétisation)
- App Information : tout rempli
- App Review Information : reviewer notes + compte test
- Version : 2.1.0 → Submit for Review

### S5.3 · Review Apple (2-7 jours attente)
Rejets probables et plan de réponse :

| Rejet possible | Plan de réponse |
|---|---|
| « Guideline 2.1 » — app crash | Je reproduis + fix + resubmit |
| « Guideline 4.2.3 » — contenu mince ou scope limité | Souligner 5 sections, CloudKit sync, drawing Apple Pencil, paywall 14j Apple natif |
| « Guideline 3.1.1 » — IAP problème | Vérifier les 4 produits « Ready to Submit », que le Free Trial est First-time only |
| « Guideline 5.1.1 » — privacy policy | Vérifier URL accessible + App Privacy questionnaire complet |
| « Guideline 5.1.2 » — data collection | Justifier CredentialAthlete stocké en private CloudKit, jamais envoyé |
| « VoiceOver inaccessible » | Étendre accessibility labels (S1.3 + batch 3) |

### S5.4 · Post-release (🤖 + 👤, ongoing)
- Monitoring TelemetryDeck dashboard
- Email support actif
- Bug reports → fixes → updates mineures
- v2.2 roadmap : EN complet, push notifications pré-expiration, WCAG AAA, biométrie Face ID

### S5.5 · Dette technique post-launch (🤖, piocher par priorité)

Items **IMPORTANT** non-bloquants (issus de la revue excellence) :
- **I1** · `observerTransactionsTask` jamais cancellé → `.onDisappear` ContentView + `.cancel()` (10 min)
- **I3** · `AbonnementService.rafraichir` ~80 lignes → découper en helpers testables (1h)

Items **LOW** (nits, à piocher pendant phase bug-fix beta) :
- **L1** · `IdentifiantsIAP.tous` Array → Set (5 min)
- **L2** · `genererMotDePasseAthlete` compactMap pattern robuste (15 min)
- **L3** · `PaywallView.layoutCartes` → `@Environment(\.horizontalSizeClass)` (30 min)
- **L4** · `PaywallView.chargerInitial` → `TaskGroup` parallèle (20 min)
- **L5** · `ConfigMembresView.autoIdJoueur/Assistant` → helper générique (20 min)
- **L6** · `AjoutUtilisateurView.creerCompte` → découper (1h)

Priorité : I1 + L3 si feedback beta mentionne Stage Manager ; le reste peut rester backlog.

---

## 📊 Dashboard des dépendances critiques

```
S1 (code) ──────────┐
                    ├──→ Build TestFlight ──→ Beta S4 ──→ Submit S5
S2 (infra + ASC) ───┘
                    ├──→ Content S3 (screenshots + desc)
                    │
S2 requires:
  - S2.1 (domaine) pour S2.2 (legal hosting)
  - S2.4 (IAP) pour S4 tests paywall
  - S2.3 (CloudKit prod) pour S4 sync multi-device
```

**Goulots d'étranglement** :
- S2.1 domaine peut bloquer S2.2 légal (24-48h propagation DNS)
- S2.4 ASC IAP peut bloquer S4 tests (5-15 min validation Apple)
- S2.3 CloudKit prod est irréversible — valider avec 2 Apple IDs **avant** la prod usage massive

---

## 🎁 Ce que je peux te livrer immédiatement si tu me le demandes

1. **`S1 complet`** — bump versions + gating 7 vues + a11y batch 2 + commit + push. ~1 jour.
2. **Wrapper HTML + GitHub Actions** pour héberger les pages légales sur GitHub Pages. ~30 min.
3. **Landing page `playco.ca`** en HTML/CSS statique 1 page. ~1-2h.
4. **Google Form template beta onboarding** — questions NPS + bugs + suggestions. ~15 min.
5. **Script de captures screenshots** — avec navigation suggérée pour obtenir les 8-10 images. ~30 min.
6. **Template email onboarding beta** finalisé avec ton nom / signature. ~10 min.
7. **Checklist reviewer notes complète** adaptée aux guidelines Apple en vigueur. ~30 min.
8. **TelemetryDeck activation** dès que tu me donnes l'App ID. ~15 min code + commit.
9. **Wrapping up** après S4 : résoudre bugs beta + bump → commit → push pour S5. En continu.

## 🤝 Ce que je ne peux PAS faire (100% toi)

1. Achat domaine + configuration DNS
2. Création comptes Google Workspace / TelemetryDeck / Apple Developer
3. Manipulations App Store Connect (fiche, screenshots upload, IAP création, submission)
4. Manipulations CloudKit Dashboard (Deploy to Production)
5. Manipulations Xcode UI : capability IAP, StoreKit config référence dans Scheme
6. Archive + Upload IPA (besoin Xcode local + Apple ID)
7. Recrutement + communication beta testeurs
8. Validation juridique avocat (pages légales Loi 25)
9. Réponse aux rejets Apple (messages à rédiger via ASC)
10. Communication + marketing post-launch

---

## 🎯 Décision pour démarrer

Dis-moi juste **« go S1 »** et je lance le sprint code complet (bump + gating + a11y + push) — j'enchaîne comme pour login v2.0 et paywall v2.0.

Ou choisis un autre livrable de la liste des 9 items ci-dessus que tu veux que je fasse en premier.

---

## ✅ Annexe — Strengths validés par la revue code-review-excellence

Points forts confirmés sur les commits `0f076bb` (login v2.0) + `179fc66` (paywall v2.0). Utilisable pour le pitch reviewer Apple ou la comm interne.

🎉 **Architecture services** — `@Observable @MainActor` avec injection `.environment(…)` systématique sur chaque écran. Séparation nette AuthService / CloudKitSyncService / CloudKitSharingService / AnalyticsService / StoreKitService / AbonnementService.

🎉 **Séparation modèles publique vs privée** — `Equipe.tierAbonnementRaw` publié publiquement pour la gate multi-Apple-ID, mais `Abonnement` et `CredentialAthlete` **jamais publiés** via `CloudKitSharingService`. Grep confirmé, cloison sécurité respectée.

🎉 **Design System cohérent** — `LiquidGlassKit` constantes (rayons, espaces, springs) utilisées systématiquement, zéro magic number détecté dans les vues paywall et auth v2.

🎉 **Tests Swift Testing moderne** — `@Suite .serialized` + `#expect` + in-memory `ModelContainer`. 12 tests verts sur iPad physique. Pattern UserDefaults suite isolée pour les tests AuthService-like.

🎉 **Gate centrale `appliquerGateTier`** — pattern élégant avec 3 chemins d'entrée : (1) LoginView.onConnecte callback, (2) PlaycoApp case `.app` après restaurerSession, (3) ContentView onChange runtime. Pas de duplication de logique.

🎉 **StoreKit 2 best practice** — `.verified` strict + rejet `.unverified`, `await transaction.finish()` appelé après la persistance (pas avant), pas de dépendance externe hors Apple SDK.

🎉 **Enum Statut 10 cas exhaustif** — pattern-matched dans `mapperTypeAbonnement` et `tierActif`, compilateur vérifie que tous les cas sont traités (defensive contre ajout futur d'un cas sans update).

🎉 **Mention légale auto-renouvellement** — `TextesPaywall.mentionAutoRenouvellement` formulation complète conforme aux guidelines App Store (obligatoire pour IAP récurrents).

🎉 **Documentation inline** — docstrings détaillées sur `CredentialAthlete` (expliquant pourquoi privé uniquement), `IdentifiantsIAP` (mapping tier + clés cache), `AbonnementService.Statut` (10 cas annotés), `PasswordPolicy` (NIST 800-63B référencé).

🎉 **Pièges CLAUDE.md respectés** — #15 (tous attributs @Model avec defaults), #17 (Logger pas print), #19 (pas de magic numbers LiquidGlassKit).

Ces points forts sont une base solide : la dette technique S5 est majoritairement cosmétique (nits), et les 2 items BLOCKING de S1 sont résolubles en ~1h chacun.
