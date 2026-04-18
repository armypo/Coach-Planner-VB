//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI

/// Sheet bloquant présenté à la fin du wizard de configuration.
/// L'utilisateur choisit son tier + démarre l'essai 14 jours, ou cancel
/// (reste dans l'app en mode lecture seule). `onTermine` est appelé dans les
/// 3 cas pour que `ConfigurationView` entre dans l'app après.
struct BienvenuePaywallView: View {
    var onTermine: () -> Void

    @State private var toast: String? = nil

    var body: some View {
        NavigationStack {
            PaywallView(
                mode: .welcome,
                source: "welcome",
                onSucces: { tier in
                    toast = TextesPaywall.toastEssaiDemarre(tier: tier)
                    onTermine()
                },
                onCancel: {
                    toast = TextesPaywall.toastCancelApple
                    onTermine()
                }
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        toast = TextesPaywall.toastCancelApple
                        onTermine()
                    } label: {
                        Text("Plus tard")
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
        }
    }
}
