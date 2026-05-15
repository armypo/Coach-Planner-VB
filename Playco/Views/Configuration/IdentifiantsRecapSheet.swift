//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  IdentifiantsRecapSheet — sheet bloquante affichée à la fin du wizard
//  pour récapituler les identifiants/mdp créés. Permet de copier/partager.
//

import SwiftUI

/// Récapitulatif d'un credential créé pendant le wizard.
struct CredentialRecap: Identifiable {
    let id = UUID()
    let nomComplet: String
    let identifiant: String
    let motDePasse: String
    /// "Athlète" ou "Assistant" — utilisé dans le template de partage.
    let role: String
}

struct IdentifiantsRecapSheet: View {
    let creds: [CredentialRecap]
    let onFermer: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Note ces identifiants maintenant", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)

                    Text("Tu pourras aussi les retrouver dans Paramètres → Identifiants de l'équipe.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if creds.isEmpty {
                        ContentUnavailableView(
                            "Aucun identifiant à afficher",
                            systemImage: "person.crop.circle.badge.questionmark",
                            description: Text("Tu n'as ajouté ni joueur ni assistant.")
                        )
                        .padding(.top, 40)
                    } else {
                        ForEach(creds) { cred in
                            carteCredential(cred)
                        }

                        if creds.count > 1 {
                            ShareLink(item: tousLesCreds()) {
                                Label("Tout partager", systemImage: "square.and.arrow.up.on.square")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(PaletteMat.bleu.opacity(0.1), in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMoyen))
                            }
                            .foregroundStyle(PaletteMat.bleu)
                            .padding(.top, LiquidGlassKit.espaceSM)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Identifiants créés")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button {
                    onFermer()
                } label: {
                    Label("J'ai noté mes identifiants", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PaletteMat.orange, in: Capsule())
                        .foregroundStyle(.white)
                        .font(.headline)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.regularMaterial)
            }
        }
    }

    private func carteCredential(_ cred: CredentialRecap) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(cred.nomComplet)
                    .font(.headline)
                Spacer()
                Text(cred.role)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(cred.role == "Athlète" ? PaletteMat.orange : PaletteMat.bleu)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        (cred.role == "Athlète" ? PaletteMat.orange : PaletteMat.bleu).opacity(0.12),
                        in: Capsule()
                    )
            }

            ligneCredentialDetail(label: "Identifiant", valeur: cred.identifiant, icone: "person.text.rectangle")
            ligneCredentialDetail(label: "Mot de passe", valeur: cred.motDePasse, icone: "key.fill")

            HStack(spacing: 10) {
                Button {
                    UIPasteboard.general.string = """
                    Identifiant : \(cred.identifiant)
                    Mot de passe : \(cred.motDePasse)
                    """
                } label: {
                    Label("Copier", systemImage: "doc.on.doc")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)

                ShareLink(item: templatePartage(cred: cred)) {
                    Label("Partager", systemImage: "square.and.arrow.up")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: LiquidGlassKit.rayonMoyen)
    }

    private func ligneCredentialDetail(label: String, valeur: String, icone: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icone)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text("\(label) :")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(valeur)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
            Spacer()
        }
    }

    private func templatePartage(cred: CredentialRecap) -> String {
        """
        Salut ! Voici tes accès Playco :
        Identifiant : \(cred.identifiant)
        Mot de passe : \(cred.motDePasse)

        Ouvre l'app Playco, choisis « Connexion », sélectionne l'onglet « \(cred.role) », puis entre ces infos.
        """
    }

    private func tousLesCreds() -> String {
        creds.map { cred in
            """
            \(cred.nomComplet) (\(cred.role))
            Identifiant : \(cred.identifiant)
            Mot de passe : \(cred.motDePasse)
            """
        }.joined(separator: "\n\n")
    }
}
