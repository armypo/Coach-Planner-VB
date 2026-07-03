//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  CloudKitSharingService — Sync équipe via CloudKit Public Database
//  Permet au coach de publier les données d'équipe et aux athlètes de les récupérer
//  via le code d'équipe, même sur des comptes iCloud différents.
//
//  Découpage du service :
//  - CloudKitSharingService.swift (ce fichier) : état, RecordType, SharingError,
//    lecture sécurisée CKRecord.
//  - CloudKitSharingService+Publication.swift : publication côté coach.
//  - CloudKitSharingService+Import.swift : récupération/import côté athlète.
//  - CloudKitSharingService+Jointure.swift : jointure d'équipe (SIWA).

import Foundation
import CloudKit
import SwiftData
import os

/// Service de partage inter-utilisateurs via CloudKit Public Database
@MainActor
@Observable
final class CloudKitSharingService {

    // MARK: - État

    var estEnCoursDePublication = false
    var estEnCoursDeRecuperation = false
    var erreur: String?

    /// Date de la dernière sync réussie (persistée en UserDefaults)
    // interne (partagé entre extensions du service)
    var derniereSyncDate: Date {
        get { UserDefaults.standard.object(forKey: "derniereSyncPublic") as? Date ?? .distantPast }
        set { UserDefaults.standard.set(newValue, forKey: "derniereSyncPublic") }
    }

    // MARK: - CloudKit

    private let container = CKContainer(identifier: "iCloud.Origo.Playco")
    // interne (partagé entre extensions du service)
    var publicDB: CKDatabase { container.publicCloudDatabase }

    // MARK: - Types d'enregistrement CloudKit

    // interne (partagé entre extensions du service)
    enum RecordType {
        static let equipe = "EquipePartagee"
        static let utilisateur = "UtilisateurPartage"
        static let joueur = "JoueurPartage"
        static let etablissement = "EtablissementPartage"
        static let seance = "SeancePartagee"
    }

    // MARK: - Erreurs

    enum SharingError: LocalizedError {
        case equipeNonTrouvee
        case importEchoue
        case sauvegardeEchouee
        case invitationInvalide
        case reseauIndisponible

        var errorDescription: String? {
            switch self {
            case .equipeNonTrouvee: return "Aucune équipe trouvée avec ce code."
            case .importEchoue: return "Impossible d'importer les données de l'équipe."
            case .sauvegardeEchouee: return "Impossible de sauvegarder les données importées."
            case .invitationInvalide: return "Code d'invitation invalide ou déjà utilisé. Vérifie avec ton coach."
            case .reseauIndisponible: return "Impossible de vérifier le code d'équipe. Vérifie ta connexion Internet et réessaie."
            }
        }
    }
}

// MARK: - Lecture sécurisée des records publics

extension CKRecord {
    /// Longueur max d'un champ texte importé depuis la Public DB. Jamais atteinte
    /// par des données légitimes — protège contre des strings dégénérées (DoS).
    private static let longueurMaxChaine = 2000

    /// Lit un champ String d'un record de la Public DB. Les records publics sont
    /// des DONNÉES EXTERNES NON FIABLES (world-writable côté clients non patchés) :
    /// longueur plafonnée, caractères de contrôle retirés (sauf sauts de ligne et
    /// tabulations, légitimes dans les notes), espaces de bord retirés.
    func chaineSecurisee(_ cle: String) -> String? {
        guard let brut = self[cle] as? String else { return nil }
        let scalairesFiltres = brut.unicodeScalars.filter { scalaire in
            !CharacterSet.controlCharacters.contains(scalaire)
                || scalaire == "\n" || scalaire == "\t"
        }
        return String(String.UnicodeScalarView(scalairesFiltres))
            .prefix(Self.longueurMaxChaine)
            .trimmingCharacters(in: .whitespaces)
    }
}
