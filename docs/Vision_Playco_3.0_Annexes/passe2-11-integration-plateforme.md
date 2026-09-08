# Playco — Référence unique plateforme (réconciliation, juillet 2026)

> **Statut : document d'arbitrage final.** Il réconcilie et REMPLACE, là où ils se contredisent : (a) la synthèse « Vision Playco 3.0 » de juillet 2026, (b) le plan « Vidéo pratiques + Supabase + tier Élite » (validé fondateur — préséance en cas de conflit), (c) `v3/MULTI_SPORT_PLAN.md` + `v3/SAAS_MODEL.md` (PR #3, mai 2026) et les specs `docs/playcast.md` + `docs/playco_insights.md` (mai 2026).
> Règle de préséance appliquée : **plan vidéo validé > synthèse juillet > docs mai**. Quand un doc de mai reste techniquement le meilleur, il est conservé comme *spec de référence* avec un calendrier requalifié.

---

## 1. Backend — trajectoire unifiée

### 1.1 Le principe qui tombe, et celui qui le remplace

Le principe de juillet « **zéro serveur avant contrat club signé** » tombe — c'était un garde-fou contre un serveur *à fonds perdus*, pas contre un serveur en soi. Le plan vidéo le remplace par un principe plus précis, qu'on érige en règle :

> **Zéro serveur sans financement dédié et sans surface impossible en CloudKit.** Un domaine n'obtient un backend Supabase que s'il remplit LES DEUX conditions : (1) une ligne de revenus le finance (tier Élite pour la vidéo, contrat Stripe pour le dashboard club) ; (2) la feature est structurellement hors de portée de CloudKit (média lourd, page web publique, realtime multi-plateforme, RLS fine par joueur).

Corollaire assumé : le dashboard club/fédération de la cible « double coach + club » se greffera sur la fondation Supabase déjà payée par Élite — le coût marginal d'entrée B2B chute, ce qui **renforce** la stratégie club au lieu de la contredire.

### 1.2 Architecture cible : deux mondes, une frontière nette

| Monde | Rôle | Contenu |
|---|---|---|
| **CloudKit + SwiftData** (colonne vertébrale) | Tout le **coaching offline-first**. Source de vérité des données pédagogiques et opérationnelles. | Les 30+ @Model existants : séances, exercices, terrain, stratégies, playbook, stats (PointMatch/ActionRallye/StatsMatch), roster, messagerie, musculation, scouting, abonnements, miroir Public DB de jointure d'équipe. |
| **Supabase (Postgres + Auth SIWA + RLS + Edge Functions + Realtime)** | Tout ce qui a une **surface web, multi-plateforme ou média**. Jamais source de vérité du coaching. | Domaine vidéo (métadonnées : `membres`, `videos`, `video_tags`, `video_clips`, `video_annotations`) ; plus tard : rapport de match web, dashboard club, profil carrière. |
| **Cloudflare Stream** | Média vidéo exclusivement (TUS upload background, HLS, purge 30 j). | Les octets vidéo ne transitent JAMAIS par CloudKit ni Postgres. |

**Règle de non-duplication** : aucune donnée n'existe dans les deux mondes. Supabase référence le monde CloudKit par identifiants opaques (`codeEquipe`, `joueurID` UUID) — jamais de copie de contenu pédagogique, jamais de nom d'athlète (PII minimale, déjà décidé : table `membres` sans nom).

### 1.3 Ce qui reste sur CloudKit à vie

- **Tout le domaine coaching** : Seance/Exercice/terrain/PointMatch/stats/scouting/musculation/messagerie. Le gymnase sans wifi est le cas nominal — ces données ne dépendent d'aucun serveur, jamais.
- **La sync inter-appareils du coach** (iPad ↔ iPhone) : `.automatic` CloudKit fait le travail, gratuit, éprouvé.
- **La jointure d'équipe SIWA** (miroir Public DB, code d'invitation, `rejoindreEquipe`/`reclamerMembreLocal`) : elle fonctionne, elle est testée, elle est gratuite. On NE la migre PAS vers Supabase Auth « pour faire propre » — c'est exactement le confort que la règle 1.1 interdit. Réévaluation seulement si le dashboard club exige une identité serveur unifiée (H3+).
- **Le partage coach→athlète existant** (SeancePartagee, MatchCalendrierPartagee, stats cumulées) : conservé tel quel.

### 1.4 Ordre de migration des domaines vers Supabase (tranché)

| # | Domaine | Quand | Justification |
|---|---|---|---|
| 1 | **Vidéo pratiques** (phases 0-9) | H1 fin → H2 | VALIDÉ. Financé par Élite. |
| 2 | **Rapport de match web par lien** (page publique lecture seule : score live via Realtime + box score final poussé par l'app) | H3 (≈ 2 sem) | Réutilise ~90 % de l'infra vidéo (Edge Functions, Realtime). Remplace le broadcast APNs de PlayCast pour les parents/supporters (§ 4). Outil de bouche-à-oreille : chaque lien partagé est du marketing. |
| 3 | **Dashboard club/fédération web** (lecture seule : équipes, résultats, présences, agrégats) | Sur premier contrat Club/Org Stripe en vue (H3-2027+) | C'est la contrepartie produit du canal Stripe. Ne se construit PAS en avance. |
| 4 | **Profil carrière athlète** (portable inter-équipes/saisons) | Post-dashboard club | Forte valeur rétention, mais exige une identité athlète serveur mature. |
| 5 | **Registre développement fédération** | Contrat fédé signé uniquement | Ticket ≥ 5 000 $/an finance son propre développement. |

**Vidéo MATCHS** n'est pas un domaine backend nouveau : c'est une extension du domaine 1 (mêmes tables, mêmes pipelines), déclenchée par le succès du pilote pratiques (§ 5).

### 1.5 Contrats architecturaux invariants (survivent à tout)

1. **Offline terrain absolu** : aucune fonctionnalité utilisée EN GYMNASE ne requiert le réseau. La capture vidéo est offline (file d'attente locale, pattern `JournalSyncStorage`) ; seule la *consommation* (streaming, partage) est online. Tout écran vidéo affiche un état dégradé propre hors ligne.
2. **Autorité de calcul = l'app** : toute formule vit dans `MetriquesVolley`/`AgregateurStatsMatch` on-device. Supabase STOCKE des résultats calculés (snapshots JSON poussés par l'app pour le rapport web/le dashboard), il ne RECALCULE jamais. Un seul endroit où un hitting % peut être faux.
3. **Frontière de confiance pédagogique** : le contenu pédagogique d'un coach (exercices, séances, playbook, annotations vidéo tactiques, notes) ne remonte JAMAIS au club/à la fédé. Le dashboard club ne voit que : résultats, présences, agrégats de participation. Cette frontière s'implémente en RLS (policies distinctes `coach_scope` vs `org_scope`) et se documente dans le contrat B2B.
4. **PII minimale côté Postgres** : pas de noms, identifiants opaques, `appleUserID` jamais stocké en clair côté Supabase (hash).

### 1.6 Coûts mensuels par palier d'usage (CAD, arrondis)

| Palier d'usage | Supabase | Stream (purge 30 j active) | Total/mois | MRR vidéo attendu | Ratio infra |
|---|---|---|---|---|---|
| **Pilote** (≤ 20 équipes vidéo) | 0 → 35 $ (Pro) | 10-20 $ | **≈ 50 $** | ≈ 800 $ (20 × 39,99) | ~6 % |
| **Croissance** (≈ 100 équipes) | 35-100 $ | 100-150 $ | **≈ 200-250 $** | ≈ 4 000 $ | ~6 % |
| **Succès** (≈ 500 équipes) | 100-200 $ | 500-900 $ | **≈ 700-1 100 $** | ≈ 17 500 $ | ~6 % |

**Règle de santé** : coût infra vidéo ≤ 15 % du MRR Élite. Si dépassé → resserrer les quotas (minutes stockées/équipe/mois) AVANT de toucher au prix. La purge 30 j (pg_cron) est le levier structurel qui rend la courbe linéaire plutôt qu'exponentielle.

---

## 2. Pricing unifié (arbitrage final)

### 2.1 L'arbitrage

Trois modèles en présence : la grille de juillet (Équipe 179 $/an, Club dégressif, Fédé 2-3 $/membre), le SAAS_MODEL 5 paliers (cohérence mathématique vérifiée, break-evens calculés), et le tier Élite du plan vidéo. **Décision : la STRUCTURE du SAAS_MODEL gagne** (5 paliers, variables structurelles, StoreKit pour les individuels / Stripe pour le B2B) — c'est le seul des trois modèles dont la cohérence interne est démontrée. La grille de juillet est abandonnée en tant que grille ; on en retient un insight : **afficher l'annuel en premier** (149/249/399 $), le mensuel existe pour baisser la barrière d'essai. Le tier Élite s'insère dans cette structure.

**Le principe « toutes les features dans tous les paliers » est AMENDÉ, pas abandonné** :

> Toutes les fonctionnalités **logicielles** (coût marginal nul : coaching, stats, Insights on-device, terrain) sont dans tous les paliers. Les fonctionnalités à **coût marginal d'infrastructure** (vidéo aujourd'hui ; toute IA cloud demain) forment un module tarifé séparément, accessible depuis n'importe quel palier.

**La vidéo est un tier ET un add-on selon le canal** — c'est la réconciliation :
- **Canal StoreKit (individuels)** : la vidéo se packagée en **tier Élite** (conforme au plan validé, product IDs `ca.origotech.playco.elite.{monthly,yearly}`). Élite = Pro + vidéo. Un seul subscription group avec upgrade path propre ; StoreKit gère mal les add-ons croisés et App Review encore plus mal. L'Entraîneur solo qui veut la vidéo passe Élite — assumé, cohérent avec le positionnement haut de gamme.
- **Canal Stripe (B2B)** : la vidéo est un **add-on par équipe** sur la facture (+8 $/équipe/mois). Un club ne doit pas payer un « tier » monolithique pour équiper 3 équipes sur 12.

### 2.2 Grille finale (CAD)

| Palier | Prix | Canal | Équipes | Head coachs | Sports | Vidéo |
|---|---|---|---|---|---|---|
| **Entraîneur** | 14,99 $/mois · **149 $/an** | StoreKit | 1 | 1 | Tous | — |
| **Pro** | 24,99 $/mois · **249 $/an** | StoreKit | 4 | 1 vérifié + assistants ∞ | Tous | — |
| **Élite** | 39,99 $/mois · **399 $/an** | StoreKit | 4 (comme Pro) | 1 vérifié | Tous | **Incluse** (quota minutes/mois) |
| **Club** | 49 $ + 12 $/équipe/mois | Stripe Invoice | ∞ | ∞ | 1 | Add-on +8 $/équipe/mois |
| **Organisation** | 89 $ + 15 $/équipe/mois | Stripe Invoice | ∞ | ∞ | Tous | Add-on +8 $/équipe/mois |
| **Fédération** | à partir de 5 000 $/an, dimensionné ≈ 2-3 $/membre/an | Contrat | ∞ | ∞ | Tous | Négociée |

Notes d'arbitrage :
- **Fédé** : les deux formules de mai et juillet se réconcilient — plancher forfaitaire 5 000 $ (protège le solo-dev), dimensionnement indicatif par membre (langage que parlent les fédés).
- **Club dégressif** (juillet) : abandonné. Le linéaire 49+12 est plus simple, et la « dégressivité » existe déjà structurellement via le break-even Fédé à 22 équipes. KISS.
- **Athlètes et assistants ne sont JAMAIS bloqués** (paywall role-aware conservé). La consommation vidéo par un athlète (clips partagés via RLS) ne requiert aucun abonnement — c'est le coach/le club qui paie.
- Essais : 14 j sans CC (StoreKit) pour Entraîneur/Pro/Élite ; 30 j démo + devis pour Club/Org. Promotions du SAAS_MODEL conservées telles quelles.

### 2.3 Product IDs et subscription group

```
ca.origotech.playco.entraineur.monthly / .yearly    (nouveaux)
ca.origotech.playco.pro.monthly / .yearly           (existants v2 — conservés tels quels)
ca.origotech.playco.elite.monthly / .yearly         (nouveaux — plan vidéo)
ca.origotech.playco.club.monthly / .yearly          (retirés de la vente — 0 abonné en prod)
```
**Subscription group : `playco.pro` existant, conservé** (un groupe ne se renomme pas sans friction). Ranking d'upgrade dans le groupe : Élite > Pro > Entraîneur. StoreKit gère le pro-rata des upgrades.

### 2.4 Migration depuis la grille v2 (Pro/Club actuels)

1. **Le lancement App Store imminent se fait sur la grille v2 telle quelle** (Pro + Club StoreKit). On ne retarde RIEN pour le pricing.
2. **Une seule bascule**, à l'activation du tier Élite (phase 8 vidéo, H2) : ajout `entraineur.*` + `elite.*` au groupe, retrait de `club.*` de la vente (« removed from sale » — les 0 abonnés existants ne cassent rien), `FeatureGating` étendu (`.bloqueSiNonElite(source:)` pour les surfaces vidéo coach).
3. **Grandfathering** : abonnés Pro v2 gardent leur tarif 12 mois (message in-app early adopter, repris du SAAS_MODEL).
4. Stripe Invoicing (Club/Org) n'ouvre qu'avec le premier contrat B2B réel — aucune infra de facturation en avance.

### 2.5 Seuils upgrade automatiques : conservés, dégraissés

`SeuilUpgradeService` est conservé mais réduit à **3 triggers v1** : (1) création d'une 2e équipe → suggérer Pro ; (2) tap sur une surface vidéo sans Élite → paywall Élite contextuel ; (3) 5e équipe OU invitation d'un 2e head coach → « Parlons Club » (mailto/formulaire, pas de checkout). Les 6 triggers + 3 downgrades + banner dashboard du SAAS_MODEL arrivent avec le dashboard club (H3+). La télémétrie `seuil_atteint`/`upgrade_accepte` (TelemetryDeck) est conservée.

---

## 3. Multi-sport (tranché)

**L'arbitrage de juillet tient : volleyball first, extraction au 2e sport payant.** Le calendrier du MULTI_SPORT_PLAN (4 packs v3.0, août-septembre 2026) est **caduc** — il est physiquement incompatible avec vidéo + refonte navigation + refonte visuelle dans un budget de 25-30 sem/an. Livrer 4 sports médiocres tuerait le positionnement « haut de gamme volleyball » qui est l'actif actuel.

**MAIS le protocole SportPack reste LA spec technique de référence.** Le document est bon : audit de couplage exact (6 enums + 3 structs), stratégie de migration CloudKit-safe démontrée (raw values conservés comme IDs = zéro perte), capabilities (`aRotation`/`aLignes`/`aPeriodesChronométrees`) qui résolvent les vraies divergences. Quand l'extraction se déclenchera, on exécutera CE plan.

**Ce que la phase 0 fait MAINTENANT (discipline, zéro refactor)** :
1. `Equipe.sportID: String = "volleyball"` — ajout trivial CloudKit-safe, à glisser dans la prochaine migration de schéma.
2. **Gel du couplage** : aucune NOUVELLE référence volleyball hors des 6 enums recensés. Toute nouvelle feature stats passe par `MetriquesVolley`/`AgregateurStatsMatch` (déjà la règle n° 24).
3. **Le domaine vidéo Supabase naît sport-agnostique** : tables sans aucune référence volley, `video_tags.type` en strings libres (pas d'enum volleyball), `debut_exercice` générique. C'est gratuit aujourd'hui, coûteux à corriger demain.
4. La refonte navigation 5 espaces ne hardcode pas « volleyball » dans les intitulés d'espaces.

**Déclencheur d'extraction** (l'un ou l'autre) : un club/une fédé d'un AUTRE sport prêt à signer, ou saturation mesurée du marché volley QC. Chantier estimé 4-6 sem (plan A.1-A.4), pas avant H3 2027. Premier candidat : basketball (marché scolaire QC, pack déjà spécifié).

**PR #3** : ne pas fermer sans trace — merger les deux docs dans `docs/` avec bandeau « Référence technique validée — calendrier remplacé par la Référence plateforme juillet 2026 ».

---

## 4. PlayCast & Insights (tranché)

### Playco Insights → FEATURE de Playco, pas un module

Conforme à la synthèse de juillet : le **résumé narratif Foundation Models on-device** devient une feature de l'espace **Analyser**. V1 = debrief fin de match (`@Generable`, streaming snapshots, < 8 s sur iPad M-series), export texte/PDF. **Coupé de la V1** : Charts 3D (gadget), annotations vocales (V2 non planifiée), mode scout IA. Gating : **inclus dès Pro** — coût marginal nul (inférence locale), donc le principe « features logicielles partout » s'applique ; c'est un argument d'upsell Entraîneur→Pro, PAS une raison de payer Élite. Fallback propre sur matériel non compatible. Effort : 3-4 sem, positionné H3 (§ 5).

### PlayCast → démantelé en trois morceaux, l'app compagnon est GELÉE

La spec PlayCast visait trois personas avec une seule app + broadcast APNs. Le Supabase vidéo **change effectivement la donne** — on tranche par persona :

1. **Le coach lui-même** (Dynamic Island, écran verrouillé) → **Live Activity LOCALE**, feature de Playco, zéro serveur, zéro APNs distant. Retenu par la synthèse de juillet, confirmé. ~1-2 sem, H3.
2. **Parents / supporters / staff distant** → **rapport de match web par lien** (§ 1.4, domaine 2) : page web au lien partageable, score live via Supabase Realtime, box score final. Supérieur à PlayCast sur toute la ligne : zéro app à installer, fonctionne sur Android (les parents !), zéro quota APNs, et chaque lien est un vecteur d'acquisition. Le « mode invité 5 spectateurs » de la spec PlayCast devient simplement « le lien est gratuit ».
3. **Coach assistant qui logge depuis son iPhone** : déjà couvert par Playco lui-même (iPhone supporté, permissions staff). Les interactive snippets/Watch/CarPlay : **gelés**, réévalués seulement si la page web live prouve une demande de suivi temps réel massive.

**Décision** : pas d'app compagnon séparée à horizon 12 mois. L'app PlayCast reste une option de *packaging* future (elle réutiliserait le canal Realtime), pas un engagement. Le modèle « second seat moins cher » de la spec meurt avec le modèle seat-based qu'il présupposait.

---

## 5. Roadmap unifiée H1/H2/H3

**Contrainte de gouvernance** : 25-30 sem effectives/an, UN pari > 6 sem/an, estimations ×2. La vidéo phases 0-9, honnêtement doublée, pèse **12-14 semaines effectives : c'est LE pari de l'année** (à cheval sur H1-H2). Conséquence brutale : la refonte navigation, la refonte visuelle « mat », terrain 2.0 et Insights ne tiennent pas tous en parallèle — on découpe et on fait glisser.

**Le pari H3 « vidéo match » de la synthèse de juillet** ne disparaît pas : il est **dérisqué et rétrogradé en extension**. Le pilote pratiques valide l'infra (upload, Stream, RLS, coûts) ; « vidéo matchs » devient alors un chantier de 4-6 sem (plus un pari de 12) — candidat naturel au pari 2027-2028, décidé sur les données du pilote.

### H1 — juillet → novembre 2026 (~12 sem effectives) : LANCER + fondations

| Chantier | Effort | Note |
|---|---|---|
| Lancement App Store v2.2 + stabilisation + retours pilotes | 3 sem | Priorité absolue. Grille pricing v2 inchangée. Capture le cycle d'achat scolaire avec le produit EXISTANT (l'objectif « v3 multi-sport avant le 15 août » est mort). |
| Refonte navigation : TabView 5 espaces (Aujourd'hui/Préparer/Coacher/Analyser/Équipe) — structure seulement, vues existantes rebrassées | 3 sem | La refonte d'IA de juillet, phase 1. Le Playbook (fusion bibliothèque+stratégies+formations) = réorganisation, pas réécriture. |
| Refonte visuelle « mat » vague 1 : tokens LiquidGlassKit, chrome, typographie, purge symboles décoratifs | 2 sem | Faisable vite PARCE QUE le design system est centralisé. D6 (zéro émoji/symbole) déjà en place côté stats. |
| Pricing v3 prep : produits ASC (entraineur/elite), `SeuilUpgradeService` 3 triggers | 1 sem | Rien d'activé côté UI. |
| **Vidéo phases 0-2** : infra Supabase (tables, RLS, Edge Functions, SPM supabase-swift derrière façade) + client + capture/upload offline | 3 sem | Démarre SEULEMENT si le lancement est stable. Sinon glisse intégralement en H2. |

### H2 — décembre 2026 → avril 2027 (~10-11 sem effectives, saison volley = période d'usage réel) : LE PARI VIDÉO

| Chantier | Effort |
|---|---|
| **Vidéo phases 3-7** : lecture HLS, tagging live (pattern PaveNumeriqueRapideView), clips auto par exercice, annotation dessin (réutilise CanvasDessinView/OverlayDessinView), partage joueur RLS | 7-8 sem |
| **Phase 8** : tier Élite activé + bascule grille v3 (Entraîneur ajouté, Club StoreKit retiré, grandfathering) | 1,5 sem |
| **Phase 9** : durcissement (tests RLS, quotas, consentement mineurs) + pilote 5-10 équipes | 1,5 sem |

H2 est monopolisé par la vidéo — c'est le prix d'un pari > 6 sem, et c'est assumé. **Glissent hors de H2** : Insights, Live Activity locale, rapport web, refonte visuelle vague 2. Point de sortie GO/NO-GO fin H2 : rétention vidéo des équipes pilotes + ratio coût infra/MRR.

### H3 — mai → septembre 2027 (~9-10 sem effectives) : RÉCOLTER + décider le pari suivant

| Chantier | Effort | Condition |
|---|---|---|
| Rapport de match web par lien (score live Realtime + box score) | 2 sem | Réutilise l'infra vidéo. |
| Insights V1 (debrief fin de match on-device) | 3-4 sem | — |
| Live Activity locale + refonte visuelle vague 2 (espaces Coacher dark/courtside) | 2 sem | — |
| **Décision du pari 2027-2028** : vidéo MATCHS (si pilote concluant) OU dashboard club web (si contrat B2B en vue) OU terrain 2.0 profond | décision, pas exécution | UN seul commence. |

**Terrain 2.0** : la directive fondateur « retravailler le terrain/les séances/la préparation » est servie en deux temps — la préparation de pratique passe par l'espace Préparer + Playbook (H1) ; le terrain 2.0 *profond* (zoom infini, frames, moteur générique compatible SportPack) est un candidat pari H3-2027, pas avant. Le dire clairement maintenant évite de le commencer « en douce » trois fois.

**Coupé / gelé (liste brutale)** : Charts 3D Insights (coupé) · annotations vocales (non planifié) · app PlayCast + Watch + CarPlay + broadcast APNs (gelés) · 4 sports v3.0 (caduc — extraction sur signal d'achat) · Superwall/RevenueCat (jamais — vendor lock, bus factor) · dégressivité Club (abandonnée) · Stripe avant premier contrat (non).

---

## 6. Risques nouveaux de l'intégration et mitigations

| Risque | Gravité | Mitigation |
|---|---|---|
| **Double stack CloudKit+Supabase** : divergence d'identité (SIWA idToken vs jointure CloudKit), double source de vérité rampante | Élevée | Règle « un domaine = un monde » (§ 1.2) ; table `membres` mappée par hash d'`appleUserID` + `codeEquipe` opaques ; document de frontière dans `docs/` ; revue systématique de tout nouveau champ Supabase (« pourquoi pas CloudKit ? »). |
| **Erreur de policy RLS = fuite de vidéos d'athlètes MINEURS** | Critique (réputationnel/légal) | Deny-by-default ; tests RLS automatisés par rôle (coach/athlète/étranger) exécutés en CI avant chaque déploiement de policy ; signed URLs Stream à expiration courte ; revue sécurité dédiée avant le pilote (déclencheur `/security-review`). |
| **Loi 25 QC + consentement mineurs** (hébergement vidéo hors QC) | Élevée | Consentement explicite par athlète dans l'app avant tout partage ; rétention 30 j documentée ; politique de confidentialité mise à jour ; PII minimale (pas de nom en Postgres — déjà décidé) ; DPA Supabase/Cloudflare archivés. |
| **Coûts Stream en cas de succès viral** | Moyenne | Quotas minutes/équipe/mois par tier ; purge 30 j (pg_cron, décidé) ; alertes de facturation Cloudflare ; kill-switch upload dans l'Edge Function `demande-upload` ; règle de santé infra ≤ 15 % MRR Élite. |
| **App Review avec tier Élite** | Moyenne | Compte démo review avec vidéo seedée (la feature payante doit être démontrable) ; AUCUN lien d'achat Stripe dans l'app iOS (guideline 3.1.1 — le B2B se vend hors app, sans mention in-app) ; athlètes jamais paywallés (déjà la règle) ; quota vidéo décrit clairement dans la fiche produit ASC. |
| **Première dépendance SPM (supabase-swift)** | Moyenne | Façade `SupabaseService` — aucun `import Supabase` hors de ce module ; version épinglée ; plan B documenté : PostgREST/GoTrue sont des APIs REST simples, un client maison minimal est faisable en cas d'abandon du SDK. |
| **File d'attente d'upload sature l'iPad** (gymnase offline, 64 Go) | Moyenne | Compression HEVC locale avant mise en file ; plafond de file avec purge FIFO après upload confirmé ; indicateur d'espace dans l'UI capture. |
| **Le pari vidéo déborde et mange H3** | Élevée (gouvernance) | Point GO/NO-GO fin H2 avec critères chiffrés ; les phases 3-7 sont individuellement livrables (tagging sans clips reste utile) — on peut couper à la phase N et livrer. |

---

## 7. Tableau de décision final

| Domaine | Décision | Remplace | Quand |
|---|---|---|---|
| Principe backend | « Zéro serveur sans financement dédié + surface hors CloudKit » | « Zéro serveur avant contrat club » (synthèse juillet) | Immédiat |
| Backend vidéo | Supabase + Cloudflare Stream, métadonnées seulement, CloudKit intouché | — (validé fondateur, confirmé) | H1 fin → H2 |
| Domaines Supabase suivants | Rapport match web → dashboard club (sur contrat) → profil carrière → registre fédé | Rien de planifié auparavant | H3 → 2027+ |
| CloudKit | À vie pour tout le coaching offline + jointure SIWA + sync coach | Toute velléité de migration « propreté » | Permanent |
| Contrats architecturaux | Offline gymnase absolu · autorité de calcul = l'app · frontière pédagogique en RLS · PII minimale | — (reconduits et durcis) | Permanent |
| Structure pricing | 5 paliers du SAAS_MODEL (Entraîneur/Pro/Élite/Club/Org/Fédé) | Grille juillet (Équipe 179 $/Club dégressif) | Bascule en H2 (phase 8) |
| Vidéo dans le pricing | Tier **Élite 39,99 $/mois · 399 $/an** côté StoreKit ; **add-on +8 $/équipe/mois** côté Stripe | « Toutes les features dans tous les paliers » (amendé : logiciel partout, infra tarifée) | H2 |
| Product IDs | `entraineur.*` + `elite.*` ajoutés au groupe `playco.pro` ; `club.*` retiré de la vente | Grille StoreKit v2 (pro+club) | H2 ; lancement imminent sur grille v2 |
| Seuils automatiques | `SeuilUpgradeService` conservé, réduit à 3 triggers | 6 triggers + downgrades + banner (SAAS_MODEL) | Triggers H2 ; le reste avec dashboard club |
| Multi-sport | Volleyball first ; SportPack = spec de référence, calendrier caduc ; phase 0 = `sportID` + gel du couplage + vidéo sport-agnostique | Exécution 4 sports v3.0 août-sept 2026 (MULTI_SPORT_PLAN) | Extraction sur signal d'achat, pas avant H3 2027 |
| Insights | Feature Playco espace Analyser, debrief on-device, inclus dès Pro ; Charts 3D coupés | Spec module « palier supérieur » (mai) | H3 (3-4 sem) |
| PlayCast | App compagnon GELÉE ; remplacée par (a) Live Activity locale, (b) rapport match web Realtime, (c) rien pour Watch/CarPlay | Spec PlayCast 11 sem + broadcast APNs (mai) | (a)+(b) en H3 |
| Pari annuel | Vidéo pratiques = LE pari 2026-2027 (12-14 sem ×2 incluses) | Pari H3 « vidéo match » (synthèse) — devient extension 4-6 sem candidate pari 2027-2028 | H1 fin → H2, GO/NO-GO fin H2 |
| Refonte navigation 5 espaces | Structure en H1 (3 sem), contenus par vagues H1→H3 | « Refonte IA » monolithique | H1 |
| Refonte visuelle « mat » | Vague 1 (tokens/chrome/typo) H1, vague 2 (Coacher/courtside) H3 | — | H1 + H3 |
| Terrain 2.0 | Préparation de pratique via espace Préparer/Playbook (H1) ; refonte profonde = candidat pari H3-2027 | Implicite « tout de suite » | H1 partiel ; profond ≥ mi-2027 |
| PR #3 | Docs mergés dans `docs/` avec bandeau « référence technique, calendrier remplacé » | PR ouverte en l'état | H1 |
| Stripe B2B | N'ouvre qu'au premier contrat Club/Org réel | Implémentation anticipée (SAAS_MODEL S5) | Sur contrat |

**Ligne de fond** : une seule dette de cohérence subsistait entre les trois corpus — « qui paie le serveur, et quand ». Elle est réglée : **Élite paie Supabase, Supabase porte ensuite le B2B, CloudKit reste le cœur offline à vie, et tout le reste du calendrier se plie au seul pari vidéo.**
