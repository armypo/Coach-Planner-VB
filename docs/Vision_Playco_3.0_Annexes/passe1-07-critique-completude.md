# Critique de complétude — Les angles morts collectifs des 5 visions

> Méthode : chaque angle de la liste de vérification a été confronté aux 5 visions ET au code réel du repo (lecture seule). Les faits code cités ont été vérifiés : `Localizable.xcstrings` (829 clés, source `fr`, **3 clés sur 829 traduites en anglais**), 639 `Text("…")` hardcodées dans `Playco/Views/` seulement, 43 `accessibilityLabel` dans toute l'app, `Equipe.saison` est une simple `String`, `dateNaissance` présent sur `Utilisateur`/`JoueurEquipe` sans aucun flux de consentement, historique athlète entièrement scopé par `codeEquipe`.

## Ce que les 5 visions couvrent déjà (vérifié, pour éviter les faux manques)

| Angle vérifié | Où c'est couvert | Reste-t-il un trou ? |
|---|---|---|
| Parents/tuteurs (tier fédé) | federation-b2b : rôle parent, consentements granulaires, règle de deux, iCal | **Oui — rien au tier Équipe** (voir n° 2) |
| Arbitres/marqueurs | federation-b2b §2.5 : registre, assignation manuelle, co-signature | **Oui — l'appareil partagé** (voir n° 7) |
| Blessures/retour au jeu | federation-b2b §4.4 : module v1, données sensibles | Partiel — voir n° 12 |
| Transition athlète inter-clubs | federation-b2b §7 : mutations transportent le dossier | **Oui — uniquement au tier fédé** (voir n° 5) |
| Beach (technique) | multisport-backend §2.6 : beach = sport n° 2 cobaye | **Oui — le produit beach, pas le descripteur** (voir n° 10) |
| Recrutement (embryonnaire) | innovation §2.1 (export clips), marché §4 (highlights Balltime) | **Oui — jamais érigé en feature** (voir n° 6) |

Tout le reste de la liste est **collectivement absent**. Classement par importance décroissante.

---

## NIVEAU 1 — Angles morts critiques (bloquants pour la stratégie annoncée)

### 1. Bilinguisme FR/EN — le chantier i18n n'existe dans aucune vision
**Le manque.** La vision marché planifie « Phase 4 : Canada anglophone » et la vision fédé affirme « le produit est déjà bilinguisable » — c'est factuellement faux. État réel du code : catalogue de chaînes à **0,4 % traduit** (3/829 clés EN), 639+ chaînes UI hardcodées en français rien que dans les Views, plus : bibliothèque d'exercices par défaut, tutoriel 12 pages, glossaire de 17 définitions stats, gabarits PDF (`PDFExportService`), en-têtes CSV, suggestions d'objectifs — tout est du français en dur. Personne n'a scopé : la localisation du `SportDescriptor` (noms d'actions, postes, métriques), les conventions de format (« 85,0 % » français vs « 85.0% »), le dashboard web bilingue, ni la terminologie volleyball EN (kill/dig/side-out ont des conventions établies qu'un mauvais glossaire ruinerait auprès des coachs ontariens).
**Pourquoi c'est grave.** (a) Volleyball Canada et tout organisme financé fédéralement sont assujettis aux langues officielles — un tier Fédération national unilingue est disqualifié d'office en approvisionnement. (b) Reporter l'i18n aggrave le coût chaque mois : chaque nouvelle vue ajoute des chaînes en dur. (c) La décision d'architecture (String Catalogs + clés dès maintenant vs migration big-bang plus tard) doit être prise **pendant** la refonte, pas après.
**Tier** : tous (Équipe dès l'expansion hors Québec ; Fédération = obligation légale). **Effort : L** (migration des chaînes + traduction + QA terminologique volleyball ; réductible à M si la refonte UI impose la règle « zéro chaîne hardcodée » dès le premier écran réécrit).

### 2. Consentement parental et mineurs au tier ÉQUIPE — l'exposition légale existe DÉJÀ
**Le manque.** La vision fédé traite les consentements comme une feature du backend B2B. Mais **l'app actuelle, tier Équipe, sans aucun backend**, collecte déjà des données de mineurs : date de naissance, photo, taille, poids, allonge, stats nominatives, messagerie — saisies par le coach **sans que le parent ait jamais été informé ni consulté**. La Loi 25 s'applique à Origotech dès aujourd'hui, pas à la signature du premier contrat fédé. Aucune vision ne propose : un avis/consentement minimal à la création d'un profil mineur, une politique de rétention au tier Équipe, ni le droit d'accès d'un parent aux données de son enfant quand il n'existe aucun compte parent.
**Pourquoi c'est grave.** C'est le seul angle mort qui est un **passif juridique actif au lancement App Store** (juin 2026). Une plainte d'un seul parent à la CAI suffit. Et la « règle de deux » safe sport (conversations privées adulte↔mineur) est décrite pour le tier fédé alors que la messagerie privée 1-à-1 existe **déjà** dans l'app entre coach et athlète mineur.
**Tier** : Équipe (immédiat), puis Club/Fédé. **Effort : S** pour le minimum viable (attestation coach « j'ai le consentement parental » horodatée + désactivation des DM adulte↔mineur par défaut + page de rétention) ; M pour le vrai flux parent.

### 3. SIWA strict exclut les moins de 13 ans — le mini-volley est structurellement hors produit
**Le manque.** L'Apple ID exige 13 ans au Canada (hors Partage familial). L'auth SIWA-strict — célébrée par les 5 visions — rend donc **impossible tout compte athlète U9-U12**. Or les clubs civils que le tier Club veut signer (vision fédé §1.3 : « le club à 12 équipes ») ont presque tous des programmes mini-volley, et Volleyball Québec en fait un axe de développement. Le pitch « une plateforme pour tout le club » est faux pour un tiers des équipes du club. Aucune vision ne mentionne l'âge plancher ni le modèle « profil géré par le parent » (le compte SIWA du parent possède N profils enfants — pattern standard des apps jeunesse).
**Pourquoi c'est grave.** Découvert en cours de vente club, c'est une objection tueuse ; découvert en architecture, c'est 3 semaines de travail. Ça touche aussi le modèle d'identité du backend (la table `personnes` de multisport-backend suppose `apple_sub` nullable — bien — mais personne n'a conçu la relation tuteur→profils).
**Tier** : Club/Fédé (et Équipe pour les écoles primaires). **Effort : M**.

### 4. Fin de saison, bascule et archivage — le cycle de vie annuel n'existe nulle part
**Le manque.** Le sport amateur vit par saisons ; l'app a `Equipe.saison: String` et `dateFinSaison`, et **aucune vision ne décrit ce qui se passe en mai**. Manquent : l'assistant de renouvellement (dupliquer l'équipe vers 2027-28, reporter le roster, promouvoir les catégories d'âge, réémettre les invitations), les archives consultables (saisons passées en lecture seule sans polluer les vues actives), la comparaison saison-sur-saison (le coach de cégep vit de ça), la politique de purge (les `PointMatch` s'accumulent indéfiniment dans le quota CloudKit de l'utilisateur), et la purge vidéo — d'autant plus urgente que la vision innovation ajoute 4-6 Go de vidéo locale par match sans autre réponse qu'une « purge assistée » évoquée en une ligne.
**Pourquoi c'est grave.** C'est la première fois que chaque client vivra le produit « en colère » : un rollover raté en septembre = churn massif synchronisé de toute la base au même moment. Et sans continuité de saison, la promesse « le coût de changement croît avec chaque saison de données » (vision marché, différenciateur n° 1) est vide.
**Tier** : tous. **Effort : M**.

### 5. La continuité de l'historique athlète au tier Équipe/Club — le dossier ne suit PAS
**Le manque.** La vision fédé promet « le dossier suit l'athlète » — via les mutations du **backend fédération**. Mais 100 % des utilisateurs des 2 premières années seront aux tiers Équipe/Club, où l'historique est scopé `codeEquipe` : l'athlète qui passe des Élans U16 aux Élans U17, ou du cégep au club civil, **repart à zéro** (JoueurEquipe, StatsMatch, TestPhysique, ObjectifJoueur — tout est par équipe). `Utilisateur.appleUserID` existe et pourrait fédérer les profils, mais aucune vision ne conçoit le « profil carrière » côté app : mes saisons, mes équipes, mon évolution multi-années.
**Pourquoi c'est grave.** C'est LA rétention athlète (la vision UX veut que « l'athlète la montre à son prochain coach » — impossible si son historique est resté dans l'équipe précédente), et c'est le prérequis du n° 6 (recrutement). Le concevoir après coup = migration de données douloureuse.
**Tier** : Équipe/Club. **Effort : M** (agrégation par `appleUserID` côté app ; converge naturellement avec la table `personnes` du backend).

---

## NIVEAU 2 — Angles morts importants (différenciateurs ou exigences de tier ratés)

### 6. Recrutement universitaire — le profil athlète exportable n'est une feature nulle part
**Le manque.** Trois visions frôlent le sujet (export de clips « recrutement », highlights Balltime, athlète qui « montre l'app à son prochain coach ») mais personne ne conçoit le livrable : un **CV sportif partageable** — stats multi-saisons, tests physiques (taille, allonge, saut — déjà dans le modèle !), vidéo, palmarès — exportable en PDF/lien web pour les recruteurs U SPORTS/NCAA/cégeps D1. Le pipeline sec5→cégep→université est LA préoccupation des athlètes de 15-19 ans et de leurs parents (qui paient). Bonus inexploité : les feuilles co-signées de la vision fédé rendraient ces stats **vérifiées** — un « profil certifié Playco » que Balltime ne peut pas offrir (ses stats IA ne sont validées par personne).
**Pourquoi c'est important.** C'est la boucle virale la plus puissante du segment (l'athlète *exige* Playco de son coach parce que son profil de recrutement en dépend) et un argument parents au tier Club. Dépend du n° 5.
**Tier** : Équipe (PDF simple) → Club/Fédé (profil vérifié). **Effort : M**.

### 7. L'appareil partagé — SIWA strict contre la réalité des iPads d'organisation
**Le manque.** Toutes les visions raisonnent « un humain = un appareil = un Apple ID ». La réalité terrain : l'iPad de la **table de marque** (e-scoresheet de la vision fédé — utilisé par un marqueur différent chaque semaine), l'iPad **propriété du cégep** partagé entre le coach et deux assistants, l'iPad du club prêté aux équipes. SIWA strict n'a aucune réponse : pas de multi-profils sur un appareil, pas de mode kiosque, pas de session marqueur éphémère. La vision fédé décrit la co-signature sur « l'iPad de la table » sans jamais se demander qui est *connecté* sur cet iPad.
**Pourquoi c'est important.** La feuille de match officielle (feature n° 2 du classement fédé) est inopérable sans ça ; et les établissements scolaires fournissent l'appareil bien plus souvent que les coachs bénévoles n'achètent un iPad perso.
**Tier** : Club/Fédé surtout. **Effort : M** (sessions par appareil + rôle « poste de marque » ; à concevoir avec l'auth, pas après).

### 8. Accessibilité — 3 lignes dans 5 visions, et des choix qui aggravent
**Le manque.** Hormis une mention WCAG du mode courtside (vision UX), rien. Pire, les visions **renforcent** des patterns inaccessibles sans le voir : la heatmap « efficacité divergente » rouge↔vert (v2.2, conservée) est illisible pour ~8 % des hommes daltoniens — soit statistiquement 1 à 2 personnes par équipe ; la sémantique nous=bleu/adversaire=rouge portée par la couleur seule est généralisée (« R1 · R1 », worm chart, mini-terrains) ; les tableaux de stats denses n'ont aucune stratégie Dynamic Type ; le terrain animé (vision innovation 5.1) n'a aucune piste VoiceOver ; et le dashboard web devra viser WCAG 2.1 AA — une exigence d'approvisionnement pour des organismes subventionnés, donc un critère d'appel d'offres du tier Fédé, pas du polish.
**Tier** : tous (web AA = argument de vente fédé). **Effort : M** (palettes daltonisme-sûres + motifs/formes en renfort de couleur ≈ S si fait pendant la refonte visuelle ; audit complet M).

### 9. DLTA/LTAD — parler la langue des fédérations canadiennes
**Le manque.** Le cadre « Développement à long terme de l'athlète » (Le sport c'est pour la vie / Sport Canada) structure les programmes, les subventions et les redditions de comptes de **toutes** les fédés canadiennes — Volleyball Canada a des stades DLTA officiels. La vision fédé propose des « standards de développement » et des percentiles provinciaux sans jamais s'arrimer à ce vocabulaire. Manquent : le tag de stade DLTA sur équipes/programmes, les ratios entraînement/compétition recommandés par stade (que le calendrier unifié pourrait mesurer automatiquement — donnée que personne d'autre n'a), et des rapports formatés dans les termes que la fédé recopie dans ses demandes de subvention.
**Pourquoi c'est important.** Vendre « des stats provinciales » au DG d'une fédé, c'est bien ; lui vendre « votre reddition de comptes DLTA générée en 3 clics », c'est signer. Coût marginal : c'est surtout du vocabulaire et des gabarits de rapport posés sur des données déjà prévues.
**Tier** : Fédé (et directeur technique de Club). **Effort : S/M** une fois le backend en place.

### 10. Beach volleyball — le descripteur est couvert, le PRODUIT beach ne l'est pas
**Le manque.** multisport-backend traite le beach comme cobaye technique du SportDescriptor — excellent. Mais personne ne traite le beach comme **marché** aux mécaniques propres : des **paires** (pas des équipes de 12 — l'invariant « 1 équipe = 1 sport » ne dit rien de « 1 athlète = N partenaires dans la saison »), des **tournois** à 4-6 matchs par jour (le modèle Seance-match et le flow « coacher ce soir » de la vision UX supposent 1 match par événement), une saison **d'été** (contre-cycle parfait : revenu et engagement pendant la morte-saison indoor, et réponse à l'objection « je paie 12 mois pour 4 »), un coach qui gère 8 paires simultanément sur 3 terrains. Volleyball Québec a un circuit beach structuré.
**Tier** : Équipe/Club. **Effort : M** (mode tournoi multi-matchs + entité paire), par-dessus le descripteur déjà planifié.

### 11. Android/web pour l'ATHLÈTE — la boucle virale suppose un iPhone que le vestiaire n'a pas
**Le manque.** La vision marché reporte Android « post-traction » pour le **coach** (défendable : la douve est l'iPad). Mais les visions UX et marché fondent l'acquisition sur la boucle athlète→parents→coachs, et une fraction importante des ados québécois est sur Android. Résultat non traité : dans un vestiaire type, une partie de l'équipe ne peut ni voir ses stats, ni recevoir « ton box score est prêt », ni utiliser la messagerie — qui ne peut donc jamais devenir le canal officiel de l'équipe (retour à Messenger, où vit déjà le concurrent n° 1 : la non-consommation). La parade existe dans les plans sans y être connectée : le « WebReports » à copier de SoloStats + le dashboard web = un **profil athlète web mobile en lecture** (stats, calendrier, box scores) à coût marginal une fois le backend construit.
**Tier** : Équipe/Club. **Effort : M** (après backend ; S pour la seule page box-score partageable par lien).

---

## NIVEAU 3 — Angles morts réels mais circonscrits

### 12. Statut de disponibilité joueur (blessé/malade/suspendu) au tier Équipe — **Effort : S**
Le module blessures de la vision fédé est un workflow de conformité. Le besoin quotidien du coach est plus bête : marquer #12 « blessée — retour prévu le 20 », la voir grisée dans `CompositionMatchView` et les présences, et suspendre ses assignations muscu (le lien blessure↔`ProgrammeMuscu` n'est fait nulle part alors que l'app a déjà toute la couche préparation physique). Tier Équipe. Deux champs et trois filtres — mais absent des 5 visions.

### 13. Suivi disciplinaire de ligue (cartons → suspensions) — **Effort : S/M**
La e-scoresheet capte « sanctions/cartons » (vision fédé) mais personne ne ferme la boucle : cumul par joueur/coach, suspension automatique après N cartons, vérification « a-t-il purgé son match ? » à la composition (même mécanique que le blocage d'affiliation déjà prévu). C'est un travail hebdomadaire réel des ligues, et une extension triviale du moteur d'éligibilité déjà spécifié. Tier Fédé.

### 14. Admissibilité académique et reddition scolaire (RSEQ/cégep) — **Effort : S**
La vision innovation évoque des « rapports direction » générés par IA, mais le besoin structurel n'est modélisé nulle part : statut d'admissibilité académique RSEQ sur la fiche joueur (l'athlète inadmissible = même mécanique « grisé à la composition » que l'affiliation), export de présences par période pour la direction des sports, années d'éligibilité restantes. Le segment cégep est pourtant désigné tête de pont par 2 visions. Tier Équipe/Club.

### 15. Parasport / volleyball assis — **Effort : S (descripteur) à M (programme)**
Zéro mention dans ~30 000 mots de vision. Volleyball Canada opère des programmes nationaux de volleyball assis ; les fédés ont des obligations d'inclusion attachées à leur financement public, et les appels d'offres comportent de plus en plus un critère parasport. Ironie : le volleyball assis (terrain 10×6, filet bas, mêmes familles d'actions) est un **second cobaye parfait du SportDescriptor** après le beach — presque gratuit techniquement, et une ligne dans le pitch fédé que ni Spordle ni personne n'a. Tier Fédé.

### 16. Propriété et succession de l'équipe — **Effort : M**
Le coach-créateur (`.admin`, son Apple ID) EST l'équipe. Coach qui démissionne en janvier, brûle son Apple ID, ou décède : aucune vision ne prévoit le transfert de propriété, ni un export/sauvegarde complet hors-CloudKit (l'« anti-lock-in rassurant » promis par la vision marché n'existe pas au tier Équipe). Au tier Club c'est un argument contractuel : le club veut posséder les données de SES équipes, pas les louer à l'Apple ID d'un bénévole. À concevoir avec le modèle d'identité du backend.

### 17. Infrastructure de notifications — la dette invisible des 5 visions — **Effort : S/M**
Les visions distribuent des push partout (« ton box score est prêt », rappels de certification 90/30/7 jours, RSVP, broadcast Live Activities) sans jamais noter qu'il n'existe **aucune** infrastructure d'envoi aujourd'hui (pas de serveur, messagerie CloudKit sans APNs applicatif). Chaque promesse de notification est donc silencieusement dépendante du backend §6 de la vision innovation — dépendance jamais tracée. À inscrire explicitement dans le séquencement : quelles notifications vivent sur CKSubscription (possible dès maintenant) vs lesquelles attendent le worker.

---

## Synthèse priorisée

| # | Angle mort | Tier | Effort | Quand |
|---|---|---|---|---|
| 1 | i18n / bilinguisme FR-EN (architecture) | Tous | **L** | Règle « zéro chaîne en dur » dès le 1er écran de la refonte |
| 2 | Consentement mineurs au tier Équipe | Équipe | **S→M** | Avant/au lancement App Store (passif actif) |
| 3 | Comptes <13 ans (profils gérés par parent) | Club/Fédé | **M** | Avec la conception auth/identité |
| 4 | Cycle de saison : rollover, archives, purge | Tous | **M** | Avant la première fin de saison de la base |
| 5 | Profil carrière athlète inter-équipes/saisons | Équipe/Club | **M** | Fondation à poser dans le modèle d'identité |
| 6 | Profil de recrutement exportable/vérifié | Équipe→Fédé | **M** | Phase 2 (boucle virale athlète) |
| 7 | Appareil partagé / mode table de marque | Club/Fédé | **M** | Avec la e-scoresheet |
| 8 | Accessibilité (daltonisme, Dynamic Type, web AA) | Tous | **M** | Pendant la refonte visuelle (S si intégré) |
| 9 | DLTA/LTAD dans les rapports fédé | Fédé | **S/M** | Avec le pitch Volleyball Québec |
| 10 | Beach comme produit (paires, tournois, été) | Équipe/Club | **M** | Après le descripteur beach |
| 11 | Accès athlète Android/web (lecture) | Équipe/Club | **M** | Dès le backend v1 |
| 12 | Statut disponibilité joueur (blessé) | Équipe | **S** | Quick win refonte |
| 13 | Discipline de ligue (cartons/suspensions) | Fédé | **S/M** | Avec l'éligibilité |
| 14 | Admissibilité académique / reddition cégep | Équipe/Club | **S** | Avec la tête de pont cégep |
| 15 | Parasport / volleyball assis | Fédé | **S→M** | Argument d'appel d'offres fédé |
| 16 | Propriété/succession d'équipe, export complet | Tous | **M** | Avec le modèle d'identité backend |
| 17 | Cartographie des dépendances notifications | Tous | **S/M** | Au séquencement de la roadmap |

**Le motif commun** : les 5 visions sont excellentes sur *les moments d'usage* (UX), *l'organisation* (B2B), *la technique* (innovation, architecture) et *le marché* — mais elles partagent trois angles morts systémiques : (a) **le temps long** (saisons, carrières, successions — tout ce qui se passe entre deux matchs et entre deux années), (b) **les humains sans iPad ni Apple ID** (mineurs de <13 ans, ados sur Android, marqueurs sur appareil partagé, parents au tier Équipe), et (c) **les obligations non fonctionnelles qui font signer ou disqualifient** (bilinguisme légal, accessibilité d'approvisionnement, conformité mineurs déjà exigible). Aucun de ces manques n'invalide les visions ; plusieurs (2, 3, 5, 7, 16) doivent cependant être tranchés **dans la conception de l'identité et de l'auth**, c'est-à-dire au tout début de la refonte, sous peine de re-migration.
