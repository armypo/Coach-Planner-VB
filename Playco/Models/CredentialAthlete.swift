//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  CredentialAthlete — marqueur de membre (athlète/assistant) par équipe.
//

import Foundation
import SwiftData

/// Marqueur des membres athlètes/assistants créés par le coach (identifiant +
/// équipe), utilisé pour lister les membres dans `IdentifiantsEquipeView`.
///
/// **Sécurité (v2.0.1)** : ne stocke PLUS de mot de passe. La connexion se fait
/// par Sign in with Apple + code d'invitation (`Utilisateur.codeInvitation`).
/// Le champ `motDePasseClair` est conservé vide pour compat schéma CloudKit
/// (suppression = migration destructive) mais n'est jamais renseigné ni lu.
@Model
final class CredentialAthlete {
    var id: UUID = UUID()
    var utilisateurID: UUID = UUID()
    var joueurEquipeID: UUID? = nil           // nil pour assistants
    var identifiant: String = ""
    /// DÉPRÉCIÉ v2.0.1 — toujours vide (plus aucun mot de passe en clair stocké).
    var motDePasseClair: String = ""
    var dateCreation: Date = Date()
    var dateModification: Date = Date()
    var codeEquipe: String = ""

    init(utilisateurID: UUID,
         joueurEquipeID: UUID? = nil,
         identifiant: String,
         motDePasseClair: String,
         codeEquipe: String) {
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

extension CredentialAthlete: FiltreParEquipe {}
