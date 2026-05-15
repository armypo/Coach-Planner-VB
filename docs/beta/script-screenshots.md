# Script captures screenshots App Store — Playco v2.1.0

Séquence à dérouler sur `Ipad christo` (iPad Air 13" M3) pour obtenir les 5-10 captures nécessaires à la fiche App Store. Résolution cible : **2064 × 2752 px (portrait)** ou **2752 × 2064 (paysage)**.

## Préparation (10 min)

1. **Dock l'iPad sur le Mac via câble** (tu l'as déjà pour les tests)
2. **QuickTime Player** → File → New Movie Recording → sélectionner « Ipad christo » comme caméra
3. Dans QuickTime, fenêtre de l'iPad visible → utiliser `Cmd+Shift+4` puis `Espace` → cliquer sur la fenêtre → capture PNG pleine résolution
4. **Alternative plus rapide** : `xcrun devicectl device screenshot --device 00008103-0001050814D3C01E --destination ~/Desktop/capture.png`
5. Avant chaque capture :
   - Désactiver les notifications (Control Center → Focus Ne pas déranger)
   - Batterie iPad ≥ 80 %
   - Wi-Fi visible (pas de icône ⚠️ offline)
   - Heure 9:41 (tradition Apple — optionnel mais propre) : Réglages → Général → Date et heure → désactiver « Automatiquement » → 9:41
   - Mode clair forcé : Réglages → Affichage → Mode clair (sauf pour captures du mode sombre)

## Préparer l'état des données

Crée une équipe de démo avec données réalistes :
- 1 établissement : « Cégep Garneau », Québec, QC
- 1 équipe : « Élans féminin D1 » (couleur orange / bleu)
- 6 joueuses avec noms fictifs, postes variés (P, C, Réception, Attaque)
- 2 matchs joués (1 victoire, 1 défaite) avec stats live complètes
- 1 match à venir la semaine prochaine
- Quelques stratégies dessinées (5-1 base, rotation)
- Quelques programmes musculation

Tu peux seed ça via le wizard + quelques minutes de saisie manuelle, OU te faire un compte test « reviewer.apple.2026 » qui sert aussi pour les reviewer notes (S2.4 / S3.3).

## Captures à réaliser

### Capture 1 — AccueilView (hero)
- État : app ouverte, utilisateur coach connecté, équipe « Élans féminin D1 » active
- Vue : **AccueilView** — 5 cartes tuiles (Séances, Matchs, Stratégies, Équipe, Entraînement) + DockBar en bas
- Intention marketing : « Le coaching volleyball qui se gère de ton iPad »

### Capture 2 — Mode bord de terrain (match live)
- Depuis AccueilView → Matchs → [le match à venir créé plus haut] → **bouton « Démarrer match live »**
- Toggle « mode bord de terrain » activé (80 % de tes coachs utilisent ça)
- Score visible en 72pt, ~5 joueuses avec # sur le pavé numérique
- Quelques points saisis (kills, aces) pour que les stats soient peuplées
- Capture : **StatsLiveView courtside**

### Capture 3 — Dashboard live split-screen iPad
- Depuis le match live → bouton **« Mode split »** (fullScreenCover MatchLiveSplitView)
- Gauche : DashboardMatchLiveView avec comparaison nous vs adversaire
- Droite : StatsLiveView saisie
- Capture en **paysage**

### Capture 4 — BienvenuePaywallView
- Déconnecter, créer un nouveau compte coach via le wizard
- Compléter les 6 étapes → sheet récap credentials → fermer
- Capture **BienvenuePaywallView** avec les 2 cartes Pro / Club + toggle mensuel/annuel + badges « 14 jours offerts »
- Intention : montrer la proposition de valeur claire

### Capture 5 — Terrain dessinable (Stratégies)
- Depuis AccueilView → Stratégies → [une stratégie existante, ex: « 5-1 rotation 2 »]
- Montrer le terrain avec joueurs placés + flèches + notes
- Barre d'outils dessin visible (Apple Pencil utilisé)

### Capture 6 — Analytics saison
- Depuis AccueilView → Équipe → Tableau de bord
- Montrer AnalyticsSaisonView avec graphiques Swift Charts (cumulatifs V/D, efficacité attaque)
- Intention : « Pro = analytics sérieuses »

### Capture 7 — IdentifiantsEquipeView
- ProfilView → Organisation → **Identifiants de l'équipe**
- Liste des 6 athlètes + 1 assistant avec identifiants + mdp monospace
- Intention : « Gestion multi-rôles simple »

### Capture 8 — ProfilView avec abonnement actif
- Depuis ProfilView d'un compte avec **essai Club actif**
- Montrer la section « Mon abonnement » avec BadgeStatut orange « Essai gratuit · 12 j restants »
- Intention : « Gestion transparente de ton abonnement »

### Capture 9 (optionnelle) — Heatmap terrain
- Matchs → [un match joué] → HeatmapTerrainView zones 1-6
- Intention : « Analyse avancée »

### Capture 10 (optionnelle) — Export PDF
- Matchs → [un match joué] → Exporter PDF → aperçu
- Intention : « Partage facile avec ton staff »

## Overlays marketing (Figma ou Canva)

Pour les 2-3 premières captures (hero), ajouter un overlay texte :

- **Capture 1** : « Coache sérieusement. Depuis ton iPad. »
- **Capture 2** : « Stats live point-par-point. Mode bord de terrain. »
- **Capture 3** : « Dashboard + saisie côte à côte. Pensé iPad. »

Fonte recommandée : SF Pro Display (système Apple) ou Inter.
Couleur : blanc sur fond sombre assombri (tint noir 40 % opacity).

## Dimensions finales

Apple exige :
- **iPad Pro 13" (6th gen / M5)** : 2064 × 2752 (portrait) ou 2752 × 2064 (paysage)
- **iPad Pro 11" (M5)** : 1668 × 2388 ou 2388 × 1668
- **iPad 11" (10th gen)** : 1640 × 2360

iPad Air 13" (M3) = 2064 × 2752. Les captures directes d'Ipad christo iront pour la **13"** sans retouche. Pour la **11"**, soit tu retouches (crop depuis 13"), soit tu utilises un simulateur iPad Pro 11" (lancer l'app là-bas pour capture — seule exception au « iPad physique only »).

## Upload dans App Store Connect

ASC → App → App Store → Version 2.1.0 → **iPad Screenshots** → glisser/déposer dans les 2 tailles (13" + 11"). 10 captures max par taille, minimum 3.

## Rappel Loi 96

Toutes les captures **doivent** afficher l'UI en français. C'est le cas par défaut (l'app est FR seulement en v2.1). Si tu captures la version anglaise pour Apple reviewer, n'upload **que** la version FR sur ASC (la version EN est pour reviewer notes uniquement).
