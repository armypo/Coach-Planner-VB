//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Carte éditable d'un joueur adverse du rapport de scouting (extrait de
//  ScoutingReportView, Phase 6). La ligne résumé (numéro, nom, étoiles de
//  menace) reste TOUJOURS visible ; les détails se déplient à la demande.
//  + EtoilesMenaceView : rangée d'étoiles 1-5 partagée (édition et lecture).
//

import SwiftUI

// MARK: - Étoiles de menace (partagé édition / lecture)

/// Rangée d'étoiles 1-5 du niveau de menace. `onTap` nil = lecture seule.
struct EtoilesMenaceView: View {
    let niveau: Int
    var onTap: ((Int) -> Void)? = nil

    var body: some View {
        HStack(spacing: LiquidGlassKit.espaceXS) {
            ForEach(1...5, id: \.self) { etoile in
                Image(systemName: etoile <= niveau ? "star.fill" : "star")
                    .font(.caption)
                    .foregroundStyle(etoile <= niveau ? .orange : PaletteMat.texteTertiaire)
                    .onTapGesture {
                        guard let onTap else { return }
                        withAnimation(LiquidGlassKit.springRebond) {
                            onTap(etoile)
                        }
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Menace \(niveau) sur 5")
    }
}

// MARK: - Carte joueur adverse

struct CarteJoueurAdverseEditable: View {
    @Binding var joueur: JoueurAdverse
    let estDeplie: Bool
    let peutModifier: Bool
    /// Frappe clavier dans un champ → sauvegarde debouncée côté parent.
    let onFrappe: () -> Void
    /// Interaction ponctuelle (étoiles) → sauvegarde immédiate côté parent.
    let onChangementImmediat: () -> Void
    let onBasculerDepli: () -> Void
    let onSupprimer: () -> Void

    private static let postes = ["Attaquant", "Passeur", "Central", "Libéro",
                                 "Réceptionneur-attaquant", "Opposé", "Autre"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ligneResume
            if estDeplie {
                details
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .glassCard(teinte: .red, cornerRadius: 14, ombre: true)
    }

    // MARK: - Ligne résumé (toujours visible, étoiles incluses)

    private var ligneResume: some View {
        HStack(spacing: 12) {
            Text("#\(joueur.numero)")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(.red)
                .frame(width: 50)

            VStack(alignment: .leading, spacing: 2) {
                Text(joueur.nom.isEmpty ? "Nouveau joueur" : joueur.nom)
                    .font(.headline)
                if !joueur.poste.isEmpty {
                    Text(joueur.poste)
                        .font(.caption)
                        .foregroundStyle(PaletteMat.texteSecondaire)
                }
            }

            Spacer()

            EtoilesMenaceView(niveau: joueur.menaceNiveau) { nouveau in
                joueur.menaceNiveau = nouveau
                onChangementImmediat()
            }

            Button {
                onBasculerDepli()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .rotationEffect(.degrees(estDeplie ? 180 : 0))
                    .foregroundStyle(PaletteMat.texteSecondaire)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(estDeplie ? "Replier les détails du joueur" : "Déplier les détails du joueur")

            Button(role: .destructive) {
                onSupprimer()
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.7))
            }
            .siAutorise(peutModifier)
        }
    }

    // MARK: - Détails (dépliables)

    private var details: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            HStack(spacing: LiquidGlassKit.espaceMD) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Numéro")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PaletteMat.texteSecondaire)
                    TextField("#", value: $joueur.numero, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onChange(of: joueur.numero) { _, _ in onFrappe() }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Nom")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PaletteMat.texteSecondaire)
                    TextField("Nom du joueur", text: $joueur.nom)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: joueur.nom) { _, _ in onFrappe() }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Poste")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PaletteMat.texteSecondaire)
                    Picker("Poste", selection: $joueur.poste) {
                        Text("Non défini").tag("")
                        ForEach(Self.postes, id: \.self) { p in
                            Text(p).tag(p)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.red)
                    .onChange(of: joueur.poste) { _, _ in onFrappe() }
                }
            }

            HStack(spacing: LiquidGlassKit.espaceMD) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Points forts", systemImage: "hand.thumbsup.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PaletteMat.vert)
                    TextEditor(text: $joueur.pointsForts)
                        .frame(minHeight: 60)
                        .scrollContentBackground(.hidden)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMini * 2, style: .continuous))
                        .onChange(of: joueur.pointsForts) { _, _ in onFrappe() }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label("Points faibles", systemImage: "hand.thumbsdown.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.red)
                    TextEditor(text: $joueur.pointsFaibles)
                        .frame(minHeight: 60)
                        .scrollContentBackground(.hidden)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMini * 2, style: .continuous))
                        .onChange(of: joueur.pointsFaibles) { _, _ in onFrappe() }
                }
            }

            HStack(spacing: LiquidGlassKit.espaceSM) {
                Text("Niveau de menace :")
                    .font(.subheadline.weight(.medium))
                EtoilesMenaceView(niveau: joueur.menaceNiveau) { nouveau in
                    joueur.menaceNiveau = nouveau
                    onChangementImmediat()
                }
            }
        }
    }
}
