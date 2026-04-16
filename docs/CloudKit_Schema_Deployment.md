# Déploiement du schéma CloudKit — Production

**Dernière mise à jour :** 15 avril 2026
**Container :** `iCloud.Origo.Playco`
**Environnement source :** Development
**Environnement cible :** Production

---

## Contexte

Playco utilise SwiftData avec `ModelConfiguration(cloudKitDatabase: .automatic)`. Le schéma CloudKit est auto-généré en **Development** dès que l'app tourne sur un build de dev, mais il doit être **explicitement déployé** en **Production** via le Dashboard CloudKit avant la soumission App Store.

**Sans ce déploiement :** les utilisateurs App Store ne recevront **aucune donnée** et la sync multi-device ne fonctionnera pas.

**Opération irréversible :** une fois le schéma poussé en production, les types de record ne peuvent plus être supprimés (Apple limite strictement les destructive changes).

---

## Pré-requis

- [ ] Compte Apple Developer actif avec accès au container `iCloud.Origo.Playco`
- [ ] Build TestFlight v1.9.x déjà validé localement
- [ ] Les 27 @Model SwiftData fonctionnels en Development CloudKit (vérifié via 2 devices)
- [ ] `project.pbxproj` : `MARKETING_VERSION = 1.9.0`, `CURRENT_PROJECT_VERSION >= 2`
- [ ] `Playco.entitlements` : `aps-environment = production`

---

## Liste des 27 types de record attendus

SwiftData préfixe automatiquement chaque `@Model` par `CD_` lors de la génération CloudKit.

| # | Type CloudKit | @Model Swift |
|---|---------------|--------------|
| 1 | `CD_Seance` | Seance |
| 2 | `CD_Exercice` | Exercice |
| 3 | `CD_ExerciceBibliotheque` | ExerciceBibliotheque |
| 4 | `CD_JoueurEquipe` | JoueurEquipe |
| 5 | `CD_StrategieCollective` | StrategieCollective |
| 6 | `CD_FormationPersonnalisee` | FormationPersonnalisee |
| 7 | `CD_Utilisateur` | Utilisateur |
| 8 | `CD_Presence` | Presence |
| 9 | `CD_Evaluation` | Evaluation |
| 10 | `CD_ExerciceMuscu` | ExerciceMuscu |
| 11 | `CD_ProgrammeMuscu` | ProgrammeMuscu |
| 12 | `CD_SeanceMuscu` | SeanceMuscu |
| 13 | `CD_TestPhysique` | TestPhysique |
| 14 | `CD_StatsMatch` | StatsMatch |
| 15 | `CD_Etablissement` | Etablissement |
| 16 | `CD_ProfilCoach` | ProfilCoach |
| 17 | `CD_Equipe` | Equipe |
| 18 | `CD_AssistantCoach` | AssistantCoach |
| 19 | `CD_CreneauRecurrent` | CreneauRecurrent |
| 20 | `CD_MatchCalendrier` | MatchCalendrier |
| 21 | `CD_MessageEquipe` | MessageEquipe |
| 22 | `CD_ScoutingReport` | ScoutingReport |
| 23 | `CD_PointMatch` | PointMatch |
| 24 | `CD_ActionRallye` | ActionRallye |
| 25 | `CD_PhaseSaison` | PhaseSaison |
| 26 | `CD_ObjectifJoueur` | ObjectifJoueur |
| 27 | `CD_CategorieExercice` | CategorieExercice |
| 28 | `CD_StaffPermissions` | StaffPermissions |

*Note : `EvenementSync` est un `struct Codable` (pas un @Model), stocké en UserDefaults → pas dans CloudKit.*

---

## Procédure pas à pas

### 1. Accéder au Dashboard CloudKit

1. Ouvrir [https://icloud.developer.apple.com/dashboard/](https://icloud.developer.apple.com/dashboard/)
2. Se connecter avec le compte Apple Developer Origo Technologies
3. Sélectionner le container **`iCloud.Origo.Playco`**

### 2. Vérifier le schéma Development

1. Onglet **Schema** en haut
2. Sélectionner l'environnement **Development**
3. Section **Record Types** à gauche
4. Vérifier que **28 types** sont listés, tous préfixés `CD_`
5. Cliquer sur chaque type pour valider :
   - Les champs correspondent aux propriétés du `@Model` Swift
   - Les index sont présents (`createdAt`, `modifiedAt`, `recordName`, et tout champ avec `@Attribute(.unique)`)

### 3. Déployer vers Production

1. Toujours dans l'onglet **Schema** en Development
2. Bouton **Deploy Schema Changes to Production...** (en haut à droite)
3. Une modale apparaît avec la liste des changements
4. **Relire attentivement** la liste des types qui seront créés
5. Confirmer le déploiement

> ⚠️ **IRRÉVERSIBLE.** Une fois confirmé, le schéma est figé en production. Les types peuvent être étendus (nouveaux champs), mais pas supprimés.

### 4. Vérifier le déploiement Production

1. Basculer sur l'environnement **Production** (toggle en haut)
2. Confirmer que les 28 types `CD_*` sont bien présents
3. Vérifier qu'aucun champ ou index ne manque

### 5. Test end-to-end sur 2 devices

1. Installer le build TestFlight sur **device A** (iPad Air 13" M3)
2. Créer une équipe + 3 joueurs via le wizard
3. Attendre ~30 secondes (sync CloudKit)
4. Installer le build TestFlight sur **device B** (autre iPad avec le même compte iCloud)
5. Se connecter → vérifier que l'équipe et les joueurs apparaissent
6. Modifier un joueur sur B → vérifier la propagation vers A en < 1 min

---

## Commandes de validation post-déploiement

### Côté app (logs)

```bash
# Filtrer les logs CloudKit de Playco sur le device connecté via Xcode
log stream --predicate 'subsystem == "com.origotech.playco" AND category == "CloudKitSync"' --level info
```

Logs attendus :
- `ModelContainer CloudKit initialisé`
- `Compte iCloud disponible`
- `Sync CloudKit : initialisation du schéma`
- `Sync CloudKit terminée`

### Côté Dashboard

- Onglet **Data** en Production
- Filtrer par type `CD_Seance`, `CD_JoueurEquipe`, etc.
- Vérifier que les records créés côté device apparaissent dans le dashboard

---

## Rollback

**Pas de rollback Production possible** une fois le déploiement confirmé.

**En Development**, pour repartir à zéro :
1. Dashboard → Development → Schema
2. Bouton **Reset Development Schema** (en bas)
3. Tous les types sont supprimés, il faut relancer l'app pour les régénérer

En cas de bug majeur découvert après déploiement Production :
- **Ajouter un champ** : OK, rétrocompatible, pousser une mise à jour app
- **Renommer un champ** : ajouter le nouveau champ, déprécier l'ancien en lecture seule
- **Supprimer un type** : impossible via Dashboard. Abandonner l'utilisation en code, ignorer les données orphelines dans le container

---

## Troubleshooting

| Symptôme | Cause probable | Fix |
|---|---|---|
| Types `CD_*` absents en Development | L'app n'a jamais tourné avec ce schéma | Lancer l'app sur simulateur ou device dev, créer au moins 1 record de chaque type |
| "Schema mismatch" sur device utilisateur | Déploiement Production incomplet | Re-vérifier tous les types en Production, re-pousser si nécessaire |
| Sync marche en dev mais pas en prod TestFlight | `aps-environment = development` dans les entitlements | Passer en `production` et re-signer |
| "Quota exceeded" lors des premiers tests | Stockage gratuit iCloud 1 Go dépassé sur comptes dev | Nettoyer les vieilles données dev via Dashboard → Data → Delete |
| Records créés sur device A invisibles sur device B | Compte iCloud différent OU permissions container | Vérifier Settings → iCloud → Playco activé, même Apple ID |
| Erreur `CKError.serverResponseLost` répétée | Problème réseau ou serveur CloudKit | Relancer l'app ; si persistent, vérifier [System Status Apple](https://www.apple.com/ca/support/systemstatus/) |
| `NSPersistentCloudKitContainer` ne se déclenche pas | `modeMatchActif` reste bloqué à true | Vérifier `CloudKitSyncService.activerModeMatch(false)` appelé à la fin d'un match |

---

## Checklist de validation finale

Avant de soumettre à l'App Store :

- [ ] Schéma production comporte les 28 types `CD_*`
- [ ] Test multi-device réussi (< 1 min de latence de sync)
- [ ] `aps-environment = production` dans `Playco.entitlements`
- [ ] Build TestFlight 1.9.x validé par au moins 2 utilisateurs beta sur devices différents
- [ ] Journal de sync (`JournalSyncView`) ne montre **aucune erreur** pendant les tests
- [ ] Aucune modification de `@Model` depuis le déploiement (sinon, redéployer)

---

*Document à maintenir à chaque ajout/modification d'un `@Model` SwiftData.*
