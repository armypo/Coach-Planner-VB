# Sécurité — Fallback d'abonnement via CloudKit Public DB

> Suivi de l'audit Xcode 27 (juin 2026). Concerne `CloudKitPublicSyncAbonnement` +
> `AbonnementService.restaurerDepuisPublicDB`. Source de vérité = **StoreKit** ;
> la Public DB n'est qu'un **fallback de confort** pour la reconnexion sur un
> Apple ID différent.

## 1. Modèle de menace

`CloudKitPublicSyncAbonnement` publie/lit un enregistrement `AbonnementPartage`
(clé `recordName = "abo-<codeEquipe>"`) dans la **CloudKit Public Database**.

- La Public DB est **inscriptible par tout utilisateur iCloud authentifié**.
- `codeEquipe` est **partagé avec toute l'équipe** (athlètes inclus) et figure
  dans les flux « Rejoindre une équipe ».

**Menace** : un utilisateur qui connaît un `codeEquipe` peut écrire un
`AbonnementPartage` forgé (`tier=club`, expiration lointaine) → toute reconnexion
sur ce code restaurerait un tier payant **sans achat** (contournement paywall).

**Gravité** : commerciale (perte de revenu), pas une fuite de données. Bornée à
l'équipe dont on connaît le code. StoreKit reste autoritatif sur l'appareil payeur.

## 2. Défense en profondeur — CÔTÉ CODE (implémenté ✅)

`AbonnementService.statutDepuisSnapshotPublic(_:)` est la **frontière de confiance**
(là où un instantané public devient un entitlement). Garde-fous ajoutés :

- **Expiration obligatoire** : un record sans `dateExpiration` est rejeté (un
  record légitime en publie toujours une via `dateExpirationCourante()`).
- **Expiration non aberrante** : rejet si `dateExpiration > now + ~13 mois` (un
  abonnement Apple ne dépasse jamais ~1 an). Bloque les forgeries grossières
  type `tier=club, expiration=2099`.
- **Log d'anomalie** : tout rejet est journalé (`loggerAbo.warning`), et tout
  octroi via fallback est journalé (visibilité).
- Le tier dérivé du public **n'est jamais traité comme StoreKit-validé** : il
  alimente seulement `statut` + le cache UserDefaults, et le prochain
  `rafraichir()` avec un vrai entitlement StoreKit l'écrase.

> Ces gardes relèvent significativement la barre, mais **ne suffisent pas seuls** :
> un attaquant peut toujours publier un record « plausible » (expiration ≤ 13 mois).
> La protection structurelle est la config CloudKit ci-dessous.

## 3. Protection structurelle — CLOUDKIT DASHBOARD (action humaine requise 🚫)

Restreindre l'écriture du record type `AbonnementPartage` au **créateur uniquement**.

**Procédure** (conteneur `iCloud.Origo.Playco`) :
1. https://icloud.developer.apple.com/dashboard → conteneur **iCloud.Origo.Playco**.
2. **Schema → Record Types → `AbonnementPartage`** (le créer si absent ; champs :
   `codeEquipe` String (queryable), `tierRaw` String, `typeRaw` String,
   `dateExpiration` Date/Time, `dateDernierSync` Date/Time).
3. **Security Roles** :
   - `_world` : **No access** (ou Read seul si une lecture anonyme est requise).
   - `_icloud` (authentifié) : **Read** uniquement.
   - `_creator` : **Read/Write**.
4. Appliquer aux environnements **Development ET Production**, puis **Deploy Schema
   Changes to Production**.

**Effet** : un attaquant ne peut plus **écraser** le record d'une équipe créé par
le coach légitime. Reste possible : créer le record d'une équipe qui n'en a pas
encore (équipe non-payante) — impact borné et sans victime payante.

**⚠️ Compromis à connaître** : `_creator`-only signifie que seul l'Apple ID ayant
créé le record peut le mettre à jour. Si le coach **change réellement d'Apple ID**,
son nouveau compte ne pourra pas rafraîchir l'ancien record (il deviendra stale).
Options : (a) accepter le stale (le record garde le dernier tier connu, lisible) ;
(b) inclure le date `dateDernierSync` et tolérer un record périmé en lecture ;
(c) à terme, valider via App Store Server API (cf. §4).

## 4. Renforcement futur (hors périmètre lancement)

- **Validation de reçu signé** (App Store Server API / `Transaction` JWS) côté
  backend pour corroborer le fallback — nécessite un serveur + clés (action humaine).
  Tant qu'absent : ne jamais élever au-dessus d'un tier crédible (déjà borné par §2).

## 5. ⚠️ Constat connexe (HORS périmètre de cette tâche — à trier séparément)

En auditant la Public DB, on note que **`CloudKitSharingService.publierUtilisateur`
écrit `motDePasseHash`, `sel`, `roleRaw`, `identifiant` dans `UtilisateurPartage`
en Public DB** (monde-lisible). Conséquences potentielles :
- Exposition publique des **hash de mots de passe** (PBKDF2 600k — coûteux à casser,
  mais ne devrait pas être public) à quiconque connaît un `codeEquipe`.
- Possibilité de **forger/écraser** des `UtilisateurPartage` (usurpation à la
  jonction d'équipe) faute de rôle d'écriture restreint.

C'est **pré-existant** (non introduit par l'audit Xcode 27) et **plus sévère** que
le fallback abonnement. À traiter dans un chantier auth/CloudKit dédié :
- déplacer les identifiants sensibles hors de la Public DB (ou chiffrer), 
- restreindre les rôles d'écriture de **tous** les types `*Partage` au créateur — y compris les types **ajoutés au partage coach→athlète** : `SeancePartagee`, `MatchCalendrierPartagee` (et les champs stats ajoutés à `JoueurPartage`). Ces nouveaux types ne contiennent **aucune PII/hash** (vérifié), mais restent inscriptibles par défaut ;
- repenser le flux « Rejoindre une équipe » sans exposer les hash.

> Note : `tierAbonnement` n'est PAS publié sur `EquipePartagee` (vérifié) — le
> commentaire de `propagerTierAuxEquipes` est trompeur (il sauvegarde en local →
> sync DB **privée**, pas la sharing DB). `AbonnementPartage` est donc le seul
> vecteur public du tier.

## 6. État

| Mesure | Statut |
|--------|--------|
| Garde-fous code (expiration obligatoire + plafond 13 mois + logs) | ✅ implémenté |
| Caveat SÉCURITÉ en tête de `CloudKitPublicSyncAbonnement.swift` | ✅ |
| Rôle d'écriture CloudKit `AbonnementPartage` = créateur | 🚫 action humaine (Dashboard) |
| Validation reçu signé | ⏳ futur (serveur) |
| Chantier `UtilisateurPartage` / hash public | 🚫 à trier séparément |
