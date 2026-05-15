//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Étape 5 — Ajouter assistants et joueurs.
/// Mdp athlètes/assistants auto-générés à la création (format `LLLLL_DD`).
/// Identifiants auto-générés au format `prenom.nom.XXXX`.
struct ConfigMembresView: View {
    @Binding var assistants: [AssistantTemp]
    @Binding var joueurs: [JoueurTemp]

    @Environment(\.modelContext) private var modelContext

    @State private var onglet: Int = 0 // 0 = joueurs, 1 = assistants

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                titreEtape(numero: 5, titre: "Membres de l'équipe",
                           description: "Identifiants et mots de passe sont générés automatiquement. Tu pourras les copier ou partager à la fin du wizard.")

                // Onglets
                Picker("Section", selection: $onglet) {
                    Text("Joueurs (\(joueurs.count))").tag(0)
                    Text("Assistants (\(assistants.count))").tag(1)
                }
                .pickerStyle(.segmented)

                if onglet == 0 {
                    sectionJoueurs
                } else {
                    sectionAssistants
                }

                Spacer(minLength: 20)
            }
            .padding(.vertical, 24)
        }
    }

    // MARK: - Joueurs

    private var sectionJoueurs: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach($joueurs) { $joueur in
                carteJoueur(joueur: $joueur)
            }
            .onDelete { joueurs.remove(atOffsets: $0) }

            Button {
                joueurs.append(JoueurTemp())
            } label: {
                Label("Ajouter un joueur", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PaletteMat.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(PaletteMat.orange.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func carteJoueur(joueur: Binding<JoueurTemp>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Joueur")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PaletteMat.orange)
                Spacer()
                Button {
                    joueurs.removeAll { $0.id == joueur.wrappedValue.id }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                TextField("Prénom", text: joueur.prenom)
                    .padding(10)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                    .onChange(of: joueur.wrappedValue.prenom) { autoIdJoueur(joueur: joueur) }
                TextField("Nom", text: joueur.nom)
                    .padding(10)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                    .onChange(of: joueur.wrappedValue.nom) { autoIdJoueur(joueur: joueur) }
            }

            HStack(spacing: 12) {
                Stepper("#\(joueur.wrappedValue.numero)", value: joueur.numero, in: 0...99)
                    .frame(maxWidth: 140)

                Picker("Poste", selection: joueur.poste) {
                    ForEach(PosteJoueur.allCases, id: \.self) { p in
                        Text(p.abreviation).tag(p)
                    }
                }
                .pickerStyle(.segmented)
            }

            credentialAffichage(
                identifiant: joueur.wrappedValue.identifiant,
                motDePasse: joueur.wrappedValue.motDePasse,
                onRegenerer: {
                    joueur.wrappedValue.motDePasse = Utilisateur.genererMotDePasseAthlete()
                }
            )
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    /// Met à jour l'identifiant via `Utilisateur.genererIdentifiantUnique`
    /// dès que prénom+nom sont renseignés.
    private func autoIdJoueur(joueur: Binding<JoueurTemp>) {
        let p = joueur.wrappedValue.prenom
        let n = joueur.wrappedValue.nom
        guard !p.isEmpty, !n.isEmpty else { return }
        let exclusions = Set(joueurs.map { $0.identifiant } + assistants.map { $0.identifiant })
        joueur.wrappedValue.identifiant = Utilisateur.genererIdentifiantUnique(
            prenom: p, nom: n, context: modelContext, exclusions: exclusions
        )
    }

    // MARK: - Assistants

    private var sectionAssistants: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach($assistants) { $assistant in
                carteAssistant(assistant: $assistant)
            }

            Button {
                assistants.append(AssistantTemp())
            } label: {
                Label("Ajouter un assistant", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PaletteMat.bleu)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(PaletteMat.bleu.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func carteAssistant(assistant: Binding<AssistantTemp>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(assistant.wrappedValue.role.rawValue)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PaletteMat.bleu)
                Spacer()
                Button {
                    assistants.removeAll { $0.id == assistant.wrappedValue.id }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                TextField("Prénom", text: assistant.prenom)
                    .padding(10)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                    .onChange(of: assistant.wrappedValue.prenom) { autoIdAssistant(assistant: assistant) }
                TextField("Nom", text: assistant.nom)
                    .padding(10)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                    .onChange(of: assistant.wrappedValue.nom) { autoIdAssistant(assistant: assistant) }
            }

            HStack(spacing: 12) {
                TextField("Courriel", text: assistant.courriel)
                    .keyboardType(.emailAddress)
                    .padding(10)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))

                Picker("Rôle", selection: assistant.role) {
                    ForEach(RoleAssistant.allCases, id: \.self) { r in
                        Text(r.rawValue).tag(r)
                    }
                }
                .pickerStyle(.menu)
                .tint(PaletteMat.bleu)
            }

            credentialAffichage(
                identifiant: assistant.wrappedValue.identifiant,
                motDePasse: assistant.wrappedValue.motDePasse,
                onRegenerer: {
                    assistant.wrappedValue.motDePasse = Utilisateur.genererMotDePasseAthlete()
                }
            )
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func autoIdAssistant(assistant: Binding<AssistantTemp>) {
        let p = assistant.wrappedValue.prenom
        let n = assistant.wrappedValue.nom
        guard !p.isEmpty, !n.isEmpty else { return }
        let exclusions = Set(joueurs.map { $0.identifiant } + assistants.map { $0.identifiant })
        assistant.wrappedValue.identifiant = Utilisateur.genererIdentifiantUnique(
            prenom: p, nom: n, context: modelContext, exclusions: exclusions
        )
    }

    // MARK: - Affichage des credentials générés

    /// Affichage monospace (read-only) de l'identifiant et du mdp auto-générés.
    /// Le coach peut régénérer le mdp via le bouton dice.
    private func credentialAffichage(
        identifiant: String,
        motDePasse: String,
        onRegenerer: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "person.text.rectangle")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text(identifiant.isEmpty ? "identifiant — auto" : identifiant)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(identifiant.isEmpty ? .tertiary : .secondary)
                Spacer()
            }
            HStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text(motDePasse)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    onRegenerer()
                } label: {
                    Image(systemName: "dice")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}
