# Beta interne Playco v2.1.0 — ressources

Ce dossier contient tous les documents nécessaires pour lancer et piloter la beta interne avant submission App Store.

**Cible** : 5-10 coachs de volleyball au Québec (Cégep Garneau, réseau RSEQ, Volleyball Québec).
**Durée** : 2-3 semaines.
**Gate NPS** : ≥ 40 avant de passer à Sprint 5 (submission).

## Fichiers

| Fichier | Usage |
|---|---|
| [`onboarding-email.md`](onboarding-email.md) | Email à envoyer à chaque testeur beta après invitation TestFlight |
| [`formulaire-nps.md`](formulaire-nps.md) | Questions à copier/coller dans Google Forms pour le feedback structuré |
| [`script-screenshots.md`](script-screenshots.md) | Séquence de navigation iPad pour obtenir les 5-10 captures App Store |
| [`reviewer-notes.md`](../apple-review/reviewer-notes.md) | Notes pour le reviewer Apple avec compte test et flow vérifiable |

## Workflow beta → submission

1. **Recrutement** (semaine 0) : identifier 5-10 coachs via réseau + envoyer invitation TestFlight via ASC
2. **Envoi email onboarding** (jour d'invitation) : `onboarding-email.md` personnalisé avec prénom + lien TestFlight
3. **Usage quotidien** (semaines 1-2) : les coachs testent avec leurs équipes réelles
4. **Collecte feedback** (fin semaine 2) : Google Form + DM/support@playco.ca
5. **Fix bugs critiques** (semaine 3) : incrémenter v2.1.1 si nécessaire, redéployer TestFlight
6. **Sondage NPS final** (fin semaine 3) : 1 question 0-10 + commentaire libre
7. **Gate** : NPS ≥ 40 → soumission Apple · sinon prolonger 1-2 semaines

## Rappel conformité Québec

- Toutes communications beta **en français** (Loi 96) — les testeurs sont francophones
- Formulaire NPS hébergé Google Forms : vérifier que les données restent dans un environnement conforme Loi 25. **À considérer** : un alternatif québécois (Formaloo, self-hosted LimeSurvey) pour une beta élargie.
- Collecte consentement avant d'intégrer un testeur : envoyer email avec mention de conformité (cf. `onboarding-email.md`).
