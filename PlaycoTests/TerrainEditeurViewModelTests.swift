//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//

import Testing
import Foundation
@testable import Playco

@Suite("TerrainEditeurViewModel — étapes & undo/redo")
@MainActor
struct TerrainEditeurViewModelTests {

    private func elementJoueur(label: String = "7") -> ElementTerrain {
        ElementTerrain(type: .joueur, x: 0.25, y: 0.5, label: label, r: 1, g: 1, b: 1)
    }

    // MARK: - sauvegarderEtapeActive

    @Test("sauvegarderEtapeActive écrit le principal quand etapeActive == 0")
    func sauvegardePrincipal() {
        let vm = TerrainEditeurViewModel()
        vm.elements = [elementJoueur()]
        var dessin: Data? = nil
        var elems: Data? = nil

        let ok = vm.sauvegarderEtapeActive(dessinData: &dessin, elementsData: &elems)

        #expect(ok)
        #expect(dessin != nil)
        #expect(elems != nil)
    }

    @Test("sauvegarderEtapeActive retourne false si l'étape active est hors bornes")
    func sauvegardeHorsBornes() {
        let vm = TerrainEditeurViewModel()
        vm.etapeActive = 3 // aucune étape n'existe
        var dessin: Data? = nil
        var elems: Data? = nil

        let ok = vm.sauvegarderEtapeActive(dessinData: &dessin, elementsData: &elems)

        #expect(!ok)
        #expect(elems == nil) // rien ne doit être écrasé en cas d'échec
    }

    // MARK: - Étapes

    @Test("ajouterEtape crée une étape, l'active et repart d'un terrain vierge")
    func ajouterEtapeCreeEtActive() {
        let vm = TerrainEditeurViewModel()
        vm.elements = [elementJoueur()]
        var dessin: Data? = nil
        var elems: Data? = nil

        vm.ajouterEtape(dessinData: &dessin, elementsData: &elems)

        #expect(vm.etapes.count == 1)
        #expect(vm.etapeActive == 1)
        #expect(elems != nil) // le principal a été sauvegardé avant le changement
    }

    @Test("changerEtape sauvegarde l'étape courante et restaure la cible")
    func changerEtapeAllerRetour() {
        let vm = TerrainEditeurViewModel()
        vm.elements = [elementJoueur(label: "1")]
        var dessin: Data? = nil
        var elems: Data? = nil

        // Étape 1 créée : on y place 2 joueurs
        vm.ajouterEtape(dessinData: &dessin, elementsData: &elems)
        vm.elements = [elementJoueur(label: "2"), elementJoueur(label: "3")]

        // Retour au principal → 1 joueur restauré
        vm.changerEtape(index: 0, dessinData: &dessin, elementsData: &elems)
        #expect(vm.etapeActive == 0)
        #expect(vm.elements.count == 1)
        #expect(vm.elements.first?.label == "1")

        // Retour à l'étape 1 → 2 joueurs restaurés
        vm.changerEtape(index: 1, dessinData: &dessin, elementsData: &elems)
        #expect(vm.etapeActive == 1)
        #expect(vm.elements.count == 2)
    }

    @Test("changerEtape vers l'étape déjà active ne fait rien")
    func changerEtapeMemeIndex() {
        let vm = TerrainEditeurViewModel()
        vm.elements = [elementJoueur()]
        var dessin: Data? = nil
        var elems: Data? = nil

        vm.changerEtape(index: 0, dessinData: &dessin, elementsData: &elems)

        #expect(vm.etapeActive == 0)
        #expect(vm.elements.count == 1) // état intact, aucune sauvegarde/rechargement
    }

    // MARK: - Undo / Redo

    @Test("annuler restaure l'état précédent, retablir le ré-applique")
    func undoRedo() {
        let vm = TerrainEditeurViewModel()

        vm.enregistrerEtat(description: "avant ajout")
        vm.elements = [elementJoueur()]

        vm.annuler()
        #expect(vm.elements.isEmpty)
        #expect(vm.peutRetablir)

        vm.retablir()
        #expect(vm.elements.count == 1)
    }

    @Test("enregistrerEtat vide la pile redo")
    func nouvelEtatVideRedo() {
        let vm = TerrainEditeurViewModel()
        vm.enregistrerEtat()
        vm.elements = [elementJoueur()]
        vm.annuler()
        #expect(vm.peutRetablir)

        vm.enregistrerEtat(description: "nouvelle action")

        #expect(!vm.peutRetablir)
    }
}
