//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Uniformisation (pivot, chantier D) : bouton « ← Accueil » partagé par les
//  5 racines de section — remplace 5 copies verbatim.
//

import SwiftUI

struct BoutonRetourAccueil: View {
    var couleur: Color = .primary
    var action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                Image(systemName: "volleyball.fill")
                    .font(.system(size: 14))
                Text("Accueil")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(couleur)
        }
    }
}
