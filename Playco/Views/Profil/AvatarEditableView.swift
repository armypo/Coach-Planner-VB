//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData
import PhotosUI

/// Avatar avec possibilité de changer la photo (coach seulement)
struct AvatarEditableView: View {
    @Bindable var utilisateur: Utilisateur
    var taille: CGFloat = 80
    var editable: Bool = true

    @Environment(\.modelContext) private var modelContext
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Photo ou initiales
            if let photoData = utilisateur.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: taille, height: taille)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(utilisateur.role.couleur.opacity(0.08))
                    .frame(width: taille, height: taille)
                    .overlay(
                        Text(initiales)
                            .font(.system(size: taille * 0.35, weight: .bold))
                            .foregroundStyle(utilisateur.role.couleur)
                    )
            }

            // Bouton caméra (si éditable)
            if editable {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Image(systemName: "camera.circle.fill")
                        .font(.system(size: taille * 0.3))
                        .foregroundStyle(.white)
                        .background(
                            Circle()
                                .fill(utilisateur.role.couleur)
                                .frame(width: taille * 0.32, height: taille * 0.32)
                        )
                }
                .offset(x: 2, y: 2)
            }
        }
        .onChange(of: photoItem) { _, nouveau in
            Task {
                if let nouveau,
                   let data = try? await nouveau.loadTransferable(type: Data.self) {
                    // Compresser l'image
                    if let uiImage = UIImage(data: data),
                       let compressed = uiImage.jpegData(compressionQuality: 0.6) {
                        utilisateur.photoData = compressed
                        // Synchroniser la photo vers JoueurEquipe lié
                        if let joueurID = utilisateur.joueurEquipeID {
                            let descriptor = FetchDescriptor<JoueurEquipe>(
                                predicate: #Predicate { $0.id == joueurID }
                            )
                            if let joueur = try? modelContext.fetch(descriptor).first {
                                joueur.photoData = compressed
                            }
                        }
                        try? modelContext.save()
                    }
                }
            }
        }
    }

    private var initiales: String {
        let p = utilisateur.prenom.prefix(1).uppercased()
        let n = utilisateur.nom.prefix(1).uppercased()
        return "\(p)\(n)"
    }
}

/// Avatar lecture seule (pour les élèves qui voient leur propre profil)
struct AvatarView: View {
    let utilisateur: Utilisateur
    var taille: CGFloat = 100

    var body: some View {
        if let photoData = utilisateur.photoData,
           let uiImage = UIImage(data: photoData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: taille, height: taille)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(utilisateur.role.couleur.opacity(0.08))
                .frame(width: taille, height: taille)
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                )
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: taille * 0.4))
                        .foregroundStyle(utilisateur.role.couleur)
                )
        }
    }
}
