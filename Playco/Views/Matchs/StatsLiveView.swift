//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "StatsLive")

/// Saisie point-par-point en temps réel pendant un match
/// Flux : clic sur stat → dropdown joueur sur le terrain → enregistrement + cascade
struct StatsLiveView: View {
    @Bindable var viewModel: MatchLiveViewModel

    @Environment(\.modelContext) private var modelContext
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Environment(\.modeBordDeTerrain) private var courtside
    @Environment(AuthService.self) private var authService
    @Query private var toutesActionsRallye: [ActionRallye]
    @Query private var toutesPermissions: [StaffPermissions]

    /// L'utilisateur connecté a-t-il la permission de saisir des stats ?
    private var lectureSeule: Bool {
        guard let user = authService.utilisateurConnecte else { return true }
        // Coach et admin ont tous les droits
        if user.role == .admin || user.role == .coach { return false }
        // Sinon, chercher les permissions du staff
        if let perms = toutesPermissions.first(where: { $0.assistantID == user.id && $0.codeEquipe == codeEquipeActif }) {
            return !perms.peutGererStats
        }
        // Athlètes sans permissions staff → lecture seule
        return true
    }

    @State private var statSelectionnee: TypeActionPoint?
    @State private var afficherPickerJoueur = false
    @State private var joueurReceptionEnCours: JoueurSurTerrain?
    @State private var afficherPickerReception = false
    @State private var triggerPointNous = 0
    @State private var triggerPointAdv = 0
    @State private var afficherPaveNumerique = false

    private var actionsRallyeMatch: [ActionRallye] {
        toutesActionsRallye.filter { $0.seanceID == viewModel.seance.id }
    }

    private var joueursActifs: [JoueurSurTerrain] {
        viewModel.joueursActuellementSurTerrain
    }

    @Query private var tousPoints: [PointMatch]
    private var pointsSetActuel: [PointMatch] {
        tousPoints.filter { $0.seanceID == viewModel.seance.id && $0.set == viewModel.setActuel }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Badge lecture seule
            if lectureSeule {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                    Text("LECTURE SEULE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(.red.gradient, in: Capsule())
                .padding(.vertical, 4)
            }

            // Tableau de score
            tableauScore

            Divider()

            // Panneau actions rallye (collapsible) — masqué en mode courtside
            if viewModel.afficherPanneauRallye && !courtside {
                panneauActionsRallye
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                Divider()
            }

            // Grille de stats + historique
            ScrollView {
                VStack(spacing: LiquidGlassKit.espaceMD) {
                    // Bouton point adversaire rapide
                    boutonPointAdversaire
                        .disabled(lectureSeule)
                        .opacity(lectureSeule ? 0.5 : 1)

                    if courtside {
                        // Mode courtside : stats réduites (6 boutons essentiels)
                        sectionStats(titre: "POINT POUR NOUS", stats: statsCourtside.filter { $0.categorie == .pointPourNous }, couleur: .green)
                        sectionStats(titre: "NOS ERREURS", stats: statsCourtside.filter { $0.categorie == .pointContre }, couleur: .red)

                        // Stats adversaire essentielles en courtside
                        sectionStatsAdversaire(titre: "ADVERSAIRE — SCORING", stats: DefinitionStat.statsAdversaireScoring, couleur: .red)
                    } else {
                        // Stats pour nous
                        sectionStats(titre: "POINT POUR NOUS", stats: DefinitionStat.statsPourNous, couleur: .green)

                        // Stats contre nous (nos erreurs)
                        sectionStats(titre: "NOS ERREURS (POINT ADV.)", stats: DefinitionStat.statsContre, couleur: .red)

                        // Stats adversaire scoring (point contre nous)
                        sectionStatsAdversaire(titre: "ADVERSAIRE — SCORING", stats: DefinitionStat.statsAdversaireScoring, couleur: .red)

                        // Stats adversaire erreurs (point pour nous)
                        sectionStatsAdversaire(titre: "ADVERSAIRE — ERREURS", stats: DefinitionStat.statsAdversaireErreurs, couleur: .green)
                    }

                    // Annuler dernier point + historique simplifié en courtside
                    if courtside {
                        boutonAnnulerDernierPoint
                    } else {
                        historiqueSet
                    }
                }
                .padding(LiquidGlassKit.espaceMD)
            }
            .disabled(lectureSeule)
            .opacity(lectureSeule ? 0.6 : 1)
        }
        .sheet(isPresented: $viewModel.afficherSelecteurZone) {
            if let point = viewModel.pointEnAttenteZone {
                SelecteurZoneView(
                    categorieHeatmap: point.typeAction.categorieHeatmap,
                    onZoneSelectionnee: { zone in
                        point.zone = zone
                        viewModel.afficherSelecteurZone = false
                        viewModel.pointEnAttenteZone = nil
                    },
                    onPasser: {
                        viewModel.afficherSelecteurZone = false
                        viewModel.pointEnAttenteZone = nil
                    }
                )
                .presentationDetents([.height(380)])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $afficherPickerReception) {
            pickerQualiteReception
                .presentationDetents([.height(220)])
                .presentationDragIndicator(.visible)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: triggerPointNous)
        .sensoryFeedback(.warning, trigger: triggerPointAdv)
        .onChange(of: viewModel.scoreNous) { _, _ in triggerPointNous += 1 }
        .onChange(of: viewModel.scoreAdv) { _, _ in triggerPointAdv += 1 }
        .overlay(alignment: .bottom) {
            if courtside && afficherPaveNumerique {
                PaveNumeriqueRapideView(viewModel: viewModel, estVisible: $afficherPaveNumerique)
                    .padding(LiquidGlassKit.espaceMD)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Tableau de score

    private var tableauScore: some View {
        HStack(spacing: 0) {
            // Nous
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Text("NOUS")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                    if viewModel.nousServons {
                        Image(systemName: "volleyball.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.green)
                    }
                }
                Text("\(viewModel.scoreNous)")
                    .font(.system(size: courtside ? LiquidGlassKit.scoreCourtside : 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)

            // Info set + rotation
            VStack(spacing: 6) {
                Text("Set \(viewModel.setActuel)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.red)

                HStack(spacing: 8) {
                    Text("R\(viewModel.rotationActuelle)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PaletteMat.bleu)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("R\(viewModel.rotationAdversaire)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.red)

                    if courtside {
                        Button {
                            withAnimation(LiquidGlassKit.springDefaut) {
                                afficherPaveNumerique.toggle()
                            }
                        } label: {
                            Image(systemName: "number")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(afficherPaveNumerique ? .white : PaletteMat.bleu)
                                .frame(width: 28, height: 28)
                                .background(
                                    afficherPaveNumerique ? PaletteMat.bleu : PaletteMat.bleu.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Boutons set
                HStack(spacing: 8) {
                    if viewModel.setActuel > 1 {
                        Button("← Set \(viewModel.setActuel - 1)") {
                            withAnimation(LiquidGlassKit.springDefaut) {
                                viewModel.changerSet(vers: viewModel.setActuel - 1)
                            }
                        }
                        .font(.caption2)
                    }
                    if viewModel.setActuel < 5 {
                        Button("Set \(viewModel.setActuel + 1) →") {
                            withAnimation(LiquidGlassKit.springDefaut) {
                                viewModel.changerSet(vers: viewModel.setActuel + 1)
                            }
                        }
                        .font(.caption2)
                    }
                }
            }
            .frame(width: 140)

            // Adversaire
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Text("ADV.")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                    if !viewModel.nousServons {
                        Image(systemName: "volleyball.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.red)
                    }
                }
                Text("\(viewModel.scoreAdv)")
                    .font(.system(size: courtside ? LiquidGlassKit.scoreCourtside : 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.red)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, LiquidGlassKit.espaceMD)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Bouton point adversaire rapide

    private var boutonPointAdversaire: some View {
        Button {
            withAnimation(LiquidGlassKit.springDefaut) {
                viewModel.enregistrerStat(action: .erreurAdversaire, joueurID: nil)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                Text("Erreur adversaire (+1 nous)")
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit))
            .overlay {
                RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit)
                    .strokeBorder(.green.opacity(0.3), lineWidth: 1)
            }
            .foregroundStyle(.green)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Grille de stats (toutes les stats)

    /// Stats réduites pour le mode courtside (6 boutons essentiels)
    private var statsCourtside: [DefinitionStat] {
        DefinitionStat.toutesStats.filter {
            [.kill, .ace, .blocSeul, .erreurAdversaire, .erreurAttaque, .erreurService].contains($0.action)
        }
    }

    /// Bouton annuler dernier point (mode courtside simplifié)
    private var boutonAnnulerDernierPoint: some View {
        Group {
            if viewModel.dernierPoint != nil {
                Button {
                    withAnimation(LiquidGlassKit.springDefaut) {
                        viewModel.annulerDernierPoint(actionsRallye: actionsRallyeMatch)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.title3)
                        Text("Annuler dernier point")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit))
                    .overlay {
                        RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit)
                            .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
                    }
                    .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sectionStats(titre: String, stats: [DefinitionStat], couleur: Color) -> some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Text(titre)
                .font(courtside ? .subheadline.weight(.bold) : .caption.weight(.bold))
                .foregroundStyle(couleur)
                .tracking(0.5)

            // Grille de statistiques — chaque cellule = 1 type de stat
            let columns = courtside
                ? [GridItem(.adaptive(minimum: LiquidGlassKit.grilleCourtside), spacing: LiquidGlassKit.espaceMD)]
                : [GridItem(.adaptive(minimum: 100), spacing: LiquidGlassKit.espaceSM)]

            LazyVGrid(columns: columns, spacing: courtside ? LiquidGlassKit.espaceMD : LiquidGlassKit.espaceSM) {
                ForEach(stats) { stat in
                    boutonStat(stat: stat, couleur: couleur)
                }
            }
        }
    }

    /// Bouton pour une statistique — au clic, ouvre le dropdown de sélection du joueur
    private func boutonStat(stat: DefinitionStat, couleur: Color) -> some View {
        Menu {
            // Liste des joueurs actuellement sur le terrain
            if joueursActifs.isEmpty {
                Text("Aucun partant défini")
            } else {
                ForEach(joueursActifs) { joueur in
                    Button {
                        withAnimation(LiquidGlassKit.springDefaut) {
                            viewModel.enregistrerStat(action: stat.action, joueurID: joueur.joueurID)
                        }
                    } label: {
                        Label("#\(joueur.numero) — \(joueur.prenom) \(joueur.nom)",
                              systemImage: joueur.estLibero ? "shield.checkered" : "person.fill")
                    }
                }

                // Actions sans joueur spécifique
                if stat.action.estStatAdversaire {
                    Divider()
                    Button {
                        withAnimation(LiquidGlassKit.springDefaut) {
                            viewModel.enregistrerStat(action: stat.action, joueurID: nil)
                        }
                    } label: {
                        Label("Sans joueur", systemImage: "questionmark.circle")
                    }
                }
            }
        } label: {
            VStack(spacing: courtside ? 8 : 4) {
                Image(systemName: stat.icone)
                    .font(courtside ? .title2 : .title3)
                Text(stat.label)
                    .font(courtside ? .caption.weight(.bold) : .caption2.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, courtside ? 20 : 14)
            .background(couleur.opacity(0.08), in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit))
            .overlay {
                RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit)
                    .strokeBorder(couleur.opacity(0.2), lineWidth: 0.5)
            }
            .foregroundStyle(couleur)
        }
        .accessibilityLabel("Ajouter un \(stat.label)")
        .accessibilityHint("Double-tapez pour choisir le joueur et enregistrer le point")
    }

    // MARK: - Stats adversaire (entrée par équipe, pas par joueur)

    private func sectionStatsAdversaire(titre: String, stats: [DefinitionStat], couleur: Color) -> some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM) {
            Text(titre)
                .font(courtside ? .subheadline.weight(.bold) : .caption.weight(.bold))
                .foregroundStyle(couleur)
                .tracking(0.5)

            let columns = courtside
                ? [GridItem(.adaptive(minimum: LiquidGlassKit.grilleCourtside), spacing: LiquidGlassKit.espaceMD)]
                : [GridItem(.adaptive(minimum: 100), spacing: LiquidGlassKit.espaceSM)]

            LazyVGrid(columns: columns, spacing: courtside ? LiquidGlassKit.espaceMD : LiquidGlassKit.espaceSM) {
                ForEach(stats) { stat in
                    boutonStatAdversaire(stat: stat, couleur: couleur)
                }
            }
        }
    }

    /// Bouton stat adversaire — enregistrement direct sans sélection de joueur
    private func boutonStatAdversaire(stat: DefinitionStat, couleur: Color) -> some View {
        Button {
            withAnimation(LiquidGlassKit.springDefaut) {
                viewModel.enregistrerStat(action: stat.action, joueurID: nil)
            }
        } label: {
            VStack(spacing: courtside ? 8 : 4) {
                Image(systemName: stat.icone)
                    .font(courtside ? .title2 : .title3)
                Text(stat.label)
                    .font(courtside ? .caption.weight(.bold) : .caption2.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, courtside ? 20 : 14)
            .background(couleur.opacity(0.08), in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit))
            .overlay {
                RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit)
                    .strokeBorder(couleur.opacity(0.2), lineWidth: 0.5)
            }
            .foregroundStyle(couleur)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stat adversaire : \(stat.label)")
        .accessibilityHint("Double-tapez pour enregistrer")
    }

    // MARK: - Historique

    private var historiqueSet: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("HISTORIQUE SET \(viewModel.setActuel)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Spacer()
                Text("\(pointsSetActuel.count) points")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                if viewModel.dernierPoint != nil {
                    Button {
                        withAnimation(LiquidGlassKit.springDefaut) {
                            viewModel.annulerDernierPoint(actionsRallye: actionsRallyeMatch)
                        }
                    } label: {
                        Label("Annuler", systemImage: "arrow.uturn.backward")
                            .font(.caption2)
                    }
                    .tint(.orange)
                }
            }

            if pointsSetActuel.isEmpty {
                Text("Aucun point enregistré")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                ForEach(pointsSetActuel.sorted(by: { $0.horodatage > $1.horodatage }).prefix(10)) { point in
                    lignePoint(point)
                }
            }
        }
    }

    private func lignePoint(_ point: PointMatch) -> some View {
        let joueur = joueursActifs.first(where: { $0.joueurID == point.joueurID })

        return HStack(spacing: 8) {
            Image(systemName: point.typeAction.icone)
                .font(.caption2)
                .foregroundStyle(point.estPointPourNous ? .green : .red)
                .frame(width: 16)

            Text("\(point.scoreEquipeAuMoment)-\(point.scoreAdversaireAuMoment)")
                .font(.caption2.monospaced().weight(.medium))
                .frame(width: 40)

            if let j = joueur {
                Text("#\(j.numero) \(j.prenom)")
                    .font(.caption2)
                    .foregroundStyle(.primary)
            }

            Text(point.typeAction.rawValue)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            Text(point.horodatage.formatHeure())
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Panneau actions rallye

    private var panneauActionsRallye: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ACTIONS DU RALLYE")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Spacer()
                Button {
                    withAnimation(LiquidGlassKit.springDefaut) {
                        viewModel.afficherPanneauRallye = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(TypeActionRallye.allCases, id: \.rawValue) { type in
                HStack(spacing: 6) {
                    Label(type.rawValue, systemImage: type.icone)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(type.couleur)
                        .frame(width: 90, alignment: .leading)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(joueursActifs) { joueur in
                                Button {
                                    if type == .reception {
                                        enregistrerActionRallyeAvecJoueur(joueurID: joueur.joueurID, type: type)
                                    } else {
                                        enregistrerActionRallye(joueurID: joueur.joueurID, type: type)
                                    }
                                } label: {
                                    Text("#\(joueur.numero)")
                                        .font(.caption2.weight(.bold))
                                        .frame(width: 34, height: 28)
                                        .background(type.couleur.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 6)
                                                .strokeBorder(type.couleur.opacity(0.25), lineWidth: 0.5)
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, LiquidGlassKit.espaceMD)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - Picker qualité réception

    private var pickerQualiteReception: some View {
        VStack(spacing: 12) {
            Text("Qualité de la réception")
                .font(.subheadline.weight(.semibold))
            if let j = joueurReceptionEnCours {
                Text("#\(j.numero) \(j.prenom) \(j.nom)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                boutonQualite(label: "Parfaite", qualite: 3, couleur: .green)
                boutonQualite(label: "Bonne", qualite: 2, couleur: .yellow)
                boutonQualite(label: "Mauvaise", qualite: 1, couleur: .red)
            }
            .padding(.top, 4)
        }
        .padding(20)
    }

    private func boutonQualite(label: String, qualite: Int, couleur: Color) -> some View {
        Button {
            if let joueur = joueurReceptionEnCours {
                enregistrerActionRallye(joueurID: joueur.id, type: .reception, qualite: qualite)
            }
            afficherPickerReception = false
            joueurReceptionEnCours = nil
        } label: {
            VStack(spacing: 4) {
                Text("\(qualite)")
                    .font(.title2.weight(.bold))
                Text(label)
                    .font(.caption2.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(couleur.opacity(0.12), in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit))
            .overlay {
                RoundedRectangle(cornerRadius: LiquidGlassKit.rayonPetit)
                    .strokeBorder(couleur.opacity(0.3), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Logique rallye

    private func enregistrerActionRallyeAvecJoueur(joueurID: UUID, type: TypeActionRallye) {
        if type == .reception {
            joueurReceptionEnCours = joueursActifs.first(where: { $0.joueurID == joueurID })
            afficherPickerReception = true
        } else {
            enregistrerActionRallye(joueurID: joueurID, type: type)
        }
    }

    private func enregistrerActionRallye(joueurID: UUID, type: TypeActionRallye, qualite: Int = 0) {
        let action = ActionRallye(seanceID: viewModel.seance.id, set: viewModel.setActuel, joueurID: joueurID, typeAction: type)
        action.qualite = qualite
        action.codeEquipe = codeEquipeActif
        action.pointMatchID = viewModel.dernierPoint?.id
        modelContext.insert(action)
        logger.info("Action rallye: \(type.rawValue)")
    }
}
