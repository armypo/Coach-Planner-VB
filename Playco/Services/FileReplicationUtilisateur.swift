//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  FileReplicationUtilisateur — File persistante des utilisateurs à re-publier
//  vers CloudKit Public Database quand `publierEquipeComplete` échoue partiellement
//  (réseau coupé, quota, timeout). Re-publié automatiquement quand le réseau revient.
//
//  v1.11 (Sprint E) : persistance déplacée de UserDefaults vers Keychain (NEW-SEC-02).
//  Abandon automatique après `tentativesMax` échecs consécutifs (NEW-SEC-04).

import Foundation
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "FileReplication")

/// Entrée en attente de re-publication. `prochainEssai` permet le backoff exponentiel.
struct UtilisateurEnAttente: Codable {
    let utilisateurID: UUID
    var tentatives: Int
    var prochainEssai: Date
}

/// Politique de retry : délais successifs, puis cap au dernier.
enum PolitiqueRetry {
    static let delais: [TimeInterval] = [
        30,          // 30 secondes
        2 * 60,      // 2 minutes
        10 * 60,     // 10 minutes
        60 * 60      // 1 heure
    ]

    /// Nombre max de tentatives avant abandon (NEW-SEC-04).
    /// 10 tentatives ≈ 10h cumulés avec le backoff plafonné à 1h.
    static let tentativesMax = 10

    /// Délai à appliquer APRÈS `numeroTentative` tentatives infructueuses.
    /// numeroTentative=1 → 30s, 2 → 120s, 3 → 600s, 4+ → 3600s.
    static func delaiApresTentative(_ numeroTentative: Int) -> TimeInterval {
        let index = min(max(numeroTentative - 1, 0), delais.count - 1)
        return delais[index]
    }
}

/// Nombre max d'utilisateurs republiés par appel à `rejouerFileAttente`.
/// Évite de monopoliser le réseau/batterie au retour en ligne.
private let tailleBatchRejeu = 20

/// Actor responsable de la file d'attente des utilisateurs non-publiés.
/// Isolation actor = accès thread-safe sans locks explicites.
actor FileReplicationUtilisateur {

    static let shared = FileReplicationUtilisateur()

    /// Clé Keychain (v1.11+). Chaîne JSON d'un tableau `[UtilisateurEnAttente]`.
    static let cleKeychain = "playco.pending_publish"

    /// Clé UserDefaults legacy (v1.10). Lue une fois pour migration.
    private static let cleUserDefaultsLegacy = "playco.pending_publish"

    /// Dictionnaire indexé par utilisateurID — garantit une entrée unique par user.
    private var pending: [UUID: UtilisateurEnAttente] = [:]
    private var charge = false

    /// Chargement lazy depuis Keychain (puis migration UserDefaults si nécessaire)
    /// à la première interaction actor-isolée.
    private func chargerSiNecessaire() {
        guard !charge else { return }
        charge = true

        // 1. Keychain (source de vérité)
        if let json = KeychainService.lire(cle: Self.cleKeychain),
           let data = json.data(using: .utf8),
           let decoded = try? JSONCoderCache.decoder.decode([UtilisateurEnAttente].self, from: data) {
            pending = Dictionary(uniqueKeysWithValues: decoded.map { ($0.utilisateurID, $0) })
            if !pending.isEmpty {
                logger.info("File re-publication chargée depuis Keychain : \(self.pending.count) entrées")
            }
            return
        }

        // 2. Migration one-shot depuis UserDefaults legacy
        guard let data = UserDefaults.standard.data(forKey: Self.cleUserDefaultsLegacy),
              let decoded = try? JSONCoderCache.decoder.decode([UtilisateurEnAttente].self, from: data) else {
            return
        }
        pending = Dictionary(uniqueKeysWithValues: decoded.map { ($0.utilisateurID, $0) })
        sauvegarder()
        UserDefaults.standard.removeObject(forKey: Self.cleUserDefaultsLegacy)
        logger.info("Migration file re-publication UserDefaults → Keychain (\(self.pending.count) entrées)")
    }

    /// Ajoute un utilisateur à la file. Idempotent sur `utilisateurID` (remplace l'entrée).
    func enregistrer(_ id: UUID) {
        chargerSiNecessaire()
        pending[id] = UtilisateurEnAttente(
            utilisateurID: id,
            tentatives: 0,
            prochainEssai: Date()
        )
        sauvegarder()
        logger.info("Utilisateur \(id.uuidString, privacy: .private) ajouté à la file (taille=\(self.pending.count))")
    }

    /// Marque un utilisateur comme publié avec succès.
    func marquerPublie(_ id: UUID) {
        chargerSiNecessaire()
        guard pending.removeValue(forKey: id) != nil else { return }
        sauvegarder()
        logger.info("Utilisateur \(id.uuidString, privacy: .private) publié, retiré (taille=\(self.pending.count))")
    }

    /// Liste des IDs prêts à être réessayés (prochainEssai <= maintenant).
    /// Retourne au plus `tailleBatchRejeu` IDs pour éviter de saturer le réseau.
    func listerPrets(maintenant: Date = .now) -> [UUID] {
        chargerSiNecessaire()
        return pending.values
            .filter { $0.prochainEssai <= maintenant }
            .prefix(tailleBatchRejeu)
            .map { $0.utilisateurID }
    }

    /// Incrémente le compteur de tentatives et programme le prochain essai.
    /// Abandonne si > `PolitiqueRetry.tentativesMax` — entrée retirée + log critique.
    func planifierRetry(_ id: UUID) {
        chargerSiNecessaire()
        guard var entree = pending[id] else { return }
        entree.tentatives += 1

        if entree.tentatives > PolitiqueRetry.tentativesMax {
            pending.removeValue(forKey: id)
            sauvegarder()
            logger.critical("Utilisateur \(id.uuidString, privacy: .private) abandonné après \(entree.tentatives - 1) tentatives infructueuses — action manuelle requise")
            return
        }

        let delai = PolitiqueRetry.delaiApresTentative(entree.tentatives)
        entree.prochainEssai = Date().addingTimeInterval(delai)
        pending[id] = entree
        sauvegarder()
        logger.warning("Retry planifié pour \(id.uuidString, privacy: .private) dans \(Int(delai))s (tentative #\(entree.tentatives))")
    }

    /// Indique si la file contient des entrées.
    func estVide() -> Bool {
        chargerSiNecessaire()
        return pending.isEmpty
    }

    /// Taille actuelle de la file (pour l'UI éventuelle).
    func taille() -> Int {
        chargerSiNecessaire()
        return pending.count
    }

    // MARK: - Persistance Keychain

    private func sauvegarder() {
        let entrees = Array(pending.values)
        guard let data = try? JSONCoderCache.encoder.encode(entrees),
              let json = String(data: data, encoding: .utf8) else { return }
        KeychainService.sauvegarder(cle: Self.cleKeychain, valeur: json)
    }

    // MARK: - Tests uniquement

    /// Reset l'état pour les tests — ne PAS utiliser en production.
    func reinitialiserPourTests() {
        pending = [:]
        charge = true
        KeychainService.supprimer(cle: Self.cleKeychain)
        UserDefaults.standard.removeObject(forKey: Self.cleUserDefaultsLegacy)
    }
}
