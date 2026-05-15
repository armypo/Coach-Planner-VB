//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  BanniereAbonnementView — bannière compacte affichée en haut de ContentView
//  pour les coachs en essai (J-3, J-1), grace period, ou expirés.
//

import SwiftUI

struct BanniereAbonnementView: View {
    @Environment(AbonnementService.self) private var abonnementService
    @State private var afficherPaywall = false

    var body: some View {
        if abonnementService.doitAfficherBanniere {
            Button {
                afficherPaywall = true
            } label: {
                BanniereEssai(statut: abonnementService.statut)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, LiquidGlassKit.espaceMD)
            .padding(.vertical, 6)
            .fullScreenCover(isPresented: $afficherPaywall) {
                NavigationStack {
                    PaywallView(mode: .bloquant)
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}
