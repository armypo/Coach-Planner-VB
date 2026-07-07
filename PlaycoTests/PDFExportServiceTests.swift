//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Smoke tests de PDFExportService : Data non vide, préfixe magique `%PDF`,
//  aucun crash avec des données vides.
//

import Testing
import Foundation
@testable import Playco

@Suite("PDFExportService — génération PDF")
@MainActor
struct PDFExportServiceTests {

    private static let prefixeMagiquePDF = Data("%PDF".utf8)

    // MARK: - Résumé de match

    @Test("genererPDFMatch — match complet : Data non vide avec préfixe %PDF")
    func pdfMatchComplet() {
        // Arrange
        let match = Seance(nom: "Match vs Titans", typeSeance: .match)
        match.adversaire = "Titans"
        match.lieu = "Gymnase A"
        match.notesMatch = "Belle performance au service."
        match.sets = [
            SetScore(numero: 1, scoreEquipe: 25, scoreAdversaire: 21),
            SetScore(numero: 2, scoreEquipe: 23, scoreAdversaire: 25),
            SetScore(numero: 3, scoreEquipe: 25, scoreAdversaire: 19),
        ]

        let joueur = JoueurEquipe(nom: "Tremblay", prenom: "Jean", numero: 7, poste: .oppose)
        let stat = StatsMatch(seanceID: match.id, joueurID: joueur.id)
        stat.kills = 14
        stat.erreursAttaque = 4
        stat.tentativesAttaque = 32
        stat.aces = 3
        stat.receptionsReussies = 10
        stat.receptionsTotales = 12

        // Act
        let data = PDFExportService.genererPDFMatch(seance: match, joueurs: [joueur], statsMatch: [stat])

        // Assert
        #expect(!data.isEmpty, "Le PDF généré ne doit pas être vide")
        #expect(data.prefix(4) == Self.prefixeMagiquePDF, "Préfixe magique %PDF attendu")
    }

    @Test("genererPDFMatch — joueurs et stats vides : aucun crash, PDF valide")
    func pdfMatchDonneesVides() {
        // Arrange — séance nue, sans sets, sans notes
        let seance = Seance(nom: "Match vide", typeSeance: .match)

        // Act
        let data = PDFExportService.genererPDFMatch(seance: seance, joueurs: [], statsMatch: [])

        // Assert
        #expect(!data.isEmpty)
        #expect(data.prefix(4) == Self.prefixeMagiquePDF)
    }

    // MARK: - Fiche joueur

    @Test("genererPDFJoueur — moyennes équipe vides : aucun crash, PDF valide")
    func pdfJoueurMoyennesVides() {
        // Arrange — joueur sans aucune stat
        let joueur = JoueurEquipe(nom: "Neuf", prenom: "Tout", numero: 1, poste: .libero)

        // Act
        let data = PDFExportService.genererPDFJoueur(joueur: joueur, moyenneEquipe: [:])

        // Assert
        #expect(!data.isEmpty)
        #expect(data.prefix(4) == Self.prefixeMagiquePDF)
    }

    @Test("genererPDFJoueur — joueur avec stats et moyennes renseignées : PDF valide")
    func pdfJoueurAvecStats() {
        // Arrange
        let joueur = JoueurEquipe(nom: "Tremblay", prenom: "Jean", numero: 7, poste: .central)
        joueur.taille = 192
        joueur.matchsJoues = 12
        joueur.attaquesReussies = 80
        joueur.erreursAttaque = 20
        joueur.attaquesTotales = 200
        joueur.aces = 15
        joueur.blocsSeuls = 8
        joueur.blocsAssistes = 14

        let moyennes: [String: Double] = [
            "kills": 45.0, "hittingPct": 0.25, "aces": 9.0,
            "blocsSeuls": 4.0, "blocsAssistes": 10.0, "receptionEff": 0.6, "passes": 20.0,
        ]

        // Act
        let data = PDFExportService.genererPDFJoueur(joueur: joueur, moyenneEquipe: moyennes)

        // Assert
        #expect(!data.isEmpty)
        #expect(data.prefix(4) == Self.prefixeMagiquePDF)
    }

    // MARK: - Plan de pratique (2.6.2)

    @Test("genererPlanPratique — séance avec exercices : PDF valide")
    func planPratiqueComplet() {
        let seance = Seance(nom: "Pratique mardi", typeSeance: .pratique)
        let exo = Exercice(nom: "Réception R1", notes: "10 réceptions dans la cible", ordre: 0, duree: 12)
        seance.exercices = [exo]
        let joueur = JoueurEquipe(nom: "Tremblay", prenom: "Laurie", numero: 7, poste: .passeur)

        let data = PDFExportService.genererPlanPratique(seance: seance, joueurs: [joueur])

        #expect(!data.isEmpty)
        #expect(String(data: data.prefix(4), encoding: .ascii) == "%PDF")
    }

    @Test("genererPlanPratique — séance vide : aucun crash, PDF valide")
    func planPratiqueVide() {
        let seance = Seance(nom: "Pratique", typeSeance: .pratique)

        let data = PDFExportService.genererPlanPratique(seance: seance, joueurs: [])

        #expect(String(data: data.prefix(4), encoding: .ascii) == "%PDF")
    }
}
