//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI

/// fullScreenCover non-dismissable par swipe, présenté quand un non-abonné
/// tape sur une action write (create/export/saisie stats). Sortie : achat
/// réussi OU bouton « Plus tard » (dismiss manuel).
struct PaywallBloquantView: View {
    @Environment(\.dismiss) private var dismiss
    let source: String

    var body: some View {
        NavigationStack {
            PaywallView(
                mode: .bloquant,
                source: source,
                onSucces: { _ in dismiss() }
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Plus tard")
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
        }
        .interactiveDismissDisabled(true)
    }
}
