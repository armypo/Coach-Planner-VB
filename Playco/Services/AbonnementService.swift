//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftData
import StoreKit
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "Abonnement")

/// Service central de gestion du statut d'abonnement du coach connecté.
/// Consommé par :
/// - la gate centrale `PlaycoApp.appliquerGateTier` (assistants / athlètes selon tier)
/// - `FeatureGating.bloqueSiNonPayant` (vues write)
/// - `PaywallView` / `BanniereAbonnementView` (UI)
///
/// `rafraichir(...)` sera branché sur StoreKit en P5 ; pour l'instant, stub.
@MainActor
@Observable
final class AbonnementService {

    // MARK: - Statut

    enum Statut: Equatable {
        case chargement
        case aucun
        case essaiActif(tier: Tier, joursRestants: Int)
        case proMensuel(dateRenouvellement: Date)
        case proAnnuel(dateRenouvellement: Date)
        case clubMensuel(dateRenouvellement: Date)
        case clubAnnuel(dateRenouvellement: Date)
        case gracePeriode(tier: Tier, dateExpirationAttendue: Date)
        case essaiExpire
        case expire(tier: Tier, depuis: Date)
    }

    // MARK: - État observable

    var statut: Statut = .chargement

    private let userDefaults: UserDefaults

    // MARK: - Init

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Computed properties

    /// Tier actif déduit du statut — .aucun hors abonnement actif et expiration.
    var tierActif: Tier {
        switch statut {
        case .chargement:
            // Optimistic : on se fie au cache pour les gates (peutEcrire, peutConnecterAthletes)
            // mais `tierActif` reste conservateur à `.aucun` pendant le chargement.
            return .aucun
        case .aucun, .essaiExpire:
            return .aucun
        case .essaiActif(let tier, _):
            return tier
        case .proMensuel, .proAnnuel:
            return .pro
        case .clubMensuel, .clubAnnuel:
            return .club
        case .gracePeriode(let tier, _):
            return tier
        case .expire:
            return .aucun
        }
    }

    /// Autorise la création/modification (stats, séances, matchs, exports).
    /// Pendant `.chargement`, on lit le cache UserDefaults pour éviter le flash paywall.
    var peutEcrire: Bool {
        switch statut {
        case .chargement:
            return userDefaults.bool(forKey: IdentifiantsIAP.cleCachePeutEcrire)
        case .aucun, .essaiExpire:
            return false
        case .expire:
            return false
        case .essaiActif, .proMensuel, .proAnnuel, .clubMensuel, .clubAnnuel, .gracePeriode:
            return true
        }
    }

    /// Autorise la connexion athlète (tier Club exclusif).
    /// Pendant `.chargement`, on lit le cache UserDefaults.
    var peutConnecterAthletes: Bool {
        switch statut {
        case .chargement:
            return userDefaults.bool(forKey: IdentifiantsIAP.cleCachePeutConnecterAthletes)
        default:
            return tierActif == .club
        }
    }

    var joursRestantsEssai: Int? {
        if case .essaiActif(_, let jours) = statut { return jours }
        return nil
    }

    /// Banner affichée en haut de ContentView : essai < 4j, expiré, grace, etc.
    var doitAfficherBanniere: Bool {
        switch statut {
        case .essaiActif(_, let jours) where jours <= 3:
            return true
        case .gracePeriode, .essaiExpire, .expire:
            return true
        default:
            return false
        }
    }

    // MARK: - Classification utilisateur

    /// Vrai si l'utilisateur est le coach principal responsable de payer
    /// l'abonnement de l'équipe. Les assistants (`.assistantCoach`) et
    /// athlètes (`.etudiant`) ne voient pas le paywall directement —
    /// leur accès dépend du tier de l'équipe (via `tierAbonnement` publiée).
    func estCoachPayant(utilisateur: Utilisateur) -> Bool {
        utilisateur.role == .coach || utilisateur.role == .admin
    }

    // MARK: - Migration one-shot rôles v2.0 (P1)

    /// Reclasse les assistants pré-v2.0 (créés avec `role == .coach` dans le wizard)
    /// vers le nouveau `role == .assistantCoach`. Détection via match
    /// `Utilisateur.identifiant == AssistantCoach.identifiant`.
    /// Idempotent : un flag UserDefaults garantit une seule exécution.
    func migrerAssistantsVersNouveauRole(context: ModelContext) {
        guard !userDefaults.bool(forKey: IdentifiantsIAP.cleMigrationRolesDone) else {
            return
        }

        let descripteurUsers = FetchDescriptor<Utilisateur>(
            predicate: #Predicate { $0.roleRaw == "coach" }
        )
        let coachs = (try? context.fetch(descripteurUsers)) ?? []
        let descripteurAssistants = FetchDescriptor<AssistantCoach>()
        let assistants = (try? context.fetch(descripteurAssistants)) ?? []
        let idsAssistants = Set(assistants.map(\.identifiant).filter { !$0.isEmpty })

        var reclasse = 0
        for user in coachs where idsAssistants.contains(user.identifiant) {
            user.role = .assistantCoach
            reclasse += 1
        }

        if reclasse > 0 {
            try? context.save()
            logger.info("Migration rôles v2 : \(reclasse, privacy: .public) coach(s) reclassés en assistantCoach")
        }

        userDefaults.set(true, forKey: IdentifiantsIAP.cleMigrationRolesDone)
    }

    // MARK: - Propagation tier → Equipe (pour la gate athlète multi-Apple-ID)

    /// Met à jour `Equipe.tierAbonnementRaw` pour toutes les équipes du coach
    /// connecté (via `codeEcole`), puis republie publiquement via
    /// `CloudKitSharingService` pour que les athlètes (Apple IDs différents)
    /// puissent lire le tier sans accéder à l'`Abonnement` privé.
    ///
    /// `sharingService` est `Any?` tant que l'intégration CloudKit n'est pas
    /// complétée (P8) — pour l'instant, on se contente du save local.
    func propagerTierAuxEquipes(
        utilisateur: Utilisateur?,
        context: ModelContext,
        sharingService: Any? = nil
    ) async {
        guard let user = utilisateur else { return }
        let code = user.codeEcole
        guard !code.isEmpty else { return }

        let descripteur = FetchDescriptor<Equipe>(
            predicate: #Predicate { $0.codeEquipe == code }
        )
        let equipes = (try? context.fetch(descripteur)) ?? []
        let tierAPropager = tierActif

        for equipe in equipes where equipe.tierAbonnement != tierAPropager {
            equipe.tierAbonnement = tierAPropager
            equipe.dateModification = Date()
        }
        try? context.save()

        if !equipes.isEmpty {
            logger.info("Tier \(tierAPropager.rawValue, privacy: .public) propagé localement à \(equipes.count, privacy: .public) équipe(s). Republication CloudKit sera faite en P8.")
        }
    }

    // MARK: - Rafraichissement (StoreKit 2)

    /// Parse l'état StoreKit courant et met à jour `statut`.
    /// Si le tier a changé depuis l'appel précédent, propage vers les équipes
    /// du coach via `propagerTierAuxEquipes` (publication CloudKit en P8).
    func rafraichir(
        utilisateur: Utilisateur?,
        context: ModelContext,
        storeKit: StoreKitService
    ) async {
        let tierAvant = tierActif

        guard let user = utilisateur, estCoachPayant(utilisateur: user) else {
            statut = .aucun
            persisterCache()
            return
        }

        guard let info = await storeKit.statutSouscriptionActif() else {
            // Pas d'entitlement actif. Distinguons « jamais abonné » (.aucun)
            // d'un essai expiré (historique présent) via l'Abonnement persisté.
            statut = chargerStatutFallback(utilisateur: user, context: context)
            persisterCache()
            return
        }

        statut = mapperStatutStoreKit(info: info)
        persisterCache()
        persisterDansSwiftData(utilisateur: user, context: context, info: info)

        if tierActif != tierAvant {
            await propagerTierAuxEquipes(utilisateur: user, context: context)
        }
    }

    // MARK: - Mapping StoreKit Status → Statut

    private func mapperStatutStoreKit(
        info: (produit: Product, status: Product.SubscriptionInfo.Status)
    ) -> Statut {
        let produit = info.produit
        let status = info.status
        let tier = IdentifiantsIAP.tier(pour: produit.id)
        let annuel = IdentifiantsIAP.estAnnuel(produit.id)

        let expirationDate: Date? = {
            if case .verified(let tx) = status.transaction { return tx.expirationDate }
            return nil
        }()
        let revocationDate: Date? = {
            if case .verified(let tx) = status.transaction { return tx.revocationDate }
            return nil
        }()

        switch status.state {
        case .subscribed:
            if let exp = expirationDate, estEnEssai(status: status) {
                let jours = joursRestants(jusqua: exp)
                return .essaiActif(tier: tier, joursRestants: jours)
            }
            let date = expirationDate ?? Date()
            switch (tier, annuel) {
            case (.pro, true):   return .proAnnuel(dateRenouvellement: date)
            case (.pro, false):  return .proMensuel(dateRenouvellement: date)
            case (.club, true):  return .clubAnnuel(dateRenouvellement: date)
            case (.club, false): return .clubMensuel(dateRenouvellement: date)
            default:             return .aucun
            }
        case .inGracePeriod, .inBillingRetryPeriod:
            return .gracePeriode(tier: tier, dateExpirationAttendue: expirationDate ?? Date())
        case .expired:
            return .expire(tier: tier, depuis: expirationDate ?? Date())
        case .revoked:
            return .expire(tier: tier, depuis: revocationDate ?? Date())
        default:
            return .aucun
        }
    }

    /// Vrai si la transaction Apple est un Introductory Offer Free (essai).
    private func estEnEssai(status: Product.SubscriptionInfo.Status) -> Bool {
        guard case .verified(let renewal) = status.renewalInfo else { return false }
        return renewal.offerType == .introductory
    }

    private func joursRestants(jusqua: Date) -> Int {
        let secondes = jusqua.timeIntervalSinceNow
        let jours = Int(ceil(secondes / 86_400))
        return max(0, jours)
    }

    // MARK: - Fallback sans entitlement

    /// Si aucun entitlement actif : on cherche un `Abonnement` persisté pour
    /// savoir si l'utilisateur a déjà eu un essai ou un tier qui a expiré.
    private func chargerStatutFallback(
        utilisateur: Utilisateur,
        context: ModelContext
    ) -> Statut {
        let uid = utilisateur.id
        let desc = FetchDescriptor<Abonnement>(
            predicate: #Predicate { $0.utilisateurID == uid }
        )
        guard let abo = try? context.fetch(desc).first,
              abo.type != .aucun else {
            return .aucun
        }
        return .essaiExpire
    }

    // MARK: - Persistance SwiftData (cache CloudKit privé)

    private func persisterDansSwiftData(
        utilisateur: Utilisateur,
        context: ModelContext,
        info: (produit: Product, status: Product.SubscriptionInfo.Status)
    ) {
        let uid = utilisateur.id
        let desc = FetchDescriptor<Abonnement>(
            predicate: #Predicate { $0.utilisateurID == uid }
        )
        let existant = try? context.fetch(desc).first
        let abonnement = existant ?? Abonnement(utilisateurID: uid)

        abonnement.tier = tierActif
        abonnement.type = mapperTypeAbonnement(statut: statut)
        abonnement.produitIAPID = info.produit.id
        if case .verified(let tx) = info.status.transaction {
            abonnement.appStoreTransactionID = String(tx.id)
            abonnement.dateExpiration = tx.expirationDate
        }
        abonnement.dateDernierSync = Date()

        if existant == nil {
            context.insert(abonnement)
        }
        try? context.save()
    }

    private func mapperTypeAbonnement(statut: Statut) -> TypeAbonnement {
        switch statut {
        case .essaiActif:                              return .essai
        case .proMensuel, .clubMensuel:                return .mensuel
        case .proAnnuel, .clubAnnuel:                  return .annuel
        case .gracePeriode:                            return .gracePeriode
        case .essaiExpire, .expire:                    return .expire
        case .chargement, .aucun:                      return .aucun
        }
    }

    // MARK: - Cache UserDefaults

    /// Sauvegarde `peutEcrire` + `peutConnecterAthletes` pour éviter le flash
    /// paywall pendant `.chargement` au prochain launch.
    private func persisterCache() {
        userDefaults.set(peutEcrire, forKey: IdentifiantsIAP.cleCachePeutEcrire)
        userDefaults.set(peutConnecterAthletes, forKey: IdentifiantsIAP.cleCachePeutConnecterAthletes)
    }
}
