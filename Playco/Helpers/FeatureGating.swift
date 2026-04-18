//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI

/// ViewModifier qui bloque une vue d'écriture si l'utilisateur n'a pas
/// d'abonnement actif (Pro ou Club, en essai ou facturation). Tap → ouvre
/// `PaywallBloquantView` en fullScreenCover.
///
/// Appliqué aux ~10 actions write critiques (create match/séance/stratégie,
/// export PDF/CSV, saisie stats live, modification utilisateur).
struct BloqueSiNonPayant: ViewModifier {
    @Environment(AbonnementService.self) private var service
    @Environment(AuthService.self) private var authService
    @State private var afficherPaywall = false
    let source: String

    func body(content: Content) -> some View {
        if doitBloquer {
            ZStack(alignment: .topTrailing) {
                content
                    .allowsHitTesting(false)
                    .opacity(0.5)
                Button {
                    afficherPaywall = true
                } label: {
                    Color.clear
                }
                .buttonStyle(.plain)
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(PaletteMat.orange, in: Circle())
                    .padding(6)
            }
            .fullScreenCover(isPresented: $afficherPaywall) {
                PaywallBloquantView(source: source)
            }
        } else {
            content
        }
    }

    /// La gate s'applique uniquement aux utilisateurs dont les actions dépendent
    /// d'un coach payant. Pour un athlète `.etudiant` connecté, l'accès à
    /// l'écriture est déjà filtré en amont par la gate centrale `appliquerGateTier`.
    /// Ici on bloque les coachs (principal / assistant) quand leur abonnement
    /// d'équipe est inactif.
    private var doitBloquer: Bool {
        guard let role = authService.utilisateurConnecte?.role else { return false }
        // Les athlètes et comptes non-connectés ne sont pas gatés par ce modifier
        // (gatés par la gate centrale).
        guard role == .coach || role == .assistantCoach || role == .admin else {
            return false
        }
        return !service.peutEcrire
    }
}

extension View {
    /// Bloque la vue si l'abonnement coach ne permet pas l'écriture.
    /// `source` identifie le point d'entrée (analytics + debug).
    func bloqueSiNonPayant(source: String) -> some View {
        modifier(BloqueSiNonPayant(source: source))
    }
}
