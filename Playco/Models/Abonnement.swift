//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftData

// MARK: - Tier abonnement

/// Niveau d'abonnement actif d'un coach.
/// - `.aucun` : pas d'abonnement actif (pré-essai OU post-expiration)
/// - `.pro` : outil solo coach + staff (pas d'accès athlète via app)
/// - `.club` : Pro + connexion athlètes + messagerie + MonProfilAthlete
enum Tier: String, Codable, CaseIterable {
    case aucun
    case pro
    case club
}

// MARK: - Type d'abonnement

/// État de souscription Apple mappé sur un type lisible localement.
enum TypeAbonnement: String, Codable, CaseIterable {
    case aucun
    case essai
    case mensuel
    case annuel
    case gracePeriode
    case expire
}

// MARK: - Modèle

/// Cache local + sync CloudKit privée du statut d'abonnement du coach.
///
/// Ne pas confondre avec `Equipe.tierAbonnement` qui est la projection publique
/// utilisée par la gate athlète multi-Apple-ID (publiée via
/// `CloudKitSharingService.publierEquipeComplete`).
///
/// Tous les attributs ont une valeur par défaut (piège CloudKit #15).
/// Pas de conformance `FiltreParEquipe` : un coach = un `Abonnement`, pas par équipe.
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

    init(
        utilisateurID: UUID,
        tier: Tier = .aucun,
        type: TypeAbonnement = .aucun,
        produitIAPID: String = "",
        appStoreTransactionID: String = "",
        dateExpiration: Date? = nil
    ) {
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
