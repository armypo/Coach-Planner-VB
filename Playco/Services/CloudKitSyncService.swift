//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftUI
import CloudKit
import Network
import CoreData
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "CloudKitSync")

/// Boîte de stockage thread-safe pour le token d'observer NotificationCenter.
/// Marquée nonisolated pour permettre l'accès depuis le deinit nonisolé de CloudKitSyncService.
/// Déclarée hors de la classe car `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` appliquerait
/// sinon l'isolation main-actor à ce type de helper thread-safe.
final class BoiteObserveur: @unchecked Sendable {
    nonisolated(unsafe) var token: NSObjectProtocol?
    nonisolated init() {}
}

/// Service de suivi de la synchronisation CloudKit
/// Surveille le compte iCloud, la connectivité réseau et les événements de sync SwiftData/CloudKit
@MainActor
@Observable
final class CloudKitSyncService {

    // MARK: - État observable

    var statutSync: StatutSync = .inactif
    var dernierSync: Date?
    var erreurSync: String?
    var estHorsLigne: Bool = false
    var modificationsEnAttente: Int = 0
    var compteICloudDisponible: Bool = false
    var journalSync: [EvenementSync] = []
    var modeMatchActif: Bool = false

    /// Statuts possibles de la synchronisation
    enum StatutSync: Equatable {
        case inactif
        case enCours
        case synchronise
        case horsLigne
        case syncPausee
        case erreur(String)

        var nomAffichage: String {
            switch self {
            case .inactif: return "Inactif"
            case .enCours: return "Synchronisation..."
            case .synchronise: return "À jour"
            case .horsLigne: return "Hors ligne"
            case .syncPausee: return "Sync pausée"
            case .erreur(let msg): return "Erreur : \(msg)"
            }
        }

        var icone: String {
            switch self {
            case .inactif: return "icloud.slash"
            case .enCours: return "arrow.triangle.2.circlepath.icloud"
            case .synchronise: return "checkmark.icloud"
            case .horsLigne: return "icloud.slash"
            case .syncPausee: return "pause.icloud"
            case .erreur: return "exclamationmark.icloud"
            }
        }

        var couleur: Color {
            switch self {
            case .inactif: return .secondary
            case .enCours: return .blue
            case .synchronise: return .green
            case .horsLigne: return .orange
            case .syncPausee: return .yellow
            case .erreur: return .red
            }
        }
    }

    // MARK: - Privé

    nonisolated private let moniteurReseau = NWPathMonitor()
    nonisolated private let fileReseau = DispatchQueue(label: "com.origotech.playco.reseau")
    nonisolated private let boiteObserveur = BoiteObserveur()

    // MARK: - Démarrage

    /// Vérifie le compte iCloud et commence à observer les événements de sync
    func demarrerSuivi() {
        chargerJournal()
        verifierCompteICloud()
        observerEvenementsSyncCoreData()
        logger.info("CloudKit sync service démarré")
    }

    /// Active la surveillance réseau (connectivité Wi-Fi/cellulaire)
    func demarrerSurveillanceReseau() {
        moniteurReseau.pathUpdateHandler = { [weak self] chemin in
            DispatchQueue.main.async {
                guard let self else { return }
                let etaitHorsLigne = self.estHorsLigne
                self.estHorsLigne = (chemin.status != .satisfied)

                if self.estHorsLigne {
                    self.statutSync = .horsLigne
                    logger.info("Réseau indisponible — mode hors ligne")
                } else if etaitHorsLigne {
                    // Retour en ligne → re-vérifier iCloud
                    self.statutSync = .enCours
                    self.verifierCompteICloud()
                    logger.info("Réseau restauré — reprise sync")
                }
            }
        }
        moniteurReseau.start(queue: fileReseau)
        logger.info("Surveillance réseau activée")
    }

    // MARK: - Vérification compte iCloud

    /// Vérifie si l'utilisateur est connecté à iCloud
    private func verifierCompteICloud() {
        CKContainer.default().accountStatus { [weak self] statut, erreur in
            DispatchQueue.main.async {
                guard let self else { return }

                if let erreur {
                    logger.error("Erreur vérification iCloud: \(erreur.localizedDescription)")
                    self.erreurSync = erreur.localizedDescription
                    self.compteICloudDisponible = false
                    self.statutSync = .erreur("Compte iCloud inaccessible")
                    return
                }

                switch statut {
                case .available:
                    self.compteICloudDisponible = true
                    if !self.estHorsLigne {
                        self.statutSync = .synchronise
                    }
                    logger.info("Compte iCloud disponible")

                case .noAccount:
                    self.compteICloudDisponible = false
                    self.statutSync = .erreur("Aucun compte iCloud")
                    logger.warning("Aucun compte iCloud configuré")

                case .restricted:
                    self.compteICloudDisponible = false
                    self.statutSync = .erreur("iCloud restreint")
                    logger.warning("Compte iCloud restreint")

                case .couldNotDetermine:
                    self.compteICloudDisponible = false
                    self.statutSync = .inactif
                    logger.warning("Statut iCloud indéterminé")

                case .temporarilyUnavailable:
                    self.compteICloudDisponible = false
                    self.statutSync = .horsLigne
                    logger.warning("iCloud temporairement indisponible")

                @unknown default:
                    self.compteICloudDisponible = false
                    self.statutSync = .inactif
                    logger.warning("Statut iCloud inconnu")
                }
            }
        }
    }

    // MARK: - Observation des événements CoreData/CloudKit

    /// Observe les notifications de sync de NSPersistentCloudKitContainer
    /// SwiftData utilise CoreData en interne — ces notifications reflètent l'état réel de la sync
    private func observerEvenementsSyncCoreData() {
        boiteObserveur.token = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSPersistentCloudKitContainer.eventChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // `queue: .main` garantit qu'on est sur le main thread,
            // on peut donc affirmer l'isolation main-actor sans data race.
            MainActor.assumeIsolated {
                self?.traiterEvenementSync(notification)
            }
        }
    }

    /// Traite un événement de sync CoreData/CloudKit
    private func traiterEvenementSync(_ notification: Notification) {
        // NSPersistentCloudKitContainer.Event est une classe interne CoreData
        // On extrait les infos via le userInfo de la notification
        guard let userInfo = notification.userInfo else { return }

        // Si mode match actif, ignorer les exports mais logger
        if modeMatchActif {
            statutSync = .syncPausee
        }

        // Vérifier si l'événement contient une erreur
        if let erreur = userInfo["error"] as? NSError {
            logger.error("Erreur sync CloudKit: \(erreur.localizedDescription)")
            erreurSync = erreur.localizedDescription
            if !modeMatchActif {
                statutSync = .erreur(messageErreurSimplifiee(erreur))
            }
            ajouterAuJournal(type: .erreur, message: messageErreurSimplifiee(erreur), estErreur: true)
            return
        }

        // Vérifier le type d'événement
        if let typeRaw = userInfo["type"] as? Int {
            switch typeRaw {
            case 0: // setup
                if !modeMatchActif { statutSync = .enCours }
                ajouterAuJournal(type: .setup, message: "Initialisation du schéma CloudKit")
                logger.info("Sync CloudKit: initialisation du schéma")
            case 1: // import
                if !modeMatchActif { statutSync = .enCours }
                ajouterAuJournal(type: .importation, message: "Import de données depuis iCloud")
                logger.info("Sync CloudKit: import en cours")
            case 2: // export
                if !modeMatchActif { statutSync = .enCours }
                ajouterAuJournal(type: .exportation, message: "Export de données vers iCloud")
                logger.info("Sync CloudKit: export en cours")
            default:
                break
            }
        }

        // Vérifier si l'événement est terminé
        if let termine = userInfo["endDate"] as? Date {
            dernierSync = termine
            erreurSync = nil
            modificationsEnAttente = 0
            if !estHorsLigne && !modeMatchActif {
                statutSync = .synchronise
            }
            logger.info("Sync CloudKit terminée")
        }
    }

    /// Simplifie les messages d'erreur CloudKit pour l'utilisateur
    private func messageErreurSimplifiee(_ erreur: NSError) -> String {
        switch erreur.code {
        case CKError.networkUnavailable.rawValue,
             CKError.networkFailure.rawValue:
            return "Réseau indisponible"
        case CKError.quotaExceeded.rawValue:
            return "Stockage iCloud plein"
        case CKError.notAuthenticated.rawValue:
            return "Connexion iCloud requise"
        case CKError.serverResponseLost.rawValue:
            return "Serveur iCloud injoignable"
        default:
            return "Sync échouée"
        }
    }

    // MARK: - Actions manuelles

    /// Enregistre une modification locale en attente de sync
    func enregistrerModificationLocale() {
        modificationsEnAttente += 1
        if estHorsLigne || modeMatchActif {
            if modeMatchActif { statutSync = .syncPausee }
            else { statutSync = .horsLigne }
        }
    }

    /// Attend la fin de la sync CloudKit initiale (max 10 secondes)
    /// Retourne immédiatement si déjà synced, hors ligne ou iCloud indisponible
    /// Permet d'éviter les logouts fantômes au boot avant que CloudKit ait rapatrié l'Utilisateur
    func attendreSyncInitiale() async {
        if dernierSync != nil { return }
        if estHorsLigne || !compteICloudDisponible { return }

        let debut = Date()
        let timeoutSecondes: TimeInterval = 10

        while Date().timeIntervalSince(debut) < timeoutSecondes {
            if dernierSync != nil {
                let duree = Date().timeIntervalSince(debut)
                logger.info("Sync initiale terminée après \(String(format: "%.2f", duree))s")
                return
            }
            if estHorsLigne {
                logger.info("Passage hors ligne pendant l'attente de la sync initiale")
                return
            }
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
        }
        logger.warning("Timeout attente sync initiale après 10s — restauration session malgré tout")
    }

    /// Force une re-vérification du statut iCloud
    func rafraichirStatut() {
        if modeMatchActif {
            statutSync = .syncPausee
            return
        }
        statutSync = .enCours
        verifierCompteICloud()
    }

    // MARK: - Mode Match (pause sync)

    /// Active ou désactive le mode match (pause la sync pendant un match live)
    func activerModeMatch(_ actif: Bool) {
        modeMatchActif = actif
        if actif {
            statutSync = .syncPausee
            ajouterAuJournal(type: .pauseSync, message: "Sync pausée — mode match activé")
            logger.info("Mode match activé — sync pausée")
        } else {
            ajouterAuJournal(type: .repriseSync, message: "Sync reprise — mode match désactivé")
            logger.info("Mode match désactivé — reprise sync")
            rafraichirStatut()
        }
    }

    // MARK: - Journal de sync

    /// Ajoute un événement au journal de sync
    private func ajouterAuJournal(type: EvenementSync.TypeEvenementSync, message: String, estErreur: Bool = false) {
        let evenement = EvenementSync(type: type, message: message, estErreur: estErreur)
        journalSync.append(evenement)
        // Buffer circulaire : garder les 50 plus récents
        if journalSync.count > 50 {
            journalSync = Array(journalSync.suffix(50))
        }
        sauvegarderJournal()
    }

    /// Charge le journal depuis UserDefaults
    private func chargerJournal() {
        journalSync = JournalSyncStorage.charger()
    }

    /// Sauvegarde le journal dans UserDefaults
    private func sauvegarderJournal() {
        JournalSyncStorage.sauvegarder(journalSync)
    }

    /// Efface le journal de sync
    func effacerJournal() {
        journalSync.removeAll()
        JournalSyncStorage.effacer()
    }

    // MARK: - Formatage

    /// Temps écoulé depuis le dernier sync formaté
    var tempsDepuisDernierSync: String {
        guard let date = dernierSync else { return "Synchronisation automatique" }
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Il y a quelques secondes" }
        if interval < 3600 { return "Il y a \(Int(interval / 60)) min" }
        if interval < 86400 { return "Il y a \(Int(interval / 3600))h" }
        return date.formatCourt()
    }

    // MARK: - Nettoyage

    deinit {
        // moniteurReseau et boiteObserveur sont nonisolated,
        // donc accessibles depuis ce deinit nonisolé.
        moniteurReseau.cancel()
        if let observeur = boiteObserveur.token {
            NotificationCenter.default.removeObserver(observeur)
        }
        // Note : pas de logger.info ici — logger est main-actor isolé et deinit est nonisolated.
    }
}

// MARK: - Vue indicateur de synchronisation

/// Indicateur compact de statut sync — à placer dans la DockBar ou toolbar
struct SyncIndicateurView: View {
    let syncService: CloudKitSyncService
    @State private var afficherDetail = false

    var body: some View {
        Button {
            afficherDetail = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: syncService.statutSync.icone)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(syncService.statutSync.couleur)
                    .symbolRenderingMode(.hierarchical)
                    .symbolEffect(.pulse, options: .repeating,
                                  isActive: syncService.statutSync == .enCours)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(syncService.statutSync.couleur.opacity(0.3), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $afficherDetail) {
            detailSync
                .frame(width: 300)
                .presentationCompactAdaptation(.popover)
        }
    }

    private var detailSync: some View {
        VStack(alignment: .leading, spacing: 16) {
            // En-tête statut
            HStack(spacing: 10) {
                Image(systemName: syncService.statutSync.icone)
                    .font(.title2)
                    .foregroundStyle(syncService.statutSync.couleur)
                VStack(alignment: .leading, spacing: 2) {
                    Text(syncService.statutSync.nomAffichage)
                        .font(.headline)
                    Text(syncService.tempsDepuisDernierSync)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            // Détails
            VStack(alignment: .leading, spacing: 8) {
                lignDetail(
                    icone: "person.icloud",
                    texte: syncService.compteICloudDisponible ? "Compte iCloud connecté" : "Compte iCloud non disponible",
                    couleur: syncService.compteICloudDisponible ? .green : .orange
                )

                lignDetail(
                    icone: "wifi",
                    texte: syncService.estHorsLigne ? "Hors ligne" : "En ligne",
                    couleur: syncService.estHorsLigne ? .orange : .green
                )

                if syncService.modificationsEnAttente > 0 {
                    lignDetail(
                        icone: "arrow.up.circle",
                        texte: "\(syncService.modificationsEnAttente) modification(s) en attente",
                        couleur: .blue
                    )
                }
            }

            if let erreur = syncService.erreurSync {
                Divider()
                Label(erreur, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Divider()

            // Bouton rafraîchir
            Button {
                syncService.rafraichirStatut()
            } label: {
                Label("Vérifier la connexion", systemImage: "arrow.clockwise")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(syncService.statutSync == .enCours)
        }
        .padding(16)
    }

    private func lignDetail(icone: String, texte: String, couleur: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icone)
                .font(.caption)
                .foregroundStyle(couleur)
                .frame(width: 16)
            Text(texte)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
