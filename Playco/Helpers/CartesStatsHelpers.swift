//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Composants du kit statistiques (Phase 1.5 refonte) :
//  - CarteMetrique : carte métrique standard (label + valeur + delta + info)
//  - EnTeteSection : en-tête de section uniforme
//  - TypographieStats : styles de texte nommés (fin des tailles inline)
//  - LegendeStatsSheet : glossaire des métriques (catalogue MetriquesVolley)
//  Les cartes utilisent un fond teinté plat (pas de glass) : le matériau
//  glass est réservé aux conteneurs de section, jamais aux cellules denses.
//

import SwiftUI

// MARK: - Typographie nommée

enum TypographieStats {
    /// Grande valeur d'une carte héro (score, métrique principale).
    static let valeurHero = Font.system(size: 32, weight: .bold, design: .rounded)
    /// Valeur d'une carte métrique standard.
    static let valeurCarte = Font.system(size: 20, weight: .bold, design: .rounded)
    /// Libellé sous la valeur.
    static let labelMetrique = Font.caption2
    /// Delta / tendance.
    static let delta = Font.caption2.weight(.semibold)
}

// MARK: - Carte métrique

/// Carte métrique du kit stats : valeur pré-formatée (via FormatMetriques),
/// tendance optionnelle et définition optionnelle (popover info).
///
/// ```swift
/// CarteMetrique(titre: "Sideout %", valeur: FormatMetriques.pourcentage(so),
///               delta: +0.04, teinte: PaletteMat.vert,
///               definition: MetriquesVolley.catalogue.first { $0.abreviation == "SO%" })
/// ```
struct CarteMetrique: View {
    let titre: String
    let valeur: String
    var sousTitre: String? = nil
    /// Variation depuis la période précédente, en fraction (+0,04 = +4 pts).
    var delta: Double? = nil
    var teinte: Color = PaletteMat.bleu
    var definition: DefinitionMetrique? = nil

    @State private var afficherDefinition = false

    var body: some View {
        VStack(spacing: LiquidGlassKit.espaceXS + 2) {
            Text(valeur)
                .font(TypographieStats.valeurCarte)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            HStack(spacing: 3) {
                Text(titre)
                    .font(TypographieStats.labelMetrique)
                    .foregroundStyle(.secondary)
                if definition != nil {
                    Button {
                        afficherDefinition = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Définition de \(titre)")
                }
            }

            if let delta {
                etiquetteDelta(delta)
            } else if let sousTitre {
                Text(sousTitre)
                    .font(TypographieStats.labelMetrique)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LiquidGlassKit.espaceSM + 4)
        .background(
            teinte.opacity(LiquidGlassKit.badgeFond),
            in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit, style: .continuous)
        )
        .popover(isPresented: $afficherDefinition) {
            if let definition {
                VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
                    Text(definition.nom)
                        .font(.headline)
                    Text(definition.definition)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(LiquidGlassKit.espaceMD)
                .frame(maxWidth: 320)
                .presentationCompactAdaptation(.popover)
            }
        }
    }

    @ViewBuilder
    private func etiquetteDelta(_ delta: Double) -> some View {
        let enHausse = delta >= 0
        HStack(spacing: 2) {
            Image(systemName: enHausse ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 9, weight: .bold))
            Text(FormatMetriques.pourcentage(abs(delta)))
        }
        .font(TypographieStats.delta)
        .foregroundStyle(enHausse ? PaletteMat.positif : PaletteMat.negatif)
        .accessibilityLabel(enHausse ? "en hausse de \(FormatMetriques.pourcentage(abs(delta)))"
                                     : "en baisse de \(FormatMetriques.pourcentage(abs(delta)))")
    }
}

// MARK: - En-tête de section

/// En-tête de section standard du kit stats : titre, sous-titre optionnel,
/// action optionnelle alignée à droite.
struct EnTeteSection: View {
    let titre: String
    var sousTitre: String? = nil
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titre)
                    .font(.headline)
                if let sousTitre {
                    Text(sousTitre)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let actionLabel, let action {
                Button(action: action) {
                    HStack(spacing: 3) {
                        Text(actionLabel)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.plain)
                .foregroundStyle(PaletteMat.bleu)
            }
        }
    }
}

// MARK: - Légende / glossaire

/// Sheet listant le glossaire des métriques (catalogue MetriquesVolley).
/// Présentée par le bouton « Légende » des tableaux et vues de stats.
struct LegendeStatsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(MetriquesVolley.catalogue) { def in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: LiquidGlassKit.espaceSM) {
                        Text(def.abreviation)
                            .font(.caption.weight(.bold).monospaced())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(PaletteMat.bleu.opacity(0.12), in: Capsule())
                        Text(def.nom)
                            .font(.subheadline.weight(.semibold))
                    }
                    Text(def.definition)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
            .navigationTitle("Légende des statistiques")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Ancien composant (remplacé progressivement par CarteMetrique)

/// Petite carte affichant un chiffre clé avec icône, valeur et label.
/// ⚠️ Déprécié par la refonte stats : utiliser `CarteMetrique` pour toute
/// nouvelle vue ; les consommateurs existants migrent en Phase 4.
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
