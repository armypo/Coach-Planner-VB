//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import StoreKit
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "StoreKit")

/// Wrapper StoreKit 2 pour les 4 produits Playco (Pro/Club × mensuel/annuel).
/// Gère : chargement des produits, achat, restauration, observation des
/// renouvellements en arrière-plan (`Transaction.updates`).
///
/// Consommé par `AbonnementService.rafraichir(...)` (P5) pour déterminer le
/// statut courant via `Transaction.currentEntitlements`.
@MainActor
@Observable
final class StoreKitService {

    // MARK: - Erreurs

    enum StoreKitError: Error {
        case unverified
        case userCancelled
        case pending
        case produitIntrouvable(String)
    }

    // MARK: - État observable

    var produits: [Product] = []
    var chargement: Bool = false
    var derniereErreur: String? = nil

    // MARK: - Chargement produits

    /// Charge les 4 produits Playco via `Product.products(for:)`.
    /// Peuple `produits` dans l'ordre du plan (Pro mensuel, Pro annuel, Club mensuel, Club annuel).
    func chargerProduits() async throws {
        chargement = true
        defer { chargement = false }
        do {
            let resultats = try await Product.products(for: IdentifiantsIAP.tous)
            // Trier selon l'ordre canonique `IdentifiantsIAP.tous`
            produits = IdentifiantsIAP.tous.compactMap { id in
                resultats.first(where: { $0.id == id })
            }
            logger.info("Produits StoreKit chargés : \(self.produits.count, privacy: .public)/\(IdentifiantsIAP.tous.count, privacy: .public)")
        } catch {
            derniereErreur = error.localizedDescription
            logger.error("Échec chargement produits : \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    // MARK: - Achat

    /// Lance l'achat d'un produit. `finish()` est appelé APRÈS que l'appelant
    /// a persisté le résultat (recommandation Apple).
    func acheter(_ produit: Product) async throws -> Transaction {
        let resultat = try await produit.purchase()
        switch resultat {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await transaction.finish()
                logger.info("Achat vérifié : \(produit.id, privacy: .public)")
                return transaction
            case .unverified(_, let error):
                logger.critical("Transaction non vérifiée pour \(produit.id, privacy: .public) : \(error.localizedDescription, privacy: .public)")
                throw StoreKitError.unverified
            }
        case .userCancelled:
            throw StoreKitError.userCancelled
        case .pending:
            throw StoreKitError.pending
        @unknown default:
            throw StoreKitError.unverified
        }
    }

    // MARK: - Restauration

    /// Rejoue les achats de l'Apple ID actif. Apple recommande d'éviter
    /// l'appel automatique et de le réserver au bouton explicite « Restaurer ».
    func restaurer() async throws {
        try await AppStore.sync()
        logger.info("Restauration déclenchée via AppStore.sync()")
    }

    // MARK: - Observation renouvellements

    /// Task détachée qui écoute `Transaction.updates` pour capter les
    /// renouvellements, révocations et refunds hors de la session d'achat.
    /// À lancer une fois au boot (case `.app` `onAppear`).
    func observerTransactions() -> Task<Void, Never> {
        Task.detached {
            for await verification in Transaction.updates {
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    logger.info("Transaction update (verified) \(transaction.productID, privacy: .public)")
                case .unverified(_, let error):
                    logger.warning("Transaction update non-verified : \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    // MARK: - Statut courant

    /// Retourne le produit actif (Subscription Group « playco.pro ») avec son
    /// `Product.SubscriptionInfo.Status`. `nil` si aucune subscription active.
    func statutSouscriptionActif() async -> (produit: Product, status: Product.SubscriptionInfo.Status)? {
        for await verification in Transaction.currentEntitlements {
            guard case .verified(let transaction) = verification,
                  IdentifiantsIAP.tous.contains(transaction.productID),
                  let produit = produits.first(where: { $0.id == transaction.productID }),
                  let status = try? await produit.subscription?.status.first
            else { continue }
            return (produit, status)
        }
        return nil
    }
}
