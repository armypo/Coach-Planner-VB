//  Playco
//  Copyright (c) 2025 Christopher Dionne. Tous droits reserves.
//

import Foundation
import SwiftData
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

    // MARK: - Dérivation de clé (délégué à KeyDerivation)

    /// Alias statique pour compat : la valeur canonique vit dans KeyDerivation.
    static var iterationsParDefaut: Int { KeyDerivation.iterationsParDefaut }

    /// Wrapper délégant à `KeyDerivation.genererSel()`.
    /// Maintenu en API publique pour compat avec les 7 call sites (ConfigurationView,
    /// NouveauJoueurView, ModifierUtilisateurView, JoueurDetailView, etc.).
    func genererSel() -> String {
        KeyDerivation.genererSel()
    }

    /// Wrapper délégant à `KeyDerivation.hashPBKDF2(_:sel:)`.
    /// Maintenu en API publique non-throwing pour compat avec les call sites.
    /// En cas d'échec crypto (extrêmement improbable — défaillance CommonCrypto OS),
    /// log `.critical` et retourne `""`. Un compte avec hash vide ne peut pas être
    /// authentifié (egaliteConstante garantit longueur ≠ → false).
    func hashMotDePasse(_ motDePasse: String, sel: String) -> String {
        do {
            return try KeyDerivation.hashPBKDF2(motDePasse, sel: sel)
        } catch {
            Self.logger.critical("hashMotDePasse échoué — défaillance crypto système: \(error.localizedDescription)")
            return ""
        }
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

            guard KeyDerivation.verifier(motDePasse,
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

    // MARK: - Connexion par Sign in with Apple

    /// Résultat d'une tentative de connexion via Sign in with Apple.
    enum EtatConnexionApple {
        /// Compte trouvé et connecté.
        case connecte
        /// Aucun compte lié à cet `appleUserID` — l'UI doit router vers
        /// lier-ancien-compte, rejoindre-une-équipe ou onboarding coach.
        case compteInconnu(appleUserID: String, prenom: String, nom: String)
    }

    /// Connecte l'utilisateur dont `appleUserID` correspond, sinon signale un
    /// compte inconnu (l'authentification a déjà été faite par Apple — aucun
    /// mot de passe n'est vérifié ici).
    /// - Parameters:
    ///   - appleUserID: `ASAuthorizationAppleIDCredential.user` (clé durable).
    ///   - prenom/nom: fournis par Apple au 1er login uniquement (sinon vides).
    func connexionApple(appleUserID: String, prenom: String, nom: String, context: ModelContext) -> EtatConnexionApple {
        erreur = nil
        let id = appleUserID.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty else {
            return .compteInconnu(appleUserID: appleUserID, prenom: prenom, nom: nom)
        }

        let descripteur = FetchDescriptor<Utilisateur>(
            predicate: #Predicate { $0.appleUserID == id && $0.estActif == true }
        )

        guard let utilisateur = try? context.fetch(descripteur).first else {
            return .compteInconnu(appleUserID: id, prenom: prenom, nom: nom)
        }

        utilisateur.sessionCreeeLe = Date()
        do {
            try context.save()
        } catch {
            Self.logger.warning("connexionApple: impossible d'amorcer la session: \(error.localizedDescription)")
        }

        utilisateurConnecte = utilisateur
        session.sauvegarder(utilisateurID: utilisateur.id)
        return .connecte
    }

    // MARK: - Rattachement d'un compte existant à Sign in with Apple

    /// Lie un compte legacy (identifiant + mot de passe) à un `appleUserID`, puis
    /// EFFACE les secrets stockés (le compte n'utilisera plus que SIWA).
    /// - Returns: `nil` si succès (utilisateur connecté), sinon message d'erreur.
    ///
    /// Vérifie le verrouillage et l'ancien mot de passe (constant-time) avant de
    /// rattacher. Supprime aussi les `CredentialAthlete` (mdp en clair) liés.
    func lierCompteExistant(appleUserID: String, identifiant: String, motDePasse: String, context: ModelContext) -> String? {
        erreur = nil
        if estVerrouille {
            return "Compte verrouillé. Réessayez dans \(tempsRestantVerrouillage) secondes."
        }

        let id = appleUserID.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty else { return "Identifiant Apple manquant. Réessaie la connexion Apple." }

        let idNormalise = identifiant.lowercased().trimmingCharacters(in: .whitespaces)
        let descripteur = FetchDescriptor<Utilisateur>(
            predicate: #Predicate { $0.identifiant == idNormalise && $0.estActif == true }
        )

        guard let utilisateur = try? context.fetch(descripteur).first,
              KeyDerivation.verifier(motDePasse,
                                     hash: utilisateur.motDePasseHash,
                                     sel: utilisateur.sel,
                                     iterations: utilisateur.iterations) else {
            enregistrerEchec()
            return "Identifiant ou mot de passe incorrect."
        }

        lockout.reinitialiser()

        // Unicité : refuser si cet Apple ID est déjà lié à un AUTRE compte actif
        // (évite qu'une même identité Apple soit rattachée à plusieurs comptes).
        let utilisateurID = utilisateur.id
        let descAppleID = FetchDescriptor<Utilisateur>(
            predicate: #Predicate { $0.appleUserID == id && $0.estActif == true && $0.id != utilisateurID }
        )
        if (try? context.fetch(descAppleID).first) != nil {
            return "Cet identifiant Apple est déjà lié à un autre compte."
        }

        // Rattacher l'identité Apple et effacer définitivement les secrets.
        utilisateur.appleUserID = id
        utilisateur.motDePasseHash = ""
        utilisateur.sel = nil
        utilisateur.iterations = 1
        utilisateur.sessionCreeeLe = Date()

        // Purger les mots de passe en clair éventuels (CredentialAthlete).
        let userID = utilisateur.id
        let credDescripteur = FetchDescriptor<CredentialAthlete>(
            predicate: #Predicate { $0.utilisateurID == userID }
        )
        if let creds = try? context.fetch(credDescripteur) {
            for cred in creds { context.delete(cred) }
        }

        do {
            try context.save()
        } catch {
            Self.logger.error("lierCompteExistant: échec sauvegarde: \(error.localizedDescription)")
            return "Impossible de lier le compte. Réessaie."
        }

        utilisateurConnecte = utilisateur
        session.sauvegarder(utilisateurID: utilisateur.id)
        return nil
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
            Self.logger.error("creerCompte: échec sauvegarde SwiftData: \(error.localizedDescription)")
            return "Erreur lors de la création du compte. Veuillez réessayer."
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
