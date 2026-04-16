# Prochaines étapes — Playco avec 2 beta testeurs

**Date :** 14 avril 2026
**Stade :** TestFlight v1.9.0, 2 coachs beta actifs
**Horizon :** 5 mois jusqu'au launch critique de septembre 2026
**Objectif document :** roadmap produit + vente décisionnelle pour les 24 prochaines semaines

---

## Table des matières

1. [Contexte stratégique](#contexte-stratégique)
2. [Semaines 1-2 : EXTRAIRE — transforme les 2 beta testeurs en or](#semaines-1-2--extraire)
3. [Semaines 3-8 : CONSOLIDER — fix le produit avant de scaler](#semaines-3-8--consolider)
4. [Semaines 9-16 : ÉLARGIR — beta payante de 15 coachs](#semaines-9-16--élargir)
5. [Semaines 17-24 : PRÉ-LAUNCH INSTITUTIONNEL](#semaines-17-24--pré-launch-institutionnel)
6. [Semaine 25+ : LAUNCH (1er septembre 2026)](#semaine-25--launch)
7. [Métriques à tracker](#métriques-à-tracker)
8. [Gates de décision](#gates-de-décision)
9. [Ce qu'il NE FAUT PAS faire](#ce-quil-ne-faut-pas-faire)
10. [Les 3 actions cette semaine](#les-3-actions-cette-semaine)

---

## Contexte stratégique

Tu es dans une **fenêtre en or** :
- Saison indoor HS/cégep se termine (avril/mai)
- **5 mois avant la reprise critique de septembre**
- 2 coachs = échantillon parfait pour apprendre avant de scaler
- Pas de pression match → tu peux casser des trucs sans ruiner personne

> **Règle d'or :** ne passe PAS à 50 beta testeurs avant d'avoir extrait 100 % de la valeur des 2 que tu as.

---

## Semaines 1-2 : EXTRAIRE

**Objectif :** transformer les 2 beta testeurs en or.

### Ce qu'il faut faire MAINTENANT (avant toute ligne de code)

#### 1. Entrevue structurée 45 min avec chaque coach (enregistrée avec permission)

6 questions à poser dans l'ordre, sans souffler les réponses :

1. **« Raconte-moi ta dernière semaine avec Playco, heure par heure. »**
   *(observation du workflow réel, pas du workflow imaginé)*

2. **« Quelles sont les 3 fonctionnalités que tu as utilisées le plus ? Celles que tu n'as jamais touchées ? »**
   *(coverage réelle vs. investie)*

3. **« Avant Playco, tu utilisais quoi ? Et tu l'utilises encore pour quoi ? »**
   *(identifier ce que Playco NE remplace PAS)*

4. **« Si je te prenais Playco demain matin, qu'est-ce qui te manquerait VRAIMENT ? »**
   *(value prop réel)*

5. **« Dans ton réseau, qui devrait avoir ça ? Donne-moi 3 noms. »**
   *(pipeline warm leads)*

6. **« Combien tu payerais par mois pour ça ? Pas pour me faire plaisir — pour vrai. »**
   *(willingness to pay réel)*

#### 2. Session d'observation 30 min (écran partagé ou en personne)

- Demande-leur d'accomplir une tâche standard (ex: entrer les stats d'un match récent, créer une pratique de la semaine)
- **Ne dis rien, observe.** Note chaque hésitation, chaque retour arrière, chaque "heu..."
- C'est là que tu trouveras les 5 vrais problèmes UX qui méritent un fix.

#### 3. Demande 3 livrables concrets à chaque coach

- **1 témoignage vidéo 60 secondes** pour la page App Store + pitch investisseurs
- **1 intro à un collègue coach** (commit publique, calendrier en main)
- **1 « Early Adopter Badge »** en échange : gratuité à vie + reconnaissance publique sur le site + accès aux futures features en priorité

### Deliverable semaine 2

Document **« Top 10 insights beta »** avec priorités et décisions produit.

---

## Semaines 3-8 : CONSOLIDER

**Principe :** corriger ce qui frictionne > ajouter des features nouvelles.

### Priorité 1 — Fix les 5 bugs/friction points du top 10 (2-3 semaines)

Ce sera évident après les entrevues. Résiste à la tentation d'ajouter des features « qui seraient cool ». Tu n'as que 5 mois.

### Priorité 2 — Onboarding flow (1 semaine)

Le plus grand killer pour un coach qui ouvre Playco sans toi à côté. Ajouter :
- Tutoriel interactif après le wizard de configuration
- Template « première saison en 3 clics » (pré-remplit exercices, créneaux types, formations de base)
- Video walkthrough 2 min embed directement dans l'app (FoundationModels peut générer la transcription)

### Priorité 3 — Monétisation (1-2 semaines)

**StoreKit 2 à remettre** (supprimé en v1.4.0 pour TestFlight). Configuration :

| Tier | Prix | Contenu |
|---|---|---|
| **Freemium** | Gratuit | 1 équipe, features core, watermark export PDF |
| **Pro** | 12,99 $/mois ou 99 $/an | Équipes illimitées, export propre, scouting, analytics avancées |
| **Club** | 299 $/an | Multi-coachs, stats historiques CloudKit illimitées |

Active un **feature flag** pour laisser les 2 beta testeurs en Pro gratuit à vie (deal Early Adopter).

### Priorité 4 — Analytics produit (3 jours)

Tu ne peux pas améliorer ce que tu ne mesures pas. Ajoute :
- Daily/Weekly Active Users
- Session duration
- Core actions par session (stats entrées, exercices créés, terrains dessinés)
- Retention D1/D7/D30
- Funnel onboarding (combien finissent le wizard, combien créent leur 1re équipe, leur 1re pratique, leur 1er match)

> **Ne PAS utiliser Firebase/Mixpanel** (privacy + Apple tax + perf). Utilise un backend minimal Supabase/Vercel ou même CloudKit Record + un dashboard local.

### Priorité 5 — FoundationModels MVP (2 semaines)

Une seule feature pour commencer : **résumé de match automatique** à partir des PointMatch. 3 lignes de Swift avec `@Generable`. Effet wow immédiat vs. tous les concurrents.

### Deliverable semaine 8

Playco v1.10 → prêt pour beta élargie + premiers payants.

---

## Semaines 9-16 : ÉLARGIR

**Beta payante de 15 coachs**

### Objectif chiffré

Passer de **2 à 15 beta testeurs actifs**, dont **5 payants** (même à 5 $/mois symbolique) — c'est ton premier signal de willingness to pay réel.

### Segmentation ciblée (via les 2 coachs actuels + réseau direct)

| Segment | Cible | Canal |
|---|---|---|
| **Cégeps Québec** | 3-5 coachs (Garneau + Limoilou + Ste-Foy + FX-Garneau + Édouard-Montpetit) | Intro chaude via Garneau + LinkedIn + mail direct |
| **Écoles secondaires RSEQ** | 3-5 coachs (Québec + Montréal régions) | Via Volleyball Québec + Facebook Groups coachs |
| **Clubs civils** | 3-5 coachs (Élans, Titans, CVQ, Impact, Rouge et Or) | Intro des coachs cégep + networking fédération |
| **Beach (bonus)** | 1-2 coachs | Test courtside mode en beach volley cet été |

### Script d'approche (inspire-toi, adapte)

> « Salut [nom], je suis Matisse, coach à Cégep Garneau et je développe une app iPad native pour coachs de volley depuis 2 ans. [Coach beta 1] et [Coach beta 2] l'utilisent depuis 3 mois. J'ouvre une beta payante pour 10-15 coachs ce printemps avant le launch officiel en septembre. 5 $/mois, accès à tout, et ton feedback façonne la v2.0. Intéressé de voir un démo 20 min ? »

### Ce qu'il faut EXIGER de chaque nouveau beta testeur

- **Check-in hebdo** (même 5 minutes via Messages) pour garder le pouls
- **1 case study signé** après 4 semaines d'usage (anonymisé OK)
- **Engagement 3 mois minimum** avant de décrocher
- **NPS score** mensuel (1 question : « Recommanderais-tu Playco à un collègue coach ? »)

### Deliverable semaine 16 (fin juin)

- 15 beta testeurs actifs
- 5 payants
- 3 case studies
- NPS > 40 (= on-track)

---

## Semaines 17-24 : PRÉ-LAUNCH INSTITUTIONNEL

**Juillet-août 2026**

**Contexte :** c'est le moment où tu montes le pipeline pour le launch de septembre. Tout doit être prêt **avant le 20 août** car les coachs planifient leur saison du 20 août au 5 septembre.

### Track 1 — Partenariats institutionnels (CRITIQUE)

#### Cible A — Volleyball Québec (priorité absolue)

- **Démarche :** écrire directement au DG + directeur technique
- **Pitch :** « Playco = outil officiel pour les coachs volleyball québécois, francophone, iPad-natif, zéro coût pour VQ, license éducation gratuite pour les coachs certifiés VQ niveau 1-2. »
- **Demande :** 1 rencontre 60 min en août, démo en live, proposition de co-branding
- **Ce que tu offres :** 50-100 licences gratuites à vie pour leurs coachs PNCE + logo VQ sur l'écran d'accueil (optionnel)
- **Ce que tu veux :** blast email à tous les coachs certifiés + mention dans leur newsletter de rentrée

#### Cible B — RSEQ Cégep Volleyball

- 60 cégeps, ~9 D1 + 25 D2 + 25 D3
- **Approche :** pitch groupé aux coordonnateurs sport RSEQ (une rencontre suffit)
- **Offre :** 299 $ / cégep / an, déductible budget sport-études, 1 démo par région si intérêt
- **Objectif réaliste :** 15 cégeps signés pour septembre = 4 485 $/an MRR annualisé

#### Cible C — RSEQ Secondaire

- Plus gros volume, plus fragmenté, plus difficile
- **Stratégie :** laisser les 15 cégeps faire le marketing par le bouche-à-oreille vers leurs feeder schools secondaires
- **Ne PAS dédier d'effort direct avant septembre**

### Track 2 — Préparation App Store 2.0 launch

- **Screenshots** retravaillés avec Mode bord de terrain + FoundationModels summary
- **App Preview video** 15 s (Cégep Garneau en action, avec permission)
- **Localisation** FR + EN (pour Canada anglophone en optionnalité)
- **Landing page** playco.ca : testimonials des 2 beta testeurs, pricing, « Essai gratuit 14 jours »
- **Demo video** 3 min pour coachs, hébergée sur YouTube + intégrée landing page

### Track 3 — Capital non-dilutif en parallèle

- **Semaine 17-20 :** finaliser application LE CAMP (soumission en juin) + Mitacs dossier étudiant Laval
- **Semaine 20-24 :** déposer Fonds Impulsion (parrainage LE CAMP) et approche anges Québec

### Deliverable semaine 24 (fin août)

- 15 cégeps contractés
- Partenariat Volleyball Québec signé ou en rédaction finale
- App Store v2.0 prête à soumettre
- Playco v2.0 Release Candidate

---

## Semaine 25+ : LAUNCH

**1er septembre 2026**

### Actions

- Release App Store v2.0 publique
- Blast email Volleyball Québec (si partenariat signé)
- Article de presse (La Presse, Radio-Canada Sport, TVA Sports) — angle « app québécoise pour coachs volleyball »
- LinkedIn post du fondateur + testimonials vidéo des beta testeurs
- Webinar gratuit « Préparer sa saison volleyball avec Playco » (attire les leads curieux)

### Objectifs 30 jours post-launch

| Métrique | Cible |
|---|---|
| Téléchargements App Store | 100 |
| Trials actifs | 30 |
| Conversions payantes (au-delà des 15 cégeps) | 10 |
| MRR | 6-8 k$ CAD |

---

## Métriques à tracker

| Métrique | Actuel | Cible juin | Cible sept |
|---|---|---|---|
| **Beta testeurs actifs** | 2 | 15 | 30 |
| **Payants (> 0 $)** | 0 | 5 | 25 |
| **MRR** | 0 $ | 250 $ | 6-8 k$ |
| **NPS** | ? | > 40 | > 50 |
| **Retention D30** | ? | > 60 % | > 70 % |
| **Contrats institutionnels signés** | 0 | 0 | 15 cégeps + 1 VQ |
| **Non-dilutif cumulé** | 0 $ | 15 k$ (Mitacs) | 30 k$ |

---

## Gates de décision

### Gate juin 2026 (fin phase « élargir »)

- **Si NPS > 40 et 5 payants** → continue plein gaz, prépare launch septembre
- **Si NPS 20-40** → pivot produit, identifie la friction majeure avant launch
- **Si NPS < 20** → stop, entrevues profondes, questionne le value prop

### Gate septembre 2026 (30 jours post-launch)

- **Si MRR > 5 k$ et croissance 15 %/mois** → dépose Fonds Impulsion (500 k$) + Anges Québec
- **Si MRR 2-5 k$** → mode indie, cherche un co-fondateur BD à equity seulement
- **Si MRR < 2 k$** → question existentielle, reviens au dossier de recherche marché

---

## Ce qu'il NE FAUT PAS faire

Pièges prévisibles à éviter :

- ❌ **Ajouter des features avant de fixer les frictions top 5** — tu vas construire sur du sable
- ❌ **Scaler la beta à 50 testeurs sans process de onboarding solide** — tu vas passer 20h/semaine en support
- ❌ **Attendre que le produit soit parfait pour le launch septembre** — done > perfect, tu auras 12 mois pour itérer
- ❌ **Monétiser trop cher trop vite** — 12,99 $/mois est ton sweet spot testé, pas 29 $/mois
- ❌ **Oublier les beach coachs en mai-août** — beta parfaite, conditions idéales (courtside, peu de pression)
- ❌ **Partir en vacances en août sans avoir contacté Volleyball Québec** — le timing institutionnel août-septembre est critique
- ❌ **Commencer à coder des features avant d'avoir fait les 2 entrevues** — les insights déterminent la roadmap

---

## Les 3 actions cette semaine

1. **Planifier les 2 entrevues beta de 45 min** (d'ici vendredi)
2. **Écrire ton script d'approche** pour les 10 prochains coachs (basé sur l'exemple ci-dessus)
3. **Ouvrir une feuille « Insights Beta »** où tu consignes chaque friction observée en direct

Tout le reste découle de ces 3 actions.

---

## Question à se poser chaque semaine jusqu'en septembre

> **« Est-ce que ce que je fais cette semaine me rapproche d'un partenariat Volleyball Québec ou de 15 cégeps signés le 1er septembre ? Si non, je fais quoi à la place ? »**

---

## Matériel complémentaire à préparer

Sur demande, documents additionnels disponibles :

- [ ] **Script détaillé des entrevues beta** (avec questions de relance)
- [ ] **Deck de pitch pour Volleyball Québec** (3-5 slides)
- [ ] **Template email d'approche** pour les cégeps
- [ ] **Liste des 60 cégeps Québec** avec contacts coachs volleyball
- [ ] **Dossier Mitacs Accelerate Entrepreneur** (structure + étudiant Laval)

---

## Timeline visuelle

```
AVRIL ────┬──── MAI ────┬──── JUIN ────┬──── JUILLET ──┬──── AOÛT ────┬──── SEPT
          │             │              │               │              │
  S1-2    │    S3-8     │    S9-16     │   S17-20      │   S21-24     │   S25+
EXTRAIRE  │ CONSOLIDER  │   ÉLARGIR    │  PRÉ-LAUNCH   │  FINALISER   │  LAUNCH
          │             │              │               │              │
 2 beta   │   v1.10     │  15 beta     │   LE CAMP     │   VQ signé   │  v2.0 App
entrevues │  FoundMdls  │  5 payants   │   Mitacs      │   15 cégeps  │   Store
insights  │  StoreKit 2 │  NPS > 40    │   RSEQ pitch  │   App 2.0 RC │  MRR 6-8k
```

---

*Document généré le 14 avril 2026 · Playco v1.9.0 · Complément à Market_Research_Avril_2026.md*
