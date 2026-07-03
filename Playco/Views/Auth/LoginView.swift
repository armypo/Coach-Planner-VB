//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData
import AuthenticationServices

// MARK: - LoginView
//
// SIWA strict : Sign in with Apple est l'UNIQUE méthode de connexion.
// Un Apple ID inconnu est invité à rejoindre son équipe (code d'équipe +
// code d'invitation fournis par le coach) ou à créer une équipe.

struct LoginView: View {
    @Environment(AuthService.self) private var authService
    @Environment(AppleSignInService.self) private var appleSignIn
    @Environment(CloudKitSharingService.self) private var sharingService
    @Environment(\.modelContext) private var modelContext

    /// Callback optionnel : retour à l'écran précédent (utilisé depuis PlaycoApp
    /// via `.login`). Si nil, le bouton retour n'apparaît pas (ContentView).
    var onRetour: (() -> Void)? = nil
    /// Callback optionnel : connexion réussie (PlaycoApp). Si nil, on laisse
    /// ContentView observer `authService.estConnecte` pour transitionner.
    var onConnecte: (() -> Void)? = nil

    /// `appleUserID` d'un Sign in with Apple non encore lié à un compte —
    /// conservé pour la jointure d'équipe par code d'invitation.
    @State private var appleUserIDEnAttente: String?

    // Rejoindre une équipe (athlète/assistant/coach invité, cross-Apple-ID)
    @State private var afficherRejoindre = false
    @State private var codeEquipeSaisi = ""
    @State private var codeInvitationSaisi = ""
    @State private var rejoindreEnCours = false

    var body: some View {
        ZStack {
            PaletteMat.bleu.opacity(0.04).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: LiquidGlassKit.hauteurSpacerHero)

                    VStack(spacing: LiquidGlassKit.espaceLG) {
                        entete
                        boutonApple
                        bandeauErreur
                        if appleUserIDEnAttente != nil {
                            boutonRejoindreEquipe
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
            Text("Connecte-toi pour continuer")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Sign in with Apple (connexion unique)

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

    /// Traite le résultat Sign in with Apple : connecte si le compte est lié,
    /// sinon propose la jointure d'équipe par code d'invitation.
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
            authService.erreur = "Aucun compte lié à cet Apple ID. Rejoins ton équipe avec ton code d'invitation, ou crée une équipe."
        case .echec(let message):
            authService.erreur = message
        }
    }

    // MARK: - Rejoindre une équipe (par code d'invitation)

    private var boutonRejoindreEquipe: some View {
        Button {
            afficherRejoindre = true
        } label: {
            HStack(spacing: LiquidGlassKit.espaceSM) {
                Image(systemName: "person.3.fill")
                Text("Rejoindre mon équipe").fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(PaletteMat.orange, in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMoyen))
            .foregroundStyle(.white)
        }
        .buttonStyle(GlassButtonStyle())
        .sheet(isPresented: $afficherRejoindre, onDismiss: {
            codeEquipeSaisi = ""
            codeInvitationSaisi = ""
            rejoindreEnCours = false
        }) { sheetRejoindre }
    }

    private var sheetRejoindre: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Code d'équipe", text: $codeEquipeSaisi)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Code d'invitation", text: $codeInvitationSaisi)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                } header: {
                    Text("Codes fournis par ton coach")
                } footer: {
                    Text("Ton coach te communique le code d'équipe et ton code d'invitation personnel.")
                }
                if let erreur = authService.erreur {
                    Text(erreur).font(.caption).foregroundStyle(.red)
                }
            }
            .navigationTitle("Rejoindre une équipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { afficherRejoindre = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Rejoindre") { Task { await rejoindre() } }
                        .disabled(codeEquipeSaisi.isEmpty || codeInvitationSaisi.isEmpty || rejoindreEnCours)
                }
            }
        }
    }

    @MainActor
    private func rejoindre() async {
        guard let appleUserID = appleUserIDEnAttente else { return }
        authService.erreur = nil
        rejoindreEnCours = true
        defer { rejoindreEnCours = false }
        do {
            let membre = try await sharingService.rejoindreEquipe(
                codeEquipe: codeEquipeSaisi,
                codeInvitation: codeInvitationSaisi,
                appleUserID: appleUserID,
                context: modelContext
            )
            // Reconnexion via l'identité Apple désormais rattachée.
            let etat = authService.connexionApple(
                appleUserID: membre.appleUserID,
                prenom: membre.prenom,
                nom: membre.nom,
                context: modelContext
            )
            if case .connecte = etat {
                appleUserIDEnAttente = nil
                afficherRejoindre = false
                onConnecte?()
            } else {
                authService.erreur = "Rattachement effectué mais connexion impossible. Réessaie."
            }
        } catch {
            authService.erreur = (error as? CloudKitSharingService.SharingError)?.errorDescription
                ?? "Impossible de rejoindre l'équipe. Vérifie ta connexion."
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

    // MARK: - Lien premier setup (ContentView uniquement)

    private var lienSetup: some View {
        Button {
            NotificationCenter.default.post(name: .allerChoixInitial, object: nil)
        } label: {
            HStack(spacing: LiquidGlassKit.espaceXS) {
                Image(systemName: "person.3.fill").font(.system(size: LiquidGlassKit.iconePetite))
                Text("Créer ou rejoindre une équipe").font(.subheadline.weight(.medium))
            }
            .foregroundStyle(PaletteMat.bleu)
            .padding(.horizontal, LiquidGlassKit.espaceLG)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(PaletteMat.bleu.opacity(0.25), lineWidth: 0.5)
            }
        }
        .buttonStyle(GlassButtonStyle())
    }
}
