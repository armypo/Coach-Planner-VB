# Sécurité — CloudKit Public Database

**Container :** `iCloud.Origo.Playco`
**Dernière mise à jour :** 13 juin 2026
**Statut :** correctif code livré (v2.x) — **actions Dashboard P0 requises avant App Store**

---

## 1. Contexte

Playco utilise SwiftData `ModelConfiguration(cloudKitDatabase: .automatic)`, qui ne synchronise que dans la **private DB d'un même Apple ID**. Pour qu'un athlète/assistant sur un **Apple ID différent** rejoigne l'équipe de son coach, `CloudKitSharingService` publie un miroir des données d'équipe dans la **Public Database** du container, interrogeable par `codeEquipe`.

La Public Database est **world-readable** par tout utilisateur iCloud authentifié, et **world-writable par défaut** tant que les *Security Roles* ne sont pas restreints.

---

## 2. Vulnérabilité (corrigée — historique)

`CloudKitSharingService.publierUtilisateur(_:)` écrivait dans le record world-readable `UtilisateurPartage` :

- `motDePasseHash` (PBKDF2-HMAC-SHA256, 600k itérations),
- `sel`,
- `iterations`.

Conséquences :

1. **Exposition des hash de mots de passe** : quiconque connaît un `codeEquipe` (partagé avec toute l'équipe, et **énumérable** via `equipeExiste`) pouvait télécharger tous les hash → **brute-force offline** (PBKDF2 600k ralentit mais ne protège pas les mots de passe faibles).
2. **Forge/écrasement** de n'importe quel record `*Partage` (record names déterministes : `user-<uuid>`, `joueur-<uuid>`, `equipe-<code>`) faute de Security Roles → usurpation + **escalade de rôle** à la jonction (un record forgé `roleRaw = coach` aurait accordé des privilèges coach sur l'appareil joignant).

> Note : le chemin de **consommation** historique (`recupererEtImporterEquipe` / `syncDepuisPublic`) n'était jamais appelé — la publication des credentials était donc purement vestigiale. Ces méthodes ont été supprimées au profit de `rejoindreEquipe`.

---

## 3. Correctif livré (code)

- **`publierUtilisateur` ne publie plus** `motDePasseHash` / `sel` / `iterations`. `UtilisateurPartage` ne contient que le **profil non sensible** (identifiant, prénom, nom, roleRaw, codeEcole, estActif, numero, posteRaw, joueurEquipeID, dateModification). Construction isolée dans `construireRecordUtilisateur(_:)` (testable).
- **Nouveau flux de jonction** `CloudKitSharingService.rejoindreEquipe(codeEquipe:identifiant:motDePasse:context:)` + `RejoindreEquipeView` (entrée « Rejoindre une équipe » dans `ChoixInitialView`). Le membre saisit code + identifiant + mot de passe ; le **hash est dérivé localement** sur son appareil (`KeyDerivation.hashPBKDF2` + sel généré, 600k itérations) — **aucun matériel dérivé du mot de passe ne transite par le réseau**.
- **Modèle « premier mot de passe tapé = le sien »** : le membre possède son mot de passe (le coach distribue un mot de passe initial suggéré hors-bande). Aucun tag de vérification n'est publié.
- **Clamp de rôle anti-escalade** : `roleJonctionAutorise(_:)` n'autorise que `.etudiant` / `.assistantCoach`. Tout `roleRaw` résolvant en `.coach` / `.admin` est **rejeté** — le rôle n'est jamais accordé en aveugle depuis un record réseau.
- **Tier publié sur `EquipePartagee`** : `tierAbonnementRaw` (non sensible) est désormais publié/importé pour que la gate d'accès laisse entrer les membres rejoignant sur un autre Apple ID quand le coach est abonné (l'`Abonnement` lui-même n'est pas synchronisé cross-Apple-ID). ⚠️ **Ajout de champ schéma** (additif/rétrocompatible) → redéployer le schéma Public en Production (cf. `CloudKit_Schema_Deployment.md`).

Gardes de régression : `PlaycoTests/CloudKitSharingServiceTests.swift`
(`publicationSansCredentials`, `roleJonctionAutoriseOK`, `roleJonctionAutoriseRejet`).

---

## 4. Actions humaines requises — CloudKit Dashboard (P0, non automatisables)

À effectuer dans [https://icloud.developer.apple.com/dashboard/](https://icloud.developer.apple.com/dashboard/), container `iCloud.Origo.Playco`, **environnements Development ET Production** :

### 4.1 Scrub des hash déjà exposés (incident de credentials)
Les hash déjà publiés **restent exposés** tant qu'ils ne sont pas supprimés — arrêter l'écriture ne suffit pas.
1. Onglet **Data** → record type `UtilisateurPartage`.
2. Supprimer les champs `motDePasseHash` / `sel` / `iterations` de tous les records (ou supprimer + republier le record type).
3. Traiter comme **exposition de credentials** : **faire tourner (rotation) les mots de passe athlètes/assistants hors-bande** (les regénérer via `IdentifiantsEquipeView` côté coach et les redistribuer).
   - ⚠️ La republication post-correctif (record names déterministes `user-<uuid>`) écrase les records des **membres locaux actuels** sans les champs hash, mais **pas** les records orphelins (membres partis) → suppression manuelle nécessaire.

### 4.2 Security Roles (write réservé au créateur)
Sans ça, retirer le hash d'un store toujours **world-writable** laisse la porte à la forge/escalade.
1. Onglet **Schema** → **Security Roles**.
2. Pour `EquipePartagee`, `UtilisateurPartage`, `JoueurPartage`, `EtablissementPartage` : rôle `_world` = **Read** uniquement (retirer Write/Create) ; **Creator** = Read/Write/Create.
3. Déployer en Production.

---

## 5. Risques résiduels acceptés

Après ce changement, **aucun matériel dérivé du mot de passe n'est publié** ; les hash sont dérivés localement sur chaque appareil à partir du mot de passe que le membre saisit (distribué hors-bande par le coach). Risques restants, acceptés :

1. **PII de mineurs world-readable** : la Public DB contient toujours noms, numéros, rôles, identifiants de connexion et code d'équipe, **énumérables par code d'équipe**. Atténué par la minimisation des champs publiés ; accepté en lieu d'une réécriture **CKShare** (ACL par participant), que le store SwiftData `.automatic` n'expose pas sans abandonner le mirroring CloudKit de SwiftData (effort disproportionné pour des données de roster non financières/médicales).
2. **Forge d'écriture** des records partagés : atténuée **uniquement** par les Security Roles (§4.2) — c'est une étape de déploiement, non garantie par le code applicatif.
3. **Rôle local épinglé** à la jonction (`.etudiant`/`.assistantCoach`), jamais accordé depuis un record réseau → pas d'escalade via record forgé.
4. **Rotation/désactivation côté coach ne se propage pas** aux membres ayant rejoint sur un autre Apple ID (pas de sync privée inter-Apple-ID) ; tout changement de credential doit être **redistribué hors-bande**. (Déjà non fonctionnel avant ce changement.)

---

## 6. À auditer (suivi)

- Confirmer qu'aucun autre champ sensible ne transite par la Public DB (revue des records `EquipePartagee` / `JoueurPartage` / `EtablissementPartage`).
- Évaluer une réduction supplémentaire de la PII publiée (ex. initiales/numéro au lieu du nom complet ; codes d'équipe non triviaux/non énumérables).
- Réévaluer **CKShare** si une exigence de revocation/rotation à distance ou de confidentialité renforcée émerge.
