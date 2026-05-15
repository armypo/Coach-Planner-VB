//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  PaywallBloquantView — fullScreenCover post-essai. Pas de dismiss possible
//  sans achat ou restauration.
//

import SwiftUI

struct PaywallBloquantView: View {
    var source: String = "feature_gate"

    var body: some View {
        NavigationStack {
            PaywallView(mode: .bloquant)
                .interactiveDismissDisabled(true)
        }
    }
}
