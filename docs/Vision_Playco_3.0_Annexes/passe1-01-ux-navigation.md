# Playco 3.0 — Vision UX & Architecture d'information
### Lentille : designer produit senior Apple (HIG iOS 26, Liquid Glass)

> **Thèse.** Playco v2.2 est une app organisée par *type de contenu* (Séances, Matchs, Stratégies, Équipe, Entraînement). Or un coach ne pense jamais « je vais consulter le type de données Stratégies ». Il pense : **je prépare mardi soir, je coache ce soir, j'analyse hier**. La refonte consiste à réaligner toute l'architecture d'information sur ces trois moments — et à faire de l'écran d'accueil non pas un menu, mais une réponse à la question « qu'est-ce qui se passe aujourd'hui ? ».

---

## 1. Critique de l'existant — ce qui casse réellement

Le hub 5 cartes + 5 sections silotées était le bon choix en v0.7 (peu de features, une carte = une feature). En v2.2, avec ~40 écrans, il produit des problèmes structurels précis :

### 1.1 La taxonomie est par type de données, pas par tâche
- **Où vit le scouting ?** Dans `Views/Matchs/` (ScoutingReportListView), accessible depuis la section Matchs. Mais le scouting se *rédige* en préparation (à la maison, 3 jours avant) et se *consulte* en match (PlanMatchPanneau). Un objet, deux moments, un seul point d'entrée — enterré derrière la mauvaise porte pour le moment « préparation ».
- **Pourquoi Stratégies est séparée de Séances ?** Une pratique existe pour répéter des systèmes de jeu. Le coach qui monte sa séance de mardi veut piocher un exercice ET la stratégie « réception 5-1 R2 » dans le même geste. Aujourd'hui : deux sections, deux tint colors, deux bibliothèques, zéro pont. Les formations sont même *dupliquées conceptuellement* entre `Views/Strategies/FormationsView` et `Views/Terrain/PanneauFormationsView`.
- **Entraînement (muscu) est un silo fantôme.** Le suivi des charges vit dans Équipe (`SuiviMusculationView`, `JoueurSuiviMuscuSection`), les programmes dans Entraînement, les tests physiques dans les deux. Le préparateur physique navigue entre deux sections violette et verte pour un seul métier.
- **Équipe est un fourre-tout** : roster + hub stats 5 entrées + palmarès + objectifs + tests physiques + tableau de bord. C'est devenu « tout ce qui n'est pas un événement ».

### 1.2 Le coût en taps du geste le plus critique
Démarrer la saisie live d'un match ce soir (match non créé — cas fréquent, les matchs de calendrier `MatchCalendrier` ne sont pas des `Seance`) :
`Accueil → carte Matchs (1) → « + » (2) → formulaire nom/date/adversaire/lieu + clavier (3–7) → sélectionner le match (8) → MatchDetailView → bouton Live (9) → CompositionMatchView : 6 joueurs + rotation (10–16) → GO.`
**≈ 15 interactions + saisie clavier**, dans un gymnase bruyant, 10 minutes avant le service. Même quand le match existe déjà : 3 niveaux de navigation avant le bouton Live (`MatchDetailView:310`). C'est le flow qui définit la valeur perçue de l'app, et c'est le plus profond.

### 1.3 Navigation hub-and-spoke = aller-retour permanent
Chaque section a son bouton « ← Accueil ». Passer des stats du dernier match à la fiche d'un joueur = remonter à l'accueil, redescendre. Le hub est un péage, pas un raccourci. Le DockBar flottant (Messages + Profil) est une pseudo-tab-bar non standard qui occupe l'espace d'une vraie tab bar sans en offrir les bénéfices (état persistant, badge système, restauration).

### 1.4 La recherche globale existe mais est invisible
`RechercheGlobaleView` est câblée dans ContentView mais n'est ni un geste système (pull-down), ni un raccourci clavier, ni dans la navigation primaire. Une feature Spotlight-like que personne ne découvre est une feature qui n'existe pas.

### 1.5 L'athlète a une app d'adulte en habits d'enfant
`MonProfilAthleteView` est une variante de la navigation coach, sur iPhone. L'athlète n'a que 3 questions : *quand est-ce que je joue, comment j'ai joué, qu'est-ce que le coach a dit ?* Aujourd'hui il navigue dans une IA pensée pour l'iPad d'un coach.

---

## 2. Nouvelle architecture d'information — organiser par moment d'usage

### 2.1 Structure primaire : 5 espaces, tab bar adaptative native

Remplacer le hub 5 cartes + DockBar par une **TabView `.sidebarAdaptable`** (iOS 18+, magnifiée par Liquid Glass iOS 26) : tab bar flottante en verre sur iPhone et iPad portrait, sidebar sur iPad paysage. Zéro navigation custom à maintenir, restauration d'état gratuite, réduction au scroll native.

| Onglet | Moment | Contenu | Couleur d'accent |
|---|---|---|---|
| **Aujourd'hui** | maintenant | Hub contextuel du jour | Couleur de l'équipe |
| **Préparer** | à la maison | Calendrier, séances, Playbook (exercices+stratégies+formations), scouting, programmes physiques | Couleur de l'équipe |
| **Coacher** | au gymnase | Live match, live séance, présences, plan de match, courtside | Rouge « live » (seul accent fonctionnel conservé) |
| **Analyser** | après | Hub stats complet : box scores, analytics, rotations, heatmap, fil du match, évolution, palmarès, exports | Couleur de l'équipe |
| **Équipe** | transversal | Roster, fiches joueurs, objectifs, tests physiques, staff, messagerie, réglages équipe | Couleur de l'équipe |

Le Profil/réglages personnels migre en avatar dans la barre de navigation d'Aujourd'hui (pattern Apple : Fitness, App Store).

### 2.2 Hiérarchie complète écran par écran

```
Playco
│
├── AUJOURD'HUI (hub contextuel — remplace AccueilView)
│   ├── En-tête : équipe active (switcher multi-équipes en un tap), avatar → Profil & réglages
│   ├── Carte HÉRO contextuelle (l'app sait quel jour on est) :
│   │   ├── Jour de match → « Sherbrooke, 19h · Plan de match · [COACHER CE MATCH] »
│   │   ├── Jour de pratique → « Pratique 18h · 6 exercices · [DÉMARRER] [Modifier] »
│   │   └── Rien aujourd'hui → prochain événement + « Préparer la semaine »
│   ├── Rangée d'actions rapides (4 max) : Nouvelle séance · Match éclair · Présences · Recherche
│   ├── Carte « Dernier match » → box score 1 tap → Analyser (pré-filtré)
│   ├── Carte « À faire » : scouting incomplet, onboarding restant, joueurs sans invitation acceptée
│   ├── Messages non lus (3 derniers, inline)
│   └── [Athlète : version réduite — voir §3]
│
├── PRÉPARER
│   ├── Calendrier (écran racine — LA colonne vertébrale)
│   │   ├── Vue mois/semaine unifiée : pratiques, matchs, muscu, échéances scouting
│   │   ├── Tap créneau récurrent vide → « Créer la séance du 12 » (pré-remplie date/lieu)
│   │   ├── Tap match futur → fiche Adversaire (scouting, historique, composition prévue)
│   │   └── Sync EventKit
│   ├── Séances (liste + détail : timeline d'exercices, terrain, présences passées)
│   │   └── Éditeur de séance = split : Playbook à gauche, timeline à droite (drag & drop)
│   ├── Playbook  ← FUSION Bibliothèque exercices + Stratégies + Formations
│   │   ├── Onglets internes : Exercices · Systèmes de jeu · Formations
│   │   ├── Recherche, catégories, favoris, terrain éditable partout
│   │   └── Tout élément est « insérable dans une séance » et « présentable » (AirPlay)
│   ├── Adversaires  ← NOUVEL OBJET DE PREMIÈRE CLASSE
│   │   ├── Fiche par adversaire : scouting (menaces zonales), historique H2H, tendances
│   │   └── PDF plan de match, duplication saison précédente
│   └── Programmes physiques (ProgrammeMuscu, assignations, bibliothèque muscu)
│
├── COACHER (le gymnase — dark par défaut, cibles larges)
│   ├── Écran racine : les événements du jour en très gros
│   │   ├── [COACHER LE MATCH] → pré-match 1 écran : 6 de départ (pré-rempli du
│   │   │   dernier match, jetons drag & drop), qui sert, config → GO
│   │   │   → MatchLiveSplitView (dashboard + saisie + rotation + plan de match en panneau)
│   │   ├── [DÉMARRER LA PRATIQUE] → séance live : timeline exercices, chrono, présences,
│   │   │   terrain en présentation AirPlay, évaluations à chaud
│   │   ├── [SÉANCE MUSCU LIVE] → SeanceLiveView
│   │   └── « Match éclair » : match hors calendrier en 2 champs (adversaire + qui sert)
│   ├── Mode courtside : sous-mode d'affichage du live (voir §6), jamais une section
│   └── Live Activity système : score dans Dynamic Island / écran verrouillé
│
├── ANALYSER (le hub stats — absorbe la section Statistiques d'EquipeView)
│   ├── Racine : « Saison » (fiche d'identité : V-D, sideout%, hitting, séries, phases)
│   ├── Matchs (résultats) → Analyse match : box score · fil du match · rotations · heatmap
│   │   (le chip « Analyse » actuel devient l'écran canonique post-match)
│   ├── Rotations (StatsParRotationView, filtres joueur/match)
│   ├── Heatmap (3 modes)
│   ├── Joueurs : évolution, comparaison par poste, palmarès & records
│   └── Exports (PDF/CSV) + rapports partagés aux athlètes
│
└── ÉQUIPE (les personnes + l'organisation)
    ├── Roster (grille jetons par poste) → Fiche joueur segmentée
    │   (Profil · Stats · Évolution · Objectifs · Physique · Invitation/QR)
    ├── Staff & permissions (GestionStaffView)
    ├── Tests physiques & suivi charges (regroupés ici — le préparateur vit ici)
    ├── Messagerie (équipe + privées)  ← sort du DockBar
    └── Réglages équipe : codes/QR d'invitation, couleurs, saison & phases, abonnement
```

**Règles de circulation** (ce qui tue le hub-and-spoke) :
- Tout objet est *navigable depuis partout* : tap sur un nom de joueur dans un box score → fiche joueur ; tap sur un adversaire dans le calendrier → fiche scouting. La navigation profonde remplace les allers-retours par le hub.
- Chaque écran d'Analyser accepte un contexte pré-filtré (déjà amorcé en v2.2 avec le chip « Analyse ») — on généralise.
- Le multi-sport (SportDescriptor) ne touche PAS cette IA : les cinq moments sont universels à tous les sports d'équipe. Le sport définit le vocabulaire, le terrain, les descripteurs de stats — pas la structure.

---

## 3. Par persona — une seule app native adaptative + un produit web séparé

**Décision : un seul binaire iOS/iPadOS dont l'IA se reconfigure par rôle. Le web est un produit distinct pour l'admin.** Deux apps App Store (coach/athlète) doubleraient la maintenance d'un solo dev pour un bénéfice marginal ; à l'inverse, porter l'admin club en SwiftUI serait du gaspillage — c'est un usage bureau, tableurs, multi-équipes.

### Athlète (iPhone, tab bar 3 onglets)
```
Aujourd'hui : prochain événement, dernière perfo perso (carte match : kills, %, note
              réception vs SA moyenne), objectifs en cours (jauges), messages
Mes stats   : saison perso, évolution, comparaison à la moyenne du poste,
              box scores de ses matchs, records personnels, muscu à faire
Équipe      : calendrier, roster (lecture), messagerie, séances partagées (si non masquées)
```
Aucune UI d'édition, aucun paywall (déjà acquis en v2.x), push « ton box score est prêt » après finalisation coach. C'est l'app qui crée la traction virale : l'athlète la montre à ses parents et à son prochain coach.

### Assistant coach
Même app que le coach ; `StaffPermissions` **masque des onglets entiers**, pas seulement des boutons : un analyste vidéo sans `peutModifierSeances` voit Coacher (saisie stats) + Analyser, et Préparer en lecture. Le rôle façonne l'IA, pas juste les permissions au bouton près.

### Préparateur physique
Coacher (séances muscu live, tests) + Équipe (suivi charges, évolution physique) + Aujourd'hui filtré sur ses assignations. Préparer se réduit à Programmes physiques. Concrètement : les mêmes onglets, dont le contenu par défaut est filtré par rôle.

### Admin de club / fédération (web — le nouveau backend)
Dashboard web (le B2B au-dessus, jamais dans l'app iPad) :
```
Vue d'ensemble : équipes du club, complétude (rosters, licences), activité
Registre athlètes : identité unique inter-équipes/saisons, conformité, exports fédération
Équipes & saisons : provisioning (créer équipe + inviter coach), archivage saison
Compétitions : ligues, classements inter-équipes (agrégation des box scores)
Facturation : sièges Club/Fédération, gestion licences
```
Le coach ne voit le club que sous forme de bénéfices silencieux : wizard pré-rempli, roster pré-chargé, classement de ligue dans Analyser.

---

## 4. Login & onboarding cible

### 4.1 Jonction d'équipe : tuer la saisie de codes
SIWA reste l'unique auth. Mais « code équipe + code d'invitation » tapés au clavier, c'est 2010. Cible :

1. **QR code par joueur** dans la fiche joueur et dans un écran « Inviter l'équipe » (grille de QR projetable sur l'écran du gymnase / imprimable). Le QR encode un **lien universel** `https://playco.app/join/{codeEquipe}/{codeInvitation}`.
2. **Lien universel partageable** par Messages/courriel : tap → app installée → sheet « Rejoindre les Élans en tant que Laurie Tremblay » → SIWA → jonction en 1 geste (`rejoindreEquipe` existant, mais alimenté par le deep link).
3. **App Clip** sur le même lien : l'athlète sans l'app scanne → App Clip « Rejoindre les Élans » (< 10 Mo : SIWA + confirmation profil) → invitation à installer l'app complète. **Time-to-team < 60 secondes, zéro code tapé.**
4. Le code alphanumérique reste en fallback (gymnase sans réseau : on note le code, on rejoint chez soi).

### 4.2 Premier lancement coach : time-to-value < 2 minutes
Le wizard 6 étapes viole le principe « la valeur avant l'administration ». Cible : **3 écrans obligatoires, tout le reste différé**.
```
1. SIWA (prénom/nom/courriel pré-remplis par Apple)
2. « Ton équipe » : nom + sport (indoor/beach) + niveau — 3 champs
3. « Ta prochaine activité » : [Pratique cette semaine] [Match à venir] [Explorer d'abord]
   → crée immédiatement le premier objet utile
```
Établissement, couleurs, assistants, créneaux récurrents, roster complet → deviennent des cartes « À faire » dans Aujourd'hui (progressive onboarding, jauge de complétude). Le roster s'importe par **collage de liste / CSV / photo de la feuille d'alignement (OCR Vision)** — un coach a toujours sa liste quelque part, ne la lui faites pas retaper.

### 4.3 Onboarding fédération (descendant)
L'admin crée club + équipes sur le web → chaque coach reçoit un lien d'invitation nominatif → SIWA → wizard réduit à 1 écran de confirmation (tout est pré-rempli : établissement, catégorie, saison, roster éventuel). Le tier Club/Fédération est porté par l'organisation : le coach ne voit jamais de paywall.

---

## 5. Les trois flows critiques, au tap près

### (a) Démarrer la saisie stats d'un match
| | v2.2 | Cible |
|---|---|---|
| Match au calendrier | ~9 taps (3 niveaux + composition) | **2 taps** : Aujourd'hui → carte héro [COACHER CE MATCH] (1) → pré-match : 6 de départ pré-rempli du dernier match, [GO] (2) |
| Ajustement du 6 | +7 taps (resélection complète) | +1 tap par échange de jetons (drag) |
| Match imprévu | ~15 interactions + clavier | **4 interactions** : Coacher → [Match éclair] (1) → adversaire (dictée/clavier) (2) → qui sert (3) → [GO] (4) |

Clés : `MatchCalendrier` promu automatiquement en `Seance` de match le jour J (plus de double création) ; la composition est un état persistant de l'équipe, pas une saisie par match ; Live Activity lancée au GO.

### (b) Créer une séance depuis la bibliothèque
| | v2.2 | Cible |
|---|---|---|
| Créer + remplir 5 exos | ~7 taps + clavier, puis ~3 taps/exo en sheet d'import | Préparer → Calendrier, tap créneau (1) → « Séance du mardi 12 » pré-nommée/datée (2) → **éditeur split** : Playbook à gauche (recherche, catégories, favoris), timeline à droite — **1 drag ou 1 tap par exercice** (3–7). Durées additionnées, dépassement du créneau signalé. |
| Resservir mardi dernier | inexistant en 1 geste | Appui long sur une séance passée → « Dupliquer vers… » : **2 taps** |

### (c) L'athlète consulte ses stats après un match
| | v2.2 | Cible |
|---|---|---|
| Chemin | ouvrir l'app → retrouver le match ou son profil (3–4 taps, aucune notification) | Le coach finalise le box score → **push « Ton match vs Sherbrooke est prêt 12 kills · .348 »** → tap = carte perso (stats du soir vs sa moyenne, note réception, objectifs impactés « plus que 4 aces ») : **1 tap**. Depuis l'app : Aujourd'hui → carte dernier match : **2 taps**. Widget iPhone « Dernier match » : **0 tap**. |

---

## 6. Langage visuel — Liquid Glass v3

1. **Le verre est le chrome, jamais le contenu.** v2.2 met du `glassEffect` sur les cartes de contenu ; c'est joli en démo, illisible sur les tableaux de stats. Cible HIG iOS 26 : verre = tab bar, toolbars, panneaux flottants (pavé rapide, PlanMatchPanneau, formations). Contenu (stats, listes, terrains) = fonds opaques hiérarchisés. `GlassCard` survit pour les surfaces de navigation ; `CarteMetrique`/`TableauStats` passent sur opaque.
2. **Une couleur = l'identité de l'équipe.** Les 5 couleurs de section (orange/rouge/bleu/vert/violet) disparaissent avec les silos. `Equipe.couleurs` (déjà en base) devient l'accentColor globale de l'app — l'app *appartient* aux Élans. Deux exceptions sémantiques : **rouge = live/enregistrement** (Coacher), sémantique nous/adversaire dans les stats (bleu/rouge conservés).
3. **Typographie stats assumée.** SF Pro (texte), **SF Pro Rounded** (compteurs, déjà amorcé), **chiffres tabulaires obligatoires** dans tout tableau, score courtside en graisse Black à 96 pt. La convention volleyball « .350 » (acquise en v2.2) devient un composant typographique unique.
4. **Iconographie** : SF Symbols hierarchical uniquement (D6 v2.2 déjà : zéro émoji). Un micro-jeu custom dessiné sur la grille SF pour les 6–8 objets volleyball sans équivalent : rotation, poste, sideout, zone de terrain.
5. **Courtside = mode d'affichage systémique**, pas un réglage caché de ProfilView : proposé automatiquement en entrant dans un live (et mémorisé). Noir véritable, verre remplacé par surfaces opaques (le blur coûte en lisibilité sous les néons de gymnase), cibles ≥ 60 pt, contraste WCAG AAA sur le score, luminosité maintenue pendant le live (idle timer off). **Coacher est dark par défaut** même hors courtside — un gymnase n'est jamais un environnement de lecture claire.
6. **Motion** : le vocabulaire spring existant (LiquidGlassKit) est bon ; on y ajoute les transitions `matchedGeometry` carte héro → live, et le morphing natif tab bar → sidebar.

---

## 7. Recherche & vitesse

1. **Palette de commandes universelle** : ⌘K (iPad clavier) / tirer-vers-le-bas sur Aujourd'hui / bouton loupe permanent dans la tab bar. Elle cherche les **objets** (joueurs, séances, adversaires, exercices, stratégies — `RechercheGlobaleView` enfin exposée) ET exécute des **actions** (« nouvelle séance », « coacher », « exporter CSV », « présences »). Premier résultat = action la plus probable selon le contexte du jour.
2. **App Intents partout** : chaque action de la palette est un App Intent → Siri (« Hé Siri, démarre le match dans Playco »), Raccourcis, Spotlight système, et **contrôles iOS 26** (bouton « Coacher » dans le Centre de contrôle / écran verrouillé de l'iPad du gymnase).
3. **Widgets** : coach — « Prochaine activité » (petit) et « Dernier match » (moyen, score+3 stats) ; athlète — « Mes stats » et « Prochain match ». Quick actions d'icône : Nouvelle séance · Coacher · Recherche.
4. **Live Activity match** : score, set, rotation dans la Dynamic Island / écran verrouillé — l'iPad peut se verrouiller entre deux sets sans perdre le contexte.
5. **Raccourcis clavier iPad complets** (Magic Keyboard au bureau) : ⌘1–5 onglets, ⌘N séance, ⌘F palette, espace = démarrer/chrono.
6. **Vitesse perçue** : tout écran d'Analyser s'ouvre pré-filtré depuis son contexte d'origine ; jamais plus de 2 niveaux entre un objet et son analyse.

---

## Les 5 décisions UX les plus importantes (classées)

1. **Réorganiser toute l'app par moment d'usage — Aujourd'hui · Préparer · Coacher · Analyser · Équipe — dans une tab bar/sidebar adaptative native**, en remplacement du hub 5 cartes par type de contenu et du DockBar custom. C'est la décision mère : elle résout le scouting orphelin, la séparation Stratégies/Séances, le silo muscu, et le hub-péage d'un seul coup.
2. **« Aujourd'hui » comme hub contextuel avec carte héro** : l'app sait quel jour on est ; 80 % des gestes quotidiens (démarrer le match du soir, la pratique, voir le dernier box score) tiennent en ≤ 2 taps. Démarrer un match passe de ~15 interactions à 2.
3. **Jonction d'équipe par QR / lien universel / App Clip** : time-to-team athlète < 60 s sans taper un code, wizard coach réduit à 3 écrans avec onboarding progressif — c'est la décision qui conditionne l'adoption virale (athlètes → parents → autres coachs) et l'onboarding fédération descendant.
4. **« Adversaire » devient un objet de première classe**, présent dans les trois moments (rédiger en Préparer, consulter en Coacher, comparer en Analyser) — le scouting cesse d'être une feature enterrée pour devenir le fil rouge de la semaine de match.
5. **Discipline Liquid Glass : le verre pour le chrome, l'opaque pour le contenu, une seule couleur = l'identité de l'équipe, et courtside/dark comme mode systémique du gymnase** — l'app cesse d'être « cinq apps colorées » pour devenir *l'app des Élans*, lisible sous les néons.
