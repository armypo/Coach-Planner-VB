//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Comparaison des stats d'un joueur vs la moyenne de l'équipe
struct ComparaisonView: View {
    let joueur: JoueurEquipe

    @Query(filter: #Predicate<JoueurEquipe> { $0.estActif == true },
           sort: \JoueurEquipe.numero) private var tousJoueurs: [JoueurEquipe]
    @Environment(\.codeEquipeActif) private var codeEquipeActif

    private var joueursEquipe: [JoueurEquipe] {
        tousJoueurs.filtreEquipe(codeEquipeActif).filter { $0.matchsJoues > 0 }
    }

    private var nbJoueurs: Double {
        max(1, Double(joueursEquipe.count))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // En-tête joueur
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.1))
                            .frame(width: 50, height: 50)
                        Text("#\(joueur.numero)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.red)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(joueur.prenom) \(joueur.nom)")
                            .font(.headline)
                        Text(joueur.poste.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(joueur.matchsJoues) matchs")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                Divider()

                // Catégories de stats
                categorieSection(titre: "Attaque", icone: "flame.fill", couleur: .red, stats: statsAttaque)
                categorieSection(titre: "Service", icone: "arrow.up.forward", couleur: .blue, stats: statsService)
                categorieSection(titre: "Bloc", icone: "shield.fill", couleur: .purple, stats: statsBloc)
                categorieSection(titre: "Réception", icone: "hand.raised.fill", couleur: .green, stats: statsReception)
                categorieSection(titre: "Jeu", icone: "sportscourt.fill", couleur: .orange, stats: statsJeu)
            }
            .padding(.vertical)
        }
        .navigationTitle("Comparaison")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Section catégorie

    private func categorieSection(titre: String, icone: String, couleur: Color, stats: [(label: String, joueur: Double, equipe: Double, format: String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icone)
                    .font(.caption)
                    .foregroundStyle(couleur)
                Text(titre.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
            }
            .padding(.horizontal)

            ForEach(stats, id: \.label) { stat in
                barreComparaison(label: stat.label, valeurJoueur: stat.joueur, moyenneEquipe: stat.equipe, format: stat.format, couleur: couleur)
            }
        }
    }

    private func barreComparaison(label: String, valeurJoueur: Double, moyenneEquipe: Double, format: String, couleur: Color) -> some View {
        let maxVal = max(valeurJoueur, moyenneEquipe, 0.01)
        let ratioJoueur = valeurJoueur / maxVal
        let ratioEquipe = moyenneEquipe / maxVal
        let estAuDessus = valeurJoueur >= moyenneEquipe

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption.weight(.medium))
                Spacer()
                // Indicateur
                Image(systemName: estAuDessus ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(estAuDessus ? .green : .red)
            }

            // Barre joueur
            HStack(spacing: 8) {
                Text("Joueur")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .leading)
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(couleur)
                        .frame(width: max(4, geo.size.width * ratioJoueur))
                }
                .frame(height: 10)
                Text(String(format: format, valeurJoueur))
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .frame(width: 44, alignment: .trailing)
            }

            // Barre moyenne
            HStack(spacing: 8) {
                Text("Moy.")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .frame(width: 44, alignment: .leading)
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray4))
                        .frame(width: max(4, geo.size.width * ratioEquipe))
                }
                .frame(height: 10)
                Text(String(format: format, moyenneEquipe))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    // MARK: - Données comparatives

    private var statsAttaque: [(label: String, joueur: Double, equipe: Double, format: String)] {
        let moyKills = joueursEquipe.reduce(0.0) { $0 + Double($1.attaquesReussies) } / nbJoueurs
        let moyHit = joueursEquipe.reduce(0.0) { $0 + $1.pourcentageAttaque } / nbJoueurs
        let moyErr = joueursEquipe.reduce(0.0) { $0 + Double($1.erreursAttaque) } / nbJoueurs
        return [
            ("Kills", Double(joueur.attaquesReussies), moyKills, "%.0f"),
            ("Hitting %", joueur.pourcentageAttaque * 100, moyHit * 100, "%.1f%%"),
            ("Erreurs attaque", Double(joueur.erreursAttaque), moyErr, "%.0f"),
        ]
    }

    private var statsService: [(label: String, joueur: Double, equipe: Double, format: String)] {
        let moyAces = joueursEquipe.reduce(0.0) { $0 + Double($1.aces) } / nbJoueurs
        let moyErr = joueursEquipe.reduce(0.0) { $0 + Double($1.erreursService) } / nbJoueurs
        let moyTotal = joueursEquipe.reduce(0.0) { $0 + Double($1.servicesTotaux) } / nbJoueurs
        return [
            ("Aces", Double(joueur.aces), moyAces, "%.0f"),
            ("Erreurs service", Double(joueur.erreursService), moyErr, "%.0f"),
            ("Total services", Double(joueur.servicesTotaux), moyTotal, "%.0f"),
        ]
    }

    private var statsBloc: [(label: String, joueur: Double, equipe: Double, format: String)] {
        let moySeuls = joueursEquipe.reduce(0.0) { $0 + Double($1.blocsSeuls) } / nbJoueurs
        let moyAss = joueursEquipe.reduce(0.0) { $0 + Double($1.blocsAssistes) } / nbJoueurs
        return [
            ("Blocs seuls", Double(joueur.blocsSeuls), moySeuls, "%.0f"),
            ("Blocs assistés", Double(joueur.blocsAssistes), moyAss, "%.0f"),
        ]
    }

    private var statsReception: [(label: String, joueur: Double, equipe: Double, format: String)] {
        let moyReussies = joueursEquipe.reduce(0.0) { $0 + Double($1.receptionsReussies) } / nbJoueurs
        let moyEff = joueursEquipe.reduce(0.0) { $0 + $1.efficaciteReception } / nbJoueurs
        return [
            ("Réceptions réussies", Double(joueur.receptionsReussies), moyReussies, "%.0f"),
            ("Efficacité réception", joueur.efficaciteReception * 100, moyEff * 100, "%.1f%%"),
        ]
    }

    private var statsJeu: [(label: String, joueur: Double, equipe: Double, format: String)] {
        let moyPasses = joueursEquipe.reduce(0.0) { $0 + Double($1.passesDecisives) } / nbJoueurs
        let moyManch = joueursEquipe.reduce(0.0) { $0 + Double($1.manchettes) } / nbJoueurs
        return [
            ("Passes décisives", Double(joueur.passesDecisives), moyPasses, "%.0f"),
            ("Manchettes", Double(joueur.manchettes), moyManch, "%.0f"),
        ]
    }
}
