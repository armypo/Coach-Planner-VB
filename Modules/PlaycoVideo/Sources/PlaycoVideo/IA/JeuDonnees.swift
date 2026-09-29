//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Export du jeu de données d'entraînement : un échantillon étiqueté par
//  clip, en JSON Lines. Les étiquettes viennent GRATUITEMENT du coaching
//  (stats live). Garde-fous Loi 25 : aucun export sans consentement propre à
//  cette finalité ; minimisation (ni code d'équipe, ni joueur par défaut).
//

import Foundation

public struct EchantillonEntrainement: Codable, Hashable, Sendable {
    public static let versionSchemaActuelle = 1

    public var versionSchema: Int
    public var seanceID: UUID
    public var fichierVideo: String
    /// Bornes du clip et instant du tap (secondes vidéo).
    public var debut: Double
    public var fin: Double
    public var instant: Double
    public var etiquette: String
    public var resultat: ResultatEvenement?
    /// Pseudonyme du joueur — seulement si demandé explicitement.
    public var joueurID: UUID?
    public var periode: Int
    public var rotation: Int?
    public var zone: Int?
    public var zoneDepart: Int?
    public var auService: Bool?
}

public enum ErreurJeuDonnees: Error, Equatable {
    /// La vidéo n'a pas le consentement « entraînement de l'IA ».
    case consentementAbsent
}

public enum JeuDonnees {

    public static func echantillons(
        manifeste: ManifesteVideoMatch,
        evenements: [EvenementMatch],
        inclureJoueur: Bool = false
    ) throws -> [EchantillonEntrainement] {
        guard manifeste.consentementEntrainementIA else { throw ErreurJeuDonnees.consentementAbsent }
        return IndexVideo.chapitres(evenements, fichiers: manifeste.alignements, fenetre: manifeste.fenetre).map { c in
            EchantillonEntrainement(
                versionSchema: EchantillonEntrainement.versionSchemaActuelle,
                seanceID: manifeste.seanceID,
                fichierVideo: manifeste.fichiers[c.indexFichier].nomFichier,
                debut: c.debut,
                fin: c.fin,
                instant: c.instant,
                etiquette: c.evenement.etiquette,
                resultat: c.evenement.resultat,
                joueurID: inclureJoueur ? c.evenement.joueurID : nil,
                periode: c.evenement.periode,
                rotation: c.evenement.rotation,
                zone: c.evenement.zone,
                zoneDepart: c.evenement.zoneDepart,
                auService: c.evenement.auService)
        }
    }

    /// Un objet JSON par ligne, clés triées (diffable, lisible en flux).
    public static func jsonLines(_ echantillons: [EchantillonEntrainement]) throws -> Data {
        let encodeur = JSONEncoder()
        encodeur.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        var donnees = Data()
        for echantillon in echantillons {
            donnees.append(try encodeur.encode(echantillon))
            donnees.append(0x0A)
        }
        return donnees
    }
}
