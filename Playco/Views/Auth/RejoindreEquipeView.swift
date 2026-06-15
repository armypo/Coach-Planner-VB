//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  RejoindreEquipeView — jonction athlète/assistant sur un Apple ID différent.
//  Flux : equipeExiste(code) → recupererEtImporterEquipe (importe roster + tier +
//  calendrier + stats depuis la Public DB) → AuthService.connexion (compte importé)
//  → vérification d'appartenance. La gate tier est appliquée ensuite par PlaycoApp.

import SwiftUI
import SwiftData
import os

private let loggerRejoindre = Logger(subsystem: "com.origotech.playco", category: "RejoindreEquipe")

struct RejoindreEquipeView: View {
    @Environment(AuthService.self) private var authService
    @Environment(CloudKitSharingService.self) private var sharingService
    @Environment(\.modelContext) private var modelContext

    var onRetour: () -> Void
    var onConnecte: () -> Void

    @State private var codeEquipe = ""
    @State private var identifiant = ""
    @State private var motDePasse = ""
    @State private var afficherMotDePasse = false
    @State private var chargementCloud = false
    @State private var erreurLocale: String?

    private let couleur = PaletteMat.vert

    private var formulaireValide: Bool {
        !codeEquipe.trimmingCharacters(in: .whitespaces).isEmpty &&
        !identifiant.trimmingCharacters(in: .whitespaces).isEmpty &&
        !motDePasse.isEmpty
    }

    private var enChargement: Bool { chargementCloud || authService.chargement }

    var body: some View {
        ZStack {
            couleur.opacity(0.04).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: LiquidGlassKit.hauteurSpacerHero)

                    VStack(spacing: LiquidGlassKit.espaceLG) {
                        entete
                        formulaire
                        bandeauErreur
                        boutonConnexion
                    }
                    .padding(.horizontal, LiquidGlassKit.espaceXL)
                    .padding(.vertical, LiquidGlassKit.espaceXL)
                    .glassCard(cornerRadius: LiquidGlassKit.rayonGrand)
                    .frame(maxWidth: 420)

                    Spacer().frame(height: LiquidGlassKit.hauteurSpacerBas)
                }
                .frame(maxWidth: .infinity)
            }

            VStack {
                HStack {
                    Button { onRetour() } label: {
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

    // MARK: - En-tête

    private var entete: some View {
        VStack(spacing: LiquidGlassKit.espaceSM) {
            Image(systemName: "number.circle.fill")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(couleur)
            Text("Rejoindre une équipe")
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text("Entrez le code d'équipe fourni par votre coach et vos identifiants.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Formulaire

    private var formulaire: some View {
        VStack(spacing: LiquidGlassKit.espaceMD) {
            champSaisie(titre: "CODE D'ÉQUIPE", placeholder: "ABCD1234",
                        icone: "number", texte: $codeEquipe)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()

            champSaisie(titre: "IDENTIFIANT", placeholder: "prenom.nom.1234",
                        icone: "person.text.rectangle.fill", texte: $identifiant)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.username)

            champMotDePasse
        }
    }

    private func champSaisie(titre: String, placeholder: String, icone: String,
                             texte: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceXS) {
            Text(titre).font(.caption.weight(.semibold)).foregroundStyle(.secondary).tracking(0.5)
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
            Text("MOT DE PASSE").font(.caption.weight(.semibold)).foregroundStyle(.secondary).tracking(0.5)
            HStack(spacing: LiquidGlassKit.espaceSM + 2) {
                Image(systemName: "lock.fill").foregroundStyle(PaletteMat.vert).frame(width: LiquidGlassKit.iconeChamp)
                if afficherMotDePasse {
                    TextField("••••••••", text: $motDePasse)
                        .autocorrectionDisabled().textInputAutocapitalization(.never)
                } else {
                    SecureField("••••••••", text: $motDePasse).textContentType(.password)
                }
                Button { afficherMotDePasse.toggle() } label: {
                    Image(systemName: afficherMotDePasse ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(LiquidGlassKit.paddingChamp)
            .background(Color(.systemGray6).opacity(0.6),
                        in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit))
        }
    }

    // MARK: - Bandeau erreur

    @ViewBuilder
    private var bandeauErreur: some View {
        if let erreur = erreurLocale ?? authService.erreur {
            HStack(spacing: LiquidGlassKit.espaceSM) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(erreur)
            }
            .font(.caption).foregroundStyle(.white).padding(12)
            .frame(maxWidth: .infinity)
            .background(.red, in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit))
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Bouton

    private var boutonConnexion: some View {
        Button {
            Task { await seConnecter() }
        } label: {
            HStack(spacing: LiquidGlassKit.espaceSM) {
                if enChargement {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Rejoindre").fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(formulaireValide ? couleur : Color.gray.opacity(0.4),
                        in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMoyen))
            .foregroundStyle(.white)
        }
        .disabled(!formulaireValide || enChargement || authService.estVerrouille)
        .animation(LiquidGlassKit.springDefaut, value: formulaireValide)
        .buttonStyle(GlassButtonStyle())
    }

    // MARK: - Logique

    private func seConnecter() async {
        let codeNormalise = Equipe.normaliserCodeEquipe(codeEquipe)
        let idNormalise = identifiant.lowercased().trimmingCharacters(in: .whitespaces)
        erreurLocale = nil
        authService.erreur = nil

        guard !codeNormalise.isEmpty, !idNormalise.isEmpty, !motDePasse.isEmpty else {
            erreurLocale = "Veuillez remplir tous les champs."
            return
        }

        // 1. Vérifier l'existence de l'équipe dans la Public DB.
        chargementCloud = true
        guard await sharingService.equipeExiste(codeEquipe: codeNormalise) else {
            chargementCloud = false
            erreurLocale = "Code équipe invalide. Vérifiez auprès de votre coach."
            return
        }

        // 2. Importer roster + tier + calendrier + stats dans le SwiftData local
        // (données non sensibles uniquement — aucun compte/credential répliqué).
        do {
            try await sharingService.recupererEtImporterEquipe(codeEquipe: codeNormalise, context: modelContext)
        } catch {
            chargementCloud = false
            loggerRejoindre.error("Import équipe échoué : \(error.localizedDescription)")
            erreurLocale = "Impossible de récupérer l'équipe. Vérifiez votre connexion internet."
            return
        }

        // 3. Créer le compte local : hash dérivé LOCALEMENT du mot de passe saisi
        // (jamais publié), rôle clampé (anti-escalade coach/admin).
        do {
            try await sharingService.creerCompteLocalJonction(
                codeEquipe: codeNormalise,
                identifiant: idNormalise,
                motDePasse: motDePasse,
                context: modelContext
            )
        } catch {
            chargementCloud = false
            loggerRejoindre.error("Création compte jonction échouée : \(error.localizedDescription)")
            erreurLocale = (error as? LocalizedError)?.errorDescription
                ?? "Impossible de créer le compte. Vérifiez votre identifiant."
            return
        }
        chargementCloud = false

        // 4. Connexion sur le compte fraîchement créé (vérification mdp locale).
        authService.connexion(identifiant: idNormalise, motDePasse: motDePasse, context: modelContext)
        guard authService.estConnecte, let user = authService.utilisateurConnecte else { return }

        // 5. Vérifier que le compte appartient bien à cette équipe.
        let codeUser = user.codeEcole
        if !codeUser.isEmpty && codeUser != codeNormalise {
            authService.deconnexion()
            erreurLocale = "Votre compte n'est pas associé à cette équipe."
            return
        }

        // PlaycoApp applique la gate tier (athlète → Club requis) via onConnecte.
        onConnecte()
    }
}
