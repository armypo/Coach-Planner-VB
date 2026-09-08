# Lentille Architecture — Multi-sport & Backend hybride

**Playco v2.2 → Plateforme** · Architecte : lentille technique de la vision produit · Juillet 2026

> Périmètre : (a) transformer le sport-spécifique en *plugins de données* derrière une abstraction `SportDescriptor`, (b) ajouter un backend web/API multi-tenant pour clubs et fédérations **sans sacrifier le local-first offline ni noyer un développeur solo**. Analyse ancrée dans le code réel du repo (`Playco/Models/`, `Playco/Services/`, `Playco/Helpers/`).

---

## 1. Audit de généralisation — l'état réel du code

Bonne nouvelle structurelle : **le code est bien plus proche du data-driven qu'il n'y paraît**. Trois patterns existants sont des cadeaux pour cette refonte :

1. **Les enums sont persistés en `String` brut** (`PointMatch.typeActionRaw`, `Seance.typeSeanceRaw`, `JoueurEquipe.posteRaw`). Le format sur disque est donc *déjà* un catalogue à clés textuelles — remplacer l'enum Swift par un catalogue data-driven ne demande **aucune migration de schéma**.
2. **Le pattern JSON-blob (`Data` + computed decode)** est partout (`Seance.setsData/rotationsHistoriqueData/configMatchData`, `ScoutingReport.tendancesZonalesData`, `FormationPersonnalisee.positionsJSON`). C'est exactement un pattern « document par sport » : le contenu volleyball vit déjà dans des blobs versionnés (`schemaVersion` sur `ElementTerrain`/`EtapeExercice`), pas dans des colonnes rigides.
3. **La refonte stats v2.2 a déjà centralisé le sport-spécifique** : formules dans `Helpers/MetriquesVolley.swift`, agrégation unique dans `Services/AgregateurStatsMatch.swift`, formatage dans `FormatMetriques`, kit UI générique (`TableauStats`, `CarteMetrique`). C'est la moitié du travail d'abstraction, déjà verrouillée par 253 tests.

### 1.1 Classement des 30 @Model + structures clés

| Catégorie | Éléments | Verdict |
|---|---|---|
| **Déjà génériques** (aucun changement) | `Equipe`, `Etablissement`, `ProfilCoach`, `AssistantCoach`, `Utilisateur`, `CredentialAthlete`, `StaffPermissions`, `Abonnement`, `MessageEquipe`, `Presence`, `Evaluation`, `PhaseSaison`, `CreneauRecurrent`, `MatchCalendrier`, `EvenementSync`, `CategorieExercice` (déjà user-defined !), toute la musculation (`ProgrammeMuscu`, `SeanceMuscu`, `TestPhysique`) | ~55 % des modèles sont sport-agnostiques. Le scoping `codeEquipe` + `FiltreParEquipe` est le socle multi-tenant embryonnaire. |
| **Génériques à 90 %** (renommage conceptuel seulement) | `ElementTerrain` (coordonnées normalisées 0-1, types joueur/ballon/flèche/trajectoire — seul l'emoji ballon est volley), `EtapeExercice`, `Exercice`, `ExerciceBibliotheque`, `Seance` côté pratique, protocole `TerrainContent`, `ObjectifJoueur` (catégories = strings) | Le terrain dessinable est une **planche tactique générique** : rien dans `ElementTerrain.swift` n'est volleyball. Seul le *rendu du fond* (parquet 2:1, lignes, filet) l'est. |
| **Volleyball hardcodé** | `TypeActionPoint` (17 cas + `estPointPourNous`/`categorieHeatmap`/`estBloc` en switch), `TypeActionRallye` (6 cas), `PosteJoueur` (5 postes + couleurs), `FormationType`/`FormationMode` (5-1/4-2/6-2/beach, `zonesIndoor`, `lineup`, positions réception/attaque codées en dur), `SetScore.estTermine` (cible 25/15, écart 2), `JoueurEquipe` (~20 colonnes de compteurs nommées : `attaquesReussies`, `blocsAssistes`, `receptionsTotales`…), `StatsMatch` (mêmes colonnes par match), `CompteursJoueur` + le switch d'agrégation, `MetriquesVolley` (sideout %, reconstruction du service), `PointMatch` (rotationAuMoment/rotationAdvAuMoment/zone 1-6/nousServionsAuMoment), `ScoutingReport` (systemJeu « 5-1 », tendances par zone 1-6), `ConfigMatch`, `DonneesHeatmap` (zones 1-6), `TypeTerrain` (indoor/beach) | C'est le cœur du chantier. MAIS : tout est soit une **table** (catalogue d'actions, positions, zones), soit une **formule** (métriques), soit une **machine à états** (rotation/sideout). Chaque nature a sa stratégie (§2). |
| **Zone grise** | `Seance` côté match (porte l'état match en blobs JSON — facile à généraliser en `etatMatchData` par sport), `MatchLiveModels` (structs live), `ScoutingReport` (structure générique, vocabulaire volley) | Les blobs restent, leur *contenu* devient décrit par le sport. |

### 1.2 Ce qui doit devenir data-driven vs rester du code

**Règle de partage** (la limite du data-driven) :

> **Si ça s'exprime comme une table ou une expression arithmétique pure → fichier de définition. Si ça a besoin d'une boucle, d'un état ou d'une séquence → protocole Swift. Si c'est une interaction UI spécialisée → vue optionnelle activée par capacité.**

- Data-driven : catalogue d'actions (avec effets score et compteurs incrémentés), postes, terrains/zones/lignes, formats de match (sets/périodes/temps), formations statiques, formules arithmétiques (hitting %, par-set), repères (« .300 »), glossaire.
- Code Swift obligatoire : logique séquentielle (`reconstruireService`, rotation auto sur sideout, runs — tout `MatchLiveViewModel`), validations métier, heuristiques (suggestions d'objectifs), layouts PDF spécifiques.
- Vues assumées sport-spécifiques : `RotationLiveView`, `SelecteurZoneView` 2 étapes, `PanneauFormationsView`. On ne les rend **pas** génériques — on les rend **optionnelles** (elles n'existent que si le sport déclare la capacité).

---

## 2. SportDescriptor — l'abstraction concrète

### 2.1 Architecture en 3 couches

```
┌──────────────────────────────────────────────────────────┐
│ Couche 1 — DONNÉES : sports/volleyball.json (bundlé)     │
│  catalogue actions · compteurs · métriques · terrain ·   │
│  postes · formats de match · formations · capacités      │
├──────────────────────────────────────────────────────────┤
│ Couche 2 — CODE : protocole MoteurSport (1 impl/sport)   │
│  progression de match, séquences, sideout/possession     │
│  (MoteurVolley = MetriquesVolley + logique live extraite)│
├──────────────────────────────────────────────────────────┤
│ Couche 3 — VUES : registre de panneaux par capacité      │
│  vues génériques (terrain, box score, heatmap, tableaux) │
│  + vues optionnelles (RotationLiveView si .rotations)    │
└──────────────────────────────────────────────────────────┘
```

**Décision de format** : JSON **bundlé dans le binaire** (pas téléchargé). Raisons : offline garanti, review Apple sans surprise, versionnement du sport = versionnement de l'app, validation par tests au build. Un sport = `sports/<id>.json` + éventuellement `Moteur<Sport>.swift` + 0-N vues optionnelles. **Pas de plugin dynamique téléchargeable** (YAGNI, et l'App Store l'interdirait de toute façon pour du code).

### 2.2 Le descripteur (Swift, Codable)

```swift
struct SportDescriptor: Codable, Identifiable {
    let id: String                     // "volleyball" — clé de persistance, JAMAIS renommée
    let version: Int
    let nom: String                    // localisable
    let capacites: Set<CapaciteSport>  // pilote l'UI — voir 2.5
    let terrains: [TerrainDescriptor]  // variantes : indoor, beach…
    let postes: [PosteDescriptor]      // id, nom, abréviation, couleurHex
    let compteurs: [CompteurDescriptor]        // le « schéma » stats du sport
    let actions: [ActionDescriptor]            // marquantes (ex-TypeActionPoint)
    let actionsRallye: [ActionDescriptor]      // non-marquantes (ex-TypeActionRallye)
    let metriques: [MetriqueDescriptor]        // formules dérivées + formats
    let formatMatch: FormatMatchDescriptor     // sets vs temps
    let formations: [FormationDescriptor]      // remplace FormationType.lineup/positions
    let rotation: RotationDescriptor?          // OPTIONNEL — module volley
    let bibliothequeDefauts: String?           // seed d'exercices par sport
    let testsPhysiquesSuggeres: [String]       // unités d'entraînement : suggestions
}
```

#### Terrain (dimensions, zones, rendu)

```swift
struct TerrainDescriptor: Codable {
    let id: String                    // "indoor" | "beach" — remplace TypeTerrain
    let ratio: Double                 // 2.0 pour volley 18×9 ; 1.87 basket ; ~1.54 hockey
    let style: StyleSurface           // .parquet, .sable, .gazon, .glace, .synthetique
    let lignes: [LigneTerrain]        // segments/arcs en coordonnées normalisées 0-1
    let filet: FiletDescriptor?       // nil = pas de filet (soccer, hockey…)
    let zones: [ZoneDescriptor]       // polygones normalisés + numéro/nom (heatmap, scouting)
}
```

Point d'appui existant : `ElementTerrain` travaille déjà en coordonnées **normalisées 0-1** (piège connu n° 3 du CLAUDE.md) et `FormationType.zonesIndoor` est déjà une table de coordonnées. `TerrainVolleyView` (Canvas) devient un `TerrainRendererView(descriptor:)` qui dessine `lignes` + `style` ; le rendu parquet/sable actuel devient deux styles parmi d'autres. La heatmap, le sélecteur de zone et les tendances zonales du scouting consomment `zones` au lieu du 1-6 codé en dur — **les zones deviennent une propriété du sport** (6 au volley, 14 zones de tir au hockey, moitiés/tiers au soccer).

#### Catalogue d'actions — le remplaçant de `TypeActionPoint`

C'est la pièce maîtresse. Aujourd'hui, ajouter une action = toucher 6+ switchs (`Seance.swift`, `AgregateurStatsMatch`, heatmap, dashboards). Demain :

```swift
struct ActionDescriptor: Codable, Identifiable {
    let id: String              // "kill" — DOIT égaler le typeActionRaw persisté
    let nom: String             // "Kill"
    let effetScore: EffetScore  // .pourNous / .contreNous / .aucun (remplace estPointPourNous)
    let camp: Camp              // .nous / .adversaire (remplace estStatAdversaire)
    let attribuableJoueur: Bool
    let supporteZone: Bool
    let categorieHeatmap: String?      // clé vers zones/catégories du sport
    let incremente: [String]           // IDs de compteurs : ["kills", "tentativesAttaque"]
    let icone: String?                 // SF Symbol
    let famille: String                // "attaque" | "service" | … (groupage UI)
}
```

Le champ `incremente` **remplace le switch de 40 lignes d'`AgregateurStatsMatch.agreger`** par une table : l'agrégateur générique fait `for id in action.incremente { compteurs[id, default: 0] += 1 }`. La sémantique actuelle (kill → +kills +tentativesAttaque ; erreurReception → +erreursReception +receptionsTotales +qualité 0) se transcrit ligne à ligne dans `volleyball.json` et se vérifie par **golden tests** : mêmes `PointMatch` en entrée → mêmes compteurs qu'aujourd'hui.

#### Compteurs et métriques dérivées

```swift
struct CompteurDescriptor: Codable { let id: String; let nom: String; let groupe: String }

struct MetriqueDescriptor: Codable {
    let id: String              // "hitting"
    let nom: String             // "Rendement attaque"
    let expression: String?     // "(kills - erreursAttaque) / tentativesAttaque"
    let calculateurID: String?  // escape hatch → code Swift enregistré ("volley.sideout")
    let format: FormatMetrique  // .fractionVolley (".350") / .pourcentage / .parSet / .brut
    let repere: Double?         // 0.300 — le repère affiché dans JoueurDetailView
}
```

- `expression` : mini-évaluateur arithmétique (4 opérateurs + garde division par zéro). ~150 lignes, testable, suffisant pour 90 % des métriques (hitting %, efficacité réception, par-set, points pondérés D3).
- `calculateurID` : pour ce qui exige une **séquence** (sideout % avec `reconstruireService`, runs) — pointeur vers une fonction Swift enregistrée dans le moteur du sport. **On n'invente pas un langage de script** : la limite du data-driven est ici, assumée.

`MetriquesVolley` ne disparaît pas : il devient l'implémentation des `calculateurID` volley, et `FormatMetriques` reste l'unique couche de formatage (décision D1/D2 conservée).

#### Format de match — sets vs temps

```swift
enum StructureScore: Codable {
    case manches(max: Int, pointsCible: Int, pointsCibleDecisive: Int,
                 ecartMin: Int, manchesPourVictoire: Int)      // volley : 5, 25, 15, 2, 3
    case periodes(nombre: Int, dureeMinutes: Int,
                  prolongation: ProlongationDescriptor?)       // hockey, basket, soccer
}
```

`SetScore.estTermine` (25/15/écart 2 codés en dur dans `Seance.swift:52-70`) lit désormais le descripteur. Le mot « set » dans l'UI devient le libellé de manche du sport (« set », « période », « quart »).

#### Rotations — rendre optionnel ce qui est très volleyball

La réponse n'est **pas** de généraliser la rotation, c'est de la **modulariser** :

- `RotationDescriptor?` est `nil` pour tout sport sauf volleyball (nb de positions, sens, règle de déclenchement `surSideout`).
- La logique (rotation auto, `tournerAdversaire()`, historique par set) vit dans `MoteurVolley` — extraction de ce qui est aujourd'hui dans `MatchLiveViewModel`.
- Les colonnes `PointMatch.rotationAuMoment/rotationAdvAuMoment/nousServionsAuMoment` restent (fossiles CloudKit assumés, cf. §5) ; les sports futurs écrivent leur contexte dans un nouveau champ additif `contexteData: Data` (JSON par sport : possession, power-play, joueur au bâton…).
- `RotationLiveView`, `StatsParRotationView`, le chip « R1 · R1 » : montés **uniquement si** `sport.capacites.contains(.rotations)`.

#### Moteur de sport (protocole)

```swift
protocol MoteurSport {
    associatedtype Contexte: Codable          // état séquentiel propre au sport
    /// IMMUABLE : retourne un nouvel état (jamais de mutation in-place)
    func appliquer(_ action: ActionDescriptor, a etat: EtatMatch<Contexte>) -> EtatMatch<Contexte>
    func annulerDerniere(_ etat: EtatMatch<Contexte>) -> EtatMatch<Contexte>
    func metriquesSequentielles(evenements: [EvenementMatch],
                                config: ConfigMatchSport) -> [String: Double]
}
```

Un sport « simple » (badminton : mêmes mécaniques de manches, pas de rotation) peut utiliser un `MoteurManchesGenerique` fourni. Le volley est le moteur le plus complexe qu'on aura à écrire — il existe déjà, il faut juste l'extraire.

### 2.3 Persistance — comment le générique cohabite avec l'existant

**Principe cardinal : on ne migre PAS les données volleyball.** CloudKit interdit de toute façon les suppressions/renommages (piège n° 15). Stratégie :

| Élément | Stratégie |
|---|---|
| `Equipe` | + `sportID: String = "volleyball"` (additif, CloudKit-safe). **1 équipe = 1 sport**, invariant simple qui règle 90 % des questions de scoping. |
| `PointMatch.typeActionRaw` | Inchangé — devient la clé du catalogue. `TypeActionPoint` survit comme *façade typée* volley pendant la transition (évite de réécrire 30 switchs d'un coup). |
| `JoueurEquipe` / `StatsMatch` (colonnes nommées) | Les colonnes volley restent LA source pour le volleyball. Le descripteur volley mappe `compteurID → KeyPath` (« kills » → `\.attaquesReussies`). Les **sports futurs** utilisent un stockage générique : `compteursData: Data` ([String: Int] JSON) ajouté sur `StatsMatch`, projection depuis l'event log. Lecture unifiée derrière un accesseur `valeur(compteur:)`. |
| Cumul carrière | Inchangé : event log (`PointMatch`) → `AgregateurStats` (générique) → `StatsMatch` → `resynchroniserCumul` idempotent. **Cette chaîne, déjà construite en v2.2, est exactement une architecture event-sourcée** — elle se généralise sans se réécrire. |
| Formations | `FormationType` (enum) → entrées de `formations` dans le JSON ; `FormationPersonnalisee.positionsJSON` déjà data-driven, il gagne juste un `sportID`. |

### 2.4 Registre de vues (couche 3)

Pas de sur-ingénierie type plugin UI dynamique. Pour des sports **compilés dans le binaire**, un simple point d'aiguillage suffit :

```swift
// Un seul fichier — le "switch assumé" du projet
enum PanneauxSport {
    @ViewBuilder static func panneauLive(_ sport: SportDescriptor, vm: MatchLiveVM) -> some View {
        if sport.capacites.contains(.rotations) { RotationLiveView(vm: vm) }
        // hockey : PanneauPresencesGlaceView(vm:) etc.
    }
}
```

Les vues **génériques** (l'essentiel) consomment le descripteur : `TerrainRendererView`, `HeatmapView(zones:)`, `StatsLiveView` (grille générée depuis `actions` groupées par `famille` — `DefinitionStat` fait déjà ça à moitié), `TableauStats`/`CarteMetrique` (déjà agnostiques), box score, palmarès, évolution, comparaison (les catégories viennent de `compteurs.groupe`).

### 2.5 Capacités (extraits)

`.rotations`, `.sideout`, `.zonesTerrain`, `.formations`, `.libero`, `.mancheAuxPoints`, `.tempsDeJeu`, `.substitutionsLimitees`, `.tempsMorts`, `.heatmapTrajectoires`, `.scoutingZonal`. L'UI ne teste **jamais** `sportID == "volleyball"` ; elle teste une capacité. C'est la règle de lint n° 1 de la refonte.

### 2.6 Preuve de l'abstraction : le beach comme sport n° 2

Avant tout sport nouveau marché, **extraire le beach volleyball en descripteur séparé** (terrain 16×8, 2 joueurs, sets à 21, pas de rotation de position au sens indoor, formations beach déjà dans `FormationType`). Le code le traite aujourd'hui en `if estBeach` éparpillés — c'est le cobaye parfait : si l'abstraction n'arrive pas à décrire le beach proprement, elle n'encaissera jamais le basket ou le hockey. Coût quasi nul, valeur de validation maximale.

---

## 3. Backend hybride — iPad local-first + plateforme club/fédération

### 3.1 Principe directeur : deux plans de données, jamais un seul maître ambigu

```
PLAN ÉQUIPE (existant, chemin critique terrain)   PLAN ORGANISATION (nouveau, B2B)
SwiftData local + CloudKit                        Postgres multi-tenant + dashboard web
→ doit marcher dans un gym sans wifi              → n'est JAMAIS requis pour coacher
```

Le backend est une **couche au-dessus**, alimentée en asynchrone. Si le backend brûle, un coach ne le remarque pas avant d'ouvrir le dashboard web. C'est le contrat architectural n° 1.

### 3.2 Choix de stack (solo dev, budget serré)

| Option | Pour | Contre | Verdict |
|---|---|---|---|
| **Vapor (Swift on Server)** | Même langage ; `PlaycoCore` (SPM) compile côté serveur → formules stats partagées | Il faut opérer un serveur, écosystème auth/admin à construire soi-même | Pas maintenant. Option de croissance si logique serveur lourde émerge. |
| **Supabase** (Postgres managé + Auth + RLS + API auto + Realtime + Storage) | ~80 % du besoin B2B sans écrire de serveur : auth SIWA incluse, Row Level Security = multi-tenant natif, API REST/Realtime générée, région **ca-central-1 (Canada)** → argument Loi 25 pour les fédérations québécoises | Logique custom en TS (edge functions) ou SQL ; lock-in modéré | **✅ Recommandé.** C'est du Postgres standard + OIDC : la porte de sortie (Neon/RDS/Vapor) reste ouverte. |
| Cloudflare Workers + D1 | Très bon marché | SQLite multi-tenant + plomberie auth/RLS à la main | Non — trop de code d'infrastructure pour un solo. |

**Dashboard web** : SvelteKit ou Next.js sur Vercel/Cloudflare Pages, parlant à Supabase **directement** (PostgREST + RLS) — pas d'API custom au démarrage. Le premier dashboard est en **lecture seule** (calendriers, résultats, rosters, présences agrégées) : c'est 80 % de la valeur admin pour 20 % du risque.

**Partage de logique** : `PlaycoCore` (package SPM) contient SportDescriptor, formules, agrégateur, et des **vecteurs de tests JSON** (entrées PointMatch → sorties box score attendues). Le serveur ne réimplémente PAS les formules : il **affiche les agrégats poussés par l'app** (l'app du coach est l'autorité de calcul) et ne recalcule que le strict minimum (validations batch), vérifié contre les mêmes vecteurs JSON. Cela neutralise le risque de divergence Swift/TS.

### 3.3 Protocole de sync — ni CRDT, ni prière

L'insight qui simplifie tout : **le match a un seul scoreur** (single-writer par design — c'est déjà vrai dans le produit). Donc :

| Type de données | Nature | Stratégie de sync |
|---|---|---|
| `PointMatch`, `ActionRallye` | **Event log append-only**, UUID, horodaté | Upload idempotent (upsert par UUID). Aucun conflit possible. C'est déjà la structure du modèle. |
| Roster, séances, calendrier, scouting | Documents éditables | **LWW par enregistrement via `dateModification`** — champ déjà présent sur `Seance`, `JoueurEquipe`, `Equipe`, et le merge par `dateModification` est déjà implémenté dans le partage Public DB. On généralise l'existant. LWW par champ seulement si un cas réel de co-édition l'exige. |
| Résultats officiels inter-clubs | Co-validés | Machine à états serveur (§4), pas de la sync. |

**Mécanique** : outbox locale (`@Model OperationSync` : entité, entiteID, payload, tentatives — généralisation du journal sync + compteur de modifications existants), push batché quand réseau (le `NWPathMonitor` de `CloudKitSyncService` sert déjà à ça), pull par curseur `(timestamp, id)` — pattern déjà maîtrisé avec la pagination CloudKit par curseur. Backoff exponentiel : déjà écrit (`FileReplicationUtilisateur`). **CRDT : non.** Réversible plus tard si la co-édition simultanée devient un vrai besoin ; aujourd'hui c'est de la complexité sans client.

### 3.4 SIWA étendu au web

- Sign in with Apple fonctionne sur le web (OIDC / « Sign in with Apple JS ») : Services ID + domaine vérifié + **même Apple Team** → le `sub` (l'`appleUserID` déjà stocké sur `Utilisateur`) est **identique** entre l'app et le web. L'identité existante mappe directement, zéro migration de comptes.
- Supabase Auth gère le provider Apple nativement (app native ET web).
- Ajout d'un **magic link courriel** pour les administrateurs de fédération (persona desktop/Windows, pas forcément d'Apple ID) — SIWA reste la voie coach/athlète.
- Corollaire irréversible : **ne jamais changer d'Apple Team ID** (le `sub` est scopé par team).

### 3.5 CloudKit : coexistence, puis remplacement partiel

| Composant CloudKit | Sort |
|---|---|
| **Base privée** (sync inter-appareils du coach) | **Conservée indéfiniment.** Gratuite, invisible, fiable pour le tier équipe. Aucune raison de la payer ailleurs. |
| **Public DB** (miroir de partage coach→athlète, records sanitisés à la main, world-readable) | **Point faible assumé de l'archi actuelle** (sécurité par sanitisation, pas d'ACL réelles, action Dashboard manuelle documentée dans `docs/Securite_AbonnementPublicDB.md`). Remplacée progressivement par le backend pour les équipes des tiers connectés (vraies ACL, RLS). Dépréciée en phase 5, jamais avant que le backend ait fait ses preuves. |

### 3.6 Coûts mensuels estimés par palier

| Palier | Usage | Infra | Coût/mois |
|---|---|---|---|
| 0 — Lancement (aujourd'hui) | App seule, tiers Pro | CloudKit (gratuit), Apple Dev 99 $/an | **~0 $** |
| 1 — Premier club payant | Dashboard lecture seule, 5-20 équipes | Supabase Pro 25 $US + Pages/Vercel 0-20 $ + domaine | **35-60 $ CA** |
| 2 — Fédération pilote | ~200 équipes, 3-10k athlètes, registre | Supabase compute+storage ~100 $ + Sentry free + sauvegardes | **150-250 $ CA** |
| 3 — Multi-fédérations | 100k athlètes, ligues | Postgres dédié + réplique + monitoring payant | **700-1 400 $ CA** — largement couvert par les contrats B2B à ce stade |

**Règle budgétaire** : le palier 1 ne s'allume qu'à la signature du premier contrat Club/Féd. Zéro serveur spéculatif.

### 3.7 Note App Store / facturation B2B

StoreKit reste pour Pro/Club individuel in-app. Les contrats organisation (fédération, ligue) se vendent **hors app** (Stripe, facture annuelle) : c'est conforme aux règles App Store pour des services multi-plateformes vendus à une organisation, et ça évite les 15-30 % sur les gros contrats. Le tier de l'équipe se propage à l'app via le backend (le mécanisme `Equipe.tierAbonnementRaw` existe déjà).

---

## 4. Multi-tenant — organisation → club → équipe

### 4.1 Modèle (Postgres, RLS)

```
organisations (id, type: federation|ligue|club_independant, nom, region)
  └─ clubs (id, organisation_id NULLABLE)          -- un club peut être indépendant
       └─ equipes (id, club_id NULLABLE, code_equipe UNIQUE, sport_id, saison)
                                 ▲
                                 └─ PONT avec l'app : le codeEquipe 8-char existant

personnes (id, apple_sub NULLABLE, email NULLABLE)  -- identité GLOBALE, sans rôle
affiliations (personne_id, scope_type: org|club|equipe, scope_id,
              role: admin_org|admin_club|coach|assistant|athlete|parent,
              permissions JSONB, date_debut, date_fin)
athletes_registre (personne_id, organisation_id, numero_federation,
                   categorie_age, eligibilite, consentements JSONB)
```

Décisions structurantes :
- **Le rôle est une arête, pas un attribut de la personne** (table `affiliations`). Un même humain est coach d'une équipe, parent dans une autre, admin d'un club — le modèle actuel (rôle sur `Utilisateur`) ne tient pas cette réalité ; le backend la porte, l'app garde son modèle simple par équipe.
- `Etablissement` (app) ≈ club léger : il mappe sur `clubs` sans réécriture côté iOS.
- `codeEquipe` reste la clé de jonction app↔backend — le scoping `FiltreParEquipe` de l'app est déjà aligné.
- **Registre athlètes = la killer feature fédération** : numéro fédéral, éligibilité, catégories d'âge, et surtout **consentements** (mineurs !). Résidence des données au Canada + visibilité par défaut limitée au club = argument Loi 25 en avant-vente.

### 4.2 Isolation et permissions

- RLS Postgres sur chaque table de données (`equipe_id`/`club_id`/`organisation_id`), policies dérivées des `affiliations`. **Par défaut : rien n'est cross-club.**
- Les `StaffPermissions` (7 booleans) de l'app restent la vérité intra-équipe ; le backend ajoute la couche org/club au-dessus, sans toucher l'app.

### 4.3 Partage inter-clubs : le match co-validé

```
matchs_officiels (id, ligue_id, equipe_domicile_id, equipe_visiteur_id,
                  date, score_resume JSONB,
                  statut: saisi → conteste? → covalide → officiel,
                  saisi_par, covalide_par, delai_validation)
```

- Chaque club voit les matchs où il figure (policy `OR`). Le club adverse co-valide (ou conteste dans un délai, sinon validation tacite) ; le résultat co-validé devient visible ligue.
- **Granularité de partage assumée** : seul le *résultat + box score consenti* traverse la frontière du club. L'event log détaillé (`PointMatch`, heatmaps, scouting) reste la propriété du club qui l'a saisi — c'est à la fois de la protection de données et de l'avantage compétitif (personne ne veut donner son scouting à l'adversaire).

---

## 5. Chemin de migration — phases sans big-bang

| Phase | Contenu | Risque utilisateurs existants |
|---|---|---|
| **0 — Geler les invariants** (avant/pendant le lancement) | Champs **additifs** CloudKit-safe : `Equipe.sportID = "volleyball"`, `PointMatch.contexteData`, `StatsMatch.compteursData`. Aucun refactor de vue. ~2-3 jours. | Nul (additif pur, defaults). |
| **1 — Extraire `PlaycoCore`** (post-lancement) | Package SPM : `MetriquesVolley`, `AgregateurStatsMatch`, `FormatMetriques`, SportDescriptor + **`volleyball.json` qui DÉCRIT l'existant à l'identique**. Remplacer les switchs par lecture du catalogue. **Golden tests** : mêmes entrées → mêmes chiffres (les 253 tests existants sont le filet). ~2-4 semaines avec Claude Code. | Nul si les golden tests tiennent — c'est un refactor interne. |
| **2 — Sport n° 2 : beach** | Descripteur beach séparé, suppression des `if estBeach`. Valide l'abstraction sans risque marché. ~1-2 semaines. | Faible (le beach existe déjà, il change de plomberie). |
| **3 — Backend v1** (déclencheur : premier contrat club signé) | Supabase (schéma §4), outbox app→Postgres, SIWA web, dashboard **lecture seule**. L'app ne dépend de rien. ~4-6 semaines. | Nul (opt-in par tier ; les équipes non connectées ne changent rien). |
| **4 — B2B complet** | Registre athlètes, co-validation inter-clubs, facturation Stripe org, écriture limitée depuis le web (calendriers, rosters) avec sync descendante LWW. | Contenu — les nouveaux flux sont derrière le tier org. |
| **5 — Dépréciation Public DB CloudKit** | Le partage coach→athlète des équipes connectées passe par le backend (vraies ACL). CloudKit privé conservé. Public DB coupée seulement quand <5 % du trafic y passe. | Géré par bascule progressive par équipe, jamais par flag global. |

**Interdits pendant toute la migration** : suppression/renommage de champ CloudKit ; double-maîtrise d'un même champ par deux systèmes de sync ; toute fonctionnalité terrain qui exige le réseau.

---

## 6. Top 5 des risques architecturaux

| # | Risque | Mitigation |
|---|---|---|
| 1 | **Inner-platform / généralisation prématurée** : l'abstraction multi-sport gèle le produit volleyball, l'expressivité du JSON devient un langage de programmation du pauvre. | `volleyball.json` doit décrire l'existant *à l'identique* (golden tests) avant toute nouveauté ; escape hatch `calculateurID` assumé plutôt qu'un moteur d'expressions généralisé ; règle « pas de 3e niveau d'abstraction avant un 2e sport réel payant » ; beach comme cobaye à coût nul. |
| 2 | **Double pile de sync (CloudKit + Postgres)** : conflits silencieux, données divergentes, bugs fantômes impossibles à reproduire. | Direction unique par type de données (event log : device→backend one-way ; roster : LWW `dateModification` ; officiel : machine à états serveur). Jamais deux maîtres du même champ. Outbox idempotente par UUID. Télémétrie de divergence (checksum de box score comparé app/serveur). |
| 3 | **Solo dev noyé par l'exploitation** : astreinte serveur, incidents, sécurité, conformité (Loi 25/RGPD), pendant que le produit iOS doit continuer d'avancer. | Managed services uniquement (Supabase/Vercel) ; aucun serveur avant contrat signé ; backend hors chemin critique (down ≠ app cassée) ; SLO honnêtes contractualisés (support 48 h, pas 24/7) ; sauvegardes gérées + restauration testée une fois par trimestre. |
| 4 | **Verrou de schéma CloudKit + colonnes fossiles** : les ~20 compteurs volley de `JoueurEquipe`/`StatsMatch` et les champs rotation de `PointMatch` sont gravés à vie ; chaque généralisation ajoute sans jamais retrancher. | Additive-only assumé et documenté (registre des champs fossiles) ; les nouveaux sports naissent sur le stockage générique (`compteursData`) ; la vraie liberté de schéma vit côté Postgres ; à très long terme, un reset de container CloudKit reste possible pour les *nouveaux* comptes seulement. |
| 5 | **Divergence des formules stats entre plateformes** (Swift app vs TS/SQL dashboard) : un hitting % différent entre l'iPad et le site de la fédération détruit la confiance. | L'app du coach est l'**autorité de calcul** — le serveur affiche les agrégats poussés ; recalcul serveur minimal validé par **vecteurs de tests JSON partagés** dans `PlaycoCore` ; toute formule a un ID et une version dans le descripteur. |

---

## 7. Schéma d'architecture cible

```
                        ┌─────────────────────────────────────────────┐
                        │              PlaycoCore (SPM)               │
                        │  SportDescriptor + sports/*.json (bundlés)  │
                        │  Métriques · Agrégateur · FormatMetriques   │
                        │  Vecteurs de tests JSON (vérité partagée)   │
                        └────────────┬───────────────────┬────────────┘
                                     │                   │
      ┌──────────────────────────────▼─────┐   ┌─────────▼─────────────────────────┐
      │      APP iOS/iPadOS (terrain)      │   │   BACKEND (tier Club/Fédération)  │
      │  SwiftUI · SwiftData · LOCAL-FIRST │   │   Supabase Postgres (ca-central)  │
      │                                    │   │   RLS multi-tenant · Auth OIDC    │
      │  MoteurVolley / MoteurBeach / …    │   │   (SIWA web + magic link admins)  │
      │  Vues génériques (terrain, stats)  │   │                                   │
      │  Vues par capacité (RotationLive)  │   │  organisations → clubs → équipes  │
      │  ┌──────────────────────────────┐  │   │  personnes ←affiliations→ scopes  │
      │  │ EVENT LOG (PointMatch,       │  │   │  athletes_registre (Loi 25)       │
      │  │ ActionRallye — append-only)  │  │   │  matchs_officiels (co-validation) │
      │  └──────────────┬───────────────┘  │   └───────┬───────────────────▲───────┘
      │        OUTBOX   │ push idempotent  │           │                   │
      │  (OperationSync)└──────────────────┼──────────►│      Stripe (B2B hors app)
      │                 ◄──────────────────┼───pull────┘                   │
      └──────┬──────────────────┬──────────┘  LWW dateModification         │
             │                  │                                          │
   ┌─────────▼────────┐  ┌──────▼──────────────────┐        ┌─────────────┴────────┐
   │ CloudKit PRIVÉ   │  │ CloudKit PUBLIC DB      │        │  DASHBOARD WEB       │
   │ sync perso coach │  │ partage équipe actuel   │        │  SvelteKit/Next      │
   │ → CONSERVÉ       │  │ → DÉPRÉCIÉ phase 5      │        │  Vercel/CF Pages     │
   └──────────────────┘  │ (remplacé par backend)  │        │  admins club/féd     │
                         └─────────────────────────┘        │  (lecture d'abord)   │
                                                            └──────────────────────┘
```

---

## 8. Choix irréversibles vs réversibles

### Irréversibles (à graver maintenant, coût de changement ≈ infini)

1. **IDs stables** : UUID partout + clés `String` des actions/compteurs/sports (`"kill"`, `"volleyball"`) — persistées à vie, jamais renommées. (Déjà le cas — à sanctuariser par convention écrite.)
2. **Additivité du schéma CloudKit** : on n'enlève jamais, on ne renomme jamais. Les colonnes volley de `JoueurEquipe`/`StatsMatch`/`PointMatch` sont des fossiles assumés.
3. **1 équipe = 1 sport** (`Equipe.sportID`). Le multi-sport se fait par équipes multiples, jamais par équipe hybride.
4. **L'event log comme source de vérité des stats de match** (`PointMatch` append-only → projections). Toute la chaîne stats et toute la sync en dépendent.
5. **Séparation identité/rôle côté backend** (`personnes` ↔ `affiliations`) — un modèle où le rôle est un attribut de la personne ne se répare pas après coup.
6. **Apple Team ID** : le `sub` SIWA est scopé par team ; changer de team = perdre le mapping de tous les comptes.
7. **Le contrat local-first** : aucune fonctionnalité terrain ne dépend du réseau. C'est un choix de culture produit plus que de code, mais il est irréversible dans la promesse faite aux coachs.

### Réversibles (décidés aujourd'hui, changeables demain à coût borné)

- **Supabase** : c'est du Postgres standard + OIDC → migrable vers Neon/RDS/Vapor sans toucher l'app (l'outbox parle à une API, pas à Supabase).
- **Framework du dashboard web** (SvelteKit/Next) — remplaçable, il ne détient aucune donnée.
- **LWW par enregistrement** → peut évoluer vers LWW par champ, voire CRDT ciblé, si un vrai cas de co-édition émerge (le format outbox le permet).
- **Public DB CloudKit** — voie de sortie planifiée (phase 5), rythme ajustable.
- **Beach = sport séparé vs variante** — le descripteur permet les deux lectures, tranchable en phase 2.
- **Stripe** comme PSP B2B ; **le mini-évaluateur d'expressions** des métriques (peut être enrichi ou remplacé par plus de `calculateurID`) ; **la granularité du partage inter-clubs** (résultat seul aujourd'hui, box score complet opt-in demain).

---

### Synthèse pour la décision « refonte progressive vs from scratch »

Du point de vue de cette lentille : **rien dans l'architecture actuelle n'exige un from scratch.** Les trois fondations critiques de la cible existent déjà dans le code — event log (`PointMatch`), formules/agrégation centralisées (`MetriquesVolley`/`AgregateurStatsMatch`, v2.2), et persistance string-keyed + JSON-blobs versionnés. Le multi-sport est un chantier d'**extraction** (descripteur qui décrit l'existant, protégé par golden tests), pas de réécriture ; le backend est une **couche additive** hors chemin critique, déclenchée par le premier contrat B2B. Le seul endroit où un « from scratch » local serait justifié est la Public DB CloudKit — et elle a déjà sa voie de sortie planifiée.
