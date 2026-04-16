# Audit de sécurité — Flux d'authentification Playco

**Date :** 15 avril 2026
**Version :** TestFlight v1.9.0
**Scope :** AuthService, LoginView, RejoindreEquipeView, ChoixInitialView, SelectionEquipeView, ConfigurationView, PlaycoApp, ProfilView

---

## 1. État général

**Le flux d'authentification est ROBUSTE avec d'excellentes pratiques de base**, mais contient **3 bugs identifiés** et plusieurs **edge cases non gérés** qui pourraient causer des problèmes avant le lancement de septembre 2026.

### Points forts confirmés

- **Hash SHA256 avec sel aléatoire 16-byte** (`AuthService.swift:84-97`)
- **Verrouillage persisté en UserDefaults avec escalade** (5 min → 15 min → 1h)
- **Session stockée en Keychain** avec migration depuis UserDefaults (`AuthService.swift:54-70`)
- **Validation d'équipe** dans `RejoindreEquipeView` avant connexion (`RejoindreEquipeView.swift:245-262`)
- **Suppression du secret session au logoff** (`AuthService.swift:274-277`)
- **Logger sans leak de mot de passe** (`AuthService.swift:190`)

---

## 2. Bugs identifiés

### 🔴 BUG #1 — CRITIQUE : Race condition au démarrage sur restauration de session

**Fichier :** `PlaycoApp.swift:150-151`

**Description :** `restaurerSession()` est appelée dans `.onAppear` de ContentView, MAIS la CloudKit sync n'est **pas** attendue. Si les données de l'utilisateur ne sont pas encore syncées du cloud vers le device, le fetch peut échouer silencieusement et l'utilisateur reste déconnecté.

**Scénario de reproduction :**
1. L'utilisateur se connecte via `RejoindreEquipeView` (sync cloud en cours)
2. Session sauvegardée dans le Keychain
3. L'app est tuée ou redémarrée avant que CloudKit finisse la sync
4. Au redémarrage, `restaurerSession()` cherche `Utilisateur` par UUID mais la ligne SwiftData n'existe pas encore
5. L'utilisateur est renvoyé à l'écran login

**Correctif suggéré :**

```swift
// PlaycoApp.swift:150-151
.onAppear {
    Task {
        // Attendre la sync CloudKit avant restauration
        try? await syncService.attendreSyncInitiale()
        authService.restaurerSession(context: container.mainContext)
        // reste du code...
    }
}
```

**Sévérité :** CRITIQUE — impact utilisateur direct au boot.

---

### 🟠 BUG #2 — HAUT : Double hash pendant la migration en cas d'échec de save

**Fichier :** `AuthService.swift:176-182`

**Description :** Si la migration du hash (ancien sans sel → nouveau avec sel) échoue à cause d'une exception SwiftData lors du `save()`, le password est re-hashé deux fois lors de la reconnexion suivante.

**Scénario de reproduction :**
1. Utilisateur ancien sans sel tente connexion
2. Migration lancée, hash recalculé avec sel
3. `context.save()` throw pour raison quelconque (disk full, CloudKit issue)
4. L'exception est silencieusement ignorée (`try?`)
5. Reconnexion : le motif "sel existe mais hash ne correspond pas" crée une boucle

**Correctif suggéré :**

```swift
if utilisateur.sel == nil || utilisateur.sel?.isEmpty == true {
    let nouveauSel = genererSel()
    let ancienSel = utilisateur.sel
    let ancienHash = utilisateur.motDePasseHash
    utilisateur.sel = nouveauSel
    utilisateur.motDePasseHash = hashMotDePasse(motDePasse, sel: nouveauSel)
    do {
        try context.save()
        logger.info("Migration hash réussie pour \(utilisateur.identifiant)")
    } catch {
        logger.error("Migration hash échouée: \(error)")
        // Rollback si save échoue
        utilisateur.sel = ancienSel
        utilisateur.motDePasseHash = ancienHash
        throw error
    }
}
```

**Sévérité :** HAUT — perte d'accès utilisateur en cas de disk full / CloudKit flaky.

---

### 🟡 BUG #3 — MOYEN : Collision d'identifiant athlète lors du wizard de configuration

**Fichier :** `ConfigurationView.swift:335`, `Utilisateur.swift:202-206`

**Description :** Durant la création d'athlètes dans le wizard (`ConfigurationView:324-352`), `genererIdentifiantUnique()` est appelé avec le contexte qui contient DÉJÀ les athlètes en mémoire (insérés mais pas encore sauvegardés). La vérification `identifiantDisponible()` cherche en BD et ne voit pas les insertions non-commitées → risque de doublon si deux athlètes ont le même nom.

**Scénario de reproduction :**
1. Coach crée 2 joueurs : "Jean Dupont" + "Jean Dupont"
2. Premier reçoit `jean.dupont`, inséré en mémoire
3. Deuxième : `identifiantDisponible("jean.dupont")` = true (pas encore en BD)
4. Deuxième reçoit aussi `jean.dupont` → conflit lors du save

**Correctif suggéré :**

```swift
// Dans finaliser() — maintenir un set d'ID en cours
var idsCreesEnMemoire = Set<String>()
for j in joueursTemp {
    var candidate = Utilisateur.genererIdentifiantUnique(
        prenom: j.prenom,
        nom: j.nom,
        context: modelContext
    )
    // Éviter doublons en mémoire
    var suffixe = 2
    let base = candidate
    while idsCreesEnMemoire.contains(candidate) {
        candidate = "\(base)\(suffixe)"
        suffixe += 1
    }
    idsCreesEnMemoire.insert(candidate)
    // puis créer utilisateur avec candidate...
}
```

**Sévérité :** MOYEN — onboarding cassé si doublon de nom, mais contournable par le coach.

---

## 3. Edge cases non gérés

### 3.1 Utilisateur supprimé pendant la session

Si l'utilisateur est marqué `estActif = false` sur un autre device via CloudKit, la session locale n'est pas invalidée.

**Fix suggéré :** ajouter un check dans un refresh périodique ou au foreground (`scenePhase == .active`).

### 3.2 Code équipe sensible à la casse

`RejoindreEquipeView.swift:193` normalise le code (`trimmingCharacters`) mais pas la case.
`ConfigurationView.swift:291` génère `.uppercased()`, mais une équipe créée pourrait avoir mixed-case.

**Risque :** "AbC123" vs "ABC123" sont différents → utilisateur rejet rejeté.

**Fix :** normaliser aussi en `.uppercased()` dans la validation.

### 3.3 Sel vide string vs nil

`AuthService.swift:108` vérifie `sel, !sel.isEmpty` mais `Utilisateur.swift:65` permet `sel: String? = nil`.

Si un ancien code met `sel = ""` (chaîne vide) au lieu de nil, la vérification du motif "old account" échoue.

**Fix :** utiliser `sel?.isEmpty ?? true` partout ou normer à nil uniquement.

### 3.4 Timing attack sur le message d'erreur login

`AuthService.swift:160` et `167` retournent le même message ("Identifiant ou mot de passe incorrect") mais le temps de réponse diffère si l'utilisateur n'existe pas vs mauvais password (présence d'un fetch).

**Risque :** Un attaquant peut énumérer les comptes en mesurant le temps.

**Fix :** ajouter un délai constant ou du dummy work si l'user n'existe pas.

### 3.5 Configuration incomplète si wizard fermé

`PlaycoApp.swift:99-104` : si l'utilisateur ferme l'app pendant le wizard et revient, il rejoint `.choixInitial` (pas d'état).

Un utilisateur peut relancer le wizard et créer une **DEUXIÈME** équipe si les données partielles restent.

**Fix :** marquer `ProfilCoach.configurationEnCours = true` et nettoyer si l'utilisateur change d'avis.

### 3.6 Pas de versioning du hash

Si vous migrez vers PBKDF2 plus tard, il y aura un conflit entre SHA256 + sel et PBKDF2.

**Fix :** ajouter un champ `hashAlgorithm: String = "SHA256+salt"` dans `Utilisateur`.

---

## 4. Recommandations d'amélioration

### 4.1 Session expiration

La session n'a **jamais d'expiration**. Ajouter une `sessionCreatedAt: Date` et auto-logout après 7-30 jours.

### 4.2 Password strength à la création

`AuthService.swift:227` vérifie juste `count >= 6`. Ajouter une regex : min 8 chars, min 1 uppercase, 1 chiffre.

### 4.3 Identifiant case-insensitive partout

Normaliser en `.lowercased()` AVANT toute comparaison (déjà fait en `AuthService.swift:146` ✓).

### 4.4 CloudKit conflict resolution

Si deux devices créent un user simultanément, SwiftData merge peut créer un doublon.

**Fix :** ajouter une migration pour détecter et nettoyer les doublons sur `identifiant` unique.

### 4.5 Champs vides/whitespace

`AuthService.swift:223` trim bien, mais dans `RejoindreEquipeView.swift:193-194` il y a trim.

**Fix :** ajouter une validation globale : aucun champ ne doit être only-whitespace.

### 4.6 Keystroke rate limiting

Aucun rate limiting sur les erreurs de typing (si attaquant spam les boutons).

**Fix :** ajouter debounce de 500 ms sur les boutons connexion.

---

## 5. Checklist de tests manuels pré-lancement

### Flux coach (`ConfigurationView` + `LoginView`)

- [ ] Créer équipe avec 2 athlètes ayant même nom → vérifier identifiants distincts
- [ ] Lancer config wizard, fermer l'app à étape 3 → relancer, vérifier state recovery
- [ ] Créer coach avec identifiant `Prenom.Nom` (majuscules) → login avec `prenom.nom` (minuscules) → doit fonctionner
- [ ] Créer coach puis changer mot de passe immédiatement → vérifier hash migré avec sel
- [ ] Multi-équipe : créer 2 équipes pour même coach → login puis choisir équipe → vérifier SelectionEquipeView auto-select si 1 seule

### Flux athlète (`RejoindreEquipeView`)

- [ ] Code équipe avec espaces → normalisation, ne doit pas rejeter
- [ ] Code équipe en minuscules (ABC123 fourni, athlète rentre abc123) → doit accepter ou refuser de façon consistante
- [ ] Athlète crée compte, rejoint équipe → puis ferme app → relancer → vérifier restauration session
- [ ] Athlète rejoint, puis coach supprime cet athlète de l'équipe → athlète redémarre app → doit déconnecter ou avertir
- [ ] Créer 100 athlètes au wizard → tous doivent avoir identifiant unique (pas de collision)

### Sécurité

- [ ] Login avec 5 tentatives échouées → verrouillage 5 min → tenter 5 fois de plus → verrouillage 15 min → vérifier escalade
- [ ] Fermer app pendant verrouillage, rouvrir → verrouillage persiste (UserDefaults)
- [ ] Vérifier Keychain : session token doit être uniquement lecture locale (pas iCloud, pas Backup)
- [ ] CloudKit : créer user sur device A, revenir à device B, syncer → user visiblement accessible

### Edge cases

- [ ] Entrer mot de passe avec accents (é, à, ç) → doit hasher correctement et login marcher
- [ ] Identifiant avec emoji ou caractères unicode → doit être filtré ou rejeté avec message clair

---

## Résumé risque

| Domaine | Sévérité | État |
|---------|----------|------|
| Hash + Sel | ✓ Robuste | OK |
| Verrouillage 5 tentatives | ✓ Robuste | OK |
| Session Keychain | ✓ Robuste | OK |
| Validation équipe | ⚠️ Race condition sync | **CRITIQUE** |
| Migration hash | ⚠️ Catch silencieux | **HAUT** |
| Collision identifiant config wizard | ⚠️ Doublon possible | **MOYEN** |
| Case sensitivity équipe | ⚠️ Inconsistance | BAS |
| Timing attack enum | ⚠️ Énumération user possible | BAS |

**Recommandation :** Corriger les 3 bugs (CRITIQUE + HAUT + MOYEN) avant TestFlight v1.10. Lancer les 16 tests manuels en parallèle sur iPad. Lancement septembre 2026 sûr après ces corrections.

---

*Audit généré le 15 avril 2026 · Playco v1.9.0*
