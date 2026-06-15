//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Tests pour CloudKitPublicSyncAbonnement (Phase 1.5 G2/G3) — miroir Public DB
//  du statut d'abonnement, clé `codeEquipe`, pour reconnexion sur Apple ID
//  différent. On teste la surface PURE : mapping CKRecord ⇄ snapshot + round-trip
//  Codable (la file pending et les I/O CloudKit réels ne sont pas unit-testables).
//

import Testing
import Foundation
import CloudKit
@testable import Playco

@Suite("CloudKitPublicSyncAbonnement — mapping snapshot")
struct CloudKitPublicSyncAbonnementTests {

    /// Construit un CKRecord du bon type pour les tests (aucun accès réseau).
    private func recordVierge(_ code: String = "EQU-TEST") -> CKRecord {
        let id = CKRecord.ID(recordName: "abo-\(code)")
        return CKRecord(recordType: CloudKitPublicSyncAbonnement.recordType, recordID: id)
    }

    // MARK: - Round-trip appliquer ⇄ snapshot

    @Test("appliquer puis snapshot reconstruit un instantané identique")
    func roundTripComplet() throws {
        let exp = Date(timeIntervalSince1970: 1_900_000_000)
        let origine = AbonnementPublicSnapshot(
            codeEquipe: "EQU-ABC",
            tier: .club,
            type: .annuel,
            dateExpiration: exp,
            dateDernierSync: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let record = recordVierge("EQU-ABC")
        CloudKitPublicSyncAbonnement.appliquer(origine, sur: record)

        let reconstruit = try #require(CloudKitPublicSyncAbonnement.snapshot(depuis: record))
        #expect(reconstruit.codeEquipe == "EQU-ABC")
        #expect(reconstruit.tier == .club)
        #expect(reconstruit.type == .annuel)
        #expect(reconstruit.dateExpiration == exp)
    }

    @Test("dateExpiration nil est préservée (abonnement sans expiration)")
    func expirationNilPreservee() throws {
        let origine = AbonnementPublicSnapshot(
            codeEquipe: "EQU-NIL",
            tier: .pro,
            type: .aucun,
            dateExpiration: nil,
            dateDernierSync: Date()
        )
        let record = recordVierge("EQU-NIL")
        CloudKitPublicSyncAbonnement.appliquer(origine, sur: record)

        let reconstruit = try #require(CloudKitPublicSyncAbonnement.snapshot(depuis: record))
        #expect(reconstruit.dateExpiration == nil)
        #expect(reconstruit.tier == .pro)
    }

    // MARK: - Records malformés → nil

    @Test("record sans tierRaw → nil")
    func recordSansTierEstNil() {
        let record = recordVierge()
        record["typeRaw"] = "mensuel" as CKRecordValue
        // pas de tierRaw ni codeEquipe
        #expect(CloudKitPublicSyncAbonnement.snapshot(depuis: record) == nil)
    }

    @Test("record avec tier invalide → nil")
    func recordTierInvalideEstNil() {
        let record = recordVierge()
        record["codeEquipe"] = "EQU-X" as CKRecordValue
        record["tierRaw"] = "platine_inexistant" as CKRecordValue
        record["typeRaw"] = "mensuel" as CKRecordValue
        #expect(CloudKitPublicSyncAbonnement.snapshot(depuis: record) == nil)
    }

    @Test("record avec type invalide → nil")
    func recordTypeInvalideEstNil() {
        let record = recordVierge()
        record["codeEquipe"] = "EQU-X" as CKRecordValue
        record["tierRaw"] = Tier.pro.rawValue as CKRecordValue
        record["typeRaw"] = "hebdomadaire_inexistant" as CKRecordValue
        #expect(CloudKitPublicSyncAbonnement.snapshot(depuis: record) == nil)
    }

    @Test("dateDernierSync absente → fallback non-nil (pas de crash)")
    func dateSyncAbsenteFallback() throws {
        let record = recordVierge()
        record["codeEquipe"] = "EQU-X" as CKRecordValue
        record["tierRaw"] = Tier.club.rawValue as CKRecordValue
        record["typeRaw"] = TypeAbonnement.mensuel.rawValue as CKRecordValue
        // pas de dateDernierSync
        let snap = try #require(CloudKitPublicSyncAbonnement.snapshot(depuis: record))
        #expect(snap.tier == .club)
    }

    // MARK: - Round-trip Codable (file pending offline)

    @Test("snapshot encodable/décodable pour la file d'attente")
    func codableRoundTrip() throws {
        let origine = AbonnementPublicSnapshot(
            codeEquipe: "EQU-CODABLE",
            tier: .pro,
            type: .mensuel,
            dateExpiration: Date(timeIntervalSince1970: 2_000_000_000),
            dateDernierSync: Date(timeIntervalSince1970: 1_950_000_000)
        )
        let data = try JSONCoderCache.encoder.encode(origine)
        let decode = try JSONCoderCache.decoder.decode(AbonnementPublicSnapshot.self, from: data)
        #expect(decode == origine)
    }
}
