//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation

/// Chaînes FR centralisées pour toutes les vues paywall, bannières, alertes
/// et messages d'erreur liés à l'abonnement. Règle : aucune string en dur
/// dans les vues — passer systématiquement par `TextesPaywall`.
enum TextesPaywall {

    // MARK: - Titres généraux

    static let titreWelcome  = "Bienvenue dans Playco · 14 jours offerts"
    static let titreBloquant = "Abonne-toi pour continuer à créer"
    static let titreGestion  = "Mon abonnement Playco"

    static let sousTitreWelcome = "Choisis le plan qui correspond à ta façon de coacher."

    // MARK: - Tier Pro

    static let nomPro      = "Playco Pro"
    static let sousTitrePro = "L'outil complet pour toi et ton staff"
    static let featuresPro  = [
        "Stats live point-par-point",
        "Export PDF & CSV",
        "Analytics saison + heatmap"
    ]

    // MARK: - Tier Club

    static let nomClub      = "Playco Club"
    static let sousTitreClub = "Playco Pro + accès app pour tes athlètes"
    static let featuresClub  = [
        "Tout Playco Pro inclus",
        "Connexion athlètes à l'app",
        "Messagerie coach-athlète + MonProfil"
    ]

    // MARK: - CTA

    static let ctaEssaiEligible = "Commencer l'essai 14 jours"
    /// Préfixe à concaténer avec `Product.displayPrice` quand l'essai n'est plus éligible.
    static let ctaAchatDirect   = "S'abonner · "
    static let ctaRestaurer     = "Restaurer mes achats"
    static let ctaGererApple    = "Gérer mon abonnement Apple"
    static let ctaVoirPlans     = "Voir les plans"
    static let ctaPasserClub    = "Passer à Club"

    // MARK: - Badges

    static let badge14JoursOfferts = "14 jours offerts"
    static let badgeAnnuelEconomie = "-17 %"
    static let badgeActuel         = "Plan actuel"

    // MARK: - Statuts

    static let statutEssaiActif     = "Essai gratuit"
    static let statutProMensuel     = "Pro mensuel"
    static let statutProAnnuel      = "Pro annuel"
    static let statutClubMensuel    = "Club mensuel"
    static let statutClubAnnuel     = "Club annuel"
    static let statutGracePeriode   = "Paiement en attente"
    static let statutEssaiExpire    = "Essai expiré"
    static let statutExpire         = "Abonnement expiré"

    // MARK: - Bannières

    static func banniereJoursRestants(_ jours: Int) -> String {
        switch jours {
        case 0:  return "Ton essai se termine aujourd'hui."
        case 1:  return "Il te reste 1 jour d'essai."
        default: return "Il te reste \(jours) jours d'essai."
        }
    }

    static let banniereEssaiExpire   = "Ton essai est terminé. Abonne-toi pour continuer à créer du contenu."
    static let banniereGracePeriode  = "Problème de paiement. Mets à jour ta méthode Apple avant l'expiration."
    static let banniereExpire        = "Abonnement expiré. Lecture seule jusqu'à la réactivation."

    // MARK: - Erreurs gate (login bloqué)

    static let erreurAthleteBloque   = "Ton coach doit activer Playco Club pour que tu puisses te connecter. Demande-lui de passer au plan Club dans Paramètres → Mon abonnement."
    static let erreurAssistantBloque = "Ton coach doit renouveler son abonnement Playco pour que tu puisses te connecter."

    // MARK: - Erreurs achat

    static let erreurAchatEchoue    = "L'achat n'a pas pu être complété. Réessaie dans un instant."
    static let erreurAchatNonVerif  = "Transaction non vérifiée par Apple. Contacte le support si ça persiste."
    static let erreurAchatEnAttente = "Paiement en attente d'approbation (ex: Ask to Buy). Tu recevras une notification Apple une fois approuvé."
    static let erreurRestauration   = "Aucun abonnement à restaurer sur cet Apple ID."

    // MARK: - Mention légale auto-renouvellement (obligatoire App Store)

    static let mentionAutoRenouvellement = """
    L'abonnement se renouvelle automatiquement tant que tu ne l'annules pas \
    au moins 24 h avant la fin de la période. Le paiement est prélevé sur ton \
    compte Apple à la confirmation d'achat. Tu peux gérer ton abonnement et \
    désactiver le renouvellement dans Réglages → Apple ID → Abonnements.
    """

    // MARK: - Toasts post-achat

    static func toastEssaiDemarre(tier: Tier) -> String {
        switch tier {
        case .pro:   return "Ton essai Playco Pro a commencé · 14 jours offerts"
        case .club:  return "Ton essai Playco Club a commencé · 14 jours offerts"
        case .aucun: return "Essai démarré"
        }
    }

    static func toastAchatReussi(tier: Tier) -> String {
        switch tier {
        case .pro:   return "Abonnement Playco Pro activé"
        case .club:  return "Abonnement Playco Club activé"
        case .aucun: return "Abonnement activé"
        }
    }

    static let toastCancelApple = "Tu peux t'abonner plus tard · Mode lecture seule pour l'instant"
}
