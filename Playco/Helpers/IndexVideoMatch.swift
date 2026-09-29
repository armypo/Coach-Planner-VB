//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Vidéo phase 1 — index vidéo ↔ stats live (local-first, HORS SORTIE :
//  compilé seulement avec le flag VIDEO, présent en Debug, absent en Release).
//
//  Chaque `PointMatch` porte un `horodatage`. Connaissant l'instant de début de
//  la vidéo, chaque point saisi en live devient un chapitre : la saisie de stats
//  EST le découpage. Le même index sert d'ÉTIQUETTES pour l'IA (vidéo + labels
//  produits gratuitement par le coaching) — d'où un format Codable versionné.
//
//  Logique pure (aucune dépendance AVFoundation) — testable sans vidéo.
//  Isolation : seuls les types lus par `VideoMatchStore` (alignement, fenêtre)
//  sont `nonisolated` ; ceux qui touchent `TypeActionPoint` (MainActor par
//  défaut) restent MainActor — pas de conformance isolée hors de son acteur.
//

#if VIDEO
import Foundation

// MARK: - Point indexable

/// Point du match réduit à ce que l'index utilise — valeur pure, découplée du
/// @Model (sérialisable dans le manifeste, testable sans SwiftData).
struct PointIndexable: Codable, Equatable {
    var pointID: UUID
    var horodatage: Date
    var set: Int
    var typeActionRaw: String
    var joueurID: UUID?
    var rotation: Int
    var rotationAdversaire: Int
    var zone: Int
    var zoneDepart: Int
    /// Contexte de service du rallye (saisi, ou reconstruit pour le legacy).
    var nousServions: Bool
    /// Vrai si `nousServions` vient de la saisie (faux = reconstruit).
    var serviceRenseigne: Bool

    /// nil si le type stocké est inconnu — jamais de type fabriqué (étiquette IA).
    var typeAction: TypeActionPoint? { TypeActionPoint(rawValue: typeActionRaw) }
}

// MARK: - Alignement

/// Comment l'instant de début de la vidéo a été obtenu.
nonisolated enum SourceAlignement: String, Codable, Sendable {
    /// Métadonnée de création du fichier (vidéo iPhone/iPad).
    case metadonneeFichier
    /// Saisi ou corrigé à la main par le coach.
    case manuel
}

/// Relie le temps réel des points au temps du fichier vidéo.
nonisolated struct AlignementVideo: Codable, Equatable, Sendable {
    /// Instant réel du début de l'enregistrement.
    var dateDebutVideo: Date
    /// Correction manuelle en secondes (+ = les points arrivent plus tard dans la vidéo).
    var decalageSecondes: Double = 0
    /// Durée du fichier vidéo en secondes.
    var dureeVideo: Double

    /// Position d'un instant réel dans la vidéo (secondes, peut sortir de [0, durée]).
    func instantDansVideo(_ date: Date) -> Double {
        date.timeIntervalSince(dateDebutVideo) + decalageSecondes
    }
}

/// Fenêtre d'un clip autour du tap de saisie. Le tap arrive APRÈS le rallye :
/// la fenêtre remonte surtout avant. Valeurs ESTIMÉES — à calibrer sur vraie vidéo.
nonisolated struct FenetreClip: Codable, Equatable, Sendable {
    var avant: Double = 8
    var apres: Double = 3
    /// Un clip plus court (point saisi hors de la vidéo) n'est pas retenu.
    var dureeMinimale: Double = 2

    static let parDefaut = FenetreClip()
}

// MARK: - Chapitre

/// Un point du match situé dans la vidéo.
struct ChapitreVideo: Codable, Equatable, Identifiable {
    var point: PointIndexable
    /// Position du tap dans la vidéo (secondes, brute — peut dépasser la durée).
    var instant: Double
    /// Bornes du clip, bornées à [0, durée].
    var debut: Double
    var fin: Double

    var id: UUID { point.pointID }
    var duree: Double { fin - debut }
}

// MARK: - Filtre (playlists façon « cutups »)

struct FiltreChapitres: Equatable {
    enum Resultat: String, CaseIterable {
        case tous, pourNous, contreNous
    }

    /// Au service = nous servions (point scoring) ; en réception = sideout.
    enum Phase: String, CaseIterable {
        case toutes, auService, enReception
    }

    /// Vide = tous les types.
    var types: Set<TypeActionPoint> = []
    var joueurID: UUID? = nil
    var set: Int? = nil
    var rotation: Int? = nil
    var resultat: Resultat = .tous
    var phase: Phase = .toutes

    func accepte(_ point: PointIndexable) -> Bool {
        if !types.isEmpty {
            guard let type = point.typeAction, types.contains(type) else { return false }
        }
        if let joueurID, point.joueurID != joueurID { return false }
        if let set, point.set != set { return false }
        if let rotation, point.rotation != rotation { return false }

        switch resultat {
        case .tous:
            break
        case .pourNous, .contreNous:
            // Type inconnu = résultat inconnu : exclu plutôt que deviné.
            guard let type = point.typeAction else { return false }
            if type.estPointPourNous != (resultat == .pourNous) { return false }
        }

        switch phase {
        case .toutes: return true
        case .auService: return point.nousServions
        case .enReception: return !point.nousServions
        }
    }
}

// MARK: - Construction de l'index

enum IndexVideoMatch {

    /// Réduit les points d'un match en valeurs indexables. Le contexte de
    /// service passe par la reconstruction déterministe de `MetriquesVolley`
    /// (règle « gagnant sert le suivant ») pour les points legacy.
    static func points(depuis points: [PointMatch], seance: Seance) -> [PointIndexable] {
        let contexte = MetriquesVolley.reconstruireService(points: points, seance: seance)
        return points.map { point in
            PointIndexable(
                pointID: point.id,
                horodatage: point.horodatage,
                set: point.set,
                typeActionRaw: point.typeActionRaw,
                joueurID: point.joueurID,
                rotation: point.rotationAuMoment,
                rotationAdversaire: point.rotationAdvAuMoment,
                zone: point.zone,
                zoneDepart: point.zoneDepart,
                nousServions: contexte[point.id] ?? point.nousServionsAuMoment,
                serviceRenseigne: point.serviceRenseigne
            )
        }
    }

    /// Chapitres triés par instant. Un point dont le clip borné est plus court
    /// que `fenetre.dureeMinimale` (saisi hors de l'enregistrement) est écarté.
    static func chapitres(
        points: [PointIndexable],
        alignement: AlignementVideo,
        fenetre: FenetreClip = .parDefaut
    ) -> [ChapitreVideo] {
        points
            .sorted { $0.horodatage < $1.horodatage }
            .compactMap { point in
                let instant = alignement.instantDansVideo(point.horodatage)
                let debut = max(0, instant - fenetre.avant)
                let fin = min(alignement.dureeVideo, instant + fenetre.apres)
                guard fin - debut >= fenetre.dureeMinimale else { return nil }
                return ChapitreVideo(point: point, instant: instant, debut: debut, fin: fin)
            }
    }

    /// Playlist filtrée (ordre chronologique conservé).
    static func playlist(_ chapitres: [ChapitreVideo], filtre: FiltreChapitres) -> [ChapitreVideo] {
        chapitres.filter { filtre.accepte($0.point) }
    }
}
#endif
