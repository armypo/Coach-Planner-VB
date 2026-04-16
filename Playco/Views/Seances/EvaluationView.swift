//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "Evaluation")

/// Vue pour évaluer les joueurs après une séance (coach seulement)
struct EvaluationView: View {
    let seance: Seance

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Query(sort: \JoueurEquipe.nom) private var joueurs: [JoueurEquipe]
    @Query(sort: \Evaluation.dateEvaluation) private var toutesEvals: [Evaluation]
    @Query(sort: \Presence.dateMarquee) private var toutesPresences: [Presence]

    private var joueursEquipe: [JoueurEquipe] {
        joueurs.filtreEquipe(codeEquipeActif)
    }

    private var evalsCetteSeance: [Evaluation] {
        toutesEvals.filter { $0.seanceID == seance.id }
    }

    /// Joueurs présents à cette séance (ou tous si pas de présences enregistrées)
    private var joueursAEvaluer: [JoueurEquipe] {
        let presences = toutesPresences.filter { $0.seanceID == seance.id && $0.estPresent }
        if presences.isEmpty {
            return joueursEquipe.filter(\.estActif)
        }
        let idsPresents = Set(presences.map(\.joueurID))
        return joueursEquipe.filter { $0.estActif && idsPresents.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // En-tête
                VStack(spacing: 4) {
                    Text(seance.nom)
                        .font(.headline)
                    Text(seance.date.formatFrancais())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGroupedBackground))

                Divider()

                if joueursAEvaluer.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "star")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                        Text("Aucun joueur à évaluer")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(joueursAEvaluer) { joueur in
                                carteEvaluation(joueur: joueur)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Évaluation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    // MARK: - Carte évaluation par joueur

    private func carteEvaluation(joueur: JoueurEquipe) -> some View {
        let eval = evalsCetteSeance.first(where: { $0.joueurID == joueur.id })

        return VStack(alignment: .leading, spacing: 12) {
            // En-tête joueur
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(joueur.poste.couleur.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Text(joueur.poste.abreviation)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(joueur.poste.couleur)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(joueur.nomComplet)
                        .font(.subheadline.weight(.semibold))
                    Text("#\(joueur.numero) · \(joueur.poste.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Moyenne
                if let eval, eval.moyenneGenerale > 0 {
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f", eval.moyenneGenerale))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.orange)
                        Text("/5")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Notes étoiles
            VStack(spacing: 8) {
                ligneEtoiles(label: "Effort", note: eval?.noteEffort ?? 0) { note in
                    modifierNote(joueur: joueur, critere: .effort, note: note)
                }
                ligneEtoiles(label: "Technique", note: eval?.noteTechnique ?? 0) { note in
                    modifierNote(joueur: joueur, critere: .technique, note: note)
                }
                ligneEtoiles(label: "Attitude", note: eval?.noteAttitude ?? 0) { note in
                    modifierNote(joueur: joueur, critere: .attitude, note: note)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
    }

    private func ligneEtoiles(label: String, note: Int, onTap: @escaping (Int) -> Void) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { etoile in
                    Button {
                        onTap(etoile == note ? 0 : etoile) // re-taper = enlever
                    } label: {
                        Image(systemName: etoile <= note ? "star.fill" : "star")
                            .font(.system(size: 20))
                            .foregroundStyle(etoile <= note ? .orange : Color(.systemGray4))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Actions

    private enum Critere { case effort, technique, attitude }

    private func modifierNote(joueur: JoueurEquipe, critere: Critere, note: Int) {
        let eval: Evaluation
        if let existing = evalsCetteSeance.first(where: { $0.joueurID == joueur.id }) {
            eval = existing
        } else {
            eval = Evaluation(
                joueurID: joueur.id,
                seanceID: seance.id,
                seanceNom: seance.nom,
                joueurPrenom: joueur.prenom,
                joueurNom: joueur.nom
            )
            modelContext.insert(eval)
        }

        switch critere {
        case .effort: eval.noteEffort = note
        case .technique: eval.noteTechnique = note
        case .attitude: eval.noteAttitude = note
        }

        do {
            try modelContext.save()
        } catch {
            logger.error("Erreur sauvegarde évaluation joueur: \(error.localizedDescription)")
        }
    }
}
