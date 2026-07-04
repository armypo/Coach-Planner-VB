//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Non-régression du bug B1 : JoueurEquipe.efficaciteReception retourne un
//  POURCENTAGE 0-100 ; plusieurs consommateurs multipliaient encore par 100
//  (CSV, PDF, Comparaison, Objectifs) et affichaient « 8500 % ».
//  Ces tests verrouillent l'échelle du modèle et la sortie CSV.
//

import Testing
import Foundation
@testable import Playco

@Suite("Efficacité réception — échelle 0-100 (B1)")
@MainActor
struct EfficaciteReceptionEchelleTests {

    private func creerJoueurReception() -> JoueurEquipe {
        let joueur = JoueurEquipe(nom: "Tremblay", prenom: "Léa", numero: 12, poste: .recepteur)
        joueur.receptionsReussies = 20
        joueur.erreursReception = 3
        joueur.receptionsTotales = 25
        return joueur
    }

    @Test("contrat d'échelle — (20-3)/25 retourne 68.0 (pourcentage 0-100, pas 0.68)")
    func contratEchelleModele() {
        let joueur = creerJoueurReception()
        #expect(abs(joueur.efficaciteReception - 68.0) < 0.0001)
    }

    @Test("export CSV — la colonne réception contient 68.0, jamais 6800.0 (B1)")
    func csvSansDoubleMultiplication() throws {
        let joueur = creerJoueurReception()

        let data = CSVExportService.exporterStatsJoueurs([joueur])
        let texte = try #require(String(data: data, encoding: .utf8))

        #expect(texte.contains(";68.0;"))
        #expect(!texte.contains("6800"))
    }
}
