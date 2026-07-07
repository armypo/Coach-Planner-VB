# Roadmap Playco v2.2.x → v3.x — référence d'exécution

> **Statut : approuvée (2026-07-06), amendée le jour même par la révision fondateur design** (« Mat Nuit » : interaction directe sans CTA, courtside essence conservée, 5 couleurs en tons neutres sur fond sombre, Liquid Glass 3.0 comme matière — voir [Vision_Playco_3.0.md](./Vision_Playco_3.0.md) §2). Issue de la vision (2 panels de design + revue adversariale nuit — matériaux dans [Vision_Playco_3.0_Annexes/](./Vision_Playco_3.0_Annexes/)). Ce document est LA référence du skill `/playco-patch` : chaque patch s'exécute depuis sa fiche ici, et son statut se met à jour ici (✅ + date + écarts).
> **Version recut** : la revue nuit a invalidé l'arithmétique de la v1 (H1 réel ~23 sem pour ~12 disponibles) — voir [annexe 13](./Vision_Playco_3.0_Annexes/nuit-13-revue-adversariale-roadmap.md) et le [verdict](./Vision_Playco_3.0_Annexes/nuit-16-verdict-final.md).

## Conventions (opposables)

- **Efforts affichés = BRUTS** ; le budget se pilote en post-×2. Gouvernance : 25-30 sem effectives/an, **UN pari >6 sem/an** (2026-27 = la vidéo), stop à ×1,5 de dépassement → découper.
- **Mineure `2.x`** = un chantier, une soumission App Store. **`2.x.y`** = sous-livraison ≤ 1,5 sem.
- Chaque patch : livrable seul · baseline tests (253 sur main v2.2) + build 0/0 · compilation DEMO en CI · **schéma CloudKit prod déployé AVANT le binaire** pour tout patch touchant un @Model · i18n zéro chaîne en dur (politique transversale dès 2.3) · gel du couplage volley (phase 0 SportPack) · rebase `suivis/pr6` post-merge.
- Dépendances déclarées : 2.7 → 2.8.1 · 2.8 → 2.8.2 · 2.5a → 2.9 (carte Aujourd'hui) · 2.4 et 2.9 → 2.10 · 2.9.1 = post-GO.
- Skills d'exécution : `/playco-patch` (moteur), `/playco-mat-review` (dès 2.4), `/playco-demo-check` (post-merge), `/playco-video-securite` (2.7→2.11), `/playco-roadmap-status` (réancrage).

## Décisions fondateur en attente de ratification

| # | Décision | Statut |
|---|---|---|
| 1 | Recut : Séances 2.0/Composer hors 2026-27, H2 = pari vidéo seul, GO/NO-GO juin 2027 | ☐ à ratifier |
| 2 | Convention ×2 (chiffres v1 = bruts) | ☐ à ratifier |
| 3 | 25 exercices = contenu produit (`peuplerSiVide`), visibles en démo | ☐ à ratifier |
| 4 | Pilote hors paywall dès 2.9.2 + geste envers les pilotes à 2.10 | ☐ à ratifier |
| 5 | Actions de la semaine : ASC accords/produits, Dashboard CloudKit, domaine playco.app + Xcode Cloud | ☐ à faire |

---

# H1 — juillet → novembre 2026 (~12 sem effectives) : lancer, instrumenter, matifier, restructurer

| Patch | Statut | Contenu | Effort brut |
|---|---|---|---|
| **2.2.a** (1 soumission) | ✅ 2026-07-06 (commit `7cd6594`) | Fix undo terrain (piles undo/redo PAR ÉTAPE, clé UUID stable — naviguer ne détruit plus l'historique, reset au chargement de document, purge à la suppression d'étape) + State Restoration match live (`Helpers/MatchLiveRestauration` : marqueur UserDefaults expirable 6 h posé/effacé par `MatchLiveSplitView`, resélection auto `MatchsView`, alerte « Reprendre » dans `MatchDetailView` gardée par `statsEntrees`, `restaurerSetActuel()` reprend au set le plus avancé). **Écarts : aucun.** Tests 253 → **270/270** (17 nouveaux), build 0/0. Revue multi-dimensions (18 agents) : 8 trouvailles confirmées, TOUTES corrigées (commit `431a5e3` — reprise live gardée par `peutModifier`, `lectureSeule` enfin appliquée au dashboard live [trou préexistant], fetch borné, budget mémoire undo global 60). Reste : soumission App Store (groupée avec 2.2.b) + rebase `suivis/pr6` post-merge | 1 sem |
| **2.2.b** (1 soumission) | ✅ 2026-07-06 (commit `c4ddbf5`, 280/280) | Consentement mineurs minimal (attestation horodatée — champ CloudKit-safe, avis parent par lien, DM adulte↔mineur off par défaut) + statut disponibilité joueur (blessé/malade/suspendu — grisé composition/présences, muscu suspendue) + **TelemetryDeck** (AnalyticsService, 17 événements, no-op sous DEMO — baseline rétention pré-vidéo pour le GO/NO-GO) + **MetricKit** (crash/hang natif, zéro dépendance) | 2 sem |
| **2.2.5+** | ☐ | Fenêtre retours lancement (crash triage, review, ASC) — réservée, ne se remplit pas de features | 1 sem |
| **2.6.2** | ☐ | PDF « Plan de pratique » une page (heure·exercice·diagramme miniature·consignes + présences à cocher — `PDFExportService` rodé). Casable dans la fenêtre 2.2.5+ | 2-3 j |
| **2.3** | ☐ | **Login/jonction QR + lien universel** `playco.app/join/{codeEquipe}/{codeInvitation}` (fallback code hors-ligne) — infra : domaine + AASA + entitlement Associated Domains (ABSENT aujourd'hui ; la cible DEMO ne l'embarque PAS ; exception écrite « hosting statique » au principe serveur) · **Phase 0 SportPack** (`Equipe.sportID = "volleyball"` CloudKit-safe, gel du couplage hors des 6 enums recensés, lint) · **CI minimale** (scheme partagé — aujourd'hui dans xcuserdata, build+test PR toolchain stable, **build DEMO automatisé** ; recommandation Xcode Cloud) · spikes S2 (AASA 0,5-1 j) et S3 (2 glyphes tab bar bout-en-bout, dessin parallélisé) | 2,5 sem |
| **2.3.1** | ◐ partiel 2026-07-06 | Duplication « Continuer » LIVRÉE (arrivées → départs par association trait↔jeton la plus proche, seuil 0.08 normalisé ; traits/rotations/encre non copiés ; bouton dans la barre d'étapes ; 2 tests, 282/282). **Reste : preset cadrage demi-terrain** — requiert un nouveau cas TypeTerrain + 2 fonctions de rendu + ratio (10+ fichiers, piège coordonnées #3) : à faire en tête de session dédiée, pas en fin de contexte | 2-3 j |
| **2.3.2** | ☐ | Match éclair (2 champs) + composition persistante (6 de départ pré-rempli) + promotion `MatchCalendrier`→`Seance` (champ de trace CloudKit-safe) | 1 sem |
| **2.4** (+2.4.1) | ☐ | **Mat Nuit vague 1 (révisé fondateur)** : tokens **nuit** (fond `#0D0D0F` par défaut, encre claire, filet blanc 10 % ; `encre3` décoratif seulement ; audit contraste), **les 5 couleurs d'espace recalibrées en tons neutres** (terre/brique/ardoise/sauge/lavande — remplacent les hex vifs, jamais en aplats de texte), couleur d'équipe conservée pour l'identité (jetons nous, en-tête), échelle typo 11 tokens + repli Dynamic Type, purge `.rounded`/gradients d'ambiance/`.hierarchical`, rayons 6/10/14, **Liquid Glass 3.0** : verre sombre = LA surface (teinte d'espace ≤ 12 %, une seule couche, encre ≥ 7:1, reflet 1 px + bordure 8-10 %, tableaux sur verre renforcé) — rebase des corps `glassCard()`/`glassSection()` **sans changer les signatures** (la migration `.glassEffect` de juin devient la fondation), **interaction directe** (cartes tappables, pas de CTA en mots), 5 glyphes tab bar maison + labels a11y (2-4 j de dessin), 10 lois documentées (lois 2/4/5 révisées → `/playco-mat-review`), **empty states maison**, **tests unitaires de contraste des tokens** | 2,5-3 sem |
| **2.5a** | ☐ | **Coquille navigation 5 espaces** : TabView `.sidebarAdaptable` (Aujourd'hui avec **carte héro tappable en entier — pas de bouton CTA** [révision fondateur] + recherche exposée [`RechercheGlobaleView` câblée mais sans déclencheur] / Préparer / Coacher / Analyser / Équipe), chaque espace teinté de son ton neutre (verre ≤ 12 %), mapping 1:1 des vues existantes, retrait DockBar (messagerie → Équipe, état vide démo à soigner), entrée démo routée vers Aujourd'hui. **La fusion Playbook (2.5b) est extraite** → backlog, rattachée au retour de Séances 2.0 | 2,5-3 sem |
| *(continu)* **2.6.4** | ☐ | 25 exercices signés (7 habiletés × 2 niveaux), diagrammes 100 % vectoriels (`elementsData`, zéro encre PencilKit) — contenu PRODUIT via `peuplerSiVide` (décision fondateur #3) | ~0,5 j/sem |

**Total H1 ≈ 12 sem.** Premiers éjectables : snapshots (~10 écrans post-Mat, 2-3 j) puis 2.3.1.
**Impact démo H1** : rebases lourds après 2.4 et 2.5a (budget ~1-2 sem/an) ; empty states + entrée Aujourd'hui + messagerie vide ; CI compile DEMO à chaque PR ; 25 exercices visibles en démo.

## Suivis revue 2.2.b (21 trouvailles confirmées — corrigées sauf ci-dessous)

Corrigés : politique DM appliquée au POINT D'ENVOI + fiche scopée équipe + attestation réservée au coach (.admin/.coach) et tracée (`attesteParNom`) + `dateModification` au changement de statut + init analytics paresseuse + libéro gaté + MetricKit idempotent/logs publics + `Package.resolved` versionné + retention-fr alignée sur le comportement réel.
**Différés (session dédiée)** : (1) **sync miroir Public DB** — consentement/`statutDisponibilite`/`dateNaissance` absents de `JoueurPartage` (publication+import) : le gate est inopérant sur l'appareil de l'athlète et l'alerte statut invisible côté athlète — chantier CloudKitSharingService (High structurel) ; (2) purge du miroir Public DB à la suppression d'équipe ; (3) filtre PII sur les VALEURS (pas seulement les clés) des métadonnées analytics ; (4) `app_launched` ré-émis à chaque retour sur `.app` ; (5) call stack MetricKit non journalisée ; (6) privacy-policy EN à aligner (TelemetryDeck) + courriels unifiés + lien baseurl retention ; (7) fermer `conversationActive` par `.onChange` quand la paire devient interdite (le guard d'envoi couvre déjà le risque) ; (8) domaine origotech.ca/playco.app NXDOMAIN → action humaine domaine (les URLs légales de l'app pointent dans le vide — PRÉEXISTANT, bloque aussi 2.3).

# H2 — décembre 2026 → avril 2027 (~10-11 sem) : LE PARI VIDÉO, rien d'autre

| Patch | Statut | Contenu | Effort brut |
|---|---|---|---|
| **Spike S1** | ☐ | TUS/capture background sur iPad physique (thermique 90 min, reprise upload, espace disque) — risque n°1 du pari, **critère d'abandon écrit** avant de commencer | 3-4 j |
| **2.7** | ☐ | Vidéo phases 0-1 : `supabase/` (tables `membres`/`videos`/`video_tags`/`video_clips`/`video_annotations` **sport-agnostiques** + **table `usage_mensuel`** + pg_cron coût infra, RLS deny-by-default **+ matrice de tests RLS par rôle écrite AVEC les policies — shift-left**, Edge Functions `demande-upload`/`webhook-stream`, purge 30 j), `BackendService` façade (SIWA→JWT lazy, structs Codable, Realtime), **SDK supabase-swift NON LINKÉ dans la cible DEMO** (condition de target SPM) — première dépendance du projet, revue supply-chain | 2 sem |
| **2.7.1** | ☐ | Phase 2 : capture AVFoundation (permissions, interruptions, espace disque) + import PhotosPicker, TUS background maison, `FileAttenteUploadVideo` (HEVC, plafond FIFO — pattern JournalSyncStorage), clés plist, **consentement mineurs étendu à la CAPTATION** | 2 sem |
| **2.8** | ☐ | **Mode exécution de pratique minimal** (chrono par exercice, carte suivante, swipe = suivant = tag `debut_exercice`, cocher/sauter/note, présences en entrée, résumé → brouillon) — gabarit `SeanceLiveView` existant. **Inclus en démo (sans vidéo).** PRÉREQUIS du pipeline clips (C4) | 2 sem |
| **2.8.1** | ☐ | Lecture HLS (`LecteurVideoView` + scrubber à pastilles — minimal si besoin) + statut Realtime + fallback polling. Si 2.8 glisse, 2.8.1 passe devant (ne dépend que de 2.7.1) | 1 sem |
| **2.8.2** | ☐ | Tagging live pendant capture (staging local offline, boutons façon `PaveNumeriqueRapideView`) + `activerModeEnregistrement` (pause sync dédiée) | 1,5 sem |
| **2.9** | ☐ | Clips auto par exercice (découpage entre tags `debut_exercice`) + surface de consultation (fiche séance ; la carte Aujourd'hui peut suivre) | 1,5 sem |
| **2.9.2** | ☐ | Partage joueur RLS + intégrations `MonProfilAthleteView`/`JoueurDetailView` + **signalement/retrait/blocage UGC (guideline 1.2 — DANS cette soumission, qui expose des vidéos souvent de mineurs)** + tampon review 1 sem. **Le pilote 5-10 équipes démarre ICI, hors paywall (TestFlight + flag)** — recrutement + consentements parentaux entamés dès l'automne 2026 | 2 sem |
| **2.11.1** | ☐ | **Rollover de saison — NON-ÉJECTABLE (deadline externe : fin de saison mai 2027)** : dupliquer équipe, reporter roster, réémettre invitations, archives lecture seule | 1 sem |

**Total ≈ 13,7 sem — dépassement absorbé par** : 2.9.1 (annotation) sortie du chemin pilote (post-GO), wizard 3 écrans glissé au backlog, scrubber minimal.
**Exclusions démo H2** : 2.7, 2.7.1, 2.8.1, 2.8.2, 2.9.x (le mode exécution 2.8 EST en démo).

# Début H3 — mai → juin 2027 : vendre, durcir, décider

| Patch | Statut | Contenu | Effort brut |
|---|---|---|---|
| **2.10** | ☐ | **Paywall v3** : produits `entraineur.*` + `elite.*` (groupe `playco.pro` conservé), retrait `club.*` de la vente (**vérifier 0 abonné AU MOMENT T**), paywall 3 cartes (pièges #22/#23), `bloqueSiNonElite` (bypassé par flag DEMO + test contractuel), **enforcement quota : compteur minutes + blocage upload au plafond DANS ce patch** (~300 min/mois par abonnement, chiffré avant fiche ASC), grandfathering Pro v2 12 mois, 3 triggers `SeuilUpgradeService` (2e équipe→Pro ; surface vidéo→Élite ; 5e équipe/2e head coach→**écran d'information neutre sans canal d'achat in-app** — anti-steering C7), essai 14 j sans CC, geste envers les pilotes (décision #4), tampon review 1 sem. *Note (ex-2.10.1)* : grille Club/Org NON publiée avant son dashboard ; Stripe au premier contrat réel | 2 sem |
| **2.11** | ☐ | Durcissement final : kill-switch upload global + alertes facturation, vérification serveur du code d'invitation, sous-clips Stream côté athlète, pen-test + `/security-review`. **GO/NO-GO en juin 2027** (pilote ≥ 8 sem de données ; critères : rétention pilote [équipes actives N/N-4], infra ≤ 40 % du delta Élite−Pro via `usage_mensuel`) | 1,5 sem |
| **2.9.1** | ☐ | Annotation frame (AVAssetImageGenerator + réutilisation `CanvasDessinView`/`OverlayDessinView`, palette fermée 3 couleurs : encre/accent/graphite — C9). Post-GO | 1 sem |
| **3.0** | ☐ | **Release identité (réduite)** : Mat Nuit vague 2 — **refonte courtside, essence et practicité conservées** [révision fondateur] : fond opaque pur (exception au verre, assumée), AAA ≥ 7:1, boutons typographiques (mots ≥ 18-20 pt, anti-troncation), cibles ≥ 60 pt, Score 96 pt, pavé rapide et haptiques intouchés + **terrain « Le Trait » transposé nuit** (plan d'architecte, lignes claires, jetons pleins couleur d'équipe/contour, heatmap monochrome) + icône d'app + splash au device du terrain | 2,5-3 sem |

# Backlog 3.x — priorisé PAR la décision du pari 2027-2028 (3.2)

**Candidats du pari (UN seul démarre)** :
- **Vidéo MATCHS** — dérisquée par le pilote pratiques (mêmes tables/pipelines), 4-6 sem.
- **Dashboard club web + grille Club/Org publiée** — si contrat B2B Stripe en vue (lecture seule Supabase, la contrepartie produit du canal Stripe).
- **Terrain 2.0 profond** — spec de référence prête ([annexe 10](./Vision_Playco_3.0_Annexes/passe2-10-terrain-seances-playbook.md)) : un seul monde objet-d'abord, trajectoires sémantiques multi-segments, timeline de frames + onion skin, animation interpolée + scrubber, Pencil Pro, snapping/guides/lasso, présentation laser. 14-19 sem brutes.
- **Retour de Séances 2.0** — Composer split + heure réelle + blocs, gabarits liés aux `CreneauRecurrent`, thème de semaine, 2.5b fusion Playbook, facettes (ex-2.6.3 **requalifié** : migration de données `CategorieExercice`→tags = patch schéma le plus risqué — double lecture + tolérance vieux clients CloudKit + tests de non-perte exigés).

**Autres backlog** : rapport de match web par lien (2 sem, remplace PlayCast broadcast, couvre parents Android — chaque lien = acquisition) · Live Activity locale · Insights on-device (debrief fin de match Foundation Models, inclus dès Pro, fallback propre — Charts 3D et voix coupés) · App Intents + widget + Spotlight · wizard 3 écrans + roster collage/CSV · profil carrière athlète + CV recrutement PDF · comptes parents + profils gérés <13 ans (tier Club) · appareil partagé/poste de saisie · multi-sport : extraction SportPack + basketball (sur signal d'achat — [PR #3](../v3/MULTI_SPORT_PLAN.md) = spec de référence, calendrier caduc) · fédération/DLTA (sur contrat) · localisation EN (~30 mois) · beach comme produit · export MP4 des animations.

**Coupés définitivement (anti-scope-creep)** : 4 sports v3.0 · P2P Bonjour/AWDL · broadcast APNs + worker · analyse de pose · auto-tracking ballon/score · visionOS · Watch/CarPlay · Siri vocal courtside · 3D · App Clip · OCR roster · Superwall/RevenueCat · registre d'affiliations (Spordle — on s'y branche, on ne le remplace pas) · e-feuille officielle co-signée · module arbitres · Android natif · réseau social · tier gratuit à pubs · prix par athlète · paywall sur la logistique · dégressivité Club · moteur de suggestions d'habileté · Fastlane/Sentry au lancement (MetricKit + Xcode Cloud d'abord ; Sentry réévalué à 2.7).

---

## Actions humaines (Christopher) — par fenêtre

| Quand | Action |
|---|---|
| **Immédiat** | (0) TelemetryDeck : créer l'app sur dashboard.telemetrydeck.com et reporter l'ID dans `PlaycoInfo.plist` clé `TelemetryDeckAppID` (vide = logger-only) + mettre à jour le privacy label ASC à la prochaine soumission ; (a) ASC : accords payants + produits « Prêt à soumettre » (reliquat v2.0.1 — bloque le lancement) ; (b) Dashboard CloudKit Security Roles (`docs/Securite_AbonnementPublicDB.md`) ; (c) domaine playco.app derrière Cloudflare + choix CI (recommandé : Xcode Cloud, 25 h/mois incluses) |
| Avant 2.3 | AASA hébergé + entitlement Associated Domains (profil de provisioning) |
| Pendant 2.4-2.5a | Projet Supabase (provider Apple : Services ID + clé .p8) + compte Cloudflare Stream + secrets |
| Automne 2026 | **Recrutement pilote 5-10 équipes + consentements parentaux** (lead time le plus long de la roadmap) |
| Dès 2.9 | Produits ASC Élite/Entraîneur créés (« Prêt à soumettre ») |
| 2.10 | Vérification 0 abonné `club.*` au moment T ; tests sandbox StoreKit sur iPad physique |

## Instrumentation GO/NO-GO (8 signaux TelemetryDeck)

| Signal | Posé en |
|---|---|
| `match_live_started` / `seance_lancee` (baseline pré-vidéo) | 2.2.b |
| `video_capture_started` / `video_upload_completed` | 2.7.1 |
| `tag_pose` / `clip_genere` | 2.8.2 / 2.9 |
| `clip_partage` / `clip_vu_athlete` | 2.9.2 |
| Coût infra par équipe (requête SQL `usage_mensuel`) | 2.7 |

Rétention pilote = équipes actives semaine N / N-4. Santé infra = coût Stream+Supabase ≤ 40 % du delta Élite−Pro.

## Politique DÉMO transversale

1. La démo démarre VIDE (décision 2026-07-04) — les empty states (2.4.1), l'entrée Aujourd'hui (2.5a) et les 25 exercices produit (2.6.4) sont les fondations de l'expérience vitrine.
2. Rebase de `suivis/pr6` à chaque mineure ; compilation DEMO dans la CI (2.3).
3. Le flag DEMO bypasse : login, paywall Pro/Club, et `bloqueSiNonElite` (2.10, avec test contractuel).
4. **Exclusions** : 2.7, 2.7.1, 2.8.1, 2.8.2, 2.9.x (SDK Supabase non linké), rapport web, Live Activity — entrées UI masquées. La cible DEMO n'a pas l'entitlement Associated Domains.
5. **Inclusions à forte valeur vitrine** : match éclair (2.3.2), Playco Mat (2.4/3.0), navigation 5 espaces (2.5a), PDF plan de pratique (2.6.2), mode exécution (2.8).
6. Garde-fou : le build DEMO ne va JAMAIS en review App Store publique ; le « compte démo review » d'App Review = compte seedé sur build de PRODUCTION.

## Traçabilité des arbitrages de contre-vérification (C1-C11)

| # | Arbitrage | Patch porteur |
|---|---|---|
| C1 | Couleurs de poste sur les jetons terrain, matifiées + redondées (révision fondateur : les 5 couleurs d'espace en tons neutres coexistent — loi 2 réécrite) | 2.4 (loi 2 du kit Mat Nuit) |
| C2 | 2e liste fermée « glyphes d'outils d'éditeur » (8) pour la toolbar terrain | 2.4 (doctrine) ; appliquée au terrain à 3.0/Terrain 2.0 |
| C3 | Terrain 2.0 profond = candidat pari 2027-2028, pas un calendrier ferme | Backlog 3.2 |
| C4 | Mode exécution = prérequis explicite du pipeline clips | 2.8 (avant 2.8.2/2.9) |
| C5 | Add-on vidéo B2B ~5-8 $/équipe à justifier vs 3,75 $ implicite Élite | Note 2.10 ; tranché à la publication de la grille B2B (dashboard) |
| C6 | Break-even Fédé : ≈ 22 équipes depuis Organisation, ≈ 31 depuis Club | Vision §pricing |
| C7 | « Parlons Club » = écran d'information neutre, aucun canal d'achat in-app (steering 3.1.1/3.1.3) | 2.10 |
| C8 | Largeur de lecture 680 pt : texte courant/formulaires seulement — tableaux/terrain/timelines exemptés | 2.4 (kit Mat) |
| C9 | Palette d'annotation Pencil fermée à 3 (encre/accent/graphite) | 2.9.1 |
| C10 | CADUC (révision fondateur) : la migration `.glassEffect` de juin devient la fondation du Liquid Glass 3.0 — plus un coût, un acquis | 2.4 |
| C11 | REC = état live (rouge conforme) ; partage Playbook inter-coachs = AirDrop/`.playco` (YAGNI Supabase 12 mois) ; empty states maison = abandon assumé de ContentUnavailableView | 2.4.1 / backlog |
