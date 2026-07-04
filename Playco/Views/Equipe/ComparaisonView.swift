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

    /// Moyennes d'équipe pré-calculées — cache @State (pattern perfo projet) :
    /// évite 12 reduce sur les joueurs à chaque render.
    private struct MoyennesEquipe: Equatable {
        var kills = 0.0
        var hittingPct = 0.0
        var erreursAttaque = 0.0
        var aces = 0.0
        var erreursService = 0.0
        var servicesTotaux = 0.0
        var blocsSeuls = 0.0
        var blocsAssistes = 0.0
        var receptionsReussies = 0.0
        var efficaciteReception = 0.0
        var passesDecisives = 0.0
        var manchettes = 0.0
    }

    @State private var moyennes = MoyennesEquipe()

    /// Invalide le cache sur mutation in-place (stats saisies/modifiées) — .onChange(collection) ne voit que les insertions/suppressions.
    private var signatureStats: Int {
        tousJoueurs.reduce(0) {
            $0 + $1.matchsJoues + $1.attaquesReussies + $1.erreursAttaque + $1.attaquesTotales
                + $1.aces + $1.erreursService + $1.servicesTotaux
                + $1.blocsSeuls + $1.blocsAssistes
                + $1.receptionsReussies + $1.receptionsTotales
                + $1.passesDecisives + $1.manchettes
        }
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
        .onAppear { mettreAJourMoyennes() }
        .onChange(of: tousJoueurs) { mettreAJourMoyennes() }
        .onChange(of: signatureStats) { mettreAJourMoyennes() }
        .onChange(of: codeEquipeActif) { mettreAJourMoyennes() }
    }

    // MARK: - Mise à jour du cache

    private func mettreAJourMoyennes() {
        let equipe = tousJoueurs.filtreEquipe(codeEquipeActif).filter { $0.matchsJoues > 0 }
        let nb = max(1, Double(equipe.count))
        func moyenne(_ valeur: (JoueurEquipe) -> Double) -> Double {
            equipe.reduce(0.0) { $0 + valeur($1) } / nb
        }
        moyennes = MoyennesEquipe(
            kills: moyenne { Double($0.attaquesReussies) },
            hittingPct: moyenne { $0.pourcentageAttaque },
            erreursAttaque: moyenne { Double($0.erreursAttaque) },
            aces: moyenne { Double($0.aces) },
            erreursService: moyenne { Double($0.erreursService) },
            servicesTotaux: moyenne { Double($0.servicesTotaux) },
            blocsSeuls: moyenne { Double($0.blocsSeuls) },
            blocsAssistes: moyenne { Double($0.blocsAssistes) },
            receptionsReussies: moyenne { Double($0.receptionsReussies) },
            efficaciteReception: moyenne { $0.efficaciteReception },
            passesDecisives: moyenne { Double($0.passesDecisives) },
            manchettes: moyenne { Double($0.manchettes) }
        )
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
        [
            ("Kills", Double(joueur.attaquesReussies), moyennes.kills, "%.0f"),
            ("Hitting %", joueur.pourcentageAttaque * 100, moyennes.hittingPct * 100, "%.1f%%"),
            ("Erreurs attaque", Double(joueur.erreursAttaque), moyennes.erreursAttaque, "%.0f"),
        ]
    }

    private var statsService: [(label: String, joueur: Double, equipe: Double, format: String)] {
        [
            ("Aces", Double(joueur.aces), moyennes.aces, "%.0f"),
            ("Erreurs service", Double(joueur.erreursService), moyennes.erreursService, "%.0f"),
            ("Total services", Double(joueur.servicesTotaux), moyennes.servicesTotaux, "%.0f"),
        ]
    }

    private var statsBloc: [(label: String, joueur: Double, equipe: Double, format: String)] {
        [
            ("Blocs seuls", Double(joueur.blocsSeuls), moyennes.blocsSeuls, "%.0f"),
            ("Blocs assistés", Double(joueur.blocsAssistes), moyennes.blocsAssistes, "%.0f"),
        ]
    }

    private var statsReception: [(label: String, joueur: Double, equipe: Double, format: String)] {
        [
            ("Réceptions réussies", Double(joueur.receptionsReussies), moyennes.receptionsReussies, "%.0f"),
            ("Efficacité réception", joueur.efficaciteReception * 100, moyennes.efficaciteReception * 100, "%.1f%%"),
        ]
    }

    private var statsJeu: [(label: String, joueur: Double, equipe: Double, format: String)] {
        [
            ("Passes décisives", Double(joueur.passesDecisives), moyennes.passesDecisives, "%.0f"),
            ("Manchettes", Double(joueur.manchettes), moyennes.manchettes, "%.0f"),
        ]
    }
}
