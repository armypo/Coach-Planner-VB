//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData
import PencilKit

struct ListeExercicesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.editMode) private var editMode
    @Environment(AuthService.self) private var authService
    @Bindable var seance: Seance
    @State private var afficherNouvelExercice = false
    @State private var afficherBibliotheque = false
    @State private var exerciceARenommer: Exercice?
    @State private var afficherRenommer = false
    @State private var nouveauNomExercice = ""
    @State private var confirmerSuppression: Exercice?
    @State private var afficherConfirmSuppression = false
    var exercicesOrdonnes: [Exercice] {
        (seance.exercices ?? []).sorted { $0.ordre < $1.ordre }
    }

    var dureeTotale: Int {
        (seance.exercices ?? []).reduce(0) { $0 + $1.duree }
    }

    private var peutModifier: Bool {
        authService.utilisateurConnecte?.role.peutModifierSeances ?? false
    }

    var body: some View {
        Group {
            if (seance.exercices ?? []).isEmpty {
                vueVide
            } else {
                listeExercices
            }
        }
        .navigationTitle(seance.nom)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 8) {
                    if peutModifier {
                        Menu {
                            Button {
                                editMode?.wrappedValue = .inactive
                                afficherBibliotheque = true
                            } label: {
                                Label("Depuis la bibliothèque", systemImage: "books.vertical")
                            }
                            Button {
                                editMode?.wrappedValue = .inactive
                                afficherNouvelExercice = true
                            } label: {
                                Label("Exercice vide", systemImage: "square.and.pencil")
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $afficherNouvelExercice) {
            NouvelExerciceView { nom, type in ajouterExercice(nom: nom, typeTerrain: type) }
        }
        .sheet(isPresented: $afficherBibliotheque) {
            NavigationStack {
                BibliothequeView(onImporter: { exoBiblio in
                    importerDepuisBibliotheque(exoBiblio)
                })
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annuler") { afficherBibliotheque = false }
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        // P2-02 — alerts avec @State bool propres
        .alert("Renommer l'exercice", isPresented: $afficherRenommer) {
            TextField("Nom de l'exercice", text: $nouveauNomExercice)
            Button("Renommer") {
                let n = nouveauNomExercice.trimmingCharacters(in: .whitespaces)
                if let ex = exerciceARenommer, !n.isEmpty { ex.nom = n }
                exerciceARenommer = nil
            }
            Button("Annuler", role: .cancel) { exerciceARenommer = nil }
        }
        .confirmationDialog(
            "Supprimer cet exercice ?",
            isPresented: $afficherConfirmSuppression,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                if let ex = confirmerSuppression { supprimerExercice(ex) }
                confirmerSuppression = nil
            }
            Button("Annuler", role: .cancel) { confirmerSuppression = nil }
        } message: {
            Text("Cette action est irréversible.")
        }
    }

    // MARK: - Liste
    private var listeExercices: some View {
        List {
            Section {
                ForEach(exercicesOrdonnes) { exercice in
                    NavigationLink(destination: ExerciceDetailView(exercice: exercice)) {
                        ExerciceRow(exercice: exercice)
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        editMode?.wrappedValue = .inactive
                    })
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if peutModifier {
                            Button(role: .destructive) {
                                confirmerSuppression = exercice; afficherConfirmSuppression = true
                            } label: { Label("Supprimer", systemImage: "trash") }

                            Button { dupliquerExercice(exercice) } label: {
                                Label("Dupliquer", systemImage: "doc.on.doc")
                            }
                            .tint(.blue)
                        }
                    }
                    .swipeActions(edge: .leading) {
                        if peutModifier {
                            Button {
                                exerciceARenommer = exercice
                                nouveauNomExercice = exercice.nom
                                afficherRenommer = true
                            } label: { Label("Renommer", systemImage: "pencil") }
                            .tint(.orange)
                        }
                    }
                    .contextMenu {
                        if peutModifier {
                            Button {
                                exerciceARenommer = exercice
                                nouveauNomExercice = exercice.nom
                                afficherRenommer = true
                            } label: { Label("Renommer", systemImage: "pencil") }

                            Button { dupliquerExercice(exercice) } label: {
                                Label("Dupliquer", systemImage: "doc.on.doc")
                            }

                            Divider()

                            Button(role: .destructive) {
                                confirmerSuppression = exercice; afficherConfirmSuppression = true
                            } label: { Label("Supprimer", systemImage: "trash") }
                        }
                    }
                }
                .onDelete(perform: supprimerExercices)
                .onMove(perform: deplacerExercices)
            } header: {
                HStack {
                    Text("\((seance.exercices ?? []).count) exercice\((seance.exercices ?? []).count > 1 ? "s" : "")")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary).textCase(nil)
                    if dureeTotale > 0 {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundStyle(PaletteMat.orange)
                        Text("\(dureeTotale) min")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PaletteMat.orange)
                            .textCase(nil)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.caption2).foregroundStyle(.tertiary)
                    Text("Réordonner")
                        .font(.caption2).foregroundStyle(.tertiary).textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Vue vide
    private var vueVide: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.volleyball")
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(PaletteMat.orange.opacity(0.4))
            Text("Aucun exercice")
                .font(.title2.weight(.semibold))
            Text("Ajoutez votre premier exercice\npour commencer à planifier")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .font(.subheadline)
            if peutModifier {
                HStack(spacing: 12) {
                    Button { afficherBibliotheque = true } label: {
                        Label("Bibliothèque", systemImage: "books.vertical")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16).padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent).tint(PaletteMat.orange).clipShape(Capsule(style: .continuous))

                    Button { afficherNouvelExercice = true } label: {
                        Label("Exercice vide", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16).padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered).tint(PaletteMat.orange).clipShape(Capsule(style: .continuous))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding()
    }

    // MARK: - Actions
    private func ajouterExercice(nom: String, typeTerrain: TypeTerrain = .indoor) {
        let ex = Exercice(nom: nom, ordre: (seance.exercices ?? []).count)
        ex.typeTerrain = typeTerrain.rawValue
        ex.seance = seance
        modelContext.insert(ex)
        if seance.exercices == nil { seance.exercices = [] }
        seance.exercices?.append(ex)
    }

    private func importerDepuisBibliotheque(_ exoBiblio: ExerciceBibliotheque) {
        let ex = Exercice(nom: exoBiblio.nom, notes: exoBiblio.descriptionExo,
                          ordre: (seance.exercices ?? []).count, duree: exoBiblio.duree)
        ex.seance = seance
        copierTerrain(de: exoBiblio, vers: ex) // P1-01
        modelContext.insert(ex)
        if seance.exercices == nil { seance.exercices = [] }
        seance.exercices?.append(ex)
    }

    private func dupliquerExercice(_ exercice: Exercice) {
        let copie = Exercice(nom: "\(exercice.nom) (copie)", ordre: (seance.exercices ?? []).count,
                             duree: exercice.duree)
        copie.seance = seance
        copie.notes = exercice.notes
        copierTerrain(de: exercice, vers: copie) // P1-01
        modelContext.insert(copie)
        if seance.exercices == nil { seance.exercices = [] }
        seance.exercices?.append(copie)
    }

    private func supprimerExercice(_ exercice: Exercice) {
        seance.exercices?.removeAll { $0.id == exercice.id }
        modelContext.delete(exercice)
        reordonner()
    }

    private func supprimerExercices(at offsets: IndexSet) {
        let tries = exercicesOrdonnes
        let toDelete = offsets.compactMap { i in i < tries.count ? tries[i] : nil }
        for ex in toDelete { supprimerExercice(ex) }
    }

    private func deplacerExercices(from source: IndexSet, to destination: Int) {
        var tries = exercicesOrdonnes
        tries.move(fromOffsets: source, toOffset: destination)
        for (i, ex) in tries.enumerated() { ex.ordre = i }
    }

    private func reordonner() {
        for (i, ex) in exercicesOrdonnes.enumerated() { ex.ordre = i }
    }

}

// MARK: - Rangée exercice avec miniature
struct ExerciceRow: View {
    let exercice: Exercice
    private var aDessin: Bool { exercice.dessinData != nil || exercice.elementsData != nil }

    var body: some View {
        HStack(spacing: 12) {
            // Miniature terrain ou icône
            if exercice.elementsData != nil {
                TerrainMiniatureView(elementsData: exercice.elementsData, taille: 56,
                                     typeTerrain: TypeTerrain(rawValue: exercice.typeTerrain) ?? .indoor)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(PaletteMat.orange.opacity(0.08))
                        .frame(width: 56, height: 28)
                    Image(systemName: "figure.volleyball")
                        .foregroundStyle(PaletteMat.orange)
                        .font(.system(size: 14, weight: .medium))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(exercice.nom)
                    .font(.system(.body, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if exercice.typeTerrain == TypeTerrain.beach.rawValue {
                        HStack(spacing: 2) {
                            Image(systemName: "sun.max")
                                .font(.caption2)
                            Text("Beach")
                                .font(.caption)
                        }
                        .foregroundStyle(.yellow)
                    }
                    if exercice.duree > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text("\(exercice.duree) min")
                                .font(.caption)
                        }
                        .foregroundStyle(PaletteMat.orange)
                    }
                    if !exercice.notes.isEmpty {
                        Text(exercice.notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            if aDessin {
                Image(systemName: "scribble.variable")
                    .font(.caption)
                    .foregroundStyle(PaletteMat.orange.opacity(0.6))
            }
        }
        .padding(.vertical, 4)
    }
}
