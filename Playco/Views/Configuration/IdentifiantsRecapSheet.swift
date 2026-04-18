//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI

/// Sheet bloquante affichée après la création d'athlètes / assistants.
/// Le coach doit explicitement fermer via « J'ai noté mes credentials »
/// — `interactiveDismissDisabled(true)` sur la présentation parente évite
/// qu'il la balaye sans voir les mots de passe générés.
struct IdentifiantsRecapSheet: View {
    let creds: [CredentialRecap]
    let onFermer: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LiquidGlassKit.espaceLG) {
                    avertissement

                    Text("Tu pourras aussi les retrouver dans Paramètres → Identifiants de l'équipe.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let texte = texteAPartagerGlobal {
                        ShareLink(item: texte) {
                            Label("Tout partager", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                    }

                    ForEach(creds) { cred in
                        carteCredential(cred)
                    }
                }
                .padding(LiquidGlassKit.espaceLG)
            }
            .navigationTitle("Identifiants créés")
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        onFermer()
                    } label: {
                        Label("J'ai noté mes credentials", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(PaletteMat.orange, in: Capsule())
                            .foregroundStyle(.white)
                            .font(.headline)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var avertissement: some View {
        Label("Note ces identifiants maintenant", systemImage: "exclamationmark.triangle.fill")
            .font(.headline)
            .foregroundStyle(.orange)
    }

    private var texteAPartagerGlobal: String? {
        guard !creds.isEmpty else { return nil }
        let lignes = creds.map { cred in
            "• \(cred.nomComplet) (\(cred.role)) — \(cred.identifiant) / \(cred.motDePasse)"
        }
        return "Accès Playco de l'équipe :\n" + lignes.joined(separator: "\n")
    }

    private func carteCredential(_ cred: CredentialRecap) -> some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            HStack {
                Text(cred.nomComplet).font(.headline)
                Spacer()
                Text(cred.role)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(couleurRole(cred.role))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(couleurRole(cred.role).opacity(0.12), in: Capsule())
            }

            ligneCredential(
                icone: "person.text.rectangle",
                titre: "Identifiant",
                valeur: cred.identifiant
            )
            ligneCredential(
                icone: "key.fill",
                titre: "Mot de passe",
                valeur: cred.motDePasse
            )

            HStack(spacing: LiquidGlassKit.espaceSM) {
                Button {
                    UIPasteboard.general.string = "Identifiant: \(cred.identifiant)\nMot de passe: \(cred.motDePasse)"
                } label: {
                    Label("Copier", systemImage: "doc.on.doc").font(.caption)
                }
                .buttonStyle(.bordered)

                ShareLink(item: texteIndividuel(cred)) {
                    Label("Partager", systemImage: "square.and.arrow.up").font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(LiquidGlassKit.espaceMD)
        .glassCard(cornerRadius: LiquidGlassKit.rayonMoyen)
    }

    private func ligneCredential(icone: String, titre: String, valeur: String) -> some View {
        HStack(spacing: LiquidGlassKit.espaceSM) {
            Image(systemName: icone)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text("\(titre) :")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(valeur)
                .font(.system(.callout, design: .monospaced, weight: .semibold))
                .textSelection(.enabled)
            Spacer()
        }
    }

    private func couleurRole(_ role: String) -> Color {
        switch role {
        case "Athlète": return PaletteMat.orange
        case "Assistant": return PaletteMat.bleu
        default: return .secondary
        }
    }

    private func texteIndividuel(_ cred: CredentialRecap) -> String {
        """
        Salut \(cred.nomComplet) ! Voici tes accès Playco :
        Identifiant : \(cred.identifiant)
        Mot de passe : \(cred.motDePasse)

        Ouvre l'app Playco, clique « Connexion », choisis « \(cred.role) », puis entre ces infos.
        """
    }
}
