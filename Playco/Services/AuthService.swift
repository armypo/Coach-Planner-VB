//  Playco
//  Copyright (c) 2025 Christopher Dionne. Tous droits reserves.
//

import Foundation
import SwiftData
import CryptoKit
import CommonCrypto
import os

// MARK: - AuthService (MainActor — thread safety)
@MainActor
@Observable
final class AuthService {

    private static let logger = Logger(subsystem: "com.origotech.playco", category: "AuthService")

    var utilisateurConnecte: Utilisateur?
    var estConnecte: Bool { utilisateurConnecte != nil }
    var erreur: String?
    var chargement: Bool = false

    /// Store UserDefaults injectable — conservé pour migration session legacy.
    private let userDefaults: UserDefaults

    // MARK: - Verrouillage (délégué à LockoutManager)

    /// Gestionnaire du verrouillage progressif + persistance Keychain.
    private let lockout: LockoutManager

    /// Alias statique pour compat tests : la vraie clé vit dans LockoutManager.
    static var cleEtatVerrouillage: String { LockoutManager.cleKeychain }

    /// Nombre d'échecs consécutifs (délégué à `lockout`).
    var tentativesEchouees: Int { lockout.tentatives }

    /// Date de fin de lockout si actif (délégué à `lockout`).
    var verrouillageJusqua: Date? { lockout.verrouillageJusqua }

    /// `true` si un lockout est actuellement actif (délégué à `lockout`).
    var estVerrouille: Bool { lockout.estVerrouille }

    /// Secondes restantes avant fin du lockout (délégué à `lockout`).
    var tempsRestantVerrouillage: Int { lockout.tempsRestant }

    // MARK: - Session (délégué à SessionManager)

    /// Gestionnaire de session (persistance Keychain + expiration 30j).
    private let session: SessionManager

    /// UUID de session sauvegardé, ou `nil` (délégué à `session`).
    var idSessionSauvegardee: String? { session.idSauvegarde }

    // MARK: - init

    /// - Parameter userDefaults: magasin UserDefaults pour la migration legacy.
    ///   Injectable pour isolation des tests. La logique de verrouillage elle-même
    ///   est déléguée à `LockoutManager` qui gère sa propre persistance Keychain.
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.lockout = LockoutManager(userDefaults: userDefaults)
        self.session = SessionManager(userDefaults: userDefaults)
    }

    // MARK: - Dérivation de clé (PBKDF2-HMAC-SHA256)

    /// Nombre d'itérations PBKDF2 pour les nouveaux comptes (OWASP 2024 : ≥ 600 000).
    static let iterationsParDefaut: Int = 600_000

    /// Génère un sel aléatoire de 16 bytes (encodé en hex, 32 caractères)
    func genererSel() -> String {
        let bytes = (0..<16).map { _ in UInt8.random(in: 0...255) }
        return Data(bytes).map { String(format: "%02x", $0) }.joined()
    }

    /// Hash du mot de passe avec PBKDF2-HMAC-SHA256 + sel.
    /// Utilise `iterationsParDefaut` (600 000) pour tous les nouveaux comptes.
    /// Sortie : 32 bytes → 64 caractères hex (même taille que l'ancien SHA256 pour compat tests).
    func hashMotDePasse(_ motDePasse: String, sel: String) -> String {
        deriverCle(motDePasse: motDePasse, sel: sel, iterations: Self.iterationsParDefaut)
    }

    /// Dérive une clé avec PBKDF2-HMAC-SHA256. Paramètre `iterations` exposé pour
    /// la vérification des comptes legacy (migration progressive).
    private func deriverCle(motDePasse: String, sel: String, iterations: Int) -> String {
        // Garde-fou : pointeur nil + count=0 sur CCKeyDerivationPBKDF est UB.
        guard !motDePasse.isEmpty else {
            Self.logger.error("deriverCle appelé avec motDePasse vide — refus")
            return ""
        }
        // Utilise Data.utf8 pour compter tous les bytes (tolère les NUL éventuels,
        // contrairement à strlen).
        let mdpData = Data(motDePasse.utf8)
        let selData = Data(sel.utf8)
        var derivee = [UInt8](repeating: 0, count: 32)

        let statut: Int32 = mdpData.withUnsafeBytes { mdpBuf in
            selData.withUnsafeBytes { selBuf in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    mdpBuf.baseAddress?.assumingMemoryBound(to: CChar.self),
                    mdpData.count,
                    selBuf.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    selData.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(iterations),
                    &derivee, derivee.count
                )
            }
        }

        guard statut == kCCSuccess else {
            Self.logger.critical("CCKeyDerivationPBKDF échec statut \(statut) — échec crypto, connexion refusée")
            return ""
        }

        return derivee.map { String(format: "%02x", $0) }.joined()
    }

    /// Hash SHA256+sel d'origine (v1.0 → v1.9) — conservé pour la vérification
    /// des comptes pré-PBKDF2. Ne JAMAIS utiliser pour de nouveaux comptes.
    private func hashLegacySHA256AvecSel(_ motDePasse: String, sel: String) -> String {
        let donnees = Data((sel + motDePasse).utf8)
        let hash = SHA256.hash(data: donnees)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Hash SHA256 sans sel (v0.x) — préhistoire, uniquement pour la compat.
    private func hashLegacySHA256SansSel(_ motDePasse: String) -> String {
        let donnees = Data(motDePasse.utf8)
        let hash = SHA256.hash(data: donnees)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Vérifie le mot de passe en choisissant l'algorithme selon les métadonnées
    /// du compte. Trois chemins :
    ///   • sel absent           → SHA256 brut (pré-v0.6)
    ///   • iterations ≤ 1 + sel → SHA256+sel (v0.6 → v1.9)
    ///   • iterations ≥ 2       → PBKDF2 avec le nombre d'itérations stocké
    private func verifierMotDePasse(_ motDePasse: String,
                                    hash: String,
                                    sel: String?,
                                    iterations: Int) -> Bool {
        guard let sel = sel, !sel.isEmpty else {
            return egaliteConstante(hashLegacySHA256SansSel(motDePasse), hash)
        }
        let candidat: String
        if iterations <= 1 {
            candidat = hashLegacySHA256AvecSel(motDePasse, sel: sel)
        } else {
            candidat = deriverCle(motDePasse: motDePasse, sel: sel, iterations: iterations)
        }
        return egaliteConstante(candidat, hash)
    }

    /// Comparaison constant-time pour éviter les timing attacks.
    private func egaliteConstante(_ a: String, _ b: String) -> Bool {
        let aBytes = Array(a.utf8)
        let bBytes = Array(b.utf8)
        guard aBytes.count == bBytes.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<aBytes.count {
            diff |= aBytes[i] ^ bBytes[i]
        }
        return diff == 0
    }

    // MARK: - Restauration de session

    /// Tente de restaurer la session précédente à partir du UUID stocké dans le
    /// Keychain. À appeler au démarrage de l'app après `attendreSyncInitiale()`
    /// pour éviter les faux-négatifs si CloudKit n'a pas encore rapatrié l'utilisateur.
    /// - Parameter context: contexte SwiftData pour fetch l'Utilisateur par id.
    ///
    /// Comportements :
    /// - Pas de session sauvegardée → no-op
    /// - Session > 30 jours → supprimée + `erreur` = "Session expirée"
    /// - Utilisateur absent/inactif → session supprimée, `utilisateurConnecte` reste nil
    /// - Session valide → `utilisateurConnecte` défini
    func restaurerSession(context: ModelContext) {
        guard let idString = session.idSauvegarde,
              let id = UUID(uuidString: idString) else { return }

        let descripteur = FetchDescriptor<Utilisateur>(
            predicate: #Predicate { $0.id == id && $0.estActif == true }
        )

        guard let utilisateur = try? context.fetch(descripteur).first else {
            session.supprimer()
            return
        }

        // Vérifier l'expiration de session (30 jours max)
        if let sessionCreee = utilisateur.sessionCreeeLe,
           SessionManager.estExpiree(dateCreation: sessionCreee) {
            Self.logger.info("Session expirée après 30 jours — déconnexion automatique")
            session.supprimer()
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

    /// Tente de connecter un utilisateur avec identifiant + mot de passe.
    ///
    /// Effets :
    /// - Succès : `utilisateurConnecte` défini, session Keychain écrite, compteur
    ///   tentatives reset. Migration auto SHA256 → PBKDF2 si compte legacy.
    /// - Échec : `erreur` défini avec message générique (pas d'info fuite sur
    ///   "identifiant inconnu" vs "mdp incorrect"), `enregistrerEchec()` appelé.
    /// - Verrouillé : retour early avec message + temps restant.
    ///
    /// Toutes les interpolations d'identifiant dans les logs utilisent
    /// `privacy: .private`. La comparaison de hash est constant-time.
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

            guard verifierMotDePasse(motDePasse,
                                     hash: utilisateur.motDePasseHash,
                                     sel: utilisateur.sel,
                                     iterations: utilisateur.iterations) else {
                enregistrerEchec()
                erreur = "Identifiant ou mot de passe incorrect."
                chargement = false
                return
            }

            // Succès → reset verrouillage
            lockout.reinitialiser()

            // Migration progressive vers PBKDF2 600k itérations :
            //   • compte sans sel (pré-v0.6)              → SHA256     → PBKDF2
            //   • compte avec sel mais iterations <= 1    → SHA256+sel → PBKDF2
            //   • compte déjà en PBKDF2 mais < 600k       → re-dérive avec 600k
            let needsMigration = (utilisateur.sel?.isEmpty ?? true) ||
                                 utilisateur.iterations < Self.iterationsParDefaut

            if needsMigration {
                let ancienHash = utilisateur.motDePasseHash
                let ancienSel = utilisateur.sel
                let ancienIterations = utilisateur.iterations
                let nouveauSel = genererSel()
                utilisateur.sel = nouveauSel
                utilisateur.motDePasseHash = hashMotDePasse(motDePasse, sel: nouveauSel)
                utilisateur.iterations = Self.iterationsParDefaut
                utilisateur.sessionCreeeLe = Date()
                do {
                    try context.save()
                    Self.logger.info("Migration hash réussie: \(utilisateur.identifiant, privacy: .private)")
                } catch {
                    // Rollback — éviter état incohérent hash mémoire vs BD
                    utilisateur.sel = ancienSel
                    utilisateur.motDePasseHash = ancienHash
                    utilisateur.iterations = ancienIterations
                    utilisateur.sessionCreeeLe = nil
                    Self.logger.error("Migration hash échouée, rollback: \(error.localizedDescription)")
                    erreur = "Impossible d'enregistrer votre session. Réessayez."
                    chargement = false
                    return
                }
            } else {
                // Marquer la date de début de session pour expiration 30 jours
                utilisateur.sessionCreeeLe = Date()
                do {
                    try context.save()
                } catch {
                    Self.logger.error("Erreur sauvegarde session: \(error.localizedDescription)")
                    erreur = "Impossible d'enregistrer votre session. Réessayez."
                    chargement = false
                    return
                }
            }

            utilisateurConnecte = utilisateur
            // Persistance session Keychain (survit à fermeture app, pas à logout explicite)
            session.sauvegarder(utilisateurID: utilisateur.id)

        } catch {
            // Message générique côté UI, détail uniquement dans le log privé
            Self.logger.error("Erreur connexion: \(error.localizedDescription)")
            erreur = "Une erreur est survenue lors de la connexion."
        }

        chargement = false
    }

    // MARK: - Enregistrer un échec de connexion

    /// Délègue à `LockoutManager.enregistrerEchec()` et propage le message de
    /// lockout vers `erreur` si un palier est atteint.
    func enregistrerEchec() {
        if let message = lockout.enregistrerEchec() {
            erreur = message
        }
    }

    // MARK: - Création de compte (par le coach/admin)

    /// Crée un nouveau compte utilisateur (coach/admin uniquement).
    /// - Returns: `nil` si succès, sinon le message d'erreur à afficher à l'UI.
    ///
    /// Valide :
    /// - Identifiant : ≥ 3 caractères, unique en BD
    /// - Mot de passe : politique NIST 800-63B (12 chars + pas dans blacklist +
    ///   ne contient pas identifiant/prénom/nom)
    /// - Prénom / nom : non vides
    ///
    /// Le hash est dérivé avec PBKDF2-HMAC-SHA256 600k itérations.
    func creerCompte(identifiant: String, motDePasse: String, prenom: String, nom: String, role: RoleUtilisateur, context: ModelContext) -> String? {
        let idNormalise = identifiant.lowercased().trimmingCharacters(in: .whitespaces)

        guard !idNormalise.isEmpty, idNormalise.count >= 3 else {
            return "L'identifiant doit contenir au moins 3 caractères."
        }

        if let erreurMdp = PasswordPolicy.valider(motDePasse,
                                                  identifiant: idNormalise,
                                                  prenom: prenom,
                                                  nom: nom) {
            return erreurMdp
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

        // PBKDF2-HMAC-SHA256 600k itérations (cf. iterationsParDefaut).
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
        nouvelUtilisateur.iterations = Self.iterationsParDefaut
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
        session.supprimer()
    }

    // MARK: - Vérification état utilisateur (foreground check)

    /// Résultat de la vérification de l'état de l'utilisateur connecté.
    enum EtatSession {
        /// Utilisateur toujours actif et valide.
        case valide
        /// Utilisateur désactivé par le coach depuis la dernière connexion.
        case desactive
        /// Utilisateur supprimé de la BD depuis la dernière connexion.
        case supprime
    }

    /// Vérifie que l'utilisateur connecté est toujours valide dans la BD.
    /// À appeler au retour foreground (scenePhase = .active) pour révoquer
    /// rapidement les comptes désactivés par le coach.
    /// NE modifie PAS l'état — le caller décide de la déconnexion.
    func verifierEtatSession(context: ModelContext) -> EtatSession {
        guard let utilisateurID = utilisateurConnecte?.id else { return .valide }
        let descripteur = FetchDescriptor<Utilisateur>(
            predicate: #Predicate { $0.id == utilisateurID }
        )
        guard let utilisateur = try? context.fetch(descripteur).first else {
            return .supprime
        }
        return utilisateur.estActif ? .valide : .desactive
    }

}
