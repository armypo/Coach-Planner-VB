//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Vue macro de planification de saison avec périodisation et timeline horizontale
struct PlanificationSaisonView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Query(sort: \PhaseSaison.dateDebut) private var toutesPhases: [PhaseSaison]
    @Query(filter: #Predicate<Seance> { $0.estArchivee == false },
           sort: \Seance.date) private var toutesSeances: [Seance]

    @State private var afficherAjoutPhase = false
    @State private var phaseSelectionnee: PhaseSaison?

    private var phases: [PhaseSaison] {
        toutesPhases.filtreEquipe(codeEquipeActif)
    }

    private var seances: [Seance] {
        toutesSeances.filtreEquipe(codeEquipeActif)
    }

    private let calendar = Calendar.current

    /// Plage de dates de la saison
    private var plageSaison: (debut: Date, fin: Date)? {
        guard let premiere = phases.first, let derniere = phases.last else { return nil }
        return (premiere.dateDebut, derniere.dateFin)
    }

    /// Semaines de la saison
    private var semaines: [Date] {
        guard let plage = plageSaison else { return [] }
        var result: [Date] = []
        var semaine = calendar.dateInterval(of: .weekOfYear, for: plage.debut)?.start ?? plage.debut
        while semaine <= plage.fin {
            result.append(semaine)
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: semaine) else { break }
            semaine = next
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LiquidGlassKit.espaceLG) {
                // En-tête
                headerSaison

                if phases.isEmpty {
                    ContentUnavailableView {
                        Label("Aucune phase définie", systemImage: "calendar.badge.plus")
                    } description: {
                        Text("Ajoutez des phases pour planifier votre saison")
                    } actions: {
                        Button("Ajouter une phase", systemImage: "plus") {
                            afficherAjoutPhase = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PaletteMat.orange)
                    }
                } else {
                    // Timeline horizontale
                    timelineSection

                    // Volume hebdomadaire
                    volumeSection

                    // Liste des phases
                    listePhasesSection
                }
            }
            .padding(LiquidGlassKit.espaceMD)
        }
        .navigationTitle("Planification saison")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { afficherAjoutPhase = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                }
            }
        }
        .sheet(isPresented: $afficherAjoutPhase) {
            PhaseSaisonDetailView(codeEquipe: codeEquipeActif)
        }
        .sheet(item: $phaseSelectionnee) { phase in
            PhaseSaisonDetailView(phase: phase, codeEquipe: codeEquipeActif)
        }
    }

    // MARK: - Header

    private var headerSaison: some View {
        HStack(spacing: LiquidGlassKit.espaceMD) {
            ForEach(TypePhase.allCases, id: \.self) { type in
                let count = phases.filter { $0.typePhase == type }.count
                if count > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: type.icone)
                            .font(.caption2)
                        Text("\(count)")
                            .font(.caption.weight(.bold).monospacedDigit())
                    }
                    .foregroundStyle(type.couleur)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(type.couleur.opacity(0.1), in: Capsule())
                }
            }
            Spacer()
            if let plage = plageSaison {
                Text("\(semaines.count) sem.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                let _ = plage // suppress unused warning
            }
        }
    }

    // MARK: - Timeline horizontale

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Text("TIMELINE")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(semaines, id: \.self) { semaine in
                        let phase = phasePourDate(semaine)
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(phase?.typePhase.couleur ?? Color(.tertiarySystemFill))
                                .frame(width: 24, height: 40)

                            Text(semaineLabel(semaine))
                                .font(.system(size: 8, weight: .medium).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .onTapGesture {
                            if let p = phase { phaseSelectionnee = p }
                        }
                    }
                }
                .padding(.horizontal, LiquidGlassKit.espaceSM)
            }
            .padding(.vertical, LiquidGlassKit.espaceSM)
            .glassSection()
        }
    }

    // MARK: - Volume hebdo

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Text("VOLUME HEBDOMADAIRE")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(semaines, id: \.self) { semaine in
                        let heuresReelles = heuresSemaine(semaine)
                        let phase = phasePourDate(semaine)
                        let cible = Double(phase?.volumeHebdo ?? 0)
                        let ratio = cible > 0 ? min(heuresReelles / cible, 1.5) : 0

                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(ratio >= 0.8 ? PaletteMat.vert : PaletteMat.orange)
                                .frame(width: 20, height: max(4, CGFloat(ratio) * 50))

                            Text(String(format: "%.0f", heuresReelles))
                                .font(.system(size: 7, weight: .medium).monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.horizontal, LiquidGlassKit.espaceSM)
                .padding(.top, LiquidGlassKit.espaceSM)
            }
            .frame(height: 80)
            .glassSection()
        }
    }

    // MARK: - Liste phases

    private var listePhasesSection: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Text("PHASES")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(phases) { phase in
                Button {
                    phaseSelectionnee = phase
                } label: {
                    HStack(spacing: LiquidGlassKit.espaceMD) {
                        Image(systemName: phase.typePhase.icone)
                            .font(.title3)
                            .foregroundStyle(phase.typePhase.couleur)
                            .frame(width: 36)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(phase.nom.isEmpty ? phase.typePhase.rawValue : phase.nom)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                            HStack(spacing: 8) {
                                Text("\(phase.dateDebut.formatCourt()) → \(phase.dateFin.formatCourt())")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if phase.volumeHebdo > 0 {
                                    Text("\(phase.volumeHebdo)h/sem")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(phase.typePhase.couleur)
                                }
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(LiquidGlassKit.espaceMD)
                    .glassCard(teinte: phase.typePhase.couleur, cornerRadius: LiquidGlassKit.rayonMoyen)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        modelContext.delete(phase)
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func phasePourDate(_ date: Date) -> PhaseSaison? {
        phases.first { phase in
            date >= calendar.startOfDay(for: phase.dateDebut) &&
            date <= calendar.startOfDay(for: phase.dateFin)
        }
    }

    private func semaineLabel(_ date: Date) -> String {
        let composants = calendar.dateComponents([.month, .day], from: date)
        return "\(composants.day ?? 0)/\(composants.month ?? 0)"
    }

    private func heuresSemaine(_ semaine: Date) -> Double {
        guard let fin = calendar.date(byAdding: .weekOfYear, value: 1, to: semaine) else { return 0 }
        let seancesSemaine = seances.filter { $0.date >= semaine && $0.date < fin }
        // Estimer ~1.5h par séance
        return Double(seancesSemaine.count) * 1.5
    }
}
