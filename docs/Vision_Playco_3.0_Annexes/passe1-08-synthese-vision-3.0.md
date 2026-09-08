# Vision Playco 3.0 — Document de synthèse arbitré
### Fusion des 5 lentilles (UX, Fédération/B2B, Innovation, Architecture, Marché) sous l'autorité des deux critiques (faisabilité solo-dev, complétude) · Juillet 2026

> **Règle de lecture.** Ce document tranche. Chaque contradiction entre les visions sources a été résolue ; chaque item tué par la critique de faisabilité est tué (ou explicitement défendu) ; chaque angle mort de la critique de complétude est intégré avec une décision. Le budget de référence est celui du sceptique : **25-30 semaines effectives de développement par année**, un seul cerveau, Claude Code comme accélérateur — pas comme deuxième employé.

---

## 1. Thèse produit

**Playco 3.0 est le poste de pilotage complet du coach de volleyball — préparation, match live, statistiques de calibre pro, développement des athlètes — conçu pour iPad, qui fonctionne sans wifi dans n'importe quel gymnase, en français d'abord.** Il gagne parce qu'il occupe le seul quadrant vide du marché : la profondeur volleyball de VBStats/DataVolley croisée avec la largeur organisationnelle que ni Hudl (2 000 $/équipe/an), ni Spordle (registre sans performance), ni TeamSnap (logistique sans sport) n'offrent — le tout offline-first, une douve architecturale que les concurrents cloud ne peuvent pas copier sans se réécrire. Sa trajectoire est bottom-up et séquencée : le coach d'abord, l'athlète comme boucle virale, le club comme unité économique, la fédération comme **canal de distribution de la couche développement de l'athlète** — jamais comme client d'un registre qu'on ne construira pas (Spordle a verrouillé ce créneau ; on s'y branche, on ne l'attaque pas).

---

## 2. Personas & tiers

### Les personas

| Persona | Appareil | Ce qu'il vit dans Playco 3.0 |
|---|---|---|
| **Coach-chef** (`admin`) | iPad (+ iPhone) | Le produit entier. Prépare à la maison, coache au gymnase, analyse après. Propriétaire de l'équipe — avec mécanisme de **transfert de propriété** (nouveau, cf. §9). |
| **Athlète** (`etudiant`) | iPhone (parfois Android → page web lecture, cf. §9) | App réduite à 3 questions : quand je joue, comment j'ai joué, qu'a dit le coach. Jamais bloqué par le paywall. Son **profil carrière** le suit d'équipe en équipe (nouveau). |
| **Assistant / staff** (`coach`) | iPhone/iPad | Même app que le coach ; `StaffPermissions` masque des **onglets entiers**, pas seulement des boutons. Le préparateur physique vit dans Coacher (muscu live) + Équipe (suivi charges). |
| **Parent/tuteur** | iPhone/web, souvent sans app | Au tier Équipe : consentement pour son mineur, calendrier .ics par lien, box score par lien web. Compte parent complet = tier Club (avec profils gérés pour les <13 ans). |
| **Admin club / DG** | Web (desktop) | Dashboard web : résultats du week-end, rosters consolidés, calendrier maître, conformité de base. Ne voit **jamais** le contenu pédagogique des coachs. |
| **Fédération / direction technique** | Web | Couche développement : standards provinciaux, rapports DLTA, exports. Horizon 18-30 mois, après preuve club. |

### Les trois tiers et le pricing (arbitrage : la lentille marché gagne sur la lentille B2B)

| Tier | Unité | Prix (CAD, indicatif) | Canal | Contenu |
|---|---|---|---|---|
| **Équipe** | par équipe | **179 $/an, 19 $/mois, ou option « Saison » ~119 $** (achat non renouvelable 6 mois — désamorce l'objection n°1 du coach scolaire : « payer 12 mois pour 4 ») | App Store (StoreKit 2 existant) | Tout le produit coach. Logistique (calendrier, présences, messagerie) **gratuite pour toujours** — c'est l'hameçon anti-papier, jamais paywallée. Athlètes gratuits. |
| **Club** | par programme, dégressif | 119 $/équipe/an dès 5 équipes, 99 $ au-delà de 15 ; **facture PDF au responsable des sports** (le vrai payeur), Stripe hors App Store (conforme, B2B multi-plateforme) | Web + facture | Tout Équipe pour chaque coach + dashboard club lecture, calendrier maître, bibliothèque de club (copie, pas lien — la frontière pédagogique reste intacte), rôle parent complet, profils gérés <13 ans. |
| **Fédération** | par membre affilié | 2-3 $/membre/an, plancher ~10 000 $ | Contrat annuel | **PAS de registre** (Spordle). La couche que personne d'autre n'a : profil de développement de l'athlète multi-saisons, standards provinciaux et rapports DLTA, exports/interop vers Spordle/Sportlomo, app Équipe incluse pour les clubs affiliés (avantage d'affiliation = flywheel). |

**Trois choix assumés** : facturation par équipe/programme, jamais par athlète ; le premier prix testé est **au-dessus** de 99 $ (le gouffre SoloStats↔Hudl le permet ; le concurrent réel est le papier gratuit, qu'on bat par l'onboarding, pas par le prix) ; le tier Fédération est un canal de distribution avant d'être une ligne de revenus.

---

## 3. Architecture d'information cible

**Décision mère (vision UX, confirmée) : réorganiser l'app par moment d'usage, pas par type de contenu.** Un coach ne pense pas « je consulte le type Stratégies » ; il pense *je prépare mardi, je coache ce soir, j'analyse hier*. **Décision d'exécution (critique de faisabilité, autoritaire) : livraison en 3 releases incrémentales, jamais en big-bang** — le meilleur moment est maintenant (base utilisateurs minuscule), mais par étapes, en préservant la base de 253 tests.

### Structure : TabView `.sidebarAdaptable` native (tab bar verre iPhone/portrait, sidebar iPad paysage), remplaçant le hub 5 cartes + DockBar custom

```
PLAYCO (coach)
│
├── AUJOURD'HUI — le hub contextuel (remplace AccueilView)
│   ├── En-tête : équipe active (switch 1 tap), avatar → Profil & réglages
│   ├── CARTE HÉRO : l'app sait quel jour on est
│   │   ├── Jour de match  → « Sherbrooke 19h · Plan de match · [COACHER CE MATCH] »
│   │   ├── Jour de pratique → « Pratique 18h · 6 exercices · [DÉMARRER] »
│   │   └── Rien → prochain événement + « Préparer la semaine »
│   ├── Actions rapides (4 max) : Nouvelle séance · Match éclair · Présences · Recherche
│   ├── Carte « Dernier match » → box score en 1 tap
│   ├── Carte « À faire » : onboarding progressif, scouting incomplet, invitations en attente
│   └── Messages non lus inline
│
├── PRÉPARER — à la maison
│   ├── Calendrier (écran racine — la colonne vertébrale) : tap créneau vide → séance pré-remplie ;
│   │   tap match futur → fiche Adversaire ; sync EventKit ; export .ics partageable
│   ├── Séances : éditeur split (Playbook à gauche, timeline à droite, 1 drag/exercice) ;
│   │   appui long → « Dupliquer vers… » (resservir mardi dernier en 2 taps)
│   ├── PLAYBOOK ← fusion Bibliothèque exercices + Stratégies + Formations
│   │   (onglets internes Exercices · Systèmes · Formations ; tout est insérable et présentable)
│   ├── ADVERSAIRES ← objet de première classe (scouting, historique H2H, PDF plan de match)
│   └── Programmes physiques
│
├── COACHER — le gymnase (dark par défaut, cibles larges, rouge = seul accent « live »)
│   ├── Les événements du jour en très gros
│   ├── [COACHER LE MATCH] → pré-match 1 écran : 6 de départ PRÉ-REMPLI du dernier match
│   │   (composition = état persistant de l'équipe), qui sert → GO → MatchLiveSplitView
│   ├── [MATCH ÉCLAIR] : match hors calendrier en 2 champs (adversaire + qui sert)
│   ├── [DÉMARRER LA PRATIQUE] / [SÉANCE MUSCU LIVE]
│   └── Courtside = mode d'affichage systémique proposé à l'entrée du live (plus un réglage caché)
│
├── ANALYSER — après (absorbe le hub Statistiques d'EquipeView)
│   ├── Racine « Saison » : V-D, sideout %, hitting, séries, phases
│   ├── Analyse match : box score · fil du match · rotations · heatmap (pré-filtrés depuis tout contexte)
│   ├── Rotations · Heatmap · Joueurs (évolution, comparaison par poste, palmarès)
│   └── Exports PDF/CSV + rapports partagés
│
└── ÉQUIPE — les personnes
    ├── Roster → fiche joueur segmentée (Profil · Stats · Objectifs · Physique · Invitation/QR)
    │   + statut de disponibilité (blessé/malade — grisé partout, cf. §9)
    ├── Staff & permissions · Tests physiques & suivi charges (le préparateur vit ici)
    ├── Messagerie (sort du DockBar)
    └── Réglages équipe : QR/codes, couleurs, saison & phases, abonnement, transfert de propriété
```

**Règles de circulation** : tout objet est navigable depuis partout (nom de joueur dans un box score → fiche ; adversaire au calendrier → scouting) ; jamais plus de 2 niveaux entre un objet et son analyse ; les 5 moments sont universels aux sports d'équipe — le SportDescriptor définit le vocabulaire, jamais la structure.

**Flow critique chiffré** : coacher le match du soir passe de ~15 interactions + clavier à **2 taps** (carte héro → GO, composition pré-remplie) ; match imprévu = **4 interactions** (Match éclair).

**Athlète (iPhone, 3 onglets)** : *Aujourd'hui* (prochain événement, dernière perfo vs sa moyenne, objectifs, messages) · *Mes stats* (saison, évolution, records, muscu à faire) · *Équipe* (calendrier, roster lecture, messagerie). Push « ton box score est prêt » via **CKSubscription sur la Public DB existante — zéro serveur** (l'astuce qui rend la promesse réaliste).

**Langage visuel (Liquid Glass v3)** : le verre = le chrome (tab bar, toolbars, panneaux flottants), **jamais le contenu** (tableaux de stats opaques hiérarchisés) ; une seule couleur d'accent = **l'identité de l'équipe** (`Equipe.couleurs`, déjà en base) — les 5 couleurs de section disparaissent avec les silos ; exceptions sémantiques : rouge = live, bleu/rouge = nous/adversaire **toujours doublés d'une forme ou d'un motif** (daltonisme, cf. §9) ; chiffres tabulaires obligatoires, convention « .350 » en composant unique ; Coacher dark par défaut, courtside opaque WCAG AAA.

---

## 4. Login & onboarding cible

**SIWA reste l'unique auth** (acquis v2.1). Ce qui change :

1. **Jonction d'équipe sans taper de code** : QR par joueur (fiche + écran « Inviter l'équipe » projetable/imprimable) encodant un **lien universel** `playco.app/join/{codeEquipe}/{codeInvitation}` → tap → « Rejoindre les Élans en tant que Laurie Tremblay » → SIWA → 1 geste. Code alphanumérique conservé en fallback (gymnase sans réseau). **App Clip : TUÉ** (critique de faisabilité — 3 semaines pour économiser une installation que l'athlète fera de toute façon ; le lien universel couvre 95 % du bénéfice).
2. **Premier lancement coach : 3 écrans, time-to-value < 2 minutes.** (1) SIWA (identité pré-remplie) ; (2) « Ton équipe » : nom + sport + niveau ; (3) « Ta prochaine activité » : [Pratique] [Match] [Explorer]. Établissement, couleurs, créneaux, roster complet → cartes « À faire » dans Aujourd'hui (onboarding progressif avec jauge). Roster importé par **collage de liste / CSV** (2 jours, fiable). **OCR photo de feuille : REPORTÉ** (puits d'edge cases pour gain marginal).
3. **Consentement mineurs intégré au flux** (cf. §9) : à la création d'un profil <18 ans, attestation coach horodatée « j'ai le consentement parental » + lien d'avis parent ; DM privés adulte↔mineur désactivés par défaut.
4. **Onboarding descendant club** (provisioning : le club crée les équipes, le coach confirme en 1 écran) : conçu, mais construit **au premier contrat club signé** — pas avant (arbitrage n°7 du sceptique : ordre, pas conflit).

---

## 5. Features par tier

| Domaine | **Équipe** (App Store) | **Club** (+facture programme) | **Fédération** (+contrat) |
|---|---|---|---|
| Logistique (calendrier, présences, messagerie, .ics) | ✅ Gratuit pour toujours | ✅ + calendrier maître multi-équipes, gestion plateaux | ✅ |
| Préparation (Playbook, séances, adversaires/scouting, muscu) | ✅ | ✅ + bibliothèque de club (curriculum copié, jamais lié) | ✅ |
| Match live (stats point-par-point, courtside, rotation, Match éclair) | ✅ | ✅ | ✅ |
| Analyse (sideout/rotation, heatmap, fil du match, palmarès, exports PDF/CSV) | ✅ | ✅ + comparaisons internes club | ✅ + standards provinciaux anonymisés |
| Animation des systèmes de jeu + présentation TV | ✅ | ✅ | ✅ |
| Vidéo synchronisée aux stats (si pari retenu, cf. §6) | ✅ (tier payant) | ✅ | ✅ |
| Résumé narratif de match (FoundationModels, fallback silencieux) | ✅ bonus | ✅ + rapports parents/direction | ✅ |
| Rapport de match web par lien (page statique, zéro login) | ✅ | ✅ | ✅ |
| Profil carrière athlète (multi-équipes/saisons) + CV de recrutement PDF | ✅ | ✅ + profil web partageable | ✅ « profil vérifié » |
| Dashboard web admin | — | ✅ lecture (résultats, rosters, présences, conformité de base) | ✅ + rapports DLTA, exports fédé |
| Comptes parents + profils gérés <13 ans (mini-volley) | avis/consentement seulement | ✅ complet | ✅ |
| Rollover de saison, archives, comparaison saison-sur-saison | ✅ | ✅ + archivage club | ✅ |
| Admissibilité académique (RSEQ) / statut disponibilité joueur | ✅ | ✅ | ✅ + discipline de ligue (plus tard) |
| Interop : exports CSV documentés, iCal, vers Spordle/Sportlomo | ✅ | ✅ | ✅ (condition de vente) |
| **Exclus par décision** : registre d'affiliations/mutations/surclassements, e-feuille officielle co-signée, paiements/inscriptions, module arbitres | — | — | ❌ (Spordle ; réévalué à 36 mois si un contrat fédé le finance) |

---

## 6. Innovations retenues

### Au lancement de la 3.0 (H1)
| Innovation | Pourquoi | Effort réaliste |
|---|---|---|
| **State Restoration du match live** | La différence entre confiance et désinstallation ; les données sont sauves, la navigation ne l'est pas | 0,5 sem |
| **Match éclair + promotion auto `MatchCalendrier`→`Seance` + composition persistante** | LE correctif du flow qui définit la valeur perçue (15 → 2-4 interactions) | 3 sem |
| **Carte héro contextuelle** (dans l'accueil actuel, avant la refonte) + **recherche globale exposée** | 80 % du bénéfice d'« Aujourd'hui » sans refonte ; la recherche existe déjà, elle est juste invisible | 2 sem |
| **QR + liens universels de jonction** | Time-to-team < 60 s sans code tapé | 1,5 sem |
| **Phase 0 SportDescriptor** (champs additifs `Equipe.sportID`, `PointMatch.contexteData`, `StatsMatch.compteursData` + convention des irréversibles) | Assurance quasi gratuite contre le verrou CloudKit | 0,5 sem |
| **Consentement mineurs minimal + statut blessé/disponibilité** | Passif juridique actif / quick win terrain | 1 sem |

### À 6 mois (H2)
- **Refonte d'IA en TabView adaptative** (2 releases : moments + fusion Playbook, puis hub Analyser) — 6 sem.
- **Wizard 3 écrans + onboarding progressif** — 2 sem.
- **Paiement par saison** (StoreKit non renouvelable) + **export .ics** — 1 sem.
- **Animation des systèmes de jeu** (⭐ meilleur ratio des 5 visions : `EtapeExercice`/Bézier déjà en base, zéro serveur ; budget 4 sem pour couvrir les cas dégénérés) + **présentation TV télécommandée** par-dessus — 5 sem.
- **Live Activity LOCALE** (seule exception temps réel admise) — 1 sem.
- **App Intents + widget « Prochain événement » + Spotlight** — 2 sem.
- **Résumé narratif de match FoundationModels** — décoration au-dessus de `MetriquesVolley`, jamais source de vérité, fallback stats brutes ; **bonus silencieux, jamais promesse App Store** (le parc iPad des cégeps n'a pas Apple Intelligence) — 2 sem.

### À 18 mois (H3) — UN seul gros pari (décision de gouvernance)
- **Option A (défaut)** : **vidéo synchronisée aux stats v1** — la saisie EST le tagging (`PointMatch.horodatage` → chapitres vidéo), playlists « tous les kills de #12 », revue entre les sets, export de clips. Devis honnête du sceptique : **8-12 semaines** (thermique, stockage 4-6 Go/match strictement local avec purge infaillible, jamais dans CloudKit). C'est ce que Volleymetrics facture des milliers de dollars, ici offline et sans ML.
- **Option B (si lettre d'intention d'un club 10+ équipes)** : **rapport de match web par lien statique** (le WebReports de SoloStats, zéro compte, zéro base) puis dashboard club lecture seule minimal sur Supabase.
- Spikes 1 semaine max : scouting agrégé multi-matchs (bandeau « basé sur N matchs », narration seulement si N≥2), scan de feuille papier (FM multimodal iOS 27, fallback Vision/OCR), plan de séance par tool calling sur la bibliothèque du coach (jamais d'exercices inventés).

### Écartées (et pourquoi — verdicts des critiques, confirmés)
| Écartée | Raison |
|---|---|
| App Clip | 3 sem pour économiser une installation ; lien universel suffit |
| P2P multi-appareils Bonjour/AWDL | « 4-5 sem » = fiction ; 2-3 mois + bugs irreproductibles. Version dégradée si besoin criant : l'assistant saisit sur son appareil, CloudKit fusionne (l'append-only rend ça sûr) |
| Live Activities broadcast parents + worker | Premier serveur = astreinte du samedi ; strictement au premier contrat signé |
| Analyse de pose, auto-tracking ballon/score, visionOS, Siri vocal courtside, watchOS coach | Niveau recherche, gymnase à 85 dB, matériel inexistant chez la cible |
| Assistant conversationnel stats | Paraphrase l'UI ; réévalué à 12-18 mois via protocole `LanguageModel` |
| IA vidéo maison, export .dvw construit (annoncé seulement, CSV documenté suffit), Android natif, réseau social, tier gratuit à pubs, prix par athlète | Consensus des 5 visions + critiques |
| Mini-évaluateur d'expressions de métriques, volleyball.json intégral, extraction beach forcée | Inner-platform effect ; les formules restent en Swift jusqu'au 2e sport **payant** |
| OCR roster, registre fédéral, e-feuille officielle, module arbitres, EFVP contractuelle | Cf. §12 |

---

## 7. Architecture technique cible

**Verdict structurant (lentille architecture, validé par le sceptique) : rien n'exige un from scratch.** Les trois fondations de la cible existent : event log (`PointMatch` append-only), formules centralisées (`MetriquesVolley`/`AgregateurStatsMatch`, v2.2), persistance string-keyed + JSON-blobs versionnés. La 3.0 est une **extraction progressive**, pas une réécriture.

### SportDescriptor — trajectoire dégonflée
- **Maintenant (phase 0, 3 jours)** : champs additifs CloudKit-safe + règle de lint « jamais de `if sport == volleyball` dans du code neuf ; on teste une capacité ». Les `typeActionRaw` persistés en String sont déjà les clés du futur catalogue — zéro migration.
- **Au 2e sport payant (pas avant)** : extraction `PlaycoCore` (SPM), `volleyball.json` qui décrit l'existant **à l'identique** sous golden tests, catalogues seulement (actions→compteurs, postes, terrains/zones, formats de manches). Formules séquentielles (sideout, rotation) = code Swift derrière un protocole `MoteurSport`, immuable (nouvel état retourné, jamais de mutation). Vues sport-spécifiques (RotationLive) montées par capacité, pas rendues génériques.
- **Beach** : cobaye technique opportuniste (si un chantier touche déjà ces fichiers) ; le beach comme *produit* (paires, tournois multi-matchs, saison d'été) est un chantier marché distinct (cf. §9).

### Backend hybride — deux plans, zéro serveur spéculatif
```
PLAN ÉQUIPE (chemin critique terrain)          PLAN ORGANISATION (B2B, au 1er contrat)
SwiftData local + CloudKit privé (conservé     Supabase Postgres ca-central-1 (Loi 25)
à vie, gratuit) + Public DB (dépréciée         RLS multi-tenant · SIWA web (même sub) +
progressivement quand le backend a fait        magic link admins · dashboard SvelteKit
ses preuves — jamais avant)                    lecture d'abord · Stripe hors App Store
        │                                              ▲
        │  OUTBOX idempotente (généralisation du       │
        │  journal sync + dateModification existants)  │
        └── event log : push one-way ─────────────────┘
            documents : LWW par dateModification
            officiel inter-clubs : machine à états serveur (H3+)
```
- **Contrat architectural n°1** : si le backend brûle, aucun coach ne le remarque avant d'ouvrir le web. Aucune fonctionnalité terrain ne dépend du réseau, jamais.
- **Séquence web durcie par le sceptique** : (1) rapport de match **statique par lien** (zéro base, zéro compte) → (2) dashboard club lecture Supabase au contrat signé → (3) écriture limitée (calendriers, rosters) → (4) registre de développement athlète fédé. **Une seule stack** (Supabase = Postgres standard + OIDC, réversible), pas trois.
- **Sync** : ni CRDT ni prière — le match a un seul scoreur (single-writer by design) ; l'event log s'upserte par UUID ; les documents mergent en LWW `dateModification` (mécanisme déjà en production sur la Public DB).
- **Autorité de calcul** : l'app du coach. Le serveur affiche les agrégats poussés, vérifiés par vecteurs de tests JSON partagés dans `PlaycoCore` — jamais de réimplémentation TS des formules.
- **Notifications** (dette invisible relevée par la complétude) : cartographiées explicitement — « box score prêt » = CKSubscription (maintenant, sans serveur) ; rappels/RSVP/broadcast = backend (au contrat).

---

## 8. Positionnement marché

> **« Du plan de pratique au développement de l'athlète : tout le volleyball de votre équipe dans une seule app iPad, qui fonctionne sans wifi dans n'importe quel gymnase, en français, au prix d'une paire de souliers plutôt que d'un contrat Hudl. »**

**Trois différenciateurs défendables** : (1) la verticale complète en un produit (pratique + live + scouting + physique + athlète — des années-personne que ni TeamSnap ni Rotate123 ne rattrapent, avec un coût de changement qui croît à chaque saison de données) ; (2) l'offline-first Apple-native (douve architecturale : la valeur de Hudl/Balltime vit sur le serveur) ; (3) l'ancrage Québec (terminologie juste, calendrier RSEQ/cégeps, Loi 25, circuit court d'un fondateur-coach — les Américains ne viendront pas se battre pour 11 800 joueurs RSEQ).

**Pilier stratégique (promu de « parade » à « pilier ») : complémentaire de Spordle, jamais concurrent.** Spordle gère l'inscription ; Playco gère la performance. Exports/interop dès que pertinent.

**Séquence de conquête (ambitions divisées par trois, règle du sceptique)** :
1. **0-6 mois — 5 à 8 ambassadeurs** cégep RSEQ / clubs civils, servis obsessionnellement (pas 20 négligés). Démo qui tue : sideout % par rotation, live, offline, en français. Le vendredi appartient aux ambassadeurs.
2. **6-18 mois — le club phare** (10-20 équipes, pilote contre étude de cas), puis 3-5 clubs payants via les tournois. Le dashboard club se construit **ici**, dollar par dollar.
3. **18-30 mois — Volleyball Québec** : pitch « X % de vos clubs utilisent déjà Playco ; voici la couche développement de l'athlète et les rapports DLTA qui vont avec » — entrée par projet pilote délimité, jamais par remplacement du registre.
4. **30 mois+ — anglais, puis basketball** (même acheteur, même gymnase, marché RSEQ 2×) ; flag football en veille (fenêtre LA 2028). **Aucun 2e sport ne s'amorce avant que le volleyball ait gagné son marché.**

Chaque phase ne démarre que si la précédente a sa preuve (rétention saison complète → 3 clubs payants → 1 lettre d'intention fédé). **Le concurrent n°1 reste le papier + Google Sheets + Messenger** : c'est lui que l'onboarding <10 min, le tier logistique gratuit et le ton marketing doivent battre.

---

## 9. Angles morts intégrés (critique de complétude — décisions)

Les trois angles morts systémiques des 5 visions — **le temps long, les humains sans iPad/Apple ID, les obligations non fonctionnelles** — sont intégrés ainsi :

| # | Angle mort | Décision Playco 3.0 | Quand |
|---|---|---|---|
| 1 | **i18n FR/EN** (0,4 % traduit, 639 chaînes en dur) | Règle non négociable : **zéro chaîne hardcodée dans tout écran touché par la refonte** (String Catalogs + clés). La traduction EN complète = chantier de la phase anglophone (30 mois), mais l'architecture se paie maintenant, pendant la refonte, pas après. | H1→continu |
| 2 | **Consentement mineurs tier Équipe** (passif juridique actif) | Minimum viable avant/au lancement : attestation coach horodatée, avis parent par lien, **DM privés adulte↔mineur désactivés par défaut** (la règle de deux, dès le tier Équipe), page de rétention publiée. Pas d'EFVP contractuelle (obligation qu'un solo ne peut honorer). | H1 |
| 3 | **<13 ans / SIWA** (mini-volley structurellement exclu) | Modèle « profils gérés » : le compte SIWA du parent possède N profils enfants. **Conçu avec l'identité backend** (table `personnes` ↔ tuteurs), livré au tier Club. | Conception H1, livraison H3 |
| 4 | **Cycle de saison** (rollover, archives, purge) | Assistant de renouvellement (dupliquer équipe, reporter roster, réémettre invitations), archives lecture seule, comparaison saison-sur-saison, politique de purge (PointMatch + vidéo). **Avant la première fin de saison de la base** (mai 2027). | H2/H3 |
| 5 | **Profil carrière athlète** (l'historique ne suit pas) | Agrégation par `appleUserID` côté app : mes saisons, mes équipes, mon évolution. Fondation posée dans le modèle d'identité — c'est LA rétention athlète et le prérequis du recrutement. | H2 (fondation), H3 |
| 6 | **CV de recrutement** | PDF exportable (stats multi-saisons + tests physiques déjà en base + palmarès) au tier Équipe ; profil web « vérifié » plus tard. La boucle virale la plus puissante du segment 15-19 ans. | H3 |
| 7 | **Appareil partagé** (iPad du cégep, table de marque) | Sessions par appareil + rôle « poste de saisie » — conçu avec l'auth, requis avant toute ambition e-scoresheet. | Conception H2 |
| 8 | **Accessibilité** | Palettes daltonisme-sûres + motifs/formes en renfort de couleur (heatmap divergente, nous/adversaire), stratégie Dynamic Type des tableaux, VoiceOver sur le terrain animé — **intégré à la refonte visuelle** (coût S si fait pendant, M après) ; web WCAG 2.1 AA = critère d'appel d'offres fédé. | H2 |
| 9 | **DLTA/LTAD** | Vocabulaire et gabarits de rapport alignés sur le cadre canadien — coût marginal, pouvoir de signature fédé maximal. | Avec le pitch fédé |
| 10 | **Beach comme produit** (paires, tournois, été) | Chantier distinct du descripteur : mode tournoi multi-matchs + entité paire. Contre-cycle estival = réponse au « je paie 12 mois pour 4 ». | Post-H3, après preuve indoor |
| 11 | **Athlète Android/web** | La page box-score par lien (H3 option B ou dès le premier livrable web) couvre le vestiaire mixte ; profil athlète web lecture au backend v1. | H3 |
| 12 | **Statut disponibilité** (blessé/suspendu) | Deux champs, trois filtres : grisé dans composition/présences, muscu suspendue. Quick win. | H1 |
| 13-15 | Discipline de ligue, admissibilité académique RSEQ, parasport (volleyball assis) | Admissibilité = mécanique « grisé à la composition » (S, avec la tête de pont cégep). Discipline + parasport = arguments fédé, sur le backend. Le volleyball assis est le 2e cobaye parfait du descripteur — une ligne de pitch que personne n'a. | H2 (14), fédé (13, 15) |
| 16 | **Propriété/succession d'équipe** | Transfert de propriété + export complet hors-CloudKit (l'anti-lock-in promis doit exister au tier Équipe ; au tier Club, le club possède les données de ses équipes). Conçu avec l'identité backend. | Conception H2 |
| 17 | **Cartographie notifications** | Faite (§7) : CKSubscription maintenant, APNs applicatif au contrat. | H1 (document) |

**Principe gravé (issu de la vision B2B, promu transversal) : la frontière de confiance pédagogique.** Séances, exercices, stratégies, dessins et scouting d'un coach ne remontent **jamais** au club ni à la fédération. Ce qui remonte : rosters, présences, résultats, stats de match consenties. Écrit dans le produit et dans les contrats.

---

## 10. Roadmap 3 horizons (périmètre solo-dev réaliste)

**Budget : 25-30 semaines effectives/an. Règles de gouvernance : un seul pari >6 semaines par année ; tout item >4 semaines passe un spike d'une semaine avec critère d'abandon écrit ; toute estimation des visions ×2 (×3 si réseau/multi-appareils/juridique) ; zéro dollar d'infra avant contrat signé.**

### H1 — Mois 0-4 : consolider le lancement, tuer la friction (~8 sem)
- State Restoration match live (0,5 sem) · Match éclair + promotion calendrier→match + composition persistante (3 sem) · Carte héro dans l'accueil actuel + recherche exposée (2 sem) · QR/liens universels (1,5 sem) · Phase 0 SportDescriptor + convention des irréversibles (0,5 sem) · Consentement mineurs minimal + statut blessé (1 sem).
- Transversal : règle « zéro chaîne hardcodée » active ; cartographie notifications documentée ; le vendredi aux 5-8 ambassadeurs.

### H2 — Mois 4-10 : la refonte d'IA, par étapes (~11 sem)
- TabView adaptative + 5 moments, en 2 releases (fusion Playbook, puis hub Analyser) (6 sem) — accessibilité et i18n intégrées à chaque écran réécrit.
- Wizard 3 écrans + onboarding progressif (2 sem) · Paiement par saison + export .ics (1 sem).
- Animation des systèmes de jeu + présentation TV télécommandée (5 sem, chevauche H3 si nécessaire) · Live Activity locale (1 sem).
- Conception (pas code) : identité backend (profils gérés <13, appareil partagé, succession d'équipe, profil carrière) — les décisions qui ne se réparent pas après coup.

### H3 — Mois 10-18 : UN pari + les fondations du temps long (~10 sem)
- **Le pari** (décision de gouvernance à la fin de H2, données ambassadeurs en main) : vidéo synchronisée v1 (8-12 sem, défaut) **OU** rapport web statique + dashboard club (si lettre d'intention club). Jamais les deux.
- Résumé narratif FoundationModels, bonus silencieux (2 sem) · App Intents + widget + Spotlight (2 sem).
- Cycle de saison : assistant de rollover + archives (avant mai 2027) · Fondation profil carrière athlète.
- Spikes 1 sem max : scouting agrégé, scan feuille papier, plan de séance tool-calling.
- Déclencheur backend : **premier contrat club signé et payé** → Supabase + dashboard lecture (4-6 sem, remplace ou suit le pari selon le calendrier).

---

## 11. Décisions irréversibles vs réversibles · Top 5 risques

### Irréversibles (à graver maintenant — coût de changement ≈ infini)
1. **IDs stables** : UUID + clés String des actions/compteurs/sports (`"kill"`, `"volleyball"`), persistées à vie, jamais renommées.
2. **Additivité du schéma CloudKit** : on n'enlève jamais, on ne renomme jamais ; les colonnes volley sont des fossiles assumés, inscrits dans un registre.
3. **1 équipe = 1 sport** (`Equipe.sportID`) ; le multi-sport = équipes multiples, jamais d'équipe hybride.
4. **L'event log comme source de vérité des stats de match** (PointMatch append-only → projections).
5. **Séparation identité/rôle côté backend** (`personnes` ↔ `affiliations`) — avec tuteurs et profils gérés dès la conception.
6. **Apple Team ID** : jamais changé (le `sub` SIWA est scopé par team = tous les comptes).
7. **Le contrat local-first** : aucune fonctionnalité terrain ne dépend du réseau — c'est la promesse faite aux coachs.
8. **La frontière de confiance pédagogique** (§9) — produit ET contrats.

### Réversibles (changeables à coût borné)
Supabase (Postgres standard + OIDC → migrable) · framework du dashboard · LWW par enregistrement (→ par champ si besoin réel) · Public DB CloudKit (sortie planifiée, rythme ajustable) · Stripe · beach variante vs sport séparé · granularité du partage inter-clubs · le pari H3 lui-même (vidéo vs club).

### Top 5 risques et mitigations
| # | Risque | Mitigation |
|---|---|---|
| 1 | **Scope solo-dev** : la vision devient une liste que personne ne peut livrer ; l'année se dilue en douze demi-features | Règles de gouvernance (§10) opposables à ce document même ; un pari/an ; spikes avec critère d'abandon ; ambitions GTM divisées par trois |
| 2 | **Hudl/Balltime descend en prix avec l'IA vidéo** (probable — acquisition 2025, package Premier 2026) | Gagner où la vidéo perd : le live (décisions pendant le match), l'offline, le prix, la langue ; la vidéo Playco *complète* la saisie au lieu de la remplacer ; veille trimestrielle du prix Balltime |
| 3 | **Spordle ajoute un module performance** vendu aux fédés qu'il détient | Vitesse (signer la couche coaching avant qu'elle existe chez eux) + posture complémentaire explicite (exports vers Spordle) + relation directe Volleyball Québec dès maintenant |
| 4 | **La refonte d'IA régresse une base saine** (253 tests, utilisateurs payants) | Phasage en 3 releases ; golden tests sur toute extraction ; la navigation change, la couche données ne bouge pas ; TabView native = moins de code custom qu'aujourd'hui |
| 5 | **Passifs non fonctionnels découverts trop tard** (mineurs/Loi 25 déjà exigible, i18n, accessibilité d'approvisionnement, verrou CloudKit) | Consentement minimal en H1 ; règle i18n/a11y « pendant la refonte, pas après » ; phase 0 additive ; conformité *hygiène pour soi*, jamais vendue contractuellement tant que l'équipe = une personne |

---

## 12. Ce qu'on ne fera PAS (liste anti-scope-creep, assumée)

1. **Registre central des membres** (affiliations, mutations, surclassements, catégories d'âge automatiques) — produit entier de 12-18 mois, créneau verrouillé par Spordle, cycle de vente incompatible. On s'y branche, on ne le remplace pas.
2. **Feuille de match électronique officielle co-signée** — exige l'effet réseau et le contrat fédé qui n'existent pas ; réévaluée à 36 mois si un contrat la finance.
3. **Tout serveur avant un contrat B2B signé et payé** — ni worker « à 20 $/mois », ni Supabase spéculatif, ni broadcast Live Activities. Le premier dollar d'infra suit le premier dollar de contrat.
4. **P2P multi-appareils (Bonjour/AWDL)** — 2-3 mois réels + traîne de bugs ; fallback CloudKit-quand-réseau si le besoin hurle.
5. **Moteur d'expressions / volleyball.json intégral / extraction beach forcée / 2e sport livré** — seule la phase 0 additive passe ; les formules restent en Swift jusqu'au 2e sport payant.
6. **App Clip, watchOS coach, visionOS, analyse de pose, auto-tracking ballon/score, Siri vocal courtside, assistant conversationnel** (ce dernier réévalué H3+).
7. **Refonte d'IA en big-bang mono-release.**
8. **Modules de conformité vendus contractuellement** (EFVP clé en main, blessures médicales, arbitres) — l'hygiène pour soi, oui ; l'engagement contractuel qu'un solo ne peut honorer, non.
9. **Export .dvw construit** (annoncé, CSV documenté livré), **Android natif**, **réseau social**, **IA vidéo maison**, **prix par athlète**, **tier gratuit à pubs**, **paywall sur la logistique**.
10. **Plus d'un pari >6 semaines en parallèle** — la règle méta qui protège toutes les autres.

---

*Ce document est la vision arbitrée. La décision « refonte progressive vs from scratch » en découle directement : **refonte progressive** — les trois fondations de la cible (event log, formules centralisées, persistance string-keyed) existent déjà dans le code v2.2 ; le multi-sport est une extraction sous golden tests ; le backend est une couche additive hors chemin critique déclenchée par le premier contrat. Rien n'exige de repartir de zéro, et tout dans le budget solo-dev l'interdit.*
