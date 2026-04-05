//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

struct CalendrierView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Query(filter: #Predicate<Seance> { $0.estArchivee == false },
           sort: \Seance.date) private var toutesSeancesQuery: [Seance]

    private var toutesSeances: [Seance] {
        toutesSeancesQuery.filtreEquipe(codeEquipeActif)
    }

    @Query(sort: \PhaseSaison.dateDebut) private var toutesPhases: [PhaseSaison]

    private var phases: [PhaseSaison] {
        toutesPhases.filtreEquipe(codeEquipeActif)
    }

    @State private var moisAffiche = Date()
    @State private var jourSelectionne: Date?
    @State private var afficherNouvelleSeance = false
    @State private var calendarService = CalendarSyncService()
    @State private var syncEnCours = false
    @State private var syncResultat: String?

    private let calendar = Calendar.current
    private let joursAbrevies = ["Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim"]

    // Séances à venir (aujourd'hui inclus)
    private var seancesFutures: [Seance] {
        let debut = calendar.startOfDay(for: Date())
        return toutesSeances.filter { $0.date >= debut }.sorted { $0.date < $1.date }
    }

    // Séances pour un jour donné
    private func seancesPourJour(_ date: Date) -> [Seance] {
        let debut = calendar.startOfDay(for: date)
        guard let fin = calendar.date(byAdding: .day, value: 1, to: debut) else { return [] }
        return toutesSeances.filter { $0.date >= debut && $0.date < fin }
    }

    // Dates qui ont des séances dans le mois affiché (P0-01 — DateFormatter caché)
    private var dateAvecSeance: Set<String> {
        let debut = premierJourDuMois
        guard let fin = calendar.date(byAdding: .month, value: 1, to: debut) else { return [] }
        return Set(toutesSeances
            .filter { $0.date >= debut && $0.date < fin }
            .map { $0.date.formatYMD() })
    }

    private var premierJourDuMois: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: moisAffiche)) ?? moisAffiche
    }

    private var titreMois: String {
        moisAffiche.formatMoisAnnee()
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Calendrier mensuel
            VStack(spacing: 12) {
                // Navigation mois
                HStack {
                    Button {
                        if let m = calendar.date(byAdding: .month, value: -1, to: moisAffiche) {
                            withAnimation { moisAffiche = m }
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .frame(width: 36, height: 36)
                    }

                    Spacer()
                    Text(titreMois)
                        .font(.headline)
                    Spacer()

                    Button {
                        if let m = calendar.date(byAdding: .month, value: 1, to: moisAffiche) {
                            withAnimation { moisAffiche = m }
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.body.weight(.semibold))
                            .frame(width: 36, height: 36)
                    }
                }
                .padding(.horizontal, 16)

                // Jours de la semaine
                HStack(spacing: 0) {
                    ForEach(joursAbrevies, id: \.self) { jour in
                        Text(jour)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 12)

                // Grille des jours
                grilleJours
                    .padding(.horizontal, 12)
            }
            .padding(.vertical, 12)
            .background(.thinMaterial)

            Divider()

            // ── Liste des séances du jour sélectionné OU prochaines séances
            if let jour = jourSelectionne {
                listeJour(jour)
            } else {
                listeProchaines
            }
        }
        .navigationTitle("Calendrier")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fermer") { dismiss() }
                    .foregroundStyle(.secondary)
            }
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 10) {
                    Button {
                        syncEnCours = true
                        Task {
                            await synchroniserCalendrier()
                            syncEnCours = false
                        }
                    } label: {
                        if syncEnCours {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.subheadline)
                        }
                    }
                    .disabled(syncEnCours)

                    Button { afficherNouvelleSeance = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
        }
        .sheet(isPresented: $afficherNouvelleSeance) {
            NouvelleSeanceView { nom, date in
                let s = Seance(nom: nom, date: date)
                modelContext.insert(s)
            }
        }
        .alert("Calendrier Apple", isPresented: Binding(
            get: { syncResultat != nil },
            set: { if !$0 { syncResultat = nil } }
        )) {
            Button("OK") { syncResultat = nil }
        } message: {
            Text(syncResultat ?? "")
        }
        .onAppear { calendarService.verifierAcces() }
    }

    // MARK: - Grille des jours
    private var grilleJours: some View {
        let premier = premierJourDuMois
        // Lundi = 2 dans Calendar. On veut que lundi soit la première colonne
        let weekday = calendar.component(.weekday, from: premier)
        let offset = (weekday + 5) % 7 // conversion pour lundi = 0
        let nbJours = calendar.range(of: .day, in: .month, for: premier)?.count ?? 30
        let aujourdhuiStr = Date().formatYMD() // P0-01 — DateFormatter caché

        let totalCells = offset + nbJours
        let rows = (totalCells + 6) / 7

        return VStack(spacing: 6) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let idx = row * 7 + col
                        let jour = idx - offset + 1
                        if jour >= 1 && jour <= nbJours {
                            let date = calendar.date(byAdding: .day, value: jour - 1, to: premier) ?? premier
                            let dateStr = date.formatYMD() // P0-01
                            let estAujourdhui = dateStr == aujourdhuiStr
                            let aSeance = dateAvecSeance.contains(dateStr)
                            let estSelectionne = jourSelectionne.map { calendar.isDate($0, inSameDayAs: date) } ?? false
                            let phaseJour = phasePourDate(date)

                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if estSelectionne {
                                        jourSelectionne = nil
                                    } else {
                                        jourSelectionne = date
                                    }
                                }
                            } label: {
                                VStack(spacing: 2) {
                                    Text("\(jour)")
                                        .font(.system(size: 15, weight: estAujourdhui ? .bold : .regular))
                                        .foregroundStyle(couleurJour(estAujourdhui: estAujourdhui,
                                                                      estSelectionne: estSelectionne,
                                                                      date: date))
                                        .frame(width: 34, height: 34)
                                        .background(
                                            Group {
                                                if estSelectionne {
                                                    Circle().fill(PaletteMat.orange)
                                                } else if estAujourdhui {
                                                    Circle().fill(PaletteMat.orange.opacity(0.08))
                                                } else if let phase = phaseJour {
                                                    Circle().fill(phase.typePhase.couleur.opacity(0.06))
                                                }
                                            }
                                        )

                                    // Points indicateurs de séances
                                    Circle()
                                        .fill(aSeance ? PaletteMat.orange : Color.clear)
                                        .frame(width: 5, height: 5)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity, minHeight: 40)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sync calendrier Apple

    private func synchroniserCalendrier() async {
        let futures = seancesFutures
        guard !futures.isEmpty else {
            await MainActor.run { syncResultat = "Aucune séance à venir à synchroniser." }
            return
        }
        var ajoutees = 0
        for seance in futures {
            let duree = (seance.exercices ?? []).reduce(0) { $0 + $1.duree }
            let notes = seance.estMatch ? "Match vs \(seance.adversaire)" : ""
            let lieu = seance.lieu
            let ok = await calendarService.ajouterAuCalendrier(
                nom: seance.nom, date: seance.date, dureeMinutes: duree, lieu: lieu, notes: notes)
            if ok { ajoutees += 1 }
        }
        await MainActor.run {
            syncResultat = "\(ajoutees) séance\(ajoutees > 1 ? "s" : "") ajoutée\(ajoutees > 1 ? "s" : "") au calendrier."
        }
    }

    private func phasePourDate(_ date: Date) -> PhaseSaison? {
        let jour = calendar.startOfDay(for: date)
        return phases.first { phase in
            jour >= calendar.startOfDay(for: phase.dateDebut) &&
            jour <= calendar.startOfDay(for: phase.dateFin)
        }
    }

    private func couleurJour(estAujourdhui: Bool, estSelectionne: Bool, date: Date) -> Color {
        if estSelectionne { return .white }
        if estAujourdhui { return PaletteMat.orange }
        if date < calendar.startOfDay(for: Date()) { return .secondary }
        return .primary
    }

    // MARK: - Liste du jour sélectionné
    private func listeJour(_ jour: Date) -> some View {
        let seances = seancesPourJour(jour)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(jour.formatJourSemaine())
                    .font(.subheadline.weight(.semibold))
                Text(jour.formatCourt())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    withAnimation { jourSelectionne = nil }
                } label: {
                    Text("Tout voir")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PaletteMat.orange)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if seances.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 32, weight: .thin))
                        .foregroundStyle(.tertiary)
                    Text("Aucune séance")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List(seances) { seance in
                    SeanceCalendrierRow(seance: seance)
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Prochaines séances
    private var listeProchaines: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.subheadline)
                    .foregroundStyle(PaletteMat.orange)
                Text("Prochaines séances")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if seancesFutures.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.system(size: 32, weight: .thin))
                        .foregroundStyle(.tertiary)
                    Text("Aucune séance planifiée")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Créez une séance avec une date future")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List(seancesFutures.prefix(15)) { seance in
                    SeanceCalendrierRow(seance: seance)
                }
                .listStyle(.plain)
            }
        }
    }
}

// MARK: - Rangée de séance dans le calendrier
struct SeanceCalendrierRow: View {
    let seance: Seance

    private var estFuture: Bool {
        Calendar.current.startOfDay(for: seance.date) >= Calendar.current.startOfDay(for: Date())
    }

    private var dureeTotale: Int {
        (seance.exercices ?? []).reduce(0) { $0 + $1.duree }
    }

    private var couleurType: Color {
        seance.estMatch ? .red : PaletteMat.orange
    }

    var body: some View {
        HStack(spacing: 12) {
            // Barre de couleur
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(estFuture ? couleurType : Color.secondary.opacity(0.3))
                .frame(width: 4, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(seance.nom)
                        .font(.system(.body, weight: .medium))
                        .lineLimit(1)
                    if seance.estMatch {
                        Text("Match")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.red, in: Capsule())
                    }
                }

                HStack(spacing: 8) {
                    // Date + heure
                    HStack(spacing: 3) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(seance.date.formatJourSemaine())
                            .font(.caption)
                        Text(seance.date.formatHeure())
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(estFuture ? couleurType : .secondary)

                    // Adversaire match
                    if seance.estMatch && !seance.adversaire.isEmpty {
                        Text("vs \(seance.adversaire)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.red)
                    }

                    // Exercices
                    if !(seance.exercices ?? []).isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "figure.volleyball")
                                .font(.caption2)
                            Text("\((seance.exercices ?? []).count)")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }

                    // Durée
                    if dureeTotale > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text("\(dureeTotale) min")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Countdown pour les futures
            if estFuture {
                let jours = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                                            to: Calendar.current.startOfDay(for: seance.date)).day ?? 0
                if jours == 0 {
                    Text("Aujourd'hui")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(couleurType)
                } else if jours == 1 {
                    Text("Demain")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(couleurType)
                } else {
                    Text("J-\(jours)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(couleurType.opacity(0.8))
                }
            }
        }
        .padding(.vertical, 4)
    }
}
