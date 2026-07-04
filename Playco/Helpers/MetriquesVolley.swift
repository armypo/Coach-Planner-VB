//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Source unique des formules statistiques volleyball (décisions D1-D5) :
//  - D1 : tous les ratios sont des fractions 0-1 — le formatage est le seul
//    endroit où l'échelle change (FormatMetriques).
//  - D3 : blocs pondérés (seuls + 0,5 × assistés) pour les points.
//  - D5 : contexte de service reconstruit depuis la séquence des points
//    (le gagnant d'un rallye sert le suivant ; le serveur initial d'un set
//    dépend de la parité du set et de Seance.nousServonsEnPremier).
//  Vérrouillé par MetriquesVolleyTests.
//

import Foundation

/// Définition d'une métrique pour le glossaire et les légendes.
struct DefinitionMetrique: Identifiable {
    var id: String { abreviation }
    let nom: String
    let abreviation: String
    let definition: String
}

/// Formules statistiques pures — aucune dépendance UI ni SwiftData (les
/// fonctions consomment des valeurs ou des modèles déjà chargés).
enum MetriquesVolley {

    // MARK: - Ratios (fractions 0-1)

    /// Rendement attaque (hitting %) = (Kills − Erreurs) / Tentatives.
    static func rendementAttaque(kills: Int, erreurs: Int, tentatives: Int) -> Double {
        guard tentatives > 0 else { return 0 }
        return Double(kills - erreurs) / Double(tentatives)
    }

    /// Efficacité réception = (Réussies − Erreurs) / Totales.
    static func efficaciteReception(reussies: Int, erreurs: Int, totales: Int) -> Double {
        guard totales > 0 else { return 0 }
        return Double(reussies - erreurs) / Double(totales)
    }

    /// Kill % = Kills / Tentatives.
    static func killPct(kills: Int, tentatives: Int) -> Double {
        guard tentatives > 0 else { return 0 }
        return Double(kills) / Double(tentatives)
    }

    // MARK: - Points (D3 : blocs pondérés)

    /// Points marqués = Kills + Aces + Blocs seuls + 0,5 × Blocs assistés.
    static func points(kills: Int, aces: Int, blocsSeuls: Int, blocsAssistes: Int) -> Double {
        Double(kills + aces + blocsSeuls) + 0.5 * Double(blocsAssistes)
    }

    /// Moyenne par set — 0 si aucun set joué.
    static func parSet(_ valeur: Double, setsJoues: Int) -> Double {
        guard setsJoues > 0 else { return 0 }
        return valeur / Double(setsJoues)
    }

    // MARK: - Note de réception (0-3)

    /// Moyenne des qualités de réception (0 = erreur, 1-3 = qualité saisie).
    static func noteReception(qualites: [Int]) -> Double {
        guard !qualites.isEmpty else { return 0 }
        return Double(qualites.reduce(0, +)) / Double(qualites.count)
    }

    // MARK: - Contexte de service (D5)

    /// Reconstruit qui servait à chaque point : le serveur initial du set
    /// dépend de la parité (sets impairs = premier serveur du match), puis
    /// le gagnant d'un rallye sert le suivant.
    static func reconstruireService(points: [PointMatch], seance: Seance) -> [UUID: Bool] {
        var contexte: [UUID: Bool] = [:]
        let parSet = Dictionary(grouping: points, by: \.set)
        for (set, pointsDuSet) in parSet {
            let ordonnes = pointsDuSet.sorted { $0.horodatage < $1.horodatage }
            var nousServons = (set % 2 == 1) == seance.nousServonsEnPremier
            for point in ordonnes {
                contexte[point.id] = nousServons
                nousServons = point.estPointPourNous
            }
        }
        return contexte
    }

    /// Sideout % = rallyes gagnés en réception / rallyes joués en réception.
    static func sideoutPct(points: [PointMatch], seance: Seance) -> Double {
        ratioRallyes(points: points, seance: seance, auService: false)
    }

    /// % au service = rallyes gagnés à notre service / rallyes à notre service.
    static func pctAuService(points: [PointMatch], seance: Seance) -> Double {
        ratioRallyes(points: points, seance: seance, auService: true)
    }

    private static func ratioRallyes(points: [PointMatch], seance: Seance,
                                     auService: Bool) -> Double {
        let contexte = reconstruireService(points: points, seance: seance)
        let rallyes = points.filter { contexte[$0.id] == auService }
        guard !rallyes.isEmpty else { return 0 }
        let gagnes = rallyes.filter(\.estPointPourNous).count
        return Double(gagnes) / Double(rallyes.count)
    }

    // MARK: - Runs (séries de points consécutifs)

    struct Run: Equatable {
        let debutIndex: Int
        let longueur: Int
        let pourNous: Bool
    }

    /// Détecte les séries d'au moins `minimum` points consécutifs pour un
    /// même camp (points triés par horodatage ; index dans l'ordre trié).
    static func detecterRuns(points: [PointMatch], minimum: Int) -> [Run] {
        let ordonnes = points.sorted { $0.horodatage < $1.horodatage }
        guard minimum > 0, !ordonnes.isEmpty else { return [] }

        var runs: [Run] = []
        var debut = 0
        var campCourant = ordonnes[0].estPointPourNous
        var longueur = 1

        for index in 1..<ordonnes.count {
            let pourNous = ordonnes[index].estPointPourNous
            if pourNous == campCourant {
                longueur += 1
            } else {
                if longueur >= minimum {
                    runs.append(Run(debutIndex: debut, longueur: longueur, pourNous: campCourant))
                }
                debut = index
                campCourant = pourNous
                longueur = 1
            }
        }
        if longueur >= minimum {
            runs.append(Run(debutIndex: debut, longueur: longueur, pourNous: campCourant))
        }
        return runs
    }

    // MARK: - Glossaire (D4 : terminologie unique)

    static let catalogue: [DefinitionMetrique] = [
        DefinitionMetrique(
            nom: "Rendement attaque", abreviation: "Rend.",
            definition: "(Kills − Erreurs) ÷ Tentatives d'attaque. Affiché en convention volleyball : .350 = 35 %. Au-dessus de .300, c'est excellent."),
        DefinitionMetrique(
            nom: "Kill %", abreviation: "K%",
            definition: "Kills ÷ Tentatives d'attaque : la part des attaques qui marquent directement."),
        DefinitionMetrique(
            nom: "Efficacité réception", abreviation: "Réc. eff.",
            definition: "(Réceptions réussies − Erreurs) ÷ Réceptions totales."),
        DefinitionMetrique(
            nom: "Note de réception", abreviation: "Note réc.",
            definition: "Moyenne des réceptions notées de 0 (erreur directe) à 3 (parfaite, toutes les options d'attaque). Au-dessus de 2,0, la distribution est confortable."),
        DefinitionMetrique(
            nom: "Sideout %", abreviation: "SO%",
            definition: "Part des rallyes gagnés quand l'adversaire sert. La métrique n°1 du volleyball moderne : viser 60 % et plus."),
        DefinitionMetrique(
            nom: "% au service", abreviation: "PS%",
            definition: "Part des rallyes gagnés sur notre propre service (point scoring %)."),
        DefinitionMetrique(
            nom: "% points gagnés", abreviation: "PG%",
            definition: "Points gagnés ÷ points joués, tous contextes confondus (service et réception)."),
        DefinitionMetrique(
            nom: "Points", abreviation: "Pts",
            definition: "Kills + Aces + Blocs seuls + 0,5 × Blocs assistés (convention NCAA/FIVB)."),
        DefinitionMetrique(
            nom: "Kills", abreviation: "K",
            definition: "Attaques qui marquent directement le point."),
        DefinitionMetrique(
            nom: "Erreurs d'attaque", abreviation: "E",
            definition: "Attaques dehors, dans le filet ou contrées directement."),
        DefinitionMetrique(
            nom: "Tentatives d'attaque", abreviation: "TA",
            definition: "Toutes les attaques tentées (kills + erreurs + attaques défendues)."),
        DefinitionMetrique(
            nom: "Aces", abreviation: "AC",
            definition: "Services qui marquent directement le point."),
        DefinitionMetrique(
            nom: "Erreurs de service", abreviation: "SE",
            definition: "Services manqués (filet ou dehors)."),
        DefinitionMetrique(
            nom: "Blocs seuls", abreviation: "BS",
            definition: "Blocs marquants réalisés seul au filet."),
        DefinitionMetrique(
            nom: "Blocs assistés", abreviation: "BA",
            definition: "Blocs marquants réalisés à deux ou trois (comptés 0,5 point chacun)."),
        DefinitionMetrique(
            nom: "Manchettes", abreviation: "M",
            definition: "Défenses en manchette qui gardent le ballon en jeu."),
        DefinitionMetrique(
            nom: "Passes décisives", abreviation: "PD",
            definition: "Passes qui mènent directement à un kill."),
    ]
}

/// Formatage canonique des métriques (D2) : hitting en convention volleyball
/// « .350 », tout le reste en pourcentage français « 85,0 % ». Formats
/// déterministes (indépendants de la locale du simulateur).
enum FormatMetriques {

    /// Convention volleyball : fraction 0-1 → « .350 », « -.050 », « 1.000 ».
    static func hittingVolley(_ ratio: Double) -> String {
        let signe = ratio < 0 ? "-" : ""
        let brut = String(format: "%.3f", abs(ratio))
        let corps = brut.hasPrefix("0.") ? String(brut.dropFirst()) : brut
        return signe + corps
    }

    /// Fraction 0-1 → pourcentage français : « 85,0 % ».
    static func pourcentage(_ ratio: Double, decimales: Int = 1) -> String {
        let brut = String(format: "%.\(decimales)f", ratio * 100)
            .replacingOccurrences(of: ".", with: ",")
        return "\(brut) %"
    }

    /// Points pondérés : décimale seulement si nécessaire (« 12 », « 12,5 »).
    static func points(_ valeur: Double) -> String {
        if valeur.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(valeur))
        }
        return String(format: "%.1f", valeur).replacingOccurrences(of: ".", with: ",")
    }

    /// Note de réception sur 3 : « 2,3 ».
    static func note(_ valeur: Double) -> String {
        String(format: "%.1f", valeur).replacingOccurrences(of: ".", with: ",")
    }
}
