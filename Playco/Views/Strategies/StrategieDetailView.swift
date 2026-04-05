//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Détail d'une stratégie collective — terrain éditable + notes
struct StrategieDetailView: View {
    @Bindable var strategie: StrategieCollective
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

    @State private var afficherRenommer = false
    @State private var nouveauNom = ""
    @State private var categorieEdit: CategorieStrategie = .attaque

    var body: some View {
        VStack(spacing: 0) {
            TerrainEditeurView(
                dessinData: $strategie.dessinData,
                elementsData: $strategie.elementsData,
                notes: $strategie.notes,
                etapesData: $strategie.etapesData,
                typeTerrain: TypeTerrain(rawValue: strategie.typeTerrain) ?? .indoor,
                afficherNotes: true,
                strategiesOffensives: strategiesOffensives,
                joueursBD: joueurs,
                formationsPerso: formationsPerso
            )

            // Section description sous le terrain
            sectionDescription
        }
        .navigationTitle(strategie.nom)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                menuActions
                    .siAutorise(authService.utilisateurConnecte?.role.peutModifierStrategies ?? false)
            }
            ToolbarItem(placement: .primaryAction) {
                // Badge catégorie
                let cat = strategie.categorie
                Label(cat.rawValue, systemImage: cat.icone)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(cat.couleur)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(cat.couleur.opacity(0.08), in: Capsule(style: .continuous))
            }
        }
        .onChange(of: strategie.notes) { _, _ in
            strategie.dateModification = Date()
        }
        .alert("Renommer", isPresented: $afficherRenommer) {
            TextField("Nom", text: $nouveauNom)
            Button("OK") {
                if !nouveauNom.trimmingCharacters(in: .whitespaces).isEmpty {
                    strategie.nom = nouveauNom
                    strategie.dateModification = Date()
                }
            }
            Button("Annuler", role: .cancel) {}
        }
    }

    // MARK: - Section description
    private var sectionDescription: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !strategie.descriptionStrategie.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "text.alignleft")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(strategie.descriptionStrategie)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Menu actions
    private var menuActions: some View {
        Menu {
            Button {
                nouveauNom = strategie.nom
                afficherRenommer = true
            } label: {
                Label("Renommer", systemImage: "pencil")
            }

            // Changer catégorie
            Menu {
                ForEach(CategorieStrategie.allCases, id: \.self) { cat in
                    Button {
                        strategie.categorieRaw = cat.rawValue
                        strategie.dateModification = Date()
                    } label: {
                        Label(cat.rawValue, systemImage: cat.icone)
                    }
                }
            } label: {
                Label("Catégorie", systemImage: "tag")
            }

            // Sauvegarder en exercice bibliothèque
            Button {
                sauvegarderEnBibliotheque()
            } label: {
                Label("Sauvegarder en bibliothèque", systemImage: "books.vertical.fill")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    // MARK: - Export vers bibliothèque
    private func sauvegarderEnBibliotheque() {
        let exo = ExerciceBibliotheque(
            nom: strategie.nom,
            categorie: "Combinaisons",
            descriptionExo: strategie.descriptionStrategie,
            notes: strategie.notes
        )
        exo.dessinData = strategie.dessinData
        exo.elementsData = strategie.elementsData
        exo.etapesData = strategie.etapesData
        exo.typeTerrain = strategie.typeTerrain
        exo.codeCoach = authService.utilisateurConnecte?.id.uuidString ?? ""

        if let ctx = strategie.modelContext {
            ctx.insert(exo)
        }
    }
}
