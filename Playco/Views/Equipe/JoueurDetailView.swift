//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Détail d'un joueur — infos, statistiques volleyball complètes, présences, suivi muscu, tests physiques (Liquid Glass)
struct JoueurDetailView: View {
    @Bindable var joueur: JoueurEquipe

    /// Onglets d'analyse de la fiche joueur (2.3 refonte — segmenté visible
    /// au lieu de NavigationLinks enfouis).
    enum OngletAnalyseJoueur: String, CaseIterable {
        case statistiques = "Statistiques"
        case evolution = "Évolution"
        case comparaison = "Comparaison"
    }

    @Environment(AuthService.self) private var authService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @State private var afficherEdition = false
    @State private var ongletAnalyse: OngletAnalyseJoueur = .statistiques
    /// Code d'invitation de l'Utilisateur lié — cache @State (évite un fetch par render)
    @State private var codeInvitationJoueur: String?
    @Query private var toutesPresences: [Presence]
    @Query private var tousStatsMatch: [StatsMatch]
    @Query private var toutesActionsRallye: [ActionRallye]
    @Query private var tousPointsMatch: [PointMatch]
    @State private var noteReception: Double = 0
    @State private var nbReceptionsNotees = 0

    /// Vrai si des stats de match existent → le cumul carrière est dérivé.
    private var aDesStatsDeMatch: Bool {
        tousStatsMatch.contains { $0.joueurID == joueur.id }
    }

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
            VStack(spacing: LiquidGlassKit.espaceLG) {
                enteteJoueur
                if authService.utilisateurConnecte?.role.peutGererEquipe ?? false {
                    sectionIdentifiants
                    sectionDisponibiliteConsentement
                }
                sectionResume
                sectionPresencesEvals
                JoueurSuiviMuscuSection(joueur: joueur)

                // Analyses du joueur — segmenté (plus de liens enfouis)
                Picker("Analyse", selection: $ongletAnalyse) {
                    ForEach(OngletAnalyseJoueur.allCases, id: \.self) { onglet in
                        Text(onglet.rawValue).tag(onglet)
                    }
                }
                .pickerStyle(.segmented)

                switch ongletAnalyse {
                case .statistiques:
                    // Objectifs individuels
                    ObjectifsJoueurView(joueur: joueur)
                        .padding(LiquidGlassKit.espaceMD)
                        .glassSection()

                    sectionAttaque
                    sectionService
                    sectionBloc
                    sectionReception
                    sectionJeu
                case .evolution:
                    EvolutionJoueurView(joueur: joueur, estIncorporee: true)
                case .comparaison:
                    ComparaisonView(joueur: joueur, estIncorporee: true)
                }

                if authService.utilisateurConnecte?.role.peutGererEquipe ?? false,
                   ongletAnalyse == .statistiques {
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
                    .bloqueSiNonPayant(source: "gestion_joueur")
                }
            }
        }
        .sheet(isPresented: $afficherEdition) {
            EditionJoueurView(joueur: joueur)
        }
        .onAppear { chargerCodeInvitation() }
        .onChange(of: joueur.utilisateurID) { chargerCodeInvitation() }
    }

    // MARK: - En-tête
    private var enteteJoueur: some View {
        HStack(spacing: LiquidGlassKit.espaceMD) {
            ZStack {
                if let photoData = joueur.photoData, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: ConstantesFicheJoueur.tailleAvatar,
                               height: ConstantesFicheJoueur.tailleAvatar)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(joueur.poste.couleur,
                                                 lineWidth: ConstantesFicheJoueur.bordureAvatar))
                } else {
                    Circle()
                        .fill(joueur.poste.couleur.opacity(LiquidGlassKit.badgeFond))
                        .frame(width: ConstantesFicheJoueur.tailleAvatar,
                               height: ConstantesFicheJoueur.tailleAvatar)
                        .overlay(
                            VStack(spacing: 2) {
                                Text("#\(joueur.numero)")
                                    .font(TypographieStats.valeurCarte)
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
                    .frame(width: ConstantesFicheJoueur.tailleBadgePoste,
                           height: ConstantesFicheJoueur.tailleBadgePoste)
                    .background(joueur.poste.couleur, in: Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .offset(x: ConstantesFicheJoueur.decalageBadgePoste,
                            y: ConstantesFicheJoueur.decalageBadgePoste)
            }
            .frame(width: ConstantesFicheJoueur.tailleAvatar,
                   height: ConstantesFicheJoueur.tailleAvatar)

            VStack(alignment: .leading, spacing: LiquidGlassKit.espaceXS) {
                Text(joueur.nomComplet)
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(spacing: LiquidGlassKit.espaceSM) {
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
                        .foregroundStyle(PaletteMat.negatif)
                        .padding(.horizontal, LiquidGlassKit.espaceSM)
                        .padding(.vertical, 2)
                        .background(PaletteMat.negatif.opacity(LiquidGlassKit.badgeFond), in: Capsule())
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

            // Code d'invitation (SIWA : remplace le mot de passe — le joueur
            // rejoint l'équipe avec Sign in with Apple + ce code)
            HStack {
                Text("Code d'invitation")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if let code = codeInvitationJoueur, !code.isEmpty {
                    Text(code)
                        .font(.subheadline.weight(.semibold).monospaced())
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                    Button {
                        UIPasteboard.general.string = code
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Non défini")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit))

            // 2.3 — QR du lien universel : scanner = jonction pré-remplie.
            if let code = codeInvitationJoueur, !code.isEmpty,
               let qr = LienInvitation.genererQR(
                   codeEquipe: joueur.codeEquipe.isEmpty ? codeEquipeActif : joueur.codeEquipe,
                   codeInvitation: code) {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(uiImage: qr)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 132, height: 132)
                            .accessibilityLabel("Code QR d'invitation de \(joueur.prenom)")
                        Text("Scanner pour rejoindre l'équipe")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            Text("Le joueur se connecte avec Sign in with Apple : communique-lui le code d'équipe et ce code d'invitation — ou fais-lui scanner le code QR.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .glassSection()
    }

    // MARK: - Disponibilité & consentement parental (2.2.b)

    private var sectionDisponibiliteConsentement: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Disponibilité", systemImage: "figure.walk.motion")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PaletteMat.vert)

            Picker("Statut", selection: Binding(
                get: { joueur.statutDisponibilite },
                set: {
                    joueur.statutDisponibilite = $0
                    joueur.dateModification = Date() // sync partagée (revue 2.2.b)
                }
            )) {
                ForEach(StatutDisponibilite.allCases) { statut in
                    Text(statut.libelle).tag(statut)
                }
            }
            .pickerStyle(.segmented)

            if !joueur.estDisponible {
                Text("Un joueur \(joueur.statutDisponibilite.libelle.lowercased()) est grisé dans la composition et les présences ; ses séances de musculation sont suspendues.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Revue 2.2.b : seul un coach (.admin/.coach au sens compte) atteste —
            // pas l'adulte assistant que le blocage DM est censé contraindre.
            if (joueur.estMineur || joueur.dateNaissance == nil),
               let role = authService.utilisateurConnecte?.role, role == .admin || role == .coach {
                Divider()

                Label("Consentement parental", systemImage: "figure.and.child.holdinghands")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PaletteMat.bleu)

                HStack {
                    if joueur.consentementParentalAtteste {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(joueur.attesteParNom.isEmpty ? "Attesté par le coach" : "Attesté par \(joueur.attesteParNom)")
                                .font(.caption.weight(.semibold))
                            if let date = joueur.dateAttestationConsentement {
                                Text(date, format: .dateTime.day().month().year())
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button("Retirer", role: .destructive) {
                            joueur.consentementParentalAtteste = false
                            joueur.dateAttestationConsentement = nil
                            joueur.dateModification = Date()
                        }
                        .font(.caption)
                    } else {
                        Text("Requis pour les messages privés avec un mineur")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Attester") {
                            joueur.consentementParentalAtteste = true
                            joueur.dateAttestationConsentement = Date()
                            joueur.attesteParNom = authService.utilisateurConnecte?.nomComplet ?? ""
                            joueur.dateModification = Date()
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(12)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit))

                ShareLink(item: AppConstants.urlPolitiqueConfidentialite) {
                    Label("Envoyer l'avis de confidentialité aux parents", systemImage: "square.and.arrow.up")
                        .font(.caption)
                }

                Text("En attestant, tu confirmes avoir obtenu le consentement d'un parent ou tuteur pour ce joueur mineur (collecte de données et messagerie).")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .glassSection()
    }

    /// Charge le code d'invitation de l'Utilisateur lié à ce joueur (nil si non lié).
    private func chargerCodeInvitation() {
        guard let utilisateurID = joueur.utilisateurID else {
            codeInvitationJoueur = nil
            return
        }
        let descriptor = FetchDescriptor<Utilisateur>(
            predicate: #Predicate { $0.id == utilisateurID }
        )
        codeInvitationJoueur = try? modelContext.fetch(descriptor).first?.codeInvitation
    }

    // MARK: - Résumé général
    private var sectionResume: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceMD) {
            EnTeteSection(titre: "Résumé")

            LazyVGrid(columns: [
                GridItem(.flexible()), GridItem(.flexible()),
                GridItem(.flexible()), GridItem(.flexible())
            ], spacing: LiquidGlassKit.espaceSM + 4) {
                CarteMetrique(titre: "Matchs", valeur: "\(joueur.matchsJoues)",
                              teinte: PaletteMat.bleu)
                CarteMetrique(titre: "Sets", valeur: "\(joueur.setsJoues)",
                              teinte: PaletteMat.violet)
                CarteMetrique(titre: "Points", valeur: "\(joueur.pointsCalcules)",
                              teinte: PaletteMat.orange,
                              definition: definitionMetrique("Pts"))
                CarteMetrique(titre: "Pts perdus", valeur: "\(joueur.pointsPerdus)",
                              teinte: PaletteMat.negatif)
            }

            if joueur.setsJoues > 0 {
                HStack(spacing: LiquidGlassKit.espaceMD) {
                    statParSet("Pts/set", valeur: joueur.pointsParSet, couleur: PaletteMat.orange)
                    statParSet("Kills/set", valeur: joueur.killsParSet, couleur: PaletteMat.positif)
                    statParSet("Aces/set", valeur: joueur.acesParSet, couleur: PaletteMat.attention)
                    statParSet("Blocs/set", valeur: joueur.blocsParSet, couleur: PaletteMat.violet)
                }
                .padding(.top, LiquidGlassKit.espaceXS)
            }
        }
        .glassSection()
    }

    // MARK: - Présences
    private var sectionPresencesEvals: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Présences")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                      spacing: LiquidGlassKit.espaceSM + 4) {
                miniStat(label: "Présences", valeur: "\(nbPresences)", couleur: PaletteMat.positif)
                miniStat(label: "Absences", valeur: "\(nbAbsences)", couleur: PaletteMat.negatif)
                miniStat(label: "Taux",
                         valeur: tauxPresence > 0
                             ? FormatMetriques.pourcentage(tauxPresence / 100, decimales: 0) : "—",
                         couleur: couleurTauxPresence)
            }
        }
        .glassSection()
    }

    // MARK: - Attaque
    private var sectionAttaque: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM + 4) {
            EnTeteSection(titre: "Attaque")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4),
                      spacing: LiquidGlassKit.espaceSM + 4) {
                CarteMetrique(titre: "Kills", valeur: "\(joueur.attaquesReussies)",
                              teinte: PaletteMat.positif)
                CarteMetrique(titre: "Erreurs", valeur: "\(joueur.erreursAttaque)",
                              teinte: PaletteMat.negatif)
                CarteMetrique(titre: "Tentatives", valeur: "\(joueur.attaquesTotales)",
                              teinte: PaletteMat.bleu)
                CarteMetrique(titre: "Rendement",
                              valeur: joueur.attaquesTotales > 0
                                  ? FormatMetriques.hittingVolley(joueur.pourcentageAttaque) : "—",
                              teinte: couleurPourcentageAttaque,
                              definition: definitionMetrique("Rend."))
            }

            if joueur.attaquesTotales > 0 {
                barreProgression(
                    label: "(Kills − Erreurs) ÷ Tentatives — .300 et plus : excellent",
                    valeur: min(max(0, joueur.pourcentageAttaque), 1.0),
                    maximum: 1.0,
                    couleur: couleurPourcentageAttaque,
                    repere: RepereNiveau(valeur: ConstantesFicheJoueur.repereRendementAttaque,
                                         label: ".300")
                )
            }
        }
        .glassSection()
    }

    // MARK: - Service
    private var sectionService: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM + 4) {
            EnTeteSection(titre: "Service")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3),
                      spacing: LiquidGlassKit.espaceSM + 4) {
                CarteMetrique(titre: "Aces", valeur: "\(joueur.aces)",
                              teinte: PaletteMat.positif,
                              definition: definitionMetrique("AC"))
                CarteMetrique(titre: "Erreurs", valeur: "\(joueur.erreursService)",
                              teinte: PaletteMat.negatif)
                CarteMetrique(titre: "Tentatives", valeur: "\(joueur.servicesTotaux)",
                              teinte: PaletteMat.bleu)
            }

            if joueur.servicesTotaux > 0 {
                let tauxAce = Double(joueur.aces) / Double(joueur.servicesTotaux)
                let tauxErreur = Double(joueur.erreursService) / Double(joueur.servicesTotaux)
                HStack(spacing: LiquidGlassKit.espaceMD) {
                    statValeur("Taux ace",
                               valeur: FormatMetriques.pourcentage(tauxAce, decimales: 0),
                               couleur: PaletteMat.positif)
                    statValeur("Taux erreur",
                               valeur: FormatMetriques.pourcentage(tauxErreur, decimales: 0),
                               couleur: PaletteMat.negatif)
                }
            }
        }
        .glassSection()
    }

    // MARK: - Bloc
    private var sectionBloc: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM + 4) {
            EnTeteSection(titre: "Bloc")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4),
                      spacing: LiquidGlassKit.espaceSM + 4) {
                CarteMetrique(titre: "Seuls", valeur: "\(joueur.blocsSeuls)",
                              teinte: PaletteMat.positif,
                              definition: definitionMetrique("BS"))
                CarteMetrique(titre: "Assistés", valeur: "\(joueur.blocsAssistes)",
                              teinte: PaletteMat.positif,
                              definition: definitionMetrique("BA"))
                CarteMetrique(titre: "Total", valeur: FormatMetriques.points(joueur.blocsTotaux),
                              teinte: PaletteMat.violet)
                CarteMetrique(titre: "Erreurs", valeur: "\(joueur.erreursBloc)",
                              teinte: PaletteMat.negatif)
            }
        }
        .glassSection()
    }

    // MARK: - Réception
    private var sectionReception: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM + 4) {
            EnTeteSection(titre: "Réception")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4),
                      spacing: LiquidGlassKit.espaceSM + 4) {
                CarteMetrique(titre: "Réussies", valeur: "\(joueur.receptionsReussies)",
                              teinte: PaletteMat.positif)
                CarteMetrique(titre: "Erreurs", valeur: "\(joueur.erreursReception)",
                              teinte: PaletteMat.negatif)
                CarteMetrique(titre: "Totales", valeur: "\(joueur.receptionsTotales)",
                              teinte: PaletteMat.bleu)
                // efficaciteReception est en échelle 0-100 (convention modèle) →
                // fraction 0-1 pour FormatMetriques (D2).
                CarteMetrique(titre: "Réc. eff.",
                              valeur: joueur.receptionsTotales > 0
                                  ? FormatMetriques.pourcentage(joueur.efficaciteReception / 100,
                                                                decimales: 0) : "—",
                              teinte: PaletteMat.violet,
                              definition: definitionMetrique("Réc. eff."))
            }

            if joueur.receptionsTotales > 0 {
                barreProgression(
                    label: "Réception positive",
                    valeur: joueur.pourcentageReceptionPositive / 100,
                    maximum: 1.0,
                    couleur: PaletteMat.violet
                )
            }

            // Note de réception 0-3 (3.2 refonte — qualité déjà saisie en live)
            if nbReceptionsNotees > 0 {
                CarteMetrique(
                    titre: "Note de réception",
                    valeur: "\(FormatMetriques.note(noteReception)) / 3",
                    sousTitre: "\(nbReceptionsNotees) réceptions notées en live",
                    teinte: PaletteMat.violet,
                    definition: definitionMetrique("Note réc.")
                )
            }
        }
        .glassSection()
        .onAppear { recalculerNoteReception() }
        .onChange(of: toutesActionsRallye.count) { _, _ in recalculerNoteReception() }
    }

    /// Note de réception carrière (0-3) : qualités des réceptions de rallye
    /// + erreurs de réception (PointMatch) comptées 0 — cache @State.
    private func recalculerNoteReception() {
        let qualites = toutesActionsRallye
            .filter { $0.joueurID == joueur.id && $0.typeAction == .reception }
            .map(\.qualite)
        let erreurs = tousPointsMatch
            .filter { $0.joueurID == joueur.id && $0.typeAction == .erreurReception }
            .map { _ in 0 }
        let toutes = qualites + erreurs
        nbReceptionsNotees = toutes.count
        noteReception = MetriquesVolley.noteReception(qualites: toutes)
    }

    // MARK: - Jeu (Passes & Manchettes)
    private var sectionJeu: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM + 4) {
            EnTeteSection(titre: "Jeu")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2),
                      spacing: LiquidGlassKit.espaceSM + 4) {
                CarteMetrique(titre: "Passes déc.", valeur: "\(joueur.passesDecisives)",
                              teinte: PaletteMat.bleu,
                              definition: definitionMetrique("PD"))
                CarteMetrique(titre: "Manchettes", valeur: "\(joueur.manchettes)",
                              teinte: PaletteMat.violet,
                              definition: definitionMetrique("M"))
            }

            if joueur.setsJoues > 0 {
                HStack(spacing: LiquidGlassKit.espaceMD) {
                    statParSet("Passes/set", valeur: joueur.passesParSet, couleur: PaletteMat.bleu)
                    statParSet("Manch./set", valeur: joueur.manchettesParSet, couleur: PaletteMat.violet)
                }
            }
        }
        .glassSection()
    }

    // MARK: - Édition rapide stats
    private var sectionEditionStats: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ajuster les statistiques cumulées")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if aDesStatsDeMatch {
                Label("Ces totaux sont recalculés à partir des matchs saisis. " +
                      "Un ajustement manuel sera écrasé au prochain match enregistré.",
                      systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(PaletteMat.attention)
                    .padding(LiquidGlassKit.espaceSM)
                    .background(PaletteMat.attention.opacity(0.1),
                                in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit))
            }

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

    /// Valeur compacte pré-formatée + libellé (taux, moyennes par set).
    private func statValeur(_ label: String, valeur: String, couleur: Color) -> some View {
        VStack(spacing: 2) {
            Text(valeur)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(couleur)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// Moyenne par set (« 2,3 ») — délègue à statValeur.
    private func statParSet(_ label: String, valeur: Double, couleur: Color) -> some View {
        statValeur(label, valeur: FormatMetriques.note(valeur), couleur: couleur)
    }

    /// Barre de progression avec repère de niveau optionnel (trait vertical
    /// discret + label sous la barre, ex. « .300 » pour le rendement attaque).
    private func barreProgression(label: String, valeur: Double, maximum: Double,
                                  couleur: Color, repere: RepereNiveau? = nil) -> some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceXS) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMini)
                        .fill(Color.primary.opacity(LiquidGlassKit.badgeFond))
                        .frame(height: ConstantesFicheJoueur.hauteurBarre)
                    RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMini)
                        .fill(couleur)
                        .frame(width: max(0, geo.size.width * min(valeur / maximum, 1.0)),
                               height: ConstantesFicheJoueur.hauteurBarre)
                    if let repere {
                        let xRepere = geo.size.width * min(repere.valeur / maximum, 1.0)
                        RoundedRectangle(cornerRadius: ConstantesFicheJoueur.largeurRepere / 2)
                            .fill(.secondary)
                            .frame(width: ConstantesFicheJoueur.largeurRepere,
                                   height: ConstantesFicheJoueur.hauteurRepere)
                            .position(x: xRepere, y: ConstantesFicheJoueur.hauteurBarre / 2)
                        Text(repere.label)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .fixedSize()
                            .position(x: xRepere, y: ConstantesFicheJoueur.centreLabelRepereY)
                    }
                }
            }
            .frame(height: repere == nil ? ConstantesFicheJoueur.hauteurBarre
                                         : ConstantesFicheJoueur.hauteurBarreAvecRepere)
        }
    }

    /// Définition du glossaire par abréviation (popover info des cartes).
    private func definitionMetrique(_ abreviation: String) -> DefinitionMetrique? {
        MetriquesVolley.catalogue.first { $0.abreviation == abreviation }
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
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                Text("\(valeur.wrappedValue)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .frame(minWidth: 24)
                Button { valeur.wrappedValue += 1 } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(PaletteMat.positif)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var couleurTauxPresence: Color {
        if tauxPresence >= ConstantesFicheJoueur.seuilPresenceBon { return PaletteMat.positif }
        if tauxPresence >= ConstantesFicheJoueur.seuilPresenceMoyen { return PaletteMat.attention }
        return PaletteMat.negatif
    }

    private var couleurPourcentageAttaque: Color {
        let rendement = joueur.pourcentageAttaque
        if rendement >= ConstantesFicheJoueur.seuilRendementExcellent { return PaletteMat.positif }
        if rendement >= ConstantesFicheJoueur.seuilRendementCorrect { return PaletteMat.attention }
        return PaletteMat.negatif
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

// MARK: - Support (fiche joueur)

/// Repère de niveau affiché sur une barre de progression
/// (ex. « .300 » = seuil d'excellence du rendement attaque).
private struct RepereNiveau {
    let valeur: Double
    let label: String
}

/// Constantes locales de la fiche joueur — pas de magic numbers dans le body.
private enum ConstantesFicheJoueur {
    // En-tête
    static let tailleAvatar: CGFloat = 64
    static let bordureAvatar: CGFloat = 3
    static let tailleBadgePoste: CGFloat = 22
    /// Rayon avatar × cos(45°) ≈ 22,6 → badge posé sur le bord bas-droit.
    static let decalageBadgePoste: CGFloat = 22

    // Barre de progression + repère
    static let hauteurBarre: CGFloat = 8
    static let hauteurRepere: CGFloat = 14
    static let largeurRepere: CGFloat = 2
    static let hauteurBarreAvecRepere: CGFloat = 26
    /// Centre vertical du label du repère (sous la barre, dans les 26 pt).
    static let centreLabelRepereY: CGFloat = 19

    // Seuils rendement attaque (convention volleyball)
    static let seuilRendementExcellent = 0.350
    static let seuilRendementCorrect = 0.200
    static let repereRendementAttaque = 0.300

    // Seuils taux de présence (échelle 0-100, convention du modèle)
    static let seuilPresenceBon = 80.0
    static let seuilPresenceMoyen = 60.0
}
