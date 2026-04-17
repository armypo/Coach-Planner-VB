//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Détail d'un joueur — infos, statistiques volleyball complètes, présences, suivi muscu, tests physiques (Liquid Glass)
struct JoueurDetailView: View {
    @Bindable var joueur: JoueurEquipe

    @Environment(AuthService.self) private var authService
    @Environment(\.modelContext) private var modelContext
    @State private var afficherEdition = false
    @State private var afficherMotDePasse = false
    @State private var afficherConfirmationReinit = false
    @State private var motDePasseTemporaire: String?
    @Query private var toutesPresences: [Presence]

    // Présences de ce joueur
    private var presencesJoueur: [Presence] {
        toutesPresences.filter { $0.joueurID == joueur.id }
    }

    private var nbPresences: Int {
        presencesJoueur.filter(\.estPresent).count
    }

    private var nbAbsences: Int {
        presencesJoueur.filter { !$0.estPresent }.count
    }

    private var tauxPresence: Double {
        let total = nbPresences + nbAbsences
        guard total > 0 else { return 0 }
        return Double(nbPresences) / Double(total) * 100
    }

    /// Taille en pieds
    private var tailleFormatee: String {
        guard joueur.taille > 0 else { return "—" }
        let totalPouces = Int(round(Double(joueur.taille) / 2.54))
        let pieds = totalPouces / 12
        let pouces = totalPouces % 12
        return "\(pieds)'\(pouces)\""
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                enteteJoueur
                if authService.utilisateurConnecte?.role.peutGererEquipe ?? false {
                    sectionIdentifiants
                }
                sectionResume
                sectionPresencesEvals
                JoueurSuiviMuscuSection(joueur: joueur)
                // Bouton évolution stats
                NavigationLink {
                    EvolutionJoueurView(joueur: joueur)
                } label: {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title3)
                            .foregroundStyle(PaletteMat.bleu)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Évolution des statistiques")
                                .font(.subheadline.weight(.semibold))
                            Text("Graphiques par match")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .glassSection()
                }
                .buttonStyle(.plain)

                // Bouton comparaison vs équipe
                NavigationLink {
                    ComparaisonView(joueur: joueur)
                } label: {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .font(.title3)
                            .foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Comparaison vs équipe")
                                .font(.subheadline.weight(.semibold))
                            Text("Stats joueur vs moyenne")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .glassSection()
                }
                .buttonStyle(.plain)

                // Objectifs individuels
                ObjectifsJoueurView(joueur: joueur)
                    .padding(LiquidGlassKit.espaceMD)
                    .glassSection()

                sectionAttaque
                sectionService
                sectionBloc
                sectionReception
                sectionJeu
                if authService.utilisateurConnecte?.role.peutGererEquipe ?? false {
                    sectionEditionStats
                    sectionNotes
                }
            }
            .padding()
        }
        .navigationTitle(joueur.nomComplet)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if authService.utilisateurConnecte?.role.peutGererEquipe ?? false {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            afficherEdition = true
                        } label: {
                            Label("Modifier", systemImage: "pencil")
                        }

                        Button {
                            joueur.estActif.toggle()
                        } label: {
                            Label(joueur.estActif ? "Marquer inactif" : "Marquer actif",
                                  systemImage: joueur.estActif ? "person.crop.circle.badge.minus" : "person.crop.circle.badge.checkmark")
                        }

                        Button(role: .destructive) {
                            reinitialiserStats()
                        } label: {
                            Label("Réinitialiser stats", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $afficherEdition) {
            EditionJoueurView(joueur: joueur)
        }
        .alert("Réinitialiser le mot de passe", isPresented: $afficherConfirmationReinit) {
            Button("Annuler", role: .cancel) { }
            Button("Réinitialiser", role: .destructive) {
                reinitialiserMotDePasseJoueur()
            }
        } message: {
            Text("Le mot de passe de \(joueur.prenom) sera réinitialisé à « volleyball123 ». Communiquez-lui le nouveau mot de passe.")
        }
        .alert("Nouveau mot de passe", isPresented: Binding(
            get: { motDePasseTemporaire != nil },
            set: { if !$0 { motDePasseTemporaire = nil } }
        )) {
            Button("OK") { motDePasseTemporaire = nil }
        } message: {
            Text("Mot de passe réinitialisé à : volleyball123\n\nCommuniquez ce mot de passe à \(joueur.prenom).")
        }
    }

    // MARK: - En-tête
    private var enteteJoueur: some View {
        HStack(spacing: 20) {
            ZStack {
                if let photoData = joueur.photoData, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(joueur.poste.couleur, lineWidth: 3))
                } else {
                    Circle()
                        .fill(joueur.poste.couleur.opacity(0.1))
                        .frame(width: 80, height: 80)
                        .overlay(
                            VStack(spacing: 2) {
                                Text("#\(joueur.numero)")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundStyle(joueur.poste.couleur)
                                Text(joueur.poste.abreviation)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(joueur.poste.couleur.opacity(0.7))
                            }
                        )
                }
                // Badge position
                Text(joueur.poste.abreviation)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(joueur.poste.couleur, in: Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .offset(x: 28, y: 28)
            }
            .frame(width: 80, height: 80)

            VStack(alignment: .leading, spacing: 6) {
                Text(joueur.nomComplet)
                    .font(.title2.weight(.bold))

                HStack(spacing: 12) {
                    Label(joueur.poste.rawValue, systemImage: joueur.poste.icone)
                        .font(.subheadline)
                        .foregroundStyle(joueur.poste.couleur)

                    if joueur.taille > 0 {
                        Label(tailleFormatee, systemImage: "ruler")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if !joueur.estActif {
                    Text("Inactif")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.red.opacity(0.1), in: Capsule())
                }
            }

            Spacer()
        }
        .glassSection()
    }

    // MARK: - Identifiants (visible coach uniquement)
    private var sectionIdentifiants: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Identifiants", systemImage: "person.badge.key.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PaletteMat.bleu)

            // Identifiant
            HStack {
                Text("Identifiant")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(joueur.identifiant.isEmpty ? "Non défini" : joueur.identifiant)
                    .font(.subheadline.weight(.semibold).monospaced())
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                if !joueur.identifiant.isEmpty {
                    Button {
                        UIPasteboard.general.string = joueur.identifiant
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit))

            // Mot de passe
            HStack {
                Text("Mot de passe")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    afficherConfirmationReinit = true
                } label: {
                    Label("Réinitialiser", systemImage: "arrow.counterclockwise")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit))

            Text("Utilisez « Réinitialiser » pour définir un mot de passe temporaire à communiquer au joueur.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .glassSection()
    }

    private func reinitialiserMotDePasseJoueur() {
        let nouveauMdp = "volleyball123"
        let sel = authService.genererSel()
        let hash = authService.hashMotDePasse(nouveauMdp, sel: sel)

        // Mettre à jour le JoueurEquipe
        joueur.motDePasseHash = hash
        joueur.sel = sel

        // Mettre à jour l'Utilisateur lié si existant
        if let utilisateurID = joueur.utilisateurID {
            let descriptor = FetchDescriptor<Utilisateur>(
                predicate: #Predicate { $0.id == utilisateurID }
            )
            if let utilisateur = try? modelContext.fetch(descriptor).first {
                utilisateur.motDePasseHash = hash
                utilisateur.sel = sel
                utilisateur.iterations = AuthService.iterationsParDefaut
            }
        }

        try? modelContext.save()
        motDePasseTemporaire = nouveauMdp
    }

    // MARK: - Résumé général
    private var sectionResume: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Résumé")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()), GridItem(.flexible()),
                GridItem(.flexible()), GridItem(.flexible())
            ], spacing: 12) {
                statCard("Matchs", valeur: "\(joueur.matchsJoues)", icone: "sportscourt", couleur: .blue)
                statCard("Sets", valeur: "\(joueur.setsJoues)", icone: "number", couleur: .indigo)
                statCard("Points", valeur: "\(joueur.pointsCalcules)", icone: "star.fill", couleur: .orange)
                statCard("Pts perdus", valeur: "\(joueur.pointsPerdus)", icone: "arrow.down.circle", couleur: .red.opacity(0.7))
            }

            if joueur.setsJoues > 0 {
                HStack(spacing: 16) {
                    statParSet("Pts/set", valeur: joueur.pointsParSet, couleur: .orange)
                    statParSet("Kills/set", valeur: joueur.killsParSet, couleur: .green)
                    statParSet("Aces/set", valeur: joueur.acesParSet, couleur: .yellow)
                    statParSet("Blocs/set", valeur: joueur.blocsParSet, couleur: .red)
                }
                .padding(.top, 4)
            }
        }
        .glassSection()
    }

    // MARK: - Présences
    private var sectionPresencesEvals: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Présences")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                miniStat(label: "Présences", valeur: "\(nbPresences)", couleur: .green)
                miniStat(label: "Absences", valeur: "\(nbAbsences)", couleur: .red)
                miniStat(label: "Taux", valeur: tauxPresence > 0 ? String(format: "%.0f%%", tauxPresence) : "—",
                         couleur: tauxPresence >= 80 ? .green : (tauxPresence >= 60 ? .orange : .red))
            }
        }
        .glassSection()
    }

    // MARK: - Attaque
    private var sectionAttaque: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Attaque", systemImage: "arrow.up.right")
                .font(.headline)
                .foregroundStyle(.green)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                statCard("Kills", valeur: "\(joueur.attaquesReussies)", icone: "flame.fill", couleur: .green)
                statCard("Erreurs", valeur: "\(joueur.erreursAttaque)", icone: "xmark.circle", couleur: .red)
                statCard("Tentatives", valeur: "\(joueur.attaquesTotales)", icone: "arrow.up.forward", couleur: .blue)
                statCard("Hitting %",
                         valeur: joueur.attaquesTotales > 0 ? String(format: "%.3f", joueur.pourcentageAttaque) : "—",
                         icone: "percent", couleur: couleurPourcentageAttaque)
            }

            if joueur.attaquesTotales > 0 {
                barreProgression(
                    label: "(Kills - Erreurs) / Tentatives",
                    valeur: max(0, joueur.pourcentageAttaque),
                    maximum: 0.5,
                    couleur: couleurPourcentageAttaque
                )
            }
        }
        .glassSection()
    }

    // MARK: - Service
    private var sectionService: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Service", systemImage: "circle.dotted")
                .font(.headline)
                .foregroundStyle(.yellow)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                statCard("Aces", valeur: "\(joueur.aces)", icone: "bolt.fill", couleur: .yellow)
                statCard("Erreurs", valeur: "\(joueur.erreursService)", icone: "xmark.circle", couleur: .red)
                statCard("Tentatives", valeur: "\(joueur.servicesTotaux)", icone: "circle.dotted", couleur: .blue)
            }

            if joueur.servicesTotaux > 0 {
                let tauxAce = Double(joueur.aces) / Double(joueur.servicesTotaux) * 100
                let tauxErreur = Double(joueur.erreursService) / Double(joueur.servicesTotaux) * 100
                HStack(spacing: 16) {
                    statParSet("Taux ace", valeur: tauxAce / 100, format: "%.0f%%", brut: tauxAce, couleur: .yellow)
                    statParSet("Taux erreur", valeur: tauxErreur / 100, format: "%.0f%%", brut: tauxErreur, couleur: .red)
                }
            }
        }
        .glassSection()
    }

    // MARK: - Bloc
    private var sectionBloc: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Bloc", systemImage: "hand.raised.fill")
                .font(.headline)
                .foregroundStyle(.red)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                statCard("Seuls", valeur: "\(joueur.blocsSeuls)", icone: "hand.raised.fill", couleur: .red)
                statCard("Assistés", valeur: "\(joueur.blocsAssistes)", icone: "hand.raised.fingers.spread.fill", couleur: .orange)
                statCard("Total", valeur: String(format: "%.1f", joueur.blocsTotaux), icone: "sum", couleur: .purple)
                statCard("Erreurs", valeur: "\(joueur.erreursBloc)", icone: "xmark.circle", couleur: .red.opacity(0.6))
            }
        }
        .glassSection()
    }

    // MARK: - Réception
    private var sectionReception: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Réception", systemImage: "figure.volleyball")
                .font(.headline)
                .foregroundStyle(.purple)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                statCard("Réussies", valeur: "\(joueur.receptionsReussies)", icone: "checkmark.circle", couleur: .green)
                statCard("Erreurs", valeur: "\(joueur.erreursReception)", icone: "xmark.circle", couleur: .red)
                statCard("Totales", valeur: "\(joueur.receptionsTotales)", icone: "arrow.down.forward", couleur: .blue)
                statCard("Eff. %",
                         valeur: joueur.receptionsTotales > 0 ? String(format: "%.0f%%", joueur.efficaciteReception) : "—",
                         icone: "percent", couleur: .purple)
            }

            if joueur.receptionsTotales > 0 {
                barreProgression(
                    label: "Réception positive",
                    valeur: joueur.pourcentageReceptionPositive / 100,
                    maximum: 1.0,
                    couleur: .purple
                )
            }
        }
        .glassSection()
    }

    // MARK: - Jeu (Passes & Manchettes)
    private var sectionJeu: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Jeu", systemImage: "hands.and.sparkles.fill")
                .font(.headline)
                .foregroundStyle(.cyan)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                statCard("Passes déc.", valeur: "\(joueur.passesDecisives)", icone: "arrow.turn.up.right", couleur: .cyan)
                statCard("Manchettes", valeur: "\(joueur.manchettes)", icone: "figure.volleyball", couleur: .teal)
            }

            if joueur.setsJoues > 0 {
                HStack(spacing: 16) {
                    statParSet("Passes/set", valeur: joueur.passesParSet, couleur: .cyan)
                    statParSet("Manch./set", valeur: joueur.manchettesParSet, couleur: .teal)
                }
            }
        }
        .glassSection()
    }

    // MARK: - Édition rapide stats
    private var sectionEditionStats: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ajouter des statistiques")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            // Général
            groupeStat(titre: "Général", couleur: .blue) {
                HStack(spacing: 8) {
                    statStepper("Matchs", valeur: $joueur.matchsJoues)
                    statStepper("Sets", valeur: $joueur.setsJoues)
                }
            }

            // Attaque
            groupeStat(titre: "Attaque", couleur: .green) {
                HStack(spacing: 8) {
                    statStepper("Kills", valeur: $joueur.attaquesReussies)
                    statStepper("Err. att.", valeur: $joueur.erreursAttaque)
                    statStepper("Tent. att.", valeur: $joueur.attaquesTotales)
                }
            }

            // Service
            groupeStat(titre: "Service", couleur: .yellow) {
                HStack(spacing: 8) {
                    statStepper("Aces", valeur: $joueur.aces)
                    statStepper("Err. serv.", valeur: $joueur.erreursService)
                    statStepper("Tent. serv.", valeur: $joueur.servicesTotaux)
                }
            }

            // Bloc
            groupeStat(titre: "Bloc", couleur: .red) {
                HStack(spacing: 8) {
                    statStepper("Seuls", valeur: $joueur.blocsSeuls)
                    statStepper("Assistés", valeur: $joueur.blocsAssistes)
                    statStepper("Err. bloc", valeur: $joueur.erreursBloc)
                }
            }

            // Réception
            groupeStat(titre: "Réception", couleur: .purple) {
                HStack(spacing: 8) {
                    statStepper("Réc. +", valeur: $joueur.receptionsReussies)
                    statStepper("Err. réc.", valeur: $joueur.erreursReception)
                    statStepper("Tent. réc.", valeur: $joueur.receptionsTotales)
                }
            }

            // Jeu
            groupeStat(titre: "Jeu", couleur: .cyan) {
                HStack(spacing: 8) {
                    statStepper("Passes déc.", valeur: $joueur.passesDecisives)
                    statStepper("Manchettes", valeur: $joueur.manchettes)
                }
            }
        }
        .glassSection()
    }

    // MARK: - Notes
    private var sectionNotes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)
            TextEditor(text: $joueur.notes)
                .font(.callout)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .overlay(alignment: .topLeading) {
                    if joueur.notes.isEmpty {
                        Text("Notes sur le joueur…")
                            .foregroundStyle(.tertiary)
                            .font(.callout)
                            .padding(.leading, 4)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                }
        }
        .glassSection()
    }

    // MARK: - Composants réutilisables

    private func miniStat(label: String, valeur: String, couleur: Color) -> some View {
        VStack(spacing: 4) {
            Text(valeur)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(couleur)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(couleur.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func statCard(_ titre: String, valeur: String, icone: String, couleur: Color) -> some View {
        CarteChiffreCle(titre: titre, valeur: valeur, icone: icone, couleur: couleur)
    }

    private func statParSet(_ label: String, valeur: Double, format: String = "%.1f", brut: Double? = nil, couleur: Color) -> some View {
        VStack(spacing: 2) {
            Text(String(format: format, brut ?? valeur))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(couleur)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func barreProgression(label: String, valeur: Double, maximum: Double, couleur: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.08))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(couleur)
                        .frame(width: max(0, geo.size.width * min(valeur / maximum, 1.0)))
                }
            }
            .frame(height: 8)
        }
    }

    private func groupeStat(titre: String, couleur: Color, @ViewBuilder contenu: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titre)
                .font(.caption.weight(.semibold))
                .foregroundStyle(couleur)
            contenu()
        }
    }

    private func statStepper(_ label: String, valeur: Binding<Int>) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(spacing: 4) {
                Button { if valeur.wrappedValue > 0 { valeur.wrappedValue -= 1 } } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                Text("\(valeur.wrappedValue)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .frame(minWidth: 24)
                Button { valeur.wrappedValue += 1 } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.green)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var couleurPourcentageAttaque: Color {
        let pct = joueur.pourcentageAttaque
        if pct >= 0.350 { return .green }
        if pct >= 0.200 { return .orange }
        return .red
    }

    private func reinitialiserStats() {
        joueur.matchsJoues = 0
        joueur.setsJoues = 0
        joueur.attaquesReussies = 0
        joueur.erreursAttaque = 0
        joueur.attaquesTotales = 0
        joueur.aces = 0
        joueur.erreursService = 0
        joueur.servicesTotaux = 0
        joueur.blocsSeuls = 0
        joueur.blocsAssistes = 0
        joueur.erreursBloc = 0
        joueur.receptionsReussies = 0
        joueur.erreursReception = 0
        joueur.receptionsTotales = 0
        joueur.passesDecisives = 0
        joueur.manchettes = 0
        // Anciens champs
        joueur.pointsMarques = 0
        joueur.blocsMarques = 0
        joueur.services = 0
        joueur.erreurs = 0
    }
}
