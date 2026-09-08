# Contre-vérification croisée — passe 2 Playco 3.0 (juillet 2026)

> Vérification adversariale des trois livrables `langage-mat`, `terrain-seances`, `integration-plateforme`, contre les décisions arbitrées (Vision 3.0, plan vidéo validé) et contre le code réel du repo (constantes courtside `LiquidGlassKit.swift`, `FormationType.couleurPourLabel` `FormationTypes.swift:165`, `pileUndo.removeAll()` `TerrainEditeurViewModel.swift:227-228` — tous vérifiés dans le worktree).

---

## 1. Contradictions — inventaire et arbitrages

### C1 — Couleurs de poste vs « Loi de l'accent unique » · MAJEURE · mat ↔ terrain-seances

`langage-mat` (Loi 2) : « la seule couleur non neutre du contenu est `accentEquipe` » ; §7 : jetons « pleins accent (nous) / contour graphite (adversaire) ». `terrain-seances` (§1.2.a et h) : étagère de jetons « couleur par poste », « les jetons y sont les seuls éléments colorés (couleurs de poste) », réutilisation de `FormationType.couleurPourLabel` — qui existe bel et bien dans le code et vient d'être centralisé en v2.2 (refonte stats/formations, juillet 2026). Appliquer la Loi 2 telle quelle jette une feature livrée il y a des semaines et détruit une information fonctionnelle (distinguer passeur/libéro/attaquants d'un coup d'œil sur un diagramme 6 jetons).

**Tranché** : la couleur de poste est de l'**information fonctionnelle de domaine**, pas de la décoration. On codifie une exception dans la Loi 2 : « les couleurs de poste sont autorisées sur les jetons joueurs du terrain uniquement, en variantes matifiées (même algorithme que l'accent), toujours redondées par le numéro/l'étiquette de poste (Loi 9) ». Partout ailleurs (listes, tableaux, avatars — mat a raison de tuer le « cercle coloré par rôle »), les neutres s'appliquent. `terrain-seances` doit préciser que la « pastille d'intensité » des cartes Playbook est monochrome (échelle d'opacité accent ou 5 ticks), pas un feu tricolore.

### C2 — Toolbar terrain vs liste fermée des 12 glyphes · MAJEURE · mat ↔ terrain-seances

La barre d'outils cible de `terrain-seances` (§1.2.h) exige : Sélection, Encre, Gomme, Formations, Cadrage, Lecture + tiroir « ··· ». La liste fermée de `langage-mat` (§2) ne contient **aucun** de ces glyphes (elle a lecture/pause, mais ni gomme, ni sélection, ni encre, ni cadrage, ni « ··· »). En l'état, la toolbar terrain viole la Loi 1 (défaut bloquant) dès le premier écran de l'éditeur.

**Tranché** : la doctrine tient si on reconnaît que ces glyphes sont **fonctionnels** (caste 3) — ils SONT l'outil, comme lecture/pause. Créer une **deuxième liste fermée « outils d'éditeur »** (~8 : sélection, encre, gomme, formation, cadrage, lecture, ellipse-débordement, pointeur-présentation), même gouvernance de revue. L'outil actif affiche son libellé (« Encre ») comme déjà prévu — le mot reste le porteur de sens, le glyphe est l'ancre spatiale.

### C3 — Terrain 2.0 : « maintenant » vs « pari H3-2027 » · MAJEURE · terrain-seances ↔ integration

`terrain-seances` présente Terrain 2.0 (un seul monde, trajectoires sémantiques, timeline de frames, animation, Pencil Pro, snapping, présentation) comme le pilier n° 1 de la passe, avec l'animation « ~3 sem » présentée comme « sous le seuil du pari ». `integration-plateforme` (§5) le rétrograde explicitement : « le terrain 2.0 profond est un candidat pari H3-2027, pas avant » et rappelle que **la vidéo est LE pari de l'année**.

**Tranché en faveur d'integration** (préséance du plan vidéo validé + gouvernance un-seul-pari). Le chiffrage honnête de Terrain 2.0 complet est de 14-19 sem brutes (voir §2), soit 28-38 sem ×2 : un deuxième pari annuel, interdit. `terrain-seances` reste la **spec de référence** du terrain (comme le SportPack l'est pour le multi-sport), mais son calendrier est requalifié : quick wins découplés en H1 (voir §2), le reste en 2027. Le « ~3 sem » de l'animation est trompeur : il suppose les décisions 1 et 2 (un seul monde + trajectoires sémantiques) déjà livrées, soit 6-8 sem de prérequis.

### C4 — Le mode exécution est absent de la roadmap mais prérequis des clips vidéo · MAJEURE · trou inter-livrables

Le pipeline vidéo H2 (« clips auto par exercice », phases 3-7) repose sur le tag `debut_exercice` « posé automatiquement par le swipe d'exercice du mode exécution » (`terrain-seances` §2.5 et §3.4). Or le **mode exécution n'apparaît dans aucune ligne de la roadmap H1/H2/H3** d'`integration-plateforme`. Sans lui, le découpage auto — l'argument « friction zéro » qui conditionne la survie de la feature pour un coach seul — n'existe pas.

**Tranché** : deux options, à choisir explicitement : (a) ajouter un **mode exécution minimal** (~2 sem : chrono + liste + swipe + tag, sans « Recaler » ni résumé) en H2 avant la phase 3 vidéo ; (b) dégrader la v1 vidéo en tagging manuel (bouton « Exercice suivant » dans l'écran de capture). Recommandation : (a) — c'est le seul morceau de `terrain-seances` qui conditionne le pari de l'année.

### C5 — Prix vidéo par équipe : 3,75 $ (StoreKit) vs 8 $ (Stripe) · MOYENNE · interne à integration

Delta Élite−Pro = 15 $/mois (mensuel) pour jusqu'à 4 équipes = **3,75 $/équipe/mois** ; l'add-on B2B est à **8 $/équipe/mois** (2,1×). Un club rationnel équipera ses coachs en comptes Élite individuels. **Tranché** : assumer et documenter l'écart (quotas minutes B2B plus généreux + support + facturation centralisée), OU aligner l'add-on à ~5 $. À défaut, l'add-on Stripe est mort-né.

### C6 — « Break-even Fédé à 22 équipes » · MINEURE · interne à integration

Vérifié : 5 000 $/an = 416,67 $/mois. Organisation : 89 + 15n = 416,67 → n ≈ 21,8 ✔. Club : 49 + 12n = 416,67 → n ≈ **30,6**, pas 22. La phrase « la dégressivité existe via le break-even Fédé à 22 équipes » n'est vraie que pour le palier Organisation. À préciser.

### C7 — « Parlons Club » in-app vs « aucun lien d'achat Stripe in-app » · MOYENNE · interne à integration

§2.5 conserve le trigger 3 : « Parlons Club (mailto/formulaire) » dans l'app ; §6 exige « AUCUN lien d'achat Stripe dans l'app (guideline 3.1.1) ». Un mailto commercial pour un abonnement vendu hors IAP est du steering au sens 3.1.3 — et les assouplissements anti-steering de 2025 ne valent que pour le storefront **US** ; Playco vend au Canada. **Tranché** : le trigger 3 devient un écran d'information neutre (« Les offres Club existent — playco.app/club ») sans mailto ni formulaire in-app, ou disparaît de l'app (page web + fiche ASC seulement).

### C8 — Largeur de lecture 680 pt vs densité d'analyse iPad · MINEURE · interne à mat

§5 impose « largeur de lecture max 680 pt sur iPad » et, deux lignes plus loin, « iPad privilégie la densité d'analyse (colonnes multiples) ». Un box score NCAA ou un tableau par rotation dépasse 680 pt utilement. **Tranché** : la contrainte 680 pt vaut pour le texte courant et les formulaires ; les tableaux de stats, le terrain et les timelines en sont exemptés (pleine largeur avec marges).

### C9 — Palette d'annotation Pencil vs encre unique · MINEURE · mat ↔ terrain-seances

Le squeeze Apple Pencil ouvre une palette « épaisseur, encre/surligneur, **couleur d'annotation** » ; mat prescrit « l'encre PencilKit adopte par défaut la couleur `encre` ». **Tranché** : palette d'annotation fermée à 3 : `encre`, `accentEquipe`, graphite (adversaire) — cohérente avec la sémantique nous/adversaire, suffisante pour un coach, conforme au mat.

### C10 — Mat jette la migration `.glassEffect` de juin 2026 · À ASSUMER · mat ↔ historique

L'audit Xcode 27 (juin 2026) vient de migrer GlassCard/GlassSection/GlassChip vers `.glassEffect` natif. Mat les remplace par des surfaces opaques un mois plus tard. Pas une contradiction de décision (la directive fondateur passe 2 prime), mais un coût irrécupérable à nommer dans le livrable — et un argument POUR le chemin de migration proposé (changer les corps des modificateurs, signatures intactes : le même pattern qui a réussi en juin réabsorbe le coût).

### C11 — Divers mineurs, conformes après reformulation

- « REC = seule occurrence du rouge hors live » (`terrain-seances` §3.4) : requalifier — l'enregistrement EST un état live ; le rouge reste conforme à « rouge = live ». Wording seulement.
- Le principe « zéro serveur avant contrat club » est amendé par integration : conforme à la préséance déclarée du plan vidéo — à entériner formellement comme décision, pas comme dérive.
- Le « partage Playbook par code entre coachs sur la fondation Supabase » (`terrain-seances` §3.3) n'apparaît pas dans l'ordre des domaines §1.4 d'integration. À ajouter comme domaine 2bis conditionnel — ou requalifier : AirDrop/`.playco` suffit à horizon 12 mois (recommandé, YAGNI).
- Les empty states « phrase + bouton » (mat §2) entrent en friction avec `ContentUnavailableView` natif (déployé partout en v1.1.0, qui attend une image). Faisable sans image, mais à dire : on quitte le pattern natif — assumé.

---

## 2. Faisabilité solo-dev — ce qu'on coupe, ce qu'on reporte

### Le budget H1 est déjà insolvable

H1 d'integration : 3+3+2+1+3 = 12 sem sur ~12 disponibles, **marge zéro**, et la règle « estimations ×2 » n'est appliquée qu'à la vidéo. « Refonte navigation 3 sem » pour 5 espaces + fusion Playbook (3 surfaces, `BibliothequeView`/`StrategiesView`/`FormationsView`) est optimiste : ×1,5-2 réaliste. **Amendement** : déclarer « pricing prep » (1 sem) et « vidéo 0-2 » (3 sem) explicitement éjectables vers H2 (le texte le dit pour la vidéo, pas pour le pricing), et retirer une des deux vagues de contenu de la refonte nav.

### Chiffrage honnête de Terrain 2.0 (absent du livrable)

| Morceau | Brut | Note |
|---|---|---|
| Un seul monde (étagère, gomme unifiée, dé-modalisation) | 3-4 sem | refonte d'interaction du fichier le plus délicat de l'app |
| Trajectoires sémantiques + multi-segments (migration `ElementTerrain` v2) | 2-3 sem | JSON versionné, ok CloudKit |
| Cadrage/zoom/pan | 1-2 sem | |
| Timeline de frames + onion skin + « Continuer » | 2 sem | |
| Animation (interpolation, scrubber, présentation) | 3 sem | dépend des 2 premiers |
| Pencil Pro (hover/squeeze/haptique) | 1-2 sem | |
| Snapping/guides/lasso | 1-2 sem | |
| **Total** | **14-19 sem** | **×2 = 28-38 sem : une année entière** |

### Découpage recommandé (remplace le calendrier implicite de terrain-seances)

**H1 — quick wins terrain découplés (~1,5 sem, sans « un seul monde »)** :
1. **Bug undo** : `chargerEtapeActive` vide `pileUndo`/`pileRedo` (vérifié `TerrainEditeurViewModel.swift:227-228`) — correctif isolé, c'est un bug, pas une feature.
2. **Duplication « Continuer »** (arrivées→départs) : extension de `dupliquerEtapeActive`, données déjà là.
3. **Cadrage demi-terrain** en preset simple (sans zoom/pan libre).

**H1 — noyau « préparation de pratique » (~5-6 sem, sert la directive fondateur n° 2 sans toucher l'éditeur)** : timeline de séance avec blocs/durées/heure réelle + drag depuis le Playbook (champs CloudKit-safe, pas de nouveau @Model — le design est bon) ; gabarits liés aux `CreneauRecurrent` ; PDF « Plan de pratique » (PDFExportService existe) ; Playbook à facettes (migration `CategorieExercice`→tags).

**H2** : mode exécution minimal (2 sem, prérequis vidéo — C4).

**Reportés 2027 (candidat pari, décision H3)** : un seul monde, trajectoires sémantiques, animation, Pencil Pro, snapping avancé, présentation laser, export MP4.

**Coupés/dégraissés** :
- **50 exercices signés → 25** couvrant 7 habiletés × 2 niveaux. 50 diagrammes multi-frames au nouveau standard = des semaines de travail de contenu du fondateur, non comptées nulle part.
- **Charge estimée (intensité×durée + courbe 7 jours)** : reporter — dépend de données d'intensité que personne n'a encore saisies. YAGNI v1.
- **Thème de semaine** : garder le champ texte + le compteur de minutes par tag ; couper la « suggestion sobre » (« aucune séance ne travaille le service… ») — c'est un moteur de règles déguisé.
- **« Recaler / couper le retour au calme »** du mode exécution : v2.
- La rangée « Pas vus depuis longtemps » : garder (tri trivial sur date d'usage), mais l'ajout du champ statistique d'usage doit être dans la liste des champs CloudKit-safe (il n'y est pas).

---

## 3. Doctrine « sans symbole » — où elle tient, où elle casse

**Tient** :
- **Tab bar** : les 5 glyphes custom sont une vraie solution (images fonctionnelles + étiquettes, conforme HIG et NN/g). Coût réel non chiffré : dessiner 5 custom SF Symbols sur la grille optique avec les 3 graisses/9 tailles requises = 2-4 jours de travail de dessin, à budgéter dans la vague 1 mat.
- **VoiceOver** : un design typographique est *supérieur* — les boutons-mots ont des labels gratuits. La doctrine est un atout a11y, pas un risque (voir §5).
- **Courtside sous stress** : les mots courts en majuscules (« KILL », « ACE », « BLOC ») scannent aussi vite que des icônes pour un utilisateur entraîné (le coach l'est après 2 matchs) et éliminent l'ambiguïté icône-métaphore. Tenable — À UNE CONDITION (ci-dessous).

**Casse — et compromis honnêtes** :
1. **Toolbar terrain** (C2) : casse contre la liste des 12. Compromis : deuxième liste « outils d'éditeur », gouvernance identique.
2. **Taille des étiquettes courtside** : mat prescrit Étiquette **15 pt** sur boutons 60 pt. La constante courtside actuelle du code est déjà à **18 pt** (`LiquidGlassKit`, « constantes courtside : police 18 ») et le livrable régresse dessous. À bout de bras, en sueur, sous éclairage de gymnase : **≥ 18-20 pt**, et attention aux mots français longs (« ERREUR ADV. », « ANNULER LE POINT ») qui contraignent la largeur — prévoir la troncation impossible (les mots sont l'interface : un mot tronqué est une icône cassée).
3. **La liste des 12 est incomplète pour l'app réelle** : il manque au minimum *envoyer* (messagerie), *filtre* (stats/Playbook — ou libellé « Filtres »), *calendrier* (sync EventKit) et *appareil photo/REC* (capture vidéo H2). Soit on les ajoute (liste à ~15), soit on tranche mot-par-mot maintenant. Une liste fermée qui explose au premier sprint perd son autorité — mieux vaut la calibrer juste une fois.
4. **Étiquette 11 pt MAJUSCULES** comme unique en-tête de section : à Dynamic Type xxxLarge, des surtitres uppercase longs en français wrappent moche. Prévoir la règle de repli (retour en casse normale au-delà de `accessibility1`).

---

## 4. Pricing — vérification mathématique

### $/équipe/mois effectifs (annuel, CAD)

| Offre | Calcul | $/équipe/mois |
|---|---|---|
| Entraîneur (1 éq.) | 149/12 | **12,42** |
| Pro (4 éq. utilisées) | 249/12/4 | **5,19** |
| Élite (4 éq. + vidéo) | 399/12/4 | **8,31** |
| Club, 4 éq. | (49+48) | **24,25** |
| Club, 10 éq. | (49+120)/10 | **16,90** |
| Club, 30 éq. | (49+360)/30 | **13,63** |
| Organisation, 10 éq. | (89+150)/10 | **23,90** |

### Trois défauts structurels

1. **Le canal Club n'est jamais compétitif contre les licences individuelles.** Club < n×Entraîneur-annuel exige 49+12n < 12,42n → n > **117 équipes**. Contre Pro c'est pire : un club de 12 équipes = 3 comptes Pro à 747 $/an vs Club 2 316 $/an (**3,1×**). Le « garde-fou Pro » (« 1 head coach vérifié ») n'a **aucune force technique ni contractuelle** : rien n'empêche — et rien ne devrait empêcher — chaque head coach d'acheter son Pro. Conclusion : Club/Org ne vendent pas « le droit d'exister à n équipes », ils ne peuvent vendre QUE le dashboard, l'administration centrale et la facturation unique. Or le dashboard n'arrive qu'à H3+ sur contrat. **Amendement** : ne PAS publier la grille Club/Org à la bascule H2 (elle n'a pas encore de produit) ; l'annoncer avec le dashboard, ou repositionner Club en « n × prix Entraîneur dégressif + admin » — la roadmap d'integration dit déjà « Stripe sur premier contrat » : la grille doit suivre la même règle.
2. **Le ratio infra 6 % est calculé sur le mauvais dénominateur.** Le tableau §1.6 rapporte le coût Stream au MRR Élite plein (39,99 $). Mais la part « logicielle » d'Élite est déjà le prix de Pro ; le revenu marginal de la vidéo est le **delta Élite−Pro = 15 $/mois (mensuel) ou 12,50 $/mois (annuel)**. À 4 équipes filmées activement (~1,4-2,2 $/éq./mois au palier succès), l'infra consomme **48-72 % du delta**. La règle de santé « ≤ 15 % du MRR Élite » masque ce cas. **Amendements** : (a) quota minutes **par abonnement**, pas par équipe, chiffré avant la fiche ASC (ex. 300 min/mois) ; (b) recalculer la règle de santé sur le delta (« infra ≤ 40 % du delta vidéo » est le vrai seuil de rentabilité).
3. **MRR pilote surestimé** : « 20 × 39,99 ≈ 800 $ » suppose 100 % de mensuels ; en annuel (399/12 = 33,25) → 665 $. Le ratio pilote passe de ~6 % à ~7,5 % — pas grave, mais le tableau doit prendre l'hypothèse conservatrice.

### Ce qui est cohérent (vérifié)

- Rabais annuel uniforme **−17 %** sur les trois paliers StoreKit (149/179,88 ; 249/299,88 ; 399/479,88) ✔.
- Échelle d'upgrade Entraîneur→Pro→Élite : +100 $/an pour 3 équipes + assistants, +150 $/an pour la vidéo — paliers monotones, ranking StoreKit propre ✔.
- Fédé : plancher 5 000 $ = 1 667-2 500 membres à 2-3 $ — dimensionnement plausible pour une fédé provinciale ✔ ; break-even Org→Fédé ≈ 22 équipes ✔ (mais Club→Fédé ≈ 31, cf. C6).
- Subscription group `playco.pro` conservé, `club.*` retiré de la vente avec 0 abonné : sans risque ✔.

---

## 5. Accessibilité & App Review

### Le design sans icônes passe — et il est même plus fort

- **Aucune guideline n'exige des icônes.** Le HIG recommande des symboles en tab bar : les 5 glyphes custom + étiquettes y satisfont. Condition : chaque glyphe custom porte un `accessibilityLabel` explicite (un custom symbol n'a pas de label automatique, contrairement aux SF Symbols).
- **VoiceOver** : boutons typographiques = labels natifs, gain net vs l'existant. Points de vigilance : les pastilles V/D (plein/contour) doivent exposer « Victoire »/« Défaite » ; le double filet comptable est purement visuel — les totaux doivent être annoncés « Total » ; le terrain « Le Trait » hérite du chantier a11y PencilKit déjà entamé (v. audit prelaunch W4).
- **Dynamic Type** : le mapping token→TextStyle + `@ScaledMetric` est la bonne architecture ; ajouter la règle de repli uppercase (§3.4) et vérifier que « Donnée 15 pt » dans des tableaux denses iPad ne casse pas la mise en page à `accessibility3+` (prévoir bascule tableau→liste).

### Contrastes WCAG — deux tokens mat sont sous la barre

- **`encre3` #8B8781 sur `surface` #FFFFFF ≈ 3,6:1** — sous 4,5:1. Or mat l'assigne à de l'information réelle : poste du joueur (cellule joueur §8), numéros de zones du terrain (§7). **Amendement** : `encre3` réservé au décoratif/désactivé, ou assombri vers ~#767269 ; le poste passe en `encre2`.
- **`deltaPositif` #3E8E6C sur blanc ≈ 4,0:1** — limite pour du texte 15 pt. Assombrir d'un cran ou garantir la lecture par le signe « + » (Loi 9) en `encre` avec la couleur en accessoire.
- Courtside AAA ≥ 7:1 : conforme et déjà décidé ✔.

### App Review — trois points chauds

1. **Steering 3.1.1/3.1.3** : le trigger « Parlons Club » mailto/formulaire in-app (C7) est le seul vrai risque de rejet du corpus. Le neutraliser (info sans canal d'achat, ou hors app).
2. **Compte démo review avec vidéo seedée** (integration §6) : nécessaire pour démontrer Élite — mais à distinguer explicitement du **build DEMO** existant (flag compile-time, garde-fou : jamais en review publique). Formulation à corriger : « compte de démonstration sur build de production », pas « build démo ».
3. **UGC / mineurs (guideline 1.2)** : des vidéos d'athlètes mineurs partagées entre comptes = contenu généré par l'utilisateur. Même en cercle privé d'équipe, prévoir signalement + retrait + blocage (en plus du consentement Loi 25 déjà couvert). À ajouter à la phase 9 « durcissement ».

---

## Amendements à appliquer

### Livrable `langage-mat`

1. **Loi 2 amendée** : exception « couleurs de poste » sur les jetons du terrain (matifiées, redondées par étiquette) — réconciliation avec `couleurPourLabel` v2.2 (C1).
2. **Deuxième liste fermée « glyphes d'outil d'éditeur »** (~8) pour la toolbar terrain ; compléter la liste des 12 avec *envoyer*, *filtre*, *calendrier*, *REC* (→ ~15-16, calibrée une fois) (C2, §3.3).
3. **Courtside : Étiquette des boutons live remontée à ≥ 18-20 pt** (la constante existante est à 18 — ne pas régresser) ; règle anti-troncation des mots-boutons français (§3.2).
4. **`encre3` assombri ou rétrogradé** au décoratif ; `deltaPositif` assombri d'un cran ; audit de contraste des 7 sémantiques sur les 2 modes avant gel des hex (§5).
5. **Exemption tableaux/terrain/timelines** de la largeur de lecture 680 pt (C8).
6. Palette d'annotation Pencil fermée à 3 couleurs : `encre` / `accentEquipe` / graphite (C9).
7. Règle de repli Dynamic Type pour le token Étiquette au-delà d'`accessibility1` ; budgéter 2-4 jours de dessin des 5 custom symbols (graisses/tailles) + labels a11y.
8. Nommer le coût irrécupérable de la migration `.glassEffect` de juin 2026 et le pattern de réabsorption (corps des modificateurs, signatures intactes) (C10).
9. Préciser le devenir des empty states : abandon de `ContentUnavailableView` avec image au profit d'un composant maison « phrase + bouton » — décision assumée, à lister dans les abandons §9.

### Livrable `terrain-seances`

1. **Requalifier le calendrier** : Terrain 2.0 profond = spec de référence pour le pari candidat H3-2027 (aligné sur integration) ; retirer la formulation « l'animation ~3 sem respecte la règle du pari » (elle omet 6-8 sem de prérequis) (C3).
2. **Extraire les 3 quick wins H1** : fix undo `removeAll` (bug vérifié au code), duplication « Continuer », preset demi-terrain — livrables sans « un seul monde ».
3. **Ajouter le mode exécution minimal (~2 sem) comme prérequis explicite de la phase 3 vidéo**, ou spécifier le fallback tagging manuel (C4).
4. Jetons Playbook : pastille d'intensité **monochrome** ; couleurs de poste conformes à l'exception Loi 2 (C1) ; toolbar conforme à la liste « outils d'éditeur » (C2).
5. **50 exercices → 25** (7 habiletés × 2 niveaux), le reste étalé ; chiffrer le travail de contenu du fondateur.
6. Couper de la v1 : charge estimée + courbe 7 jours, suggestion « habileté négligée », « Recaler » ; ajouter `ExerciceBibliotheque.dernierUsage`/`compteurUsage` à la liste des champs CloudKit-safe (rangée « Pas vus depuis longtemps »).
7. Requalifier « REC = rouge hors live » → l'enregistrement est un état live (wording) ; partage Playbook inter-coachs : AirDrop/`.playco` seulement à 12 mois, retirer la mention Supabase ou la conditionner au domaine 2bis d'integration.
8. Ajouter une ligne de chiffrage honnête par morceau (tableau du §2 ci-dessus) — le livrable n'en a aucune hors animation.

### Livrable `integration-plateforme`

1. **Retirer la grille Club/Org de la bascule H2** : sans dashboard, Club est 3× plus cher que n×Pro sans contrepartie — publier la grille B2B avec le produit B2B (même logique que « Stripe sur contrat ») (§4.1).
2. **Quota vidéo par abonnement, chiffré** (ex. 300 min/mois) avant fiche ASC ; règle de santé infra recalculée sur le **delta Élite−Pro** (≤ 40 % du delta), pas sur le prix plein (§4.2).
3. Corriger : MRR pilote en hypothèse annuelle (665 $) ; « break-even Fédé 22 équipes » → Organisation (Club ≈ 31) (C6).
4. **Neutraliser le trigger « Parlons Club »** : information sans canal d'achat in-app, ou hors app (C7 — seul vrai risque App Review).
5. Aligner l'add-on vidéo B2B (justifier 8 $ vs 3,75 $ implicite StoreKit, ou baisser à ~5 $) (C5).
6. **Insérer le mode exécution minimal en H2** (dépendance `debut_exercice`) et marquer « pricing prep » comme éjectable de H1 ; appliquer ×1,5-2 à « refonte navigation 3 sem » ou en réduire le périmètre (C4, §2).
7. Distinguer « compte démo review » du build DEMO compile-time (garde-fou existant : jamais en review) ; ajouter signalement/retrait UGC mineurs à la phase 9 (§5).
8. Ajouter au tableau de décision : l'exception « couleurs de poste » (C1), la deuxième liste de glyphes (C2), et le domaine 2bis « partage Playbook » (ou son rejet YAGNI).

**Verdict d'ensemble** : les trois livrables sont individuellement solides et convergent sur l'essentiel (mat éditorial, verre-chrome, vidéo = pari unique, CloudKit à vie). Les quatre failles qui devaient être trouvées avant d'engager du code : la collision couleurs-de-poste/Loi 2, la toolbar terrain hors liste fermée, le mode exécution fantôme dont dépend le pipeline vidéo, et un canal Club mathématiquement invendable avant son dashboard. Toutes ont un correctif local — aucune n'invalide la direction.
