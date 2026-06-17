# Sécurité — Statut d'abonnement via CloudKit Public DB

> ⚠️ **MISE À JOUR v2.0.1 / Sign in with Apple (juin 2026)** — Ce document décrit
> l'approche initiale (par mot de passe) de `main`. La direction retenue est
> **Sign in with Apple**, qui **DURCIT** ce modèle. Corrections à appliquer en
> lisant la suite :
> - **`AbonnementService.restaurerDepuisPublicDB` et le fallback d'accès ont été
>   SUPPRIMÉS.** Aucun accès payant n'est JAMAIS accordé à partir d'un statut publié
>   en Public DB (non signé). La récupération d'un abonnement sur un nouvel appareil
>   passe par **« Restaurer » StoreKit** (modèle Apple). `CloudKitPublicSyncAbonnement`
>   ne sert plus qu'à un affichage **informationnel** (`tierEquipeActif`, jamais une
>   décision d'accès).
> - **La jonction d'équipe ne dérive plus de mot de passe** (`creerCompteLocalJonction`
>   supprimé). Elle se fait par **Sign in with Apple + code d'invitation**
>   (`rejoindreEquipe`/`reclamerMembreLocal`), avec anti-escalade (`roleJonctionAutorise` :
>   jamais coach/admin via jointure).
> - **Aucun mot de passe n'est stocké** (`CredentialAthlete.motDePasseClair` toujours vide).
>
> Le reste du document (modèle de menace Public DB, durcissement Dashboard
> creator-write, scrub des hash) **reste valide et applicable**.

> Concerne `CloudKitPublicSyncAbonnement`. Source de vérité d'accès = **StoreKit
> local** ; la Public DB est **informationnelle uniquement** (jamais une décision
> d'accès).

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

## 5. Credentials hors Public DB + refonte jonction (RÉSOLU ✅ — code)

> Constat initialement pré-existant : `CloudKitSharingService.publierUtilisateur`
> écrivait `motDePasseHash` / `sel` / `iterations` dans `UtilisateurPartage`
> (world-readable) → brute-force offline des hash + forge/escalade à la jonction.

**Correctif livré (code) :**
- `publierUtilisateur` ne publie **plus** `motDePasseHash` / `sel` / `iterations`
  (extraction `construireRecordUtilisateur`, testable). `UtilisateurPartage` ne
  porte que le profil non sensible.
- Suppression de `importerUtilisateur` et retrait de l'import de comptes (avec
  credentials) dans `recupererEtImporterEquipe` / `syncDepuisPublic` — on ne
  réplique **plus jamais** les comptes des autres membres sur l'appareil.
- **Refonte jonction** : `creerCompteLocalJonction(...)` crée le compte du membre
  joignant en **dérivant le hash localement** depuis le mot de passe saisi
  (PBKDF2 600k) — rien de dérivé du mdp ne transite par le réseau. Modèle
  « premier mdp tapé = le sien ». Appelé par `RejoindreEquipeView` après l'import
  de données, avant `AuthService.connexion`.
- **Clamp de rôle anti-escalade** : `roleJonctionAutorise(_:)` n'autorise que
  `.etudiant` / `.assistantCoach` ; `.coach` / `.admin` rejetés — le rôle n'est
  jamais accordé en aveugle depuis un record réseau.
- Gardes de régression : `CloudKitSharingServiceTests`
  (`publicationSansCredentials`, `roleJonctionAutoriseOK`, `roleJonctionAutoriseRejet`).

**Actions humaines requises (Dashboard 🚫) :**
- **Scrub** des `motDePasseHash` / `sel` / `iterations` déjà publiés dans
  `UtilisateurPartage` (les hash exposés y restent jusqu'à suppression) + **rotation
  hors-bande** des mdp athlètes/assistants.
- **Security Roles** `_world` = lecture seule (write = créateur) sur **tous** les
  `*Partage` : `EquipePartagee`, `UtilisateurPartage`, `JoueurPartage`,
  `EtablissementPartage`, `SeancePartagee`, `MatchCalendrierPartagee`,
  `AbonnementPartage` (cf. §3). Ces types ne contiennent aucune PII/hash après ce
  correctif, mais restent inscriptibles par défaut → forge possible sans restriction.

**Risque résiduel accepté** : la Public DB contient toujours du PII de roster
(noms, numéros, rôles, identifiants, code d'équipe), world-readable et énumérable
par code d'équipe ; accepté en lieu d'un rewrite CKShare (non exposé par le store
SwiftData `.automatic`). La rotation/désactivation côté coach ne se propage pas aux
membres ayant rejoint sur un autre Apple ID (à redistribuer hors-bande).

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
| `UtilisateurPartage` sans credentials + dérivation locale + clamp rôle | ✅ implémenté |
| Scrub hash publiés + Security Roles tous `*Partage` + rotation mdp | 🚫 action humaine (Dashboard) |
