# PLAYCO MAT — Langage visuel de Playco 3.0
## Spécification de direction artistique (passe 2 — juillet 2026)

> Livrable de design. Mode lecture seule — aucun fichier modifié. Fondé sur l'audit du code actuel (`ThemeCouleurRole.swift`, `LiquidGlassKit.swift`, `TerrainVolleyView.swift`) et sur une recherche en ligne dédiée (références citées en fin de document).

---

## 0. Ce que dit la recherche (synthèse avant doctrine)

Cinq signaux convergents ressortent de la veille 2025-2026 :

1. **La typographie devient le héros.** Les identités primées de 2026 (Fontfabric, travaux Studio Dumbar / Smith & Diction pour Perplexity) traitent le texte comme l'image : le titre EST l'interface, la grille typographique se substitue à la décoration. C'est exactement la voie « sans symbole » demandée.
2. **La fin des théâtralités visuelles.** Envato et Tubik nomment la tendance dominante « calm interfaces » : moins d'effets, plus de lisibilité, la retenue comme marqueur de gamme. Le glassmorphism lui-même se replie : même ses défenseurs (Clay, Tim Graf) prescrivent désormais le verre **sélectif** — overlays et chrome seulement, contenu plat et opaque.
3. **Liquid Glass est contesté sur la lisibilité.** NN/g titre « Liquid Glass Is Cracked » ; Infinum mesure des contrastes à 1,5:1 (norme : 4,5:1) ; Apple a dû ajouter un réglage de transparence. Faire du **mat** n'est pas être en retard sur iOS 26 : c'est être en avance sur sa correction.
4. **Le luxe silencieux est codifié.** Les meilleures interfaces bancaires privées (UXDA, Eleken) reposent sur : neutres graphite/crème, un seul accent utilisé « comme un bijou, pas comme de la peinture », données à fort contraste, espaces généreux. Le sentiment produit : « je me sens en sécurité ici ».
5. **Les chiffres alignés sont un standard professionnel.** Chiffres tabulaires obligatoires dès qu'on compare des valeurs (TypeType, guide data tables de Molly Hellmuth) — c'est le vocabulaire du rapport financier et du tableau de marque broadcast, pas celui de l'app grand public.

Contre-référence : **TeamSnap** assume un style « léger et doux » orienté familles ; **Hudl** est un outil vidéo à l'identité corporate saturée. Aucun acteur du sport amateur n'occupe le territoire « document éditorial de précision ». Il est libre. On le prend.

Références de calibre pour la retenue : **Things 3** (hiérarchie purement typographique), **Flighty** (ADA Interaction — densité d'information sans bruit, chiffres monospacés), **Linear** (gris quasi monochromes, un accent), **Teenage Engineering / Braun-Rams** (« Weniger, aber besser » : chaque élément gagne sa place ou disparaît).

---

## 1. Positionnement esthétique

### Nom de l'identité : « PLAYCO MAT — La feuille de match »

Trois adjectifs : **Éditorial. Exact. Calme.**

### Manifeste (5 lignes)

> Playco n'est pas une app de sport. C'est l'instrument de travail d'un coach.
> Chaque écran se lit comme un document imprimé avec soin : de l'encre sur du papier, des chiffres qui tombent juste, des traits qui veulent dire quelque chose.
> Rien ne brille, rien ne clignote, rien ne décore. Ce qui reste a une fonction.
> La seule couleur qui compte est celle de l'équipe ; le seul rouge est celui du direct.
> Le calme de l'interface, c'est le respect du travail du coach.

### Reconnaissabilité immédiate face à TeamSnap / Hudl / VBStats

Eux font du « sport app » : couleurs criardes, icônes partout, gradients énergiques, badges, confettis. Playco se reconnaît en une demi-seconde par quatre invariants qu'aucun concurrent ne possède :

| Invariant | Description |
|---|---|
| **Le papier** | Fond grège chaud, jamais blanc pur, jamais de gradient d'ambiance. On croit toucher une feuille. |
| **Le trait** | Le terrain dessiné comme un plan d'architecte : lignes fines, surface mate, zéro texture illustrative. C'est le logo vivant de l'app. |
| **La colonne de chiffres** | Chiffres tabulaires alignés à droite, totaux soulignés d'un double filet comptable. Une esthétique de rapport annuel appliquée au volleyball. |
| **La tab bar typographique** | Cinq glyphes au trait dérivés de la géométrie du terrain + étiquettes. Personne d'autre n'a ça. |

Positionnement en une phrase : **« Si Hudl est ESPN, Playco est Monocle. »**

---

## 2. Doctrine sans-symbole

### Principe : trois castes d'images, deux sont interdites

1. **Icône décorative** (accompagne un titre, « égaye » une carte, illustre un état vide) → **INTERDITE**. Un état vide se traite par une phrase bien composée et un bouton, pas par un pictogramme géant.
2. **Icône métaphorique de navigation** (la flamme pour « populaire », l'éclair pour « rapide ») → **INTERDITE**. La navigation se lit, elle ne se devine pas — la recherche (NN/g « Icon Usability », WebDesignerDepot) confirme que les icônes sans étiquette échouent hors des 5-6 standards universels.
3. **Icône fonctionnelle** (elle EST l'action ou l'affordance) → **AUTORISÉE**, dans une liste fermée.

### La liste fermée des glyphes fonctionnels (12)

`chevron` (disclosure), `croix` (fermer), `plus` (créer), `partage` (share sheet système), `lecture/pause` (média), `recherche` (loupe), `coche` (sélection dans menus/pickers), `poubelle` (destruction, toujours accompagnée du mot), `flèche retour` (navigation système), `œil` (visibilité), `cadenas` (verrouillage terrain), `personne` (avatar de secours). Tout ajout à cette liste passe par une revue de design, pas par un commit.

**Style de ces glyphes** : SF Symbols en rendu **monochrome uniquement** (`.symbolRenderingMode(.monochrome)` — le `.hierarchical` actuel est déprécié comme effet décoratif), graisse alignée sur le texte adjacent (`.regular` avec Corps, `.medium` avec Corps fort), taille = hauteur de capitale du texte voisin, couleur = encre ou encre secondaire, **jamais** teintés à la couleur d'accent sauf s'ils sont l'action principale.

### La tab bar : le cas frontière, résolu

La `TabView .sidebarAdaptable` (décision Vision 3.0) exige des images. On ne triche pas avec le système : on crée **cinq glyphes maison au trait**, symboles custom dessinés sur la grille optique SF, mono-trait 1,5 pt, géométrie pure dérivée du terrain — pas des métaphores, des **plans** :

| Espace | Glyphe | Construction |
|---|---|---|
| Aujourd'hui | Le point du jour | Un disque plein 3 pt posé sur une ligne de base horizontale |
| Préparer | Le plan | Grille de 2×3 traits (le plan de séance vu de haut) |
| Coacher | Le terrain | Rectangle 2:1 au trait avec ligne centrale (le device de marque) |
| Analyser | La mesure | Trois ticks verticaux de hauteurs croissantes sur une ligne de base |
| Équipe | La rotation | Six points disposés aux positions 1-6 du terrain |

Toujours accompagnés de leur étiquette (le HIG et la recherche NN/g concordent : étiquette systématique). Ces cinq glyphes sont les **seules** images « identitaires » de l'app — et elles sont si abstraites qu'elles fonctionnent comme de la typographie.

### Règle d'or (applicable en revue de code)

> **« Masque l'image. Si l'écran perd une action ou une information, elle est fonctionnelle : elle reste. S'il reste compréhensible, elle est décorative : elle disparaît. »**
> Vérification mécanique : toute `Image(systemName:)` hors de la liste des 12 + les 5 glyphes de tab bar = défaut bloquant.

---

## 3. Typographie — le système porteur

### Familles

- **SF Pro** (Display/Text, bascule optique automatique) : TOUT le produit. C'est « la police style Apple » demandée — et sa version droite, pas la `.rounded` actuelle, **qu'on retire intégralement** : l'arrondi est sympathique, donc hors gamme.
- **New York : non retenu.** Le serif éditorial est tentant mais introduirait une deuxième voix ; la sobriété Apple se joue à une seule famille. (Réévaluable un jour pour l'export PDF de scouting, jamais pour l'UI.)
- **SF Mono** : réservé aux **codes** (code d'équipe, code d'invitation) — l'esthétique du billet d'embarquement, façon Flighty. Nulle part ailleurs.
- **Chiffres** : SF Pro en **figures tabulaires** (`.monospacedDigit()`) partout où deux nombres peuvent se comparer. C'est déjà une décision arbitrée (Vision 3.0) — elle devient une loi (§10).

### Échelle typographique nommée (tokens, base Dynamic Type `large`)

| Token | Taille/Interligne | Graisse | Tracking | Rôle |
|---|---|---|---|---|
| **Affiche** | 40/44 (iPad 48/52) | Bold | −0,8 pt | Titre d'écran éditorial |
| **Score** | 76/76 (courtside 96) | Heavy, tabulaire | 0 | Score live uniquement |
| **Titre 1** | 28/34 | Semibold | −0,4 pt | Titre de zone |
| **Titre 2** | 22/28 | Semibold | −0,2 pt | Carte, adversaire |
| **Corps** | 17/24 | Regular | 0 | Texte courant |
| **Corps fort** | 17/24 | Semibold | 0 | Emphase, totaux |
| **Détail** | 15/20 | Regular | 0 | Métadonnées |
| **Donnée** | 15/20 | Medium, tabulaire | 0 | Cellules de stats |
| **Note** | 13/18 | Regular | 0 | Légendes, aide |
| **Étiquette** | 11/13 | Semibold | +0,6 pt, **MAJUSCULES** | En-têtes de section, axes, contexte |
| **Code** | SF Mono 15/20 | Medium | +0,5 pt | Codes équipe/invitation |

### Hiérarchie éditoriale : l'écran comme document

Chaque écran suit la structure d'une page de magazine de référence :
1. **Surtitre** en Étiquette (le contexte : « SAISON 2026 — ÉLANS ») ;
2. **Titre** en Affiche ;
3. **Chapô** en Note (une ligne, facultative) ;
4. Sections ouvertes par Étiquette + filet fin — jamais par une icône, jamais par une couleur de fond.

La casse : les MAJUSCULES sont réservées au token Étiquette (avec son tracking élargi — c'est ce qui les rend élégantes plutôt que criardes) et aux boutons courtside. Interdiction de `.uppercased()` manuel ailleurs.

**Dynamic Type** : chaque token mappe un `Font.TextStyle` système (Affiche→`.largeTitle`, Donnée→`.subheadline`, etc.) et les dimensions de composants passent par `@ScaledMetric`. Le mode courtside fixe un plancher (jamais en dessous de la taille de base) mais suit l'agrandissement.

---

## 4. Couleur & matière MAT

### Doctrine : l'encre, le papier, une seule couleur

La palette actuelle a quatre couleurs de section (orange/bleu/vert/violet). C'est quatre fois trop : c'est le code visuel des apps grand public. Playco Mat n'a que **des neutres chauds + la couleur de l'équipe + deux rouges de fonction**.

### Neutres — mode clair « Papier »

| Token | Hex | Rôle |
|---|---|---|
| `fond` | `#F6F4F1` | Fond d'app — grège papier, jamais blanc pur |
| `surface` | `#FFFFFF` | Cartes et tableaux (le seul blanc, en contraste avec le fond) |
| `surfaceCreuse` | `#EFECE7` | Champs, zones inset, pistes de graphique |
| `encre` | `#1A1918` | Texte principal — noir chaud, pas #000 |
| `encre2` | `#55524D` | Secondaire |
| `encre3` | `#8B8781` | Tertiaire, désactivé |
| `filet` | `#E4E1DB` | Hairlines (0,5 pt) |

### Neutres — mode sombre « Ardoise »

| Token | Hex |
|---|---|
| `fond` | `#121110` |
| `surface` | `#1C1B19` |
| `surfaceCreuse` | `#262421` |
| `encre` | `#F1EFEA` |
| `encre2` | `#A5A19A` |
| `encre3` | `#6E6A64` |
| `filet` | `#2E2C28` |

### L'accent : la couleur de l'équipe, matifiée

L'unique accent est la couleur d'équipe (décision arbitrée), passée par un **algorithme de matification** : saturation plafonnée à ~62 %, luminance contrainte dans une fenêtre garantissant 4,5:1 sur `surface` claire ET sombre (deux variantes calculées). L'accent sert : action principale, éléments « nous », sélection, progression. Il ne sert **jamais** : aux fonds pleins d'écran, aux titres, aux icônes fonctionnelles. Accent par défaut (aucune équipe) : `#3D5A80` (bleu ardoise).

### Sémantiques

| Fonction | Clair | Sombre | Redondance de forme (daltonisme) |
|---|---|---|---|
| **Live** | `#D9382E` | `#E0473D` | Pastille pleine + le mot « DIRECT » — le rouge n'est jamais seul |
| **Nous** | accent équipe | accent (variante sombre) | Barres/jetons **pleins** |
| **Adversaire** | `#6E6A64` graphite | `#8B8781` | Barres/jetons **au contour** (jamais hachures : bruit) |
| **Victoire** | pastille pleine encre, lettre « V » | idem | Plein vs creux |
| **Défaite** | pastille au contour, lettre « D » | idem | — |
| **Delta positif** | `#3E8E6C` | `#4FA37E` | Signe « + » toujours imprimé |
| **Delta négatif** | `#C05B52` | `#D4726A` | Signe « − » toujours imprimé |

Aucune information n'est portée par la couleur seule — toujours doublée d'une forme, d'un signe ou d'un mot.

### La matière : faire du mat DANS iOS 26 sans paraître daté

La règle Vision 3.0 « le verre = le chrome, jamais le contenu » est durcie en doctrine de matière :

1. **Le verre est délégué au système.** Tab bar, toolbars, sheets : matériaux natifs iOS 26, non teintés. On ne combat pas la plateforme, on la laisse gérer son chrome — c'est ce qui évite l'effet « app d'un autre OS ».
2. **Tout le contenu est opaque.** Cartes = `surface` pleine + filet 0,5 pt. Zéro `ultraThinMaterial`, zéro `.glassEffect` sur le contenu, zéro teinte translucide. C'est précisément la prescription des analyses NN/g/Infinum et du glassmorphism « mature » (verre sélectif).
3. **La profondeur vient du papier, pas de l'ombre.** Trois niveaux seulement : `fond` (0), `surface` (1, séparée par contraste + filet, ombre quasi nulle `0.04/8/2`), `flottant` (2 : modales, popovers, pavé live — seule ombre réelle `0.10/24/10`). Fini les doubles ombres de GlassCard.
4. **Aucun gradient d'ambiance.** Les doubles RadialGradient d'AccueilView disparaissent. Le fond est une couleur. Point.
5. **Le grain : non, sauf un endroit.** Un grain de 2 % pourrait vendre le « papier », mais c'est un risque de kitsch et un coût GPU. Verdict : fonds UI 100 % unis ; un grain statique subtil est toléré uniquement sur la surface du terrain (voir §7), où il évoque le matériau du sol.

### Mode gymnase (courtside)

Fond `#000000` pur, encre `#FFFFFF`, accent en variante éclaircie ≥ 7:1 (AAA — décision arbitrée), **interdiction totale de matériaux et d'opacités < 1**, cibles 60 pt conservées, Score à 96 pt. C'est le mode le plus mat de l'app : un tableau de marque.

---

## 5. Espace, grille, profondeur

- **Trame 4 pt conservée** (XS 4 / SM 8 / MD 16 / LG 24 / XL 32 / XXL 40) — elle est saine ; on ajoute **marges d'écran** : iPhone 20 pt, iPad 32 pt (compact) / 40 pt (regular), et une **largeur de lecture max 680 pt** sur iPad (un document ne s'étale pas sur 13 pouces).
- **Rayons réduits et unifiés** : 6 (champs, chips, pastilles), 10 (cartes, boutons), 14 (feuilles, panneaux flottants) — tous `style: .continuous`. L'échelle actuelle 12/16/22/28 est trop bulbeuse pour un langage éditorial ; les coins plus tenus rapprochent la carte de la fiche imprimée.
- **Bordures** : filet 0,5 pt (`filet`) sur toute `surface` posée sur `fond`. Le filet remplace l'ombre comme définisseur de bord — c'est lui qui donne le fini « imprimé ».
- **Filets typographiques** : séparateurs horizontaux uniquement (jamais de grilles verticales dans les tableaux), pleine largeur de la carte, et le **double filet comptable** au-dessus des totaux (signature maison).
- **Densité iPad vs iPhone** : iPhone privilégie le confort (rangées de liste 52 pt, une donnée-clé par rangée) ; iPad privilégie la densité d'analyse (rangées de tableau 40 pt, colonnes multiples) — le même document en édition de poche et en grand format.

---

## 6. Motion — doctrine du calme

Le vocabulaire spring existant est bon et **conservé tel quel** : défaut `0.35/0.85`, rebond `0.25/0.7` (press states uniquement), douce `0.45/0.9` (transitions d'écran). Ce qui change, c'est la loi d'usage :

1. **Rien ne bouge sans cause utilisateur.** Aucune animation ambiante, aucun `repeatForever`, aucun shimmer, aucun parallaxe. L'indicateur « DIRECT » ne pulse pas : il est rouge, c'est suffisant.
2. **Les chiffres roulent, les cadres jamais.** `.contentTransition(.numericText())` sur toute valeur qui change (déjà en place — devient obligatoire) ; les conteneurs, le score courtside, le terrain et la tab bar ne changent **jamais** de position d'eux-mêmes.
3. **Press state unique** : scale 0,98 + opacité 0,88, spring rebond. Un seul, partout.
4. **Durée plafond 350 ms.** Toute transition perceptible au-delà est un bug.
5. **Chargements** : fondu d'opacité simple sur placeholders fixes — pas de squelettes dansants.
6. **`accessibilityReduceMotion`** : bascule tout en cross-fade 150 ms.

---

## 7. Le terrain comme signature — « Le Trait »

Le rendu actuel (parquet beige texturé lignes par lignes, zones 3 m brun foncé, sable à grains pré-calculés) est illustratif : il imite un gymnase. La direction 3.0 l'élève au rang de **plan d'architecte** — l'abstraction cartographique dont parlent les références de dessin technique : distiller l'objet à ses caractéristiques fondamentales.

### Direction artistique

- **Surface** : une seule couleur mate. Indoor clair `#EDE9E2` (papier légèrement plus chaud que le fond, pour que le terrain se détache comme une planche insérée dans le document) ; indoor sombre `#22201D` ; beach `#EAE3D2` clair / `#26231E` sombre. **Aucune texture de parquet, aucun grain animé, aucune ondulation** — au plus le grain statique 2 % toléré en §4.
- **Lignes** : encre. Contour du terrain 2 pt, ligne centrale et lignes 3 m 1,25 pt, prolongements des lignes 3 m en pointillé fin (convention FIVB, dessinée comme sur un plan). Couleur : `encre` à 85 % sur la surface — jamais de bleu illustratif.
- **Filet** : double trait fin perpendiculaire + deux points de poteau. Pas de maillage dessiné.
- **Zones 1-6** : numérotées en token Étiquette, `encre3`, aux positions réglementaires — discrètes, comme les cotes d'un plan.
- **Indoor vs beach** : différenciés par les proportions (18×9 vs 16×8), la présence des lignes 3 m et la température de la surface — pas par la texture. Un œil de coach comprend en 200 ms.
- **Éléments dessinés** (couche tactique) : jetons joueurs = cercles 28 pt, **pleins accent** (nous) / **au contour graphite** (adversaire), numéro en Donnée ; trajectoire de ballon = trait plein ; déplacement de joueur = pointillé ; flèches à tête ouverte 45°, fine. L'encre du PencilKit adopte par défaut la couleur `encre` (rendu craie/feutre du coach sur son plan).
- **Le heatmap** : monochrome accent (échelle d'opacité 8 % → 65 %) en mode volume ; divergent accent ↔ graphite en mode efficacité. Jamais l'arc-en-ciel thermique.

### Pourquoi c'est la signature

Ce rectangle 2:1 au trait devient le **device de marque** : glyphe de l'espace Coacher, motif de l'icône d'app (terrain au trait encre sur fond papier), en-tête des PDF exportés, écran de démarrage. Le terrain n'est plus un décor dans l'app — il **est** l'identité, déclinée du splash au rapport de scouting. Aucun concurrent ne peut le copier sans se renier.

---

## 8. Composants clés redessinés

**Carte de match** — Surface blanche, rayon 10, filet 0,5 pt. Ligne 1 : Étiquette « SAM. 14 NOV. — DOMICILE ». Ligne 2 : adversaire en Titre 2 à gauche, score « 3–1 » en Donnée 22 pt tabulaire à droite. Ligne 3 : pastille V (pleine) ou D (contour) + détail des sets en Note (« 25-19, 23-25, 25-21, 25-17 »). Aucune icône, aucune teinte de fond. État pressé : press state unique. Match live : la carte gagne un filet supérieur rouge 2 pt + « DIRECT » en Étiquette rouge — c'est tout.

**Tableau de stats** — L'écran devient une feuille de calcul de luxe : en-têtes de colonnes en Étiquette `encre2`, alignées sur leurs données ; rangées 40 pt (iPad) séparées par filets horizontaux seuls (pas de zébrures, pas de grille verticale) ; noms à gauche en Corps, chiffres à droite en Donnée tabulaire ; hitting en convention « .350 » (conservée) ; rangée de totaux en Corps fort précédée du **double filet comptable**. Tri : le libellé de colonne actif passe en `encre` + petit chevron — pas de fond coloré.

**Cellule joueur** — Numéro dans une pastille carrée arrondie (6) au contour, en Donnée ; nom en Corps fort ; poste en Étiquette `encre3` ; à droite, une seule stat contextuelle en Donnée. Avatar : initiales sur `surfaceCreuse` — plus de cercle coloré par rôle. Hauteur 52 pt iPhone / 44 pt iPad.

**Boutons live (courtside)** — Puisque sans icône, ils deviennent **purement typographiques** : « KILL », « ACE », « BLOC », « ERREUR » en Étiquette 15 pt, boutons 60 pt minimum, rayon 10. Nous = fond accent plein, texte noir/blanc selon contraste ; adversaire = fond `#000`, contour graphite 1 pt, texte blanc. Undo : « ANNULER LE POINT » en texte, largeur pleine. Le pavé flottant porte l'ombre niveau 2 — seul élément ombré de l'écran.

**Tab bar** — Chrome système (verre natif non teinté), les 5 glyphes au trait de §2 + étiquettes. Sélection : glyphe et étiquette passent en `encre` pleine (pas en accent — la tab bar reste neutre ; l'accent est réservé au contenu). En mode Coacher, la tab bar s'efface (plein écran opaque).

**En-tête d'écran** — Surtitre Étiquette + titre Affiche + filet, défilant vers un titre inline standard. Boutons d'action : mots (« Modifier », « Exporter ») plutôt que glyphes quand la place le permet ; `plus` et `partage` restent des glyphes (liste des 12).

---

## 9. Ce qu'on abandonne de Liquid Glass v2 — et le chemin de migration

### Abandons explicites

| Liquid Glass v2 (actuel) | Playco Mat (3.0) |
|---|---|
| 4 couleurs de section (`PaletteMat.orange/bleu/vert/violet`) + `couleurRole` | Un seul accent : la couleur d'équipe matifiée. Les espaces se distinguent par leur titre, pas par leur teinte |
| `GlassCard` (glassEffect teinté + ombre), `GlassSection`, `GlassChip` | `CartePapier` / `SectionPapier` / `PastilleEncre` : surfaces opaques + filet, ombre quasi nulle |
| Doubles RadialGradient de fond (AccueilView), gradients de texture terrain | Fonds unis `fond` ; terrain mate « Le Trait » |
| Typographie `.rounded` | SF Pro droite exclusivement |
| `.symbolRenderingMode(.hierarchical)` décoratif, icônes de cartes d'accueil | Doctrine sans-symbole §2 |
| Rayons 12/16/22/28 | Rayons 6/10/14 |
| Ombres douce/moyenne généralisées | Ombre réservée au niveau flottant |
| Rouge `negatif #E85C5C` polyvalent | Rouge scindé : live `#D9382E` vs delta négatif `#C05B52` |

### Ce qu'on garde (continuité, pas table rase)

La trame 4 pt, les trois springs, `.contentTransition(.numericText())`, les chiffres tabulaires, la convention « .350 », le kit stats (`CarteMetrique`/`TableauStats` — restylés, pas réécrits), D6 (zéro émoji, déjà acquis), le mode courtside AAA, et le pattern de migration éprouvé de l'équipe : **changer le corps des modificateurs sans changer leurs signatures** (comme lors du passage v2 → glassEffect natif, où 15 sites ont hérité du nouveau matériau sans être touchés).

### Chemin de migration (3 chantiers, refonte progressive — jamais from scratch)

1. **Tokens (1 sem)** — Étendre `PaletteMat` avec les neutres Papier/Ardoise + `accentEquipe` + sémantiques ; introduire l'échelle typographique nommée dans `LiquidGlassKit` ; déprécier les 4 couleurs de section (warning de compilation maison). Aucun écran ne change encore.
2. **Composants (2-3 sem)** — Rebaser `glassCard()/glassSection()/glassChip()` sur les corps mats (signatures inchangées → toute l'app bascule d'un coup) ; purger `.rounded`, gradients de fond, `.hierarchical` ; nouvelle tab bar + glyphes. Un flag de comparaison A/B interne pour valider écran par écran.
3. **Signatures (2-3 sem)** — Nouveau rendu terrain « Le Trait » derrière le même `TypeTerrain` (l'ancien rendu reste dans l'historique git, pas dans le binaire) ; en-têtes éditoriaux ; tableaux au double filet ; courtside typographique ; icône d'app et splash au device du terrain.

---

## 10. Les dix lois de « Playco Mat » (vérifiables en revue de code)

1. **Loi de l'image fonctionnelle.** Toute `Image` est soit l'un des 12 glyphes fonctionnels, soit l'un des 5 glyphes de tab bar. Toute autre occurrence (dont tout symbole accolé à un titre) est un défaut bloquant.
2. **Loi de l'accent unique.** Aucune référence à `PaletteMat.orange/bleu/vert/violet` ni couleur hex inline dans une vue ; la seule couleur non neutre du contenu est `accentEquipe` ; le rouge n'apparaît que via les tokens `live` et `deltaNegatif`.
3. **Loi du chiffre tabulaire.** Tout nombre susceptible d'être comparé à un autre (tableau, score, compteur, delta) porte `.monospacedDigit()` et s'aligne à droite dans les colonnes.
4. **Loi du verre-chrome.** `.glassEffect` et les `Material` sont interdits sur toute surface de contenu ; seuls la tab bar, les toolbars et les présentations système en portent.
5. **Loi du papier.** Aucun `Color.white`/`Color.black` direct ni gradient de fond dans les vues : uniquement les tokens `fond`/`surface`/`surfaceCreuse` ; toute `surface` posée sur `fond` porte le filet 0,5 pt.
6. **Loi du style nommé.** Aucun `.font(.system(size:))` hors du kit typographique ; chaque texte utilise un des 11 tokens ; `.rounded` et `.uppercased()` manuel sont interdits (les majuscules passent par le token Étiquette).
7. **Loi de l'ombre unique.** Seuls les éléments de niveau flottant (modales, popovers, pavé live) portent une ombre ; toute autre `shadow` est un défaut.
8. **Loi du calme.** Aucun `repeatForever`, parallaxe ou effet ambiant ; toute animation utilise l'un des trois springs du kit et répond à une action ; les valeurs changent par `.contentTransition(.numericText())`.
9. **Loi de la redondance.** Aucune information portée par la couleur seule : nous/adversaire = plein/contour, victoire/défaite = pastille pleine/creuse + lettre, deltas = signes imprimés, live = mot « DIRECT ».
10. **Loi du gymnase.** En mode courtside : fond opaque pur, contraste ≥ 7:1 (AAA), aucune opacité < 1, cibles ≥ 60 pt, boutons typographiques — toute violation est bloquante avant merge.

---

## Sources

- [Fontfabric — Top 10 Design & Typography Trends 2026](https://www.fontfabric.com/blog/10-design-trends-shaping-the-visual-typographic-landscape-in-2026/) · [Tubik — 7 UI Design Trends of 2026](https://blog.tubikstudio.com/ui-design-trends-2026/) · [Envato — Calm interfaces & the end of visual theatrics](https://elements.envato.com/learn/ux-ui-design-trends)
- [NN/g — Liquid Glass Is Cracked, and Usability Suffers in iOS 26](https://www.nngroup.com/articles/liquid-glass/) · [Infinum — Liquid Glass: Sleek, Shiny, Questionably Accessible](https://infinum.com/blog/apples-ios-26-liquid-glass-sleek-shiny-and-questionably-accessible/) · [MacRumors — Reduce Transparency in iOS 26](https://www.macrumors.com/how-to/ios-reduce-transparency-liquid-glass-effect/) · [MacRumors — critiques utilisateurs](https://www.macrumors.com/2025/09/17/ios-26-liquid-glass-critiques/)
- [Clay — Glassmorphism, how to do it right (verre sélectif)](https://clay.global/blog/glassmorphism-ui) · [Tim Graf — Mastering Glassmorphism UX in 2026](https://timgraf.com/ui/the-glass-cube-evolution-mastering-glassmorphism-ux-in-2026/)
- [UXDA — Luxury banking app case study](https://theuxda.com/blog/ux-design-case-study-most-beautiful-banking-in-the-world) · [Eleken — Fintech UI examples that build trust](https://www.eleken.co/blog-posts/trusted-fintech-ui-examples) · [Inspo AI — Best color palettes for fintech](https://www.inspoai.io/blog/best-color-palette-for-fintech-app)
- [Apple — Behind the Design: Flighty](https://developer.apple.com/news/?id=970ncww4) · [Apple Design Awards — winners & finalists](https://developer.apple.com/design/awards/)
- [Awwwards — Less, But Better: Dieter Rams' influence on UI](https://www.awwwards.com/less-but-better-dieter-rams-s-influence-on-today-s-ui-design.html) · [Only Once Shop — From Braun to Teenage Engineering](https://onlyonceshop.com/blog/from-braun-to-teenage-engineering) · [Dovetail — Dieter Rams' design principles](https://dovetail.com/ux/dieter-ram-design/)
- [NN/g — Icon Usability](https://www.nngroup.com/articles/icon-usability/) · [WebDesignerDepot — Why icon-only design fails users](https://webdesignerdepot.com/why-icon-only-design-is-failing-users-the-case-for-text-labels/) · [UX Movement — labelling icons](https://uxmovement.com/mobile/why-you-shouldnt-always-label-your-icons/)
- [TypeType — Numbers and numerals in typography](https://typetype.org/blog/numbers-and-numerals-in-typography-basic-types/) · [Molly Hellmuth — The Ultimate Guide to Designing Data Tables](https://medium.com/design-with-figma/the-ultimate-guide-to-designing-data-tables-7db29713a85a)
- [TeamSnap — Behind the Scenes: TeamSnap's New Look](https://www.teamsnap.com/blog/teamsnap-features/behind-the-scenes-teamsnaps-new-look) · [Hudl — plateforme produit](https://www.hudl.com/)
- [Architizer — Pristine minimalist detail drawings](https://architizer.com/blog/practice/details/architectural-drawings-minimalist-details/) · [White Design — Abstraction in architecture](https://www.white-design.com/abstraction-in-architecture/)
