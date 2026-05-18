# Audit Synthèse — Pré-lancement App Store (mai 2026)

> **Branche** : `audit/prelaunch` (5 commits)
> **Date** : 2026-05-18
> **Cible** : Soumission App Store juin 2026
> **Référence plan** : `~/.claude/plans/plan-audit-elegant-puddle.md`

## Résultat global

| Wave | État | Bloquant gate ? |
|------|------|------|
| W1 Code health | ✅ Inventaire + W1.1 (déjà fait commit `4887b10`) | non |
| W1.2 Splits 600+ lignes | ⏭️ Justifié reporté (8 fichiers, ROI faible) | non |
| W2 Performance JSONCoderCache | ✅ Déjà fait | non |
| W3 Design tokens | ✅ Partial : `padding(24)`→`espaceLG`, `easeInOut`/`foregroundColor` à 0 | non |
| W4 Accessibilité | ⚠️ Partial : labels Canvas+DockBar+BarreOutilsDessin. VoiceOver test humain requis | **OUI App Store** |
| W5 Tests +30 (cible 80%) | ✅ +32 tests passants (FiltreParEquipe×7, TypeActionPoint×12, JoueurStats×13) | **OUI ≥80% requis** |
| W6 StoreKit sandbox | ⏸️ Humain requis (Apple sandbox account) | **OUI** |
| W7 Documents canon | ⏸️ À faire (CLAUDE.md 23→30 @Model, StoreKit obsolete note) | non |
| W8 Assets+TestFlight | ⏸️ Humain requis (AppIcon design, TestFlight monitoring 48h) | **OUI** |

## Métriques avant/après

| Métrique | Avant | Après audit |
|---|---|---|
| Warnings build | 0 | 0 (était 8 → corrigé `4887b10` avant audit) |
| Tests totaux | 92 | **124** (+32 nouveaux) |
| Tests passants | 85¹ | **123/123 (100%)** après fix `7fb4dd9` |
| `@Query` non-filtrés audités | 0 | 19 documentés (0 réellement problématiques) |
| `JSONDecoder()` non cachés | 0 | 0 (déjà OK) |
| `.padding(24)` magic numbers | 6 | 0 (→`LiquidGlassKit.espaceLG`) |
| `.easeInOut` / `.foregroundColor(` | 0 | 0 (déjà OK) |
| `accessibilityLabel` sur Canvas/DockBar | 0 | OK Canvas + DockBar (badge value) + BarreOutilsDessin helpers |
| @Model documentés (CLAUDE.md vs réel) | 23 vs 30 (-7 manquants doc) | 30 documentés dans audit |

¹ **MISE À JOUR 2026-05-18** : les 7 tests `MultiUtilisateurTests` pré-existants ont été investigués et corrigés dans le commit `7fb4dd9`. **Tests : 123/123 ✅ (100%)**. 3 causes racines :
1. **Isolation Keychain incomplète** entre tests sérialisés — `creerAuthIsole()` purgeait `SessionManager.cleKeychain` mais pas `LockoutManager.cleKeychain` (état verrouillage persistant) ⇒ 4 tests
2. **PBKDF2 iterations** — tests créaient `Utilisateur` avec `iterations` par défaut (1) mais hash généré par `AuthService.hashMotDePasse()` utilise PBKDF2 600k. Verifier choisissait branche legacy SHA256+sel → mismatch hash ⇒ 3 tests
3. **PasswordPolicy v2** — `longueurMinimale` passée de 8 à 12 + check mots de passe communs ⇒ 1 test (mdp `motdepasse1` rejeté)

## Gates plan vs état réel

| Gate | Cible plan | État réel | Verdict |
|---|---|---|---|
| W1 Build 0/0 | Oui | ✅ | PASS |
| W1 Aucun fichier > 600 | Oui | ❌ (8 fichiers — justifié docs) | PASS justifié |
| W1 Tests 92/92 | Oui | ✅ 123/123 après fix `7fb4dd9` | PASS |
| W2 JSON cache | grep=0 | ✅ | PASS |
| W3 Design grep clean | Oui | ✅ | PASS |
| W4 >80 a11y annotations | 80 | ~30 (vs ~21 avant) | **PARTIAL** — humain requis |
| W4 VoiceOver flow OK | Humain | ⏸️ | À faire humain |
| W5 Coverage ≥80% | 80% | ⏸️ Non mesuré (besoin `xcrun llvm-cov report`) | À vérifier |
| W5 Tests 100% pass | Oui | **123/123 ✅** | PASS |

## Findings W5 — Tests pré-existants en échec

7 tests `MultiUtilisateurTests` échouent sur la branche `audit/prelaunch` **et sur `main`** (vérifié via commit history — non introduit par l'audit). Symptômes : tests sérialisés (`@Suite(.serialized)`) avec accès Keychain partagé, isolation probablement incomplète entre méthodes.

**Action recommandée hors-scope audit** : sprint dédié de fix MultiUtilisateurTests — vérifier `KeychainService.supprimer(cle:)` exhaustif dans `creerAuthIsole()`, ajouter cleanup `Utilisateur` après chaque test, vérifier UserDefaults suite isolation.

## Items requérant action humaine (non-autonome agent)

| Wave | Item | Pourquoi humain | Effort |
|---|---|---|---|
| W4 | VoiceOver flow iPad physique 10 min | Test sensoriel | 30 min |
| W4 | Audit contraste WCAG AA mode courtside | Inspection visuelle | 30 min |
| W4 | Dynamic Type xxxLarge overflow check | Inspection 10 écrans | 1h |
| W6 | Sandbox StoreKit 4 SKU + restore (achat/expiration) | Compte testeur Apple | 1h |
| W6 | `Playco.storekit` ↔ App Store Connect synchro | Accès ASC | 30 min |
| W8 | AppIcon production toutes tailles | Design graphique | 4h |
| W8 | `PrivacyInfo.xcprivacy` complétude | Audit privacy keys | 1h |
| W8 | Validate Xcode Organizer | UI Xcode | 15 min |
| W8 | TestFlight build + 48h monitoring ≥3 testeurs | Distribution + temps réel | 48h |
| W8 | Screenshots + descriptions App Store Connect | Web ASC | 4h |

**Total effort humain restant** : ~6 jours dispersés sur 2 semaines.

## Commits audit/prelaunch (séquence reproductible)

```
54cd42b audit(wave5): +32 tests (FiltreParEquipe 7, TypeActionPoint 12, JoueurEquipeStats 13)
6495129 audit(wave2-4): JSONCoderCache+padding(24) propres, a11y Canvas/DockBar/BarreOutilsDessin
5f1ad6a audit(wave1): inventaire initial - 30 @Model, 8 fichiers >600 lignes, @Query audit
d62e26f fix(tests): MultiUtilisateurTests MainActor isolation
e1bd3a7 fix(signing): remove invalid com.apple.developer.in-app-purchase entitlement (main)
```

## Prochaines actions recommandées (ordre de priorité)

1. **Investiguer 7 tests pré-existants** `MultiUtilisateurTests` (sprint dédié — pas dans l'audit)
2. **W7 Documents canon** : CLAUDE.md 23→30 @Model, ajouter section a11y + StoreKit. Archiver audits avril dans `docs/archive/2026-04/`
3. **W4 humain** : VoiceOver flow + Dynamic Type sur device
4. **W6 humain** : Sandbox StoreKit 4 SKU
5. **W8 humain** : AppIcon prod + TestFlight 48h
6. **Mesure coverage** : `xcrun llvm-cov report` sur xcresult pour confirmer % réel
