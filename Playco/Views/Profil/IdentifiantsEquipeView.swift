//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  IdentifiantsEquipeView — liste des credentials athlètes/assistants de l'équipe
//  active, accessible via Paramètres → Organisation. Permet de copier, partager
//  et régénérer le mdp d'un membre.
//

import SwiftUI
import SwiftData

struct IdentifiantsEquipeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Environment(AuthService.self) private var authService

    @Query private var credentials: [CredentialAthlete]
    @Query private var utilisateurs: [Utilisateur]

    @State private var afficherNouveauMdp: NouveauMdpWrapper? = nil

    private var credsFiltres: [CredentialAthlete] {
        credentials.filtreEquipe(codeEquipeActif)
    }

    private var athletes: [CredentialAthlete] {
        credsFiltres.filter { $0.joueurEquipeID != nil }
    }

    private var assistantsList: [CredentialAthlete] {
        credsFiltres.filter { $0.joueurEquipeID == nil }
    }

    var body: some View {
        Group {
            if credsFiltres.isEmpty {
                ContentUnavailableView(
                    "Aucun identifiant",
                    systemImage: "key.slash",
                    description: Text("Les identifiants des athlètes et assistants créés via le wizard ou Paramètres apparaîtront ici.")
                )
            } else {
                List {
                    if !athletes.isEmpty {
                        Section("Athlètes (\(athletes.count))") {
                            ForEach(athletes) { cred in
                                ligneCredential(cred)
                            }
                        }
                    }
                    if !assistantsList.isEmpty {
                        Section("Assistants (\(assistantsList.count))") {
                            ForEach(assistantsList) { cred in
                                ligneCredential(cred)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Identifiants de l'équipe")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $afficherNouveauMdp) { wrapper in
            nouveauMdpSheet(wrapper: wrapper)
        }
    }

    // MARK: - Ligne credential

    private func ligneCredential(_ cred: CredentialAthlete) -> some View {
        let user = utilisateurs.first { $0.id == cred.utilisateurID }
        let role = cred.joueurEquipeID == nil ? "Assistant" : "Athlète"
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(user?.nomComplet ?? "—")
                    .font(.headline)
                Spacer()
                Text(role)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(role == "Athlète" ? PaletteMat.orange : PaletteMat.bleu)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        (role == "Athlète" ? PaletteMat.orange : PaletteMat.bleu).opacity(0.12),
                        in: Capsule()
                    )
            }
            HStack(spacing: 8) {
                Text("ID :").font(.caption).foregroundStyle(.secondary)
                Text(cred.identifiant)
                    .font(.system(.caption, design: .monospaced))
                Spacer()
                Button {
                    UIPasteboard.general.string = cred.identifiant
                } label: {
                    Image(systemName: "doc.on.doc").font(.caption)
                }
                .buttonStyle(.borderless)
            }
            HStack(spacing: 8) {
                Text("Mdp :").font(.caption).foregroundStyle(.secondary)
                Text(cred.motDePasseClair)
                    .font(.system(.caption, design: .monospaced))
                Spacer()
                Button {
                    UIPasteboard.general.string = cred.motDePasseClair
                } label: {
                    Image(systemName: "doc.on.doc").font(.caption)
                }
                .buttonStyle(.borderless)
            }
            HStack(spacing: 10) {
                Button {
                    regenererMdp(cred: cred, user: user)
                } label: {
                    Label("Régénérer mdp", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                Spacer()
                ShareLink(item: templatePartage(cred: cred, user: user, role: role)) {
                    Label("Partager", systemImage: "square.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Régénération mdp

    private func regenererMdp(cred: CredentialAthlete, user: Utilisateur?) {
        guard let user = user else { return }
        let nouveauMdp = Utilisateur.genererMotDePasseAthlete()
        let nouveauSel = authService.genererSel()
        user.sel = nouveauSel
        user.motDePasseHash = authService.hashMotDePasse(nouveauMdp, sel: nouveauSel)
        user.iterations = AuthService.iterationsParDefaut
        cred.motDePasseClair = nouveauMdp
        cred.dateModification = Date()
        try? modelContext.save()
        afficherNouveauMdp = NouveauMdpWrapper(nom: user.nomComplet, mdp: nouveauMdp)
    }

    // MARK: - Sheet nouveau mdp

    private func nouveauMdpSheet(wrapper: NouveauMdpWrapper) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "key.fill")
                .font(.system(size: 60))
                .foregroundStyle(PaletteMat.orange)
            Text("Nouveau mot de passe pour \(wrapper.nom)")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Text(wrapper.mdp)
                .font(.system(.title2, design: .monospaced, weight: .bold))
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            Text("L'ancien mot de passe ne fonctionne plus. Partage le nouveau à la personne concernée.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            HStack(spacing: 12) {
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
        .padding(24)
        .presentationDetents([.medium])
    }

    // MARK: - Template de partage

    private func templatePartage(cred: CredentialAthlete, user: Utilisateur?, role: String) -> String {
        let prenom = user?.prenom ?? ""
        return """
        Salut \(prenom) ! Voici tes accès Playco :
        Identifiant : \(cred.identifiant)
        Mot de passe : \(cred.motDePasseClair)

        Ouvre l'app Playco, choisis « Connexion », sélectionne l'onglet « \(role) », puis entre ces infos.
        """
    }

    // MARK: - Wrapper Sheet item

    struct NouveauMdpWrapper: Identifiable {
        let id = UUID()
        let nom: String
        let mdp: String
    }
}
