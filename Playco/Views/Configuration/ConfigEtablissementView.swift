//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI

/// Étape 1 — Sélectionner l'établissement
struct ConfigEtablissementView: View {
    @Binding var nom: String
    @Binding var type: TypeEtablissement
    @Binding var ville: String
    @Binding var province: String
    @Binding var logo: Data?

    private let provinces = [
        "QC", "ON", "BC", "AB", "SK", "MB", "NB", "NS", "PE", "NL", "NT", "YT", "NU"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Titre
                titreEtape(numero: 1, titre: "Votre établissement",
                           description: "Identifiez l'école, le cégep ou le club auquel votre équipe est rattachée.")

                // Nom
                champTexte(label: "NOM DE L'ÉTABLISSEMENT", placeholder: "ex : Cégep Garneau",
                           texte: $nom, obligatoire: true)

                // Type
                VStack(alignment: .leading, spacing: 6) {
                    Text("TYPE D'ÉTABLISSEMENT")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                    Picker("Type", selection: $type) {
                        ForEach(TypeEtablissement.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(PaletteMat.orange)
                }

                // Ville + Province
                HStack(spacing: 16) {
                    champTexte(label: "VILLE", placeholder: "ex : Québec",
                               texte: $ville, obligatoire: false)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("PROVINCE")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)
                        Picker("Province", selection: $province) {
                            ForEach(provinces, id: \.self) { p in
                                Text(p).tag(p)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(PaletteMat.orange)
                    }
                    .frame(width: 100)
                }

                Spacer(minLength: 20)
            }
            .padding(.vertical, 24)
        }
    }
}
