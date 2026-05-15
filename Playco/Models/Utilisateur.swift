//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Rôle utilisateur

enum RoleUtilisateur: String, Codable, CaseIterable {
    case etudiant
    case coach              // coach admin payant
    case assistantCoach     // mêmes permissions que coach, gratuit
    case admin

    var label: String {
        switch self {
        case .etudiant: return "Élève"
        case .coach: return "Coach"
        case .assistantCoach: return "Coach assistant"
        case .admin: return "Admin"
        }
    }

    var icone: String {
        switch self {
        case .etudiant: return "graduationcap.fill"
        case .coach: return "figure.volleyball"
        case .assistantCoach: return "person.badge.shield.checkmark"
        case .admin: return "shield.checkered"
        }
    }

    var couleurHex: String {
        switch self {
        case .etudiant: return "#FF6B35"
        case .coach: return "#2563EB"
        case .assistantCoach: return "#4A8AF4"
        case .admin: return "#10B981"
        }
    }

    var couleur: Color {
        Color(hex: couleurHex)
    }
}

// MARK: - Modèle Utilisateur

@Model
final class Utilisateur {
    var id: UUID = UUID()
    var codeEcole: String = ""
    var dateModification: Date = Date()
    var identifiant: String = ""
    var motDePasseHash: String = ""
    var prenom: String = ""
    var nom: String = ""
    var roleRaw: String = RoleUtilisateur.etudiant.rawValue
    var dateCreation: Date = Date()
    var estActif: Bool = true
    @Attribute(.externalStorage) var photoData: Data? = nil

    // Compatibilité migration SwiftData
    var email: String = ""

    // S1 : Sel pour hashage sécurisé
    var sel: String? = nil

    /// Nombre d'itérations PBKDF2 utilisées pour dériver `motDePasseHash`.
    /// `1` = chemin legacy SHA256 (compatibilité avec comptes pré-v1.10).
    /// `>= 600_000` = PBKDF2-HMAC-SHA256 conforme OWASP 2024.
    var iterations: Int = 1

    /// Date du dernier début de session — utilisée pour l'expiration 30 jours
    var sessionCreeeLe: Date? = nil

    /// Code unique d'invitation (6 caractères alphanumériques)
    var codeInvitation: String = ""

    // Données physiques
    var tailleCm: Int = 0          // cm
    var poidKg: Double = 0         // kg
    var allongeBras: Int = 0       // cm (envergure)
    var hauteurSaut: Int = 0       // cm (détente verticale)
    var dateNaissance: Date? = nil
    var posteRaw: String = ""      // PosteJoueur.rawValue (pour élèves)
    var numero: Int = 0            // numéro de maillot

    // Statistiques (modifiables par le coach)
    var matchsJoues: Int = 0
    var setsJoues: Int = 0

    // Attaque
    var attaquesReussies: Int = 0
    var erreursAttaque: Int = 0
    var attaquesTotales: Int = 0

    // Service
    var aces: Int = 0
    var erreursService: Int = 0
    var servicesTotaux: Int = 0

    // Bloc
    var blocsSeuls: Int = 0
    var blocsAssistes: Int = 0
    var erreursBloc: Int = 0

    // Réception
    var receptionsReussies: Int = 0
    var erreursReception: Int = 0
    var receptionsTotales: Int = 0

    // Jeu
    var passesDecisives: Int = 0
    var manchettes: Int = 0

    // Anciens champs (migration SwiftData)
    var pointsMarques: Int = 0
    var blocsMarques: Int = 0
    var services: Int = 0
    var erreurs: Int = 0

    // Lien vers JoueurEquipe
    var joueurEquipeID: UUID? = nil

    var role: RoleUtilisateur {
        get { RoleUtilisateur(rawValue: roleRaw) ?? .etudiant }
        set { roleRaw = newValue.rawValue }
    }

    var nomComplet: String {
        "\(prenom) \(nom)"
    }

    var poste: PosteJoueur? {
        get { PosteJoueur(rawValue: posteRaw) }
        set { posteRaw = newValue?.rawValue ?? "" }
    }

    var age: Int? {
        guard let dateNaissance else { return nil }
        return Calendar.current.dateComponents([.year], from: dateNaissance, to: Date()).year
    }

    /// Pourcentage d'attaque (Hitting %) = (Kills - Erreurs) / Tentatives
    var pourcentageAttaque: Double {
        guard attaquesTotales > 0 else { return 0 }
        return Double(attaquesReussies - erreursAttaque) / Double(attaquesTotales)
    }

    /// Rétrocompatibilité
    var efficaciteAttaque: Double {
        guard attaquesTotales > 0 else { return 0 }
        return Double(attaquesReussies) / Double(attaquesTotales) * 100
    }

    var efficaciteReception: Double {
        guard receptionsTotales > 0 else { return 0 }
        return Double(receptionsReussies - erreursReception) / Double(receptionsTotales) * 100
    }

    var blocsTotaux: Double {
        Double(blocsSeuls) + Double(blocsAssistes) * 0.5
    }

    var pointsCalcules: Int {
        attaquesReussies + aces + blocsSeuls + Int(round(Double(blocsAssistes) * 0.5))
    }

    init(identifiant: String, motDePasseHash: String, prenom: String, nom: String, role: RoleUtilisateur, codeEcole: String = "") {
        self.id = UUID()
        self.codeEcole = codeEcole
        self.identifiant = identifiant
        self.email = identifiant
        self.motDePasseHash = motDePasseHash
        self.prenom = prenom
        self.nom = nom
        self.roleRaw = role.rawValue
        self.dateCreation = Date()
        self.estActif = true
        self.codeInvitation = Utilisateur.genererCodeInvitation()
    }

    /// Génère un code d'invitation unique de 6 caractères (lettres majuscules + chiffres)
    static func genererCodeInvitation() -> String {
        let caracteres = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // sans I/O/1/0 pour éviter confusion
        return String((0..<6).compactMap { _ in caracteres.randomElement() })
    }

    /// Vérifie qu'un code est unique dans le contexte donné
    static func codeEstUnique(_ code: String, context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<Utilisateur>(
            predicate: #Predicate { $0.codeInvitation == code }
        )
        return (try? context.fetchCount(descriptor)) == 0
    }

    /// Génère un code garanti unique
    static func genererCodeUniqueInvitation(context: ModelContext) -> String {
        var code = genererCodeInvitation()
        var tentatives = 0
        while !codeEstUnique(code, context: context) && tentatives < 100 {
            code = genererCodeInvitation()
            tentatives += 1
        }
        return code
    }

    /// Génère un identifiant unique : `prenom.nom.XXXX` (sans accents, minuscules,
    /// suffixe aléatoire 4 chiffres). Garantit l'unicité face à la BD + un Set
    /// d'identifiants déjà réservés en mémoire (utilisé pendant le wizard pour
    /// éviter les collisions inter-joueurs du même lot).
    /// - Parameter exclusions: identifiants déjà réservés en mémoire mais pas
    ///   encore persistés en BD.
    static func genererIdentifiantUnique(
        prenom: String,
        nom: String,
        context: ModelContext,
        exclusions: Set<String> = []
    ) -> String {
        let base = "\(prenom).\(nom)"
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0 == "." || $0 == "-" }

        // Si base vide ou réduite au seul séparateur → fallback "user.XXXX"
        guard !base.isEmpty, base != "." else {
            return "user." + String(format: "%04d", Int.random(in: 0...9999))
        }

        for _ in 0..<1000 {
            let suffixe = String(format: "%04d", Int.random(in: 0...9999))
            let candidat = "\(base).\(suffixe)"
            if !exclusions.contains(candidat) && identifiantDisponible(candidat, context: context) {
                return candidat
            }
        }

        // Fallback ultime : UUID tronqué (extrêmement improbable d'arriver ici)
        return base + "." + String(UUID().uuidString.prefix(4)).lowercased()
    }

    /// Génère un mot de passe athlète/assistant au format `LLLLL_DD` :
    /// 5 lettres safe (sans I/L/O) + underscore + 2 chiffres safe (sans 0/1).
    /// Évite les caractères ambigus visuellement pour faciliter la communication
    /// du mot de passe à l'utilisateur.
    static func genererMotDePasseAthlete() -> String {
        let lettres = "ABCDEFGHJKMNPQRSTUVWXYZ"  // sans I, L, O
        let chiffres = "23456789"                 // sans 0, 1
        let partieLettres = String((0..<5).compactMap { _ in lettres.randomElement() })
        let partieChiffres = String((0..<2).compactMap { _ in chiffres.randomElement() })
        return "\(partieLettres)_\(partieChiffres)"
    }

    /// Vérifie si un identifiant est disponible
    static func identifiantDisponible(_ identifiant: String, context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<Utilisateur>(
            predicate: #Predicate { $0.identifiant == identifiant }
        )
        return (try? context.fetchCount(descriptor)) == 0
    }
}
