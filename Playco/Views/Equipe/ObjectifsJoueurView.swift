//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Gestion des objectifs individuels d'un joueur
struct ObjectifsJoueurView: View {
    let joueur: JoueurEquipe

    @Environment(\.modelContext) private var modelContext
    @Environment(\.codeEquipeActif) private var codeEquipeActif
    @Query private var tousObjectifs: [ObjectifJoueur]

    @State private var objectifsJoueur: [ObjectifJoueur] = []
    @State private var afficherAjout = false

    var body: some View {
        VStack(spacing: LiquidGlassKit.espaceMD) {
            entete
            resumeProgression

            if objectifsJoueur.isEmpty {
                ContentUnavailableView(
                    "Aucun objectif",
                    systemImage: "target",
                    description: Text("Ajoutez des objectifs pour suivre la progression de \(joueur.prenom).")
                )
            } else {
                listeObjectifs
            }
        }
        .onAppear { mettreAJour() }
        .onChange(of: tousObjectifs) { _, _ in mettreAJour() }
        .sheet(isPresented: $afficherAjout) {
            NouvelObjectifView(joueur: joueur)
        }
    }

    // MARK: - En-tête

    private var entete: some View {
        HStack {
            VStack(alignment: .leading, spacing: LiquidGlassKit.espaceXS) {
                Label("Objectifs", systemImage: "target")
                    .font(.headline.weight(.bold))
                Text("#\(joueur.numero) \(joueur.prenom) \(joueur.nom)")
                    .font(.subheadline)
                    .foregroundStyle(PaletteMat.texteSecondaire)
            }
            Spacer()
            Button {
                afficherAjout = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(PaletteMat.vert)
                    .symbolRenderingMode(.hierarchical)
            }
        }
    }

    // MARK: - Résumé progression

    private var resumeProgression: some View {
        let total = objectifsJoueur.count
        let atteints = objectifsJoueur.filter(\.estAtteint).count
        let pct = total > 0 ? Double(atteints) / Double(total) : 0

        return HStack(spacing: LiquidGlassKit.espaceMD) {
            VStack(spacing: LiquidGlassKit.espaceXS) {
                Text("\(atteints)/\(total)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("atteints")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(PaletteMat.texteSecondaire)
            }

            Gauge(value: pct) {
                EmptyView()
            } currentValueLabel: {
                Text(String(format: "%.0f%%", pct * 100))
                    .font(.caption.weight(.bold))
            }
            .gaugeStyle(.accessoryCircular)
            .tint(Gradient(colors: [PaletteMat.orange, PaletteMat.vert]))
            .frame(width: 60, height: 60)
        }
        .frame(maxWidth: .infinity)
        .padding(LiquidGlassKit.espaceSM + 4)
        .glassCard(teinte: PaletteMat.vert, cornerRadius: LiquidGlassKit.rayonMoyen)
    }

    // MARK: - Liste

    private var listeObjectifs: some View {
        VStack(spacing: LiquidGlassKit.espaceSM) {
            ForEach(objectifsJoueur) { objectif in
                carteObjectif(objectif)
            }
        }
    }

    private func carteObjectif(_ objectif: ObjectifJoueur) -> some View {
        let progression = calculerProgression(objectif)

        return HStack(spacing: LiquidGlassKit.espaceSM + 4) {
            // Icône catégorie
            Image(systemName: objectif.categorie.icone)
                .font(.title3)
                .foregroundStyle(objectif.categorie.couleur)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 32)

            // Détails
            VStack(alignment: .leading, spacing: LiquidGlassKit.espaceXS) {
                HStack {
                    Text(objectif.titre)
                        .font(.subheadline.weight(.semibold))
                        .strikethrough(objectif.estAtteint)
                    Spacer()
                    if objectif.estAtteint {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(PaletteMat.vert)
                    }
                }

                HStack(spacing: LiquidGlassKit.espaceSM) {
                    Text("Cible : \(formatterValeur(objectif.cible)) \(objectif.unite)")
                        .font(.caption)
                        .foregroundStyle(PaletteMat.texteSecondaire)

                    if progression > 0 {
                        Text("Actuel : \(formatterValeur(progression))")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(progression >= objectif.cible ? PaletteMat.vert : PaletteMat.orange)
                    }
                }

                // Barre de progression
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.12))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [objectif.categorie.couleur.opacity(0.6), objectif.categorie.couleur],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * min(1, objectif.cible > 0 ? progression / objectif.cible : 0))
                            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: progression)
                    }
                }
                .frame(height: 6)
            }

            // Supprimer / Marquer atteint
            Menu {
                Button {
                    withAnimation(LiquidGlassKit.springDefaut) {
                        objectif.estAtteint.toggle()
                    }
                } label: {
                    Label(
                        objectif.estAtteint ? "Marquer non atteint" : "Marquer atteint",
                        systemImage: objectif.estAtteint ? "xmark.circle" : "checkmark.circle"
                    )
                }
                Button(role: .destructive) {
                    withAnimation(LiquidGlassKit.springDefaut) {
                        modelContext.delete(objectif)
                    }
                } label: {
                    Label("Supprimer", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption)
                    .foregroundStyle(PaletteMat.texteSecondaire)
                    .padding(LiquidGlassKit.espaceSM)
            }
        }
        .padding(LiquidGlassKit.espaceSM + 4)
        .glassSection()
    }

    // MARK: - Logique

    private func mettreAJour() {
        objectifsJoueur = tousObjectifs
            .filtreEquipe(codeEquipeActif)
            .filter { $0.joueurID == joueur.id }
            .sorted { ($0.estAtteint ? 1 : 0) < ($1.estAtteint ? 1 : 0) }
    }

    /// Calcule la progression actuelle du joueur pour un objectif donné
    private func calculerProgression(_ objectif: ObjectifJoueur) -> Double {
        switch objectif.categorie {
        case .attaque:
            if objectif.unite == "%" { return joueur.pourcentageAttaque * 100 }
            if objectif.unite == "kills/set" { return joueur.killsParSet }
            return Double(joueur.attaquesReussies)
        case .service:
            if objectif.unite == "aces/set" { return joueur.acesParSet }
            return Double(joueur.aces)
        case .bloc:
            if objectif.unite == "blocs/set" { return joueur.blocsParSet }
            return Double(joueur.blocsTotaux)
        case .reception:
            if objectif.unite == "%" { return joueur.efficaciteReception * 100 }
            return Double(joueur.receptionsReussies)
        case .jeu:
            if objectif.unite == "passes/set" { return joueur.passesParSet }
            return Double(joueur.passesDecisives)
        case .physique:
            return 0
        }
    }

    private func formatterValeur(_ val: Double) -> String {
        val == val.rounded() ? String(format: "%.0f", val) : String(format: "%.1f", val)
    }
}

// MARK: - Nouvel objectif

struct NouvelObjectifView: View {
    let joueur: JoueurEquipe

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.codeEquipeActif) private var codeEquipeActif

    @State private var titre = ""
    @State private var categorie: CategorieObjectif = .attaque
    @State private var cible: String = ""
    @State private var unite = ""
    @State private var notes = ""

    /// Suggestions d'objectifs prédéfinis
    private let suggestions: [(String, CategorieObjectif, Double, String)] = [
        ("Efficacité attaque 25%+", .attaque, 25, "%"),
        ("3 kills par set", .attaque, 3, "kills/set"),
        ("Réception positive 60%+", .reception, 60, "%"),
        ("1 ace par set", .service, 1, "aces/set"),
        ("2 blocs par set", .bloc, 2, "blocs/set"),
        ("5 passes décisives/set", .jeu, 5, "passes/set"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Suggestions rapides") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: LiquidGlassKit.espaceSM) {
                            ForEach(suggestions, id: \.0) { sug in
                                Button {
                                    titre = sug.0
                                    categorie = sug.1
                                    cible = formatterDouble(sug.2)
                                    unite = sug.3
                                } label: {
                                    HStack(spacing: LiquidGlassKit.espaceXS) {
                                        Image(systemName: sug.1.icone)
                                            .font(.caption2)
                                        Text(sug.0)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, LiquidGlassKit.espaceSM + 2)
                                    .padding(.vertical, LiquidGlassKit.espaceSM)
                                    .background(sug.1.couleur.opacity(0.1), in: Capsule())
                                    .foregroundStyle(sug.1.couleur)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, LiquidGlassKit.espaceXS)
                    }
                }

                Section("Détails") {
                    TextField("Titre de l'objectif", text: $titre)
                    Picker("Catégorie", selection: $categorie) {
                        ForEach(CategorieObjectif.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.icone)
                                .tag(cat)
                        }
                    }
                    HStack {
                        TextField("Cible", text: $cible)
                            .keyboardType(.decimalPad)
                        TextField("Unité (%, kills/set...)", text: $unite)
                    }
                }

                Section("Notes (optionnel)") {
                    TextField("Notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Nouvel objectif")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") { sauvegarder() }
                        .disabled(titre.isEmpty || cible.isEmpty)
                }
            }
        }
    }

    private func sauvegarder() {
        guard let valeurCible = Double(cible.replacingOccurrences(of: ",", with: ".")) else { return }
        let objectif = ObjectifJoueur(
            joueurID: joueur.id,
            titre: titre,
            categorie: categorie,
            cible: valeurCible,
            unite: unite
        )
        objectif.codeEquipe = codeEquipeActif
        objectif.notes = notes
        modelContext.insert(objectif)
        dismiss()
    }

    private func formatterDouble(_ val: Double) -> String {
        val == val.rounded() ? String(format: "%.0f", val) : String(format: "%.1f", val)
    }
}
