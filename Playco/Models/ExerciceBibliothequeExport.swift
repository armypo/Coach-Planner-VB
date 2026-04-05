//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation

/// Structure Codable de transfert pour export/import d'exercices bibliothèque
struct ExerciceExportItem: Codable, Identifiable, Sendable {
    var id: UUID
    var nom: String
    var categorie: String
    var descriptionExo: String
    var notes: String
    var notesCoach: String
    var duree: Int
    var typeTerrain: String
    var dessinData: Data?
    var elementsData: Data?
    var etapesData: Data?
    var dateCreation: Date

    /// Conversion depuis @Model
    init(from exo: ExerciceBibliotheque) {
        self.id = UUID() // Nouvel ID pour éviter les conflits
        self.nom = exo.nom
        self.categorie = exo.categorie
        self.descriptionExo = exo.descriptionExo
        self.notes = exo.notes
        self.notesCoach = exo.notesCoach
        self.duree = exo.duree
        self.typeTerrain = exo.typeTerrain
        self.dessinData = exo.dessinData
        self.elementsData = exo.elementsData
        self.etapesData = exo.etapesData
        self.dateCreation = exo.dateCreation
    }

    /// Conversion vers @Model
    func versExerciceBibliotheque(codeCoach: String) -> ExerciceBibliotheque {
        let exo = ExerciceBibliotheque(nom: nom, categorie: categorie,
                                        descriptionExo: descriptionExo, notes: notes,
                                        duree: duree)
        exo.notesCoach = notesCoach
        exo.typeTerrain = typeTerrain
        exo.dessinData = dessinData
        exo.elementsData = elementsData
        exo.etapesData = etapesData
        exo.codeCoach = codeCoach
        return exo
    }
}

/// Conteneur de fichier .playco
struct PlaycoExportBundle: Codable, Sendable {
    var version: String = "1.0"
    var dateExport: Date = Date()
    var exercices: [ExerciceExportItem]
}
