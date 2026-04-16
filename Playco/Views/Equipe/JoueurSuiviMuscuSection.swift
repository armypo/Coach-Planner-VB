//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Section suivi musculation + tests physiques du joueur — extraite de JoueurDetailView
/// pour respecter la limite de 800 lignes par fichier
struct JoueurSuiviMuscuSection: View {
    let joueur: JoueurEquipe

    @Query(sort: \SeanceMuscu.date, order: .reverse) private var toutesSeancesMuscu: [SeanceMuscu]
    @Query(filter: #Predicate<ProgrammeMuscu> { $0.estArchive == false }) private var tousProgrammes: [ProgrammeMuscu]
    @Query(sort: \TestPhysique.date, order: .reverse) private var tousTests: [TestPhysique]

    private var seancesMusculationJoueur: [SeanceMuscu] {
        toutesSeancesMuscu.filter { $0.joueurID == joueur.id && $0.estTerminee }
    }

    private var nbProgrammesAssignes: Int {
        tousProgrammes.filter { $0.decoderJoueursAssignes().contains(joueur.id) }.count
    }

    private var testsJoueur: [TestPhysique] {
        tousTests.filter { $0.joueurID == joueur.id }
    }

    var body: some View {
        VStack(spacing: LiquidGlassKit.espaceLG) {
            sectionSuiviMuscu
            sectionTestsPhysiques
        }
    }

    // MARK: - Suivi musculation

    private var sectionSuiviMuscu: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Suivi musculation", systemImage: "dumbbell.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PaletteMat.violet)

            HStack(spacing: 16) {
                CarteChiffreCle(titre: "Programmes", valeur: "\(nbProgrammesAssignes)", icone: "dumbbell", couleur: PaletteMat.violet)
                CarteChiffreCle(titre: "Séances", valeur: "\(seancesMusculationJoueur.count)", icone: "checkmark.circle", couleur: .green)

                if let derniere = seancesMusculationJoueur.first {
                    CarteChiffreCle(titre: "Dernière", valeur: derniere.date.formatCourt(), icone: "calendar", couleur: .blue)
                }
            }

            NavigationLink {
                SuiviMusculationView(joueur: joueur)
            } label: {
                HStack {
                    Text("Voir le suivi complet")
                        .font(.caption.weight(.medium))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .foregroundStyle(PaletteMat.violet)
                .padding(12)
                .background(PaletteMat.violet.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .glassSection()
    }

    // MARK: - Tests physiques

    private var sectionTestsPhysiques: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Tests physiques", systemImage: "gauge.with.needle.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.orange)

            if testsJoueur.isEmpty {
                Text("Aucun test enregistré")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                let derniers = derniersResultatsTests()
                HStack(spacing: 16) {
                    ForEach(derniers.prefix(3), id: \.0) { type, test in
                        CarteChiffreCle(
                            titre: type.label,
                            valeur: type == .sprintTime ? String(format: "%.2f", test.valeur) : "\(Int(test.valeur))",
                            icone: type.icone,
                            couleur: type.couleur
                        )
                    }
                }
            }

            NavigationLink {
                TestsPhysiquesView(joueur: joueur)
            } label: {
                HStack {
                    Text("Voir tous les tests")
                        .font(.caption.weight(.medium))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .foregroundStyle(.orange)
                .padding(12)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .glassSection()
    }

    private func derniersResultatsTests() -> [(TypeTestPhysique, TestPhysique)] {
        var resultats: [TypeTestPhysique: TestPhysique] = [:]
        for test in testsJoueur where resultats[test.typeTest] == nil {
            resultats[test.typeTest] = test
        }
        return TypeTestPhysique.allCases.compactMap { type in
            guard let test = resultats[type] else { return nil }
            return (type, test)
        }
    }

}
