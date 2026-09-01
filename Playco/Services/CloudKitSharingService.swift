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

    /// E′ — identité d'ÉCRIVAIN de cet appareil (`Utilisateur.id` du compte
    /// connecté, stable inter-appareils d'un même compte). Posée par ContentView
    /// avant toute sync et par la jonction. Aucune publication sans écrivain.
    var ecrivainID: String?

    /// E′ — état de sync PAR ÉQUIPE : seuil de publication, filigranes anti-écho,
    /// tombstones traités, borne d'import des points (docs/Architecture_SyncEPrime.md §3).
    let etatSync = EtatSyncEquipe()

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
        // E2 — contenus de préparation (parité assistant D6)
        static let exercice = "ExercicePartage"
        static let strategie = "StrategiePartagee"
        static let scouting = "ScoutingPartage"
        static let bibliotheque = "BibliothequePartagee"
        // E3 — analyse (parité assistant D6)
        static let statsMatch = "StatsMatchPartage"
        static let pointMatch = "PointMatchPartage"
        static let formation = "FormationPartagee"
        // E′ — tombstones de suppression (docs/Architecture_SyncEPrime.md §4)
        static let suppression = "SuppressionPartagee"
    }

    // MARK: - Nommage par écrivain (E′ §1)

    /// RecordName par écrivain : deux coachs n'écrivent JAMAIS le même record
    /// (la Public DB n'autorise l'écriture d'un record existant qu'à son
    /// créateur). L'import fusionne les copies par LWW. Fonction pure testable.
    static func nomRecord(_ prefixe: String, id: String, ecrivain: String) -> String {
        "\(prefixe)-\(id)-w\(ecrivain)"
    }

    /// Portée séance des tombstones de points live (un tombstone couvre tous
    /// les points d'un match supprimé — jamais un tombstone par point).
    static let typeCiblePointsSeance = "PointMatchSeance"

    // MARK: - Confiance par créateur (E′ §2)

    /// Ensemble des créateurs CloudKit acceptés à l'import d'une équipe.
    /// `creatorUserRecordID` est posé par le SERVEUR — infalsifiable, contrairement
    /// aux champs du record (codeEquipe, IDs…) qu'un tiers peut copier.
    struct ConfianceEquipe {
        /// Créateur du record `equipe-<code>` (recordName unique : le premier
        /// créateur le détient). nil = équipe introuvable → tout est rejeté.
        let racine: String?
        /// Racine + assistants dont la copie UtilisateurPartage correspond à une
        /// ligne créée par la racine (couple utilisateurID+codeInvitation).
        let membres: Set<String>

        /// Mes propres records reviennent avec le créateur placeholder
        /// `__defaultOwner__` — toujours de confiance (ils sont à moi).
        static let proprietaireLocal = "__defaultOwner__"

        func accepte(createur: String?) -> Bool {
            guard let createur else { return false }
            if createur == Self.proprietaireLocal { return true }
            return membres.contains(createur)
        }
    }

    /// Construit l'ensemble de confiance à partir des lignes UtilisateurPartage.
    /// Fonction pure testable. `lignes` = (createur, utilisateurID, codeInvitation).
    static func construireConfiance(
        racine: String?,
        lignes: [(createur: String, utilisateurID: String, codeInvitation: String)]
    ) -> ConfianceEquipe {
        guard let racine else { return ConfianceEquipe(racine: nil, membres: []) }
        // Fixpoint (D6 — un assistant peut en ajouter un autre) : la racine est
        // de confiance ; un couple (utilisateurID, codeInvitation) émis par un
        // membre DÉJÀ de confiance devient un couple valide ; un écrivain qui
        // revendique un couple valide rejoint les membres. On itère jusqu'à
        // stabilité. `proprietaireLocal` (mes propres records) = toujours membre.
        func cle(_ l: (createur: String, utilisateurID: String, codeInvitation: String)) -> String {
            "\(l.utilisateurID)|\(l.codeInvitation)"
        }
        var membres: Set<String> = [racine, ConfianceEquipe.proprietaireLocal]
        var change = true
        while change {
            change = false
            let couplesValides = Set(
                lignes
                    .filter { membres.contains($0.createur) && !$0.codeInvitation.isEmpty }
                    .map(cle)
            )
            for ligne in lignes where !membres.contains(ligne.createur) {
                if couplesValides.contains(cle(ligne)) {
                    membres.insert(ligne.createur)
                    change = true
                }
            }
        }
        membres.remove(ConfianceEquipe.proprietaireLocal)  // reste accepté via accepte()
        return ConfianceEquipe(racine: racine, membres: membres)
    }

    // MARK: - Plan de synchronisation par rôle (E4 — parité D6)

    /// Qui importe / qui publie. D6 : assistant = head coach — TOUS les rôles
    /// coach importent PUIS publient par les mêmes chemins (dernier écrivain
    /// gagne par `dateModification`). `.etudiant` (legacy, lecture seule)
    /// importe seulement. Fonction pure testable.
    static func planSync(role: RoleUtilisateur) -> (importe: Bool, publie: Bool) {
        switch role {
        case .etudiant:
            return (importe: true, publie: false)
        case .admin, .coach, .assistantCoach:
            return (importe: true, publie: true)
        }
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
