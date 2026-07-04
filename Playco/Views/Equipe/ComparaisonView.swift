//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Comparaison des stats d'un joueur vs la moyenne de son poste.
/// Fallback : moyenne de l'équipe entière si le poste compte trop peu de
/// joueurs avec des matchs joués.
struct ComparaisonView: View {
    let joueur: JoueurEquipe
    /// Vrai quand la vue est incorporée dans la fiche joueur (pas de ScrollView propre).
    var estIncorporee: Bool = false

    @Query(filter: #Predicate<JoueurEquipe> { $0.estActif == true },
           sort: \JoueurEquipe.numero) private var tousJoueurs: [JoueurEquipe]
    @Environment(\.codeEquipeActif) private var codeEquipeActif

    // MARK: - Constantes

    /// Nombre minimal de joueurs du poste (matchs joués > 0) pour comparer
    /// au poste plutôt qu'à l'équipe entière.
    private static let minimumJoueursPoste = 2
    /// Seuil sous lequel la moyenne est considérée nulle (protection ÷ 0).
    private static let epsilonMoyenne = 0.0001
    /// Valeur plancher pour normaliser les barres (évite ÷ 0).
    private static let plancherNormalisation = 0.01
    /// `JoueurEquipe.efficaciteReception` est déjà en échelle 0-100.
    private static let echellePourcentage = 100.0
    private static let largeurBarreMinimale: CGFloat = 4
    private static let hauteurBarre: CGFloat = 12
    private static let largeurRepereMoyenne: CGFloat = 2
    private static let largeurColonneValeurs: CGFloat = 84
    private static let tailleAvatar: CGFloat = 50

    // MARK: - Cache moyennes

    /// Moyennes de référence pré-calculées — cache @State (pattern perfo
    /// projet) : évite 12 reduce sur les joueurs à chaque render.
    private struct MoyennesEquipe: Equatable {
        var kills = 0.0
        /// Fraction 0-1 (convention D1 — formatée « .350 » à l'affichage).
        var rendementAttaque = 0.0
        var erreursAttaque = 0.0
        var aces = 0.0
        var erreursService = 0.0
        var servicesTotaux = 0.0
        var blocsSeuls = 0.0
        var blocsAssistes = 0.0
        var receptionsReussies = 0.0
        /// Échelle 0-100 (convention `JoueurEquipe.efficaciteReception`).
        var efficaciteReception = 0.0
        var passesDecisives = 0.0
        var manchettes = 0.0
        /// Nombre de joueurs entrant dans la moyenne de référence.
        var nombreJoueurs = 0
        /// Vrai si la référence est le poste du joueur (sinon équipe entière).
        var estParPoste = false
    }

    @State private var moyennes = MoyennesEquipe()

    /// Invalide le cache sur mutation in-place (stats saisies/modifiées) — .onChange(collection) ne voit que les insertions/suppressions.
    private var signatureStats: Int {
        tousJoueurs.reduce(0) {
            $0 + $1.matchsJoues + $1.attaquesReussies + $1.erreursAttaque + $1.attaquesTotales
                + $1.aces + $1.erreursService + $1.servicesTotaux
                + $1.blocsSeuls + $1.blocsAssistes
                + $1.receptionsReussies + $1.receptionsTotales
                + $1.passesDecisives + $1.manchettes
        }
    }

    /// Invalide le cache si un poste change : la référence de comparaison
    /// dépend du poste du joueur ET de celui de ses coéquipiers.
    private var signaturePostes: String {
        tousJoueurs.map(\.posteRaw).joined(separator: "|")
    }

    var body: some View {
        Group {
            if estIncorporee {
                // Incorporée dans la fiche joueur (segmenté 2.3) : le parent
                // fournit déjà le ScrollView, l'en-tête joueur est redondant.
                VStack(spacing: LiquidGlassKit.espaceLG) {
                    noteReference
                    categoriesStats
                }
            } else {
                ScrollView {
                    VStack(spacing: LiquidGlassKit.espaceLG) {
                        enteteJoueurComparaison
                        Divider()
                        noteReference
                        categoriesStats
                    }
                    .padding(.vertical)
                }
                .navigationTitle("Comparaison")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .onAppear { mettreAJourMoyennes() }
        .onChange(of: tousJoueurs) { mettreAJourMoyennes() }
        .onChange(of: signatureStats) { mettreAJourMoyennes() }
        .onChange(of: signaturePostes) { mettreAJourMoyennes() }
        .onChange(of: codeEquipeActif) { mettreAJourMoyennes() }
    }

    // MARK: - En-tête joueur

    private var enteteJoueurComparaison: some View {
        HStack(spacing: LiquidGlassKit.espaceSM + 4) {
            ZStack {
                Circle()
                    .fill(PaletteMat.vert.opacity(LiquidGlassKit.badgeFond))
                    .frame(width: Self.tailleAvatar, height: Self.tailleAvatar)
                Text("#\(joueur.numero)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(PaletteMat.vert)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(joueur.nomComplet)
                    .font(.headline)
                Text(joueur.poste.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(libelleMatchs(joueur.matchsJoues))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    /// Note expliquant la référence de comparaison (poste ou équipe).
    private var noteReference: some View {
        Text(texteReference)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
    }

    private var texteReference: String {
        guard moyennes.nombreJoueurs > 0 else {
            return "Aucune moyenne disponible — aucun joueur n'a encore de match joué."
        }
        if moyennes.estParPoste {
            return "Moyenne des \(moyennes.nombreJoueurs) joueurs au poste \(joueur.poste.rawValue)"
        }
        return "Moyenne de l'équipe (\(moyennes.nombreJoueurs) joueurs)"
    }

    @ViewBuilder
    private var categoriesStats: some View {
        categorieSection(titre: "Attaque", teinte: PaletteMat.orange, stats: statsAttaque)
        categorieSection(titre: "Service", teinte: PaletteMat.bleu, stats: statsService)
        categorieSection(titre: "Bloc", teinte: PaletteMat.violet, stats: statsBloc)
        categorieSection(titre: "Réception", teinte: PaletteMat.vert, stats: statsReception)
        categorieSection(titre: "Jeu", teinte: PaletteMat.bleu, stats: statsJeu)
    }

    // MARK: - Mise à jour du cache

    /// Moyenne par poste (>= `minimumJoueursPoste` joueurs du poste avec des
    /// matchs joués), sinon fallback sur la moyenne de l'équipe entière.
    private func mettreAJourMoyennes() {
        let equipe = tousJoueurs.filtreEquipe(codeEquipeActif).filter { $0.matchsJoues > 0 }
        let memePoste = equipe.filter { $0.poste == joueur.poste }
        let estParPoste = memePoste.count >= Self.minimumJoueursPoste
        let reference = estParPoste ? memePoste : equipe
        let nb = max(1, Double(reference.count))
        func moyenne(_ valeur: (JoueurEquipe) -> Double) -> Double {
            reference.reduce(0.0) { $0 + valeur($1) } / nb
        }
        moyennes = MoyennesEquipe(
            kills: moyenne { Double($0.attaquesReussies) },
            rendementAttaque: moyenne { $0.pourcentageAttaque },
            erreursAttaque: moyenne { Double($0.erreursAttaque) },
            aces: moyenne { Double($0.aces) },
            erreursService: moyenne { Double($0.erreursService) },
            servicesTotaux: moyenne { Double($0.servicesTotaux) },
            blocsSeuls: moyenne { Double($0.blocsSeuls) },
            blocsAssistes: moyenne { Double($0.blocsAssistes) },
            receptionsReussies: moyenne { Double($0.receptionsReussies) },
            efficaciteReception: moyenne { $0.efficaciteReception },
            passesDecisives: moyenne { Double($0.passesDecisives) },
            manchettes: moyenne { Double($0.manchettes) },
            nombreJoueurs: reference.count,
            estParPoste: estParPoste
        )
    }

    // MARK: - Section catégorie

    private func categorieSection(titre: String, teinte: Color, stats: [StatComparee]) -> some View {
        VStack(alignment: .leading, spacing: LiquidGlassKit.espaceSM + 4) {
            EnTeteSection(titre: titre)
            ForEach(stats) { stat in
                ligneComparaison(stat, teinte: teinte)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Ligne de comparaison

    /// Une ligne : label + écart % vs moyenne, barre du joueur avec repère
    /// vertical de moyenne, valeurs formatées (joueur en gras, moyenne dessous).
    private func ligneComparaison(_ stat: StatComparee, teinte: Color) -> some View {
        let maxVal = max(stat.valeurJoueur, stat.moyenne, Self.plancherNormalisation)
        let ratioJoueur = min(1, max(0, stat.valeurJoueur / maxVal))
        let ratioMoyenne = min(1, max(0, stat.moyenne / maxVal))

        return VStack(alignment: .leading, spacing: LiquidGlassKit.espaceXS) {
            HStack(alignment: .firstTextBaseline) {
                Text(stat.label)
                    .font(.caption.weight(.medium))
                Spacer()
                etiquetteEcart(valeurJoueur: stat.valeurJoueur, moyenne: stat.moyenne)
            }

            HStack(spacing: LiquidGlassKit.espaceSM) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Piste
                        RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMini, style: .continuous)
                            .fill(teinte.opacity(LiquidGlassKit.badgeFond))
                        // Barre joueur
                        RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMini, style: .continuous)
                            .fill(teinte)
                            .frame(width: max(Self.largeurBarreMinimale, geo.size.width * ratioJoueur))
                        // Repère de moyenne : trait vertical sur la barre du joueur
                        RoundedRectangle(cornerRadius: Self.largeurRepereMoyenne / 2)
                            .fill(PaletteMat.textePrincipal)
                            .frame(width: Self.largeurRepereMoyenne)
                            .offset(x: positionRepere(largeur: geo.size.width, ratio: ratioMoyenne))
                    }
                }
                .frame(height: Self.hauteurBarre)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(stat.formatter(stat.valeurJoueur))
                        .font(.caption.weight(.bold).monospacedDigit())
                        .contentTransition(.numericText())
                    Text("moy. \(stat.formatter(stat.moyenne))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .frame(width: Self.largeurColonneValeurs, alignment: .trailing)
            }
        }
        .padding(.vertical, LiquidGlassKit.espaceXS)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibiliteLigne(stat))
    }

    /// Position x du repère de moyenne, borné aux limites de la piste.
    private func positionRepere(largeur: CGFloat, ratio: Double) -> CGFloat {
        min(max(largeur * ratio - Self.largeurRepereMoyenne / 2, 0),
            largeur - Self.largeurRepereMoyenne)
    }

    // MARK: - Écart vs moyenne

    /// Écart relatif : « +18 % » (PaletteMat.positif) ou « −12 % »
    /// (PaletteMat.negatif). Masqué quand la moyenne est (quasi) nulle (÷ 0).
    @ViewBuilder
    private func etiquetteEcart(valeurJoueur: Double, moyenne: Double) -> some View {
        if let ecart = ecartRelatif(valeurJoueur: valeurJoueur, moyenne: moyenne) {
            Text(formaterEcart(ecart))
                .font(TypographieStats.delta)
                .monospacedDigit()
                .foregroundStyle(ecart >= 0 ? PaletteMat.positif : PaletteMat.negatif)
        }
    }

    /// (joueur − moyenne) ÷ |moyenne| — nil si la moyenne est (quasi) nulle.
    private func ecartRelatif(valeurJoueur: Double, moyenne: Double) -> Double? {
        guard abs(moyenne) > Self.epsilonMoyenne else { return nil }
        return (valeurJoueur - moyenne) / abs(moyenne)
    }

    private func formaterEcart(_ ecart: Double) -> String {
        let pct = Int((abs(ecart) * Self.echellePourcentage).rounded())
        return (ecart >= 0 ? "+" : "−") + "\(pct) %"
    }

    private func accessibiliteLigne(_ stat: StatComparee) -> String {
        var texte = "\(stat.label) : \(stat.formatter(stat.valeurJoueur)), moyenne \(stat.formatter(stat.moyenne))"
        if let ecart = ecartRelatif(valeurJoueur: stat.valeurJoueur, moyenne: stat.moyenne) {
            texte += ecart >= 0 ? ", au-dessus de la moyenne" : ", en dessous de la moyenne"
        }
        return texte
    }

    private func libelleMatchs(_ nombre: Int) -> String {
        nombre > 1 ? "\(nombre) matchs" : "\(nombre) match"
    }

    // MARK: - Données comparatives

    /// Une ligne de comparaison : valeur du joueur vs moyenne de référence,
    /// avec formatage canonique (D2 : rendement « .350 », % « 85,0 % »).
    private struct StatComparee: Identifiable {
        let label: String
        let valeurJoueur: Double
        let moyenne: Double
        let formatter: (Double) -> String
        var id: String { label }
    }

    private var statsAttaque: [StatComparee] {
        [
            StatComparee(label: "Kills", valeurJoueur: Double(joueur.attaquesReussies),
                         moyenne: moyennes.kills, formatter: FormatMetriques.points),
            // D2 : rendement attaque en convention volleyball (« .350 »).
            StatComparee(label: "Rendement attaque", valeurJoueur: joueur.pourcentageAttaque,
                         moyenne: moyennes.rendementAttaque, formatter: FormatMetriques.hittingVolley),
            StatComparee(label: "Erreurs attaque", valeurJoueur: Double(joueur.erreursAttaque),
                         moyenne: moyennes.erreursAttaque, formatter: FormatMetriques.points),
        ]
    }

    private var statsService: [StatComparee] {
        [
            StatComparee(label: "Aces", valeurJoueur: Double(joueur.aces),
                         moyenne: moyennes.aces, formatter: FormatMetriques.points),
            StatComparee(label: "Erreurs service", valeurJoueur: Double(joueur.erreursService),
                         moyenne: moyennes.erreursService, formatter: FormatMetriques.points),
            StatComparee(label: "Total services", valeurJoueur: Double(joueur.servicesTotaux),
                         moyenne: moyennes.servicesTotaux, formatter: FormatMetriques.points),
        ]
    }

    private var statsBloc: [StatComparee] {
        [
            StatComparee(label: "Blocs seuls", valeurJoueur: Double(joueur.blocsSeuls),
                         moyenne: moyennes.blocsSeuls, formatter: FormatMetriques.points),
            StatComparee(label: "Blocs assistés", valeurJoueur: Double(joueur.blocsAssistes),
                         moyenne: moyennes.blocsAssistes, formatter: FormatMetriques.points),
        ]
    }

    private var statsReception: [StatComparee] {
        [
            StatComparee(label: "Réceptions réussies", valeurJoueur: Double(joueur.receptionsReussies),
                         moyenne: moyennes.receptionsReussies, formatter: FormatMetriques.points),
            // `efficaciteReception` est déjà en échelle 0-100 — ne pas re-multiplier.
            StatComparee(label: "Réception (eff.)", valeurJoueur: joueur.efficaciteReception,
                         moyenne: moyennes.efficaciteReception,
                         formatter: { FormatMetriques.pourcentage($0 / Self.echellePourcentage) }),
        ]
    }

    private var statsJeu: [StatComparee] {
        [
            StatComparee(label: "Passes décisives", valeurJoueur: Double(joueur.passesDecisives),
                         moyenne: moyennes.passesDecisives, formatter: FormatMetriques.points),
            StatComparee(label: "Manchettes", valeurJoueur: Double(joueur.manchettes),
                         moyenne: moyennes.manchettes, formatter: FormatMetriques.points),
        ]
    }
}
