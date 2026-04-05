//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import PencilKit

struct BarreOutilsDessin: View {
    @Binding var modeActif: ModeDessin
    @Binding var couleur: Color
    @Binding var epaisseur: CGFloat
    @Binding var drawing: PKDrawing
    @Binding var elements: [ElementTerrain]
    @Binding var afficherZones: Bool
    @Binding var afficherDessinLibre: Bool
    @Binding var clipboardElements: [ElementTerrain]?
    @Binding var verrouille: Bool
    var typeTerrain: TypeTerrain = .indoor
    var controller: CanvasController
    var onUndo: () -> Void
    var onRedo: () -> Void
    var peutAnnuler: Bool
    var peutRetablir: Bool
    var onFormation: ((FormationType, Int, FormationMode) -> Void)?
    var strategiesOffensives: [StrategieCollective] = []
    var onStrategieOffensive: ((StrategieCollective) -> Void)?
    var joueursBD: [JoueurEquipe] = []
    var onPlacerJoueur: ((JoueurEquipe) -> Void)?
    var onEffacerTout: (() -> Void)?
    var onPresentation: (() -> Void)?

    @State private var afficherCouleurs  = false
    @State private var confirmerEffacer  = false

    private let couleursEquipes: [(String, Color)] = [
        ("Éq. A", PaletteMat.orange),
        ("Éq. B", PaletteMat.bleu)
    ]

    private let couleursLibres: [Color] = [
        .white, .yellow, .green, .purple, .black
    ]

    var body: some View {
        HStack(spacing: 0) {
            // Barre d'outils scrollable
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                // ── Curseur
                outilBtn("cursorarrow", "Curseur", .curseur, accent: .white)

                sep

                // ── Dessin libre
                outilBtn("pencil", "Crayon", .crayon)
                outilBtn("highlighter", "Marqueur", .marqueur)

                sep

                // ── Outils terrain (flèche avec Bézier + pointillé)
                outilBtn("arrow.up.right", "Flèche", .trajectoire, accent: .cyan)
                // Pointillé : icône custom
                Button {
                    modeActif = .pointille
                } label: {
                    ZStack {
                        // Flèche pointillée dessinée
                        Canvas { ctx, sz in
                            let from = CGPoint(x: 6, y: sz.height - 6)
                            let to = CGPoint(x: sz.width - 8, y: 8)
                            var path = Path()
                            path.move(to: from)
                            path.addLine(to: to)
                            ctx.stroke(path, with: .color(modeActif == .pointille ? .cyan : .primary),
                                       style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                            // Pointe
                            let angle = atan2(to.y - from.y, to.x - from.x)
                            let hl: CGFloat = 8, ha: CGFloat = 0.45
                            var head = Path()
                            head.move(to: to)
                            head.addLine(to: CGPoint(x: to.x - hl * cos(angle - ha),
                                                     y: to.y - hl * sin(angle - ha)))
                            head.move(to: to)
                            head.addLine(to: CGPoint(x: to.x - hl * cos(angle + ha),
                                                     y: to.y - hl * sin(angle + ha)))
                            ctx.stroke(head, with: .color(modeActif == .pointille ? .cyan : .primary),
                                       style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        }
                        .frame(width: 24, height: 24)
                    }
                    .frame(width: 36, height: 38)
                    .background(modeActif == .pointille ? Color.cyan.opacity(0.18) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .help("Pointillé")

                sep

                // ── Placement
                outilBtn("person.crop.circle.fill", "Joueur", .joueur, accent: .green)

                // ── Placer joueur depuis la base de données
                if !joueursBD.isEmpty {
                    menuJoueursBD
                }

                // ── Ballon (emoji 🏐)
                Button {
                    modeActif = .ballon
                } label: {
                    Text("🏐")
                        .font(.system(size: 18))
                        .frame(width: 36, height: 38)
                        .background(modeActif == .ballon ? Color.yellow.opacity(0.18) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .help("Ballon")

                sep

                // ── Suppression overlay + Gomme PencilKit
                outilBtn("xmark.circle", "Supprimer élément", .suppression, accent: .red)
                outilBtn("eraser.fill", "Gomme dessin", .gomme, accent: .red)

                sep

                // ── Verrouillage des éléments
                Button {
                    verrouille.toggle()
                } label: {
                    Image(systemName: verrouille ? "lock.fill" : "lock.open")
                        .font(.system(size: 15))
                        .frame(width: 36, height: 38)
                        .background(verrouille ? Color.red.opacity(0.18) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .foregroundStyle(verrouille ? .red : .primary)
                }
                .help(verrouille ? "Déverrouiller éléments" : "Verrouiller éléments")

                sep

                // ── Formations (rotation de base)
                menuFormation(
                    mode: .base,
                    icone: "arrow.triangle.2.circlepath",
                    couleurIcone: .green.opacity(0.8),
                    aide: "Rotation de base"
                )

                // ── Réception
                menuFormation(
                    mode: .reception,
                    icone: "hand.raised.fill",
                    couleurIcone: .blue.opacity(0.8),
                    aide: "Formation réception"
                )

                // ── Attaque (indoor uniquement)
                if typeTerrain == .indoor {
                    menuFormationAttaque(
                        icone: "flame.fill",
                        couleurIcone: .red.opacity(0.9),
                        aide: "Système offensif"
                    )
                }

                sep

                // ── Couleurs rapides (équipes)
                ForEach(couleursEquipes, id: \.0) { nom, c in
                    Button {
                        couleur = c
                    } label: {
                        Circle().fill(c)
                            .frame(width: 18, height: 18)
                            .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1))
                            .frame(width: 34, height: 38)
                    }
                    .help(nom)
                }

                // ── Couleur personnalisée
                Button {
                    afficherCouleurs.toggle()
                } label: {
                    Circle().fill(couleur)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1.5))
                        .frame(width: 34, height: 38)
                        .background(afficherCouleurs ? Color.white.opacity(0.08) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .overlay(alignment: .bottom) {
                    if afficherCouleurs {
                        CouleurPickerPopup(couleurs: couleursLibres, selection: $couleur) {
                            afficherCouleurs = false
                        }
                        .offset(y: 52).zIndex(10)
                    }
                }

                sep

                // ── Couches (masquer/afficher dessin libre)
                Button {
                    afficherDessinLibre.toggle()
                } label: {
                    Image(systemName: afficherDessinLibre ? "square.3.layers.3d.top.filled" : "square.3.layers.3d.slash")
                        .font(.system(size: 15))
                        .frame(width: 34, height: 38)
                        .foregroundStyle(afficherDessinLibre ? Color.primary : Color.red.opacity(0.7))
                }
                .help(afficherDessinLibre ? "Masquer dessin libre" : "Afficher dessin libre")

                // ── Zones toggle — indoor uniquement
                if typeTerrain == .indoor {
                    Button {
                        afficherZones.toggle()
                    } label: {
                        Image(systemName: afficherZones ? "number.square.fill" : "number.square")
                            .font(.system(size: 16))
                            .frame(width: 36, height: 38)
                            .background(afficherZones ? Color.orange.opacity(0.18) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                            .foregroundStyle(afficherZones ? Color.orange : .primary)
                    }
                    .help(afficherZones ? "Masquer zones" : "Afficher zones")
                }

                sep

                // ── Copier / Coller éléments
                Button {
                    clipboardElements = elements
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14))
                        .frame(width: 34, height: 38)
                        .foregroundStyle(elements.isEmpty ? .quaternary : .primary)
                }
                .disabled(elements.isEmpty)
                .help("Copier éléments")

                Button {
                    if let clip = clipboardElements {
                        let nouveaux = clip.map { el in
                            var copie = el
                            copie.id = UUID()
                            return copie
                        }
                        elements.append(contentsOf: nouveaux)
                    }
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 14))
                        .frame(width: 34, height: 38)
                        .foregroundStyle(clipboardElements == nil ? .quaternary : .primary)
                }
                .disabled(clipboardElements == nil)
                .help("Coller éléments")

                sep

                // ── Undo / Redo
                Button { onUndo() } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 15))
                        .frame(width: 34, height: 38)
                        .foregroundStyle(peutAnnuler ? .primary : .quaternary)
                }
                .disabled(!peutAnnuler)

                Button { onRedo() } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 15))
                        .frame(width: 34, height: 38)
                        .foregroundStyle(peutRetablir ? .primary : .quaternary)
                }
                .disabled(!peutRetablir)

                if onPresentation != nil {
                    sep

                    // ── Présentation plein écran
                    Button { onPresentation?() } label: {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 15))
                            .frame(width: 36, height: 38)
                            .foregroundStyle(.mint)
                    }
                    .help("Présentation")
                }

                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }

            // ── Bouton effacer tout — fixe à droite, toujours visible
            Divider().frame(height: 22)

            Button { confirmerEffacer = true } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 38, height: 38)
                    .foregroundStyle(.red.opacity(0.85))
            }
            .help("Effacer tout")
            .confirmationDialog("Effacer tout ?",
                                isPresented: $confirmerEffacer, titleVisibility: .visible) {
                Button("Tout effacer", role: .destructive) {
                    onEffacerTout?()
                }
                Button("Annuler", role: .cancel) {}
            }
            .padding(.trailing, 6)
        }
    }

    // MARK: - Menu formation réutilisable
    @ViewBuilder
    private func menuFormation(mode: FormationMode, icone: String, couleurIcone: Color, aide: String) -> some View {
        Menu {
            ForEach(FormationType.allCases.filter { $0.estBeach == (typeTerrain == .beach) }, id: \.self) { f in
                if f.estBeach {
                    Button {
                        onFormation?(f, 0, mode)
                    } label: {
                        Label(f.rawValue, systemImage: "person.2.fill")
                    }
                } else {
                    Menu {
                        ForEach(0..<f.nombreRotations, id: \.self) { r in
                            Button {
                                onFormation?(f, r, mode)
                            } label: {
                                Label("Rotation \(r + 1) — \(f.descriptionRotation(r))",
                                      systemImage: "arrow.clockwise")
                            }
                        }
                    } label: {
                        Label("Formation \(f.rawValue)", systemImage: "person.3.fill")
                    }
                }
            }
        } label: {
            Image(systemName: icone)
                .font(.system(size: 14))
                .frame(width: 36, height: 38)
                .foregroundStyle(couleurIcone)
        }
        .help(aide)
    }

    // MARK: - Menu joueurs base de données
    private var menuJoueursBD: some View {
        Menu {
            ForEach(joueursBD.sorted(by: { $0.numero < $1.numero }), id: \.id) { joueur in
                Button {
                    onPlacerJoueur?(joueur)
                } label: {
                    Label("#\(joueur.numero) \(joueur.prenom) \(joueur.nom) (\(joueur.poste.abreviation))",
                          systemImage: joueur.poste.icone)
                }
            }
        } label: {
            Image(systemName: "person.text.rectangle")
                .font(.system(size: 14))
                .frame(width: 36, height: 38)
                .foregroundStyle(.mint.opacity(0.9))
        }
        .help("Placer un joueur (BD)")
    }

    // MARK: - Menu formation attaque (stratégies offensives)
    @ViewBuilder
    private func menuFormationAttaque(icone: String, couleurIcone: Color, aide: String) -> some View {
        Menu {
            // Formations de base avec rotations
            ForEach(FormationType.allCases.filter { !$0.estBeach }, id: \.self) { f in
                Menu {
                    ForEach(0..<f.nombreRotations, id: \.self) { r in
                        Button {
                            onFormation?(f, r, .attaque)
                        } label: {
                            Label("Rotation \(r + 1) — \(f.descriptionRotation(r))",
                                  systemImage: "arrow.clockwise")
                        }
                    }
                } label: {
                    Label("Formation \(f.rawValue)", systemImage: "person.3.fill")
                }
            }

            if !strategiesOffensives.isEmpty {
                Divider()

                // Stratégies offensives depuis la section stratégie
                ForEach(strategiesOffensives, id: \.id) { strat in
                    Button {
                        onStrategieOffensive?(strat)
                    } label: {
                        Label(strat.nom, systemImage: "bolt.fill")
                    }
                }
            }
        } label: {
            Image(systemName: icone)
                .font(.system(size: 14))
                .frame(width: 36, height: 38)
                .foregroundStyle(couleurIcone)
        }
        .help(aide)
    }

    // MARK: - Helpers
    private func outilBtn(_ icone: String, _ label: String, _ mode: ModeDessin,
                          accent: Color = .orange) -> some View {
        Button {
            modeActif = mode
        } label: {
            Image(systemName: icone)
                .font(.system(size: 15))
                .frame(width: 36, height: 38)
                .background(modeActif == mode ? accent.opacity(0.18) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .foregroundStyle(modeActif == mode ? accent : .primary)
        }
        .help(label)
    }

    private var sep: some View {
        Divider().frame(height: 22).padding(.horizontal, 1)
    }
}

// MARK: - Popup couleurs
struct CouleurPickerPopup: View {
    let couleurs: [Color]
    @Binding var selection: Color
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(couleurs.indices, id: \.self) { i in
                Button {
                    selection = couleurs[i]; onDismiss()
                } label: {
                    Circle().fill(couleurs[i])
                        .frame(width: 26, height: 26)
                        .overlay(Circle().stroke(
                            selection == couleurs[i] ? Color.orange : .white.opacity(0.3),
                            lineWidth: selection == couleurs[i] ? 2.5 : 1))
                }
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 8)
    }
}
