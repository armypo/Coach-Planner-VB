//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  FeatureGating — modificateur `.bloqueSiNonPayant(source:)` à appliquer
//  sur les boutons d'écriture (création/modification/export).
//
//  Comportement :
//  - Si `abonnementService.peutEcrire == true` → affichage normal
//  - Sinon → contenu grisé + tap déclenche PaywallBloquantView fullScreenCover
//

import SwiftUI

struct BloqueSiNonPayant: ViewModifier {
    @Environment(AbonnementService.self) private var service
    @State private var afficherPaywall = false
    let source: String

    func body(content: Content) -> some View {
        if service.peutEcrire {
            content
        } else {
            content
                .allowsHitTesting(false)
                .opacity(0.45)
                .overlay {
                    Button { afficherPaywall = true } label: {
                        Color.clear.contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .fullScreenCover(isPresented: $afficherPaywall) {
                    PaywallBloquantView(source: source)
                }
        }
    }
}

extension View {
    /// Bloque l'interaction avec ce composant si l'utilisateur n'a pas d'abonnement
    /// actif (essai, Pro ou Club). Au tap : ouvre PaywallBloquantView.
    /// - Parameter source: identifiant analytique de la source du paywall.
    func bloqueSiNonPayant(source: String) -> some View {
        modifier(BloqueSiNonPayant(source: source))
    }
}
