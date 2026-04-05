//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Type de résultat de recherche
private enum TypeResultat: String, CaseIterable {
    case joueur = "Joueurs"
    case seance = "Séances"
    case match = "Matchs"
    case strategie = "Stratégies"
    case exercice = "Exercices"

    var icone: String {
        switch self {
        case .joueur: "person.fill"
        case .seance: "calendar.badge.clock"
        case .match: "flag.fill"
        case .strategie: "sportscourt.fill"
        case .exercice: "book.fill"
        }
    }

    var couleur: Color {
        switch self {
        case .joueur: PaletteMat.vert
        case .seance: PaletteMat.orange
        case .match: .red
        case .strategie: PaletteMat.bleu
        case .exercice: PaletteMat.violet
        }
    }

    var section: SectionApp? {
        switch self {
        case .joueur: .equipe
        case .seance: .pratiques
        case .match: .matchs
        case .strategie: .strategies
        case .exercice: .pratiques
        }
    }
}

/// Résultat de recherche unifié
private struct ResultatRecherche: Identifiable {
    let id: UUID
    let type: TypeResultat
    let titre: String
    let sousTitre: String
}

/// Recherche globale Spotlight-like — cherche joueurs, séances, matchs, stratégies, exercices
struct RechercheGlobaleView: View {
    var onNaviguer: ((SectionApp) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.codeEquipeActif) private var codeEquipeActif

    @Query(filter: #Predicate<Seance> { $0.estArchivee == false })
    private var toutesSeances: [Seance]
    @Query private var tousJoueurs: [JoueurEquipe]
    @Query(filter: #Predicate<StrategieCollective> { $0.estArchivee == false })
    private var toutesStrategies: [StrategieCollective]
    @Query private var tousExercices: [ExerciceBibliotheque]

    @State private var recherche = ""
    @State private var filtreType: TypeResultat?

    private var seances: [Seance] { toutesSeances.filtreEquipe(codeEquipeActif) }
    private var joueurs: [JoueurEquipe] { tousJoueurs.filtreEquipe(codeEquipeActif) }
    private var strategies: [StrategieCollective] { toutesStrategies.filtreEquipe(codeEquipeActif) }

    private var resultats: [TypeResultat: [ResultatRecherche]] {
        guard !recherche.trimmingCharacters(in: .whitespaces).isEmpty else { return [:] }
        let terme = recherche.lowercased()
        var dict: [TypeResultat: [ResultatRecherche]] = [:]

        // Joueurs
        if filtreType == nil || filtreType == .joueur {
            let r = joueurs.compactMap { j -> ResultatRecherche? in
                let nomComplet = "\(j.prenom) \(j.nom)"
                let numero = String(j.numero)
                guard nomComplet.localizedCaseInsensitiveContains(terme) ||
                      numero.contains(terme) else { return nil }
                return ResultatRecherche(id: j.id, type: .joueur,
                    titre: "#\(j.numero) \(j.prenom) \(j.nom)",
                    sousTitre: j.poste.rawValue)
            }
            if !r.isEmpty { dict[.joueur] = r }
        }

        // Séances pratiques
        if filtreType == nil || filtreType == .seance {
            let r = seances.filter { !$0.estMatch }.compactMap { s -> ResultatRecherche? in
                guard s.nom.localizedCaseInsensitiveContains(terme) else { return nil }
                return ResultatRecherche(id: s.id, type: .seance,
                    titre: s.nom,
                    sousTitre: s.date.formatted(date: .abbreviated, time: .shortened))
            }
            if !r.isEmpty { dict[.seance] = r }
        }

        // Matchs
        if filtreType == nil || filtreType == .match {
            let r = seances.filter { $0.estMatch }.compactMap { s -> ResultatRecherche? in
                let adversaire = s.adversaire
                guard s.nom.localizedCaseInsensitiveContains(terme) ||
                      adversaire.localizedCaseInsensitiveContains(terme) else { return nil }
                return ResultatRecherche(id: s.id, type: .match,
                    titre: s.nom.isEmpty ? "vs \(adversaire)" : s.nom,
                    sousTitre: adversaire.isEmpty ? s.date.formatted(date: .abbreviated, time: .omitted) : "vs \(adversaire) — \(s.date.formatted(date: .abbreviated, time: .omitted))")
            }
            if !r.isEmpty { dict[.match] = r }
        }

        // Stratégies
        if filtreType == nil || filtreType == .strategie {
            let r = strategies.compactMap { s -> ResultatRecherche? in
                guard s.nom.localizedCaseInsensitiveContains(terme) ||
                      s.descriptionStrategie.localizedCaseInsensitiveContains(terme) else { return nil }
                return ResultatRecherche(id: s.id, type: .strategie,
                    titre: s.nom,
                    sousTitre: s.categorie.rawValue)
            }
            if !r.isEmpty { dict[.strategie] = r }
        }

        // Exercices bibliothèque
        if filtreType == nil || filtreType == .exercice {
            let r = tousExercices.compactMap { e -> ResultatRecherche? in
                guard e.nom.localizedCaseInsensitiveContains(terme) ||
                      e.categorie.localizedCaseInsensitiveContains(terme) ||
                      e.descriptionExo.localizedCaseInsensitiveContains(terme) else { return nil }
                return ResultatRecherche(id: e.id, type: .exercice,
                    titre: e.nom,
                    sousTitre: e.categorie)
            }
            if !r.isEmpty { dict[.exercice] = r }
        }

        return dict
    }

    private var totalResultats: Int {
        resultats.values.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filtres par type
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: LiquidGlassKit.espaceSM) {
                        filtreChip(nil, label: "Tout", icone: "magnifyingglass")
                        ForEach(TypeResultat.allCases, id: \.self) { type in
                            filtreChip(type, label: type.rawValue, icone: type.icone)
                        }
                    }
                    .padding(.horizontal, LiquidGlassKit.espaceMD)
                    .padding(.vertical, LiquidGlassKit.espaceSM)
                }

                // Résultats
                if recherche.trimmingCharacters(in: .whitespaces).isEmpty {
                    ContentUnavailableView(
                        "Rechercher",
                        systemImage: "magnifyingglass",
                        description: Text("Tapez pour chercher dans joueurs, séances, matchs, stratégies et exercices.")
                    )
                } else if resultats.isEmpty {
                    ContentUnavailableView.search(text: recherche)
                } else {
                    List {
                        ForEach(TypeResultat.allCases, id: \.self) { type in
                            if let items = resultats[type] {
                                Section {
                                    ForEach(items) { item in
                                        Button {
                                            if let section = item.type.section {
                                                dismiss()
                                                onNaviguer?(section)
                                            }
                                        } label: {
                                            ligneResultat(item)
                                        }
                                    }
                                } header: {
                                    HStack(spacing: 6) {
                                        Image(systemName: type.icone)
                                            .foregroundStyle(type.couleur)
                                        Text(type.rawValue)
                                    }
                                    .font(.caption.weight(.semibold))
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Recherche")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $recherche, prompt: "Joueurs, séances, stratégies…")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if totalResultats > 0 {
                        Text("\(totalResultats) résultat\(totalResultats > 1 ? "s" : "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Composants

    private func filtreChip(_ type: TypeResultat?, label: String, icone: String) -> some View {
        let estActif = filtreType == type
        return Button {
            withAnimation(LiquidGlassKit.springDefaut) {
                filtreType = type
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icone)
                    .font(.system(size: 12))
                Text(label)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(estActif ? (type?.couleur ?? PaletteMat.orange).opacity(0.15) : Color(.systemGray6))
            .foregroundStyle(estActif ? (type?.couleur ?? PaletteMat.orange) : .primary)
            .clipShape(Capsule())
        }
    }

    private func ligneResultat(_ item: ResultatRecherche) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(item.type.couleur.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: item.type.icone)
                    .font(.system(size: 14))
                    .foregroundStyle(item.type.couleur)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.titre)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(item.sousTitre)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.quaternary)
        }
    }
}
