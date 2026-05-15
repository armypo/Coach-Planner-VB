//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  Abonnement — cache local (CloudKit private DB) du statut StoreKit.
//

import Foundation
import SwiftData

// MARK: - Tier d'abonnement

enum Tier: String, Codable, CaseIterable {
    case aucun
    case pro    // coach + staff
    case club   // tout Pro + athlètes

    var label: String {
        switch self {
        case .aucun: return "Aucun"
        case .pro: return "Playco Pro"
        case .club: return "Playco Club"
        }
    }
}

// MARK: - Type d'abonnement

enum TypeAbonnement: String, Codable, CaseIterable {
    case aucun
    case essai           // 14 jours d'essai gratuit Apple
    case mensuel
    case annuel
    case gracePeriode    // Apple a échoué de débiter, période de tolérance
    case expire
}

// MARK: - Modèle

/// Cache local du statut StoreKit. Source of truth = `StoreKit.Transaction.currentEntitlements`,
/// ce modèle sert à : (1) afficher le statut hors-ligne, (2) historiser pour analytics,
/// (3) propager le tier vers les Équipes via CloudKitSharingService.
@Model
final class Abonnement {
    var id: UUID = UUID()
    var utilisateurID: UUID = UUID()
    var tierRaw: String = Tier.aucun.rawValue
    var typeAbonnementRaw: String = TypeAbonnement.aucun.rawValue
    var produitIAPID: String = ""
    var appStoreTransactionID: String = ""
    var dateDernierSync: Date = Date()
    var dateExpiration: Date? = nil

    var tier: Tier {
        get { Tier(rawValue: tierRaw) ?? .aucun }
        set { tierRaw = newValue.rawValue }
    }

    var type: TypeAbonnement {
        get { TypeAbonnement(rawValue: typeAbonnementRaw) ?? .aucun }
        set { typeAbonnementRaw = newValue.rawValue }
    }

    init(utilisateurID: UUID,
         tier: Tier = .aucun,
         type: TypeAbonnement = .aucun,
         produitIAPID: String = "",
         appStoreTransactionID: String = "",
         dateExpiration: Date? = nil) {
        self.id = UUID()
        self.utilisateurID = utilisateurID
        self.tierRaw = tier.rawValue
        self.typeAbonnementRaw = type.rawValue
        self.produitIAPID = produitIAPID
        self.appStoreTransactionID = appStoreTransactionID
        self.dateExpiration = dateExpiration
        self.dateDernierSync = Date()
    }
}
