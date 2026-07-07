//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//

import Foundation
import os
#if canImport(TelemetryDeck)
import TelemetryDeck
#endif

// MARK: - Mode analytics
//
// 2.2.b — TelemetryDeck branché (décision fondateur 2026-07-06 : première
// dépendance SPM du projet). Le SDK ne s'active que si la clé Info.plist
// `TelemetryDeckAppID` est renseignée (action humaine : créer l'app sur
// dashboard.telemetrydeck.com et reporter l'ID) ET hors build DEMO — sinon
// le service reste en mode logger-only (Console.app, filtre
// `subsystem == "com.origotech.playco"`), aucune donnée n'est envoyée.
// TelemetryDeck : privacy-first (pas d'IDFA, données agrégées côté serveur),
// compatible Loi 25 / RGPD / PIPEDA — le filtrage PII local reste actif en
// défense en profondeur.

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

    private var estInitialise = false
    /// Vrai quand le SDK TelemetryDeck est actif (appID présent, hors DEMO).
    private(set) var sdkActif = false

    /// Clé Info.plist portant l'App ID TelemetryDeck ("" = logger-only).
    static let cleAppID = "TelemetryDeckAppID"

    // MARK: - Initialisation

    /// Initialise le service d'analytics au démarrage de l'app.
    /// Appeler une seule fois depuis PlaycoApp.swift init().
    /// Mode logger-only : pour brancher un backend, initialiser le SDK ici.
    func initialiser() {
        guard !estInitialise else { return }
        estInitialise = true
        #if DEMO
        logger.info("AnalyticsService initialisé (DEMO — logger-only, aucun envoi)")
        #else
        let appID = (Bundle.main.object(forInfoDictionaryKey: Self.cleAppID) as? String) ?? ""
        if appID.isEmpty {
            logger.info("AnalyticsService initialisé (logger-only — TelemetryDeckAppID absent)")
        } else {
            #if canImport(TelemetryDeck)
            TelemetryDeck.initialize(config: .init(appID: appID))
            sdkActif = true
            logger.info("AnalyticsService initialisé (TelemetryDeck actif)")
            #else
            logger.warning("TelemetryDeckAppID présent mais SDK non lié — logger-only")
            #endif
        }
        #endif
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
        // Revue 2.2.b : init paresseuse — les événements émis avant
        // initialiser() (wizard d'onboarding) ne sont plus perdus.
        if !estInitialise { initialiser() }

        let metadonneesFiltrees = filtrerDonneesPersonnelles(metadonnees)

        let metaStr = metadonneesFiltrees.isEmpty ? "" : " \(metadonneesFiltrees)"
        logger.info("Analytics: \(evenement)\(metaStr, privacy: .public)")

        #if canImport(TelemetryDeck)
        if sdkActif {
            TelemetryDeck.signal(evenement, parameters: metadonneesFiltrees)
        }
        #endif
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
