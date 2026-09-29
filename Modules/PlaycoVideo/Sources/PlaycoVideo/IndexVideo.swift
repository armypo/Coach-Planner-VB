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
    /// Position du tap dans la vidéo (secondes, brute — peut dépasser la durée).
    public var instant: Double
    /// Bornes du clip, bornées à [0, durée].
    public var debut: Double
    public var fin: Double

    public var id: UUID { evenement.id }
    public var duree: Double { fin - debut }

    public init(evenement: EvenementMatch, instant: Double, debut: Double, fin: Double) {
        self.evenement = evenement
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

    /// Chapitres triés par instant. Un événement dont le clip borné est plus
    /// court que `fenetre.dureeMinimale` (saisi hors de l'enregistrement) est écarté.
    public static func chapitres(
        _ evenements: [EvenementMatch],
        alignement: AlignementVideo,
        fenetre: FenetreClip = .parDefaut
    ) -> [ChapitreVideo] {
        evenements
            .map { (evenement: $0, instant: alignement.instantDansVideo($0.horodatage)) }
            .sorted { $0.instant < $1.instant }
            .compactMap { paire in
                let debut = max(0, paire.instant - fenetre.avant)
                let fin = min(alignement.dureeVideo, paire.instant + fenetre.apres)
                guard fin - debut >= fenetre.dureeMinimale else { return nil }
                return ChapitreVideo(evenement: paire.evenement, instant: paire.instant, debut: debut, fin: fin)
            }
    }

    /// Liste de clips filtrée (ordre chronologique conservé).
    public static func playlist(_ chapitres: [ChapitreVideo], filtre: FiltreChapitres) -> [ChapitreVideo] {
        chapitres.filter { filtre.accepte($0.evenement) }
    }
}

// MARK: - Segments de lecture

/// Plage continue de la vidéo à lire d'un trait.
public struct SegmentLecture: Hashable, Sendable {
    public var debut: Double
    public var fin: Double
    /// Chapitres couverts, dans l'ordre.
    public var chapitres: [UUID]

    public var duree: Double { fin - debut }
}

public enum PlanLecture {

    /// Fusionne les clips qui se chevauchent ou sont séparés de moins de
    /// `ecartFusion` secondes : moins de sauts, aucune image vue deux fois.
    public static func segments(_ chapitres: [ChapitreVideo], ecartFusion: Double = 1) -> [SegmentLecture] {
        var resultat: [SegmentLecture] = []
        for chapitre in chapitres.sorted(by: { $0.debut < $1.debut }) {
            if var dernier = resultat.last, chapitre.debut <= dernier.fin + ecartFusion {
                dernier.fin = max(dernier.fin, chapitre.fin)
                dernier.chapitres.append(chapitre.id)
                resultat[resultat.count - 1] = dernier
            } else {
                resultat.append(SegmentLecture(debut: chapitre.debut, fin: chapitre.fin, chapitres: [chapitre.id]))
            }
        }
        return resultat
    }

    /// Durée totale lue.
    public static func dureeTotale(_ segments: [SegmentLecture]) -> Double {
        segments.reduce(0) { $0 + $1.duree }
    }
}
