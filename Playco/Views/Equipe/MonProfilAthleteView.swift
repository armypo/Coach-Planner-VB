//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Vue Mon Profil pour les athlètes — remplace Équipe quand l'utilisateur est étudiant
struct MonProfilAthleteView: View {
    var onRetour: () -> Void

    @Environment(AuthService.self) private var authService
    @Query(sort: \JoueurEquipe.nom) private var joueurs: [JoueurEquipe]

    private var monJoueur: JoueurEquipe? {
        guard let joueurID = authService.utilisateurConnecte?.joueurEquipeID else { return nil }
        return joueurs.first { $0.id == joueurID }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let joueur = monJoueur {
                    JoueurDetailView(joueur: joueur)
                } else {
                    etatVide
                }
            }
            .navigationTitle("Mon profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    boutonRetour
                }
            }
        }
    }

    private var etatVide: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.circle")
                .font(.system(size: 60, weight: .thin))
                .foregroundStyle(.tertiary)
            Text("Profil non lié")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
            Text("Votre compte n'est pas encore associé à un joueur de l'équipe.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var boutonRetour: some View {
        Button {
            onRetour()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                Image(systemName: "volleyball.fill")
                    .font(.system(size: 14))
                Text("Accueil")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(PaletteMat.vert)
        }
    }
}
