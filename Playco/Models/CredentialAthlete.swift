//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftData

/// Stocke en clair les mots de passe auto-générés des athlètes et assistants
/// afin que le coach puisse les récupérer/partager après création.
///
/// **Sécurité** : ce modèle vit UNIQUEMENT dans la private CloudKit DB du coach
/// (chiffré par Apple at transport + at-rest). Il ne doit PAS être publié
/// via `CloudKitSharingService.publierEquipeComplete` (qui expose les
/// JoueurEquipe publiquement pour la découverte inter-device).
@Model
final class CredentialAthlete {
    var id: UUID = UUID()
    var utilisateurID: UUID = UUID()
    var joueurEquipeID: UUID? = nil           // nil pour les assistants
    var identifiant: String = ""
    var motDePasseClair: String = ""
    var dateCreation: Date = Date()
    var dateModification: Date = Date()
    var codeEquipe: String = ""

    init(
        utilisateurID: UUID,
        joueurEquipeID: UUID? = nil,
        identifiant: String,
        motDePasseClair: String,
        codeEquipe: String
    ) {
        self.id = UUID()
        self.utilisateurID = utilisateurID
        self.joueurEquipeID = joueurEquipeID
        self.identifiant = identifiant
        self.motDePasseClair = motDePasseClair
        self.codeEquipe = codeEquipe
        self.dateCreation = Date()
        self.dateModification = Date()
    }
}
