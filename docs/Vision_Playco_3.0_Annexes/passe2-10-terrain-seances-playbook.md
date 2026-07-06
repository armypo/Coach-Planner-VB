# Refonte Terrain + Séances + Préparation de pratique — Playco 3.0 (passe 2)

Livrable de design produit. Périmètre : les trois piliers de la préparation (éditeur de terrain, constructeur de séances, Playbook) plus l'intégration du plan vidéo validé (Supabase + Cloudflare Stream, tier Élite). Fondé sur : lecture du code existant (`Views/Terrain/`, `ViewModels/TerrainEditeurViewModel.swift`, `Models/ElementTerrain.swift`, `Views/Seances/`, `Views/Bibliotheque/`) et recherche en ligne (état 2026 des outils de practice planning, canvas modernes, vidéo d'entraînement).

---

## 0. Recherche — ce que je retiens, ce que je rejette

### Outils de practice planning

**XPS Network (Sideline Sports)** — la référence pro : Session Builder drag & drop vers le calendrier, Playbook avec diagrammes ET animations image par image, Collections (bibliothèque d'organisation partagée entre coachs), 2500+ exercices fournis.
- Je retiens : le **split Playbook ↔ séance en drag & drop**, l'**animation des diagrammes comme extension naturelle des étapes** (pas un module séparé), les tags dans le Playbook, la bibliothèque comme actif d'organisation (pertinent pour la cible club/fédé de Playco).
- Je rejette : la densité desktop-first (XPS est un outil d'analyste, pas un outil de gymnase), la séparation planification/exécution (rien pour le coach pendant la pratique).

**Sportplan** — 300+ drills volleyball, chalkboard web, session planner.
- Je retiens : **le contenu par défaut de qualité est un argument commercial d'onboarding** (Sportplan vend littéralement sa banque d'exercices), et la structure de fiche drill (description, points de coaching, progressions).
- Je rejette : les diagrammes datés (clipart), le modèle web-first sans mode hors-ligne — le gymnase sans wifi est le cas critique de Playco.

**TacticalPad** — multi-sport, plays animés, visualisation 3D.
- Je retiens : la preuve que **l'animation de systèmes est le facteur de différenciation le plus démontrable en vente** (1M+ téléchargements portés par ça).
- Je rejette : la 3D « réaliste » — coût énorme, gadget de démo, contraire au positionnement mat et sobre de Playco. Un diagramme 2D animé propre bat une 3D médiocre.

**planet.training / YouCoach / VolleyballXL** — constructeurs de séances par blocs (échauffement / partie principale / retour au calme), durées par bloc, objectifs de séance.
- Je retiens : **la séance structurée en blocs avec horloge**, standard pédagogique que Playco n'a pas (une `Seance` actuelle = nom + date + liste plate d'exercices).
- Je rejette : les formulaires à 15 champs par exercice — la saisie doit rester au niveau d'exigence d'un dimanche soir à 21 h.

**Périodisation (TrainingPeaks, CoachRx, Volleyball Canada LTAD, Art of Coaching Volleyball)** — macro/méso/microcycle, plans de 4 semaines à thèmes.
- Je retiens : le **microcycle hebdomadaire à thème** comme unité de planification réaliste pour un coach scolaire/civil — pas la périodisation ondulatoire complète. `PhaseSaison` existe déjà dans Playco : il manque juste l'étage « semaine ».
- Je rejette : tout ce qui exige de saisir des charges quotidiennes par athlète (réservé au tier Élite/préparateur physique, plus tard).

### Canvas modernes

**tldraw / Apple Freeform / Concepts**
- Je retiens : la **manipulation directe non modale** (taper sélectionne toujours ; on ne « change pas de mode » pour déplacer), les **guides d'alignement et le snapping magnétique** (Freeform), les poignées de courbure visibles à la sélection (tldraw), la palette d'outils minimale avec tiroir de débordement, le principe « tout est un objet réinterprétable ».
- Je rejette : le **canvas infini**. Un terrain de volleyball est un cadre fixe et signifiant — le zoom doit être un cadrage (demi-terrain, zone filet), pas une errance. C'est une différence assumée avec Freeform.

### Vidéo d'entraînement

**Onform / Hudl Technique** — annotation par dessin sur vidéo, voice-over, comparaison côte à côte, organisation « people first » (un espace par athlète), zéro temps de traitement à l'enregistrement.
- Je retiens : **dessiner sur une frame avec les mêmes outils que le tableau tactique** (Playco a un avantage structurel : `CanvasDessinView`/`OverlayDessinView` sont réutilisables tels quels), l'organisation des clips par personne, et la friction zéro à la capture.
- Je rejette pour la v1 : la comparaison de deux vidéos superposées, l'analyse squelettique IA, le voice-over (bon candidat v2).

### Apple Pencil Pro (WWDC24)
- Je retiens tout : **hover** (préviz du point de chute + surbrillance des cibles d'aimantation), **squeeze** (palette contextuelle sous la pointe), **double-tap** (bascule outil/gomme), **haptique** via `UICanvasFeedbackGenerator` (pulsation au snap). C'est ce qui fait passer l'éditeur du statut « fonctionnel » au statut « calibre Procreate » — la signature sensorielle de Playco sur iPad.

---

## 1. Terrain 2.0 — l'éditeur signature

### 1.1 Critique de l'existant (précise, fichier par fichier)

Ce qui est bon et doit survivre :
- Coordonnées normalisées 0-1 (`ElementTerrain.x/y`) : fondation saine pour miniatures, PDF, présentation, et le multi-sport.
- Étapes (`EtapeExercice`) avec duplication (Phase 5.4) et verrouillage par étape (`etapesVerrouillees`) : le bon instinct — il manque juste l'étage supérieur (timeline, onion skin, animation).
- Auto-save debounce 3 s, undo par snapshots, `PanneauFormationsView` en 2 taps, jetons colorés par poste (`FormationType.couleurPourLabel`).

Ce qui bloque le passage au haut de gamme :

1. **Deux mondes de dessin étanches.** PencilKit (encre) et l'overlay vectoriel (objets) coexistent en couches séparées : deux gommes (`gomme` vs `suppression`), deux systèmes d'undo (le fallback `canvasCtrl.annuler()` dans `TerrainEditeurViewModel.annuler()` en témoigne), un toggle `afficherDessinLibre` pour cacher l'encre. Le coach doit comprendre l'architecture interne pour effacer un trait.
2. **Interaction modale.** `ModeDessin` compte 10 modes ; le sens d'un tap dépend du mode courant. C'est la source d'erreurs classique des éditeurs modaux (placer un joueur en croyant sélectionner, dessiner en croyant déplacer).
3. **Barre d'outils contraire à la direction artistique.** `BarreOutilsDessin` : 15+ boutons dans un ScrollView horizontal, accents cyan/vert/jaune/rouge simultanés, icône « pointillé » dessinée à la main dans un `Canvas` inline. C'est exactement ce que la directive « mat, sans symbole criard » condamne.
4. **Aucune sémantique volleyball dans les traits.** `ElementTerrain.TypeElement` distingue `fleche`/`trajectoire`/`rotation` mais rien ne dit si une flèche est une passe, une attaque ou un déplacement. Conséquences : pas de légende automatique, pas d'animation correcte possible (un joueur ne suit pas un arc de ballon), le coach compense en jonglant avec les couleurs — d'où la barre criarde.
5. **Pas de cadrage.** `aspectRatio` figé (2:1 paysage, 0.5 portrait), pas de zoom, pas de pan, pas de demi-terrain — alors que la majorité des exercices de volleyball se dessinent sur un demi-terrain. Tout est petit, tout le temps.
6. **Undo/redo vidé à chaque changement d'étape** (`chargerEtapeActive` fait `pileUndo.removeAll()`) : naviguer dans ses étapes détruit son historique.
7. **Bézier à un seul point de contrôle** (`ctrlX/ctrlY`) : impossible de dessiner une trajectoire en plusieurs temps (approche + appel + attaque).
8. **Présentation statique.** `PresentationTerrainView` = pages fixes, navigation par tiers d'écran. Aucune lecture animée, aucun pointeur.

### 1.2 La cible

#### a) Un seul monde : l'objet d'abord, l'encre en annotation

Principe : **taper et glisser manipulent toujours des objets ; l'encre PencilKit devient un calque « Annotation » par étape**, activé explicitement (crayon en main via Apple Pencil, ou outil Encre). Suppression d'objet et gomme d'encre fusionnent dans une seule gomme contextuelle : elle efface ce qu'elle touche, trait ou objet. Un seul undo unifié (le snapshot actuel contient déjà les deux — c'est l'UX qui doit suivre).

Le placement n'est plus un mode : une **étagère de jetons** (bord inférieur du terrain, verre discret) présente les objets à glisser sur le terrain :
- jetons génériques 1-6 (numérotation auto conservée),
- roster réel (numéro + initiales, couleur par poste — réutilise `joueursBD`),
- ballon,
- nouveaux objets « logistiques » : plot, cible (cerceau/zone à viser), panier de ballons — indispensables pour dessiner un vrai exercice et absents aujourd'hui.

Un glissement depuis l'étagère pose l'objet ; un glissement depuis un objet posé crée une trajectoire (voir c). Zéro mode, zéro erreur de mode.

#### b) Cadrage : le zoom qui a du sens

Pas de canvas infini. Un sélecteur de **cadrage** discret (coin supérieur du terrain) avec 4 presets :

| Preset | Usage | Ratio affiché |
|---|---|---|
| Terrain complet | systèmes 6v6, transition | 2:1 |
| Demi-terrain (nôtre) | réception, défense, la majorité des drills | 1:1 |
| Demi-terrain adverse | scouting, cibles de service | 1:1 |
| Zone filet | bloc, attaque, fixation | bande centrale |

Plus : pincer pour zoomer (1×–3×), pan à deux doigts, double-tap deux doigts pour revenir au preset. Le cadrage est **sauvegardé avec l'exercice** (nouveau champ `cadrage` dans `EtapeExercice`/l'exercice) — un drill de réception s'ouvre toujours cadré demi-terrain, grand et lisible. Le preset « Demi-terrain » devient le défaut à la création d'exercice.

#### c) Trajectoires sémantiques : la grammaire du volleyball

Le trait est défini par son **verbe**, pas par sa couleur. Quatre sémantiques, conventions des diagrammes de volleyball :

| Verbe | Style de trait | Animation |
|---|---|---|
| Déplacement (joueur) | pointillé fin | le jeton glisse le long du trait |
| Trajet du ballon (passe, relance) | plein fin, arc | le ballon suit l'arc |
| Attaque / service | plein épais, pointe pleine | le ballon suit, rapide |
| Rotation | flèche circulaire (existant) | pivot des 6 jetons |

L'app **infère le verbe** : tirer depuis un joueur = déplacement ; tirer depuis le ballon = trajet de ballon ; une pastille contextuelle apparaît à la relâche pour requalifier en un tap (Attaque, Service). Bénéfices en cascade : légende générée automatiquement sur le PDF et en présentation, animation correcte, re-théming par la couleur d'accent d'équipe (le style ne dépend plus de couleurs stockées en dur), et grammaire transposable à d'autres sports (section 5).

Les trajectoires deviennent **multi-segments** (liste de points avec courbure par segment, poignées visibles à la sélection, à la tldraw) — l'approche d'attaque en deux temps devient dessinable.

#### d) Manipulation : snapping, alignement, précision

- **Aimants de positions** : les 6 positions réglementaires (et les positions de la formation active) sont des cibles magnétiques ; l'aimantation déclenche une pulsation haptique (`UICanvasFeedbackGenerator`).
- **Guides d'alignement** à la Freeform : lignes fantômes quand un jeton s'aligne avec un autre ou avec l'axe du terrain ; distribution automatique de 3+ jetons sélectionnés.
- **Sélection multiple** au lasso (doigt maintenu) ou par rectangle — déplace un bloc de joueurs d'un geste.
- Numéro/label modifiable par tap long sur le jeton (popover), plus de mode dédié.

#### e) Étapes → timeline de frames, onion skin, duplication intelligente

La barre d'étapes actuelle (chips texte) devient une **timeline de miniatures** sous le terrain : chaque frame est rendue en vignette (le rendu miniature existe déjà — `TerrainMiniatureView`), réordonnable par drag, renommable inline.

- **Onion skin** : toggle « Fantôme » qui affiche la frame précédente à 25 % d'opacité sous la frame active — indispensable pour dessiner des continuités.
- **Duplication intelligente « Continuer »** (en plus du dupliquer actuel) : les **positions d'arrivée** des trajectoires de la frame N deviennent les **positions de départ** de la frame N+1 ; trajectoires et encre sont effacées. C'est la mécanique exacte de la pensée du coach (« et ensuite, ils vont là »). Aujourd'hui `dupliquerEtapeActive` copie tel quel — la moitié du travail.
- L'historique undo devient **par document, pas par étape** (correction du `removeAll()`).

#### f) Animation des systèmes — la signature

Chaque frame contient déjà tout ce qu'il faut : positions de départ (jetons) et chemins (trajectoires sémantiques). La lecture :

- **Interpolation** des jetons le long de leur trait de déplacement avec easing naturel (départ/arrivée amortis) ; le ballon suit son arc légèrement décalé dans le temps (le ballon part quand le passeur « touche ») ; durée par frame ~1,5 s par défaut, ajustable.
- **UX de lecture** : bouton Lecture dans la barre ; **scrubber** fin sous le terrain (glisser = avancer/reculer dans l'interpolation, exactement comme un lecteur vidéo) ; vitesses 0,5× / 1× / 2× ; **boucle** par frame ou enchaînée sur toutes les frames ; tap sur le terrain pendant la lecture = pause.
- **Techniquement** : rendu de l'overlay piloté par une horloge (`TimelineView`), aucune modification des données — l'animation est une *vue* des frames, pas un nouveau format. L'encre d'annotation reste statique (affichée en fondu au début de frame).
- **Phasage** (gouvernance solo-dev) : v1 = lecture in-app + mode présentation (~3 sem) ; v2 = export MP4 (`AVAssetWriter` hors-ligne, partage aux joueuses via messagerie) ; jamais de 3D.

#### g) Apple Pencil : la division du travail

- **Le doigt manipule, le crayon annote** (défaut Procreate, réglage disponible) : la main qui tient le crayon peut déplacer des jetons au doigt sans changer d'outil.
- **Hover** : ombre de l'outil avant contact ; les cibles d'aimantation s'illuminent discrètement à l'approche.
- **Squeeze** : palette radiale sous la pointe (épaisseur, encre/surligneur, couleur d'annotation) — la barre d'outils n'a plus besoin d'exposer ces réglages en permanence.
- **Double-tap** : bascule encre/gomme.
- **Haptique** : pulsation légère au snap d'un jeton, à l'accroche d'une poignée de courbure, au passage de frame.

#### h) La barre d'outils mat (direction « sans symbole criard »)

Le verre est le chrome ; l'outil est typographié et monochrome :

- **Une seule rangée fixe, 6 emplacements** : Sélection · Encre · Gomme · Formations · Cadrage · Lecture. Le débordement (verrouillage, zones, effacer tout, présentation) vit dans un tiroir « ··· ».
- Icônes SF Symbols en `primary` monochrome, poids regular. **L'état actif est une pastille pleine de la couleur d'accent de l'équipe** avec le libellé texte affiché (« Encre ») — la couleur signale l'état, jamais la fonction. Aucun cyan/jaune/rouge simultanés, aucune icône bricolée en Canvas.
- L'étagère de jetons (bas) est le deuxième foyer visuel ; les jetons y sont les seuls éléments colorés (couleurs de poste) — la couleur vit dans le *contenu*, pas dans le chrome. Cohérent avec « le verre = le chrome, jamais le contenu ».

#### i) Mode présentation repensé

- Plein écran noir mat, chrome disparu ; jetons et traits agrandis ~130 %, contraste AAA (réutilise l'esprit courtside).
- **Lecture animée** : tap = jouer la frame ; les contrôles (frame précédente / lecture / suivante) sont trois grandes zones discrètes en bas.
- **Pointeur laser éphémère** : glisser le doigt trace un trait lumineux qui s'évanouit en ~1 s sans rien écrire — le geste du coach devant l'équipe.
- AirPlay inchangé ; le scrubber reste disponible pour « rejouer juste ce moment-là ».

### 1.3 Migration technique (résumé)

`ElementTerrain` passe en `schemaVersion 2` : ajout `semantique` (deplacement/ballon/attaque/annotation), `points: [Point]` multi-segments (les champs `x/y/toX/toY/ctrlX/ctrlY` v1 restent décodables et migrent : `fleche` → déplacement, `trajectoire` → ballon). `EtapeExercice` gagne `cadrage` et `dureeAnimation`. Tout reste des blobs JSON dans les @Model existants — **aucune migration SwiftData/CloudKit risquée**, le pattern de décodage versionné (P1-03) est déjà en place.

---

## 2. Constructeur de séances 2.0

### 2.1 Critique de l'existant

`Seance` = nom + date + `[Exercice]?` ordonnés, `Exercice.duree` optionnelle. La création (`NouvelleSeanceView`) est un sheet nom + date. Il n'existe **ni blocs, ni objectifs, ni horloge cumulative, ni gabarits, ni notion de charge, ni mode exécution**. L'import depuis la bibliothèque se fait exercice par exercice via un mode « import » détourné de `BibliothequeView`. `PlanificationSaisonView` (phases + timeline + volume hebdo) existe et est une bonne fondation macro — mais rien ne relie une phase à ce qu'on fait mardi.

### 2.2 Le flow du dimanche soir — écran par écran

**Écran « Composer la séance »** (iPad paysage, le cœur du pilier) :

- **Colonne gauche (38 %) — le Playbook** : recherche, facettes de tags (section 3), rangée « Récents » et « Favoris », et une rangée intelligente « Pas vus depuis longtemps » (variété). Chaque carte : miniature du diagramme, nom, durée par défaut, pastille d'intensité.
- **Colonne droite (62 %) — la timeline de séance**, verticale, avec **heure réelle calculée** dans la gouttière : si la pratique commence à 18 h 00, chaque exercice affiche son heure de début (18 h 00, 18 h 12, 18 h 30…). Le drag & drop (API `draggable`/`dropDestination`) dépose une carte du Playbook dans la timeline ; la **durée s'ajuste en tirant le bord inférieur de la carte**, comme un événement de calendrier — le geste le plus naturel qui existe pour du temps.
- **Blocs de séance** : Activation · Technique · Systèmes · Jeu dirigé · Retour au calme (+ bloc libre renommable). Les blocs sont des en-têtes de section dans la timeline, repliables, avec sous-total de durée. Un exercice glissé hérite du bloc où il tombe.
- **Bandeau d'en-tête** : durée cible (90 min) avec jauge fine — passe à l'orange en dépassement ; **objectifs de séance** (1 à 3 tags, les mêmes que le Playbook) ; thème de la semaine hérité (voir 2.3).
- **Charge estimée** : chaque exercice porte une intensité 1-5 (héritée de sa fiche Playbook, ajustable) ; charge de séance = Σ intensité × durée, affichée en points avec une mini-courbe des 7 derniers jours — le coach voit qu'il empile trois grosses séances.

Techniquement : ajout de champs **CloudKit-safe** (défauts sur la déclaration) — `Exercice.bloc: String = ""`, `Exercice.intensite: Int = 3`, `Seance.objectifs: String = ""` (tags joints), `Seance.dureeCibleMinutes: Int = 0`, `Seance.gabaritSource: String = ""`. Pas de nouveau @Model pour les blocs : un bloc est un attribut d'exercice, l'ordre existant fait le reste. KISS.

### 2.3 Gabarits et microcycles

- **Gabarit de séance** : « Enregistrer comme gabarit » depuis n'importe quelle séance ; un gabarit = structure de blocs + durées + exercices (optionnels, remplaçables). « Mardi type » se crée en un tap depuis le calendrier — les `CreneauRecurrent` existants proposent automatiquement le gabarit associé au créneau.
- **Thème de semaine (microcycle)** : dans la vue Semaine du futur espace Préparer, chaque semaine porte un thème (« Réception + transition ») rattaché à la `PhaseSaison` englobante. Le thème pré-remplit les objectifs des séances de la semaine et alimente un compteur honnête : « 42 min sur la réception cette semaine ». Pas d'IA, pas de plan généré : un thème, un compteur, une suggestion sobre (« aucune séance ne travaille le service depuis 3 semaines »).
- `PlanificationSaisonView` devient la vue macro de cet ensemble : phases → semaines à thème → séances. Trois étages, chacun optionnel — un coach qui ignore tout ça garde une liste de séances qui marche.

### 2.4 Le papier vit encore dans les gymnases

Export **« Plan de pratique » PDF une page** (le PDFExportService existe déjà pour les matchs) :
- En-tête : équipe, date, thème, objectifs, durée.
- Corps en colonnes : heure · bloc · exercice · **diagramme miniature** (rendu des frames) · consignes/critères de réussite.
- Pied : liste des présences à cocher à la main.
- Typographie sobre, chiffres tabulaires, noir sur blanc — pensé pour une impression laser et une planchette. Deux taps : Partager → Imprimer. Le même PDF s'envoie aux assistants via la messagerie interne.

### 2.5 Mode exécution — le mardi soir

Bouton « Lancer la pratique » sur la séance du jour (et en carte héro dans Aujourd'hui) :

- Plein écran opaque type courtside : **gros chrono de l'exercice courant** (compte à rebours de sa durée), nom, diagramme (tap = plein écran + lecture animée), consignes ; la **carte suivante** est visible en bas (« Dans 4 min : Défense 3 contre 6 »).
- **Swipe = exercice suivant** ; l'écart au plan est absorbé : si on déborde de 3 min, l'app propose « Recaler » (répartit le retard sur le reste) ou « Couper le retour au calme ». Aucune culpabilisation, juste l'heure de fin projetée.
- Boutons discrets : **Cocher** (fait), **Sauter**, **Note** (dictée ou 3 mots — stockée sur l'exercice de la séance), **Présences** en entrée de pratique (réutilise `PresencesView`).
- Si la **capture vidéo** est active (section 3.4) : le swipe d'exercice pose automatiquement le tag `debut_exercice` — le découpage en clips ne coûte aucun geste.
- Fin de pratique : écran résumé (durées réelles vs planifiées, exercices sautés, notes) ; « Envoyer au brouillon de la prochaine séance » transforme les notes à chaud en points de départ du dimanche suivant.

---

## 3. Playbook 2.0 (Bibliothèque unifiée)

### 3.1 Critique de l'existant

`BibliothequeView` : catégorie unique par exercice (8 prédéfinies + `CategorieExercice` perso), recherche sur le nom seulement, scoping par `codeCoach`, export/import JSON fonctionnel mais brut, favoris. Les stratégies (`StrategiesView`) et formations (`FormationsView`) vivent ailleurs — trois bibliothèques mentales pour le même contenu de coaching. La fiche exercice n'a ni critères de réussite, ni variantes, ni matériel, ni média.

### 3.2 Organisation : des tags à facettes, pas des dossiers

Le Playbook (déjà acté dans la vision : fusion bibliothèque + stratégies + formations) contient trois types d'objets — **Exercice, Système, Formation** — sous une seule recherche. La catégorie unique devient un jeu de **tags à facettes** :

| Facette | Valeurs |
|---|---|
| Habileté | service, réception, passe, attaque, bloc, défense, transition |
| Format | 1v1 … 6v6, vagues, stations |
| Intensité | 1–5 |
| Matériel | nb ballons, plots, cibles |
| Niveau | initiation → élite |

Les `CategorieExercice` existantes migrent en tags (mapping mécanique). La recherche combine texte + facettes en chips ; les objectifs pédagogiques de séance (2.2) et les thèmes de semaine (2.3) parlent la même langue de tags — c'est ce qui rend le compteur « minutes par habileté » possible.

### 3.3 Fiche exercice riche et création rapide

- **Fiche** : diagramme multi-frames animé en tête (lecture au tap), consignes, **critères de réussite** (« 10 réceptions dans la cible d'affilée »), **variantes** (plus facile / plus difficile — liens vers d'autres exercices), matériel, intensité, durée par défaut, statistiques d'usage (« utilisé 4 fois cette saison, dernière fois le 12 juin »), et la zone Vidéo (3.4).
- **Création rapide** : depuis la timeline de séance, « Nouvel exercice » ouvre directement le Terrain 2.0 cadré demi-terrain avec la dernière formation utilisée ; nom suggéré depuis les tags choisis. Un exercice dessinable en moins d'une minute — sinon le coach retourne au papier.
- **Import/export entre coachs** : le JSON existant évolue en format `.playco` (JSON zippé + vignettes), partage AirDrop/ShareLink ; à terme sur la fondation Supabase, un partage par code entre coachs du même club (respect strict de la frontière de confiance pédagogique : rien ne remonte au club sans action explicite du coach).
- **Contenu par défaut** : 50 exercices signés Playco, diagrammes multi-frames aux conventions sémantiques, français impeccable, couvrant les 7 habiletés × 3 niveaux — refonte de `BibliothequeDefauts`/`DiagrammesBibliotheque` au nouveau standard. C'est un argument d'onboarding et de fiche App Store, pas un remplissage.

### 3.4 L'intégration vidéo (plan Supabase/Stream validé — pratiques v1)

**Où vivent les clips.** Deux ancrages, tous deux dans des objets déjà familiers :
1. **Fiche Playbook → « Démo »** : un clip canonique choisi par le coach (la meilleure exécution jamais captée, ou un import) — la référence montrée aux joueuses.
2. **Fiche Playbook et fiche Séance → « Dernières exécutions »** : les clips auto-découpés des pratiques, rattachés à la fois à l'exercice (via l'ID posé par le tag `debut_exercice`) et à la séance. Pas de section « Vidéo » dans l'app : la vidéo est une propriété du contenu de coaching.

**UX de capture (mardi)** : iPad sur trépied, « Filmer la pratique » depuis le mode exécution. Bandeau REC discret (point rouge, seule occurrence du rouge hors live, conforme au système). Par-dessus l'aperçu, des **boutons de tag façon `PaveNumeriqueRapideView`** : « Moment » (temps fort générique), grille de numéros de joueuses (tag joueur), et le tag `debut_exercice` **posé automatiquement par le swipe d'exercice** du mode exécution — la capture ne coûte aucun geste supplémentaire au coach seul dans son gymnase. Tout fonctionne hors-ligne : tags en local, **file d'upload** (pattern `JournalSyncStorage`), TUS reprise en tâche de fond une fois le wifi retrouvé. La vidéo ne transite jamais par CloudKit.

**UX de revue (mercredi)** : carte « 14 clips — pratique de mardi » dans Aujourd'hui ; grille de clips groupés **par exercice**, filtre par joueuse. Sur un clip : lecture HLS, **pause → Annoter** : la frame se fige et reçoit exactement les outils du Terrain 2.0 (trajectoires sémantiques + encre — réutilisation directe de `CanvasDessinView`/`OverlayDessinView`, l'annotation est un `[ElementTerrain]` + PKDrawing sérialisés dans `video_annotations`). **Partage ciblé** à une joueuse en deux taps (RLS Supabase ; les athlètes ne sont jamais bloquées par le paywall — la vidéo est gated côté coach par le tier Élite via `FeatureGating`).

**Fermeture de boucle** : sur un clip, « Ajuster l'exercice » ouvre la fiche Playbook ; « Reprogrammer » l'ajoute au brouillon de la prochaine séance.

---

## 4. La boucle complète — une semaine de coaching, écran par écran

**Dimanche 20 h — Préparer.**
1. Espace Préparer → vue Semaine ; le créneau du mardi propose « Créer depuis Mardi type » (gabarit lié au `CreneauRecurrent`). 1 tap : blocs, durées et heures sont posés, objectifs pré-remplis par le thème de semaine (« Réception »).
2. Écran Composer : 3 exercices du gabarit conservés ; 2 exercices glissés depuis le panneau Playbook (facette Réception, rangée « Pas vus depuis longtemps ») ; 1 nouvel exercice créé en 50 s dans le Terrain 2.0 (demi-terrain, formation R1 en 2 taps, 3 trajectoires inférées, duplication « Continuer » pour la frame 2).
3. Jauge : 92 min / 90 — le bord d'une carte est remonté de 5 min. Export PDF → impression pour la planchette. Fermé en 15 minutes.

**Mardi 18 h — Exécuter et capturer.**
4. Aujourd'hui → carte héro « Pratique 18 h » → Lancer la pratique. Présences en entrée (8 taps). iPad sur trépied, « Filmer » activé.
5. Chrono par exercice ; au tap sur le diagramme, **lecture animée** projetée du système de réception — 20 secondes d'explication au lieu de 2 minutes de discours. Swipe = exercice suivant = tag `debut_exercice` silencieux. Deux tags « Moment » posés à la volée, une note dictée (« passe trop basse en R4 »). Débordement de 4 min absorbé par « Recaler ».
6. Fin : résumé, notes envoyées au brouillon du jeudi. Les uploads partent tout seuls sur le wifi de la maison.

**Mercredi midi — Revoir.**
7. Aujourd'hui → « 14 clips — pratique de mardi ». Groupés par exercice ; le clip du nouvel exercice de réception, filtré sur la joueuse #7, est annoté (frame figée, flèche de déplacement corrigée dessinée dessus) et partagé à #7. 4 taps + l'annotation.
8. Sur le clip : « Reprogrammer » → l'exercice est déjà dans le brouillon de jeudi, avec la note de mardi attachée.

**Jeudi/dimanche — Ajuster.**
9. Le brouillon de jeudi s'ouvre avec : notes à chaud de mardi, exercice reprogrammé, compteur « Réception : 42 min cette semaine ». Le cycle recommence — chaque pilier alimente le suivant, aucune saisie n'est demandée deux fois.

C'est la boucle : **préparer → exécuter → capturer → revoir → ajuster**, où la vidéo n'est pas un produit à côté mais la preuve qui circule entre les trois piliers.

---

## 5. Multi-sport ready

Ce que le `SportPack` doit fournir (et ce que l'éditeur ne doit jamais coder en dur) :

| Fourni par le SportPack | Exemple volleyball (actuel) |
|---|---|
| `dessinerTerrain` (Canvas) + ratio | `TerrainVolleyView`, 2:1, indoor/beach |
| **Presets de cadrage** | complet / demi / zone filet |
| Positions nommées + aimants | zones 1–6, positions de formation |
| Formations | 5-1, 4-2, 6-2, beach (`FormationTypes`) |
| **Verbes de trajectoires** | déplacement / ballon / attaque / rotation |
| Objets d'étagère | ballon, plot, cible, panier |
| Taxonomie d'habiletés (tags) | service, réception, passe… |
| Blocs de séance par défaut | activation → retour au calme |

Généralisable tel quel (aucune dépendance volleyball) : le moteur d'objets et de frames, le snapping/guides, l'animation par interpolation, l'encre d'annotation, la timeline de séance avec horloge et blocs, le Playbook à facettes, toute la chaîne vidéo (capture, tags, clips, annotation). Volleyball-spécifique et encapsulé : rotations R1–R6, systèmes, zones statistiques, le verbe « attaque/service ».

Conséquences concrètes sur le design de l'éditeur : (1) l'étagère de jetons est **déclarée par le SportPack**, pas dessinée en dur dans la barre ; (2) les verbes de trajectoire sont une **liste fournie**, l'inférence « depuis un joueur = déplacement, depuis le ballon = trajet d'objet » est générique ; (3) le cadrage est une liste de rectangles normalisés — un SportPack basketball fournirait « demi-terrain offensif » sans toucher l'éditeur. Le beach actuel (`TypeTerrain`) prouve déjà la moitié de cette paramétrisation ; il devient le premier « pack » du système.

---

## 6. Les 5 décisions produit les plus importantes

1. **L'objet avant l'encre — un seul monde.** Fin des 10 modes de `ModeDessin` : taper/glisser manipule toujours des objets, l'étagère remplace les modes de placement, l'encre PencilKit devient un calque d'annotation, une seule gomme, un seul undo. C'est la décision fondatrice ; tout le reste (animation, hover, snapping) s'appuie dessus.
2. **Trajectoires sémantiques (verbes) plutôt que styles cosmétiques.** Le trait porte son sens : légende automatique, animation correcte, re-théming par l'accent d'équipe, barre d'outils mat possible (plus besoin de 7 couleurs pour distinguer les traits), et grammaire multi-sport. Migration `ElementTerrain` v2 en JSON, zéro risque CloudKit.
3. **L'animation comme signature — phasée, jamais 3D.** v1 lecture in-app + présentation (~3 sem), v2 export MP4. C'est la fonctionnalité la plus démontrable en vente (leçon TacticalPad/XPS) et elle tombe presque gratuitement une fois la décision 2 prise. Respecte la règle « un seul pari > 6 sem/an » en restant sous le seuil.
4. **La séance devient structurée par ajouts, pas par refonte** : blocs, intensité, objectifs, durée cible = champs à défauts CloudKit-safe sur `Seance`/`Exercice` ; gabarits liés aux créneaux ; thème de semaine posé sur `PhaseSaison` existant. Le coach qui ignore tout ça garde exactement son app actuelle.
5. **La vidéo vit dans le Playbook et la séance, pas dans une section « Vidéo ».** Le clip est une propriété de l'exercice (démo) et de son exécution (preuve) ; le tag `debut_exercice` est posé par le geste que le coach fait déjà (swipe d'exercice). La friction de capture tend vers zéro — condition de survie de la feature pour un coach seul dans un gymnase.

---

## 7. Trois flows chiffrés en taps (avant → après)

**Flow A — Dessiner un exercice de réception en R1 (demi-terrain, 3 déplacements, 1 trajet de ballon)**

| | Avant | Après |
|---|---|---|
| Ouvrir l'éditeur depuis la séance | 3 taps (séance → + exercice → ouvrir) | 1 tap (« Nouvel exercice » dans la timeline, cadré demi-terrain d'office) |
| Poser la formation R1 | 2 taps (panneau formations) | 2 taps (identique — déjà bon) |
| Placer le ballon | 2 (mode Ballon + tap) | 1 drag (étagère) |
| 3 déplacements + 1 trajet ballon distingués | ~9 (mode flèche, 2 changements de couleur, 4 tracés, retour curseur) | 4 drags (verbes inférés, zéro couleur) |
| Nommer | 2 | 0 (suggestion par tags, validation au retour) |
| **Total** | **~18 interactions**, terrain complet illisible | **~8 interactions**, demi-terrain lisible et animable |

**Flow B — Préparer la séance du mardi (90 min, 6 exercices dont 1 nouveau)**

| | Avant | Après |
|---|---|---|
| Créer la séance | 4 (+, nom, date, créer) | 1 (« Créer depuis Mardi type » sur le créneau) |
| 4 exercices de bibliothèque | ~16 (mode import : 4 × naviguer/chercher/taper) | 4 drags (panneau latéral, facettes) |
| 1 exercice nouveau | ~18 (flow A avant) | ~8 (flow A après) |
| Durées (6 exercices) | ~12 (éditer chaque exercice) | ~3 (tirer le bord de 3 cartes, les autres héritent du gabarit) |
| Ordre | 4 drags | 0 (blocs du gabarit) |
| Objectifs / horloge / impression | inexistant | +2 taps (PDF) |
| **Total** | **~54 interactions**, sans horloge ni papier | **~18 interactions**, avec horloge, objectifs et PDF |

**Flow C — Revoir les clips d'une joueuse après la pratique et lui envoyer une correction**

| | Avant | Après |
|---|---|---|
| Retrouver le moment | impossible (aucune vidéo dans Playco ; caméra tierce = des minutes de scrubbing) | 2 taps (carte « clips de mardi » → filtre joueuse) |
| Voir le clip du bon exercice | — | 1 tap (groupé par exercice) |
| Annoter la frame | — | 1 tap + dessin (outils du terrain) |
| Envoyer à la joueuse | — | 2 taps (partage ciblé RLS) |
| **Total** | **impossible** | **6 taps + un dessin** |

---

## Sources

- [Sportplan — Volleyball Session Planner](https://www.sportplan.net/drills/Volleyball/Volleyball-Session-Planner.jsp) · [Sportplan — Volleyball Drills](https://www.sportplan.net/drills/Volleyball/index.jsp) · [Sportplan — Coaching Apps](https://www.sportplan.net/drills/Volleyball/Volleyball-Coaching-App.jsp)
- [XPS Network — Volleyball](https://sidelinesports.com/sport/volleyball/) · [XPS — Creating Animations in Playbook](https://sidelinesports.com/blog/xps-tutorial-creating-animations-in-playbook/) · [XPS — Creating Diagrams in Playbook](https://sidelinesports.com/blog/xps-tutorial-creating-diagrams-in-xps-playbook/) · [XPS — All Features Walkthrough](https://sidelinesports.com/blog/xps-walkthrough-all-features-in-one-video/)
- [TacticalPad](https://www.tacticalpad.com/new/index.php) · [TacticalPad Coach's Whiteboard (App Store)](https://apps.apple.com/us/app/tacticalpad-coachs-whiteboard/id512949303)
- [planet.training — Volleyball](https://planet.training/volleyball) · [VolleyballXL — Training Plans](https://volleyballxl.com/volleyball-training-plan/) · [TeamSnap — Volleyball](https://www.teamsnap.com/teams/sports/volleyball) · [Waresport — Volleyball Software 2026](https://www.waresport.com/blog/best-volleyball-club-management-software)
- [The Art of Coaching Volleyball — 4-week practice plan](https://www.theartofcoachingvolleyball.com/4-week-practice-plan/) · [AOC — Coaches Planner](https://store.theartofcoachingvolleyball.com/shop/volleyball-coaches-planner/) · [Volleyball Canada — Development Matrix (LTAD)](https://volleyball.ca/uploads/About/LTAD/VDM_May_8_2023_EN.pdf) · [TrainingPeaks — Macro/Meso/Microcycles](https://www.trainingpeaks.com/blog/macrocycles-mesocycles-and-microcycles-understanding-the-3-cycles-of-periodization/) · [CoachRx — Planning & Periodization Tools](https://www.coachrx.app/articles/planning-amp-periodization-tools-to-design-better-programs)
- [tldraw](https://tldraw.dev/) · [tldraw (GitHub)](https://github.com/tldraw/tldraw) · [Apple Freeform (App Store)](https://apps.apple.com/us/app/freeform/id6443742539) · [Concepts vs Freeform](https://concepts.app/en/freeform-vs-concepts-app/) · [Storyflow — Best Infinite Canvas Tools 2026](https://storyflow.so/blog/best-infinite-canvas-tools-2026)
- [Onform](https://onform.com/) · [Onform vs Hudl Technique](https://onform.com/blog/onform-vs-hudl-technique/) · [Onform — Three New Tools](https://onform.com/blog/three-new-tools-that-make-coaching-faster-clearer-and-more-connected/) · [Onform — iOS User Guide](https://support.onform.com/article/153-user-guide-onform-video-analysis-app)
- [Apple — Squeeze the most out of Apple Pencil (WWDC24)](https://developer.apple.com/videos/play/wwdc2024/10214/) · [Apple Pencil Pro — Tech Specs](https://support.apple.com/en-us/120123) · [Procreate — Apple Pencil Pro](https://help.procreate.com/articles/LA4SAi-apple-pencil-pro-procreate) · [Paperlike — Pencil Pro Workflow](https://paperlike.com/blogs/paperlikers-insights/apple-pencil-pro-for-artists)
