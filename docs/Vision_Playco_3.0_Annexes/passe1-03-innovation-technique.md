# Lentille Innovation Technique — Playco v.next
**Architecte iOS, horizon WWDC 2025–2026 · juillet 2026**

---

## 0. Le filtre du gymnase (principes de tri)

Chaque innovation ci-dessous est passée au travers de quatre filtres non négociables, dans cet ordre :

1. **Le test du gymnase sans wifi.** Playco est exceptionnel offline — c'est un avantage concurrentiel structurel (Hudl, Balltime et SoloStats sont dégradés ou morts sans réseau). Toute techno qui exige une connexion pendant un match est disqualifiée du chemin critique. Elle peut exister comme *couche de diffusion*, jamais comme *couche de saisie*.
2. **Le test des mains occupées.** Un coach en match tient un crayon, gère 12 athlètes et conteste un ballon touché. Une innovation qui ajoute un tap est suspecte ; une qui en retire un est précieuse.
3. **Le test du dev solo.** Chaque item est chiffré en semaines-développeur (avec Claude Code comme accélérateur). Un item « 6 mois de R&D vision par ordinateur » est un non, peu importe le wow.
4. **Le test de la donnée existante.** Playco a déjà un actif rare : un flux d'événements horodatés (`PointMatch.horodatage`, rotation, zone, contexte de service) + un terrain vectoriel multi-étapes (`EtapeExercice` avec positions normalisées 0-1 et trajectoires Bézier). **Les meilleures innovations de ce document ne créent pas de nouvelles données : elles exploitent celles qui dorment déjà dans SwiftData.**

Verdicts : **RETENIR** (dans la roadmap), **EXPLORER** (spike de validation avant engagement), **ÉCARTER** (gadget, ou ratio effort/valeur indéfendable aujourd'hui).

---

## 1. IA on-device — Apple Foundation Models

### Contexte technique (état juillet 2026)

Le framework FoundationModels (iOS 26) donne accès **gratuit, offline et privé** au modèle ~3B on-device : sortie structurée par macro `@Generable` (le modèle remplit un struct Swift typé, pas du texte à parser), tool calling (le modèle appelle du code de l'app), streaming par snapshots. Contraintes dures : **fenêtre de 4 096 tokens** (instructions + prompt + sortie — iOS 26.4 a ajouté `contextSize`/`tokenCount(for:)` pour la gérer proprement), et **disponibilité conditionnelle** (Apple Intelligence activée, appareil M1+/A17 Pro+, langue supportée — le français l'est). WWDC 2026 a ajouté : **entrée multimodale image** sur le modèle on-device, protocole **`LanguageModel` ouvert** (brancher Claude/Gemini/un modèle hébergé sans changer le code de session), et FoundationModels sur **watchOS 27** via Private Cloud Compute.

**Règle d'architecture Playco** : la couche IA est une *décoration* au-dessus de `MetriquesVolley`/`AgregateurStatsMatch`, jamais une source de vérité. Le modèle **narrre des chiffres calculés de façon déterministe**, il ne calcule jamais. Toute surface IA a un fallback non-IA (les stats brutes) quand `SystemLanguageModel.default.availability != .available`. Le protocole `LanguageModel` de WWDC26 est un cadeau stratégique : on code contre FoundationModels aujourd'hui, et le tier Club/Fédération pourra plus tard router vers un modèle cloud plus puissant **sans réécrire une ligne de la logique de session** — l'abstraction est fournie par Apple.

### 1.1 Résumé narratif de match auto-généré — **RETENIR** ⭐

Le cas d'usage parfait pour le modèle 4k tokens. On ne lui donne PAS les 180 `PointMatch` bruts : on lui donne le condensé déjà calculé (score par set, runs, sideout % par rotation, top performeurs, moments clés extraits du fil du match) — ~800 tokens d'entrée. Sortie `@Generable` : `struct ResumeMatch { var titre: String; var recit: String; var troisClés: [String]; var joueursEnEvidence: [MentionJoueur] }`. Streaming par snapshots → le résumé « s'écrit » sous les yeux du coach dans les 5 secondes post-match, offline, dans l'autobus au retour de Trois-Rivières.

- **Pourquoi game-changer** : c'est le rapport que le coach n'écrit jamais faute de temps. Injecté dans la messagerie d'équipe + dans le PDF d'export existant (`PDFExportService`), il transforme la saisie live (déjà faite) en communication (jamais faite).
- **Risque contrôlé** : hallucination quasi nulle si le prompt interdit tout chiffre non fourni ; le PDF garde le box score factuel à côté.
- **Effort** : 1–2 semaines. **Impact** : élevé.

### 1.2 Rapports parents / direction / athlète — **RETENIR**

Même moteur, autre gabarit : rapport de progression individuel (objectifs `ObjectifJoueur` + évolution + comparaison par poste → texte poli en français, ton configurable « parent » vs « direction sportive »). Au Québec (cégeps, RSEQ), le coach DOIT rendre des comptes — c'est une corvée mensuelle réelle. **Effort** : 1 semaine une fois 1.1 livré (mutualisation du pipeline). **Impact** : élevé, différenciateur B2B pour le tier Club.

### 1.3 Plan de séance suggéré depuis les faiblesses — **RETENIR** (v1 contrainte)

Le piège serait l'IA générative qui « invente » des exercices (slop). La bonne version : **tool calling sur la bibliothèque existante**. Détection déterministe des faiblesses (`MetriquesVolley` : note de réception < 1.8, sideout R4 < 45 %…) → le modèle appelle `rechercherExercices(categorie:duree:)` sur `ExerciceBibliotheque` → il assemble une séance de 90 min **exclusivement à partir des exercices du coach**, avec justification (« R4 fuit en réception : 25 min de réception en formation R4 »). Le coach édite ensuite normalement. L'IA choisit dans TA bibliothèque — c'est vendable, honnête et défendable. **Effort** : 2–3 semaines. **Impact** : élevé (c'est LA promesse « assistant-coach »).

### 1.4 Scouting auto depuis l'historique adversaire — **EXPLORER**

Verdict nuancé : la partie *analytique* est déterministe et existe à 80 % (zones des actions marquantes adverses, tendances zonales 0-3 déjà dans `ScoutingReport`). Une agrégation multi-matchs par `adversaire` (les `PointMatch` adverses sont déjà stockés) + une couche narrative FM = plan de match pré-rempli. **Mais** : la réalité terrain est qu'un coach affronte le même adversaire 1 à 3 fois/saison — l'échantillon est mince, et un plan « intelligent » sur 40 points de données est dangereux. Spike : pré-remplir le `ScoutingReport` avec les agrégats + bandeau « basé sur N matchs » ; la narration FM seulement si N ≥ 2. **Effort spike** : 1 semaine.

### 1.5 Assistant conversationnel (« pourquoi on perd la rotation 4 ? ») — **EXPLORER** (horizon 12-18 mois)

Brutal : la réponse honnête à cette question est **déjà à l'écran** dans `StatsParRotationView`. Un chatbot qui paraphrase l'UI est un gadget. La version qui vaut quelque chose : tool calling sur ~8 outils (`statsRotation(n:)`, `statsJoueur(id:)`, `tendanceSaison(metrique:)`, `comparerMatchs(a:b:)`) pour les questions *transversales* que l'UI ne pré-calcule pas (« mes réceptions se dégradent-elles en fin de set ? »). Risques réels : 4k tokens = pas de vraie conversation longue ; une réponse fausse détruit la confiance dans TOUTES les stats de l'app. À faire seulement quand 1.1–1.3 auront prouvé le pipeline, potentiellement routé vers un modèle cloud via le protocole `LanguageModel` pour le tier Club. **Effort** : 4-6 semaines. **Impact** : moyen (wow marketing > usage quotidien).

### 1.6 (Bonus WWDC26) Numérisation de feuille de match papier — **EXPLORER**

L'entrée multimodale image du modèle on-device (iOS 27) + `@Generable` = photographier une feuille de stats papier ou un box score adverse PDF → struct typé → import dans `StatsMatch`. Cas réel : les fédérations et les adversaires vivent encore sur papier. Spike 1 semaine quand iOS 27 sera stable ; fallback Vision/OCR (`VNRecognizeTextRequest`) si la qualité déçoit.

---

## 2. Vision & vidéo

### 2.1 Capture vidéo synchronisée aux stats — **RETENIR** ⭐⭐ (l'innovation n°1 du document)

**L'actif est déjà dans le schéma** : chaque `PointMatch` porte `horodatage: Date`. Il suffit d'enregistrer la vidéo (AVFoundation, iPad sur trépied ou 2e appareil) en stockant l'instant de début d'enregistrement → chaque point devient un chapitre vidéo par simple soustraction. Clip d'un point = `[horodatage − 8 s, horodatage + 3 s]`. **Zéro ML, zéro serveur, zéro travail supplémentaire pour le coach : la saisie de stats EST le tagging.** C'est exactement ce que Volleymetrics/Hudl facturent des milliers de dollars par saison, ici gratuit et offline.

Ce que ça débloque (tout en local, AVPlayer + liste de time-offsets) :
- « Tous les kills de #12 » / « toutes nos erreurs de réception en R4 » = playlists instantanées croisant les filtres stats existants.
- Revue vidéo au vestiaire entre deux sets (les 5 derniers points en 40 secondes).
- Export d'un clip pour un athlète via ShareLink (recrutement, correction technique).

**Stockage — la décision qui tue ou sauve la feature** : un match 1080p HEVC ≈ 4–6 Go. Règles : (1) la vidéo reste **locale** (Documents ou Photothèque), **jamais dans CloudKit** (le quota iCloud de l'utilisateur exploserait et la sync s'écroulerait) ; (2) SwiftData ne stocke qu'un index léger (URL locale + offset de départ) ; (3) proposer 720p par défaut + purge assistée en fin de saison. Le partage inter-appareils passe par export de clips, pas par sync du match complet.

**Effort** : 4–6 semaines (v1 mono-appareil : caméra de l'iPad de saisie ou fichier importé recalé manuellement sur le 1er point). **Impact** : transformationnel — c'est la feature qui fait passer Playco de « app de stats » à « plateforme de développement d'équipe » et qui justifie seule le tier Pro.

### 2.2 Tag vidéo manuel léger vs auto complet — **RETENIR le manuel-assisté, ÉCARTER l'auto**

Le débat est résolu par 2.1 : le tag « manuel » est un sous-produit gratuit de la saisie. Y ajouter un bouton « marqueur » libre (moment à revoir, sans stat) coûte 2 jours. Le tagging automatique complet (détection de rallye par ML) n'apporte que la suppression du recalage initial — ratio effort/gain absurde pour un dev solo.

### 2.3 Analyse de pose (technique de service/attaque) — **ÉCARTER** (revisiter H3)

`VNDetectHumanBodyPose3D` rend la démo facile ; l'outil utile est très loin derrière. Il faut un angle caméra contrôlé, un athlète isolé, des référentiels biomécaniques par geste, et une interprétation qui engage la responsabilité du coach. En match c'est inutilisable (occlusions, 12 corps) ; en atelier individuel c'est un AUTRE produit (marché du développement individuel, pas du coaching d'équipe). C'est le prototype qui impressionne à TestFlight et que personne n'ouvre en novembre. À revisiter uniquement comme « mode atelier » beach/service en H3, si les coachs le réclament.

### 2.4 Auto-tracking ballon / score — **ÉCARTER** (franchement)

Suivi d'un ballon de volleyball rapide, petit, occlus, depuis une tribune, sur device : c'est un problème de niveau recherche sur lequel des entreprises financées (Balltime, PlaySight) brûlent des millions avec des résultats moyens. OCR du panneau de score : fragile, dépend de chaque gymnase. Aucun des deux ne passe le filtre du dev solo. La saisie humaine assistée (pavé courtside existant + duo coach/assistant, cf. 3.2) est plus fiable que n'importe quel auto-tracking accessible.

---

## 3. Live & temps réel

### 3.1 Live Activities + Dynamic Island (score live) — **RETENIR** (en deux temps)

- **Temps 1 — locale, au lancement** : Live Activity sur l'appareil de saisie (et l'écran verrouillé du coach) : score, set, rotation « R1 · R3 », série en cours. Effort : ~1 semaine (ActivityKit, mise à jour depuis `MatchLiveViewModel`). Valeur : le coach qui verrouille son iPhone garde le match ; polish perçu énorme.
- **Temps 2 — diffusée aux parents/athlètes (6 mois)** : les Live Activities distantes exigent des pushs APNs. La bonne techno est le **broadcast push par canal** (iOS 18+) : un canal par match, tous les abonnés reçoivent la même mise à jour — pas de gestion de tokens individuels, coût APNs nul, il ne faut qu'un micro-endpoint qui relaie le score (cf. §6, le même backend sert les deux). Le scénario « le parent suit le tournoi depuis le travail » est un moteur d'adoption virale : chaque parent qui installe l'app pour suivre est un utilisateur acquis gratuitement.

**Attention** : la diffusion suppose que l'appareil de saisie a du réseau. Dégradation propre : sans réseau, la LA locale vit, la diffusion reprend au retour du réseau. Jamais l'inverse.

### 3.2 Saisie multi-appareils simultanée (assistant saisit, coach regarde) — **RETENIR** ⭐ (6 mois)

Le choix de techno est dicté par le filtre n°1 : **le gymnase n'a pas de wifi**. Donc ni CloudKit push (latence minutes, exige réseau), ni WebSocket backend (exige réseau), ni SharePlay/GroupActivities (conçu pour FaceTime, fragile hors appel). La bonne réponse : **pair-à-pair local via Network.framework (Bonjour/AWDL)** — iPad coach ↔ iPhone assistant, sans aucune infrastructure, à 15 m de distance.

Et ici l'architecture existante de Playco est une chance inespérée : le match live est un **journal append-only d'événements** (`PointMatch`, substitutions, TM). Un log append-only horodaté se fusionne trivialement (union + tri par horodatage) — pas besoin de CRDT généraux ni de résolution de conflits complexe. Un appareil est « greffier » (autorité sur le score), l'autre pousse des événements ; l'undo devient un événement d'annulation. Le mode lecture seule (`StaffPermissions.peutGererStats`) existe déjà pour borner les rôles.

**Effort** : 4–5 semaines (protocole d'événements + appairage QR + réconciliation). **Impact** : élevé — c'est le mode de travail réel d'un staff (l'assistant statisticien saisit, le coach coache avec le dashboard), et aucun concurrent grand public ne le fait bien offline.

### 3.3 watchOS — **ÉCARTER au lancement, EXPLORER un seul cas en H3**

Brutal : le coach a un iPad dans les mains ; présences, chrono et « stats rapides au poignet » sont des solutions en quête de problème (saisir un kill sur un écran de 45 mm en suivant un rallye : non). Le SEUL cas qui passe le filtre : **compagnon athlète pour la section Entraînement** — la séance muscu au poignet (série suivante, charge, chrono de repos, cochage) pendant que le téléphone reste dans le sac. C'est cohérent avec l'axe B2C athlète, et watchOS 27 + FoundationModels via PCC pourrait même y résumer la séance. À n'ouvrir que quand la base athlète le justifiera.

---

## 4. Intégration système

### 4.1 App Intents / Siri — **RETENIR la fondation, ÉCARTER le vocal courtside**

« Siri, démarre le match contre Garneau » est du marketing : personne ne parle à Siri dans un gymnase à 85 dB. Mais **App Intents est la fondation invisible de tout le reste** : Raccourcis, widgets interactifs, Spotlight, et surtout l'exposition de l'app à Apple Intelligence (qui prend de l'ampleur chaque année). Intents à livrer : `DemarrerMatchIntent`, `ProchainEvenementIntent`, `MarquerPresencesIntent`, `OuvrirSeanceDuJourIntent`. Effort : 1–2 semaines, ROI durable.

### 4.2 Widgets interactifs — **RETENIR (ciblé)**

Un seul widget vaut de l'or : **« Prochain événement »** (match/pratique, heure, lieu, tap → séance) sur l'écran d'accueil du coach ET de l'athlète — le calendrier unifié existe déjà. Widget présences interactif : EXPLORER (mignon, mais la prise de présences se fait devant le groupe, dans l'app). Tout le reste (stats du dernier match en widget) : gadget.

### 4.3 Spotlight — **RETENIR**

Indexer bibliothèque d'exercices, séances, joueurs et scouting reports via `CSSearchableItem` (la recherche globale interne existe déjà — c'est une projection de plus). « float serve » dans Spotlight → l'exercice s'ouvre. 3–4 jours, polish disproportionné.

### 4.4 State Restoration — **RETENIR (non négociable avant lancement)**

Un coach dont l'iPad tue l'app en plein 3e set et qui ne retombe PAS sur `MatchLiveSplitView` désinstalle. Les données sont déjà sauves (SwiftData au fil de l'eau) ; il manque la restauration de *navigation* (`@SceneStorage` sur la section + réouverture automatique du match « en cours »). 2–3 jours. C'est de la confiance, pas de l'innovation — raison de plus.

---

## 5. Terrain & spatial

### 5.1 Animation des systèmes de jeu (lecture des déplacements) — **RETENIR** ⭐⭐

Deuxième plus gros ROI du document, et le modèle de données est **déjà prêt** : `EtapeExercice` stocke par étape des `ElementTerrain` avec positions normalisées 0-1, identifiés par `id` stable, avec trajectoires Bézier. Animer = interpoler la position de chaque élément entre l'étape N et N+1 (matching par `id`), faire voyager le ballon le long de ses courbes Bézier, avec `keyframeAnimator`/`TimelineView` sur le Canvas existant. Bouton « ▶︎ Lecture » + scrubber + vitesse 0.5×/1×.

- **Pourquoi game-changer** : un diagramme statique explique une position ; une animation explique un *mouvement* — c'est toute la différence pédagogique pour montrer une transition défense→attaque ou une couverture en R4 à des athlètes de 17 ans. Les exercices multi-étapes, formations et stratégies existants deviennent tous animables rétroactivement, sans ressaisie.
- **Effort** : 2–3 semaines. **Impact** : très élevé, différenciateur visuel immédiat (démos App Store, TikTok de coachs).

### 5.2 Évolution PencilKit — **RETENIR (2 raffinements), EXPLORER (1)**

RETENIR : (a) **reconnaissance de formes vectorielles** — un trait ~droit dessiné au Pencil se « snappe » en `ElementTerrain.fleche`, un arc en `trajectoire` (RDP + heuristiques simples, pas de ML) : le dessin libre devient éditable/animable ; (b) **gomme par griffonnage et hover Apple Pencil** (aperçu de l'outil, pointeur laser en présentation). EXPLORER : calques nommés par étape. Le reste de l'éditeur (hybride PencilKit + overlay vectoriel) est architecturalement juste — ne pas y toucher.

### 5.3 visionOS — tactique 3D — **ÉCARTER (sans état d'âme)**

Aucun coach de cégep québécois ne possède un Vision Pro, et aucun n'en achètera un pour du volleyball avant longtemps. La tactique volleyball se pense en 2D vue de haut (c'est le format de TOUS les tableaux de coach depuis 50 ans) ; la 3D n'ajoute que du spectacle. Coût réel : un rendu 3D du terrain + portage RealityKit = 2–3 mois pour une démo. C'est le stand WWDC, pas le gymnase. Ne revisiter que si Apple sort un casque grand public ET que le tier Fédération demande de la visualisation broadcast.

### 5.4 Mode présentation AirPlay amélioré — **RETENIR**

Le mode présentation existe ; le brancher sur 5.1 le transforme : l'iPad du coach devient télécommande (scrubber, annotations laser au Pencil en direct) pendant que la TV du vestiaire affiche l'animation plein écran (`UIScreen` externe / scène séparée, pas un simple mirroring — le coach garde ses contrôles privés). Effort : 1–2 semaines par-dessus 5.1. Le combo animation + TV vestiaire est un moment « wow » de vente en démo club.

---

## 6. Plateforme — temps réel fédération sans brûler de budget

Le besoin réel du tier Fédération : **des centaines de spectateurs qui suivent des dizaines de matchs d'un tournoi de fin de semaine**. Analysons froidement : un score de volleyball change ~1 fois/30 s ; une latence de 10–20 s est parfaitement acceptable pour un parent. Donc **pas de flotte WebSocket, pas de serveur stateful**.

**Architecture minimale (« le score est un fichier ») :**

```
iPad de saisie (source de vérité, offline-first)
   │  POST HTTPS débounché (chaque point, ou toutes les 10 s)
   ▼
Edge worker serverless (Cloudflare Workers + KV/Durable Object)
   │  ├─→ état JSON du match (~1 Ko), servi via GET + cache edge
   │  └─→ relais APNs broadcast (canal par match → Live Activities §3.1)
   ▼
Spectateurs : app (polling 15 s ou SSE) + page web publique du tournoi
```

- **Coûts** : un tournoi provincial complet tient dans le palier gratuit de Cloudflare ; à l'échelle Volleyball Québec, < 20–30 $/mois. Chaque dollar est justifiable parce que la diffusion est une feature *facturée* au tier Fédération.
- **Principes gravés dans le béton** : (1) l'appareil de saisie ne *dépend jamais* du serveur — il pousse quand il peut, point ; (2) le serveur est un miroir de fan-out en lecture, pas une base de données maîtresse ; (3) la page web spectateur est statique + JSON — pas de compte, pas de RGPD compliqué, pas de surface d'attaque.
- **Synergie** : ce même worker est l'endpoint des Live Activities broadcast (§3.1 temps 2) et le premier brique du dashboard web admin (décision fondateur n°2) — l'API read-mostly du dashboard club consomme les mêmes JSON. Un seul investissement serveur, trois features. CloudKit reste le canal de sync d'équipe (gratuit) ; le backend propre ne porte que ce que CloudKit ne sait pas faire : diffusion publique et administration web.

**Verdict : RETENIR (H3, adossé au tier Fédération payant — pas un dollar de serveur avant le premier contrat club/fédé).**

---

## 7. Matrice impact réel × effort (synthèse brutale)

| # | Innovation | Verdict | Effort (sem.) | Impact coach | Ratio |
|---|---|---|---|---|---|
| 2.1 | **Vidéo synchronisée aux stats** | RETENIR | 4–6 | Transformationnel | ⭐⭐⭐ |
| 5.1 | **Animation des systèmes de jeu** | RETENIR | 2–3 | Très élevé | ⭐⭐⭐ |
| 1.1 | Résumé narratif de match (FM) | RETENIR | 1–2 | Élevé | ⭐⭐⭐ |
| 4.4 | State Restoration match live | RETENIR | 0.5 | Confiance vitale | ⭐⭐⭐ |
| 3.1a | Live Activity locale | RETENIR | 1 | Moyen-élevé | ⭐⭐ |
| 4.1–4.3 | App Intents + widget + Spotlight | RETENIR | 2–3 | Moyen, durable | ⭐⭐ |
| 1.2 | Rapports parents/direction | RETENIR | 1 | Élevé (B2B) | ⭐⭐⭐ |
| 1.3 | Plan de séance (tool calling bibliothèque) | RETENIR | 2–3 | Élevé | ⭐⭐ |
| 3.2 | Saisie duo pair-à-pair offline | RETENIR | 4–5 | Élevé | ⭐⭐ |
| 5.4 | Présentation TV + télécommande | RETENIR | 1–2 | Élevé (démo/vente) | ⭐⭐ |
| 3.1b | Live Activities broadcast parents | RETENIR | 2 (+backend) | Élevé (viralité) | ⭐⭐ |
| 6 | Backend diffusion fédération | RETENIR (H3) | 4–6 | Élevé (B2B $) | ⭐⭐ |
| 5.2 | Snap de formes PencilKit + hover | RETENIR | 1–2 | Moyen | ⭐⭐ |
| 1.4 | Scouting auto (agrégats + narration) | EXPLORER | 1 (spike) | Moyen | ⭐ |
| 1.6 | Scan feuille de match (FM multimodal) | EXPLORER | 1 (spike) | Moyen | ⭐ |
| 1.5 | Assistant conversationnel | EXPLORER | 4–6 | Moyen (wow > usage) | ⭐ |
| 3.3 | Watch compagnon muscu athlète | EXPLORER (H3) | 3–4 | Faible-moyen | ⭐ |
| 2.3 | Analyse de pose | ÉCARTER | 8+ | Faible (niche) | ✗ |
| 2.4 | Auto-tracking ballon/score | ÉCARTER | ∞ | Illusoire | ✗ |
| 5.3 | visionOS tactique 3D | ÉCARTER | 8–12 | Nul (2026) | ✗ |
| 4.1v | Siri vocal courtside | ÉCARTER | — | Nul (gymnase bruyant) | ✗ |

---

## 8. Roadmap d'innovation en 3 horizons

### H1 — Lancement +0 à 3 mois : « exploiter la donnée qui dort »
*Thème : zéro nouvelle infrastructure, tout est on-device, tout dégrade proprement.*
1. **State Restoration** du match live (pré-requis de confiance).
2. **Animation des systèmes de jeu** + mode présentation TV télécommandé (5.1 + 5.4) — le différenciateur visible dans chaque démo.
3. **Résumé narratif de match** FoundationModels avec fallback stats brutes (1.1), injecté dans PDF + messagerie.
4. **Live Activity locale** + App Intents/widget « Prochain événement »/Spotlight (3.1a, 4.1–4.3).
5. Spike 1 semaine : recalage vidéo v0 (importer un fichier, caler sur le 1er point) pour dérisquer H2.

### H2 — +3 à 9 mois : « la vidéo et le staff »
*Thème : les deux features qui justifient le tier Pro et l'usage quotidien du staff.*
1. **Vidéo synchronisée complète** (2.1) : capture in-app, playlists par joueur/action/rotation, revue entre les sets, export de clips. Stockage local strict, purge assistée.
2. **Saisie duo coach/assistant** pair-à-pair offline (3.2) sur journal d'événements append-only.
3. **Plan de séance suggéré** par tool calling sur la bibliothèque (1.3) + **rapports parents/direction** (1.2).
4. **Live Activities broadcast** pour parents/athlètes via canal APNs + micro-worker (3.1b) — première brique serveur, uniquement si la traction le justifie.
5. Spikes : scouting agrégé multi-matchs (1.4), scan de feuille de match multimodal iOS 27 (1.6).

### H3 — +9 à 18 mois : « la plateforme »
*Thème : le B2B finance le serveur ; l'IA passe à l'échelle via le protocole `LanguageModel`.*
1. **Backend de diffusion fédération** (§6) : worker edge + page tournoi publique + API read-mostly qui amorce le dashboard web club/fédération (décision fondateur n°2). Déclencheur : premier contrat club signé.
2. **Assistant conversationnel** à outils déterministes (1.5), tier Club, routable vers un modèle cloud via le protocole `LanguageModel` WWDC26 sans refonte.
3. **Compagnon watchOS athlète** pour la musculation (3.3) si la base athlète a décollé.
4. Réévaluation froide des ÉCARTÉS : analyse de pose en « mode atelier » si demande explicite des coachs beach ; visionOS seulement si le matériel Apple a changé la donne.

### Fil rouge transversal
Chaque brique sport-spécifique de cette roadmap (métriques narrées, catégories d'actions vidéo, formations animées) passe par l'abstraction **SportDescriptor** (décision fondateur n°4) : le résumé narratif prend un glossaire par sport, les playlists vidéo prennent une taxonomie d'actions par sport, l'animateur de systèmes prend un terrain par sport. L'innovation d'aujourd'hui ne doit jamais recreuser le couplage volleyball qu'on est en train d'extraire.

---

*Sources techniques : [What's new in the Foundation Models framework — WWDC26 (Apple)](https://developer.apple.com/videos/play/wwdc2026/241/) · [WWDC26 Apple Intelligence guide (Apple Developer)](https://developer.apple.com/wwdc26/guides/apple-intelligence/) · [WWDC 2026 — Foundation Models ouvert à tout fournisseur LLM (DEV Community)](https://dev.to/arshtechpro/wwdc-2026-apple-just-opened-the-foundation-models-framework-to-any-llm-provider-5ejn) · [Apple améliore la gestion du contexte des Foundation Models — iOS 26.4 (InfoQ)](https://www.infoq.com/news/2026/03/apple-foundation-models-context/) · [Foundation Models adapter training (Apple Developer)](https://developer.apple.com/apple-intelligence/foundation-models-adapter/) · [Meet the Foundation Models framework — WWDC25 (Apple)](https://developer.apple.com/videos/play/wwdc2025/286/) · Code Playco vérifié : `Playco/Models/PointMatch.swift` (horodatage par point), `Playco/Models/ElementTerrain.swift` (positions normalisées, Bézier, `EtapeExercice`).*
