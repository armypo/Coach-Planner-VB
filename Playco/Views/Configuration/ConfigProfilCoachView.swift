//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI

/// Étape 3 — Profil du coach
struct ConfigProfilCoachView: View {
    @Binding var prenom: String
    @Binding var nom: String
    @Binding var courriel: String
    @Binding var telephone: String
    @Binding var role: RoleCoach
    @Binding var photo: Data?
    @Binding var identifiant: String
    @Binding var motDePasse: String
    @Binding var confirmerMotDePasse: String

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

                // MARK: - Identifiants
                Text("IDENTIFIANTS DE CONNEXION")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PaletteMat.orange)
                    .tracking(0.8)

                // Code école (identifiant)
                VStack(alignment: .leading, spacing: 6) {
                    Text("CODE ÉCOLE (identifiant) *")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                    TextField("ex : christopher.dionne", text: $identifiant)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(identifiant.trimmingCharacters(in: .whitespaces).isEmpty ? Color.clear : .green.opacity(0.4), lineWidth: 1)
                        )
                    Text("Cet identifiant servira à vous connecter à l'application.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .onChange(of: prenom) { genererIdentifiant() }
                .onChange(of: nom) { genererIdentifiant() }

                // Mot de passe
                VStack(alignment: .leading, spacing: 6) {
                    Text("MOT DE PASSE *")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                    SecureField("Minimum 6 caractères", text: $motDePasse)
                        .textContentType(.newPassword)
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(motDePasse.count >= 6 ? .green.opacity(0.4) : Color.clear, lineWidth: 1)
                        )
                    if !motDePasse.isEmpty && motDePasse.count < 6 {
                        Text("Le mot de passe doit contenir au moins 6 caractères")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }

                // Confirmer mot de passe
                VStack(alignment: .leading, spacing: 6) {
                    Text("CONFIRMER LE MOT DE PASSE *")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                    SecureField("Retapez le mot de passe", text: $confirmerMotDePasse)
                        .textContentType(.newPassword)
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    !confirmerMotDePasse.isEmpty && confirmerMotDePasse == motDePasse
                                        ? .green.opacity(0.4) : Color.clear,
                                    lineWidth: 1
                                )
                        )
                    if !confirmerMotDePasse.isEmpty && confirmerMotDePasse != motDePasse {
                        Text("Les mots de passe ne correspondent pas")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(.vertical, 24)
        }
    }

    /// Auto-génère l'identifiant depuis prénom.nom (sans accents, minuscules)
    private func genererIdentifiant() {
        // Ne pas écraser si l'utilisateur a modifié manuellement
        let p = prenom.trimmingCharacters(in: .whitespaces)
        let n = nom.trimmingCharacters(in: .whitespaces)
        guard !p.isEmpty || !n.isEmpty else { return }

        let candidat = "\(p).\(n)"
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0 == "." || $0 == "-" }

        // Ne mettre à jour que si l'identifiant est vide ou correspond au format auto-généré
        if identifiant.isEmpty || identifiant == candidat
            || identifiant == ancienIdentifiantAuto {
            identifiant = candidat
        }
        ancienIdentifiantAuto = candidat
    }

    @State private var ancienIdentifiantAuto = ""
}
