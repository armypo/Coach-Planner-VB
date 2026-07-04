//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  PaywallViewModel — extrait la logique d'état du paywall hors de PaywallView.
//  Gère le cycle chargement → prêt / erreur, l'éligibilité essai, l'achat et la
//  restauration avec messages d'erreur fins (rien-à-restaurer vs réseau).
//

import Foundation
import Observation
import StoreKit
import os

@MainActor
@Observable
final class PaywallViewModel {

    enum EtatChargement: Equatable {
        case initial
        case chargement
        case pret
        case erreur(String)
    }

    // MARK: - État UI

    var periode: PeriodePaywall = .annuel
    var produitSelectionneID: String? = nil
    private(set) var eligibiliteParProduit: [String: Bool] = [:]
    private(set) var enCours = false
    private(set) var erreur: String? = nil
    private(set) var etat: EtatChargement = .initial

    // MARK: - Dépendances

    private let storeKit: StoreKitService
    private let analytics: AnalyticsService
    private let logger = Logger(subsystem: "com.origotech.playco", category: "paywall")

    init(storeKit: StoreKitService, analytics: AnalyticsService) {
        self.storeKit = storeKit
        self.analytics = analytics
    }

    // MARK: - Produits filtrés selon période

    var produitPro: Product? {
        let id = periode == .annuel ? IdentifiantsIAP.proAnnuel : IdentifiantsIAP.proMensuel
        return storeKit.produits.first { $0.id == id }
    }

    var produitClub: Product? {
        let id = periode == .annuel ? IdentifiantsIAP.clubAnnuel : IdentifiantsIAP.clubMensuel
        return storeKit.produits.first { $0.id == id }
    }

    var produitSelectionne: Product? {
        guard let id = produitSelectionneID else { return nil }
        return storeKit.produits.first { $0.id == id }
    }

    // MARK: - Label CTA dynamique (jamais tronqué)

    /// Logique pure du label CTA — testable sans `Product` StoreKit (non constructible en test).
    static func ctaLabel(etat: EtatChargement, prixSelectionne: String?, essaiEligible: Bool) -> String {
        switch etat {
        case .chargement:
            return TextesPaywall.ctaChargement
        case .erreur:
            return TextesPaywall.ctaReessayer
        case .initial, .pret:
            guard let prix = prixSelectionne else { return TextesPaywall.ctaChoisirPlan }
            if essaiEligible {
                return TextesPaywall.ctaEssaiEligible
            }
            return "\(TextesPaywall.ctaAchatPrefixe)\(prix)"
        }
    }

    var ctaLabel: String {
        Self.ctaLabel(
            etat: etat,
            prixSelectionne: produitSelectionne?.displayPrice,
            essaiEligible: produitSelectionne.map { eligibiliteParProduit[$0.id] == true } ?? false
        )
    }

    /// Logique pure de l'activation du CTA — testable sans `Product` StoreKit.
    /// Vrai uniquement quand on peut réellement déclencher un achat.
    /// L'état `.erreur` reste cliquable mais déclenche un retry — voir `tapCTA`.
    static func ctaEstActif(etat: EtatChargement, aProduitSelectionne: Bool, achatEnCours: Bool) -> Bool {
        switch etat {
        case .erreur:
            return !achatEnCours
        case .pret:
            return aProduitSelectionne && !achatEnCours
        case .initial, .chargement:
            return false
        }
    }

    var ctaEstActif: Bool {
        Self.ctaEstActif(
            etat: etat,
            aProduitSelectionne: produitSelectionne != nil,
            achatEnCours: enCours
        )
    }

    // MARK: - Chargement / retry idempotent

    func chargerSiNecessaire() async {
        guard etat != .chargement else { return }
        etat = .chargement
        erreur = nil

        do {
            if storeKit.produits.isEmpty {
                try await storeKit.chargerProduits()
            }
            if storeKit.produits.isEmpty {
                logger.warning("Paywall : produits toujours vides après chargement")
                etat = .erreur(TextesPaywall.erreurChargementProduits)
                return
            }
            await chargerEligibilite()
            etat = .pret
        } catch {
            logger.error("Échec chargement paywall : \(error.localizedDescription)")
            etat = .erreur(TextesPaywall.erreurChargementProduits)
        }
    }

    private func chargerEligibilite() async {
        var resultats: [String: Bool] = [:]
        for produit in storeKit.produits {
            let eligible = await produit.subscription?.isEligibleForIntroOffer ?? false
            resultats[produit.id] = eligible
        }
        eligibiliteParProduit = resultats
    }

    // MARK: - Achat

    /// Retourne `true` si l'achat a abouti (la vue dismiss alors).
    func acheter() async -> Bool {
        guard let produit = produitSelectionne, !enCours else { return false }
        enCours = true
        erreur = nil
        analytics.suivre(evenement: EvenementAnalytics.achatInitie,
                         metadonnees: ["produit": produit.id])
        defer { enCours = false }

        do {
            _ = try await storeKit.acheter(produit)
            analytics.suivre(evenement: EvenementAnalytics.achatReussi,
                             metadonnees: ["produit": produit.id])
            return true
        } catch StoreKitError.userCancelled {
            analytics.suivre(evenement: EvenementAnalytics.achatEchoue,
                             metadonnees: ["raison": "annule"])
            return false
        } catch {
            erreur = (error as? LocalizedError)?.errorDescription ?? TextesPaywall.erreurAchat
            analytics.suivre(evenement: EvenementAnalytics.achatEchoue,
                             metadonnees: ["raison": "\(error)"])
            return false
        }
    }

    // MARK: - Restauration

    /// Retourne `true` si un abonnement actif a été retrouvé (la vue dismiss alors).
    func restaurer() async -> Bool {
        guard !enCours else { return false }
        enCours = true
        erreur = nil
        analytics.suivre(evenement: EvenementAnalytics.restaurationTentee)
        defer { enCours = false }

        do {
            try await storeKit.restaurer()
            if await storeKit.statutSouscriptionActif() == nil {
                erreur = TextesPaywall.erreurAucunAchatARestaurer
                return false
            }
            return true
        } catch {
            erreur = TextesPaywall.erreurRestaurationReseau
            return false
        }
    }
}
