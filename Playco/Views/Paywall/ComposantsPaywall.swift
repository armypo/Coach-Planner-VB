//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import StoreKit

// MARK: - Période d'abonnement

enum PeriodePaywall: String, CaseIterable, Identifiable {
    case mensuel, annuel
    var id: String { rawValue }
    var label: String { self == .mensuel ? "Mensuel" : "Annuel" }
}

// MARK: - FeatureRow

/// Ligne feature avec SF Symbol hierarchical + texte blanc.
struct FeatureRow: View {
    let icone: String
    let titre: String

    var body: some View {
        HStack(spacing: LiquidGlassKit.espaceSM) {
            Image(systemName: icone)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .frame(width: 20)
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
        .tint(PaletteMat.orange)
    }
}

// MARK: - PricingCard

/// Carte tier (Pro ou Club) avec prix, features, badges, sélection visuelle.
struct PricingCard: View {
    let produit: Product
    let estSelectionne: Bool
    let eligibleEssai: Bool
    let couleurTier: Color
    let nomTier: String
    let sousTitre: String
    let features: [String]
    let prefixe: String?   // ex: "Tout Playco Pro inclus"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: LiquidGlassKit.espaceMD) {
                enTete
                prix
                separateur
                listeFeatures
            }
            .padding(LiquidGlassKit.espaceLG)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: LiquidGlassKit.rayonGrand, style: .continuous)
                    .fill(couleurTier.opacity(estSelectionne ? 0.24 : 0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: LiquidGlassKit.rayonGrand, style: .continuous)
                    .strokeBorder(couleurTier.opacity(estSelectionne ? 0.9 : 0.3),
                                  lineWidth: estSelectionne ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .animation(LiquidGlassKit.springDefaut, value: estSelectionne)
        .accessibilityLabel("\(nomTier) — \(produit.displayPrice) \(IdentifiantsIAP.estAnnuel(produit.id) ? "par an" : "par mois")\(eligibleEssai ? ", 14 jours offerts" : "")\(estSelectionne ? ", sélectionné" : "")")
        .accessibilityHint("Double-tapez pour sélectionner ce plan")
    }

    private var enTete: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(nomTier)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text(sousTitre)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if estSelectionne {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(couleurTier)
            }
        }
    }

    private var prix: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(produit.displayPrice)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(IdentifiantsIAP.estAnnuel(produit.id) ? "/an" : "/mois")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                if IdentifiantsIAP.estAnnuel(produit.id) {
                    Text(TextesPaywall.badgeAnnuelEconomie)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(couleurTier, in: Capsule())
                }
            }
            if eligibleEssai {
                Label(TextesPaywall.badge14JoursOfferts, systemImage: "gift.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(couleurTier)
            }
        }
    }

    private var separateur: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(height: 1)
    }

    private var listeFeatures: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            if let prefixe {
                FeatureRow(icone: "star.fill", titre: prefixe)
            }
            ForEach(features, id: \.self) { f in
                FeatureRow(icone: "checkmark.circle.fill", titre: f)
            }
        }
    }
}

// MARK: - BadgeStatut

struct BadgeStatut: View {
    let statut: AbonnementService.Statut

    var body: some View {
        Text(texte)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(couleur, in: Capsule())
    }

    private var texte: String {
        switch statut {
        case .chargement:                      return "…"
        case .aucun:                           return "Aucun"
        case .essaiActif:                      return TextesPaywall.statutEssaiActif
        case .proMensuel:                      return TextesPaywall.statutProMensuel
        case .proAnnuel:                       return TextesPaywall.statutProAnnuel
        case .clubMensuel:                     return TextesPaywall.statutClubMensuel
        case .clubAnnuel:                      return TextesPaywall.statutClubAnnuel
        case .gracePeriode:                    return TextesPaywall.statutGracePeriode
        case .essaiExpire:                     return TextesPaywall.statutEssaiExpire
        case .expire:                          return TextesPaywall.statutExpire
        }
    }

    private var couleur: Color {
        switch statut {
        case .essaiActif:                      return PaletteMat.orange
        case .proMensuel, .proAnnuel:          return PaletteMat.bleu
        case .clubMensuel, .clubAnnuel:        return PaletteMat.violet
        case .gracePeriode:                    return .yellow
        case .essaiExpire, .expire:            return .red
        default:                               return .gray
        }
    }
}

// MARK: - BanniereEssai (contenu interne de BanniereAbonnementView)

struct BanniereEssai: View {
    let statut: AbonnementService.Statut

    var body: some View {
        HStack(spacing: LiquidGlassKit.espaceSM) {
            Image(systemName: icone)
                .foregroundStyle(.white)
            Text(texte)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, LiquidGlassKit.espaceMD)
        .padding(.vertical, LiquidGlassKit.espaceSM + 2)
        .background(couleur)
    }

    private var icone: String {
        switch statut {
        case .essaiActif:       return "clock.fill"
        case .gracePeriode:     return "exclamationmark.triangle.fill"
        case .essaiExpire:      return "lock.fill"
        case .expire:           return "lock.fill"
        default:                return "info.circle.fill"
        }
    }

    private var texte: String {
        switch statut {
        case .essaiActif(_, let jours):  return TextesPaywall.banniereJoursRestants(jours)
        case .gracePeriode:              return TextesPaywall.banniereGracePeriode
        case .essaiExpire:               return TextesPaywall.banniereEssaiExpire
        case .expire:                    return TextesPaywall.banniereExpire
        default:                         return ""
        }
    }

    private var couleur: Color {
        switch statut {
        case .essaiActif(_, let jours):  return jours <= 1 ? .red : PaletteMat.orange
        case .gracePeriode:              return .yellow
        case .essaiExpire, .expire:      return .red
        default:                         return .gray
        }
    }
}
