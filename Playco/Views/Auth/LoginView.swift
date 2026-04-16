//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

struct LoginView: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.modelContext) private var modelContext

    @State private var identifiant = ""
    @State private var motDePasse = ""
    @State private var afficherMotDePasse = false
    @State private var categorieSelectionnee: CategorieLogin = .athlete

    private var couleurActive: Color {
        categorieSelectionnee.couleur
    }

    /// Catégories de connexion affichées sur le login
    enum CategorieLogin: String, CaseIterable {
        case coach
        case athlete

        var label: String {
            switch self {
            case .coach: return "Coach"
            case .athlete: return "Athlète"
            }
        }

        var icone: String {
            switch self {
            case .coach: return "figure.volleyball"
            case .athlete: return "figure.run"
            }
        }

        var couleur: Color {
            switch self {
            case .coach: return PaletteMat.bleu
            case .athlete: return PaletteMat.orange
            }
        }
    }

    private var formulaireValide: Bool {
        !identifiant.trimmingCharacters(in: .whitespaces).isEmpty &&
        !motDePasse.isEmpty
    }

    var body: some View {
        ZStack {
            fondDegrade
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 80)

                    VStack(spacing: 28) {
                        entete
                        selectionCategorie
                        formulaire
                        bandeauErreur
                        boutonConnexion
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 36)
                    .glassCard(cornerRadius: 24)
                    .frame(maxWidth: 420)

                    // Lien vers création d'équipe / rejoindre
                    Button {
                        NotificationCenter.default.post(name: .allerChoixInitial, object: nil)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 13))
                            Text("Créer ou rejoindre une équipe")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundStyle(couleurActive)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(couleurActive.opacity(0.2), lineWidth: 0.5)
                        }
                    }
                    .buttonStyle(GlassButtonStyle())
                    .padding(.top, 16)

                    Spacer().frame(height: 60)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Fond

    private var fondDegrade: some View {
        Color(.systemBackground)
            .overlay(
                couleurActive.opacity(0.04)
                    .ignoresSafeArea()
            )
            .animation(LiquidGlassKit.springDefaut, value: categorieSelectionnee)
    }

    // MARK: - En-tête

    private var entete: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "volleyball.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.orange)
                Text("Playco")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
            }

            Text("Connectez-vous pour continuer")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Sélection catégorie (Coach / Athlète)

    private var selectionCategorie: some View {
        HStack(spacing: 14) {
            ForEach(CategorieLogin.allCases, id: \.self) { categorie in
                let estSelectionne = categorieSelectionnee == categorie

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        categorieSelectionnee = categorie
                    }
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: categorie.icone)
                            .font(.system(size: 30))
                            .foregroundStyle(estSelectionne ? categorie.couleur : .gray)

                        Text(categorie.label)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(estSelectionne ? categorie.couleur : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(estSelectionne ? categorie.couleur.opacity(0.08) : Color(.systemGray6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(estSelectionne ? categorie.couleur.opacity(0.5) : .white.opacity(0.2), lineWidth: 0.5)
                    )
                    .overlay(alignment: .bottom) {
                        if estSelectionne {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(categorie.couleur)
                                .background(Circle().fill(Color(.systemBackground)).padding(-2))
                                .offset(y: 10)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
                .buttonStyle(.plain)
                .scaleEffect(estSelectionne ? 1.03 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: estSelectionne)
            }
        }
    }

    // MARK: - Formulaire

    private var formulaire: some View {
        VStack(spacing: 16) {
            // Champ Identifiant
            VStack(alignment: .leading, spacing: 6) {
                Text("Identifiant")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                HStack(spacing: 12) {
                    Image(systemName: "person.text.rectangle.fill")
                        .foregroundStyle(couleurActive)
                        .frame(width: 20)

                    TextField("prenom.nom", text: $identifiant)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.systemGray6).opacity(0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                )
            }

            // Champ Mot de passe
            VStack(alignment: .leading, spacing: 6) {
                Text("Mot de passe")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(PaletteMat.vert)
                        .frame(width: 20)

                    if afficherMotDePasse {
                        TextField("Mot de passe", text: $motDePasse)
                            .textContentType(.password)
                    } else {
                        SecureField("Mot de passe", text: $motDePasse)
                            .textContentType(.password)
                    }

                    Button {
                        afficherMotDePasse.toggle()
                    } label: {
                        Image(systemName: afficherMotDePasse ? "eye.slash.fill" : "eye.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.systemGray6).opacity(0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                )
            }
        }
    }

    // MARK: - Bandeau d'erreur

    @ViewBuilder
    private var bandeauErreur: some View {
        if let erreur = authService.erreur {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(erreur)
            }
            .font(.caption)
            .foregroundStyle(.white)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.red)
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Bouton connexion

    private var boutonConnexion: some View {
        Button {
            authService.connexion(
                identifiant: identifiant,
                motDePasse: motDePasse,
                context: modelContext
            )
            // Vérifier la cohérence du rôle sélectionné
            if authService.estConnecte, let utilisateur = authService.utilisateurConnecte {
                let estAthleteSelection = categorieSelectionnee == .athlete
                let estAthleteCompte = utilisateur.role == .etudiant
                if estAthleteSelection != estAthleteCompte {
                    authService.deconnexion()
                    authService.erreur = "Identifiant ou mot de passe incorrect."
                }
            }
        } label: {
            HStack(spacing: 8) {
                if authService.chargement {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Connexion")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(formulaireValide ? couleurActive : Color.gray.opacity(0.4))
            )
            .foregroundStyle(.white)
        }
        .disabled(!formulaireValide || authService.chargement || authService.estVerrouille)
        .animation(LiquidGlassKit.springDefaut, value: formulaireValide)
    }
}
