//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData
import PencilKit

struct ExerciceDetailView: View {
    @Bindable var exercice: Exercice
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
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

    // Rename
    @State private var afficherRenommer = false
    @State private var nouveauNom       = ""

    // Durée
    @State private var afficherDuree    = false

    // Bibliothèque
    @State private var afficherSauveBiblio = false
    @State private var categorieBiblio = CategorieBibliotheque.echauffement.rawValue
    @State private var descriptionBiblio = ""
    @State private var confirmeSauveBiblio = false

    var body: some View {
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
        .navigationTitle(titreAvecDuree)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if authService.utilisateurConnecte?.role.peutModifierSeances ?? false {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 10) {
                        Button { afficherDuree = true } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "clock")
                                    .font(.system(size: 13))
                                Text(exercice.duree > 0 ? "\(exercice.duree) min" : "Durée")
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundStyle(exercice.duree > 0 ? .orange : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                exercice.duree > 0
                                ? Color.orange.opacity(0.12)
                                : Color.primary.opacity(0.06),
                                in: Capsule()
                            )
                        }

                        Menu {
                            Button {
                                nouveauNom = exercice.nom; afficherRenommer = true
                            } label: { Label("Renommer", systemImage: "pencil") }

                            Button {
                                descriptionBiblio = exercice.notes
                                afficherSauveBiblio = true
                            } label: {
                                Label("Sauvegarder en bibliothèque", systemImage: "books.vertical")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.body.weight(.medium))
                        }
                    }
                }
            }
        }
        .alert("Renommer l'exercice", isPresented: $afficherRenommer) {
            TextField("Nom", text: $nouveauNom)
            Button("Renommer") {
                let n = nouveauNom.trimmingCharacters(in: .whitespaces)
                if !n.isEmpty { exercice.nom = n }
            }
            Button("Annuler", role: .cancel) {}
        }
        .alert("Durée (minutes)", isPresented: $afficherDuree) {
            TextField("Minutes", value: $exercice.duree, format: .number)
                .keyboardType(.numberPad)
            Button("OK") {}
            Button("Annuler", role: .cancel) {}
        }
        .sheet(isPresented: $afficherSauveBiblio) {
            EditerExerciceBibliothequeView(
                nomInitial: exercice.nom,
                categorieInitiale: categorieBiblio,
                descriptionInitiale: descriptionBiblio,
                onSave: { nom, cat, desc in
                    let biblio = ExerciceBibliotheque(nom: nom, categorie: cat,
                                                      descriptionExo: desc, notes: exercice.notes,
                                                      duree: exercice.duree)
                    biblio.codeCoach = authService.utilisateurConnecte?.id.uuidString ?? ""
                    copierTerrain(de: exercice, vers: biblio) // P1-01
                    modelContext.insert(biblio)
                    confirmeSauveBiblio = true
                }
            )
        }
        .alert("Sauvegardé !", isPresented: $confirmeSauveBiblio) {
            Button("OK") {}
        } message: {
            Text("L'exercice a été ajouté à votre bibliothèque.")
        }
    }

    private var titreAvecDuree: String {
        if exercice.duree > 0 {
            return "\(exercice.nom) (\(exercice.duree) min)"
        }
        return exercice.nom
    }

}
