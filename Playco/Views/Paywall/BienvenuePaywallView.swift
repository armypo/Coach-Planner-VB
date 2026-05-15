//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  BienvenuePaywallView — sheet après le wizard. Non-dismissable autrement que
//  via le choix de plan (ou refus explicite par Apple dialog).
//

import SwiftUI

struct BienvenuePaywallView: View {
    let onTermine: () -> Void

    var body: some View {
        NavigationStack {
            PaywallView(mode: .welcome, onTermine: onTermine)
        }
    }
}
