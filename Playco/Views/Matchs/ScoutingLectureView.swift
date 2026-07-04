//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Vue LECTURE « une page » d'un rapport de scouting (Phase 6) : l'essentiel
//  du plan de match d'un coup d'œil — adversaire, système/style en chips,
//  joueurs clés triés par menace, stratégies prioritaires, tendances zonales
//  en lecture seule et notes. « Modifier » pousse l'éditeur complet ;
//  « Exporter » génère le PDF du plan de match.
//

import SwiftUI
import SwiftData

struct ScoutingLectureView: View {
    let rapport: ScoutingReport

    @Environment(\.codeEquipeActif) private var codeEquipeActif

    /// Nombre de stratégies mises en avant dans le résumé.
    private static let nbStrategiesPrioritaires = 3

    // Décodages JSON cachés (rafraîchis au onAppear, y compris au retour de l'éditeur)
    @State private var joueursTries: [JoueurAdverse] = []
    @State private var strategiesPrioritaires: [StrategieRecommandee] = []
    @State private var tendancesZonales = TendancesZonales()

    // Export PDF
    @State private var pdfData: Data?
    @State private var afficherPartage = false

    /// Résolution du match lié (seanceID → Seance) pour le chip d'en-tête.
    @Query(filter: #Predicate<Seance> { $0.estArchivee == false && $0.typeSeanceRaw == "Match" },
           sort: \Seance.date, order: .reverse) private var tousMatchs: [Seance]

    private var matchLie: Seance? {
        guard let seanceID = rapport.seanceID else { return nil }
        return tousMatchs.filtreEquipe(codeEquipeActif).first { $0.id == seanceID }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: LiquidGlassKit.espaceLG - 4) {
                sectionEntete
                sectionJoueursCles
                sectionStrategies
                sectionTendancesZonales
                sectionNotes
                boutonExport
            }
            .padding(LiquidGlassKit.espaceLG)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(rapport.adversaire.isEmpty ? "Plan de match" : "vs \(rapport.adversaire)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    ScoutingReportView(rapport: rapport)
                } label: {
                    Label("Modifier", systemImage: "pencil")
                }
            }
        }
        .onAppear(perform: rafraichir)
        .sheet(isPresented: $afficherPartage) {
            if let data = pdfData {
                let url = sauvegarderPDFTemporaire(
                    data: data,
                    nom: "PlanMatch_\(rapport.adversaire.isEmpty ? "scouting" : rapport.adversaire)"
                )
                ActivityViewController(activityItems: [url])
            }
        }
    }

    private func rafraichir() {
        joueursTries = rapport.joueurs.sorted { $0.menaceNiveau > $1.menaceNiveau }
        strategiesPrioritaires = Array(
            rapport.strategies
                .sorted { $0.priorite < $1.priorite }
                .prefix(Self.nbStrategiesPrioritaires)
        )
        tendancesZonales = rapport.tendancesZonales
    }

    // MARK: - En-tête

    private var sectionEntete: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM + 4) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rapport.adversaire.isEmpty ? "Adversaire sans nom" : rapport.adversaire)
                        .font(.title2.weight(.bold))
                    Text("Match prévu le \(rapport.dateMatch.formatCourt()) · rapport créé le \(rapport.dateCreation.formatCourt())")
                        .font(.caption)
                        .foregroundStyle(PaletteMat.texteSecondaire)
                }
                Spacer()
            }

            // Chips système / style / match lié / observation
            HStack(spacing: LiquidGlassKit.espaceSM) {
                if !rapport.systemJeu.isEmpty {
                    Text("Système \(rapport.systemJeu)").glassChip(couleur: .red)
                }
                if !rapport.styleJeu.isEmpty {
                    Text(rapport.styleJeu).glassChip(couleur: PaletteMat.bleu)
                }
                if let match = matchLie {
                    Text("Match : \(match.adversaire.isEmpty ? match.nom : "vs \(match.adversaire)") — \(match.date.formatCourt())")
                        .glassChip(couleur: PaletteMat.vert)
                }
                Spacer()
            }

            if !rapport.adversaireObserve.isEmpty {
                Text("Observé lors de : \(rapport.adversaireObserve)")
                    .font(.footnote)
                    .foregroundStyle(PaletteMat.texteSecondaire)
            }
        }
        .glassSection()
    }

    // MARK: - Joueurs clés (triés par menace)

    private var sectionJoueursCles: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceMD) {
            EnTeteSection(titre: "Joueurs clés", sousTitre: "Triés par niveau de menace")

            if joueursTries.isEmpty {
                Text("Aucun joueur clé identifié")
                    .font(.subheadline)
                    .foregroundStyle(PaletteMat.texteTertiaire)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, LiquidGlassKit.espaceMD)
            } else {
                ForEach(joueursTries) { joueur in
                    HStack(spacing: 12) {
                        Text("#\(joueur.numero)")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(.red)
                            .frame(width: 44, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(joueur.nom.isEmpty ? "Sans nom" : joueur.nom)
                                .font(.subheadline.weight(.semibold))
                            if !joueur.poste.isEmpty {
                                Text(joueur.poste)
                                    .font(.caption)
                                    .foregroundStyle(PaletteMat.texteSecondaire)
                            }
                            if !joueur.pointsForts.isEmpty {
                                Text(joueur.pointsForts)
                                    .font(.caption)
                                    .foregroundStyle(PaletteMat.texteTertiaire)
                                    .lineLimit(2)
                            }
                        }

                        Spacer()

                        EtoilesMenaceView(niveau: joueur.menaceNiveau)
                    }
                    .padding(.vertical, LiquidGlassKit.espaceXS)
                }
            }
        }
        .glassSection()
    }

    // MARK: - Stratégies prioritaires

    private var sectionStrategies: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceMD) {
            EnTeteSection(titre: "Stratégies prioritaires")

            if strategiesPrioritaires.isEmpty {
                Text("Aucune stratégie recommandée")
                    .font(.subheadline)
                    .foregroundStyle(PaletteMat.texteTertiaire)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, LiquidGlassKit.espaceMD)
            } else {
                ForEach(strategiesPrioritaires) { strategie in
                    VStack(alignment: .leading, spacing: LiquidGlassKit.espaceXS) {
                        HStack(spacing: LiquidGlassKit.espaceSM) {
                            Text(strategie.titre.isEmpty ? "Sans titre" : strategie.titre)
                                .font(.subheadline.weight(.semibold))
                            if !strategie.categorie.isEmpty {
                                Text(strategie.categorie).glassChip(couleur: PaletteMat.violet)
                            }
                            Spacer()
                        }
                        if !strategie.description.isEmpty {
                            Text(strategie.description)
                                .font(.footnote)
                                .foregroundStyle(PaletteMat.texteSecondaire)
                        }
                    }
                    .padding(12)
                    .glassCard(teinte: PaletteMat.violet, cornerRadius: LiquidGlassKit.rayonPetit, ombre: false)
                }
            }
        }
        .glassSection()
    }

    // MARK: - Tendances zonales (lecture seule)

    private var sectionTendancesZonales: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceMD) {
            EnTeteSection(titre: "Tendances zonales", sousTitre: MiniTerrainZonesMenace.legendeNiveaux)

            HStack(alignment: .top, spacing: LiquidGlassKit.espaceLG) {
                VStack(alignment: .leading, spacing: LiquidGlassKit.espaceXS) {
                    MiniTerrainZonesMenace(
                        titre: "Service adverse",
                        niveaux: tendancesZonales.service,
                        estInteractif: false
                    )
                    if !rapport.tendanceService.isEmpty {
                        Text(rapport.tendanceService)
                            .font(.caption)
                            .foregroundStyle(PaletteMat.texteSecondaire)
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: LiquidGlassKit.espaceXS) {
                    MiniTerrainZonesMenace(
                        titre: "Attaque adverse",
                        niveaux: tendancesZonales.attaque,
                        estInteractif: false
                    )
                    if !rapport.tendanceAttaque.isEmpty {
                        Text(rapport.tendanceAttaque)
                            .font(.caption)
                            .foregroundStyle(PaletteMat.texteSecondaire)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .glassSection()
    }

    // MARK: - Notes

    @ViewBuilder
    private var sectionNotes: some View {
        let aNotesComplementaires = !rapport.notes.isEmpty
            || !rapport.tendanceReception.isEmpty
            || !rapport.tendanceBloc.isEmpty

        if aNotesComplementaires {
            VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM + 4) {
                EnTeteSection(titre: "Notes")

                if !rapport.tendanceReception.isEmpty {
                    ligneNote(titre: "Réception", texte: rapport.tendanceReception)
                }
                if !rapport.tendanceBloc.isEmpty {
                    ligneNote(titre: "Bloc", texte: rapport.tendanceBloc)
                }
                if !rapport.notes.isEmpty {
                    Text(rapport.notes)
                        .font(.footnote)
                        .foregroundStyle(PaletteMat.textePrincipal)
                }
            }
            .glassSection()
        }
    }

    private func ligneNote(titre: String, texte: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titre)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PaletteMat.bleu)
            Text(texte)
                .font(.footnote)
                .foregroundStyle(PaletteMat.texteSecondaire)
        }
    }

    // MARK: - Export PDF

    /// Bouton d'export placé dans le contenu (et pas la toolbar) : le
    /// modificateur `.bloqueSiNonPayant` s'appuie sur overlay + fullScreenCover,
    /// peu fiables dans un ToolbarItem (même pattern qu'ExportMatchPDFView).
    private var boutonExport: some View {
        Button {
            exporterPDF()
        } label: {
            Label("Exporter en PDF", systemImage: "square.and.arrow.up")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, LiquidGlassKit.paddingChamp)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .bloqueSiNonPayant(source: "export_pdf_scouting")
    }

    private func exporterPDF() {
        let data = PDFExportService.genererPDFScouting(rapport: rapport)
        pdfData = data
        afficherPartage = true
    }

    private func sauvegarderPDFTemporaire(data: Data, nom: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(nom).pdf")
        try? data.write(to: url)
        return url
    }
}
