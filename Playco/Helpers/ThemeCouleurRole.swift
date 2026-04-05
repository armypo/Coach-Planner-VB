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
}

// MARK: - Glass Modifiers

/// Carte glass premium — fond material, highlight gradient, double shadow
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    var ombre: Bool = true
    var teinte: Color? = nil

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        if let teinte {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(teinte.opacity(0.05))
                        }
                    }
            }
            // Highlight gradient interne (refraction lumineuse)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.12), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .allowsHitTesting(false)
            }
            // Bordure fine
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
            }
            .if(ombre) { view in
                view
                    .shadow(color: .black.opacity(0.03), radius: 3, y: 1)
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
            }
    }
}

/// Section glass — conteneur de contenu
struct GlassSection: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.06), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.03), radius: 6, y: 2)
    }
}

/// Chip glass — badge/tag
struct GlassChip: ViewModifier {
    var couleur: Color = .secondary

    func body(content: Content) -> some View {
        content
            .font(.caption.weight(.medium))
            .foregroundStyle(couleur)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                Capsule(style: .continuous)
                    .fill(couleur.opacity(0.1))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(couleur.opacity(0.15), lineWidth: 0.5)
            }
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
