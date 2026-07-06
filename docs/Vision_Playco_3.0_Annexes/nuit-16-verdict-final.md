# VERDICT FINAL — Roadmap Playco v2.2.x → v3.x

**Verdict d'ensemble.** L'architecture de la roadmap est bonne (pari unique vidéo, patchs livrables seuls, démo transversale, séquencement 2.4→2.5 confirmé). Mais son arithmétique est fausse et non récupérable par ajustements à la marge : la somme réelle des patchs H1 est **~23 sem contre ~12 disponibles**, H2 est déjà plein de son propre pari, et la règle ×2 n'est déclarée nulle part. La revue a raison sur le budget ; l'optim a raison sur l'instrumentation et le dérisquage — mais son bilan « net ~+1 sem » est de la comptabilité optimiste et est **rejeté**. Conséquence structurante, tranchée ici : **l'année 2026-2027 ne contient pas à la fois Séances 2.0/Playbook (2.6) ET le pari vidéo. La vidéo gagne (plan validé fondateur). 2.6 sort du calendrier 2026-27.** Deux risques App Review (UGC 2.9.2, quota Élite 2.10) sont corrigés avant mise en vente.

---

## 1. Amendements à la roadmap — liste finale ordonnée

Sources : [R]=revue, [O]=optim. Règle appliquée : chaque ajout déloge quelque chose ou tient dans une économie identifiée.

### A. Gouvernance & budget (bloquants — à appliquer avant tout patch)

1. **[R] Déclarer la convention d'estimation en tête de roadmap.** Les chiffres actuels sont traités comme **bruts** (2.5 à « 3 sem » pour remplacer routeur+DockBar+5 NavigationSplitView ne peut pas être post-×2). Toute fiche patch affiche désormais brut ET post-×2 ; le budget se pilote en post-×2.
2. **[R] Réécrire le récapitulatif budget avec les sommes réelles** (H1 ~23,4 · H2 ~13,2 · H3 ~10,5 sem) et supprimer la « marge fantôme » : le garde-fou « 2.6/2.7 éjectables » était déjà consommé dans le chiffre affiché.
3. **[verdict — recut des horizons]** Nouvelle grille (post-×2, corrections [O] R13 intégrées) :
   - **H1 (juil→nov, ~12 sem)** : 2.2.a (2.2.1+2.2.2, 1 soumission, 1 sem) · 2.2.b (2.2.3+2.2.4+télémétrie+MetricKit, 1 soumission, 2 sem) · fenêtre 2.2.5+ **chiffrée 1 sem** · 2.3 (QR/jonction + phase 0 SportPack + CI + spikes S2/S3, 2,5 sem) · 2.3.1 ramené à 2-3 j · 2.3.2 (1 sem) · 2.4+2.4.1 (+tests contraste, 2,5-3 sem) · **2.5a seul** (coquille TabView 5 espaces, mapping 1:1 des vues existantes, 2,5-3 sem). Total ≈ 12.
   - **H2 (déc→avr, ~10-11 sem) = LE PARI, rien d'autre** : spike S1 (0,7) · 2.7 (2, avec tests RLS + `usage_mensuel`) · 2.7.1 ré-estimé (2) · 2.8 (2, gabarit `SeanceLiveView`) · 2.8.1 (1) · 2.8.2 (1,5) · 2.9 (1,5) · 2.9.2+UGC (2) · **2.11.1 rollover (1, NON-ÉJECTABLE — deadline mai 2027)**. Total ≈ 13,7 → dépassement assumé de ~2-3 sem absorbé par : 2.9.1 (annotation) **sortie du chemin pilote** (post-GO), 2.5.1 wizard glissé, scrubber 2.8.1 minimal si nécessaire.
   - **Début H3 (mai-juin)** : 2.10 bascule pricing (+1 sem tampon review) · 2.11 durcissement final + **GO/NO-GO déplacé à juin 2027** (le pilote démarré à 2.9.2 a alors ≥8 sem de données — résout [R]#25) · puis 3.0 réduit (Mat vague 2 + Le Trait). 3.0.1, 3.0.2, 3.1, et le retour de 2.6 → backlog priorisé PAR la décision 3.2.
4. **[R] Coupes fermes de 2026-27** : 2.6 (Composer), 2.6.1 (gabarits), **2.6.3 reporté post-3.0 et requalifié** (migration de données CloudKit `CategorieExercice`→tags = le patch schéma le plus risqué de la roadmap, pas un confort de 1,5 sem ; stratégie double-lecture + tests de non-perte exigés le jour où il revient), roster CSV de 2.5.1 → backlog, 3.0.2 = premier éjectable de H3. **Restent de 2.6** : 2.6.2 (PDF plan de pratique, ramené à 2-3 j — `PDFExportService` rodé) casable en fenêtre 2.2.5+, et 2.6.4 (25 exercices) requalifié en travail de contenu continu **chiffré** (~0,5 j/sem), démarrant immédiatement, **contrainte : diagrammes 100 % vectoriels (elementsData), zéro encre PencilKit** [O R10].
5. **[R] Budgéter les coûts invisibles** : maintien du build démo ~1-2 sem/an (rebases `suivis/pr6`, dont 2.4 et 2.5a lourds) ; +2-3 j de tests sur chaque patch structurant pour tenir la baseline 253.

### B. Conformité & sécurité (bloquants — non négociables avant mise en vente)

6. **[R#3] Signalement/retrait/blocage UGC déplacé de 2.11 vers 2.9.2** (guideline 1.2 : la modération doit exister dans LA soumission qui expose des vidéos — souvent de mineurs — aux athlètes). 2.9.2 = 2 sem (déjà compté au recut).
7. **[R#5] Enforcement minimal du quota remonté dans 2.10** : compteur de minutes + blocage d'upload au plafond DANS le patch qui vend « ~300 min/mois ». Kill-switch global + alertes facturation restent en 2.11.
8. **[R#8 + O H7/H11] Consentement mineurs étendu à la captation vidéo dès 2.7.1** (l'attestation 2.2.3 couvre les profils, pas la captation) ; **recrutement pilote + consentements parentaux entamés dès l'automne 2026** — le plus long lead time de la roadmap.
9. **[O R6 = R] Shift-left RLS** : la matrice de tests automatisés par rôle (coach/athlète/étranger/anonyme) s'écrit AVEC les policies en 2.7, pas en 2.11. 2.11 garde pen-test + `/security-review`.
10. **[R#15] SDK supabase-swift : exclusion au niveau du LINK dans la cible DEMO** (condition de target SPM), pas seulement « aucun appel » ; noter que c'est la première dépendance SPM du projet (revue supply-chain).
11. **[R#7 + O R7/S2] Infra lien universel déclarée dans 2.3** : domaine playco.app derrière Cloudflare + AASA + entitlement Associated Domains (absent aujourd'hui — vérifié) + exception ÉCRITE au principe « pas de serveur sans revenu » (hosting statique) ; la cible DEMO n'embarque PAS l'entitlement. Spike S2 (0,5-1 j) avant d'écrire 2.3.
12. **[R#14] Checklist release transversale** (portée par le skill playco-patch) : (a) déploiement schéma CloudKit prod AVANT le binaire pour tout patch touchant un @Model ; (b) flagger CloudKit-safe les champs oubliés (2.2.3 attestation, 2.6.1 thème, 2.3.2 promotion) ; (c) tampon review 1 sem sur 2.9.2 et 2.10 + vérification factuelle « 0 abonné club.* » au moment T.

### C. Politique démo (corrections de spec)

13. **[R#6] §4 réécrit** : exclusions = « 2.7, 2.7.1, 2.8.1, 2.8.2, 2.9.x » (le mode exécution 2.8 sans vidéo EST en démo — la contradiction §4/§5 disparaît).
14. **[R#11] Tranché : les 25 exercices sont du contenu PRODUIT** (via `BibliothequeDefauts.peuplerSiVide`, présents chez tous les utilisateurs) — pas un seed démo ; compatible avec « démarre VIDE » du 2026-07-04. À écrire noir sur blanc (décision fondateur #3 ci-dessous pour ratification).
15. **[R#10] Spécifier le wizard 3 écrans en DEMO** (écran SIWA sauté, création d'équipe locale) — c'est LE chemin d'entrée de la vitrine ; **[R#22]** + état vide messagerie post-DockBar (pas d'expéditeur connecté) dans les empty states de 2.5a.

### D. Instrumentation & infra qualité (ajouts retenus, financés)

16. **[O R1] TelemetryDeck branché en 2.2.b (1-2 j)** — `AnalyticsService` existe, 17 événements catalogués, 9 call-sites câblés, no-op sous DEMO. Décisif : le GO/NO-GO exige une baseline de rétention pré-vidéo — branché en 2.11 il serait inutile. Financé par les corrections R13 (2.3.1 et 2.6.2 surestimés de ~3-4 j).
17. **[O R2] MetricKit natif (1-2 j, 2.2.b)** — zéro dépendance ; Sentry = décision différée à 2.7 seulement.
18. **[O R3] CI minimale en 2.3 (2-3 j)** : scheme partagé (aujourd'hui dans xcuserdata — bloquant 5 min), build+test PR toolchain stable, **et build de la config DEMO** — remplace la checklist manuelle de compilation DEMO répétée à chaque patch : auto-financée.
19. **[O R4 réduit] Tests unitaires de contraste des tokens dans 2.4 (1 j, rend les lois 5/10 exécutables) — retenus.** Snapshots swift-snapshot-testing : réduits à ~10 écrans post-Mat, 2-3 j, **premier éjectable de H1** si ça sature.
20. **[O R12] Les 8 signaux GO/NO-GO posés au fil des patchs** (tableau de l'optim) + table `usage_mensuel` + pg_cron coût infra dans les migrations 2.7 Phase 0 (~0,5 j) : le ratio ≤ 40 % devient une requête SQL.
21. **[O R8/R9] Spikes retenus** : **S1 TUS/capture background iPad physique (3-4 j, avant 2.7.1 — non négociable, risque n°1 du pari ; couvre la sous-estimation de 2.7.1)** ; S2 AASA (avant 2.3) ; S3 deux glyphes bout-en-bout (pendant 2.3, début du dessin parallélisé) ; S5 replié en critère d'acceptation de 2.7. **S4 « Le Trait » : opportuniste NON budgété.**
22. **[O R5] Pilote découplé du paywall** : démarre dès 2.9.2, vidéo offerte aux équipes pilotes (TestFlight+flag) ; 2.10 livré pendant que le pilote tourne. Compatible avec le tampon review [R#24]. **[O] Si 2.8 glisse, 2.8.1 (lecteur) passe devant** (il ne dépend que de 2.7.1).
23. **[O §6] Actions humaines avancées à leur fenêtre** : H1/H2 (ASC accords + Dashboard CloudKit) immédiat ; H5/H6 (domaine+entitlement) avant 2.3 ; H8/H9/H10 (Supabase/Stream/secrets) pendant 2.4-2.5a ; H13 (produits ASC Élite) dès 2.9.

### E. Hygiène documentaire (mineurs, au moment de créer `docs/Roadmap_…`)

24. **[R#18]** Convention x.y alignée : « sous-livraison ≤1,5 sem ». **[R#19]** Règle i18n sortie de 2.3 → politiques transversales. **[R#20]** 2.10.1 dénuméroté (note de décision). **[R#21]** Dépendances déclarées complétées (2.9→2.5a, 2.10→2.4) — noter que la coupe de « carte N clips dans Aujourd'hui » vers une autre surface (fiche séance) dissout la dépendance si 2.5 réduit. **[R#16]** Tableau de traçabilité C1-C11 → patch porteur dans `docs/Vision_Playco_3.0.md` (C5, C6, C8, C10, C11 invérifiables aujourd'hui).

### Rejetés (avec motif)

- **Bilan budgétaire de l'optim (« net ~+1 sem H1 »)** : incompatible avec l'arithmétique réelle — l'infra est retenue mais le recut de A.3 est la vraie contrepartie.
- **2.4.2 patch snapshots complet** : réduit (cf. 19) — la maintenance de snapshots pendant deux refontes actives coûte plus qu'elle ne protège.
- **Rejets X1-X10 de l'optim confirmés** (Fastlane, Sentry au lancement, CloudKitSyncMonitor, AccessibilitySnapshot, snapshots pré-Mat, inversion 2.4/2.5, runner self-hosted, Git LFS, vidéo avancée avant 2.5, télémétrie hand-rolled).
- **Garder 2.6 en 2026-27 en le compressant** : un Composer split à moitié fait n'est ni un argument démo ni un livrable — sortie franche, retour post-3.0 en concurrence avec Insights.

---

## 2. Skills retenus (5 + 1 mise à jour)

| Skill | Justification (une ligne) |
|---|---|
| **playco-patch** | Le moteur (~30 usages/an) : déroule un patch avec les pièges CLAUDE.md ciblés, et porte désormais la checklist amendée (schéma CloudKit prod avant binaire, budget tests baseline, tampon review, stop à ×1,5 de dépassement). |
| **playco-demo-check** | La gate qui protège l'actif le plus fragile (branche `suivis/pr6`, isolation CloudKit, garde-fou « jamais en review publique ») — à corriger avec le §4 réécrit (amendement 13) et le renvoi CI (18). |
| **playco-mat-review** | Les 10 lois rendues mécaniquement vérifiables à chaque patch UI dès 2.4 — c'est la seule façon qu'une doctrine design survive à 30 patchs solo-dev ; complétée par les tests de contraste (19). |
| **playco-video-securite** | La gate du SEUL domaine serveur, qui touche des vidéos de mineurs : matrice RLS, PII minimale, signed URLs, purge double (SQL + Stream) — amendée pour exiger les tests RLS **dès 2.7** (shift-left, amendement 9). |
| **playco-roadmap-status** | La boussole inter-session sur 15 mois — à condition qu'elle affiche les **sommes réelles du recut** (A.3), pas les en-têtes optimistes, et alerte sur tout deuxième pari >6 sem. |
| *(hors quota)* **playco-release** mis à jour | Aux jalons : produits `entraineur.*`/`elite.*` + quota chiffré (2.10), gate `/playco-video-securite` GO (2.7+), renvoi `/playco-demo-check`. |

Non retenus confirmés : skill i18n séparé (3 vérifs → dans playco-patch), skill supabase-migrate (absorbé), skill onboarding générique (CLAUDE.md le fait).

---

## 3. Décisions à ton réveil (fondateur seul)

1. **Le grand sacrifice — ratifier le recut A.3.** Séances 2.0/Playbook (2.6 Composer + gabarits + facettes) sort de 2026-27 ; H2 = le pari vidéo seul ; 2.9.1 hors chemin pilote ; 2.10/2.11 débordent en mai-juin ; GO/NO-GO en juin 2027. L'alternative honnête est de retarder la vidéo d'un an — mais c'est LE pari validé, et la fenêtre pilote colle à la saison. Il n'existe pas de troisième option où tout rentre.
2. **La convention ×2.** Confirmer que les chiffres actuels sont bruts (ma lecture) → le recut ci-dessus est un PLANCHER de coupes ; ou décréter qu'ils sont post-×2 → alors 2.5 et 2.7.1 doivent être formellement ré-estimés (leurs chiffres ne sont pas crédibles en post-×2).
3. **Les 25 exercices = contenu produit** (installés chez TOUS les utilisateurs via `peuplerSiVide`), donc visibles en démo sans violer « démarre VIDE » du 4 juillet — ratifier cette lecture ou amender ta décision du 4 juillet. Sans arbitrage écrit, quelqu'un les coupera de la démo un jour au nom de cette décision.
4. **Pilote hors paywall.** Vidéo offerte aux 5-10 équipes pilotes dès 2.9.2 (TestFlight, avant la mise en vente Élite) : dis oui/non, et si oui, décide le geste envers les pilotes à la bascule 2.10 (gratuité prolongée ? tarif fondateur ?).
5. **Trois actions humaines cette semaine** (tout le reste en découle) : (a) vérifier accords payants ASC + statut produits « Prêt à soumettre » (reliquat v2.0.1, bloque le lancement) ; (b) action Dashboard CloudKit Security Roles (documentée `docs/Securite_AbonnementPublicDB.md`) ; (c) domaine playco.app derrière Cloudflare + choix CI — recommandation : **Xcode Cloud** (25 h/mois incluses, zéro secret à gérer), et accepter par écrit l'exception « hosting statique » au principe serveur.
