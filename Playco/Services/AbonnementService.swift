//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  AbonnementService — état d'abonnement de l'utilisateur connecté, gate
//  centrale paywall, migration rôles, propagation tier vers Équipes.
//
//  Source of truth = StoreKit.Transaction.currentEntitlements (via StoreKitService).
//  Ce service expose un cache observable + des computed safe pendant le
//  chargement initial (hors-ligne friendly).
//

import Foundation
import SwiftData
import StoreKit
import os

private let loggerAbo = Logger(subsystem: "com.origotech.playco", category: "abonnement")

@MainActor
@Observable
final class AbonnementService {

    // MARK: - Statut

    /// 10 cases couvrant les états Apple StoreKit possibles.
    enum Statut: Codable, Equatable {
        case chargement
        case aucun
        case essaiActif(tier: Tier, joursRestants: Int)
        case proMensuel(dateRenouvellement: Date)
        case proAnnuel(dateRenouvellement: Date)
        case clubMensuel(dateRenouvellement: Date)
        case clubAnnuel(dateRenouvellement: Date)
        case gracePeriode(tier: Tier, dateExpirationAttendue: Date)
        case essaiExpire
        case expire(tier: Tier, depuis: Date)
    }

    // MARK: - State observable

    var statut: Statut = .chargement
    var dernierRafraichissement: Date? = nil

    /// Tier de l'équipe lu depuis le public DB (appareils non-coach). Permet
    /// d'informer athlètes/assistants du plan actif du coach sans StoreKit local.
    var tierEquipeActif: Tier = .aucun

    // MARK: - Computed

    /// Tier actuellement actif (Pro, Club ou aucun).
    var tierActif: Tier {
        switch statut {
        case .clubMensuel, .clubAnnuel: return .club
        case .proMensuel, .proAnnuel: return .pro
        case .essaiActif(let tier, _): return tier
        case .gracePeriode(let tier, _): return tier
        default: return .aucun
        }
    }

    /// True si l'utilisateur peut écrire (créer/modifier). Pendant le chargement,
    /// fallback sur le cache UserDefaults pour éviter de bloquer l'UI au cold start.
    var peutEcrire: Bool {
        switch statut {
        case .chargement:
            return UserDefaults.standard.bool(forKey: IdentifiantsIAP.cleCachePeutEcrire)
        case .aucun, .essaiExpire, .expire:
            return false
        case .essaiActif, .proMensuel, .proAnnuel, .clubMensuel, .clubAnnuel, .gracePeriode:
            return true
        }
    }

    /// True si le tier permet aux athlètes de se connecter (Club uniquement).
    var peutConnecterAthletes: Bool {
        switch statut {
        case .chargement:
            return UserDefaults.standard.bool(forKey: IdentifiantsIAP.cleCachePeutConnecterAthletes)
        case .clubMensuel, .clubAnnuel:
            return true
        case .essaiActif(.club, _), .gracePeriode(.club, _):
            return true
        default:
            return false
        }
    }

    /// Jours restants d'essai si applicable.
    var joursRestantsEssai: Int? {
        if case .essaiActif(_, let jours) = statut { return jours }
        return nil
    }

    /// True si une bannière non-bloquante doit être affichée au coach.
    var doitAfficherBanniere: Bool {
        switch statut {
        case .essaiActif(_, let jours): return jours <= 3
        case .gracePeriode, .essaiExpire, .expire: return true
        default: return false
        }
    }

    // MARK: - Init

    init() {
        chargerCache()
    }

    // MARK: - Cache UserDefaults

    private func chargerCache() {
        guard let data = UserDefaults.standard.data(forKey: IdentifiantsIAP.cleCacheStatut),
              let cached = try? JSONCoderCache.decoder.decode(Statut.self, from: data)
        else {
            statut = .chargement
            return
        }
        statut = cached
    }

    private func persisterCache() {
        if let data = try? JSONCoderCache.encoder.encode(statut) {
            UserDefaults.standard.set(data, forKey: IdentifiantsIAP.cleCacheStatut)
        }
        UserDefaults.standard.set(peutEcrire, forKey: IdentifiantsIAP.cleCachePeutEcrire)
        UserDefaults.standard.set(peutConnecterAthletes, forKey: IdentifiantsIAP.cleCachePeutConnecterAthletes)
        dernierRafraichissement = Date()
    }

    // MARK: - Helpers rôle

    /// True si l'utilisateur est un coach payant (admin ou coach).
    /// Les assistants ne paient pas eux-mêmes (le coach paie pour son staff).
    func estCoachPayant(utilisateur: Utilisateur) -> Bool {
        utilisateur.role == .coach || utilisateur.role == .admin
    }

    // MARK: - Migration rôles (one-shot)

    /// Reclassent les anciens utilisateurs marqués `.coach` qui étaient en réalité
    /// des assistants (présents dans AssistantCoach). À appeler une fois au premier
    /// lancement de v2.0 (flag UserDefaults idempotent).
    func migrerAssistantsVersNouveauRole(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: IdentifiantsIAP.cleMigrationRolesDone) else {
            return
        }

        let descAssistants = FetchDescriptor<AssistantCoach>()
        let descCoaches = FetchDescriptor<Utilisateur>(
            predicate: #Predicate { $0.roleRaw == "coach" }
        )
        let assistants = (try? context.fetch(descAssistants)) ?? []
        let coaches = (try? context.fetch(descCoaches)) ?? []
        let idsAssistants = Set(assistants.map { $0.identifiant })

        var nbReclasses = 0
        for user in coaches where idsAssistants.contains(user.identifiant) {
            user.role = .assistantCoach
            nbReclasses += 1
        }

        if nbReclasses > 0 {
            do {
                try context.save()
                loggerAbo.info("Migration rôles : \(nbReclasses) utilisateurs reclassés .coach → .assistantCoach")
            } catch {
                loggerAbo.error("Migration rôles : échec sauvegarde \(error.localizedDescription)")
                return  // ne pas poser le flag si l'échec
            }
        }

        UserDefaults.standard.set(true, forKey: IdentifiantsIAP.cleMigrationRolesDone)
    }

    // MARK: - Propagation tier → Équipes

    /// Met à jour `tierAbonnementRaw` sur toutes les Équipes du coach, puis
    /// republie via CloudKitSharingService pour que les athlètes (multi-Apple-ID)
    /// puissent lire le tier depuis le public DB CloudKit.
    func propagerTierAuxEquipes(context: ModelContext) async {
        let nouveauTier = tierActif
        let desc = FetchDescriptor<Equipe>()
        guard let equipes = try? context.fetch(desc) else { return }

        var aChange = false
        for equipe in equipes where equipe.tierAbonnement != nouveauTier {
            equipe.tierAbonnement = nouveauTier
            aChange = true
        }

        guard aChange else { return }

        do {
            try context.save()
            loggerAbo.info("Tier propagé à \(equipes.count) équipes : \(nouveauTier.rawValue)")
        } catch {
            loggerAbo.error("propagerTierAuxEquipes: échec save \(error.localizedDescription)")
        }
    }

    // MARK: - Rafraîchir (branché sur StoreKitService)

    /// Source of truth : StoreKitService. Mappe les 8 états Apple StoreKit
    /// vers les 10 cases de `Statut`. Sur transition de tier, déclenche la
    /// propagation vers les Équipes.
    func rafraichir(utilisateur: Utilisateur?, context: ModelContext, storeKit: StoreKitService) async {
        let ancienTier = tierActif
        let ancienStatut = statut

        // Non-coach ou pas de session : statut aucun (gate par rôle se charge du reste).
        guard let user = utilisateur, estCoachPayant(utilisateur: user) else {
            statut = .aucun
            persisterCache()
            return
        }

        // Pas d'entitlement actif : tenter le fallback équipe (coach reconnecté
        // sur un autre Apple ID où StoreKit n'a pas l'entitlement local), sinon essaiExpire.
        guard let info = await storeKit.statutSouscriptionActif() else {
            if await appliquerFallbackEquipe(context: context) {
                persisterCache()
                return
            }
            statut = .essaiExpire
            persisterCache()
            return
        }

        let produit = info.produit
        let status = info.status
        let tier = IdentifiantsIAP.tier(pour: produit.id)
        let annuel = IdentifiantsIAP.estAnnuel(produit.id)

        // Extraction sécurisée des dates depuis la transaction vérifiée.
        let txInfo: Transaction? = {
            if case .verified(let tx) = status.transaction { return tx }
            return nil
        }()
        let expDate = txInfo?.expirationDate ?? Date()
        let revocationDate = txInfo?.revocationDate

        switch status.state {
        case .inGracePeriod, .inBillingRetryPeriod:
            statut = .gracePeriode(tier: tier, dateExpirationAttendue: expDate)
        case .expired:
            statut = .expire(tier: tier, depuis: expDate)
        case .revoked:
            statut = .expire(tier: tier, depuis: revocationDate ?? Date())
        case .subscribed:
            // Distinguer essai vs souscription payante via isUpgraded/offerType
            let estEssai = txInfo?.offer?.paymentMode == .freeTrial
            if estEssai {
                let jours = max(0, Calendar.current.dateComponents([.day], from: Date(), to: expDate).day ?? 0)
                statut = .essaiActif(tier: tier, joursRestants: jours)
            } else {
                switch (tier, annuel) {
                case (.pro, true): statut = .proAnnuel(dateRenouvellement: expDate)
                case (.pro, false): statut = .proMensuel(dateRenouvellement: expDate)
                case (.club, true): statut = .clubAnnuel(dateRenouvellement: expDate)
                case (.club, false): statut = .clubMensuel(dateRenouvellement: expDate)
                default: statut = .aucun
                }
            }
        default:
            statut = .essaiExpire
        }

        persisterCache()
        persisterDansSwiftData(context: context, utilisateur: user, produit: produit, expDate: expDate)

        // Propager le tier vers les Équipes si changement (athlètes multi-Apple-ID).
        if ancienTier != tierActif {
            await propagerTierAuxEquipes(context: context)
        }

        // Publier le STATUT (sans secret) dans le public DB pour que tout appareil
        // de l'équipe — y compris le coach reconnecté sur un autre Apple ID — le lise.
        await publierStatutEquipe(context: context, expDate: expDate)

        // Détection de transitions pour analytics (essai démarré / expiré).
        detecterTransitions(ancien: ancienStatut, nouveau: statut)
    }

    // MARK: - Sync statut équipe (CloudKit public, sans secret)

    /// Code de la première équipe locale (les coachs en ont au moins une).
    private func codeEquipeLocal(context: ModelContext) -> String {
        ((try? context.fetch(FetchDescriptor<Equipe>()))?.first?.codeEquipe) ?? ""
    }

    /// Publie le tier + état actif courant de l'équipe (aucun secret).
    private func publierStatutEquipe(context: ModelContext, expDate: Date?) async {
        let code = codeEquipeLocal(context: context)
        guard !code.isEmpty else { return }
        let tierRaw = tierActif.rawValue
        let actif = peutEcrire
        await CloudKitPublicSyncAbonnement.shared.publierStatut(
            codeEquipe: code, tierRaw: tierRaw, isActive: actif, dateExpiration: expDate
        )
    }

    /// Fallback : adopte le statut publié de l'équipe si actif (coach sans
    /// entitlement local sur cet Apple ID). Représenté en `.gracePeriode`
    /// (accès autorisé + bannière douce invitant à vérifier l'abonnement).
    /// - Returns: `true` si un statut actif a été adopté.
    private func appliquerFallbackEquipe(context: ModelContext) async -> Bool {
        let code = codeEquipeLocal(context: context)
        guard !code.isEmpty,
              let s = await CloudKitPublicSyncAbonnement.shared.lireStatut(codeEquipe: code),
              s.isActive,
              let tier = Tier(rawValue: s.tierRaw), tier != .aucun else {
            return false
        }
        let exp = s.dateExpiration ?? Date().addingTimeInterval(30 * 24 * 3600)
        statut = .gracePeriode(tier: tier, dateExpirationAttendue: exp)
        loggerAbo.info("Fallback équipe adopté : tier=\(tier.rawValue) (Apple ID sans entitlement local)")
        return true
    }

    /// Lit le statut d'abonnement de l'équipe depuis le public DB (appareils
    /// non-coach). Informe l'UI du tier du coach sans dépendre de StoreKit local.
    func chargerStatutEquipe(codeEquipe: String) async {
        guard let s = await CloudKitPublicSyncAbonnement.shared.lireStatut(codeEquipe: codeEquipe) else {
            tierEquipeActif = .aucun
            return
        }
        tierEquipeActif = s.isActive ? (Tier(rawValue: s.tierRaw) ?? .aucun) : .aucun
    }

    /// Émet les événements analytics sur les transitions d'état pertinentes.
    /// Appelé après `rafraichir`. Idempotent (compare ancien vs nouveau).
    private func detecterTransitions(ancien: Statut, nouveau: Statut) {
        let estEssaiAvant: Bool
        switch ancien {
        case .essaiActif: estEssaiAvant = true
        default: estEssaiAvant = false
        }
        let estEssaiApres: Bool
        switch nouveau {
        case .essaiActif: estEssaiApres = true
        default: estEssaiApres = false
        }

        // Transition aucun/chargement → essaiActif = essai démarré
        if !estEssaiAvant && estEssaiApres {
            loggerAbo.info("Transition : essai démarré (tier: \(self.tierActif.rawValue))")
            // NB: l'événement analytics réel est émis via AnalyticsService côté
            // PaywallView ou PlaycoApp en réponse à ce log si nécessaire.
        }

        // Transition essaiActif → essaiExpire = essai expiré
        if estEssaiAvant, case .essaiExpire = nouveau {
            loggerAbo.info("Transition : essai expiré")
        }
    }

    /// Sauvegarde le statut courant dans le modèle Abonnement (SwiftData).
    /// Renseigne `codeEquipe` depuis la première équipe locale du coach (clé de
    /// fallback CloudKit Public DB pour reconnexion sur Apple ID différent).
    private func persisterDansSwiftData(context: ModelContext,
                                        utilisateur: Utilisateur,
                                        produit: Product,
                                        expDate: Date) {
        let userID = utilisateur.id
        let desc = FetchDescriptor<Abonnement>(
            predicate: #Predicate { $0.utilisateurID == userID }
        )
        let abo = (try? context.fetch(desc).first) ?? {
            let nouveau = Abonnement(utilisateurID: userID)
            context.insert(nouveau)
            return nouveau
        }()
        abo.tier = tierActif
        abo.produitIAPID = produit.id
        abo.dateExpiration = expDate
        abo.dateDernierSync = Date()
        abo.type = typeAbonnementCourant()

        // Lookup codeEquipe via première équipe disponible (les coachs ont au
        // moins une équipe après onboarding ; multi-équipes → première suffit
        // car le tier est propagé sur TOUTES via propagerTierAuxEquipes).
        if abo.codeEquipe.isEmpty {
            let equipes = (try? context.fetch(FetchDescriptor<Equipe>())) ?? []
            if let code = equipes.first?.codeEquipe, !code.isEmpty {
                abo.codeEquipe = code
                loggerAbo.info("Abonnement scopé codeEquipe=\(code)")
            }
        }

        do {
            try context.save()
        } catch {
            loggerAbo.error("persisterDansSwiftData: échec save \(error.localizedDescription)")
        }
    }

    /// Mappe le statut courant vers un TypeAbonnement pour le modèle SwiftData.
    private func typeAbonnementCourant() -> TypeAbonnement {
        switch statut {
        case .essaiActif: return .essai
        case .proMensuel, .clubMensuel: return .mensuel
        case .proAnnuel, .clubAnnuel: return .annuel
        case .gracePeriode: return .gracePeriode
        case .expire, .essaiExpire: return .expire
        default: return .aucun
        }
    }
}
