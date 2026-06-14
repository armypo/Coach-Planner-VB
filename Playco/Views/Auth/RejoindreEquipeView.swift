//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  RejoindreEquipeView — jonction d'équipe multi-Apple-ID.
//
//  L'athlète/assistant rejoint l'équipe de son coach (sur un Apple ID différent)
//  avec : code d'équipe + identifiant + mot de passe. Les données d'équipe
//  publiques sont importées et le compte local est créé en dérivant le hash
//  LOCALEMENT à partir du mot de passe saisi (aucun hash n'est jamais publié).
//  Voir docs/Securite_AbonnementPublicDB.md.

import SwiftUI
import SwiftData

struct RejoindreEquipeView: View {
    @Environment(AuthService.self) private var authService
    @Environment(CloudKitSharingService.self) private var sharingService
    @Environment(\.modelContext) private var modelContext

    /// Retour à l'écran précédent (ChoixInitialView).
    var onRetour: () -> Void
    /// Jonction + connexion réussies → laisser PlaycoApp appliquer la gate.
    var onConnecte: () -> Void

    @State private var codeEquipe = ""
    @State private var identifiant = ""
    @State private var motDePasse = ""
    @State private var afficherMotDePasse = false
    @State private var chargement = false
    @State private var erreur: String?

    private let couleurActive = PaletteMat.vert

    private var formulaireValide: Bool {
        !codeEquipe.trimmingCharacters(in: .whitespaces).isEmpty &&
        !identifiant.trimmingCharacters(in: .whitespaces).isEmpty &&
        !motDePasse.isEmpty
    }

    var body: some View {
        ZStack {
            couleurActive.opacity(0.04).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: LiquidGlassKit.hauteurSpacerHero)

                    VStack(spacing: LiquidGlassKit.espaceLG) {
                        entete
                        formulaire
                        bandeauErreur
                        boutonRejoindre
                    }
                    .padding(.horizontal, LiquidGlassKit.espaceXL)
                    .padding(.vertical, LiquidGlassKit.espaceXL)
                    .glassCard(cornerRadius: LiquidGlassKit.rayonGrand)
                    .frame(maxWidth: 420)

                    Spacer().frame(height: LiquidGlassKit.hauteurSpacerBas)
                }
                .frame(maxWidth: .infinity)
            }

            boutonRetour
        }
    }

    // MARK: - En-tête

    private var entete: some View {
        VStack(spacing: LiquidGlassKit.espaceXS) {
            Image(systemName: "person.2.badge.key.fill")
                .font(.system(size: LiquidGlassKit.iconeGrande, weight: .bold))
                .foregroundStyle(couleurActive)
            Text("Rejoindre une équipe")
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text("Entrez le code fourni par votre coach et vos identifiants.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Formulaire

    private var formulaire: some View {
        VStack(spacing: LiquidGlassKit.espaceMD) {
            champSaisie(
                titre: "CODE D'ÉQUIPE",
                placeholder: "ABC123",
                icone: "number.square.fill",
                texte: $codeEquipe
            )
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()

            champSaisie(
                titre: "IDENTIFIANT",
                placeholder: "prenom.nom.1234",
                icone: "person.text.rectangle.fill",
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
        texte: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceXS) {
            Text(titre)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            HStack(spacing: LiquidGlassKit.espaceSM + 2) {
                Image(systemName: icone).foregroundStyle(couleurActive).frame(width: LiquidGlassKit.iconeChamp)
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
                Image(systemName: "lock.fill").foregroundStyle(couleurActive).frame(width: LiquidGlassKit.iconeChamp)
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
        if let erreur {
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

    // MARK: - Bouton rejoindre

    private var boutonRejoindre: some View {
        Button {
            rejoindre()
        } label: {
            HStack(spacing: LiquidGlassKit.espaceSM) {
                if chargement {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Rejoindre").fontWeight(.semibold)
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
        .disabled(!formulaireValide || chargement)
        .animation(LiquidGlassKit.springDefaut, value: formulaireValide)
        .buttonStyle(GlassButtonStyle())
    }

    private var boutonRetour: some View {
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

    // MARK: - Action

    /// Importe les données d'équipe + crée le compte local (hash dérivé
    /// localement), puis connecte le membre. La connexion réutilise tout
    /// l'appareil d'auth existant (verrouillage, session).
    private func rejoindre() {
        erreur = nil
        chargement = true
        let code = codeEquipe
        let id = identifiant
        let mdp = motDePasse

        Task { @MainActor in
            defer { chargement = false }
            do {
                try await sharingService.rejoindreEquipe(
                    codeEquipe: code,
                    identifiant: id,
                    motDePasse: mdp,
                    context: modelContext
                )
            } catch {
                erreur = (error as? LocalizedError)?.errorDescription
                    ?? "Impossible de rejoindre l'équipe. Vérifiez le code et vos identifiants."
                return
            }

            // Connexion locale (le compte vient d'être créé avec ce mot de passe)
            authService.connexion(identifiant: id, motDePasse: mdp, context: modelContext)
            guard authService.utilisateurConnecte != nil else {
                erreur = authService.erreur ?? "Connexion impossible après la jonction."
                return
            }
            onConnecte()
        }
    }
}
