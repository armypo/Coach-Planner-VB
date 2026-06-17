# TODO — Partage coach→athlète · Login cross-Apple-ID · Paywall (juin 2026)

> Document de suivi vivant. Statuts : ✅ fait · ⏳ en cours · ☐ à faire · 🚫 hors-code (humain).
> Build/tests sous Xcode 27 beta via `DEVELOPER_DIR`, tests **en série** (`-parallel-testing-enabled NO`).

## Objectif
(1) Bonnes données partagées coach→athlète cross-Apple-ID, (2) connexion athlète fonctionnelle, (3) paywall rafraîchi. Corrige 3 bugs bloquants + ajoute calendrier & stats perso en lecture seule.

## Phases

| # | Phase | Statut | Effort |
|---|-------|--------|--------|
| P0 | Préparation modèles (dateModification/codeEquipe) | ✅ | S |
| P1+P2 | Login « Rejoindre » + tier dans la gate | ✅ | L |
| P3 | Rafraîchir paywall (achat/restore + foreground) | ✅ | S |
| P4 | Sync incrémentale câblée (athlète/assistant) | ✅ | S |
| P5 | Données partagées lecture seule (calendrier + stats) | ✅ | L |
| P6 | Tests (série) | ✅ | M |
| P7 | Sécurité CloudKit (action humaine) | ⚠️ | — |

**État build/tests :** `** BUILD SUCCEEDED **` 0/0 (iOS 27) · **150/150 tests** verts en série (132 + 18 nouveaux partage/sécurité). Compat iOS 26.3 vérifiée.

**Note d'architecture :** plutôt que des triggers de publication éparpillés, un **sweep coach unique** `CloudKitSharingService.publierMisesAJourCoach(codeEquipe:context:)` (basé sur `dateModification`, respecte `masquerPratiquesAthletes`) est appelé au foreground/appear du coach (ContentView, via `synchroniserDonneesPartagees()` role-aware). Les créations posent `codeEquipe`+`dateModification` ; le sweep republie. Côté athlète/assistant, le même point appelle `syncDepuisPublic`.

---

### P0 — Préparation modèles ⏳
- ✅ `Seance.dateModification` (default `Date()`).
- ✅ `MatchCalendrier.codeEquipe` + `dateModification` (defaults).
- ☐ Build vert (migration SwiftData safe).

### P1+P2 — Login + gate tier
- ☐ `RejoindreEquipeView` (code+identifiant+mdp → equipeExiste → recupererEtImporterEquipe → connexion → vérif appartenance).
- ☐ 3e carte « Rejoindre avec un code » dans `ChoixInitialView`.
- ☐ `PlaycoApp` : écran `.rejoindre` + routage.
- ☐ Tier sourcé via `CloudKitPublicSyncAbonnement.lire` à l'import (`recupererEtImporterEquipe`).
- ☐ `appliquerGateTier()` async + fallback Public DB + transition `.app` centralisée ; 3 appelants mis à jour.

### P3 — Rafraîchir paywall
- ☐ `rafraichir()` après `acheter()`/`restaurer()` (PaywallView + injection AuthService/modelContext).
- ☐ `rafraichir()` coach sur `scenePhase == .active` (ContentView).

### P4 — Sync incrémentale
- ☐ `syncIncrementaleSiConsommateur()` → `syncDepuisPublic` (appear + foreground), athlète/assistant.

### P5 — Données partagées (lecture seule)
- ☐ Record types `SeancePartagee` + `MatchCalendrierPartagee` (publier/importer + merge).
- ☐ Stats cumulées (~16 champs) sur `JoueurPartage` (+ helper `appliquerStats`).
- ☐ Inclure séances/matchs dans `syncDepuisPublic` + `recupererEtImporterEquipe`.
- ☐ Triggers coach : `CalendrierView`, `SaisieStatsMatchView`, `ConfigurationView` (respecter `masquerPratiquesAthletes` à la publication).
- ☐ Vérifier lecture seule athlète (`.siAutorise` sur boutons d'écriture).

### P6 — Tests (série)
- ☐ Import `SeancePartagee`/`MatchCalendrierPartagee`/stats + merge `dateModification`.
- ☐ Flux jonction (appartenance + normalisation code).
- ☐ Gate tier async.
- ☐ Suite complète verte (132 + nouveaux) en série.

### P7 — Sécurité CloudKit ⚠️
- ✅ Vérif code : **aucune PII/hash** sur `SeancePartagee`/`MatchCalendrierPartagee` ni sur les stats de `JoueurPartage` (vérifié) ; **aucun `publier*` depuis une vue athlète** (gating `.siAutorise` + sweep role-gated, vérifié).
- 🚫 **Dashboard (action humaine)** : rôle d'écriture **créateur-seul** sur `SeancePartagee` + `MatchCalendrierPartagee` (s'ajoute aux `*Partage` + `AbonnementPartage` déjà tracés dans `docs/Securite_AbonnementPublicDB.md`). Créer les record types avec les champs publiés (cf. `publierSeance`/`publierMatchCalendrier`) en Development + Production, puis Deploy.

---

## Décisions produit (défauts retenus)
- Stats **cumulées uniquement** (pas StatsMatch/PointMatch par match).
- `masquerPratiquesAthletes` respecté **à la publication** (pas de pratiques publiées si activé).
- Publication stats depuis box score (`SaisieStatsMatchView`) + édition profil.
