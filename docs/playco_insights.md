# Playco Insights

**Projet n° 1 — Origotech**
**Type** : Module d'extension de Coach Planner VB (Playco)
**Plateformes** : iPadOS 26+, iOS 26+ (compagnon)
**Statut** : Spécification initiale
**Dernière mise à jour** : 12 mai 2026

---

## 1. Vision

Playco Insights est un module IA local intégré directement dans Coach Planner VB. À la fin de chaque match (ou en cours de set), le coach reçoit un **debrief tactique généré on-device** : patterns de jeu détectés, faiblesses tactiques adverses, recommandations de rotation, statistiques contextualisées en langage naturel.

L'argument différenciateur : **zéro coût d'inférence, zéro réseau, 100 % privé**. Aucun compétiteur volleyball n'offre cette fonctionnalité sans abonnement cloud payant. C'est aussi une justification forte pour un palier supérieur dans le modèle d'abonnement seat-based existant.

---

## 2. Stack technique

| Couche | Technologie | Rôle |
|---|---|---|
| IA on-device | **Foundation Models framework** (iOS 26) | Génération de debriefs, classification tactique, résumés |
| Structure de sortie | `@Generable`, `@Guide` macros | Garantit des outputs typés Swift directement insérables en SwiftData |
| Persistance | **SwiftData** (modèle existant Playco étendu) | Stockage des `Debrief`, `PatternDetecte`, `Recommandation` |
| Visualisation | **Swift Charts** + nouveau support 3D (iOS 26) | Heatmaps rotation × zone × efficacité, charts 3D des trajectoires |
| Audio (V2) | **Speech Framework** révisé (WWDC25) | Annotations vocales tactiques temps réel pendant le match |
| Sync | **CloudKit** (existant) | Propagation des debriefs entre iPad coach et iPhone staff |

**Aucun service cloud, aucune clé API, aucun coût récurrent côté Origotech.**

---

## 3. Architecture

### 3.1 Nouveaux modèles SwiftData

```swift
@Model
final class Debrief {
    @Attribute(.unique) var id: UUID
    var match: Match           // relation existante
    var dateGeneration: Date
    var typeDebrief: TypeDebrief  // .miTemps, .finSet, .finMatch
    var resumeTactique: String
    var patternsDetectes: [PatternDetecte]
    var recommandations: [Recommandation]
    var scoreConfiance: Double  // confidence du modèle
}

@Model
final class PatternDetecte {
    @Attribute(.unique) var id: UUID
    var debrief: Debrief
    var categorie: CategoriePattern  // .service, .reception, .attaque, .bloc, .defense
    var description: String
    var zonesImpactees: [Int]   // zones 1-6 du terrain
    var impactScore: Double     // -1.0 (négatif) à +1.0 (positif)
    var actionsRecommandees: [String]
}

@Model
final class Recommandation {
    var debrief: Debrief
    var priorite: Priorite      // .critique, .haute, .moyenne, .info
    var titre: String
    var detail: String
    var rotationConcernee: Int?
    var joueursConcernes: [Joueur]  // relation
}
```

### 3.2 Pipeline Foundation Models

```
Match terminé / set terminé
        ↓
StatsAggregator (existant) → snapshot structuré du match
        ↓
PromptBuilder → prompt système + données du match (JSON serialisé)
        ↓
LanguageModelSession (Foundation Models, stateful)
        ↓
@Generable Debrief → Swift struct typé
        ↓
SwiftData persist + CloudKit sync
        ↓
UI : DebriefView (SwiftUI)
```

### 3.3 Exemple de structure générée

```swift
@Generable
struct DebriefGenere {
    @Guide(description: "Résumé tactique du match en 3-4 phrases, ton professionnel mais accessible")
    let resume: String

    @Guide(description: "Liste des patterns observés, triés par impact décroissant")
    let patterns: [PatternGenere]

    @Guide(description: "Recommandations actionnables pour le prochain match ou la prochaine séance")
    let recommandations: [RecommandationGeneree]

    @Guide(description: "Score de confiance global du modèle entre 0.0 et 1.0")
    let confiance: Double
}
```

---

## 4. Fonctionnalités V1

**Debrief automatique en fin de match**
- Génération déclenchée par le bouton "Terminer le match" existant
- Temps de génération cible : < 8 secondes sur iPad Air M2
- Indicateur de progression streaming (snapshots Foundation Models)

**Debrief de mi-temps / fin de set**
- Bouton dédié dans le module Live Match (deux taps existant)
- Génération plus courte (< 4 sec), focalisée sur ajustements immédiats

**Heatmap 3D tactique**
- Rotation × zone × efficacité en 3 dimensions (Swift Charts 3D)
- Filtrable par joueur, par phase (service / réception / attaque)
- Comparaison avec les matchs précédents (overlay)

**Export de debrief**
- PDF stylisé pour partage avec staff
- Texte brut pour insertion dans le système de notes du coach

---

## 5. Fonctionnalités V2 (post-launch)

- **Annotations vocales temps réel** : pendant le match, le coach dicte via Speech Framework → transcription instantanée → l'IA tagge automatiquement (timeout, point gagnant, faute critique) et lie au contexte de la rotation en cours.
- **Comparaison multi-matchs** : le modèle analyse une série de matchs (saison, contre adversaire spécifique) et identifie les tendances longues.
- **Mode scout** : le coach scanne un match adverse (sans son équipe), génère un dossier adversaire structuré.
- **Permissions staff** : intégration avec `peutVoirIdentifiantsJoueurs` et le système granulaire de permissions existant — un assistant peut voir le debrief sans accéder aux notes brutes.

---

## 6. Considérations produit

### Modèle commercial
- **Inclus dans le palier Pro** (positionnement supérieur du seat-based existant)
- Justification forte d'upsell vs. palier de base
- Pas de coût marginal côté Origotech (inférence locale) → marge identique sur tous les paliers

### Conformité Apple
- Foundation Models est intégré au système → **aucune augmentation de la taille de l'app**
- Pas de mention de "AI" en marketing évitée si possible (positionnement : "analyse tactique automatique") — Apple revoit attentivement les apps qui se vendent comme IA
- Disclosures de Privacy Manifest : aucun tracking, aucune donnée transmise

### Hardware minimum
- iPhone 15 Pro / iPad avec Apple Silicon M1+ (contrainte Apple Intelligence)
- Fallback gracieux sur appareils non compatibles : message "Insights disponible sur iPad Air M1 ou plus récent"

---

## 7. Roadmap proposée

| Phase | Durée | Livrable |
|---|---|---|
| Setup | 1 semaine | Migration SwiftData (3 nouveaux modèles), entitlements Foundation Models, prompts initiaux |
| MVP debrief | 2 semaines | Génération fin de match, UI DebriefView basique, export texte |
| Charts 3D | 1 semaine | Intégration Swift Charts 3D, heatmaps rotation/zone |
| Mi-temps + tuning | 1 semaine | Debrief court, optimisation latence, fine-tuning prompts |
| Beta TestFlight | 2 semaines | 5-10 coachs beta, itération sur qualité des debriefs |
| Release | 1 semaine | Marketing, mise à jour App Store |

**Total : ~8 semaines à temps partagé.**

---

## 8. Risques et mitigations

| Risque | Mitigation |
|---|---|
| Qualité variable des debriefs générés | Itération intensive sur prompts + scoreConfiance pour filtrer les outputs faibles |
| Hardware minimum exclut une partie de la base | Fallback texte sans IA pour anciens appareils, communication claire |
| Latence > 8s en fin de match | Streaming UI, génération en background dès la dernière action loggée |
| Drift du modèle Apple entre versions iOS | Tests de régression sur chaque major iOS, possibilité de prompts versionnés |

---

## 9. Prochaines étapes

1. Valider la disponibilité de Foundation Models sur le hardware cible des coachs beta
2. Rédiger les prompts initiaux (3 templates : fin de match, mi-temps, fin de set)
3. Migration SwiftData lightweight (ajout des 3 modèles, pas de changement existant)
4. PoC debrief simple sur match de test (données mockées)
5. Décision : Charts 3D V1 ou V2 ?
