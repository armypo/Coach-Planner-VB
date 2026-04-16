//  Playco
//  Copyright (c) 2025 Christopher Dionne. Tous droits reserves.
//

import Foundation
import SwiftData
import CryptoKit
import os

// MARK: - Correction 6 : @MainActor
@MainActor
@Observable
final class AuthService {

    private static let logger = Logger(subsystem: "com.origotech.playco", category: "AuthService")

    var utilisateurConnecte: Utilisateur?
    var estConnecte: Bool { utilisateurConnecte != nil }
    var erreur: String?
    var chargement: Bool = false

    // MARK: - Correction 3 : Verrouillage persisté dans UserDefaults

    private static let cleTentatives = "playco_auth_tentatives"
    private static let cleVerrouillage = "playco_auth_verrouillage"

    /// Store persistant injecté — permet l'isolation des tests via des suites dédiées
    private let userDefaults: UserDefaults

    private(set) var tentativesEchouees: Int {
        didSet {
            userDefaults.set(tentativesEchouees, forKey: Self.cleTentatives)
        }
    }

    private(set) var verrouillageJusqua: Date? {
        didSet {
            if let date = verrouillageJusqua {
                userDefaults.set(date.timeIntervalSince1970, forKey: Self.cleVerrouillage)
            } else {
                userDefaults.removeObject(forKey: Self.cleVerrouillage)
            }
        }
    }

    var estVerrouille: Bool {
        guard let jusqua = verrouillageJusqua else { return false }
        return Date() < jusqua
    }

    var tempsRestantVerrouillage: Int {
        guard let jusqua = verrouillageJusqua else { return 0 }
        return max(0, Int(jusqua.timeIntervalSince(Date())))
    }

    // MARK: - Correction 5 : Session dans le Keychain

    private let cleSession = "playco_session_utilisateurConnecteID"
    private let cleSessionLegacy = "utilisateurConnecteID"

    var idSessionSauvegardee: String? {
        // Lecture depuis le Keychain ; migration depuis UserDefaults si nécessaire
        if let idKeychain = KeychainService.lire(cle: cleSession) {
            return idKeychain
        }
        // Migration : ancienne valeur UserDefaults → Keychain
        if let idLegacy = userDefaults.string(forKey: cleSessionLegacy) {
            KeychainService.sauvegarder(cle: cleSession, valeur: idLegacy)
            userDefaults.removeObject(forKey: cleSessionLegacy)
            return idLegacy
        }
        return nil
    }

    // MARK: - init : chargement de l'état persisté

    /// - Parameter userDefaults: magasin persistant à utiliser pour tentatives/verrouillage.
    ///   Les tests peuvent injecter `UserDefaults(suiteName: UUID().uuidString)` pour l'isolation.
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        tentativesEchouees = userDefaults.integer(forKey: Self.cleTentatives)
        let intervalSauvegarde = userDefaults.double(forKey: Self.cleVerrouillage)
        if intervalSauvegarde > 0 {
            verrouillageJusqua = Date(timeIntervalSince1970: intervalSauvegarde)
        } else {
            verrouillageJusqua = nil
        }
    }

    // MARK: - S1 : Hash du mot de passe avec sel (salt)

    /// Génère un sel aléatoire de 16 bytes
    func genererSel() -> String {
        let bytes = (0..<16).map { _ in UInt8.random(in: 0...255) }
        return Data(bytes).map { String(format: "%02x", $0) }.joined()
    }

    /// Hash avec sel : SHA256(sel + motDePasse)
    func hashMotDePasse(_ motDePasse: String, sel: String) -> String {
        let donnees = Data((sel + motDePasse).utf8)
        let hash = SHA256.hash(data: donnees)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Hash sans sel (rétrocompatibilité pour anciens comptes) — privée
    private func hashMotDePasse(_ motDePasse: String) -> String {
        let donnees = Data(motDePasse.utf8)
        let hash = SHA256.hash(data: donnees)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Vérifie le mot de passe (avec ou sans sel)
    /// Utilise `sel?.isEmpty ?? true` pour traiter nil et "" comme "pas de sel"
    private func verifierMotDePasse(_ motDePasse: String, hash: String, sel: String?) -> Bool {
        let selAbsent = sel?.isEmpty ?? true
        if selAbsent {
            // Rétrocompatibilité : hash sans sel
            return hashMotDePasse(motDePasse) == hash
        } else {
            return hashMotDePasse(motDePasse, sel: sel!) == hash
        }
    }

    // MARK: - Restauration de session

    /// Durée maximum d'une session avant réauthentification obligatoire (30 jours)
    private static let dureeMaxSessionSecondes: TimeInterval = 30 * 24 * 3600

    func restaurerSession(context: ModelContext) {
        guard let idString = idSessionSauvegardee,
              let id = UUID(uuidString: idString) else { return }

        let descripteur = FetchDescriptor<Utilisateur>(
            predicate: #Predicate { $0.id == id && $0.estActif == true }
        )

        guard let utilisateur = try? context.fetch(descripteur).first else {
            KeychainService.supprimer(cle: cleSession)
            return
        }

        // Vérifier l'expiration de session (30 jours max)
        if let sessionCreee = utilisateur.sessionCreeeLe,
           Date().timeIntervalSince(sessionCreee) > Self.dureeMaxSessionSecondes {
            Self.logger.info("Session expirée après 30 jours — déconnexion automatique")
            KeychainService.supprimer(cle: cleSession)
            erreur = "Session expirée, veuillez vous reconnecter."
            return
        }

        // Amorcer le compteur pour les comptes migrés (sessionCreeeLe == nil avant cette version)
        // Sans ça, les anciens comptes bypasseraient indéfiniment la règle 30 jours
        if utilisateur.sessionCreeeLe == nil {
            utilisateur.sessionCreeeLe = Date()
            do {
                try context.save()
            } catch {
                Self.logger.warning("Impossible d'amorcer sessionCreeeLe: \(error.localizedDescription)")
            }
        }

        utilisateurConnecte = utilisateur
    }

    // MARK: - Connexion par Identifiant + Mot de passe

    func connexion(identifiant: String, motDePasse: String, context: ModelContext) {
        erreur = nil
        chargement = true

        // Vérifier le verrouillage
        if estVerrouille {
            erreur = "Compte verrouillé. Réessayez dans \(tempsRestantVerrouillage) secondes."
            chargement = false
            return
        }

        let idNormalise = identifiant.lowercased().trimmingCharacters(in: .whitespaces)

        let descripteur = FetchDescriptor<Utilisateur>(
            predicate: #Predicate {
                $0.identifiant == idNormalise &&
                $0.estActif == true
            }
        )

        do {
            let resultats = try context.fetch(descripteur)

            guard let utilisateur = resultats.first else {
                enregistrerEchec()
                erreur = "Identifiant ou mot de passe incorrect."
                chargement = false
                return
            }

            guard verifierMotDePasse(motDePasse, hash: utilisateur.motDePasseHash, sel: utilisateur.sel) else {
                enregistrerEchec()
                erreur = "Identifiant ou mot de passe incorrect."
                chargement = false
                return
            }

            // Succès → reset tentatives
            tentativesEchouees = 0
            verrouillageJusqua = nil

            // S1 : Migrer vers hash avec sel si l'ancien compte n'en avait pas
            if utilisateur.sel?.isEmpty ?? true {
                let nouveauSel = genererSel()
                utilisateur.sel = nouveauSel
                utilisateur.motDePasseHash = hashMotDePasse(motDePasse, sel: nouveauSel)
            }

            // Marquer la date de début de session pour expiration 30 jours
            utilisateur.sessionCreeeLe = Date()

            do {
                try context.save()
            } catch {
                Self.logger.error("Erreur sauvegarde session utilisateur: \(error.localizedDescription)")
                erreur = "Impossible d'enregistrer votre session. Réessayez."
                chargement = false
                return
            }

            utilisateurConnecte = utilisateur
            // Correction 5 : session dans le Keychain
            KeychainService.sauvegarder(cle: cleSession, valeur: utilisateur.id.uuidString)

        } catch {
            // Correction 4 : message générique + log détaillé
            Self.logger.error("Erreur connexion: \(error.localizedDescription)")
            erreur = "Une erreur est survenue lors de la connexion."
        }

        chargement = false
    }

    // MARK: - Correction 3 : Verrouillage progressif
    // 5 tentatives → 5 min, 10 tentatives → 15 min, 15+ tentatives → 1h

    func enregistrerEchec() {
        tentativesEchouees += 1

        let cycleActuel = tentativesEchouees / 5
        let reste = tentativesEchouees % 5

        guard reste == 0 && cycleActuel >= 1 else { return }

        let dureesVerrouillage: [TimeInterval] = [300, 900, 3600]
        let indexDuree = min(cycleActuel - 1, dureesVerrouillage.count - 1)
        let duree = dureesVerrouillage[indexDuree]

        verrouillageJusqua = Date().addingTimeInterval(duree)

        let minutes = Int(duree / 60)
        erreur = "Trop de tentatives. Compte verrouillé pendant \(minutes) minute(s)."
    }

    // MARK: - Création de compte (par le coach/admin)

    func creerCompte(identifiant: String, motDePasse: String, prenom: String, nom: String, role: RoleUtilisateur, context: ModelContext) -> String? {
        let idNormalise = identifiant.lowercased().trimmingCharacters(in: .whitespaces)

        guard !idNormalise.isEmpty, idNormalise.count >= 3 else {
            return "L'identifiant doit contenir au moins 3 caractères."
        }

        // Politique renforcée : min 8 caractères + au moins 1 chiffre
        guard motDePasse.count >= 8 else {
            return "Le mot de passe doit contenir au moins 8 caractères."
        }
        guard motDePasse.contains(where: { $0.isNumber }) else {
            return "Le mot de passe doit contenir au moins 1 chiffre."
        }

        guard !prenom.trimmingCharacters(in: .whitespaces).isEmpty,
              !nom.trimmingCharacters(in: .whitespaces).isEmpty else {
            return "Veuillez remplir le prénom et le nom."
        }

        let descripteur = FetchDescriptor<Utilisateur>(
            predicate: #Predicate { $0.identifiant == idNormalise }
        )

        do {
            let existants = try context.fetch(descripteur)
            if !existants.isEmpty {
                return "Cet identifiant existe déjà."
            }
        } catch {
            return "Erreur lors de la vérification."
        }

        // S1 : Hash avec sel
        let sel = genererSel()
        let hash = hashMotDePasse(motDePasse, sel: sel)
        let nouvelUtilisateur = Utilisateur(
            identifiant: idNormalise,
            motDePasseHash: hash,
            prenom: prenom.trimmingCharacters(in: .whitespaces),
            nom: nom.trimmingCharacters(in: .whitespaces),
            role: role
        )
        nouvelUtilisateur.sel = sel
        nouvelUtilisateur.codeInvitation = Utilisateur.genererCodeUniqueInvitation(context: context)

        context.insert(nouvelUtilisateur)

        do {
            try context.save()
            return nil
        } catch {
            return "Erreur lors de la création : \(error.localizedDescription)"
        }
    }

    // MARK: - Déconnexion

    func deconnexion() {
        utilisateurConnecte = nil
        KeychainService.supprimer(cle: cleSession)
    }

}
