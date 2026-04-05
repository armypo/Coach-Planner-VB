//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData
import PencilKit

/// Vue de détail pour éditer un exercice de la bibliothèque (terrain + dessin + notes + notes coach)
struct BibliothequeDetailView: View {
    @Bindable var exercice: ExerciceBibliotheque
    @Environment(\.dismiss) private var dismiss
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Query(filter: #Predicate<StrategieCollective> { $0.categorieRaw == "Système d'attaque" && $0.estArchivee == false })
    private var strategiesOffensives: [StrategieCollective]
    @Query(filter: #Predicate<JoueurEquipe> { $0.estActif == true },
           sort: \JoueurEquipe.numero)
    private var joueurs: [JoueurEquipe]
    @Query private var toutesFormationsPerso: [FormationPersonnalisee]
    private var formationsPerso: [FormationPersonnalisee] {
        toutesFormationsPerso.filtreEquipe(codeEquipeActif)
    }
    @Query(sort: \CategorieExercice.nom) private var toutesCategoriesPerso: [CategorieExercice]
    private var categoriesPerso: [CategorieExercice] {
        toutesCategoriesPerso.filtreEquipe(codeEquipeActif)
    }

    // Rename
    @State private var afficherRenommer = false
    @State private var nouveauNom       = ""

    // Sauvegarde
    @State private var confirmeSauvegarde = false
    @State private var aDesModifications  = false

    // Durée
    @State private var afficherDuree = false

    var body: some View {
        VStack(spacing: 0) {
            // Terrain éditeur (prend l'espace principal)
            TerrainEditeurView(
                dessinData: $exercice.dessinData,
                elementsData: $exercice.elementsData,
                notes: $exercice.notes,
                etapesData: $exercice.etapesData,
                typeTerrain: TypeTerrain(rawValue: exercice.typeTerrain) ?? .indoor,
                strategiesOffensives: strategiesOffensives,
                joueursBD: joueurs,
                formationsPerso: formationsPerso
            )

            // ── Notes coach (sous le terrain, toujours visible)
            notesCoachSection
        }
        .navigationTitle(exercice.nom)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 10) {
                    // Durée — visible directement
                    Button { afficherDuree = true } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 13))
                            Text(exercice.duree > 0 ? "\(exercice.duree) min" : "Durée")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(exercice.duree > 0 ? PaletteMat.orange : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            exercice.duree > 0
                            ? PaletteMat.orange.opacity(0.08)
                            : Color.primary.opacity(0.06),
                            in: Capsule(style: .continuous)
                        )
                    }

                    Button {
                        aDesModifications = false
                        confirmeSauvegarde = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.body.weight(.medium))
                    }
                    .help("Sauvegarder")

                    Menu {
                        Button {
                            nouveauNom = exercice.nom; afficherRenommer = true
                        } label: { Label("Renommer", systemImage: "pencil") }

                        // Menu catégorie avec prédéfinies + personnalisées
                        Menu {
                            ForEach(CategorieBibliotheque.allCases, id: \.self) { cat in
                                Button {
                                    exercice.categorie = cat.rawValue
                                } label: {
                                    if exercice.categorie == cat.rawValue {
                                        Label(cat.rawValue, systemImage: "checkmark")
                                    } else {
                                        Label(cat.rawValue, systemImage: cat.icone)
                                    }
                                }
                            }
                            if !categoriesPerso.isEmpty {
                                Divider()
                                ForEach(categoriesPerso) { cat in
                                    Button {
                                        exercice.categorie = cat.nom
                                    } label: {
                                        if exercice.categorie == cat.nom {
                                            Label(cat.nom, systemImage: "checkmark")
                                        } else {
                                            Label(cat.nom, systemImage: cat.icone)
                                        }
                                    }
                                }
                            }
                        } label: {
                            Label("Catégorie : \(exercice.categorie)", systemImage: "tag")
                        }

                        Divider()

                        Button {
                            exercice.estFavori.toggle()
                        } label: {
                            Label(exercice.estFavori ? "Retirer des favoris" : "Ajouter aux favoris",
                                  systemImage: exercice.estFavori ? "star.slash" : "star.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.body.weight(.medium))
                    }
                }
            }
        }
        .alert("Sauvegardé !", isPresented: $confirmeSauvegarde) {
            Button("OK") {}
        } message: {
            Text("L'exercice a été enregistré dans la bibliothèque.")
        }
        .alert("Renommer l'exercice", isPresented: $afficherRenommer) {
            TextField("Nom", text: $nouveauNom)
            Button("Renommer") {
                let n = nouveauNom.trimmingCharacters(in: .whitespaces)
                if !n.isEmpty { exercice.nom = n }
            }
            Button("Annuler", role: .cancel) {}
        }
        .alert("Durée suggérée (minutes)", isPresented: $afficherDuree) {
            TextField("Minutes", value: $exercice.duree, format: .number)
                .keyboardType(.numberPad)
            Button("OK") {}
            Button("Annuler", role: .cancel) {}
        }
        .onChange(of: exercice.dessinData) { _, _ in aDesModifications = true }
        .onChange(of: exercice.elementsData) { _, _ in aDesModifications = true }
        .onChange(of: exercice.notes) { _, _ in aDesModifications = true }
    }

    // MARK: - Notes coach (sous le terrain)
    private var notesCoachSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "person.text.rectangle")
                    .font(.caption)
                    .foregroundStyle(PaletteMat.orange)
                Text("Notes du coach")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            TextEditor(text: $exercice.notesCoach)
                .font(.callout)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .frame(minHeight: 60, maxHeight: 120)
                .overlay(alignment: .topLeading) {
                    if exercice.notesCoach.isEmpty {
                        Text("Conseils, variantes, points clés…")
                            .foregroundStyle(.tertiary)
                            .font(.callout)
                            .padding(.leading, 16)
                            .padding(.top, 12)
                            .allowsHitTesting(false)
                    }
                }
        }
        .background(.ultraThinMaterial)
    }
}
