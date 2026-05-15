# PlayCast

**Projet n° 3 — Origotech**
**Type** : Compagnon live-activity de Coach Planner VB (Playco)
**Plateformes** : iOS 26+, watchOS 26+, CarPlay
**Statut** : Spécification initiale
**Dernière mise à jour** : 12 mai 2026

---

## 1. Vision

PlayCast est l'app compagnon de Playco qui pousse le **match en cours** sur tous les appareils Apple secondaires : Dynamic Island, écran verrouillé, complications Apple Watch, widget CarPlay. Cible trois personas distincts :

1. **Coach assistant** : doit suivre/logger le match sans interférer avec l'iPad principal du coach-chef.
2. **Gérant / staff non technique** : veut voir le score, la rotation actuelle, qui est libéro — sans toucher à Playco.
3. **Parents / supporters** : suivent le match du gymnase d'à côté, ou pendant le trajet pour rejoindre.

C'est un **second seat moins cher** dans le modèle d'abonnement seat-based existant, qui élargit la base de revenus sans cannibaliser le seat coach principal.

---

## 2. Stack technique

| Couche | Technologie | Rôle |
|---|---|---|
| Live Activities | **ActivityKit** | État du match en temps réel sur écran verrouillé / Dynamic Island |
| Widgets | **WidgetKit** | Home Screen, Lock Screen, StandBy, Control Center |
| Actions inline | **App Intents** + **interactive snippets** (iOS 26) | Log d'événements depuis l'écran verrouillé sans ouvrir l'app |
| Push de mises à jour | **APNs Live Activity broadcast** | Diffusion du match aux N appareils suivant en temps réel |
| Sync entre devices | **CloudKit** (canal pub/sub) | iPad coach principal pousse les updates aux appareils PlayCast |
| Wearable | **WatchKit** + complications **ClockKit** | Match sur cadran Apple Watch |
| Auto | **CarPlay widgets** (nouveau iOS 26 : systemSmall supporté) | Suivi du score en conduisant |
| Notifications | **UserNotifications** + push critiques | Alertes : timeout, fin de set, point décisif |

---

## 3. Architecture

### 3.1 Modèle de données partagé

PlayCast lit le même `Match` SwiftData que Playco via **App Group** + CloudKit subscription. Pas de duplication, pas de modèle propre.

```swift
// Existant dans Playco, exposé à PlayCast via App Group
@Model
final class Match { /* existant */ }

// Nouveau, dédié PlayCast
struct MatchLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var scoreEquipe: Int
        var scoreAdversaire: Int
        var setActuel: Int
        var setsEquipe: Int
        var setsAdversaire: Int
        var rotationActuelle: Int
        var libero: String?
        var timeoutsRestantsEquipe: Int
        var dernierEvenement: EvenementLive
        var phaseService: PhaseService  // .equipe, .adversaire
    }

    var matchId: UUID
    var nomEquipe: String
    var nomAdversaire: String
    var categorie: String  // U18F, Sénior M, etc.
}

enum EvenementLive: Codable, Hashable {
    case point(equipe: Bool, joueur: String?)
    case timeout(equipe: Bool)
    case substitution(entrant: String, sortant: String)
    case rotation
    case finSet(score: String)
}
```

### 3.2 Flux de données

```
Coach iPad (Playco)
   ↓ log événement (point, timeout, etc.)
SwiftData local + CloudKit push
   ↓
CloudKit subscription côté PlayCast
   ↓
ActivityKit update + APNs broadcast
   ↓
Dynamic Island / Lock Screen / Watch / CarPlay
```

Latence cible : < 2 secondes entre tap iPad coach et update visible sur appareils PlayCast.

### 3.3 Interactive snippets pour log inline

Le coach assistant peut logger un événement depuis l'écran verrouillé sans ouvrir Playco. Exploite la nouvelle API iOS 26 :

```swift
struct LogPointIntent: AppIntent {
    static var title: LocalizedStringResource = "Logger un point"

    @Parameter(title: "Équipe ou adversaire")
    var pourEquipe: Bool

    @Parameter(title: "Joueur (optionnel)")
    var joueur: JoueurEntity?

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        // 1. Valide la permission (rôle staff dans Playco)
        // 2. Pousse l'événement via CloudKit
        // 3. Retourne un snippet SwiftUI mis à jour
        let snippet = MatchSnippetView(matchId: ...)
        return .result(view: snippet, dialog: "Point loggé")
    }
}
```

Le coach assistant tient son iPhone, appuie sur le widget Lock Screen → snippet apparaît → tap "+1 nous" → événement loggé sans déverrouiller le téléphone.

---

## 4. Surfaces UI

### 4.1 Dynamic Island
- **Compact** : score actuel (ex. `21-18 • S2`)
- **Expanded** : score complet, sets, rotation, qui sert, dernier événement
- **Minimal** : icône Origotech + score en miniature

### 4.2 Lock Screen Live Activity
- Score grand format
- Indicateur de service (flèche / icône)
- Rotation actuelle visualisée (mini-diagramme)
- Boutons d'action si l'utilisateur a les permissions staff

### 4.3 Home Screen Widgets
- **Small** : score + set actuel
- **Medium** : score + rotation + dernier événement
- **Large** : score + rotation complète (6 joueurs) + timeouts restants
- **Lock Screen rectangulaire** : score compact
- **StandBy** : score grand format pour iPhone sur dock de nuit en bord de terrain

### 4.4 Apple Watch
- **Complication** sur cadran : score live
- **App native** : vue détaillée du match, possibilité de log par tap pour staff autorisé
- **Smart Stack** : promotion automatique pendant les matchs actifs

### 4.5 CarPlay (nouveau iOS 26)
- Widget systemSmall : score + temps écoulé
- Notifications critiques (fin de set, timeout)
- Pas d'interaction (sécurité conduite) — lecture seule

### 4.6 Control Center
- Quick toggle "Voir le match en cours" → ouvre snippet
- Quick toggle "Notifications match" on/off

---

## 5. Système de permissions

Réutilise le système de permissions granulaires existant de Playco. PlayCast respecte les rôles :

| Rôle | Permissions PlayCast |
|---|---|
| Coach principal | Tout (mais utilise plutôt iPad) |
| Coach assistant | Voir + logger événements |
| Gérant / scoreur | Voir + logger score uniquement |
| Staff médical | Voir + logger blessures/sorties |
| Parent / supporter | Voir score + sets seulement, pas de détails tactiques |

L'invitation à PlayCast se fait depuis Playco : le coach principal génère un **QR code** ou un **lien deep link** que les autres scannent pour rejoindre le match comme spectateurs (avec rôle assigné).

---

## 6. Modèle commercial

PlayCast est gratuit à télécharger, mais nécessite un seat actif rattaché à un compte Playco coach.

- **Inclus** dans tous les seats Playco existants (coach principal et assistants payés)
- **Mode invité gratuit** : un coach principal peut inviter jusqu'à 5 spectateurs (parents, gérant) en read-only, sans seat payant
- Au-delà → palier "Programme étendu" (équipes universitaires, clubs avec staff large)

Avantage stratégique : élargit la base d'utilisateurs Playco sans cannibaliser les revenus principaux. Les parents qui découvrent PlayCast peuvent recommander Playco à leurs propres coachs.

---

## 7. Fonctionnalités V1

- Live Activity Dynamic Island + Lock Screen
- Widgets Home Screen (3 tailles)
- Apple Watch app + complication
- Permissions et invitations via QR
- Log de points via interactive snippet (assistants autorisés seulement)
- Notifications fin de set / timeout

---

## 8. Fonctionnalités V2

- **CarPlay widget**
- **StandBy mode optimisé** (mode plein écran dédié pour iPhone posé sur le bord de terrain)
- **Replay sets** : tap sur un set passé → résumé visuel
- **Notifications enrichies** : avec preview du dernier point loggé
- **Mode multi-match** : suivre 2-3 matchs en parallèle (utile pour tournois)

---

## 9. Roadmap proposée

| Phase | Durée | Livrable |
|---|---|---|
| Setup | 1 semaine | App Group, CloudKit subscriptions, modèle partagé |
| Live Activity | 2 semaines | ActivityKit, Dynamic Island, Lock Screen, push APNs |
| Widgets | 1 semaine | 3 tailles Home Screen + Lock Screen rectangulaire |
| Interactive snippets | 1 semaine | LogPointIntent + permissions |
| Apple Watch | 2 semaines | App native + complication |
| Invitations / QR | 1 semaine | Deep link, onboarding spectateur |
| Beta TestFlight | 2 semaines | Test sur 3-5 équipes |
| Release | 1 semaine | App Store |

**Total : ~11 semaines à temps partagé.**

V2 (CarPlay, StandBy, multi-match) : post-launch selon retours utilisateurs.

---

## 10. Risques et mitigations

| Risque | Mitigation |
|---|---|
| Latence push trop élevée (> 3s) | Tests réseau réels en gymnase (souvent wifi médiocre) ; fallback Bluetooth peer-to-peer entre iPad coach et iPhone assistants proches |
| Confusion entre Playco et PlayCast pour les utilisateurs | Branding clair : PlayCast = "voir le match", Playco = "coacher le match" ; onboarding explicite |
| Apple peut rejeter app trop "thin" vs Playco | Justifier valeur autonome : permissions différenciées, surfaces uniques (Watch, CarPlay) que Playco ne couvre pas |
| Abus du mode gratuit invité | Limite hardcoded à 5 invités, expiration après chaque match |
| Drain batterie Live Activity longue durée (matchs 2h+) | Updates throttled, mode économie automatique après inactivité, doc claire utilisateurs |

---

## 11. Lien avec l'écosystème Origotech

- **Playco** : dépendance directe (modèle partagé via App Group + CloudKit)
- **Playco Insights** : PlayCast peut afficher des **insights tactiques courts** générés par Insights en mi-temps (résumé 1-2 lignes) sur la Live Activity
- **OrigoVault** : événements de match peuvent générer automatiquement une note de débrief post-match dans le vault (via App Intent partagé)

---

## 12. Prochaines étapes

1. Valider la quota Live Activity longue durée pour Playco (Apple a des limites sur les push frequency)
2. PoC App Group entre Playco et PlayCast : partage `Match` en lecture
3. Maquette Dynamic Island (3 états) et Lock Screen
4. Décision : Apple Watch dans V1 ou V2 ?
5. Spécifier le système d'invitation QR (format token, expiration, révocation)
