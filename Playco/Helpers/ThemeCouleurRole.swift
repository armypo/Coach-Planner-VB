//  Playco
//  Copyright (c) 2025 Christopher Dionne. Tous droits reserves.
//

import SwiftUI

// MARK: - Clé d'environnement pour la couleur du rôle connecté

/// Permet à toutes les vues enfants d'accéder à la couleur du rôle actif
/// Usage : @Environment(\.couleurRole) private var couleurRole
private struct CouleurRoleKey: EnvironmentKey {
    static let defaultValue: Color = PaletteMat.orange
}

extension EnvironmentValues {
    var couleurRole: Color {
        get { self[CouleurRoleKey.self] }
        set { self[CouleurRoleKey.self] = newValue }
    }
}

// MARK: - Liquid Glass Design System v2

/// Couleurs mates uniformes — palette Apple Liquid Glass
enum PaletteMat {
    // Couleurs principales — mates et désaturées
    static let orange = Color(hex: "#E8734A")    // Pratiques
    static let bleu   = Color(hex: "#4A8AF4")    // Stratégies
    static let vert   = Color(hex: "#34C785")    // Équipe
    static let violet = Color(hex: "#9B7AE8")    // Entraînement

    // Neutres
    static let fondPrincipal   = Color(.systemBackground)
    static let fondSecondaire  = Color(.secondarySystemBackground)
    static let fondTertiaire   = Color(.tertiarySystemBackground)
    static let separateur      = Color(.separator)

    // Texte
    static let textePrincipal  = Color(.label)
    static let texteSecondaire = Color(.secondaryLabel)
    static let texteTertiaire  = Color(.tertiaryLabel)

    // Sémantique stats — un seul endroit pour « bon / mauvais / neutre »
    static let positif = vert
    static let negatif = Color(hex: "#E85C5C")   // rouge mat aligné sur la palette
    static let attention = Color(hex: "#E8A54A") // orange d'alerte mat
}

// MARK: - Glass Modifiers (Liquid Glass natif — iOS 26+)
//
// Migration v2 → matériau Apple natif `.glassEffect` (API iOS 26.0, disponible
// sur la cible 26.2 sans garde `#available`). Le natif fournit refraction,
// highlight et bordure dynamiques (plus besoin des overlays gradient/stroke
// manuels). Les signatures `.glassCard()/.glassSection()/.glassChip()` sont
// inchangées : tous les sites d'appel héritent du matériau natif.

/// Carte glass premium — matériau Liquid Glass natif, teinte optionnelle.
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    var ombre: Bool = true
    var teinte: Color? = nil

    func body(content: Content) -> some View {
        content
            .glassEffect(
                .regular.tint(teinte.map { $0.opacity(0.18) }),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            // Élévation : une ombre douce conservée (le natif ne porte pas d'ombre
            // d'élévation sur fond clair). Désactivable via `ombre: false`.
            .if(ombre) { view in
                view.shadow(color: .black.opacity(0.06), radius: 12, y: 4)
            }
    }
}

/// Section glass — conteneur de contenu (matériau natif, sans teinte).
struct GlassSection: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Chip glass — badge/tag (capsule Liquid Glass teintée).
struct GlassChip: ViewModifier {
    var couleur: Color = .secondary

    func body(content: Content) -> some View {
        content
            .font(.caption.weight(.medium))
            .foregroundStyle(couleur)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .glassEffect(.regular.tint(couleur.opacity(0.18)), in: Capsule(style: .continuous))
    }
}

// MARK: - Button Styles

/// Style bouton glass — scale + opacity au press avec spring
struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
    func glassCard(cornerRadius: CGFloat = 20, ombre: Bool = true) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, ombre: ombre))
    }

    func glassCard(teinte: Color, cornerRadius: CGFloat = 20, ombre: Bool = true) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, ombre: ombre, teinte: teinte))
    }

    func glassSection() -> some View {
        modifier(GlassSection())
    }

    func glassChip(couleur: Color = .secondary) -> some View {
        modifier(GlassChip(couleur: couleur))
    }

    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
