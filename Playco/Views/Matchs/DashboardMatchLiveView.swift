//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Statistique agrégée par joueur pour le dashboard
private struct StatsJoueur: Identifiable {
    let id: UUID
    let nom: String
    let numero: Int
    var kills: Int = 0
    var aces: Int = 0
    var blocs: Int = 0
    var errAttaque: Int = 0
    var errService: Int = 0
    var errBloc: Int = 0
    var errReception: Int = 0
    var fautes: Int = 0
    var manchettes: Int = 0
    var passesDecisives: Int = 0
    var receptions: Int = 0
    var tentativesAttaque: Int = 0
    var servicesEnJeu: Int = 0
    var digs: Int = 0
    var erreurs: Int { errAttaque + errService + errBloc + errReception + fautes }
    var points: Int { kills + aces + blocs }
    /// Hitting % = (kills - errAttaque) / totalTentatives × 100
    var totalTentativesAttaque: Int { kills + errAttaque + tentativesAttaque }
    var hittingPct: Double {
        guard totalTentativesAttaque > 0 else { return 0 }
        return Double(kills - errAttaque) / Double(totalTentativesAttaque) * 100
    }
}

/// Dashboard temps réel montrant les statistiques agrégées d'un match en cours
struct DashboardMatchLiveView: View {
    var viewModel: MatchLiveViewModel

    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Environment(\.modeBordDeTerrain) private var courtside
    @Environment(AuthService.self) private var authService
    @Query private var tousPoints: [PointMatch]
    @Query private var toutesActionsRallye: [ActionRallye]
    @Query(filter: #Predicate<JoueurEquipe> { $0.estActif == true },
           sort: \JoueurEquipe.numero) private var tousJoueurs: [JoueurEquipe]

    @Query private var toutesPermissions: [StaffPermissions]
    @State private var afficherSubstitutions = false
    @State private var afficherRotation = false
    @State private var afficherDetailsJoueurs = false
    @State private var timerTempsMort: Int = 30
    @State private var timerActif = false
    @State private var afficherTTO = false
    @State private var timerRef: Timer?

    // Cache pré-calculé — recalculé uniquement sur changement de tousPoints.count
    @State private var cache = StatsMatchLiveCache()

    /// Cache des stats agrégées du match live — évite de filtrer points/actions à chaque render
    private struct StatsMatchLiveCache {
        var totalKills = 0
        var totalAces = 0
        var totalBlocs = 0
        var totalErreurs = 0
        var totalErrAttaque = 0
        var totalErrService = 0
        var totalErrReception = 0
        var totalManchettes = 0
        var totalPasses = 0
        var totalReceptions = 0
        var totalDigs = 0
        var totalServicesEnJeu = 0
        var totalTentativesAttaque = 0
        var efficaciteAttaque: Double = 0
        var pointsNous = 0
        var pointsAdversaire = 0
        var advKills = 0
        var advAces = 0
        var advBlocs = 0
        var advErreurs = 0
        var statsParJoueur: [StatsJoueur] = []
    }

    private func recalculerCache() {
        let seanceID = viewModel.seance.id
        let points = tousPoints.filter { $0.seanceID == seanceID }
        let actionsRallye = toutesActionsRallye.filter { $0.seanceID == seanceID }
        let joueurs = tousJoueurs.filtreEquipe(codeEquipeActif)

        var s = StatsMatchLiveCache()

        // Stats points
        for point in points {
            switch point.typeAction {
            case .kill: s.totalKills += 1
            case .ace: s.totalAces += 1
            case .erreurAttaque: s.totalErrAttaque += 1
            case .erreurService: s.totalErrService += 1
            case .erreurReception: s.totalErrReception += 1
            case .killAdversaire: s.advKills += 1
            case .aceAdversaire: s.advAces += 1
            case .blocAdversaire: s.advBlocs += 1
            case .erreurAdversaire, .erreurAttaqueAdversaire, .erreurServiceAdversaire:
                s.advErreurs += 1
            default: break
            }
            if point.typeAction.estBloc { s.totalBlocs += 1 }
            if point.typeAction.estErreurEquipe { s.totalErreurs += 1 }
            if point.estPointPourNous { s.pointsNous += 1 } else { s.pointsAdversaire += 1 }
        }

        // Stats actions rallye
        for action in actionsRallye {
            switch action.typeAction {
            case .manchette: s.totalManchettes += 1
            case .passeDecisive: s.totalPasses += 1
            case .reception: s.totalReceptions += 1
            case .tentativeAttaque: s.totalTentativesAttaque += 1
            case .serviceEnJeu: s.totalServicesEnJeu += 1
            case .dig: s.totalDigs += 1
            }
        }
        s.totalTentativesAttaque += s.totalKills + s.totalErrAttaque

        s.efficaciteAttaque = s.totalTentativesAttaque > 0
            ? Double(s.totalKills - s.totalErrAttaque) / Double(s.totalTentativesAttaque) * 100
            : 0

        // Stats par joueur
        var dict: [UUID: StatsJoueur] = [:]
        for joueur in joueurs {
            dict[joueur.id] = StatsJoueur(id: joueur.id, nom: "\(joueur.prenom) \(joueur.nom)", numero: joueur.numero)
        }
        for point in points {
            guard let jid = point.joueurID, dict[jid] != nil else { continue }
            switch point.typeAction {
            case .kill: dict[jid]?.kills += 1
            case .ace: dict[jid]?.aces += 1
            case .blocSeul, .blocAssiste, .bloc: dict[jid]?.blocs += 1
            case .erreurAttaque: dict[jid]?.errAttaque += 1
            case .erreurService: dict[jid]?.errService += 1
            case .erreurBloc: dict[jid]?.errBloc += 1
            case .erreurReception: dict[jid]?.errReception += 1
            case .fauteJeu, .erreurEquipe: dict[jid]?.fautes += 1
            case .erreurAdversaire, .killAdversaire, .aceAdversaire, .blocAdversaire,
                 .erreurAttaqueAdversaire, .erreurServiceAdversaire: break
            }
        }
        for action in actionsRallye {
            guard dict[action.joueurID] != nil else { continue }
            switch action.typeAction {
            case .manchette: dict[action.joueurID]?.manchettes += 1
            case .passeDecisive: dict[action.joueurID]?.passesDecisives += 1
            case .reception: dict[action.joueurID]?.receptions += 1
            case .tentativeAttaque: dict[action.joueurID]?.tentativesAttaque += 1
            case .serviceEnJeu: dict[action.joueurID]?.servicesEnJeu += 1
            case .dig: dict[action.joueurID]?.digs += 1
            }
        }
        s.statsParJoueur = dict.values.sorted { $0.points > $1.points }

        cache = s
    }

    private var lectureSeule: Bool {
        guard let user = authService.utilisateurConnecte else { return true }
        // Coach (principal + assistant) et admin ont tous les droits
        if user.role == .admin || user.role == .coach || user.role == .assistantCoach { return false }
        if let perms = toutesPermissions.first(where: { $0.assistantID == user.id && $0.codeEquipe == codeEquipeActif }) {
            return !perms.peutGererStats
        }
        return true
    }

    var body: some View {
        ScrollView {
            VStack(spacing: LiquidGlassKit.espaceMD) {
                // Score principal
                scoreBoard

                // Formation live + Temps morts côte à côte
                HStack(alignment: .top, spacing: LiquidGlassKit.espaceMD) {
                    // Formation
                    VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
                        Text("FORMATION")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)
                        FormationMatchLiveView(viewModel: viewModel, compact: true)
                    }
                    .padding(LiquidGlassKit.espaceMD)
                    .glassSection()
                    .frame(maxWidth: .infinity)

                    // Temps morts
                    sectionTempsMorts
                        .frame(maxWidth: .infinity)
                }

                // Stats rapides — en courtside, seulement 4 cartes essentielles
                if courtside {
                    statsRapidesCourtside
                } else {
                    statsRapides
                }

                // Comparaison nous vs adversaire
                comparaisonLive

                // Infos match — masquer les chips en courtside (rotation visible via formation)
                if !courtside {
                    HStack(spacing: LiquidGlassKit.espaceMD) {
                        Button {
                            afficherRotation = true
                        } label: {
                            infoChip(icone: "arrow.triangle.2.circlepath", texte: "Rotation \(viewModel.rotationActuelle)", couleur: PaletteMat.bleu)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Modifier la rotation. Actuellement rotation \(viewModel.rotationActuelle)")
                        .accessibilityHint("Double-tapez pour ouvrir le sélecteur de rotation")

                        infoChip(icone: "arrow.triangle.2.circlepath.camera", texte: "Rot. adv. R\(viewModel.rotationAdversaire)", couleur: .red)
                        infoChip(icone: "number.circle", texte: "Set \(viewModel.setActuel)", couleur: PaletteMat.violet)
                        infoChip(icone: "chart.line.uptrend.xyaxis", texte: "Eff. \(String(format: "%.0f", cache.efficaciteAttaque))%", couleur: cache.efficaciteAttaque >= 25 ? PaletteMat.vert : .red)

                        // Bouton substitutions
                        Button {
                            afficherSubstitutions = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.caption)
                                Text("Subs \(viewModel.subsUtiliseesDansSet)/\(viewModel.subsMaxParSet)")
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundStyle(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.red.opacity(0.1), in: Capsule())
                        }
                        .accessibilityLabel("Substitutions : \(viewModel.subsUtiliseesDansSet) sur \(viewModel.subsMaxParSet) utilisées dans ce set")
                        .accessibilityHint("Double-tapez pour gérer les substitutions")
                    }
                }

                // Tableau joueurs — masqué par défaut en courtside
                if courtside {
                    if afficherDetailsJoueurs {
                        tableauJoueurs
                    }
                    Button {
                        withAnimation(LiquidGlassKit.springDefaut) {
                            afficherDetailsJoueurs.toggle()
                        }
                    } label: {
                        Label(afficherDetailsJoueurs ? "Masquer les détails" : "Voir les détails joueurs",
                              systemImage: afficherDetailsJoueurs ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit))
                    }
                    .buttonStyle(.plain)
                } else {
                    tableauJoueurs
                }
            }
            .padding(LiquidGlassKit.espaceMD)
        }
        .onAppear { recalculerCache() }
        .onChange(of: tousPoints.count) { recalculerCache() }
        .onChange(of: toutesActionsRallye.count) { recalculerCache() }
        .onDisappear {
            timerRef?.invalidate()
            timerRef = nil
        }
        .sensoryFeedback(.success, trigger: viewModel.subsUtiliseesDansSet)
        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.scoreNous)
        .sheet(isPresented: $afficherSubstitutions) {
            SubstitutionsView(viewModel: viewModel)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $afficherRotation) {
            RotationLiveView(viewModel: viewModel)
                .presentationDetents([.large])
        }
        .alert("Temps mort technique", isPresented: $afficherTTO) {
            Button("OK") { afficherTTO = false }
        } message: {
            let score = Swift.max(viewModel.scoreNous, viewModel.scoreAdv)
            Text("TTO automatique — \(score) points (set \(viewModel.setActuel))")
        }
        .onChange(of: viewModel.scoreNous) { verifierEtAfficherTTO() }
        .onChange(of: viewModel.scoreAdv) { verifierEtAfficherTTO() }
        .overlay {
            if timerActif {
                timerTempsMortOverlay
            }
        }
    }

    // MARK: - Score Board

    private var scoreBoard: some View {
        HStack(spacing: LiquidGlassKit.espaceXL) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text("NOUS")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if viewModel.nousServons {
                        Image(systemName: "volleyball.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(PaletteMat.vert)
                    }
                }
                Text("\(viewModel.scoreNous)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(PaletteMat.vert)
                    .contentTransition(.numericText())
            }

            VStack(spacing: 4) {
                Text("SET \(viewModel.setActuel)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("—")
                    .font(.title.weight(.light))
                    .foregroundStyle(.quaternary)
            }

            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text("ADV")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if !viewModel.nousServons {
                        Image(systemName: "volleyball.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.red)
                    }
                }
                Text("\(viewModel.scoreAdv)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.red)
                    .contentTransition(.numericText())
            }
        }
        .padding(.vertical, LiquidGlassKit.espaceLG)
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: LiquidGlassKit.rayonXL)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score du set \(viewModel.setActuel)")
        .accessibilityValue("Nous \(viewModel.scoreNous), adversaire \(viewModel.scoreAdv). \(viewModel.nousServons ? "Nous servons." : "L'adversaire sert.")")
    }

    // MARK: - Temps morts

    private var sectionTempsMorts: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Text("TEMPS MORTS")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            HStack(spacing: LiquidGlassKit.espaceLG) {
                // Nous
                VStack(spacing: 6) {
                    Text("Nous")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        let maxTM = viewModel.seance.configMatch.tempsMortsParSetParEquipe
                        let utilises = viewModel.tempsMortsNousUtilises
                        ForEach(0..<maxTM, id: \.self) { i in
                            Circle()
                                .fill(i < utilises ? Color.red : Color.red.opacity(0.15))
                                .frame(width: 14, height: 14)
                        }
                    }

                    Button {
                        withAnimation(LiquidGlassKit.springDefaut) {
                            viewModel.prendreTempsMort(equipe: "nous")
                            timerActif = true
                        }
                    } label: {
                        Text("TM")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.red.opacity(0.12), in: Capsule())
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.tempsMortsNousRestants <= 0)
                    .opacity(viewModel.tempsMortsNousRestants > 0 ? 1 : 0.4)
                }

                // Adversaire
                VStack(spacing: 6) {
                    Text("Adv.")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        let maxTM = viewModel.seance.configMatch.tempsMortsParSetParEquipe
                        let utilises = viewModel.tempsMortsAdvUtilises
                        ForEach(0..<maxTM, id: \.self) { i in
                            Circle()
                                .fill(i < utilises ? Color.orange : Color.orange.opacity(0.15))
                                .frame(width: 14, height: 14)
                        }
                    }

                    Button {
                        withAnimation(LiquidGlassKit.springDefaut) {
                            viewModel.prendreTempsMort(equipe: "adversaire")
                            timerActif = true
                        }
                    } label: {
                        Text("TM")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.orange.opacity(0.12), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.tempsMortsAdvRestants <= 0)
                    .opacity(viewModel.tempsMortsAdvRestants > 0 ? 1 : 0.4)
                }
            }
        }
        .padding(LiquidGlassKit.espaceMD)
        .glassSection()
    }

    // MARK: - Stats rapides courtside (4 cartes essentielles)

    private var statsRapidesCourtside: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: LiquidGlassKit.espaceSM), count: 4), spacing: LiquidGlassKit.espaceSM) {
            statCard(titre: "Kills", valeur: cache.totalKills, icone: "flame.fill", couleur: PaletteMat.vert)
            statCard(titre: "Aces", valeur: cache.totalAces, icone: "arrow.up.forward", couleur: PaletteMat.bleu)
            statCard(titre: "Blocs", valeur: cache.totalBlocs, icone: "shield.fill", couleur: PaletteMat.violet)
            statCard(titre: "Erreurs", valeur: cache.totalErreurs, icone: "exclamationmark.triangle", couleur: .red)
        }
    }

    // MARK: - Stats rapides (4 cartes)

    private var statsRapides: some View {
        VStack(spacing: LiquidGlassKit.espaceSM) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: LiquidGlassKit.espaceSM), count: 4), spacing: LiquidGlassKit.espaceSM) {
                statCard(titre: "Kills", valeur: cache.totalKills, icone: "flame.fill", couleur: PaletteMat.vert)
                statCard(titre: "Aces", valeur: cache.totalAces, icone: "arrow.up.forward", couleur: PaletteMat.bleu)
                statCard(titre: "Blocs", valeur: cache.totalBlocs, icone: "shield.fill", couleur: PaletteMat.violet)
                statCard(titre: "Erreurs", valeur: cache.totalErreurs, icone: "exclamationmark.triangle", couleur: .red)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: LiquidGlassKit.espaceSM), count: 4), spacing: LiquidGlassKit.espaceSM) {
                statCard(titre: "Digs", valeur: cache.totalDigs + cache.totalManchettes, icone: "hand.point.down.fill", couleur: .teal)
                statCard(titre: "Assists", valeur: cache.totalPasses, icone: "arrow.turn.up.right", couleur: .yellow)
                statCard(titre: "Réceptions", valeur: cache.totalReceptions, icone: "arrow.down.to.line", couleur: .purple)
                statCardPct(titre: "Eff. Att.", valeur: cache.efficaciteAttaque, icone: "chart.line.uptrend.xyaxis", couleur: cache.efficaciteAttaque >= 25 ? PaletteMat.vert : .red)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: LiquidGlassKit.espaceSM), count: 3), spacing: LiquidGlassKit.espaceSM) {
                statCard(titre: "Err. Service", valeur: cache.totalErrService, icone: "arrow.up.forward.circle", couleur: .orange)
                statCard(titre: "Err. Attaque", valeur: cache.totalErrAttaque, icone: "flame", couleur: .orange)
                statCard(titre: "Err. Récep.", valeur: cache.totalErrReception, icone: "arrow.down.left", couleur: .orange)
            }
        }
    }

    // MARK: - Comparaison live nous vs adversaire

    private var comparaisonLive: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Text("COMPARAISON LIVE")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            let totalPoints = cache.pointsNous + cache.pointsAdversaire
            let pctNous = totalPoints > 0 ? Double(cache.pointsNous) / Double(totalPoints) : 0.5

            HStack(spacing: LiquidGlassKit.espaceMD) {
                VStack(spacing: 4) {
                    Text("NOUS")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text("\(cache.pointsNous)")
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(PaletteMat.vert)
                        .contentTransition(.numericText())
                }

                GeometryReader { geo in
                    let w = geo.size.width
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.red.opacity(0.2))
                            .frame(height: 12)
                        Capsule()
                            .fill(PaletteMat.vert)
                            .frame(width: w * pctNous, height: 12)
                    }
                }
                .frame(height: 12)

                VStack(spacing: 4) {
                    Text("ADV")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text("\(cache.pointsAdversaire)")
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(.red)
                        .contentTransition(.numericText())
                }
            }
            .padding(.vertical, LiquidGlassKit.espaceSM)

            // Détails comparatifs
            HStack(spacing: 0) {
                barreComparaison(label: "Kills", nousVal: cache.totalKills, advVal: cache.advKills, couleurNous: PaletteMat.vert)
                barreComparaison(label: "Aces", nousVal: cache.totalAces, advVal: cache.advAces, couleurNous: PaletteMat.bleu)
                barreComparaison(label: "Blocs", nousVal: cache.totalBlocs, advVal: cache.advBlocs, couleurNous: PaletteMat.violet)
                barreComparaison(label: "Erreurs", nousVal: cache.totalErreurs, advVal: cache.advErreurs, couleurNous: .red)
            }
        }
        .padding(LiquidGlassKit.espaceMD)
        .glassSection()
    }

    private func barreComparaison(label: String, nousVal: Int, advVal: Int, couleurNous: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(nousVal)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(couleurNous)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 9).weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func statCard(titre: String, valeur: Int, icone: String, couleur: Color) -> some View {
        VStack(spacing: LiquidGlassKit.espaceSM) {
            Image(systemName: icone)
                .font(.system(size: 20))
                .foregroundStyle(couleur)
            Text("\(valeur)")
                .font(.title2.weight(.bold).monospacedDigit())
                .contentTransition(.numericText())
            Text(titre)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LiquidGlassKit.espaceMD)
        .glassCard(teinte: couleur, cornerRadius: LiquidGlassKit.rayonMoyen)
    }

    private func statCardPct(titre: String, valeur: Double, icone: String, couleur: Color) -> some View {
        VStack(spacing: LiquidGlassKit.espaceSM) {
            Image(systemName: icone)
                .font(.system(size: 20))
                .foregroundStyle(couleur)
            Text(String(format: "%.0f%%", valeur))
                .font(.title2.weight(.bold).monospacedDigit())
                .contentTransition(.numericText())
            Text(titre)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LiquidGlassKit.espaceMD)
        .glassCard(teinte: couleur, cornerRadius: LiquidGlassKit.rayonMoyen)
    }

    private func infoChip(icone: String, texte: String, couleur: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icone)
                .font(.caption)
            Text(texte)
                .font(.caption.weight(.medium))
                .contentTransition(.numericText())
        }
        .foregroundStyle(couleur)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(couleur.opacity(0.1), in: Capsule())
    }

    // MARK: - Tableau joueurs

    private var tableauJoueurs: some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Text("STATISTIQUES PAR JOUEUR")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    // En-tête
                    HStack(spacing: 0) {
                        Text("#").frame(width: 30, alignment: .leading)
                        Text("Joueur").frame(width: 100, alignment: .leading)
                        Text("Pts").frame(width: 32)
                        Text("K").frame(width: 28)
                        Text("A").frame(width: 28)
                        Text("B").frame(width: 28)
                        Text("D").frame(width: 28)
                        Text("As").frame(width: 28)
                        Text("R").frame(width: 28)
                        Text("EAt").frame(width: 32)
                        Text("ESv").frame(width: 32)
                        Text("EB").frame(width: 28)
                        Text("ER").frame(width: 28)
                        Text("F").frame(width: 28)
                        Text("E").frame(width: 28)
                        Text("Eff%").frame(width: 40)
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)

                    Divider()

                    ForEach(cache.statsParJoueur) { stat in
                        HStack(spacing: 0) {
                            Text("\(stat.numero)")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .frame(width: 30, alignment: .leading)
                            Text(stat.nom)
                                .font(.caption)
                                .lineLimit(1)
                                .frame(width: 100, alignment: .leading)
                            Text("\(stat.points)")
                                .font(.caption.weight(.bold))
                                .frame(width: 32)
                                .foregroundStyle(PaletteMat.vert)
                                .contentTransition(.numericText())
                            Text("\(stat.kills)")
                                .frame(width: 28)
                                .contentTransition(.numericText())
                            Text("\(stat.aces)")
                                .frame(width: 28)
                                .contentTransition(.numericText())
                            Text("\(stat.blocs)")
                                .frame(width: 28)
                                .contentTransition(.numericText())
                            Text("\(stat.manchettes)")
                                .frame(width: 28)
                                .foregroundStyle(.teal)
                                .contentTransition(.numericText())
                            Text("\(stat.passesDecisives)")
                                .frame(width: 28)
                                .foregroundStyle(.yellow)
                                .contentTransition(.numericText())
                            Text("\(stat.receptions)")
                                .frame(width: 28)
                                .foregroundStyle(.purple)
                                .contentTransition(.numericText())
                            Text("\(stat.errAttaque)")
                                .frame(width: 32)
                                .foregroundStyle(stat.errAttaque > 0 ? .orange : .primary)
                                .contentTransition(.numericText())
                            Text("\(stat.errService)")
                                .frame(width: 32)
                                .foregroundStyle(stat.errService > 0 ? .orange : .primary)
                                .contentTransition(.numericText())
                            Text("\(stat.errBloc)")
                                .frame(width: 28)
                                .foregroundStyle(stat.errBloc > 0 ? .orange : .primary)
                                .contentTransition(.numericText())
                            Text("\(stat.errReception)")
                                .frame(width: 28)
                                .foregroundStyle(stat.errReception > 0 ? .orange : .primary)
                                .contentTransition(.numericText())
                            Text("\(stat.fautes)")
                                .frame(width: 28)
                                .foregroundStyle(stat.fautes > 0 ? .red : .primary)
                                .contentTransition(.numericText())
                            Text("\(stat.erreurs)")
                                .frame(width: 28)
                                .foregroundStyle(stat.erreurs > 0 ? .red : .primary)
                                .contentTransition(.numericText())
                            Text(stat.tentativesAttaque > 0 ? String(format: "%.0f", stat.hittingPct) : "—")
                                .frame(width: 40)
                                .foregroundStyle(stat.hittingPct >= 25 ? PaletteMat.vert : (stat.hittingPct < 0 ? .red : .primary))
                                .contentTransition(.numericText())
                        }
                        .font(.caption.monospacedDigit())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                    }
                }
            }

            if cache.statsParJoueur.isEmpty {
                Text("Aucune statistique enregistrée")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, LiquidGlassKit.espaceLG)
            }
        }
        .padding(LiquidGlassKit.espaceMD)
        .glassSection()
    }

    // MARK: - TTO

    private func verifierEtAfficherTTO() {
        if viewModel.verifierTTO() {
            afficherTTO = true
        }
    }

    // MARK: - Timer temps mort (30s)

    private var timerTempsMortOverlay: some View {
        VStack(spacing: LiquidGlassKit.espaceMD) {
            Text("TEMPS MORT")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            Text("\(timerTempsMort)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(timerTempsMort <= 10 ? .red : .primary)
                .contentTransition(.numericText())

            Text("secondes")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                timerActif = false
                timerTempsMort = 30
            } label: {
                Text("Fermer")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(.red.opacity(0.12), in: Capsule())
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .onAppear {
            demarrerTimerTempsMort()
        }
    }

    private func demarrerTimerTempsMort() {
        timerRef?.invalidate()
        timerTempsMort = 30
        timerRef = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if timerTempsMort > 0 && timerActif {
                withAnimation(LiquidGlassKit.springDefaut) {
                    timerTempsMort -= 1
                }
            } else {
                timer.invalidate()
                timerRef = nil
                if timerTempsMort <= 0 {
                    timerActif = false
                    timerTempsMort = 30
                }
            }
        }
    }
}
