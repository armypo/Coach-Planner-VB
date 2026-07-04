//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

// MARK: - ScoutingReportView

/// Éditeur complet de rapport de scouting pour un adversaire.
///
/// Refonte Phase 6 :
/// - sections repliables (chevron par section, « Autres notes » repliée par défaut) ;
/// - tendances service/attaque saisies sur 2 mini-terrains 6 zones (tap = cycle
///   du niveau de menace 0→1→2→3→0) + une note texte courte par catégorie ;
/// - lien optionnel vers un match du calendrier (`seanceID`) ;
/// - sauvegarde DEBOUNCÉE : les frappes clavier planifient une écriture unique
///   (délai `delaiSauvegarde`) au lieu de ré-encoder le JSON à chaque caractère ;
///   flush garanti au `onDisappear`. Les ajouts/suppressions structurels
///   persistent immédiatement.
struct ScoutingReportView: View {
    @Bindable var rapport: ScoutingReport

    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Environment(\.codeEquipeActif) private var codeEquipeActif

    // État local — copies des arrays JSON pour édition fluide
    @State private var joueurs: [JoueurAdverse] = []
    @State private var forces: [String] = []
    @State private var faiblesses: [String] = []
    @State private var strategies: [StrategieRecommandee] = []
    @State private var tendancesZonales = TendancesZonales()
    @State private var joueurDeplie: UUID?

    // Sauvegarde debouncée
    @State private var sauvegardeTask: Task<Void, Never>?
    @State private var aDesModifications = false
    private static let delaiSauvegarde: Duration = .milliseconds(600)

    // Sections repliables — « Autres notes » repliée par défaut
    private enum SectionRapport: Hashable {
        case joueurs, forces, faiblesses, tendances, strategies, notes, autresNotes
    }
    @State private var sectionsRepliees: Set<SectionRapport> = [.autresNotes]

    /// Matchs du calendrier liables au rapport (non archivés, équipe active).
    @Query(filter: #Predicate<Seance> { $0.estArchivee == false && $0.typeSeanceRaw == "Match" },
           sort: \Seance.date, order: .reverse) private var tousMatchs: [Seance]

    private var matchsEquipe: [Seance] {
        tousMatchs.filtreEquipe(codeEquipeActif)
    }

    private var peutModifier: Bool {
        authService.utilisateurConnecte?.role.peutModifierStrategies ?? false
    }

    // MARK: - Pickers data

    private let systemesJeu = ["5-1", "6-2", "4-2", "Autre"]
    private let stylesJeu = ["Offensif", "Défensif", "Équilibré"]
    private let categoriesStrategie = ["Service", "Attaque", "Bloc", "Réception", "Général"]

    var body: some View {
        ScrollView {
            VStack(spacing: LiquidGlassKit.espaceLG - 4) {
                sectionEntete
                sectionJoueursCles
                sectionForces
                sectionFaiblesses
                sectionTendances
                sectionStrategies
                sectionNotes
                sectionAutresNotes
            }
            .padding(LiquidGlassKit.espaceLG)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Rapport")
        .onAppear {
            joueurs = rapport.joueurs
            forces = rapport.forces
            faiblesses = rapport.faiblesses
            strategies = rapport.strategies
            tendancesZonales = rapport.tendancesZonales
        }
        .onDisappear {
            // Flush : on annule le debounce en cours et on persiste tout de suite.
            sauvegardeTask?.cancel()
            persisterTout()
        }
    }

    // MARK: - Repli / dépli

    private func estRepliee(_ section: SectionRapport) -> Bool {
        sectionsRepliees.contains(section)
    }

    private func basculerSection(_ section: SectionRapport) {
        withAnimation(LiquidGlassKit.springDefaut) {
            if sectionsRepliees.contains(section) {
                sectionsRepliees.remove(section)
            } else {
                sectionsRepliees.insert(section)
            }
        }
    }

    private func boutonRepli(_ section: SectionRapport) -> some View {
        Button {
            basculerSection(section)
        } label: {
            Image(systemName: "chevron.down")
                .font(.subheadline.weight(.semibold))
                .rotationEffect(.degrees(estRepliee(section) ? -90 : 0))
                .foregroundStyle(PaletteMat.texteSecondaire)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(estRepliee(section) ? "Déplier la section" : "Replier la section")
    }

    // MARK: - 1. En-tête

    private var sectionEntete: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceMD) {
            titreSectionAvecIcone("Informations générales", icone: "info.circle.fill", couleur: .red)

            HStack(spacing: LiquidGlassKit.espaceMD) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Adversaire")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PaletteMat.texteSecondaire)
                    TextField("Nom de l'équipe adverse", text: $rapport.adversaire)
                        .textFieldStyle(.roundedBorder)
                        .font(.body.weight(.medium))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Date du match")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PaletteMat.texteSecondaire)
                    DatePicker("", selection: $rapport.dateMatch, displayedComponents: [.date])
                        .labelsHidden()
                }
                .frame(width: 180)
            }

            // Match du calendrier lié à ce rapport (optionnel)
            VStack(alignment: .leading, spacing: 6) {
                Text("Match lié")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(PaletteMat.texteSecondaire)
                Picker("Match lié", selection: $rapport.seanceID) {
                    Text("Aucun").tag(UUID?.none)
                    ForEach(matchsEquipe) { match in
                        Text("\(match.adversaire.isEmpty ? match.nom : "vs \(match.adversaire)") — \(match.date.formatCourt())")
                            .tag(Optional(match.id))
                    }
                    // Sélection existante hors liste (match archivé/autre équipe)
                    if let lie = rapport.seanceID, !matchsEquipe.contains(where: { $0.id == lie }) {
                        Text("Match archivé").tag(Optional(lie))
                    }
                }
                .pickerStyle(.menu)
                .tint(.red)
            }

            // Match observé (contexte de l'observation)
            VStack(alignment: .leading, spacing: 6) {
                Text("Match observé")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(PaletteMat.texteSecondaire)
                TextField("ex : Équipe X vs Équipe Y", text: $rapport.adversaireObserve)
                    .textFieldStyle(.roundedBorder)
                Text("Le match durant lequel vous avez observé cet adversaire (contre qui il jouait).")
                    .font(.caption2)
                    .foregroundStyle(PaletteMat.texteTertiaire)
            }

            HStack(spacing: LiquidGlassKit.espaceMD) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Système de jeu")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PaletteMat.texteSecondaire)
                    Picker("Système", selection: $rapport.systemJeu) {
                        Text("Non défini").tag("")
                        ForEach(systemesJeu, id: \.self) { sys in
                            Text(sys).tag(sys)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.red)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Style de jeu")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PaletteMat.texteSecondaire)
                    Picker("Style", selection: $rapport.styleJeu) {
                        Text("Non défini").tag("")
                        ForEach(stylesJeu, id: \.self) { style in
                            Text(style).tag(style)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.red)
                }

                Spacer()
            }
        }
        .glassSection()
    }

    // MARK: - 2. Joueurs clés

    private var sectionJoueursCles: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceMD) {
            HStack {
                titreSectionAvecIcone("Joueurs clés adverses", icone: "person.3.fill", couleur: .red)
                Spacer()
                if !estRepliee(.joueurs) {
                    Button {
                        withAnimation(LiquidGlassKit.springDefaut) {
                            let nouveau = JoueurAdverse()
                            joueurs.append(nouveau)
                            joueurDeplie = nouveau.id
                            sauvegarderImmediatement()
                        }
                    } label: {
                        Label("Ajouter", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(GlassButtonStyle())
                    .siAutorise(peutModifier)
                }
                boutonRepli(.joueurs)
            }

            if !estRepliee(.joueurs) {
                if joueurs.isEmpty {
                    placeholderVide("Aucun joueur clé identifié", icone: "person.crop.circle.badge.questionmark")
                } else {
                    ForEach(Array(joueurs.enumerated()), id: \.element.id) { index, joueur in
                        CarteJoueurAdverseEditable(
                            joueur: $joueurs[index],
                            estDeplie: joueurDeplie == joueur.id,
                            peutModifier: peutModifier,
                            onFrappe: { planifierSauvegarde() },
                            onChangementImmediat: { sauvegarderImmediatement() },
                            onBasculerDepli: {
                                withAnimation(LiquidGlassKit.springDefaut) {
                                    joueurDeplie = joueurDeplie == joueur.id ? nil : joueur.id
                                }
                            },
                            onSupprimer: {
                                withAnimation(LiquidGlassKit.springDefaut) {
                                    joueurs.remove(at: index)
                                    sauvegarderImmediatement()
                                }
                            }
                        )
                    }
                }
            }
        }
        .glassSection()
    }

    // MARK: - 3. Forces

    private var sectionForces: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceMD) {
            HStack {
                titreSectionAvecIcone("Forces de l'adversaire", icone: "bolt.fill", couleur: PaletteMat.vert)
                Spacer()
                if !estRepliee(.forces) {
                    Button {
                        withAnimation(LiquidGlassKit.springDefaut) {
                            forces.append("")
                            sauvegarderImmediatement()
                        }
                    } label: {
                        Label("Ajouter", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(GlassButtonStyle())
                    .siAutorise(peutModifier)
                }
                boutonRepli(.forces)
            }

            if !estRepliee(.forces) {
                if forces.isEmpty {
                    placeholderVide("Aucune force identifiée", icone: "bolt.slash")
                } else {
                    ForEach(Array(forces.enumerated()), id: \.offset) { index, _ in
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(PaletteMat.vert)
                                .font(.body)

                            TextField("Force de l'adversaire", text: $forces[index])
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: forces[index]) { _, _ in planifierSauvegarde() }

                            Button(role: .destructive) {
                                withAnimation(LiquidGlassKit.springDefaut) {
                                    forces.remove(at: index)
                                    sauvegarderImmediatement()
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red.opacity(0.6))
                            }
                            .siAutorise(peutModifier)
                        }
                    }
                }
            }
        }
        .glassSection()
    }

    // MARK: - 4. Faiblesses

    private var sectionFaiblesses: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceMD) {
            HStack {
                titreSectionAvecIcone("Faiblesses de l'adversaire", icone: "exclamationmark.triangle.fill", couleur: .orange)
                Spacer()
                if !estRepliee(.faiblesses) {
                    Button {
                        withAnimation(LiquidGlassKit.springDefaut) {
                            faiblesses.append("")
                            sauvegarderImmediatement()
                        }
                    } label: {
                        Label("Ajouter", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(GlassButtonStyle())
                    .siAutorise(peutModifier)
                }
                boutonRepli(.faiblesses)
            }

            if !estRepliee(.faiblesses) {
                if faiblesses.isEmpty {
                    placeholderVide("Aucune faiblesse identifiée", icone: "exclamationmark.triangle")
                } else {
                    ForEach(Array(faiblesses.enumerated()), id: \.offset) { index, _ in
                        HStack(spacing: 12) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.orange)
                                .font(.body)

                            TextField("Faiblesse de l'adversaire", text: $faiblesses[index])
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: faiblesses[index]) { _, _ in planifierSauvegarde() }

                            Button(role: .destructive) {
                                withAnimation(LiquidGlassKit.springDefaut) {
                                    faiblesses.remove(at: index)
                                    sauvegarderImmediatement()
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red.opacity(0.6))
                            }
                            .siAutorise(peutModifier)
                        }
                    }
                }
            }
        }
        .glassSection()
    }

    // MARK: - 5. Tendances zonales (service + attaque)

    private var sectionTendances: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceMD) {
            HStack {
                titreSectionAvecIcone("Tendances observées", icone: "chart.line.uptrend.xyaxis", couleur: PaletteMat.bleu)
                Spacer()
                boutonRepli(.tendances)
            }

            if !estRepliee(.tendances) {
                Text("Touchez une zone pour faire monter son niveau de menace (0 → 3).")
                    .font(.caption)
                    .foregroundStyle(PaletteMat.texteSecondaire)

                // NB : les notes courtes ci-dessous sont liées directement au
                // modèle (String simple, pas de ré-encodage JSON par frappe) —
                // SwiftData coalesce ces écritures, pas besoin de debounce.

                HStack(alignment: .top, spacing: LiquidGlassKit.espaceLG) {
                    VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
                        MiniTerrainZonesMenace(
                            titre: "Service adverse",
                            niveaux: tendancesZonales.service,
                            estInteractif: peutModifier,
                            onCycleZone: { zone in cyclerZone(zone, service: true) }
                        )
                        TextField("Note courte (ex : sert surtout zone 1 et 5)", text: $rapport.tendanceService)
                            .textFieldStyle(.roundedBorder)
                            .font(.footnote)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
                        MiniTerrainZonesMenace(
                            titre: "Attaque adverse",
                            niveaux: tendancesZonales.attaque,
                            estInteractif: peutModifier,
                            onCycleZone: { zone in cyclerZone(zone, service: false) }
                        )
                        TextField("Note courte (ex : attaque rapide au centre)", text: $rapport.tendanceAttaque)
                            .textFieldStyle(.roundedBorder)
                            .font(.footnote)
                    }
                    .frame(maxWidth: .infinity)
                }

                Text(MiniTerrainZonesMenace.legendeNiveaux)
                    .font(.caption2)
                    .foregroundStyle(PaletteMat.texteTertiaire)
            }
        }
        .glassSection()
    }

    /// Cycle le niveau de menace d'une zone (copie immuable puis réassignation).
    private func cyclerZone(_ zone: Int, service: Bool) {
        var nouvelles = tendancesZonales
        if service {
            nouvelles.service[zone] = TendancesZonales.niveauSuivant(nouvelles.service[zone] ?? 0)
        } else {
            nouvelles.attaque[zone] = TendancesZonales.niveauSuivant(nouvelles.attaque[zone] ?? 0)
        }
        tendancesZonales = nouvelles
        planifierSauvegarde()
    }

    // MARK: - 6. Stratégies recommandées

    private var sectionStrategies: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceMD) {
            HStack {
                titreSectionAvecIcone("Stratégies recommandées", icone: "lightbulb.fill", couleur: PaletteMat.violet)
                Spacer()
                if !estRepliee(.strategies) {
                    Button {
                        withAnimation(LiquidGlassKit.springDefaut) {
                            strategies.append(StrategieRecommandee())
                            sauvegarderImmediatement()
                        }
                    } label: {
                        Label("Ajouter", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(GlassButtonStyle())
                    .siAutorise(peutModifier)
                }
                boutonRepli(.strategies)
            }

            if !estRepliee(.strategies) {
                if strategies.isEmpty {
                    placeholderVide("Aucune stratégie recommandée", icone: "lightbulb.slash")
                } else {
                    ForEach(Array(strategies.enumerated()), id: \.element.id) { index, strategie in
                        carteStrategie(index: index, strategie: strategie)
                    }
                }
            }
        }
        .glassSection()
    }

    private func carteStrategie(index: Int, strategie: StrategieRecommandee) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Indicateur priorité
                badgePriorite(strategie.priorite)

                VStack(alignment: .leading, spacing: 4) {
                    TextField("Titre de la stratégie", text: $strategies[index].titre)
                        .font(.headline)
                        .onChange(of: strategies[index].titre) { _, _ in planifierSauvegarde() }

                    HStack(spacing: 12) {
                        Picker("Priorité", selection: $strategies[index].priorite) {
                            Text("Haute").tag(1)
                            Text("Moyenne").tag(2)
                            Text("Basse").tag(3)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 260)
                        .onChange(of: strategies[index].priorite) { _, _ in planifierSauvegarde() }

                        Picker("Catégorie", selection: $strategies[index].categorie) {
                            Text("Catégorie").tag("")
                            ForEach(categoriesStrategie, id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(PaletteMat.violet)
                        .onChange(of: strategies[index].categorie) { _, _ in planifierSauvegarde() }
                    }
                }

                Spacer()

                Button(role: .destructive) {
                    withAnimation(LiquidGlassKit.springDefaut) {
                        strategies.remove(at: index)
                        sauvegarderImmediatement()
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.7))
                }
                .siAutorise(peutModifier)
            }

            TextEditor(text: $strategies[index].description)
                .frame(minHeight: 60)
                .scrollContentBackground(.hidden)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMini * 2, style: .continuous))
                .overlay {
                    if strategies[index].description.isEmpty {
                        Text("Description de la stratégie...")
                            .font(.footnote)
                            .foregroundStyle(PaletteMat.texteTertiaire)
                            .padding(LiquidGlassKit.espaceSM)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .allowsHitTesting(false)
                    }
                }
                .onChange(of: strategies[index].description) { _, _ in planifierSauvegarde() }
        }
        .padding(12)
        .glassCard(teinte: PaletteMat.violet, cornerRadius: 14, ombre: true)
    }

    // MARK: - 7. Notes générales

    private var sectionNotes: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                titreSectionAvecIcone("Notes générales", icone: "note.text", couleur: PaletteMat.texteSecondaire)
                Spacer()
                boutonRepli(.notes)
            }

            if !estRepliee(.notes) {
                TextEditor(text: $rapport.notes)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit - 2, style: .continuous))
                    .overlay {
                        if rapport.notes.isEmpty {
                            Text("Notes supplémentaires sur l'adversaire, le contexte du match, les enjeux...")
                                .font(.footnote)
                                .foregroundStyle(PaletteMat.texteTertiaire)
                                .padding(LiquidGlassKit.espaceSM)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .allowsHitTesting(false)
                        }
                    }
            }
        }
        .glassSection()
    }

    // MARK: - 8. Autres notes (réception + bloc) — repliée par défaut

    private var sectionAutresNotes: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                titreSectionAvecIcone("Autres notes (réception, bloc)", icone: "text.alignleft", couleur: PaletteMat.texteSecondaire)
                Spacer()
                boutonRepli(.autresNotes)
            }

            if !estRepliee(.autresNotes) {
                champTendanceTexte(
                    titre: "Réception",
                    texte: $rapport.tendanceReception,
                    placeholder: "Ex : Faiblesse en réception zone 6..."
                )
                champTendanceTexte(
                    titre: "Bloc",
                    texte: $rapport.tendanceBloc,
                    placeholder: "Ex : Bloc double sur l'extérieur..."
                )
            }
        }
        .glassSection()
    }

    private func champTendanceTexte(titre: String, texte: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Text(titre)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PaletteMat.bleu)

            TextEditor(text: texte)
                .frame(minHeight: 80)
                .scrollContentBackground(.hidden)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit - 2, style: .continuous))
                .overlay {
                    if texte.wrappedValue.isEmpty {
                        Text(placeholder)
                            .font(.footnote)
                            .foregroundStyle(PaletteMat.texteTertiaire)
                            .padding(LiquidGlassKit.espaceSM)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    // MARK: - Composants réutilisables

    private func titreSectionAvecIcone(_ titre: String, icone: String, couleur: Color) -> some View {
        Label(titre, systemImage: icone)
            .font(.title3.weight(.semibold))
            .foregroundStyle(couleur)
            .symbolRenderingMode(.hierarchical)
    }

    private func placeholderVide(_ texte: String, icone: String) -> some View {
        HStack(spacing: LiquidGlassKit.espaceSM) {
            Image(systemName: icone)
                .font(.title3)
                .foregroundStyle(PaletteMat.texteTertiaire)
            Text(texte)
                .font(.subheadline)
                .foregroundStyle(PaletteMat.texteTertiaire)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LiquidGlassKit.espaceLG)
    }

    private func badgePriorite(_ priorite: Int) -> some View {
        let (texte, couleur): (String, Color) = switch priorite {
        case 1: ("!", .red)
        case 2: ("!!", .orange)
        default: ("~", PaletteMat.texteSecondaire)
        }

        return Text(texte)
            .font(.caption.weight(.black))
            .foregroundStyle(couleur)
            .frame(width: 28, height: 28)
            .background {
                Circle()
                    .fill(couleur.opacity(0.12))
            }
    }

    // MARK: - Sauvegarde (debounce)

    /// Planifie une écriture unique après `delaiSauvegarde` : les frappes
    /// rapprochées annulent la tâche précédente, on n'encode donc le JSON
    /// qu'une fois la saisie stabilisée (au lieu d'à chaque caractère).
    private func planifierSauvegarde() {
        aDesModifications = true
        sauvegardeTask?.cancel()
        sauvegardeTask = Task {
            try? await Task.sleep(for: Self.delaiSauvegarde)
            guard !Task.isCancelled else { return }
            persisterTout()
        }
    }

    /// Changement structurel (ajout/suppression, étoiles, zones) : marque le
    /// rapport modifié et persiste immédiatement (pas de debounce — ces
    /// interactions sont ponctuelles, contrairement aux frappes clavier).
    private func sauvegarderImmediatement() {
        aDesModifications = true
        persisterTout()
    }

    /// Écrit l'état local dans le modèle (encodage JSON). Appelé à l'échéance
    /// du debounce, sur `sauvegarderImmediatement()` et au `onDisappear`
    /// (flush). No-op si rien n'a changé depuis la dernière écriture — évite
    /// de re-salir l'enregistrement CloudKit inutilement.
    private func persisterTout() {
        sauvegardeTask?.cancel()
        guard aDesModifications else { return }
        rapport.joueurs = joueurs
        rapport.forces = forces
        rapport.faiblesses = faiblesses
        rapport.strategies = strategies
        rapport.tendancesZonales = tendancesZonales
        aDesModifications = false
    }
}
