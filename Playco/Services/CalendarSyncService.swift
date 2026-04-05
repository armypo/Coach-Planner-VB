//  Playco
//  Copyright (c) 2025 Christopher Dionne. Tous droits reserves.
//

import EventKit
import SwiftUI

/// Service de synchronisation avec le calendrier Apple
@Observable
final class CalendarSyncService {
    private let store = EKEventStore()
    var estAutorise: Bool = false
    var erreur: String?

    func demanderAcces() async {
        do {
            let granted = try await store.requestFullAccessToEvents()
            await MainActor.run { estAutorise = granted }
        } catch {
            await MainActor.run { self.erreur = error.localizedDescription }
        }
    }

    /// Ajoute une séance au calendrier Apple
    func ajouterAuCalendrier(nom: String, date: Date, dureeMinutes: Int, lieu: String = "", notes: String = "") async -> Bool {
        if !estAutorise {
            await demanderAcces()
        }
        guard estAutorise else { return false }

        let event = EKEvent(eventStore: store)
        event.title = nom
        event.startDate = date
        event.endDate = Calendar.current.date(byAdding: .minute, value: max(dureeMinutes, 60), to: date)
        event.calendar = store.defaultCalendarForNewEvents
        if !lieu.isEmpty { event.location = lieu }
        if !notes.isEmpty { event.notes = notes }

        // Alerte 30 min avant
        event.addAlarm(EKAlarm(relativeOffset: -1800))

        do {
            try store.save(event, span: .thisEvent)
            return true
        } catch {
            await MainActor.run { self.erreur = error.localizedDescription }
            return false
        }
    }

    /// Vérifie si l'accès est déjà accordé
    func verifierAcces() {
        let status = EKEventStore.authorizationStatus(for: .event)
        estAutorise = (status == .fullAccess)
    }
}
