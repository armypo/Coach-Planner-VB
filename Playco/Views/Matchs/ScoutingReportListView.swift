//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Liste des rapports de scouting, groupée par adversaire.
///
/// Refonte Phase 6 :
/// - un rapport existant s'ouvre en LECTURE (`ScoutingLectureView`), l'éditeur
///   est accessible via « Modifier » ;
/// - création : saisie du nom d'adversaire, puis si un rapport existe déjà pour
///   cet adversaire (insensible à la casse), choix « Dupliquer le dernier
///   rapport » ou « Partir de zéro ».
struct ScoutingReportListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<ScoutingReport> { $0.estArchive == false },
           sort: \ScoutingReport.dateMatch, order: .reverse) private var tousRapports: [ScoutingReport]

    // Flux de création
    @State private var afficherSaisieAdversaire = false
    @State private var nomAdversaireSaisi = ""
    @State private var rapportADupliquer: ScoutingReport?
    @State private var afficherChoixDuplication = false
    @State private var rapportEnEdition: ScoutingReport?

    private var rapports: [ScoutingReport] {
        tousRapports.filtreEquipe(codeEquipeActif)
    }

    // MARK: - Groupement par adversaire

    private struct GroupeAdversaire: Identifiable {
        let id: String
        let nomAffiche: String
        let rapports: [ScoutingReport]
    }

    private var groupes: [GroupeAdversaire] {
        let parCle = Dictionary(grouping: rapports) {
            $0.adversaire.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        return parCle
            .map { cle, items in
                let nom = items.first?.adversaire.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return GroupeAdversaire(
                    id: cle.isEmpty ? "~sans-nom" : cle,
                    nomAffiche: nom.isEmpty ? "Sans nom" : nom,
                    rapports: items
                )
            }
            .sorted { ($0.rapports.first?.dateMatch ?? .distantPast) > ($1.rapports.first?.dateMatch ?? .distantPast) }
    }

    var body: some View {
        List {
            if rapports.isEmpty {
                ContentUnavailableView {
                    Label("Aucun rapport", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text("Créez un rapport pour analyser un adversaire.")
                } actions: {
                    Button("Nouveau rapport") {
                        demarrerCreation()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            ForEach(groupes) { groupe in
                Section(groupe.nomAffiche) {
                    ForEach(groupe.rapports) { rapport in
                        NavigationLink {
                            ScoutingLectureView(rapport: rapport)
                        } label: {
                            ligneRapport(rapport)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                rapport.estArchive = true
                                try? modelContext.save()
                            } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Rapports")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Fermer") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { demarrerCreation() } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Nouveau rapport")
            }
        }
        .navigationDestination(item: $rapportEnEdition) { rapport in
            ScoutingReportView(rapport: rapport)
        }
        .alert("Nouveau rapport", isPresented: $afficherSaisieAdversaire) {
            TextField("Nom de l'adversaire", text: $nomAdversaireSaisi)
            Button("Continuer") { poursuivreCreation() }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Pour quel adversaire préparez-vous ce rapport ?")
        }
        .confirmationDialog(
            "Un rapport existe déjà pour cet adversaire",
            isPresented: $afficherChoixDuplication,
            titleVisibility: .visible
        ) {
            if let base = rapportADupliquer {
                Button("Dupliquer le dernier rapport (\(base.dateCreation.formatCourt()))") {
                    creerRapport(adversaire: base.adversaire, base: base)
                }
            }
            Button("Partir de zéro") {
                creerRapport(adversaire: nomAdversaireNettoye, base: nil)
            }
            Button("Annuler", role: .cancel) {}
        }
    }

    // MARK: - Ligne

    private func ligneRapport(_ rapport: ScoutingReport) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(rapport.adversaire.isEmpty ? "Sans nom" : "vs \(rapport.adversaire)")
                .font(.headline)
            if !rapport.adversaireObserve.isEmpty {
                Text("observé lors de \(rapport.adversaireObserve)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            HStack(spacing: LiquidGlassKit.espaceSM) {
                Text(rapport.dateMatch.formatCourt())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Créé le \(rapport.dateCreation.formatCourt())")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if !rapport.systemJeu.isEmpty {
                    Text(rapport.systemJeu)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red.opacity(0.1), in: Capsule())
                        .foregroundStyle(.red)
                }
                if !rapport.joueurs.isEmpty {
                    Text("\(rapport.joueurs.count) joueurs")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Création

    private var nomAdversaireNettoye: String {
        nomAdversaireSaisi.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func demarrerCreation() {
        nomAdversaireSaisi = ""
        rapportADupliquer = nil
        afficherSaisieAdversaire = true
    }

    private func poursuivreCreation() {
        let nom = nomAdversaireNettoye
        if let dernier = dernierRapportPour(adversaire: nom) {
            rapportADupliquer = dernier
            // Présentation différée d'un runloop : enchaîner un dialog
            // immédiatement après la fermeture d'une alerte échoue sinon.
            Task { @MainActor in
                afficherChoixDuplication = true
            }
        } else {
            creerRapport(adversaire: nom, base: nil)
        }
    }

    /// Dernier rapport (dateCreation la plus récente) pour cet adversaire,
    /// comparaison insensible à la casse.
    private func dernierRapportPour(adversaire: String) -> ScoutingReport? {
        guard !adversaire.isEmpty else { return nil }
        return rapports
            .filter { $0.adversaire.compare(adversaire, options: [.caseInsensitive]) == .orderedSame }
            .max { $0.dateCreation < $1.dateCreation }
    }

    private func creerRapport(adversaire: String, base: ScoutingReport?) {
        let rapport: ScoutingReport
        if let base {
            rapport = ScoutingReport.dupliquer(base)
        } else {
            rapport = ScoutingReport()
            rapport.adversaire = adversaire
            rapport.dateMatch = Date()
        }
        rapport.codeEquipe = codeEquipeActif
        modelContext.insert(rapport)
        rapportEnEdition = rapport
    }
}
