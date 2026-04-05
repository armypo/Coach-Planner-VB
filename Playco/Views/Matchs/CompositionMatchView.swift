//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Sélection des 6 partants (postes 1-6) + libéro optionnel + configuration match
struct CompositionMatchView: View {
    @Bindable var seance: Seance

    @Query(filter: #Predicate<JoueurEquipe> { $0.estActif == true },
           sort: \JoueurEquipe.numero) private var joueurs: [JoueurEquipe]
    @Environment(\.codeEquipeActif) private var codeEquipeActif

    /// Mapping poste (1-6) → joueur ID
    @State private var postesAssignes: [Int: UUID] = [:]
    @State private var liberoSelectionne: UUID?
    @State private var utiliserLibero: Bool = false
    @State private var nousServons: Bool = true
    @State private var rotationDepart: Int = 1
    @State private var configMatch: ConfigMatch = ConfigMatch()

    private var joueursEquipe: [JoueurEquipe] {
        joueurs.filtreEquipe(codeEquipeActif)
    }

    /// Joueurs déjà assignés à un poste (ne peuvent pas être sélectionnés pour un autre poste)
    private var joueursAssignesIDs: Set<UUID> {
        var ids = Set(postesAssignes.values)
        if let lib = liberoSelectionne { ids.insert(lib) }
        return ids
    }

    /// Composition complète : 6 postes remplis
    private var compositionComplete: Bool {
        postesAssignes.count == 6
    }

    var body: some View {
        ScrollView {
            VStack(spacing: LiquidGlassKit.espaceLG) {
                // En-tête
                entete

                // Postes 1 à 6
                sectionPostes

                // Libéro
                sectionLibero

                // Configuration service & rotation
                sectionServiceRotation

                // Configuration match
                sectionConfigMatch

                // Résumé
                if compositionComplete {
                    resumeComposition
                }
            }
            .padding(LiquidGlassKit.espaceMD)
        }
        .onAppear { chargerDepuisSeance() }
        .onChange(of: postesAssignes) { sauvegarder() }
        .onChange(of: liberoSelectionne) { sauvegarder() }
        .onChange(of: nousServons) { seance.nousServonsEnPremier = nousServons }
        .onChange(of: configMatch) { seance.configMatch = configMatch }
    }

    // MARK: - En-tête

    private var entete: some View {
        VStack(spacing: LiquidGlassKit.espaceSM) {
            HStack {
                Text("COMPOSITION (\(postesAssignes.count)/6)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Spacer()
                if compositionComplete {
                    Label("Prêt", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }

            if !compositionComplete {
                Text("Assignez un joueur à chaque poste (1 à 6)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Postes 1-6

    private var sectionPostes: some View {
        VStack(spacing: LiquidGlassKit.espaceSM) {
            // Rangée avant (postes 4, 3, 2) — côté filet
            HStack(spacing: LiquidGlassKit.espaceSM) {
                slotPoste(poste: 4, label: "Poste 4", description: "Avant gauche")
                slotPoste(poste: 3, label: "Poste 3", description: "Avant centre")
                slotPoste(poste: 2, label: "Poste 2", description: "Avant droit")
            }

            HStack {
                Text("─── Filet ───")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Rangée arrière (postes 5, 6, 1)
            HStack(spacing: LiquidGlassKit.espaceSM) {
                slotPoste(poste: 5, label: "Poste 5", description: "Arrière gauche")
                slotPoste(poste: 6, label: "Poste 6", description: "Arrière centre")
                slotPoste(poste: 1, label: "Poste 1", description: "Arrière droit (service)")
            }
        }
    }

    private func slotPoste(poste: Int, label: String, description: String) -> some View {
        let joueurAssigne = postesAssignes[poste].flatMap { id in joueursEquipe.first(where: { $0.id == id }) }
        let joueursDisponibles = joueursEquipe.filter {
            !joueursAssignesIDs.contains($0.id) || postesAssignes[poste] == $0.id
        }

        return VStack(spacing: 4) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)

            Menu {
                if joueurAssigne != nil {
                    Button(role: .destructive) {
                        postesAssignes.removeValue(forKey: poste)
                    } label: {
                        Label("Retirer", systemImage: "minus.circle")
                    }
                    Divider()
                }

                ForEach(joueursDisponibles) { joueur in
                    Button {
                        postesAssignes[poste] = joueur.id
                    } label: {
                        Label("#\(joueur.numero) — \(joueur.prenom) \(joueur.nom)", systemImage: joueur.poste.icone)
                    }
                }
            } label: {
                VStack(spacing: 2) {
                    if let j = joueurAssigne {
                        Text("#\(j.numero)")
                            .font(.title3.weight(.bold).monospacedDigit())
                        Text(j.prenom)
                            .font(.caption2)
                            .lineLimit(1)
                    } else {
                        Image(systemName: "plus.circle.dashed")
                            .font(.title3)
                            .foregroundStyle(.tertiary)
                        Text("Vide")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 70)
                .background(
                    joueurAssigne != nil ? Color.red.opacity(0.08) : Color(.tertiarySystemFill),
                    in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit)
                        .strokeBorder(joueurAssigne != nil ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
                }
            }

            Text(description)
                .font(.system(size: 9))
                .foregroundStyle(.quaternary)
        }
    }

    // MARK: - Libéro

    private var sectionLibero: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Toggle(isOn: $utiliserLibero) {
                HStack(spacing: 6) {
                    Image(systemName: "shield.checkered")
                        .foregroundStyle(.green)
                    Text("Libéro")
                        .font(.subheadline.weight(.medium))
                }
            }
            .tint(.green)
            .onChange(of: utiliserLibero) {
                if !utiliserLibero { liberoSelectionne = nil }
            }

            if utiliserLibero {
                let joueursDispos = joueursEquipe.filter { !joueursAssignesIDs.contains($0.id) || liberoSelectionne == $0.id }

                Menu {
                    if liberoSelectionne != nil {
                        Button(role: .destructive) {
                            liberoSelectionne = nil
                        } label: {
                            Label("Retirer", systemImage: "minus.circle")
                        }
                        Divider()
                    }
                    ForEach(joueursDispos) { joueur in
                        Button {
                            liberoSelectionne = joueur.id
                        } label: {
                            Label("#\(joueur.numero) — \(joueur.prenom) \(joueur.nom)", systemImage: "shield.checkered")
                        }
                    }
                } label: {
                    HStack {
                        if let libID = liberoSelectionne,
                           let j = joueursEquipe.first(where: { $0.id == libID }) {
                            Text("#\(j.numero) \(j.prenom) \(j.nom)")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.green)
                        } else {
                            Text("Sélectionner le libéro")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit))
                }
            }
        }
        .padding(LiquidGlassKit.espaceMD)
        .glassSection()
    }

    // MARK: - Service & Rotation

    private var sectionServiceRotation: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Text("SERVICE & ROTATION")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            // Qui sert en premier
            HStack {
                Text("Premier service")
                    .font(.subheadline)
                Spacer()
                Picker("Service", selection: $nousServons) {
                    Text("Nous").tag(true)
                    Text("Adversaire").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
        }
        .padding(LiquidGlassKit.espaceMD)
        .glassSection()
    }

    // MARK: - Config Match

    private var sectionConfigMatch: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Text("CONFIGURATION")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            HStack {
                Text("Substitutions max / set")
                    .font(.subheadline)
                Spacer()
                Stepper("\(configMatch.subsMaxParSet)", value: $configMatch.subsMaxParSet, in: 1...15)
                    .frame(width: 140)
            }

            HStack {
                Text("Temps morts / set / équipe")
                    .font(.subheadline)
                Spacer()
                Stepper("\(configMatch.tempsMortsParSetParEquipe)", value: $configMatch.tempsMortsParSetParEquipe, in: 1...5)
                    .frame(width: 140)
            }

            Toggle(isOn: $configMatch.ttoActifs) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Temps morts techniques (TTO)")
                        .font(.subheadline)
                    Text("Automatiques à 8 et 16 pts (sets 1-4)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .tint(.red)
        }
        .padding(LiquidGlassKit.espaceMD)
        .glassSection()
    }

    // MARK: - Résumé

    private var resumeComposition: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Text("TITULAIRES")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            FlowLayout(spacing: 6) {
                ForEach(Array(1...6), id: \.self) { poste in
                    if let joueurID = postesAssignes[poste],
                       let j = joueursEquipe.first(where: { $0.id == joueurID }) {
                        HStack(spacing: 4) {
                            Text("P\(poste)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(.red, in: RoundedRectangle(cornerRadius: 3))
                            Text("#\(j.numero) \(j.prenom)")
                                .font(.caption2.weight(.medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.08), in: Capsule())
                    }
                }

                if let libID = liberoSelectionne,
                   let j = joueursEquipe.first(where: { $0.id == libID }) {
                    HStack(spacing: 4) {
                        Text("L")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(.green, in: RoundedRectangle(cornerRadius: 3))
                        Text("#\(j.numero) \(j.prenom)")
                            .font(.caption2.weight(.medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.08), in: Capsule())
                }
            }
        }
        .padding(LiquidGlassKit.espaceMD)
        .glassSection()
    }

    // MARK: - Persistence

    private func chargerDepuisSeance() {
        let partants = seance.partants
        for p in partants {
            postesAssignes[p.poste] = p.joueurID
        }
        liberoSelectionne = seance.liberoUUID
        utiliserLibero = liberoSelectionne != nil
        nousServons = seance.nousServonsEnPremier
        configMatch = seance.configMatch
    }

    private func sauvegarder() {
        seance.partants = postesAssignes.map { PartantMatch(poste: $0.key, joueurID: $0.value) }
        seance.liberoUUID = liberoSelectionne
        seance.compositionJoueurs = Array(postesAssignes.values) + (liberoSelectionne.map { [$0] } ?? [])
    }
}

// MARK: - FlowLayout (pour chips joueurs)

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                                  proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = Swift.max(rowHeight, size.height)
            x += size.width + spacing
            maxHeight = Swift.max(maxHeight, y + rowHeight)
        }

        return (CGSize(width: maxWidth, height: maxHeight), positions)
    }
}
