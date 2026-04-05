//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI

// MARK: - Composants partagés pour le wizard de configuration

/// Titre d'étape standardisé
func titreEtape(numero: Int, titre: String, description: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text("Étape \(numero) de 6")
            .font(.caption.weight(.semibold))
            .foregroundStyle(PaletteMat.orange)
            .tracking(0.5)

        Text(titre)
            .font(.title2.weight(.bold))

        Text(description)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Champ texte standardisé
func champTexte(label: String, placeholder: String, texte: Binding<String>, obligatoire: Bool) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            if obligatoire {
                Text("*")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.red)
            }
        }
        TextField(placeholder, text: texte)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12))
            .autocorrectionDisabled()
    }
}
