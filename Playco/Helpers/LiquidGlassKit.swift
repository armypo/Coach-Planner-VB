//  Playco
//  Copyright (c) 2025 Christopher Dionne. Tous droits reserves.
//

import SwiftUI

/// Constantes centralisées du Design System Liquid Glass
/// Utiliser ces valeurs au lieu de magic numbers dans les vues
enum LiquidGlassKit {

    // MARK: - Coins arrondis

    /// Pour éléments de graphique (Swift Charts BarMark, indicateurs compacts)
    static let rayonMini: CGFloat = 4
    static let rayonPetit: CGFloat = 12
    static let rayonMoyen: CGFloat = 16
    static let rayonGrand: CGFloat = 22
    static let rayonXL: CGFloat = 28

    // MARK: - Espacement (système 4pt)

    static let espaceXS: CGFloat = 4
    static let espaceSM: CGFloat = 8
    static let espaceMD: CGFloat = 16
    static let espaceLG: CGFloat = 24
    static let espaceXL: CGFloat = 32
    static let espaceXXL: CGFloat = 40

    // MARK: - Animations

    static let springDefaut = Animation.spring(response: 0.35, dampingFraction: 0.85)
    static let springRebond = Animation.spring(response: 0.25, dampingFraction: 0.7)
    static let springDouce = Animation.spring(response: 0.45, dampingFraction: 0.9)

    // MARK: - Bordures Glass

    static let bordureCouleur = Color.white.opacity(0.25)
    static let bordureLargeur: CGFloat = 0.5

    // MARK: - Ombres

    static let ombreSubtile = (couleur: Color.black.opacity(0.03), rayon: CGFloat(3), y: CGFloat(1))
    static let ombreDouce = (couleur: Color.black.opacity(0.06), rayon: CGFloat(12), y: CGFloat(4))
    static let ombreMoyenne = (couleur: Color.black.opacity(0.08), rayon: CGFloat(16), y: CGFloat(8))

    // MARK: - Opacités

    static let highlightGradient = Color.white.opacity(0.12)
    static let teinteFond: CGFloat = 0.05
    static let badgeFond: CGFloat = 0.08

    // MARK: - Mode bord de terrain (courtside)

    /// Hauteur minimale des boutons en mode courtside (touch target)
    static let boutonCourtside: CGFloat = 60
    /// Largeur minimale des items de grille en mode courtside
    static let grilleCourtside: CGFloat = 120
    /// Taille de police du score en mode courtside
    static let scoreCourtside: CGFloat = 72
    /// Taille de police des labels en mode courtside
    static let policeCourtside: CGFloat = 18
}
