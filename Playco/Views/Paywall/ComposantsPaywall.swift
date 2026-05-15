//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  ComposantsPaywall — éléments UI réutilisables (FeatureRow, PricingCard,
//  SelecteurPeriode, BadgeStatut, BanniereEssai).
//

import SwiftUI
import StoreKit

// MARK: - Période sélecteur

enum PeriodePaywall: String, CaseIterable, Identifiable {
    case mensuel, annuel
    var id: String { rawValue }
    var label: String {
        switch self {
        case .mensuel: return TextesPaywall.periodeMensuel
        case .annuel: return TextesPaywall.periodeAnnuel
        }
    }
}

// MARK: - FeatureRow

struct FeatureRow: View {
    let icone: String
    let titre: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icone)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .frame(width: 22)
            Text(titre)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
        }
    }
}

// MARK: - SelecteurPeriode

struct SelecteurPeriode: View {
    @Binding var selection: PeriodePaywall

    var body: some View {
        Picker("Période", selection: $selection) {
            ForEach(PeriodePaywall.allCases) { p in
                Text(p.label).tag(p)
            }
        }
        .pickerStyle(.segmented)
        .colorScheme(.dark)
    }
}

// MARK: - PricingCard

struct PricingCard: View {
    let produit: Product
    let tier: Tier
    let estSelectionne: Bool
    let estEligibleEssai: Bool
    let onTap: () -> Void

    private var couleurTier: Color {
        tier == .club ? PaletteMat.violet : PaletteMat.orange
    }

    private var labelPeriode: String {
        guard let subscription = produit.subscription else { return "" }
        let period = subscription.subscriptionPeriod
        switch (period.unit, period.value) {
        case (.month, 1): return "/ mois"
        case (.year, 1): return "/ année"
        default: return ""
        }
    }

    /// Calcul équivalent /mois pour les abonnements annuels (affichage informatif).
    private var equivalentMois: String? {
        guard let subscription = produit.subscription,
              subscription.subscriptionPeriod.unit == .year else { return nil }
        let prix = NSDecimalNumber(decimal: produit.price).doubleValue / 12.0
        return String(format: "%.2f $ / mois", prix)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(tier.label)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Spacer()
                    if estEligibleEssai {
                        Text(TextesPaywall.badge14JoursOfferts)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(couleurTier, in: Capsule())
                    }
                }

                Text(tier == .pro ? TextesPaywall.sousTitreTierPro : TextesPaywall.sousTitreTierClub)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(produit.displayPrice)
                        .font(.title.weight(.heavy))
                        .foregroundStyle(.white)
                    Text(labelPeriode)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                if let equiv = equivalentMois {
                    Text(equiv)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Divider().background(Color.white.opacity(0.2))

                VStack(alignment: .leading, spacing: 8) {
                    let features = tier == .pro ? TextesPaywall.featuresPro : TextesPaywall.featuresClub
                    ForEach(features, id: \.self) { f in
                        FeatureRow(icone: "checkmark.circle.fill", titre: f)
                    }
                }
            }
            .padding(LiquidGlassKit.espaceLG)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: LiquidGlassKit.rayonGrand)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: LiquidGlassKit.rayonGrand)
                            .strokeBorder(
                                estSelectionne ? couleurTier : Color.white.opacity(0.15),
                                lineWidth: estSelectionne ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(LiquidGlassKit.springDefaut, value: estSelectionne)
    }
}

// MARK: - BadgeStatut

struct BadgeStatut: View {
    let statut: AbonnementService.Statut

    private var labelEtCouleur: (label: String, couleur: Color) {
        switch statut {
        case .chargement: return ("Chargement…", .gray)
        case .aucun: return ("Aucun abonnement", .gray)
        case .essaiActif(_, let jours): return ("Essai · \(jours)j restants", PaletteMat.orange)
        case .proMensuel, .proAnnuel: return (TextesPaywall.tierPro, PaletteMat.orange)
        case .clubMensuel, .clubAnnuel: return (TextesPaywall.tierClub, PaletteMat.violet)
        case .gracePeriode: return (TextesPaywall.badgeGracePeriode, .yellow)
        case .essaiExpire: return ("Essai expiré", .red)
        case .expire: return ("Expiré", .red)
        }
    }

    var body: some View {
        let infos = labelEtCouleur
        HStack(spacing: 6) {
            Circle()
                .fill(infos.couleur)
                .frame(width: 8, height: 8)
            Text(infos.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(infos.couleur)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(infos.couleur.opacity(0.12), in: Capsule())
    }
}

// MARK: - BanniereEssai (réutilisée dans la bannière in-app)

struct BanniereEssai: View {
    let statut: AbonnementService.Statut

    private var texte: String? {
        switch statut {
        case .essaiActif(_, let jours):
            return TextesPaywall.banniereEssaiJoursRestants(jours)
        case .gracePeriode: return TextesPaywall.banniereGracePeriode
        case .essaiExpire, .expire: return TextesPaywall.banniereExpire
        default: return nil
        }
    }

    private var couleur: Color {
        switch statut {
        case .essaiActif: return PaletteMat.orange
        case .gracePeriode: return .yellow
        case .essaiExpire, .expire: return .red
        default: return .clear
        }
    }

    var body: some View {
        if let t = texte {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(t)
                    .font(.caption.weight(.medium))
                    .lineLimit(2)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(couleur, in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMoyen))
        }
    }
}
