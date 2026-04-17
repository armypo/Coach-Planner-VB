//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "RejoindreEquipe")

/// Rejoindre une équipe avec identifiants créés par le coach
struct RejoindreEquipeView: View {
    var onRetour: () -> Void
    var onConnecte: () -> Void

    @Environment(AuthService.self) private var authService
    @Environment(CloudKitSharingService.self) private var sharingService
    @Environment(\.modelContext) private var modelContext

    @State private var codeEquipe = ""
    @State private var identifiant = ""
    @State private var motDePasse = ""
    @State private var afficherMotDePasse = false
    @State private var chargementCloud = false
    @State private var erreurLocale: String?

    private var formulaireValide: Bool {
        !codeEquipe.trimmingCharacters(in: .whitespaces).isEmpty &&
        !identifiant.trimmingCharacters(in: .whitespaces).isEmpty &&
        !motDePasse.isEmpty
    }

    private var enChargement: Bool {
        chargementCloud || authService.chargement
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)

                    VStack(spacing: 28) {
                        // En-tête
                        VStack(spacing: 10) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 40))
                                .foregroundStyle(PaletteMat.bleu)

                            Text("Rejoindre une équipe")
                                .font(.title2.weight(.bold))

                            Text("Entrez les identifiants fournis par votre coach.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        // Formulaire
                        VStack(spacing: 16) {
                            // Code équipe
                            VStack(alignment: .leading, spacing: 6) {
                                Text("CODE ÉQUIPE")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .tracking(0.5)
                                HStack(spacing: 12) {
                                    Image(systemName: "number.circle.fill")
                                        .foregroundStyle(PaletteMat.orange)
                                        .frame(width: 20)
                                    TextField("ABCD2345", text: $codeEquipe)
                                        .textInputAutocapitalization(.characters)
                                        .autocorrectionDisabled()
                                        .onChange(of: codeEquipe) { _, nouveau in
                                            // Filtre alphabet + uppercase + max 8 car
                                            let normalise = Equipe.normaliserCodeEquipe(nouveau)
                                            let tronque = String(normalise.prefix(8))
                                            if tronque != nouveau {
                                                codeEquipe = tronque
                                            }
                                        }
                                }
                                .padding(14)
                                .background(Color(.systemGray6).opacity(0.6),
                                            in: RoundedRectangle(cornerRadius: 12))
                            }

                            // Identifiant
                            VStack(alignment: .leading, spacing: 6) {
                                Text("IDENTIFIANT")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .tracking(0.5)
                                HStack(spacing: 12) {
                                    Image(systemName: "person.text.rectangle.fill")
                                        .foregroundStyle(PaletteMat.bleu)
                                        .frame(width: 20)
                                    TextField("prenom.nom", text: $identifiant)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .textContentType(.username)
                                }
                                .padding(14)
                                .background(Color(.systemGray6).opacity(0.6),
                                            in: RoundedRectangle(cornerRadius: 12))
                            }

                            // Mot de passe
                            VStack(alignment: .leading, spacing: 6) {
                                Text("MOT DE PASSE")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .tracking(0.5)
                                HStack(spacing: 12) {
                                    Image(systemName: "lock.fill")
                                        .foregroundStyle(PaletteMat.vert)
                                        .frame(width: 20)
                                    if afficherMotDePasse {
                                        TextField("Mot de passe", text: $motDePasse)
                                    } else {
                                        SecureField("Mot de passe", text: $motDePasse)
                                    }
                                    Button {
                                        afficherMotDePasse.toggle()
                                    } label: {
                                        Image(systemName: afficherMotDePasse ? "eye.slash.fill" : "eye.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(14)
                                .background(Color(.systemGray6).opacity(0.6),
                                            in: RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        // Erreur
                        if let erreur = erreurLocale ?? authService.erreur {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(erreur)
                            }
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(.red, in: RoundedRectangle(cornerRadius: 10))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Bouton connexion
                        Button {
                            Task { await seConnecter() }
                        } label: {
                            HStack(spacing: 8) {
                                if enChargement {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                    Text("Se connecter")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                formulaireValide ? PaletteMat.bleu : Color.gray.opacity(0.4),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                            .foregroundStyle(.white)
                        }
                        .disabled(!formulaireValide || enChargement)

                        // Bouton retour
                        Button {
                            authService.erreur = nil
                            onRetour()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                Text("Retour")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 36)
                    .glassCard(cornerRadius: 24)
                    .frame(maxWidth: 420)

                    Spacer().frame(height: 60)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func seConnecter() async {
        let codeNormalise = Equipe.normaliserCodeEquipe(codeEquipe.trimmingCharacters(in: .whitespaces))
        let idNormalise = identifiant.lowercased().trimmingCharacters(in: .whitespaces)
        erreurLocale = nil
        authService.erreur = nil

        // Validation locale avant toute requête réseau
        guard !codeNormalise.isEmpty, !idNormalise.isEmpty, !motDePasse.isEmpty else {
            erreurLocale = "Veuillez remplir tous les champs."
            return
        }
        guard Equipe.codeEquipeValide(codeNormalise) else {
            erreurLocale = "Code équipe invalide. Format attendu : 8 caractères (lettres + chiffres)."
            return
        }

        // 1. Récupérer les données depuis le CloudKit public DB
        chargementCloud = true
        do {
            // Vérifier d'abord si l'équipe existe dans le cloud
            let existe = await sharingService.equipeExiste(codeEquipe: codeNormalise)
            guard existe else {
                chargementCloud = false
                erreurLocale = "Code équipe invalide. Vérifiez auprès de votre coach."
                return
            }

            // Importer toutes les données de l'équipe localement
            try await sharingService.recupererEtImporterEquipe(
                codeEquipe: codeNormalise,
                context: modelContext
            )
            logger.info("Données équipe \(codeNormalise, privacy: .private) importées depuis CloudKit")
        } catch {
            chargementCloud = false
            logger.error("Erreur récupération équipe: \(error.localizedDescription)")
            erreurLocale = "Impossible de récupérer l'équipe. Vérifiez votre connexion internet."
            return
        }
        chargementCloud = false

        // 2. Maintenant les données existent localement → connexion
        authService.connexion(
            identifiant: identifiant,
            motDePasse: motDePasse,
            context: modelContext
        )

        // 3. Si connexion réussie → vérifier que l'utilisateur appartient à cette équipe
        if authService.estConnecte {
            guard let utilisateur = authService.utilisateurConnecte else {
                authService.deconnexion()
                erreurLocale = "Erreur de connexion. Veuillez réessayer."
                return
            }

            if let joueurID = utilisateur.joueurEquipeID {
                let descripteurJoueur = FetchDescriptor<JoueurEquipe>(
                    predicate: #Predicate { $0.id == joueurID && $0.codeEquipe == codeNormalise }
                )
                let joueurTrouve = (try? modelContext.fetch(descripteurJoueur).first) != nil

                if !joueurTrouve {
                    authService.deconnexion()
                    erreurLocale = "Votre compte n'est pas associé à cette équipe."
                    return
                }
            } else {
                let codeUtilisateur = utilisateur.codeEcole
                if !codeUtilisateur.isEmpty && codeUtilisateur != codeNormalise {
                    authService.deconnexion()
                    erreurLocale = "Votre compte n'est pas associé à cette équipe."
                    return
                }
            }

            // Créer ProfilCoach minimal pour marquer config terminée
            let profils = (try? modelContext.fetch(FetchDescriptor<ProfilCoach>())) ?? []
            if profils.isEmpty {
                let profil = ProfilCoach()
                profil.prenom = utilisateur.prenom
                profil.nom = utilisateur.nom
                profil.configurationCompletee = true
                modelContext.insert(profil)
                try? modelContext.save()
            }
            onConnecte()
        }
    }
}
