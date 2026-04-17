//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

// MARK: - Sheet création nouvelle équipe

struct NouvelleEquipeSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var etablissements: [Etablissement]

    @State private var nom = ""
    @State private var categorie: CategorieEquipe = .masculin
    @State private var division: DivisionEquipe = .division1
    @State private var saison = ""

    // Établissement
    @State private var choixEtablissement: ChoixEtablissement = .existant
    @State private var etablissementSelectionne: Etablissement?
    @State private var nouveauNomEtablissement = ""
    @State private var nouveauTypeEtablissement: TypeEtablissement = .universite
    @State private var nouvelleVille = ""
    @State private var nouvelleProvince = "QC"

    enum ChoixEtablissement: String, CaseIterable {
        case existant = "Existant"
        case nouveau = "Nouveau"
    }

    private let provinces = [
        "QC", "ON", "BC", "AB", "SK", "MB", "NB", "NS", "PE", "NL", "NT", "YT", "NU"
    ]

    private var formulaireValide: Bool {
        let nomOk = !nom.trimmingCharacters(in: .whitespaces).isEmpty
        if choixEtablissement == .nouveau {
            return nomOk && !nouveauNomEtablissement.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return nomOk
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nom de l'équipe") {
                    TextField("Ex: Diablos B", text: $nom)
                }
                Section("Catégorie") {
                    Picker("Catégorie", selection: $categorie) {
                        ForEach(CategorieEquipe.allCases, id: \.self) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Division") {
                    Picker("Division", selection: $division) {
                        ForEach(DivisionEquipe.allCases, id: \.self) { d in
                            Text(d.rawValue).tag(d)
                        }
                    }
                }
                Section("Saison") {
                    TextField("Ex: 2025-2026", text: $saison)
                }

                // Établissement
                Section("Établissement") {
                    if !etablissements.isEmpty {
                        Picker("", selection: $choixEtablissement) {
                            ForEach(ChoixEtablissement.allCases, id: \.self) { c in
                                Text(c.rawValue).tag(c)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    if choixEtablissement == .existant && !etablissements.isEmpty {
                        ForEach(etablissements) { etab in
                            Button {
                                etablissementSelectionne = etab
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(etab.nom)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.primary)
                                        Text("\(etab.typeEtablissement.rawValue) — \(etab.ville.isEmpty ? etab.province : "\(etab.ville), \(etab.province)")")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if etablissementSelectionne?.id == etab.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(PaletteMat.vert)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        TextField("Nom de l'établissement", text: $nouveauNomEtablissement)
                        Picker("Type", selection: $nouveauTypeEtablissement) {
                            ForEach(TypeEtablissement.allCases, id: \.self) { t in
                                Text(t.rawValue).tag(t)
                            }
                        }
                        HStack {
                            TextField("Ville", text: $nouvelleVille)
                            Picker("Province", selection: $nouvelleProvince) {
                                ForEach(provinces, id: \.self) { p in
                                    Text(p).tag(p)
                                }
                            }
                            .frame(width: 90)
                        }
                    }
                }
            }
            .navigationTitle("Nouvelle équipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") { creerEquipe() }
                        .disabled(!formulaireValide)
                }
            }
            .onAppear {
                // Pré-sélectionner le premier établissement
                if etablissementSelectionne == nil {
                    etablissementSelectionne = etablissements.first
                }
                if etablissements.isEmpty {
                    choixEtablissement = .nouveau
                }
            }
        }
    }

    private func creerEquipe() {
        // Établissement
        let etab: Etablissement
        if choixEtablissement == .nouveau || etablissements.isEmpty {
            etab = Etablissement(
                nom: nouveauNomEtablissement,
                type: nouveauTypeEtablissement,
                ville: nouvelleVille,
                province: nouvelleProvince
            )
            modelContext.insert(etab)
        } else {
            guard let etabExistant = etablissementSelectionne ?? etablissements.first else { return }
            etab = etabExistant
        }

        let equipe = Equipe(nom: nom)
        equipe.categorie = categorie
        equipe.division = division
        equipe.saison = saison
        equipe.etablissement = etab
        equipe.codeEquipe = Equipe.genererCodeEquipe()
        modelContext.insert(equipe)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Carte utilisateur (vue coach) — conservée pour réutilisation

struct CarteUtilisateurCoach: View {
    let utilisateur: Utilisateur
    let onSupprimer: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var afficherModification = false
    @State private var confirmerSuppression = false
    @Query private var tousJoueurs: [JoueurEquipe]

    private var joueurLie: JoueurEquipe? {
        guard let joueurID = utilisateur.joueurEquipeID else { return nil }
        return tousJoueurs.first { $0.id == joueurID }
    }

    @Query private var toutesPresences: [Presence]
    @Query private var toutesEvaluations: [Evaluation]

    private var presencesJoueur: [Presence] {
        guard let joueurID = utilisateur.joueurEquipeID else { return [] }
        return toutesPresences.filter { $0.joueurID == joueurID }
    }

    private var evaluationsJoueur: [Evaluation] {
        guard let joueurID = utilisateur.joueurEquipeID else { return [] }
        return toutesEvaluations.filter { $0.joueurID == joueurID }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                if let joueur = joueurLie, let photoData = joueur.photoData, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(joueur.poste.couleur, lineWidth: 2))
                } else {
                    AvatarEditableView(utilisateur: utilisateur, taille: 48, editable: false)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(utilisateur.nomComplet)
                        .font(.subheadline.weight(.semibold))
                    HStack(spacing: 8) {
                        Text("ID : \(utilisateur.identifiant)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let joueur = joueurLie {
                            Text("#\(joueur.numero)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(joueur.poste.couleur)
                            Text(joueur.poste.abreviation)
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(joueur.poste.couleur, in: Capsule())
                        }
                    }
                }
                Spacer()
                HStack(spacing: 8) {
                    Button { afficherModification = true } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)
                    }
                    Button { confirmerSuppression = true } label: {
                        Image(systemName: "trash.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.red.opacity(0.7))
                    }
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
        .sheet(isPresented: $afficherModification) {
            ModifierUtilisateurView(utilisateur: utilisateur)
        }
        .alert("Supprimer \(utilisateur.prenom) ?", isPresented: $confirmerSuppression) {
            Button("Annuler", role: .cancel) { }
            Button("Supprimer", role: .destructive) { onSupprimer() }
        } message: {
            Text("L'athlète ne pourra plus se connecter.")
        }
    }
}

// MARK: - Profil Élève (lecture seule)

struct ProfilEleveContenu: View {
    let utilisateur: Utilisateur
    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss
    @Query private var toutesPresences: [Presence]
    @Query private var tousJoueurs: [JoueurEquipe]

    private var joueurLie: JoueurEquipe? {
        guard let joueurID = utilisateur.joueurEquipeID else { return nil }
        return tousJoueurs.first { $0.id == joueurID }
    }

    private var mesPresences: [Presence] {
        guard let joueurID = utilisateur.joueurEquipeID else { return [] }
        return toutesPresences.filter { $0.joueurID == joueurID }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Photo
                VStack(spacing: 16) {
                    if let joueur = joueurLie, let photoData = joueur.photoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(joueur.poste.couleur, lineWidth: 3))
                    } else {
                        AvatarView(utilisateur: utilisateur, taille: 100)
                    }

                    Text(utilisateur.nomComplet)
                        .font(.title2.weight(.bold))

                    HStack(spacing: 8) {
                        Text("Athlète")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PaletteMat.orange)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(PaletteMat.orange.opacity(0.08), in: Capsule())

                        if let joueur = joueurLie {
                            Text(joueur.poste.rawValue)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(joueur.poste.couleur)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(joueur.poste.couleur.opacity(0.08), in: Capsule())
                        }
                    }
                }

                // Avis lecture seule
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                    Text("Seul votre coach peut modifier vos informations et statistiques.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6).opacity(0.6), in: RoundedRectangle(cornerRadius: 10))

                // Déconnexion
                Button(role: .destructive) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        authService.deconnexion()
                    }
                } label: {
                    Label("Déconnexion", systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}
