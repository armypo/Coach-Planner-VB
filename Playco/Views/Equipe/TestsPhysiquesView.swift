//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData
import Charts

/// Tests physiques d'un joueur — ajout, résultats, graphique évolution
struct TestsPhysiquesView: View {
    let joueur: JoueurEquipe

    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Query(sort: \TestPhysique.date, order: .reverse) private var tousTests: [TestPhysique]

    @State private var afficherAjout = false
    @State private var typeGraphique: TypeTestPhysique = .squat1RM

    private var testsJoueur: [TestPhysique] {
        tousTests.filter { $0.joueurID == joueur.id }
    }

    /// Dernier résultat par type de test
    private var derniersResultats: [(TypeTestPhysique, TestPhysique)] {
        var resultats: [TypeTestPhysique: TestPhysique] = [:]
        for test in testsJoueur {
            if resultats[test.typeTest] == nil {
                resultats[test.typeTest] = test
            }
        }
        return TypeTestPhysique.allCases.compactMap { type in
            guard let test = resultats[type] else { return nil }
            return (type, test)
        }
    }

    /// Tests pour le graphique, triés par date
    private var testsGraphique: [TestPhysique] {
        testsJoueur
            .filter { $0.typeTest == typeGraphique }
            .sorted { $0.date < $1.date }
    }

    /// Delta entre le dernier et l'avant-dernier test d'un type
    private func delta(pour type: TypeTestPhysique) -> Double? {
        let tests = testsJoueur.filter { $0.typeTest == type }.sorted { $0.date > $1.date }
        guard let dernier = tests.first, let avantDernier = tests.dropFirst().first else { return nil }
        return dernier.valeur - avantDernier.valeur
    }

    private var estCoach: Bool {
        authService.utilisateurConnecte?.role.peutGererEquipe ?? false
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Résultats récents
                sectionResultats

                // Graphique
                if !testsGraphique.isEmpty {
                    sectionGraphique
                }

                // Historique
                sectionHistorique
            }
            .padding(16)
        }
        .navigationTitle("Tests physiques")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if estCoach {
                ToolbarItem(placement: .primaryAction) {
                    Button { afficherAjout = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $afficherAjout) {
            AjouterTestSheet(joueurID: joueur.id)
        }
    }

    // MARK: - Résultats récents

    private var sectionResultats: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Derniers résultats", systemImage: "gauge.with.needle.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.orange)

            if derniersResultats.isEmpty {
                Text("Aucun test enregistré")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(derniersResultats, id: \.0) { type, test in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: type.icone)
                                    .font(.caption)
                                    .foregroundStyle(type.couleur)
                                Text(type.label)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(type == .sprintTime ? String(format: "%.2f", test.valeur) : "\(Int(test.valeur))")
                                    .font(.title3.weight(.bold))
                                Text(type.unite)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            // Delta
                            if let d = delta(pour: type) {
                                let amelioration = type.estTemps ? d < 0 : d > 0
                                let texte = type.estTemps
                                    ? String(format: "%+.2f", d)
                                    : (d > 0 ? "+\(Int(d))" : "\(Int(d))")
                                Text(texte)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(amelioration ? .green : .red)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                    }
                }
            }
        }
        .glassSection()
    }

    // MARK: - Graphique évolution

    private var sectionGraphique: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Évolution", systemImage: "chart.line.uptrend.xyaxis")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.orange)

            // Sélection type
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TypeTestPhysique.allCases, id: \.self) { type in
                        let aDesTests = testsJoueur.contains { $0.typeTest == type }
                        if aDesTests {
                            Button {
                                typeGraphique = type
                            } label: {
                                Text(type.label)
                                    .font(.caption.weight(typeGraphique == type ? .bold : .regular))
                                    .foregroundStyle(typeGraphique == type ? .white : .primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        typeGraphique == type
                                            ? AnyShapeStyle(type.couleur)
                                            : AnyShapeStyle(Color.primary.opacity(0.06)),
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Chart(testsGraphique) { test in
                LineMark(
                    x: .value("Date", test.date),
                    y: .value(typeGraphique.unite, test.valeur)
                )
                .foregroundStyle(typeGraphique.couleur)
                .symbol(Circle())

                PointMark(
                    x: .value("Date", test.date),
                    y: .value(typeGraphique.unite, test.valeur)
                )
                .foregroundStyle(typeGraphique.couleur)
                .annotation(position: .top, spacing: 4) {
                    Text(typeGraphique == .sprintTime
                         ? String(format: "%.2f", test.valeur)
                         : "\(Int(test.valeur))")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(typeGraphique.couleur)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 220)
        }
        .glassSection()
    }

    // MARK: - Historique

    private var sectionHistorique: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Historique complet", systemImage: "list.bullet")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.orange)

            if testsJoueur.isEmpty {
                Text("Aucun test")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(testsJoueur) { test in
                    HStack(spacing: 12) {
                        Image(systemName: test.typeTest.icone)
                            .font(.caption)
                            .foregroundStyle(test.typeTest.couleur)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(test.typeTest.label)
                                .font(.caption.weight(.medium))
                            Text(test.date.formatCourt())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("\(test.typeTest == .sprintTime ? String(format: "%.2f", test.valeur) : "\(Int(test.valeur))") \(test.typeTest.unite)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(test.typeTest.couleur)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                }
            }
        }
        .glassSection()
    }
}

// MARK: - Sheet ajouter test physique

struct AjouterTestSheet: View {
    let joueurID: UUID

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var typeTest: TypeTestPhysique = .squat1RM
    @State private var valeur: String = ""
    @State private var date: Date = Date()
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Type de test") {
                    Picker("Test", selection: $typeTest) {
                        ForEach(TypeTestPhysique.allCases, id: \.self) { type in
                            Label(type.label, systemImage: type.icone)
                                .tag(type)
                        }
                    }
                }

                Section("Résultat") {
                    HStack {
                        TextField("Valeur", text: $valeur)
                            .keyboardType(.decimalPad)
                        Text(typeTest.unite)
                            .foregroundStyle(.secondary)
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Notes") {
                    TextField("Commentaires optionnels", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Nouveau test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        sauvegarder()
                    }
                    .disabled(Double(valeur) == nil || Double(valeur) == 0)
                }
            }
        }
    }

    private func sauvegarder() {
        guard let val = Double(valeur), val > 0 else { return }
        let test = TestPhysique(joueurID: joueurID, typeTest: typeTest, valeur: val, date: date, notes: notes)
        modelContext.insert(test)
        try? modelContext.save()
        dismiss()
    }
}
