//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

// MARK: - ScoutingReportView

/// Editeur complet de rapport de scouting pour un adversaire
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
    @State private var joueurDeplie: UUID?

    private var peutModifier: Bool {
        authService.utilisateurConnecte?.role.peutModifierStrategies ?? false
    }

    // MARK: - Pickers data

    private let systemesJeu = ["5-1", "6-2", "4-2", "Autre"]
    private let stylesJeu = ["Offensif", "Défensif", "Équilibré"]
    private let postes = ["Attaquant", "Passeur", "Central", "Libéro", "Réceptionneur-attaquant", "Opposé", "Autre"]
    private let categoriesStrategie = ["Service", "Attaque", "Bloc", "Réception", "Général"]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                sectionEntete
                sectionJoueursCles
                sectionForces
                sectionFaiblesses
                sectionTendances
                sectionStrategies
                sectionNotes
            }
            .padding(24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Rapport")
        .onAppear {
            joueurs = rapport.joueurs
            forces = rapport.forces
            faiblesses = rapport.faiblesses
            strategies = rapport.strategies
        }
    }

    // MARK: - 1. En-tête

    private var sectionEntete: some View {
        VStack(alignment: .leading, spacing: 16) {
            titreSectionAvecIcone("Informations générales", icone: "info.circle.fill", couleur: .red)

            HStack(spacing: 16) {
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

            // Adversaire observé (contre qui jouait l'équipe scoutée)
            VStack(alignment: .leading, spacing: 6) {
                Text("Adversaire observé (contre qui jouait l'équipe scoutée)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(PaletteMat.texteSecondaire)
                TextField("ex : Équipe X vs Équipe Y", text: $rapport.adversaireObserve)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 16) {
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                titreSectionAvecIcone("Joueurs clés adverses", icone: "person.3.fill", couleur: .red)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        let nouveau = JoueurAdverse()
                        joueurs.append(nouveau)
                        joueurDeplie = nouveau.id
                        sauvegarderJoueurs()
                    }
                } label: {
                    Label("Ajouter", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(GlassButtonStyle())
                .siAutorise(peutModifier)
            }

            if joueurs.isEmpty {
                placeholderVide("Aucun joueur clé identifié", icone: "person.crop.circle.badge.questionmark")
            } else {
                ForEach(Array(joueurs.enumerated()), id: \.element.id) { index, joueur in
                    carteJoueur(index: index, joueur: joueur)
                }
            }
        }
        .glassSection()
    }

    private func carteJoueur(index: Int, joueur: JoueurAdverse) -> some View {
        let estDeplie = joueurDeplie == joueur.id

        return VStack(alignment: .leading, spacing: 12) {
            // Ligne résumé — toujours visible
            HStack(spacing: 12) {
                // Numéro
                Text("#\(joueur.numero)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(.red)
                    .frame(width: 50)

                VStack(alignment: .leading, spacing: 2) {
                    Text(joueur.nom.isEmpty ? "Nouveau joueur" : joueur.nom)
                        .font(.headline)
                    if !joueur.poste.isEmpty {
                        Text(joueur.poste)
                            .font(.caption)
                            .foregroundStyle(PaletteMat.texteSecondaire)
                    }
                }

                Spacer()

                // Étoiles de menace
                etoilesMenace(niveau: joueur.menaceNiveau) { nouveau in
                    joueurs[index].menaceNiveau = nouveau
                    sauvegarderJoueurs()
                }

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        joueurDeplie = estDeplie ? nil : joueur.id
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(estDeplie ? 180 : 0))
                        .foregroundStyle(PaletteMat.texteSecondaire)
                }

                Button(role: .destructive) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        joueurs.remove(at: index)
                        sauvegarderJoueurs()
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.7))
                }
                .siAutorise(peutModifier)
            }

            // Détails — dépliable
            if estDeplie {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Numéro")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(PaletteMat.texteSecondaire)
                            TextField("#", value: $joueurs[index].numero, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .onChange(of: joueurs[index].numero) { _, _ in sauvegarderJoueurs() }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Nom")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(PaletteMat.texteSecondaire)
                            TextField("Nom du joueur", text: $joueurs[index].nom)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: joueurs[index].nom) { _, _ in sauvegarderJoueurs() }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Poste")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(PaletteMat.texteSecondaire)
                            Picker("Poste", selection: $joueurs[index].poste) {
                                Text("Non défini").tag("")
                                ForEach(postes, id: \.self) { p in
                                    Text(p).tag(p)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(.red)
                            .onChange(of: joueurs[index].poste) { _, _ in sauvegarderJoueurs() }
                        }
                    }

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Points forts", systemImage: "hand.thumbsup.fill")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(PaletteMat.vert)
                            TextEditor(text: $joueurs[index].pointsForts)
                                .frame(minHeight: 60)
                                .scrollContentBackground(.hidden)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .onChange(of: joueurs[index].pointsForts) { _, _ in sauvegarderJoueurs() }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Label("Points faibles", systemImage: "hand.thumbsdown.fill")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.red)
                            TextEditor(text: $joueurs[index].pointsFaibles)
                                .frame(minHeight: 60)
                                .scrollContentBackground(.hidden)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .onChange(of: joueurs[index].pointsFaibles) { _, _ in sauvegarderJoueurs() }
                        }
                    }

                    HStack(spacing: 8) {
                        Text("Niveau de menace :")
                            .font(.subheadline.weight(.medium))
                        etoilesMenace(niveau: joueurs[index].menaceNiveau) { nouveau in
                            joueurs[index].menaceNiveau = nouveau
                            sauvegarderJoueurs()
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .glassCard(teinte: .red, cornerRadius: 14, ombre: true)
    }

    // MARK: - 3. Forces

    private var sectionForces: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                titreSectionAvecIcone("Forces de l'adversaire", icone: "bolt.fill", couleur: PaletteMat.vert)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        forces.append("")
                        sauvegarderForces()
                    }
                } label: {
                    Label("Ajouter", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(GlassButtonStyle())
                .siAutorise(peutModifier)
            }

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
                            .onChange(of: forces[index]) { _, _ in sauvegarderForces() }

                        Button(role: .destructive) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                forces.remove(at: index)
                                sauvegarderForces()
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
        .glassSection()
    }

    // MARK: - 4. Faiblesses

    private var sectionFaiblesses: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                titreSectionAvecIcone("Faiblesses de l'adversaire", icone: "exclamationmark.triangle.fill", couleur: .orange)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        faiblesses.append("")
                        sauvegarderFaiblesses()
                    }
                } label: {
                    Label("Ajouter", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(GlassButtonStyle())
                .siAutorise(peutModifier)
            }

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
                            .onChange(of: faiblesses[index]) { _, _ in sauvegarderFaiblesses() }

                        Button(role: .destructive) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                faiblesses.remove(at: index)
                                sauvegarderFaiblesses()
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
        .glassSection()
    }

    // MARK: - 5. Tendances

    private var sectionTendances: some View {
        VStack(alignment: .leading, spacing: 16) {
            titreSectionAvecIcone("Tendances observées", icone: "chart.line.uptrend.xyaxis", couleur: PaletteMat.bleu)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                champTendance(
                    titre: "Service",
                    icone: "figure.volleyball",
                    texte: $rapport.tendanceService,
                    placeholder: "Ex : Sert principalement zone 1 et 5..."
                )

                champTendance(
                    titre: "Attaque",
                    icone: "flame.fill",
                    texte: $rapport.tendanceAttaque,
                    placeholder: "Ex : Attaque rapide au centre..."
                )

                champTendance(
                    titre: "Réception",
                    icone: "arrow.down.to.line",
                    texte: $rapport.tendanceReception,
                    placeholder: "Ex : Faiblesse en réception zone 6..."
                )

                champTendance(
                    titre: "Bloc",
                    icone: "hand.raised.fill",
                    texte: $rapport.tendanceBloc,
                    placeholder: "Ex : Bloc double sur l'extérieur..."
                )
            }
        }
        .glassSection()
    }

    private func champTendance(titre: String, icone: String, texte: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(titre, systemImage: icone)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PaletteMat.bleu)

            TextEditor(text: texte)
                .frame(minHeight: 80)
                .scrollContentBackground(.hidden)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    if texte.wrappedValue.isEmpty {
                        Text(placeholder)
                            .font(.footnote)
                            .foregroundStyle(PaletteMat.texteTertiaire)
                            .padding(8)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    // MARK: - 6. Stratégies recommandées

    private var sectionStrategies: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                titreSectionAvecIcone("Stratégies recommandées", icone: "lightbulb.fill", couleur: PaletteMat.violet)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        strategies.append(StrategieRecommandee())
                        sauvegarderStrategies()
                    }
                } label: {
                    Label("Ajouter", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(GlassButtonStyle())
                .siAutorise(peutModifier)
            }

            if strategies.isEmpty {
                placeholderVide("Aucune stratégie recommandée", icone: "lightbulb.slash")
            } else {
                ForEach(Array(strategies.enumerated()), id: \.element.id) { index, strategie in
                    carteStrategie(index: index, strategie: strategie)
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
                        .onChange(of: strategies[index].titre) { _, _ in sauvegarderStrategies() }

                    HStack(spacing: 12) {
                        Picker("Priorité", selection: $strategies[index].priorite) {
                            Text("Haute").tag(1)
                            Text("Moyenne").tag(2)
                            Text("Basse").tag(3)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 260)
                        .onChange(of: strategies[index].priorite) { _, _ in sauvegarderStrategies() }

                        Picker("Catégorie", selection: $strategies[index].categorie) {
                            Text("Catégorie").tag("")
                            ForEach(categoriesStrategie, id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(PaletteMat.violet)
                        .onChange(of: strategies[index].categorie) { _, _ in sauvegarderStrategies() }
                    }
                }

                Spacer()

                Button(role: .destructive) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        strategies.remove(at: index)
                        sauvegarderStrategies()
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
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    if strategies[index].description.isEmpty {
                        Text("Description de la stratégie...")
                            .font(.footnote)
                            .foregroundStyle(PaletteMat.texteTertiaire)
                            .padding(8)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .allowsHitTesting(false)
                    }
                }
                .onChange(of: strategies[index].description) { _, _ in sauvegarderStrategies() }
        }
        .padding(12)
        .glassCard(teinte: PaletteMat.violet, cornerRadius: 14, ombre: true)
    }

    // MARK: - 7. Notes générales

    private var sectionNotes: some View {
        VStack(alignment: .leading, spacing: 12) {
            titreSectionAvecIcone("Notes générales", icone: "note.text", couleur: PaletteMat.texteSecondaire)

            TextEditor(text: $rapport.notes)
                .frame(minHeight: 120)
                .scrollContentBackground(.hidden)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    if rapport.notes.isEmpty {
                        Text("Notes supplémentaires sur l'adversaire, le contexte du match, les enjeux...")
                            .font(.footnote)
                            .foregroundStyle(PaletteMat.texteTertiaire)
                            .padding(8)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .allowsHitTesting(false)
                    }
                }
        }
        .glassSection()
    }

    // MARK: - Composants réutilisables

    private func titreSectionAvecIcone(_ titre: String, icone: String, couleur: Color) -> some View {
        Label(titre, systemImage: icone)
            .font(.title3.weight(.semibold))
            .foregroundStyle(couleur)
            .symbolRenderingMode(.hierarchical)
    }

    private func placeholderVide(_ texte: String, icone: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icone)
                .font(.title3)
                .foregroundStyle(PaletteMat.texteTertiaire)
            Text(texte)
                .font(.subheadline)
                .foregroundStyle(PaletteMat.texteTertiaire)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func etoilesMenace(niveau: Int, onTap: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { etoile in
                Image(systemName: etoile <= niveau ? "star.fill" : "star")
                    .font(.caption)
                    .foregroundStyle(etoile <= niveau ? .orange : PaletteMat.texteTertiaire)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            onTap(etoile)
                        }
                    }
            }
        }
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

    // MARK: - Sauvegarde

    private func sauvegarderJoueurs() {
        rapport.joueurs = joueurs
    }

    private func sauvegarderForces() {
        rapport.forces = forces
    }

    private func sauvegarderFaiblesses() {
        rapport.faiblesses = faiblesses
    }

    private func sauvegarderStrategies() {
        rapport.strategies = strategies
    }
}
