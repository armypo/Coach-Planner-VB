//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import StoreKit

/// Vue de gestion d'abonnement accessible depuis ProfilView pour les coachs.
/// Affiche le statut courant + actions : gérer Apple, upgrade Pro→Club, restaurer.
struct GestionAbonnementView: View {
    @Environment(AbonnementService.self) private var abonnement
    @Environment(StoreKitService.self) private var storeKit

    @State private var afficherUpgrade = false
    @State private var erreur: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: LiquidGlassKit.espaceLG) {
                carteStatut
                if abonnement.tierActif == .pro {
                    sectionUpgrade
                }
                if abonnement.tierActif == .club {
                    sectionClubAccesComplet
                }
                actionsApple
            }
            .padding(LiquidGlassKit.espaceLG)
        }
        .navigationTitle(TextesPaywall.titreGestion)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $afficherUpgrade) {
            NavigationStack {
                PaywallView(
                    mode: .gestion,
                    source: "upgrade_pro_to_club",
                    onSucces: { _ in afficherUpgrade = false }
                )
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Fermer") { afficherUpgrade = false }
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .interactiveDismissDisabled(false)
        }
    }

    // MARK: - Carte statut

    private var carteStatut: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            HStack {
                BadgeStatut(statut: abonnement.statut)
                Spacer()
            }
            Text(libelleStatut)
                .font(.headline)
            if let sousTitre = sousTitreStatut {
                Text(sousTitre)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(LiquidGlassKit.espaceLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var libelleStatut: String {
        switch abonnement.statut {
        case .essaiActif(let tier, let jours):
            let nom = tier == .club ? TextesPaywall.nomClub : TextesPaywall.nomPro
            return "\(nom) · essai (\(jours) j restants)"
        case .proMensuel(let date):   return TextesPaywall.statutProMensuel + " · renouvellement \(formater(date))"
        case .proAnnuel(let date):    return TextesPaywall.statutProAnnuel + " · renouvellement \(formater(date))"
        case .clubMensuel(let date):  return TextesPaywall.statutClubMensuel + " · renouvellement \(formater(date))"
        case .clubAnnuel(let date):   return TextesPaywall.statutClubAnnuel + " · renouvellement \(formater(date))"
        case .gracePeriode(_, let date): return TextesPaywall.statutGracePeriode + " · relance \(formater(date))"
        case .essaiExpire:            return TextesPaywall.statutEssaiExpire
        case .expire(_, let date):    return TextesPaywall.statutExpire + " depuis \(formater(date))"
        case .aucun:                  return "Aucun abonnement actif"
        case .chargement:             return "Chargement…"
        }
    }

    private var sousTitreStatut: String? {
        switch abonnement.statut {
        case .essaiActif:   return "Accès complet pendant 14 jours. Tu peux annuler à tout moment."
        case .gracePeriode: return "Mets à jour ta méthode de paiement Apple pour ne pas perdre l'accès."
        case .essaiExpire, .expire: return "Mode lecture seule. Abonne-toi pour créer à nouveau."
        default: return nil
        }
    }

    private func formater(_ date: Date) -> String {
        date.formatFrancais()
    }

    // MARK: - Upgrade Pro → Club

    private var sectionUpgrade: some View {
        Button {
            afficherUpgrade = true
        } label: {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundStyle(PaletteMat.violet)
                VStack(alignment: .leading, spacing: 2) {
                    Text(TextesPaywall.ctaPasserClub)
                        .font(.subheadline.weight(.semibold))
                    Text("Débloque l'accès app pour tes athlètes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(LiquidGlassKit.espaceMD)
            .glassSection()
        }
        .buttonStyle(.plain)
    }

    private var sectionClubAccesComplet: some View {
        HStack(spacing: LiquidGlassKit.espaceSM) {
            Image(systemName: "star.circle.fill")
                .foregroundStyle(PaletteMat.violet)
            Text("Tu as accès à toutes les fonctionnalités Playco Club.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(LiquidGlassKit.espaceMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSection()
    }

    // MARK: - Actions Apple

    private var actionsApple: some View {
        VStack(spacing: LiquidGlassKit.espaceSM) {
            Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                HStack {
                    Image(systemName: "applelogo")
                    Text(TextesPaywall.ctaGererApple)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                }
                .padding(LiquidGlassKit.espaceMD)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassSection()
                .foregroundStyle(.primary)
            }

            Button {
                Task {
                    do {
                        try await storeKit.restaurer()
                    } catch {
                        erreur = TextesPaywall.erreurRestauration
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text(TextesPaywall.ctaRestaurer)
                    Spacer()
                }
                .padding(LiquidGlassKit.espaceMD)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassSection()
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            if let erreur {
                Text(erreur)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}
