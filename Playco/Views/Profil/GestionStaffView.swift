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

    /// Descripteur d'une permission affichable (libellé + icône + accès au flag)
    private struct PermissionStaff {
        let titre: String
        let icone: String
        let keyPath: ReferenceWritableKeyPath<StaffPermissions, Bool>
    }

    private static let permissionsDisponibles: [PermissionStaff] = [
        .init(titre: "Modifier les formations", icone: "person.3.fill", keyPath: \.peutModifierFormation),
        .init(titre: "Gérer les statistiques", icone: "chart.bar.fill", keyPath: \.peutGererStats),
        .init(titre: "Modifier le terrain", icone: "sportscourt.fill", keyPath: \.peutModifierTerrain),
        .init(titre: "Gérer les joueurs", icone: "person.badge.plus", keyPath: \.peutGererJoueurs),
        .init(titre: "Supprimer un match", icone: "trash", keyPath: \.peutSupprimerMatch),
        .init(titre: "Inviter du staff", icone: "person.badge.key", keyPath: \.peutInviterStaff),
        .init(titre: "Voir identifiants joueurs", icone: "eye", keyPath: \.peutVoirIdentifiantsJoueurs)
    ]

    private func permissionsToggles(pour assistant: AssistantCoach) -> some View {
        let permissions = obtenirOuCreerPermissions(pour: assistant)
        return ForEach(Self.permissionsDisponibles, id: \.titre) { permission in
            togglePermission(permission.titre, icone: permission.icone,
                             valeur: Binding(
                                get: { permissions[keyPath: permission.keyPath] },
                                set: { permissions[keyPath: permission.keyPath] = $0; sauvegarder() }
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
