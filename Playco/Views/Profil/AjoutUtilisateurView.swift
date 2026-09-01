//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "AjoutUtilisateur")

/// Ajout d'un ASSISTANT coach (accessible par le coach/admin).
/// Pivot coach-first : les athlètes ne sont plus des utilisateurs — cette vue
/// ne crée plus que des membres du staff (`.assistantCoach`, mêmes droits que
/// le head coach). Le rôle Coach n'est pas proposé : la jointure SIWA
/// (`roleJonctionAutorise`) le rejetterait.
struct AjoutUtilisateurView: View {
    let codeEquipe: String

    @Environment(AuthService.self) private var authService
    @Environment(CloudKitSharingService.self) private var sharingService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var prenom = ""
    @State private var nom = ""
    @State private var identifiant = ""
    @State private var erreur: String?
    @State private var succes = false

    // Sheet récap (code d'invitation)
    @State private var afficherRecap = false
    @State private var credACopier: [CredentialRecap] = []

    private let couleur = PaletteMat.bleu

    private var formulaireValide: Bool {
        // SIWA strict : aucun mot de passe — connexion par Sign in with Apple
        // + code d'invitation.
        !prenom.trimmingCharacters(in: .whitespaces).isEmpty &&
            !nom.trimmingCharacters(in: .whitespaces).isEmpty &&
            !identifiant.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Icône
                    ZStack {
                        Circle()
                            .fill(couleur.opacity(0.08))
                            .frame(width: 70, height: 70)
                            .overlay(
                                Circle()
                                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                            )

                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 30))
                            .foregroundStyle(couleur)
                    }

                    // Formulaire
                    VStack(spacing: 14) {
                        champFormulaire(icone: "person.fill", label: "Prénom", texte: $prenom)
                        champFormulaire(icone: "person.fill", label: "Nom", texte: $nom)

                        VStack(alignment: .leading, spacing: 6) {
                                Text("Identifiant")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)

                                HStack(spacing: 12) {
                                    Image(systemName: "person.text.rectangle.fill")
                                        .foregroundStyle(couleur)
                                        .frame(width: 20)

                                    TextField("Ex: A3F9K2", text: $identifiant)
                                        .textInputAutocapitalization(.characters)
                                        .autocorrectionDisabled()

                                    Button {
                                        identifiant = genererCode()
                                    } label: {
                                        Image(systemName: "dice.fill")
                                            .foregroundStyle(couleur)
                                    }
                                }
                                .padding(14)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                            }

                            // Connexion via Sign in with Apple + code d'invitation.
                            // Aucun mot de passe — le code s'affiche après la création.
                            HStack(spacing: 8) {
                                Image(systemName: "ticket.fill")
                                    .foregroundStyle(couleur)
                                Text("Un code d'invitation sera généré pour rejoindre l'équipe avec Sign in with Apple.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(couleur.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                            // Info code équipe
                            HStack(spacing: 8) {
                                Image(systemName: "building.2.fill")
                                    .foregroundStyle(.secondary)
                                Text("Équipe : \(codeEquipe)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                    }

                    // Erreur
                    if let erreur {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(erreur)
                        }
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 10).fill(.red))
                    }

                    // Succès
                    if succes {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Compte créé avec succès !")
                        }
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 10).fill(.green))
                    }

                    // Bouton créer
                    Button {
                        creerCompte()
                    } label: {
                        Text("Créer le compte")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(formulaireValide ? couleur : Color.gray.opacity(0.4))
                            )
                            .foregroundStyle(.white)
                    }
                    .disabled(!formulaireValide)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .navigationTitle("Nouvel assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .onChange(of: prenom) { autoRefreshIdentifiant() }
            .onChange(of: nom) { autoRefreshIdentifiant() }
            .sheet(isPresented: $afficherRecap) {
                IdentifiantsRecapSheet(creds: credACopier) {
                    afficherRecap = false
                    dismiss()
                }
                .interactiveDismissDisabled(true)
            }
        }
    }

    private func champFormulaire(icone: String, label: String, texte: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 12) {
                Image(systemName: icone)
                    .foregroundStyle(couleur)
                    .frame(width: 20)

                TextField(label, text: texte)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
        }
    }

    /// Auto-régénère l'identifiant au format `prenom.nom.XXXX` dès que
    /// prénom+nom sont saisis.
    private func autoRefreshIdentifiant() {
        guard !prenom.trimmingCharacters(in: .whitespaces).isEmpty,
              !nom.trimmingCharacters(in: .whitespaces).isEmpty
        else { return }
        identifiant = Utilisateur.genererIdentifiantUnique(
            prenom: prenom, nom: nom, context: modelContext
        )
    }

    private func creerCompte() {
        erreur = nil
        succes = false

        guard let idFinal = validerEtNormaliserIdentifiant() else { return }

        // SIWA strict : création sans mot de passe (Utilisateur + CredentialAthlete)
        let membre = MembreFactory.creerMembre(
            prenom: prenom, nom: nom,
            role: .assistantCoach, codeEquipe: codeEquipe,
            identifiantSouhaite: idFinal,
            context: modelContext
        )

        do {
            try modelContext.save()
        } catch {
            annulerInsertion(membre: membre)
            logger.error("Échec de sauvegarde à la création du membre: \(error.localizedDescription)")
            self.erreur = "Erreur lors de la création du compte. Veuillez réessayer."
            return
        }

        publierMembre(membre.utilisateur)

        succes = true

        // Afficher le sheet récap (code d'invitation) — SIWA strict : c'est
        // l'unique moyen de connexion du nouveau membre.
        credACopier = [membre.recap]
        afficherRecap = true
    }

    /// Normalise l'identifiant saisi (ou en génère un si vide) et vérifie
    /// l'unicité. Retourne nil (et renseigne `erreur`) si invalide.
    private func validerEtNormaliserIdentifiant() -> String? {
        let idFinal = identifiant.trimmingCharacters(in: .whitespaces).isEmpty
            ? Utilisateur.genererIdentifiantUnique(prenom: prenom, nom: nom, context: modelContext)
            : identifiant.lowercased().trimmingCharacters(in: .whitespaces)

        guard idFinal.count >= 3 else {
            erreur = "L'identifiant doit contenir au moins 3 caractères."
            return nil
        }
        let idRechercheUnicite = idFinal
        let descUnicite = FetchDescriptor<Utilisateur>(
            predicate: #Predicate { $0.identifiant == idRechercheUnicite }
        )
        if (try? modelContext.fetch(descUnicite).first) != nil {
            erreur = "Cet identifiant existe déjà."
            return nil
        }
        return idFinal
    }

    /// Rollback : retire du contexte les entités insérées par cette création.
    private func annulerInsertion(membre: MembreFactory.Membre) {
        modelContext.delete(membre.credential)
        modelContext.delete(membre.utilisateur)
    }

    /// Publie le nouveau membre vers la Public DB CloudKit (asynchrone, ne bloque pas).
    private func publierMembre(_ utilisateur: Utilisateur) {
        let codeEquipePub = codeEquipe
        Task {
            await sharingService.publierNouvelUtilisateur(utilisateur, joueur: nil, codeEquipe: codeEquipePub)
        }
    }

    /// Génère un code aléatoire de 6 caractères (lettres + chiffres)
    private func genererCode() -> String {
        let caracteres = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).compactMap { _ in caracteres.randomElement() })
    }

}
