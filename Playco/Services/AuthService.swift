//  Playco
//  Copyright (c) 2025 Christopher Dionne. Tous droits reserves.
//

import Foundation
import SwiftData
import CryptoKit

@Observable
final class AuthService {

    var utilisateurConnecte: Utilisateur?
    var estConnecte: Bool { utilisateurConnecte != nil }
    var erreur: String?
    var chargement: Bool = false

    // S2 : Verrouillage après 5 tentatives
    private(set) var tentativesEchouees: Int = 0
    private(set) var verrouillageJusqua: Date?

    var estVerrouille: Bool {
        guard let jusqua = verrouillageJusqua else { return false }
        return Date() < jusqua
    }

    var tempsRestantVerrouillage: Int {
        guard let jusqua = verrouillageJusqua else { return 0 }
        return max(0, Int(jusqua.timeIntervalSince(Date())))
    }

    // MARK: - Persistance de session

    private let cleSession = "utilisateurConnecteID"

    var idSessionSauvegardee: String? {
        UserDefaults.standard.string(forKey: cleSession)
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

    /// Hash sans sel (rétrocompatibilité pour anciens comptes)
    func hashMotDePasse(_ motDePasse: String) -> String {
        let donnees = Data(motDePasse.utf8)
        let hash = SHA256.hash(data: donnees)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Vérifie le mot de passe (avec ou sans sel)
    private func verifierMotDePasse(_ motDePasse: String, hash: String, sel: String?) -> Bool {
        if let sel, !sel.isEmpty {
            return hashMotDePasse(motDePasse, sel: sel) == hash
        } else {
            // Rétrocompatibilité : hash sans sel
            return hashMotDePasse(motDePasse) == hash
        }
    }

    // MARK: - Restauration de session

    func restaurerSession(context: ModelContext) {
        guard let idString = idSessionSauvegardee,
              let id = UUID(uuidString: idString) else { return }

        let descripteur = FetchDescriptor<Utilisateur>(
            predicate: #Predicate { $0.id == id && $0.estActif == true }
        )

        if let utilisateur = try? context.fetch(descripteur).first {
            utilisateurConnecte = utilisateur
        } else {
            UserDefaults.standard.removeObject(forKey: cleSession)
        }
    }

    // MARK: - Connexion par Identifiant + Mot de passe

    func connexion(identifiant: String, motDePasse: String, context: ModelContext) {
        erreur = nil
        chargement = true

        // S2 : Vérifier le verrouillage
        if estVerrouille {
            erreur = "Compte verrouillé. Réessayez dans \(tempsRestantVerrouillage) secondes."
            chargement = false
            return
        }

        #if DEBUG
        // TODO: Retirer avant production — Compte admin passe-partout pour tests
        if identifiant.lowercased().trimmingCharacters(in: .whitespaces) == "admin@playco.dev" && motDePasse == "PlaycoAdmin2026!" {
            let adminID = "admin@playco.dev"
            let descripteurAdmin = FetchDescriptor<Utilisateur>(
                predicate: #Predicate { $0.identifiant == adminID }
            )
            if let adminExistant = try? context.fetch(descripteurAdmin).first {
                utilisateurConnecte = adminExistant
                UserDefaults.standard.set(adminExistant.id.uuidString, forKey: cleSession)
            } else {
                let sel = genererSel()
                let hash = hashMotDePasse(motDePasse, sel: sel)
                let admin = Utilisateur(
                    identifiant: adminID,
                    motDePasseHash: hash,
                    prenom: "Admin",
                    nom: "Playco",
                    role: .admin,
                    codeEcole: ""
                )
                admin.sel = sel
                context.insert(admin)
                try? context.save()
                utilisateurConnecte = admin
                UserDefaults.standard.set(admin.id.uuidString, forKey: cleSession)
            }
            chargement = false
            return
        }
        #endif

        let idNormalise = identifiant.lowercased().trimmingCharacters(in: .whitespaces)

        // Cherche par identifiant uniquement
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

            // Vérifier le mot de passe (avec ou sans sel)
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
            if utilisateur.sel == nil || utilisateur.sel?.isEmpty == true {
                let nouveauSel = genererSel()
                utilisateur.sel = nouveauSel
                utilisateur.motDePasseHash = hashMotDePasse(motDePasse, sel: nouveauSel)
                try? context.save()
            }

            utilisateurConnecte = utilisateur
            UserDefaults.standard.set(utilisateur.id.uuidString, forKey: cleSession)
        } catch {
            erreur = "Erreur lors de la connexion : \(error.localizedDescription)"
        }

        chargement = false
    }

    // S2 : Enregistrer un échec de connexion
    func enregistrerEchec() {
        tentativesEchouees += 1
        if tentativesEchouees >= 5 {
            verrouillageJusqua = Date().addingTimeInterval(300) // 5 minutes
            erreur = "Trop de tentatives. Compte verrouillé pendant 5 minutes."
        }
    }

    // MARK: - Création de compte (par le coach/admin)

    func creerCompte(identifiant: String, motDePasse: String, prenom: String, nom: String, role: RoleUtilisateur, context: ModelContext) -> String? {
        let idNormalise = identifiant.lowercased().trimmingCharacters(in: .whitespaces)

        guard !idNormalise.isEmpty, idNormalise.count >= 3 else {
            return "L'identifiant doit contenir au moins 3 caractères."
        }

        guard motDePasse.count >= 6 else {
            return "Le mot de passe doit contenir au moins 6 caractères."
        }

        guard !prenom.trimmingCharacters(in: .whitespaces).isEmpty,
              !nom.trimmingCharacters(in: .whitespaces).isEmpty else {
            return "Veuillez remplir le prénom et le nom."
        }

        // Vérifier si l'identifiant existe déjà
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
        UserDefaults.standard.removeObject(forKey: cleSession)
    }

}
