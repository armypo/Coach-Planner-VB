//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//

import SwiftUI

/// Petite carte affichant un chiffre clé avec icône, valeur et label.
/// Factorise le pattern dupliqué dans JoueurDetailView, JoueurSuiviMuscuSection
/// et d'autres vues de statistiques.
///
/// Utilisation :
/// ```swift
/// CarteChiffreCle(
///     titre: "Kills",
///     valeur: "\(joueur.attaquesReussies)",
///     icone: "flame.fill",
///     couleur: .green
/// )
/// ```
struct CarteChiffreCle: View {
    let titre: String
    let valeur: String
    let icone: String
    let couleur: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icone)
                .font(.system(size: 18))
                .foregroundStyle(couleur)
            Text(valeur)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
            Text(titre)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            couleur.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }
}
