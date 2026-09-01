//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  IdentifiantsEquipeView — codes d'invitation des ASSISTANTS de l'équipe
//  active, accessible via Paramètres → Organisation. Permet de copier, partager
//  et régénérer le code d'un assistant. (Pivot coach-first : plus de comptes
//  athlètes — la grille QR projetable « Inviter l'équipe » a disparu avec eux.)
//

import SwiftUI
import SwiftData

struct IdentifiantsEquipeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Environment(AuthService.self) private var authService
    @Environment(CloudKitSharingService.self) private var sharingService

    @Query private var credentials: [CredentialAthlete]
    @Query private var utilisateurs: [Utilisateur]

    @State private var afficherNouveauMdp: NouveauMdpWrapper? = nil

    private var credsFiltres: [CredentialAthlete] {
        credentials.filtreEquipe(codeEquipeActif)
    }

    /// Marqueurs d'assistants (joueurEquipeID == nil). Les anciens marqueurs
    /// athlètes (joueurEquipeID != nil) peuvent subsister en base — ignorés.
    private var assistantsList: [CredentialAthlete] {
        credsFiltres.filter { $0.joueurEquipeID == nil }
    }

    var body: some View {
        Group {
            if assistantsList.isEmpty {
                ContentUnavailableView(
                    "Aucun identifiant",
                    systemImage: "key.slash",
                    description: Text("Les codes d'invitation des assistants créés via le wizard ou Paramètres apparaîtront ici.")
                )
            } else {
                List {
                    Section("Assistants (\(assistantsList.count))") {
                        ForEach(assistantsList) { cred in
                            ligneCredential(cred)
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
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(user?.nomComplet ?? "—")
                    .font(.headline)
                Spacer()
                Text("Assistant")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PaletteMat.bleu)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(PaletteMat.bleu.opacity(0.12), in: Capsule())
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
                Text("Équipe :").font(.caption).foregroundStyle(.secondary)
                Text(codeEquipeActif)
                    .font(.system(.caption, design: .monospaced))
                Spacer()
                Button {
                    UIPasteboard.general.string = codeEquipeActif
                } label: {
                    Image(systemName: "doc.on.doc").font(.caption)
                }
                .buttonStyle(.borderless)
            }
            HStack(spacing: 8) {
                Text("Invitation :").font(.caption).foregroundStyle(.secondary)
                Text(user?.codeInvitation ?? "—")
                    .font(.system(.caption, design: .monospaced))
                Spacer()
                Button {
                    UIPasteboard.general.string = user?.codeInvitation ?? ""
                } label: {
                    Image(systemName: "doc.on.doc").font(.caption)
                }
                .buttonStyle(.borderless)
            }
            HStack(spacing: 10) {
                // Durcissement posture A (E′ résidu) : régénérer le code d'un
                // assistant DÉJÀ rattaché casserait sa chaîne de confiance (ses
                // records deviendraient inertes chez les autres coachs) — et il
                // n'en a plus besoin. Régénération réservée aux lignes non réclamées.
                if user?.appleUserID.isEmpty == false {
                    Label("Rattaché — code désormais inutile", systemImage: "checkmark.seal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        regenererCodeInvitation(user: user)
                    } label: {
                        Label("Régénérer le code", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
                ShareLink(item: templatePartage(cred: cred, user: user)) {
                    Label("Partager", systemImage: "square.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Régénération du code d'invitation

    /// Génère un nouveau code d'invitation (ex: si l'ancien a fuité avant la jointure)
    /// et republie le mapping vers CloudKit public pour qu'il soit réclamable.
    private func regenererCodeInvitation(user: Utilisateur?) {
        // Défense en profondeur : jamais sur une ligne déjà rattachée (cf. UI).
        guard let user = user, user.appleUserID.isEmpty else { return }
        let nouveauCode = Utilisateur.genererCodeUniqueInvitation(context: modelContext)
        user.codeInvitation = nouveauCode
        user.dateModification = Date()
        try? modelContext.save()
        let code = codeEquipeActif
        sharingService.ecrivainID = authService.utilisateurConnecte?.id.uuidString
        Task { await sharingService.publierNouvelUtilisateur(user, joueur: nil, codeEquipe: code) }
        afficherNouveauMdp = NouveauMdpWrapper(nom: user.nomComplet, mdp: nouveauCode)
    }

    // MARK: - Sheet nouveau code d'invitation

    private func nouveauMdpSheet(wrapper: NouveauMdpWrapper) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "ticket.fill")
                .font(.system(size: 60))
                .foregroundStyle(PaletteMat.orange)
            Text("Nouveau code d'invitation pour \(wrapper.nom)")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Text(wrapper.mdp)
                .font(.system(.title2, design: .monospaced, weight: .bold))
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            Text("L'ancien code ne fonctionne plus. Partage le nouveau code (avec le code d'équipe) à la personne concernée.")
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
        .padding(LiquidGlassKit.espaceLG)
        .presentationDetents([.medium])
    }

    // MARK: - Template de partage

    private func templatePartage(cred: CredentialAthlete, user: Utilisateur?) -> String {
        let prenom = user?.prenom ?? ""
        let invitation = user?.codeInvitation ?? ""
        return """
        Salut \(prenom) ! Voici comment rejoindre l'équipe sur Playco :
        Code d'équipe : \(codeEquipeActif)
        Code d'invitation : \(invitation)

        Ouvre l'app Playco, appuie sur « Se connecter avec Apple », puis « Rejoindre mon équipe » et entre ces deux codes.
        """
    }

    // MARK: - Wrapper Sheet item

    /// `mdp` contient désormais le code d'invitation (nom historique conservé).
    struct NouveauMdpWrapper: Identifiable {
        let id = UUID()
        let nom: String
        let mdp: String
    }
}
