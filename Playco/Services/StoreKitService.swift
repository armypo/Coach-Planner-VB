//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  StoreKitService — StoreKit 2 natif. Charge les 4 produits, gère l'achat,
//  observe les transactions en continu. Source of truth pour AbonnementService.
//

import Foundation
import StoreKit
import os

/// `nonisolated` car Logger est Sendable — permet l'usage depuis `Task.detached`
/// dans `observerTransactions()` (sinon warning Swift 6 MainActor isolation).
nonisolated private let loggerSK = Logger(subsystem: "com.origotech.playco", category: "storekit")

// MARK: - Erreurs

enum StoreKitError: LocalizedError {
    case productNotFound
    case unverified
    case userCancelled
    case pending
    case purchaseFailed

    var errorDescription: String? {
        switch self {
        case .productNotFound: return "Produit introuvable."
        case .unverified: return "Transaction non vérifiée par Apple."
        case .userCancelled: return "Achat annulé."
        case .pending: return "Achat en attente d'approbation."
        case .purchaseFailed: return "L'achat a échoué. Réessaie plus tard."
        }
    }
}

// MARK: - Service

@MainActor
@Observable
final class StoreKitService {

    /// Produits chargés depuis App Store / Playco.storekit. Vide tant que
    /// `chargerProduits()` n'a pas été appelé.
    var produits: [Product] = []

    /// Charge les 4 produits référencés dans `IdentifiantsIAP.tous`.
    /// À appeler une fois au démarrage de l'app.
    func chargerProduits() async throws {
        produits = try await Product.products(for: IdentifiantsIAP.tous)
        loggerSK.info("Produits StoreKit chargés : \(self.produits.count)")
    }

    /// Lance l'achat d'un produit. Sur succès, `await tx.finish()` puis retourne
    /// la transaction. Sur erreur, throw une `StoreKitError` typée.
    func acheter(_ produit: Product) async throws -> Transaction {
        let result = try await produit.purchase()
        switch result {
        case .success(.verified(let tx)):
            await tx.finish()
            loggerSK.info("Achat réussi : \(produit.id)")
            return tx
        case .success(.unverified(_, let error)):
            loggerSK.critical("Achat non vérifié : \(error.localizedDescription)")
            throw StoreKitError.unverified
        case .userCancelled:
            throw StoreKitError.userCancelled
        case .pending:
            throw StoreKitError.pending
        @unknown default:
            throw StoreKitError.purchaseFailed
        }
    }

    /// Force une synchronisation avec l'App Store pour restaurer les achats.
    func restaurer() async throws {
        try await AppStore.sync()
        loggerSK.info("Restauration AppStore.sync terminée")
    }

    /// Lance la boucle d'observation `Transaction.updates`. À appeler une fois
    /// au démarrage de l'app — le Task tourne tant que l'app est en vie.
    /// Retourne le Task pour permettre l'annulation en deinit si nécessaire.
    func observerTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let tx) = result {
                    await tx.finish()
                    loggerSK.info("Transaction.updates finalisée : \(tx.productID)")
                } else {
                    loggerSK.warning("Transaction.updates non vérifiée — ignorée")
                }
            }
        }
    }

    /// Retourne la souscription active (verified) si l'utilisateur en a une.
    /// Itère `Transaction.currentEntitlements` et retourne le tuple
    /// (Product, SubscriptionInfo.Status) pour le produit le plus récent.
    func statutSouscriptionActif() async -> (produit: Product, status: Product.SubscriptionInfo.Status)? {
        var derniereTx: Transaction? = nil
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result,
                  IdentifiantsIAP.tous.contains(tx.productID)
            else { continue }

            if let courante = derniereTx {
                if tx.purchaseDate > courante.purchaseDate {
                    derniereTx = tx
                }
            } else {
                derniereTx = tx
            }
        }

        guard let tx = derniereTx,
              let produit = produits.first(where: { $0.id == tx.productID }),
              let status = try? await produit.subscription?.status.first
        else {
            return nil
        }
        return (produit, status)
    }
}
