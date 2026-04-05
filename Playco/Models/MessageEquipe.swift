//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftData

/// Message dans le fil de discussion d'une équipe
@Model
final class MessageEquipe {
    var id: UUID = UUID()
    var contenu: String = ""
    var dateEnvoi: Date = Date()

    /// Expéditeur (dénormalisé pour affichage rapide sans join)
    var expediteurID: UUID = UUID()
    var expediteurNom: String = ""
    var expediteurRoleRaw: String = ""

    /// Code équipe — filtre inter-équipe (= Utilisateur.codeEcole)
    var codeEquipe: String = ""

    /// nil = message d'équipe (groupe), non-nil = message privé vers cet utilisateur
    var destinataireID: UUID? = nil
    var destinataireNom: String = ""

    /// JSON [String] — UUIDs des utilisateurs ayant lu ce message
    var lecteurIDsData: Data? = nil

    /// true = message d'équipe (groupe), false = message privé
    var estGroupe: Bool { destinataireID == nil }

    // MARK: - Helpers lecteurs

    func lecteurIDs() -> Set<UUID> {
        guard let data = lecteurIDsData,
              let ids = try? JSONCoderCache.decoder.decode([String].self, from: data)
        else { return [] }
        return Set(ids.compactMap { UUID(uuidString: $0) })
    }

    func ajouterLecteur(_ userID: UUID) {
        var ids = lecteurIDs()
        ids.insert(userID)
        let strings = ids.map(\.uuidString)
        lecteurIDsData = try? JSONCoderCache.encoder.encode(strings)
    }

    func estLuPar(_ userID: UUID) -> Bool {
        lecteurIDs().contains(userID)
    }

    // MARK: - Init

    /// Message d'équipe (groupe)
    init(contenu: String, expediteur: Utilisateur, codeEquipe: String) {
        self.id = UUID()
        self.contenu = contenu
        self.dateEnvoi = Date()
        self.expediteurID = expediteur.id
        self.expediteurNom = expediteur.nomComplet
        self.expediteurRoleRaw = expediteur.roleRaw
        self.codeEquipe = codeEquipe
        self.destinataireID = nil
        self.destinataireNom = ""
        let ids = [expediteur.id.uuidString]
        self.lecteurIDsData = try? JSONCoderCache.encoder.encode(ids)
    }

    /// Message privé (individuel)
    init(contenu: String, expediteur: Utilisateur, destinataire: Utilisateur, codeEquipe: String) {
        self.id = UUID()
        self.contenu = contenu
        self.dateEnvoi = Date()
        self.expediteurID = expediteur.id
        self.expediteurNom = expediteur.nomComplet
        self.expediteurRoleRaw = expediteur.roleRaw
        self.codeEquipe = codeEquipe
        self.destinataireID = destinataire.id
        self.destinataireNom = destinataire.nomComplet
        let ids = [expediteur.id.uuidString]
        self.lecteurIDsData = try? JSONCoderCache.encoder.encode(ids)
    }
}
