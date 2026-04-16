//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Écran d'accueil avec 3 sections principales — adaptatif iPhone/iPad, portrait/paysage
struct AccueilView: View {
    var onSection: (SectionApp) -> Void

    @Query(filter: #Predicate<Seance> { $0.estArchivee == false },
           sort: \Seance.date, order: .reverse) private var toutesSeances: [Seance]
    @Query(filter: #Predicate<StrategieCollective> { $0.estArchivee == false })
    private var toutesStrategies: [StrategieCollective]
    @Query private var tousJoueurs: [JoueurEquipe]

    @Environment(\.colorScheme) private var colorScheme
    @Environment(AuthService.self) private var authService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.couleurRole) private var couleurRole
    @Environment(\.codeEquipeActif) private var codeEquipeActif

    /// Données filtrées par équipe (cachées pour éviter recalcul chaque render)
    @State private var seances: [Seance] = []
    @State private var strategies: [StrategieCollective] = []
    @State private var joueurs: [JoueurEquipe] = []
    @AppStorage("modeSombre") private var modeSombre: Bool = false

    private func recalculerDonnees() {
        seances = toutesSeances.filtreEquipe(codeEquipeActif)
        strategies = toutesStrategies.filtreEquipe(codeEquipeActif)
        joueurs = tousJoueurs.filtreEquipe(codeEquipeActif)
    }

    var body: some View {
        GeometryReader { geo in
            let estPaysage = geo.size.width > geo.size.height
            let estLarge = horizontalSizeClass == .regular

            ZStack {
                fondGradient

                ScrollView {
                    VStack(spacing: estLarge ? 24 : 16) {
                        // En-tête
                        HStack {
                            boutonDarkMode
                                .padding(.leading, estLarge ? 30 : 16)
                                .padding(.top, 12)
                            Spacer()
                        }

                        entete(estLarge: estLarge)

                        // Cartes : layout adaptatif
                        cartesAdaptatives(estLarge: estLarge, estPaysage: estPaysage, geo: geo)

                        // Résumé rapide
                        resumeRapide
                            .padding(.top, 8)
                            .padding(.bottom, 130)
                    }
                }
            }
        }
        .onAppear { recalculerDonnees() }
        .onChange(of: toutesSeances) { recalculerDonnees() }
        .onChange(of: toutesStrategies) { recalculerDonnees() }
        .onChange(of: tousJoueurs) { recalculerDonnees() }
        .onChange(of: codeEquipeActif) { recalculerDonnees() }
    }

    // MARK: - En-tête

    private func entete(estLarge: Bool) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "volleyball.fill")
                    .font(.system(size: estLarge ? 36 : 24, weight: .bold))
                    .foregroundStyle(couleurRole)
                Text("Playco")
                    .font(.system(size: estLarge ? 34 : 22, weight: .bold, design: .rounded))
            }
            Text("Volleyball")
                .font(estLarge ? .title2.weight(.medium) : .caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Fond Liquid Glass

    private var fondGradient: some View {
        ZStack {
            Color(.systemBackground)
            // Double gradient pour profondeur — style Liquid Glass
            RadialGradient(
                colors: [
                    couleurRole.opacity(colorScheme == .dark ? 0.06 : 0.04),
                    .clear
                ],
                center: .top,
                startRadius: 80,
                endRadius: 500
            )
            RadialGradient(
                colors: [
                    PaletteMat.bleu.opacity(colorScheme == .dark ? 0.04 : 0.025),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 60,
                endRadius: 400
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Layout adaptatif des cartes

    @ViewBuilder
    private func cartesAdaptatives(estLarge: Bool, estPaysage: Bool, geo: GeometryProxy) -> some View {
        if estLarge {
            // iPad : grille 3+2
            VStack(spacing: 24) {
                HStack(spacing: 24) {
                    cartePratiques
                    carteMatchs
                    carteStrategies
                }
                HStack(spacing: 24) {
                    carteEquipe
                    carteEntrainement
                }
            }
            .padding(.horizontal, 40)
        } else if estPaysage {
            // iPhone paysage : 3+2
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    cartePratiques
                    carteMatchs
                    carteStrategies
                }
                HStack(spacing: 12) {
                    carteEquipe
                    carteEntrainement
                }
            }
            .padding(.horizontal, 16)
        } else {
            // iPhone portrait : cartes empilées
            VStack(spacing: 12) {
                cartePratiques
                carteMatchs
                carteStrategies
                carteEquipe
                carteEntrainement
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Cartes

    private var seancesPratiques: [Seance] {
        seances.filter { !$0.estMatch }
    }

    private var seancesMatchs: [Seance] {
        seances.filter { $0.estMatch }
    }

    private var cartePratiques: some View {
        let nb = seancesPratiques.count
        return carteSection(
            icone: "calendar.badge.clock",
            titre: "Séances",
            sousTitre: "Pratiques & exercices",
            badge: "\(nb) séance\(nb > 1 ? "s" : "")",
            couleur: PaletteMat.orange,
            section: .pratiques,
            detail: prochainePratique
        )
    }

    private var carteMatchs: some View {
        let nb = seancesMatchs.count
        let victoires = seancesMatchs.filter { $0.resultat == .victoire }.count
        let defaites = seancesMatchs.filter { $0.resultat == .defaite }.count
        return carteSection(
            icone: "flag.fill",
            titre: "Matchs",
            sousTitre: "Résultats & box score",
            badge: nb > 0 ? "\(victoires)V-\(defaites)D" : "Aucun",
            couleur: .red,
            section: .matchs,
            detail: nb > 0 ? "\(nb) match\(nb > 1 ? "s" : "")" : "Planifiez vos matchs"
        )
    }

    private var carteStrategies: some View {
        carteSection(
            icone: "sportscourt.fill",
            titre: "Stratégies",
            sousTitre: "Systèmes collectifs",
            badge: "\(strategies.count) stratégie\(strategies.count > 1 ? "s" : "")",
            couleur: PaletteMat.bleu,
            section: .strategies,
            detail: resumeStrategies
        )
    }

    private var estAthlete: Bool {
        authService.utilisateurConnecte?.role == .etudiant
    }

    private var carteEquipe: some View {
        carteSection(
            icone: estAthlete ? "person.circle.fill" : "person.3.fill",
            titre: estAthlete ? "Mon profil" : "Équipe",
            sousTitre: estAthlete ? "Mes stats & suivi" : "Joueurs & statistiques",
            badge: estAthlete ? "Voir" : { let n = joueursActifsCount; return "\(n) joueur\(n > 1 ? "s" : "")" }(),
            couleur: PaletteMat.vert,
            section: .equipe,
            detail: estAthlete ? nil : resumeEquipe
        )
    }

    @Query(filter: #Predicate<ProgrammeMuscu> { $0.estArchive == false })
    private var programmesMuscu: [ProgrammeMuscu]
    @Query(sort: \SeanceMuscu.date, order: .reverse) private var seancesMuscu: [SeanceMuscu]

    private var programmesMuscuEquipe: [ProgrammeMuscu] {
        programmesMuscu.filtreEquipe(codeEquipeActif)
    }

    private var seancesMuscuEquipe: [SeanceMuscu] {
        seancesMuscu.filtreEquipe(codeEquipeActif)
    }

    private var carteEntrainement: some View {
        let nbProgrammes = programmesMuscuEquipe.count
        let nbSeances = seancesMuscuEquipe.count
        return carteSection(
            icone: "dumbbell.fill",
            titre: "Entraînement",
            sousTitre: "Musculation & charges",
            badge: nbProgrammes > 0 ? "\(nbProgrammes) prog." : "Commencer",
            couleur: PaletteMat.violet,
            section: .entrainement,
            detail: nbSeances > 0 ? "\(nbSeances) séance\(nbSeances > 1 ? "s" : "") complétée\(nbSeances > 1 ? "s" : "")" : "Créez votre premier programme"
        )
    }

    // MARK: - Carte générique

    private func carteSection(icone: String, titre: String, sousTitre: String,
                              badge: String, couleur: Color, section: SectionApp,
                              detail: String?) -> some View {
        let estCompact = horizontalSizeClass != .regular

        return Button {
            onSection(section)
        } label: {
            Group {
                if estCompact {
                    // iPhone : layout horizontal compact
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(couleur.opacity(0.1))
                                .frame(width: 56, height: 56)
                            Image(systemName: icone)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(couleur)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(titre)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(sousTitre)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let detail {
                                Text(detail)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        Spacer()

                        Text(badge)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(couleur)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(couleur.opacity(0.08), in: Capsule())

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, minHeight: 80)
                } else {
                    // iPad : layout vertical avec grande icône
                    VStack(spacing: 16) {
                        Spacer()

                        ZStack {
                            Circle()
                                .fill(couleur.opacity(0.1))
                                .frame(width: 80, height: 80)
                            Image(systemName: icone)
                                .font(.system(size: 38, weight: .semibold))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(couleur)
                        }

                        VStack(spacing: 4) {
                            Text(titre)
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .foregroundStyle(.primary)
                            Text(sousTitre)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        Text(badge)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(couleur)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(couleur.opacity(0.08), in: Capsule())
                            .contentTransition(.numericText())

                        if let detail {
                            Text(detail)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 12)
                        }

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .glassCard(teinte: couleur, cornerRadius: estCompact ? 16 : 20)
        }
        .buttonStyle(GlassButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Section \(titre)")
        .accessibilityHint("\(sousTitre). Double-tapez pour ouvrir.")
        .accessibilityValue(badge)
    }

    // MARK: - Bouton Dark Mode

    private var boutonDarkMode: some View {
        Button {
            withAnimation(LiquidGlassKit.springDefaut) {
                modeSombre.toggle()
            }
        } label: {
            Image(systemName: modeSombre ? "sun.max.fill" : "moon.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(modeSombre ? .yellow : .secondary)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle().strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Menu utilisateur

    private var menuUtilisateur: some View {
        Menu {
            if let utilisateur = authService.utilisateurConnecte {
                Label("\(utilisateur.nomComplet)", systemImage: "person.circle")
                Label("\(utilisateur.role.label)", systemImage: utilisateur.role.icone)
                Divider()
            }

            Button(role: .destructive) {
                withAnimation {
                    authService.deconnexion()
                }
            } label: {
                Label("Déconnexion", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            HStack(spacing: 6) {
                if let utilisateur = authService.utilisateurConnecte {
                    Text(utilisateur.prenom)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    if let photoData = utilisateur.photoData,
                       let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 30, height: 30)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(utilisateur.role.couleur, lineWidth: 1.5)
                            )
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.title3)
                            .foregroundStyle(utilisateur.role.couleur)
                    }
                }
            }
        }
    }

    // MARK: - Computed memoized (P1-04)
    private var joueursActifsCount: Int { joueurs.filter(\.estActif).count }

    private var prochaineSeance: Seance? {
        seances.filter { $0.date > Date() }.min(by: { $0.date < $1.date })
    }

    // MARK: - Détails contextuels

    private var prochainePratique: String? {
        guard let prochaine = prochaineSeance else { return nil }
        return "Prochaine : \(prochaine.date.formatCourt())"
    }

    private var resumeStrategies: String? {
        guard !strategies.isEmpty else { return "Créez vos systèmes" }
        let cats = Set(strategies.map(\.categorieRaw)).count
        return "\(cats) catégorie\(cats > 1 ? "s" : "")"
    }

    private var resumeEquipe: String? {
        guard !joueurs.isEmpty else { return "Ajoutez vos joueurs" }
        let actifs = joueursActifsCount
        return "\(actifs) actif\(actifs > 1 ? "s" : "")"
    }

    // MARK: - Résumé rapide

    private var resumeRapide: some View {
        HStack(spacing: 32) {
            if let prochaine = prochaineSeance {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .foregroundStyle(.orange)
                    Text("Prochaine : \(prochaine.nom) — \(prochaine.date.formatFrancais())")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 20)
    }
}
