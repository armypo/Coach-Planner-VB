//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Tests 2.3.1 : cadrage demi-terrain — rawValues stables, legacy sûr, ratios.
//

import Testing
import Foundation
@testable import Playco

@Suite("TypeTerrain — demi-terrain (2.3.1)")
struct TypeTerrainTests {

    @Test("rawValues stables (contrat de persistance)")
    func rawValuesStables() {
        #expect(TypeTerrain.indoor.rawValue == "Indoor")
        #expect(TypeTerrain.beach.rawValue == "Beach")
        #expect(TypeTerrain.demiTerrain.rawValue == "DemiTerrain")
    }

    @Test("le legacy et l'inconnu retombent sur indoor (piège #6)")
    func decodageLegacySur() {
        #expect(TypeTerrain(rawValue: "Indoor") == .indoor)
        #expect((TypeTerrain(rawValue: "terrain_mystere") ?? .indoor) == .indoor)
    }

    @Test("formations remappées sur demi-terrain : la ligne arrière s'éloigne du filet")
    @MainActor
    func formationsRemappees() {
        let vm = TerrainEditeurViewModel()
        vm.ajouterFormation(.cinqUn, typeTerrain: .demiTerrain)
        let xs = vm.elements.filter { $0.type == .joueur }.map(\.x)
        #expect(xs.count == 6)
        // Plein terrain : x ∈ [0.12 ; 0.38] (filet à 0.5). Remappé : la
        // distance au filet se projette sur toute la largeur → x ∈ [0.24 ; 0.76]
        // et la ligne ARRIÈRE (ex-0.12) est désormais LOIN du filet (x élevé).
        #expect(xs.allSatisfy { $0 > 0.2 && $0 < 0.8 })
        #expect(xs.max()! > 0.7) // les arrières au fond, plus au filet
    }

    @Test("ratios d'affichage : 2:1 plein terrain, 1:1 demi-terrain")
    func ratios() {
        #expect(TypeTerrain.indoor.ratioHorizontal == 2.0)
        #expect(TypeTerrain.indoor.ratioVertical == 0.5)
        #expect(TypeTerrain.demiTerrain.ratioHorizontal == 1.0)
        #expect(TypeTerrain.demiTerrain.ratioVertical == 1.0)
    }
}
