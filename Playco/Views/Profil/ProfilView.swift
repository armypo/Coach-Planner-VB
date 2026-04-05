//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Vue profil / paramètres — adaptée selon le rôle (Coach, Élève, Admin)
struct ProfilView: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.codeEquipeActif) private var codeEquipeActif

    @Query private var equipes: [Equipe]
    @Query private var profils: [ProfilCoach]

    private var estCoach: Bool {
        let role = authService.utilisateurConnecte?.role
        return role == .coach || role == .admin
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let utilisateur = authService.utilisateurConnecte {
                        // En-tête profil
                        carteProfilHeader(utilisateur)

                        if estCoach {
                            // Code d'équipe
                            sectionCodeEquipe

                            // Visibilité athlètes
                            sectionVisibilite

                            // Organisation (gestion membres)
                            sectionOrganisation(utilisateur)

                            // Gestion équipes (coach seulement)
                            sectionEquipes
                        }

                        // Mode bord de terrain
                        sectionBordDeTerrain

                        // Synchronisation iCloud
                        sectionICloud

                        // Aide / Tutoriel
                        sectionTutoriel

                        // Déconnexion
                        boutonDeconnexion
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Paramètres")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    // MARK: - En-tête profil

    private func carteProfilHeader(_ utilisateur: Utilisateur) -> some View {
        VStack(spacing: 16) {
            AvatarEditableView(utilisateur: utilisateur, taille: 90, editable: estCoach)

            Text(utilisateur.nomComplet)
                .font(.title2.weight(.bold))

            Text(utilisateur.role.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(utilisateur.role.couleur)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(utilisateur.role.couleur.opacity(0.08), in: Capsule())

            HStack(spacing: 20) {
                infoTag(icone: "person.text.rectangle", texte: utilisateur.identifiant)
                if !utilisateur.codeEcole.isEmpty {
                    infoTag(icone: "building.2.fill", texte: utilisateur.codeEcole)
                }
            }
            .font(.footnote)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    // MARK: - Code d'équipe (coach)

    private var sectionCodeEquipe: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Code d'équipe", systemImage: "number.circle.fill")
                .font(.headline)
                .foregroundStyle(PaletteMat.bleu)

            if let equipeActive = equipes.first(where: { $0.codeEquipe == codeEquipeActif }) ?? equipes.first {
                HStack(spacing: 12) {
                    Text(equipeActive.codeEquipe.isEmpty ? "—" : equipeActive.codeEquipe)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(PaletteMat.bleu)

                    Spacer()

                    Button {
                        UIPasteboard.general.string = equipeActive.codeEquipe
                    } label: {
                        Label("Copier", systemImage: "doc.on.doc")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(PaletteMat.bleu)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(PaletteMat.bleu.opacity(0.1), in: Capsule())
                    }
                }

                Text("Partagez ce code à vos athlètes et assistants pour qu'ils puissent rejoindre l'équipe.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Aucune équipe configurée")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .glassCard()
    }

    // MARK: - Visibilité athlètes

    private var sectionVisibilite: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Visibilité", systemImage: "eye.slash")
                .font(.headline)
                .foregroundStyle(PaletteMat.violet)

            if let profil = profils.first {
                Toggle(isOn: Binding(
                    get: { profil.masquerPratiquesAthletes },
                    set: {
                        profil.masquerPratiquesAthletes = $0
                        try? modelContext.save()
                    }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Masquer les pratiques aux athlètes")
                            .font(.subheadline.weight(.medium))
                        Text("Les athlètes ne verront pas le contenu des séances (exercices, terrain, notes).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(PaletteMat.violet)
            }
        }
        .padding(20)
        .glassCard()
    }

    // MARK: - Organisation (gérer membres)

    @State private var afficherTutoriel = false
    @State private var afficherAjoutEleve = false
    @State private var afficherAjoutCoach = false
    @State private var afficherGestionStaff = false
    @State private var afficherJournalSync = false

    private func sectionOrganisation(_ utilisateur: Utilisateur) -> some View {
        let codeEcole = utilisateur.codeEcole
        return VStack(alignment: .leading, spacing: 12) {
            Label("Organisation", systemImage: "person.3.fill")
                .font(.headline)
                .foregroundStyle(PaletteMat.orange)

            VStack(spacing: 10) {
                boutonAction(icone: "person.badge.plus", titre: "Créer un profil d'athlète",
                             couleur: PaletteMat.orange) {
                    afficherAjoutEleve = true
                }
                boutonAction(icone: "figure.volleyball", titre: "Ajouter un coach",
                             couleur: PaletteMat.bleu) {
                    afficherAjoutCoach = true
                }
                boutonAction(icone: "lock.shield", titre: "Permissions du staff",
                             couleur: PaletteMat.vert) {
                    afficherGestionStaff = true
                }
            }
        }
        .padding(20)
        .glassCard()
        .sheet(isPresented: $afficherAjoutEleve) {
            AjoutUtilisateurView(codeEcole: codeEcole, roleParDefaut: .etudiant)
        }
        .sheet(isPresented: $afficherAjoutCoach) {
            AjoutUtilisateurView(codeEcole: codeEcole, roleParDefaut: .coach)
        }
        .sheet(isPresented: $afficherGestionStaff) {
            NavigationStack {
                GestionStaffView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Fermer") { afficherGestionStaff = false }
                        }
                    }
            }
        }
    }

    // MARK: - Gestion équipes (coach)

    @State private var afficherNouvelleEquipe = false
    @State private var equipeASupprimer: Equipe?
    @State private var confirmationNomEquipe = ""
    @State private var afficherConfirmationSuppression = false

    private var sectionEquipes: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Équipes", systemImage: "person.2.fill")
                .font(.headline)
                .foregroundStyle(PaletteMat.vert)

            // Liste des équipes
            ForEach(equipes) { equipe in
                HStack(spacing: 12) {
                    Circle()
                        .fill(equipe.couleurPrincipale)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text(String(equipe.nom.prefix(1)))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(equipe.nom)
                            .font(.subheadline.weight(.medium))
                        Text("\(equipe.categorie.rawValue) • \(equipe.codeEquipe)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    // Bouton supprimer équipe
                    Button {
                        equipeASupprimer = equipe
                        confirmationNomEquipe = ""
                        afficherConfirmationSuppression = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.6))
                    }
                }
                .padding(10)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
            }

            // Actions
            VStack(spacing: 10) {
                if equipes.count > 1 {
                    boutonAction(icone: "arrow.left.arrow.right", titre: "Changer d'équipe",
                                 couleur: PaletteMat.vert) {
                        dismiss()
                        // Reset la sélection d'équipe dans ContentView
                        NotificationCenter.default.post(name: .changerEquipe, object: nil)
                    }
                }

                boutonAction(icone: "plus.circle", titre: "Créer une nouvelle équipe",
                             couleur: PaletteMat.vert) {
                    afficherNouvelleEquipe = true
                }
            }
        }
        .padding(20)
        .glassCard()
        .sheet(isPresented: $afficherNouvelleEquipe) {
            NouvelleEquipeSheet()
        }
        .alert("Supprimer l'équipe", isPresented: $afficherConfirmationSuppression) {
            TextField("Tapez le nom de l'équipe pour confirmer", text: $confirmationNomEquipe)
            Button("Annuler", role: .cancel) {
                equipeASupprimer = nil
                confirmationNomEquipe = ""
            }
            Button("Supprimer définitivement", role: .destructive) {
                if let equipe = equipeASupprimer,
                   confirmationNomEquipe.trimmingCharacters(in: .whitespaces).lowercased() == equipe.nom.lowercased() {
                    supprimerEquipe(equipe)
                }
            }
            .disabled(equipeASupprimer.map { confirmationNomEquipe.trimmingCharacters(in: .whitespaces).lowercased() != $0.nom.lowercased() } ?? true)
        } message: {
            if let equipe = equipeASupprimer {
                Text("Cette action est irréversible. Tous les joueurs, matchs, stats et données de « \(equipe.nom) » seront supprimés. Votre compte coach sera conservé.\n\nTapez « \(equipe.nom) » pour confirmer.")
            }
        }
    }

    // MARK: - Suppression d'équipe (cascade manuelle)

    private func supprimerEquipe(_ equipe: Equipe) {
        let code = equipe.codeEquipe

        // Supprimer toutes les entités liées par codeEquipe
        supprimerEntites(JoueurEquipe.self, codeEquipe: code)
        supprimerEntites(Seance.self, codeEquipe: code)
        supprimerEntites(StatsMatch.self, codeEquipe: code)
        supprimerEntites(PointMatch.self, codeEquipe: code)
        supprimerEntites(StrategieCollective.self, codeEquipe: code)
        supprimerEntites(FormationPersonnalisee.self, codeEquipe: code)
        supprimerEntites(ProgrammeMuscu.self, codeEquipe: code)
        supprimerEntites(SeanceMuscu.self, codeEquipe: code)
        supprimerEntites(MessageEquipe.self, codeEquipe: code)
        supprimerEntites(ScoutingReport.self, codeEquipe: code)
        supprimerEntites(StaffPermissions.self, codeEquipe: code)
        supprimerEntites(ObjectifJoueur.self, codeEquipe: code)
        supprimerEntites(ActionRallye.self, codeEquipe: code)
        supprimerEntites(CategorieExercice.self, codeEquipe: code)

        // Les AssistantCoach, CreneauRecurrent, MatchCalendrier sont en cascade via la relation Equipe
        // Supprimer l'équipe elle-même
        modelContext.delete(equipe)
        try? modelContext.save()

        equipeASupprimer = nil
        confirmationNomEquipe = ""

        // Si plus d'équipe, retour au choix initial
        if equipes.count <= 1 {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: .allerChoixInitial, object: nil)
            }
        } else {
            // Changer vers une autre équipe
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: .changerEquipe, object: nil)
            }
        }
    }

    private func supprimerEntites<T: PersistentModel & FiltreParEquipe>(_ type: T.Type, codeEquipe: String) {
        let descriptor = FetchDescriptor<T>()
        guard let entites = try? modelContext.fetch(descriptor) else { return }
        for entite in entites where entite.codeEquipe == codeEquipe {
            modelContext.delete(entite)
        }
    }

    // MARK: - Tutoriel

    private var sectionTutoriel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Aide", systemImage: "questionmark.circle.fill")
                .font(.headline)
                .foregroundStyle(PaletteMat.bleu)

            boutonAction(icone: "book.fill", titre: "Voir le tutoriel", couleur: PaletteMat.bleu) {
                afficherTutoriel = true
            }
        }
        .padding(20)
        .glassCard()
        .fullScreenCover(isPresented: $afficherTutoriel) {
            TutorielView()
        }
    }

    // MARK: - Mode bord de terrain

    @AppStorage("modeBordDeTerrain") private var modeBordDeTerrain = false
    @AppStorage("themeHautContraste") private var themeHautContraste = false

    private var sectionBordDeTerrain: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Mode bord de terrain", systemImage: "sportscourt.fill")
                .font(.headline)
                .foregroundStyle(PaletteMat.orange)

            Toggle(isOn: $modeBordDeTerrain) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Interface simplifiée")
                        .font(.subheadline.weight(.medium))
                    Text("Grands boutons et layout épuré pour la saisie rapide en match.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(PaletteMat.orange)

            Toggle(isOn: $themeHautContraste) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Thème haut contraste")
                        .font(.subheadline.weight(.medium))
                    Text("Couleurs plus vives pour meilleure visibilité en extérieur.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(PaletteMat.orange)
        }
        .padding(20)
        .glassCard()
    }

    // MARK: - Statut iCloud

    @Environment(CloudKitSyncService.self) private var cloudKitService

    private var sectionICloud: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Synchronisation iCloud", systemImage: "icloud")
                .font(.headline)

            HStack(spacing: 12) {
                Image(systemName: cloudKitService.statutSync.icone)
                    .font(.title2)
                    .foregroundStyle(cloudKitService.statutSync == .synchronise ? .green :
                                    cloudKitService.statutSync == .enCours ? .blue :
                                    cloudKitService.statutSync == .syncPausee ? .yellow : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(cloudKitService.statutSync.nomAffichage)
                        .font(.subheadline.weight(.medium))

                    if let date = cloudKitService.dernierSync {
                        Text("Dernière sync : \(date.formatHeure())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

            }
            .padding(14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

            boutonAction(icone: "clock.arrow.circlepath", titre: "Journal de synchronisation", couleur: PaletteMat.bleu) {
                afficherJournalSync = true
            }
        }
        .padding(20)
        .glassCard()
        .sheet(isPresented: $afficherJournalSync) {
            JournalSyncView()
        }
    }

    // MARK: - Déconnexion

    private var boutonDeconnexion: some View {
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

    // MARK: - Helpers

    private func infoTag(icone: String, texte: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icone)
                .foregroundStyle(.secondary)
            Text(texte)
                .foregroundStyle(.secondary)
        }
    }

    private func boutonAction(icone: String, titre: String, couleur: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icone)
                    .font(.subheadline)
                    .foregroundStyle(couleur)
                    .frame(width: 28)
                Text(titre)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Notification pour changer d'équipe

extension Notification.Name {
    static let changerEquipe = Notification.Name("changerEquipe")
    static let allerChoixInitial = Notification.Name("allerChoixInitial")
}

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
        let prefixe = String(nom.uppercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .filter(\.isLetter).prefix(4))
        equipe.codeEquipe = (prefixe + String(format: "%02d", Int.random(in: 10...99))).uppercased()
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
