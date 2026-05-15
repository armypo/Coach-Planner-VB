//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  PaywallView — vue canonique du paywall. 3 modes (welcome, bloquant, gestion)
//  partagent le même layout. 2 PricingCard (Pro / Club), toggle mensuel/annuel,
//  CTA dynamique (essai gratuit si éligible, sinon achat direct).
//

import SwiftUI
import StoreKit

enum ModePaywall {
    case welcome     // sheet après wizard, dismissable uniquement via choix
    case bloquant    // fullScreenCover post-essai, pas de dismiss
    case gestion     // depuis ProfilView, dismissable
}

struct PaywallView: View {
    let mode: ModePaywall
    var onTermine: (() -> Void)? = nil

    @Environment(StoreKitService.self) private var storeKit
    @Environment(AbonnementService.self) private var abonnementService
    @Environment(AnalyticsService.self) private var analytics
    @Environment(\.dismiss) private var dismiss

    @State private var periode: PeriodePaywall = .annuel
    @State private var produitSelectionneID: String? = nil
    @State private var eligibiliteParProduit: [String: Bool] = [:]
    @State private var enCours = false
    @State private var erreur: String? = nil

    // MARK: - Produits filtrés selon période

    private var produitPro: Product? {
        let id = periode == .annuel ? IdentifiantsIAP.proAnnuel : IdentifiantsIAP.proMensuel
        return storeKit.produits.first { $0.id == id }
    }

    private var produitClub: Product? {
        let id = periode == .annuel ? IdentifiantsIAP.clubAnnuel : IdentifiantsIAP.clubMensuel
        return storeKit.produits.first { $0.id == id }
    }

    private var produitSelectionne: Product? {
        guard let id = produitSelectionneID else { return produitPro }
        return storeKit.produits.first { $0.id == id }
    }

    // MARK: - Titre selon mode

    private var titre: String {
        switch mode {
        case .welcome: return TextesPaywall.titreWelcome
        case .bloquant: return TextesPaywall.titreBloquant
        case .gestion: return TextesPaywall.titreGestion
        }
    }

    private var sousTitre: String {
        switch mode {
        case .welcome: return TextesPaywall.sousTitreWelcome
        case .bloquant: return TextesPaywall.sousTitreBloquant
        case .gestion: return ""
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Fond dégradé sombre
            LinearGradient(
                colors: [Color.black, Color(red: 0.08, green: 0.04, blue: 0.02)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: LiquidGlassKit.espaceLG) {
                    entete
                    SelecteurPeriode(selection: $periode)
                        .padding(.horizontal, LiquidGlassKit.espaceMD)

                    cartesPricing

                    if let erreur {
                        Text(erreur)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    boutonCTA
                    boutonRestaurer

                    mentionsLegales

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, LiquidGlassKit.espaceMD)
                .padding(.top, LiquidGlassKit.espaceLG)
            }

            if mode != .bloquant {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            analytics.suivre(evenement: EvenementAnalytics.paywallFerme)
                            onTermine?() ?? dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.6))
                                .padding()
                        }
                    }
                    Spacer()
                }
            }
        }
        .onAppear {
            analytics.suivre(evenement: EvenementAnalytics.paywallAffiche,
                             metadonnees: ["mode": "\(mode)"])
            // Pré-sélection Pro annuel par défaut
            if produitSelectionneID == nil {
                produitSelectionneID = IdentifiantsIAP.proAnnuel
            }
            Task { await chargerEligibilite() }
        }
    }

    // MARK: - En-tête

    private var entete: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "volleyball.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(PaletteMat.orange)
                Text("Playco")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Text(titre)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            if !sousTitre.isEmpty {
                Text(sousTitre)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Cartes Pricing

    @ViewBuilder
    private var cartesPricing: some View {
        VStack(spacing: LiquidGlassKit.espaceMD) {
            if let pro = produitPro {
                PricingCard(
                    produit: pro,
                    tier: .pro,
                    estSelectionne: produitSelectionneID == pro.id,
                    estEligibleEssai: eligibiliteParProduit[pro.id] ?? false,
                    onTap: { produitSelectionneID = pro.id }
                )
            }
            if let club = produitClub {
                PricingCard(
                    produit: club,
                    tier: .club,
                    estSelectionne: produitSelectionneID == club.id,
                    estEligibleEssai: eligibiliteParProduit[club.id] ?? false,
                    onTap: { produitSelectionneID = club.id }
                )
            }
        }
    }

    // MARK: - CTA

    private var boutonCTA: some View {
        Button {
            Task { await acheter() }
        } label: {
            HStack {
                if enCours {
                    ProgressView().tint(.white)
                } else {
                    Text(ctaLabel)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [PaletteMat.orange, PaletteMat.orange.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonGrand)
            )
        }
        .disabled(produitSelectionne == nil || enCours)
    }

    private var ctaLabel: String {
        guard let p = produitSelectionne else { return TextesPaywall.ctaAchatDirect }
        if eligibiliteParProduit[p.id] == true {
            return TextesPaywall.ctaEssaiEligible
        }
        return TextesPaywall.ctaAchatDirect + p.displayPrice
    }

    private var boutonRestaurer: some View {
        Button {
            Task { await restaurer() }
        } label: {
            Text(TextesPaywall.ctaRestaurer)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var mentionsLegales: some View {
        VStack(spacing: 8) {
            Text(TextesPaywall.mentionAutoRenouvellement)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            HStack(spacing: 16) {
                Link("CGU", destination: AppConstants.urlConditionsUtilisation)
                Link("Confidentialité", destination: AppConstants.urlPolitiqueConfidentialite)
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Actions

    private func chargerEligibilite() async {
        var resultats: [String: Bool] = [:]
        for produit in storeKit.produits {
            let eligible = await produit.subscription?.isEligibleForIntroOffer ?? false
            resultats[produit.id] = eligible
        }
        eligibiliteParProduit = resultats
    }

    private func acheter() async {
        guard let produit = produitSelectionne else { return }
        enCours = true
        erreur = nil
        analytics.suivre(evenement: EvenementAnalytics.achatInitie,
                         metadonnees: ["produit": produit.id, "tier": IdentifiantsIAP.tier(pour: produit.id).rawValue])
        do {
            _ = try await storeKit.acheter(produit)
            analytics.suivre(evenement: EvenementAnalytics.achatReussi,
                             metadonnees: ["produit": produit.id])
            onTermine?() ?? dismiss()
        } catch StoreKitError.userCancelled {
            // Pas d'erreur affichée — l'utilisateur a juste annulé
            analytics.suivre(evenement: EvenementAnalytics.achatEchoue,
                             metadonnees: ["raison": "annule"])
        } catch {
            erreur = (error as? LocalizedError)?.errorDescription ?? "L'achat a échoué. Réessaie."
            analytics.suivre(evenement: EvenementAnalytics.achatEchoue,
                             metadonnees: ["raison": "\(error)"])
        }
        enCours = false
    }

    private func restaurer() async {
        enCours = true
        analytics.suivre(evenement: EvenementAnalytics.restaurationTentee)
        do {
            try await storeKit.restaurer()
        } catch {
            erreur = "La restauration a échoué. Réessaie."
        }
        enCours = false
    }
}
