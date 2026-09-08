# Playco v3 — Modèle SaaS

> Statut : **proposition validée** (mai 2026) — implémentation cible v3.0 (août-septembre 2026)
> Voir aussi : [MULTI_SPORT_PLAN.md](./MULTI_SPORT_PLAN.md)

## Principe

**Toutes les fonctionnalités sont incluses dans tous les paliers.** Les seules variables qui font monter le prix sont :

1. Nombre d'**équipes**
2. Nombre de **head coachs**
3. Nombre de **sports**

Pas de feature gating compliquée. Le client choisit le palier qui correspond à sa structure organisationnelle.

---

## Les 5 paliers

| Palier | Tarif | Équipes | Head coachs | Sports |
|---|---|:-:|:-:|:-:|
| **Entraîneur** | 14,99 $/mois · 149 $/an | 1 | 1 | Tous |
| **Pro** | 24,99 $/mois · 249 $/an | 4 max | 1 (vérifié) + assistants ∞ | Tous |
| **Club** | 49 $ base + 12 $/équipe/mois | ∞ | ∞ | **1 sport** au choix |
| **Organisation** | 89 $ base + 15 $/équipe/mois | ∞ | ∞ | Tous |
| **Fédération** | À partir de **5 000 $/an** (forfait) | ∞ | ∞ | Tous |

### Pour qui ?

- **Entraîneur** — Coach solo qui gère une seule équipe. Cas de base.
- **Pro** — Coach indépendant multi-équipes (RSEQ M15-M18, U Sports, coach saisonnier multi-sport).
- **Club** — École / club / programme sportif mono-sport (ex. programme volley féminin d'un cégep).
- **Organisation** — École / club multi-sport, cégep, conglomérat sportif.
- **Fédération** — Volleyball QC, RSEQ, Hockey Canada régional, fédérations provinciales/nationales.

---

## Rôle "Admin" (Club / Org / Fédé)

**1 seul admin par institution.** C'est le compte qui :

- Détient l'abonnement et gère la facturation (Stripe Invoice annuel)
- Voit toutes les équipes dans un dashboard cross-équipes
- Invite / désactive les coachs (sièges illimités)
- Choisit le sport au niveau Club (verrouillé pour la durée du contrat) ou active tous les sports au niveau Org/Fédé
- Configure logo + couleurs institution
- Reçoit les rapports d'utilisation mensuels

Côté code :
- Nouveau cas `RoleUtilisateur.adminOrganisation` (à ajouter dans `Models/Utilisateur.swift`)
- Nouveau champ `Etablissement.adminUtilisateurID` (`Models/Etablissement.swift`)
- Nouveau champ `Etablissement.palierAbonnement: String`

---

## Garde-fou Pro

**Pro = 1 head coach vérifié.** Vérification par Apple ID + device principal.

- Tentative d'inviter un 2e head coach → sheet bloquante "Limite Pro — passer en Club ou Org"
- Tentative de connecter le même compte Pro depuis 3+ devices distincts → alerte sécurité
- Les **assistants restent illimités** (ils n'ont pas accès admin, juste exécution)

Sans cette vérification, un compte Pro à 24,99 $/mois pourrait héberger 4 head coachs à 6,25 $/équipe — moins cher que Club à 14-24 $/équipe. Le garde-fou est essentiel à la cohérence du modèle.

---

## Cohérence mathématique (vérifiée)

### Coût mensuel par équipe (descendant monotone — sauf garde-fou Pro)

| Palier | Config | $/mois total | $/équipe/mois |
|---|---|---:|---:|
| Entraîneur | 1 équipe | 14,99 | **14,99** |
| Pro | 2 équipes | 24,99 | 12,50 |
| Pro | 4 équipes (max) | 24,99 | 6,25 ⚠️ |
| Club | 4 équipes | 97,00 | 24,25 |
| Club | 10 équipes | 169,00 | 16,90 |
| Club | 22 équipes | 313,00 | 14,45 |
| Org | 6 équipes | 179,00 | 29,83 |
| Org | 22 équipes | 419,00 | 19,05 |
| Fédé | 22 équipes | 416,67 (5000/12) | **18,94** |
| Fédé | 100 équipes | 416,67 | 4,17 |

⚠️ L'écart Pro 4 équipes vs Club est volontaire et protégé par le garde-fou (1 head coach unique).

### Break-evens calculés

**Org → Fédération** :
`89 × 12 + 15 × N × 12 ≥ 5 000` → `1 068 + 180 N ≥ 5 000` → **N ≥ 22 équipes** ✅

**Club → Org** (surcoût pour activer un 2e sport) :
`(89 - 49) + (15 - 12) × N = 40 + 3 N $/mois` → rentable dès activation d'un 2e sport (sinon double-paiement infrastructure si on prenait 2 Club).

**Entraîneur → Pro** :
2 abos Entraîneur = 29,98 $/mois → Pro à 24,99 $/mois économise **5 $/mois** dès 2 équipes.

---

## Seuils de conseils automatiques (in-app)

### 🔼 Upgrade triggers

| Trigger | Palier actuel | Suggestion | Bénéfice |
|---|---|---|---|
| User crée une 2e équipe | Entraîneur | **Pro** | -5 $/mois vs 2 abos |
| User atteint 4 équipes | Pro | Club ou Org | Équipes ∞ |
| User invite un 2e head coach | Pro | **Club** | Head coachs ∞ |
| User Club tente d'activer un 2e sport | Club | **Organisation** | +40 $ base + 3 $/équipe |
| User Org atteint 18 équipes (anticipation) | Org | Alerte "Fédé rentable à 22" | Préparation |
| User Org atteint 22 équipes | Org | **Fédération** | Forfait + SSO + white-label |

### 🔽 Downgrade triggers (anti-churn, loyauté)

| Trigger | Palier actuel | Suggestion | Économie |
|---|---|---|---|
| Pro avec 1 équipe depuis 60 jours | Pro | Entraîneur | -10 $/mois |
| Org avec 1 sport actif depuis 90 jours | Org | Club | -40 $ base + -3 $/équipe |
| Fédé avec <22 équipes depuis 1 an | Fédé | Organisation | Selon N |

### Banner permanent (dashboard admin)

```
┌──────────────────────────────────────────────────┐
│ 💡 Vous gérez 8 équipes en Club (volley)         │
│    Tous sports : Organisation = 209 $/mois (+72) │
│    Forfait Fédération rentable à 22 équipes      │
└──────────────────────────────────────────────────┘
```

### Service technique

`Services/SeuilUpgradeService.swift` (nouveau) :

```swift
struct UsageAbonnement {
    let nbEquipesUtilisees: Int
    let nbHeadCoachsUtilises: Int
    let sportsActifs: [String]
    let dateDernierChangementPalier: Date
}

func suggererUpgrade(abonnement: Abonnement, usage: UsageAbonnement) -> PalierOptimal?
func suggererDowngrade(abonnement: Abonnement, usage: UsageAbonnement) -> PalierOptimal?
```

Télémétrie (via `AnalyticsService` / TelemetryDeck) :
- `seuil_atteint:{trigger}`
- `upgrade_suggere:{from}_to_{to}`
- `upgrade_accepte` / `upgrade_refuse`

---

## Product IDs StoreKit v3

```
ca.origotech.playco.entraineur.monthly   →  14,99 $ CAD
ca.origotech.playco.entraineur.yearly    →  149 $ CAD
ca.origotech.playco.pro.monthly          →  24,99 $ CAD
ca.origotech.playco.pro.yearly           →  249 $ CAD
```

**Subscription group** : `playco.individual` — Entraîneur ↔ Pro upgrade fluide (StoreKit gère le pro-rata).

**Club / Organisation / Fédération** : **hors StoreKit**, Stripe Invoicing annuel.
- Évite les 30 % / 15 % Apple sur les gros tickets B2B
- Facturation annuelle classique (PO école, NEQ, TPS/TVQ)
- Compatibles avec cycles d'achat scolaires (août-septembre)

---

## Essais

| Palier | Essai |
|---|---|
| Entraîneur / Pro | **14 jours sans CC** (StoreKit natif `paymentMode: .freeTrial`) |
| Club / Organisation | **30 jours démo** + devis Stripe |
| Fédération | Démo personnalisée + RFP |

---

## Promotions

| Programme | Réduction | Sur |
|---|---|---|
| Étudiant-entraîneur (vérif `.edu` / `.cegep`) | -50 % | Entraîneur / Pro |
| Coach RSEQ / U Sports | -25 % à vie | Pro |
| École année 1 | -50 % | Club / Organisation |
| Ambassadeur (par référence convertie) | 3 mois offerts | Entraîneur / Pro |

---

## Migration v2.0.1 → v3.0

1. Subscribers `ca.origotech.playco.pro.{monthly,yearly}` actuels → alias **Pro v3** (renommage côté `StoreKitService`).
2. Subscribers `ca.origotech.playco.club.*` actuels → **Club v3** (0 utilisateur en prod, sans risque).
3. **Grandfathering** : tarif v2.0.1 maintenu pendant 12 mois après release v3.0.
4. Notification in-app v3.0 : « Merci d'être early adopter — votre tarif actuel est garanti jusqu'en septembre 2027. »

---

## Projections financières (12 mois post-v3.0)

Hypothèses prudentes marché QC élargi multi-sport (TAM × 4 vs volley seul) :

| Mois | Entraîneur | Pro | Club | Org | Fédé | MRR (CAD) |
|---|---|---|---|---|---|---|
| M3 | 30 | 8 | 2 | 1 | 0 | 1 015 $ |
| M6 | 100 | 25 | 8 | 4 | 0 | 3 433 $ |
| M9 | 250 | 70 | 20 | 12 | 1 | 8 870 $ |
| M12 | 500 | 150 | 40 | 25 | 2 | **18 575 $/mois** |

**ARR M12 cible** : **~223 k$ CAD**
+ 2-3 deals Fédération à 10-30 k$ : **ARR ~280-330 k$**

---

## Risques & mitigations

| Risque | Mitigation |
|---|---|
| Garde-fou Pro contourné par head coachs multiples | Vérification Apple ID + device principal, blocage propre à la 2e invitation head coach |
| Apple "Reader app" exemption refusée Club/Org | Acceptable : Stripe hors-store reste légal pour B2B contracts annuels |
| Stripe Invoicing manuel = compta lourde | Max 50 écoles/an gérable solo via QuickBooks / Sage |
| Fédération à 5 000 $/an trop bas pour vraie fédé | "À partir de" — sales ajuste à 12-30 k$ selon taille (Volleyball QC ~30k membres) |
| 24,99 $/mois jugé cher vs TeamSnap (12 $) | Positionner sur valeur unique (tactic board + multi-sport + Apple Pencil) |
| Cycle d'achat scolaire raté (août-sept) | Release v3.0 visée **avant le 15 août 2026** pour capter saison 2026-2027 |
| Sans free tier → WOM plus lent | Essai 14j sans CC + ambassadeurs + contenu YouTube par sport |
