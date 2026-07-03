//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import AuthenticationServices

/// Étape 3 — Profil du coach.
///
/// SIWA strict : la connexion du coach passe par Sign in with Apple — aucun
/// identifiant ni mot de passe saisi. `appleUserID` est capturé ici et
/// utilisé à la finalisation (création du compte + auto-login).
struct ConfigProfilCoachView: View {
    @Environment(AppleSignInService.self) private var appleSignIn

    @Binding var prenom: String
    @Binding var nom: String
    @Binding var courriel: String
    @Binding var telephone: String
    @Binding var role: RoleCoach
    @Binding var photo: Data?
    @Binding var appleUserID: String

    @State private var erreurApple: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                titreEtape(numero: 3, titre: "Votre profil",
                           description: "Ces informations identifient le coach principal de l'équipe.")

                // Photo (optionnelle)
                HStack {
                    Spacer()
                    ZStack {
                        if let photoData = photo, let img = UIImage(data: photoData) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 90, height: 90)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(PaletteMat.orange.opacity(0.12))
                                .frame(width: 90, height: 90)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 36))
                                        .foregroundStyle(PaletteMat.orange.opacity(0.5))
                                )
                        }
                    }
                    Spacer()
                }

                // Prénom + Nom
                HStack(spacing: 16) {
                    champTexte(label: "PRÉNOM", placeholder: "Christopher",
                               texte: $prenom, obligatoire: true)
                    champTexte(label: "NOM", placeholder: "Dionne",
                               texte: $nom, obligatoire: true)
                }

                // Courriel
                VStack(alignment: .leading, spacing: 6) {
                    Text("COURRIEL")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                    TextField("coach@garneau.ca", text: $courriel)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 12))
                }

                // Téléphone
                VStack(alignment: .leading, spacing: 6) {
                    Text("TÉLÉPHONE (optionnel)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                    TextField("(514) 555-0123", text: $telephone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 12))
                }

                // Rôle
                VStack(alignment: .leading, spacing: 6) {
                    Text("RÔLE")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                    Picker("Rôle", selection: $role) {
                        ForEach(RoleCoach.allCases, id: \.self) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(PaletteMat.orange)
                }

                Divider().padding(.vertical, 4)

                // MARK: - Connexion (Sign in with Apple)
                Text("CONNEXION")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PaletteMat.orange)
                    .tracking(0.8)

                if appleUserID.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SignInWithAppleButton(.signUp) { requete in
                            appleSignIn.configurerRequete(requete)
                        } onCompletion: { resultat in
                            traiterApple(resultat)
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        Text("Ton compte coach utilise Sign in with Apple — aucun mot de passe à retenir.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        if let erreurApple {
                            Text(erreurApple)
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Text("Compte Apple lié")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Button("Changer") {
                            appleUserID = ""
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(Color.green.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 12))
                }

                Spacer(minLength: 20)
            }
            .padding(.vertical, 24)
        }
    }

    /// Capture l'identité Apple et pré-remplit prénom/nom/courriel si Apple
    /// les fournit (uniquement à la toute première autorisation).
    private func traiterApple(_ resultat: Result<ASAuthorization, Error>) {
        erreurApple = nil
        guard let creds = appleSignIn.traiterResultat(resultat) else {
            erreurApple = "Connexion Apple impossible. Réessaie."
            return
        }
        appleUserID = creds.user
        if prenom.trimmingCharacters(in: .whitespaces).isEmpty, !creds.prenom.isEmpty {
            prenom = creds.prenom
        }
        if nom.trimmingCharacters(in: .whitespaces).isEmpty, !creds.nom.isEmpty {
            nom = creds.nom
        }
        if courriel.trimmingCharacters(in: .whitespaces).isEmpty, let email = creds.email {
            courriel = email
        }
    }
}
