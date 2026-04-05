//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Vue pour cocher les présences des joueurs à une séance (coach seulement)
struct PresencesView: View {
    let seance: Seance

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Query(sort: \JoueurEquipe.nom) private var joueurs: [JoueurEquipe]
    @Query(sort: \Presence.dateMarquee) private var toutesPresences: [Presence]

    private var presencesCetteSeance: [Presence] {
        toutesPresences.filter { $0.seanceID == seance.id }
    }

    private var joueursActifs: [JoueurEquipe] {
        joueurs.filtreEquipe(codeEquipeActif).filter(\.estActif)
    }

    private func estPresent(_ joueur: JoueurEquipe) -> Bool {
        presencesCetteSeance.first(where: { $0.joueurID == joueur.id })?.estPresent ?? false
    }

    private var nbPresents: Int {
        presencesCetteSeance.filter(\.estPresent).count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Résumé
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(seance.nom)
                            .font(.headline)
                        Text(seance.date.formatFrancais())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack {
                        Text("\(nbPresents)/\(joueursActifs.count)")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.orange)
                        Text("Présents")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .background(Color(.systemGroupedBackground))

                Divider()

                // Liste des joueurs
                if joueursActifs.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "person.3")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                        Text("Aucun joueur dans l'équipe")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Ajoutez des joueurs dans la section Équipe.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(joueursActifs) { joueur in
                            let present = estPresent(joueur)
                            HStack(spacing: 14) {
                                // Avatar
                                ZStack {
                                    Circle()
                                        .fill(joueur.poste.couleur.opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    Text(joueur.poste.abreviation)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(joueur.poste.couleur)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(joueur.nomComplet)
                                        .font(.subheadline.weight(.medium))
                                    Text("#\(joueur.numero) · \(joueur.poste.rawValue)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                // Toggle présence
                                Button {
                                    togglePresence(joueur: joueur)
                                } label: {
                                    Image(systemName: present ? "checkmark.circle.fill" : "circle")
                                        .font(.title2)
                                        .foregroundStyle(present ? .green : .secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listStyle(.plain)
                }

                // Boutons tout cocher/décocher
                HStack(spacing: 16) {
                    Button {
                        marquerTous(present: true)
                    } label: {
                        Label("Tous présents", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.green)
                    }

                    Button {
                        marquerTous(present: false)
                    } label: {
                        Label("Tout effacer", systemImage: "xmark.circle")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Présences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private func togglePresence(joueur: JoueurEquipe) {
        if let existing = presencesCetteSeance.first(where: { $0.joueurID == joueur.id }) {
            existing.estPresent.toggle()
        } else {
            let presence = Presence(
                joueurID: joueur.id,
                seanceID: seance.id,
                estPresent: true,
                joueurPrenom: joueur.prenom,
                joueurNom: joueur.nom
            )
            modelContext.insert(presence)
        }
        try? modelContext.save()
    }

    private func marquerTous(present: Bool) {
        for joueur in joueursActifs {
            if let existing = presencesCetteSeance.first(where: { $0.joueurID == joueur.id }) {
                existing.estPresent = present
            } else if present {
                let p = Presence(
                    joueurID: joueur.id,
                    seanceID: seance.id,
                    estPresent: true,
                    joueurPrenom: joueur.prenom,
                    joueurNom: joueur.nom
                )
                modelContext.insert(p)
            }
        }
        try? modelContext.save()
    }
}
