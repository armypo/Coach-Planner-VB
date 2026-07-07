# Playco — Lentille Club & Fédération (B2B)
## Vision de la couche organisation — v1.0, juillet 2026

> **Thèse.** Playco a déjà ce qu'aucun logiciel de fédération ne possède : la donnée terrain, saisie en temps réel par le coach, dans le gymnase, sans wifi. Les Spordle, SportLomo et Amilia de ce monde gèrent l'administratif mais ne savent rien de ce qui se passe sur le terrain. L'angle B2B de Playco n'est donc pas « un autre registre » : c'est **le seul système où la feuille de match, le classement de ligue, le registre d'athlètes et le développement du joueur sont alimentés par la même saisie**, faite une seule fois, par le coach, pendant le match. Tout le reste de ce document découle de cette asymétrie.

---

## 1. Modèle organisationnel & multi-tenant

### 1.1 La hiérarchie

```
Fédération (ex. Volleyball Québec)                    ← tenant racine
└── Association régionale (ex. Région Québec–Ch-App)  ← niveau optionnel
    └── Club (ex. Club Célestes de Québec)            ← unité économique
        └── Programme/Saison (ex. 2026-2027)          ← axe temporel
            └── Équipe (ex. U16 F Division 1)         ← unité d'usage (l'app actuelle)
                └── Membre (athlète, coach, gérant, parent lié)
```

Deux principes structurants :

1. **Le niveau supérieur est toujours optionnel.** Un coach solo vit sans club (c'est le produit actuel). Un club vit sans fédération. Une fédération coiffe des clubs existants sans les forcer à réonboarder. Concrètement : l'entité `Organisation` (nouveau backend) a un `parentOrgID` nullable. Le tenant = l'organisation racine de la chaîne (fédération, ou club autonome, ou « organisation fantôme » implicite pour le coach solo).
2. **La frontière de confiance pédagogique est sacrée.** Les séances, exercices, stratégies, dessins de terrain et scouting reports d'un coach ne remontent **jamais** au club ni à la fédération. Ce qui remonte : rosters, présences, résultats, feuilles de match, stats de match, blessures (avec consentement), conformité. C'est LA condition d'adoption bottom-up : si le coach sent que le DG lit ses plans de match, il n'utilise plus l'app, et sans coach il n'y a plus de donnée, donc plus de valeur fédé. Cette frontière doit être écrite noir sur blanc dans le produit ET dans le contrat.

### 1.2 Mapping avec le code actuel

Le modèle existant s'étend naturellement, il ne se remplace pas :

| Existant (SwiftData/CloudKit) | Devient dans la couche B2B |
|---|---|
| `Etablissement` (déjà typé `club`/`cegep`/`ecoleSecondaire`…) | Miroir local de l'`Organisation` backend ; gagne un `orgID` serveur |
| `Equipe.codeEquipe` (8 chars Base32 Crockford, 40 bits) | Reste la clé de scoping locale ; l'équipe gagne un `orgID` de rattachement |
| `Utilisateur` + `codeInvitation` (SIWA strict) | Reste l'identité app ; gagne un `membreFederalID` optionnel (numéro d'affiliation) |
| `StatsMatch` / `PointMatch` / `Seance` type match | Source de la feuille de match électronique publiée vers l'API |
| `TestPhysique` | Base des tests physiques standardisés provinciaux |
| `StaffPermissions` (7 booleans) | Généralisé en matrice de rôles org (voir 1.4) |
| `Presence` | Alimente le rapport d'assiduité club |

Le pattern de publication existe déjà (`CloudKitSharingService` publie des miroirs sanitisés vers la Public DB) : la couche B2B remplace/complète cette cible par l'API propre, avec la même philosophie — **local-first, publication événementielle idempotente, l'app ne bloque jamais sur le réseau**. Un match saisi hors-ligne dans un gymnase de Rimouski se publie au retour du wifi ; le classement de ligue se met à jour à ce moment-là, pas avant, et c'est acceptable.

### 1.3 Comment un club à 12 équipes vit dans le produit

Persona : **le DG / registraire d'un club civil** (souvent un bénévole ou un demi-poste). Son quotidien aujourd'hui : Excel + Amilia + courriels + Facebook Messenger. Ce qu'il obtient :

- **Onboarding club** : le DG crée le club sur le web, invite ses 12 coachs par courriel. Chaque coach télécharge l'app, SIWA, et son équipe est pré-rattachée (le wizard 6 étapes actuel se raccourcit : établissement + équipe déjà créés côté club). Les équipes existantes d'un coach déjà utilisateur se **rattachent** au club par code — pas de re-saisie.
- **Vue roster consolidée** : 140 athlètes, filtrables par équipe/catégorie/statut d'affiliation. Mutation interne (une U15 surclassée en U16 pour un tournoi) = 2 clics, tracée.
- **Calendrier maître** : les créneaux récurrents (`CreneauRecurrent`) et matchs (`MatchCalendrier`) des 12 équipes sur une seule grille, avec **gestion des plateaux** (gymnases) : conflits détectés, le club voit que le gymnase A est libre le mardi 18h.
- **Bibliothèque de club** : curriculum d'exercices et programmes muscu partagés du club (extension naturelle d'`ExerciceBibliotheque.codeCoach` → `orgID`) — le directeur technique pousse une progression commune U13→U18, chaque coach la copie et l'adapte dans SA bibliothèque (copie, pas lien : la frontière pédagogique reste intacte).
- **Conformité en un écran** : qui n'a pas payé son affiliation, quel coach a une vérification d'antécédents expirée, quel parent n'a pas signé le consentement.
- **Facturation unique** : 12 équipes sous un seul contrat club (voir §6), fini les 12 abonnements App Store à rembourser aux coachs.

### 1.4 Rôles et permissions (matrice cible)

| Rôle | Périmètre | Voit | Fait |
|---|---|---|---|
| **Admin fédération** | Tenant entier | Agrégats, registre, ligues, conformité | Paramètres saison/catégories, règlements, approbation mutations |
| **Admin régional** | Sa région | Idem, filtré région | Gestion ligues régionales |
| **Registraire club** | Son club | Registre club, paiements | Affiliations, demandes de mutation |
| **DG / dir. technique club** | Son club | Résultats, présences, blessures, conformité, calendrier maître | Créer équipes, assigner coachs, bibliothèque club |
| **Coach-chef** | Son équipe | Tout de son équipe | Le produit actuel (rôle `.admin`) |
| **Assistant** | Son équipe | Selon `StaffPermissions` | Le produit actuel (rôle `.coach`) |
| **Athlète** | Soi + son équipe | Ses stats, calendrier, messages | Le produit actuel (rôle `.etudiant`) |
| **Parent/tuteur** *(nouveau)* | Son enfant mineur | Calendrier, présences, stats de l'enfant, communications | Consentements, coordonnées, signalement |
| **Marqueur de ligue** *(nouveau)* | Un match | La feuille de match | Saisie/validation feuille |
| **Arbitre** *(module opt.)* | Ses assignations | Calendrier d'assignation | Signature de feuille, rapport |

Règle d'or : **les permissions descendent, les données agrégées montent, les données pédagogiques ne montent jamais.**

---

## 2. Les features qui font signer une fédération

### 2.1 Registre central des membres (le cœur)

C'est le système opérationnel d'une fédération — celui pour lequel elle paie déjà un fournisseur. Pour le déplacer, il faut couvrir à 100 % :

- **Dossier membre unique** : un athlète = un `membreFederalID` à vie, indépendant du club. Photo, date de naissance (vérifiée une fois, source des catégories), contacts, tuteurs liés.
- **Affiliation annuelle** : statuts (active / en attente de paiement / suspendue), types (compétitif, récréatif, scolaire, essai), fenêtres de dates paramétrables par la fédé. **Règle produit clé : un athlète non affilié ne peut pas apparaître sur une feuille de match officielle** — l'app coach l'affiche grisé avec le motif. C'est l'application automatique du règlement que les fédés font aujourd'hui à la main, après coup, avec des amendes.
- **Catégories d'âge auto-calculées** : moteur de règles « né entre X et Y ⇒ U16 pour la saison S » paramétrable par la fédé (et par sport — voir SportDescriptor, §8 note). Zéro saisie, zéro erreur de classement.
- **Mutations (transferts inter-clubs)** : workflow demande (club acquéreur) → consentement (athlète/tuteur) → approbation ou délai d'opposition (club cédant) → validation fédé. Traçé, horodaté, avec période de mutation paramétrable. Aujourd'hui : des courriels et des PDF.
- **Surclassements** : demande du coach → règles automatiques (max N catégories, pas plus de X matchs, autorisation parentale pour mineur, attestation médicale si exigée) → approbation club/fédé. Le surclassement approuvé rend l'athlète **sélectionnable dans la composition de match** de l'équipe supérieure — directement dans `CompositionMatchView`.
- **Double affiliation / scolaire+civil** : un athlète cégep (RSEQ) ET club civil (Volleyball Québec) = deux affiliations sur un même dossier. C'est un cauchemar réel au Québec ; le gérer nativement est un argument de vente en soi.
- **Import de l'existant** : import CSV/XLSX des registres actuels (exports Spordle/Amilia/maison), avec dédoublonnage assisté (nom + date de naissance). Une fédé ne signera jamais si la migration ressemble à une re-saisie.

### 2.2 Ligues, tournois, résultats officiels, classements

- **Création de ligue** : divisions, poules, format (aller-retour, festivals, tournois à vagues typiques du volley civil québécois), règles de points (3-0/3-1/3-2, ratio de sets, point-average FIVB comme bris d'égalité).
- **Génération de calendrier inter-clubs** : round-robin avec contraintes (disponibilité plateaux déclarée par les clubs, distances régionales, pas 2 matchs même jour pour une équipe). Publication → chaque `MatchCalendrier` d'équipe se peuple automatiquement dans l'app des deux coachs concernés. Le calendrier unifié existant devient bidirectionnel.
- **Résultats officiels** : quand le match est un match de ligue, la finalisation dans Playco (score par set déjà structuré via `SetScore`) **est** la remontée de résultat. Pas de re-saisie sur un portail. Classements recalculés à la minute, publiables (widget web embarquable sur le site du club/de la fédé).
- **Tournois** : seeding depuis le classement, brackets, horaires par vagues, résultats en direct à la table de marque sur iPad — le mode courtside existant est littéralement conçu pour ça.

### 2.3 Feuille de match électronique officielle (e-scoresheet)

La killer feature de jonction terrain↔fédé :

- Roster **verrouillé depuis le registre** (affiliations + surclassements vérifiés à la composition), numéros de maillot, libéro(s), staff banc.
- Pendant le match : le score par set et les données `PointMatch` déjà saisies génèrent la feuille — sanctions/cartons et remarques ajoutées par la table.
- **Co-signature** : coach A, coach B, arbitre (ou marqueur) signent sur l'iPad (signature tactile + horodatage + identité SIWA). La feuille signée devient immuable, versionnée, exportable **PDF au format officiel** de la fédération (gabarit paramétrable, aligné sur la feuille FIVB/VQ).
- Litiges : procédure de protêt attachée à la feuille, visible fédé.
- Mode dégradé assumé : pas de réseau au gymnase → tout se signe localement sur l'iPad de la table, publication différée. C'est exactement la force actuelle de l'app.

### 2.4 Certifications et parcours coach

- Dossier coach : niveaux **PNCE** (Programme national de certification des entraîneurs), formations fédé, **vérification d'antécédents judiciaires** (date + expiration), formations safe sport (type Respect et sport / Sport'Aide) — Playco **suit** les attestations (upload de preuve, dates), il ne les délivre pas.
- **Blocage souple paramétrable** : la fédé décide si un coach non conforme est bloqué d'assignation à une équipe compétitive, ou juste signalé en jaune au club. (Commencer en mode signalement : le blocage dur crée des crises politiques la première saison.)
- Rappels automatiques 90/30/7 jours avant expiration — au coach ET au registraire du club. C'est bête, et c'est ce qui fait gagner des heures aux fédés.

### 2.5 Arbitres — module optionnel, phase 2

L'assignation d'arbitres est demandée par toutes les fédés mais c'est un métier en soi (disponibilités, niveaux, distances, paie/per diem, politique d'assignation). Recommandation : **registre + niveaux + assignation manuelle + signature de feuille** en v1 du tier fédé (suffisant pour la démo), auto-assignation et gestion de paie en module payant séparé plus tard. Ne pas laisser ce module retarder la signature.

### 2.6 Statistiques agrégées provinciales & détection de talents

Le différenciateur absolu — **personne d'autre ne peut l'offrir** parce que personne d'autre n'a la donnée point-par-point :

- **Standards de développement** : distributions provinciales par catégorie/âge (hitting %, efficacité de réception 0-3, sideout %, tests physiques standardisés via `TestPhysique` — protocole provincial : saut vertical, allonge, etc.). Le coach voit « ton U16 reçoit à 1,9 ; le p50 provincial U16 F est 2,1 » — valeur pour le coach ET pour la direction technique de la fédé qui pilote son plan de développement.
- **Détection de talents** : pour les identifications Équipe Québec, la fédé requête « U15 F, top 5 % en attaque, min 8 matchs joués » au lieu d'envoyer des dépisteurs partout. **Garde-fou vie privée** : les agrégats sont anonymisés par défaut ; l'accès nominatif à un profil de mineur exige le consentement « programme d'identification » signé par le tuteur (case distincte à l'affiliation, voir §4).
- **Rapport annuel de la fédé** : participation, rétention par âge/sexe/région, heures d'entraînement — les chiffres que les fédés doivent produire pour leurs subventions gouvernementales (Québec exige des redditions de comptes chiffrées). Générer ce rapport en 3 clics, c'est parler directement au DG de la fédé.

---

## 3. Dashboard web admin

### 3.1 Le lundi matin du DG de club

L'écran d'accueil répond à une question : *« que s'est-il passé en fin de semaine et qu'est-ce qui brûle ? »*

1. **Résultats du week-end** — les 12 équipes : V/D, scores par set, lien feuille de match. En un coup d'œil.
2. **Alertes conformité** (triées par gravité) : « 2 athlètes non affiliées ont été alignées samedi (U17 F) » / « certification de J. Tremblay expire dans 12 jours » / « 3 consentements parentaux manquants U14 ».
3. **Blessures rapportées** (si consenties) : « 1 blessure déclarée — cheville, U16 M » → suivi retour au jeu.
4. **Assiduité** : taux de présence 7 derniers jours par équipe, flag si une équipe passe sous 70 %.
5. **Finances** : affiliations impayées, échéances.
6. **Semaine à venir** : occupation des plateaux, matchs à domicile (besoin de marqueurs/bénévoles).

### 3.2 Vues, rôles, exports

| Vue | Fédération | Club | Exports |
|---|---|---|---|
| Tableau de bord | agrégats provinciaux, santé des clubs | le lundi matin ci-dessus | PDF hebdo automatique par courriel |
| Registre membres | tous, + workflow mutations | son club | CSV/XLSX liste d'affiliation |
| Ligues & classements | CRUD complet | lecture + dispos plateaux | classements CSV, widget web, PDF |
| Feuilles de match | archivage officiel, protêts | ses équipes | PDF officiel signé |
| Conformité | vue provinciale, règles | son club | rapport d'audit |
| Statistiques | agrégats, détection (consentie) | comparaisons internes club | XLSX |
| Facturation | contrat, sièges | son abonnement club | factures PDF |
| Loi 25 | registre incidents, demandes d'accès | demandes de ses membres | dossier complet d'un membre (portabilité) |

### 3.3 Architecture (contrainte : dev solo, budget infra minimal)

- **Un monolithe simple** : Postgres + API REST + dashboard SSR (une stack, un déploiement, hébergé au Canada — voir §4). Pas de microservices, pas de temps réel websocket en v1 : le rafraîchissement des classements à la publication suffit.
- **L'app reste la source de vérité terrain** ; le backend est la source de vérité **organisationnelle** (registre, ligues, conformité). Le protocole entre les deux : publications idempotentes horodatées (le pattern `dateModification` + merge déjà en place pour la Public DB CloudKit se transpose tel quel).
- CloudKit **reste** pour la sync intra-équipe des contenus pédagogiques (dessins, séances) — zéro coût serveur pour la donnée la plus lourde. Le backend ne reçoit que la donnée organisationnelle, légère. C'est ça qui rend le tier fédé rentable à petit prix.
- Auth web : magic link courriel (les registraires n'ont pas d'Apple ID pro) + SIWA en option. L'app garde SIWA strict.

---

## 4. Conformité & confiance — souvent LE critère d'achat

Une fédération n'achète pas des features, elle achète la **réduction de son risque juridique et réputationnel**. C'est le chapitre à mettre en avant dans le pitch.

### 4.1 Mineurs et consentement parental

- Tout membre < 18 ans (ou < 14 pour le consentement autonome selon la Loi 25 — au Québec, un mineur de 14 ans et plus peut consentir seul pour certains traitements) est **lié à au moins un tuteur** avec compte parent.
- **Consentements granulaires, horodatés, versionnés**, recueillis à l'affiliation : (a) profil et données sportives de base — requis ; (b) photo ; (c) apparition dans les statistiques publiées (classements de pointeurs, palmarès) ; (d) programme d'identification de talents (accès nominatif fédé) ; (e) données de blessure partagées au club. Chaque case refusable indépendamment ; le produit dégrade gracieusement (athlète = « Joueuse #12 » dans les stats publiques si (c) refusé).
- **Messagerie safe sport** : la messagerie actuelle doit appliquer la « règle de deux » pour les mineurs — pas de conversation privée 1-à-1 adulte↔mineur ; soit canal d'équipe, soit parent automatiquement inclus, soit journalisation accessible au club. Configurable par la fédé, activé par défaut. C'est un argument de vente que zéro concurrent grand public offre.

### 4.2 Loi 25 (Québec) / RGPD-ready

- **Résidence des données au Canada** (idéalement Québec) — argument commercial explicite face aux solutions US. À inscrire au contrat.
- Registre des traitements, **EFVP** (évaluation des facteurs relatifs à la vie privée) documentée pour le produit — la fournir clé en main à la fédé, car c'est ELLE l'organisme responsable et elle doit la produire ; lui mâcher le travail accélère la signature.
- **Portabilité** (en vigueur depuis sept. 2024) : export du dossier complet d'un membre en format structuré, en libre-service.
- Droit à l'effacement avec **exceptions documentées** : les résultats officiels et feuilles de match signées sont conservés (archives sportives légitimes), les données personnelles au-delà sont purgées N années après la dernière affiliation (N paramétrable par la fédé, défaut 3 ans).
- Journal d'accès : qui a consulté le dossier d'un mineur, quand. Consultable par la fédé.

### 4.3 Safe sport

- Suivi des vérifications d'antécédents et formations obligatoires (§2.4) avec preuve d'audit : « montrez-moi que 100 % des coachs U14 étaient conformes au 1er octobre » = un clic.
- **Bouton de signalement** dans l'app athlète/parent, routé vers le mécanisme indépendant choisi par la fédé (Officier des plaintes, Sport'Aide, Bureau du Commissaire à l'intégrité) — Playco route, ne traite pas.

### 4.4 Données de santé / blessures

- Module blessures = **données sensibles** : consentement distinct, chiffrement, accès limité (athlète, tuteur, coach-chef, thérapeute désigné), jamais dans les agrégats sans anonymisation k-anonyme, rétention courte. En v1 du tier club : déclaration simple + statut retour au jeu. Ne pas jouer au dossier médical — c'est un champ réglementaire miné.

---

## 5. Interopérabilité

- **Imports** : CSV/XLSX générique avec mapping de colonnes assisté (couvre les exports Spordle/SportLomo/Amilia et les Excel maison) ; format « roster RSEQ » pour les cégeps.
- **Exports** : feuille de match PDF officielle ; classements/calendriers CSV et **iCal par équipe** (les parents s'abonnent au calendrier — feature d'adoption massive et triviale) ; stats XLSX.
- **Format DataVolley (.dvw)** en export : c'est le standard du volley élite mondial — un export compatible ouvre la porte des programmes universitaires et d'Équipe Québec, et crédibilise face aux analystes. Phase 2, mais à annoncer.
- **API publique en lecture** (clé par organisation) : classements, calendriers, résultats → les clubs affichent leurs classements en direct sur leur site. Webhooks : `resultat.finalise`, `mutation.approuvee`. API d'écriture : plus tard, à la demande.
- **Pas d'intégration profonde avec les registres concurrents** : on les remplace, on ne s'y branche pas. La seule passerelle qui compte : la **remontée nationale** (une fédé provinciale doit déclarer ses membres à Volleyball Canada) → un export conforme au format demandé par l'organisme national suffit en v1.

---

## 6. Pricing & go-to-market

### 6.1 Structure des trois tiers

| Tier | Unité de facturation | Prix indicatif (CAD) | Canal | Contenu |
|---|---|---|---|---|
| **Équipe** (actuel Pro) | par équipe | ~99 $/an ou 12 $/mois | App Store (StoreKit 2, en place) | Tout le produit coach ; athlètes gratuits, jamais bloqués (déjà le cas) |
| **Club** | par équipe, dégressif | 69 $/équipe/an, min 5 équipes (~350 $ plancher) ; 59 $ au-delà de 15 | **Web + facture** (Stripe) — hors App Store, normal pour du B2B | Tout Équipe pour chaque coach + dashboard club, calendrier maître/plateaux, bibliothèque club, conformité club, rôle parent |
| **Fédération** | par membre affilié | 2–3 $/membre affilié/an, plancher ~10 000 $/an | Contrat annuel, facture | Registre central, ligues/classements, e-feuille de match, certifications, stats provinciales, Loi 25 clé en main, **et l'app tier Équipe incluse pour tous les coachs des clubs affiliés** |

Trois choix assumés :

1. **Par équipe, jamais par siège athlète.** Facturer les athlètes tue l'adoption (personne ne veut compter les têtes) et contredit le paywall role-aware existant. L'équipe est l'unité mentale du client.
2. **Par membre affilié pour la fédé** : c'est isomorphe à SON propre modèle de revenus (elle facture déjà l'affiliation ~30-60 $/tête). Elle peut répercuter 2-3 $ dans le coût d'affiliation — indolore, scalable, et ça indexe le contrat sur sa croissance. Ordre de grandeur : une fédération provinciale de volleyball compte grosso modo 10 000–20 000 membres affiliés ⇒ contrat de 25 000–60 000 $/an.
3. **Le tier fédé finance le reste.** L'app incluse pour tous les coachs affiliés fait de Playco un **avantage d'affiliation** (la fédé s'en sert pour justifier sa cotisation) et supprime le coût d'acquisition coach dans la province signée. Chaque coach actif crée la donnée qui rend le tier fédé plus indispensable. C'est le flywheel.

### 6.2 Séquence d'entrée (ne PAS commencer par la fédération)

Un cycle de vente fédération dure 12–24 mois, passe par un CA bénévole, et exige des références. La séquence réaliste :

1. **Saison 2026-27 — le club phare.** Un club civil de 10-20 équipes (bassin Québec/Lévis ou Montréal), pilote gratuit une saison complète contre étude de cas + droit de citation + comité produit mensuel. Objectif : prouver le dashboard club et le rôle parent en conditions réelles. Un seul club, servi de façon obsessionnelle.
2. **En parallèle — les cégeps.** Le coach de cégep est déjà l'utilisateur cible du produit actuel ; le réseau RSEQ collégial est petit, dense, et se parle. 15 équipes collégiales qui utilisent Playco en match = une notoriété provinciale disproportionnée. Vendre le tier Équipe, offrir le passage Club à l'établissement.
3. **Hiver 2027 — 3 à 5 clubs payants** sur la base du cas du club phare, via les tournois (les DG de clubs se croisent tous les week-ends dans les mêmes gymnases).
4. **2027-28 — Volleyball Québec.** Le pitch n'est plus « adoptez notre outil » mais « **X % de vos clubs et Y coachs utilisent déjà Playco chaque semaine ; voici le registre, la feuille de match officielle et le rapport annuel qui vont avec** ». Entrée possible par un projet pilote délimité (e-feuille de match sur UNE ligue, ou tests physiques standardisés pour l'identification) plutôt que le remplacement frontal du registre dès l'an 1.
5. **Ensuite** : autres fédés provinciales de volleyball (le produit est déjà bilinguisable), puis — grâce au SportDescriptor — première fédé d'un autre sport, où le même registre/ligues/conformité se revend avec un plugin de données sportif.

---

## 7. Effet réseau — le match entre deux équipes clientes

C'est ici que Playco cesse d'être un outil et devient un réseau :

- **Match lié** : quand les deux équipes d'un match de ligue sont sur Playco, le match existe une fois côté serveur, référencé par les deux. Une seule saisie fait foi (l'équipe receveuse ou le marqueur de table) ; l'autre banc reçoit le score en miroir. Fini les « 25-22 chez toi, 25-20 chez moi ».
- **Feuille co-signée** : les deux coachs valident sur l'iPad de la table à la fin du match → le résultat devient officiel instantanément, le classement bouge avant même que les sacs soient faits. Litige = la feuille reste « contestée », visible ligue.
- **Stats mutuelles automatiques** : mes actions offensives sont ses actions défensives. Aujourd'hui le coach saisit les stats adverses à la main (les 5 `TypeActionPoint` adversaire de v1.9) ; sur un match lié, **chaque équipe reçoit le box score officiel de l'autre** après co-signature. La saisie adverse manuelle devient un fallback.
- **Scouting éthique à trois niveaux**, décidé par la ligue, pas par les individus :
  1. *Public* (défaut) : scores, classements, feuilles officielles.
  2. *Réciprocité de ligue* : la ligue active le partage des box scores agrégés d'équipe pour TOUTES ses équipes — uniforme, donc équitable ; personne n'espionne, tout le monde prépare mieux ses matchs. C'est vendeur pour une ligue (« niveau de jeu augmenté »).
  3. *Jamais partagé* : stats individuelles nominatives des mineurs aux équipes adverses, tendances de rotation détaillées, scouting reports, contenus pédagogiques.
- **Le dossier suit l'athlète** : une athlète qui change de club retrouve son historique (stats carrière, tests physiques, objectifs) dans son nouveau vestiaire — la mutation §2.1 transporte le dossier avec consentement. Rétention produit maximale : quitter Playco, c'est perdre son historique sportif.
- Conséquence stratégique : la valeur d'une ligue sur Playco croît avec le carré des équipes connectées → dynamique **winner-take-most à l'échelle provinciale**. Raison de plus pour concentrer le GTM géographiquement (Québec d'abord, à fond) plutôt que de s'étaler.

---

## 8. Note d'architecture produit — SportDescriptor jusqu'en haut

La décision multi-sport (#4) doit traverser TOUTE la couche B2B, pas seulement le terrain : les **catégories d'âge**, le **format de feuille de match**, les **règles de classement** (points par victoire, bris d'égalité), les **types de tests physiques standardisés** et les **positions/actions statistiques** sont des données du SportDescriptor, pas du code. Si c'est fait dès la v1 de la couche fédé, signer Badminton Québec ou une fédé de basket régionale = livrer un fichier de configuration + un module terrain. C'est ce qui transforme un produit volleyball québécois en plateforme fédérative canadienne.

---

## Les 5 features fédération, classées par pouvoir de signature de contrat

1. **Registre central des membres — affiliations, catégories d'âge automatiques, mutations, surclassements, avec migration de l'existant clé en main.** C'est le système nerveux opérationnel de la fédé et une ligne budgétaire qu'elle paie déjà : on ne lui vend pas un coût nouveau, on remplace un fournisseur en faisant mieux. Sans ça, pas de contrat ; avec ça, tout le reste s'enclenche.
2. **Feuille de match électronique officielle co-signée + résultats et classements de ligue automatiques.** La douleur la plus visible et la plus récurrente (chaque week-end, chaque gymnase), et la démonstration parfaite de l'asymétrie Playco : la saisie terrain du coach DEVIENT le document officiel. Effet démo en réunion de CA : imbattable.
3. **Conformité clé en main — Loi 25, consentements parentaux granulaires, safe sport (suivi des vérifications, messagerie règle-de-deux), données hébergées au Canada.** C'est l'argument qui parle au président et à l'avocat du CA, ceux qui signent. Réduit un risque existentiel pour la fédé ; aucun concurrent grand public ne le couvre pour le sport amateur québécois.
4. **Statistiques provinciales agrégées, standards de développement et détection de talents (consentie).** Le différenciateur inimitable — impossible sans la donnée point-par-point que seul Playco collecte. Transforme la fédé de gestionnaire administratif en organisation pilotée par la donnée, et nourrit ses redditions de comptes gouvernementales.
5. **L'app coach tier Équipe incluse pour tous les clubs affiliés.** La fédé n'achète pas un logiciel de plus : elle achète un **avantage d'affiliation tangible** à offrir à ses membres — et chaque coach activé renforce les features 1 à 4. C'est la clause qui fait dire oui, et le moteur du flywheel.
