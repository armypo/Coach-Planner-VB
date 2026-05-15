# Playco — Login unifié v2.0 (Plan)

## Context

Le système de connexion actuel est fragmenté en 3 flows (`ChoixInitialView` → `LoginView` OU `RejoindreEquipeView`) avec un système de **code équipe** (ex: `DIAB26`) que les athlètes et assistants doivent saisir en plus de leur identifiant + mot de passe. C'est une friction inutile : le coach doit partager 3 infos (code + id + mdp) à chaque athlète, et la saisie manuelle des mots de passe athlète par le coach alourdit le wizard de configuration.

**Objectif v2.0** : simplifier radicalement le flow.
- `ChoixInitialView` garde 2 boutons mais "Rejoindre une équipe" devient "Connexion"
- Flow "Créer mon équipe" inchangé (wizard 6 étapes)
- **Un seul `LoginView` unifié** : picker 3 rôles (Coach / Assistant / Athlète) + identifiant + mot de passe. Plus de code équipe en UI.
- **Identifiant auto-généré** au format `prenom.nom.XXXX` (4 chiffres aléatoires) — remplace le suffixe séquentiel actuel
- **Mot de passe athlète/assistant auto-généré** au format `LLLLL_DD` (5 lettres + underscore + 2 chiffres). Le coach n'a plus à inventer de mots de passe.
- **Credentials récupérables** par le coach via une nouvelle vue "Identifiants de l'équipe" (stockage chiffré dans la private CloudKit DB du coach)
- **Suppression de `RejoindreEquipeView`** côté UI, mais `codeEquipe` / `codeEcole` restent en interne (toujours utilisés par `FiltreParEquipe`, la gate paywall, le scoping de données)

**Cohérence avec le paywall v2.0** (cf. `paywall/PLAN.md`) : la gate sécurité centrale dans `PlaycoApp` (qui bloque un athlète si tier != `.club` ou un assistant si tier == `.aucun`) s'applique directement au nouveau `LoginView`. Le flow "Rejoindre" disparaît — la gate couvre désormais LoginView + restaurerSession uniquement.

---

## Décisions business validées

| Décision | Choix |
|---|---|
| **Boutons ChoixInitialView** | "Créer mon équipe" (inchangé) + "Connexion" (renommé depuis "Rejoindre") |
| **Picker rôles dans LoginView** | 3 tabs segmented : Coach (bleu) / Assistant (bleu clair) / Athlète (orange) |
| **Champs LoginView** | `identifiant` + `motDePasse` uniquement. **Plus de code équipe.** |
| **Format identifiant nouveaux users** | `prenom.nom.XXXX` — 4 chiffres aléatoires (10 000 combinaisons) |
| **Format mdp athlète/assistant auto-généré** | 5 lettres majuscules safe (sans I/O) + underscore + 2 chiffres safe (sans 0/1). Ex : `ABCDE_23` |
| **Format mdp coach** | Inchangé — choisi par le coach dans `ConfigProfilCoachView` (wizard étape 3) |
| **Affichage mdp après création** | Sheet au moment de la création + stockage chiffré récupérable via une vue "Identifiants de l'équipe" |
| **Role mismatch à la connexion** | Erreur explicite "Mauvais type de compte" + déconnexion automatique. Pattern : vérification post-auth. |
| **Migration IDs existants** | Aucune. Les users pré-v2.0 gardent `prenom.nom` / `prenom.nom2`, les nouveaux ont `prenom.nom.XXXX`. Login fonctionne pour les deux formats (lookup exact). |
| **RejoindreEquipeView** | Suppression du fichier. `codeEcole` sur Utilisateur et `codeEquipe` sur Equipe **restent** (utilisés par le scoping + paywall). |
| **Reset mot de passe** | Coach peut régénérer le mdp d'un athlète depuis "Identifiants de l'équipe" → nouveau mdp affiché + hash mis à jour + entrée chiffrée mise à jour |

---

## Architecture technique

### 1. Modèle `CredentialAthlete` (nouveau) — stockage mdp en clair chiffré

Ce modèle vit **uniquement dans la private CloudKit DB du coach**. Il n'est PAS publié via `CloudKitSharingService.publierEquipeComplete` (qui expose les JoueurEquipe publiquement pour la découverte).

`Playco/Models/CredentialAthlete.swift` :
```swift
@Model final class CredentialAthlete {
    var id: UUID = UUID()
    var utilisateurID: UUID = UUID()       // référence Utilisateur
    var joueurEquipeID: UUID? = nil        // référence JoueurEquipe (si athlète)
    var identifiant: String = ""           // pour affichage dans la vue Identifiants
    var motDePasseClair: String = ""       // stocké en clair dans private CloudKit (chiffré au transport et at-rest par Apple)
    var dateCreation: Date = Date()
    var dateModification: Date = Date()
    var codeEquipe: String = ""            // scoping par équipe (FiltreParEquipe)
}
extension CredentialAthlete: FiltreParEquipe {}
```

**Sécurité** :
- Apple chiffre automatiquement CloudKit private DB au transport (TLS) et at-rest (AES). Accessible seulement via l'Apple ID du coach.
- **Alternative évaluée et rejetée** : ajouter `motDePasseClair` sur `JoueurEquipe` ou `Utilisateur` — mais ces modèles sont publiés via `CloudKitSharingService`, donc visibles dans la public DB. Non conforme.
- Seul le coach avec accès à son Apple ID peut lire ces credentials. Apple gère l'isolation.

Tous les attributs avec default (piège CloudKit #15). `FiltreParEquipe` conformance pour scoping par équipe.

### 2. Modification `Models/Utilisateur.swift`

**Algorithme `genererIdentifiantUnique` modifié** (ligne 211) :
```swift
static func genererIdentifiantUnique(
    prenom: String,
    nom: String,
    context: ModelContext,
    exclusions: Set<String> = []
) -> String {
    let base = "\(prenom).\(nom)"
        .lowercased()
        .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
        .replacingOccurrences(of: " ", with: "-")
        .filter { $0.isLetter || $0 == "." || $0 == "-" }

    // Retry jusqu'à 1000 fois avec 4 chiffres aléatoires différents
    for _ in 0..<1000 {
        let suffixe = String(format: "%04d", Int.random(in: 0...9999))
        let candidat = "\(base).\(suffixe)"
        if !exclusions.contains(candidat) && identifiantDisponible(candidat, context: context) {
            return candidat
        }
    }

    // Fallback rare : UUID tronqué
    return base + "." + UUID().uuidString.prefix(4).lowercased()
}
```

**Nouvelle fonction `Utilisateur.genererMotDePasseAthlete()`** :
```swift
static func genererMotDePasseAthlete() -> String {
    // Alphabet sans I/O/L pour éviter confusion visuelle avec 1/0/1
    let lettres = "ABCDEFGHJKMNPQRSTUVWXYZ"
    let chiffres = "23456789"  // sans 0/1

    let partieLettres = String((0..<5).compactMap { _ in lettres.randomElement() })
    let partieChiffres = String((0..<2).compactMap { _ in chiffres.randomElement() })
    return "\(partieLettres)_\(partieChiffres)"
}
```

### 3. `ChoixInitialView.swift` (simplifié)

- Bouton 1 : "Créer mon équipe" (onConfigurer — **inchangé**)
- Bouton 2 : renommer de "Rejoindre une équipe" → "Connexion" (badge "Coach / Assistant / Athlète" en sous-titre) — callback renommé `onConnexion` qui route vers `LoginView`
- Supprimer toute référence à `onRejoindre`

### 4. `LoginView.swift` (redesign complet)

Structure actuelle a déjà un picker binaire Coach/Athlète (ligne 73-77). À étendre en **3 tabs segmentés** :

```swift
enum RoleLogin: String, CaseIterable {
    case coach, assistant, athlete

    var label: String { ... }       // "Coach" / "Assistant" / "Athlète"
    var couleur: Color { ... }       // bleu / bleu clair / orange
    var roleUtilisateur: RoleUtilisateur { ... }
    // coach → .coach (ou .admin, accepté), assistant → .assistantCoach, athlete → .etudiant
}

@State var roleSelectionne: RoleLogin = .coach
```

**Segmented Picker** en haut avec les 3 tabs stylés.

Champs :
- `identifiant` (inchangé, format lowercase, placeholder `prenom.nom.1234`)
- `motDePasse` (inchangé, toggle visibilité)

**Bouton "Connexion"** :
1. Appelle `authService.connexion(identifiant:motDePasse:context:)`
2. Si succès : **vérification role match** :
   ```swift
   guard let user = authService.utilisateurConnecte else { return }
   let rolesValides: [RoleUtilisateur] = {
       switch roleSelectionne {
       case .coach: return [.coach, .admin]
       case .assistant: return [.assistantCoach]
       case .athlete: return [.etudiant]
       }
   }()
   guard rolesValides.contains(user.role) else {
       authService.deconnexion()
       erreur = "Mauvais type de compte. Tu as sélectionné '\(roleSelectionne.label)' mais ton compte est '\(user.role.label)'."
       return
   }
   onConnecte()
   ```
3. La gate paywall centrale dans `PlaycoApp.appliquerGateTier()` (cf. paywall/PLAN.md) s'applique ensuite automatiquement.

**Supprimer** tous les champs/logique liés à code équipe dans cette vue (il n'y en a pas actuellement, juste confirmation).

### 5. Suppression `RejoindreEquipeView.swift`

- Supprimer le fichier `Playco/Views/Auth/RejoindreEquipeView.swift`
- Dans `PlaycoApp.swift` :
  - Supprimer `case .rejoindre` de l'enum `EcranLancement`
  - Supprimer le switch-case `.rejoindre` dans le body
  - Mettre à jour le callback `onRejoindre` de ChoixInitialView → il devient `onConnexion` qui route vers une nouvelle ou la même case `.login` OU directement on reste sur `.choixInitial` et on présente `LoginView` en sheet/push

**Décision UX** : `LoginView` est présenté depuis `ChoixInitialView` via un **NavigationLink / sheet** (non un nouvel écran `EcranLancement`). Ça évite d'ajouter une case.

Alternative : ajouter `case .login` dans `EcranLancement` (plus cohérent avec le flow actuel qui traite `.configuration` et `.rejoindre` comme des écrans plein écran). **À confirmer** — je propose `case .login` pour symétrie.

**En pratique** : renommer `.rejoindre` → `.login` dans l'enum et pointer la case vers `LoginView` au lieu de `RejoindreEquipeView`.

### 6. `ConfigMembresView.swift` — auto-génération mdp athlète + assistant

**Athlètes** (struct `JoueurTemp`) :
- Supprimer le champ `motDePasse` du formulaire (ligne 116-120)
- Auto-générer `motDePasse = Utilisateur.genererMotDePasseAthlete()` à la création du `JoueurTemp`
- `identifiant` auto-généré quand prenom/nom changent (déjà en place, mais utiliser la nouvelle `Utilisateur.genererIdentifiantUnique` — format `.XXXX`)
- **Afficher les mdp dans la carte athlète** une fois saisi prénom/nom : "Identifiant : `john.doe.4821`" · "Mot de passe : `ABCDE_23`" en monospaced

**Assistants** (struct `AssistantTemp`) :
- Même logique : mdp auto-généré, champ masqué, affiché dans la carte

**Finalisation wizard** (dans `ConfigurationView.finaliser()`) :
- Pour chaque joueur/assistant créé, créer en plus un `CredentialAthlete` record :
  ```swift
  let cred = CredentialAthlete()
  cred.utilisateurID = utilisateur.id
  cred.joueurEquipeID = joueur.id  // nil pour assistant
  cred.identifiant = idUnique
  cred.motDePasseClair = j.motDePasse  // plain
  cred.codeEquipe = codeEquipe
  modelContext.insert(cred)
  ```
- **Après `try? modelContext.save()`** : présenter `IdentifiantsRecapSheet` (nouvelle vue) listant tous les identifiants + mdp avec boutons copier/partager. Cette sheet est bloquante (l'utilisateur DOIT fermer explicitement, bouton "J'ai noté mes credentials").

### 7. `AjoutUtilisateurView.swift` — ajustement

- Pour `roleParDefaut == .etudiant` OU `.assistantCoach` :
  - Masquer SecureField mot de passe
  - Auto-générer `Utilisateur.genererMotDePasseAthlete()` en interne
  - Identifiant auto-généré via nouvelle `Utilisateur.genererIdentifiantUnique`
  - À la création, créer aussi un `CredentialAthlete` record
  - Afficher sheet récap (identifiant + mdp en clair + copier + partager)
- Pour `roleParDefaut == .coach` OU `.admin` :
  - Mot de passe manuel (inchangé)
  - Pas de CredentialAthlete créé (coach crée et mémorise son propre mdp)

### 8. Nouvelle vue `Views/Profil/IdentifiantsEquipeView.swift`

Accessible depuis `ProfilView > sectionOrganisation` via un nouveau bouton "Identifiants de l'équipe" (visible si estCoach).

**Contenu** :
- `@Query` sur `CredentialAthlete` filtré par codeEquipeActif
- Liste sectionnée : "Athlètes" (joueurEquipeID != nil) / "Assistants" (joueurEquipeID == nil)
- Chaque ligne : nom complet (fetch `Utilisateur` via `utilisateurID`) + identifiant monospaced + mdp monospaced + boutons
  - 📋 Copier identifiant
  - 📋 Copier mdp
  - 🔄 Régénérer mdp (confirmation alert → nouvelle gen → update Utilisateur.motDePasseHash + CredentialAthlete.motDePasseClair + sheet affichant le nouveau)
  - 📤 Partager (ShareSheet avec template "Salut X, voici tes accès Playco : identifiant: …, mdp: …")

**Template de partage** (string constante dans TextesPaywall ou nouveau TextesAuth) :
```
Salut [Prénom] ! Voici tes accès Playco :
Identifiant : [identifiant]
Mot de passe : [motDePasse]
Ouvre l'app, clique "Connexion", choisis "[Athlète|Assistant]" puis entre ces infos.
```

### 9. `ProfilView.swift` — ajout bouton "Identifiants de l'équipe"

Dans `sectionOrganisation` (ligne 183), ajouter un `boutonAction` :
```swift
boutonAction(icone: "key.fill", titre: "Identifiants de l'équipe",
             couleur: PaletteMat.violet) {
    afficherIdentifiantsEquipe = true
}
```
Avec `.sheet(isPresented: $afficherIdentifiantsEquipe) { IdentifiantsEquipeView() }`.

### 10. `PlaycoApp.swift` — modeles + enum

- Ajouter `CredentialAthlete.self` dans `PlaycoApp.modeles`
- Renommer `case .rejoindre` → `case .login` dans `EcranLancement`
- Supprimer `RejoindreEquipeView` du switch body, remplacer par `LoginView` directement OU laisser `LoginView` être ouvert en sheet depuis `ChoixInitialView`

**Au choix** : je recommande **renommer `.rejoindre` → `.login`** pour symétrie. LoginView devient l'écran plein écran au lieu d'être une sheet.

### 11. `AuthService.swift` — pas de changement fonctionnel

La vérification role se fait dans `LoginView` (post-auth) plutôt que dans `AuthService.connexion`. Rationale : la UI connaît le picker, AuthService reste générique et réutilisable pour la restauration session (qui ne passe pas par un picker).

---

## Fichiers — récapitulatif

### À créer (2)
- `Playco/Models/CredentialAthlete.swift`
- `Playco/Views/Profil/IdentifiantsEquipeView.swift`

### À modifier (7)
- `Playco/Models/Utilisateur.swift` — nouvelle `genererIdentifiantUnique` (format `.XXXX`) + nouvelle `genererMotDePasseAthlete`
- `Playco/Views/Auth/ChoixInitialView.swift` — renommer CTA "Rejoindre" → "Connexion", callback `onConnexion`
- `Playco/Views/Auth/LoginView.swift` — picker 3 tabs + post-auth role check
- `Playco/Views/Configuration/ConfigMembresView.swift` — masquer saisie mdp, afficher identifiant + mdp générés dans les cartes
- `Playco/Views/Configuration/ConfigurationView.swift` — `finaliser()` crée des `CredentialAthlete` + sheet récap
- `Playco/Views/Profil/AjoutUtilisateurView.swift` — auto-gen pour .etudiant / .assistantCoach + create CredentialAthlete + sheet récap
- `Playco/Views/Profil/ProfilView.swift` — bouton "Identifiants de l'équipe"
- `Playco/PlaycoApp.swift` — ajout `CredentialAthlete.self`, enum `.rejoindre` → `.login`

### À supprimer (1)
- `Playco/Views/Auth/RejoindreEquipeView.swift`

---

## Utilitaires réutilisés (DRY)

- `LiquidGlassKit` (rayons, espaces, animations)
- `PaletteMat` (couleurs par rôle)
- `GlassCard`, `GlassSection`, `GlassButtonStyle`
- `AuthService` existant (aucun changement signature)
- Pattern validation + erreur bannière de `LoginView` existant (garder tel quel)
- Pattern auto-gen identifiant `onChange(of: prenom/nom)` de `ConfigMembresView` (adapter avec nouvelle algo)
- `FiltreParEquipe` + `.filtreEquipe()` pour `CredentialAthlete`

---

## Interaction avec le paywall v2.0

Le plan `paywall/PLAN.md` prévoit :
- Une **gate sécurité centrale** dans `PlaycoApp.appliquerGateTier()` qui s'applique après login + restaurerSession
- Des checks : athlète → tier `.club` requis, assistant → tier `.pro`/`.club` requis

Avec le nouveau LoginView unifié :
- La gate s'applique **une seule fois** post-`LoginView.onConnecte()` (au lieu de couvrir LoginView + RejoindreEquipeView séparément)
- Le prompt paywall **P9** devient plus simple : "sheet bloquant welcome + accepter assistantCoach" sans modifier RejoindreEquipeView (elle n'existe plus)
- Le champ `codeEcole` sur Utilisateur reste la clé de lookup pour `fetchEquipeActive(user:)` dans la gate

**Ordre de déploiement recommandé** :
1. Implémenter ce plan (Login unifié) d'abord
2. Puis implémenter le paywall (qui assume que LoginView unifié existe)

---

## Vérification end-to-end

### Tests unitaires (cible ≥80%)
- `UtilisateurTests.genererIdentifiantUniqueFormat` : vérifie que le résultat match regex `^[a-z.-]+\.\d{4}$`
- `UtilisateurTests.genererIdentifiantUniqueCollision` : seed 10 users avec même prenom.nom → 10 identifiants distincts générés
- `UtilisateurTests.genererMotDePasseAthlete` : vérifie format `^[A-Z]{5}_[0-9]{2}$` + pas de I/O/L dans lettres + pas de 0/1 dans chiffres
- `CredentialAthleteTests` : création, FetchDescriptor par codeEquipe, round-trip save/fetch

### Tests manuels iPad (iPad Air 13" M3)
1. **ChoixInitialView** : 2 boutons "Créer" et "Connexion" (plus "Rejoindre")
2. **Wizard création** : coach invente son mdp à l'étape 3, crée 3 athlètes + 1 assistant à l'étape 5 → mdp auto-générés visibles dans les cartes (format `ABCDE_23`) → fin wizard → sheet récap avec toutes les identifiants + mdp
3. **Bouton "Tout partager"** dans sheet récap : ouvre ShareSheet avec texte formaté pour chaque athlète
4. **LoginView coach** : picker Coach + identifiant coach + mdp coach → connexion OK
5. **LoginView assistant** : picker Assistant + identifiant assistant (format `prenom.nom.1234`) + mdp (format `ABCDE_23`) → connexion OK → redirige vers app
6. **LoginView athlète** : picker Athlète + credentials → connexion OK (si tier Club de son coach) / erreur gate sinon
7. **Role mismatch** : picker Coach + credentials athlète → erreur "Mauvais type de compte" + reste sur LoginView
8. **ProfilView coach** : nouveau bouton "Identifiants de l'équipe" → liste athlètes/assistants avec copier/partager
9. **Régénérer mdp** : tap "Régénérer" sur un athlète → confirmation alert → nouveau mdp affiché → login athlète avec ancien mdp échoue → login avec nouveau mdp OK
10. **AjoutUtilisateurView athlète** (depuis ProfilView) : prenom + nom → identifiant auto-généré + mdp auto-généré → création → sheet récap
11. **AjoutUtilisateurView coach** (depuis ProfilView) : saisie manuelle mdp coach (inchangé)
12. **Users pré-v2.0** : identifiant `alice.martin` (sans .XXXX) → login OK (compat backward)

### Build
```
cd "/Users/armypo/Documents/Origotech/Playco" && xcodebuild -scheme "Playco" -destination 'platform=iOS Simulator,name=iPad Air 13-inch (M3)' build
```
Cible : 0 erreur, 0 warning.

### Code review MCP
- `detect_changes_tool` sur ChoixInitialView, LoginView, ConfigMembresView, ConfigurationView, AjoutUtilisateurView, ProfilView, Utilisateur, PlaycoApp
- `get_impact_radius_tool` sur `genererIdentifiantUnique` (caller sites)

---

## Pièges CLAUDE.md respectés

- **#15 CloudKit** : `CredentialAthlete` a tous les attributs avec defaults, pas de relation — safe
- **#11 FiltreParEquipe** : `CredentialAthlete` conforme, utilise `.filtreEquipe()` dans la vue Identifiants
- **#17 Logger** : tous les logs via `Logger(subsystem: "com.origotech.playco", category: "auth"/"credentials")`
- **#19 LiquidGlassKit** : aucun magic number dans les vues
- **#3 soft delete** : `CredentialAthlete` supprimé en cascade quand l'équipe est supprimée (via la fonction existante `supprimerEntites` dans ProfilView)

---

## Ce que cette v2.0 NE contient PAS

- Récupération mdp oublié côté athlète (pas de "Mot de passe oublié ?") — l'athlète contacte son coach qui régénère
- Biométrie / Face ID pour login — v2.1
- SSO (Apple / Google) — hors scope
- Password complexity configurable par le coach — le format auto est fixe

---

---

