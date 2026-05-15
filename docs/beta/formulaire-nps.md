# Questions formulaire NPS Playco v2.1 Beta

Copie/colle ces questions dans Google Forms (ou Formaloo pour option québécoise Loi 25 compatible). Toutes en français, rédigées pour des coachs volleyball.

---

## Titre du formulaire

**Feedback beta Playco v2.1 — ton avis compte**

## Description

Merci de tester Playco en beta ! Ce formulaire prend 5-10 min. Tes réponses sont anonymes par défaut mais laisse ton email si tu veux qu'on revienne vers toi pour creuser un point.

---

## Section 1 — Ton profil coach

### Q1. Quel est ton rôle principal ?
*(choix unique)*
- Coach en chef (head coach)
- Coach assistant
- Coach saisonnier / occasionnel
- Responsable sportif / directeur technique
- Autre : _____

### Q2. Quel niveau de volleyball entraînes-tu principalement ?
*(choix unique)*
- Secondaire (12-18 ans)
- Cégep / CEPEP
- Universitaire
- Club civil / RSEQ
- Équipe provinciale ou nationale
- Autre : _____

### Q3. Depuis combien de temps utilises-tu un iPad pour ton coaching ?
*(choix unique)*
- Moins de 6 mois
- 6 mois à 2 ans
- 2 à 5 ans
- Plus de 5 ans
- Je n'utilisais pas d'iPad avant Playco

---

## Section 2 — Usage de Playco

### Q4. Combien de temps as-tu utilisé Playco pendant la beta ?
*(choix unique)*
- Moins d'une heure (juste testé)
- 1-5 heures (quelques sessions)
- 5-15 heures (usage régulier)
- 15+ heures (usage quotidien avec mon équipe)

### Q5. Quelles sections as-tu utilisées ? *(case à cocher — plusieurs réponses)*
- Séances (pratiques)
- Matchs (composition + stats live)
- Stratégies (terrain dessinable)
- Équipe (joueurs + statistiques)
- Entraînement (musculation)
- Messagerie
- Analytics saison + palmarès
- Export PDF / CSV

### Q6. As-tu testé l'**essai 14 jours** du paywall ?
*(choix unique)*
- Oui, plan Pro
- Oui, plan Club
- Oui, j'ai annulé le dialogue Apple (refusé essai)
- Non, pas testé

---

## Section 3 — Satisfaction (NPS)

### Q7. ⭐ **Sur une échelle de 0 à 10, quelle probabilité que tu recommandes Playco à un autre coach ?**
*(0 = jamais, 10 = certainement)*

`[ 0 ] [ 1 ] [ 2 ] [ 3 ] [ 4 ] [ 5 ] [ 6 ] [ 7 ] [ 8 ] [ 9 ] [ 10 ]`

> **Note** : c'est LA question NPS. La cible gate pour passer à la submission App Store est un NPS ≥ 40. Calcul : `(% promoteurs 9-10) - (% détracteurs 0-6)`.

### Q8. Qu'est-ce qui t'a le **plus plu** dans Playco ? *(texte libre)*

### Q9. Qu'est-ce qui t'a le **plus frustré** ou manqué ? *(texte libre)*

---

## Section 4 — Tarification

### Q10. Les prix t'ont-ils semblé équitables pour ce que Playco offre ?
*(choix unique)*
- Trop cher (quel prix te semblerait juste ?) : _____
- Un peu cher mais acceptable
- Juste ce qu'il faut
- Moins cher que ce à quoi je m'attendais

### Q11. Quel plan choisirais-tu si tu devais t'abonner aujourd'hui ?
*(choix unique)*
- Playco Pro mensuel (14,99 $)
- Playco Pro annuel (149,99 $)
- Playco Club mensuel (25 $)
- Playco Club annuel (250 $)
- Je n'achèterais pas encore (pas prêt)
- Aucun (pas intéressé)

---

## Section 5 — Bugs / problèmes rencontrés

### Q12. As-tu rencontré des bugs ou crashes ? *(case à cocher)*
- Non, aucun problème
- Oui, au démarrage
- Oui, dans le wizard de création d'équipe
- Oui, pendant la saisie stats live
- Oui, au paywall / essai
- Oui, sync iCloud
- Oui, autre : _____

### Q13. Peux-tu décrire le bug / ce qui n'a pas marché ? *(texte libre)*

---

## Section 6 — Suite

### Q14. Tu accepterais qu'on te contacte par email pour approfondir ton retour ?
*(choix unique)*
- Oui, voici mon email : _____
- Non merci

### Q15. Tu accepterais que ton témoignage (prénom + initiale + citation courte) soit utilisé sur le site playco.ca ou App Store ?
*(choix unique)*
- Oui
- Non

### Q16. Un dernier mot, suggestion ou question ? *(texte libre)*

---

## Conformité Loi 25

Inclure **à la fin du formulaire** cette mention :

> Origo Technologies, responsable des renseignements personnels, collecte tes réponses uniquement pour améliorer Playco. Les données sont stockées chez Google Workspace (si Google Forms) et ne sont ni revendues ni utilisées à des fins marketing. Tu peux retirer ton consentement ou demander l'effacement en écrivant à support@playco.ca. Conforme Loi 25 (Québec) et LPRPDE.

---

## Analyse des résultats

Une fois le formulaire clôturé (fin semaine 3 beta) :

1. **Calculer NPS** : `(Promoteurs 9-10 / total) × 100 − (Détracteurs 0-6 / total) × 100`
2. **Classifier les commentaires libres** (Q8, Q9, Q16) :
   - Top 3 points forts récurrents → candidats témoignages landing page
   - Top 3 irritants → tickets prioritaires S5.5 dette technique ou urgent pre-launch
3. **Bugs critiques Q13** : créer issues GitHub immédiatement, fix si > 20 % des testeurs rapportent le même
4. **Tarif Q10-Q11** : si < 30 % choisiraient Club, reconsidérer prix / positionnement
5. **Décision go/no-go** : si NPS ≥ 40 ET pas de bug critique > 20 % → submission, sinon prolonger beta
