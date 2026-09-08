# E′ — résidu après deux rondes de correctifs (décision fondateur requise)

> Après E′ (`bfc739f`) + contre-revue round 2 (`c5a3cea`) : le cas COOPÉRATIF (des coachs légitimes qui synchronisent) est sain — plus de perte de données, de résurrection, d'écho, de dessin détruit ; PII minimisée ; mode match étanche ; 320/320 tests. **Il reste un cluster ADVERSARIAL inhérent à la Public DB world-readable.** Ce document le pose pour arbitrage.

## Le résidu (borné par « qui connaît le code d'équipe »)

La confiance repose in fine sur le **code d'invitation, publié en clair** dans une base **lisible par tout compte iCloud**. Le code d'équipe circule sur les QR projetés au gymnase. Conséquence : un acteur malveillant **qui obtient le code d'équipe** peut, dans le pire cas :

1. **Se faire passer pour un membre de confiance** (lit un couple `(utilisateurID, codeInvitation)` valide, publie sa propre copie `UtilisateurPartage` le revendiquant → entre dans la chaîne). Menace = « connaît le code d'équipe » — le MÊME niveau que rejoindre l'équipe.
2. **Injecter/altérer des données par LWW** avec des `dateModification` fraîches (séances, stats, disponibilité), voire **publier des tombstones** (faire disparaître du contenu).
3. **Squatter l'ancre `equipe-<code>`** si l'équipe est créée hors-ligne et le code partagé avant la 1re publication (devient racine, ou — sous ACL créateur-seul — casse la sync du vrai coach).
4. **Laisser un miroir orphelin** : supprimer une équipe ne nettoie pas la Public DB (les données restent lisibles).

**Ce que les correctifs ONT fait pour réduire (pas éliminer) :** records par écrivain + ACL créateur-seul (action Dashboard) ⇒ un attaquant ne peut que **créer ses propres** records, jamais **modifier** ceux des autres ; la chaîne de confiance rejette les créateurs inconnus ; les tombstones et filigranes convergent. Le trou restant est l'usurpation d'identité **par le code au porteur** + le LWW.

## Pourquoi ça ne se « corrige » pas dans la Public DB

C'est exactement ce que la revue E disait dès le départ : une base **world-readable** ne peut pas offrir de l'écriture multi-auteurs **inviolable**. L'outil correct est **CKShare / base partagée CloudKit** (chaque membre invité par un partage signé, écriture contrôlée par le serveur) — mais SwiftData ne le supporte pas : ce serait une **migration Core Data**, hors périmètre du pivot.

## Trois postures possibles (à trancher)

| | Posture | Effet | Effort |
|---|---|---|---|
| **A** | **Accepter le résidu, documenté** — modèle de menace = « le code d'équipe est un secret au porteur, comme pour rejoindre ». Livrer E′ + ACL créateur-seul (Dashboard) + 2 durcissements bon marché (alerte si le créateur de `equipe-<code>` ≠ moi après publication ; ne pas régénérer un code sans raison). | E′ part avec la PR. Résidu assumé pour une app pré-lancement d'équipes qui se connaissent. | ~0,5 j (durcissements) |
| **B** | **Rétrécir D6** — publication head-coach **autoritaire**, assistants en **import + write-back étroit** (p. ex. seulement les stats de LEUR match). Surface d'attaque bien plus petite, proche de ce qu'une Public DB peut porter sainement. | La « parité complète » D6 devient « parité de lecture + écriture ciblée ». | ~2-3 j de refonte |
| **C** | **CKShare plus tard** — le vrai correctif inviolable, post-lancement (migration Core Data, chantier dédié). E′ tient l'intérim sous posture A ou B. | Backlog. | semaines |

## Recommandation

**A pour la PR** (le résidu est borné par le code d'équipe, déjà un secret au porteur, et l'app est gratuite/pré-lancement entre gens qui partagent un gymnase), **+ C au backlog** (CKShare quand la vidéo/le scaling justifieront un vrai backend). **B** si le fondateur juge la parité d'ÉCRITURE des assistants non essentielle à court terme — c'est le choix le plus sûr.

Décision attendue avant de finaliser la PR.
