# Playco — Lentille Marché & Concurrence (juillet 2026)

> Livrable d'analyse concurrentielle pour la refonte Playco. Périmètre : outils de stats volleyball, gestion d'équipe généraliste, plateformes club/fédération. Marché initial : Québec / Canada francophone, puis anglophone. État des concurrents vérifié en ligne (juillet 2026).

---

## 0. Résumé exécutif

Le marché se divise en **trois couches qui ne se parlent pas** :

1. **Stats volleyball** (VBStats, SoloStats, iStatVball, DataVolley, Balltime/Hudl) — profonds mais mono-rôle (le coach-statisticien), anglophones, et soit chers (Hudl 2 000 $/équipe/an), soit vieillissants (VBStats, DataVolley Windows).
2. **Gestion d'équipe généraliste** (TeamSnap, Spond, Heja, SportEasy) — excellents en logistique (horaire, présences, messages), nuls en volleyball (aucune notion de rotation, sideout, box score FIVB).
3. **Plateformes fédération/club** (Spordle, Sportlomo, LeagueApps, PlayyOn) — registre, inscriptions, paiements ; **zéro couche performance/coaching**.

**Personne ne fait la verticale complète** coach → équipe → club → fédération dans un seul produit. Personne n'est Apple-native premium. Personne n'est offline-first crédible en gymnase. Personne n'est en français québécois. C'est exactement le carré vide où Playco se place — à condition de **ne pas attaquer frontalement Spordle sur le registre** (verrouillé au Québec : Hockey Canada, Hockey Québec, et désormais les inscriptions de tournois Volleyball Québec) et de **ne pas courir après l'IA vidéo** de Hudl/Balltime.

Le concurrent n° 1 reste toutefois la **non-consommation** : feuille de stats papier + Google Sheets + groupe Messenger. Le pricing et l'onboarding doivent battre « gratuit et déjà connu », pas seulement battre SoloStats.

---

## 1. Cartographie concurrentielle

### 1.1 Stats & analyse volleyball (concurrence directe)

| Produit | Forces | Faiblesses | Prix (vérifié 2026) | Plateformes |
|---|---|---|---|---|
| **VBStats (Perana Sports)** | Référence historique iPad ; recommandé clubs élite/NCAA/FIVB ; sync vidéo ; **multi-iPad connectés pour le staff** | UI datée, courbe d'apprentissage, anglais seulement, aucun volet gestion d'équipe, développement au ralenti | Achat unique App Store premium (historiquement ~70 $ US) | iPad |
| **SoloStats / SoloStats Live (Rotate123)** | Freemium efficace ; famille d'apps (123, Live, Video, Rotate123, WebReports) ; rapports web partageables ; SEO agressif (leurs comparatifs « best stat apps » se classent eux-mêmes) | Fragmenté en 4-5 apps ; anglais seulement ; design utilitaire ; rien pour pratiques/muscu/scouting | Gratuit + Starter 7,99 $/mois, Intermediate 10,99 $, Advanced 16,99 $ (-17 % annuel) | iPhone/iPad, Android, web |
| **iStatVball 3** | Stats profondes « de calibre collégial » à petit prix ; **paiement par saison, pas d'abonnement auto-renouvelable** — modèle aimé des coachs scolaires | Solo-dev, UI austère, anglais, aucun écosystème d'équipe | Gratuit 14 jours, puis achat par saison/équipe | iPad (+ Android) |
| **Rotate123** | Meilleur outil rotations/alignements ; détection de chevauchements ; export diagrammes imprimables ; web sans installation | Outil de niche absorbé dans l'offre SoloStats ; ne fait que ça | Inclus dans les tiers SoloStats | Web |
| **Balltime (→ Hudl, acquis fév. 2025)** | IA vidéo : breakdown automatique, highlights, stats sans saisie ; partenariat LOVB ; freemium viral côté athlètes/parents | Dépend de la captation vidéo + upload (réseau) ; post-match, pas live ; anglais ; désormais dans l'orbite Hudl (prix susceptibles de monter) | Freemium ; plan Team ~25 $/mois (299 $/an) | iOS, web |
| **Hudl / Volleymetrics** | Standard de facto NCAA/pro ; analystes humains + IA (Assist) ; vente par programme/école ; package « Premier » lancé en 2026 | **2 000 $/équipe/an** (1 250 $ multi-équipes) ; sur-dimensionné et hors budget pour cégeps/clubs civils ; dépendant du réseau | Club Plus : 2 000 $/équipe/an ; Volleymetrics : contrats collégiaux/pro | Web, iOS, Android |
| **DataVolley 4 (Genius/Data Project)** | Standard mondial pro (format .dvw), scouting exhaustif, vidéo intégrée | **Windows seulement**, courbe d'apprentissage brutale (codage clavier), UX années 2000, hors de portée d'un coach scolaire | Licence annuelle à partir de ~299 €/$ (versions supérieures beaucoup plus) | Windows/PC |

**Lecture** : entre le « trop simple » (SoloStats Starter) et le « trop cher/lourd » (Hudl, DataVolley), la zone 100-400 $/an pour un club exigeant mais non-professionnel est mal servie — surtout hors des États-Unis.

### 1.2 Gestion d'équipe généraliste

| Produit | Forces | Faiblesses | Prix | Plateformes |
|---|---|---|---|---|
| **TeamSnap** | Leader nord-américain ; horaire, disponibilités/RSVP, paiements, offre club/ligue | Pubs sur le tier gratuit (ressentiment documenté), stats quasi abandonnées, aucun contenu volleyball, français partiel | ~5,84 à 10,84 $ US/mois selon tier (Basic/Premium/Ultra) + offres club sur devis | iOS, Android, web |
| **SportEasy** | Français natif (France), bonnes stats génériques, multi-sport | Stats « soccer-first » inadaptées au volleyball ; peu implanté au Québec | Gratuit limité ; Premium ~9,99 €/mois/équipe | iOS, Android, web |
| **Spond** | **100 % gratuit** (se finance sur les frais de paiement) ; RSVP par courriel sans app ; croissance forte | Zéro stats, zéro terrain, zéro volleyball ; produit logistique pur | Gratuit | iOS, Android, web |
| **Heja** | UX la mieux notée (4,8/5, 30k+ avis) ; communication parents exemplaire | Jeunesse/parents surtout ; Pro requis pour desktop/stats ; rien de tactique | Gratuit + Pro ~8,33 $/mois | iOS, Android |

**Lecture** : ces produits définissent le **plancher d'attente logistique** (calendrier, présences, messagerie — que Playco a déjà). Ils prouvent aussi qu'on ne peut pas monétiser la logistique seule : Spond l'a rendue gratuite pour tout le monde.

### 1.3 Plateformes club / fédération (couche B2B visée par le tier Club/Fédération)

| Produit | Forces | Faiblesses | Prix | Plateformes |
|---|---|---|---|---|
| **Spordle** ⚠️ | **Québécois** ; partenariats Hockey Canada (pluriannuel), Hockey Québec, Soccer/Baseball Québec ; **Volleyball Québec fait migrer ses inscriptions de tournois 2025-2026 sur Spordle** ; app mobile lancée 2025 | Registre/inscriptions/horaires/classements — **aucune couche coaching/performance** (pas de terrain, pas de stats fines, pas de développement athlète) | Contrats fédération sur devis | Web + app mobile |
| **Sportlomo** | Portail d'inscription de **Volleyball Canada** ; multilingue, conforme RGPD ; conçu pour instances dirigeantes | Aucun outil terrain ; UX administrative ; pas de produit coach | Contrats sur devis | Web |
| **LeagueApps** | Référence youth sports US : inscriptions, paiements, horaires, installations | US-centré, anglais, coûts en milliers/saison, zéro performance | Custom (milliers $/saison) | Web, apps |
| **PlayyOn** | Gratuit tout-en-un pour la récréation communautaire | Généraliste léger, pas de profondeur sport, pas d'ancrage québécois | Freemium | Web |

**Lecture stratégique majeure** : au Québec, la couche « registre/inscriptions/sanctions » est en cours de **verrouillage par Spordle** (et Sportlomo au national). La refonte Playco ne doit **pas** vendre du registre aux fédérations — elle doit vendre la **couche performance et développement de l'athlète** que ni Spordle ni Sportlomo n'ont, avec des exports/intégrations vers ces registres.

---

## 2. Les trous du marché — validation des hypothèses

| Hypothèse | Verdict | Preuve |
|---|---|---|
| **Intégration verticale coach→fédé dans un même produit** | ✅ **Confirmé — personne ne le fait.** | Hudl s'arrête au programme sportif ; Spordle/Sportlomo s'arrêtent au registre ; SoloStats s'arrête au coach. Aucun produit ne relie plan de pratique → stats de match → développement athlète → vue club → rapport fédération. |
| **Expérience Apple-native premium** | ✅ Confirmé. | VBStats est iPad-native mais figé esthétiquement ; tout le reste est web/hybride. Personne n'exploite PencilKit, Liquid Glass, le split-screen iPad, l'Apple Pencil, SharePlay/AirPlay. Playco est déjà des années devant sur ce plan. |
| **Français de qualité** | ✅ Confirmé (avec nuance). | Aucun outil de stats volleyball n'existe en français. SportEasy et Spordle sont francophones mais sans volet coaching volleyball. Nuance : le français est un **avantage d'entrée**, pas une douve durable — la douve, c'est français **+ profondeur volleyball + ancrage RSEQ/cégep** ensemble. |
| **Prix honnête vs DataVolley/Hudl à 1 000 $+** | ✅ Confirmé, à cadrer. | Le vrai gouffre : SoloStats Advanced ~200 $ US/an ↔ Hudl 2 000 $/équipe/an. Une offre 150-500 $ CAD/équipe/an qui couvre stats + pratiques + muscu + scouting est sans équivalent. Attention : le plancher de référence du coach scolaire québécois est « gratuit » (papier/Sheets), pas 200 $. |
| **Offline réel en gymnase** | ✅ Confirmé — et c'est structurel. | Balltime/Hudl **exigent** upload vidéo ; SoloStats/Rotate123 dépendent du web pour les rapports ; DataVolley est desktop. Le local-first SwiftData+CloudKit avec pause de sync en match est un différenciateur que les concurrents cloud ne peuvent pas copier sans réarchitecture. |
| Trou supplémentaire identifié : **le multi-rôle** | ✅ | Tous les outils de stats sont pensés pour UN utilisateur (le statisticien). Playco est déjà multi-rôles (coach/assistant avec permissions granulaires/athlète avec son profil, ses objectifs, sa muscu). L'athlète comme utilisateur de première classe (à la Balltime, qui l'a compris côté highlights) est rare dans la saisie de stats. |
| Trou supplémentaire : **pratiques + match + physique au même endroit** | ✅ | Personne ne combine éditeur d'exercices dessinable, stats de match, scouting ET préparation physique. Le coach jongle aujourd'hui avec 4 outils + papier. |

---

## 3. Positionnement Playco

### Phrase de positionnement

> **« Playco est le poste de pilotage complet du coach de volleyball — pratiques, matchs, stats de calibre pro, développement des athlètes — conçu pour iPad, qui fonctionne sans wifi dans n'importe quel gymnase, en français, au prix d'une paire de souliers plutôt que d'un contrat Hudl. »**

Variante courte (App Store / pitch fédé) : *« Du plan de pratique au rapport de fédération : tout le volleyball de votre organisation dans une seule app. »*

### Trois différenciateurs défendables

1. **La verticale complète dans un produit unique** — pratique + match live + scouting + muscu + objectifs athlète + vue club/fédération. Défendable parce que la profondeur accumulée (30 modèles, stats FIVB/NCAA, rotations nous/adversaire, heatmaps, worm chart) représente des années-personne que ni un généraliste (TeamSnap) ni un outil de niche (Rotate123) ne rattrapent vite ; et le coût de changement croît avec chaque saison de données accumulées.
2. **Offline-first Apple-native** — architecture local-first (SwiftData+CloudKit, pause sync en match, mode courtside) vs concurrents cloud-first. C'est une douve *architecturale* : Hudl/Balltime ne peuvent pas offrir ça sans réécrire leur produit, car leur valeur (IA vidéo, analystes) vit sur le serveur.
3. **Ancrage francophone Québec/Canada** — terminologie volleyball québécoise juste, calendrier aligné RSEQ/cégeps/clubs civils, conformité canadienne (Loi 25) — combiné au circuit court d'un fondateur-coach local qui peut signer les 50 programmes collégiaux un par un. Les Américains n'iront pas se battre pour 11 800 joueurs RSEQ ; c'est précisément pour ça que c'est une tête de pont sûre.

### Contre-attaques probables et parades

| Contre-attaque | Probabilité | Parade |
|---|---|---|
| **Hudl bundle Balltime à bas prix** vers écoles/clubs (l'IA vidéo « gratuite » rend la saisie manuelle ringarde) | Haute (déjà en cours : Assist volleyball AI, package Premier 2026) | Rester le **live courtside** (l'IA vidéo est post-match), l'offline, le prix, la langue. Offrir l'export vidéo-compatible plutôt que de rivaliser. |
| **Spordle ajoute un module « performance »** et le vend aux fédés qu'il détient déjà | Moyenne | Devenir **complémentaire avant qu'ils y pensent** : export/import vers Spordle, positionnement « Spordle gère l'inscription, Playco gère la performance ». Un partenariat vaut mieux qu'une guerre contre celui qui détient Hockey Canada. |
| **SoloStats localise en français** | Faible (marché QC trop petit pour eux) | La localisation ne suffit pas : il faudrait aussi le calendrier RSEQ, la vente terrain, la verticale. Accélérer la signature des programmes phares avant. |
| **TeamSnap/Spond ajoutent des stats volleyball** | Très faible (ils ont historiquement désinvesti les stats) | Aucune action ; surveiller. |

---

## 4. Ce que la refonte DOIT copier — et refuser

### À copier (référence précise)

| Feature | De qui | Pourquoi |
|---|---|---|
| **Rapports web partageables par lien** (WebReports) | SoloStats | La killer feature de rétention : le coach envoie un lien aux parents/athlètes/DA après le match. Le futur dashboard web de Playco doit d'abord être ÇA (lecture publique, zéro login) avant d'être un back-office. |
| **Multi-iPad connectés en match** (staff qui voit les stats en direct) | VBStats | Playco a déjà le split-screen ; l'étape suivante est le multi-appareil local (MultipeerConnectivity — cohérent avec offline-first, aucun serveur requis). |
| **Paiement par saison, sans abonnement perpétuel** | iStatVball 3 | Les coachs scolaires détestent payer 12 mois pour une saison de 4. Offrir une option « Saison » à côté du mensuel/annuel StoreKit désamorce l'objection n° 1. |
| **Vérification de chevauchements / légalité de l'alignement + export imprimable des 6 rotations** | Rotate123 | Petit, très aimé, viral (feuille affichée dans le gym avec le logo). Playco a les formations ; il manque le contrôle de légalité et l'export une-page. |
| **Highlights/clips pour l'athlète** (boucle virale parents-recrutement) | Balltime | Pas d'IA jour 1 : commencer par le marquage manuel de moments + export de clips liés aux stats (le lien stat↔vidéo de SoloStats Video, en plus simple). C'est ce qui fait que l'ATHLÈTE réclame l'outil à son coach. |
| **Interopérabilité par formats standards** (.dvw comme lingua franca pro) | DataVolley | Exporter (au minimum CSV structuré, idéalement compatible DVW) = argument de vente aux programmes qui touchent le niveau universitaire/pro, et anti-lock-in rassurant pour les fédés. |
| **Logistique de base gratuite pour toujours** | Spond | Ne jamais paywaller calendrier/présences/messagerie : c'est l'hameçon d'acquisition. Monétiser l'analyse et la couche club. |
| **Vente « par programme », pas par coach** | Hudl | Le contrat s'adresse au responsable des sports du cégep/club (budget établissement), pas à la carte de crédit du coach. Le pricing Club de Playco doit avoir une facture PDF et un prix « par programme/an ». |
| **RSVP sans app / par courriel** | Spond | Les parents n'installeront pas Playco. Toute convocation doit être consultable/répondable par lien web. |

### À refuser

| Tentation | Pourquoi refuser |
|---|---|
| **Construire l'IA vidéo maison** | Course à l'armement perdue d'avance contre Hudl/Balltime (des dizaines de M$ investis). Intégrer/exporter à la place ; revisiter dans 3 ans si les modèles deviennent commodité on-device (Apple Neural Engine). |
| **Devenir le système d'inscriptions/paiements des fédés** | Spordle/Sportlomo verrouillés au QC/Canada ; fintech + conformité + assurance = gouffre pour un solo dev. S'intégrer au-dessus, ne pas remplacer. |
| **Réseau social sportif** (fil, likes, stories à la Heja) | Distraction ; modération = risque juridique mineurs ; zéro lien avec la proposition de valeur coach. La messagerie d'équipe actuelle suffit. |
| **Tier gratuit financé par la pub** | Le ressentiment anti-pubs de TeamSnap est documenté partout ; incompatible avec un positionnement premium et avec des données de mineurs. |
| **Prix par athlète** | Friction administrative maximale (rosters qui bougent) ; prix par équipe/programme uniquement. |
| **App Android native jour 1** | Le dashboard web de la refonte couvre les non-Apple (DA, parents, fédé) ; l'expérience terrain reste la douve iPad. Android = décision post-traction, données en main. |
| **Sur-généraliser trop tôt le multi-sport** | Le SportDescriptor doit exister dans l'architecture (décision 4), mais AUCUN 2e sport ne doit être livré avant que le volleyball ait gagné son marché — sinon Playco devient un SportEasy de plus. |

---

## 5. Multi-sport — 2e et 3e vagues

Critère = (taille × structuration du marché QC/Canada) × (proximité du modèle volleyball : indoor, jeu séquencé, stats par action, rotations/alignements, culture de club-école).

| Sport | Marché QC/Canada | Proximité modèle volleyball | Concurrence outils | Verdict |
|---|---|---|---|---|
| **Basketball** | ⭐⭐⭐⭐ 20 000+ pratiquants RSEQ (presque 2× le volleyball), forte croissance, cégeps/écoles équipés | ⭐⭐⭐⭐ Gymnase, banc, box score par possession, mêmes acheteurs (mêmes DA de cégep !), terrain dessinable identique | Moyenne-forte (Hudl, apps US) mais **rien en français** | **2e vague — n° 1.** Le même responsable des sports achète les deux : vente croisée immédiate dans les établissements déjà signés. |
| **Flag football** | ⭐⭐⭐ En explosion : olympique LA 2028, RSEQ féminin depuis 2021 (8 équipes varsity), pilote U Sports 2027-28, le Québec domine l'équipe nationale, championnat national 2026 à Montréal | ⭐⭐⭐⭐ Jeu **arrêté et séquencé** (par down = par rallye), playbook dessinable = usage PencilKit parfait, alignements | **Quasi nulle en français, faible partout** | **3e vague — le pari asymétrique.** Fenêtre olympique 2026-2028, aucun outil établi, croissance financée par la NFL/fédés. |
| **Handball** | ⭐ Marché québécois minuscule | ⭐⭐⭐⭐⭐ Le portage technique le plus facile (gymnase, 7 joueurs, actions discrètes) | Faible | Port « gratuit » pour valider le SportDescriptor à l'interne, mais pas un marché. À faire seulement si l'Europe francophone devient une cible. |
| **Badminton** | ⭐⭐⭐ Très pratiqué au scolaire québécois | ⭐⭐ Sport individuel/duo : pas de rotations, pas de box score d'équipe, pas de playbook — le descriptor couvrirait mal | Faible | Non prioritaire. Éventuellement un mode « léger » (calendrier + résultats) pour les écoles multi-sports, sans stats riches. |
| **Hockey cosom / dek** | ⭐⭐⭐⭐ Énorme (75 000-100 000 joueurs estimés au QC) | ⭐⭐ Jeu continu (pas séquencé), MAIS surtout : récréatif adulte, **presque pas de coachs** — l'acheteur de Playco n'existe pas ; le besoin est côté ligues (horaires/classements = Spordle/PlayyOn) | Faible côté coaching, forte côté ligues | Faux ami : gros marché, mauvais produit-marché. Refuser. |
| **Soccer** | ⭐⭐⭐⭐⭐ 170 000+ affiliés Soccer Québec, 300 clubs | ⭐ Extérieur, jeu continu, stats vidéo-dépendantes | **Écrasante** (Veo, Hudl, SportEasy, TeamSnap — le sport le plus servi au monde) | Refuser en 2e/3e vague. Océan rouge où Playco n'a aucun angle. |

**Recommandation** : 2e vague = **basketball** (même acheteur, même gymnase, marché RSEQ 2× plus gros) ; 3e vague = **flag football** (timing olympique, vide concurrentiel francophone, mécanique de jeu séquencée idéale). Handball comme test technique interne du SportDescriptor. Badminton/dek/soccer : non.

---

## 6. Risques marché — top 3

1. **Hudl/Balltime descend en prix avec l'IA vidéo (probabilité haute, impact haut).** L'acquisition de Balltime (fév. 2025) + le package « Premier » 2026 montrent la trajectoire : l'IA qui produit stats et highlights *sans saisie* pourrait convaincre les clubs que « stater » à la main est obsolète. **Mitigation** : Playco gagne là où la vidéo perd — le live (décisions pendant le match, pas après), l'offline, le prix, la langue ; et interopère avec la vidéo au lieu de la combattre. Surveiller trimestriellement le prix d'entrée Balltime (299 $/an aujourd'hui).
2. **Spordle verrouille la relation fédération au Québec (probabilité moyenne, impact haut).** Spordle détient Hockey Canada, Hockey Québec, Soccer/Baseball Québec — et Volleyball Québec y migre ses inscriptions de tournois 2025-2026. Si Spordle lance un module « développement/performance », il le vendra aux fédés par-dessus la relation existante. **Mitigation** : vitesse (signer la couche coaching avant qu'elle existe chez eux), positionnement explicitement complémentaire (exports vers Spordle), et relation directe avec Volleyball Québec dès maintenant.
3. **La non-consommation et le « assez bon gratuit » (probabilité certaine, impact moyen mais permanent).** Papier + Google Sheets + Spond gratuit couvrent 80 % du besoin perçu d'un coach scolaire bénévole ; TeamSnap/Spond occupent la logistique. **Mitigation** : un tier gratuit réellement utile (logistique + stats de base), un onboarding < 10 minutes, et la démonstration terrain (un coach qui voit le sideout % par rotation en temps réel ne revient pas au papier). *Risque écarté : Apple Sports — l'app est un agrégateur de scores de ligues professionnelles (Mondial 2026, NBA, etc.), aucune ambition sport amateur/outils coach.*

---

## 7. Matrice de positionnement

**Axe X : profondeur volleyball** (générique → spécialisé pro) · **Axe Y : largeur organisationnelle** (équipe seule → club → fédération)

```
  Largeur organisationnelle
  (fédération) ▲
              │  Spordle ● Sportlomo ●            ┌──────────────────┐
              │  LeagueApps ●                     │   ★ PLAYCO v3    │
              │  (registre sans                   │  (verticale      │
              │   performance)                    │   coach→fédé     │
              │                                   │   volleyball)    │
   (club)     │  TeamSnap Club ●                  │                  │
              │                    Hudl/          └──────────────────┘
              │                    Volleymetrics ●
              │                    (programme, 2000$/an)
   (équipe)   │  Spond ● Heja ●        SoloStats ●     Playco v2.2 ★
              │  SportEasy ●           Balltime ●      VBStats ●
              │  (logistique           iStatVball ●    DataVolley ●
              │   sans sport)          Rotate123 ●     (profonds,
              │                                         mono-rôle)
              └──────────────────────────────────────────────────► X
                 générique          volleyball-aware      volleyball pro
```

Le quadrant supérieur droit — **profondeur volleyball pro × largeur club/fédération** — est vide. Hudl s'en approche par le haut (prix prohibitif, pas de couche fédé amateur, pas de logistique) ; Spordle par la gauche (largeur sans profondeur sport). C'est la cible de la refonte.

---

## 8. Séquence de conquête recommandée

**Phase 1 (0-6 mois) — Les 20 ambassadeurs cégep/club.**
Signer 15-20 coachs de volleyball collégial RSEQ (D1/D2) et de clubs civils Volleyball Québec. *Feature d'accroche* : **stats live courtside offline + sideout % par rotation en français** — la démo qui tue en 5 minutes de gymnase, ce que ni papier ni SoloStats (anglais, fragmenté) n'offrent. Prix d'attaque : tier Équipe par saison (à la iStatVball). Objectif : preuve sociale nominale (« utilisé par les Élans de Garneau… ») et rétention d'une saison complète.

**Phase 2 (6-18 mois) — Le club civil comme unité économique.**
Vendre le tier Club aux clubs civils multi-équipes (5-20 équipes). *Features d'accroche* : multi-équipes + permissions staff (déjà là), **dashboard web club** (lecture pour DA/parents — le WebReports de SoloStats en mieux), scouting partagé entre équipes du club, facturation par programme (à la Hudl, à 1/5 du prix). C'est ici que le backend propre de la refonte se justifie dollar par dollar.

**Phase 3 (18-30 mois) — La fédération comme canal, pas comme client de dev custom.**
Approcher Volleyball Québec (puis les instances régionales RSEQ) avec la couche que Spordle n'a pas : **registre de développement de l'athlète** (historique stats/tests physiques multi-saisons qui suit le joueur d'un club à l'autre), exports standardisés de tournois, tarif fédération qui subventionne l'adoption des petits clubs. Livrer l'export/l'interop vers Spordle/Sportlomo plutôt que de les concurrencer. La fédé ne rapporte pas beaucoup d'argent directement — elle **distribue** Playco à tous ses clubs.

**Phase 4 (30 mois+) — Anglais + 2e sport.**
Canada anglophone volleyball (Volleyball Canada/OVA — arriver avec les études de cas québécoises), puis **basketball** vendu aux établissements déjà clients (même DA, même gymnase, même facture). Le flag football se prépare en parallèle pour surfer la vague LA 2028.

**Règle de séquence** : chaque phase ne démarre que si la précédente a sa preuve (rétention saison complète en P1, 3 clubs payants en P2, 1 lettre d'intention fédé en P3). Le pire scénario serait de construire la couche fédération avant d'avoir 100 coachs qui ouvrent l'app chaque semaine.

---

## Sources

- [VBStats — App Store](https://apps.apple.com/us/app/vbstats/id575141935) · [Perana Sports](http://peranasports.com/software/vbstatshd/)
- [SoloStats — Pricing](https://www.solostatslive.com/pricing) · [Famille de produits](https://www.solostatslive.com/products) · [Comparatif « Best Volleyball Stat Apps 2026 »](https://www.solostatslive.com/best-volleyball-stat-apps.html)
- [iStatVball 3 — App Store](https://apps.apple.com/us/app/istatvball-3/id1524359895) · [istatvball.com](https://istatvball.com/)
- [Rotate123](https://www.rotate123.com/) · [Rotations app](https://www.rotate123.com/volleyball-rotations-app.html)
- [Balltime AI — App Store](https://apps.apple.com/us/app/balltime-ai/id6450258692) · [Balltime × LOVB](https://www.balltime.com/blog/lovb-partnership) · [Hudl × Balltime](https://www.hudl.com/hudl-balltime) · [Hudl — Club Team Pricing (Balltime)](https://www.hudl.com/en_gb/pricing/balltime)
- [Hudl — Club Volleyball Pricing](https://www.hudl.com/pricing/club/volleyball) · [Volleymetrics](https://www.hudl.com/products/volleymetrics) · [Hudl Assist volleyball AI](https://www.hudl.com/products/assist/volleyball/ai)
- [Data Volley 4 — Data Project](https://www.dataproject.com/Products/US/en/Volleyball/DataVolley4) · [datavolley.eu](https://www.datavolley.eu/en/product/data-volley-4/)
- [TeamSnap — Pricing](https://www.teamsnap.com/pricing) · [TrustRadius — TeamSnap pricing](https://www.trustradius.com/products/teamsnap/pricing)
- [Spond](https://www.spond.com/en-us/) · [Klubraum — comparatif 17 apps 2026](https://klubraum.com/blog/the-17-best-apps-for-your-team-comparison/) · [Vanta Sports — comparatif 2026](https://www.vantasports.ai/blog/best-team-management-apps)
- [SportLoMo](https://sportlomo.com/) · [LeagueApps](https://leagueapps.com/) · [PlayyOn](https://playyon.com/)
- [Spordle](https://erp.spordle.com/fr/) · [Spordle × Hockey Québec](https://hub.spordle.com/fr/publication/etudes-de-cas/hockey_quebec-1.html) · [Le Soleil — « L'application québécoise à l'assaut du sport canadien » (nov. 2025)](https://www.lesoleil.com/sports/2025/11/15/lapplication-quebecoise-a-lassaut-du-sport-canadien-PTIFODSUONALFNVRMFLFHWMQ2Y/) · [Volleyball Québec — inscriptions tournois 2025-2026 (Spordle)](https://www.volleyball.qc.ca/fr/publication/nouvelle/ouverture_des_inscriptions_aux_tournois_2025-2026_de_volleyball_quebec.html)
- [RSEQ — Volleyball](https://rseq.ca/sports/volleyball/) · [RSEQ — Basketball](https://rseq.ca/sports/basketball/ligues/)
- [Soccer Québec — la fédération](https://www.soccerquebec.org/fr/page/saviez-vous_que.html)
- [CBC — U Sports women's flag football pilot](https://www.cbc.ca/sports/olympics/summer/u-sports-to-introduce-women-s-flag-football-as-pilot-sport-9.7221886) · [Football Canada — Championnat national flag 2026](https://footballcanada.com/news/football-canada-announces-2026-national-flag-football-championship-schedule/)
- [dekhockey.info — croissance du sport](https://dekhockey.info/pages/un-des-sports-les-plus-populaires-au-quebec)
- [Apple Newsroom — Apple Sports expansion (mai 2026)](https://www.apple.com/newsroom/2026/05/apple-sports-expands-to-more-than-90-new-countries-and-regions/) · [MacRumors — Apple Sports World Cup 2026](https://www.macrumors.com/2026/05/19/apple-sports-app-2026-world-cup/)

