//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "CSVExport")

/// Service d'export CSV pour les statistiques de l'équipe
enum CSVExportService {

    // MARK: - Export stats joueurs (saison complète)

    /// Génère un fichier CSV avec les stats cumulatives de tous les joueurs
    static func exporterStatsJoueurs(_ joueurs: [JoueurEquipe]) -> Data {
        var lignes: [String] = []

        // En-tête
        lignes.append([
            "Numéro", "Prénom", "Nom", "Poste",
            "Matchs joués", "Sets joués",
            "Kills", "Erreurs attaque", "Tentatives attaque", "Hitting %",
            "Aces", "Erreurs service", "Services totaux",
            "Blocs seuls", "Blocs assistés", "Blocs totaux", "Erreurs bloc",
            "Réceptions réussies", "Erreurs réception", "Réceptions totales", "Efficacité réception %",
            "Passes décisives", "Manchettes",
            "Points calculés"
        ].joined(separator: ";"))

        // Données joueurs
        for j in joueurs.sorted(by: { $0.numero < $1.numero }) {
            let ligne = [
                "\(j.numero)",
                echapper(j.prenom),
                echapper(j.nom),
                echapper(j.poste.rawValue),
                "\(j.matchsJoues)", "\(j.setsJoues)",
                "\(j.attaquesReussies)", "\(j.erreursAttaque)", "\(j.attaquesTotales)",
                String(format: "%.3f", j.pourcentageAttaque),
                "\(j.aces)", "\(j.erreursService)", "\(j.servicesTotaux)",
                "\(j.blocsSeuls)", "\(j.blocsAssistes)", "\(j.blocsTotaux)", "\(j.erreursBloc)",
                "\(j.receptionsReussies)", "\(j.erreursReception)", "\(j.receptionsTotales)",
                String(format: "%.1f", j.efficaciteReception * 100),
                "\(j.passesDecisives)", "\(j.manchettes)",
                "\(j.pointsCalcules)"
            ].joined(separator: ";")
            lignes.append(ligne)
        }

        let csv = lignes.joined(separator: "\n")
        logger.info("Export CSV joueurs : \(joueurs.count) joueurs")
        return csv.data(using: .utf8) ?? Data()
    }

    // MARK: - Export stats par match

    /// Génère un CSV avec les stats détaillées par match (box score)
    static func exporterStatsParMatch(
        matchs: [Seance],
        statsMatchs: [StatsMatch],
        joueurs: [JoueurEquipe]
    ) -> Data {
        var lignes: [String] = []

        // En-tête
        lignes.append([
            "Date", "Adversaire", "Lieu", "Résultat", "Score",
            "Numéro joueur", "Joueur",
            "Kills", "Erreurs attaque", "Tentatives", "Hitting %",
            "Aces", "Erreurs service",
            "Blocs seuls", "Blocs assistés",
            "Réceptions réussies", "Erreurs réception",
            "Passes décisives", "Manchettes",
            "Points"
        ].joined(separator: ";"))

        // Données par match
        for match in matchs.sorted(by: { $0.date < $1.date }) {
            let statsMatch = statsMatchs.filter { $0.seanceID == match.id }
            let dateStr = match.date.formatCourt()
            let resultatStr = match.resultat?.label ?? ""
            let scoreStr = "\(match.scoreEquipe)-\(match.scoreAdversaire)"

            for stat in statsMatch.sorted(by: { $0.points > $1.points }) {
                let joueur = joueurs.first(where: { $0.id == stat.joueurID })
                let hitPct = stat.tentativesAttaque > 0
                    ? String(format: "%.3f", stat.hittingPct) : ""

                let ligne = [
                    echapper(dateStr),
                    echapper(match.adversaire),
                    echapper(match.lieu),
                    echapper(resultatStr),
                    scoreStr,
                    "\(joueur?.numero ?? 0)",
                    echapper(joueur?.nomComplet ?? "Inconnu"),
                    "\(stat.kills)", "\(stat.erreursAttaque)", "\(stat.tentativesAttaque)", hitPct,
                    "\(stat.aces)", "\(stat.erreursService)",
                    "\(stat.blocsSeuls)", "\(stat.blocsAssistes)",
                    "\(stat.receptionsReussies)", "\(stat.erreursReception)",
                    "\(stat.passesDecisives)", "\(stat.manchettes)",
                    "\(stat.points)"
                ].joined(separator: ";")
                lignes.append(ligne)
            }
        }

        let csv = lignes.joined(separator: "\n")
        logger.info("Export CSV matchs : \(matchs.count) matchs")
        return csv.data(using: .utf8) ?? Data()
    }

    // MARK: - Export résultats matchs (résumé)

    /// Génère un CSV avec les résultats de tous les matchs
    static func exporterResultatsMatchs(_ matchs: [Seance]) -> Data {
        var lignes: [String] = []

        lignes.append([
            "Date", "Nom", "Adversaire", "Lieu",
            "Score nous", "Score adversaire", "Résultat",
            "Nombre de sets"
        ].joined(separator: ";"))

        for match in matchs.sorted(by: { $0.date < $1.date }) {
            let ligne = [
                match.date.formatCourt(),
                echapper(match.nom),
                echapper(match.adversaire),
                echapper(match.lieu),
                "\(match.scoreEquipe)", "\(match.scoreAdversaire)",
                echapper(match.resultat?.label ?? ""),
                "\(match.nombreSets)"
            ].joined(separator: ";")
            lignes.append(ligne)
        }

        let csv = lignes.joined(separator: "\n")
        logger.info("Export CSV résultats : \(matchs.count) matchs")
        return csv.data(using: .utf8) ?? Data()
    }

    // MARK: - Helpers

    /// Échappe les guillemets et entoure si nécessaire
    private static func echapper(_ texte: String) -> String {
        if texte.contains(";") || texte.contains("\"") || texte.contains("\n") {
            return "\"\(texte.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return texte
    }
}
