//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  IdentifiantsIAP — product IDs StoreKit et constantes UserDefaults.
//

import Foundation

enum IdentifiantsIAP {

    // MARK: - Product IDs (doivent matcher Playco.storekit + App Store Connect)

    static let proMensuel = "ca.origotech.playco.pro.monthly"
    static let proAnnuel  = "ca.origotech.playco.pro.yearly"
    static let clubMensuel = "ca.origotech.playco.club.monthly"
    static let clubAnnuel  = "ca.origotech.playco.club.yearly"

    /// Subscription Group dans App Store Connect.
    static let groupeAbonnement = "playco.pro"

    /// Tous les product IDs gérés par l'app.
    static let tous: [String] = [proMensuel, proAnnuel, clubMensuel, clubAnnuel]

    // MARK: - Helpers

    /// Mappe un product ID vers le tier correspondant.
    static func tier(pour produitID: String) -> Tier {
        switch produitID {
        case proMensuel, proAnnuel: return .pro
        case clubMensuel, clubAnnuel: return .club
        default: return .aucun
        }
    }

    /// True si le product ID correspond à un abonnement annuel.
    static func estAnnuel(_ produitID: String) -> Bool {
        produitID == proAnnuel || produitID == clubAnnuel
    }

    // MARK: - Clés UserDefaults (cache statut + flags migration)

    static let cleCacheStatut = "playco_abo_cache_statut"
    static let cleCachePeutEcrire = "playco_abo_cache_peut_ecrire"
    static let cleCachePeutConnecterAthletes = "playco_abo_cache_peut_connecter_athletes"
    static let cleMigrationRolesDone = "playco_abo_migration_roles_done"
}
