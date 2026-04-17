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

    // MARK: - Verrouillage persisté dans Keychain (Sprint B)
    //
    // Le Keychain survit à la désinstallation/réinstallation de l'app (jusqu'à
    // supprimer via Réglages), empêchant le contournement du lockout par simple
    // réinstall. Les anciennes clés UserDefaults sont migrées au premier init.

    /// Clé Keychain pour l'état verrouillage (JSON encodé Codable).
    static let cleEtatVerrouillage = "playco_auth_state"

    /// Clés legacy UserDefaults — lues une fois pour migration, puis supprimées.
    private static let cleTentativesLegacy = "playco_auth_tentatives"
    private static let cleVerrouillageLegacy = "playco_auth_verrouillage"

    /// Store UserDefaults injectable — conservé pour compat tests + migration.
    private let userDefaults: UserDefaults

    /// État sérialisable persisté dans le Keychain.
    private struct EtatVerrouillage: Codable {
        var tentatives: Int
        var jusqua: TimeInterval?
    }

    private(set) var tentativesEchouees: Int
    private(set) var verrouillageJusqua: Date?

    /// Persiste l'état courant dans le Keychain. Appelée explicitement après
    /// chaque mutation de `tentativesEchouees` ou `verrouillageJusqua`.
    private func persisterEtatVerrouillage() {
        let etat = EtatVerrouillage(
            tentatives: tentativesEchouees,
            jusqua: verrouillageJusqua?.timeIntervalSince1970
        )
        do {
            let data = try JSONCoderCache.encoder.encode(etat)
            guard let json = String(data: data, encoding: .utf8) else { return }
            KeychainService.sauvegarder(cle: Self.cleEtatVerrouillage, valeur: json)
        } catch {
            Self.logger.error("Échec encodage état verrouillage: \(error.localizedDescription)")
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

    // MARK: - Session persistée dans le Keychain

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

    /// - Parameter userDefaults: magasin UserDefaults pour la migration legacy uniquement.
    ///   Les tests peuvent injecter `UserDefaults(suiteName: UUID().uuidString)`, mais le
    ///   verrouillage lui-même est maintenant stocké dans le Keychain (global iOS).
    ///   Les tests doivent nettoyer `KeychainService.supprimer(cle: cleEtatVerrouillage)`
    ///   avant chaque test.
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        // 1. Tentative lecture Keychain (source de vérité)
        if let json = KeychainService.lire(cle: Self.cleEtatVerrouillage),
           let data = json.data(using: .utf8),
           let etat = try? JSONCoderCache.decoder.decode(EtatVerrouillage.self, from: data) {
            self.tentativesEchouees = etat.tentatives
            self.verrouillageJusqua = etat.jusqua.map { Date(timeIntervalSince1970: $0) }
            return
        }

        // 2. Fallback : migration depuis UserDefaults legacy
        let tentativesLegacy = userDefaults.integer(forKey: Self.cleTentativesLegacy)
        let intervalLegacy = userDefaults.double(forKey: Self.cleVerrouillageLegacy)
        self.tentativesEchouees = tentativesLegacy
        self.verrouillageJusqua = intervalLegacy > 0
            ? Date(timeIntervalSince1970: intervalLegacy)
            : nil

        // Si des données legacy existent, migrer vers Keychain et nettoyer UserDefaults
        if tentativesLegacy > 0 || intervalLegacy > 0 {
            persisterEtatVerrouillage()
            userDefaults.removeObject(forKey: Self.cleTentativesLegacy)
            userDefaults.removeObject(forKey: Self.cleVerrouillageLegacy)
            Self.logger.info("Migration état verrouillage UserDefaults → Keychain")
        }
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

    /// Durée maximum d'une session avant réauthentification obligatoire (30 jours)
    private static let dureeMaxSessionSecondes: TimeInterval = 30 * 24 * 3600

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

            // Succès → reset tentatives
            tentativesEchouees = 0
            verrouillageJusqua = nil
            persisterEtatVerrouillage()

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
            KeychainService.sauvegarder(cle: cleSession, valeur: utilisateur.id.uuidString)

        } catch {
            // Message générique côté UI, détail uniquement dans le log privé
            Self.logger.error("Erreur connexion: \(error.localizedDescription)")
            erreur = "Une erreur est survenue lors de la connexion."
        }

        chargement = false
    }

    // MARK: - Verrouillage progressif
    // 5 tentatives → 5 min, 10 tentatives → 15 min, 15+ tentatives → 1h

    func enregistrerEchec() {
        tentativesEchouees += 1

        let cycleActuel = tentativesEchouees / 5
        let reste = tentativesEchouees % 5

        if reste == 0 && cycleActuel >= 1 {
            let dureesVerrouillage: [TimeInterval] = [300, 900, 3600]
            let indexDuree = min(cycleActuel - 1, dureesVerrouillage.count - 1)
            let duree = dureesVerrouillage[indexDuree]

            verrouillageJusqua = Date().addingTimeInterval(duree)

            let minutes = Int(duree / 60)
            erreur = "Trop de tentatives. Compte verrouillé pendant \(minutes) minute(s)."
        }

        persisterEtatVerrouillage()
    }

    // MARK: - Création de compte (par le coach/admin)

    /// Mots de passe interdits (liste noire NIST 800-63B).
    /// Comprend les termes contextuels Playco, patterns clavier communs, et
    /// mots de passe par défaut historiques. La vérification utilisateur
    /// (contient prenom/nom/identifiant) est faite en plus à `creerCompte`.
    static let motsDePasseInterdits: Set<String> = [
        "motdepasse", "password", "passe1234", "volleyball", "volleyball123",
        "playco", "playco123", "garneau", "equipe", "coach", "admin",
        "123456789012", "azertyuiopqs", "qwertyuiopas", "aaaaaaaaaaaa",
        "000000000000", "111111111111"
    ]

    /// Valide un mot de passe selon la politique NIST 800-63B.
    /// Retourne `nil` si valide, sinon le message d'erreur spécifique.
    static func validerMotDePasse(_ motDePasse: String,
                                  identifiant: String,
                                  prenom: String,
                                  nom: String) -> String? {
        guard motDePasse.count >= 12 else {
            return "Le mot de passe doit contenir au moins 12 caractères."
        }
        let mdpBas = motDePasse.lowercased()
        // `contains` pour éviter le contournement trivial par suffixe
        // ("motdepasse123" serait accepté par une égalité stricte).
        for interdit in motsDePasseInterdits where mdpBas.contains(interdit) {
            return "Ce mot de passe est trop commun. Choisissez-en un autre."
        }
        // Refuser si contient identifiant, prénom ou nom (≥ 3 car, insensible casse)
        let interditsContextuels = [identifiant, prenom, nom]
            .map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
            .filter { $0.count >= 3 }
        for terme in interditsContextuels where mdpBas.contains(terme) {
            return "Le mot de passe ne peut pas contenir votre identifiant, prénom ou nom."
        }
        return nil
    }

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

        if let erreurMdp = Self.validerMotDePasse(motDePasse,
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
        KeychainService.supprimer(cle: cleSession)
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
