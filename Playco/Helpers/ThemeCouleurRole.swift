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
/// `nonisolated` : constantes Sendable lues depuis des contextes non-MainActor
/// (FormationType.couleurPourLabel — Phase 5.2).
// MARK: - Mat Nuit (2.4, révision fondateur 2026-07-06)
// Le fond est LA NUIT ; les 5 couleurs d'espace survivent en tons neutres
// calibrés (contraste ≥ 4,5:1 sur la nuit — garanti par MatNuitTests) ; le
// verre sombre est la matière (corps des modificateurs, étape B).
// Hex figés = contrat de design vérifié en revue par /playco-mat-review.
nonisolated enum MatNuit {
    // Fond & encres
    static let fondHex = "#0D0D0F"
    static let encreHex = "#F2F1ED"
    static let encre2Hex = "#ABA9A3"
    static let encre3Hex = "#6F6D68"   // décoratif SEULEMENT (contraste insuffisant)

    static let fond = Color(hex: fondHex)
    static let encre = Color(hex: encreHex)
    static let encre2 = Color(hex: encre2Hex)
    static let encre3 = Color(hex: encre3Hex)
    /// Filet hairline : blanc 10 % sur la nuit.
    static let filet = Color.white.opacity(0.10)

    // Les 5 tons d'espace (neutres, calibrés sur la nuit)
    static let terreHex = "#C08A64"      // Séances
    static let briqueHex = "#BE6B63"     // Matchs
    static let ardoiseHex = "#7292B4"    // Stratégies
    static let saugeHex = "#74A98D"      // Équipe
    static let lavandeHex = "#9789BD"    // Entraînement

    static let terre = Color(hex: terreHex)
    static let brique = Color(hex: briqueHex)
    static let ardoise = Color(hex: ardoiseHex)
    static let sauge = Color(hex: saugeHex)
    static let lavande = Color(hex: lavandeHex)

    // Sémantiques
    static let liveHex = "#E0473D"
    static let deltaPositifHex = "#4FA37E"
    static let deltaNegatifHex = "#D4726A"
    static let live = Color(hex: liveHex)
    static let deltaPositif = Color(hex: deltaPositifHex)
    static let deltaNegatif = Color(hex: deltaNegatifHex)

    /// Teinte de verre maximale d'un espace (loi 4 : verre sombre, ≤ 12 %).
    static let teinteVerreMax = 0.12
    /// Bordure blanche du verre (détache le panneau de la nuit).
    static let bordureVerre = 0.09
    /// Reflet spéculaire 1 pt en haut du verre.
    static let refletVerre = 0.08
    /// Ombre des cartes sur la nuit (exception assumée à la loi 7 : sans elle,
    /// le verre sombre ne se détache pas du fond nuit).
    static let ombreCarteNuit = 0.35
}

nonisolated enum PaletteMat {
    // Couleurs principales — mates et désaturées
    // 2.4-C (Mat Nuit) : les 4 noms SURVIVENT (signatures intactes — tous les
    // sites héritent) mais pointent vers les tons neutres calibrés sur la nuit.
    // Les hex vifs v2 (#E8734A/#4A8AF4/#34C785/#9B7AE8) sont morts (loi 2).
    static let orange = MatNuit.terre      // Séances
    static let bleu   = MatNuit.ardoise    // Stratégies
    static let vert   = MatNuit.sauge      // Équipe
    static let violet = MatNuit.lavande    // Entraînement

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
    // 2.4 (revue) : sémantiques alignées MatNuit — plus aucun hex vif survivant.
    static let positif = MatNuit.deltaPositif
    static let negatif = MatNuit.deltaNegatif
    static let attention = MatNuit.terre
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
    /// Loi 10 — le courtside est INTOUCHABLE en vague 1 : pas de nouveaux
    /// ornements de verre au bord du terrain.
    @Environment(\.modeBordDeTerrain) private var modeBordDeTerrain

    func body(content: Content) -> some View {
        // 2.4-B — verre sombre 3.0 (Mat Nuit) : UNE couche, teinte d'espace
        // plafonnée (MatNuit.teinteVerreMax), bordure blanche 9 % + reflet
        // 1 pt en haut, ombre douce pour détacher de la nuit.
        content
            .glassEffect(
                .regular.tint(teinte.map { $0.opacity(MatNuit.teinteVerreMax) }),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(modeBordDeTerrain ? 0 : MatNuit.bordureVerre), lineWidth: 1)
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(modeBordDeTerrain ? 0 : MatNuit.refletVerre))
                    .frame(height: 1)
                    .padding(.horizontal, cornerRadius)
            }
            .if(ombre) { view in
                view.shadow(color: .black.opacity(modeBordDeTerrain ? 0.06 : MatNuit.ombreCarteNuit), radius: 12, y: 4)
            }
    }
}

/// Section glass — conteneur de contenu (matériau natif, sans teinte).
struct GlassSection: ViewModifier {
    @Environment(\.modeBordDeTerrain) private var modeBordDeTerrain

    func body(content: Content) -> some View {
        content
            .padding(16)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(modeBordDeTerrain ? 0 : MatNuit.bordureVerre), lineWidth: 1)
            )
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
            .glassEffect(.regular.tint(couleur.opacity(MatNuit.teinteVerreMax)), in: Capsule(style: .continuous))
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
