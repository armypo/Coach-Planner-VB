//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Index vidéo ↔ stats live : chaque événement horodaté devient un chapitre
//  de la vidéo. La saisie de stats EST le découpage. Filtres = listes de clips
//  façon « cutups » ; segments = lecture continue sans sauts inutiles.
//

import Foundation

// MARK: - Fenêtre de clip

/// Fenêtre d'un clip autour du tap de saisie. Le tap arrive APRÈS le rallye :
/// la fenêtre remonte surtout avant. Valeurs ESTIMÉES — à calibrer
/// (`EstimationFenetre`) sur vraie vidéo.
public struct FenetreClip: Codable, Hashable, Sendable {
    public var avant: Double
    public var apres: Double
    /// Un clip borné plus court (événement saisi hors de l'enregistrement) est écarté.
    public var dureeMinimale: Double

    public static let parDefaut = FenetreClip()

    public init(avant: Double = 8, apres: Double = 3, dureeMinimale: Double = 2) {
        self.avant = avant
        self.apres = apres
        self.dureeMinimale = dureeMinimale
    }

    private enum CodingKeys: String, CodingKey { case avant, apres, dureeMinimale }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaut = FenetreClip()
        avant = try c.decodeIfPresent(Double.self, forKey: .avant) ?? defaut.avant
        apres = try c.decodeIfPresent(Double.self, forKey: .apres) ?? defaut.apres
        dureeMinimale = try c.decodeIfPresent(Double.self, forKey: .dureeMinimale) ?? defaut.dureeMinimale
    }
}

// MARK: - Chapitre

/// Un événement situé dans la vidéo.
public struct ChapitreVideo: Codable, Hashable, Sendable, Identifiable {
    public var evenement: EvenementMatch
    /// Fichier du match qui contient le clip (0 pour un match en un fichier).
    public var indexFichier: Int
    /// Position du tap dans ce fichier (secondes, brute — peut dépasser la durée).
    public var instant: Double
    /// Bornes du clip, bornées à [0, durée du fichier].
    public var debut: Double
    public var fin: Double

    public var id: UUID { evenement.id }
    public var duree: Double { fin - debut }

    public init(evenement: EvenementMatch, indexFichier: Int = 0, instant: Double, debut: Double, fin: Double) {
        self.evenement = evenement
        self.indexFichier = indexFichier
        self.instant = instant
        self.debut = debut
        self.fin = fin
    }
}

// MARK: - Filtre

public struct FiltreChapitres: Hashable, Sendable {
    /// Au service = nous servions (point scoring) ; en réception = sideout.
    public enum Phase: String, CaseIterable, Hashable, Sendable {
        case toutes, auService, enReception
    }

    /// Vide = toutes les étiquettes.
    public var etiquettes: Set<String>
    public var joueurID: UUID?
    public var periode: Int?
    public var rotation: Int?
    /// nil = tous les résultats.
    public var resultat: ResultatEvenement?
    public var phase: Phase

    public init(
        etiquettes: Set<String> = [],
        joueurID: UUID? = nil,
        periode: Int? = nil,
        rotation: Int? = nil,
        resultat: ResultatEvenement? = nil,
        phase: Phase = .toutes
    ) {
        self.etiquettes = etiquettes
        self.joueurID = joueurID
        self.periode = periode
        self.rotation = rotation
        self.resultat = resultat
        self.phase = phase
    }

    /// Une information inconnue (résultat, service) n'est jamais devinée :
    /// l'événement est exclu dès qu'un filtre porte dessus.
    public func accepte(_ e: EvenementMatch) -> Bool {
        if !etiquettes.isEmpty, !etiquettes.contains(e.etiquette) { return false }
        if let joueurID, e.joueurID != joueurID { return false }
        if let periode, e.periode != periode { return false }
        if let rotation, e.rotation != rotation { return false }
        if let resultat, e.resultat != resultat { return false }
        switch phase {
        case .toutes: return true
        case .auService: return e.auService == true
        case .enReception: return e.auService == false
        }
    }
}

// MARK: - Index

public enum IndexVideo {

    /// Chapitres d'un match en un seul fichier.
    public static func chapitres(
        _ evenements: [EvenementMatch],
        alignement: AlignementVideo,
        fenetre: FenetreClip = .parDefaut
    ) -> [ChapitreVideo] {
        chapitres(evenements, fichiers: [alignement], fenetre: fenetre)
    }

    /// Chapitres d'un match filmé en plusieurs fichiers (ex. un par set),
    /// triés chronologiquement. Chaque événement est rattaché au fichier qui
    /// contient le plus long clip ; un événement dont aucun clip borné
    /// n'atteint `fenetre.dureeMinimale` (saisi hors de tout enregistrement,
    /// ex. pendant une pause caméra coupée) est écarté.
    public static func chapitres(
        _ evenements: [EvenementMatch],
        fichiers: [AlignementVideo],
        fenetre: FenetreClip = .parDefaut
    ) -> [ChapitreVideo] {
        evenements
            .sorted { $0.horodatage < $1.horodatage }
            .compactMap { evenement in
                var meilleur: ChapitreVideo?
                for (index, alignement) in fichiers.enumerated() {
                    let instant = alignement.instantDansVideo(evenement.horodatage)
                    let debut = max(0, instant - fenetre.avant)
                    let fin = min(alignement.dureeVideo, instant + fenetre.apres)
                    guard fin - debut >= fenetre.dureeMinimale else { continue }
                    if let actuel = meilleur, actuel.duree >= fin - debut { continue }
                    meilleur = ChapitreVideo(evenement: evenement, indexFichier: index,
                                             instant: instant, debut: debut, fin: fin)
                }
                return meilleur
            }
    }

    /// Liste de clips filtrée (ordre chronologique conservé).
    public static func playlist(_ chapitres: [ChapitreVideo], filtre: FiltreChapitres) -> [ChapitreVideo] {
        chapitres.filter { filtre.accepte($0.evenement) }
    }
}

// MARK: - Segments de lecture

/// Plage continue d'un fichier du match à lire d'un trait.
public struct SegmentLecture: Hashable, Sendable {
    public var indexFichier: Int
    public var debut: Double
    public var fin: Double
    /// Chapitres couverts, dans l'ordre.
    public var chapitres: [UUID]

    public var duree: Double { fin - debut }

    public init(indexFichier: Int = 0, debut: Double, fin: Double, chapitres: [UUID] = []) {
        self.indexFichier = indexFichier
        self.debut = debut
        self.fin = fin
        self.chapitres = chapitres
    }
}

public enum PlanLecture {

    /// Fusionne, dans un même fichier, les clips qui se chevauchent ou sont
    /// séparés de moins de `ecartFusion` secondes : moins de sauts, aucune
    /// image vue deux fois. Jamais de fusion entre deux fichiers.
    public static func segments(_ chapitres: [ChapitreVideo], ecartFusion: Double = 1) -> [SegmentLecture] {
        let tries = chapitres.sorted {
            ($0.indexFichier, $0.debut) < ($1.indexFichier, $1.debut)
        }
        var resultat: [SegmentLecture] = []
        for chapitre in tries {
            if var dernier = resultat.last, dernier.indexFichier == chapitre.indexFichier,
               chapitre.debut <= dernier.fin + ecartFusion {
                dernier.fin = max(dernier.fin, chapitre.fin)
                dernier.chapitres.append(chapitre.id)
                resultat[resultat.count - 1] = dernier
            } else {
                resultat.append(SegmentLecture(indexFichier: chapitre.indexFichier,
                                               debut: chapitre.debut, fin: chapitre.fin,
                                               chapitres: [chapitre.id]))
            }
        }
        return resultat
    }

    /// Durée totale lue.
    public static func dureeTotale(_ segments: [SegmentLecture]) -> Double {
        segments.reduce(0) { $0 + $1.duree }
    }
}
