//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Agrégation unique PointMatch + ActionRallye → compteurs par joueur.
//  Sémantique de référence : le switch historique de finaliserMatch
//  (MatchDetailView), verrouillée par AgregateurStatsMatchTests.
//  Remplace les 3 copies dupliquées (dashboard live, finalisation, box score).
//

import Foundation
import SwiftData

/// Compteurs de stats d'un joueur pour un match (struct valeur, pur).
struct CompteursJoueur: Equatable {
    var kills = 0
    var erreursAttaque = 0
    var tentativesAttaque = 0
    var aces = 0
    var erreursService = 0
    var servicesTotaux = 0
    var blocsSeuls = 0
    var blocsAssistes = 0
    var erreursBloc = 0
    var receptionsReussies = 0
    var erreursReception = 0
    var receptionsTotales = 0
    var passesDecisives = 0
    var manchettes = 0
    var setsJoues = 0
    /// Qualités de réception (0-3) collectées pour la note de réception —
    /// une erreur de réception (PointMatch) compte 0.
    var qualitesReception: [Int] = []
    /// Compteurs d'affichage live (non persistés dans StatsMatch) :
    var fautes = 0
    var digs = 0
    var servicesEnJeu = 0
}

enum AgregateurStatsMatch {

    /// Agrège les points et actions d'un match en compteurs par joueur.
    /// Un point sans joueur (ex. erreur adverse non attribuée) est ignoré ;
    /// les actions adverses ne créditent aucun compteur mais comptent pour
    /// les sets joués du joueur qui les a saisies.
    static func agreger(points: [PointMatch], actions: [ActionRallye]) -> [UUID: CompteursJoueur] {
        var compteurs: [UUID: CompteursJoueur] = [:]
        var setsParJoueur: [UUID: Set<Int>] = [:]

        for point in points {
            guard let joueurID = point.joueurID else { continue }
            var c = compteurs[joueurID] ?? CompteursJoueur()

            switch point.typeAction {
            case .kill:
                c.kills += 1
                c.tentativesAttaque += 1
            case .erreurAttaque:
                c.erreursAttaque += 1
                c.tentativesAttaque += 1
            case .ace:
                c.aces += 1
                c.servicesTotaux += 1
            case .erreurService:
                c.erreursService += 1
                c.servicesTotaux += 1
            case .blocSeul, .bloc:
                c.blocsSeuls += 1
            case .blocAssiste:
                c.blocsAssistes += 1
            case .erreurBloc:
                c.erreursBloc += 1
            case .erreurReception:
                c.erreursReception += 1
                c.receptionsTotales += 1
                c.qualitesReception.append(0)
            case .fauteJeu, .erreurEquipe:
                c.fautes += 1
            case .erreurAdversaire,
                 .killAdversaire, .aceAdversaire, .blocAdversaire,
                 .erreurAttaqueAdversaire, .erreurServiceAdversaire:
                break
            }

            compteurs[joueurID] = c
            setsParJoueur[joueurID, default: []].insert(point.set)
        }

        for action in actions {
            let joueurID = action.joueurID
            var c = compteurs[joueurID] ?? CompteursJoueur()

            switch action.typeAction {
            case .manchette:
                c.manchettes += 1
            case .passeDecisive:
                c.passesDecisives += 1
            case .reception:
                c.receptionsTotales += 1
                if action.qualite >= 2 {
                    c.receptionsReussies += 1
                }
                c.qualitesReception.append(action.qualite)
            case .tentativeAttaque:
                c.tentativesAttaque += 1
            case .serviceEnJeu:
                c.servicesEnJeu += 1
            case .dig:
                c.digs += 1
            }

            compteurs[joueurID] = c
            setsParJoueur[joueurID, default: []].insert(action.set)
        }

        for (joueurID, sets) in setsParJoueur {
            compteurs[joueurID]?.setsJoues = sets.count
        }
        return compteurs
    }

    /// Finalise un match : agrège les points/actions en StatsMatch (créés ou
    /// complétés), puis resynchronise le cumul carrière des joueurs touchés.
    /// IMPORTANT : les StatsMatch créés ICI sont unis à `statsExistants` avant
    /// la resynchronisation — un snapshot @Query pris avant l'appel ne les
    /// contient pas (finding CRITICAL de la revue Phase 1, couvert par
    /// FinalisationMatchTests).
    @MainActor
    static func finaliserStats(
        seance: Seance,
        points: [PointMatch],
        actions: [ActionRallye],
        statsExistants: [StatsMatch],
        joueurs: [JoueurEquipe],
        codeEquipe: String,
        contexte: ModelContext
    ) {
        guard !seance.statsEntrees else { return }

        let compteurs = agreger(points: points, actions: actions)
        var statsPourResync = statsExistants

        for (joueurID, c) in compteurs {
            let stat: StatsMatch
            if let existant = statsExistants.first(where: {
                $0.seanceID == seance.id && $0.joueurID == joueurID
            }) {
                stat = existant
            } else {
                stat = StatsMatch(seanceID: seance.id, joueurID: joueurID)
                stat.codeEquipe = codeEquipe
                contexte.insert(stat)
                statsPourResync.append(stat)
            }

            // Comportement historique conservé : les compteurs s'AJOUTENT à un
            // StatsMatch préexistant (saisie manuelle partielle).
            stat.kills += c.kills
            stat.erreursAttaque += c.erreursAttaque
            stat.tentativesAttaque += c.tentativesAttaque
            stat.aces += c.aces
            stat.erreursService += c.erreursService
            stat.servicesTotaux += c.servicesTotaux
            stat.blocsSeuls += c.blocsSeuls
            stat.blocsAssistes += c.blocsAssistes
            stat.erreursBloc += c.erreursBloc
            stat.receptionsReussies += c.receptionsReussies
            stat.erreursReception += c.erreursReception
            stat.receptionsTotales += c.receptionsTotales
            stat.passesDecisives += c.passesDecisives
            stat.manchettes += c.manchettes
            stat.setsJoues = c.setsJoues
        }

        let joueursTouches = joueurs.filter { compteurs.keys.contains($0.id) }
        resynchroniserCumul(joueurs: joueursTouches, statsMatch: statsPourResync)
        for joueur in joueursTouches {
            // Bump pour que le sweep coach republie les stats à jour (Public DB).
            joueur.dateModification = Date()
        }

        seance.statsEntrees = true
    }

    /// Recalcule le cumul carrière d'un joueur depuis la somme de ses
    /// StatsMatch (idempotent — corrige aussi les cumuls doublés, bug B2).
    static func resynchroniserCumul(joueurs: [JoueurEquipe], statsMatch: [StatsMatch]) {
        for joueur in joueurs {
            let stats = statsMatch.filter { $0.joueurID == joueur.id }

            var cumul = CompteursJoueur()
            var seances = Set<UUID>()
            for stat in stats {
                seances.insert(stat.seanceID)
                cumul.setsJoues += stat.setsJoues
                cumul.kills += stat.kills
                cumul.erreursAttaque += stat.erreursAttaque
                cumul.tentativesAttaque += stat.tentativesAttaque
                cumul.aces += stat.aces
                cumul.erreursService += stat.erreursService
                cumul.servicesTotaux += stat.servicesTotaux
                cumul.blocsSeuls += stat.blocsSeuls
                cumul.blocsAssistes += stat.blocsAssistes
                cumul.erreursBloc += stat.erreursBloc
                cumul.receptionsReussies += stat.receptionsReussies
                cumul.erreursReception += stat.erreursReception
                cumul.receptionsTotales += stat.receptionsTotales
                cumul.passesDecisives += stat.passesDecisives
                cumul.manchettes += stat.manchettes
            }

            joueur.matchsJoues = seances.count
            joueur.setsJoues = cumul.setsJoues
            joueur.attaquesReussies = cumul.kills
            joueur.erreursAttaque = cumul.erreursAttaque
            joueur.attaquesTotales = cumul.tentativesAttaque
            joueur.aces = cumul.aces
            joueur.erreursService = cumul.erreursService
            joueur.servicesTotaux = cumul.servicesTotaux
            joueur.blocsSeuls = cumul.blocsSeuls
            joueur.blocsAssistes = cumul.blocsAssistes
            joueur.erreursBloc = cumul.erreursBloc
            joueur.receptionsReussies = cumul.receptionsReussies
            joueur.erreursReception = cumul.erreursReception
            joueur.receptionsTotales = cumul.receptionsTotales
            joueur.passesDecisives = cumul.passesDecisives
            joueur.manchettes = cumul.manchettes
        }
    }
}
