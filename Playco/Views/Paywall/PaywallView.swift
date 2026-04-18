//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import StoreKit

/// Mode d'usage du paywall canonique.
enum ModePaywall: String {
    case welcome    // fin de wizard, non-dismissable par swipe
    case bloquant   // action write tentée par non-abonné, fullScreenCover
    case gestion    // upgrade Pro → Club depuis ProfilView
}

/// Vue canonique paywall : 2 PricingCard (Pro + Club) + toggle mensuel/annuel
/// + CTA conditionnel selon éligibilité Introductory Offer.
///
/// Wrapped par `BienvenuePaywallView` / `PaywallBloquantView` / `GestionAbonnementView`.
struct PaywallView: View {
    @Environment(StoreKitService.self) private var storeKit
    @Environment(AbonnementService.self) private var abonnement
    @Environment(AnalyticsService.self) private var analytics
    @Environment(\.dismiss) private var dismiss

    let mode: ModePaywall
    let source: String
    var onSucces: ((_ tier: Tier) -> Void)? = nil
    var onCancel: (() -> Void)? = nil

    @State private var periode: PeriodePaywall = .annuel
    @State private var produitSelectionneID: String? = nil
    @State private var eligibleParProduit: [String: Bool] = [:]
    @State private var enAchat = false
    @State private var erreurAchat: String? = nil
    @State private var animer = false

    // MARK: - Body

    var body: some View {
        ZStack {
            fond
            contenu
        }
        .task { await chargerInitial() }
        .onAppear {
            analytics.suivre(
                evenement: EvenementAnalytics.paywallAffiche,
                metadonnees: ["source": source, "mode": mode.rawValue]
            )
        }
        .onDisappear {
            if mode != .bloquant {
                analytics.suivre(
                    evenement: EvenementAnalytics.paywallFerme,
                    metadonnees: ["source": source]
                )
            }
        }
    }

    // MARK: - Fond noir + gradient animé

    private var fond: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [PaletteMat.orange.opacity(0.35), .clear],
                center: animer ? .topTrailing : .topLeading,
                startRadius: 50, endRadius: 400
            )
            .ignoresSafeArea()
            .blur(radius: 40)
            .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: animer)
        }
        .onAppear { animer = true }
    }

    // MARK: - Contenu

    private var contenu: some View {
        ScrollView {
            VStack(spacing: LiquidGlassKit.espaceLG) {
                entete
                SelecteurPeriode(selection: $periode)
                    .padding(.horizontal, LiquidGlassKit.espaceMD)

                if storeKit.produits.isEmpty {
                    ProgressView().tint(.white).padding(.top, 40)
                } else {
                    cartesTiers
                }

                if let erreurAchat {
                    banniereErreur(erreurAchat)
                }

                ctaPrincipal
                ctaRestaurer
                mentionLegale
            }
            .padding(.horizontal, LiquidGlassKit.espaceLG)
            .padding(.vertical, LiquidGlassKit.espaceXL)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - En-tête

    private var entete: some View {
        VStack(spacing: LiquidGlassKit.espaceSM) {
            HStack(spacing: 10) {
                Image(systemName: "volleyball.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(PaletteMat.orange)
                Text("Playco")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Text(titreSelonMode)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            if mode == .welcome {
                Text(TextesPaywall.sousTitreWelcome)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var titreSelonMode: String {
        switch mode {
        case .welcome:   return TextesPaywall.titreWelcome
        case .bloquant:  return TextesPaywall.titreBloquant
        case .gestion:   return TextesPaywall.titreGestion
        }
    }

    // MARK: - Cartes tiers

    private var cartesTiers: some View {
        let layout = layoutCartes()
        return layout {
            if let pro = produit(tier: .pro, annuel: periode == .annuel) {
                PricingCard(
                    produit: pro,
                    estSelectionne: produitSelectionneID == pro.id,
                    eligibleEssai: eligibleParProduit[pro.id] ?? false,
                    couleurTier: PaletteMat.orange,
                    nomTier: TextesPaywall.nomPro,
                    sousTitre: TextesPaywall.sousTitrePro,
                    features: TextesPaywall.featuresPro,
                    prefixe: nil,
                    action: { produitSelectionneID = pro.id }
                )
            }
            if let club = produit(tier: .club, annuel: periode == .annuel) {
                PricingCard(
                    produit: club,
                    estSelectionne: produitSelectionneID == club.id,
                    eligibleEssai: eligibleParProduit[club.id] ?? false,
                    couleurTier: PaletteMat.violet,
                    nomTier: TextesPaywall.nomClub,
                    sousTitre: TextesPaywall.sousTitreClub,
                    features: Array(TextesPaywall.featuresClub.dropFirst()),
                    prefixe: TextesPaywall.featuresClub.first,
                    action: { produitSelectionneID = club.id }
                )
            }
        }
    }

    /// iPad large : 2 cards côte à côte. iPhone/iPad portrait étroit : empilées.
    private func layoutCartes() -> AnyLayout {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad,
           UIScreen.main.bounds.width > 700 {
            return AnyLayout(HStackLayout(alignment: .top, spacing: LiquidGlassKit.espaceMD))
        }
        #endif
        return AnyLayout(VStackLayout(spacing: LiquidGlassKit.espaceMD))
    }

    private func produit(tier: Tier, annuel: Bool) -> Product? {
        let id: String = {
            switch (tier, annuel) {
            case (.pro, true):   return IdentifiantsIAP.proAnnuel
            case (.pro, false):  return IdentifiantsIAP.proMensuel
            case (.club, true):  return IdentifiantsIAP.clubAnnuel
            case (.club, false): return IdentifiantsIAP.clubMensuel
            default:             return ""
            }
        }()
        return storeKit.produits.first { $0.id == id }
    }

    // MARK: - CTA

    private var ctaPrincipal: some View {
        Button(action: declencherAchat) {
            HStack {
                if enAchat {
                    ProgressView().tint(.white)
                } else {
                    Text(labelCTA)
                        .fontWeight(.bold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(PaletteMat.orange, in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMoyen))
            .foregroundStyle(.white)
        }
        .disabled(enAchat || produitSelectionne == nil)
        .buttonStyle(GlassButtonStyle())
    }

    private var labelCTA: String {
        guard let produit = produitSelectionne else { return TextesPaywall.ctaEssaiEligible }
        if eligibleParProduit[produit.id] == true {
            return TextesPaywall.ctaEssaiEligible
        }
        let periodeLabel = IdentifiantsIAP.estAnnuel(produit.id) ? "/an" : "/mois"
        return TextesPaywall.ctaAchatDirect + produit.displayPrice + periodeLabel
    }

    private var produitSelectionne: Product? {
        guard let id = produitSelectionneID else { return nil }
        return storeKit.produits.first { $0.id == id }
    }

    private var ctaRestaurer: some View {
        Button {
            Task { await restaurer() }
        } label: {
            Text(TextesPaywall.ctaRestaurer)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))
                .underline()
        }
    }

    private var mentionLegale: some View {
        Text(TextesPaywall.mentionAutoRenouvellement)
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.55))
            .multilineTextAlignment(.center)
            .padding(.top, LiquidGlassKit.espaceSM)
    }

    private func banniereErreur(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message).font(.footnote)
        }
        .foregroundStyle(.white)
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.red, in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit))
    }

    // MARK: - Actions

    private func chargerInitial() async {
        if storeKit.produits.isEmpty {
            try? await storeKit.chargerProduits()
        }
        // Pré-sélection Pro annuel
        if produitSelectionneID == nil {
            produitSelectionneID = IdentifiantsIAP.proAnnuel
        }
        // Éligibilité essai par produit
        for produit in storeKit.produits {
            let eligible = (try? await produit.subscription?.isEligibleForIntroOffer) ?? false
            eligibleParProduit[produit.id] = eligible == true
        }
    }

    private func declencherAchat() {
        guard let produit = produitSelectionne else { return }
        enAchat = true
        erreurAchat = nil
        let tier = IdentifiantsIAP.tier(pour: produit.id)
        analytics.suivre(
            evenement: EvenementAnalytics.achatInitie,
            metadonnees: ["produit": produit.id, "tier": tier.rawValue]
        )
        Task {
            defer { enAchat = false }
            do {
                _ = try await storeKit.acheter(produit)
                analytics.suivre(
                    evenement: EvenementAnalytics.achatReussi,
                    metadonnees: [
                        "produit": produit.id,
                        "tier": tier.rawValue,
                        "prix": produit.displayPrice,
                        "source": source
                    ]
                )
                if eligibleParProduit[produit.id] == true {
                    analytics.suivre(
                        evenement: EvenementAnalytics.essaiDemarre,
                        metadonnees: ["tier": tier.rawValue]
                    )
                }
                onSucces?(tier)
                if mode != .welcome { dismiss() }
            } catch StoreKitService.StoreKitError.userCancelled {
                analytics.suivre(
                    evenement: EvenementAnalytics.achatEchoue,
                    metadonnees: ["raison": "userCancelled", "produit": produit.id]
                )
                onCancel?()
            } catch StoreKitService.StoreKitError.pending {
                erreurAchat = TextesPaywall.erreurAchatEnAttente
                analytics.suivre(
                    evenement: EvenementAnalytics.achatEchoue,
                    metadonnees: ["raison": "pending", "produit": produit.id]
                )
            } catch StoreKitService.StoreKitError.unverified {
                erreurAchat = TextesPaywall.erreurAchatNonVerif
                analytics.suivre(
                    evenement: EvenementAnalytics.achatEchoue,
                    metadonnees: ["raison": "unverified", "produit": produit.id]
                )
            } catch {
                erreurAchat = TextesPaywall.erreurAchatEchoue
                analytics.suivre(
                    evenement: EvenementAnalytics.achatEchoue,
                    metadonnees: ["raison": error.localizedDescription, "produit": produit.id]
                )
            }
        }
    }

    private func restaurer() async {
        analytics.suivre(evenement: EvenementAnalytics.restaurationTentee)
        do {
            try await storeKit.restaurer()
        } catch {
            erreurAchat = TextesPaywall.erreurRestauration
        }
    }
}
