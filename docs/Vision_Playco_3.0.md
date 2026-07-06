# Vision Playco 3.0 — document maître

> **Statut : approuvé (2026-07-06).** Vision arbitrée issue de 3 panels ultracode (16 agents, recherche web) : passe 1 (5 visions indépendantes + 2 critiques + synthèse), passe 2 (langage visuel, terrain/séances, intégration plateforme, contre-vérification C1-C11), passe nuit (revue adversariale, skills, optimisations, verdict). **Matériaux complets** (~440k caractères, 16 documents) : [Vision_Playco_3.0_Annexes/](./Vision_Playco_3.0_Annexes/). **Exécution** : [Roadmap_Playco_v2.2_v3.x.md](./Roadmap_Playco_v2.2_v3.x.md).
> Préséance en cas de conflit entre sources : plan vidéo validé fondateur > verdict nuit > contre-vérification passe 2 > synthèse passe 1 > docs de mai (PR #3, PlayCast/Insights).

---

## 1. Thèse produit

**Playco 3.0 est le poste de pilotage complet du coach de volleyball — préparation, match live, statistiques de calibre pro, vidéo des pratiques, développement des athlètes — conçu pour iPad, qui fonctionne sans wifi dans n'importe quel gymnase, en français d'abord.** Il occupe le seul quadrant vide du marché : la profondeur volleyball de VBStats/DataVolley croisée avec la largeur organisationnelle que ni Hudl (~2 000 $/équipe/an), ni Spordle (registre sans performance), ni TeamSnap (logistique sans sport) n'offrent — le tout offline-first, une douve architecturale que les concurrents cloud ne peuvent pas copier sans se réécrire.

Trajectoire bottom-up : le coach d'abord, l'athlète comme boucle virale, le club comme unité économique, la fédération comme **canal de distribution de la couche développement de l'athlète** — jamais comme client d'un registre qu'on ne construira pas (Spordle a verrouillé ce créneau ; on s'y branche, on ne l'attaque pas).

> **Positionnement** : « Du plan de pratique au développement de l'athlète : tout le volleyball de votre équipe dans une seule app iPad, qui fonctionne sans wifi, en français, au prix d'une paire de souliers plutôt que d'un contrat Hudl. » — *Si Hudl est ESPN, Playco est Monocle.*

Le concurrent n°1 reste **le papier + Google Sheets + Messenger** : c'est lui que l'onboarding < 10 min, la logistique gratuite et le ton du produit doivent battre. Détail marché : [annexe 05](./Vision_Playco_3.0_Annexes/passe1-05-marche-concurrence.md).

## 2. Design « Playco Mat Nuit » — l'identité visuelle

> **Révision fondateur (2026-07-06)** — quatre directives amendent la spec d'origine ([annexe 09](./Vision_Playco_3.0_Annexes/passe2-09-langage-playco-mat.md), conservée comme matériau source) : (1) **interaction directe** — la carte EST le bouton, pas de gros CTA en mots ; (2) **courtside refondu mais essence et practicité conservées** ; (3) **les 5 couleurs d'espace sont CONSERVÉES, en tons neutres, sur un fond sombre/noir** (l'« accent unique couleur d'équipe » comme seule couleur du contenu est abandonné) ; (4) **pas de séparation mat/chrome : le Liquid Glass 3.0, poussé au meilleur, est la matière** de l'app.

Identité : **Éditorial. Exact. Calme — dans la nuit.** Des chiffres qui tombent juste, des traits qui veulent dire quelque chose, du verre sombre qui laisse respirer le noir. Rien ne clignote, rien ne décore.

- **Doctrine sans-symbole (inchangée)** : trois castes d'images — décorative (interdite), métaphorique de navigation (interdite), fonctionnelle (autorisée dans des **listes fermées** : ~16 glyphes fonctionnels ; 8 glyphes d'outils d'éditeur [C2] ; 5 glyphes de tab bar maison au trait, toujours étiquetés, `accessibilityLabel` explicites). Règle d'or : *masque l'image — si l'écran perd une action, elle reste ; s'il reste compréhensible, elle disparaît.*
- **Typographie (inchangée)** : SF Pro droite exclusivement, SF Mono pour les codes seulement. Échelle nommée de 11 tokens, chiffres tabulaires, **double filet comptable** au-dessus des totaux.
- **Couleur — la nuit et les cinq tons** : fond `nuit #0D0D0F` (noir par défaut, unique) ; encre claire `#F2F1ED` / `encre2 #ABA9A3` / `encre3 #6F6D68` (décoratif) ; filet = blanc 10 %. **Les 5 couleurs d'espace, calibrées en tons neutres sur la nuit** : Séances `#C08A64` (terre) · Matchs `#BE6B63` (brique) · Stratégies `#7292B4` (ardoise) · Équipe `#74A98D` (sauge) · Entraînement `#9789BD` (lavande) — jamais les hex vifs v2, jamais en grands aplats de texte, toujours redondées (loi 9). La **couleur d'équipe** reste celle de l'identité (jetons « nous » au terrain, en-tête d'équipe). Rouge vif = `live #E0473D` seulement.
- **Matière — Liquid Glass 3.0, le meilleur possible** : le verre EST la surface (cartes, panneaux, tab bar), pas un chrome à part. Sa discipline : (1) le verre est toujours **sombre** (luminance plafonnée — l'encre claire garde ≥ 7:1 dessus, la leçon NN/g intégrée) ; (2) **teinté à la couleur de son espace à 8-12 %** maximum ; (3) **une seule couche de verre à la fois** — jamais de verre sur verre ; (4) reflet spéculaire discret (1 px en haut) + bordure blanche 8-10 % + ombre douce pour détacher du noir ; (5) les tableaux de chiffres reposent sur verre à teinte renforcée (quasi opaque) — la donnée prime sur la matière ; (6) le morphing du verre (`glassEffectID`) est réservé aux transitions d'espace ; (7) zéro gradient d'ambiance.
- **Interaction directe** : tout objet actionnable se tape directement — la carte héro lance le match d'un tap sur la carte, pas via un bouton « [COACHER CE MATCH] ». Les boutons en mots subsistent là où l'action n'a pas d'objet (courtside, formulaires, destructif).
- **Le terrain « Le Trait » (inchangé, transposé nuit)** : plan d'architecte — surface sombre mate, lignes claires fines, jetons pleins (nous, couleur d'équipe) / au contour (adversaire), heatmap monochrome. Signature de marque (icône, splash, PDF).
- **Motion du calme (inchangée)** : 3 springs, rien ne bouge sans cause utilisateur, les chiffres roulent, plafond 350 ms.
- **Courtside — l'essence conservée** : refonte visuelle alignée nuit, mais les acquis pratiques sont intouchables — fond opaque pur (le verre s'efface : exception assumée), AAA ≥ 7:1, boutons typographiques (mots ≥ 18-20 pt, jamais tronqués), cibles ≥ 60 pt, Score 96 pt, pavé rapide, haptiques.
- **10 lois vérifiables** — portées par `/playco-mat-review`, lois 2/4/5 réécrites par cette révision (couleur calibrée / verre sombre / nuit) ; lois 1, 2, 4, 10 bloquantes.
- Migration en 3 chantiers « corps-sans-signatures » : tokens → composants → signatures. La migration `.glassEffect` de juin 2026 n'est plus un coût irrécupérable [C10 caduc] : elle devient la fondation directe du verre 3.0.

## 3. Architecture d'information — 5 espaces par moment d'usage

Un coach ne pense pas « je consulte le type Stratégies » ; il pense *je prépare mardi, je coache ce soir, j'analyse hier*. La TabView `.sidebarAdaptable` native remplace le hub 5 cartes + DockBar :

| Espace | Contenu |
|---|---|
| **AUJOURD'HUI** | Carte héro contextuelle **tappable en entier** (jour de match : un tap sur la carte → pré-match ; jour de pratique : un tap → mode exécution — pas de bouton CTA), actions rapides, dernier match, « À faire » (onboarding progressif), messages inline |
| **PRÉPARER** | Calendrier racine, séances, Playbook (fusion Bibliothèque + Stratégies + Formations — livrée avec le retour de Séances 2.0), Adversaires (scouting en objet de première classe), programmes physiques |
| **COACHER** | Nuit par nature ; la carte du match du jour se tape directement (6 de départ pré-rempli), match éclair 2 champs, mode exécution de pratique, capture vidéo ; courtside proposé à l'entrée du live |
| **ANALYSER** | Saison, analyse match pré-filtrée (box score/fil/rotations/heatmap), joueurs, exports, debrief IA (backlog) |
| **ÉQUIPE** | Roster (fiche segmentée + QR d'invitation + statut disponibilité), staff & permissions, messagerie, réglages/abonnement |

Flow chiffré : coacher le match du soir passe de ~15 interactions à **2 taps**. Athlète iPhone : 3 onglets (Aujourd'hui / Mes stats / Équipe), push « box score prêt » via CKSubscription — zéro serveur. Les 5 moments sont universels aux sports d'équipe : le SportPack fournit le vocabulaire, jamais la structure. Détail : [annexe 01](./Vision_Playco_3.0_Annexes/passe1-01-ux-navigation.md) et [annexe 08](./Vision_Playco_3.0_Annexes/passe1-08-synthese-vision-3.0.md) §3.

## 4. Login & onboarding

SIWA reste l'unique authentification (acquis v2.1). Nouveautés : **QR par joueur + lien universel** `playco.app/join/{codeEquipe}/{codeInvitation}` (time-to-team < 60 s ; code alphanumérique en fallback gymnase sans réseau ; infra = domaine + AASA + entitlement Associated Domains, exception « hosting statique » assumée) ; premier lancement coach en **3 écrans < 2 min** puis onboarding progressif ; roster par collage de liste/CSV (backlog) ; **consentement mineurs intégré au flux** (attestation coach horodatée, avis parent par lien, DM adulte↔mineur désactivés par défaut — étendu à la captation vidéo dès qu'elle existe). App Clip et OCR : écartés.

## 5. Terrain, Séances, Playbook — la préparation de pratique

Spécification complète : [annexe 10](./Vision_Playco_3.0_Annexes/passe2-10-terrain-seances-playbook.md). L'essentiel :

- **Terrain 2.0 (spec de référence, candidat pari 2027-2028 [C3])** : un seul monde objet-d'abord (fin des 10 modes ; étagère de jetons ; l'encre devient un calque d'annotation ; gomme et undo unifiés), **trajectoires sémantiques** (déplacement pointillé / ballon arc / attaque épais — verbe inféré, multi-segments), cadrage 4 presets, timeline de frames + onion skin, **animation des systèmes** (interpolation + scrubber — jamais de 3D), Apple Pencil Pro (hover/squeeze/haptique), présentation + pointeur laser. **Quick wins livrés tôt** : fix du bug undo, duplication « Continuer », preset demi-terrain.
- **Séances 2.0 (spec de référence, backlog — sortie du calendrier 2026-27 par le recut)** : écran Composer split Playbook↔timeline avec heure réelle calculée, blocs de séance (champs CloudKit-safe, pas de nouveau @Model), gabarits liés aux `CreneauRecurrent`, thème de semaine sur `PhaseSaison`. **Livré dès H1** : le PDF « Plan de pratique » une page (le papier vit encore dans les gymnases) et les 25 exercices signés (contenu produit).
- **Mode exécution (H2 — prérequis du pipeline vidéo [C4])** : plein écran chrono par exercice, swipe = suivant = tag `debut_exercice` automatique, présences, résumé → brouillon suivant.
- **La boucle** : préparer (dim.) → exécuter (mar.) → capturer/taguer (mar., zéro geste) → revoir les clips par exercice (mer.) → ajuster (jeu.). **La vidéo vit dans le Playbook et la séance, pas dans une section « Vidéo ».**

## 6. Vidéo des pratiques + backend hybride (plan validé)

Capture live AVFoundation + import ; tagging live ; clips auto par exercice ; partage ciblé joueur (RLS) ; annotation sur frame (réutilise les outils du terrain, palette 3 couleurs [C9]). **Supabase** (Postgres + Auth SIWA + RLS + Edge Functions + Realtime) porte les métadonnées ; **Cloudflare Stream** le média (TUS background, HLS, purge 30 j) ; **CloudKit intouché** — la vidéo ne transite jamais par CloudKit ni Postgres. Offline pour la capture, online pour la consommation. Première dépendance SPM du projet (supabase-swift, derrière façade, non linkée en DEMO).

**Principe backend** (remplace « zéro serveur avant contrat club ») :
> Un domaine n'obtient un backend que si **(1) une ligne de revenus le finance** ET **(2) la feature est structurellement hors de portée de CloudKit** (média lourd, page web publique, realtime multi-plateforme, RLS fine par joueur).

Ordre des domaines : vidéo (financée par Élite) → rapport de match web par lien (remplace le broadcast PlayCast ; couvre les parents Android ; chaque lien = acquisition) → dashboard club (sur contrat Stripe) → profil carrière → registre développement fédé (sur contrat). **Invariants** : offline gymnase absolu · autorité de calcul = l'app (Supabase stocke des résultats, ne recalcule jamais) · **frontière de confiance pédagogique** (séances, exercices, dessins, scouting, annotations d'un coach ne remontent JAMAIS au club/à la fédé — implémentée en RLS, écrite dans les contrats) · PII minimale côté Postgres (pas de noms, `appleUserID` hashé). Détail : [annexe 11](./Vision_Playco_3.0_Annexes/passe2-11-integration-plateforme.md).

## 7. Pricing unifié

Structure du SAAS_MODEL (5 paliers, variables structurelles), amendée : les fonctionnalités **logicielles** (coût marginal nul) sont dans tous les paliers ; les fonctionnalités à **coût d'infrastructure** (vidéo) sont tarifées séparément.

| Palier | Prix CAD | Canal | Vidéo |
|---|---|---|---|
| Entraîneur | 14,99 $/mois · 149 $/an (1 équipe) | StoreKit | — |
| Pro | 24,99 $/mois · 249 $/an (4 équipes, assistants ∞) | StoreKit (existant) | — |
| **Élite** | 39,99 $/mois · 399 $/an | StoreKit (nouveau) | Incluse — quota ~300 min/mois **par abonnement, avec enforcement** |
| Club / Organisation | **grille non publiée avant son dashboard** (sans lui, Club ≈ 3× n×Pro : invendable) | Stripe, au premier contrat réel | Add-on ~5-8 $/équipe/mois (à trancher [C5]) |
| Fédération | dès 5 000 $/an (≈ 2-3 $/membre/an) | Contrat | Négociée |

Rabais annuel uniforme −17 % ; break-evens : Fédé ≈ 22 équipes depuis Organisation, ≈ 31 depuis Club [C6]. Athlètes et assistants **jamais bloqués** par le paywall. Lancement App Store sur la grille v2 inchangée ; bascule unique au patch 2.10 ; grandfathering Pro v2 12 mois ; groupe `playco.pro` conservé ; santé infra ≤ 40 % du **delta Élite−Pro**. Anti-steering : aucun canal d'achat B2B in-app [C7]. Modèle détaillé : [v3/SAAS_MODEL.md](../v3/SAAS_MODEL.md) (référence structurelle, chiffres remplacés par cette grille).

## 8. Multi-sport

**Volleyball first.** Le calendrier « 4 sports v3.0 » de mai 2026 est caduc ; le protocole **SportPack** ([v3/MULTI_SPORT_PLAN.md](../v3/MULTI_SPORT_PLAN.md)) reste LA spec technique de référence (capabilities `aRotation`/`aLignes`/`aPeriodesChronométrées`, raw values conservés = zéro perte CloudKit), exécutée **sur signal d'achat** d'un autre sport (≥ 2027 ; basketball premier candidat). Phase 0 immédiate : `Equipe.sportID`, gel du couplage (aucune nouvelle référence volley hors des 6 enums recensés), domaine vidéo sport-agnostique, espaces sans « volleyball » en dur. L'éditeur terrain consomme du SportPack (étagère de jetons, verbes de trajectoire, presets de cadrage déclarés) ; le beach est le premier « pack » de fait. Le volleyball assis est le 2e cobaye parfait (argument fédé unique).

## 9. PlayCast & Insights (tranchés)

- **Playco Insights** → feature de l'espace Analyser : debrief tactique fin de match on-device (Foundation Models `@Generable`) — décoration au-dessus de `MetriquesVolley`, jamais source de vérité, fallback stats brutes, bonus silencieux jamais promis en marketing. **Inclus dès Pro** (coût marginal nul). Charts 3D et annotations vocales : coupés. Backlog 3.x.
- **PlayCast** → app compagnon **gelée**, démantelée par persona : le coach = Live Activity locale (zéro serveur) ; les parents/supporters = rapport de match web par lien (supérieur sur toute la ligne : zéro app, Android couvert, zéro quota APNs) ; l'assistant qui logge = Playco sur iPhone (existant). Watch/CarPlay/snippets : gelés.

## 10. Angles morts intégrés (critique de complétude, passe 1)

i18n FR/EN (règle « zéro chaîne en dur » active dès 2.3 — l'architecture se paie pendant la refonte) · consentement mineurs (2.2.b, étendu à la captation en 2.7.1) · profils gérés < 13 ans (conçus avec l'identité backend, livrés au tier Club) · cycle de saison/rollover (NON-ÉJECTABLE avant mai 2027) · **profil carrière athlète** multi-équipes par `appleUserID` (LA rétention athlète, prérequis du CV de recrutement) · accessibilité (daltonisme : redondance de forme systématique [loi 9] ; Dynamic Type ; VoiceOver — pendant la refonte, pas après) · DLTA/LTAD (vocabulaire aligné pour le pitch fédé) · beach comme produit (contre-cycle été) · athlète Android via page web par lien · transfert de propriété d'équipe + export anti-lock-in · appareil partagé/poste de saisie (avant toute e-feuille). Détail : [annexe 07](./Vision_Playco_3.0_Annexes/passe1-07-critique-completude.md).

## 11. Gouvernance, risques, traçabilité

**Gouvernance solo-dev (opposable à ce document)** : 25-30 semaines effectives/an · UN pari > 6 sem/an (2026-27 = la vidéo, 12-14 sem ×2 incluses) · tout item > 4 sem passe un spike d'1 sem avec critère d'abandon écrit · les efforts affichés sont bruts, le budget se pilote en post-×2 · zéro dollar d'infra sans financement dédié · la refonte d'IA jamais en big-bang.

**Top 5 risques** : (1) fuite RLS de vidéos de mineurs → deny-by-default + matrice de tests par rôle dès 2.7 + revue dédiée avant pilote ; (2) scope solo-dev → recut + garde-fous d'éjection + `playco-roadmap-status` ; (3) Hudl/Balltime descend en prix → gagner où la vidéo cloud perd (live, offline, prix, langue) ; (4) Spordle ajoute un module performance → vitesse + posture complémentaire explicite ; (5) App Review (UGC 1.2, steering 3.1) → modération dans la soumission 2.9.2, aucun canal d'achat B2B in-app, compte démo review sur build de production.

**Traçabilité des arbitrages C1-C11** (contre-vérification passe 2, [annexe 12](./Vision_Playco_3.0_Annexes/passe2-12-contre-verification.md)) :

| # | Arbitrage | Porté par |
|---|---|---|
| C1 | Couleurs de poste = exception unique à l'accent, jetons terrain seulement (matifiées + redondées) | Patch 2.4 — loi 2 |
| C2 | 2e liste fermée « glyphes d'outils d'éditeur » (8) | Patch 2.4 (doctrine) ; terrain à 3.0+ |
| C3 | Terrain 2.0 profond = candidat pari 2027-28, pas un calendrier | Backlog 3.2 |
| C4 | Mode exécution = prérequis du pipeline clips | Patch 2.8 |
| C5 | Add-on vidéo B2B à justifier (~5-8 $) vs 3,75 $ implicite Élite | Tranché à la publication de la grille B2B |
| C6 | Break-even Fédé : ≈ 22 éq. (Organisation), ≈ 31 (Club) | §7 |
| C7 | « Parlons Club » = information neutre, aucun achat in-app | Patch 2.10 |
| C8 | 680 pt = texte courant seulement ; tableaux/terrain exemptés | Patch 2.4 — kit Mat |
| C9 | Palette d'annotation Pencil fermée à 3 | Patch 2.9.1 |
| C10 | Coût `.glassEffect` de juin assumé, réabsorbé par corps-sans-signatures | Patch 2.4 |
| C11 | REC = état live ; partage Playbook = AirDrop `.playco` (YAGNI) ; empty states maison assumés | Patch 2.4.1 / backlog |

**Ce qu'on ne fera pas** : voir la liste « Coupés définitivement » de la [roadmap](./Roadmap_Playco_v2.2_v3.x.md) — elle fait partie de la vision au même titre que le reste.

---

*Décision d'exécution : **refonte progressive, jamais from scratch** — les fondations de la cible (event log `PointMatch`, formules centralisées `MetriquesVolley`/`AgregateurStatsMatch`, persistance string-keyed, design system centralisé) existent déjà en v2.2. Le multi-sport est une extraction sous golden tests ; le backend est une couche additive hors chemin critique, financée par Élite. Rien n'exige de repartir de zéro, et le budget solo-dev l'interdit.*
