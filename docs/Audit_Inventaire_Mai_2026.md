# Audit Inventaire — Pré-lancement App Store (mai 2026)

> Date : 2026-05-18. Branche : `audit/prelaunch`. Référence plan : `~/.claude/plans/plan-audit-elegant-puddle.md`.

## État réel vs plan (corrections importantes)

| Item du plan | État réel constaté | Action |
|---|---|---|
| 8 warnings `@MainActor` `FileReplicationUtilisateur` | **0 warning** (corrigés dans `4887b10`) | ✅ W1.1 déjà fait — retirer de la liste |
| 23 @Model (CLAUDE.md) | **30 @Model** distincts | 📝 W7 mettre à jour docs |
| 24 @Model (plan) | **30 @Model** distincts | 📝 W7 mettre à jour docs |
| DashboardMatchLiveView 781 lignes | **781 lignes confirmé** | W1.2 à faire |

## Inventaire des 30 @Model

```
Abonnement, ActionRallye, AssistantCoach, CategorieExercice, CredentialAthlete,
CreneauRecurrent, Equipe, Etablissement, Evaluation, Exercice,
ExerciceBibliotheque, ExerciceMuscu, FormationPersonnalisee, JoueurEquipe,
MatchCalendrier, MessageEquipe, ObjectifJoueur, PhaseSaison, PointMatch,
Presence, ProfilCoach, ProgrammeMuscu, ScoutingReport, Seance, SeanceMuscu,
StaffPermissions, StatsMatch, StrategieCollective, TestPhysique, Utilisateur
```

Nouveaux modèles vs CLAUDE.md (23) : `Abonnement`, `ActionRallye`, `CategorieExercice`, `CredentialAthlete`, `ExerciceMuscu`, `ObjectifJoueur`, `PhaseSaison`, `StaffPermissions` (= +8 → cohérent avec waves d'évolution v1.5→v1.9).

## Fichiers > 600 lignes (cible W1 : aucun > 600)

| Fichier | Lignes |
|---|---|
| Playco/Views/Matchs/DashboardMatchLiveView.swift | 781 |
| Playco/Views/Equipe/TableauBordView.swift | 748 |
| Playco/Views/Equipe/JoueurDetailView.swift | 690 |
| Playco/Views/Matchs/ScoutingReportView.swift | 658 |
| Playco/Views/Matchs/StatsLiveView.swift | 653 |
| Playco/Views/Configuration/ConfigurationView.swift | 646 |
| Playco/Views/Matchs/HeatmapTerrainView.swift | 642 |
| Playco/Views/Profil/ProfilView.swift | 626 |

→ 8 fichiers à splitter (vs 1 prévu dans le plan). Effort W1.2 réévalué : **+1 jour**.

## @Query sans filtre `estArchivee` (W1.5)

| Fichier | Ligne | Modèle | Filtre archive ? | Décision |
|---|---|---|---|---|
| RechercheGlobaleView | 64 | JoueurEquipe | non | Recherche globale : OK sans filtre — documenter |
| RechercheGlobaleView | 68 | ExerciceBibliotheque | non | Recherche globale : OK — documenter |
| EntrainementView | 24 | SeanceMuscu | non | Pas de soft-delete sur SeanceMuscu — OK |
| AccueilView | 16 | JoueurEquipe | non | Filtré via FiltreParEquipe — documenter |
| AccueilView | 232 | SeanceMuscu | non | Idem entrainement — OK |
| ExerciceDetailView | 19 | FormationPersonnalisee | non | Pas de soft-delete — OK |
| GestionStaffView | 16-17 | AssistantCoach/StaffPermissions | non | Pas de soft-delete — OK |
| ContentView | 32-33 | Equipe/MessageEquipe | non | Pas de soft-delete — OK |
| PratiquesView | 13 | ProfilCoach | non | Pas de soft-delete — OK |
| MessagerieView | 22-23 | MessageEquipe/Utilisateur | non | OK |
| FormationsView | 12 | FormationPersonnalisee | non | OK |
| SelectionEquipeView | 12 | Equipe | non | OK |
| JoueurSuiviMuscuSection | 13/15 | SeanceMuscu/TestPhysique | non | OK |
| ProfilView | 16-17 | Equipe/ProfilCoach | non | OK |
| ObjectifsJoueurView | 14 | ObjectifJoueur | non | Pas de soft-delete — OK |
| IdentifiantsEquipeView | 17-18 | CredentialAthlete/Utilisateur | non | OK |
| EvolutionJoueurView | 89 | StatsMatch | non | OK |
| AnalyticsSaisonView | 14/17 | StatsMatch/PhaseSaison | non | OK |
| TableauBordView | 481 | JoueurEquipe | non | À filtrer par `estActif` ? À vérifier |

**Conclusion W1.5** : Aucun @Query ne manque un filtre `estArchivee` requis — les modèles sans soft-delete sont OK. Seul `TableauBordView:481` est à confirmer (filtrer joueurs inactifs ?).

## Items requérant action humaine (non-autonome)

Ces tâches ne peuvent **pas** être exécutées par l'agent dans la session — surface explicite pour planning humain :

| Wave | Item | Pourquoi humain |
|---|---|---|
| W2.4 | Lancement à froid iPad Air physique | Mesure sur device |
| W3 | Visual diff 10 écrans clés | Inspection visuelle |
| W4.7 | Test VoiceOver iPad physique 10 min | Test sensoriel |
| W4 | Contraste WCAG AA mode courtside | Inspection visuelle |
| W6.1-2 | Sandbox StoreKit 4 SKU + restore | Compte testeur Apple |
| W6.3 | Vérifier `Playco.storekit` ↔ App Store Connect | Accès App Store Connect |
| W8.1 | AppIcon production toutes tailles | Design graphique |
| W8.6 | Validate Xcode Organizer | UI Xcode |
| W8.7 | TestFlight 48h ≥3 testeurs | Distribution + monitoring temps réel |
| W8.8 | Assets App Store Connect (screenshots, descriptions) | Web App Store Connect |

→ **6 jours d'effort humain** à planifier en parallèle des waves agent.

## Prochaines étapes recommandées (autonome)

1. **W1.2** — Splitter `DashboardMatchLiveView` + 7 autres fichiers > 600 lignes (ordre de priorité : DashboardMatchLive, TableauBord, JoueurDetail, ScoutingReport, StatsLive, ConfigurationView, HeatmapTerrain, ProfilView)
2. **W2.1** — Remplacer `JSONDecoder()`/`JSONEncoder()` par `JSONCoderCache` (rapide, mécanique)
3. **W3** — Padding hardcodés + `.shadow()` + `.symbolRenderingMode` (mécanique)
4. **W4** — Ajouts `accessibilityLabel/Hint` (long mais mécanique sur 5 fichiers cibles)
5. **W5** — Écriture tests (lent, ~2j)
6. **W7** — Synchronisation docs CLAUDE.md / AGENTS.md / GEMINI.md (30 @Model, sections A11y/StoreKit, archivage docs avril)

Estimation révisée pour la part autonome : **6-7 jours** (vs 9j initialement). Items humains en parallèle : **2 jours dispersés**.
