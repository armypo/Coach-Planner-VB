//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import PencilKit
import Combine
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "TerrainEditeurViewModel")

/// ViewModel @Observable pour TerrainEditeurView (P1-05 + P0-03)
/// Centralise les 16+ @State en un objet testable et découplé de la vue
@Observable
final class TerrainEditeurViewModel {

    // MARK: - État du terrain
    var drawing         = PKDrawing()
    var elements: [ElementTerrain] = []
    var modeActif: ModeDessin = .curseur
    var couleur: Color   = .white
    var epaisseur: CGFloat = 3
    var prochainNumero   = 1
    var afficherZones    = true
    var afficherDessinLibre = true
    var clipboardElements: [ElementTerrain]? = nil
    var etapesVerrouillees: Set<Int> = []

    // Notes
    var notesDeployees   = false

    // Canvas controller (ObservableObject legacy pour UIViewRepresentable)
    let canvasCtrl = CanvasController()

    // Sauvegarde — debounce 3s (P0-03 v0.4.0)
    var derniereSauvegarde: Date?
    var aDesModifications = false
    @ObservationIgnored private let saveSubject = PassthroughSubject<Void, Never>()
    @ObservationIgnored private(set) lazy var debounceSave: AnyPublisher<Void, Never> = saveSubject
        .debounce(for: .seconds(3), scheduler: RunLoop.main)
        .eraseToAnyPublisher()

    deinit {
        saveSubject.send(completion: .finished)
    }

    func planifierSauvegarde() {
        aDesModifications = true
        saveSubject.send()
    }

    // Étapes
    var etapes: [EtapeExercice] = []
    var etapeActive: Int = 0  // 0 = principal, 1+ = étapes supplémentaires

    // MARK: - Undo / Redo — Command Pattern (P0-03)

    /// Snapshot d'un état complet (éléments + dessin) pour undo/redo
    struct TerrainSnapshot {
        let elements: [ElementTerrain]
        let drawingData: Data
        let description: String

        init(elements: [ElementTerrain], drawing: PKDrawing, description: String = "") {
            self.elements = elements
            self.drawingData = drawing.dataRepresentation()
            self.description = description
        }

        var drawing: PKDrawing {
            (try? PKDrawing(data: drawingData)) ?? PKDrawing()
        }
    }

    private(set) var pileUndo: [TerrainSnapshot] = []
    private(set) var pileRedo: [TerrainSnapshot] = []
    private let maxUndo = 15

    var peutAnnuler: Bool  { !pileUndo.isEmpty }
    var peutRetablir: Bool { !pileRedo.isEmpty }

    // MARK: - Verrouillage

    var verrouille: Bool {
        etapesVerrouillees.contains(etapeActive)
    }

    func toggleVerrouillage() {
        if etapesVerrouillees.contains(etapeActive) {
            etapesVerrouillees.remove(etapeActive)
        } else {
            etapesVerrouillees.insert(etapeActive)
        }
    }

    // MARK: - Undo / Redo

    /// Enregistre l'état actuel avant une modification (snapshot complet)
    func enregistrerEtat(description: String = "") {
        let snapshot = TerrainSnapshot(elements: elements, drawing: drawing, description: description)
        pileUndo.append(snapshot)
        pileRedo.removeAll()
        if pileUndo.count > maxUndo { pileUndo.removeFirst() }
        aDesModifications = true
    }

    func annuler() {
        if let snapshot = pileUndo.popLast() {
            pileRedo.append(TerrainSnapshot(elements: elements, drawing: drawing, description: ""))
            elements = snapshot.elements
            drawing = snapshot.drawing
        } else {
            canvasCtrl.annuler()
        }
    }

    func retablir() {
        if let snapshot = pileRedo.popLast() {
            pileUndo.append(TerrainSnapshot(elements: elements, drawing: drawing, description: ""))
            elements = snapshot.elements
            drawing = snapshot.drawing
        } else {
            canvasCtrl.retablir()
        }
    }

    // MARK: - Formations

    func ajouterFormation(_ type: FormationType, rotation: Int = 0, mode: FormationMode = .base,
                          formationsPerso: [FormationPersonnalisee] = []) {
        enregistrerEtat(description: "Formation \(type.rawValue)")
        elements.removeAll { $0.type == .joueur }

        // P0-04 v0.4.0 — Cache local pour éviter double décodage JSON de .positions
        if let perso = formationsPerso.first(where: {
            $0.formationTypeRaw == type.rawValue &&
            $0.rotation == rotation &&
            $0.modeRaw == mode.rawValue
        }) {
            let positionsCache = perso.positions
            guard !positionsCache.isEmpty else {
                let positions = type.positions(rotation: rotation, mode: mode)
                for pos in positions {
                    elements.append(ElementTerrain(
                        type: .joueur, x: pos.x, y: pos.y,
                        label: pos.label, couleur: couleur))
                }
                return
            }
            for pos in positionsCache {
                elements.append(ElementTerrain(
                    type: .joueur, x: pos.x, y: pos.y,
                    label: pos.label, couleur: couleur))
            }
        } else {
            let positions = type.positions(rotation: rotation, mode: mode)
            for pos in positions {
                elements.append(ElementTerrain(
                    type: .joueur, x: pos.x, y: pos.y,
                    label: pos.label, couleur: couleur))
            }
        }
    }

    // MARK: - Placer un joueur depuis la base de données

    func placerJoueurBD(_ joueur: JoueurEquipe) {
        enregistrerEtat(description: "Joueur #\(joueur.numero)")
        let elem = ElementTerrain(
            type: .joueur, x: 0.25, y: 0.50,
            label: "\(joueur.numero)", couleur: joueur.poste.couleur)
        elements.append(elem)
    }

    // MARK: - Charger une stratégie offensive

    func chargerStrategie(_ strat: StrategieCollective) {
        enregistrerEtat(description: "Stratégie \(strat.nom)")
        if let data = strat.elementsData,
           let elems = try? JSONCoderCache.decoder.decode([ElementTerrain].self, from: data) {
            let nouveaux = elems.map { el in
                var copie = el; copie.id = UUID(); return copie
            }
            elements.append(contentsOf: nouveaux)
        }
    }

    // MARK: - Effacer tout

    func effacerTout() {
        enregistrerEtat(description: "Effacer tout")
        drawing = PKDrawing()
        elements = []
    }

    // MARK: - Gestion des étapes

    func sauvegarderEtapeActive(dessinData: inout Data?, elementsData: inout Data?) {
        let dessin = drawing.dataRepresentation()
        let elems = try? JSONCoderCache.encoder.encode(elements)

        if etapeActive == 0 {
            dessinData = dessin
            elementsData = elems
        } else {
            let idx = etapeActive - 1
            if idx < etapes.count {
                etapes[idx].dessinData = dessin
                etapes[idx].elementsData = elems
            }
        }
    }

    func chargerEtapeActive(dessinData: Data?, elementsData: Data?) {
        pileUndo.removeAll()
        pileRedo.removeAll()

        if etapeActive == 0 {
            if let d = dessinData, let pk = try? PKDrawing(data: d) { drawing = pk }
            else { drawing = PKDrawing() }
            if let d = elementsData,
               let dec = try? JSONCoderCache.decoder.decode([ElementTerrain].self, from: d) {
                elements = dec
            } else { elements = [] }
        } else {
            let idx = etapeActive - 1
            if idx < etapes.count {
                let etape = etapes[idx]
                if let d = etape.dessinData, let pk = try? PKDrawing(data: d) { drawing = pk }
                else { drawing = PKDrawing() }
                if let d = etape.elementsData,
                   let dec = try? JSONCoderCache.decoder.decode([ElementTerrain].self, from: d) {
                    elements = dec
                } else { elements = [] }
            }
        }

        prochainNumero = (elements.filter { $0.type == .joueur }
            .compactMap { Int($0.label) }.max() ?? 0) + 1
    }

    func sauvegarderEtapes() -> Data? {
        try? JSONCoderCache.encoder.encode(etapes)
    }

    func ajouterEtape(dessinData: inout Data?, elementsData: inout Data?) {
        sauvegarderEtapeActive(dessinData: &dessinData, elementsData: &elementsData)
        etapes.append(EtapeExercice(nom: ""))
        etapeActive = etapes.count
        chargerEtapeActive(dessinData: dessinData, elementsData: elementsData)
    }

    func changerEtape(index: Int, dessinData: inout Data?, elementsData: inout Data?) {
        guard etapeActive != index else { return }
        sauvegarderEtapeActive(dessinData: &dessinData, elementsData: &elementsData)
        etapeActive = index
        chargerEtapeActive(dessinData: dessinData, elementsData: elementsData)
    }

    func renommerEtape(index: Int) {
        let idx = index - 1
        if idx < etapes.count {
            if etapes[idx].nom.isEmpty {
                etapes[idx].nom = "Ét. \(index + 1)"
            }
        }
    }

    func supprimerEtape(index: Int, dessinData: Data?, elementsData: Data?) {
        let idx = index - 1
        guard idx < etapes.count else { return }

        if etapeActive == index {
            etapeActive = 0
            chargerEtapeActive(dessinData: dessinData, elementsData: elementsData)
        } else if etapeActive > index {
            etapeActive -= 1
        }

        etapes.remove(at: idx)
    }

    // MARK: - Persistance (P2-07)

    func charger(dessinData: Data?, elementsData: Data?, etapesData: Data?) {
        if let d = etapesData {
            do {
                etapes = try JSONCoderCache.decoder.decode([EtapeExercice].self, from: d)
            } catch {
                logger.warning("Échec chargement étapes: \(error.localizedDescription)")
                etapes = []
            }
        }
        chargerEtapeActive(dessinData: dessinData, elementsData: elementsData)
        aDesModifications = false
    }

    func sauvegarder(dessinData: inout Data?, elementsData: inout Data?, etapesData: inout Data?) {
        sauvegarderEtapeActive(dessinData: &dessinData, elementsData: &elementsData)
        etapesData = sauvegarderEtapes()
        derniereSauvegarde = Date()
        aDesModifications = false
    }
}
