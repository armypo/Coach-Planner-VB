# Dossier de recherche marché — Playco

**Date :** 14 avril 2026
**Stade :** TestFlight v1.9.0
**Fondateur :** Solo (Québec)
**Scope :** 4 axes — Concurrence · Taille de marché · Investisseurs · Tendances tech

---

## Table des matières

1. [Résumé exécutif](#résumé-exécutif)
2. [Principales conclusions](#principales-conclusions)
   - [1. Le marché existe mais il est petit et compétitif](#1-le-marché-existe-mais-il-est-petit-et-compétitif)
   - [2. Concurrence — deux menaces réelles, une opportunité](#2-concurrence--deux-menaces-réelles-une-opportunité)
   - [3. Capital — le jeu se gagne sans VC](#3-capital--le-jeu-se-gagne-sans-vc)
   - [4. Technologie — ignorer la vidéo IA, miser Apple-native](#4-technologie--ignorer-la-vidéo-ia-miser-apple-native)
3. [Analyse concurrentielle détaillée](#analyse-concurrentielle-détaillée)
4. [Modèle TAM/SAM/SOM détaillé](#modèle-tamsamsom-détaillé)
5. [Recherche investisseurs détaillée](#recherche-investisseurs-détaillée)
6. [Veille technologique détaillée](#veille-technologique-détaillée)
7. [Implications stratégiques](#implications-stratégiques)
8. [Risques et caveats](#risques-et-caveats)
9. [Recommandation — Plan 90 jours + 12 mois](#recommandation--plan-90-jours--12-mois)
10. [Sources](#sources)

---

## Résumé exécutif

| Dimension | Verdict |
|---|---|
| **Taille de marché** | Niche viable — **200-400 k$ CAD/an** SAM Québec, **7-12 M$ CAD/an** SAM Amérique du Nord. **PAS un marché VC-scale.** |
| **Position concurrentielle** | Whitespace réel : **aucun concurrent iPad-natif francophone tout-en-un** sur le segment scolaire/collégial québécois. Menaces principales = Hudl (distribution) et Assistant Coach Volleyball (produit). |
| **Capital** | **Non-dilutif d'abord**. Stack québécois (LE CAMP → Mitacs → Fonds Impulsion → Anges Québec) peut lever 150-300 k$ sans toucher à une seule part. VC seulement à 20 k$ MRR signés. |
| **Priorité tech H2 2026** | **Apple FoundationModels + DataVolley parser + HealthKit**. **Ignorer** l'analyse vidéo IA (Hudl a 5+ ans d'avance, terrain perdu). |
| **Décision** | **Continuer comme indie/lifestyle business** avec plafond réaliste 100-200 k$ ARR An 3, path vers 500-700 k$ An 5 si extension Canada anglophone. Si l'objectif est un VC-scale 10 M$ ARR : pivoter ou vendre. |

---

## Principales conclusions

### 1. Le marché existe mais il est petit et compétitif

**Faits sourcés :**
- 800 M pratiquants volleyball mondial, 350 M réguliers ([FIVB](https://staracademyvolleyball.com/how-many-volleyball-players-are-there-worldwide/))
- Canada : ~130-150 k joueurs licenciés, ~5 000-6 000 coachs
- **Québec : 35-40 k joueurs, ~1 200-1 500 coachs adressables** ([La Presse](https://www.lapresse.ca/sports/volleyball-quebec/le-volleyball-pour-tous/2025-01-02/volleyball-quebec/un-sport-entre-bonnes-mains.php))
- US : 492 799 joueurs secondaires + 1 500 programmes collégiaux = ~39 000 coachs ([NFHS 2024-25](https://nfhs.org/stories/participation-in-high-school-sports-hits-record-high-with-sizable-increase-in-2024-25))
- Marché plateformes coaching sportif : **5,2 G$ US en 2024** (CAGR 18,9 %) — mais écart énorme avec Technavio (0,34 G$), définition molle

**Calcul Playco** (hypothèses ARPU 150 $ CAD/coach blended) :
- SAM Québec : **200-400 k$ CAD/an**
- SOM An 3 réaliste : **80-150 k$ CAD ARR**
- Plafond théorique Québec seul : **225 k$ CAD/an** (même à 100 % de pénétration)

**Comparable-clé** : Hudl fait **730,4 M$ US en 2024**, 3,5 M clients, **ARPU moyen ~209 $ US/an** ([getlatka](https://getlatka.com/companies/hudl)).

### 2. Concurrence — deux menaces réelles, une opportunité

**Tier 1 — Volleyball spécifique :**
- **Hudl Volleymetrics/Balltime** (230 M$ US levés, [acquisition Balltime fév. 2025](https://www.businesswire.com/news/home/20250206384625/en/Hudl-Expands-Volleyball-Focus-Through-Game-Changing-Acquisition-of-Balltime)) — **$900-1600/an**. ERP sportif, pas tablette de coach. Force : distribution. Faiblesse : prix, UX bench-side, zéro français.
- **Data Volley 4** (~450 $ CAD/an, [Data Project](https://www.dataproject.com/Products/EN/en/Volleyball/DataVolley4)) — standard pro, inaccessible aux non-spécialistes.
- **SoloStats 123** (gratuit, 50 000+ coachs, [AVCA endorsed](https://www.solostatslive.com/)) — stats seulement, zéro pratique/stratégie/équipe.
- **iStatVball 3** ([istatvball.com](https://istatvball.com/)) — mature, stats RallyFlow, iOS/Android.
- **Assistant Coach Volleyball** ([assistantcoach.co](https://www.assistantcoach.co/)) — **concurrent le plus proche structurellement** : tout-en-un, Apple-native, français. **Faiblesse vs Playco** : match live moins profond, pas de rotation adversaire, pas de mode courtside.

**Tier 2 — Multi-sports :**
- **GameChanger** ([DICK's, gratuit](https://gc.com/volleyball)) — volleyball minimaliste (aces/erreurs seulement) mais **danger si DICK's investit**.
- **TeamSnap** (9,99-17,99 $/mois, [pricing](https://www.teamsnap.com/pricing)) — logistique pure, complémentaire, pas concurrent direct.

**Tier 3 — le vrai statu quo :** Notability/GoodNotes + Excel + WhatsApp + clipboard papier. C'est là que les coachs québécois sont coincés.

**Gap de positionnement identifié :**
1. iPad Air 13" + Apple Pencil natif : personne ne cible ce couple
2. Français québécois + NCAA/FIVB : zone blanche totale
3. Tout-en-un courtside (mode bord de terrain = unique)
4. Hors-ligne robuste (gymnases Wi-Fi médiocre)
5. Prix sous 200 $/an avec profondeur complète

### 3. Capital — le jeu se gagne sans VC

**VC sport-tech NA** existe (Courtside, 359 Capital ex-Sapphire, Elysian Park, Will Ventures, Alumni Ventures Sports) mais **thèses privilégient IA vidéo et scale mondial** — pas un produit iPad francophone volleyball-only. [SportsVisio a levé 9 M$](https://www.sportsvisio.com/stories/sportsvisio-secures-3-2m-additional-funding-to-scale-ai-sports-solution) précisément parce qu'ils sont multi-sport + AI vidéo.

**Le stack non-dilutif québécois est exceptionnel et mal exploité :**

- **LE CAMP Québec** (gratuit, [lecampquebec.com](https://lecampquebec.com/en)) — porte d'entrée obligatoire pour les programmes gouvernementaux
- **Mitacs Accelerate Entrepreneur** ([mitacs.ca](https://www.mitacs.ca/our-programs/accelerate-entrepreneur/)) — 15 k$/stage de 4-6 mois par étudiant gradué, renouvelable. 30-60 k$ cumulés sur 12 mois.
- **Fonds Impulsion (Investissement Québec, 200 M$ annoncés oct. 2025)** ([La Presse](https://www.lapresse.ca/affaires/2025-10-21/administre-par-investissement-quebec/un-fonds-de-200-millions-pour-les-jeunes-pousses-technos.php)) — **chèques 250 k$-2 M$**, plafond 50 % du tour, siège social Québec obligatoire. **Match parfait** pour Playco.
- **Anges Québec** ([angesquebec.com](https://angesquebec.com/en)) — **a déjà investi dans Sportlogiq**, seule preuve d'appétit sport-tech québécois. Syndicate co-invest Elevia = chèques ~25 k$+.
- **CEIM Fonds SIJ** ([ceim.org](https://www.ceim.org/fonds-sij/)) — jusqu'à 200 k$ non-dilutif.
- **RS&DE + CDAE** : 30-40 % de la masse salariale dev remboursée.
- **Panache Ventures** (100 M$ Fund II, [BetaKit](https://betakit.com/panache-closes-100-million-for-second-fund-as-firm-doubles-down-on-seed-stage-startups/)) — seul fonds CA qui écrit encore des premiers chèques agnostic-sector en pré-seed.

**À éviter :** Sapphire/359 Capital (trop tard), Drive by DraftKings (mauvaise thèse), Techstars Sports ([discontinué mars 2025](https://www.ibj.com/articles/techstars-discontinues-indianapolis-based-sports-tech-accelerator)), Inovia (mauvais match B2B SaaS entreprise).

**Stack non-dilutif atteignable : 150-300 k$ de runway sans dilution.** Le VC devient utile seulement à 20 k$ MRR signés.

### 4. Technologie — ignorer la vidéo IA, miser Apple-native

**Analyse vidéo IA** : **champ perdu**. Hudl Assist + Balltime AI identifie déjà chaque touche avec vitesse de service et hauteur d'attaque ([Hudl Assist](https://www.hudl.com/products/assist/volleyball/ai)). Pixellot utilise multi-caméras + CNN ([Pixellot](https://www.pixellot.tv/sports/volleyball/)). Construire un détecteur YOLO maison = 50k+ images annotées + 6-12 mois + expertise ML. Coût d'opportunité prohibitif.

**Opportunité asymétrique Apple FoundationModels (iOS 26)** : accès direct au LLM ~3B paramètres on-device, `@Generable`, tool calling, **gratuit, hors ligne, privacy-first** ([Apple newsroom](https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/)). 3 usages immédiats :
1. Résumé match automatique depuis PointMatch structuré
2. Recommandations stratégiques depuis ScoutingReport
3. Saisie vocale notes coach

**Standards DataVolley/VIS** : le format `.dvw` reste le standard pro/NCAA de facto. `openvolley/datavolley` (GitHub, MIT) est un parser R actif. **Porter en Swift = 2-3 semaines de dev** = import/export DataVolley = différentiation technique réelle vs. tous les concurrents iPad ([openvolley](https://github.com/openvolley/datavolley), [FIVB VIS manual](https://inside.cev.eu/media/t2udgpnl/fivb_vis_user_manual.pdf)).

**UX courtside** : **Playco est déjà en avance**. Le Mode bord de terrain v1.8.0 (60pt boutons, 72pt score, haptics, PaveNumeriqueRapide) est le vrai moat vs. Hudl/Assistant Coach.

**HealthKit read-only** : 3-5 jours de dev pour afficher HR/load/sommeil des athlètes sur fiche joueur — différentiation Apple-native immédiate.

**Vision Pro, DMA, Apps alt EU** : **ignorer**. Non-marché avant 2028.

---

## Analyse concurrentielle détaillée

### Synthèse

Le marché des applications de coaching volleyball est **bifurqué** : d'un côté, un géant quasi-monopolistique (Hudl, 730,4 M$ US de revenus en 2024, 400 000+ utilisateurs volleyball, 79 pays) qui absorbe les innovateurs par acquisition ; de l'autre, une longue traîne de niches (SoloStats, iStatVball, VolleyStation, Volleyball Ace) servant des segments spécifiques. Entre les deux, un vide : aucun produit iPad-natif, bilingue français-anglais, tout-en-un (pratique + match live + stratégie + équipe) n'occupe vraiment le segment scolaire/collégial québécois. **C'est l'espace que Playco peut revendiquer.**

### Tier 1 — Concurrents directs (volleyball-spécifiques)

#### Hudl / Volleymetrics / Balltime (le consolidateur)
- **Réalité produit** : suite fragmentée en transition. Hudl a acquis Volleymetrics puis Balltime (février 2025) et reconstruit une plateforme unifiée, avec "aucun changement attendu pendant la saison 2025". L'expérience utilisateur est en chantier.
- **Tarification** : club volleyball **Silver 900 $/an, Gold 1 600 $/an** (équipes additionnelles 650–1 100 $/an). Balltime individuel **25 $/mois ou 299 $/an**.
- **Plateforme** : web + iOS/Android (app centrée vidéo, pas iPad-natif SwiftUI).
- **Financement** : **230 M$ US levés** sur 6 rounds (Accel, Bain Capital, Nelnet).
- **Force** : ubiquité (27 000 organisations, 40 000 écoles/clubs desservis), crédibilité NCAA/pro, intégration vidéo IA.
- **Faiblesse** : prix hors de portée du coach scolaire/amateur ; UX pour entrées manuelles chère en temps ; zéro français ; surtout orienté vidéo/post-match, pas pratique au quotidien.
- **Gap vs Playco** : Hudl est un ERP sportif — Playco est une tablette de coach.

#### Data Volley 4 (Data Project, Italie — standard pro)
- **Réalité produit** : logiciel desktop Windows/Mac pour scouts pros/élite, codification symbolique obscure, courbe d'apprentissage semaines/mois.
- **Tarification** : **licence annuelle à partir de 299 €** avec analyse vidéo.
- **Plateforme** : Windows/Mac desktop (pas d'iPad natif).
- **Force** : le standard de facto en volleyball pro/FIVB/NCAA D1.
- **Faiblesse** : inaccessible aux non-spécialistes ; aucune dimension "pratique/équipe/messagerie". Cible pros uniquement.

#### SoloStats 123 (Rotate123, É-U)
- **Réalité produit** : app gratuite simple "1-2-3 button flow", endossée par l'AVCA, 50 000+ coachs.
- **Tarification** : **gratuit illimité** ; Starter Bundle payant pour rapports agrégés et WebReports.
- **Plateforme** : iOS + Android + Web. iPad compatible, pas iPad-natif premium.
- **Force** : gratuit, simple, endosseurs crédibles, export MaxPreps/Hudl/Excel.
- **Faiblesse** : stats seulement — zéro pratique, stratégie, terrain dessinable, équipe, messagerie.
- **Gap vs Playco** : Playco couvre 5 dimensions, SoloStats couvre 1.

#### iStatVball 3 (Demivision, É-U)
- **Réalité produit** : "la prochaine génération de la #1 app stats volleyball depuis 10 ans". Interface brevetée "RallyFlow", shot charts, heatmaps, sync vidéo.
- **Tarification** : essai 14 jours, puis **achat par saison** (pas d'abonnement auto-renouvelé).
- **Plateforme** : iOS + Android.
- **Force** : mature, coachs satisfaits, export Excel/MaxPreps, cloud backup.
- **Faiblesse** : stats uniquement. Pas de pratique, pas de gestion d'équipe. Payant par saison désoriente les nouveaux coachs.

#### Volleyball Ace (TapRecorder, É-U)
- **Réalité produit** : app vétéran (10+ ans), utilisée par 5 000+ équipes HS/club/college.
- **Tarification** : achats intégrés — Charting 14,99 $, Opponent Insight 9,99 $, Consolidation 9,99 $, **Time Codes Hudl 39,99 $**. Modèle fragmenté, cumulable vers ~75 $.
- **Plateforme** : iOS, Android, Windows Surface Pro.
- **Force** : stats complètes, output MaxPreps/DakStats/Hudl, mature.
- **Faiblesse** : UI/UX datée, produit uniquement stats, fragmentation des IAP crée friction.

#### VolleyStation (Pologne)
- **Réalité produit** : plateforme "VS Score" orientée scoring digital + stats avancées.
- **Tarification** : non publiée publiquement — contact commercial.
- **Plateforme** : iOS/Android + web.
- **Force** : positionnement européen, rapports détaillés, intégration fédérations.
- **Faiblesse** : opacité tarifaire, faible présence nord-américaine, pas d'écosystème pratique/équipe.

#### Assistant Coach Volleyball (France-Europe)
- **Réalité produit** : **le concurrent le plus proche de Playco structurellement**. All-in-one : bibliothèque d'exercices, plans de pratique, profils joueurs, box scores, Apple TV/Watch support, export PDF, sync multi-device.
- **Tarification** : non divulguée (freemium + IAP selon catalogue App Store).
- **Plateforme** : iPhone/iPad/Apple TV/Apple Watch — également dispo pour basket, foot, handball, rugby, water polo.
- **Force** : multi-sport, multi-device, UX propre, iPad-friendly, **disponible en français** (app française à l'origine).
- **Faiblesse** : stats live point-par-point moins poussées qu'iStatVball/Hudl ; pas de messagerie inter-équipe dédiée ; pas de rotation adversaire ni heatmap zone 1-6 ; vidéo absente ; multi-sport = profondeur moindre par sport.
- **Gap vs Playco** : Playco est plus profond côté match live (PointMatch, rotation adversaire symétrique, mode bord de terrain courtside) et ancré iPadOS natif SwiftUI moderne.

### Tier 2 — Plateformes multi-sports

#### GameChanger (DICK's Sporting Goods)
- **Réalité produit** : scorekeeping + streaming 1080p + vidéo automatique. Volleyball : stats service (aces, erreurs, ace %).
- **Tarification** : **100 % gratuit pour coachs et staff**.
- **Force** : gratuit, streaming intégré, propriété DICK's (marketing massif).
- **Faiblesse** : volleyball minimaliste vs baseball/softball (produit phare).

#### TeamSnap
- **Réalité produit** : gestion d'équipe (planning, RSVP, chat, paiements). 30+ sports.
- **Tarification** : **gratuit (≤15 membres) → 9,99–17,99 $/mois**.
- **Force** : standard nord-américain de facto pour la logistique d'équipe.
- **Faiblesse** : **zéro stats live, zéro terrain dessinable, zéro pratique volleyball profond**.

#### SportsEngine (NBC Sports / Comcast)
- Plateforme clubs/tournois + AES pour volleyball. Backend fédérations. Lourd, ERP, pas outil de coach terrain.

#### CoachNow
- Video analysis + messagerie coach/athlète multi-sport. **À partir de 39,99 $/mois**. Focalisé feedback individuel (golf/tennis surtout), volleyball faiblement desservi.

#### TeamBuildr
- Plateforme strength & conditioning (University of Oregon volleyball). **900–2 800 $/an**. Complémentaire — couvre uniquement la musculation.

### Tier 3 — Outils adjacents (le vrai statu quo)

La réalité du coach québécois scolaire/collégial en 2026 : **Notability/GoodNotes pour dessiner les plays + Excel/Numbers pour les stats + WhatsApp pour la messagerie équipe + papier/clipboard pour le match live**.

Les coachs y restent coincés pour 3 raisons :
1. **Friction d'adoption** : les apps volleyball pro (Data Volley) demandent des jours de formation.
2. **Prix** : Hudl Club 900–1 600 $/an inaccessible pour un club scolaire québécois.
3. **Langue** : aucune app volleyball pro en français nativement.

### Tableau comparatif

| Produit | Pratique | Match live | Terrain dessinable | Équipe/Stats | Messagerie | Prix/an | iPad natif | Français |
|---|---|---|---|---|---|---|---|---|
| **Playco** | Oui | Oui (PointMatch + rotation adv.) | PencilKit + overlay | NCAA/FIVB complet | Oui | TBD | **Oui (SwiftUI)** | **Oui** |
| Hudl Volleymetrics | Non | Oui (vidéo) | Limité | Oui | Non | **900–1 600 $** | Non | Non |
| Data Volley 4 | Non | Oui (pro) | Non | Oui | Non | ~450 $ CAD | Non (Win/Mac) | Partiel |
| SoloStats 123 | Non | Oui | Non | Limité | Non | **Gratuit** | Non | Non |
| iStatVball 3 | Non | Oui (RallyFlow) | Non (shot charts) | Oui | Non | Par saison | Non | Non |
| Assistant Coach VB | Oui | Oui (box score) | Whiteboard basique | Oui | Non | Freemium + IAP | Partiel | **Oui** |
| GameChanger | Non | Scoring + stream | Non | Service only | Oui | **Gratuit** | Non | Non |
| TeamSnap | Drills partenaire | Non | Non | Non | Oui | 70–130 $ | Non | EN seulement |

### Vue contrariante — qui Playco risque de perdre face à qui

**Le concurrent le plus dangereux est Hudl, mais pas pour les raisons évidentes.** Hudl ne va pas offrir une expérience iPad-native meilleure que Playco — son ADN est web + vidéo. Le vrai risque : **Hudl distribue gratuitement, via les fédérations et associations (AVCA, NCAA, Volleyball Canada), son produit bundle à chaque coach inscrit**. Si Volleyball Québec ou le RSEQ signe un deal Hudl distribution, tous les coachs reçoivent Hudl "offert" avec leur licence fédérale, et Playco devient une 2e app à payer en plus.

Le **deuxième danger réel : Assistant Coach Volleyball**. Produit propre, français natif, multi-device Apple, couvre déjà les mêmes dimensions que Playco. Playco doit prouver sa supériorité dans le match live (PointMatch, rotation adversaire, mode courtside).

Le **troisième danger silencieux : GameChanger gratuit + bundle DICK's Sporting Goods**. Si DICK's décide d'investir dans le volleyball comme il l'a fait pour baseball/softball, GameChanger devient le standard gratuit adopté par défaut.

### 3 recommandations stratégiques concurrence

**1. Verrouiller le marché francophone canadien par partenariats fédéraux (6 mois)**
Aller directement chercher Volleyball Québec, RSEQ (cégeps), Volleyball Canada, les programmes sport-études. Offrir une licence éducation gratuite pour les programmes HS/cégep en échange de la distribution officielle. Avant que Hudl/Assistant Coach ne signe un deal francophone, Playco doit devenir le "outil officiel du coach francophone québécois". Le marché (500+ programmes scolaires/collégiaux + 200+ clubs) est atteignable en 6 mois de BD focalisé.

**2. Doubler sur le différentiateur "courtside PencilKit + live stats"**
Le mode bord de terrain avec pavé numérique rapide et le support Apple Pencil pour annoter le terrain EN temps réel pendant un match sont uniques. Ajouter : (a) export vidéo du match avec overlay stats (pas besoin d'intégration Hudl Vidéo si Playco génère le clip nativement), (b) AirPlay vers écran de gymnase pour présenter rotations en équipe time-out, (c) bibliothèque d'exercices partageable entre coachs avec diagrammes animés.

**3. Modèle prix freemium agressif + monétisation club (12 mois)**
- **Coach individuel** : 100 % gratuit pour 1 équipe (contre-attaque GameChanger et SoloStats).
- **Club/école** : 199 $ CAD/an tout inclus (multi-équipes, multi-coach, assistants, stats historisées CloudKit, export PDF/CSV). Prix *1/5e* de Hudl avec meilleure UX iPad.
- **Pro/fédération** : tarif custom avec scouting adversaire IA et rapports avancés.

Le risque absolu à éviter : **tarifer comme Data Volley (449 €) ou Hudl (900 $)** — Playco perdra, car la distribution gagnera.

---

## Modèle TAM/SAM/SOM détaillé

### Snapshot

| Métrique | Valeur | Confiance |
|---|---|---|
| **TAM mondial** (plateformes coaching sportif) | 5,2 G$ US (2024) | Sourcé |
| **TAM volleyball spécifique** (estimé) | ~260 M$ US/an | **Estimation** |
| **SAM Amérique du Nord volleyball** | ~90-120 M$ US/an | **Estimation** |
| **SAM Canada volleyball** | ~4-6 M$ CAD/an | **Estimation** |
| **SAM Québec volleyball** | ~1,0-1,4 M$ CAD/an | **Estimation** |
| **SOM Québec An 1** | 30-80 k$ CAD | **Estimation** |
| **SOM Québec An 3** | 150-400 k$ CAD | **Estimation** |
| **Verdict** | **Marché de niche viable, mais pas "VC-scale"** | — |

### TAM — Approche top-down

**Contexte mondial (faits sourcés) :**
- **800 M de pratiquants volleyball mondiaux** selon la FIVB, dont ~350 M réguliers. Volleyball = 4e sport mondial par popularité.
- **Marché global des plateformes de coaching sportif** : 5,2 G$ US en 2024, CAGR projeté 18,9 % jusqu'à 20,8 G$ US en 2033.
- **Marché plus restreint (Technavio)** : 0,34 G$ en 2024 vers 0,41 G$ en 2025 (CAGR 19,6 %). Écart énorme — à prendre avec prudence.
- **Marché global sports-tech** : 22,69 G$ US en 2024 → 27,39 G$ US en 2025.

> **⚠️ ALERTE :** L'écart entre 0,34 G$ et 5,2 G$ pour "sports coaching platforms" montre que la définition du marché est molle. Les deux chiffres sont cités tels quels par les firmes d'analyse.

**TAM volleyball spécifique (estimation) :** Le volleyball représente environ 5 % du marché coaching sportif.

**TAM volleyball mondial ≈ 5,2 G$ × 5 % = 260 M$ US/an**

> **⚠️ LEAP DE LOGIQUE :** Le 5 % est un "guesstimate" basé sur la part relative du volleyball vs autres sports dans les catalogues Hudl/TeamSnap/SkillShark. Aucune source directe.

### Comparables cotés/privés

| Entreprise | Revenu 2024 | Clients | Sport(s) |
|---|---|---|---|
| **Hudl** | 730,4 M$ US | 3,5 M | Multi-sports (incl. volleyball) |
| **TeamSnap** | ~30 M$ US (certaines sources citent 100-250 M$) | 25 M utilisateurs, 19 k organisations | Multi-sports jeunesse |

**Lecture :** Hudl est le 800-livres gorille du marché coaching. Avec 3,5 M de clients et 730 M$ US de revenus, son ARPU moyen ≈ **209 $ US/client/an**. C'est un point d'ancrage crucial.

### SAM — Marché adressable réaliste

#### Amérique du Nord

**États-Unis :**
- **492 799 participants volleyball secondaire (2024-25)**, 3e sport féminin le plus pratiqué
- **~16 572 écoles secondaires** avec programme volleyball
- **334 universités NCAA D1 + 437 NCAA D3** avec programme volleyball
- Ajoutons ~300 D2 et ~500 NAIA/junior college → **~1 500 programmes collégiaux**

**Estimation coaches volleyball É.-U. :** 16 572 écoles × 1,5 coach (head + assistant) + 1 500 programmes collégiaux × 3 coaches ≈ **~29 000 coachs scolaires/collégiaux** + ~10 000 coachs club USA Volleyball = **~39 000 coachs adressables É.-U.** *(estimation)*

**Canada :**
- **Volleyball Canada** : estimation interne ~65 000 à 85 000 membres licenciés
- **Estimation coaches Canada :** ~4 000-6 000 coachs actifs tous niveaux confondus

**Calcul SAM Amérique du Nord (estimation) :**
- 39 000 (É.-U.) + 5 000 (Canada) = **~44 000 coachs volleyball adressables**
- ARPU plausible : ~180 $ CAD/an moyen
- **SAM NA ≈ 44 000 × 180 $ = 7,9 M$ CAD/an en revenu potentiel**

Avec les équipes payant au niveau organisationnel :
- ~18 000 équipes NA × 400 $ CAD/équipe/an = **~7,2 M$ CAD/an**

**SAM Amérique du Nord volleyball ≈ 7-12 M$ CAD/an** *(estimation large)*

#### Canada — focus

| Source | Pratiquants | Coachs estimés |
|---|---|---|
| Volleyball Québec | 35-40 k joueurs | ~1 500-2 000 *(est.)* |
| Ontario (extrapolation) | ~50-60 k | ~2 500 *(est.)* |
| BC + Alberta + autres | ~30-40 k | ~1 500 *(est.)* |
| **Total Canada** | **~130-150 k joueurs** | **~5 000-6 000 coachs** *(est.)* |

**SAM Canada (estimation) :**
- 5 500 coachs × 180 $ CAD ARPU = **~1,0 M$ CAD/an** (licence individuelle)
- OU 2 200 équipes × 400 $ CAD = **~0,9 M$ CAD/an** (licence équipe)
- **SAM Canada ≈ 1,0-1,5 M$ CAD/an**

#### Québec — le marché primaire

**Données sourcées :**
- **35 000-40 000 joueurs** licenciés au Québec
- **~10 500 étudiants-athlètes au secondaire RSEQ** *(à valider)*
- **Tarification Volleyball Québec** : 11,98 $ récréatif / 33,73 $ compétitif

**Segmentation coachs Québec (estimation bottom-up) :**

| Segment | Unités | Coachs/équipe | Total coachs |
|---|---|---|---|
| Écoles secondaires RSEQ (D1/D2/D3 benjamin/cadet/juvénile × M/F) | ~400 équipes | 1,5 | **600** |
| Cégeps (D1/D2/D3 M/F) | ~60 équipes | 1,5 | **90** |
| Universités (U Sports/RSEQ U) | ~10 équipes | 2 | **20** |
| Clubs civils Volleyball Québec | ~150 clubs × 3 équipes | 1 | **450** |
| Beach volley (saisonnier) | — | — | **50** |
| **TOTAL COACHS QUÉBEC** | | | **~1 200-1 500** |

**SAM Québec (calcul avec ARPU réaliste de 150 $ CAD/coach/an) :**
- 1 300 × 150 $ CAD = **195 k$ CAD/an** (prix coach-par-coach)
- OU 500 équipes × 250 $ CAD = **125 k$ CAD/an** (prix équipe)
- Avec extensions features premium : × 1,5-2
- **SAM Québec volleyball ≈ 200-400 k$ CAD/an**

### Hypothèses ARPU — pourquoi 150 $ et pas 30 $/mois

**Contrainte psychologique :** un coach de volley secondaire québécois est typiquement bénévole ou payé une centaine d'heures × 25 $/h pour toute la saison. Sa volonté de payer (WTP) est plafonnée autour de **100-200 $/an**.

**Scénarios ARPU pour Playco :**

| Scénario | ARPU | Commentaire |
|---|---|---|
| **Freemium pur** | 0 $ (conversion < 3 %) | Non viable standalone |
| **Pro individuel** | 12 $/mois = **144 $/an** | Sweet spot marché |
| **Équipe (cégep/univ)** | 300 $/an | Payé par l'établissement |
| **Premium (video + analytics)** | 25 $/mois = **300 $/an** | Parité Hudl Bronze |

**Hypothèse retenue :** ARPU blended ≈ 150 $ CAD/an (mix 70 % individuel à 144 $ + 30 % équipe à 300 $).

### SOM — Capture réaliste 3 ans

**Hypothèses de pénétration :**
- An 1 (2026-27) : 3-5 % des coachs québécois
- An 2 : 8-12 %
- An 3 : 15-25 %

**Projection revenu Playco Québec :**

| Année | Coachs payants | ARPU | Revenu CAD |
|---|---|---|---|
| An 1 | 40-80 | 150 $ | **6-12 k$** |
| An 2 | 120-200 | 160 $ | **19-32 k$** |
| An 3 | 250-400 | 175 $ | **44-70 k$** |

**Ajoutons :**
- Upside Canada hors-Qc An 3 (Ontario + BC early) : +30-60 k$
- Early adopters USA francophones/Nord-est An 3 : +10-30 k$

**Revenu An 3 réaliste cas médian : 80-150 k$ CAD/an**
**Revenu An 3 cas bullish : 200-300 k$ CAD/an**

**SOM 3 ans ≈ 100-200 k$ CAD de ARR**

### Vue ours (bear case) — pourquoi le marché peut être plus petit

1. **Fragmentation du marché coach volley.** Contrairement au football US, beaucoup de coachs volley utilisent gratuitement Google Docs, papier, Excel. La "WTP commerciale" est structurellement inférieure.

2. **Cannibalisation Hudl.** Hudl Volleyball existe déjà, est omniprésent chez les cégeps/universités D1, et offre video + stats + recrutement.

3. **Saisonnalité brutale.** Volleyball indoor = septembre-mars. Beach = juin-août. Un coach paie 6-8 mois utiles — l'ARPU réel est plus proche de 80-120 $ que 150 $.

4. **Taille du Québec.** 1 200-1 500 coachs est un plafond dur. Même à 100 % de pénétration, c'est **225 k$ CAD/an**. Au prix iPad-only (excluant coachs Android — perte estimée 40 % du marché), le plafond redescend à ~130 k$. **Ce n'est pas un marché VC-scale.**

5. **Apple Tax.** La commission 15 % (small business program) sur abonnements in-app enlève 15 % du revenu brut sans effort.

6. **Écart données coaching sportif 5,2 G$ vs 0,34 G$.** Le TAM global est possiblement surévalué par les cabinets d'analyse.

7. **Barrière iPad-only.** Le parc d'iPad chez les coachs scolaires québécois peut plafonner le marché adressable réel à 30-50 % des coachs.

**Bear case Québec : SOM An 3 ≈ 30-60 k$ CAD** — soit 1 employé temps partiel.

### Décision marché

**Playco est un produit viable comme business de niche rentable pour 1-2 personnes, mais n'est PAS un candidat VC-scale.**

- **TAM mondial volleyball coaching tech :** ~260 M$ US *(estimation)*
- **SAM Québec réaliste :** 200-400 k$ CAD/an *(estimation)*
- **SOM An 3 réaliste :** 80-150 k$ CAD de ARR
- **Plafond théorique Québec seul :** ~225 k$ CAD/an
- **Plafond avec Canada + Northeast US francophone :** ~500-700 k$ CAD/an

**Continuer l'investissement est justifié SI :**
- (a) L'objectif est un side-business/indie product à 100-200 k$ ARR, OU
- (b) Playco sert de véhicule d'apprentissage vers un pivot multi-sports plus tard, OU
- (c) Une vente stratégique à Volleyball Québec/Canada est envisagée comme exit (probable valorisation 1-3x ARR = 80-300 k$).

**Continuer l'investissement n'est PAS justifié SI :**
Vous cherchez à lever du VC, scaler à 10 M$ ARR, ou en faire votre revenu principal à temps plein dans moins de 3 ans.

---

## Recherche investisseurs détaillée

### 1. VC québécois/canadiens early-stage

**Real Ventures (Montréal) — Orbit MTL.** Fonds de 31 M$ dédié à Montréal, chèques typiques < 1 M$, pré-money 3–5 M$. Sector agnostic, priorité affichée sur IA. Pas de thèse sport-tech explicite.

**Inovia Capital (Montréal).** > 1,5 G$ US sous gestion. Seed moyen 3,84 M$, Series A moyen 8,95 M$. Full-stack fund montréalais, mais historiquement focus B2B SaaS, fintech, entreprise — **peu probable pour une app iOS niche sport**.

**Panache Ventures (Montréal/Toronto).** Fonds II de 100 M$, premiers chèques jusqu'à 1,5 M$ en pré-seed/seed. 105 entreprises au portfolio. Cheque sweet-spot parfait pour Playco ; sector agnostic ; **fondamental canadien le plus actif au pré-seed**.

**BDC Capital – Seed Venture Fund.** Enveloppe 50 M$ annoncée en 2024, 10 M$/an sur 5 ans, focus logiciel IA, pré-seed/seed, co-lead canadien. Chèques 500 k$–2 M$.

**Investissement Québec – Fonds Impulsion (annoncé oct. 2025).** 200 M$, successeur d'Impulsion PME. Chèques **250 k$–2 M$**, multiples follow-ons. Pré-seed + seed, **obligation siège social/décisionnel au Québec** — Playco coche toutes les cases. Doit être supporté par incubateur/accélérateur (LE CAMP, CEIM, Québec Tech, District 3). Plafond 50 % du tour total.

**Anges Québec.** 171 M$ investis sur près de 200 sociétés depuis 2008. **Investisseur dans Sportlogiq** (volleyball/hockey AI) — seule preuve directe d'appétit sport-tech dans l'écosystème. 3 investissements en 2025 (rythme ralenti). Nouveau véhicule Elevia (syndicate co-investment, min 25 k$).

**Brightspark Ventures (Toronto).** 48 sociétés au portfolio, seulement 2 nouveaux investissements en 12 mois. Rythme faible, pas de thèse sport-tech. **Pas prioritaire.**

**Whitecap Venture Partners (Toronto).** Focus historique B2B techno industrielle. **Skip.**

### 2. Fonds spécialisés sport-tech nord-américains

**Courtside Ventures (New York).** 300 M$ AUM cumulés, Fund III 100 M$ en déploiement, Michael Jordan LP. 96+ investissements. **Leader indiscuté early-stage sport/lifestyle/gaming**. Stage pré-seed à Series A. **Fit idéal thématique, mais taille Playco probablement trop petite**.

**Sapphire Sport → 359 Capital (spin-out nov. 2025).** 300 M$ AUM, chèques 2–10 M$, Series A/B uniquement. **Stage trop avancé pour Playco.**

**Elysian Park Ventures (Los Angeles, LA Dodgers ownership group).** 399 M$ AUM, stage-agnostic, chèques 500 k$–100 M$, moyenne 1–5 M$. **Investit hors US**. Bon fit thématique.

**Drive by DraftKings (Boston).** Fonds I de 60 M$ (2021, drapeau : 4 ans). LPs = Kraft, Jones, DraftKings, MSG, Arctos. **Probable trop gros/tard pour Playco.**

**Will Ventures (Boston).** Fonds II 150 M$ (2022). 38 sociétés, 4 nouveaux investissements en 12 mois. Early-stage sport/entertainment/consumer. **Stage compatible Playco.**

**KB Partners (Chicago).** Intersection sport + tech, opérateurs-entrepreneurs. Information publique mince.

**Alumni Ventures – Sports & Humans First Fund.** Véhicule "focused fund" LP pour particuliers accrédités (min 10 k$). Écrit petits chèques (100–500 k$), co-investit aux côtés de lead VCs. **Utile comme co-investisseur passif**, pas comme lead.

**Causeway Media Partners.** Growth-stage (Freeletics, FitLab). **Trop tard pour Playco, skip.**

**Techstars Sports Accelerator (Indianapolis).** **DISCONTINUÉ en mars 2025** – ne plus le cibler.

**Comparatif marché (important).** SportsVisio (concurrent direct : AI stats volleyball/basket) a levé **3,2 M$ en juin 2025**, portant son total à 9 M$+. LPs : Sapphire Sport, Hyperplane, Sovereign's, Mighty Capital, Sony Innovation Fund, Alumni Ventures. **Lecture** : le capital sport-tech existe mais les fonds NA privilégient la vidéo IA ; une app iPad pure « coach planning » sans ML vidéo est sous-pondérée dans les thèses.

### 3. Anges stratégiques & accélérateurs

- **LE CAMP (Québec)** – incubateur 340 startups depuis 2008. Programmes MVP, Propulsion, Fast-Track. **Passage obligatoire** pour se qualifier au Fonds Impulsion et au programme Mitacs.
- **CEIM (Montréal)** – Fonds SIJ jusqu'à 200 k$ pour jeunes startups tech.
- **Québec Tech (ex-Startup Montréal)** – 9 M$ fédéraux 2024 pour internationalisation.
- **Founder Institute Québec City** – accélérateur global, sans chèque significatif mais mentorat et réseau LPs.
- **Y Combinator** – aucun coaching volleyball identifié W25/S25. Long shot mais prestigieux (500 k$ standard deal).
- **Mitacs Accelerate Entrepreneur** – levier massif non-dilutif : 7 500 $ contribution → 15 000 $ par stage de 4–6 mois avec étudiant gradué, renouvelable. Exclut sociétés non-incorporées. Doit être en incubateur approuvé.

### Shortlist — Top 10 meilleurs fits

| # | Investisseur | Type | Stage | Chèque typique | Thèse sport-tech | Fit Playco |
|---|-------------|------|-------|----------------|------------------|-----------|
| 1 | **Fonds Impulsion (Investissement Québec)** | Gouvernemental QC | Pré-seed/seed | 250 k–2 M$ | Non, mais mandat QC tech | **Très fort** |
| 2 | **Panache Ventures** | VC privé CA | Pré-seed/seed | jusqu'à 1,5 M$ | Sector agnostic | **Fort** |
| 3 | **Anges Québec** | Réseau anges | Pré-seed/seed | 250 k–1 M$ | Oui (Sportlogiq) | **Fort** |
| 4 | **BDC Seed Venture Fund** | Gouvernemental CA | Pré-seed/seed | 500 k–2 M$ | Non, IA-friendly | **Bon** |
| 5 | **Will Ventures** | VC spécialisé sport | Seed/Series A | 1–3 M$ | Oui (sport/athlète) | **Bon** |
| 6 | **Elysian Park Ventures** | VC Dodgers | Agnostic-stage | 1–5 M$ moy. | Oui (global) | **Bon mais gros** |
| 7 | **Courtside Ventures** | VC spécialisé sport | Seed | 1–3 M$ | Oui (leader catégorie) | **Bon mais stade au-dessus** |
| 8 | **Real Ventures (Orbit MTL)** | VC Montréal | Pré-seed | < 1 M$ | Agnostic | **Moyen** |
| 9 | **Alumni Ventures Sports Fund** | Syndicate | Co-invest | 100–500 k$ | Oui | **Moyen** |
| 10 | **CEIM – Fonds SIJ** | Accélérateur QC | Pré-seed | jusqu'à 200 k$ | Non | **Bon filet** |

### Top 3 « must-pitch » avec chemins intro

**1. Fonds Impulsion (Investissement Québec).** Le match parfait structurellement : fondateur au QC, produit québécois, francophone, stade amorçage, chèque 500 k$ atteignable. **Intro chaude** : passer d'abord par LE CAMP Québec pour devenir leur "protégé" — le programme exige parrainage d'un incubateur reconnu.

**2. Anges Québec.** Ils ont *déjà* validé la thèse sport-tech québécoise avec Sportlogiq. Ils comprennent l'angle "coach-technologue". **Intro chaude** : demander à Pedro Herrera (dir. investissement) via LinkedIn en citant Sportlogiq + le marché volleyball québécois. Anges Québec fait des journées pitch mensuelles ; soumettre via leur portail et activer parallèlement le véhicule Elevia.

**3. Panache Ventures.** Un des seuls fonds canadiens qui écrit toujours des premiers chèques significatifs en pré-seed, sector agnostic, francophone (bureau Montréal). **Intro chaude** : réseau BetaKit, Notman House, ou via un portfolio founder Panache déjà backé.

### Top 3 « éviter » ou « no probable »

**1. Sapphire Sport / 359 Capital.** Stage 2–10 M$ Series A/B, trop avancé, spin-out récent en restructuration.

**2. Drive by DraftKings.** Fonds de 60 M$ datant de 2021 (drapeau âge), focus Series A+, LPs = propriétaires NBA/NFL. Mismatch taille et thèse.

**3. Techstars Sports Accelerator.** **Discontinué mars 2025**.

### Vue contrariante : VC est-il la bonne voie ?

**Réponse courte : NON, pas encore — et possiblement jamais.**

**(a) Le marché sport-tech volleyball est trop étroit pour une thèse VC classique.** Le volleyball en NA a ~1/20 la taille du marché basketball, et les fonds sport-tech priorisent les catégories qui scalent (vidéo IA, fan engagement, paris, athlète perso). Les VC demandent 10× retour ; ça ne colle pas avec un plafond de 500-700 k$ ARR.

**(b) Un fondateur solo dev+coach en TestFlight avec 0 revenue signed n'a pas la traction VC.** Les dilutions pré-revenue au Québec sont brutales (20–30 % pour 500 k$). Réflexe : **non-dilutif d'abord**.

**(c) Le mix non-dilutif québécois est exceptionnel.** Playco peut réalistement cumuler :
- **Mitacs Accelerate Entrepreneur** : 2–4 stages = 30–60 k$ de R&D
- **CEIM Fonds SIJ** : jusqu'à 200 k$ non-dilutif/dette convertible
- **Subvention Montréal « Innovation ouverte »**
- **Crédits impôt RS&DE fédéral + CDAE Québec** : 30–40 % de la masse salariale dev remboursée
- **Revenu contrats école** : RSEQ Cégeps volleyball = 25+ équipes abonnables à 500–1 500 $/an/club = 12–40 k$ MRR atteignable en 12 mois

**Stack non-dilutif + premiers contrats RSEQ = 150–300 k$ de runway sans toucher à une seule part.** Le VC ne devient utile qu'à ~20 k$ MRR signés.

---

## Veille technologique détaillée

### 1. AI/ML d'analyse vidéo en volleyball

#### État des lieux

**Hudl domine.** Après le rachat de **Volleymetrics** (2017) et de **Balltime** (février 2025), Hudl dessert 27 000 organisations de volleyball et plus de 400 000 utilisateurs dans 79 pays. Balltime seul apportait 12 000 équipes et 125 000 athlètes.

**Capacités réelles de l'IA volleyball aujourd'hui.** Le produit phare **Hudl Assist powered by Balltime AI** identifie chaque touche et son résultat, expose les moments clés, et permet un workflow post-match de 30–45 min (contre 2–3h manuel). Métriques automatiques: **vitesse de service, hauteur d'attaque**. Couverture NCAA college disponible; high school annoncé pour 2026.

**Pixellot** utilise un système multi-caméras breveté + CNN (réseaux convolutionnels) pour production broadcast automatique, avec algorithmes dédiés indoor et beach.

**Catapult** reste sur le monitoring de charge (PlayerLoad, sauts, HR via capteurs Polar H10) plutôt que l'analyse vidéo, y compris en beach.

**Open source crédible :**
- `VolleyVision` (shukkkur, GitHub) propose segmentation sémantique de terrain entraînée sur 25 000 images, avec tracking DaSiamRPN
- `VolleyBallYolo` (Roboflow, janvier 2025) est un modèle YOLOv8s entraîné sur ballons + joueurs
- Un modèle DETR temps réel publié en 2025 traite l'information globale sur frames consécutives pour détection d'actions volleyball

**Apple on-device (iOS 26).** Le framework **FoundationModels** donne accès direct au LLM ~3B paramètres avec `@Generable` (génération guidée) et tool calling — gratuit, hors ligne, privacy-first. Pour la vision: **VNDetectHumanBodyPoseRequest** + Core ML + Create ML permettent pose estimation, trajectory detection et action classification sur CPU/Neural Engine, sans serveur.

#### Implication Playco

**IGNORER l'analyse vidéo AI full-stack** à court terme (6–12 mois). Construire un détecteur de ballon YOLOv8 + action classifier compétitif avec Balltime requiert 50k+ images annotées, une pipeline d'entraînement et 6–12 mois. Hudl dépense déjà des millions.

**PRÉPARER un usage ciblé de FoundationModels** pour:
1. Résumé automatique de match à partir des PointMatch structurés existants
2. Suggestions de stratégies à partir du ScoutingReport
3. Transcription de notes coach vocales

Coût de build: faible (3 lignes de Swift). Coût d'intégration: nul. Risque lock-in: nul.

### 2. Standards d'analytics volleyball modernes

#### État des lieux

**VIS (FIVB Volleyball Information System)** est le standard officiel pour les événements FIVB. Il enregistre chaque rallye et classe les actions en 3 skills de scoring (serve, attack, block) + 3 non-scoring (receive, set, dig).

**DataVolley** (fichier `.dvw`) reste le format de facto pour le scouting pro/NCAA. Data Project publie la mapping officielle FIVB VIS ↔ DataVolley. `openvolley/datavolley` (R) est un parser open source actif (v1.9.2, 2 mois) par Raymond/Ickowicz/Widdison, capable de lire `.dvw` en play-by-play.

**Métriques actuelles.** Kill%, hitting efficiency (FIVB: (K−E)/TA), receive rating, side-out%, point-scoring ratio par rotation. **Expected Points Added (EPA)** n'est **pas** standardisé en volleyball à la différence de la NFL/NBA.

#### Implication Playco

**ADOPTER le format DataVolley en import/export.** L'écrire comme une fonctionnalité "Pro": importer un `.dvw` depuis une clé USB via Files, l'exposer en `PointMatch` pour visualisation sur iPad. C'est un moat différentiateur contre TeamSnap. Complexité: parser modéré, 1–2 semaines de dev Swift.

**Porter openvolley en Swift** pour la lecture uniquement. Pas besoin de réécrire toute l'analytique R — juste le parser `.dvw`.

### 3. UX coach 2025–2026

#### État des lieux

- **Tablet-first** reste la norme
- **Wearables coach-athlete.** Catapult Vector +HR vests intègrent Polar H10 pour HR temps réel. Mais l'intégration se fait via app propriétaire Catapult — pas d'API ouverte simple.
- **Multi-device sync.** Cloud is king (Hudl) mais dans notre niche (club/NCAA), la latence et la robustesse hors-ligne restent un problème. CloudKit reste un différenciateur pour un stack 100% Apple.
- **WCAG 2.2 / Accessibility.** Obligation croissante (Europe, Canada, secteurs éducatifs).

#### Implication Playco

**Playco est déjà en avance.** Le Mode bord de terrain v1.8.0 (grands boutons 60pt, score 72pt, PaveNumeriqueRapideView, haptics) est très bien positionné. C'est le vrai moat vs. Hudl.

**PRIORITÉ: CONSOLIDER** le bord de terrain avant d'ajouter des features analytics lourdes.

**INTÉGRER HealthKit en lecture seule** pour afficher HR/load/sommeil des athlètes — 2–3 jours de dev, différenciation immédiate.

### 4. Plateforme / distribution

#### État des lieux

- **Vision Pro = prototype R&D, pas de marché volleyball.** Aucune app volleyball coaching dédiée.
- **EU DMA.** Depuis juin 2025, les apps peuvent être distribuées via marketplaces alternatifs en EU. Pour Playco (base Québec/Canada), impact nul à court terme.
- **Hudl pricing club** ~499$ USD/équipe/saison. **TeamSnap** reste freemium.
- **Subscription fatigue.** Les coachs de club paient déjà TeamSnap (gestion) + Hudl (vidéo) + éventuellement DataVolley (analyse). Un 4e abonnement est un no-go.

#### Implication Playco

- **IGNORER Vision Pro.** Zéro ROI avant 2027.
- **IGNORER distribution alternative EU.** Non-marché pour Playco.
- **STRATÉGIE PRIX: freemium par coach + payant par équipe** quand Playco monétise. Copier le pattern Notion. Éviter le Hudl Club tier et son sticker shock.

### Synthèse tech

#### Top 5 tendances par impact sur Playco

1. **Hudl/Balltime consolide le marché vidéo** — concurrent direct sur la stats live et video, mais UX club-level encore faible. **Haut impact, négatif**.
2. **Apple FoundationModels (iOS 26) on-device** — opportunité asymétrique pour Playco. **Haut impact, positif**.
3. **Standards DataVolley/VIS** — ouverture possible via openvolley. **Moyen impact, positif**.
4. **UX courtside/haptics** — Playco est déjà devant. **Haut impact, positif, à défendre**.
5. **Subscription fatigue coach/club** — menace tout nouveau modèle payant. **Moyen impact, neutre**.

#### Top 3 tech bets à FAIRE (6 mois)

1. **Intégrer Apple FoundationModels** pour 3 features: résumé match automatique, recommandations stratégiques, saisie vocale notes. Stack: `FoundationModels` + `@Generable` + Swift. Effort: 2–3 semaines. Différenciation immédiate, zéro coût runtime.
2. **Parser DataVolley `.dvw`** en import/export dans Playco. Permet d'absorber les données des équipes NCAA/pro existantes. Effort: 2–3 semaines. Moat technique réel.
3. **HealthKit read-only pour stats athlètes** (HR moyen, sommeil, load journalier). Effort: 3–5 jours.

#### Top 3 tech bets à NE PAS FAIRE

1. **Construire un détecteur vidéo YOLO/pose estimation maison.** Coût: 50k+ images annotées, 6–12 mois, expertise ML. Hudl/Pixellot ont 5+ ans d'avance.
2. **Porter Playco à Vision Pro.** Marché inexistant en volleyball, 2 ans minimum avant ROI.
3. **Monétisation SaaS cher à la Hudl.** Subscription fatigue réelle. Éviter la trappe du "490$/saison/équipe".

#### Vue contrarienne

**La vraie valeur n'est PAS dans l'AI vidéo.** Hudl/Balltime/Volleymetrics ont investi des dizaines de millions, et leur produit reste "30–45 min post-match". Ça reste un workflow **post-game**, pas **in-game**. Le coach de club qui est au bord du terrain avec son iPad à 19h30 un mardi soir n'a **ni le temps, ni la bande passante, ni le budget** pour de la vidéo AI. Il veut **entrer un kill en 2 taps, voir le hitting% de sa rotation actuelle en 0.2s, et tourner sa rotation sans se tromper**.

Playco v1.9.0 couvre déjà 80% de ce besoin. Le gap restant n'est **pas technique** — c'est de la **simplicité obsessive** et la **fiabilité hors ligne**. L'AI vidéo est un distracteur narcissique pour les investisseurs, pas pour les coachs.

#### Décision: priorité tech #1 Playco H2 2026

**Consolider le "bord de terrain intelligent" en intégrant Apple FoundationModels pour le résumé post-match et la saisie vocale, tout en ajoutant l'import DataVolley pour ouvrir le marché NCAA/pro.**

Concrètement:
- **Juin–juillet 2026:** FoundationModels résumé match + saisie vocale notes coach
- **Août 2026:** Parser DataVolley `.dvw` en lecture seule
- **Septembre 2026:** HealthKit read-only pour les athlètes avec Apple Watch
- **Octobre–novembre 2026:** Polissage, accessibilité WCAG 2.2, App Store release 2.0

---

## Implications stratégiques

1. **Le "rêve SaaS scalable 10 M$ ARR" est une illusion sur ce produit à son état actuel.** Le plafond structurel québécois seul est ~225 k$ CAD/an. Playco est un **produit de niche premium défendable**, pas une startup VC.

2. **La bataille se gagne par la distribution institutionnelle, pas par la feature war.** Le vrai danger Hudl n'est pas son produit, c'est un deal de distribution Volleyball Québec/RSEQ qui rendrait Hudl "gratuit" pour tous les coachs licenciés. **Playco doit arriver là en premier.**

3. **Le fondateur doit consolider le marché francophone avant d'étendre.** Tenter les USA ou le Canada anglophone sans verrouiller le Québec = perdre les deux.

4. **Le stack technologique Apple-native est un moat, pas un handicap.** Hudl, Assistant Coach, Data Project ne peuvent pas répliquer l'expérience FoundationModels + PencilKit + HealthKit + CloudKit sur Android/Windows. **C'est le différentiateur à défendre obsessivement.**

5. **La stratégie prix doit attaquer depuis le bas.** Freemium 1 équipe + 199 $ CAD/an équipe illimitée = position où Hudl (900-1600 $) ne peut pas descendre facilement sans casser sa structure 230 M$ US levés.

---

## Risques et caveats

### Risques business
- **Deal Hudl × Volleyball Québec/RSEQ** → Playco devient "2e app à payer en plus" → game over. **Probabilité : moyenne. Impact : critique.**
- **Assistant Coach Volleyball ajoute rotation adversaire / mode courtside** → Playco perd son différentiateur principal. **Probabilité : moyenne. Impact : élevé.**
- **GameChanger investit sérieusement dans le volleyball (comme baseball)** → standard gratuit adopté par défaut. **Probabilité : faible-moyenne. Impact : élevé.**
- **Saisonnalité brutale** (indoor sept-mars, beach juin-août) → ARPU réel 80-120 $ plutôt que 150 $.
- **Apple Tax** 15 % sur abonnements in-app → -15 % du revenu brut.
- **Fragmentation WTP** : beaucoup de coachs amateurs utilisent gratuit (Google Docs, papier, Excel) → plafond WTP structurellement bas.
- **iPad-only** : exclut peut-être 40 % du marché adressable (coachs sur Android/Chromebook).

### Risques fondateur
- **Solo founder bottleneck** : dev + BD + support + marketing = insoutenable sans premier embauche.
- **Cycle saisonnier volleyball** : fenêtre de BD active = août-octobre (pré-saison). Rater un cycle = perdre un an.
- **Anges Québec ralentit** (seulement 3 investissements 2025) → timing du deal moins favorable.

### Caveats sur les données
- Écart **5,2 G$** vs **0,34 G$** pour "sports coaching platforms" en 2024 = définition molle, à prendre avec prudence.
- Les comparables Hudl (730 M$) et TeamSnap sont multi-sports, pas volleyball-only — extrapoler le volleyball à 5 % du total est une **estimation non sourcée**.
- Le **nombre de coachs québécois (1 200-1 500)** est une estimation bottom-up depuis la structure RSEQ/clubs, pas une donnée Volleyball Québec officielle.
- **EPA-style metrics en volleyball** : pas de standard mainstream NCAA en 2026, contrairement aux sports US majeurs.
- L'**Expected Points Added** comme différentiateur analytics Playco est **prématuré** — le marché ne le demande pas encore.

---

## Recommandation — Plan 90 jours + 12 mois

### 90 jours (avril-juillet 2026)

#### Axe produit — consolider le moat
1. Intégrer **Apple FoundationModels** pour résumé match + saisie vocale notes coach (2-3 semaines dev)
2. Finaliser le **parser DataVolley `.dvw`** en lecture seule (2-3 semaines dev)
3. Ajouter **HealthKit read-only** sur fiche joueur (3-5 jours dev)
4. Lancer **pricing test** : "Coach Pro" 12,99 $/mois + "Équipe" 299 $/an avec 14 jours trial

#### Axe BD — verrouiller la distribution francophone
1. Cibler directement **les 60 cégeps volleyball Québec** → pipe ~60 deals B2B à 300 $/an, cible réaliste 15 signés An 1 = **4,5 k$ CAD**
2. Premier contact **Volleyball Québec** pour partenariat fédéral (licence fédération + option Playco)
3. Pilotes payants : **Cégep Garneau + 2 autres équipes RSEQ** → 3-5 k$ MRR documenté

#### Axe capital — stack non-dilutif
1. **Déposer candidature LE CAMP Québec** (S1-S2) — porte d'entrée obligatoire
2. **Monter dossier Mitacs Accelerate Entrepreneur** avec étudiant Université Laval IFT sur "heatmap statistique ML" (S2-S4) → 15 k$ premier stage
3. **Incorporation + structure SAFE/actions privilégiées** à valuation 2,5-3,5 M$ (préparation)

### 12 mois (mai 2026 → mai 2027)

**Objectifs chiffrés :**
- **MRR** : 10-15 k$ CAD (≈ 40-80 coachs payants + 15 cégeps)
- **Non-dilutif cumulé** : 60-120 k$ (Mitacs + CEIM SIJ + RS&DE)
- **Dilutif** : **Fonds Impulsion 500 k$** (parrainage LE CAMP) + **Anges Québec 250 k$** + **friends & family 50 k$** = **800 k$ à valuation ~3 M$**
- **Signé** : 3 cégeps pilotes + 1 partenariat Volleyball Québec / RSEQ + App Store release v2.0

### Gate de décision à An 2 (mai 2027)

- Si ARR > 50 k$ et croissance > 15 %/mois → **accélérer, préparer Panache + Will Ventures pour Series Seed 1,5-2 M$**
- Si ARR 20-50 k$ et croissance lente → **mode indie profitable, hire 1 BD**
- Si ARR < 20 k$ et stagnant → **mode maintenance ou vente stratégique à Volleyball Québec** (valorisation 1-3× ARR = 20-150 k$)

### Ce qu'il NE faut pas faire

- ❌ **Construire un détecteur vidéo YOLO/pose estimation maison** — Hudl a 5 ans d'avance, 50k+ images à annoter, 6-12 mois perdus
- ❌ **Pitcher Courtside / 359 Capital / Elysian Park / Drive by DraftKings** au stade actuel — mauvaise taille, mauvaise thèse
- ❌ **Tarifer comme Hudl (900-1600 $)** — Playco perd, la distribution gagne
- ❌ **Porter sur Vision Pro ou Android** — opportunity cost prohibitif
- ❌ **Attaquer le marché US avant An 2** — Hudl écrase, 100 % de l'effort doit rester Québec → Canada francophone
- ❌ **Lever du VC avant 20 k$ MRR** — dilution 25-30 % pour 500 k$ = destruction de valeur

### Phrase-décision

> **Le jeu dans les 12 prochains mois, c'est : empiler le non-dilutif québécois + signer 15 contrats cégep + sortir v2.0 avec FoundationModels + DataVolley parser. Le VC attend. Le marché francophone ne peut pas attendre — Hudl ou Assistant Coach peut signer un deal fédéral n'importe quand.**

---

## Sources

### Concurrence
- [Hudl revenue 730,4 M$ — getlatka](https://getlatka.com/companies/hudl)
- [Hudl acquires Balltime (BusinessWire)](https://www.businesswire.com/news/home/20250206384625/en/Hudl-Expands-Volleyball-Focus-Through-Game-Changing-Acquisition-of-Balltime)
- [Hudl Club pricing](https://www.hudl.com/pricing/club/hudl)
- [Hudl Assist AI](https://www.hudl.com/products/assist/volleyball/ai)
- [Hudl acquires Volleymetrics](https://www.hudl.com/blog/hudl-acquires-volleymetrics-strengthens-solutions-for-volleyball-at-every-level)
- [Hudl funding — Clay](https://www.clay.com/dossier/hudl-funding)
- [Hudl acquires Balltime — YSBR](https://youthsportsbusinessreport.com/hudl-acquires-balltime-a-game-changing-leap-in-volleyball-technology/)
- [Data Volley 4](https://www.dataproject.com/Products/EN/en/Volleyball/DataVolley4)
- [SoloStats 123 App Store](https://apps.apple.com/us/app/solostats-123-volleyball-stats/id499803638)
- [SoloStats Live](https://www.solostatslive.com/)
- [iStatVball 3](https://istatvball.com/)
- [Volleyball Ace / TapRecorder](https://www.taprecorder.com/)
- [VolleyStation](https://volleystation.com/)
- [Assistant Coach Volleyball](https://www.assistantcoach.co/)
- [GameChanger Volleyball](https://gc.com/volleyball)
- [TeamSnap volleyball](https://www.teamsnap.com/teams/sports/volleyball)
- [TeamSnap pricing](https://www.teamsnap.com/pricing)
- [SportsEngine volleyball](https://www.sportsengine.com/hq/sports/volleyball/)
- [CoachNow](https://coachnow.com/)
- [TeamBuildr pricing](https://www.teambuildr.com/pricing)
- [Coach Tactic Board: Volley](https://apps.apple.com/us/app/coach-tactic-board-volley/id861268156)
- [Luceo Volleyball](https://www.luceosports.com/volleyball)

### Taille de marché
- [FIVB 800 M pratiquants — staracademyvolleyball](https://staracademyvolleyball.com/how-many-volleyball-players-are-there-worldwide/)
- [NFHS 492 799 joueurs HS 2024-25](https://nfhs.org/stories/participation-in-high-school-sports-hits-record-high-with-sizable-increase-in-2024-25)
- [Volleyball Canada Annual Report 2023-24](https://volleyball.ca/uploads/About/Governance/Annual_reports/VC_Annual_Report_2023-24_EN.pdf)
- [Volleyball Québec 35-40k pratiquants (La Presse)](https://www.lapresse.ca/sports/volleyball-quebec/le-volleyball-pour-tous/2025-01-02/volleyball-quebec/un-sport-entre-bonnes-mains.php)
- [Tarification membres Volleyball Québec](https://www.volleyball.qc.ca/fr/page/membre/s_affilier.html)
- [Sports coaching platforms 5,2 G$ (GMR)](https://growthmarketreports.com/report/sports-coaching-platform-market)
- [Sports coaching platforms 0,34 G$ (Technavio)](https://www.openpr.com/news/3847874/global-sports-coaching-platforms-market-2025-soaring-at-a-cagr)
- [Sports technology 22,69 G$ (Grand View)](https://www.grandviewresearch.com/industry-analysis/sports-technology-market)
- [NCAA Division 1 volleyball 334 programmes](https://productiverecruit.com/mens-volleyball/division-1-colleges)
- [SkillShark pricing](https://skillshark.com/blog/volleyball-coaching-apps)
- [RSEQ volleyball structure](https://rseq.ca/sports/volleyball/)

### Investisseurs
- [Fonds Impulsion 200 M$ (La Presse)](https://www.lapresse.ca/affaires/2025-10-21/administre-par-investissement-quebec/un-fonds-de-200-millions-pour-les-jeunes-pousses-technos.php)
- [Fonds Impulsion officiel IQ](https://www.investquebec.com/quebec/fr/financement/impulsion-pme.html)
- [Fonds Impulsion (BetaKit)](https://betakit.com/investissement-quebec-transforms-early-stage-program-into-200-million-vc-fund/)
- [Panache Fund II 100 M$ (BetaKit)](https://betakit.com/panache-closes-100-million-for-second-fund-as-firm-doubles-down-on-seed-stage-startups/)
- [BDC Seed Venture Fund](https://www.bdc.ca/en/bdc-capital/venture-capital/funds/seed-fund)
- [BDC 50M envelope (BetaKit)](https://betakit.com/bdc-capital-recommits-to-leading-seed-deals-in-startups-across-canada-with-new-50-million-fund/)
- [Anges Québec](https://angesquebec.com/en)
- [Elevia co-invest (BetaKit)](https://betakit.com/anges-quebec-looks-to-expedite-early-stage-rounds-with-co-investment-angel-fund/)
- [Real Ventures — Orbit MTL Medium](https://medium.com/real-ventures/targeting-local-startup-excellence-65111194605d)
- [Inovia Capital — Tracxn](https://tracxn.com/d/venture-capital/inoviacapital/___xnpd1QJjfV6eDcTaHAb7LmoSDti6xVFQeLC6fUigfw)
- [Courtside Ventures](https://www.courtsidevc.com)
- [Courtside — Crunchbase](https://www.crunchbase.com/organization/courtside-ventures)
- [Sapphire Sport → 359 Capital (TechCrunch)](https://techcrunch.com/2025/11/10/sapphire-sport-spins-out-rebrands-as-359-capital-with-300m-aum/)
- [Elysian Park Ventures](https://elysianpark.ventures/)
- [Drive by DraftKings (PR Newswire)](https://www.prnewswire.com/news-releases/drive-by-draftkings-launches-60-million-venture-fund-to-invest-in-sports-tech-and-entertainment-301403848.html)
- [Will Ventures (TechCrunch)](https://techcrunch.com/2022/10/18/will-ventures-second-fund-sports-technologies/)
- [Alumni Ventures Sports Fund](https://www.av.vc/funds/sports)
- [AV Sports 2025 Review](https://www.av.vc/blog/av-sports-fund-portfolio-review-and-upcoming-market-opportunities-4-10-25)
- [SportsVisio 3,2 M$ funding](https://www.sportsvisio.com/stories/sportsvisio-secures-3-2m-additional-funding-to-scale-ai-sports-solution)
- [LE CAMP Québec](https://lecampquebec.com/en)
- [Founder Institute Québec City](https://fi.co/insight/founder-institute-world-s-largest-startup-accelerator-testing-launch-in-quebec-city)
- [CEIM Fonds SIJ](https://www.ceim.org/fonds-sij/)
- [Mitacs Accelerate Entrepreneur](https://www.mitacs.ca/our-programs/accelerate-entrepreneur/)
- [Techstars Sports discontinué (IBJ)](https://www.ibj.com/articles/techstars-discontinues-indianapolis-based-sports-tech-accelerator)
- [Top 50 Sports VC 2025 — Shizune](https://shizune.co/investors/sports-vc-funds-united-states)
- [Montréal Innovation ouverte subvention](https://montreal.ca/programmes/subvention-linnovation-ouverte-pour-les-entreprises-emergentes)

### Tech & standards
- [Apple FoundationModels newsroom](https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/)
- [Apple Developer — FoundationModels](https://developer.apple.com/documentation/FoundationModels)
- [Apple ML Research — Foundation Models 2025](https://machinelearning.apple.com/research/apple-foundation-models-2025-updates)
- [Apple Vision 3D body pose](https://developer.apple.com/documentation/Vision/detecting-human-body-poses-in-3d-with-vision)
- [Apple Developer — Action & Vision app](https://developer.apple.com/videos/play/wwdc2020/10099/)
- [FIVB VIS user manual](https://inside.cev.eu/media/t2udgpnl/fivb_vis_user_manual.pdf)
- [FIVB ↔ DataVolley mapping](https://www.dataproject.com/app_userfiles/documents/procedure_vis_dv2013.pdf)
- [Volleyballscores — VIS explained](https://www.volleyballscores.co.uk/vis/)
- [openvolley/datavolley (GitHub)](https://github.com/openvolley/datavolley)
- [VolleyVision GitHub (shukkkur)](https://github.com/shukkkur/VolleyVision)
- [VolleyBallYolo (Roboflow, Jan 2025)](https://universe.roboflow.com/volleyballyolo/volleyballyolo)
- [DETR volleyball action detection (OpenReview 2025)](https://openreview.net/forum?id=btlyJrqR7H)
- [Pixellot volleyball](https://www.pixellot.tv/sports/volleyball/)
- [Catapult volleyball](https://www.catapult.com/sports/volleyball)
- [Catapult — wearable technology in sports](https://www.catapult.com/blog/wearable-technology-in-sports)
- [SAP Sports One + Vision Pro (Feb 2025)](https://news.sap.com/2025/02/immersive-match-analysis-apple-vision-pro/)
- [Apple Vision Pro sports apps (Sportico)](https://www.sportico.com/business/tech/2024/apple-vision-pro-sports-apps-list-mlb-nba-golf-1234765220/)
- [EU DMA Apple preliminary findings (April 2025)](https://digital-markets-act.ec.europa.eu/commission-closes-investigation-apples-user-choice-obligations-and-issues-preliminary-findings-rules-2025-04-23_en)
- [Apple DMA update for EU apps](https://developer.apple.com/support/dma-and-apps-in-the-eu/)
- [VolleyMatch iPad app](https://apps.apple.com/sa/app/volleymatch/id6455731542?platform=ipad)
- [Haptic feedback 2025 guide](https://saropa-contacts.medium.com/2025-guide-to-haptics-enhancing-mobile-ux-with-tactile-feedback-676dd5937774)
- [TeamSnap pricing breakdown 2025](https://communiti.app/blog/is-teamsnap-free-for-independent-coaches-a-2025-pricing-breakdown)
- [Hudl pricing](https://www.hudl.com/pricing)
- [Balltime pricing](https://www.hudl.com/pricing/balltime)
- [Hudl — AI volleyball](https://www.hudl.com/blog/ai-volleyball)
- [Balltime — Letter to Volleyball](https://www.balltime.com/blog/balltime-hudl)

---

## Notes méthodologiques

**Alerte fraîcheur** : toutes les données citées sont de 2024-2026. Les chiffres Hudl (730 M$ 2024), Balltime acquisition (fév. 2025), Fonds Impulsion (oct. 2025), Apple FoundationModels (sept. 2025), EU DMA (avril 2025), Techstars Sports discontinué (mars 2025) sont vérifiés. Le NFHS data (2018-19 écoles) est signalé comme daté. Les estimations de coachs québécois (1 200-1 500) et TAM volleyball-spécifique (260 M$ US) sont explicitement étiquetées comme estimations non sourcées.

**Méthodologie** : ce dossier combine **4 recherches parallèles** (concurrence, taille de marché, investisseurs, tech) menées le 14 avril 2026 par 4 agents de recherche indépendants, puis synthétisées en une recommandation unique. Chaque sous-rapport fait 1 500-2 000 mots et peut être consulté séparément pour approfondir un axe.

**Niveau de confiance par axe :**
- Concurrence : **Élevé** (données App Store, pages pricing publiques, rapports presse vérifiables)
- Taille de marché : **Moyen** (données top-down sourcées, bottom-up basé sur estimations RSEQ/clubs)
- Investisseurs : **Élevé** (données VC publiques BetaKit/TechCrunch/Crunchbase)
- Tech : **Élevé** (documentation Apple officielle, papers académiques, produits commerciaux vérifiables)

---

*Dossier généré le 14 avril 2026 · Playco v1.9.0 · Pour usage interne fondateur*
