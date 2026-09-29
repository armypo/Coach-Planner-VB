//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//

import Foundation
import Testing
@testable import PlaycoVideo

@Suite("JeuDonnees — export d'entraînement (Loi 25)")
struct JeuDonneesTests {

    private func manifeste(consentement: Bool) -> ManifesteVideoMatch {
        ManifesteVideoMatch(
            seanceID: UUID(),
            codeEquipe: "EQUIPE-SECRETE",
            alignement: Fixtures.alignement(),
            sourceAlignement: .metadonneeFichier,
            consentementEntrainementIA: consentement)
    }

    private let joueur = UUID()

    private var evenements: [EvenementMatch] {
        [Fixtures.evenement(a: 100, etiquette: "Kill", joueurID: joueur),
         Fixtures.evenement(a: 200, etiquette: "Ace", joueurID: joueur)]
    }

    @Test("aucun export sans consentement")
    func sansConsentement() {
        #expect(throws: ErreurJeuDonnees.consentementAbsent) {
            try JeuDonnees.echantillons(manifeste: manifeste(consentement: false), evenements: evenements)
        }
    }

    @Test("un échantillon par clip, étiquettes du coaching")
    func echantillons() throws {
        let m = manifeste(consentement: true)
        let e = try JeuDonnees.echantillons(manifeste: m, evenements: evenements)
        #expect(e.map(\.etiquette) == ["Kill", "Ace"])
        #expect(e.map(\.instant) == [100, 200])
        #expect(e[0].debut == 92)
        #expect(e[0].seanceID == m.seanceID)
        #expect(e[0].fichierVideo == m.nomFichierVideo)
    }

    @Test("minimisation : joueur exclu par défaut, inclus sur demande")
    func minimisation() throws {
        let m = manifeste(consentement: true)
        #expect(try JeuDonnees.echantillons(manifeste: m, evenements: evenements).allSatisfy { $0.joueurID == nil })
        #expect(try JeuDonnees.echantillons(manifeste: m, evenements: evenements, inclureJoueur: true)
            .allSatisfy { $0.joueurID == joueur })
    }

    @Test("JSON Lines : une ligne décodable par échantillon, sans code d'équipe")
    func jsonLines() throws {
        let e = try JeuDonnees.echantillons(manifeste: manifeste(consentement: true), evenements: evenements)
        let data = try JeuDonnees.jsonLines(e)
        let texte = try #require(String(data: data, encoding: .utf8))
        let lignes = texte.split(separator: "\n")
        #expect(lignes.count == 2)
        #expect(!texte.contains("EQUIPE-SECRETE"))
        #expect(!texte.contains("codeEquipe"))
        let relu = try JSONDecoder().decode(EchantillonEntrainement.self, from: Data(lignes[0].utf8))
        #expect(relu == e[0])
    }
}
