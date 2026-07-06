# Revue adversariale finale — Roadmap Playco v2.2.x → v3.x

Relecture à charge du plan `/Users/armypo/.claude/plans/si-tu-avait-a-typed-rossum.md`, contre-vérifiée sur le code du worktree (TerrainEditeurViewModel, ContentView, RechercheGlobaleView, FeatureGating, docs/). Verdict global : **l'architecture de la roadmap est saine (séquencement vidéo, pari unique, démo transversale), mais l'arithmétique budgétaire est fausse, la règle ×2 n'est appliquée nulle part, et deux risques App Review (UGC, mineurs en vidéo) sont séquencés APRÈS la mise en vente.**

---

## 1. Dépendances

### Vérifiées correctes
- **2.9 « carte N clips » → 2.5 (Aujourd'hui)** : ordre correct (2.5 en H1, 2.9 en H2). Mais la dépendance n'est PAS déclarée dans la section Vérification, qui ne liste que 2.8→2.8.2, 2.7→2.8.1, 2.10 après 2.9. Idem 2.10 (paywall 3 cartes) → 2.4 (tokens Mat) : ordre correct, non déclaré.
- **Rien en H1 ne dépend d'un livrable H2** : confirmé. 2.7 est autonome ; la carte héro de 2.5 ne référence les clips qu'à partir de 2.9 ; 2.6.2 (PDF) dépend de 2.6 (blocs/heure réelle) mais pas de 2.6.3 (facettes) — l'ordre interne 2.6 → 2.6.2 → 2.6.3 tient.
- **2.2.1 vérifié dans le code** : `chargerEtapeActive` vide bien `pileUndo`/`pileRedo` (TerrainEditeurViewModel, `removeAll()` en tête de fonction). Le fix est réel.
- **2.5.2 « recherche déjà codée, invisible »** : `RechercheGlobaleView` est câblée en sheet dans ContentView (`$afficherRecherche`) ; aucun déclencheur visible trouvé — l'affirmation tient.

### Dépendances cachées trouvées
1. **2.3 (QR / lien universel `playco.app/join/…`) exige une infra web non déclarée** : domaine `playco.app` servi en HTTPS avec fichier AASA + entitlement Associated Domains + provisioning. C'est du « backend » AVANT 2.7, et une action humaine (DNS, hébergement) absente de la liste. Accessoirement, cela contredit le principe « un domaine n'obtient un serveur que si une ligne de revenus le finance » — l'exception (hosting statique) doit être assumée par écrit.
2. **2.10 vend Élite AVANT le durcissement 2.11** : quotas + kill-switch upload, tests RLS automatisés et signalement/retrait/blocage UGC sont tous en 2.11, c'est-à-dire APRÈS l'ouverture des ventes (2.10) et APRÈS le partage de clips aux athlètes (2.9.2). Deux problèmes distincts : (a) **App Review guideline 1.2** — dès que 2.9.2 expose de l'UGC (vidéos, souvent de mineurs) à d'autres utilisateurs, la modération/signalement doit exister DANS CETTE soumission, pas deux patchs plus tard ; risque de rejet direct ; (b) **risque financier** — vendre un quota « ~300 min/mois » sans mécanisme d'enforcement ni kill-switch.
3. **Consentement vidéo de mineurs** : 2.2.3 couvre la création de profils <18, mais la CAPTATION vidéo (2.7.1 enregistrement, 2.8.2 tagging live) est un traitement distinct — le consentement/attestation doit être étendu au domaine vidéo au plus tard en 2.7.1, pas en 2.11.
4. **2.6.3 n'est pas un champ additif** : « migration `CategorieExercice`→tags » transforme des données utilisateur existantes d'un @Model vers un autre format. Ni stratégie de migration (double lecture ? rétro-compat vieux clients CloudKit qui écrivent encore `CategorieExercice` pendant la fenêtre de mise à jour ?) ni flag CloudKit-safe. C'est le patch le plus risqué de la roadmap côté schéma et il est présenté comme un patch de confort de 1,5 sem.
5. **2.7 introduit la première dépendance SPM du projet** (supabase-swift) dans une app dont l'argument est « aucune dépendance externe » : impact binaire, revue supply-chain, et surtout vérification que le SDK ne compile PAS dans la cible DEMO — mentionné pour les clés, pas pour le SDK lui-même.
6. **Champs @Model non flaggés CloudKit-safe** : 2.2.3 (attestation coach horodatée = nouveau champ ou @Model ?), 2.6.1 (thème de semaine sur `PhaseSaison`), 2.3.2 (trace de promotion `MatchCalendrier`→`Seance`). 2.2.4, 2.3 (sportID), 2.6 et 2.6.3 (`dernierUsage`) sont correctement flaggés — la discipline existe mais n'est pas uniforme.

---

## 2. Budget — l'arithmétique ne tient pas

Recalcul en additionnant la colonne Effort (5 j = 1 sem, midpoints) :

| Chantier | Somme des patchs | En-tête annoncé | Écart |
|---|---|---|---|
| 2.2.x | ~2,6 sem (+ « continu » non chiffré) | ~3 sem | ok |
| 2.3 | 2 + 0,8 + 1 = **3,8 sem** | 2,5-3 sem | **+0,8 à +1,3** |
| 2.4 | 2 + 0,6 = **2,6 sem** | 2-2,5 sem | +0,1 |
| 2.5 | 3 + 1,5 + 0,6 = **5,1 sem** | 3-4 sem | **+1,1 à +2,1** |
| 2.6 | 2,5+1+0,8+1,5 = **5,8 sem** (+2.6.4 continu) | 5-6 sem | ok |
| 2.7 | 2 + 1,5 = **3,5 sem** | 3 sem | +0,5 |
| **Total H1** | **~23,4 sem** | récap : « ~13-14 (sur ~12) » | **marge fantôme ~9-10 sem** |

Le « ~13-14 » du récapitulatif correspond en réalité à H1 **SANS 2.6 ni 2.7** (23,4 − 9,3 = 14,1), alors que la ligne du tableau annonce « 2.2.1→2.7.1 ». Autrement dit : le récap présente comme garde-fou (« 2.6 et 2.7 éjectables ») ce qui est en fait **déjà consommé** dans son propre chiffre. Et même 14,1 sem dépasse le budget réel : juillet→novembre = 5 mois ≈ 10,5-12,5 sem effectives à 25-30 sem/an. **Conclusion mécanique : 2.6 ET 2.7 glissent en H2 avec quasi-certitude, et il manque encore ~2 sem en H1.**

| Horizon | Somme réelle | Récap | Si 2.6+2.7 glissent |
|---|---|---|---|
| H2 | 4,5+4+1,7+3 = **13,2 sem** | ~10,5-11,5 (sur ~10-11) | **~22,5 sem sur 10-11** |
| H3 | 5,5 + 4-5 = **9,5-10,5 sem** | ~9-10 | ok, mais 3.0 somme 5,5 vs en-tête 4-4,5 |

Le garde-fou « éjectable vers H2 » **n'a aucune capacité d'accueil** : H2 est déjà en dépassement de ~2 sem sur son propre contenu (le pari vidéo, non compressible puisque c'est LE pari de l'année).

**Règle ×2 : non appliquée.** Elle n'apparaît explicitement qu'une seule fois (« 14-19 sem brutes ×2 » pour Terrain 2.0, option C de 3.2). Rien n'indique si « 2.5 = 3 sem » est brut ou post-×2 — et 3 semaines pour remplacer le routeur ContentView + DockBar + 5 NavigationSplitView par une TabView 5 espaces avec fusion Playbook ressemble fortement à une estimation brute. Si les chiffres sont bruts, H1 réel = ~47 sem : la roadmap est infaisable telle quelle. La roadmap DOIT déclarer la convention (chiffres = post-×2) et assumer les coupes qui en découlent.

**Coûts non budgétés nulle part** : maintien du build démo (rebase de `suivis/pr6` à ~10 mineures, dont deux rebases lourds 2.4 et 2.5 ≈ 1-2 sem/an) ; écriture de tests pour tenir la baseline 253 (la refonte stats a coûté 67 tests ; 2.5/2.6 = +2-3 j chacun) ; le lancement App Store lui-même (allers-retours review, actions ASC Phase 2 connues bloquantes) ; infra Supabase/Stream à découvert de 2.7 (H1) à 2.10 (H2), soit 4-6 mois avant le premier dollar Élite.

---

## 3. Périmètre des patchs et numérotation

- **2.5 est le patch le plus dangereux de H1** : « périmètre réductible » sans plan de réduction est un vœu, pas un garde-fou. La fusion Playbook (Bibliothèque+Stratégies+Formations) est un chantier à part entière caché dans une ligne. Sous-ensemble livrable à définir MAINTENANT : 2.5a = coquille 5 espaces avec mapping 1:1 des vues existantes (livrable/reviewable seul) ; 2.5b = fusion Playbook (peut fusionner avec 2.6 dont c'est le prérequis naturel).
- **Convention x.y violée** : « correctif 2.x.y = <1 sem » — or 2.5.1 = 1,5 sem, 2.6.3 = 1,5 sem, 2.7.1 = 1,5 sem, 2.9.2 = 1,5 sem. Soit la convention change (« x.y = sous-livraison ≤1,5 sem »), soit ces patchs deviennent des mineures.
- **2.6.4 et 2.2.5+ « continu » ne sont pas des patchs** : ce sont des réserves de capacité. Les chiffrer (ex. 2.2.5+ = 1 sem réservée, 2.6.4 = 2 j/sem pendant 5 sem) et les inclure dans les totaux — sinon ils sont de la marge fantôme inversée.
- **2.10.1 (1 j)** n'est pas un livrable App Store (page web + décision de ne rien publier) : le sortir de la numérotation binaire, le rattacher comme note à 2.10.
- **2.3 mélange trois natures** : QR login (produit), Phase 0 SportPack (dette d'architecture), règle i18n (politique transversale permanente). La règle i18n doit migrer dans les politiques transversales à côté de la politique démo — une règle « pour tout écran touché désormais » n'est pas versionnable.
- **Reviewabilité seule** : chaque mineure repasse en App Review — 2.2.1→2.2.4 = jusqu'à 4 soumissions en 3 sem pendant la fenêtre de lancement, là où les premiers retours/rejets tombent. Regrouper (2.2.1+2.2.2, puis 2.2.3+2.2.4) = 2 soumissions.

---

## 4. Politique démo — trous identifiés

1. **Contradiction interne §4 vs §5** : §4 exclut « le domaine Supabase/vidéo (2.7-2.9) » en bloc ; §5 inclut « mode exécution (2.8) ». Or 2.8 (le patch) contient le mode exécution SANS vidéo. Réécrire §4 : « exclusions = 2.7, 2.7.1, 2.8.1, 2.8.2, 2.9.x ».
2. **Wizard 3 écrans (2.5.1) en démo : écran 1 = SIWA.** Le flag DEMO bypasse le login, mais alors comment la démo (qui démarre VIDE) crée-t-elle son équipe ? Le flux « wizard sans écran SIWA, création d'équipe locale » doit être spécifié dans 2.5.1 — c'est LE chemin d'entrée de la vitrine.
3. **25 exercices (2.6.4) vs « démarre VIDE, aucun seed » (décision 2026-07-04)** : la politique démo §1 déclare les 25 exercices « fondations de l'expérience démo », mais la décision fondateur dit aucun seed. À trancher explicitement : si les 25 exercices sont du contenu PRODUIT (via `BibliothequeDefauts.peuplerSiVide`, présent chez tous les utilisateurs), ils ne sont pas un « seed démo » et la contradiction disparaît — mais il faut l'écrire, sinon quelqu'un les coupera de la démo au nom de la décision du 4 juillet.
4. **2.5 supprime le DockBar** : Messages/Profil déménagent (Équipe / Aujourd'hui). En démo, pas d'utilisateur connecté : qui est l'expéditeur d'un message ? La messagerie démo mono-utilisateur est un état vide supplémentaire à soigner, non couvert par la ligne « impact démo » de 2.5.
5. **QR / Associated Domains (2.3)** : « vérifier que le flag DEMO compile le chemin » est insuffisant. Préciser que la cible DEMO n'embarque PAS l'entitlement Associated Domains (sinon un scan de QR peut router vers le build démo installé).
6. **SDK Supabase en démo (2.7)** : la politique exclut « clés/SDK actifs » — exiger plus fort : le package ne LINK pas dans la cible DEMO (condition de target SPM), pas seulement « pas d'appel ».

---

## 5. Risques d'exécution oubliés

- **App Review par mineure** : 2.9.2 (UGC partagé) et 2.10 (nouveaux produits d'abonnement + retrait club.*) sont les deux soumissions à plus haut risque de rejet ; aucune marge calendrier n'est prévue pour un aller-retour de review (compter 1 sem tampon chacune). Vérifier « 0 abonné club » au moment T, pas au moment de la rédaction.
- **Schéma CloudKit production** : chaque champ additif doit être déployé au schéma prod (cf. `docs/CloudKit_Schema_Deployment.md`) AVANT le binaire — à inscrire dans la checklist de release de CHAQUE patch touchant un @Model (2.2.3, 2.2.4, 2.3, 2.3.2, 2.6, 2.6.1, 2.6.3), au même titre que « test de compilation DEMO ».
- **2.11.1 (rollover) est daté par la réalité (fin de saison mai 2027) mais placé en dernier de H2** — le patch le plus susceptible d'être éjecté est aussi le seul à deadline externe dure. Le marquer non-éjectable ou le remonter.
- **Chevauchement lancement/2.2.x** : le plan le mentionne mais ne réserve aucune capacité pour les retours du lancement lui-même (crash triage, review metadata, questions ASC). La « fenêtre 2.2.5+ » doit être chiffrée.
- **Fenêtre GO/NO-GO (2.11)** : le critère « rétention pilote » demande du temps calendaire de pilote (semaines d'usage réel) — non représenté dans le budget H2 ; le GO/NO-GO de 3.2 (mai 2027) risque de statuer sur 4-6 semaines de données seulement.

---

## 6. Contradictions C1-C11

Traçables dans les patchs : **C1** (couleurs de poste jetons terrain — décision 2, exception explicite), **C2** (8 glyphes d'outils — décision 2), **C3** (Terrain 2.0 = candidat pari 3.2, pas calendrier ferme), **C4** (mode exécution prérequis vidéo — 2.8, déclaré), **C7** (écran d'information neutre sans achat in-app — 2.10), **C9** (palette annotation 3 couleurs — 2.9.1). **Non traçables : C5, C6, C8, C10, C11** — résumées en « C5-C7 pricing/steering, C8-C11 divers » sans qu'un relecteur puisse vérifier où chacune atterrit. Pour un document qui revendique « les 11 arbitrages appliqués », c'est un trou de traçabilité : exiger un tableau C# → décision → patch porteur dans `docs/Vision_Playco_3.0.md`.

---

# AMENDEMENTS À APPLIQUER (patch par patch)

## Bloquants

1. **[Récap budget] Corriger l'arithmétique H1/H2** : le total H1 réel (somme des patchs) est ~23,4 sem, pas 13-14 ; le « 13-14 » n'est vrai que sans 2.6/2.7. Réécrire le tableau avec les sommes réelles, et acter dès maintenant que **2.6 OU 2.7 (au moins un des deux) est planifié en H2 d'office** — puis résoudre le dépassement H2 induit (~22,5 sem sur 10-11 si les deux glissent) en coupant : candidats désignés = 2.5.1 roster CSV, 2.6.1, 2.6.3 (reportés post-3.0), 3.0.2.
2. **[Gouvernance] Déclarer la convention ×2** : une ligne en tête de roadmap — « tous les efforts affichés sont POST-×2 » — et re-vérifier patch par patch que c'est crédible (2.5 à 3 sem post-×2 = 1,5 sem brutes pour la refonte de navigation : intenable ; re-estimer 2.5 à 4-5 sem minimum ou le scinder, cf. amendement 4).
3. **[2.9.2] Déplacer le signalement/retrait/blocage UGC de 2.11 vers 2.9.2** : la guideline 1.2 exige la modération dans la soumission qui introduit le partage de vidéos (souvent de mineurs) aux athlètes. 2.9.2 passe de 1,5 à ~2 sem ; 2.11 rétrécit d'autant.
4. **[2.5] Définir le plan de réduction écrit** : 2.5a = TabView 5 espaces avec mapping 1:1 des vues existantes (livrable seul) ; 2.5b = fusion Playbook, extraite et rattachée à 2.6 (son vrai client). « Périmètre réductible » sans découpage nommé n'est pas un garde-fou.
5. **[2.10] Conditionner la mise en vente d'Élite à un enforcement minimal du quota** : remonter dans 2.10 le compteur de minutes + blocage d'upload au plafond (le kill-switch global et les alertes facturation peuvent rester en 2.11). Vendre « ~300 min/mois » sans mécanisme = passif juridique et financier.
6. **[Politique démo §4/§5] Résoudre la contradiction 2.8** : §4 doit lister « 2.7, 2.7.1, 2.8.1, 2.8.2, 2.9.x » au lieu de « 2.7-2.9 ».

## Importants

7. **[2.3] Déclarer l'infra lien universel** : ajouter aux actions humaines de 2.3 le domaine playco.app + AASA + entitlement Associated Domains, et l'exception écrite au principe « pas de serveur sans revenu » (hosting statique). Préciser que la cible DEMO n'a pas cet entitlement.
8. **[2.7.1] Étendre le consentement mineurs à la captation vidéo** : attestation/politique de 2.2.3 référencée et complétée dans 2.7.1 (captation) — pas en 2.11.
9. **[2.6.3] Requalifier la migration CategorieExercice→tags** : ce n'est pas un ajout de champ ; exiger dans le patch une stratégie de migration explicite (double lecture, mapping automatique catégorie→tag, tolérance vieux clients CloudKit) + tests de migration. Ré-estimer à 2 sem ou reporter post-3.0.
10. **[2.5.1] Spécifier le wizard en mode DEMO** : écran SIWA sauté, création d'équipe locale, données vides — c'est le chemin d'entrée de la vitrine bêta.
11. **[Politique démo §1 / 2.6.4] Trancher « 25 exercices vs démarre vide »** : écrire que les 25 exercices sont du contenu produit (peuplerSiVide, tous utilisateurs), donc présents en démo SANS violer « aucun seed » — ou amender la décision du 2026-07-04.
12. **[2.2.x] Regrouper les soumissions** : 2.2.1+2.2.2 puis 2.2.3+2.2.4 (2 reviews au lieu de 4 pendant la fenêtre de lancement) ; chiffrer la fenêtre 2.2.5+ (ex. 1 sem réservée) et l'inclure au total H1.
13. **[2.11.1] Marquer le rollover non-éjectable** (deadline externe : fin de saison mai 2027) ou le remonter en tête de H2 ; c'est actuellement le dernier patch du pire horizon.
14. **[Checklist release transversale] Ajouter deux items** à la checklist de chaque patch : (a) déploiement du schéma CloudKit prod avant le binaire pour tout patch touchant un @Model (2.2.3, 2.2.4, 2.3, 2.3.2, 2.6, 2.6.1, 2.6.3) ; (b) budget tests pour tenir la baseline 253 (compter +2-3 j sur 2.5 et 2.6).
15. **[2.7] Exiger l'exclusion du SDK Supabase au niveau du LINK** dans la cible DEMO (condition de target SPM), pas seulement « aucun appel » ; noter que c'est la première dépendance externe du projet (revue supply-chain).
16. **[Vision maître] Tableau de traçabilité C1-C11 → patch porteur** : C5, C6, C8, C10, C11 sont invérifiables dans la roadmap actuelle.
17. **[Budget transversal] Chiffrer le maintien du build démo** (~1-2 sem/an de rebases de `suivis/pr6`, dont 2.4 et 2.5 lourds) et le déduire des horizons.

## Mineurs

18. **[Convention] Aligner la règle « x.y = <1 sem »** avec la réalité (2.5.1, 2.6.3, 2.7.1, 2.9.2 à 1,5 sem) : soit « ≤1,5 sem », soit promotion en mineures.
19. **[2.3] Sortir la règle i18n du patch** et la placer dans les politiques transversales (c'est une règle permanente, pas un livrable).
20. **[2.10.1] Dénuméroter** (note de décision rattachée à 2.10, pas un patch App Store).
21. **[Vérification] Compléter la liste des dépendances déclarées** : ajouter 2.9→2.5 (carte « N clips » suppose Aujourd'hui) et 2.10→2.4 (paywall 3 cartes sur tokens Mat).
22. **[2.5, impact démo] Couvrir la messagerie post-DockBar** : état vide messagerie en démo (pas d'expéditeur connecté) à spécifier avec les autres empty states.
23. **[3.0] Réconcilier l'en-tête (4-4,5 sem) avec la somme des sous-patchs (5,5 sem)** ; idem 2.3 (2,5-3 vs 3,8), 2.4 (2-2,5 vs 2,6), 2.7 (3 vs 3,5), 3.1 (3-4 vs 4-5).
24. **[2.10] Ajouter la vérification factuelle « 0 abonné club.* » au moment du retrait** (pas seulement à la rédaction) + 1 sem de tampon review sur 2.9.2 et 2.10 (soumissions à plus haut risque de rejet).
25. **[2.11] Expliciter la durée calendaire du pilote** (les semaines d'usage réel nécessaires au critère de rétention ne sont pas des semaines d'effort, mais elles contraignent la date du GO/NO-GO de 3.2).
