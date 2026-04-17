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
    @State private var modeCoach = true

    private var couleurActive: Color { modeCoach ? PaletteMat.bleu : PaletteMat.orange }

    private var formulaireValide: Bool {
        !identifiant.trimmingCharacters(in: .whitespaces).isEmpty && !motDePasse.isEmpty
    }

    var body: some View {
        ZStack {
            couleurActive.opacity(0.04).ignoresSafeArea()
                .animation(LiquidGlassKit.springDefaut, value: modeCoach)

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: LiquidGlassKit.hauteurSpacerHero)

                    VStack(spacing: LiquidGlassKit.espaceLG) {
                        entete
                        toggleRole
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

    // MARK: - Toggle Coach / Athlète

    private var toggleRole: some View {
        HStack(spacing: 0) {
            roleButton(label: "Coach", icone: "figure.volleyball", estCoach: true)
            roleButton(label: "Athlète", icone: "figure.run", estCoach: false)
        }
        .padding(LiquidGlassKit.espaceXS / 2)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonToggleContainer))
    }

    @ViewBuilder
    private func roleButton(label: String, icone: String, estCoach: Bool) -> some View {
        let estSelectionne = modeCoach == estCoach
        let couleur: Color = estCoach ? PaletteMat.bleu : PaletteMat.orange
        Button {
            withAnimation(LiquidGlassKit.springRebond) { modeCoach = estCoach }
        } label: {
            HStack(spacing: LiquidGlassKit.espaceSM) {
                Image(systemName: icone).font(.system(size: LiquidGlassKit.iconeMoyenne, weight: .medium))
                Text(label).font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(estSelectionne ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, LiquidGlassKit.espaceSM + 2)
            .background(
                estSelectionne ? couleur : Color.clear,
                in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit)
            )
        }
        .buttonStyle(.plain)
        .animation(LiquidGlassKit.springDefaut, value: estSelectionne)
    }

    // MARK: - Formulaire

    private var formulaire: some View {
        VStack(spacing: LiquidGlassKit.espaceMD) {
            champSaisie(
                titre: "IDENTIFIANT",
                placeholder: "prenom.nom",
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
            authService.erreur = nil
            authService.connexion(
                identifiant: identifiant,
                motDePasse: motDePasse,
                context: modelContext
            )
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

    // MARK: - Lien premier setup

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
