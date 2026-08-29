# Journal d'exécution — Pivot Coach-First

> Trace de chaque opération du pivot (branche `pivot/coach-first`), pour la revue de PR différée (GitHub indisponible au moment de l'exécution — décision fondateur 2026-08-29 : « continue et on va PR plus tard, garde des traces »). Plan de référence : [Pivot_CoachFirst_Plan.md](./Pivot_CoachFirst_Plan.md).

## 2026-08-29 — Mise en place

- **Analyse** (2026-08-26/29) : 7 agents d'exploration + critique de complétude sur `suivis/pr6` ; décisions fondateur D1-D6 actées ; revue diff-par-diff des 25 commits de la boucle de nuit (8 groupes) → verdict : merge intégral.
- **Branche** : `pivot/coach-first` créée sur `c233bb6` (tête de `CChristo/agitated-mcnulty-c2cefa` = main v2.2 + boucle de nuit des 6-7 juil.). Le « merge de la nuit » est donc porté par cette branche ; la PR vers `main` (nuit + pivot) se fera au retour de GitHub. `suivis/pr6` (démo) sera rebasée après ce retour sur `main`.
- **Docs** : bandeaux ARCHIVE PRÉ-PIVOT posés sur `Vision_Playco_3.0.md` et `Roadmap_Playco_v2.2_v3.x.md` ; plan chantiers A-E versionné (`Pivot_CoachFirst_Plan.md`) ; ce journal créé.

## Chantier A — Suppression paywall + messagerie ✅ 2026-08-29

- `ed5a1aa` **feat(pivot-A): app gratuite — suppression complète du paywall StoreKit (D3)** — ~2 100 lignes supprimées (services, ViewModel, 6 vues, helpers, .storekit, framework, 10 gates, bannière, paywall de bienvenue, section abonnement, erreurGate, 8 événements analytics, lecture AbonnementPartage). `migrerAssistantsVersNouveauRole` extraite vers `Services/MigrationRoles.swift`. `Abonnement` @Model + `Equipe.tierAbonnementRaw` conservés au schéma. Tests supprimés : PaywallViewModelTests, PaywallTextesTests, FeatureGatingTests ; AbonnementCodeEquipeTests adaptée.
- `ac6a5ac` **feat(pivot-A): retrait de la messagerie (D1) + fix warnings MetricKit** — MessagerieView, PolitiqueMessagerie (+6 tests), item Messages du Dock, badges/non-lus, page tutoriel messagerie. `MessageEquipe` @Model conservé (schéma + cascade). Fix annexe : 5 warnings d'isolation MetricKitService (toolchain courante).
- **Vérification** : build 0 erreur / 0 warning (iPad Pro 13-inch M5) ; **275/275 tests, 43 suites** (base nuit 303 − 28 tests paywall/messagerie supprimés).

## Chantier B — Retrait athlète

_(en cours)_
