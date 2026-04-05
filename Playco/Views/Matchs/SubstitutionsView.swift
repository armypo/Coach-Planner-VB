//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Module de gestion des substitutions en cours de match
struct SubstitutionsView: View {
    var viewModel: MatchLiveViewModel

    @Query(filter: #Predicate<JoueurEquipe> { $0.estActif == true },
           sort: \JoueurEquipe.numero) private var tousJoueurs: [JoueurEquipe]
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Environment(\.dismiss) private var dismiss

    @State private var joueurSortantID: UUID?
    @State private var joueurEntrantID: UUID?

    private var joueursEquipe: [JoueurEquipe] {
        tousJoueurs.filtreEquipe(codeEquipeActif)
    }

    /// Joueurs actuellement sur le terrain (6 + libéro éventuel)
    private var surTerrain: [JoueurSurTerrain] {
        viewModel.joueursActuellementSurTerrain
    }

    /// Joueurs sur le banc
    private var surLeBanc: [JoueurEquipe] {
        let surTerrainIDs = Set(surTerrain.map(\.joueurID))
        return joueursEquipe.filter { !surTerrainIDs.contains($0.id) }
    }

    /// Substitutions du set actuel
    private var subsSet: [SubstitutionRecord] {
        viewModel.seance.substitutions.filter { $0.set == viewModel.setActuel }
    }

    private var peutSubstituer: Bool {
        viewModel.subsUtiliseesDansSet < viewModel.subsMaxParSet &&
        joueurSortantID != nil && joueurEntrantID != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: LiquidGlassKit.espaceLG) {
                    // Compteur
                    compteur

                    // Sélection sortant / entrant
                    HStack(alignment: .top, spacing: LiquidGlassKit.espaceMD) {
                        sectionSortant
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                            .padding(.top, 40)
                        sectionEntrant
                    }

                    // Bouton confirmer
                    boutonConfirmer

                    // Historique du set
                    historique
                }
                .padding(LiquidGlassKit.espaceMD)
            }
            .navigationTitle("Substitutions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    // MARK: - Compteur

    private var compteur: some View {
        HStack(spacing: LiquidGlassKit.espaceMD) {
            VStack(spacing: 4) {
                Text("\(viewModel.subsUtiliseesDansSet)")
                    .font(.title.weight(.bold).monospacedDigit())
                    .foregroundStyle(.red)
                    .contentTransition(.numericText())
                Text("utilisées")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text("/")
                .font(.title2.weight(.light))
                .foregroundStyle(.tertiary)

            VStack(spacing: 4) {
                Text("\(viewModel.subsMaxParSet)")
                    .font(.title.weight(.bold).monospacedDigit())
                    .foregroundStyle(.primary)
                Text("maximum")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Set \(viewModel.setActuel)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(.tertiarySystemFill), in: Capsule())
        }
        .padding(LiquidGlassKit.espaceMD)
        .glassSection()
    }

    // MARK: - Joueur sortant

    private var sectionSortant: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Text("JOUEUR SORTANT")
                .font(.caption.weight(.bold))
                .foregroundStyle(.red)
                .tracking(0.5)

            ForEach(surTerrain.filter { !$0.estLibero }) { joueur in
                boutonJoueur(
                    numero: joueur.numero,
                    prenom: joueur.prenom,
                    nom: joueur.nom,
                    poste: "P\(joueur.poste)",
                    estSelectionne: joueurSortantID == joueur.joueurID,
                    couleur: .red
                ) {
                    joueurSortantID = joueurSortantID == joueur.joueurID ? nil : joueur.joueurID
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Joueur entrant

    private var sectionEntrant: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Text("JOUEUR ENTRANT")
                .font(.caption.weight(.bold))
                .foregroundStyle(.green)
                .tracking(0.5)

            if surLeBanc.isEmpty {
                Text("Aucun joueur sur le banc")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, LiquidGlassKit.espaceMD)
            } else {
                ForEach(surLeBanc) { joueur in
                    boutonJoueur(
                        numero: joueur.numero,
                        prenom: joueur.prenom,
                        nom: joueur.nom,
                        poste: joueur.poste.abreviation,
                        estSelectionne: joueurEntrantID == joueur.id,
                        couleur: .green
                    ) {
                        joueurEntrantID = joueurEntrantID == joueur.id ? nil : joueur.id
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func boutonJoueur(numero: Int, prenom: String, nom: String, poste: String, estSelectionne: Bool, couleur: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text("#\(numero)")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(prenom) \(nom)")
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                    Text(poste)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if estSelectionne {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(couleur)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                estSelectionne ? couleur.opacity(0.12) : Color(.tertiarySystemFill),
                in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit)
            )
            .overlay {
                RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit)
                    .strokeBorder(estSelectionne ? couleur.opacity(0.4) : .clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bouton confirmer

    private var boutonConfirmer: some View {
        Button {
            guard let sortantID = joueurSortantID,
                  let entrantID = joueurEntrantID else { return }

            withAnimation(LiquidGlassKit.springDefaut) {
                viewModel.effectuerSubstitution(sortantID: sortantID, entrantID: entrantID)
                joueurSortantID = nil
                joueurEntrantID = nil
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.subheadline)
                Text("Confirmer la substitution")
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(peutSubstituer ? Color.red : Color(.tertiarySystemFill),
                        in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMoyen))
            .foregroundStyle(peutSubstituer ? Color.white : Color.secondary)
        }
        .buttonStyle(.plain)
        .disabled(!peutSubstituer)
    }

    // MARK: - Historique

    private var historique: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Text("HISTORIQUE SET \(viewModel.setActuel)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            if subsSet.isEmpty {
                Text("Aucune substitution")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(subsSet) { sub in
                    let sortant = joueursEquipe.first(where: { $0.id == sub.joueurSortantID })
                    let entrant = joueursEquipe.first(where: { $0.id == sub.joueurEntrantID })

                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.red)

                        if let s = sortant {
                            Text("#\(s.numero)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.red)
                        }
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                        if let e = entrant {
                            Text("#\(e.numero)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.green)
                        }

                        Spacer()

                        Text("\(sub.scoreNousAuMoment)-\(sub.scoreAdvAuMoment)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)

                        Text(sub.horodatage.formatHeure())
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(LiquidGlassKit.espaceMD)
        .glassSection()
    }
}
