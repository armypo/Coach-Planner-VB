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

## Phase 1 — replay indexé (en cours)

| Tranche | Contenu | État |
|---|---|---|
| 1a | Flag `VIDEO` · `IndexVideoMatch` (alignement, chapitres, filtres « cutups ») · `VideoMatchStore` (local, hors sauvegarde iCloud) · tests | ✅ code — **à compiler sur Mac** |
| 1b | Import (PhotosPicker/Fichiers) · heure de début lue dans les métadonnées du fichier (hypothèse à valider sur vidéo iPhone réelle) · suppression de la vidéo dans la cascade de suppression de match | ☐ |
| 1c | Lecteur à pastilles (1 pastille = 1 point) · filtres · export de clip | ☐ |
| 1d | Calibration de la fenêtre de clip (8 s avant / 3 s après — ESTIMÉ) sur un vrai match filmé + stats live | ☐ |

## Sources

- [Hudl — Balltime](https://www.hudl.com/products/balltime) · [Hudl — AI volleyball](https://www.hudl.com/blog/ai-volleyball)
- [VolleyVision (GitHub)](https://github.com/shukkkur/VolleyVision) · [volleyball-tracking (GitHub)](https://github.com/jadidimohammad/volleyball-tracking) · [sujet GitHub volleyball-tracking](https://github.com/topics/volleyball-tracking)
