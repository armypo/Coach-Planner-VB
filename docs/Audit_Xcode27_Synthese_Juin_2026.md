# Synthèse — Audit Playco sous Xcode 27 beta (juin 2026)

## Contexte
Audit complet de Playco sous le toolchain **Xcode 27.0 beta** (`27A5194q`, SDK iOS 27.0), cible **iOS 26.2 inchangée**, avec contrainte bloquante de **compatibilité iOS 26 complète**. Objectif : build propre, correction de tout ce que le compilateur signale, durcissement concurrence raisonné, implémentation des items stagés, et adoption du Liquid Glass natif. Suivi détaillé : [TODO_Audit_Xcode27.md](./TODO_Audit_Xcode27.md).

## Résultat
- **Build (mode qui ship) : `** BUILD SUCCEEDED **`, 0 erreur, 0 warning** sous Xcode 27 beta.
- **Tests : 132/132 verts** (123 d'origine + 9 nouveaux), en série.
- **Aucune deprecation iOS 27** émise par le compilateur (les deprecations annoncées par l'exploration initiale — `.onChange` 1-param, `.alert` — étaient des **faux positifs** : vérifiées inexistantes).
- Cible `IPHONEOS_DEPLOYMENT_TARGET = 26.2` et `SWIFT_VERSION = 5.0` conservées.

## Corrections livrées
1. **Concurrence (12 warnings baseline)** — `JSONCoderCache`, `KeychainService`, `PolitiqueRetry` marqués `nonisolated` (utilitaires purs accédés depuis l'`actor FileReplicationUtilisateur`) ; 4× `_ = try await publicDB.save(...)`.
2. **Correctness** — élimination des force-unwraps d'URL via helper DRY `AppConstants.url(_:)` (repli infaillible `URL(filePath:)`), 7 sites.
3. **Item stagé `CloudKitPublicSyncAbonnement`** — actor de miroir Public DB (clé `codeEquipe`) pour reconnexion sur Apple ID différent : publication idempotente + file pending offline, lecture fallback branchée dans `AbonnementService.rafraichir(...)` avant `essaiExpire`. + 5 tests.
4. **TelemetryDeck** — placeholder mort retiré, mode logger-only documenté comme choix d'architecture (zéro dépendance externe préservé).
5. **Liquid Glass natif** — `GlassCard`/`GlassSection`/`GlassChip` migrés vers `.glassEffect(.regular.tint(...), in:)` (API iOS 26.0, compatible cible 26.2 sans garde). Signatures publiques inchangées → 15 sites d'appel héritent du matériau Apple natif.

## Décisions importantes
- **`SWIFT_STRICT_CONCURRENCY = complete` abandonné.** Tenté ; il force des `@Model nonisolated` (Utilisateur, Exercice, StrategieCollective, ExerciceBibliotheque + protocole `TerrainContent`) qui **cassent SwiftData + CloudKit au runtime sur iOS 27** (crash `NSManagedObjectContext.save()` pendant la migration de métadonnées CloudKit). Diagnostic prouvé par bissection (code d'origine = 16/16 ; ajout `@Model nonisolated` = crash). Mode **approachable concurrency** (config réelle de prod) conservé → 0 warning sans toucher la couche données.
- **Reporté post-lancement** : flip `SWIFT_VERSION = 6.0` et strict concurrency complete (chantier SwiftData/concurrence dédié, hors fenêtre pré-App Store).
- **Liquid Glass** : matériau natif livré ; `GlassButtonStyle` custom conservé (feedback press). Revue visuelle humaine recommandée (le rendu natif diffère de l'ancienne simulation `.ultraThinMaterial`).
- **WWDC 2026 — autres nouveautés** non adoptées par défaut (impact visuel large, risque près du lancement) : `tabViewBottomAccessory`, `scrollEdgeEffect`, `backgroundExtensionEffect`, Foundation Models on-device — cadrées comme suivi.

## Vérification compatibilité
- **iOS 27.0** (iPad Air 13" M4) : build 0/0 + tests 132/132.
- **iOS 26.3** (iPad Air 13" M3) : build de compatibilité (toutes les API utilisées ≤ iOS 26.0, aucun symbole iOS 27 appelé sans garde).
- ⚠️ **Tests parallèles instables sous Xcode 27 beta** (clones + host CloudKit du simulateur) → lancer `-parallel-testing-enabled NO`. À re-vérifier sur Xcode 27 RC.

## Hors-périmètre (actions humaines)
Validation sandbox StoreKit · VoiceOver iPad physique + Dynamic Type xxxLarge + contraste WCAG AA · AppIcon prod + assets/metadata ASC + TestFlight 48 h · décision/ajout package TelemetryDeck · revue visuelle Liquid Glass natif.
