//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI

// MARK: - Données page tutoriel

private struct DonneesPageTutoriel: Identifiable {
    let id: Int
    let icone: String
    let couleur: Color
    let titre: String
    let description: String
    let astuces: [String]
}

// MARK: - Tutoriel complet

/// Tutoriel paginé couvrant toutes les fonctionnalités de Playco
struct TutorielView: View {
    @AppStorage("tutorielVu") private var tutorielVu = false
    @Environment(\.dismiss) private var dismiss
    @State private var pageActuelle = 0

    private let pages: [DonneesPageTutoriel] = [
        DonneesPageTutoriel(
            id: 0,
            icone: "volleyball.fill",
            couleur: PaletteMat.orange,
            titre: "Bienvenue dans Playco",
            description: "Votre assistant de coaching volleyball complet. Planifiez vos pratiques, analysez les performances en temps réel et optimisez le potentiel de votre équipe.",
            astuces: [
                "Conçu pour iPad avec support Apple Pencil",
                "Synchronisation iCloud entre tous vos appareils",
                "Interface adaptée pour les coachs et les athlètes",
                "Aucune connexion internet requise pour fonctionner"
            ]
        ),
        DonneesPageTutoriel(
            id: 1,
            icone: "square.grid.2x2.fill",
            couleur: PaletteMat.bleu,
            titre: "L'écran d'accueil",
            description: "Accédez aux 5 sections principales d'un simple tap : Séances, Matchs, Stratégies, Équipe et Entraînement. Chaque section a sa propre couleur pour une navigation intuitive.",
            astuces: [
                "Séances (orange) — pratiques et exercices",
                "Matchs (rouge) — résultats et stats live",
                "Stratégies (bleu) — systèmes collectifs",
                "Équipe (vert) — joueurs et analytics",
                "Entraînement (violet) — musculation et tests"
            ]
        ),
        DonneesPageTutoriel(
            id: 2,
            icone: "calendar.badge.plus",
            couleur: PaletteMat.orange,
            titre: "Séances & Exercices",
            description: "Planifiez vos pratiques, créez des exercices avec un terrain dessinable et organisez-les en étapes. Importez des exercices depuis la bibliothèque intégrée.",
            astuces: [
                "Glissez-déposez pour réordonner les exercices",
                "Importez depuis la bibliothèque d'exercices prédéfinis",
                "Gérez les présences et évaluez vos joueurs par séance",
                "Dupliquez ou archivez vos séances facilement"
            ]
        ),
        DonneesPageTutoriel(
            id: 3,
            icone: "flag.fill",
            couleur: .red,
            titre: "Matchs & Stats live",
            description: "Créez des matchs, saisissez le score par set et utilisez le mode live pour enregistrer chaque point en temps réel avec le joueur et le type d'action.",
            astuces: [
                "Mode Live split-screen : dashboard + saisie côte à côte",
                "Composition du 6 de départ par poste et rotation",
                "Score set par set (1 à 5 sets)",
                "Rapport d'analyse pour étudier l'adversaire",
                "Undo du dernier point en un tap"
            ]
        ),
        DonneesPageTutoriel(
            id: 4,
            icone: "pencil.and.ruler.fill",
            couleur: PaletteMat.orange,
            titre: "Terrain dessinable",
            description: "Dessinez librement avec Apple Pencil sur le terrain de volleyball. Placez des joueurs, ballons, flèches et trajectoires, puis créez des étapes pour animer vos systèmes.",
            astuces: [
                "Undo/redo avec pile de 15 états",
                "Éléments vectoriels : joueurs, ballons, flèches, rotations",
                "Formations automatiques : 5-1, 4-2, 6-2, beach",
                "Multi-étapes pour animer un exercice pas à pas",
                "Auto-sauvegarde toutes les 3 secondes"
            ]
        ),
        DonneesPageTutoriel(
            id: 5,
            icone: "lightbulb.fill",
            couleur: PaletteMat.bleu,
            titre: "Stratégies collectives",
            description: "Documentez vos systèmes d'attaque, de réception, de service et de défense. Chaque stratégie a son propre terrain éditable avec notes et étapes.",
            astuces: [
                "Catégories : attaque, réception, service, défense, transition",
                "Sauvegardez vos stratégies en bibliothèque d'exercices",
                "Terrain éditable avec notes et description par stratégie",
                "Navigation par swipe entre les étapes d'une stratégie"
            ]
        ),
        DonneesPageTutoriel(
            id: 6,
            icone: "person.3.fill",
            couleur: PaletteMat.vert,
            titre: "Équipe & Joueurs",
            description: "Gérez votre roster complet, suivez les statistiques NCAA/FIVB de chaque joueur et fixez des objectifs individuels avec suivi de progression automatique.",
            astuces: [
                "Stats complètes : attaque, service, bloc, réception, jeu",
                "Graphiques d'évolution par catégorie (Swift Charts)",
                "Comparaison joueur vs moyenne de l'équipe",
                "Objectifs individuels avec progression automatique",
                "Tableau de bord agrégé de toute l'équipe"
            ]
        ),
        DonneesPageTutoriel(
            id: 7,
            icone: "chart.bar.xaxis",
            couleur: PaletteMat.vert,
            titre: "Analytics & Stats avancées",
            description: "Analysez les tendances de votre saison, les performances par rotation, le heatmap terrain par zone et consultez le palmarès des records.",
            astuces: [
                "Tendances saison : victoires/défaites, séries, efficacité attaque",
                "Heatmap terrain avec zones 1-6 réelles par catégorie",
                "Stats par rotation : efficacité, points pour/contre",
                "Palmarès et records individuels et d'équipe"
            ]
        ),
        DonneesPageTutoriel(
            id: 8,
            icone: "figure.strengthtraining.traditional",
            couleur: PaletteMat.violet,
            titre: "Entraînement physique",
            description: "Créez des programmes de musculation personnalisés, suivez les charges en temps réel et mesurez la progression avec les tests physiques.",
            astuces: [
                "Programmes assignables à des joueurs spécifiques",
                "Mode live avec chrono intégré et repos programmés",
                "Suivi graphique de l'évolution des charges",
                "Tests physiques : vitesse, saut, force, endurance"
            ]
        ),
        DonneesPageTutoriel(
            id: 9,
            icone: "bubble.left.and.bubble.right.fill",
            couleur: PaletteMat.violet,
            titre: "Messagerie & Collaboration",
            description: "Communiquez avec votre équipe via la messagerie intégrée. Envoyez des messages à toute l'équipe ou en conversation privée avec un joueur.",
            astuces: [
                "Fil d'équipe visible par tous les membres",
                "Conversations privées coach ↔ athlète",
                "Badges de messages non-lus dans le dock flottant",
                "Multi-équipes : chaque équipe a son propre fil"
            ]
        ),
        DonneesPageTutoriel(
            id: 10,
            icone: "calendar",
            couleur: PaletteMat.orange,
            titre: "Calendrier & Planification",
            description: "Visualisez toutes vos activités dans un calendrier unifié : pratiques, matchs, entraînements et phases de saison. Synchronisez avec Apple Calendar.",
            astuces: [
                "Vue mensuelle avec indicateurs colorés par type",
                "Phases de saison configurables (pré-saison, compétition, tournoi…)",
                "Synchronisation avec Apple Calendar en un tap",
                "Créneaux récurrents pour les pratiques régulières"
            ]
        ),
        DonneesPageTutoriel(
            id: 11,
            icone: "square.and.arrow.up.fill",
            couleur: PaletteMat.bleu,
            titre: "Export & Partage",
            description: "Exportez vos statistiques en CSV pour Excel/Numbers, générez des PDF de résumé de match et projetez vos terrains et stratégies via AirPlay.",
            astuces: [
                "CSV compatible Excel, Numbers et Google Sheets",
                "PDF résumé match avec box score partageable",
                "Mode présentation plein écran pour projection AirPlay",
                "Partagez directement via AirDrop, Mail ou Messages"
            ]
        )
    ]

    var body: some View {
        ZStack {
            // Fond animé
            fondGradient

            VStack(spacing: 0) {
                // Bouton passer
                HStack {
                    Spacer()
                    if pageActuelle < pages.count - 1 {
                        Button {
                            fermer()
                        } label: {
                            Text("Passer")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, LiquidGlassKit.espaceMD)
                                .padding(.vertical, LiquidGlassKit.espaceSM)
                        }
                    }
                }
                .padding(.horizontal, LiquidGlassKit.espaceMD)
                .padding(.top, LiquidGlassKit.espaceSM)

                // Pages
                TabView(selection: $pageActuelle) {
                    ForEach(pages) { page in
                        PageTutoriel(donnees: page)
                            .tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Indicateur de pages
                indicateurPages
                    .padding(.bottom, LiquidGlassKit.espaceMD)

                // Bouton principal
                boutonPrincipal
                    .padding(.horizontal, LiquidGlassKit.espaceXL)
                    .padding(.bottom, LiquidGlassKit.espaceXL)
            }
        }
        .animation(LiquidGlassKit.springDefaut, value: pageActuelle)
    }

    // MARK: - Fond gradient

    private var fondGradient: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RadialGradient(
                colors: [
                    pages[pageActuelle].couleur.opacity(0.3),
                    pages[pageActuelle].couleur.opacity(0.08),
                    .clear
                ],
                center: .top,
                startRadius: 100,
                endRadius: 600
            )
            .ignoresSafeArea()
            .animation(LiquidGlassKit.springDefaut, value: pageActuelle)
        }
    }

    // MARK: - Indicateur de pages

    private var indicateurPages: some View {
        HStack(spacing: 6) {
            ForEach(pages) { page in
                Capsule()
                    .fill(page.id == pageActuelle
                          ? pages[pageActuelle].couleur
                          : Color.white.opacity(0.25))
                    .frame(width: page.id == pageActuelle ? 20 : 6, height: 6)
                    .animation(LiquidGlassKit.springDefaut, value: pageActuelle)
            }
        }
    }

    // MARK: - Bouton principal

    private var boutonPrincipal: some View {
        Button {
            if pageActuelle < pages.count - 1 {
                withAnimation(LiquidGlassKit.springDefaut) {
                    pageActuelle += 1
                }
            } else {
                fermer()
            }
        } label: {
            Text(pageActuelle < pages.count - 1 ? "Suivant" : "Commencer")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, LiquidGlassKit.espaceMD)
                .background(
                    pages[pageActuelle].couleur,
                    in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMoyen)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Fermer

    private func fermer() {
        tutorielVu = true
        dismiss()
    }
}

// MARK: - Page individuelle

private struct PageTutoriel: View {
    let donnees: DonneesPageTutoriel

    var body: some View {
        ScrollView {
            VStack(spacing: LiquidGlassKit.espaceLG) {
                Spacer(minLength: LiquidGlassKit.espaceXL)

                // Icône
                ZStack {
                    Circle()
                        .fill(donnees.couleur.opacity(0.15))
                        .frame(width: 100, height: 100)
                    Image(systemName: donnees.icone)
                        .font(.system(size: 44))
                        .foregroundStyle(donnees.couleur)
                        .symbolRenderingMode(.hierarchical)
                }

                // Titre
                Text(donnees.titre)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                // Description
                Text(donnees.description)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, LiquidGlassKit.espaceLG)

                // Astuces
                VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM + 4) {
                    ForEach(donnees.astuces, id: \.self) { astuce in
                        HStack(alignment: .top, spacing: LiquidGlassKit.espaceSM + 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(donnees.couleur)
                            Text(astuce)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.75))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(LiquidGlassKit.espaceMD + 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMoyen))

                Spacer(minLength: LiquidGlassKit.espaceXL)
            }
            .padding(.horizontal, LiquidGlassKit.espaceLG)
        }
        .scrollIndicators(.hidden)
    }
}
