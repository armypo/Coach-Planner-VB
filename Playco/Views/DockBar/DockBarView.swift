//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI

/// Données d'un item du dock
private struct DockItem: Identifiable {
    let id: String
    let label: String
    let icone: String
    let couleur: Color
    var section: SectionApp?
}

/// Dock bar flottant — style cohérent avec l'app (material + ombres subtiles)
struct DockBarView: View {
    @Binding var sectionActive: SectionApp?
    var badgeMessages: Bool = false       // V5 : point rouge sur Messages
    var badgeSeanceAujourdhui: Bool = false // V5 : point orange sur Profil
    var onMessages: (() -> Void)?
    var onProfil: (() -> Void)?
    var onRecherche: (() -> Void)?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass // V4
    @Environment(\.couleurRole) private var couleurRole             // V1
    @Environment(AuthService.self) private var authService
    @Environment(CloudKitSyncService.self) private var syncService

    @State private var indexActif: Int? = nil
    @State private var estVisible: Bool = false

    private var estCompact: Bool { horizontalSizeClass != .regular }
    // V4 : iPhone en paysage = très compact
    private var estPaysagePhone: Bool { estCompact && verticalSizeClass == .compact }

    private var items: [DockItem] {
        [
            DockItem(id: "recherche", label: "Recherche", icone: "magnifyingglass",
                     couleur: PaletteMat.orange, section: nil),
            DockItem(id: "messages", label: "Messages", icone: "bubble.left.and.bubble.right.fill",
                     couleur: PaletteMat.violet, section: nil),
            DockItem(id: "profil", label: "Profil", icone: "person.circle.fill",
                     couleur: PaletteMat.bleu, section: nil),
        ]
    }

    var body: some View {
        VStack {
            Spacer()

            HStack(spacing: estPaysagePhone ? 12 : (estCompact ? 16 : 24)) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    boutonItem(item: item, index: index)
                }
            }
            .padding(.horizontal, estPaysagePhone ? 20 : (estCompact ? 24 : 32))
            .padding(.vertical, estPaysagePhone ? 8 : (estCompact ? 12 : 16))
            .background {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.08), radius: 20, y: 8)
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                    }
            }
            // Animation d'entrée
            .offset(y: estVisible ? 0 : 80)
            .opacity(estVisible ? 1 : 0)
            // V4 : padding réduit sur iPhone paysage
            .padding(.bottom, estPaysagePhone ? 6 : (estCompact ? 8 : 24))
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                estVisible = true
            }
        }
    }

    // MARK: - Bouton item

    private func boutonItem(item: DockItem, index: Int) -> some View {
        let estActif = indexActif == index
        let couleurUtilisateur = authService.utilisateurConnecte?.role.couleur

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                indexActif = index
            }

            if item.id == "recherche" {
                onRecherche?()
            } else if item.id == "messages" {
                onMessages?()
            } else if item.id == "profil" {
                onProfil?()
            }

            // Reset après un court délai
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.2)) {
                    indexActif = nil
                }
            }
        } label: {
            VStack(spacing: estPaysagePhone ? 2 : 5) {
                ZStack {
                    // Fond cercle au tap
                    Circle()
                        .fill((item.id == "profil" ? (couleurUtilisateur ?? item.couleur) : item.couleur).opacity(estActif ? 0.15 : 0))
                        .frame(width: estCompact ? 44 : 52, height: estCompact ? 44 : 52)

                    // Photo de profil ou icône
                    if item.id == "profil",
                       let utilisateur = authService.utilisateurConnecte,
                       let photoData = utilisateur.photoData,
                       let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: estCompact ? 32 : 38, height: estCompact ? 32 : 38)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(couleurUtilisateur ?? item.couleur, lineWidth: 2)
                            )
                    } else {
                        Image(systemName: item.icone)
                            .font(.system(size: estCompact ? 22 : 26, weight: .medium))
                            .foregroundStyle(
                                item.id == "profil" ? (couleurUtilisateur ?? item.couleur) : item.couleur
                            )
                            .symbolRenderingMode(.hierarchical)
                    }
                }
                // V5 : Badge notification
                .overlay(alignment: .topTrailing) {
                    if item.id == "messages" && badgeMessages {
                        Circle()
                            .fill(.red)
                            .frame(width: 10, height: 10)
                            .offset(x: 4, y: -4)
                    }
                    if item.id == "profil" && badgeSeanceAujourdhui {
                        Circle()
                            .fill(.orange)
                            .frame(width: 10, height: 10)
                            .offset(x: 4, y: -4)
                    }
                }

                // V4 : cacher labels en paysage iPhone
                if !estPaysagePhone {
                    Text(item.id == "profil" ? (authService.utilisateurConnecte?.prenom ?? "Profil") : item.label)
                        .font(.system(size: estCompact ? 10 : 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .scaleEffect(estActif ? 1.12 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: estActif)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}
