//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation

/// Identifiants StoreKit partagés entre l'app et App Store Connect.
/// Convention : `com.origo.playco.<tier>.<periode>`.
/// Le Subscription Group « playco.pro » contient les 4 produits et partage
/// l'Introductory Offer (un seul essai 14 jours par Apple ID, tous produits confondus).
enum IdentifiantsIAP {

    // MARK: - Product IDs

    /// Tier Pro mensuel — 14,99 $ CAD
    static let proMensuel  = "com.origo.playco.pro.mensuel"
    /// Tier Pro annuel — 149,99 $ CAD (~ -17 %)
    static let proAnnuel   = "com.origo.playco.pro.annuel"
    /// Tier Club mensuel — 25 $ CAD
    static let clubMensuel = "com.origo.playco.club.mensuel"
    /// Tier Club annuel — 250 $ CAD (~ -17 %)
    static let clubAnnuel  = "com.origo.playco.club.annuel"

    static let groupeAbonnement = "playco.pro"

    /// Tous les product IDs à charger via `Product.products(for:)`.
    static let tous: [String] = [proMensuel, proAnnuel, clubMensuel, clubAnnuel]

    // MARK: - Lookup tier / période

    /// Mappe un product ID vers son tier.
    static func tier(pour produitID: String) -> Tier {
        switch produitID {
        case proMensuel, proAnnuel:   return .pro
        case clubMensuel, clubAnnuel: return .club
        default:                      return .aucun
        }
    }

    /// Vrai si le product ID correspond à une offre annuelle.
    static func estAnnuel(_ produitID: String) -> Bool {
        produitID == proAnnuel || produitID == clubAnnuel
    }

    // MARK: - Clés UserDefaults (cache sans-réseau + migration)

    /// Cache JSON du dernier `AbonnementService.Statut` connu (évite le flash
    /// paywall au launch pendant que StoreKit recharge).
    static let cleCacheStatut = "playco_cache_statut_abo"
    /// Cache booléen de `peutEcrire` — consulté avant le retour de `rafraichir`.
    static let cleCachePeutEcrire = "playco_cache_peut_ecrire"
    /// Cache booléen de `peutConnecterAthletes` — idem.
    static let cleCachePeutConnecterAthletes = "playco_cache_peut_athletes"
    /// Flag de migration one-shot : assistants pré-v2.0 (role `.coach`) reclassés `.assistantCoach`.
    static let cleMigrationRolesDone = "playco_migration_roles_v2_done"
}
