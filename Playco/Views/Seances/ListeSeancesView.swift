//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

struct ListeSeancesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    // P3-01 — Filtrer les séances archivées
    @Query(filter: #Predicate<Seance> { $0.estArchivee == false },
           sort: \Seance.date, order: .reverse) private var seances: [Seance]
    @Binding var seanceSelectionnee: Seance?
    @State private var afficherNouvelleSeance = false
    @State private var seanceARenommer: Seance?
    @State private var afficherRenommer = false
    @State private var nouveauNom = ""
    @State private var recherche = ""
    @State private var seancePresences: Seance?

    /// Séances pratiques uniquement, filtrées par équipe
    private var seancesPratiques: [Seance] {
        seances.filtreEquipe(codeEquipeActif).filter { !$0.estMatch }
    }

    private var seancesFiltrees: [Seance] {
        if recherche.isEmpty { return seancesPratiques }
        return seancesPratiques.filter { $0.nom.localizedCaseInsensitiveContains(recherche) }
    }

    var body: some View {
        Group {
            if seancesPratiques.isEmpty {
                vueVide
            } else {
                List {
                    ForEach(seancesFiltrees) { seance in
                        SeanceCardRow(
                            seance: seance,
                            estSelectionnee: seanceSelectionnee?.id == seance.id,
                            onPresences: (authService.utilisateurConnecte?.role.peutEvaluer ?? false) ? {
                                seancePresences = seance
                            } : nil,
                            onStatsMatch: nil
                        )
                        .onTapGesture {
                            seanceSelectionnee = seance
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .contextMenu {
                            Button { seancePresences = seance } label: {
                                Label("Présences", systemImage: "checkmark.circle")
                            }
                            if authService.utilisateurConnecte?.role.peutModifierSeances ?? false {
                                Divider()
                                Button { renommer(seance) } label: {
                                    Label("Renommer", systemImage: "pencil")
                                }
                                Button { dupliquer(seance) } label: {
                                    Label("Dupliquer", systemImage: "doc.on.doc")
                                }
                                Divider()
                                Button(role: .destructive) { supprimer(seance) } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if authService.utilisateurConnecte?.role.peutModifierSeances ?? false {
                                Button(role: .destructive) { supprimer(seance) } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if authService.utilisateurConnecte?.role.peutModifierSeances ?? false {
                                Button { dupliquer(seance) } label: {
                                    Label("Dupliquer", systemImage: "doc.on.doc")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .searchable(text: $recherche, prompt: "Rechercher une séance")
            }
        }
        .navigationTitle("Séances")
        .toolbar {
            // S3 : bouton + visible seulement pour coach/admin
            if authService.utilisateurConnecte?.role.peutModifierSeances ?? false {
                ToolbarItem(placement: .primaryAction) {
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
                creerSeance(nom: nom, date: date)
            }
        }
        .sheet(item: $seancePresences) { seance in
            PresencesView(seance: seance)
        }
        // P2-02 — alert avec @State bool propre au lieu de Binding(get:set:)
        .sensoryFeedback(.success, trigger: seances.count)
        .alert("Renommer la séance", isPresented: $afficherRenommer) {
            TextField("Nom de la séance", text: $nouveauNom)
            Button("Renommer") {
                let nom = nouveauNom.trimmingCharacters(in: .whitespaces)
                if let s = seanceARenommer, !nom.isEmpty { s.nom = nom }
                seanceARenommer = nil
            }
            Button("Annuler", role: .cancel) { seanceARenommer = nil }
        }
    }

    // MARK: - Vue vide
    private var vueVide: some View {
        ContentUnavailableView {
            Label("Aucune séance", systemImage: "calendar.badge.plus")
        } description: {
            Text("Commencez par créer votre première séance")
        } actions: {
            if authService.utilisateurConnecte?.role.peutModifierSeances ?? false {
                Button("Nouvelle séance", systemImage: "plus") {
                    afficherNouvelleSeance = true
                }
                .buttonStyle(.borderedProminent)
                .tint(PaletteMat.orange)
            }
        }
    }

    @Environment(\.codeEquipeActif) private var codeEquipeActif

    // MARK: - Actions
    private func creerSeance(nom: String, date: Date = Date()) {
        let s = Seance(nom: nom, date: date, typeSeance: .pratique)
        s.codeEquipe = codeEquipeActif
        modelContext.insert(s)
        seanceSelectionnee = s
    }

    // P3-01 — Soft delete : archive au lieu de supprimer définitivement
    private func supprimer(_ seance: Seance) {
        if seanceSelectionnee == seance { seanceSelectionnee = nil }
        seance.estArchivee = true
    }

    private func renommer(_ seance: Seance) {
        seanceARenommer = seance; nouveauNom = seance.nom; afficherRenommer = true
    }

    private func dupliquer(_ seance: Seance) {
        let nouvelle = Seance(nom: "\(seance.nom) (copie)")
        modelContext.insert(nouvelle)
        for ex in (seance.exercices ?? []).sorted(by: { $0.ordre < $1.ordre }) {
            let copie = Exercice(nom: ex.nom, ordre: ex.ordre, duree: ex.duree)
            copie.seance = nouvelle
            copie.notes = ex.notes
            copierTerrain(de: ex, vers: copie) // P1-01 (inclut etapesData)
            modelContext.insert(copie)
            if nouvelle.exercices == nil { nouvelle.exercices = [] }
            nouvelle.exercices?.append(copie)
        }
        seanceSelectionnee = nouvelle
    }
}

// MARK: - Carte séance (V3 — design amélioré)
struct SeanceCardRow: View {
    let seance: Seance
    var estSelectionnee: Bool = false
    var onPresences: (() -> Void)? = nil
    var onStatsMatch: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var estFuture: Bool {
        Calendar.current.startOfDay(for: seance.date) >= Calendar.current.startOfDay(for: Date())
    }

    private var estAujourdhui: Bool {
        Calendar.current.isDateInToday(seance.date)
    }

    private var couleurType: Color {
        seance.estMatch ? .red : PaletteMat.orange
    }

    /// Icone contextuelle selon le type ou le nom
    private var iconeSeance: String {
        if seance.estMatch { return "flag.fill" }
        let nom = seance.nom.lowercased()
        if nom.contains("tactique") { return "flag.fill" }
        if nom.contains("attaque") || nom.contains("frappe") { return "flame.fill" }
        if nom.contains("service") || nom.contains("réception") { return "arrow.up.forward" }
        if nom.contains("bloc") || nom.contains("défense") { return "shield.fill" }
        if nom.contains("échauffement") || nom.contains("passe") { return "figure.volleyball" }
        return "sportscourt.fill"
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Barre laterale coloree
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(estAujourdhui ? couleurType : (estFuture ? couleurType.opacity(0.5) : Color(.systemGray4)))
                    .frame(width: 4)

                // Icone contextuelle
                ZStack {
                    Circle()
                        .fill(estAujourdhui ? couleurType.opacity(0.08) : Color(.systemGray5))
                        .frame(width: 40, height: 40)
                    Image(systemName: iconeSeance)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(estAujourdhui ? couleurType : (estFuture ? couleurType.opacity(0.7) : .secondary))
                }

                // Contenu texte
                VStack(alignment: .leading, spacing: 4) {
                    // Date + badge aujourd'hui
                    HStack(spacing: 6) {
                        Text(seance.date.formatCourt().uppercased())
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(estFuture ? couleurType : .secondary)
                            .tracking(0.6)
                        if estFuture {
                            Text(seance.date.formatHeure())
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(couleurType.opacity(0.7))
                        }
                        if seance.estMatch {
                            Text("Match")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.red, in: Capsule())
                        }
                        if estAujourdhui {
                            Text("Aujourd'hui")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(couleurType, in: Capsule())
                        }
                    }

                    // Nom
                    Text(seance.nom)
                        .font(.system(.body, design: .default, weight: .semibold))
                        .foregroundStyle(Color(.label))
                        .lineLimit(2)

                    // Info match
                    if seance.estMatch {
                        HStack(spacing: 8) {
                            if !seance.adversaire.isEmpty {
                                HStack(spacing: 3) {
                                    Image(systemName: "person.2.fill")
                                        .font(.caption2)
                                    Text("vs \(seance.adversaire)")
                                        .font(.caption.weight(.medium))
                                }
                                .foregroundStyle(.red)
                            }
                            if !seance.lieu.isEmpty {
                                HStack(spacing: 3) {
                                    Image(systemName: "mappin")
                                        .font(.caption2)
                                    Text(seance.lieu)
                                        .font(.caption)
                                }
                                .foregroundStyle(.secondary)
                            }
                            if seance.scoreEquipe > 0 || seance.scoreAdversaire > 0 {
                                Text("\(seance.scoreEquipe) - \(seance.scoreAdversaire)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(seance.resultat?.couleur ?? .primary)
                            }
                        }
                    }

                    // Details : duree + exercices
                    HStack(spacing: 12) {
                        if !(seance.exercices ?? []).isEmpty {
                            let duree = (seance.exercices ?? []).reduce(0) { $0 + $1.duree }
                            if duree > 0 {
                                HStack(spacing: 3) {
                                    Image(systemName: "clock")
                                        .font(.caption2)
                                    Text("\(duree) min")
                                        .font(.caption)
                                }
                                .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 3) {
                                Image(systemName: "list.bullet")
                                    .font(.caption2)
                                Text("\((seance.exercices ?? []).count) exercice\((seance.exercices ?? []).count > 1 ? "s" : "")")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        } else {
                            Text("Aucun exercice")
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()

                // Aperçu terrain — miniature du premier exercice dessiné
                if let premierDessin = (seance.exercices ?? [])
                    .sorted(by: { $0.ordre < $1.ordre })
                    .first(where: { $0.elementsData != nil && !($0.elementsData?.isEmpty ?? true) }) {
                    TerrainMiniatureView(
                        elementsData: premierDessin.elementsData,
                        taille: 110,
                        typeTerrain: TypeTerrain(rawValue: premierDessin.typeTerrain) ?? .indoor
                    )
                    .overlay(alignment: .bottomTrailing) {
                        // Badge compteur exercices
                        Text("\((seance.exercices ?? []).count)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(couleurType, in: Circle())
                            .offset(x: 4, y: 4)
                    }
                } else if !(seance.exercices ?? []).isEmpty {
                    // Pas de dessin — badge compteur seul
                    Text("\((seance.exercices ?? []).count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(couleurType, in: Circle())
                }

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            // Boutons actions (visible quand la seance est selectionnee)
            if estSelectionnee {
                HStack(spacing: 10) {
                    if let onPresences {
                        Button {
                            onPresences()
                        } label: {
                            Label("Présences", systemImage: "checkmark.circle")
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(PaletteMat.vert.opacity(0.08), in: Capsule(style: .continuous))
                                .foregroundStyle(PaletteMat.vert)
                        }
                        .buttonStyle(.plain)
                    }

                    // Bouton stats match — visible quand match avec score entré
                    if seance.estMatch && seance.scoreEntre, let onStatsMatch {
                        Button {
                            onStatsMatch()
                        } label: {
                            Label(seance.statsEntrees ? "Stats ✓" : "Entrer stats", systemImage: "tablecells")
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(seance.statsEntrees
                                    ? Color.green.opacity(0.08)
                                    : Color.red.opacity(0.08),
                                    in: Capsule(style: .continuous))
                                .foregroundStyle(seance.statsEntrees ? .green : .red)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(estSelectionnee || estAujourdhui ? 0 : 1)
        }
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(estSelectionnee
                      ? couleurType.opacity(0.08)
                      : (estAujourdhui ? couleurType.opacity(0.04) : .clear))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(estSelectionnee ? couleurType.opacity(0.3) : .white.opacity(0.2), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }
}
