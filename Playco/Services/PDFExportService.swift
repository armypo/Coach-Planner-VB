//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import UIKit
import SwiftUI
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "PDFExport")

/// Service de génération de PDF pour résumés de match et fiches joueur
enum PDFExportService {

    // MARK: - Résumé de match

    static func genererPDFMatch(seance: Seance, joueurs: [JoueurEquipe], statsMatch: [StatsMatch]) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792)) // Letter
        let data = renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = 40

            // Titre
            y = dessinerTexte("Résumé de match", x: 40, y: y, font: .boldSystemFont(ofSize: 24), context: context)
            y += 8

            // Info match
            y = dessinerTexte("Date : \(seance.date.formatCourt())", x: 40, y: y, font: .systemFont(ofSize: 12), context: context)
            if !seance.adversaire.isEmpty {
                y = dessinerTexte("Adversaire : \(seance.adversaire)", x: 40, y: y, font: .systemFont(ofSize: 12), context: context)
            }
            if !seance.lieu.isEmpty {
                y = dessinerTexte("Lieu : \(seance.lieu)", x: 40, y: y, font: .systemFont(ofSize: 12), context: context)
            }
            y += 8

            // Score par set
            let sets = seance.sets
            if !sets.isEmpty {
                y = dessinerTexte("Score par set", x: 40, y: y, font: .boldSystemFont(ofSize: 16), context: context)
                y += 4
                for set in sets {
                    let gagnant = set.scoreEquipe > set.scoreAdversaire ? "✓" : "✗"
                    y = dessinerTexte("  Set \(set.numero) : \(set.scoreEquipe) — \(set.scoreAdversaire)  \(gagnant)",
                                      x: 40, y: y, font: .monospacedDigitSystemFont(ofSize: 12, weight: .regular), context: context)
                }
                y += 4
                y = dessinerTexte("Score final : \(seance.scoreEquipe) — \(seance.scoreAdversaire) (\(seance.resultat?.label ?? "—"))",
                                  x: 40, y: y, font: .boldSystemFont(ofSize: 14), context: context)
                y += 12
            }

            // Feuille de match
            let statsSeance = statsMatch.filter { $0.seanceID == seance.id }
            if !statsSeance.isEmpty {
                y = dessinerTexte("Feuille de match", x: 40, y: y, font: .boldSystemFont(ofSize: 16), context: context)
                y += 8

                // En-tête tableau
                let colonnes = ["#", "Joueur", "K", "E", "TA", "H%", "A", "BS", "BA", "RR", "RT", "R%", "PD", "Pts"]
                let largeurs: [CGFloat] = [25, 90, 25, 25, 25, 35, 25, 25, 25, 25, 25, 35, 25, 30]
                var x: CGFloat = 40
                for (i, col) in colonnes.enumerated() {
                    dessinerTexteAligne(col, rect: CGRect(x: x, y: y, width: largeurs[i], height: 14),
                                        font: .boldSystemFont(ofSize: 8), context: context)
                    x += largeurs[i]
                }
                y += 16

                // Ligne séparatrice
                context.cgContext.setStrokeColor(UIColor.gray.cgColor)
                context.cgContext.setLineWidth(0.5)
                context.cgContext.move(to: CGPoint(x: 40, y: y))
                context.cgContext.addLine(to: CGPoint(x: 572, y: y))
                context.cgContext.strokePath()
                y += 4

                // Données joueurs
                for stat in statsSeance {
                    if y > 740 {
                        context.beginPage()
                        y = 40
                    }
                    guard let joueur = joueurs.first(where: { $0.id == stat.joueurID }) else { continue }

                    let hitPct = stat.tentativesAttaque > 0
                        ? String(format: "%.0f", Double(stat.kills - stat.erreursAttaque) / Double(stat.tentativesAttaque) * 100)
                        : "—"
                    let recPct = stat.receptionsTotales > 0
                        ? String(format: "%.0f", Double(stat.receptionsReussies) / Double(stat.receptionsTotales) * 100)
                        : "—"

                    let valeurs = [
                        "\(joueur.numero)", "\(joueur.prenom) \(joueur.nom.prefix(1)).",
                        "\(stat.kills)", "\(stat.erreursAttaque)", "\(stat.tentativesAttaque)", hitPct,
                        "\(stat.aces)", "\(stat.blocsSeuls)", "\(stat.blocsAssistes)",
                        "\(stat.receptionsReussies)", "\(stat.receptionsTotales)", recPct,
                        "\(stat.passesDecisives)", "\(stat.points)"
                    ]

                    x = 40
                    for (i, val) in valeurs.enumerated() {
                        dessinerTexteAligne(val, rect: CGRect(x: x, y: y, width: largeurs[i], height: 12),
                                            font: .monospacedDigitSystemFont(ofSize: 8, weight: .regular), context: context)
                        x += largeurs[i]
                    }
                    y += 14
                }
            }

            // Notes
            if !seance.notesMatch.isEmpty {
                y += 12
                y = dessinerTexte("Notes", x: 40, y: y, font: .boldSystemFont(ofSize: 16), context: context)
                y += 4
                y = dessinerTexte(seance.notesMatch, x: 40, y: y, font: .systemFont(ofSize: 11), context: context, maxWidth: 532)
            }

            // Pied de page
            let piedPage = "Playco — Généré le \(Date().formatCourt())"
            dessinerTexteAligne(piedPage, rect: CGRect(x: 40, y: 770, width: 532, height: 12),
                               font: .systemFont(ofSize: 8), context: context, align: .center)
        }

        logger.info("PDF match généré (\(data.count) octets)")
        return data
    }

    // MARK: - Fiche joueur

    static func genererPDFJoueur(joueur: JoueurEquipe, moyenneEquipe: [String: Double]) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let data = renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = 40

            // Titre
            y = dessinerTexte("Fiche Joueur", x: 40, y: y, font: .boldSystemFont(ofSize: 24), context: context)
            y += 8

            // Info joueur
            y = dessinerTexte("#\(joueur.numero) \(joueur.prenom) \(joueur.nom)", x: 40, y: y, font: .boldSystemFont(ofSize: 18), context: context)
            y = dessinerTexte("Poste : \(joueur.poste.rawValue)", x: 40, y: y, font: .systemFont(ofSize: 12), context: context)
            if joueur.taille > 0 {
                y = dessinerTexte("Taille : \(joueur.taille) cm", x: 40, y: y, font: .systemFont(ofSize: 12), context: context)
            }
            y = dessinerTexte("Matchs joués : \(joueur.matchsJoues)", x: 40, y: y, font: .systemFont(ofSize: 12), context: context)
            y += 12

            // Stats avec comparaison
            y = dessinerTexte("Statistiques", x: 40, y: y, font: .boldSystemFont(ofSize: 16), context: context)
            y += 8

            let stats: [(String, String, String)] = [
                ("Kills", "\(joueur.attaquesReussies)", String(format: "%.1f", moyenneEquipe["kills"] ?? 0)),
                ("Hitting %", String(format: "%.1f%%", joueur.pourcentageAttaque * 100), String(format: "%.1f%%", (moyenneEquipe["hittingPct"] ?? 0) * 100)),
                ("Aces", "\(joueur.aces)", String(format: "%.1f", moyenneEquipe["aces"] ?? 0)),
                ("Blocs seuls", "\(joueur.blocsSeuls)", String(format: "%.1f", moyenneEquipe["blocsSeuls"] ?? 0)),
                ("Blocs assistés", "\(joueur.blocsAssistes)", String(format: "%.1f", moyenneEquipe["blocsAssistes"] ?? 0)),
                ("Réception %", String(format: "%.1f%%", joueur.efficaciteReception), String(format: "%.1f%%", moyenneEquipe["receptionEff"] ?? 0)),
                ("Passes décisives", "\(joueur.passesDecisives)", String(format: "%.1f", moyenneEquipe["passes"] ?? 0)),
            ]

            // En-tête
            dessinerTexteAligne("Stat", rect: CGRect(x: 40, y: y, width: 150, height: 14), font: .boldSystemFont(ofSize: 10), context: context)
            dessinerTexteAligne("Joueur", rect: CGRect(x: 200, y: y, width: 80, height: 14), font: .boldSystemFont(ofSize: 10), context: context, align: .right)
            dessinerTexteAligne("Moy. équipe", rect: CGRect(x: 290, y: y, width: 80, height: 14), font: .boldSystemFont(ofSize: 10), context: context, align: .right)
            y += 16

            for stat in stats {
                dessinerTexteAligne(stat.0, rect: CGRect(x: 40, y: y, width: 150, height: 14), font: .systemFont(ofSize: 10), context: context)
                dessinerTexteAligne(stat.1, rect: CGRect(x: 200, y: y, width: 80, height: 14), font: .boldSystemFont(ofSize: 10), context: context, align: .right)
                dessinerTexteAligne(stat.2, rect: CGRect(x: 290, y: y, width: 80, height: 14), font: .systemFont(ofSize: 10, weight: .light), context: context, align: .right)
                y += 16
            }

            // Pied de page
            let piedPage = "Playco — Généré le \(Date().formatCourt())"
            dessinerTexteAligne(piedPage, rect: CGRect(x: 40, y: 770, width: 532, height: 12),
                               font: .systemFont(ofSize: 8), context: context, align: .center)
        }

        logger.info("PDF joueur généré (\(data.count) octets)")
        return data
    }

    // MARK: - Plan de match (scouting)

    /// PDF « une page » du plan de match issu d'un rapport de scouting :
    /// système/style, joueurs clés (menace en étoiles textuelles), stratégies
    /// prioritaires, tendances zonales (grilles 3×2) et notes.
    static func genererPDFScouting(rapport: ScoutingReport) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792)) // Letter
        let data = renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = 40

            // Titre
            let titre = rapport.adversaire.isEmpty ? "Plan de match" : "Plan de match — vs \(rapport.adversaire)"
            y = dessinerTexte(titre, x: 40, y: y, font: .boldSystemFont(ofSize: 22), context: context)
            y += 4

            // Infos générales
            y = dessinerTexte("Match du \(rapport.dateMatch.formatCourt())", x: 40, y: y, font: .systemFont(ofSize: 11), context: context)
            var infos: [String] = []
            if !rapport.systemJeu.isEmpty { infos.append("Système : \(rapport.systemJeu)") }
            if !rapport.styleJeu.isEmpty { infos.append("Style : \(rapport.styleJeu)") }
            if !infos.isEmpty {
                y = dessinerTexte(infos.joined(separator: "   ·   "), x: 40, y: y, font: .systemFont(ofSize: 11), context: context)
            }
            if !rapport.adversaireObserve.isEmpty {
                y = dessinerTexte("Observé lors de : \(rapport.adversaireObserve)", x: 40, y: y, font: .systemFont(ofSize: 10), context: context)
            }
            y += 10

            // Joueurs clés (triés par menace, limités pour tenir sur la page)
            let joueurs = rapport.joueurs
                .sorted { $0.menaceNiveau > $1.menaceNiveau }
                .prefix(8)
            if !joueurs.isEmpty {
                y = dessinerTexte("Joueurs clés", x: 40, y: y, font: .boldSystemFont(ofSize: 15), context: context)
                y += 4
                for joueur in joueurs {
                    let menace = max(0, min(5, joueur.menaceNiveau))
                    let etoiles = String(repeating: "★", count: menace)
                    let poste = joueur.poste.isEmpty ? "" : " — \(joueur.poste)"
                    let nom = joueur.nom.isEmpty ? "Sans nom" : joueur.nom
                    let ligne = "#\(joueur.numero)  \(nom)\(poste)   \(etoiles) \(menace)/5"
                    y = dessinerTexte(ligne, x: 48, y: y, font: .systemFont(ofSize: 11), context: context)
                }
                y += 10
            }

            // Stratégies prioritaires (3 max, par priorité croissante = haute d'abord)
            let strategies = rapport.strategies
                .sorted { $0.priorite < $1.priorite }
                .prefix(3)
            if !strategies.isEmpty {
                y = dessinerTexte("Stratégies prioritaires", x: 40, y: y, font: .boldSystemFont(ofSize: 15), context: context)
                y += 4
                for (index, strategie) in strategies.enumerated() {
                    let categorie = strategie.categorie.isEmpty ? "" : " (\(strategie.categorie))"
                    let titreStrategie = strategie.titre.isEmpty ? "Sans titre" : strategie.titre
                    y = dessinerTexte("\(index + 1). \(titreStrategie)\(categorie)",
                                      x: 48, y: y, font: .boldSystemFont(ofSize: 11), context: context)
                    if !strategie.description.isEmpty {
                        y = dessinerTexte(strategie.description, x: 60, y: y, font: .systemFont(ofSize: 10), context: context, maxWidth: 500)
                    }
                    y += 2
                }
                y += 10
            }

            // Tendances zonales — 2 grilles 3×2 (rangée avant 4-3-2, arrière 5-6-1)
            let tendances = rapport.tendancesZonales
            y = dessinerTexte("Tendances zonales (menace 0-3)", x: 40, y: y, font: .boldSystemFont(ofSize: 15), context: context)
            y += 6
            let hauteurGrille = dessinerGrilleZonale(titre: "Service adverse", niveaux: tendances.service,
                                                     x: 40, y: y, context: context)
            _ = dessinerGrilleZonale(titre: "Attaque adverse", niveaux: tendances.attaque,
                                     x: 320, y: y, context: context)
            y += hauteurGrille + 12

            // Notes texte (tendances courtes + notes générales)
            var notes: [String] = []
            if !rapport.tendanceService.isEmpty { notes.append("Service : \(rapport.tendanceService)") }
            if !rapport.tendanceAttaque.isEmpty { notes.append("Attaque : \(rapport.tendanceAttaque)") }
            if !rapport.tendanceReception.isEmpty { notes.append("Réception : \(rapport.tendanceReception)") }
            if !rapport.tendanceBloc.isEmpty { notes.append("Bloc : \(rapport.tendanceBloc)") }
            if !rapport.notes.isEmpty { notes.append(rapport.notes) }
            if !notes.isEmpty {
                y = dessinerTexte("Notes", x: 40, y: y, font: .boldSystemFont(ofSize: 15), context: context)
                y += 4
                for note in notes where y < 730 {
                    y = dessinerTexte(note, x: 48, y: y, font: .systemFont(ofSize: 10), context: context, maxWidth: 520)
                }
            }

            // Pied de page
            let piedPage = "Playco — Généré le \(Date().formatCourt())"
            dessinerTexteAligne(piedPage, rect: CGRect(x: 40, y: 770, width: 532, height: 12),
                                font: .systemFont(ofSize: 8), context: context, align: .center)
        }

        logger.info("PDF scouting généré (\(data.count) octets)")
        return data
    }

    /// Dessine une grille zonale 3×2 (zones 4-3-2 / 5-6-1) avec le niveau de
    /// menace par zone. Retourne la hauteur totale occupée.
    @discardableResult
    private static func dessinerGrilleZonale(titre: String, niveaux: [Int: Int],
                                             x: CGFloat, y: CGFloat,
                                             context: UIGraphicsPDFRendererContext) -> CGFloat {
        let largeurCellule: CGFloat = 70
        let hauteurCellule: CGFloat = 30
        let rangees: [[Int]] = [[4, 3, 2], [5, 6, 1]] // avant (filet) puis arrière

        var yLocal = dessinerTexte(titre, x: x, y: y, font: .boldSystemFont(ofSize: 11), context: context)
        yLocal += 2

        for rangee in rangees {
            var xLocal = x
            for zone in rangee {
                let rect = CGRect(x: xLocal, y: yLocal, width: largeurCellule, height: hauteurCellule)
                context.cgContext.setStrokeColor(UIColor.gray.cgColor)
                context.cgContext.setLineWidth(0.5)
                context.cgContext.stroke(rect)

                let niveau = max(0, min(3, niveaux[zone] ?? 0))
                dessinerTexteAligne("Z\(zone)",
                                    rect: CGRect(x: rect.minX + 4, y: rect.minY + 3, width: rect.width - 8, height: 10),
                                    font: .systemFont(ofSize: 7), context: context)
                dessinerTexteAligne("\(niveau)",
                                    rect: CGRect(x: rect.minX, y: rect.minY + 12, width: rect.width, height: 14),
                                    font: .boldSystemFont(ofSize: 12), context: context, align: .center)
                xLocal += largeurCellule
            }
            yLocal += hauteurCellule
        }
        return (yLocal - y)
    }

    // MARK: - Helpers de dessin

    @discardableResult
    private static func dessinerTexte(_ texte: String, x: CGFloat, y: CGFloat, font: UIFont, context: UIGraphicsPDFRendererContext, maxWidth: CGFloat = 532) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
        let rect = CGRect(x: x, y: y, width: maxWidth, height: 400)
        let attrString = NSAttributedString(string: texte, attributes: attrs)
        let boundingRect = attrString.boundingRect(with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                                                    options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        attrString.draw(in: rect)
        return y + boundingRect.height + 2
    }

    @discardableResult
    private static func dessinerTexteAligne(_ texte: String, rect: CGRect, font: UIFont, context: UIGraphicsPDFRendererContext, align: NSTextAlignment = .left) -> CGFloat {
        let style = NSMutableParagraphStyle()
        style.alignment = align
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black, .paragraphStyle: style]
        texte.draw(in: rect, withAttributes: attrs)
        return rect.maxY + 2
    }
}
