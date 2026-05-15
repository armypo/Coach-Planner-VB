# Playco — Login unifié v2.0 (Prompts d'implémentation)

Destination finale : `/Users/armypo/Documents/Origotech/Playco/login/PROMPTS.md`

Chaque prompt est **auto-suffisant** (copiable dans une session Claude Code fresh). Format standardisé :
- **Dépend de** : prompts à exécuter avant
- **Objectif** : une phrase
- **Fichiers** : create / modify / delete
- **Snippets** : code clé attendu
- **Critères** : acceptables et testables
- **Pièges** : CLAUDE.md + contexte Playco
- **Tests** : à écrire pendant le prompt

**Contexte global à rappeler à Claude** :
- Projet : Playco iOS/iPadOS (SwiftUI + SwiftData + CloudKit)
- Working dir : `/Users/armypo/Documents/Origotech/Playco`
- Plan : `/Users/armypo/Documents/Origotech/Playco/login/PLAN.md`
- Paywall plan lié : `/Users/armypo/Documents/Origotech/Playco/paywall/PLAN.md` — la gate centrale paywall s'applique post-login (cf. section "Interaction avec le paywall v2.0")
- CLAUDE.md projet pour conventions + pièges
- Build : `cd "/Users/armypo/Documents/Origotech/Playco" && xcodebuild -scheme "Playco" -destination 'platform=iOS Simulator,name=iPad Air 13-inch (M3)' build`
- Cible qualité : **0 erreur, 0 warning** (niveau v1.9.0)

**Ordre d'exécution** : L1 → L8 strict. Les dépendances sont explicitées dans chaque prompt.

**Note d'intégration paywall** : L1 ajoute le rôle `.assistantCoach` au modèle `Utilisateur` (sans les permissions associées, qui sont étendues par le prompt paywall P1). Si paywall P1 est déjà exécuté, l'ajout enum dans L1 est un no-op — détection via `RoleUtilisateur.allCases.contains { $0 == .assistantCoach }`.

---

## 🟩 L1 — Fondations Utilisateur (rôle + générateurs)

**Dépend de** : aucune.

**Objectif** : Ajouter le rôle `.assistantCoach` à `RoleUtilisateur`, remplacer l'algo `genererIdentifiantUnique` par le format `prenom.nom.XXXX`, et ajouter `genererMotDePasseAthlete` au format `ABCDE_23`.

**Fichiers à modifier** :
- `Playco/Models/Utilisateur.swift`

**Snippets attendus** :

1. Ajout case enum (ligne ~11-14 dans `enum RoleUtilisateur`) :
```swift
enum RoleUtilisateur: String, Codable, CaseIterable {
    case etudiant
    case coach             // coach admin payant
    case assistantCoach    // NOUVEAU — mêmes permissions que coach, gratuit
    case admin

    var label: String {
        switch self {
        case .etudiant: return "Élève"
        case .coach: return "Coach"
        case .assistantCoach: return "Coach assistant"
        case .admin: return "Admin"
        }
    }

    var icone: String {
        switch self {
        case .etudiant: return "graduationcap.fill"
        case .coach: return "figure.volleyball"
        case .assistantCoach: return "person.badge.shield.checkmark"
        case .admin: return "shield.checkered"
        }
    }

    var couleurHex: String {
        switch self {
        case .etudiant: return "#FF6B35"
        case .coach: return "#2563EB"
        case .assistantCoach: return "#4A8AF4"
        case .admin: return "#10B981"
        }
    }
}
```

2. Remplacement complet de `genererIdentifiantUnique` (ligne ~211) :
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

    // Si base vide (prenom/nom vides) → fallback immédiat
    guard !base.isEmpty, base != "." else {
        return "user." + String(format: "%04d", Int.random(in: 0...9999))
    }

    for _ in 0..<1000 {
        let suffixe = String(format: "%04d", Int.random(in: 0...9999))
        let candidat = "\(base).\(suffixe)"
        if !exclusions.contains(candidat) && identifiantDisponible(candidat, context: context) {
            return candidat
        }
    }

    // Fallback : UUID tronqué
    return base + "." + String(UUID().uuidString.prefix(4)).lowercased()
}
```

3. Nouvelle fonction statique `genererMotDePasseAthlete` (ajouter après `genererCodeInvitation` ligne ~186) :
```swift
/// Génère un mot de passe athlète/assistant au format `LLLLL_DD`
/// 5 lettres safe (sans I/L/O) + underscore + 2 chiffres safe (sans 0/1)
static func genererMotDePasseAthlete() -> String {
    let lettres = "ABCDEFGHJKMNPQRSTUVWXYZ"  // sans I, L, O
    let chiffres = "23456789"                 // sans 0, 1
    let partieLettres = String((0..<5).compactMap { _ in lettres.randomElement() })
    let partieChiffres = String((0..<2).compactMap { _ in chiffres.randomElement() })
    return "\(partieLettres)_\(partieChiffres)"
}
```

**Critères d'acceptation** :
- `RoleUtilisateur.allCases.count == 4` et contient `.assistantCoach`
- Regex identifiant : `^[a-z.-]+\.\d{4}$` sur 100 échantillons
- Regex mdp : `^[A-Z]{5}_[0-9]{2}$` sur 100 échantillons
- 10 appels `genererIdentifiantUnique("Jean", "Dupont", context:)` → 10 résultats distincts
- 1000 appels `genererMotDePasseAthlete()` → 0 occurrence de `I`/`L`/`O` dans lettres, 0 occurrence de `0`/`1` dans chiffres
- Build 0 erreur 0 warning

**Pièges** :
- **Pas de suppression du case `.coach`** (il reste le rôle coach admin payant)
- `identifiantDisponible` existant (ligne ~242) compatible avec n'importe quel format → marche pour legacy (`prenom.nom`) ET nouveau (`prenom.nom.XXXX`)
- L'extension `PermissionsRole.swift` pour `.assistantCoach` est faite par le prompt paywall P1 (hors scope de ce prompt) — si déjà faite, les permissions fonctionnent ; sinon, un assistant connecté ne pourra pas exécuter certaines actions tant que paywall P1 n'est pas exécuté

**Tests à écrire** (`PlaycoTests/UtilisateurIdentifiantTests.swift` — nouveau fichier) :
```swift
func testGenererIdentifiantFormatXXXX() { ... }
func testGenererIdentifiantCollisionResolue() { ... }
func testGenererIdentifiantPrenomNomVides() { ... } // fallback "user.XXXX"
func testGenererMotDePasseAthleteFormat() { ... }
func testGenererMotDePasseSansCaracteresAmbigus() { ... }
func testRoleUtilisateurAssistantCoachExiste() {
    XCTAssertTrue(RoleUtilisateur.allCases.contains(.assistantCoach))
}
```

---

## 🟩 L2 — Modèle CredentialAthlete

**Dépend de** : L1 (pour utiliser genererMotDePasseAthlete dans les tests)

**Objectif** : Créer le modèle SwiftData `CredentialAthlete` qui stocke les mdp en clair dans la private CloudKit DB du coach (chiffré by Apple at transport + at-rest), et l'enregistrer dans le schema de l'app.

**Fichiers à créer** :
- `Playco/Models/CredentialAthlete.swift`

**Fichiers à modifier** :
- `Playco/PlaycoApp.swift` (ajout au schema uniquement)

**Snippets attendus** :

`CredentialAthlete.swift` complet :
```swift
//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftData

/// Stocke en clair les mots de passe auto-générés des athlètes et assistants
/// pour permettre au coach de les récupérer après création.
///
/// **Sécurité** : ce modèle vit UNIQUEMENT dans la private CloudKit DB du coach
/// (chiffré par Apple at transport + at-rest). Il N'EST PAS publié via
/// `CloudKitSharingService.publierEquipeComplete` — à préserver strictement.
@Model final class CredentialAthlete {
    var id: UUID = UUID()
    var utilisateurID: UUID = UUID()
    var joueurEquipeID: UUID? = nil           // nil pour assistants
    var identifiant: String = ""
    var motDePasseClair: String = ""
    var dateCreation: Date = Date()
    var dateModification: Date = Date()
    var codeEquipe: String = ""

    init(utilisateurID: UUID,
         joueurEquipeID: UUID? = nil,
         identifiant: String,
         motDePasseClair: String,
         codeEquipe: String) {
        self.id = UUID()
        self.utilisateurID = utilisateurID
        self.joueurEquipeID = joueurEquipeID
        self.identifiant = identifiant
        self.motDePasseClair = motDePasseClair
        self.codeEquipe = codeEquipe
        self.dateCreation = Date()
        self.dateModification = Date()
    }
}

extension CredentialAthlete: FiltreParEquipe {}
```

Dans `PlaycoApp.swift`, ajouter dans `PlaycoApp.modeles` (ligne ~24-36) :
```swift
CategorieExercice.self, StaffPermissions.self,
CredentialAthlete.self    // ← ajout
```

**Critères d'acceptation** :
- Build 0 erreur 0 warning
- Grep `"CredentialAthlete"` dans `Services/CloudKitSharingService.swift` → 0 résultat (jamais publié publiquement)
- `FetchDescriptor<CredentialAthlete>()` ne crash pas au premier launch (default empty)
- Tous attributs avec default (piège #15 CloudKit)

**Pièges** :
- **NE PAS** ajouter `CredentialAthlete` dans `CloudKitSharingService.publierEquipeComplete` (sinon les mdp fuient en public DB)
- Le ModelContainer doit gérer la migration automatique (ajout @Model sans champs obligatoires = safe)

**Tests à écrire** (`PlaycoTests/CredentialAthleteTests.swift`) :
```swift
func testCreationAvecDefaults() { ... }
func testRoundTripSaveFetch() { ... }
func testFiltreParEquipe() { ... } // via .filtreEquipe()
```

---

## 🟩 L3 — Flow unifié : ChoixInitial + LoginView picker 3 tabs + suppression RejoindreEquipe

**Dépend de** : L1 (nécessite `.assistantCoach` dans l'enum)

**Objectif** : Simplifier `ChoixInitialView` (2e bouton "Connexion"), étendre `LoginView` avec un picker 3 tabs + post-auth role check, supprimer `RejoindreEquipeView`, renommer enum `.rejoindre` → `.login`.

**Fichiers à modifier** :
- `Playco/Views/Auth/ChoixInitialView.swift`
- `Playco/Views/Auth/LoginView.swift`
- `Playco/PlaycoApp.swift`

**Fichiers à supprimer** :
- `Playco/Views/Auth/RejoindreEquipeView.swift`

**Snippets attendus** :

### 3a. `ChoixInitialView.swift`
Renommer callback et texte :
```swift
// Avant : var onRejoindre: () -> Void
var onConnexion: () -> Void

// Bouton 2 (ligne ~58) :
Button { onConnexion() } label: {
    VStack {
        Image(systemName: "person.fill.badge.plus")  // ou l'existante
        Text("Connexion")
            .font(.headline)
        Text("Coach · Assistant · Athlète")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
```

### 3b. `LoginView.swift` — enum interne + picker 3 tabs + post-auth check

Ajouter en haut du fichier (extérieur au body) :
```swift
enum RoleLogin: String, CaseIterable, Identifiable {
    case coach, assistant, athlete
    var id: String { rawValue }
    var label: String {
        switch self {
        case .coach: return "Coach"
        case .assistant: return "Assistant"
        case .athlete: return "Athlète"
        }
    }
    var couleur: Color {
        switch self {
        case .coach: return PaletteMat.bleu
        case .assistant: return Color(hex: "#7FB0F7")
        case .athlete: return PaletteMat.orange
        }
    }
    var rolesValides: [RoleUtilisateur] {
        switch self {
        case .coach: return [.coach, .admin]
        case .assistant: return [.assistantCoach]
        case .athlete: return [.etudiant]
        }
    }
}
```

Dans le struct `LoginView` :
```swift
@State private var roleSelectionne: RoleLogin = .coach
```

Remplacer le toggle binaire actuel (ligne ~73-77) par :
```swift
Picker("Type de compte", selection: $roleSelectionne) {
    ForEach(RoleLogin.allCases) { r in
        Text(r.label).tag(r)
    }
}
.pickerStyle(.segmented)
.tint(roleSelectionne.couleur)
.padding(.horizontal)
```

Modifier l'action du bouton "Connexion" pour ajouter le post-auth check :
```swift
Button {
    authService.connexion(identifiant: identifiant, motDePasse: motDePasse, context: modelContext)
    // AuthService peuple utilisateurConnecte si succès
    if let user = authService.utilisateurConnecte {
        guard roleSelectionne.rolesValides.contains(user.role) else {
            let roleReel = user.role.label
            authService.deconnexion()
            authService.erreur = "Mauvais type de compte. Tu as sélectionné '\(roleSelectionne.label)' mais ton compte est '\(roleReel)'. Sélectionne le bon type et réessaie."
            return
        }
        onConnecte()
    }
} label: { ... }
```

Placeholder identifiant : `"prenom.nom.1234"`.

### 3c. `PlaycoApp.swift`

Enum `EcranLancement` :
```swift
enum EcranLancement {
    case chargement
    case choixInitial
    case configuration
    case login         // ← renommé depuis .rejoindre
    case app
}
```

Switch body : remplacer le case `.rejoindre` (ligne ~150-165) par :
```swift
case .login:
    LoginView(
        onRetour: {
            withAnimation { ecranActif = .choixInitial }
        },
        onConnecte: {
            withAnimation(LiquidGlassKit.springDefaut) {
                ecranActif = .app
            }
        }
    )
    .environment(authService)
    .environment(syncService)
    .environment(sharingService)
    .modelContainer(container)
    .transition(.move(edge: .trailing).combined(with: .opacity))
```

Appel `ChoixInitialView` : changer `onRejoindre:` → `onConnexion:` avec animation vers `.login`.

### 3d. Supprimer `RejoindreEquipeView.swift`
- `rm Playco/Views/Auth/RejoindreEquipeView.swift` (via l'outil Bash ou manuel)
- Vérifier aucune référence orpheline : `grep -r "RejoindreEquipeView" Playco/` → 0 résultat

**Critères d'acceptation** :
- Build 0 erreur 0 warning
- Navigation ChoixInitial → Login → App → logout → ChoixInitial fonctionne
- Picker 3 tabs visible, couleur d'accent change selon sélection
- Role mismatch : Coach tab + credentials athlète → erreur "Mauvais type de compte", reste sur LoginView, champs gardés
- Ancien coach (`prenom.nom` legacy) peut se logger via Coach tab → accès app OK

**Pièges** :
- `LoginView` a déjà une propriété `onConnecte` + `onRetour` ? Vérifier avant de les recréer
- Le picker `.segmented` peut être tronqué sur petits écrans → tester iPhone landscape
- Vérifier qu'aucun `.sheet(isPresented:)` dans d'autres vues ne réfère `RejoindreEquipeView`

**Tests manuels à faire** :
1. Ouvrir app fresh → ChoixInitial → "Connexion" → LoginView avec picker
2. Coach tab + credentials coach valides → onConnecte → app
3. Coach tab + credentials athlète (test legacy user) → erreur + reste sur LoginView
4. Retour → ChoixInitial

---

## 🟩 L4 — Wizard : ConfigMembresView auto-gen + ConfigurationView.finaliser + IdentifiantsRecapSheet

**Dépend de** : L1 (générateurs) + L2 (CredentialAthlete).

**Objectif** : Dans le wizard de création, auto-générer les mdp athlètes/assistants dès saisie prénom/nom, créer les `CredentialAthlete` à la finalisation, présenter une sheet bloquante récap avant d'entrer dans l'app.

**Fichiers à modifier** :
- `Playco/Views/Configuration/ConfigMembresView.swift`
- `Playco/Views/Configuration/ConfigurationView.swift`

**Fichiers à créer** :
- `Playco/Views/Configuration/IdentifiantsRecapSheet.swift`

**Snippets attendus** :

### 4a. `ConfigMembresView.swift`

Struct `JoueurTemp` (dans `ConfigurationView.swift` ligne 513) — init pré-rempli :
```swift
struct JoueurTemp: Identifiable {
    let id = UUID()
    var prenom = ""
    var nom = ""
    var numero: Int = 1
    var poste: PosteJoueur = .recepteur
    var identifiant = ""
    var motDePasse = Utilisateur.genererMotDePasseAthlete()  // ← auto-gen
}

struct AssistantTemp: Identifiable {
    let id = UUID()
    var prenom = ""
    var nom = ""
    var courriel = ""
    var role: RoleAssistant = .assistantCoach
    var identifiant = ""
    var motDePasse = Utilisateur.genererMotDePasseAthlete()  // ← auto-gen
}
```

Dans `ConfigMembresView` :
- Supprimer le SecureField mdp (ligne ~116-120) pour athlètes et assistants
- Remplacer par un affichage clair monospace :
```swift
VStack(alignment: .leading, spacing: 4) {
    HStack(spacing: 6) {
        Image(systemName: "person.text.rectangle")
            .foregroundStyle(.secondary)
            .font(.caption)
        Text(joueur.identifiant.wrappedValue.isEmpty ? "identifiant auto" : joueur.identifiant.wrappedValue)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)
    }
    HStack(spacing: 6) {
        Image(systemName: "key.fill")
            .foregroundStyle(.secondary)
            .font(.caption)
        Text(joueur.motDePasse.wrappedValue)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)
    }
}
```
- `autoId` (ligne 127-135) : utiliser `Utilisateur.genererIdentifiantUnique(prenom:nom:context:exclusions:)` avec modelContext (injecté via `@Environment(\.modelContext)`)

### 4b. `ConfigurationView.swift` — `finaliser()`

Dans la boucle joueurs (ligne 343-379), après insertion Utilisateur :
```swift
let cred = CredentialAthlete(
    utilisateurID: utilisateur.id,
    joueurEquipeID: joueur.id,
    identifiant: idJoueur,
    motDePasseClair: j.motDePasse,
    codeEquipe: codeEquipe
)
modelContext.insert(cred)
```

Idem dans la boucle assistants (ligne 308-341) avec `joueurEquipeID: nil`.

Après `try? modelContext.save()` ET auto-login (ligne ~423-444), **avant** `Task { publier CloudKit }` et `onTermine()` :

Ajouter aux @State de ConfigurationView :
```swift
@State private var afficherRecap = false
@State private var credsRecap: [CredentialRecap] = []

struct CredentialRecap: Identifiable {
    let id = UUID()
    let nomComplet: String
    let identifiant: String
    let motDePasse: String
    let role: String  // "Athlète" / "Assistant"
}
```

À la fin de `finaliser()`, peupler `credsRecap` :
```swift
credsRecap = joueursTemp.map { j in
    CredentialRecap(
        nomComplet: "\(j.prenom) \(j.nom)",
        identifiant: /* idJoueur correspondant — retrouver via mapping */,
        motDePasse: j.motDePasse,
        role: "Athlète"
    )
} + assistants.map { a in ... role: "Assistant" ... }
afficherRecap = true
```

**Attention** : il faut préserver les `identifiantsGeneres` dans un dictionnaire `[UUID: String]` pendant la boucle de création pour pouvoir les retrouver après.

Ajouter sheet sur le body :
```swift
.sheet(isPresented: $afficherRecap) {
    IdentifiantsRecapSheet(creds: credsRecap) {
        afficherRecap = false
        onTermine()
    }
    .interactiveDismissDisabled(true)
}
```

### 4c. `IdentifiantsRecapSheet.swift`
```swift
struct IdentifiantsRecapSheet: View {
    let creds: [ConfigurationView.CredentialRecap]
    let onFermer: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Note ces identifiants maintenant", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                    Text("Tu pourras aussi les retrouver dans Paramètres → Identifiants de l'équipe.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(creds) { cred in
                        carteCredential(cred)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Identifiants créés")
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        onFermer()
                    } label: {
                        Label("J'ai noté mes credentials", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(PaletteMat.orange, in: Capsule())
                            .foregroundStyle(.white)
                            .font(.headline)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func carteCredential(_ cred: ConfigurationView.CredentialRecap) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(cred.nomComplet).font(.headline)
            Label("Identifiant : \(cred.identifiant)", systemImage: "person.text.rectangle")
                .font(.system(.caption, design: .monospaced))
            Label("Mot de passe : \(cred.motDePasse)", systemImage: "key.fill")
                .font(.system(.caption, design: .monospaced))
            HStack {
                Button {
                    UIPasteboard.general.string = "Identifiant: \(cred.identifiant)\nMot de passe: \(cred.motDePasse)"
                } label: {
                    Label("Copier", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                ShareLink(item: "Salut ! Voici tes accès Playco : identifiant \(cred.identifiant), mot de passe \(cred.motDePasse). Ouvre l'app, clique Connexion, choisis \(cred.role), puis entre ces infos.") {
                    Label("Partager", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .glassCard()
    }
}
```

**Critères d'acceptation** :
- Créer 3 joueurs et 1 assistant → fin wizard → sheet récap affiche 4 credentials
- Chaque ligne copiable + partageable
- Sheet bloquante (pas de swipe-to-dismiss, pas de X)
- Après clic "J'ai noté" → app ouverte
- 4 `CredentialAthlete` records présents en BD (`FetchDescriptor` vérifie)

**Pièges** :
- `interactiveDismissDisabled(true)` sur la sheet, pas sur le contenu
- Les identifiants générés dans la boucle doivent être MÉMORISÉS (en `idsCreesEnMemoire` existant OU dictionnaire dédié) pour les retrouver au moment du récap
- Piège #19 : LiquidGlassKit pour rayons/espaces

---

## 🟩 L5 — AjoutUtilisateurView : auto-gen + CredentialAthlete + sheet récap

**Dépend de** : L1 (générateurs) + L2 (CredentialAthlete) + L4 (IdentifiantsRecapSheet réutilisé)

**Objectif** : Quand le coach ajoute un élève ou assistant depuis Paramètres, auto-générer identifiant + mdp, créer CredentialAthlete, afficher sheet récap 1-item.

**Fichiers à modifier** :
- `Playco/Views/Profil/AjoutUtilisateurView.swift`

**Snippets attendus** :

Ajout de computed :
```swift
private var estRoleAutoGen: Bool {
    roleParDefaut == .etudiant || roleParDefaut == .assistantCoach
}
```

Dans `init` (ou `onAppear`), pré-remplir pour roles auto-gen :
```swift
.onAppear {
    if estRoleAutoGen {
        motDePasse = Utilisateur.genererMotDePasseAthlete()
    }
}
.onChange(of: prenom) { autoRefreshIdentifiant() }
.onChange(of: nom) { autoRefreshIdentifiant() }

private func autoRefreshIdentifiant() {
    if estRoleAutoGen, !prenom.isEmpty, !nom.isEmpty {
        identifiant = Utilisateur.genererIdentifiantUnique(
            prenom: prenom, nom: nom, context: modelContext
        )
    }
}
```

Dans la section mot de passe (ligne ~109-134), wrapper :
```swift
if estRoleAutoGen {
    // Affichage monospace, pas de saisie
    HStack {
        Image(systemName: "key.fill").foregroundStyle(.secondary)
        Text(motDePasse)
            .font(.system(.callout, design: .monospaced))
            .foregroundStyle(.primary)
        Spacer()
        Button {
            motDePasse = Utilisateur.genererMotDePasseAthlete()
        } label: {
            Image(systemName: "dice")
                .foregroundStyle(.secondary)
        }
    }
    .padding(12)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
} else {
    // SecureField coach/admin existant (inchangé)
}
```

Dans `creerCompte` (ligne 336-425), après le save d'Utilisateur, pour roles auto-gen :
```swift
if estRoleAutoGen {
    let cred = CredentialAthlete(
        utilisateurID: nouvelUtilisateur.id,
        joueurEquipeID: nil,
        identifiant: identifiantFinal,
        motDePasseClair: motDePasse,
        codeEquipe: codeEcole
    )
    context.insert(cred)
    try? context.save()

    credACopier = [ConfigurationView.CredentialRecap(
        nomComplet: "\(prenom) \(nom)",
        identifiant: identifiantFinal,
        motDePasse: motDePasse,
        role: roleParDefaut == .etudiant ? "Athlète" : "Assistant"
    )]
    afficherRecap = true
} else {
    dismiss()
}
```

Ajouter state + sheet :
```swift
@State private var afficherRecap = false
@State private var credACopier: [ConfigurationView.CredentialRecap] = []

.sheet(isPresented: $afficherRecap) {
    IdentifiantsRecapSheet(creds: credACopier) {
        afficherRecap = false
        dismiss()
    }
    .interactiveDismissDisabled(true)
}
```

**Critères d'acceptation** :
- `.etudiant` : création → sheet récap 1-item → dismiss → retour Paramètres
- `.assistantCoach` : même comportement
- `.coach` / `.admin` : saisie manuelle préservée, aucune sheet récap
- `CredentialAthlete` créé en BD pour roles auto-gen uniquement

**Pièges** :
- Le flux actuel `AjoutUtilisateurView.creerCompte` crée un `Utilisateur`, pas de `JoueurEquipe` (c'est ConfigMembresView qui gère ça). Donc `joueurEquipeID: nil` est correct ici même pour un athlète — il sera créé plus tard si le coach l'associe à un JoueurEquipe via une autre vue.
- `roleParDefaut` peut être `.assistantCoach` depuis ProfilView — vérifier que le sélecteur de rôle dans AjoutUtilisateurView n'override pas avec `.coach`

---

## 🟩 L6 — IdentifiantsEquipeView + intégration ProfilView

**Dépend de** : L2 (CredentialAthlete).

**Objectif** : Nouvelle vue liste credentials de l'équipe avec copier/partager/régénérer mdp. Bouton d'accès dans ProfilView section Organisation.

**Fichiers à créer** :
- `Playco/Views/Profil/IdentifiantsEquipeView.swift`

**Fichiers à modifier** :
- `Playco/Views/Profil/ProfilView.swift`

**Snippets attendus** :

### 6a. `IdentifiantsEquipeView.swift`
```swift
import SwiftUI
import SwiftData

struct IdentifiantsEquipeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Environment(AuthService.self) private var authService

    @Query private var credentials: [CredentialAthlete]
    @Query private var utilisateurs: [Utilisateur]

    private var credsFiltres: [CredentialAthlete] {
        credentials.filtreEquipe(codeEquipeActif)
    }
    private var athletes: [CredentialAthlete] {
        credsFiltres.filter { $0.joueurEquipeID != nil }
    }
    private var assistants: [CredentialAthlete] {
        credsFiltres.filter { $0.joueurEquipeID == nil }
    }

    @State private var afficherNouveauMdp: (nom: String, mdp: String)? = nil

    var body: some View {
        List {
            Section("Athlètes (\(athletes.count))") {
                ForEach(athletes) { cred in ligneCredential(cred) }
            }
            Section("Assistants (\(assistants.count))") {
                ForEach(assistants) { cred in ligneCredential(cred) }
            }
        }
        .navigationTitle("Identifiants de l'équipe")
        .sheet(item: Binding(
            get: { afficherNouveauMdp.map { MdpWrapper(nom: $0.nom, mdp: $0.mdp) } },
            set: { _ in afficherNouveauMdp = nil }
        )) { wrapper in
            nouveauMdpSheet(wrapper: wrapper)
        }
    }

    private func ligneCredential(_ cred: CredentialAthlete) -> some View {
        let user = utilisateurs.first { $0.id == cred.utilisateurID }
        return VStack(alignment: .leading, spacing: 8) {
            Text(user?.nomComplet ?? "—").font(.headline)
            HStack {
                Text("ID :").font(.caption).foregroundStyle(.secondary)
                Text(cred.identifiant).font(.system(.caption, design: .monospaced))
                Spacer()
                Button { UIPasteboard.general.string = cred.identifiant }
                    label: { Image(systemName: "doc.on.doc").font(.caption) }
            }
            HStack {
                Text("Mdp :").font(.caption).foregroundStyle(.secondary)
                Text(cred.motDePasseClair).font(.system(.caption, design: .monospaced))
                Spacer()
                Button { UIPasteboard.general.string = cred.motDePasseClair }
                    label: { Image(systemName: "doc.on.doc").font(.caption) }
            }
            HStack {
                Button {
                    regenererMdp(cred: cred, user: user)
                } label: {
                    Label("Régénérer mdp", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                Spacer()
                ShareLink(item: templateTexte(cred: cred, user: user)) {
                    Label("Partager", systemImage: "square.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    private func regenererMdp(cred: CredentialAthlete, user: Utilisateur?) {
        guard let user = user else { return }
        let nouveauMdp = Utilisateur.genererMotDePasseAthlete()
        let nouveauSel = authService.genererSel()
        user.sel = nouveauSel
        user.motDePasseHash = authService.hashMotDePasse(nouveauMdp, sel: nouveauSel)
        user.iterations = AuthService.iterationsParDefaut
        cred.motDePasseClair = nouveauMdp
        cred.dateModification = Date()
        try? modelContext.save()
        afficherNouveauMdp = (nom: user.nomComplet, mdp: nouveauMdp)
    }

    private func templateTexte(cred: CredentialAthlete, user: Utilisateur?) -> String {
        let prenom = user?.prenom ?? ""
        let role = cred.joueurEquipeID == nil ? "Assistant" : "Athlète"
        return """
        Salut \(prenom) ! Voici tes accès Playco :
        Identifiant : \(cred.identifiant)
        Mot de passe : \(cred.motDePasseClair)

        Ouvre l'app Playco, clique "Connexion", choisis "\(role)", puis entre ces infos.
        """
    }

    private func nouveauMdpSheet(wrapper: MdpWrapper) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "key.fill")
                .font(.system(size: 60))
                .foregroundStyle(PaletteMat.orange)
            Text("Nouveau mot de passe pour \(wrapper.nom)")
                .font(.headline)
            Text(wrapper.mdp)
                .font(.system(.title2, design: .monospaced, weight: .bold))
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            Text("L'ancien mot de passe ne fonctionne plus. Partage le nouveau à la personne concernée.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            HStack {
                Button { UIPasteboard.general.string = wrapper.mdp } label: {
                    Label("Copier", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
                ShareLink(item: wrapper.mdp) {
                    Label("Partager", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .presentationDetents([.medium])
    }

    struct MdpWrapper: Identifiable {
        let id = UUID()
        let nom: String
        let mdp: String
    }
}
```

### 6b. `ProfilView.swift`

Dans `sectionOrganisation` (ligne ~183), ajouter après les 3 `boutonAction` existants :
```swift
boutonAction(icone: "key.fill",
             titre: "Identifiants de l'équipe",
             couleur: PaletteMat.violet) {
    afficherIdentifiantsEquipe = true
}
```

Ajouter state à côté des autres @State (vers ligne 177) :
```swift
@State private var afficherIdentifiantsEquipe = false
```

Ajouter sheet sur le body `sectionOrganisation` :
```swift
.sheet(isPresented: $afficherIdentifiantsEquipe) {
    NavigationStack {
        IdentifiantsEquipeView()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { afficherIdentifiantsEquipe = false }
                }
            }
    }
    .environment(authService)
}
```

**Critères d'acceptation** :
- Bouton "Identifiants de l'équipe" visible dans Organisation (coach seulement via `estCoach` guard existant)
- Liste filtre bien par équipe active
- Tap Régénérer → confirmation (implicite par le bouton) → nouveau mdp généré → sheet affiche → l'ancien mdp ne permet plus le login
- Template partage inclut le nom, l'identifiant, le mdp, et le rôle (Athlète/Assistant)

**Pièges** :
- `AuthService.hashMotDePasse` existe déjà (ligne 105) — le réutiliser, ne pas réimplémenter
- Le sel doit être régénéré en même temps que le hash (sinon collision avec ancien)
- `user.iterations = AuthService.iterationsParDefaut` pour migration PBKDF2
- `.environment(authService)` doit être propagé à la sheet (sinon crash `Environment`)

**Tests manuels** :
1. Créer équipe avec 2 athlètes + 1 assistant → ouvrir Paramètres → "Identifiants de l'équipe" → 3 lignes (2 Athlètes, 1 Assistant)
2. Copier mdp d'un athlète → coller → format correct
3. Régénérer mdp d'un athlète → sheet nouveau mdp → login athlète avec ancien → échec → login avec nouveau → succès

---

## 🟩 L7 — Tests unitaires + code review MCP

**Dépend de** : L1-L6

**Objectif** : Écrire la suite de tests unitaires couvrant les nouveaux générateurs et le modèle CredentialAthlete, exécuter le build et le code review MCP.

**Fichiers à créer** :
- `PlaycoTests/UtilisateurIdentifiantTests.swift`
- `PlaycoTests/CredentialAthleteTests.swift`
- `PlaycoTests/LoginRoleMatchTests.swift` (optionnel si facilement testable)

**Snippets de tests attendus** :

`UtilisateurIdentifiantTests.swift` :
```swift
import XCTest
import SwiftData
@testable import Playco

@MainActor final class UtilisateurIdentifiantTests: XCTestCase {
    var container: ModelContainer!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Utilisateur.self, AssistantCoach.self, configurations: config)
    }

    func testGenererIdentifiantFormatXXXX() {
        for _ in 0..<100 {
            let id = Utilisateur.genererIdentifiantUnique(
                prenom: "Jean", nom: "Dupont", context: container.mainContext
            )
            XCTAssertTrue(id.range(of: #"^[a-z.-]+\.\d{4}$"#, options: .regularExpression) != nil,
                          "Identifiant \(id) ne matche pas le format")
        }
    }

    func testGenererIdentifiantCollisionResolue() {
        var ids: Set<String> = []
        for _ in 0..<10 {
            let id = Utilisateur.genererIdentifiantUnique(
                prenom: "Jean", nom: "Dupont",
                context: container.mainContext, exclusions: ids
            )
            XCTAssertFalse(ids.contains(id))
            ids.insert(id)
            container.mainContext.insert(Utilisateur(
                identifiant: id, motDePasseHash: "x",
                prenom: "Jean", nom: "Dupont", role: .etudiant
            ))
        }
        XCTAssertEqual(ids.count, 10)
    }

    func testGenererIdentifiantPrenomNomVidesFallback() {
        let id = Utilisateur.genererIdentifiantUnique(
            prenom: "", nom: "", context: container.mainContext
        )
        XCTAssertTrue(id.hasPrefix("user."))
    }

    func testGenererMotDePasseAthleteFormat() {
        for _ in 0..<100 {
            let mdp = Utilisateur.genererMotDePasseAthlete()
            XCTAssertTrue(mdp.range(of: #"^[A-Z]{5}_[0-9]{2}$"#, options: .regularExpression) != nil)
        }
    }

    func testGenererMotDePasseSansCaracteresAmbigus() {
        for _ in 0..<1000 {
            let mdp = Utilisateur.genererMotDePasseAthlete()
            for char in mdp {
                XCTAssertFalse(["I", "L", "O", "0", "1"].contains(String(char)),
                              "Caractère ambigu \(char) trouvé dans \(mdp)")
            }
        }
    }

    func testRoleAssistantCoachExiste() {
        XCTAssertTrue(RoleUtilisateur.allCases.contains(.assistantCoach))
        XCTAssertEqual(RoleUtilisateur.assistantCoach.label, "Coach assistant")
    }
}
```

`CredentialAthleteTests.swift` :
```swift
@MainActor final class CredentialAthleteTests: XCTestCase {
    var container: ModelContainer!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: CredentialAthlete.self, configurations: config)
    }

    func testCreationAvecDefaults() {
        let cred = CredentialAthlete(
            utilisateurID: UUID(),
            identifiant: "jean.dupont.1234",
            motDePasseClair: "ABCDE_23",
            codeEquipe: "DIAB26"
        )
        XCTAssertNotNil(cred.id)
        XCTAssertNil(cred.joueurEquipeID)
        XCTAssertEqual(cred.motDePasseClair, "ABCDE_23")
    }

    func testFiltreParEquipe() throws {
        let c1 = CredentialAthlete(utilisateurID: UUID(), identifiant: "a", motDePasseClair: "X", codeEquipe: "A1")
        let c2 = CredentialAthlete(utilisateurID: UUID(), identifiant: "b", motDePasseClair: "Y", codeEquipe: "B2")
        container.mainContext.insert(c1)
        container.mainContext.insert(c2)
        try container.mainContext.save()

        let desc = FetchDescriptor<CredentialAthlete>()
        let all = try container.mainContext.fetch(desc)
        XCTAssertEqual(all.count, 2)

        let filtered = all.filtreEquipe("A1")
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.identifiant, "a")
    }
}
```

**Exécution** :
```bash
cd "/Users/armypo/Documents/Origotech/Playco"
xcodebuild test -scheme "Playco" -destination 'platform=iOS Simulator,name=iPad Air 13-inch (M3)' -only-testing:PlaycoTests/UtilisateurIdentifiantTests -only-testing:PlaycoTests/CredentialAthleteTests
```

**Code review MCP** :
- `mcp__code-review-graph__detect_changes_tool` sur : `Utilisateur.swift`, `LoginView.swift`, `ChoixInitialView.swift`, `PlaycoApp.swift`, `ConfigMembresView.swift`, `ConfigurationView.swift`, `AjoutUtilisateurView.swift`, `ProfilView.swift`, `CredentialAthlete.swift`, `IdentifiantsEquipeView.swift`, `IdentifiantsRecapSheet.swift`
- `mcp__code-review-graph__get_impact_radius_tool` sur `genererIdentifiantUnique` → lister callers et vérifier aucune régression

**Critères d'acceptation** :
- Tous les tests ci-dessus verts
- Code review MCP : aucune régression flaggée sur les callers de `genererIdentifiantUnique`

---

## 🟩 L8 — Validation finale (build + 12 scénarios manuels + CLAUDE.md)

**Dépend de** : L1-L7

**Objectif** : Build final sans warnings, validation manuelle des 12 scénarios du plan, mise à jour CLAUDE.md.

**Actions** :

1. **Build strict** :
```bash
cd "/Users/armypo/Documents/Origotech/Playco" && xcodebuild -scheme "Playco" -destination 'platform=iOS Simulator,name=iPad Air 13-inch (M3)' clean build
```
Cible : **0 erreur, 0 warning**. Si warnings → fix avant de continuer.

2. **12 scénarios manuels iPad** (iPad Air 13" M3) :
   1. ChoixInitialView : 2 boutons "Créer" et "Connexion" (plus "Rejoindre")
   2. Wizard création : coach saisit son mdp étape 3, crée 3 athlètes + 1 assistant étape 5 → mdp auto-générés visibles monospace → fin wizard → sheet récap bloquante
   3. Sheet récap : "Tout partager" → ShareSheet avec texte formaté
   4. LoginView coach : picker Coach + identifiant + mdp coach → connexion OK
   5. LoginView assistant : picker Assistant + identifiant format `prenom.nom.1234` + mdp `ABCDE_23` → connexion OK
   6. LoginView athlète : picker Athlète + credentials → connexion OK (tier Club si paywall actif) / gate bloque sinon
   7. Role mismatch : picker Coach + credentials athlète → erreur "Mauvais type de compte"
   8. ProfilView coach : nouveau bouton "Identifiants de l'équipe" → liste avec copier/partager
   9. Régénérer mdp : tap Régénérer sur un athlète → nouveau mdp affiché → login avec ancien échoue → login avec nouveau OK
   10. AjoutUtilisateurView athlète depuis ProfilView : prenom + nom → identifiant + mdp auto → sheet récap
   11. AjoutUtilisateurView coach : saisie manuelle mdp
   12. Users pré-v2.0 : identifiant `alice.martin` (sans .XXXX) → login OK (rétrocompat)

3. **Mise à jour `CLAUDE.md`** : ajouter entrée patch dans le tableau historique (section "Historique des patchs") :
```markdown
| 2.0.0 | **Login unifié + paywall** — Suppression RejoindreEquipeView, LoginView picker 3 tabs (Coach/Assistant/Athlète), rôle .assistantCoach, identifiants auto-générés `prenom.nom.XXXX`, mdp athlète auto-générés `LLLLL_DD`, nouveau modèle CredentialAthlete (stockage privé mdp en clair), vue IdentifiantsEquipeView avec régénération mdp, sheet récap bloquante à la fin du wizard. Préparation pour paywall v2.0 Pro+Club. |
```

4. **Commit final** :
```
feat(login): flow unifié v2.0 + auto-gen credentials athlète

- Suppression système code équipe (RejoindreEquipeView)
- LoginView : picker 3 tabs Coach/Assistant/Athlète + post-auth role check
- Identifiants nouveau format prenom.nom.XXXX (4 chiffres random)
- Mdp athlète/assistant auto-généré ABCDE_23 (5 lettres + _ + 2 chiffres)
- Nouveau modèle CredentialAthlete (private CloudKit DB)
- IdentifiantsEquipeView : copier/partager/régénérer mdp
- Sheet récap bloquante à la finalisation du wizard
- Rôle .assistantCoach ajouté (permissions étendues via paywall P1)
```

**Critères d'acceptation finaux** :
- 0 erreur / 0 warning build
- 12/12 scénarios manuels passent
- Tests unitaires L7 verts
- Aucun crash fresh install ni avec BD pré-v2.0
- CLAUDE.md à jour
- Commit créé

---

