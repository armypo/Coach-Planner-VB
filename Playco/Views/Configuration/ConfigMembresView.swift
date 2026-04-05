//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI

/// Étape 5 — Ajouter assistants et joueurs
struct ConfigMembresView: View {
    @Binding var assistants: [AssistantTemp]
    @Binding var joueurs: [JoueurTemp]

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
                    TextField("auto", text: joueur.identifiant)
                        .font(.caption)
                        .padding(8)
                        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                        .onChange(of: joueur.wrappedValue.prenom) { autoId(joueur: joueur) }
                        .onChange(of: joueur.wrappedValue.nom) { autoId(joueur: joueur) }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mot de passe (min 6 car.)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    SecureField("••••••", text: joueur.motDePasse)
                        .font(.caption)
                        .padding(8)
                        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func autoId(joueur: Binding<JoueurTemp>) {
        if joueur.wrappedValue.identifiant.isEmpty ||
           joueur.wrappedValue.identifiant == genererIdentifiant(prenom: "", nom: "") {
            joueur.wrappedValue.identifiant = genererIdentifiant(
                prenom: joueur.wrappedValue.prenom,
                nom: joueur.wrappedValue.nom
            )
        }
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
                    TextField("auto", text: assistant.identifiant)
                        .font(.caption)
                        .padding(8)
                        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                        .onChange(of: assistant.wrappedValue.prenom) {
                            if assistant.wrappedValue.identifiant.isEmpty {
                                assistant.wrappedValue.identifiant = genererIdentifiant(
                                    prenom: assistant.wrappedValue.prenom,
                                    nom: assistant.wrappedValue.nom
                                )
                            }
                        }
                        .onChange(of: assistant.wrappedValue.nom) {
                            if assistant.wrappedValue.identifiant.isEmpty {
                                assistant.wrappedValue.identifiant = genererIdentifiant(
                                    prenom: assistant.wrappedValue.prenom,
                                    nom: assistant.wrappedValue.nom
                                )
                            }
                        }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mot de passe (min 6 car.)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    SecureField("••••••", text: assistant.motDePasse)
                        .font(.caption)
                        .padding(8)
                        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
