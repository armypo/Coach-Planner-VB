# Plan Vidéo + IA — post-pivot

> **Statut : décidé fondateur le 2026-09-29.** Remplace la partie backend (Supabase + Cloudflare Stream, financée par le tier Élite — caduque avec l'app gratuite) du plan vidéo H2 de [Roadmap_Playco_v2.2_v3.x.md](./Roadmap_Playco_v2.2_v3.x.md). Garde de cette roadmap : la thèse « les stats indexent la vidéo » ([annexe 03](./Vision_Playco_3.0_Annexes/passe1-03-innovation-technique.md) §2) et la gouvernance solo-dev.

## Décisions

| # | Décision |
|---|---|
| V1 | **Vidéo hors de la version de lancement.** Tout le code vidéo vit sous le flag de compilation `VIDEO`, actif en **Debug seulement** : absent des binaires Release (App Store, TestFlight). |
| V2 | **Local-first.** La vidéo reste sur l'appareil, jamais dans CloudKit. Aucun @Model vidéo avant la livraison : manifeste JSON à côté du fichier (`VideoMatchStore`) → zéro changement de schéma CloudKit. |
| V3 | **Monétisation plus tard** : abonnement mensuel vidéo/IA. Le cloud (stockage, IA lourde) ne revient qu'avec ce revenu (règle « zéro $ d'infra sans financement »). |
| V4 | **On ne bâtit pas UN modèle d'IA : on bâtit ce qui absorbe chaque nouveau modèle le jour de sa sortie.** |

## Thèse

Chaque `PointMatch` porte un `horodatage` (préservé par la sync entre coachs). Avec l'heure de début de la vidéo, chaque point saisi en live devient un chapitre : **la saisie de stats EST le découpage.** Le même index constitue des **étiquettes d'entraînement** gratuites : Balltime paie pour étiqueter, les coachs Playco étiquettent en coachant.

## Les 3 actifs IA (ce qui rend le timing favorable)

| Actif | Rôle | Pourquoi c'est la douve |
|---|---|---|
| **Données étiquetées** | Vidéo + index stats (manifeste versionné, opt-in) | Un nouveau modèle, tout le monde l'a le même jour — Hudl aussi. Des matchs québécois étiquetés par des coachs, personne ne les achète. |
| **Banc d'essai** | 10-20 matchs de référence + score par capacité (« % des kills retrouvés ») | Évaluer un nouveau modèle en heures, pas en mois : c'est ce qui permet de saisir le bon moment. |
| **Interface interchangeable** | Protocole `AnalyseurVideo` : on-device (Vision/Core ML), cloud, futurs modèles Apple | Changer de modèle sans réécrire l'app (style protocol-based du projet). |

## Échelle des capacités IA

| N | Capacité | Faisabilité (ESTIMÉ) | Voie |
|---|---|---|---|
| 1 | Échanges détectés, temps morts coupés | Maintenant | On-device (mouvement + son) ; l'index stats le fait déjà en partie |
| 2 | Ballon suivi → zones, trajectoires, vitesse de service | Spike : modèles open source existants (VolleyVision, VballNet/TrackNetV4) — YOLOv8n 92,5 % précision / 81,4 % rappel **MESURÉ par l'auteur, non reproduit** | YOLO → Core ML, sur l'iPad |
| 3 | Actions + joueur (service/réception/passe/attaque/bloc, n° de maillot) | Avec nos étiquettes | Ajustement sur données Playco ; modèle vision cloud en repli |
| 4 | Stats sans saisie (niveau Balltime) | Quand N2 + N3 passent le seuil du banc d'essai | Combinaison ; le coach courtside valide |
| 5 | Coach IA : débrief, séance suggérée | Maintenant | Foundation Models on-device, narre des stats calculées (jamais ne calcule) |

**Viser mieux que Balltime** : Balltime livre ses stats 1-2 h après l'upload (source Hudl). Playco vise : dans le gymnase, sur l'iPad, sans upload — et l'humain courtside corrige l'IA au lieu de la subir.

## Contraintes non négociables

- **Offline** : l'IA n'entre jamais dans le chemin critique du live.
- **Loi 25 (à valider par un juriste)** : entraîner une IA = finalité distincte → consentement propre, **NON par défaut** (`ManifesteVideoMatch.consentementEntrainementIA`) ; < 14 ans → consentement parental ; évaluation des facteurs relatifs à la vie privée avant tout envoi hors Québec (IA cloud).
- **Identifier les joueurs par le numéro de maillot, jamais par le visage** (biométrie → déclaration à la CAI).

## Où vit le code : `Modules/PlaycoVideo` (hors de l'app)

Package Swift autonome, **non lié à la cible Playco**, testé à chaque push par la CI `.github/workflows/playco-video.yml` : Linux (logique pure — prouve l'indépendance aux frameworks Apple) + macOS (AVFoundation sur de vrais fichiers générés par les tests). L'environnement de dev distant bloque `download.swift.org` : la CI est la boucle de test.

| Brique | Rôle | Testé sur |
|---|---|---|
| `EvenementMatch` | Point saisi en live, sport-agnostique (étiquette brute, résultat, période, rotation/zone/service optionnels — l'inconnu n'est jamais deviné) | Linux |
| `AlignementVideo` | Temps réel ↔ temps vidéo ; calage par ancres (1 = décalage ; éloignées = décalage + dérive d'horloge ; médiane robuste) | Linux |
| `IndexVideo` · `FiltreChapitres` · `PlanLecture` | Chapitres par point, « cutups » filtrés, segments de lecture continue ; match en **plusieurs fichiers** (un par set) | Linux |
| `StockageVideoMatch` · `ManifesteVideoMatch` v2 | Stockage local hors iCloud, manifeste versionné (relit le v1), import multi-fichiers, ajout d'un fichier | Linux |
| `BancEssai` · `AnalyseurVideo` | Précision/rappel/F1 d'un analyseur contre la vérité du coaching ; tout modèle se branche par le protocole | Linux |
| `DetecteurEchanges` | IA N1 — échanges sur signal d'activité (hystérésis entre repos et actif, seuils LOCAUX sur fenêtre glissante de 60 s avec plancher — suit les changements de plan/zoom) | Linux + vraie vidéo (macOS) |
| `DetecteurSifflets` · `AnalyseurSiffletsFlux` | IA N1 audio — sifflet d'arbitre (FFT, pic tonal 2-4,5 kHz), en flux à mémoire constante | Linux + vrai WAV (macOS) |
| `FusionBornes` | Fin d'échange recalée sur le sifflet | Linux |
| `CalageAutomatique` (± `estimerLarge`) · `EstimationFenetre` | Calage vidéo ↔ stats **sans ancre** (jusqu'à ±4 h) + fenêtre de clip apprise | Linux |
| `ReglageDetecteur` | Réglage AUTOMATIQUE des seuils au banc d'essai (grille → meilleur F1, validation sur un match non utilisé) | Linux |
| `CalibrationTerrain` | IA N2 (fondation) — 4 coins touchés → homographie image ↔ terrain en mètres ; tout détecteur (ballon, joueurs) devient une position sur le terrain | Linux |
| `JeuDonnees` | Export JSON Lines des clips étiquetés — refusé sans consentement, minimisé | Linux |
| `LecteurMetadonneesVideo` | Date de création **avec son origine** (clé caméra = tournage ; en-tête = écriture, faux après ré-encodage) | macOS |
| `ExtracteurSignaux` · `ExporteurClip` · `AnalyseurEchanges` | Signal d'activité, audio 11 kHz en flux, export clip/montage multi-fichiers, analyseur concret | macOS |
| `playco-video` (CLI) · `CommandesVideo` | Outil en ligne de commande : infos, échanges, sifflets, match condensé | macOS |
| `CompensationCamera` | Vidéos du web : déplacement global de la caméra retiré (grossier puis fin), coupures de montage ignorées | Linux + vraie vidéo qui panoramique (macOS) |

### Tester sur une VRAIE vidéo, sans l'app (Mac)

```bash
cd Modules/PlaycoVideo
swift run playco-video infos ~/Movies/match.mov
swift run playco-video echanges ~/Movies/match.mov
swift run playco-video condenser ~/Movies/match.mov -o ~/Movies/match-condense.mp4
swift run playco-video caler ~/Movies/match.mov --points points.csv --montage ~/Movies/kills.mp4 --etiquette Kill
```

`condenser` = le match sans les temps morts (échanges + 2 s avant / 1,5 s après, réglables avec `--avant` / `--apres`).
`caler` = cale les points saisis sur la vidéo SANS ancre (recherche large si la date du fichier n'est pas fiable), puis monte les clips choisis. Format du CSV (séparateur « ; ») :

```
horodatage;etiquette;resultat;periode
2026-09-29T19:04:12.350-04:00;Kill;pourNous;1
```

**Vidéo YouTube** : l'outil lit un fichier local ; il ne télécharge rien. Tes propres vidéos : YouTube Studio → Télécharger. Télécharger la vidéo d'un autre enfreint les conditions de YouTube ; dans l'APP, importer depuis YouTube est interdit par l'App Store (règle 5.2.3) — l'app n'importera que depuis Photos/Fichiers. Sur une vidéo du web, la date du fichier n'est jamais fiable (ré-encodée) et la caméra bouge : la **compensation de caméra** (panoramiques retirés, coupures de montage ignorées) est active par défaut ; `--camera-fixe` la désactive pour comparer. Limite connue : les ralentis/reprises d'une diffusion télé peuvent être pris pour des échanges.

### Résultats sur données SIMULÉES (pas encore de vraie vidéo de match)

| Mesure | Résultat | Étiquette |
|---|---|---|
| Échanges retrouvés (bornes ±1 s), 3 matchs simulés de 40 échanges | rappel ≥ 95 %, précision ≥ 95 % | MESURÉ (simulé) |
| Calage automatique, horloge fausse de 37 s | erreur ≤ 4 s, fiable | MESURÉ (simulé) |
| Calage large, fichier ré-encodé (2 h 13 min d'écart) | erreur ≤ 4 s | MESURÉ (simulé) |
| Clips qui couvrent l'échange entier après calage auto + fenêtre apprise | ≥ 90 % | MESURÉ (simulé) |
| Vraie vidéo H.264 générée → échanges | bornes ±0,5 s | MESURÉ (synthétique) |
| Vrai WAV 44,1 kHz → sifflets | bornes ±60 ms | MESURÉ (synthétique) |

**Trouvailles de la boucle de test** : (1) le concurrent naturel du calage automatique est le décalage d'UN échange (~75 % des taps expliqués) → la fiabilité se juge à la marge, pas à un ratio ; (2) sans clé caméra, la date d'un fichier est celle de son écriture → calage large obligatoire ; (3) après un changement de plan (vidéo du web), l'activité d'un échange peut chuter de ~2,5× → des seuils globaux le ratent → seuils locaux.

### Reste à faire

| Tranche | Contenu |
|---|---|
| Colle app | Lier le package (Xcode → Add Local Package) ; adaptateur `PointMatch` → `EvenementMatch` sous `#if VIDEO` ; préréglages de cutups volleyball (sideouts ratés, kills d'un joueur…) |
| UI | Import (PhotosPicker/Fichiers), lecteur à pastilles, filtres, export/partage de montage |
| **Vraie vidéo** | Filmer 2-3 matchs avec stats live → banc d'essai réel, régler seuils et fenêtre (valeurs actuelles ESTIMÉES) |
| IA N2 | Suivi du ballon (modèles open source YOLO → Core ML), mesuré au même banc d'essai |

## Sources

- [Hudl — Balltime](https://www.hudl.com/products/balltime) · [Hudl — AI volleyball](https://www.hudl.com/blog/ai-volleyball)
- [VolleyVision (GitHub)](https://github.com/shukkkur/VolleyVision) · [volleyball-tracking (GitHub)](https://github.com/jadidimohammad/volleyball-tracking) · [sujet GitHub volleyball-tracking](https://github.com/topics/volleyball-tracking)
