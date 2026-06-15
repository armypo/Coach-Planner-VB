//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData
import AuthenticationServices

// MARK: - Rôle Login

/// Représente l'onglet de login sélectionné. Indépendant de `RoleUtilisateur` :
/// permet de mapper plusieurs rôles internes vers un même onglet UI
/// (ex: `.coach` regroupe `.coach` + `.admin`).
enum RoleLogin: String, CaseIterable, Identifiable {
    case coach, assistant, athlete

    var id: String { rawValue }

    var label: String {
        switch self {
        case .coach: return "Coach"
        case .assistant: return "Assistant"
        case .athlete: return "Athlète"
        }
    }

    var icone: String {
        switch self {
        case .coach: return "figure.volleyball"
        case .assistant: return "person.badge.shield.checkmark"
        case .athlete: return "figure.run"
        }
    }

    var couleur: Color {
        switch self {
        case .coach: return PaletteMat.bleu
        case .assistant: return Color(hex: "#7FB0F7")
        case .athlete: return PaletteMat.orange
        }
    }

    /// Rôles `RoleUtilisateur` autorisés pour cet onglet — un mismatch
    /// après connexion déclenche une erreur explicite à l'utilisateur.
    var rolesValides: [RoleUtilisateur] {
        switch self {
        case .coach: return [.coach, .admin]
        case .assistant: return [.assistantCoach]
        case .athlete: return [.etudiant]
        }
    }
}

// MARK: - LoginView

struct LoginView: View {
    @Environment(AuthService.self) private var authService
    @Environment(AppleSignInService.self) private var appleSignIn
    @Environment(\.modelContext) private var modelContext

    /// Callback optionnel : retour à l'écran précédent (utilisé depuis PlaycoApp
    /// via `.login`). Si nil, le bouton retour n'apparaît pas (ContentView).
    var onRetour: (() -> Void)? = nil
    /// Callback optionnel : connexion réussie (PlaycoApp). Si nil, on laisse
    /// ContentView observer `authService.estConnecte` pour transitionner.
    var onConnecte: (() -> Void)? = nil

    @State private var identifiant = ""
    @State private var motDePasse = ""
    @State private var afficherMotDePasse = false
    @State private var roleSelectionne: RoleLogin = .coach

    /// Affiche le formulaire identifiant/mot de passe (chemin « ancien compte »
    /// pour la transition Sign in with Apple). Masqué par défaut : SIWA primaire.
    @State private var afficherFormulaireLegacy = false
    /// `appleUserID` d'un Sign in with Apple non encore lié à un compte —
    /// conservé pour le rattachement (lierCompteExistant, Phase 3).
    @State private var appleUserIDEnAttente: String?

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
                        boutonApple
                        bandeauErreur
                        if afficherFormulaireLegacy {
                            separateurLegacy
                            pickerRole
                            formulaire
                            boutonConnexion
                        } else {
                            lienAncienCompte
                        }
                    }
                    .padding(.horizontal, LiquidGlassKit.espaceXL)
                    .padding(.vertical, LiquidGlassKit.espaceXL)
                    .glassCard(cornerRadius: LiquidGlassKit.rayonGrand)
                    .frame(maxWidth: 420)

                    if onRetour == nil {
                        lienSetup
                            .padding(.top, LiquidGlassKit.espaceMD)
                    }

                    Spacer().frame(height: LiquidGlassKit.hauteurSpacerBas)
                }
                .frame(maxWidth: .infinity)
            }

            // Bouton retour optionnel (overlay haut-gauche)
            if let onRetour {
                VStack {
                    HStack {
                        Button {
                            onRetour()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                Text("Retour")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                        }
                        Spacer()
                    }
                    .padding(.horizontal, LiquidGlassKit.espaceMD)
                    .padding(.top, LiquidGlassKit.espaceMD)
                    Spacer()
                }
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

    // MARK: - Sign in with Apple (connexion primaire)

    private var boutonApple: some View {
        SignInWithAppleButton(.signIn) { requete in
            appleSignIn.configurerRequete(requete)
        } onCompletion: { resultat in
            traiterApple(resultat)
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMoyen))
    }

    private var separateurLegacy: some View {
        HStack(spacing: LiquidGlassKit.espaceSM) {
            Rectangle().frame(height: 0.5).foregroundStyle(.secondary.opacity(0.3))
            Text("ou ancien compte").font(.caption2).foregroundStyle(.secondary)
            Rectangle().frame(height: 0.5).foregroundStyle(.secondary.opacity(0.3))
        }
    }

    private var lienAncienCompte: some View {
        Button {
            withAnimation(LiquidGlassKit.springDefaut) { afficherFormulaireLegacy = true }
        } label: {
            Text("J'ai un identifiant Playco")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    /// Traite le résultat Sign in with Apple : connecte si le compte est lié,
    /// sinon révèle le formulaire « ancien compte » pour rattachement (Phase 3).
    private func traiterApple(_ resultat: Result<ASAuthorization, Error>) {
        authService.erreur = nil
        guard let creds = appleSignIn.traiterResultat(resultat) else {
            authService.erreur = "Connexion Apple impossible. Réessaie."
            return
        }
        let etat = authService.connexionApple(
            appleUserID: creds.user,
            prenom: creds.prenom,
            nom: creds.nom,
            context: modelContext
        )
        switch etat {
        case .connecte:
            onConnecte?()
        case .compteInconnu(let appleUserID, _, _):
            appleUserIDEnAttente = appleUserID
            authService.erreur = "Aucun compte lié à cet Apple ID. Connecte-toi une fois avec ton ancien identifiant pour le lier, ou crée/rejoins une équipe."
            withAnimation(LiquidGlassKit.springDefaut) { afficherFormulaireLegacy = true }
        }
    }

    // MARK: - Picker 3 tabs (Coach / Assistant / Athlète)

    private var pickerRole: some View {
        Picker("Type de compte", selection: $roleSelectionne) {
            ForEach(RoleLogin.allCases) { r in
                Text(r.label).tag(r)
            }
        }
        .pickerStyle(.segmented)
        .tint(roleSelectionne.couleur)
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

    // MARK: - Bouton connexion (avec post-auth role check)

    private var boutonConnexion: some View {
        Button {
            connecter()
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

    /// Effectue la connexion + vérifie que le rôle réel correspond à l'onglet
    /// sélectionné. Si mismatch : déconnexion immédiate + message explicite.
    private func connecter() {
        authService.erreur = nil

        // Si un Sign in with Apple non lié est en attente, on RATTACHE le compte
        // legacy à l'identité Apple (puis les secrets sont effacés).
        if let appleUserID = appleUserIDEnAttente {
            if let messageErreur = authService.lierCompteExistant(
                appleUserID: appleUserID,
                identifiant: identifiant,
                motDePasse: motDePasse,
                context: modelContext
            ) {
                authService.erreur = messageErreur
                return
            }
            appleUserIDEnAttente = nil
            onConnecte?()
            return
        }

        authService.connexion(
            identifiant: identifiant,
            motDePasse: motDePasse,
            context: modelContext
        )
        guard let user = authService.utilisateurConnecte else { return }
        guard roleSelectionne.rolesValides.contains(user.role) else {
            let roleReel = user.role.label
            authService.deconnexion()
            authService.erreur = "Mauvais type de compte. Tu as sélectionné « \(roleSelectionne.label) » mais ton compte est « \(roleReel) ». Sélectionne le bon onglet et réessaie."
            return
        }
        onConnecte?()
    }

    // MARK: - Lien premier setup (ContentView uniquement)

    private var lienSetup: some View {
        Button {
            NotificationCenter.default.post(name: .allerChoixInitial, object: nil)
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
