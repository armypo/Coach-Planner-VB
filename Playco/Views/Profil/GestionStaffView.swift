//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "GestionStaff")

/// Gestion des permissions du staff — l'entraîneur-chef peut configurer
/// les permissions de chaque assistant individuellement.
struct GestionStaffView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Query private var tousAssistants: [AssistantCoach]
    @Query private var toutesPermissions: [StaffPermissions]

    private var assistants: [AssistantCoach] {
        tousAssistants.filtreEquipe(codeEquipeActif)
    }

    var body: some View {
        List {
            if assistants.isEmpty {
                ContentUnavailableView(
                    "Aucun assistant",
                    systemImage: "person.2.slash",
                    description: Text("Ajoutez des assistants depuis l'écran Organisation.")
                )
            } else {
                ForEach(assistants) { assistant in
                    Section {
                        carteAssistant(assistant)
                        permissionsToggles(pour: assistant)
                    }
                }
            }
        }
        .navigationTitle("Permissions du staff")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Carte assistant

    private func carteAssistant(_ assistant: AssistantCoach) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(PaletteMat.bleu.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(assistant.prenom.prefix(1)) + String(assistant.nom.prefix(1)))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PaletteMat.bleu)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("\(assistant.prenom) \(assistant.nom)")
                    .font(.subheadline.weight(.semibold))
                Text(assistant.roleAssistant.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Toggles permissions

    private func permissionsToggles(pour assistant: AssistantCoach) -> some View {
        let permissions = obtenirOuCreerPermissions(pour: assistant)
        return Group {
            togglePermission("Modifier les formations", icone: "person.3.fill",
                             valeur: Binding(
                                get: { permissions.peutModifierFormation },
                                set: { permissions.peutModifierFormation = $0; sauvegarder() }
                             ))
            togglePermission("Gérer les statistiques", icone: "chart.bar.fill",
                             valeur: Binding(
                                get: { permissions.peutGererStats },
                                set: { permissions.peutGererStats = $0; sauvegarder() }
                             ))
            togglePermission("Modifier le terrain", icone: "sportscourt.fill",
                             valeur: Binding(
                                get: { permissions.peutModifierTerrain },
                                set: { permissions.peutModifierTerrain = $0; sauvegarder() }
                             ))
            togglePermission("Gérer les joueurs", icone: "person.badge.plus",
                             valeur: Binding(
                                get: { permissions.peutGererJoueurs },
                                set: { permissions.peutGererJoueurs = $0; sauvegarder() }
                             ))
            togglePermission("Supprimer un match", icone: "trash",
                             valeur: Binding(
                                get: { permissions.peutSupprimerMatch },
                                set: { permissions.peutSupprimerMatch = $0; sauvegarder() }
                             ))
            togglePermission("Inviter du staff", icone: "person.badge.key",
                             valeur: Binding(
                                get: { permissions.peutInviterStaff },
                                set: { permissions.peutInviterStaff = $0; sauvegarder() }
                             ))
            togglePermission("Voir identifiants joueurs", icone: "eye",
                             valeur: Binding(
                                get: { permissions.peutVoirIdentifiantsJoueurs },
                                set: { permissions.peutVoirIdentifiantsJoueurs = $0; sauvegarder() }
                             ))
        }
    }

    private func togglePermission(_ titre: String, icone: String, valeur: Binding<Bool>) -> some View {
        Toggle(isOn: valeur) {
            Label(titre, systemImage: icone)
                .font(.subheadline)
        }
        .tint(PaletteMat.vert)
    }

    // MARK: - Gestion permissions

    private func obtenirOuCreerPermissions(pour assistant: AssistantCoach) -> StaffPermissions {
        let assistID = assistant.id
        if let existant = toutesPermissions.first(where: { $0.assistantID == assistID && $0.codeEquipe == codeEquipeActif }) {
            return existant
        }

        // Créer des permissions par défaut (tout activé)
        let nouvelles = StaffPermissions(assistantID: assistant.id, codeEquipe: codeEquipeActif)
        modelContext.insert(nouvelles)
        try? modelContext.save()
        logger.info("Permissions créées pour \(assistant.prenom) \(assistant.nom)")
        return nouvelles
    }

    private func sauvegarder() {
        try? modelContext.save()
    }
}
