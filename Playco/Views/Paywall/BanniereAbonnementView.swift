//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI

/// Bannière compacte top-screen affichée via `.safeAreaInset(edge: .top)`
/// de ContentView. Tap → PaywallView(.bloquant) en sheet.
/// Hidden si `!doitAfficherBanniere` ou si l'utilisateur n'est pas coach/admin.
struct BanniereAbonnementView: View {
    @Environment(AbonnementService.self) private var abonnement
    @Environment(AuthService.self) private var authService
    @State private var afficherPaywall = false

    var body: some View {
        if afficher {
            Button {
                afficherPaywall = true
            } label: {
                BanniereEssai(statut: abonnement.statut)
            }
            .buttonStyle(.plain)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityLabel("Bannière d'abonnement")
            .accessibilityHint("Double-tapez pour gérer votre abonnement Playco")
            .sheet(isPresented: $afficherPaywall) {
                NavigationStack {
                    PaywallView(
                        mode: .gestion,
                        source: "banniere",
                        onSucces: { _ in afficherPaywall = false }
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Fermer") { afficherPaywall = false }
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
            }
        }
    }

    private var afficher: Bool {
        guard abonnement.doitAfficherBanniere,
              let role = authService.utilisateurConnecte?.role,
              role == .coach || role == .admin
        else { return false }
        return true
    }
}
