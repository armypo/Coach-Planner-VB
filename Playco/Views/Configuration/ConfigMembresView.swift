//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Étape 5 — Ajouter assistants et joueurs
struct ConfigMembresView: View {
    @Binding var assistants: [AssistantTemp]
    @Binding var joueurs: [JoueurTemp]

    @Environment(\.modelContext) private var modelContext

    @State private var onglet: Int = 0 // 0 = joueurs, 1 = assistants

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                titreEtape(numero: 5, titre: "Membres de l'équipe",
                           description: "Ajoutez vos joueurs et assistants. Chacun recevra un identifiant de connexion. Vous pourrez aussi en ajouter plus tard.")

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
                let j = JoueurTemp()
                joueurs.append(j)
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
                TextField("Nom", text: joueur.nom)
                    .padding(10)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
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

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Identifiant")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    champMonospaceAvecDice(
                        valeur: joueur.wrappedValue.identifiant,
                        placeholder: "auto",
                        onRegenerer: {
                            joueur.wrappedValue.identifiant = Utilisateur.genererIdentifiantUnique(
                                prenom: joueur.wrappedValue.prenom,
                                nom: joueur.wrappedValue.nom,
                                context: modelContext
                            )
                        }
                    )
                    .onChange(of: joueur.wrappedValue.prenom) { autoIdJoueur(joueur: joueur) }
                    .onChange(of: joueur.wrappedValue.nom) { autoIdJoueur(joueur: joueur) }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mot de passe (auto-généré)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    champMonospaceAvecDice(
                        valeur: joueur.wrappedValue.motDePasse,
                        placeholder: "auto",
                        onRegenerer: {
                            joueur.wrappedValue.motDePasse = Utilisateur.genererMotDePasseAthlete()
                        }
                    )
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    /// Génère un identifiant `prenom.nom.XXXX` tant que l'utilisateur n'a pas
    /// personnalisé le champ lui-même (= vide).
    private func autoIdJoueur(joueur: Binding<JoueurTemp>) {
        let j = joueur.wrappedValue
        guard j.identifiant.isEmpty,
              !j.prenom.trimmingCharacters(in: .whitespaces).isEmpty,
              !j.nom.trimmingCharacters(in: .whitespaces).isEmpty
        else { return }
        joueur.wrappedValue.identifiant = Utilisateur.genererIdentifiantUnique(
            prenom: j.prenom,
            nom: j.nom,
            context: modelContext
        )
    }

    /// Champ monospace read-only (placeholder si vide) avec bouton dé pour régénérer.
    private func champMonospaceAvecDice(
        valeur: String,
        placeholder: String,
        onRegenerer: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 6) {
            Text(valeur.isEmpty ? placeholder : valeur)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(valeur.isEmpty ? .tertiary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.middle)
            Button {
                onRegenerer()
            } label: {
                Image(systemName: "dice")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
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
                TextField("Nom", text: assistant.nom)
                    .padding(10)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
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

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Identifiant")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    champMonospaceAvecDice(
                        valeur: assistant.wrappedValue.identifiant,
                        placeholder: "auto",
                        onRegenerer: {
                            assistant.wrappedValue.identifiant = Utilisateur.genererIdentifiantUnique(
                                prenom: assistant.wrappedValue.prenom,
                                nom: assistant.wrappedValue.nom,
                                context: modelContext
                            )
                        }
                    )
                    .onChange(of: assistant.wrappedValue.prenom) { autoIdAssistant(assistant: assistant) }
                    .onChange(of: assistant.wrappedValue.nom) { autoIdAssistant(assistant: assistant) }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mot de passe (auto-généré)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    champMonospaceAvecDice(
                        valeur: assistant.wrappedValue.motDePasse,
                        placeholder: "auto",
                        onRegenerer: {
                            assistant.wrappedValue.motDePasse = Utilisateur.genererMotDePasseAthlete()
                        }
                    )
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func autoIdAssistant(assistant: Binding<AssistantTemp>) {
        let a = assistant.wrappedValue
        guard a.identifiant.isEmpty,
              !a.prenom.trimmingCharacters(in: .whitespaces).isEmpty,
              !a.nom.trimmingCharacters(in: .whitespaces).isEmpty
        else { return }
        assistant.wrappedValue.identifiant = Utilisateur.genererIdentifiantUnique(
            prenom: a.prenom,
            nom: a.nom,
            context: modelContext
        )
    }
}
