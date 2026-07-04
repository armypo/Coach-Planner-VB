//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Tableau de statistiques du kit (Phase 1.5 refonte) : colonnes groupées
//  par catégorie (Attaque / Service / Bloc / Réception / Général), chiffres
//  monospacés, ligne de totaux optionnelle et bouton « Légende » branché sur
//  le glossaire MetriquesVolley. Remplace les tableaux ad hoc à 15 colonnes
//  du box score et du dashboard live.
//

import SwiftUI

/// Un groupe de colonnes (ex. « Attaque » : K, E, TA, Rend.).
struct GroupeColonnesStats: Identifiable {
    var id: String { titre }
    let titre: String
    let colonnes: [String]
    var teinte: Color = PaletteMat.bleu
}

/// Une ligne du tableau : libellé + valeurs pré-formatées (ordre = colonnes aplaties).
struct LigneTableauStats: Identifiable {
    let id: UUID
    let libelle: String
    let valeurs: [String]
    /// Couleurs optionnelles par colonne (nil = couleur par défaut).
    var couleurs: [Color?] = []

    func couleur(_ index: Int) -> Color? {
        index < couleurs.count ? couleurs[index] : nil
    }
}

struct TableauStats: View {
    let groupes: [GroupeColonnesStats]
    let lignes: [LigneTableauStats]
    var ligneTotaux: LigneTableauStats? = nil
    var largeurLibelle: CGFloat = 132
    var largeurColonne: CGFloat = 46

    @State private var afficherLegende = false

    private var colonnesAplaties: [String] { groupes.flatMap(\.colonnes) }

    var body: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            HStack {
                Spacer()
                Button {
                    afficherLegende = true
                } label: {
                    Label("Légende", systemImage: "info.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(PaletteMat.bleu)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }

            ScrollView(.horizontal, showsIndicators: true) {
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    // Rangée 1 : groupes de catégories
                    GridRow {
                        Color.clear
                            .frame(width: largeurLibelle, height: 1)
                        ForEach(groupes) { groupe in
                            Text(groupe.titre)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(groupe.teinte)
                                .frame(width: largeurColonne * CGFloat(groupe.colonnes.count),
                                       alignment: .center)
                                .padding(.vertical, 4)
                                .background(groupe.teinte.opacity(0.06))
                                .gridCellColumns(groupe.colonnes.count)
                        }
                    }

                    // Rangée 2 : abréviations
                    GridRow {
                        Text("Joueur")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: largeurLibelle, alignment: .leading)
                            .padding(.leading, LiquidGlassKit.espaceXS)
                        ForEach(Array(colonnesAplaties.enumerated()), id: \.offset) { _, abreviation in
                            Text(abreviation)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: largeurColonne)
                        }
                    }
                    .padding(.vertical, 4)

                    Divider().gridCellUnsizedAxes(.horizontal)

                    // Rangées de données
                    ForEach(lignes) { ligne in
                        rangee(ligne, enGras: false)
                    }

                    if let ligneTotaux {
                        Divider().gridCellUnsizedAxes(.horizontal)
                        rangee(ligneTotaux, enGras: true)
                    }
                }
            }
        }
        .sheet(isPresented: $afficherLegende) {
            LegendeStatsSheet()
        }
    }

    private func rangee(_ ligne: LigneTableauStats, enGras: Bool) -> some View {
        GridRow {
            Text(ligne.libelle)
                .font(enGras ? .caption.weight(.bold) : .caption)
                .lineLimit(1)
                .frame(width: largeurLibelle, alignment: .leading)
                .padding(.leading, LiquidGlassKit.espaceXS)
            ForEach(Array(ligne.valeurs.enumerated()), id: \.offset) { index, valeur in
                Text(valeur)
                    .font((enGras ? Font.caption.weight(.bold) : .caption).monospacedDigit())
                    .foregroundStyle(ligne.couleur(index) ?? PaletteMat.textePrincipal)
                    .frame(width: largeurColonne)
            }
        }
        .padding(.vertical, 5)
        // VoiceOver : une rangée = un élément « Joueur : abréviation valeur, … »
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(labelAccessibilite(ligne))
    }

    private func labelAccessibilite(_ ligne: LigneTableauStats) -> String {
        let paires = zip(colonnesAplaties, ligne.valeurs)
            .map { "\($0.0) \($0.1)" }
            .joined(separator: ", ")
        return "\(ligne.libelle) : \(paires)"
    }
}
