//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Smoke tests de CSVExportService : en-têtes, séparateur point-virgule,
//  listes vides (en-tête seul) et échappement des champs (`;` et `"`).
//

import Testing
import Foundation
@testable import Playco

@Suite("CSVExportService — export CSV")
@MainActor
struct CSVExportServiceTests {

    // MARK: - Helpers

    private func decoderCSV(_ data: Data) throws -> [String] {
        let texte = try #require(String(data: data, encoding: .utf8), "Le CSV doit être décodable en UTF-8")
        #expect(!texte.isEmpty)
        return texte.components(separatedBy: "\n")
    }

    private func creerJoueur(prenom: String = "Jean", nom: String = "Tremblay", numero: Int = 7) -> JoueurEquipe {
        let joueur = JoueurEquipe(nom: nom, prenom: prenom, numero: numero, poste: .passeur)
        joueur.matchsJoues = 3
        joueur.setsJoues = 9
        joueur.attaquesReussies = 20
        joueur.erreursAttaque = 5
        joueur.attaquesTotales = 50
        joueur.aces = 4
        return joueur
    }

    private func creerMatch(adversaire: String = "Titans") -> Seance {
        let match = Seance(nom: "Match 1", typeSeance: .match)
        match.adversaire = adversaire
        match.lieu = "Gymnase A"
        match.sets = [
            SetScore(numero: 1, scoreEquipe: 25, scoreAdversaire: 20),
            SetScore(numero: 2, scoreEquipe: 25, scoreAdversaire: 18),
        ]
        return match
    }

    // MARK: - exporterStatsJoueurs

    @Test("exporterStatsJoueurs — en-tête attendu, séparateur point-virgule et ligne joueur")
    func statsJoueursEnTeteEtLigne() throws {
        // Arrange
        let joueur = creerJoueur()

        // Act
        let data = CSVExportService.exporterStatsJoueurs([joueur])
        let lignes = try decoderCSV(data)

        // Assert
        #expect(lignes.count == 2, "En-tête + 1 joueur")
        #expect(lignes[0].hasPrefix("Numéro;Prénom;Nom;Poste;"), "En-tête avec séparateur point-virgule")
        #expect(lignes[0].contains(";Kills;"))
        #expect(lignes[0].contains(";Points calculés"))
        #expect(lignes[1].hasPrefix("7;Jean;Tremblay;Passeur;"))
        #expect(lignes[1].components(separatedBy: ";").count
                == lignes[0].components(separatedBy: ";").count,
                "Même nombre de colonnes que l'en-tête")
    }

    @Test("exporterStatsJoueurs — liste vide : en-tête seul")
    func statsJoueursListeVide() throws {
        // Act
        let data = CSVExportService.exporterStatsJoueurs([])
        let lignes = try decoderCSV(data)

        // Assert
        #expect(lignes.count == 1, "Aucune ligne de données, seulement l'en-tête")
        #expect(lignes[0].hasPrefix("Numéro;"))
    }

    @Test("exporterStatsJoueurs — échappement d'un nom contenant point-virgule et guillemets")
    func statsJoueursEchappement() throws {
        // Arrange — prénom avec `;`, nom avec `"`
        let joueur = creerJoueur(prenom: "Jean;Paul", nom: "O\"Neil")

        // Act
        let data = CSVExportService.exporterStatsJoueurs([joueur])
        let lignes = try decoderCSV(data)

        // Assert — champ entouré de guillemets, guillemets internes doublés
        #expect(lignes[1].contains("\"Jean;Paul\""), "Champ avec `;` entouré de guillemets")
        #expect(lignes[1].contains("\"O\"\"Neil\""), "Guillemet interne doublé (RFC 4180)")
    }

    // MARK: - exporterResultatsMatchs

    @Test("exporterResultatsMatchs — en-tête attendu et une ligne par match")
    func resultatsMatchsEnTeteEtLigne() throws {
        // Arrange
        let match = creerMatch()

        // Act
        let data = CSVExportService.exporterResultatsMatchs([match])
        let lignes = try decoderCSV(data)

        // Assert
        #expect(lignes.count == 2)
        #expect(lignes[0] == "Date;Nom;Adversaire;Lieu;Score nous;Score adversaire;Résultat;Nombre de sets")
        #expect(lignes[1].contains(";Titans;"))
        #expect(lignes[1].contains(";2;0;"), "2 sets gagnés, 0 perdu")
        #expect(lignes[1].hasSuffix(";2"), "Nombre de sets joués en dernière colonne")
    }

    @Test("exporterResultatsMatchs — liste vide : en-tête seul")
    func resultatsMatchsListeVide() throws {
        // Act
        let data = CSVExportService.exporterResultatsMatchs([])
        let lignes = try decoderCSV(data)

        // Assert
        #expect(lignes.count == 1)
        #expect(lignes[0].hasPrefix("Date;Nom;Adversaire;"))
    }

    // MARK: - exporterStatsParMatch

    @Test("exporterStatsParMatch — en-tête attendu et ligne box score par joueur")
    func statsParMatchEnTeteEtLigne() throws {
        // Arrange
        let joueur = creerJoueur()
        let match = creerMatch()
        let stat = StatsMatch(seanceID: match.id, joueurID: joueur.id)
        stat.kills = 12
        stat.erreursAttaque = 3
        stat.tentativesAttaque = 30
        stat.aces = 2

        // Act
        let data = CSVExportService.exporterStatsParMatch(matchs: [match], statsMatchs: [stat], joueurs: [joueur])
        let lignes = try decoderCSV(data)

        // Assert
        #expect(lignes.count == 2, "En-tête + 1 ligne joueur")
        #expect(lignes[0].hasPrefix("Date;Adversaire;Lieu;Résultat;Score;"))
        #expect(lignes[1].contains("Jean Tremblay"))
        #expect(lignes[1].contains(";Titans;"))
        #expect(lignes[1].contains(";12;3;30;"), "Kills, erreurs et tentatives du box score")
    }

    @Test("exporterStatsParMatch — listes vides : en-tête seul")
    func statsParMatchListesVides() throws {
        // Act
        let data = CSVExportService.exporterStatsParMatch(matchs: [], statsMatchs: [], joueurs: [])
        let lignes = try decoderCSV(data)

        // Assert
        #expect(lignes.count == 1)
        #expect(lignes[0].hasPrefix("Date;Adversaire;"))
    }
}
