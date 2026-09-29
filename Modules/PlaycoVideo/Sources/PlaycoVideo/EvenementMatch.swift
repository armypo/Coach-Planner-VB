//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Événement horodaté d'un match (un point saisi en live), vu par la vidéo.
//  Sport-agnostique : l'app traduit ses types (ex. `TypeActionPoint`) en
//  étiquettes brutes et en résultat ; le package ne réinterprète jamais rien.
//

import Foundation

/// Résultat d'un événement du point de vue de notre équipe.
public enum ResultatEvenement: String, Codable, Hashable, Sendable, CaseIterable {
    case pourNous
    case contreNous
}

public struct EvenementMatch: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    /// Instant réel du tap de saisie (horloge de l'appareil de saisie).
    public var horodatage: Date
    /// Type d'action brut (ex. rawValue de `TypeActionPoint`).
    public var etiquette: String
    /// nil = inconnu (type non reconnu par l'app) — jamais deviné.
    public var resultat: ResultatEvenement?
    public var joueurID: UUID?
    /// Période de jeu (le set au volleyball).
    public var periode: Int
    /// nil si le sport n'a pas de rotation.
    public var rotation: Int?
    /// Zones d'arrivée et de départ (nil = non assignée).
    public var zone: Int?
    public var zoneDepart: Int?
    /// Vrai si nous avions le service au début du rallye (nil = inconnu).
    public var auService: Bool?

    public init(
        id: UUID = UUID(),
        horodatage: Date,
        etiquette: String,
        resultat: ResultatEvenement?,
        joueurID: UUID? = nil,
        periode: Int = 1,
        rotation: Int? = nil,
        zone: Int? = nil,
        zoneDepart: Int? = nil,
        auService: Bool? = nil
    ) {
        self.id = id
        self.horodatage = horodatage
        self.etiquette = etiquette
        self.resultat = resultat
        self.joueurID = joueurID
        self.periode = periode
        self.rotation = rotation
        self.zone = zone
        self.zoneDepart = zoneDepart
        self.auService = auService
    }
}
