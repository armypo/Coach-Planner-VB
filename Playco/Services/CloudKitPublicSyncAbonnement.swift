//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  CloudKitPublicSyncAbonnement — publication/lecture du statut d'abonnement
//  dans la CloudKit Public Database, indexé par `codeEquipe`.
//
//  Pourquoi (Phase 1.5 G2/G3) : la source de vérité du statut est
//  StoreKit.Transaction.currentEntitlements, liée à l'Apple ID. Quand un coach
//  se reconnecte sur un Apple ID DIFFÉRENT (nouvel appareil, compte familial,
//  changement de compte), `currentEntitlements` est vide → l'app retomberait à
//  tort sur `.essaiExpire`. Ce service publie le tier dans la Public DB (clé =
//  codeEquipe, déjà partagée entre membres de l'équipe) et permet de le relire
//  comme fallback, pour ne pas verrouiller un coach légitimement abonné.
//
//  L'écriture est résiliente : en cas d'échec (réseau coupé, quota), l'instantané
//  est enfilé (UserDefaults) et rejoué au prochain `publier`/`rejouerSiNecessaire`.
//
//  ⚠️ SÉCURITÉ (limite connue, non bloquante) : la Public DB est inscriptible par
//  tout utilisateur iCloud authentifié et `codeEquipe` est partagé avec l'équipe.
//  Un enregistrement `AbonnementPartage` forgé pourrait donc débloquer un tier sans
//  achat (contournement paywall) lors d'une reconnexion sur Apple ID différent.
//  La SOURCE DE VÉRITÉ reste StoreKit (entitlements locaux) ; ce miroir n'est qu'un
//  fallback de confort. Atténuation requise avant de durcir : restreindre le rôle
//  d'écriture du type `AbonnementPartage` à « créateur uniquement » dans le
//  CloudKit Dashboard (+ idéalement validation de reçu signé). Voir TODO audit.

import Foundation
import CloudKit
import os

/// Instantané Sendable de l'abonnement publié dans la Public DB.
/// `Codable` pour la file d'attente offline ; `Equatable` pour les tests.
nonisolated struct AbonnementPublicSnapshot: Codable, Sendable, Equatable {
    let codeEquipe: String
    let tier: Tier
    let type: TypeAbonnement
    let dateExpiration: Date?
    let dateDernierSync: Date
}

/// Actor responsable du miroir Public DB de l'abonnement.
/// Isolation actor = accès thread-safe à la file `pending` sans locks explicites.
actor CloudKitPublicSyncAbonnement {

    static let shared = CloudKitPublicSyncAbonnement()

    private let container = CKContainer(identifier: "iCloud.Origo.Playco")
    private var publicDB: CKDatabase { container.publicCloudDatabase }
    private let logger = Logger(subsystem: "com.origotech.playco", category: "AboPublicSync")

    /// Type d'enregistrement CloudKit (aligné sur la nomenclature `*Partage`).
    static let recordType = "AbonnementPartage"

    /// Clé UserDefaults de la file d'attente (un seul instantané en attente suffit :
    /// le dernier état gagne, c'est un upsert idempotent par `codeEquipe`).
    private static let clePending = "playco.abo_public_pending"

    private func recordID(codeEquipe: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "abo-\(codeEquipe)")
    }

    // MARK: - Publication (côté coach payant)

    /// Publie (upsert) l'instantané dans la Public DB. Idempotent.
    /// En cas d'échec, enfile l'instantané pour rejeu ultérieur.
    func publier(_ snap: AbonnementPublicSnapshot) async {
        guard !snap.codeEquipe.isEmpty, snap.tier != .aucun else { return }
        do {
            try await ecrire(snap)
            effacerPending()
            logger.info("Abonnement publié Public DB (codeEquipe=\(snap.codeEquipe, privacy: .public), tier=\(snap.tier.rawValue, privacy: .public))")
        } catch {
            enregistrerPending(snap)
            logger.warning("Publication abonnement échouée, enfilé : \(error.localizedDescription)")
        }
    }

    /// Rejoue l'instantané en attente s'il en existe un (à appeler au retour réseau).
    func rejouerSiNecessaire() async {
        guard let snap = lirePending() else { return }
        await publier(snap)
    }

    private func ecrire(_ snap: AbonnementPublicSnapshot) async throws {
        let id = recordID(codeEquipe: snap.codeEquipe)
        // Upsert : récupérer l'enregistrement existant pour le modifier, sinon créer.
        let record: CKRecord
        if let existant = try? await publicDB.record(for: id) {
            record = existant
        } else {
            record = CKRecord(recordType: Self.recordType, recordID: id)
        }
        Self.appliquer(snap, sur: record)
        _ = try await publicDB.save(record)
    }

    // MARK: - Lecture (fallback reconnexion Apple ID différent)

    /// Lit l'instantané publié pour un `codeEquipe`. `nil` si absent ou erreur
    /// (l'appelant retombe alors sur le comportement par défaut).
    func lire(codeEquipe: String) async -> AbonnementPublicSnapshot? {
        guard !codeEquipe.isEmpty else { return nil }
        do {
            let record = try await publicDB.record(for: recordID(codeEquipe: codeEquipe))
            return Self.snapshot(depuis: record)
        } catch {
            logger.info("Lecture abonnement Public DB absente (codeEquipe=\(codeEquipe, privacy: .public)) : \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Mapping CKRecord ⇄ snapshot (pur, testable)

    /// Écrit les champs de l'instantané sur un enregistrement CloudKit.
    nonisolated static func appliquer(_ snap: AbonnementPublicSnapshot, sur record: CKRecord) {
        record["codeEquipe"] = snap.codeEquipe as CKRecordValue
        record["tierRaw"] = snap.tier.rawValue as CKRecordValue
        record["typeRaw"] = snap.type.rawValue as CKRecordValue
        record["dateDernierSync"] = snap.dateDernierSync as CKRecordValue
        if let exp = snap.dateExpiration {
            record["dateExpiration"] = exp as CKRecordValue
        }
    }

    /// Reconstruit un instantané depuis un enregistrement CloudKit. `nil` si
    /// champs requis manquants/invalides (record malformé).
    nonisolated static func snapshot(depuis record: CKRecord) -> AbonnementPublicSnapshot? {
        guard let code = record["codeEquipe"] as? String,
              let tierRaw = record["tierRaw"] as? String,
              let typeRaw = record["typeRaw"] as? String,
              let tier = Tier(rawValue: tierRaw),
              let type = TypeAbonnement(rawValue: typeRaw) else {
            return nil
        }
        let dateSync = record["dateDernierSync"] as? Date ?? Date()
        let dateExp = record["dateExpiration"] as? Date
        return AbonnementPublicSnapshot(
            codeEquipe: code,
            tier: tier,
            type: type,
            dateExpiration: dateExp,
            dateDernierSync: dateSync
        )
    }

    // MARK: - File d'attente offline (UserDefaults, un seul instantané)

    private func enregistrerPending(_ snap: AbonnementPublicSnapshot) {
        guard let data = try? JSONCoderCache.encoder.encode(snap) else { return }
        UserDefaults.standard.set(data, forKey: Self.clePending)
    }

    private func lirePending() -> AbonnementPublicSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: Self.clePending) else { return nil }
        return try? JSONCoderCache.decoder.decode(AbonnementPublicSnapshot.self, from: data)
    }

    private func effacerPending() {
        UserDefaults.standard.removeObject(forKey: Self.clePending)
    }

    // MARK: - Tests uniquement

    /// Vide la file d'attente — usage tests, ne PAS utiliser en production.
    func reinitialiserPourTests() {
        effacerPending()
    }
}
