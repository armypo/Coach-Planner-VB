//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

// MARK: - Poste du joueur
enum PosteJoueur: String, Codable, CaseIterable {
    case passeur    = "Passeur"
    case central    = "Central"
    case recepteur  = "Réceptionneur"
    case oppose     = "Opposé"
    case libero     = "Libéro"

    var abreviation: String {
        switch self {
        case .passeur:    return "P"
        case .central:    return "C"
        case .recepteur:  return "R"
        case .oppose:     return "O"
        case .libero:     return "L"
        }
    }

    var icone: String {
        switch self {
        case .passeur:    return "p.circle.fill"
        case .central:    return "c.circle.fill"
        case .recepteur:  return "r.circle.fill"
        case .oppose:     return "o.circle.fill"
        case .libero:     return "l.circle.fill"
        }
    }

    var couleur: Color {
        switch self {
        case .passeur:    return .yellow
        case .central:    return .red
        case .recepteur:  return Color(hex: "#FF6B35")
        case .oppose:     return Color(hex: "#2563EB")
        case .libero:     return .green
        }
    }
}

// MARK: - Modèle joueur
@Model
final class JoueurEquipe {
    var id: UUID = UUID()
    var nom: String = ""
    var prenom: String = ""
    var numero: Int = 0
    var posteRaw: String = PosteJoueur.recepteur.rawValue  // PosteJoueur.rawValue
    var dateNaissance: Date? = nil
    var taille: Int = 0       // cm
    var notes: String = ""
    @Attribute(.externalStorage) var photoData: Data? = nil
    var estActif: Bool = true
    var dateCreation: Date = Date()

    /// Code équipe — filtre multi-équipe
    var codeEquipe: String = ""
    var dateModification: Date = Date()

    /// Lien vers le compte Utilisateur (athlète) — nil = joueur non-connecté (importé)
    var utilisateurID: UUID? = nil

    /// Relation vers l'équipe (inverse de Equipe.joueurs)
    var equipe: Equipe? = nil

    /// Identifiants pour connexion athlète (onboarding)
    var identifiant: String = ""
    var motDePasseHash: String = ""
    var sel: String = ""

    // MARK: - Statistiques générales
    var matchsJoues: Int = 0
    var setsJoues: Int = 0

    // MARK: - Attaque (Attack)
    /// Kills — attaques qui marquent directement un point
    var attaquesReussies: Int = 0
    /// Erreurs d'attaque — dans le filet, hors limites, contrées
    var erreursAttaque: Int = 0
    /// Tentatives d'attaque totales
    var attaquesTotales: Int = 0

    // MARK: - Service (Serve)
    /// Aces — services gagnants directs
    var aces: Int = 0
    /// Erreurs de service — filet, hors limites, pied
    var erreursService: Int = 0
    /// Tentatives de service totales
    var servicesTotaux: Int = 0

    // MARK: - Bloc (Block)
    /// Blocs seuls — un joueur bloque seul pour un point
    var blocsSeuls: Int = 0
    /// Blocs assistés — 2-3 joueurs bloquent ensemble pour un point
    var blocsAssistes: Int = 0
    /// Erreurs de bloc — touche filet, faute ligne centrale
    var erreursBloc: Int = 0

    // MARK: - Réception (Serve Receive)
    /// Réceptions réussies (passées jouables)
    var receptionsReussies: Int = 0
    /// Erreurs de réception — acé, mauvaise passe non jouable
    var erreursReception: Int = 0
    /// Tentatives de réception totales
    var receptionsTotales: Int = 0

    // MARK: - Jeu (Setting & Defense)
    /// Passes décisives (assists) — passe suivie d'un kill
    var passesDecisives: Int = 0
    /// Manchettes (digs) — défense sur attaque adverse gardée en jeu
    var manchettes: Int = 0

    // MARK: - Anciens champs (migration SwiftData — gardés avec defaults)
    var pointsMarques: Int = 0
    var blocsMarques: Int = 0
    var services: Int = 0
    var erreurs: Int = 0

    // MARK: - Computed — Poste
    var poste: PosteJoueur {
        get { PosteJoueur(rawValue: posteRaw) ?? .recepteur }
        set { posteRaw = newValue.rawValue }
    }

    var nomComplet: String { "\(prenom) \(nom)" }

    // MARK: - Computed — Attaque

    /// Pourcentage d'attaque (Hitting %) = (Kills - Erreurs) / Tentatives
    /// La statistique offensive la plus importante en volleyball
    var pourcentageAttaque: Double {
        guard attaquesTotales > 0 else { return 0 }
        return Double(attaquesReussies - erreursAttaque) / Double(attaquesTotales)
    }

    /// Kills par set
    var killsParSet: Double {
        guard setsJoues > 0 else { return 0 }
        return Double(attaquesReussies) / Double(setsJoues)
    }

    // MARK: - Computed — Service

    /// Aces par set
    var acesParSet: Double {
        guard setsJoues > 0 else { return 0 }
        return Double(aces) / Double(setsJoues)
    }

    // MARK: - Computed — Bloc

    /// Total blocs (formule équipe : seuls + assistés/2, formule individuelle : seuls + assistés)
    var blocsTotaux: Double {
        Double(blocsSeuls) + Double(blocsAssistes) * 0.5
    }

    /// Blocs par set
    var blocsParSet: Double {
        guard setsJoues > 0 else { return 0 }
        return blocsTotaux / Double(setsJoues)
    }

    // MARK: - Computed — Réception

    /// Efficacité réception = (Réussies - Erreurs) / Totales × 100
    var efficaciteReception: Double {
        guard receptionsTotales > 0 else { return 0 }
        return Double(receptionsReussies - erreursReception) / Double(receptionsTotales) * 100
    }

    /// Pourcentage réception positive = Réussies / Totales × 100
    var pourcentageReceptionPositive: Double {
        guard receptionsTotales > 0 else { return 0 }
        return Double(receptionsReussies) / Double(receptionsTotales) * 100
    }

    // MARK: - Computed — Jeu

    /// Passes décisives par set
    var passesParSet: Double {
        guard setsJoues > 0 else { return 0 }
        return Double(passesDecisives) / Double(setsJoues)
    }

    /// Manchettes par set
    var manchettesParSet: Double {
        guard setsJoues > 0 else { return 0 }
        return Double(manchettes) / Double(setsJoues)
    }

    // MARK: - Computed — Points

    /// Points totaux calculés = Kills + Aces + Blocs (seuls + 0.5 × assistés)
    var pointsCalcules: Int {
        attaquesReussies + aces + blocsSeuls + Int(round(Double(blocsAssistes) * 0.5))
    }

    /// Points par set
    var pointsParSet: Double {
        guard setsJoues > 0 else { return 0 }
        return Double(pointsCalcules) / Double(setsJoues)
    }

    /// Points perdus = erreurs attaque + erreurs service + erreurs bloc + erreurs réception
    var pointsPerdus: Int {
        erreursAttaque + erreursService + erreursBloc + erreursReception
    }

    // MARK: - Rétrocompatibilité

    /// Ancien efficaciteAttaque (pourcentage simple réussies/totales × 100)
    var efficaciteAttaque: Double {
        guard attaquesTotales > 0 else { return 0 }
        return Double(attaquesReussies) / Double(attaquesTotales) * 100
    }

    // MARK: - Validation

    /// Validation métier
    var estValide: Bool {
        !nom.trimmingCharacters(in: .whitespaces).isEmpty &&
        !prenom.trimmingCharacters(in: .whitespaces).isEmpty &&
        numero >= 0 && taille >= 0 &&
        attaquesReussies <= attaquesTotales &&
        receptionsReussies <= receptionsTotales &&
        erreursAttaque <= attaquesTotales &&
        erreursReception <= receptionsTotales
    }

    init(nom: String, prenom: String, numero: Int, poste: PosteJoueur) {
        self.id = UUID()
        self.nom = nom
        self.prenom = prenom
        self.numero = max(0, numero)
        self.posteRaw = poste.rawValue
        self.dateCreation = Date()
    }
}
