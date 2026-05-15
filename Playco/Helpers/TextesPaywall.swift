//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  TextesPaywall — toutes les chaînes UI du paywall, centralisées (FR).
//

import Foundation

enum TextesPaywall {

    // MARK: - Titres

    static let titreWelcome = "Bienvenue dans Playco · 14 jours offerts"
    static let titreBloquant = "Abonne-toi pour continuer à créer"
    static let titreGestion = "Mon abonnement"

    static let sousTitreWelcome = "Choisis le plan qui correspond à ta façon de coacher"
    static let sousTitreBloquant = "Ton essai est terminé. Active un plan pour continuer à créer du contenu."
    static let sousTitreTierPro = "L'outil complet pour toi et ton staff"
    static let sousTitreTierClub = "Playco Pro + accès app pour tes athlètes"

    // MARK: - Tiers

    static let tierPro = "Playco Pro"
    static let tierClub = "Playco Club"

    static let featuresPro: [String] = [
        "Stats live point-par-point",
        "Export PDF & CSV",
        "Analytics saison complets"
    ]

    static let featuresClub: [String] = [
        "Tout Pro + accès athlètes",
        "Messagerie coach-athlète",
        "Profils athlètes personnalisés"
    ]

    // MARK: - CTA

    static let ctaEssaiEligible = "Commencer l'essai 14 jours"
    /// Préfixe — concaténer avec `produit.displayPrice` (ex: "S'abonner · 14,99 $ CAD")
    static let ctaAchatDirect = "S'abonner · "
    static let ctaRestaurer = "Restaurer mes achats"
    static let ctaGererApple = "Gérer mon abonnement Apple"
    static let ctaPasserClub = "Passer à Playco Club"

    // MARK: - Badges

    static let badge14JoursOfferts = "14 jours offerts"
    static let badgeAnnuelEconomie = "-17 %"
    static let badgeEssaiActif = "Essai actif"
    static let badgeGracePeriode = "Renouvellement en cours"

    // MARK: - Périodes

    static let periodeMensuel = "Mensuel"
    static let periodeAnnuel = "Annuel"

    // MARK: - Mentions légales (obligatoires App Store)

    static let mentionAutoRenouvellement = """
    L'abonnement se renouvelle automatiquement sauf annulation au moins 24h avant la fin de la période en cours. \
    Gère ton abonnement et désactive le renouvellement automatique dans Réglages → ton Apple ID → Abonnements.
    """

    static let mentionPaiement = "Paiement débité sur ton compte Apple à la confirmation."

    // MARK: - Bannières (selon statut)

    static func banniereEssaiJoursRestants(_ jours: Int) -> String {
        if jours <= 1 {
            return "Essai expire demain · Active ton plan pour continuer"
        }
        if jours <= 3 {
            return "Essai expire dans \(jours) jours · Active ton plan"
        }
        return "Essai · \(jours) jours restants"
    }

    static let banniereGracePeriode = "Problème de paiement détecté · Vérifie ta méthode de paiement"
    static let banniereExpire = "Abonnement expiré · Active un plan pour retrouver toutes les fonctionnalités"

    // MARK: - Messages d'erreur gate

    static let erreurAthleteBloque = "Ton coach doit activer Playco Club pour que tu puisses te connecter. Demande-lui de passer au plan Club dans Paramètres → Mon abonnement."

    static let erreurAssistantBloque = "Ton coach doit renouveler son abonnement Playco pour que tu puisses te connecter."

    // MARK: - Toasts

    static let toastEssaiDemarre = "Ton essai a commencé · 14 jours offerts"
    static let toastAbonnementActif = "Abonnement activé"
    static let toastPasReussiPlusTard = "Tu peux t'abonner plus tard · Mode lecture seule"
    static let toastRestauration = "Restauration en cours…"
    static let toastRestaurationReussie = "Achats restaurés"
    static let toastRestaurationVide = "Aucun achat à restaurer"
}
