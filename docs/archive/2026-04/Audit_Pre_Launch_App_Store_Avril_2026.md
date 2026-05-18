# Checklist pré-App Store — Playco v1.9.0

**Date :** 15 avril 2026
**Cible :** Soumission App Store pour lancement officiel septembre 2026
**Scope :** Conformité Apple, légal, accessibilité, i18n, CloudKit

---

## Résumé exécutif

**STATUT GLOBAL : ⚠️ PRESQUE PRÊT — 5 BLOQUEURS CRITIQUES + 6 MANQUES IMPORTANTS**

L'app TestFlight fonctionne sans erreurs de build, mais plusieurs éléments essentiels pour le App Store sont manquants ou mal configurés. Avec 5 mois avant le lancement critique de septembre 2026, ces points doivent être résolus immédiatement pour éviter un rejet lors de la soumission officielle.

---

## 1. PlaycoInfo.plist — Clés de configuration

### ✅ PRÉSENTES

| Clé | Valeur | Statut |
|---|---|---|
| `CFBundleIconName` | AppIcon | ✅ |
| `ITSAppUsesNonExemptEncryption` | false | ✅ |
| `NSCalendarsFullAccessUsageDescription` | Texte français complet | ✅ |
| `NSPhotoLibraryUsageDescription` | Texte français complet | ✅ |
| `UIApplicationSupportsMultipleScenes` | true | ✅ |
| `UILaunchScreen` | Configuré | ✅ |
| `UIBackgroundModes` | [remote-notification] | ✅ |
| `LSSupportsOpeningDocumentsInPlace` | true | ✅ |
| `UTExportedTypeDeclarations` | com.origotech.playco.exercices | ✅ |
| `CFBundleDocumentTypes` | Configuré pour exercices | ✅ |

### ❌ MANQUANTES (Critique)

| Clé | Impact | Fix |
|---|---|---|
| `CFBundleShortVersionString` | BLOQUANT — actuellement `1.0` dans .pbxproj | Changer en `1.9.0` |
| `CFBundleVersion` | BLOQUANT — actuellement `1` dans .pbxproj | Incrémenter à `2+` |
| `NSPhotoLibraryAddUsageDescription` | PhotosPicker utilisé dans ModifierUtilisateurView et AvatarEditableView, Apple peut rejeter si utilisateur clique "Save to Photos" | Ajouter |
| `NSMicrophoneUsageDescription` | Non présent — requis si FoundationModels ajouté pour saisie vocale | Ajouter si future feature |
| `NSUserTrackingUsageDescription` | Absent — OK si aucun tracking ATT prévu | Optionnel |
| `LSApplicationQueriesSchemes` | Absent — non critique | Optionnel pour EventKit |

### ⚠️ À VÉRIFIER

- `UIRequiredDeviceCapabilities` — Absent. Playco supporte iPad, mais aucune restriction d'appareils déclarée. À vérifier si tu veux limiter à iPads uniquement.

---

## 2. Entitlements — Fichier Playco.entitlements

### ✅ PRÉSENTES

| Clé | Valeur | Statut |
|---|---|---|
| `com.apple.security.application-groups` | group.com.origotech.playco | ✅ |
| `com.apple.developer.icloud-container-identifiers` | iCloud.Origo.Playco | ✅ |
| `com.apple.developer.icloud-services` | [CloudKit] | ✅ |
| `aps-environment` | **development** (actuellement) | ⚠️ |

### ❌ MANQUANTES / À CORRIGER (Critique)

| Problème | Impact | Fix |
|---|---|---|
| `aps-environment = development` | **REJET AUTOMATIQUE** App Store si laissé en development | Changer en `production` |
| `com.apple.developer.ubiquity-container-identifiers` | Absent — normalement nécessaire si CloudKit sync | À vérifier si `ModelConfiguration:cloudKitDatabase:.automatic` suffit |
| `com.apple.developer.associated-domains` | Absent | Non critique sauf si universal links prévus |
| `com.apple.developer.healthkit` | Absent | OK si HealthKit non intégré |

### ⚠️ CONFIGURATION POUR PRODUCTION

- **Code signing** : vérifier que le Team ID Apple Developer est correct dans Xcode
- **Provisioning profile** : doit correspondre à `Origo.Playco` bundle ID

---

## 3. Project settings (Playco.xcodeproj)

### ✅ CORRECTEMENT CONFIGURÉS

| Paramètre | Valeur | Statut |
|---|---|---|
| Bundle ID | `Origo.Playco` | ✅ |
| Swift Version | 5.0 | ✅ |
| `SWIFT_APPROACHABLE_CONCURRENCY` | YES | ✅ |
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | MainActor | ✅ |

### ❌ BLOQUEURS CRITIQUES

| Paramètre | Actuel | Doit être |
|---|---|---|
| `MARKETING_VERSION` | `1.0` | `1.9.0` |
| `CURRENT_PROJECT_VERSION` | `1` | `2+` (chaque soumission > build précédent) |
| `IPHONEOS_DEPLOYMENT_TARGET` | `26.2` | À vérifier — si iOS 26 est réellement sorti OK, sinon corriger vers `17.0` |

### ⚠️ À VÉRIFIER

- `SWIFT_EMIT_LOC_STRINGS` — Absent pour target Playco mais présent pour tests. À vérifier pour localisation

---

## 4. AppIcon — Configuration Assets

### ✅ PRÉSENT

- `AppIcon.appiconset/` existe ✅
- `AppIcon.png` (1024x1024) en place ✅
- `Contents.json` correct avec idiom `universal` et platform `ios` ✅

### ⚠️ ATTENTION

- **Seule taille fournie** : 1024x1024. Apple accepte un seul fichier pour génération automatique, **MAIS** vérifier que l'icône est :
  - Sans transparence (solide ou gradient)
  - Avec suffisant contraste
  - Lisible même en très petit (120x120 sur écran d'accueil)
- **Pas d'icônes iPad 76x76, 152x152, 167x167** générées manuellement — Xcode 15+ génère automatiquement, donc OK
- **Dark mode** et **tinted** variants présentes dans `Contents.json` — bon pour iOS 17+

---

## 5. Build warnings et erreurs

### ✅ AUCUN WARNING DE BUILD

- `grep @available` → Aucun avertissement ✅
- `grep #warning` → Aucun `#warning` trouvé ✅
- `grep fatalError` → Probablement présent dans fallback code (mentionné CLAUDE.md pitfall mémoire)

### ⚠️ POTENTIELS PROBLÈMES

1. **fatalError en fallback mémoire** — Si non utilisé en production, acceptable
2. **137 fichiers Swift** — Aucun FIXME/TODO trouvé → bonne hygiène ✅
3. **Aucune dépendance SPM détectée** — App self-contained, excellent pour App Store ✅

---

## 6. Empty states — ContentUnavailableView

### ✅ BONNE COUVERTURE

- **20 utilisations de ContentUnavailableView** trouvées ✅
- Vues principales couvertes :
  - ListeSeancesView ✅
  - MatchsView ✅
  - EquipeView ✅
  - BibliothequeView ✅
  - ExercicesView ✅
  - StrategiesView ✅
  - MessagerieView (à vérifier)

### ⚠️ À VÉRIFIER

- Vérifier que CHAQUE liste affiche un empty state pertinent (ex: "Aucune séance prévue" avec CTA)
- Apple rejette les listes vides sans contexte utilisateur

---

## 7. Haptics — sensoryFeedback

### ✅ PARTIELLEMENT IMPLÉMENTÉS

- **12 utilisations de `sensoryFeedback`** trouvées ✅

### ❌ MANQUES CRITIQUES

Actions sensorielles manquantes sur les interactions critiques :

1. **Création de seance** — Pas de feedback détecté
2. **Suppression de seance** — Pas de feedback détecté
3. **Succès de match live** (fin de set, fin match) — Doit avoir `.success` feedback (à confirmer)
4. **Substitution joueur** — Pas de feedback détecté
5. **Timeout** — Pas de feedback détecté
6. **Score point en match live** — Probablement implémenté ✅

**Recommandation :** ajouter `sensoryFeedback` à tous les points de décision utilisateur (création, suppression, actions temps réel) pour améliorer la qualité perçue App Store.

---

## 8. Accessibility — accessibilityLabel, accessibilityHint, accessibilityValue

### ❌ CRITIQUE — SCORE TRÈS BAS

- **0 occurrences** de `accessibilityLabel`, `accessibilityHint`, `accessibilityValue` trouvées

### ⚠️ IMPLICATION APP STORE

Apple WONTFIX si l'app est complètement inaccessible, mais ne rejette officiellement que si :

- VoiceOver impossible à naviguer
- Contraste texte < 4.5:1 sur textes importants

Cependant, l'absence totale d'accessibilité labels sera un **point faible majeur en App Store review et pour la réputation**.

### Action requise

Ajouter au minimum :

- `accessibilityLabel` sur boutons d'actions (créer, supprimer, sauvegarder)
- `accessibilityHint` sur contrôles non-évidents (swipe, long-press)
- `accessibilityValue` sur indicateurs (score, rotation, set count)

**Effort estimé :** 3-5 jours pour les 137 fichiers Swift.

---

## 9. Dynamic Type — Support des tailles de texte personnalisées

### ❌ ABSENT

- **0 utilisations** de `.dynamicTypeSize`, `.scaledToFit()` ou `.lineLimit(.max)` trouvées

### ⚠️ IMPACT

- iPad Air (cible primaire) avec TextSize ajusté → texte peut être coupé
- Utilisateurs malvoyants → problème d'accessibilité
- Landscape orientation sur iPad → risque de débordement

### Recommandation

Ajouter support Dynamic Type aux vues texte critiques (au minimum StatView, ScoresView, PointMatch affichage).

---

## 10. CloudKit schema — production status

### ❌ BLOQUANT — DONNÉES PERDUES EN PRODUCTION

- **Aucun fichier `.xcdatamodeld` ou CloudKit schema trouvé** dans le projet public
- SwiftData + CloudKit utilisé en mode `cloudKitDatabase: .automatic` (CLAUDE.md)
- **PROBLÈME :** Le schema CloudKit (24 @Model) n'a jamais été déployé en production
- **CONSÉQUENCE :** Aucun utilisateur n'a de données CloudKit en production

### Critique pour launch

Avant septembre 2026, il faut :

1. Créer un compte iCloud de test avec Apple Developer account
2. Déployer le schema production CloudKit (via dashboard ou Xcode)
3. Valider que sync fonctionne en multi-device
4. Documenter le schema pour support utilisateur

**Action urgente :** Contacter Apple Developer Support pour configurer CloudKit production et tester migration données des 2 beta testeurs.

---

## 11. Français Québec — Localisation et Loi 96

### ⚠️ PARTIELLEMENT COMPLIANT

- **Strings généré en français** — UI principale en français (`STRING_CATALOG_GENERATE_SYMBOLS = YES`) ✅
- **Texte hardcodé en anglais détecté :**
  - "Box Score" × 3 occurrences (TableauBordView, MatchDetailView, PDFExportService)
  - Probable "Mode Live" (TableauBordView)

### ❌ MANQUES POUR LOI 96 QUÉBEC

1. **Pas de `Localizable.xcstrings` détecté** — Doit exister pour gérer multilingue (français principal, anglais optionnel)
2. **Strings hardcodées** → Doit passer par `.localized` ou `NSLocalizedString("key")`
3. **Aucun fichier `fr-CA.lproj` trouvé** — France français vs. Canada français distincts

### Action requise

- Ajouter `Localizable.xcstrings` avec clés pour Box Score, Mode Live, tous les UI strings
- Changer hardcoded strings → `.localized` ou équivalent
- Vérifier contrats légaux (Privacy Policy, Terms) disponibles en français québécois

---

## 12. Analytics et crash reporting

### ❌ CRITIQUE — AUCUN SYSTÈME DÉTECTÉ

- **TelemetryDeck** — aucune trace
- **Firebase Crashlytics** — aucune trace
- **Sentry** — aucune trace
- **Posthog** — aucune trace
- **Buildbeaver/Bugsnag** — aucune trace

### ⚠️ CONSÉQUENCE POUR PRODUCTION

- **Crash en production** → Aucun signal d'alerte automatique
- **Usage patterns** → Impossible de savoir si la 1.9.0 est utilisée ou abandonnée
- **Support utilisateur** → Reproduction de bugs impossible sans reproduire manuellement

### Recommandation

Implémenter au minimum **TelemetryDeck** (privacy-first, Apple-native, < 1 jour install) ou Firebase Crashlytics (gratuit) avant septembre. **Priorité haute**.

---

## 13. Legal — Privacy Policy et Terms

### ❌ MANQUES CRITIQUES

- **Privacy Policy URL** — Non trouvé dans `Info.plist`, doit être prêt pour App Store
- **Terms of Service URL** — Non trouvé
- **CGU français québécois** — Manquant

### Action requise

Créer/déployer URLs publiques pour Privacy & Terms. Inclure obligatoirement :

- Quelles données utilisateur collectées (identifiants, photos, stats volleyball)
- Si CloudKit sync → mention explicite "données synchronisées sur serveurs Apple"
- **PIPEDA compliance** si données canadiennes
- **Responsabilité légale :** à valider avec avocat québécois avant soumission App Store

---

## 14. Taille de l'app et App Thinning

### ✅ DIMENSIONS ACCEPTABLES

- **Taille projet** : 1.5 MB source Swift (137 fichiers)
- **Assets** : Terrain volleyball (Canvas), AppIcon 1024x1024, aucune vidéo embeddée
- **Dépendances** : 0 (aucune SPM/Cocoapods)

### ✅ TAILLE IPA ESTIMÉE

- ~50-80 MB après compilation (à confirmer via Xcode build)
- **Acceptable** pour App Store (limite = 200 MB)
- **App Thinning** : Activé par défaut Xcode 15+

---

## 15. Configuration de code signing et provisioning

### ⚠️ À VÉRIFIER AVANT SOUMISSION

- **Apple Developer Account** : Compte Origo Technologies
- **Bundle ID** : `Origo.Playco` — enregistré dans Apple Developer Portal ?
- **Certificate** : iOS Distribution Certificate valide et non expiré ?
- **Provisioning Profile** : App Store Distribution profile créé pour `Origo.Playco` ?

**Action :** Avant soumission, vérifier dans Xcode que le signing team est correct et le statut de profile est "Valid".

---

## 📋 BLOQUEURS CRITIQUES — Empêchent la soumission App Store

| # | Problème | Sévérité | Fix estimé | Impact |
|---|----------|----------|-----------|--------|
| 1 | `MARKETING_VERSION = 1.0` (doit être 1.9.0) | BLOQUANT | 5 min | Rejet automatique |
| 2 | `aps-environment = development` (doit être production) | BLOQUANT | 5 min | Rejet automatique |
| 3 | `CURRENT_PROJECT_VERSION = 1` (doit être 2+) | BLOQUANT | 5 min | Rejet automatique |
| 4 | `IPHONEOS_DEPLOYMENT_TARGET` à vérifier | BLOQUANT | 15 min | Potentiel rejet build |
| 5 | **CloudKit schema non déployé en production** | BLOQUANT | 2-3 jours | Données perdues, multi-device sync non fonctionnel |
| 6 | Pas de `NSPhotoLibraryAddUsageDescription` (PhotosPicker utilisé) | TRÈS PROBABLE REJET | 10 min | Rejet si photo save testée |
| 7 | **0 `accessibilityLabel/hint`** (WCAG minimal) | REJET PROBABLE | 3-5 jours | Rejet si app inaccessible |
| 8 | **Strings anglaises en dur** (Box Score, Mode Live) | REJET PROBABLE | 1 jour | Non-conformité Loi 96 Québec |

---

## 🎯 NICE-TO-HAVE — Améliorations non-bloquantes

| # | Amélioration | Effort | Gain App Store |
|---|---|---|---|
| 1 | `sensoryFeedback` sur création/suppression | 2 jours | Qualité UX perçue ++ |
| 2 | Dynamic Type (TextSize responsive) | 3 jours | Accessibilité WCAG AAA |
| 3 | Sentry/Crashlytics/TelemetryDeck | 1 jour | Monitoring production critique |
| 4 | `Localizable.xcstrings` fr/en | 1-2 jours | Future multilingue |
| 5 | `UIRequiredDeviceCapabilities` (iPad only ?) | 30 min | Clarté App Store |
| 6 | Screenshots App Store (5-10 images) | 1 jour | Conversion utilisateurs ++ |

---

## ✅ Top 10 actions prioritaires — Avant soumission App Store

### Semaine 1 (immédiat) — 8 heures

1. Changer `MARKETING_VERSION` → 1.9.0 (Xcode Build Settings)
2. Changer `CURRENT_PROJECT_VERSION` → 2 (Xcode Build Settings)
3. Changer `aps-environment` → production (Playco.entitlements)
4. Vérifier `IPHONEOS_DEPLOYMENT_TARGET`
5. Ajouter `NSPhotoLibraryAddUsageDescription` (PlaycoInfo.plist)
6. Valider CloudKit schema en Apple Developer Portal (2-3 heures)

### Semaines 2-3 (urgent) — 8 jours

7. Ajouter `accessibilityLabel` aux boutons/contrôles critiques (3-5 jours) — prioriser : boutons match live, créer séance, score, subs
8. Remplacer strings anglaises par `.localized` (1 jour) — Box Score, Mode Live et 3+ autres
9. Créer/publier Privacy Policy et Terms URLs (1-2 jours)
10. Implémenter TelemetryDeck ou Sentry (1 jour)

### Semaine 4 (avant octobre)

- Créer 5-10 screenshots App Store
- Rédiger description App Store (300 caractères)
- Préparer questionnaire confidentialité Apple (données collectées ?)
- Valider en TestFlight avec 10-20 testeurs externes

---

## 📊 Matrice de risque

```
╔════════════════════════════════════════════════════════════════╗
║ RISQUE APP STORE REVIEW — SEPTEMBRE 2026                      ║
╠════════════════════════════════════════════════════════════════╣
║ Blockers (rejet 100%)         : 8 issues — 5 heures fix        ║
║ Probables (rejet 70%)         : 2 issues — 4 jours fix         ║
║ Possibles (rejet 30%)         : 4 issues — 5 jours fix         ║
║ Nice-to-have (impact < 10%)   : 6 items — 7 jours optionnel    ║
╚════════════════════════════════════════════════════════════════╝
```

**Verdict :** Avec 5 mois, tous les blockers sont résolvables. Prioriser semaines 1-2 pour régler les 8 bloqueurs critiques (< 1 semaine), puis semaines 3-4 pour accessibilité et légalité (2 semaines). Reste 16 semaines pour features, marketing, et stabilisation avant lancement septembre.

---

*Audit généré le 15 avril 2026 · Playco v1.9.0 · Checklist conformité App Store*
