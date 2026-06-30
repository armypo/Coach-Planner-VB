//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  CloudKitPublicSyncAbonnement — publication/lecture du STATUT d'abonnement
//  d'une équipe dans la base CloudKit publique, scopé par codeEquipe.
//
//  Permet à n'importe quel appareil (coach reconnecté sur un autre Apple ID,
//  ou membre de l'équipe) de connaître le tier actif du coach SANS exposer
//  aucun secret de transaction (pas d'appStoreTransactionID, pas de produitIAPID,
//  pas d'utilisateurID). Source of truth = StoreKit côté coach payeur.
//

import Foundation
import CloudKit
import os

actor CloudKitPublicSyncAbonnement {

    static let shared = CloudKitPublicSyncAbonnement()

    private let logger = Logger(subsystem: "com.origotech.playco", category: "AbonnementPartage")
    private let container = CKContainer(identifier: "iCloud.Origo.Playco")
    private var publicDB: CKDatabase { container.publicCloudDatabase }

    private enum RecordType { static let abonnement = "AbonnementPartage" }

    /// Statut d'équipe lu depuis le public DB (aucune donnée sensible).
    struct StatutEquipe: Sendable {
        let tierRaw: String
        let isActive: Bool
        let dateExpiration: Date?
    }

    private func recordID(_ codeEquipe: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "abo-\(codeEquipe)")
    }

    /// Publie le statut d'abonnement de l'équipe (coach payeur uniquement).
    func publierStatut(codeEquipe: String, tierRaw: String, isActive: Bool, dateExpiration: Date?) async {
        guard !codeEquipe.isEmpty else { return }
        let id = recordID(codeEquipe)
        let record = (try? await publicDB.record(for: id))
            ?? CKRecord(recordType: RecordType.abonnement, recordID: id)

        record["codeEquipe"] = codeEquipe as CKRecordValue
        record["tierRaw"] = tierRaw as CKRecordValue
        record["isActive"] = (isActive ? 1 : 0) as CKRecordValue
        if let exp = dateExpiration {
            record["dateExpiration"] = exp as CKRecordValue
        }
        record["dateModification"] = Date() as CKRecordValue

        do {
            _ = try await publicDB.save(record)
            logger.info("Statut abonnement publié pour équipe \(codeEquipe, privacy: .private) — tier=\(tierRaw) actif=\(isActive)")
        } catch {
            logger.error("publierStatut: échec \(error.localizedDescription)")
        }
    }

    /// Lit le statut d'abonnement publié pour une équipe (tout appareil).
    func lireStatut(codeEquipe: String) async -> StatutEquipe? {
        guard !codeEquipe.isEmpty else { return nil }
        guard let record = try? await publicDB.record(for: recordID(codeEquipe)) else {
            return nil
        }
        return StatutEquipe(
            tierRaw: record["tierRaw"] as? String ?? Tier.aucun.rawValue,
            isActive: (record["isActive"] as? Int ?? 0) == 1,
            dateExpiration: record["dateExpiration"] as? Date
        )
    }
}
