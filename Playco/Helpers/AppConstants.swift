//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  AppConstants — constantes globales de l'application.
//
//  ⚠️ AVANT LANCEMENT APP STORE — vérifier que TOUTES les valeurs marquées
//  `PLACEHOLDER_LAUNCH` ont été remplacées par les URLs/emails finaux.
//  Recherche : `grep -rn "PLACEHOLDER_LAUNCH" Playco/`

import Foundation

enum AppConstants {

    // MARK: - URLs légales (hébergées sur le site Origotech)

    /// Conditions d'utilisation (CGU). PLACEHOLDER_LAUNCH : à remplacer par l'URL finale.
    static let urlConditionsUtilisation = URL(string: "https://origotech.ca/playco/cgu")!

    /// Politique de confidentialité. PLACEHOLDER_LAUNCH : à remplacer par l'URL finale.
    static let urlPolitiqueConfidentialite = URL(string: "https://origotech.ca/playco/confidentialite")!

    // MARK: - Support

    /// Email de support utilisateur. PLACEHOLDER_LAUNCH : confirmer l'adresse finale.
    static let emailSupport = "support@origotech.ca"

    /// URL `mailto:` formatée avec sujet pré-rempli pour le support général.
    static var mailtoSupport: URL {
        let sujet = "Aide%20Playco".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Aide"
        return URL(string: "mailto:\(emailSupport)?subject=\(sujet)")!
    }

    /// URL `mailto:` pour signaler une erreur de démarrage critique.
    static var mailtoSupportErreurDemarrage: URL {
        URL(string: "mailto:\(emailSupport)?subject=Erreur%20d%C3%A9marrage%20Playco")!
    }
}
