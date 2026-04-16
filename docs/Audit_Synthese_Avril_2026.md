# Audit pré-lancement Playco — Synthèse

**Date :** 15 avril 2026
**Stade :** TestFlight v1.9.0 → préparation lancement officiel septembre 2026
**Scope :** 4 audits parallèles (auth, bugs, performance, App Store)

---

## Verdict général

**L'app est fondamentalement saine.** Les fondations sont solides, le code est propre (0 TODO, 0 print, patterns défensifs appliqués), l'architecture est bien pensée. Mais **5 bloqueurs App Store** doivent être corrigés avant soumission, et **3 bugs à risque crash** doivent être fixés avant d'élargir la beta.

## Scorecard par catégorie

| Catégorie | Score | Statut | Rapport détaillé |
|---|---|---|---|
| **Authentification** | 8/10 | ✅ Robuste avec 3 bugs à corriger | `Audit_Auth_Flow_Avril_2026.md` |
| **Bugs / stabilité** | 8.5/10 | ✅ Très propre (3 bugs critiques isolés) | `Audit_Bugs_Avril_2026.md` |
| **Performance** | 7.5/10 | ⚠️ 3 fichiers > 800 lignes à découper | `Audit_Performance_Avril_2026.md` |
| **Conformité App Store** | 6/10 | ❌ 5 bloqueurs de soumission à fixer | `Audit_Pre_Launch_App_Store_Avril_2026.md` |

---

## 🔴 BLOQUEURS CRITIQUES (empêchent le launch)

### 1. Config projet — bloqueurs automatiques de soumission
**Fichiers :** `Playco.xcodeproj/project.pbxproj` et `Playco.entitlements`

| Clé | Actuel | Doit être | Temps |
|---|---|---|---|
| `MARKETING_VERSION` | `1.0` | `1.9.0` | 2 min |
| `CURRENT_PROJECT_VERSION` | `1` | `2+` (incrémenter à chaque build) | 2 min |
| `aps-environment` | `development` | `production` | 2 min |
| `IPHONEOS_DEPLOYMENT_TARGET` | `26.2` | à vérifier | 5 min |
| `NSPhotoLibraryAddUsageDescription` | Manquant | Ajouter (PhotosPicker utilisé) | 5 min |

**Total : ~15 minutes de fix, rejet automatique si oubliés.**

### 2. Bug auth — Race condition restauration session CloudKit
**Fichier :** `PlaycoApp.swift:150-151`
Utilisateur se connecte, ferme l'app avant fin sync CloudKit, rouvre → session perdue, retour au login.
**Fix :** Attendre `syncService.attendreSyncInitiale()` avant `restaurerSession()`.

### 3. Bug auth — Collision identifiant pendant wizard config
**Fichier :** `ConfigurationView.swift:335` + `Utilisateur.swift:202-206`
Deux joueurs avec même nom → `genererIdentifiantUnique()` ne voit pas les insertions en mémoire → doublons au save.
**Fix :** Maintenir un `Set<String>` des IDs déjà créés pendant le wizard.

### 4. Memory leaks Timer — 3 fichiers
| Fichier | Ligne | Problème |
|---|---|---|
| `DashboardMatchLiveView.swift` | 756-773 | `timerRef` jamais invalidé au deinit |
| `SeanceLiveView.swift` | 504-530 | `timerRepos` + `timerSeance` fuient si vue détruite avant fin |
| `PlaycoApp.swift` | 62 | `try!` sur ModelContainer in-memory (cas limite) |

**Scénario crash :** après 10-15 navigations rapides entre matchs, accumulation de Timers.

### 5. CloudKit schema production non déployé
Le schema (23 @Model) n'a jamais été pushé en production via Dashboard CloudKit. Tant que ce n'est pas fait, les utilisateurs App Store auront des **données vides** et pas de sync multi-device.
**Action :** Dashboard CloudKit → Origo.Playco → Deploy Schema to Production.

---

## 🟠 HAUTE PRIORITÉ (avant beta élargie juin)

### Accessibility — 0 labels trouvés dans tout le codebase
- Rejet probable Apple si VoiceOver testé
- Minimum viable = `accessibilityLabel` sur boutons Mode bord de terrain + actions critiques
- **Effort :** 3-5 jours pour minimum viable

### Strings hardcodées en anglais — Loi 96 Québec
- "Box Score" × 3 (TableauBordView, MatchDetailView, PDFExportService)
- **Fix :** Migration `Localizable.xcstrings` + clés `.localized`. 1 jour.

### Crash reporting absent
- Aucun Sentry / Crashlytics / TelemetryDeck
- **Recommandation :** TelemetryDeck (privacy-first, 1 jour d'install)

### Privacy Policy + Terms URLs
- Bloquant App Store
- **Fix :** Page statique avec données collectées + PIPEDA + avocat québécois

---

## 🟡 MOYENNE PRIORITÉ (avant launch septembre)

### Fichiers > 800 lignes à découper
| Fichier | Lignes |
|---|---|
| `JoueurDetailView.swift` | 974 |
| `BibliothequeView.swift` | 896 |
| `ProfilView.swift` | 869 |
| `DashboardMatchLiveView.swift` | 774 |

**Effort total :** 5-7 heures.

### Autres bugs moyens
- `try?` JSON decoding silencieux → ajouter `logger.warning`
- `try? modelContext.save()` sans error user-facing → wrap en `do/catch`
- `.cornerRadius(4)` magic number dans `AnalyticsSaisonView.swift:287`

### Edge cases auth mineurs
- Code équipe case-insensitive
- Migration hash SHA256→PBKDF2 préparer
- Session expiration (actuellement jamais d'expiration)
- Password strength > 6 chars

---

## 🟢 NICE-TO-HAVE (post-launch OK)

- Dynamic Type support
- Haptics sur toutes les actions création/suppression (partiel)
- Screenshots App Store (5-10 images)
- App Preview video 15s
- Landing page playco.ca
- Découpage des fonctions > 50 lignes non-critiques

---

## Plan d'exécution proposé

### Sprint 1 — Bloqueurs (semaine du 15 avril) · 5h dev
1. Config projet : versions + aps-environment + privacy key (15 min)
2. Fix Timer leaks : 3 fichiers (30 min)
3. Fix race condition auth : PlaycoApp restaurerSession (1h)
4. Fix collision identifiant wizard : Set tracking (45 min)
5. Fix try! PlaycoApp:62 : do/catch gracieux (15 min)
6. Push CloudKit schema en production via Dashboard (1-2h manuel)
7. Build + test complet (30 min)

### Sprint 2 — Conformité (semaines 2-4) · 1-2 semaines
1. Privacy Policy + Terms URLs (1 jour)
2. Localisation strings anglaises (1 jour)
3. TelemetryDeck intégration (1 jour)
4. Accessibility labels minimum viable (3 jours)
5. Découpage JoueurDetailView + DashboardMatchLiveView (2 jours)

### Sprint 3 — Polissage (mai) · 1 semaine
1. Error handling user-facing sur saves critiques
2. Découpage ProfilView + BibliothequeView
3. Edge cases auth
4. Tests manuels des 16 scénarios auth

---

## Checklist tests manuels auth (à exécuter avant chaque release)

1. [ ] Créer équipe avec 2 athlètes même nom → identifiants distincts
2. [ ] Wizard config fermé à mi-parcours → state recovery
3. [ ] Login case-insensitive (`Prenom.Nom` → `prenom.nom`)
4. [ ] Multi-équipes : coach avec 2 équipes → SelectionEquipeView
5. [ ] Code équipe avec espaces et majuscules → normalisation
6. [ ] Athlète supprimé pendant session → déconnexion propre
7. [ ] 5 tentatives échouées → verrouillage 5 min
8. [ ] Verrouillage persistant après fermeture app
9. [ ] Mot de passe avec accents (é, à, ç) → hash correct
10. [ ] Identifiant avec emoji → rejeté avec message clair
11. [ ] CloudKit sync : create device A → visible device B
12. [ ] Race condition : connexion → ferme app → rouvre avant sync → session restaurée
13. [ ] Wizard → auto-login → changement d'équipe → redéconnexion
14. [ ] Session > 30 jours → auto-logout (à implémenter)
15. [ ] Mot de passe < 8 chars → rejeté (à implémenter)
16. [ ] Hash migration ancien compte sans sel → nouveau avec sel

---

## Documents d'audit complémentaires

| Fichier | Contenu |
|---|---|
| `Audit_Auth_Flow_Avril_2026.md` | Analyse détaillée du flux d'authentification (AuthService, LoginView, RejoindreEquipeView, session restoration, edge cases) |
| `Audit_Bugs_Avril_2026.md` | Chasse exhaustive aux bugs (force unwraps, try! / try?, memory leaks, patterns dangereux, TODO/FIXME) |
| `Audit_Performance_Avril_2026.md` | Audit perfs (fichiers trop gros, fonctions longues, caching, computed properties, LiquidGlassKit compliance) |
| `Audit_Pre_Launch_App_Store_Avril_2026.md` | Checklist conformité App Store (Info.plist, entitlements, accessibilité, i18n, CloudKit, legal) |

---

*Dossier généré le 15 avril 2026 · Playco v1.9.0 · 4 audits parallèles synthétisés*
