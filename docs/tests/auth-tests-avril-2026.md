# Playco — Plan de tests manuels authentification

**Date :** 15 avril 2026
**Version cible :** Playco 1.9.x (TestFlight)
**Appareil de test :** iPad Air 13" M3
**Compte iCloud de test :** [À RENSEIGNER]
**Testeur :** [À RENSEIGNER]

---

## Contexte

Cette checklist valide les 16 scénarios critiques du flow d'authentification Playco après les correctifs des Sprints 1, 2, 3 (avril 2026). Chaque scénario doit passer avant le lancement officiel.

**Blockers de sécurité** : scénarios 7, 8, 10, 15, 16 — un échec sur l'un de ces scénarios bloque le lancement.

**Prérequis** :
- [ ] Build TestFlight 1.9.x installé sur l'iPad Air M3
- [ ] Compte iCloud de test actif (Settings → iCloud → Playco activé)
- [ ] Schéma CloudKit déployé en production (voir `docs/CloudKit_Schema_Deployment.md`)
- [ ] Sprints 1, 2, 3 appliqués (voir `Prompts_Sprint_Fixes_Avril_2026.md`)
- [ ] L'app a été désinstallée puis réinstallée pour partir d'un état propre

---

## Scénarios de tests

### 1. Deux athlètes avec le même nom → identifiants distincts

**Objectif** : valider le fix de collision d'identifiants dans le wizard (Prompt 4).

**Étapes** :
1. Lancer l'app (premier lancement)
2. ChoixInitialView → « Créer mon équipe »
3. Compléter le wizard jusqu'à l'étape 5 (Membres)
4. Ajouter **2 joueurs** : « Jean Dupont » et « Jean Dupont »
5. Finaliser le wizard
6. Profil → Organisation → Joueurs

**Attendu** :
- ☐ Le premier joueur a l'identifiant `jean.dupont`
- ☐ Le second joueur a l'identifiant `jean.dupont2`
- ☐ Aucun crash, aucun message d'erreur sur la finalisation

**Résultat** : ☐ PASS ☐ FAIL
**Notes** :

---

### 2. Wizard fermé à mi-parcours → reprise

**Objectif** : valider la reprise du wizard avec `configurationEnCours` (Prompt 15).

**Étapes** :
1. Désinstaller/réinstaller Playco
2. Lancer le wizard jusqu'à l'étape 4 (Équipe)
3. Tuer l'app (double-clic home, balayer vers le haut)
4. Relancer l'app

**Attendu** :
- ☐ L'app propose « Reprendre la configuration » ou « Recommencer »
- ☐ Si « Reprendre » : le wizard reprend à l'étape 4 avec les données saisies
- ☐ Si « Recommencer » : tout est effacé, retour ChoixInitialView

**Résultat** : ☐ PASS ☐ FAIL
**Notes** :

---

### 3. Login case-insensitive

**Objectif** : valider que la casse de l'identifiant est ignorée.

**Étapes** :
1. Créer un compte avec l'identifiant `jean.dupont`
2. Se déconnecter
3. Dans LoginView, saisir `Jean.Dupont` (avec majuscule)
4. Saisir le mot de passe correct
5. Tap « Connexion »

**Attendu** :
- ☐ Connexion réussie malgré la casse mixte
- ☐ Même comportement avec `JEAN.DUPONT`

**Résultat** : ☐ PASS ☐ FAIL
**Notes** :

---

### 4. Multi-équipes (coach avec 2 équipes)

**Objectif** : valider le scoping par `codeEquipeActif`.

**Étapes** :
1. Se connecter en tant que coach
2. Profil → « Créer une nouvelle équipe »
3. Créer une seconde équipe (ex : « Diablos B »)
4. Se déconnecter
5. Se reconnecter avec le même identifiant

**Attendu** :
- ☐ `SelectionEquipeView` s'affiche avec les 2 équipes listées
- ☐ Sélection d'une équipe → seules les données de cette équipe sont visibles
- ☐ Changement via Profil → retour `SelectionEquipeView`

**Résultat** : ☐ PASS ☐ FAIL
**Notes** :

---

### 5. Code équipe avec espaces et majuscules

**Objectif** : valider la normalisation dans RejoindreEquipeView (Prompt 15 fix 1).

**Étapes** :
1. Retour ChoixInitialView → « Rejoindre une équipe »
2. Saisir le code équipe avec des variations :
   - `diab26` (minuscules)
   - ` DIAB26 ` (espaces)
   - `Diab 26` (espace au milieu)
3. Tester les 3 variantes

**Attendu** :
- ☐ `diab26` → accepté, connexion réussie
- ☐ ` DIAB26 ` → accepté, connexion réussie
- ☐ `Diab 26` → le « 26 » fait partie du code, comportement variable — documenter

**Résultat** : ☐ PASS ☐ FAIL
**Notes** :

---

### 6. Athlète supprimé pendant session

**Objectif** : valider que la déconnexion est propre si l'utilisateur est supprimé côté serveur.

**Étapes** :
1. Athlète connecté sur device A
2. Coach supprime l'athlète sur device B
3. Device A : passer l'app en background puis au foreground
4. Observer le comportement

**Attendu** :
- ☐ Au retour foreground, détection de l'utilisateur manquant
- ☐ Déconnexion automatique avec message « Votre compte n'existe plus »
- ☐ Retour à `LoginView`

**Résultat** : ☐ PASS ☐ FAIL
**Notes** :

---

### 7. 🔒 5 tentatives échouées → verrouillage 5 min (BLOQUANT)

**Objectif** : valider le verrouillage progressif.

**Étapes** :
1. LoginView → saisir un identifiant valide + mauvais mot de passe
2. Répéter **5 fois** avec mauvais mot de passe
3. À la 6e tentative

**Attendu** :
- ☐ Après 5 échecs : message « Trop de tentatives. Compte verrouillé pendant 5 minute(s). »
- ☐ Bouton connexion désactivé pendant 5 minutes
- ☐ Compteur de temps restant affiché

**Résultat** : ☐ PASS ☐ FAIL
**Notes** :

---

### 8. 🔒 Verrouillage persistant après fermeture app (BLOQUANT)

**Objectif** : valider que le verrouillage survit au kill d'app (UserDefaults).

**Étapes** :
1. Déclencher un verrouillage (test 7)
2. Tuer l'app complètement
3. Relancer l'app
4. Aller à LoginView

**Attendu** :
- ☐ Le verrouillage est toujours actif
- ☐ Message de verrouillage avec temps restant correct

**Résultat** : ☐ PASS ☐ FAIL
**Notes** :

---

### 9. Mot de passe avec accents

**Objectif** : valider que les caractères UTF-8 fonctionnent dans le hash SHA-256.

**Étapes** :
1. Créer un compte avec un mot de passe contenant des accents : `motdepassé123`
2. Se déconnecter
3. Se reconnecter avec le même mot de passe

**Attendu** :
- ☐ Création du compte acceptée (nouveau pattern : min 8 chars + 1 chiffre)
- ☐ Connexion réussie avec le mot de passe à accents

**Résultat** : ☐ PASS ☐ FAIL
**Notes** :

---

### 10. 🔒 Identifiant avec emoji (BLOQUANT)

**Objectif** : valider que les caractères non-alphabétiques sont rejetés.

**Étapes** :
1. Créer un compte avec l'identifiant `jean.😊`
2. Observer le comportement

**Attendu** :
- ☐ Refus avec message d'erreur clair
- ☐ OU filtrage automatique de l'emoji (identifiant stocké sans emoji)
- ☐ Aucun crash

**Résultat** : ☐ PASS ☐ FAIL
**Notes** :

---

### 11. CloudKit sync multi-device

**Objectif** : valider la propagation des comptes créés.

**Étapes** :
1. Device A : créer un compte utilisateur
2. Attendre 30 secondes
3. Device B (même compte iCloud) : se connecter

**Attendu** :
- ☐ L'utilisateur créé sur A apparaît dans la liste des utilisateurs sur B
- ☐ Connexion possible avec le nouvel identifiant sur B
- ☐ Aucune erreur « Schema mismatch »

**Résultat** : ☐ PASS ☐ FAIL
**Notes** :

---

### 12. Race condition boot → session restaurée

**Objectif** : valider le fix de race condition (Prompt 3).

**Étapes** :
1. Se connecter avec un compte valide
2. Tuer l'app immédiatement (< 2 sec après la connexion)
3. Relancer l'app

**Attendu** :
- ☐ La session est restaurée (pas de retour à LoginView)
- ☐ Le compte reste connecté
- ☐ `attendreSyncInitiale` attend max 10 sec avant de restaurer

**Résultat** : ☐ PASS ☐ FAIL
**Notes** :

---

### 13. Wizard → auto-login → changement d'équipe → redéconnexion

**Objectif** : valider le flow end-to-end complet.

**Étapes** :
1. Désinstaller/réinstaller
2. Wizard complet (6 étapes)
3. Auto-login en fin de wizard
4. Profil → Créer une nouvelle équipe
5. Changer d'équipe via Profil
6. Déconnexion

**Attendu** :
- ☐ Aucun crash à aucune étape
- ☐ Transitions fluides (spring animations)
- ☐ Retour à ChoixInitialView après déconnexion

**Résultat** : ☐ PASS ☐ FAIL
**Notes** :

---

### 14. Session > 30 jours → auto-logout

**Objectif** : valider le fix d'expiration de session (Prompt 15).

**Étapes** :
1. Se connecter avec un compte
2. Utiliser une technique pour simuler 31 jours passés :
   - Option A : modifier l'heure système de l'iPad → avancer de 31 jours
   - Option B : modifier manuellement `sessionCreeeLe` via debugger Xcode à une date de -31 jours
3. Tuer/relancer l'app

**Attendu** :
- ☐ Déconnexion automatique au prochain `restaurerSession()`
- ☐ Message « Session expirée, veuillez vous reconnecter »
- ☐ Retour à LoginView

**Résultat** : ☐ PASS ☐ FAIL
**Notes** :

---

### 15. 🔒 Mot de passe < 8 chars → rejeté (BLOQUANT)

**Objectif** : valider la politique renforcée (Prompt 15 fix 4).

**Étapes** :
1. Wizard ou création de compte
2. Saisir un mot de passe `123456` (6 chars)
3. Saisir `monpass` (7 chars sans chiffre)
4. Saisir `monpass1` (8 chars avec chiffre)

**Attendu** :
- ☐ `123456` → refus « Le mot de passe doit contenir au moins 8 caractères. »
- ☐ `monpass` → refus « Le mot de passe doit contenir au moins 8 caractères. »
- ☐ `monpass1` → accepté
- ☐ Message d'erreur clair et en français

**Résultat** : ☐ PASS ☐ FAIL
**Notes** :

---

### 16. 🔒 Migration hash ancien compte sans sel (BLOQUANT)

**Objectif** : valider la migration transparente vers `sel + hashAlgorithme`.

**Étapes** :
1. Si possible, utiliser un compte créé en v0.7.x (avant l'introduction du sel)
2. Alternative : via Xcode, supprimer manuellement le champ `sel` d'un utilisateur en BD
3. Tenter une connexion avec cet utilisateur
4. Re-vérifier la BD après connexion

**Attendu** :
- ☐ La connexion réussit malgré l'absence de sel initial
- ☐ Après connexion, le hash est re-calculé avec sel et persisté
- ☐ La prochaine connexion utilise le nouveau hash + sel
- ☐ Aucun utilisateur existant n'est forcé à se déconnecter

**Résultat** : ☐ PASS ☐ FAIL
**Notes** :

---

## Rapport global

| # | Scénario | Résultat | Bloquant |
|---|---|---|---|
| 1 | Collision identifiants wizard | ☐ | Non |
| 2 | Reprise wizard inachevé | ☐ | Non |
| 3 | Login case-insensitive | ☐ | Non |
| 4 | Multi-équipes | ☐ | Non |
| 5 | Code équipe espaces/majuscules | ☐ | Non |
| 6 | Athlète supprimé pendant session | ☐ | Non |
| 7 | 5 tentatives → verrouillage | ☐ | **Oui** |
| 8 | Verrouillage persistant | ☐ | **Oui** |
| 9 | Mot de passe avec accents | ☐ | Non |
| 10 | Identifiant avec emoji | ☐ | **Oui** |
| 11 | CloudKit sync multi-device | ☐ | Non |
| 12 | Race condition boot | ☐ | Non |
| 13 | End-to-end flow complet | ☐ | Non |
| 14 | Session > 30 jours | ☐ | Non |
| 15 | Mot de passe < 8 chars | ☐ | **Oui** |
| 16 | Migration hash ancien compte | ☐ | **Oui** |

**Score** : _ / 16 PASS
**Bloquants** : _ / 5 PASS (doit être 5/5 pour lancer)

---

## Bugs identifiés pendant les tests

Lister ici les bugs découverts, par ordre de gravité. Créer un ticket dans `docs/tests/bugs-identifies.md` pour chaque.

| # | Sévérité | Scénario | Description | Status |
|---|---|---|---|---|
| — | — | — | — | — |

---

**Signature du testeur :** ________________
**Date de complétion :** ________________

*Document à archiver avant chaque release majeure.*
