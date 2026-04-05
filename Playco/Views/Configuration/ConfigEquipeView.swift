//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI

/// Étape 4 — Créer une équipe
struct ConfigEquipeView: View {
    @Binding var nom: String
    @Binding var categorie: CategorieEquipe
    @Binding var division: DivisionEquipe
    @Binding var saison: String
    @Binding var couleurPrincipale: Color
    @Binding var couleurSecondaire: Color

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                titreEtape(numero: 4, titre: "Votre équipe",
                           description: "Créez votre équipe avec ses couleurs. Celles-ci seront utilisées sur le terrain de jeu.")

                // Nom
                champTexte(label: "NOM DE L'ÉQUIPE", placeholder: "ex : Élans",
                           texte: $nom, obligatoire: true)

                // Catégorie
                VStack(alignment: .leading, spacing: 6) {
                    Text("CATÉGORIE")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                    Picker("Catégorie", selection: $categorie) {
                        ForEach(CategorieEquipe.allCases, id: \.self) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Division
                VStack(alignment: .leading, spacing: 6) {
                    Text("DIVISION")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                    Picker("Division", selection: $division) {
                        ForEach(DivisionEquipe.allCases, id: \.self) { d in
                            Text(d.rawValue).tag(d)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(PaletteMat.orange)
                }

                // Saison
                champTexte(label: "SAISON", placeholder: "2025-2026",
                           texte: $saison, obligatoire: false)

                // Couleurs
                VStack(alignment: .leading, spacing: 12) {
                    Text("COULEURS D'ÉQUIPE")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)

                    HStack(spacing: 24) {
                        VStack(spacing: 8) {
                            ColorPicker("", selection: $couleurPrincipale, supportsOpacity: false)
                                .labelsHidden()
                                .frame(width: 50, height: 50)
                            Text("Équipe A")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        VStack(spacing: 8) {
                            ColorPicker("", selection: $couleurSecondaire, supportsOpacity: false)
                                .labelsHidden()
                                .frame(width: 50, height: 50)
                            Text("Équipe B")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Aperçu terrain miniature
                        HStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(couleurPrincipale)
                                .frame(width: 40, height: 24)
                                .overlay(Text("A").font(.caption2.bold()).foregroundStyle(.white))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(couleurSecondaire)
                                .frame(width: 40, height: 24)
                                .overlay(Text("B").font(.caption2.bold()).foregroundStyle(.white))
                        }
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(.vertical, 24)
        }
    }
}
