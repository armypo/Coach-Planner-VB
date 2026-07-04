//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Jeu de données vitrine du mode DÉMO : roster complet, matchs terminés avec
//  points détaillés (contexte de service, zones, rotations, subs, temps morts),
//  actions de rallye (qualités de réception), exercices avec formations posées
//  et rapport de scouting lié à un match — pour que le hub statistiques,
//  sideout %, note de réception, fil du match, rotations, trajectoires et
//  heatmap efficacité aient tous des données à montrer.
//
//  Compilé uniquement sous la condition `DEMO`. Idempotent : ne peuple que si
//  l'équipe démo n'a encore aucun joueur. Les cumuls carrière passent par
//  AgregateurStatsMatch.finaliserStats (même pipeline que la saisie réelle).
//

#if DEMO
import Foundation
import SwiftData
import SwiftUI
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "DemoBootstrapDonnees")

// MARK: - Générateur déterministe

/// Générateur pseudo-aléatoire déterministe (LCG 64 bits) — la vitrine est
/// identique d'un appareil à l'autre et reproductible pour les captures.
/// `nonisolated` : struct valeur pure utilisable depuis les helpers non isolés
/// (convention projet, comme ConfigMatch/MetriquesVolley).
nonisolated private struct GenerateurDemo {
    private var etat: UInt64

    init(graine: UInt64) { self.etat = graine }

    private mutating func brut() -> UInt64 {
        etat = etat &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return etat
    }

    /// Entier uniforme dans 0..<borne.
    mutating func entier(_ borne: Int) -> Int {
        guard borne > 0 else { return 0 }
        return Int(brut() >> 33) % borne
    }

    /// Vrai avec probabilité `p` (0-1).
    mutating func chance(_ p: Double) -> Bool {
        Double(brut() >> 11) / Double(1 << 53) < p
    }

    /// Élément tiré selon des poids entiers (poids 0 = jamais tiré).
    mutating func pondere<T>(_ paires: [(T, Int)]) -> T {
        let total = paires.reduce(0) { $0 + $1.1 }
        var tirage = entier(max(1, total))
        for paire in paires {
            if tirage < paire.1 { return paire.0 }
            tirage -= paire.1
        }
        return paires[0].0
    }
}

// MARK: - Fiches statiques de la vitrine

private struct FicheJoueurDemo {
    let prenom: String
    let nom: String
    let numero: Int
    let poste: PosteJoueur
    let taille: Int
}

private struct FicheMatchDemo {
    let adversaire: String
    let lieu: String
    let joursAvant: Int
    let sets: [(nous: Int, adv: Int)]
    let nousServonsEnPremier: Bool
}

/// Effectif courant d'un set : les 6 sur le terrain + libéro + banc.
private struct EffectifDemo {
    var surLeTerrain: [JoueurEquipe]
    let libero: JoueurEquipe
    var banc: [JoueurEquipe]
}

/// Résultat de la génération d'un set (valeur pure, fusionnée par l'appelant).
private struct ResultatSetDemo {
    var points: [PointMatch] = []
    var actions: [ActionRallye] = []
    var rotations: [Int] = []
    var rotationsAdv: [Int] = []
    var substitutions: [SubstitutionRecord] = []
    var tempsMorts: [TempsMortRecord] = []
}

// MARK: - Jeu de données vitrine

extension DemoBootstrap {

    /// Peuple le jeu de données vitrine si l'équipe démo est encore vide.
    /// Idempotent : un roster existant (même partiel) bloque tout re-seed —
    /// les installations démo déjà provisionnées reçoivent les données au
    /// prochain lancement, jamais en double.
    @MainActor
    static func peuplerVitrineSiVide(coach: Utilisateur, context: ModelContext) {
        let code = coach.codeEcole
        guard !code.isEmpty else { return }

        var descripteur = FetchDescriptor<JoueurEquipe>(
            predicate: #Predicate { $0.codeEquipe == code }
        )
        descripteur.fetchLimit = 1
        let rosterExistant = (try? context.fetch(descripteur)) ?? []
        guard rosterExistant.isEmpty else { return }

        var generateur = GenerateurDemo(graine: 20_260_704)
        let joueurs = creerRoster(code: code, context: context)
        let matchs = creerMatchsTermines(joueurs: joueurs, code: code,
                                         context: context, generateur: &generateur)
        creerMatchAVenir(code: code, context: context)
        creerPratiqueAvecFormations(code: code, context: context)
        if let dernierMatch = matchs.last {
            creerScoutingReport(pour: dernierMatch, code: code, context: context)
        }

        do {
            try context.save()
            logger.info("Vitrine démo créée : \(joueurs.count) joueurs, \(matchs.count) matchs terminés")
        } catch {
            logger.error("Sauvegarde de la vitrine démo échouée: \(error.localizedDescription)")
        }
    }

    // MARK: - Roster (~12 joueurs)

    @MainActor
    private static func creerRoster(code: String, context: ModelContext) -> [JoueurEquipe] {
        let fiches: [FicheJoueurDemo] = [
            FicheJoueurDemo(prenom: "Émile", nom: "Tremblay", numero: 4, poste: .passeur, taille: 183),
            FicheJoueurDemo(prenom: "Nathan", nom: "Gagnon", numero: 9, poste: .recepteur, taille: 188),
            FicheJoueurDemo(prenom: "Loïc", nom: "Bouchard", numero: 7, poste: .central, taille: 196),
            FicheJoueurDemo(prenom: "Félix", nom: "Côté", numero: 11, poste: .oppose, taille: 192),
            FicheJoueurDemo(prenom: "Samuel", nom: "Lavoie", numero: 3, poste: .recepteur, taille: 186),
            FicheJoueurDemo(prenom: "Antoine", nom: "Fortin", numero: 13, poste: .central, taille: 194),
            FicheJoueurDemo(prenom: "Olivier", nom: "Gauthier", numero: 6, poste: .libero, taille: 175),
            FicheJoueurDemo(prenom: "William", nom: "Morin", numero: 10, poste: .passeur, taille: 181),
            FicheJoueurDemo(prenom: "Thomas", nom: "Pelletier", numero: 2, poste: .recepteur, taille: 184),
            FicheJoueurDemo(prenom: "Xavier", nom: "Bélanger", numero: 15, poste: .oppose, taille: 190),
            FicheJoueurDemo(prenom: "Jacob", nom: "Girard", numero: 8, poste: .central, taille: 191),
            FicheJoueurDemo(prenom: "Alexis", nom: "Roy", numero: 17, poste: .libero, taille: 173),
        ]

        let equipeDescripteur = FetchDescriptor<Equipe>(
            predicate: #Predicate { $0.codeEquipe == code }
        )
        let equipe = (try? context.fetch(equipeDescripteur))?.first

        return fiches.enumerated().map { index, fiche in
            let joueur = JoueurEquipe(nom: fiche.nom, prenom: fiche.prenom,
                                      numero: fiche.numero, poste: fiche.poste)
            joueur.codeEquipe = code
            joueur.taille = fiche.taille
            joueur.equipe = equipe
            joueur.dateNaissance = Calendar.current.date(
                byAdding: DateComponents(year: -18, month: -(index % 12)), to: Date())
            context.insert(joueur)
            return joueur
        }
    }

    // MARK: - Matchs terminés

    @MainActor
    private static func creerMatchsTermines(joueurs: [JoueurEquipe], code: String,
                                            context: ModelContext,
                                            generateur: inout GenerateurDemo) -> [Seance] {
        let fiches: [FicheMatchDemo] = [
            FicheMatchDemo(adversaire: "Titans de Limoilou", lieu: "Palestre du Club Démo",
                           joursAvant: 35, sets: [(25, 20), (23, 25), (25, 18), (25, 21)],
                           nousServonsEnPremier: true),
            FicheMatchDemo(adversaire: "Carabins de Sainte-Foy", lieu: "Gymnase Sainte-Foy",
                           joursAvant: 28, sets: [(25, 17), (25, 22), (25, 19)],
                           nousServonsEnPremier: false),
            FicheMatchDemo(adversaire: "Nordiques de Lévis", lieu: "Palestre du Club Démo",
                           joursAvant: 21, sets: [(25, 22), (20, 25), (25, 23), (18, 25), (12, 15)],
                           nousServonsEnPremier: true),
            FicheMatchDemo(adversaire: "Phénix de l'Estrie", lieu: "Complexe sportif de l'Estrie",
                           joursAvant: 10, sets: [(22, 25), (25, 20), (21, 25), (25, 16), (15, 11)],
                           nousServonsEnPremier: false),
            FicheMatchDemo(adversaire: "Dynamo de Trois-Rivières", lieu: "Palestre du Club Démo",
                           joursAvant: 3, sets: [(25, 27), (25, 21), (19, 25), (22, 25)],
                           nousServonsEnPremier: true),
        ]

        let titulaires = alignementDepart(joueurs: joueurs)
        let libero = joueurs.first { $0.poste == .libero } ?? joueurs[0]

        return fiches.map { fiche in
            creerMatch(fiche: fiche, joueurs: joueurs, titulaires: titulaires,
                       libero: libero, code: code, context: context, generateur: &generateur)
        }
    }

    /// Six de départ en 5-1, ordonné par poste terrain 1→6 : P, R, C, O, R, C.
    @MainActor
    private static func alignementDepart(joueurs: [JoueurEquipe]) -> [JoueurEquipe] {
        let numerosDepart = [4, 9, 7, 11, 3, 13]
        return numerosDepart.compactMap { numero in joueurs.first { $0.numero == numero } }
    }

    @MainActor
    private static func creerMatch(fiche: FicheMatchDemo, joueurs: [JoueurEquipe],
                                   titulaires: [JoueurEquipe], libero: JoueurEquipe,
                                   code: String, context: ModelContext,
                                   generateur: inout GenerateurDemo) -> Seance {
        let dateMatch = dateRelative(jours: -fiche.joursAvant)
        let seance = Seance(nom: "Match vs \(fiche.adversaire)", date: dateMatch, typeSeance: .match)
        seance.adversaire = fiche.adversaire
        seance.lieu = fiche.lieu
        seance.codeEquipe = code
        seance.nousServonsEnPremier = fiche.nousServonsEnPremier
        seance.partants = titulaires.enumerated().map { PartantMatch(poste: $0.offset + 1, joueurID: $0.element.id) }
        seance.liberoUUID = libero.id
        context.insert(seance)

        var points: [PointMatch] = []
        var actions: [ActionRallye] = []
        var rotationsParSet: [Int: [Int]] = [:]
        var rotationsAdvParSet: [Int: [Int]] = [:]
        var substitutions: [SubstitutionRecord] = []
        var tempsMorts: [TempsMortRecord] = []
        var joueursUtilises: Set<UUID> = Set(titulaires.map(\.id) + [libero.id])

        for (indexSet, cible) in fiche.sets.enumerated() {
            let numeroSet = indexSet + 1
            var effectif = EffectifDemo(
                surLeTerrain: titulaires,
                libero: libero,
                banc: joueurs.filter { joueur in
                    !titulaires.contains(where: { $0.id == joueur.id }) && joueur.id != libero.id
                })
            let resultat = genererSet(seance: seance, numeroSet: numeroSet, cible: cible,
                                      effectif: &effectif, code: code,
                                      horodatageBase: dateMatch.addingTimeInterval(Double(indexSet) * 1_900),
                                      generateur: &generateur)
            points.append(contentsOf: resultat.points)
            actions.append(contentsOf: resultat.actions)
            rotationsParSet[numeroSet] = resultat.rotations
            rotationsAdvParSet[numeroSet] = resultat.rotationsAdv
            substitutions.append(contentsOf: resultat.substitutions)
            tempsMorts.append(contentsOf: resultat.tempsMorts)
            joueursUtilises.formUnion(resultat.substitutions.map(\.joueurEntrantID))
        }

        seance.sets = fiche.sets.enumerated().map {
            SetScore(numero: $0.offset + 1, scoreEquipe: $0.element.nous, scoreAdversaire: $0.element.adv)
        }
        seance.rotationsHistorique = rotationsParSet
        seance.rotationsHistoriqueAdv = rotationsAdvParSet
        seance.substitutions = substitutions
        seance.tempsMorts = tempsMorts
        seance.compositionJoueurs = Array(joueursUtilises)

        points.forEach { context.insert($0) }
        actions.forEach { context.insert($0) }

        // Même pipeline que la saisie réelle : StatsMatch créés + cumuls
        // carrière resynchronisés (idempotent, B2) depuis TOUS les matchs.
        let statsExistants = (try? context.fetch(FetchDescriptor<StatsMatch>())) ?? []
        AgregateurStatsMatch.finaliserStats(seance: seance, points: points, actions: actions,
                                            statsExistants: statsExistants, joueurs: joueurs,
                                            codeEquipe: code, contexte: context)
        return seance
    }

    // MARK: - Génération d'un set

    @MainActor
    private static func genererSet(seance: Seance, numeroSet: Int, cible: (nous: Int, adv: Int),
                                   effectif: inout EffectifDemo, code: String,
                                   horodatageBase: Date,
                                   generateur: inout GenerateurDemo) -> ResultatSetDemo {
        var resultat = ResultatSetDemo()
        let vainqueurs = sequenceVainqueurs(cible: cible, generateur: &generateur)

        // Même règle que le live (D5) : le serveur initial dépend de la parité
        // du set et de nousServonsEnPremier ; le gagnant d'un rallye sert le suivant.
        var nousServons = (numeroSet % 2 == 1) == seance.nousServonsEnPremier
        var rotation = 1
        var rotationAdv = 1
        var scoreNous = 0
        var scoreAdv = 0
        var horloge = horodatageBase
        let indexSubstitution = vainqueurs.count * 3 / 5
        let setPerdu = cible.nous < cible.adv

        for (index, pourNous) in vainqueurs.enumerated() {
            horloge = horloge.addingTimeInterval(Double(35 + generateur.entier(35)))
            if pourNous { scoreNous += 1 } else { scoreAdv += 1 }

            let action = choisirTypeAction(pourNous: pourNous, nousServons: nousServons,
                                           generateur: &generateur)
            let point = PointMatch(seanceID: seance.id, set: numeroSet,
                                   joueurID: joueurPourAction(action, effectif: effectif,
                                                              generateur: &generateur),
                                   typeAction: action)
            point.scoreEquipeAuMoment = scoreNous
            point.scoreAdversaireAuMoment = scoreAdv
            point.rotationAuMoment = rotation
            point.rotationAdvAuMoment = rotationAdv
            point.codeEquipe = code
            point.horodatage = horloge
            point.nousServionsAuMoment = nousServons
            point.serviceRenseigne = true
            assignerZones(point, generateur: &generateur)
            resultat.points.append(point)

            resultat.actions.append(contentsOf: genererActionsRallye(
                pour: point, nousServions: nousServons, effectif: effectif,
                code: code, generateur: &generateur))

            if let tempsMort = tempsMortEventuel(set: numeroSet, scoreNous: scoreNous,
                                                 scoreAdv: scoreAdv, horloge: horloge,
                                                 dejaPris: resultat.tempsMorts,
                                                 generateur: &generateur) {
                resultat.tempsMorts.append(tempsMort)
            }

            if index == indexSubstitution, setPerdu || generateur.chance(0.4),
               let substitution = effectuerSubstitution(set: numeroSet, effectif: &effectif,
                                                        scoreNous: scoreNous, scoreAdv: scoreAdv,
                                                        horloge: horloge, generateur: &generateur) {
                resultat.substitutions.append(substitution)
            }

            // Sideout : l'équipe en réception qui marque tourne et prend le service.
            if pourNous && !nousServons {
                nousServons = true
                rotation = (rotation % 6) + 1
                resultat.rotations.append(rotation)
            } else if !pourNous && nousServons {
                nousServons = false
                rotationAdv = (rotationAdv % 6) + 1
                resultat.rotationsAdv.append(rotationAdv)
            }
        }
        return resultat
    }

    /// Séquence des vainqueurs de rallye : mélange déterministe qui atteint
    /// exactement le score cible, dernier point au gagnant du set.
    nonisolated private static func sequenceVainqueurs(cible: (nous: Int, adv: Int),
                                           generateur: inout GenerateurDemo) -> [Bool] {
        let vainqueurFinal = cible.nous > cible.adv
        var pool = Array(repeating: true, count: cible.nous - (vainqueurFinal ? 1 : 0))
            + Array(repeating: false, count: cible.adv - (vainqueurFinal ? 0 : 1))
        var index = pool.count - 1
        while index > 0 {
            pool.swapAt(index, generateur.entier(index + 1))
            index -= 1
        }
        return pool + [vainqueurFinal]
    }

    // MARK: - Choix d'action et de joueur

    /// Type d'action cohérent avec le contexte de service : un ace exige que
    /// l'équipe qui marque serve, une erreur de réception que l'autre serve.
    nonisolated private static func choisirTypeAction(pourNous: Bool, nousServons: Bool,
                                          generateur: inout GenerateurDemo) -> TypeActionPoint {
        if pourNous {
            if nousServons {
                return generateur.pondere([
                    (.kill, 45), (.ace, 10), (.blocSeul, 8), (.blocAssiste, 12),
                    (.erreurAttaqueAdversaire, 15), (.erreurAdversaire, 10),
                ])
            }
            return generateur.pondere([
                (.kill, 50), (.blocSeul, 7), (.blocAssiste, 10),
                (.erreurAttaqueAdversaire, 13), (.erreurServiceAdversaire, 12),
                (.erreurAdversaire, 8),
            ])
        }
        if nousServons {
            return generateur.pondere([
                (.killAdversaire, 40), (.erreurService, 18), (.erreurAttaque, 20),
                (.blocAdversaire, 8), (.fauteJeu, 6), (.erreurBloc, 8),
            ])
        }
        return generateur.pondere([
            (.killAdversaire, 35), (.aceAdversaire, 8), (.erreurReception, 12),
            (.erreurAttaque, 25), (.blocAdversaire, 8), (.fauteJeu, 5), (.erreurBloc, 7),
        ])
    }

    /// Joueur crédité de l'action — nil pour les stats adverses.
    private static func joueurPourAction(_ action: TypeActionPoint, effectif: EffectifDemo,
                                         generateur: inout GenerateurDemo) -> UUID? {
        guard !action.estStatAdversaire else { return nil }
        switch action {
        case .kill, .erreurAttaque:
            return tirerJoueur(effectif.surLeTerrain, poids: poidsAttaque, generateur: &generateur)
        case .ace, .erreurService:
            return tirerJoueur(effectif.surLeTerrain, poids: poidsService, generateur: &generateur)
        case .blocSeul, .blocAssiste, .erreurBloc, .bloc:
            return tirerJoueur(effectif.surLeTerrain, poids: poidsBloc, generateur: &generateur)
        case .erreurReception:
            return tirerJoueur(effectif.surLeTerrain + [effectif.libero],
                               poids: poidsReception, generateur: &generateur)
        case .fauteJeu, .erreurEquipe:
            return effectif.surLeTerrain[generateur.entier(effectif.surLeTerrain.count)].id
        default:
            return nil
        }
    }

    nonisolated private static func tirerJoueur(_ candidats: [JoueurEquipe], poids: (PosteJoueur) -> Int,
                                    generateur: inout GenerateurDemo) -> UUID? {
        let paires = candidats.map { ($0.id, poids($0.poste)) }.filter { $0.1 > 0 }
        guard !paires.isEmpty else { return nil }
        return generateur.pondere(paires)
    }

    nonisolated private static func poidsAttaque(_ poste: PosteJoueur) -> Int {
        switch poste {
        case .recepteur: return 30
        case .oppose: return 28
        case .central: return 15
        case .passeur: return 3
        case .libero: return 0
        }
    }

    nonisolated private static func poidsService(_ poste: PosteJoueur) -> Int {
        poste == .libero ? 0 : 15
    }

    nonisolated private static func poidsBloc(_ poste: PosteJoueur) -> Int {
        switch poste {
        case .central: return 35
        case .oppose: return 20
        case .recepteur: return 12
        case .passeur: return 8
        case .libero: return 0
        }
    }

    nonisolated private static func poidsReception(_ poste: PosteJoueur) -> Int {
        switch poste {
        case .libero: return 40
        case .recepteur: return 25
        case .oppose: return 4
        case .passeur: return 2
        case .central: return 2
        }
    }

    // MARK: - Zones (heatmap + trajectoires)

    /// Assigne zone d'arrivée et zone de départ sur une partie des points —
    /// comme une vraie saisie où le coach ne renseigne pas tout.
    private static func assignerZones(_ point: PointMatch, generateur: inout GenerateurDemo) {
        switch point.typeAction.categorieHeatmap {
        case .attaque:
            guard generateur.chance(0.72) else { return }
            point.zone = generateur.pondere([(1, 25), (5, 22), (6, 20), (4, 13), (2, 10), (3, 10)])
            if generateur.chance(0.8) {
                point.zoneDepart = generateur.pondere([(4, 40), (2, 25), (3, 20), (1, 8), (6, 7)])
            }
        case .service:
            guard generateur.chance(0.8) else { return }
            point.zone = generateur.pondere([(1, 22), (5, 25), (6, 30), (2, 8), (3, 7), (4, 8)])
            point.zoneDepart = generateur.pondere([(1, 55), (6, 30), (5, 15)])
        case .bloc:
            guard generateur.chance(0.65) else { return }
            point.zone = generateur.pondere([(2, 30), (3, 40), (4, 30)])
        case .reception:
            guard generateur.chance(0.75) else { return }
            point.zone = generateur.pondere([(1, 30), (6, 35), (5, 25), (2, 5), (3, 3), (4, 2)])
        case nil:
            return
        }
    }

    // MARK: - Actions de rallye

    /// Actions non-marquantes autour d'un point : réception notée (0-3 via la
    /// qualité), passe décisive sur kill, tentatives d'attaque, digs, manchettes.
    private static func genererActionsRallye(pour point: PointMatch, nousServions: Bool,
                                             effectif: EffectifDemo, code: String,
                                             generateur: inout GenerateurDemo) -> [ActionRallye] {
        var actions: [ActionRallye] = []

        func ajouter(_ type: TypeActionRallye, joueurID: UUID, qualite: Int = 0, decalage: TimeInterval) {
            let action = ActionRallye(seanceID: point.seanceID, set: point.set,
                                      joueurID: joueurID, typeAction: type)
            action.qualite = qualite
            action.codeEquipe = code
            action.horodatage = point.horodatage.addingTimeInterval(decalage)
            action.pointMatchID = point.id
            actions.append(action)
        }

        // Réception notée : l'adversaire servait et le service n'a été ni un
        // ace contre nous ni une erreur de réception directe.
        if !nousServions, point.typeAction != .aceAdversaire, point.typeAction != .erreurReception,
           let receveur = tirerJoueur(effectif.surLeTerrain + [effectif.libero],
                                      poids: poidsReception, generateur: &generateur) {
            let qualite = generateur.pondere([(3, 30), (2, 45), (1, 25)])
            ajouter(.reception, joueurID: receveur, qualite: qualite, decalage: -12)
        }

        // Passe décisive du passeur sur la grande majorité de nos kills.
        if point.typeAction == .kill, generateur.chance(0.78),
           let passeur = effectif.surLeTerrain.first(where: { $0.poste == .passeur }) {
            ajouter(.passeDecisive, joueurID: passeur.id, decalage: -6)
        }

        // Tentatives d'attaque gardées en jeu — ramène le rendement vers ~.200.
        if generateur.chance(0.5),
           let attaquant = tirerJoueur(effectif.surLeTerrain, poids: poidsAttaque,
                                       generateur: &generateur) {
            ajouter(.tentativeAttaque, joueurID: attaquant, decalage: -9)
        }

        // Défense : digs (libéro surtout) et manchettes occasionnelles.
        if generateur.chance(0.28) {
            let defenseur = generateur.chance(0.6)
                ? effectif.libero.id
                : effectif.surLeTerrain[generateur.entier(effectif.surLeTerrain.count)].id
            ajouter(.dig, joueurID: defenseur, decalage: -4)
        }
        if generateur.chance(0.2) {
            let joueur = effectif.surLeTerrain[generateur.entier(effectif.surLeTerrain.count)].id
            ajouter(.manchette, joueurID: joueur, decalage: -3)
        }

        // Service en jeu quand nous servions sans ace ni faute.
        if nousServions, point.typeAction != .ace, point.typeAction != .erreurService,
           generateur.chance(0.8),
           let serveur = tirerJoueur(effectif.surLeTerrain, poids: poidsService,
                                     generateur: &generateur) {
            ajouter(.serviceEnJeu, joueurID: serveur, decalage: -15)
        }

        return actions
    }

    // MARK: - Temps morts & substitutions

    /// Temps mort quand l'écart se creuse (max 2 par équipe par set, comme la config FIVB).
    private static func tempsMortEventuel(set: Int, scoreNous: Int, scoreAdv: Int,
                                          horloge: Date, dejaPris: [TempsMortRecord],
                                          generateur: inout GenerateurDemo) -> TempsMortRecord? {
        let equipe: String
        if scoreAdv - scoreNous == 4 { equipe = "nous" }
        else if scoreNous - scoreAdv == 5 { equipe = "adversaire" }
        else { return nil }

        let prisCeSet = dejaPris.filter { $0.set == set && $0.equipe == equipe }.count
        guard prisCeSet < 2, generateur.chance(0.6) else { return nil }

        var tempsMort = TempsMortRecord(set: set, equipe: equipe)
        tempsMort.scoreNousAuMoment = scoreNous
        tempsMort.scoreAdvAuMoment = scoreAdv
        tempsMort.horodatage = horloge.addingTimeInterval(5)
        return tempsMort
    }

    /// Substitution poste-pour-poste depuis le banc, effectif mis à jour pour
    /// que les actions suivantes créditent l'entrant.
    private static func effectuerSubstitution(set: Int, effectif: inout EffectifDemo,
                                              scoreNous: Int, scoreAdv: Int, horloge: Date,
                                              generateur: inout GenerateurDemo) -> SubstitutionRecord? {
        let sortants = effectif.surLeTerrain.filter { $0.poste == .recepteur || $0.poste == .oppose }
        guard !sortants.isEmpty else { return nil }
        let sortant = sortants[generateur.entier(sortants.count)]
        guard let entrant = effectif.banc.first(where: { $0.poste == sortant.poste })
                ?? effectif.banc.first else { return nil }

        guard let indexTerrain = effectif.surLeTerrain.firstIndex(where: { $0.id == sortant.id }),
              let indexBanc = effectif.banc.firstIndex(where: { $0.id == entrant.id }) else { return nil }
        effectif.surLeTerrain[indexTerrain] = entrant
        effectif.banc[indexBanc] = sortant

        var substitution = SubstitutionRecord(set: set, joueurSortantID: sortant.id,
                                              joueurEntrantID: entrant.id)
        substitution.scoreNousAuMoment = scoreNous
        substitution.scoreAdvAuMoment = scoreAdv
        substitution.horodatage = horloge.addingTimeInterval(8)
        return substitution
    }

    // MARK: - Match à venir

    @MainActor
    private static func creerMatchAVenir(code: String, context: ModelContext) {
        let match = Seance(nom: "Match vs Titans de Limoilou",
                           date: dateRelative(jours: 4), typeSeance: .match)
        match.adversaire = "Titans de Limoilou"
        match.lieu = "Aréna de Limoilou"
        match.codeEquipe = code
        context.insert(match)
    }

    // MARK: - Pratique avec formations posées

    @MainActor
    private static func creerPratiqueAvecFormations(code: String, context: ModelContext) {
        let pratique = Seance(nom: "Pratique — système 5-1",
                              date: dateRelative(jours: 2, heure: 18), typeSeance: .pratique)
        pratique.codeEquipe = code
        context.insert(pratique)

        let exerciceReception = Exercice(
            nom: "Réception 5-1 — rotation 1",
            notes: "Formation de réception R1 : le libéro couvre les zones 5-6, les réceptionneurs prennent les couloirs. Objectif : note de réception 2,0+.",
            ordre: 0, duree: 15)
        exerciceReception.typeTerrain = TypeTerrain.indoor.rawValue
        exerciceReception.elementsData = elementsFormation(
            .cinqUn, rotation: 0, mode: .reception,
            trajectoires: [trajectoireService()])

        let exerciceAttaque = Exercice(
            nom: "Transition attaque — 5-1 rotation 1",
            notes: "Sortie de réception vers l'attaque : premier tempo au centre, ballon de sécurité à l'ailier. Varier les cibles zones 1 et 5.",
            ordre: 1, duree: 20)
        exerciceAttaque.typeTerrain = TypeTerrain.indoor.rawValue
        exerciceAttaque.elementsData = elementsFormation(
            .cinqUn, rotation: 0, mode: .attaque,
            trajectoires: [trajectoireAttaque(versY: 0.18), trajectoireAttaque(versY: 0.85)])

        if pratique.exercices == nil { pratique.exercices = [] }
        for exercice in [exerciceReception, exerciceAttaque] {
            context.insert(exercice)
            exercice.seance = pratique
            pratique.exercices?.append(exercice)
        }
    }

    /// Jetons de formation identiques à ceux du panneau formations (mêmes
    /// positions et couleurs par poste), plus des trajectoires d'illustration.
    private static func elementsFormation(_ type: FormationType, rotation: Int,
                                          mode: FormationMode,
                                          trajectoires: [ElementTerrain]) -> Data? {
        let jetons = type.positions(rotation: rotation, mode: mode).map { position in
            ElementTerrain(type: .joueur, x: position.x, y: position.y,
                           label: position.label,
                           couleur: FormationType.couleurPourLabel(position.label))
        }
        return try? JSONCoderCache.encoder.encode(jetons + trajectoires)
    }

    /// Trajectoire de service adverse : du fond du camp droit vers notre zone 6.
    private static func trajectoireService() -> ElementTerrain {
        ElementTerrain(type: .trajectoire, x: 0.95, y: 0.30, toX: 0.15, toY: 0.55,
                       ctrlX: 0.55, ctrlY: 0.10, estPointille: true, couleur: PaletteMat.bleu)
    }

    /// Trajectoire d'attaque : de notre zone 4 vers le camp adverse.
    private static func trajectoireAttaque(versY: Double) -> ElementTerrain {
        ElementTerrain(type: .trajectoire, x: 0.44, y: 0.18, toX: 0.85, toY: versY,
                       ctrlX: 0.62, ctrlY: (0.18 + versY) / 2 - 0.08,
                       estPointille: true, couleur: PaletteMat.orange)
    }

    // MARK: - Rapport de scouting

    /// Rapport lié au match terminé le plus récent — montre la vue lecture et
    /// « prédictions vs réalité » (les points du match existent).
    @MainActor
    private static func creerScoutingReport(pour seance: Seance, code: String,
                                            context: ModelContext) {
        let rapport = ScoutingReport()
        rapport.adversaire = seance.adversaire
        rapport.seanceID = seance.id
        rapport.dateMatch = seance.date
        rapport.dateCreation = seance.date.addingTimeInterval(-5 * 86_400)
        rapport.codeEquipe = code
        rapport.systemJeu = "5-1"
        rapport.styleJeu = "Offensif"
        rapport.adversaireObserve = "Nordiques de Lévis"
        rapport.notes = "Équipe rapide au centre, servie par un passeur expérimenté. Prendre le service flottant du #12 au sérieux dès le premier set."

        rapport.joueurs = [
            JoueurAdverse(numero: 12, nom: "M.-A. Deschamps", poste: "Opposé",
                          pointsForts: "Service flottant agressif, diagonale puissante",
                          pointsFaibles: "Défense basse en zone 5", menaceNiveau: 5),
            JoueurAdverse(numero: 8, nom: "T. Lachance", poste: "Central",
                          pointsForts: "Premier tempo, bloc en lecture",
                          pointsFaibles: "Lent sur les ballons dispersés", menaceNiveau: 4),
            JoueurAdverse(numero: 3, nom: "É. Paradis", poste: "Passeur",
                          pointsForts: "Distribution variée, deuxième main au filet",
                          pointsFaibles: "Réception courte le déstabilise", menaceNiveau: 3),
            JoueurAdverse(numero: 5, nom: "J. Bergeron", poste: "Réceptionneur",
                          pointsForts: "Régulier en réception",
                          pointsFaibles: "Attaque prévisible sur la ligne", menaceNiveau: 2),
        ]
        rapport.forces = [
            "Attaque rapide au centre (premier tempo)",
            "Pression constante au service",
            "Bloc organisé sur l'aile gauche",
        ]
        rapport.faiblesses = [
            "Couverture de zone 5 en défense",
            "Réception sur services courts",
            "Transition lente après un bloc touché",
        ]
        rapport.strategies = [
            StrategieRecommandee(titre: "Servir court en zone 2",
                                 description: "Forcer le réceptionneur à remonter et couper le premier tempo du central #8.",
                                 priorite: 1, categorie: "Service"),
            StrategieRecommandee(titre: "Attaquer la diagonale zone 5",
                                 description: "La couverture basse du #12 laisse la diagonale longue ouverte en zone 5.",
                                 priorite: 1, categorie: "Attaque"),
            StrategieRecommandee(titre: "Bloc double sur l'opposé",
                                 description: "Fermer la ligne au #12 et laisser la défense prendre la diagonale.",
                                 priorite: 2, categorie: "Bloc"),
        ]
        rapport.tendanceService = "Sert long zones 5 et 6, flottant du #12 en fin de set"
        rapport.tendanceAttaque = "Premier tempo au centre dès que la réception est parfaite"
        rapport.tendanceReception = "Libéro glisse en zone 6, faiblesse sur services courts zone 2"
        rapport.tendanceBloc = "Bloc double systématique sur l'aile gauche adverse"
        rapport.tendancesZonales = TendancesZonales(
            service: [5: 3, 6: 2, 1: 1],
            attaque: [4: 3, 3: 2, 2: 1])

        context.insert(rapport)
    }

    // MARK: - Dates

    /// Date relative à aujourd'hui, calée sur une heure de match/pratique.
    private static func dateRelative(jours: Int, heure: Int = 19) -> Date {
        let base = Calendar.current.date(byAdding: .day, value: jours, to: Date()) ?? Date()
        return Calendar.current.date(bySettingHour: heure, minute: 0, second: 0, of: base) ?? base
    }
}
#endif
