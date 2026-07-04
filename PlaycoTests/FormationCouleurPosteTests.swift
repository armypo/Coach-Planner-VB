//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Phase 5.2 — Source unique des couleurs de jetons de formation :
//  FormationType.couleurPourLabel. Verrouille le mapping poste → couleur
//  et son application dans TerrainEditeurViewModel.ajouterFormation.
//  Phase 5.4 — Duplication d'étape (dessin + éléments copiés).
//

import Testing
import Foundation
import SwiftUI
@testable import Playco

@Suite("FormationType.couleurPourLabel — mapping poste → couleur")
struct FormationCouleurPosteTests {

    @Test("P/C/R/O/L délèguent à PosteJoueur.couleur")
    func postesIndoorViaPosteJoueur() {
        for poste in PosteJoueur.allCases {
            #expect(FormationType.couleurPourLabel(poste.abreviation) == poste.couleur)
        }
    }

    @Test("A (attaquant 4-2/6-2) = violet de la palette")
    func attaquantViolet() {
        #expect(FormationType.couleurPourLabel("A") == PaletteMat.violet)
    }

    @Test("beach : J1/B = bleu, J2/D = orange")
    func labelsBeach() {
        #expect(FormationType.couleurPourLabel("J1") == PaletteMat.bleu)
        #expect(FormationType.couleurPourLabel("B") == PaletteMat.bleu)
        #expect(FormationType.couleurPourLabel("J2") == PaletteMat.orange)
        #expect(FormationType.couleurPourLabel("D") == PaletteMat.orange)
    }

    @Test("label inconnu = gris (fallback)")
    func labelInconnuGris() {
        #expect(FormationType.couleurPourLabel("Z") == Color.gray)
        #expect(FormationType.couleurPourLabel("") == Color.gray)
    }
}

@Suite("TerrainEditeurViewModel — formations & duplication d'étape (Phase 5)")
@MainActor
struct FormationApplicationCouleurTests {

    /// Composantes RGB attendues pour un label, via le même chemin de
    /// conversion Color → UIColor qu'ElementTerrain.
    private func rgbAttendu(_ label: String) -> (Double, Double, Double) {
        let temoin = ElementTerrain(
            type: .joueur, x: 0, y: 0, label: label,
            couleur: FormationType.couleurPourLabel(label))
        return (temoin.r, temoin.g, temoin.b)
    }

    @Test("ajouterFormation colore chaque jeton selon son poste, pas la couleur d'outil")
    func formationCouleursParPoste() {
        let vm = TerrainEditeurViewModel()
        vm.couleur = .white // couleur d'outil courante — ne doit PAS être utilisée

        vm.ajouterFormation(.cinqUn, rotation: 0, mode: .base)

        let joueurs = vm.elements.filter { $0.type == .joueur }
        #expect(joueurs.count == 6)

        for joueur in joueurs {
            let (r, g, b) = rgbAttendu(joueur.label)
            #expect(abs(joueur.r - r) < 0.001, "rouge du jeton \(joueur.label)")
            #expect(abs(joueur.g - g) < 0.001, "vert du jeton \(joueur.label)")
            #expect(abs(joueur.b - b) < 0.001, "bleu du jeton \(joueur.label)")
        }

        // Au moins 2 couleurs distinctes (l'ancien comportement était uniforme)
        let couleursDistinctes = Set(joueurs.map { "\($0.r)-\($0.g)-\($0.b)" })
        #expect(couleursDistinctes.count >= 2)
    }

    @Test("dupliquerEtapeActive copie les éléments dans une nouvelle étape active")
    func dupliquerEtapeCopieElements() {
        let vm = TerrainEditeurViewModel()
        vm.elements = [ElementTerrain(type: .joueur, x: 0.3, y: 0.4,
                                      label: "P", r: 1, g: 1, b: 0)]
        var dessin: Data? = nil
        var elems: Data? = nil

        vm.dupliquerEtapeActive(dessinData: &dessin, elementsData: &elems)

        #expect(vm.etapes.count == 1)
        #expect(vm.etapeActive == 1)
        #expect(elems != nil) // le principal a été sauvegardé avant duplication
        #expect(vm.elements.count == 1) // la copie est chargée dans l'étape active
        #expect(vm.elements.first?.label == "P")
        #expect(vm.etapes.first?.elementsData != nil)
    }
}
