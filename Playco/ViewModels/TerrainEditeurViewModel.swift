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

    // 2.2.a — piles PAR ÉTAPE (clé stable) : naviguer entre les étapes ne détruit
    // plus l'historique ; seul le chargement d'un document (charger) le remet à zéro.
    private var pilesUndo: [String: [TerrainSnapshot]] = [:]
    private var pilesRedo: [String: [TerrainSnapshot]] = [:]
    private let maxUndo = 15

    private static let clePrincipal = "principal"

    /// Clé stable de l'étape active : UUID de l'étape, ou "principal" pour l'étape 0.
    private var cleEtapeActive: String {
        guard etapeActive > 0, etapeActive - 1 < etapes.count else { return Self.clePrincipal }
        return etapes[etapeActive - 1].id.uuidString
    }

    var pileUndo: [TerrainSnapshot] { pilesUndo[cleEtapeActive] ?? [] }
    var pileRedo: [TerrainSnapshot] { pilesRedo[cleEtapeActive] ?? [] }

    var peutAnnuler: Bool  { !pileUndo.isEmpty }
    var peutRetablir: Bool { !pileRedo.isEmpty }

    /// Budget GLOBAL de snapshots undo, toutes étapes confondues (revue LO-002) :
    /// chaque snapshot embarque le dessin PencilKit sérialisé — sans borne
    /// globale, la mémoire croît en 15 × (nombre d'étapes). L'étape active
    /// garde toujours ses maxUndo snapshots ; au-delà du budget, les plus
    /// anciens des étapes NON actives sont évincés.
    private let maxSnapshotsTotal = 60

    /// Coutures de test (revue LO-003) — permettent de vérifier la purge de
    /// supprimerEtape et le budget global sans exposer les dictionnaires.
    var nombreDePilesUndo: Int { pilesUndo.count }
    var nombreSnapshotsUndoTotal: Int { pilesUndo.values.reduce(0) { $0 + $1.count } }

    private func appliquerBudgetGlobal() {
        var total = nombreSnapshotsUndoTotal
        guard total > maxSnapshotsTotal else { return }
        let cleActive = cleEtapeActive
        for cle in pilesUndo.keys.sorted() where cle != cleActive {
            while total > maxSnapshotsTotal, !(pilesUndo[cle]?.isEmpty ?? true) {
                pilesUndo[cle]?.removeFirst()
                total -= 1
            }
        }
    }

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
        let cle = cleEtapeActive
        let snapshot = TerrainSnapshot(elements: elements, drawing: drawing, description: description)
        pilesUndo[cle, default: []].append(snapshot)
        pilesRedo[cle] = []
        if pilesUndo[cle]!.count > maxUndo { pilesUndo[cle]!.removeFirst() }
        appliquerBudgetGlobal()
        aDesModifications = true
    }

    func annuler() {
        let cle = cleEtapeActive
        if let snapshot = pilesUndo[cle]?.popLast() {
            pilesRedo[cle, default: []].append(TerrainSnapshot(elements: elements, drawing: drawing, description: ""))
            elements = snapshot.elements
            drawing = snapshot.drawing
        } else {
            canvasCtrl.annuler()
        }
    }

    func retablir() {
        let cle = cleEtapeActive
        if let snapshot = pilesRedo[cle]?.popLast() {
            pilesUndo[cle, default: []].append(TerrainSnapshot(elements: elements, drawing: drawing, description: ""))
            elements = snapshot.elements
            drawing = snapshot.drawing
        } else {
            canvasCtrl.retablir()
        }
    }

    // MARK: - Formations

    /// Revue 2.3.1 : sur le preset demi-terrain (filet au bord gauche), les
    /// positions plein-terrain (filet à x=0.5, demi gauche) sont remappées —
    /// la distance au filet se projette sur toute la largeur du carré.
    private func remapPourDemiTerrain(x: Double) -> Double {
        min(max((0.5 - x) * 2, 0.04), 0.96)
    }

    func ajouterFormation(_ type: FormationType, rotation: Int = 0, mode: FormationMode = .base,
                          formationsPerso: [FormationPersonnalisee] = [],
                          typeTerrain: TypeTerrain = .indoor) {
        enregistrerEtat(description: "Formation \(type.rawValue)")
        elements.removeAll { $0.type == .joueur }
        let remap = typeTerrain == .demiTerrain

        // P0-04 v0.4.0 — Cache local pour éviter double décodage JSON de .positions
        if let perso = formationsPerso.first(where: {
            $0.formationTypeRaw == type.rawValue &&
            $0.rotation == rotation &&
            $0.modeRaw == mode.rawValue
        }) {
            let positionsCache = perso.positions
            guard !positionsCache.isEmpty else {
                ajouterJoueursFormation(type.positions(rotation: rotation, mode: mode), remap: remap)
                return
            }
            for pos in positionsCache {
                elements.append(ElementTerrain(
                    type: .joueur, x: remap ? remapPourDemiTerrain(x: pos.x) : pos.x, y: pos.y,
                    label: pos.label,
                    couleur: FormationType.couleurPourLabel(pos.label)))
            }
        } else {
            ajouterJoueursFormation(type.positions(rotation: rotation, mode: mode), remap: remap)
        }
    }

    /// Phase 5.2 — chaque jeton reçoit la couleur de son poste (source unique
    /// FormationType.couleurPourLabel) au lieu de la couleur d'outil courante.
    private func ajouterJoueursFormation(_ positions: [FormationType.Position], remap: Bool = false) {
        for pos in positions {
            elements.append(ElementTerrain(
                type: .joueur, x: remap ? remapPourDemiTerrain(x: pos.x) : pos.x, y: pos.y,
                label: pos.label,
                couleur: FormationType.couleurPourLabel(pos.label)))
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

    /// Sauvegarde l'étape active. Retourne `false` si l'encodage échoue ou si
    /// l'étape active n'existe plus — l'appelant ne doit alors PAS changer
    /// d'étape, sous peine de perdre le travail en cours.
    @discardableResult
    func sauvegarderEtapeActive(dessinData: inout Data?, elementsData: inout Data?) -> Bool {
        let dessin = drawing.dataRepresentation()
        guard let elems = try? JSONCoderCache.encoder.encode(elements) else {
            logger.warning("Encodage des éléments échoué — étape active non sauvegardée")
            return false
        }

        if etapeActive == 0 {
            dessinData = dessin
            elementsData = elems
            return true
        }
        let idx = etapeActive - 1
        guard idx < etapes.count else {
            logger.warning("Étape active \(self.etapeActive) hors bornes (\(self.etapes.count) étapes)")
            return false
        }
        etapes[idx].dessinData = dessin
        etapes[idx].elementsData = elems
        return true
    }

    func chargerEtapeActive(dessinData: Data?, elementsData: Data?) {
        // 2.2.a — ne vide plus l'historique : chaque étape garde ses piles
        // (le reset global vit dans charger(), au chargement d'un document).
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
        guard sauvegarderEtapeActive(dessinData: &dessinData, elementsData: &elementsData) else { return }
        etapes.append(EtapeExercice(nom: ""))
        etapeActive = etapes.count
        chargerEtapeActive(dessinData: dessinData, elementsData: elementsData)
    }

    /// Phase 5.4 — Duplique l'étape active (dessin + éléments) vers une
    /// nouvelle étape ajoutée en fin de liste, puis l'active.
    func dupliquerEtapeActive(dessinData: inout Data?, elementsData: inout Data?) {
        guard sauvegarderEtapeActive(dessinData: &dessinData, elementsData: &elementsData) else { return }
        guard let elems = try? JSONCoderCache.encoder.encode(elements) else {
            logger.warning("Encodage des éléments échoué — étape non dupliquée")
            return
        }
        etapes.append(EtapeExercice(nom: "",
                                    dessinData: drawing.dataRepresentation(),
                                    elementsData: elems))
        etapeActive = etapes.count
        chargerEtapeActive(dessinData: dessinData, elementsData: elementsData)
    }

    /// 2.3.1 — Duplication « Continuer » : les ARRIVÉES de l'étape active
    /// deviennent les DÉPARTS de la nouvelle étape. Chaque flèche/trajectoire
    /// déplace le jeton (joueur/ballon) le plus proche de son point de départ
    /// vers son point d'arrivée ; traits, rotations et encre ne sont pas copiés.
    /// C'est la mécanique de la pensée du coach : « et ensuite, ils vont là ».
    func dupliquerEtapeContinuer(dessinData: inout Data?, elementsData: inout Data?) {
        guard sauvegarderEtapeActive(dessinData: &dessinData, elementsData: &elementsData) else { return }

        /// Rayon d'association départ-de-trait ↔ jeton (coordonnées normalisées 0-1).
        let seuilAssociation = 0.08
        func distanceCarree(_ jeton: ElementTerrain, _ trait: ElementTerrain) -> Double {
            let dx = jeton.x - trait.x, dy = jeton.y - trait.y
            return dx * dx + dy * dy
        }

        let jetons = elements.filter { $0.type == .joueur || $0.type == .ballon }
        let traits = elements.filter {
            ($0.type == .fleche || $0.type == .trajectoire) && $0.toX != nil && $0.toY != nil
        }

        // Associations calculées sur les positions d'ORIGINE (un trait = un jeton).
        var destinations: [UUID: (x: Double, y: Double)] = [:]
        for trait in traits {
            guard let toX = trait.toX, let toY = trait.toY else { continue }
            guard let proche = jetons.min(by: { distanceCarree($0, trait) < distanceCarree($1, trait) }),
                  distanceCarree(proche, trait) < seuilAssociation * seuilAssociation else { continue }
            destinations[proche.id] = (toX, toY)
        }

        var suivants = jetons
        for i in suivants.indices {
            if let destination = destinations[suivants[i].id] {
                suivants[i].x = destination.x
                suivants[i].y = destination.y
            }
        }

        guard let elems = try? JSONCoderCache.encoder.encode(suivants) else {
            logger.warning("Encodage des éléments échoué — étape « Continuer » non créée")
            return
        }
        etapes.append(EtapeExercice(nom: "", dessinData: nil, elementsData: elems))
        etapeActive = etapes.count
        chargerEtapeActive(dessinData: dessinData, elementsData: elementsData)
    }

    func changerEtape(index: Int, dessinData: inout Data?, elementsData: inout Data?) {
        guard etapeActive != index else { return }
        guard sauvegarderEtapeActive(dessinData: &dessinData, elementsData: &elementsData) else { return }
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

        // 2.2.a — purge l'historique de l'étape supprimée (clé stable)
        let cle = etapes[idx].id.uuidString
        pilesUndo[cle] = nil
        pilesRedo[cle] = nil

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
        // Nouveau document : l'historique undo/redo repart à zéro (2.2.a)
        pilesUndo.removeAll()
        pilesRedo.removeAll()

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
