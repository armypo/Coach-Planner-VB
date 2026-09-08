//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  2.2.a — State Restoration du match live.
//  Marqueur UserDefaults posé à l'entrée du mode live et effacé à la sortie
//  propre : s'il survit au relancement de l'app (kill, crash, batterie),
//  MatchsView resélectionne le match et MatchDetailView propose la reprise.
//  Les DONNÉES sont déjà sûres (PointMatch + SetScore persistés à chaque
//  point) — ce marqueur ne restaure que la navigation.

import Foundation

enum MatchLiveRestauration {

    static let cleSeanceID = "matchLiveEnCours.seanceID"
    static let cleDate = "matchLiveEnCours.date"

    /// Un match de volleyball ne dure pas 6 heures : au-delà, le marqueur est
    /// périmé (on ne propose pas de « reprendre » un match d'il y a trois jours).
    static let dureeValiditeSecondes: TimeInterval = 6 * 3600

    /// Pose le marqueur à l'entrée du mode live.
    static func marquer(seanceID: UUID, defaults: UserDefaults = .standard) {
        defaults.set(seanceID.uuidString, forKey: cleSeanceID)
        defaults.set(Date().timeIntervalSinceReferenceDate, forKey: cleDate)
    }

    /// Efface le marqueur (sortie propre du live, finalisation, ou refus de reprise).
    static func effacer(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: cleSeanceID)
        defaults.removeObject(forKey: cleDate)
    }

    /// L'identifiant de la séance dont le live était en cours, ou `nil` si aucun
    /// marqueur valide. Un marqueur périmé est effacé au passage.
    static func seanceEnCours(defaults: UserDefaults = .standard, maintenant: Date = Date()) -> UUID? {
        guard let brut = defaults.string(forKey: cleSeanceID),
              let id = UUID(uuidString: brut) else { return nil }

        let pose = Date(timeIntervalSinceReferenceDate: defaults.double(forKey: cleDate))
        guard maintenant.timeIntervalSince(pose) < dureeValiditeSecondes else {
            effacer(defaults: defaults)
            return nil
        }
        return id
    }

    /// Vrai si le marqueur valide désigne cette séance.
    static func correspond(a seanceID: UUID, defaults: UserDefaults = .standard, maintenant: Date = Date()) -> Bool {
        seanceEnCours(defaults: defaults, maintenant: maintenant) == seanceID
    }
}
