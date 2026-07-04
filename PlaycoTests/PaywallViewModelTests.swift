//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Tests du PaywallViewModel : logique pure du CTA (label + activation) via les
//  statiques extraits (`Product` StoreKit n'étant pas constructible en test),
//  verrou anti-achat-involontaire B4 et chargement sans produits (→ erreur).
//

import Testing
import Foundation
@testable import Playco

@Suite("PaywallViewModel — CTA et états")
@MainActor
struct PaywallViewModelTests {

    private typealias Etat = PaywallViewModel.EtatChargement

    private func creerVM() -> PaywallViewModel {
        PaywallViewModel(storeKit: StoreKitService(), analytics: AnalyticsService())
    }

    // MARK: - ctaLabel par état

    @Test("ctaLabel — état chargement : label de chargement")
    func labelChargement() {
        // Arrange / Act
        let label = PaywallViewModel.ctaLabel(etat: .chargement, prixSelectionne: "14,99 $", essaiEligible: true)

        // Assert — le chargement prime sur toute sélection
        #expect(label == TextesPaywall.ctaChargement)
    }

    @Test("ctaLabel — état erreur : label réessayer")
    func labelErreur() {
        // Arrange / Act
        let label = PaywallViewModel.ctaLabel(etat: .erreur("boom"), prixSelectionne: "14,99 $", essaiEligible: false)

        // Assert
        #expect(label == TextesPaywall.ctaReessayer)
    }

    @Test("ctaLabel — état initial : choisir un plan sans sélection, prix ou essai avec sélection")
    func labelInitial() {
        // Sans produit sélectionné
        #expect(PaywallViewModel.ctaLabel(etat: .initial, prixSelectionne: nil, essaiEligible: false)
                == TextesPaywall.ctaChoisirPlan)

        // Produit sélectionné + essai éligible
        #expect(PaywallViewModel.ctaLabel(etat: .initial, prixSelectionne: "14,99 $", essaiEligible: true)
                == TextesPaywall.ctaEssaiEligible)

        // Produit sélectionné sans essai → préfixe + prix
        #expect(PaywallViewModel.ctaLabel(etat: .initial, prixSelectionne: "14,99 $", essaiEligible: false)
                == "\(TextesPaywall.ctaAchatPrefixe)14,99 $")
    }

    @Test("ctaLabel — état prêt : mêmes règles que initial, garde-fou B2 (jamais de « · » traînant)")
    func labelPret() {
        // Sans produit sélectionné
        #expect(PaywallViewModel.ctaLabel(etat: .pret, prixSelectionne: nil, essaiEligible: false)
                == TextesPaywall.ctaChoisirPlan)

        // Essai éligible
        #expect(PaywallViewModel.ctaLabel(etat: .pret, prixSelectionne: "89,99 $", essaiEligible: true)
                == TextesPaywall.ctaEssaiEligible)

        // Achat direct
        let label = PaywallViewModel.ctaLabel(etat: .pret, prixSelectionne: "89,99 $", essaiEligible: false)
        #expect(label == "S'abonner · 89,99 $")

        // Garde-fou régression B2 : aucun label ne se termine par le séparateur seul
        for etat: Etat in [.initial, .chargement, .pret, .erreur("x")] {
            for prix in [nil, "14,99 $"] {
                for essai in [true, false] {
                    let l = PaywallViewModel.ctaLabel(etat: etat, prixSelectionne: prix, essaiEligible: essai)
                    #expect(!l.hasSuffix("·") && !l.hasSuffix("· "), "Label tronqué B2 : « \(l) »")
                    #expect(!l.isEmpty)
                }
            }
        }
    }

    // MARK: - ctaEstActif : matrice complète

    @Test("ctaEstActif — matrice état × sélection × achat en cours")
    func ctaEstActifMatrice() {
        // (etat, aProduitSelectionne, achatEnCours, attendu)
        let cas: [(Etat, Bool, Bool, Bool, String)] = [
            (.initial, false, false, false, "initial : jamais actif"),
            (.initial, true, false, false, "initial : jamais actif même avec sélection"),
            (.chargement, true, false, false, "chargement : jamais actif"),
            (.pret, true, false, true, "prêt + sélection + libre : actif"),
            (.pret, false, false, false, "prêt sans sélection : inactif (anti-B6)"),
            (.pret, true, true, false, "prêt mais achat en cours : inactif"),
            (.erreur("x"), false, false, true, "erreur : cliquable pour retry même sans sélection"),
            (.erreur("x"), false, true, false, "erreur pendant opération en cours : inactif"),
        ]

        for (etat, selection, enCours, attendu, message) in cas {
            let actif = PaywallViewModel.ctaEstActif(
                etat: etat, aProduitSelectionne: selection, achatEnCours: enCours
            )
            #expect(actif == attendu, Comment(rawValue: message))
        }
    }

    // MARK: - Verrou anti-achat-involontaire B4

    @Test("init — verrou B4 : aucun produit pré-sélectionné et CTA inactif à l'initialisation")
    func verrouB4AucunePreSelection() {
        // Arrange / Act
        let vm = creerVM()

        // Assert
        #expect(vm.produitSelectionneID == nil, "B4 : jamais de pré-sélection à l'init")
        #expect(vm.produitSelectionne == nil)
        #expect(vm.etat == .initial)
        #expect(vm.ctaEstActif == false, "Anti-B6 : bouton inactif tant que rien n'est prêt")
        #expect(vm.ctaLabel == TextesPaywall.ctaChoisirPlan)
    }

    // MARK: - Chargement sans produits

    @Test("chargerSiNecessaire — produits vides (pas de config StoreKit en test) : état erreur et CTA réessayer")
    func chargerSiNecessaireProduitsVides() async {
        // Arrange — vrai StoreKitService : sans configuration StoreKit attachée au
        // test runner, Product.products(for:) ne livre aucun produit (ou throw).
        let vm = creerVM()

        // Act
        await vm.chargerSiNecessaire()

        // Assert — dans les deux cas (vide ou throw), l'état doit être .erreur
        #expect(vm.etat == .erreur(TextesPaywall.erreurChargementProduits))
        #expect(vm.ctaLabel == TextesPaywall.ctaReessayer)
        #expect(vm.ctaEstActif == true, "B5 : l'état erreur reste cliquable pour relancer le chargement")
    }
}
