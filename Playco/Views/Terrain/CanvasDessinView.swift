//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import PencilKit
import Combine

// MARK: - Contrôleur pour undo/redo PencilKit
class CanvasController: ObservableObject {
    // Pas @Published — évite la boucle infinie updateUIView ↔ re-render SwiftUI
    weak var canvasView: PKCanvasView?

    func annuler()   { canvasView?.undoManager?.undo() }
    func retablir()  { canvasView?.undoManager?.redo() }
    var peutAnnuler:  Bool { canvasView?.undoManager?.canUndo ?? false }
    var peutRetablir: Bool { canvasView?.undoManager?.canRedo ?? false }
}

// MARK: - Modes de dessin
enum ModeDessin: String, CaseIterable {
    case curseur     = "Curseur"
    case crayon      = "Crayon"
    case marqueur    = "Marqueur"
    case trajectoire = "Flèche"
    case pointille   = "Pointillé"
    case rotation    = "Rotation"
    case joueur      = "Joueur"
    case ballon      = "Ballon"
    case suppression = "Supprimer"
    case gomme       = "Gomme"

    var icone: String {
        switch self {
        case .curseur:     return "cursorarrow"
        case .crayon:      return "pencil"
        case .marqueur:    return "highlighter"
        case .trajectoire: return "arrow.up.right"
        case .pointille:   return "arrow.up.forward.and.arrow.down.backward"
        case .rotation:    return "arrow.clockwise.circle"
        case .joueur:      return "person.crop.circle.fill"
        case .ballon:      return "figure.volleyball"
        case .suppression: return "xmark.circle"
        case .gomme:       return "eraser.fill"
        }
    }

    var estDessinLibre: Bool {
        self == .crayon || self == .marqueur || self == .gomme
    }
}

// MARK: - Canvas PencilKit
struct CanvasDessinView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var mode: ModeDessin
    var couleurOutil: UIColor
    var epaisseurOutil: CGFloat
    var controller: CanvasController

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.delegate = context.coordinator
        controller.canvasView = canvas
        appliquerOutil(canvas: canvas)
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        canvas.isUserInteractionEnabled = mode.estDessinLibre
        if canvas.drawing != drawing { canvas.drawing = drawing }
        if controller.canvasView == nil { controller.canvasView = canvas }
        appliquerOutil(canvas: canvas)
    }

    private func appliquerOutil(canvas: PKCanvasView) {
        switch mode {
        case .crayon:
            canvas.tool = PKInkingTool(.pen, color: couleurOutil, width: epaisseurOutil)
        case .marqueur:
            canvas.tool = PKInkingTool(.marker, color: couleurOutil.withAlphaComponent(0.6), width: epaisseurOutil * 2)
        case .gomme:
            canvas.tool = PKEraserTool(.vector)
        default:
            canvas.tool = PKInkingTool(.pen, color: couleurOutil, width: epaisseurOutil)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(drawing: $drawing) }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var drawing: PKDrawing
        init(drawing: Binding<PKDrawing>) { _drawing = drawing }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // Defer the state update to avoid modifying state during view update
            Task { @MainActor in
                self.drawing = canvasView.drawing
            }
        }
    }
}
