//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  GestionAbonnementView — push depuis ProfilView. Affiche le tier courant,
//  permet de gérer l'abonnement Apple, restaurer les achats, ou upgrader.
//

import SwiftUI

struct GestionAbonnementView: View {
    @Environment(AbonnementService.self) private var abonnementService
    @Environment(StoreKitService.self) private var storeKit
    @Environment(\.dismiss) private var dismiss

    @State private var afficherPaywallUpgrade = false
    @State private var enCoursRestauration = false
    @State private var toast: String? = nil

    private let urlAppleAbonnements = URL(string: "https://apps.apple.com/account/subscriptions")!

    var body: some View {
        ScrollView {
            VStack(spacing: LiquidGlassKit.espaceLG) {
                // En-tête statut
                VStack(spacing: 12) {
                    BadgeStatut(statut: abonnementService.statut)
                    dateRenouvText
                }
                .frame(maxWidth: .infinity)
                .padding(LiquidGlassKit.espaceLG)
                .glassCard()

                // Actions
                VStack(spacing: 12) {
                    Link(destination: urlAppleAbonnements) {
                        ligneAction(icone: "applelogo", titre: TextesPaywall.ctaGererApple, couleur: PaletteMat.bleu)
                    }

                    if abonnementService.tierActif == .pro {
                        Button {
                            afficherPaywallUpgrade = true
                        } label: {
                            ligneAction(icone: "arrow.up.circle.fill", titre: TextesPaywall.ctaPasserClub, couleur: PaletteMat.violet)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        Task { await restaurer() }
                    } label: {
                        ligneAction(
                            icone: enCoursRestauration ? "arrow.clockwise" : "arrow.counterclockwise",
                            titre: TextesPaywall.ctaRestaurer,
                            couleur: PaletteMat.vert
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(enCoursRestauration)
                }

                if let t = toast {
                    Text(t)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top)
                }

                Spacer(minLength: 40)
            }
            .padding(LiquidGlassKit.espaceMD)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Mon abonnement")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $afficherPaywallUpgrade) {
            NavigationStack {
                PaywallView(mode: .gestion)
            }
        }
    }

    @ViewBuilder
    private var dateRenouvText: some View {
        let statut = abonnementService.statut
        switch statut {
        case .essaiActif(_, let jours):
            Text("Essai · \(jours) jours restants")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .proMensuel(let d), .proAnnuel(let d), .clubMensuel(let d), .clubAnnuel(let d):
            Text("Renouvellement le \(d.formatFrancais())")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .gracePeriode(_, let d):
            Text("Période de tolérance jusqu'au \(d.formatFrancais())")
                .font(.caption)
                .foregroundStyle(.orange)
        case .expire(_, let d):
            Text("Expiré depuis le \(d.formatFrancais())")
                .font(.caption)
                .foregroundStyle(.red)
        default:
            EmptyView()
        }
    }

    private func ligneAction(icone: String, titre: String, couleur: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icone)
                .foregroundStyle(couleur)
                .frame(width: 24)
            Text(titre)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMoyen))
    }

    private func restaurer() async {
        enCoursRestauration = true
        toast = TextesPaywall.toastRestauration
        do {
            try await storeKit.restaurer()
            toast = TextesPaywall.toastRestaurationReussie
        } catch {
            toast = TextesPaywall.toastRestaurationVide
        }
        enCoursRestauration = false
    }
}
