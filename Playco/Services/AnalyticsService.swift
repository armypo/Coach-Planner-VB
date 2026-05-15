//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//

import Foundation
import os

// MARK: - TelemetryDeck integration
//
// Pour activer TelemetryDeck en production :
// 1. Xcode → File → Add Package Dependencies → https://github.com/TelemetryDeck/SwiftSDK
//    Rule : Up to Next Major Version (à partir de la version courante)
// 2. Créer un compte sur https://telemetrydeck.com → obtenir l'App ID
// 3. Remplacer `placeholderAppID` ci-dessous par la vraie valeur
// 4. Décommenter les lignes `import TelemetryDeck` et `TelemetryDeck.signal(...)`
//
// Tant que la librairie n'est pas ajoutée, ce service fonctionne en mode
// "logger-only" : les événements sont écrits dans le système de log unifié Apple
// (Console.app, filtre `subsystem == "com.origotech.playco"`) mais rien n'est
// envoyé au serveur TelemetryDeck.
//
// import TelemetryDeck

private let logger = Logger(subsystem: "com.origotech.playco", category: "Analytics")

/// Service d'analytics privacy-first pour Playco
///
/// **Principes de confidentialité :**
/// - Aucune donnée personnelle (identifiant, nom, prénom, mot de passe) n'est jamais capturée
/// - Aucun code équipe n'est envoyé (pourrait identifier un établissement)
/// - Les métadonnées sont agrégées (ex: nombre de joueurs, durée, pas les contenus)
/// - Conforme Loi 25 Québec / RGPD / PIPEDA
@Observable
@MainActor
final class AnalyticsService {

    /// App ID TelemetryDeck — à remplacer par la vraie valeur lors de l'ajout du package
    /// Référencé dans le commentaire d'initialisation ci-dessous
    private let _placeholderAppID = "REMPLACER-PAR-APP-ID-TELEMETRYDECK"

    private var estInitialise = false

    // MARK: - Initialisation

    /// Initialise TelemetryDeck au démarrage de l'app
    /// Appeler une seule fois depuis PlaycoApp.swift init()
    func initialiser() {
        guard !estInitialise else { return }

        // TelemetryDeck non activé pour cette version — mode logger-only.
        // Pour activer : ajouter le package TelemetryDeck SDK, configurer l'App ID,
        // puis décommenter les deux lignes ci-dessous.
        // let config = TelemetryDeck.Config(appID: _placeholderAppID)
        // TelemetryDeck.initialize(config: config)
        _ = _placeholderAppID // évite l'avertissement "unused" avant l'ajout du package

        estInitialise = true
        logger.info("AnalyticsService initialisé (mode logger-only)")
    }

    // MARK: - Suivi d'événements

    /// Envoie un événement d'analyse au serveur TelemetryDeck
    /// - Parameters:
    ///   - evenement: clé de l'événement en snake_case (ex: "equipe_creee")
    ///   - metadonnees: dictionnaire de métadonnées non-personnelles (ex: ["nb_joueurs": "12"])
    ///
    /// **Règles de confidentialité à respecter :**
    /// - Jamais d'identifiant, nom, prénom, mot de passe, code équipe
    /// - Jamais d'email, numéro de téléphone
    /// - Valeurs agrégées OK (compteurs, durées, catégories)
    func suivre(evenement: String, metadonnees: [String: String] = [:]) {
        guard estInitialise else {
            logger.warning("Événement ignoré avant init: \(evenement)")
            return
        }

        let metadonneesFiltrees = filtrerDonneesPersonnelles(metadonnees)

        // TelemetryDeck non activé — voir initialiser() ci-dessus.
        // TelemetryDeck.signal(evenement, parameters: metadonneesFiltrees)

        let metaStr = metadonneesFiltrees.isEmpty ? "" : " \(metadonneesFiltrees)"
        logger.info("Analytics: \(evenement)\(metaStr, privacy: .public)")
    }

    // MARK: - Filtrage PII

    /// Noms de clés interdits (données personnelles potentielles)
    private static let clesInterdites: Set<String> = [
        "identifiant", "nom", "prenom", "prénom", "motdepasse", "motDePasse",
        "password", "email", "courriel", "telephone", "téléphone", "phone",
        "codeEquipe", "code_equipe", "code", "sel", "salt", "hash"
    ]

    /// Filtre les métadonnées pour retirer toute donnée personnelle potentielle
    /// Défense en profondeur : même si un appelant oublie, rien de sensible ne sort
    private func filtrerDonneesPersonnelles(_ metadonnees: [String: String]) -> [String: String] {
        metadonnees.filter { cle, _ in
            let cleBasse = cle.lowercased()
            return !AnalyticsService.clesInterdites.contains(where: { cleBasse.contains($0.lowercased()) })
        }
    }
}

// MARK: - Événements clés

/// Catalogue des événements trackés dans Playco
/// Utiliser ces constantes plutôt que des strings littérales pour éviter les typos
enum EvenementAnalytics {
    static let appLancee = "app_launched"
    static let utilisateurConnecte = "utilisateur_connecte"
    static let equipeCreee = "equipe_creee"
    static let seanceCreee = "seance_creee"
    static let matchCree = "match_cree"
    static let matchLiveDemarre = "match_live_demarre"
    static let exerciceCree = "exercice_cree"
    static let erreurCritique = "erreur_critique"
    static let configurationCompletee = "configuration_completee"
    static let exportPDFGenere = "export_pdf_genere"

    // Paywall v2.0 (8 événements)
    static let paywallAffiche     = "paywall_affiche"
    static let paywallFerme       = "paywall_ferme"
    static let essaiDemarre       = "essai_demarre"
    static let essaiExpire        = "essai_expire"
    static let achatInitie        = "achat_initie"
    static let achatReussi        = "achat_reussi"
    static let achatEchoue        = "achat_echoue"
    static let restaurationTentee = "restauration_tentee"
}
