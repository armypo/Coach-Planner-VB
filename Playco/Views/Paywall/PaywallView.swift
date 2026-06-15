//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  PaywallView — vue canonique du paywall. 3 modes (welcome, bloquant, gestion)
//  partagent le même layout. Délègue toute la logique d'état à `PaywallViewModel`
//  (états chargement/pret/erreur, achat, restauration). Empty state + retry inclus.
//

import SwiftUI
import StoreKit
import SwiftData

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
    @Environment(AuthService.self) private var authService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: PaywallViewModel?

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
            LinearGradient(
                colors: [Color.black, Color(red: 0.08, green: 0.04, blue: 0.02)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: LiquidGlassKit.espaceLG) {
                    entete

                    if viewModel?.etat == .pret {
                        SelecteurPeriode(selection: bindingPeriode)
                            .padding(.horizontal, LiquidGlassKit.espaceMD)
                    }

                    cartesPricing

                    if let erreur = viewModel?.erreur {
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
                            if let onTermine { onTermine() } else { dismiss() }
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
        .task {
            if viewModel == nil {
                viewModel = PaywallViewModel(storeKit: storeKit, analytics: analytics)
            }
            analytics.suivre(evenement: EvenementAnalytics.paywallAffiche,
                             metadonnees: ["mode": "\(mode)"])
            await viewModel?.chargerSiNecessaire()
        }
    }

    // MARK: - Bindings

    private var bindingPeriode: Binding<PeriodePaywall> {
        Binding(
            get: { viewModel?.periode ?? .annuel },
            set: { viewModel?.periode = $0 }
        )
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

    // MARK: - Cartes Pricing (avec empty state + erreur)

    @ViewBuilder
    private var cartesPricing: some View {
        if let vm = viewModel {
            switch vm.etat {
            case .initial, .chargement:
                cartesChargement
            case .erreur(let message):
                cartesErreur(message: message)
            case .pret:
                cartesProduits(vm: vm)
            }
        } else {
            cartesChargement
        }
    }

    private var cartesChargement: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.white)
                .controlSize(.large)
            Text(TextesPaywall.chargementProduits)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private func cartesErreur(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.8))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private func cartesProduits(vm: PaywallViewModel) -> some View {
        VStack(spacing: LiquidGlassKit.espaceMD) {
            if let pro = vm.produitPro {
                PricingCard(
                    produit: pro,
                    tier: .pro,
                    estSelectionne: vm.produitSelectionneID == pro.id,
                    estEligibleEssai: vm.eligibiliteParProduit[pro.id] ?? false,
                    onTap: { vm.produitSelectionneID = pro.id }
                )
            }
            if let club = vm.produitClub {
                PricingCard(
                    produit: club,
                    tier: .club,
                    estSelectionne: vm.produitSelectionneID == club.id,
                    estEligibleEssai: vm.eligibiliteParProduit[club.id] ?? false,
                    onTap: { vm.produitSelectionneID = club.id }
                )
            }
        }
    }

    // MARK: - CTA

    private var boutonCTA: some View {
        Button {
            Task { await tapCTA() }
        } label: {
            HStack {
                if viewModel?.enCours == true {
                    ProgressView().tint(.white)
                } else {
                    Text(viewModel?.ctaLabel ?? TextesPaywall.ctaChargement)
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
            .opacity(viewModel?.ctaEstActif == true ? 1.0 : 0.45)
        }
        .disabled(viewModel?.ctaEstActif != true)
        .animation(LiquidGlassKit.springDefaut, value: viewModel?.produitSelectionneID)
        .animation(LiquidGlassKit.springDefaut, value: viewModel?.ctaEstActif)
    }

    private func tapCTA() async {
        guard let vm = viewModel else { return }
        if case .erreur = vm.etat {
            await vm.chargerSiNecessaire()
            return
        }
        if await vm.acheter() {
            // Rafraîchir immédiatement le statut (sinon l'app reste sur le tier
            // périmé jusqu'au prochain lancement). Déclenche aussi en cascade
            // publierAbonnementPublic + propagerTierAuxEquipes → débloque les athlètes.
            await abonnementService.rafraichir(
                utilisateur: authService.utilisateurConnecte,
                context: modelContext,
                storeKit: storeKit
            )
            if let onTermine { onTermine() } else { dismiss() }
        }
    }

    private var boutonRestaurer: some View {
        Button {
            Task {
                guard let vm = viewModel else { return }
                if await vm.restaurer() {
                    await abonnementService.rafraichir(
                        utilisateur: authService.utilisateurConnecte,
                        context: modelContext,
                        storeKit: storeKit
                    )
                    if let onTermine { onTermine() } else { dismiss() }
                }
            }
        } label: {
            Text(TextesPaywall.ctaRestaurer)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))
        }
        .disabled(viewModel?.enCours == true)
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
}
