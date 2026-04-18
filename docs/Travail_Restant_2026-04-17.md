# Travail restant — Playco v2.1.0
**Date handoff** : 17 avril 2026, 22 h 30
**Branche active** : `claude/admiring-bohr-4a25b3` (à jour sur `origin`, commit `8e53149`)
**Dernière session** : Sprints S1 complet + S2 partie code/contenu

---

## 📊 État global des 5 sprints

| Sprint | Nom | État | Reste à faire |
|---|---|---|---|
| **S1** | Dette code finalisée | ✅ **DONE** | — |
| **S2** | Infra + App Store Connect | 🟡 **Partiel** (code livré, actions manuelles restantes) | 👤 8 actions |
| **S3** | Content fiche App Store | 🟡 **Préparé** (templates prêts) | 👤 Captures + upload ASC |
| **S4** | TestFlight beta | ⏳ Pas démarré | 👤 Recrutement + itérations |
| **S5** | Soumission + review | ⏳ Pas démarré | 🤝 Archive + submit |
| **S5.5** | Dette technique post-launch | 📋 Backlog | I1, I3, L1-L6 |

---

## ✅ S1 — DONE (commit `bf3c1f4`)

Rien à faire. Tout est livré, pushé, buildé clean iPad physique. Récap :

- 4 fixes code review : B1 (propagation tier CloudKit via `republierEquipeComplete`), B2 (`Statut` custom Equatable ignorant Date), I2 (`statutSouscriptionActif` déterministe via `purchaseDate`), I4 (`regenererMdp` do/catch + alert + rollback)
- Bump versions : `MARKETING_VERSION 1.9.0 → 2.1.0`, `CURRENT_PROJECT_VERSION 2 → 3`
- Paywall feature gating sur 10 vues write (3 de S1.2 initial + 7 de S1.3 ajoutées) : StrategiesView, EquipeView, EntrainementView, SaisieStatsMatchView, StatsLiveView, ModifierUtilisateurView, ExportMatchPDFView
- Accessibility labels batch 2 : LoginView (picker + bouton), ChoixInitialView (2 boutons), MatchsView, EquipeView, PricingCard, BanniereAbonnementView, IdentifiantsEquipeView

---

## 🟡 S2 — État détaillé

### ✅ Partie code/contenu livrée (commit `8e53149`)

Tout ce qui peut être fait sans intervention manuelle externe. Prêt à l'emploi :

- **Site Jekyll GitHub Pages** : `docs/_config.yml`, `docs/_layouts/page.html` (layout pages légales), `docs/_layouts/landing.html` (layout landing), `docs/index.md` (landing playco.ca)
- **Pages légales conformes QC** : front matter ajouté aux 4 `docs/legal/{privacy-policy,terms-of-service}-{fr,en}.md` avec permalinks `/legal/...` et mention juridiction tribunaux Québec
- **Playco.storekit** : [Playco/Playco.storekit](../Playco/Playco.storekit) — 4 produits + trial 14j + Family Sharing OFF, prêt à être ajouté au Scheme Xcode
- **Beta docs** : `docs/beta/{README,onboarding-email,formulaire-nps,script-screenshots}.md`
- **Reviewer notes Apple** : `docs/apple-review/reviewer-notes.md` (EN primary ~3800 chars ASC + FR summary)

### ❌ Actions manuelles restantes (👤 toi seul)

#### S2.1 · Domaine + email support (~30 min)
- **Acheter domaine `playco.ca`** chez Hover (~14 $/an) ou Namecheap
- **Configurer email** `support@playco.ca` via Google Workspace (6 $/mois) ou Zoho Mail (gratuit 1 domaine)
- Optionnel : `hello@playco.ca`, `legal@playco.ca`

#### S2.2 · Activer GitHub Pages (~10 min)
- Aller sur https://github.com/armypo/Coach-Planner-VB/settings/pages
- Source = **Deploy from a branch** · Branch = `main` · Folder = `/docs`
- Save → attendre le premier build (~2-3 min)
- URL finale : `https://armypo.github.io/Coach-Planner-VB/`
- Vérifier :
  - Landing : https://armypo.github.io/Coach-Planner-VB/
  - Privacy FR : https://armypo.github.io/Coach-Planner-VB/legal/privacy-policy-fr/
  - Privacy EN : https://armypo.github.io/Coach-Planner-VB/legal/privacy-policy-en/
  - Terms FR : https://armypo.github.io/Coach-Planner-VB/legal/terms-of-service-fr/
  - Terms EN : https://armypo.github.io/Coach-Planner-VB/legal/terms-of-service-en/
- **Plus tard** : migration vers `playco.ca` via fichier `docs/CNAME` avec `playco.ca` + DNS record chez registrar (je peux faire le fichier CNAME sur demande)
- **⚠️ Action code associée** : une fois l'URL stable, remplacer dans [ProfilView.swift:449-450](../Playco/Views/Profil/ProfilView.swift) les placeholders `origotech.com/playco/{privacy,terms}` par les vraies URLs. Je peux le faire sur demande.

#### S2.3 · CloudKit schema production (~30 min)
- Suivre [docs/CloudKit_Schema_Deployment.md](CloudKit_Schema_Deployment.md)
- https://icloud.developer.apple.com/dashboard
- Container `iCloud.Origo.Playco` → Schema → Development
- Vérifier la liste des 26+ record types CD_* (le plan liste 24, ajoute `CD_CredentialAthlete` + `CD_Abonnement` depuis login v2.0 + paywall v2.0 = **26 types**)
- Bouton **« Deploy Schema Changes to Production… »** → confirmer (irréversible mais ajouts futurs OK)
- Valider sync avec 2 Apple IDs différents

#### S2.4 · App Store Connect — Subscription Group + 4 IAP (~1h)
- https://appstoreconnect.apple.com → App Playco → Features → Subscriptions
- **Subscription Group** : Reference Name = `Playco Pro` · Group ID = `playco.pro`
- **4 produits** (détails complets dans [docs/apple-review/reviewer-notes.md](apple-review/reviewer-notes.md) section « Subscription Architecture ») :

| Product ID | Display Name | Level | Durée | Prix CAD | Free Trial | Family Sharing |
|---|---|---|---|---|---|---|
| `com.origo.playco.club.mensuel` | Playco Club Mensuel | 1 | 1 Month | 25.00 | 2 weeks First-time | OFF |
| `com.origo.playco.club.annuel` | Playco Club Annuel | 1 | 1 Year | 250.00 | 2 weeks First-time | OFF |
| `com.origo.playco.pro.mensuel` | Playco Pro Mensuel | 2 | 1 Month | 14.99 | 2 weeks First-time | OFF |
| `com.origo.playco.pro.annuel` | Playco Pro Annuel | 2 | 1 Year | 149.99 | 2 weeks First-time | OFF |

- **Descriptions FR + EN** : cf. reviewer-notes.md (localizations Playco.storekit)
- Attendre statut **« Ready to Submit »** sur chaque (5-15 min validation Apple)

#### S2.5 · App Privacy questionnaire (~2h)
- ASC → App → App Privacy → Get Started
- Suivre les réponses listées dans [docs/apple-review/reviewer-notes.md](apple-review/reviewer-notes.md) section « Privacy & Data »
- **Contact info** : oui (email support) · **User ID** : oui (identifiant + codeInvitation) · **Usage data** : oui · **Diagnostics** : oui
- Pour chaque catégorie : `Used to track you` = **NO** partout (aucun tracking cross-app)
- Ajouter URLs pages légales (une fois GitHub Pages activé S2.2)

#### S2.6 · TelemetryDeck activation (~30 min)
1. Créer compte sur https://telemetrydeck.com (gratuit jusqu'à 100k signaux/mois)
2. Créer l'app Playco dans le dashboard → obtenir **App ID** (UUID)
3. **Me donner l'App ID** : je branche en 15 min (Xcode → Add Package Dependencies → `https://github.com/TelemetryDeck/SwiftSDK` + remplacer `REMPLACER-PAR-APP-ID-TELEMETRYDECK` dans [AnalyticsService.swift](../Playco/Services/AnalyticsService.swift) + décommenter 2 lignes TODO → commit)

#### S2.7 · Xcode — In-App Purchase capability (~5 min)
- Target `Playco` → Signing & Capabilities → bouton **+ Capability** → choisir **In-App Purchase**
- Rien d'autre à faire — Apple gère via provisioning profile (pas d'entitlement explicite)

#### S2.8 · Xcode — référencer `Playco.storekit` dans le Scheme (~5 min)
1. Xcode → Project navigator → clique droit sur dossier `Playco/` → **Add Files to « Playco »…**
2. Sélectionne `Playco/Playco.storekit` → coche « Add to target: Playco » → Add
3. Menu Product → Scheme → **Edit Scheme…** → Run → Options → **StoreKit Configuration** : choisir `Playco.storekit`
4. Close
5. Tester : build sur iPad physique et vérifier que les 4 produits s'affichent dans BienvenuePaywallView avec prix CAD

#### S2.9 · Tests manuels iPad physique (~3-4h après S2.4 + S2.7 + S2.8)
- **12 scénarios login v2.0** : détaillés dans [paywall/PLAN.md](../paywall/PLAN.md) + scénarios documentés dans commit `0f076bb`
- **16 scénarios paywall v2.0** : détaillés dans [paywall/PLAN.md](../paywall/PLAN.md) section « Tests manuels iPad »
- Créer compte test `reviewer.apple.2026` avec `ReviewPlayco2026!` pour S3/S5 reviewer notes

---

## 🟡 S3 — Content fiche App Store

**Préparé** : [docs/beta/script-screenshots.md](beta/script-screenshots.md) (10 captures détaillées) + [docs/apple-review/reviewer-notes.md](apple-review/reviewer-notes.md).

### Reste à faire (👤)

1. **Générer les screenshots** en suivant [docs/beta/script-screenshots.md](beta/script-screenshots.md) :
   - Utiliser `Ipad christo` connecté via câble
   - Préparer les données de démo (équipe « Élans féminin D1 », 6 joueuses, 2 matchs joués)
   - Capturer via `xcrun devicectl device screenshot --device 00008103-0001050814D3C01E --destination ~/Desktop/capture-N.png` ou QuickTime mirror
   - 5-10 captures : AccueilView, Courtside mode, Split-screen, BienvenuePaywall, Strategies, Analytics, Identifiants, ProfilView + (optionnel) Heatmap + Export PDF
   - Retoucher dans Figma/Canva pour les 2-3 premières (overlay marketing texte FR)
2. **Upload ASC** → App → App Store → version 2.1.0 → **iPad Screenshots** (3-10 images en 2064×2752 et/ou 1668×2388)
3. **Description App Store** FR ~4000 chars : template dans `docs/apple-review/reviewer-notes.md` (ou je peux l'écrire sur demande)
4. **Keywords** (100 chars) : `volleyball,coach,iPad,stats,équipe,match,Québec,Apple Pencil,analytics,entraînement`
5. **Promotional Text** (170 chars, modifiable sans review) : « Nouveau : login unifié, identifiants auto-générés pour tes athlètes et essai 14 jours sur Playco Pro et Club. Le coaching volleyball qui se gère de ton iPad. »
6. **Reviewer notes** : copier [docs/apple-review/reviewer-notes.md](apple-review/reviewer-notes.md) section anglaise dans ASC → App Review Information → Notes for the reviewer
7. **Compte test** : créer `reviewer.apple.2026` (wizard complet) + renseigner dans ASC → Demo Account

### Ce que je peux faire (🤖 sur demande)

- Description App Store finale FR + EN adaptée au caractère limit ASC
- Landing page `playco.ca` custom domain setup (CNAME + DNS instructions)
- Retouche overlays marketing des screenshots (si tu exportes les PNG raw, je peux scripter ImageMagick)

---

## ⏳ S4 — TestFlight beta

**Préparé** : [docs/beta/README.md](beta/README.md) (workflow complet) + email onboarding + formulaire NPS.

### Reste à faire (👤)

1. **Upload build TestFlight** : Xcode → Window → Organizer → Archives → Distribute App → TestFlight Internal (~10-30 min validation Apple)
2. **Recruter 5-10 coachs beta** via :
   - Réseau personnel (Cégep Garneau)
   - Volleyball Québec (contact fédération)
   - RSEQ
3. **Envoyer email onboarding** : personnaliser le template `docs/beta/onboarding-email.md` (remplacer `[Prénom]` et `[LIEN_TESTFLIGHT]`)
4. **Créer le Google Form** depuis `docs/beta/formulaire-nps.md` (copier les 16 questions)
5. **Attendre 2-3 semaines** avec support actif (répondre emails + bugs)
6. **Fixes urgents** si remontés → je peux itérer sur demande (nouveau commit + nouvelle build TestFlight)
7. **Calcul NPS final** : `(% promoteurs 9-10) - (% détracteurs 0-6)`. Gate **≥ 40** pour passer à S5. Si < 40, prolonger 1-2 semaines + corrections.

---

## ⏳ S5 — Soumission App Store

### Reste à faire (🤝)

1. **Build de release final** (🤝 : je peux archiver avec toi par Xcode Organizer)
2. **Valider les prérequis ASC** :
   - [ ] 4 IAP en « Ready to Submit »
   - [ ] Privacy Policy URL accessible
   - [ ] App Privacy questionnaire complet
   - [ ] Screenshots uploadés (3-10 pour chaque taille iPad)
   - [ ] Description FR + EN
   - [ ] Reviewer notes + compte test
   - [ ] Contract/Tax/Banking (Paid Apps Agreement) signé
   - [ ] Apple Developer Program actif
3. **Soumettre** : ASC → Version 2.1.0 → Submit for Review
4. **Attente review Apple** : 2-7 jours typiquement
5. **Gestion rejets** : rejets probables et réponses documentés dans [docs/Plan_Lancement_V2.1.0.md](Plan_Lancement_V2.1.0.md) section S5.3
6. **Release** : auto ou manuel selon préférence

---

## 📋 S5.5 — Dette technique post-launch (backlog)

À piocher après le launch, par ordre d'impact :

| ID | Item | Fichier | Effort |
|---|---|---|---|
| **I1** | `observerTransactionsTask` jamais cancellé | [PlaycoApp.swift:20](../Playco/PlaycoApp.swift) | 10 min |
| **I3** | `AbonnementService.rafraichir` ~80 lignes → helpers testables | [AbonnementService.swift](../Playco/Services/AbonnementService.swift) | 1h |
| **L1** | `IdentifiantsIAP.tous` Array → Set | [IdentifiantsIAP.swift](../Playco/Helpers/IdentifiantsIAP.swift) | 5 min |
| **L2** | `genererMotDePasseAthlete` compactMap robuste | [Utilisateur.swift](../Playco/Models/Utilisateur.swift) | 15 min |
| **L3** | `PaywallView.layoutCartes` → `@Environment(\.horizontalSizeClass)` | [PaywallView.swift](../Playco/Views/Paywall/PaywallView.swift) | 30 min |
| **L4** | `PaywallView.chargerInitial` → `TaskGroup` parallèle | idem | 20 min |
| **L5** | `ConfigMembresView.autoIdJoueur/Assistant` → helper générique | [ConfigMembresView.swift](../Playco/Views/Configuration/ConfigMembresView.swift) | 20 min |
| **L6** | `AjoutUtilisateurView.creerCompte` → découper | [AjoutUtilisateurView.swift](../Playco/Views/Profil/AjoutUtilisateurView.swift) | 1h |

---

## 🔗 Références rapides

| Pour… | Consulter |
|---|---|
| Plan complet des 5 sprints | [docs/Plan_Lancement_V2.1.0.md](Plan_Lancement_V2.1.0.md) |
| Findings code review (2 BLOCKING + 4 IMPORTANT + 6 LOW) | idem, section « Code Review Excellence findings » |
| Strengths validés par la revue | idem, annexe en fin de doc |
| CloudKit Schema procédure Prod | [docs/CloudKit_Schema_Deployment.md](CloudKit_Schema_Deployment.md) |
| Pages légales source Markdown | `docs/legal/{privacy-policy,terms-of-service}-{fr,en}.md` |
| Workflow beta complet | [docs/beta/README.md](beta/README.md) |
| Script captures screenshots | [docs/beta/script-screenshots.md](beta/script-screenshots.md) |
| Email onboarding beta | [docs/beta/onboarding-email.md](beta/onboarding-email.md) |
| Questions Google Form NPS | [docs/beta/formulaire-nps.md](beta/formulaire-nps.md) |
| Reviewer notes Apple | [docs/apple-review/reviewer-notes.md](apple-review/reviewer-notes.md) |
| StoreKit sandbox config | [Playco/Playco.storekit](../Playco/Playco.storekit) |

---

## 💡 Comment reprendre la session

Dans une nouvelle conversation avec Claude Code, commence par :

```
On reprend Playco v2.1.0. Lis `docs/Travail_Restant_2026-04-17.md` pour l'état
actuel. État : S1 complet commit bf3c1f4, S2 partie code livrée commit 8e53149.
Il me reste les actions manuelles S2 à finir (domaine + GitHub Pages + CloudKit
Dashboard + ASC IAP + Xcode capability + tests manuels).

[Précise ce que tu as fait entre temps]

Prochaine étape : [choix parmi : S3 content, S4 beta, itérations code, dette technique post-launch, etc.]
```

### Dépendances critiques à respecter

```
S2.1 domaine
   ├→ S2.2 GitHub Pages actif → URLs stables pour ProfilView.swift update
   └→ S2.2 migration playco.ca future

S2.3 CloudKit Prod (irréversible, valider avec 2 Apple IDs avant usage massif)

S2.4 ASC IAP + S2.7 Xcode capability
   └→ S2.9 tests manuels paywall sur iPad
       └→ S4 TestFlight beta
           └→ S5 submission
```

Les tests paywall réels (achats sandbox) ne fonctionnent **PAS** sans S2.4 + S2.7 + S2.8 (le `.storekit` local fonctionne en Debug mode uniquement).

### Commande de build iPad physique (rappel)

```bash
cd "/Users/armypo/Documents/Origotech/Playco/.claude/worktrees/admiring-bohr-4a25b3" && \
xcodebuild -scheme "Playco" \
  -destination 'platform=iOS,id=00008103-0001050814D3C01E' \
  build
```

Device : `Ipad christo` (iPad Air 5e gen, iOS 26.3.1). UDID `00008103-0001050814D3C01E`.

---

## 🎯 Décisions en attente (quand tu reprends)

1. **Hébergement landing** : GitHub Pages suffit pour début ? Migration `playco.ca` dans combien de temps ?
2. **TelemetryDeck** : tu crées le compte et me donnes l'App ID → je branche en 15 min
3. **Dimensions screenshots** : iPad Pro 13" M5 suffit ou aussi iPad Pro 11" ?
4. **Reviewer notes language** : EN primary + FR summary est bien ou tu veux inverser ?
5. **Beta recrutement** : début quand ? 5 testeurs minimum ou 10 ?
6. **Launch target date** : septembre 2026 encore viable ou à revoir ?

---

**Dernier commit** : `8e53149` sur `claude/admiring-bohr-4a25b3`.
**Arbre** : `0f076bb` (login v2) → `179fc66` (paywall v2) → `bf3c1f4` (S1) → `8e53149` (S2 code/content).

Bonne pause — tout est pushé, rien à perdre.
