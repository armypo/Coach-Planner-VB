# Critique adversariale — Faisabilité solo-dev
## Le sceptique en chef face aux 5 visions · Playco v3 · juillet 2026

> **Méthode.** Chaque idée est passée au crible de quatre réalités non négociables : (1) un seul cerveau et deux mains, même dopés à Claude Code ; (2) une app EN COURS de lancement App Store qui exige support, correctifs et releases ; (3) un budget infra proche de zéro tant qu'aucun contrat B2B n'est signé ; (4) des fédérations qui signent en 12-24 mois quand elles signent. Règle d'étalonnage : **toute estimation d'effort venant d'un designer enthousiaste se multiplie par 2, et par 3 si elle touche du réseau, du multi-appareils ou du juridique.** L'historique du projet le confirme : la « simple » refonte stats v2.2 = ~35 commits et 67 nouveaux tests ; l'audit SIWA = un chantier complet à lui seul.

**Budget réel de l'année** : 52 semaines − vacances − support/bugs post-lancement − App Review − ventes terrain (le fondateur est aussi le vendeur) − comptabilité Origotech ≈ **25 à 30 semaines de développement de nouveautés**. C'est l'enveloppe. Tout ce qui suit se juge contre elle.

---

## 1. Vision [ux-navigation] — la meilleure, mais elle cache un big-bang

### (a) À tuer ou reporter

1. **L'App Clip — TUER.** Cible de build séparée, plafond de taille, associated domains, review Apple spécifique, matrice de tests doublée… pour économiser *une installation d'app* à un athlète qui va l'installer de toute façon (c'est tout l'intérêt). Le lien universel + QR couvre 95 % du bénéfice pour 20 % du coût. L'App Clip est le genre d'item qui mange 3 semaines et ne change aucun chiffre d'adoption.
2. **L'import de roster par photo/OCR (Vision) — REPORTER.** Écritures manuscrites de coachs, feuilles d'alignement hétérogènes, accents français mal reconnus : c'est un puits d'edge cases pour un gain marginal versus « coller une liste » (2 jours de dev, fiable à 100 %). Livrer le collage de texte/CSV, oublier l'OCR.
3. **La refonte d'IA en un seul geste — PHASER, sinon elle tue l'année.** La vision présente le passage 5 sections → 5 moments comme une décision ; c'est en réalité la migration de ~40 écrans, de toute la navigation, des deep links, du filtrage par rôle et des habitudes des premiers utilisateurs payants. Réalité solo : 2-3 mois à ne livrer AUCUNE valeur nouvelle, avec régressions garanties sur une app qui vient d'atteindre 253/253 tests. Nuance importante : le meilleur moment pour cette refonte est *maintenant* (base utilisateurs minuscule, coût de réapprentissage quasi nul) — mais en 2-3 releases incrémentales, jamais en big-bang.

### (b) Sous-estimé — mérite plus

- **« Match éclair » + promotion automatique `MatchCalendrier` → `Seance` le jour J.** C'est enterré dans le §5 alors que c'est LE correctif du flow qui définit la valeur perçue (15 interactions → 4). Effort minuscule (les deux modèles existent), impact maximal. À faire avant toute refonte d'IA.
- **La composition persistante** (le 6 de départ comme état d'équipe, pré-rempli du dernier match) — quelques jours, tue 7 taps à chaque match.
- **Exposer `RechercheGlobaleView`** — la feature existe, elle est juste invisible. C'est du ROI gratuit, une demi-journée.
- **La carte héro « Aujourd'hui »** peut vivre DANS l'AccueilView actuelle sans refonte : le calendrier unifié sait déjà quel jour on est. 2 semaines, 80 % du bénéfice de l'onglet « Aujourd'hui » complet.
- **Le push « ton box score est prêt »** : faisable SANS serveur via CKSubscription/CKQuerySubscription sur la Public DB existante — la vision ne le dit pas, et c'est ce qui la rend réaliste.

---

## 2. Vision [federation-b2b] — la plus dangereuse pour un solo dev

C'est un excellent document de stratégie… pour une entreprise de 15 personnes. Prise au pied de la lettre, elle transforme un développeur iOS en éditeur de logiciel de gestion + DPO + équipe support, à temps plein, sans revenus avant 2028.

### (a) À tuer ou reporter

1. **Le registre central des membres (affiliations, mutations, surclassements, double affiliation, import Spordle) — TUER en v3, sans appel.** Trois raisons brutales : (i) c'est un produit entier — 12-18 mois de dev à lui seul, avec des workflows d'approbation, de la paie de conformité et un support opérationnel quotidien ; (ii) le cycle de vente fédération est de 12-24 mois via un CA bénévole — on construirait donc 18 mois pour vendre dans 24 ; (iii) **la vision marché du même exercice démontre que ce créneau est en cours de verrouillage par Spordle chez Volleyball Québec même**. Construire le registre, c'est attaquer frontalement le seul acteur québécois verrouillé, sur son terrain, avec zéro vendeur. La vision B2B dit « on les remplace, on ne s'y branche pas » — c'est exactement l'inverse qu'il faut faire.
2. **La feuille de match électronique officielle co-signée — REPORTER (36 mois+).** Elle exige : les deux équipes clientes (effet réseau à froid = zéro), un statut réglementaire accordé par la fédé (donc le contrat fédé signé AVANT la feature), un format officiel paramétrable, une immuabilité juridique. C'est la killer demo… d'une réunion de CA à laquelle Playco ne sera pas invité avant 2 ans.
3. **« Loi 25 clé en main » + messagerie règle-de-deux + module blessures + arbitres — TUER l'emballage, garder l'hygiène.** Un solo dev qui vend contractuellement de l'EFVP, un registre d'incidents, un journal d'accès aux dossiers de mineurs et du safe sport signe des obligations de conformité qu'il ne peut pas honorer (pas de DPO, pas d'astreinte, pas d'auditeur). Faire l'hygiène Loi 25 pour soi-même (résidence canadienne le jour où il y a un serveur, export de données, minimisation) : oui. En faire une ligne de contrat : non, pas seul.

### (b) Sous-estimé

- **L'export .ics/calendrier partageable** — mentionné en passant (« feature d'adoption massive et triviale ») : c'est vrai, et ça devrait être en tête de liste. Attention au détail technique : l'*abonnement* webcal exige une URL servie (donc un serveur) ; l'export de fichier .ics par ShareLink est lui 100 % gratuit et immédiat.
- **La « frontière de confiance pédagogique »** (les plans de match ne remontent jamais au club) — principe produit gratuit, différenciant, à graver dans la vision finale même si tout le reste attend.
- **La séquence GTM inversée** (club phare d'abord, fédé en dernier) est la partie la plus lucide du document — elle contredit d'ailleurs son propre sommaire de features, qui est trié par « pouvoir de signature fédé ».

---

## 3. Vision [innovation-technique] — la plus honnête, deux chiffrages fantaisistes quand même

Ce document fait déjà le travail du sceptique sur vision/pose/watch. Restent deux angles morts.

### (a) À tuer ou reporter

1. **La saisie duo pair-à-pair offline (Network.framework/Bonjour) : « 4-5 semaines » est une fiction — REPORTER.** Le P2P local, c'est : appairage, reprise après déconnexion AWDL (qui coupe quand l'écran se verrouille…), réconciliation d'undo croisés, débogage uniquement sur matériel physique en conditions réelles, et des bugs irreproductibles pendant des mois. Compter 2-3 mois + une traîne de support. L'insight « journal append-only, pas de CRDT » est juste et précieux — mais il sert d'abord la sync backend future, pas un protocole radio à maintenir seul. Version dégradée honnête si le besoin hurle : l'assistant saisit sur SON appareil et CloudKit fusionne quand il y a du réseau (l'append-only rend ça sûr) — zéro protocole custom.
2. **Live Activities broadcast (parents) + micro-worker — REPORTER strictement au premier contrat payant.** « Ce n'est qu'un micro-endpoint » : c'est surtout le PREMIER serveur — donc monitoring, astreinte implicite (un tournoi le samedi = pannes le samedi), gestion de certificats APNs, et une promesse publique de disponibilité. La vision énonce elle-même la règle (« pas un dollar de serveur avant contrat ») puis la contourne en H2 « si la traction le justifie ». Non : contrat signé, ou rien.
3. **La vidéo synchronisée : garder l'idée, doubler le devis.** « 4-6 semaines » ignore : la thermique et la batterie d'un enregistrement continu de 90 min sur iPad, les iPad 64 Go des cégeps déjà pleins (4-6 Go/match = crise au 8e match), l'UX de purge qui doit être infaillible sinon c'est un bug « l'app a mangé mon stockage » en review App Store, le recalage, l'écran verrouillé qui coupe la capture, le trépied volé par le prof d'éduc. C'est un produit dans le produit : **8-12 semaines réalistes**, soit LE pari unique de l'année — pas un item parmi douze.

### (b) Sous-estimé

- **L'animation des systèmes de jeu (5.1)** — même mon scepticisme n'y trouve rien : données déjà en base (`EtapeExercice`, positions 0-1, Bézier), zéro serveur, zéro permission, différenciateur démo/TikTok immédiat. Meilleur ratio des cinq visions. Seul bémol : prévoir les cas dégénérés (éléments ajoutés/supprimés entre étapes) — c'est ça qui fera passer 2-3 semaines à 4.
- **State Restoration du match live** — 2-3 jours, et c'est la différence entre un coach qui fait confiance et un coach qui désinstalle. Aurait dû être le titre du document.
- **Un caveat que la vision minimise** : FoundationModels exige Apple Intelligence (M1+/A17 Pro+, réglage activé). Le parc réel des coachs de cégep québécois = iPads de 3-6 ans. Le résumé narratif sera indisponible pour une grosse fraction des utilisateurs → c'est un « délice » pour équipés récents, pas un pilier marketing. Le fallback prévu est la bonne décision ; la conséquence (ne pas le vendre comme feature phare) manque.

---

## 4. Vision [multisport-backend] — architecture juste, calendrier délirant

Le diagnostic (« rien n'exige un from scratch », event log déjà en place, string-keyed partout) est correct et rassurant. Le problème est le rythme.

### (a) À tuer ou reporter

1. **Le mini-évaluateur d'expressions arithmétiques pour les métriques — TUER (YAGNI incarné).** « ~150 lignes testables » pour interpréter `"(kills - erreursAttaque) / tentativesAttaque"`… alors qu'il n'existe QU'UN sport livré et que `MetriquesVolley` compile, est typé, et est couvert par 253 tests. C'est l'inner-platform effect que le document lui-même liste en risque n° 1, puis commet au §2.2. Les formules restent en Swift jusqu'au 2e sport *payant*. Le descripteur v1 se limite aux **catalogues** (actions→compteurs, postes, terrains/zones, format de manches) — la partie table, pas la partie langage.
2. **Phases 1-2 complètes (PlaycoCore + volleyball.json intégral + extraction beach) « 2-4 semaines » — REPORTER et découper.** Remplacer les switchs de 30 fichiers par un catalogue, sur l'app qui vient de se stabiliser, c'est 2-3 mois de refactor à risque de régression pour un bénéfice utilisateur de ZÉRO en 2026 (aucun 2e sport ne sera vendu cette année, la vision marché l'interdit même explicitement). En v3 : **phase 0 seulement** (champs additifs `Equipe.sportID`, `PointMatch.contexteData`, `StatsMatch.compteursData` — 2-3 jours) + la règle de lint « jamais de `if sport == volleyball` dans du code neuf ». L'extraction du beach en descripteur : opportuniste, seulement si un chantier touche déjà ces fichiers.
3. **Supabase + RLS + dashboard « lecture seule » comme premier pas web — DÉGRADER encore d'un cran.** Même « lecture seule », c'est : auth OIDC, policies RLS à auditer (une erreur = fuite de données de mineurs), CI de déploiement, backups testés, monitoring. Le premier livrable web qui a du sens pour un solo est plus petit : **le rapport de match partageable par lien** (page statique générée, zéro compte, zéro base) — exactement le WebReports de SoloStats que la vision marché ordonne de copier. Les deux visions convergent sans le savoir ; le sceptique tranche : page statique d'abord, Postgres au contrat.

### (b) Sous-estimé

- **La phase 0 elle-même** : 2-3 jours d'assurance quasi gratuite contre le verrou CloudKit. À faire dans la prochaine release, point.
- **La liste des irréversibles** (Apple Team ID, additivité CloudKit, 1 équipe = 1 sport, event log source de vérité) — c'est la page la plus précieuse des cinq visions ; elle coûte zéro et évite des erreurs à coût infini.
- **La discipline « zéro serveur spéculatif »** — c'est la seule règle budgétaire qui protège un solo dev ; elle devrait être promue en principe transversal de la vision finale, opposable aux quatre autres documents.

---

## 5. Vision [marche-concurrence] — la plus utile, trois excès d'optimisme

### (a) À tuer ou reporter

1. **« Signer 15-20 ambassadeurs en 0-6 mois » — DIVISER PAR TROIS.** Chaque coach ambassadeur = démo en gymnase + suivi hebdo + correctifs à la demande. Le fondateur qui fait ça ne code pas. 5-8 ambassadeurs servis obsessionnellement > 20 négligés qui churnent en janvier. (Et c'est cohérent avec la leçon du club phare « servi de façon obsessionnelle » de la vision B2B.)
2. **L'export DataVolley (.dvw) — ANNONCER, ne pas construire.** Format propriétaire non documenté officiellement : reverse-engineering + validation par des analystes qui n'existent pas dans le réseau actuel = des semaines pour séduire un segment (universitaire/pro) qui n'est PAS la cible des 24 premiers mois. Un CSV structuré documenté suffit à l'argument anti-lock-in.
3. **Basketball en « 2e vague » — ne même pas l'amorcer en 12 mois.** La vision le dit elle-même (« aucun 2e sport avant que le volleyball ait gagné son marché ») mais le tableau du §5 crée une tentation permanente. Le SportDescriptor phase 0 suffit comme préparation.

### (b) Sous-estimé

- **Le paiement par saison (à la iStatVball)** — un produit StoreKit non renouvelable, ~1 semaine avec la plomberie d'`Abonnement` existante, et ça désamorce l'objection n° 1 du coach scolaire (« payer 12 mois pour 4 »). Devrait être dans le trio de tête de la roadmap monétisation.
- **« Le concurrent n° 1 est le papier gratuit »** — c'est la phrase qui devrait gouverner l'onboarding (< 10 min), le tier gratuit (logistique jamais paywallée, comme Spond) et le ton marketing. Les quatre autres visions l'oublient toutes.
- **Le positionnement « complémentaire de Spordle »** — c'est LA décision stratégique de l'exercice, et elle invalide à elle seule la moitié de la vision federation-b2b. Elle mérite d'être promue de « parade » à « pilier ».

---

## 6. Contradictions entre visions — le sceptique tranche

| # | Conflit | Positions | Verdict |
|---|---|---|---|
| 1 | **Registre fédéral** | federation-b2b : « on remplace Spordle, on ne s'y branche pas » ↔ marche-concurrence : « créneau verrouillé, être complémentaire, vendre la couche performance » | **marche-concurrence gagne, sans débat.** Le registre, les mutations, les surclassements et la e-feuille officielle sortent de la v3. Playco vend ce que Spordle n'aura jamais : la donnée terrain. |
| 2 | **Premier serveur** | innovation-technique : worker edge en H2 « si traction » ↔ multisport-backend : « zéro serveur avant contrat signé » ↔ federation-b2b : monolithe Postgres complet | **multisport-backend gagne, durci** : zéro serveur avant un contrat *signé et payé*. Et le premier livrable web n'est même pas une base : c'est le rapport de match statique par lien. |
| 3 | **Stack backend** | federation-b2b : monolithe SSR + Postgres ↔ multisport-backend : Supabase + PostgREST ↔ innovation-technique : Cloudflare Workers + KV | Suivre les trois = opérer trois infrastructures. **Une seule stack le jour venu (Supabase, réversible car Postgres standard)** ; le worker score-live s'y greffera s'il existe un jour. |
| 4 | **Offline vs temps réel** | Tous jurent « offline-first », puis deux visions ajoutent du temps réel (broadcast parents, multi-iPad staff, classements à la minute) | Pas de contradiction de principe — la couche de saisie reste offline — mais une contradiction de *budget* : chaque canal temps réel est un système distribué à déboguer seul. **En v3 : zéro temps réel. La Live Activity LOCALE (sans push) est la seule exception admise.** |
| 5 | **Vidéo** | innovation-technique : la feature n° 1 de l'app ↔ marche-concurrence : « ne pas courir après l'IA vidéo », copier seulement le clip manuel | Compatibles sur le fond (la sync par horodatage n'est pas de l'IA), incompatibles en périmètre. **Verdict : c'est un pari légitime, mais c'est LE gros pari de l'année ou rien — 8-12 semaines réelles, en exclusivité mutuelle avec le dashboard club.** |
| 6 | **Refonte IA vs lancement en cours** | ux-navigation : tout réorganiser ↔ l'état réel : app soumise, utilisateurs TestFlight actifs | **Phaser.** Le contenu de la refonte est juste ; le big-bang est le risque. Release 1 : carte héro + match éclair + recherche exposée (dans l'IA actuelle). Release 2 : TabView adaptative + fusion Playbook. Release 3 : hub Analyser. |
| 7 | **Onboarding** | ux-navigation : wizard 3 écrans bottom-up ↔ federation-b2b : provisioning descendant club→coach | **Ordre, pas conflit** : le wizard court sert 100 % des coachs dès maintenant ; le provisioning descendant sert des clients qui n'existent pas encore. Wizard d'abord, provisioning au premier contrat club. |
| 8 | **Pricing** | federation-b2b : 99 $/an l'équipe, dégressif club ↔ marche-concurrence : 150-500 $ CAD/équipe/an, vente par programme, option saison | **marche-concurrence gagne** : le gouffre SoloStats↔Hudl permet de tester plus haut que 99 $, l'option « par saison » désamorce l'objection scolaire, et la facture « par programme » parle au vrai payeur (le responsable des sports). |
| 9 | **IA on-device** | innovation-technique : pilier de H1 ↔ réalité du parc matériel des cégeps (Apple Intelligence exige M1+/A17 Pro+) | Livrer le résumé narratif, oui (petit effort), mais **comme bonus silencieux avec fallback, jamais comme promesse App Store** — une feature phare indisponible sur la moitié du parc est une promesse cassée. |

---

## 7. La liste « à ne surtout PAS faire en v3 »

1. **Registre central des membres** (affiliations, mutations, surclassements, catégories d'âge automatiques) — produit entier, marché verrouillé par Spordle, cycle de vente incompatible.
2. **Feuille de match électronique officielle co-signée** — exige l'effet réseau et le contrat fédé qui n'existent pas.
3. **Tout serveur avant un contrat B2B signé** — ni worker « à 20 $/mois », ni Supabase « lecture seule », ni broadcast Live Activities. Le premier dollar d'infra suit le premier dollar de contrat.
4. **P2P multi-appareils (Bonjour/AWDL)** — 2-3 mois réels + traîne de bugs irreproductibles ; version CloudKit-quand-réseau si besoin criant.
5. **Moteur d'expressions / volleyball.json intégral / extraction beach forcée / 2e sport** — refactor à bénéfice utilisateur nul en 2026 ; seule la phase 0 additive passe.
6. **App Clip, watchOS, visionOS, analyse de pose, auto-tracking, assistant conversationnel, Siri vocal** — les visions elles-mêmes en écartent la plupart ; je confirme et j'y ajoute l'App Clip.
7. **Refonte d'IA en big-bang mono-release** — 2-3 mois sans valeur livrée, régressions sur une base saine de 253 tests.
8. **Modules conformité vendus contractuellement** (EFVP clé en main, messagerie règle-de-deux, blessures, arbitres) — obligations qu'un solo ne peut pas honorer.
9. **Export .dvw, Android, réseau social, IA vidéo maison, prix par athlète, tier gratuit à pubs** — consensus des visions, confirmé.
10. **Plus d'un « gros pari » (> 6 semaines) en parallèle** — la règle méta qui protège toutes les autres.

---

## 8. Périmètre maximal réaliste — 12 mois de solo dev assisté par IA

**Hypothèse honnête : 25-30 semaines effectives de dev nouveau.** Claude Code double la vitesse d'écriture du code ; il ne double ni la QA en gymnase, ni App Review, ni les décisions de design, ni les démos de vente.

### T1 (mois 0-3) — Consolider le lancement, tuer la friction
*~7 semaines de dev*
- **State Restoration du match live** (0,5 sem) — non négociable.
- **Match éclair + promotion `MatchCalendrier`→`Seance` + composition persistante pré-remplie** (3 sem) — le flow critique passe de ~15 interactions à ~4.
- **Carte héro contextuelle dans l'accueil actuel** + exposition de la recherche globale (2 sem).
- **Phase 0 SportDescriptor** : champs additifs CloudKit-safe + convention écrite des irréversibles (0,5 sem).
- **Liens universels + QR d'invitation** (jonction d'équipe sans taper de code — sans App Clip) (1,5 sem).

### T2 (mois 3-6) — La refonte d'IA, par étapes
*~9 semaines de dev*
- **TabView adaptative native + moments Aujourd'hui/Préparer/Coacher/Analyser/Équipe**, livrée en 2 releases (6 sem) — fusion Playbook incluse, hub Analyser en release 2.
- **Wizard coach 3 écrans + onboarding progressif** (2 sem).
- **Paiement par saison** (StoreKit non renouvelable) + export .ics partageable (1 sem).

### T3 (mois 6-9) — UN pari, pas deux (décision de gouvernance, pas de technique)
*~8 semaines de dev*
- **Option A (défaut, produit)** : **vidéo synchronisée v1** — capture mono-appareil, playlists par stat, export de clips, purge assistée. Devis honnête : elle déborde sur T4.
- **Option B (si un club de 10+ équipes met une lettre d'intention sur la table)** : rapports de match web par lien statique, puis dashboard club lecture seule minimal.
- En marge (petits items) : **animation des systèmes de jeu** (3-4 sem — si elle n'a pas déjà été glissée en T2, elle est prioritaire sur le début du pari), **Live Activity locale** (1 sem).

### T4 (mois 9-12) — Finir le pari, polir, préparer 2027
*~6 semaines de dev*
- Terminer le pari de T3 (la vidéo déborde toujours).
- **Résumé narratif FoundationModels** avec fallback silencieux (2 sem).
- **App Intents + widget « Prochain événement » + Spotlight** (2 sem).
- Spikes d'une semaine max chacun : scouting agrégé multi-matchs, scan de feuille papier.

### Règles de gouvernance de l'année
1. **Un seul pari > 6 semaines par année.** Vidéo OU dashboard club — jamais les deux.
2. **Tout item estimé > 4 semaines passe d'abord un spike d'une semaine** avec critère d'abandon écrit.
3. **Toute estimation issue des visions × 2** (× 3 si réseau/multi-appareils/juridique).
4. **Zéro dollar d'infra avant un contrat signé ; zéro feature terrain dépendante du réseau — jamais.**
5. **Le vendredi appartient aux ambassadeurs** (5-8, pas 20) : c'est la donnée produit qui arbitrera T3, et c'est le seul « backend » que Playco peut se payer cette année — des humains qui répondent.

**En une phrase** : la v3 réaliste, c'est la vision UX phasée + les quick wins de vitesse + un seul gros pari (vidéo ou club, pas les deux), sur des fondations phase-0 multi-sport gravées en trois jours — et tout le lexique fédération reste dans le document de vision, pas dans Xcode.
