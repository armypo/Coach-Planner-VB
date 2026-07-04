//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Tests de CKRecord.chaineSecurisee — sanitisation des champs texte lus
//  depuis la Public DB CloudKit (données externes non fiables).
//

import Testing
import Foundation
import CloudKit
@testable import Playco

@Suite("CKRecord.chaineSecurisee — lecture sécurisée des records publics")
struct ChaineSecuriseeTests {

    private func record(avec valeur: String, cle: String = "cle") -> CKRecord {
        let record = CKRecord(recordType: "Test")
        record[cle] = valeur
        return record
    }

    @Test("Les caractères de contrôle sont supprimés")
    func caracteresDeControleSupprimes() {
        // Arrange — BEL (0x07), VT (0x0B), NUL (0x00) intercalés
        let record = record(avec: "abc\u{07}def\u{0B}ghi\u{00}")

        // Act
        let resultat = record.chaineSecurisee("cle")

        // Assert
        #expect(resultat == "abcdefghi")
    }

    @Test("Les sauts de ligne et tabulations sont conservés (légitimes dans les notes)")
    func sautsDeLigneEtTabulationsConserves() {
        // Arrange
        let record = record(avec: "ligne1\nligne2\tfin")

        // Act
        let resultat = record.chaineSecurisee("cle")

        // Assert
        #expect(resultat == "ligne1\nligne2\tfin")
    }

    @Test("Les chaînes dégénérées sont tronquées à 2000 caractères")
    func troncatureA2000() {
        // Arrange
        let record = record(avec: String(repeating: "a", count: 2500))

        // Act
        let resultat = record.chaineSecurisee("cle")

        // Assert
        #expect(resultat?.count == 2000)
    }

    @Test("Les espaces de bord sont retirés")
    func espacesDeBordRetires() {
        // Arrange
        let record = record(avec: "  Élans de Garneau  ")

        // Act
        let resultat = record.chaineSecurisee("cle")

        // Assert
        #expect(resultat == "Élans de Garneau")
    }

    @Test("Clé absente : retourne nil")
    func cleAbsenteRetourneNil() {
        // Arrange
        let record = CKRecord(recordType: "Test")

        // Act / Assert
        #expect(record.chaineSecurisee("absente") == nil)
    }
}
