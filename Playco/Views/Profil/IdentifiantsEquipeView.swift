//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Liste les identifiants + mots de passe auto-générés des athlètes et
/// assistants de l'équipe active. Accessible depuis ProfilView → Organisation
/// (coach seulement). Permet de copier / partager / régénérer un mdp.
struct IdentifiantsEquipeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Environment(AuthService.self) private var authService

    @Query private var credentials: [CredentialAthlete]
    @Query private var utilisateurs: [Utilisateur]

    @State private var nouveauMdpAffiche: NouveauMdpWrapper?

    private var credsFiltres: [CredentialAthlete] {
        credentials.filtreEquipe(codeEquipeActif)
    }

    private var athletes: [CredentialAthlete] {
        credsFiltres.filter { $0.joueurEquipeID != nil }
            .sorted { utilisateurPour($0)?.nomComplet ?? "" < utilisateurPour($1)?.nomComplet ?? "" }
    }

    private var assistants: [CredentialAthlete] {
        credsFiltres.filter { $0.joueurEquipeID == nil }
            .sorted { utilisateurPour($0)?.nomComplet ?? "" < utilisateurPour($1)?.nomComplet ?? "" }
    }

    var body: some View {
        List {
            if credsFiltres.isEmpty {
                ContentUnavailableView(
                    "Aucun identifiant enregistré",
                    systemImage: "key.slash",
                    description: Text("Les identifiants des athlètes et assistants créés via le wizard ou le bouton « Créer un profil d'athlète » apparaissent ici.")
                )
            } else {
                Section("Athlètes (\(athletes.count))") {
                    ForEach(athletes) { cred in ligneCredential(cred) }
                }
                Section("Assistants (\(assistants.count))") {
                    ForEach(assistants) { cred in ligneCredential(cred) }
                }
            }
        }
        .navigationTitle("Identifiants de l'équipe")
        .sheet(item: $nouveauMdpAffiche) { wrapper in
            feuilleNouveauMdp(wrapper: wrapper)
        }
    }

    // MARK: - Ligne credential

    private func ligneCredential(_ cred: CredentialAthlete) -> some View {
        let user = utilisateurPour(cred)
        return VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Text(user?.nomComplet ?? "—").font(.headline)

            ligneValeur(titre: "ID", valeur: cred.identifiant)
            ligneValeur(titre: "Mdp", valeur: cred.motDePasseClair)

            HStack(spacing: LiquidGlassKit.espaceSM) {
                Button {
                    regenererMdp(cred: cred, user: user)
                } label: {
                    Label("Régénérer mdp", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Spacer()

                ShareLink(item: templateTexte(cred: cred, user: user)) {
                    Label("Partager", systemImage: "square.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    private func ligneValeur(titre: String, valeur: String) -> some View {
        HStack {
            Text("\(titre) :")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(valeur)
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .textSelection(.enabled)
            Spacer()
            Button {
                UIPasteboard.general.string = valeur
            } label: {
                Image(systemName: "doc.on.doc").font(.caption)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Régénération mdp

    private func regenererMdp(cred: CredentialAthlete, user: Utilisateur?) {
        guard let user else { return }
        let nouveauMdp = Utilisateur.genererMotDePasseAthlete()
        let nouveauSel = authService.genererSel()
        user.sel = nouveauSel
        user.motDePasseHash = authService.hashMotDePasse(nouveauMdp, sel: nouveauSel)
        user.iterations = AuthService.iterationsParDefaut
        cred.motDePasseClair = nouveauMdp
        cred.dateModification = Date()
        try? modelContext.save()
        nouveauMdpAffiche = NouveauMdpWrapper(nom: user.nomComplet, mdp: nouveauMdp)
    }

    private func feuilleNouveauMdp(wrapper: NouveauMdpWrapper) -> some View {
        VStack(spacing: LiquidGlassKit.espaceLG) {
            Image(systemName: "key.fill")
                .font(.system(size: 60))
                .foregroundStyle(PaletteMat.orange)
            Text("Nouveau mot de passe pour \(wrapper.nom)")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(wrapper.mdp)
                .font(.system(.title2, design: .monospaced, weight: .bold))
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMoyen))
                .textSelection(.enabled)
            Text("L'ancien mot de passe ne fonctionne plus. Partage le nouveau à la personne concernée.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            HStack(spacing: LiquidGlassKit.espaceSM) {
                Button {
                    UIPasteboard.general.string = wrapper.mdp
                } label: {
                    Label("Copier", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
                ShareLink(item: wrapper.mdp) {
                    Label("Partager", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(LiquidGlassKit.espaceLG + 4)
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private func utilisateurPour(_ cred: CredentialAthlete) -> Utilisateur? {
        utilisateurs.first { $0.id == cred.utilisateurID }
    }

    private func templateTexte(cred: CredentialAthlete, user: Utilisateur?) -> String {
        let prenom = user?.prenom ?? ""
        let role = cred.joueurEquipeID == nil ? "Assistant" : "Athlète"
        return """
        Salut \(prenom) ! Voici tes accès Playco :
        Identifiant : \(cred.identifiant)
        Mot de passe : \(cred.motDePasseClair)

        Ouvre l'app Playco, clique « Connexion », choisis « \(role) », puis entre ces infos.
        """
    }

    struct NouveauMdpWrapper: Identifiable {
        let id = UUID()
        let nom: String
        let mdp: String
    }
}
