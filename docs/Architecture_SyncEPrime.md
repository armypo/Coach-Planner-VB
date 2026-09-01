# E′ — Architecture corrigée de la sync inter-coachs (fix-forward, option C)

> Décision fondateur 2026-09-01 : corriger l'architecture E avant la PR (option C). Spec des problèmes : [Revue_Chantier_E.md](./Revue_Chantier_E.md) (54 trouvailles). Ce document fige les SOLUTIONS. Exécution : [Journal_Pivot_CoachFirst.md](./Journal_Pivot_CoachFirst.md).

## 1. Records PAR ÉCRIVAIN (règle la CRITIQUE ACL)

La Public DB n'autorise l'écriture d'un record existant qu'à son CRÉATEUR. Donc **plus jamais deux coachs sur le même record** :

- Tout recordName porte l'écrivain : `{prefixe}-{entiteID}-w{ecrivainID}` où `ecrivainID = Utilisateur.id` du compte connecté (stable inter-appareils d'un même compte — même Apple ID = même créateur CloudKit).
- Chaque record porte un champ `ecrivainID` ; **l'import IGNORE tout record sans ce champ** (les records legacy pré-E′ deviennent inertes — app pré-lancement, aucune migration).
- L'import d'une entité fusionne les copies de TOUS les écrivains par LWW (`dateModification` max).
- **Exceptions mono-écrivain** : `equipe-{code}` et `etab-{code}` (ancres, publiées par `.admin` seul — une retouche des métadonnées d'équipe par un assistant ne se propage pas, arbitrage assumé) ; `PointMatchPartage` (immuable, `.allKeys`, purge des fantômes restreinte à SES propres records).

## 2. Chaîne de confiance par créateur (règle le spoofing)

`creatorUserRecordID` est posé par le SERVEUR — infalsifiable. À l'import :

1. **Racine** = créateur du record `equipe-{code}` (recordName unique : le premier créateur le détient ; personne d'autre ne peut l'écraser).
2. **Membres de confiance** = racine ∪ créateurs d'une copie `UtilisateurPartage` dont le couple (utilisateurID, codeInvitation) correspond à une ligne créée par la racine (= la jonction : le code d'invitation reste un jeton au porteur, cohérent avec D5).
3. Tout autre record (joueur, séance, exercice, stats, points, tombstone…) n'est importé que si son créateur ∈ membres de confiance. `__defaultOwner__` (mes propres records) = toujours de confiance.

## 3. État de sync local par équipe (`EtatSyncEquipe`)

Fichier JSON par équipe (Application Support), trois structures :

- **`seuilPublication`** : remplace la clé UserDefaults GLOBALE. Capturé en DÉBUT de sweep ; avancé SEULEMENT si zéro échec ET hors mode match (sinon retry idempotent au cycle suivant).
- **`filigranes`** (anti-écho) : à l'import d'une entité, `filigrane[entiteID] = dateModification importée`. Le sweep ne publie une entité que si `dateModification > seuil` **ET** `dateModification ≠ filigrane[entiteID]` — on ne republie JAMAIS ce qu'on vient d'importer, chacun ne pousse que SES modifications.
- **`bornePublieLe`** (points) : les points portent un champ `publieLe` posé À LA PUBLICATION ; l'import borne sur `publieLe > borne` (tri croissant + reprise) — une publication TARDIVE de vieux points est quand même rattrapée (horodatage d'événement ≠ moment de publication).

## 4. Tombstones (règle les résurrections)

Nouveau record type **`SuppressionPartagee`** (`tomb-{entiteID}-w{ecrivainID}`) : codeEquipe, typeCible, entiteID, horodatage, ecrivainID.

- Toute suppression DURE locale publie un tombstone + best-effort delete de SON propre record : exercice, item de bibliothèque, formation, joueur du roster, scouting, et **match** (tombstones des StatsMatch + un tombstone de portée séance `PointMatchSeance` pour les points).
- L'import applique les tombstones EN PREMIER : entité locale supprimée si `tombstone.horodatage ≥ dateModification` locale ; les records d'entité plus vieux que le tombstone sont ignorés. Une re-création postérieure (dateModification > tombstone) gagne.

## 5. Binaires sûrs (dessins PencilKit)

- La lecture d'un champ binaire distingue **absent** (champ réellement vide → nil local légitime) / **présent mais illisible** (échec asset, plafond 15 Mo) : dans le second cas, **l'entité entière n'est PAS mise à jour** (pas d'adoption de `dateModification`) — retry au cycle suivant, jamais d'écrasement d'un dessin local par un échec réseau.
- Garde de taille TOTALE du record avant save (~900 Ko utile) : si dépassé, chaque binaire passe en CKAsset.
- Import : clamps sur tous les entiers de PointMatch (set 1-5, scores 0-99, rotations 1-6, zones 0-6) ; dédup `StatsMatch` par clé fonctionnelle (seanceID+joueurID), pas seulement par id.

## 6. Mode match réellement étanche + DEMO

- `ContentView.synchroniserDonneesPartagees` : **AUCUNE sync (ni import ni publication)** si `modeMatchActif` OU si un marqueur `MatchLiveRestauration` est vivant (couvre le kill pendant le live). Le seuil n'avançant pas, le sweep post-live rattrape tout (filet réel).
- `publierAnalyseMatch` (sortie de live) : publie séance + box scores + points (hors points filigranés = importés), purge SES fantômes seulement.
- `#if DEMO return` sur TOUS les points d'entrée du service (sweep, publierEquipeComplete, publierNouvelUtilisateur, rejouerFileAttente, syncDepuisPublic, imports initiaux).

## 7. PII minimale (santé/attestation hors Public DB)

- `JoueurPartage` ne publie plus `statutDisponibiliteRaw` (santé) ni AUCUN champ d'attestation : il publie un booléen **`estDisponible`**. Import : indisponible → statut générique `.indisponible` (nouveau cas d'enum) si le motif local est vide ; le MOTIF (blessé/malade/suspendu) et **l'attestation parentale restent locaux au compte du head coach** (registre légal non répliqué). Écart D6 assumé et documenté.
- `joueursData` du scouting : toujours jamais publié/importé. Textes libres (notes scouting/bibliothèque) : publiés (c'est la fonction), risque résiduel documenté — champ « notes privées » local en backlog.
- Gardes de régression étendues en **allowlist** (liste FERMÉE des clés autorisées par type, binaires inclus).

## 8. Hors périmètre E′ (documenté, assumé)

- Écriture des métadonnées d'équipe par un assistant (mono-écrivain §1).
- CKShare/base partagée (exigerait Core Data) ; desiredKeys/delta fin sur les binaires (optimisation, backlog).
- Skew d'horloges entre appareils (LWW à la seconde près, réfuté comme risque réel par la revue).
