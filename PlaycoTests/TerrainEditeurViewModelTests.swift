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

    // MARK: - Undo / Redo par étape (2.2.a — naviguer ne détruit plus l'historique)

    @Test("changer d'étape conserve l'historique undo du principal")
    func historiqueSurvitAuChangementDEtape() {
        let vm = TerrainEditeurViewModel()
        var dessin: Data? = nil
        var elems: Data? = nil

        vm.enregistrerEtat(description: "avant ajout")
        vm.elements = [elementJoueur(label: "1")]

        // Aller sur une nouvelle étape : elle démarre sans historique propre
        vm.ajouterEtape(dessinData: &dessin, elementsData: &elems)
        #expect(!vm.peutAnnuler)

        // Retour au principal : son historique est intact
        vm.changerEtape(index: 0, dessinData: &dessin, elementsData: &elems)
        #expect(vm.peutAnnuler)

        vm.annuler()
        #expect(vm.elements.isEmpty)
    }

    @Test("chaque étape garde son propre historique undo")
    func historiqueParEtape() {
        let vm = TerrainEditeurViewModel()
        var dessin: Data? = nil
        var elems: Data? = nil

        vm.ajouterEtape(dessinData: &dessin, elementsData: &elems) // étape 1 active, vierge
        vm.enregistrerEtat(description: "avant ajout étape 1")
        vm.elements = [elementJoueur(label: "2"), elementJoueur(label: "3")]

        // Aller-retour principal ↔ étape 1
        vm.changerEtape(index: 0, dessinData: &dessin, elementsData: &elems)
        vm.changerEtape(index: 1, dessinData: &dessin, elementsData: &elems)

        #expect(vm.elements.count == 2)
        #expect(vm.peutAnnuler)
        vm.annuler()
        #expect(vm.elements.isEmpty)
    }

    @Test("supprimer une étape purge son historique (la pile disparaît du dictionnaire)")
    func suppressionPurgeHistorique() {
        let vm = TerrainEditeurViewModel()
        var dessin: Data? = nil
        var elems: Data? = nil

        vm.ajouterEtape(dessinData: &dessin, elementsData: &elems)
        vm.enregistrerEtat(description: "action sur l'étape 1")
        vm.elements = [elementJoueur()]
        #expect(vm.peutAnnuler)
        #expect(vm.nombreDePilesUndo == 1) // seule l'étape 1 a un historique

        vm.supprimerEtape(index: 1, dessinData: dessin, elementsData: elems)
        #expect(vm.etapeActive == 0)

        // La purge est vérifiée sur la couture, pas par déduction d'UUID :
        // la pile de l'étape supprimée a bel et bien disparu.
        #expect(vm.nombreDePilesUndo == 0)
        #expect(vm.nombreSnapshotsUndoTotal == 0)

        vm.ajouterEtape(dessinData: &dessin, elementsData: &elems)
        #expect(!vm.peutAnnuler) // pas d'historique hérité de l'étape supprimée
        #expect(!vm.peutRetablir)
    }

    @Test("redo survit à la navigation entre étapes (aller-retour puis rétablir)")
    func redoSurvitALaNavigation() {
        let vm = TerrainEditeurViewModel()
        var dessin: Data? = nil
        var elems: Data? = nil

        // Principal : action puis annulation → un redo disponible
        vm.enregistrerEtat(description: "avant ajout")
        vm.elements = [elementJoueur(label: "1")]
        vm.annuler()
        #expect(vm.elements.isEmpty)
        #expect(vm.peutRetablir)

        // Aller sur une étape vierge : ni undo ni redo, et annuler() y est
        // un no-op sur les éléments (fallback canvas, pas de vol de pile)
        vm.ajouterEtape(dessinData: &dessin, elementsData: &elems)
        #expect(!vm.peutAnnuler)
        #expect(!vm.peutRetablir)
        vm.annuler()
        #expect(vm.elements.isEmpty)

        // Retour au principal : le redo est toujours là et ré-applique
        vm.changerEtape(index: 0, dessinData: &dessin, elementsData: &elems)
        #expect(vm.peutRetablir)
        vm.retablir()
        #expect(vm.elements.count == 1)
        #expect(vm.elements.first?.label == "1")
    }

    @Test("maxUndo est appliqué PAR étape (20 actions → 15 snapshots, l'autre étape intacte)")
    func maxUndoParEtape() {
        let vm = TerrainEditeurViewModel()
        var dessin: Data? = nil
        var elems: Data? = nil

        for i in 1...20 { vm.enregistrerEtat(description: "action \(i)") }
        #expect(vm.pileUndo.count == 15) // borne par étape respectée

        vm.ajouterEtape(dessinData: &dessin, elementsData: &elems)
        for i in 1...3 { vm.enregistrerEtat(description: "étape 1 — \(i)") }
        #expect(vm.pileUndo.count == 3)

        vm.changerEtape(index: 0, dessinData: &dessin, elementsData: &elems)
        #expect(vm.pileUndo.count == 15) // le principal n'a pas été affecté
    }

    @Test("budget global : les snapshots des étapes non actives sont évincés au-delà de 60")
    func budgetGlobalDesSnapshots() {
        let vm = TerrainEditeurViewModel()
        var dessin: Data? = nil
        var elems: Data? = nil

        // 4 étapes + principal remplis à ras bord (5 × 15 = 75 > 60)
        for i in 1...15 { vm.enregistrerEtat(description: "principal \(i)") }
        for _ in 1...4 {
            vm.ajouterEtape(dessinData: &dessin, elementsData: &elems)
            for i in 1...15 { vm.enregistrerEtat(description: "étape \(i)") }
        }

        #expect(vm.nombreSnapshotsUndoTotal <= 60) // budget global respecté
        #expect(vm.pileUndo.count == 15) // l'étape ACTIVE garde tout son historique
    }

    // MARK: - Duplication « Continuer » (2.3.1)

    @Test("« Continuer » : les arrivées deviennent les départs, traits effacés")
    func dupliquerContinuerDeplaceLesJetons() {
        let vm = TerrainEditeurViewModel()
        var dessin: Data? = nil
        var elems: Data? = nil

        let joueur = elementJoueur(label: "7") // départ (0.25, 0.5)
        var fleche = ElementTerrain(type: .fleche, x: 0.26, y: 0.51, label: "", r: 1, g: 1, b: 1)
        fleche.toX = 0.6
        fleche.toY = 0.3
        var flecheOrpheline = ElementTerrain(type: .fleche, x: 0.9, y: 0.9, label: "", r: 1, g: 1, b: 1)
        flecheOrpheline.toX = 0.95
        flecheOrpheline.toY = 0.95 // aucun jeton à proximité → ignorée
        vm.elements = [joueur, fleche, flecheOrpheline]

        vm.dupliquerEtapeContinuer(dessinData: &dessin, elementsData: &elems)

        #expect(vm.etapes.count == 1)
        #expect(vm.etapeActive == 1)
        #expect(vm.elements.count == 1) // seuls les jetons survivent
        #expect(vm.elements.first?.type == .joueur)
        #expect(abs((vm.elements.first?.x ?? 0) - 0.6) < 0.0001)
        #expect(abs((vm.elements.first?.y ?? 0) - 0.3) < 0.0001)
    }

    @Test("« Continuer » sans trajectoires : les jetons restent en place")
    func dupliquerContinuerSansTraits() {
        let vm = TerrainEditeurViewModel()
        var dessin: Data? = nil
        var elems: Data? = nil
        vm.elements = [elementJoueur(label: "3")]

        vm.dupliquerEtapeContinuer(dessinData: &dessin, elementsData: &elems)

        #expect(vm.etapeActive == 1)
        #expect(vm.elements.count == 1)
        #expect(abs((vm.elements.first?.x ?? 0) - 0.25) < 0.0001)
    }

    @Test("charger un document remet tout l'historique à zéro")
    func chargerRemetLHistoriqueAZero() {
        let vm = TerrainEditeurViewModel()
        vm.enregistrerEtat()
        vm.elements = [elementJoueur()]
        #expect(vm.peutAnnuler)

        vm.charger(dessinData: nil, elementsData: nil, etapesData: nil)

        #expect(!vm.peutAnnuler)
        #expect(!vm.peutRetablir)
    }
}
