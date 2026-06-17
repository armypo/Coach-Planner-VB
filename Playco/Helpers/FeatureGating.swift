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

/// Décision PURE (testable) : faut-il bloquer ce composant derrière le paywall ?
///
/// Seul le **rôle payeur** (`.coach`/`.admin`) est soumis au paywall. Les athlètes
/// (`.etudiant`) et les assistants (`.assistantCoach`) passent TOUJOURS — ils ne
/// paient pas (le coach paie pour son staff). Défense en profondeur avec `.siAutorise`.
func paywallDoitBloquer(role: RoleUtilisateur?, peutEcrire: Bool) -> Bool {
    guard let role, role == .coach || role == .admin else { return false }
    return !peutEcrire
}

struct BloqueSiNonPayant: ViewModifier {
    @Environment(AbonnementService.self) private var service
    @Environment(AuthService.self) private var authService
    @State private var afficherPaywall = false
    let source: String

    func body(content: Content) -> some View {
        if !paywallDoitBloquer(role: authService.utilisateurConnecte?.role, peutEcrire: service.peutEcrire) {
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

// MARK: - Gate Club (connexion d'athlètes)

/// Décision PURE (testable) : faut-il bloquer une action réservée au tier **Club**
/// (ajout d'athlètes) ? Seul le coach/admin est concerné ; le gate s'appuie sur
/// `peutConnecterAthletes` (Club-only, dérivé de StoreKit — jamais de la Public DB).
/// Les autres rôles ne déclenchent pas ce gate (l'action ne leur est de toute façon
/// pas exposée via `.siAutorise`).
func clubRequisDoitBloquer(role: RoleUtilisateur?, peutConnecterAthletes: Bool) -> Bool {
    guard let role, role == .coach || role == .admin else { return false }
    return !peutConnecterAthletes
}

struct BloqueSiNonClub: ViewModifier {
    @Environment(AbonnementService.self) private var service
    @Environment(AuthService.self) private var authService
    @State private var afficherPaywall = false
    let source: String

    func body(content: Content) -> some View {
        if !clubRequisDoitBloquer(role: authService.utilisateurConnecte?.role,
                                  peutConnecterAthletes: service.peutConnecterAthletes) {
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
    /// Bloque l'interaction si le coach n'a pas le tier **Club** (requis pour
    /// connecter des athlètes). Au tap : ouvre PaywallBloquantView. Réservé aux
    /// actions coach déjà masquées par `.siAutorise` pour les autres rôles.
    func bloqueSiNonClub(source: String) -> some View {
        modifier(BloqueSiNonClub(source: source))
    }
}
