//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Vue d'export des statistiques en CSV
struct ExportStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Query(filter: #Predicate<JoueurEquipe> { $0.estActif == true },
           sort: \JoueurEquipe.numero) private var joueurs: [JoueurEquipe]
    @Query(filter: #Predicate<Seance> { $0.typeSeanceRaw == "Match" && $0.estArchivee == false },
           sort: \Seance.date) private var seances: [Seance]
    @Query private var statsMatchs: [StatsMatch]

    @State private var joueursEquipe: [JoueurEquipe] = []
    @State private var matchsEquipe: [Seance] = []
    @State private var statsEquipe: [StatsMatch] = []

    enum TypeExport: String, CaseIterable, Identifiable {
        case joueurs    = "Stats joueurs (saison)"
        case matchs     = "Stats par match (box score)"
        case resultats  = "Résultats matchs"

        var id: String { rawValue }

        var icone: String {
            switch self {
            case .joueurs:   return "person.3.fill"
            case .matchs:    return "tablecells"
            case .resultats: return "flag.fill"
            }
        }

        var description: String {
            switch self {
            case .joueurs:   return "Statistiques cumulatives de chaque joueur sur la saison"
            case .matchs:    return "Feuille de match détaillée match par match, joueur par joueur"
            case .resultats: return "Liste des matchs avec scores et résultats"
            }
        }

        var couleur: Color {
            switch self {
            case .joueurs:   return PaletteMat.vert
            case .matchs:    return PaletteMat.orange
            case .resultats: return .red
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(TypeExport.allCases) { type in
                        carteExport(type)
                    }
                } header: {
                    Text("Choisissez le type d'export")
                } footer: {
                    Text("Les fichiers CSV s'ouvrent dans Excel, Numbers ou Google Sheets. Le séparateur est le point-virgule (;).")
                }
            }
            .navigationTitle("Exporter les stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .onAppear { mettreAJour() }
            .onChange(of: codeEquipeActif) { _, _ in mettreAJour() }
        }
    }

    private func carteExport(_ type: TypeExport) -> some View {
        let csvData = genererCSV(type)
        let nomFichier = nomFichierCSV(type)

        return ShareLink(
            item: csvData,
            preview: SharePreview(nomFichier, icon: Image(systemName: "doc.text"))
        ) {
            HStack(spacing: LiquidGlassKit.espaceSM + 4) {
                Image(systemName: type.icone)
                    .font(.title2)
                    .foregroundStyle(type.couleur)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: LiquidGlassKit.espaceXS) {
                    Text(type.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PaletteMat.textePrincipal)
                    Text(type.description)
                        .font(.caption)
                        .foregroundStyle(PaletteMat.texteSecondaire)
                }

                Spacer()

                Image(systemName: "square.and.arrow.up")
                    .font(.caption)
                    .foregroundStyle(type.couleur)
            }
            .padding(.vertical, LiquidGlassKit.espaceXS)
        }
    }

    // MARK: - Génération CSV

    private func genererCSV(_ type: TypeExport) -> CSVFile {
        let data: Data
        switch type {
        case .joueurs:
            data = CSVExportService.exporterStatsJoueurs(joueursEquipe)
        case .matchs:
            data = CSVExportService.exporterStatsParMatch(
                matchs: matchsEquipe, statsMatchs: statsEquipe, joueurs: joueursEquipe
            )
        case .resultats:
            data = CSVExportService.exporterResultatsMatchs(matchsEquipe)
        }
        return CSVFile(nomFichier: nomFichierCSV(type), contenu: data)
    }

    private func nomFichierCSV(_ type: TypeExport) -> String {
        let date = Date().formatYMD()
        switch type {
        case .joueurs:   return "Playco_Stats_Joueurs_\(date).csv"
        case .matchs:    return "Playco_Stats_Matchs_\(date).csv"
        case .resultats: return "Playco_Resultats_\(date).csv"
        }
    }

    private func mettreAJour() {
        joueursEquipe = joueurs.filtreEquipe(codeEquipeActif)
        matchsEquipe = seances.filtreEquipe(codeEquipeActif)
        statsEquipe = statsMatchs.filtreEquipe(codeEquipeActif)
    }
}

// MARK: - CSVFile pour ShareLink

struct CSVFile: Transferable {
    let nomFichier: String
    let contenu: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { csvFile in
            csvFile.contenu
        }
    }
}
