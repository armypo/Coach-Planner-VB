//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Rôle sélectionné dans le picker de la `LoginView` unifiée.
/// Le rôle réel de l'utilisateur est lu depuis le modèle `Utilisateur` après
/// authentification ; ce picker permet simplement de valider que le type de
/// compte correspond à ce que l'utilisateur a sélectionné (évite les
/// confusions du style « coach qui clique Athlète »).
enum RoleLogin: String, CaseIterable, Identifiable {
    case coach
    case assistant
    case athlete

    var id: String { rawValue }

    var label: String {
        switch self {
        case .coach: return "Coach"
        case .assistant: return "Assistant"
        case .athlete: return "Athlète"
        }
    }

    var couleur: Color {
        switch self {
        case .coach: return PaletteMat.bleu
        case .assistant: return Color(hex: "#7FB0F7")
        case .athlete: return PaletteMat.orange
        }
    }

    var rolesValides: [RoleUtilisateur] {
        switch self {
        case .coach: return [.coach, .admin]
        case .assistant: return [.assistantCoach]
        case .athlete: return [.etudiant]
        }
    }
}

struct LoginView: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.modelContext) private var modelContext

    var onRetour: (() -> Void)? = nil
    var onConnecte: (() -> Void)? = nil

    @State private var identifiant = ""
    @State private var motDePasse = ""
    @State private var afficherMotDePasse = false
    @State private var roleSelectionne: RoleLogin = .coach

    private var couleurActive: Color { roleSelectionne.couleur }

    private var formulaireValide: Bool {
        !identifiant.trimmingCharacters(in: .whitespaces).isEmpty && !motDePasse.isEmpty
    }

    var body: some View {
        ZStack {
            couleurActive.opacity(0.04).ignoresSafeArea()
                .animation(LiquidGlassKit.springDefaut, value: roleSelectionne)

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: LiquidGlassKit.hauteurSpacerHero)

                    VStack(spacing: LiquidGlassKit.espaceLG) {
                        entete
                        pickerRole
                        formulaire
                        bandeauErreur
                        boutonConnexion
                    }
                    .padding(.horizontal, LiquidGlassKit.espaceXL)
                    .padding(.vertical, LiquidGlassKit.espaceXL)
                    .glassCard(cornerRadius: LiquidGlassKit.rayonGrand)
                    .frame(maxWidth: 420)

                    lienSetup
                        .padding(.top, LiquidGlassKit.espaceMD)

                    Spacer().frame(height: LiquidGlassKit.hauteurSpacerBas)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - En-tête

    private var entete: some View {
        VStack(spacing: LiquidGlassKit.espaceXS) {
            HStack(spacing: 10) {
                Image(systemName: "volleyball.fill")
                    .font(.system(size: LiquidGlassKit.iconeGrande, weight: .bold))
                    .foregroundStyle(.orange)
                Text("Playco")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
            }
            Text("Connectez-vous pour continuer")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Picker Coach / Assistant / Athlète

    private var pickerRole: some View {
        Picker("Type de compte", selection: $roleSelectionne) {
            ForEach(RoleLogin.allCases) { role in
                Text(role.label).tag(role)
            }
        }
        .pickerStyle(.segmented)
        .tint(couleurActive)
        .animation(LiquidGlassKit.springDefaut, value: roleSelectionne)
    }

    // MARK: - Formulaire

    private var formulaire: some View {
        VStack(spacing: LiquidGlassKit.espaceMD) {
            champSaisie(
                titre: "IDENTIFIANT",
                placeholder: "prenom.nom.1234",
                icone: "person.text.rectangle.fill",
                couleur: couleurActive,
                texte: $identifiant
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.username)

            champMotDePasse
        }
    }

    private func champSaisie(
        titre: String,
        placeholder: String,
        icone: String,
        couleur: Color,
        texte: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceXS) {
            Text(titre)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            HStack(spacing: LiquidGlassKit.espaceSM + 2) {
                Image(systemName: icone).foregroundStyle(couleur).frame(width: LiquidGlassKit.iconeChamp)
                TextField(placeholder, text: texte)
            }
            .padding(LiquidGlassKit.paddingChamp)
            .background(Color(.systemGray6).opacity(0.6),
                        in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit))
        }
    }

    private var champMotDePasse: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceXS) {
            Text("MOT DE PASSE")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            HStack(spacing: LiquidGlassKit.espaceSM + 2) {
                Image(systemName: "lock.fill").foregroundStyle(PaletteMat.vert).frame(width: LiquidGlassKit.iconeChamp)
                if afficherMotDePasse {
                    // Pas de textContentType ici : iOS ne doit pas suggérer
                    // l'autofill de mot de passe dans un champ visible.
                    TextField("••••••••", text: $motDePasse)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } else {
                    SecureField("••••••••", text: $motDePasse).textContentType(.password)
                }
                Button {
                    afficherMotDePasse.toggle()
                } label: {
                    Image(systemName: afficherMotDePasse ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(LiquidGlassKit.paddingChamp)
            .background(Color(.systemGray6).opacity(0.6),
                        in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit))
        }
    }

    // MARK: - Bandeau d'erreur

    @ViewBuilder
    private var bandeauErreur: some View {
        if let erreur = authService.erreur {
            HStack(spacing: LiquidGlassKit.espaceSM) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(erreur)
            }
            .font(.caption)
            .foregroundStyle(.white)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(.red, in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit))
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Bouton connexion

    private var boutonConnexion: some View {
        Button {
            tenterConnexion()
        } label: {
            HStack(spacing: LiquidGlassKit.espaceSM) {
                if authService.chargement {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Connexion").fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                formulaireValide ? couleurActive : Color.gray.opacity(0.4),
                in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMoyen)
            )
            .foregroundStyle(.white)
        }
        .disabled(!formulaireValide || authService.chargement || authService.estVerrouille)
        .animation(LiquidGlassKit.springDefaut, value: formulaireValide)
        .buttonStyle(GlassButtonStyle())
    }

    /// Tente la connexion puis vérifie que le rôle réel correspond au picker sélectionné.
    /// En cas de mismatch (ex: coach qui clique Athlète), déconnecte l'utilisateur
    /// immédiatement et affiche un message d'erreur explicite.
    private func tenterConnexion() {
        authService.erreur = nil
        authService.connexion(
            identifiant: identifiant,
            motDePasse: motDePasse,
            context: modelContext
        )
        guard let user = authService.utilisateurConnecte else { return }
        guard roleSelectionne.rolesValides.contains(user.role) else {
            let roleReel = user.role.label
            let roleAttendu = roleSelectionne.label
            authService.deconnexion()
            authService.erreur = "Mauvais type de compte. Tu as sélectionné « \(roleAttendu) » mais ton compte est « \(roleReel) ». Sélectionne le bon type et réessaie."
            return
        }
        onConnecte?()
    }

    // MARK: - Lien retour / premier setup

    private var lienSetup: some View {
        Button {
            if let onRetour {
                onRetour()
            } else {
                NotificationCenter.default.post(name: .allerChoixInitial, object: nil)
            }
        } label: {
            HStack(spacing: LiquidGlassKit.espaceXS) {
                Image(systemName: "person.3.fill").font(.system(size: LiquidGlassKit.iconePetite))
                Text("Créer ou rejoindre une équipe").font(.subheadline.weight(.medium))
            }
            .foregroundStyle(couleurActive)
            .padding(.horizontal, LiquidGlassKit.espaceLG)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(couleurActive.opacity(0.25), lineWidth: 0.5)
            }
        }
        .buttonStyle(GlassButtonStyle())
    }
}
