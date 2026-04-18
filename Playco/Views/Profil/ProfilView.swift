//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Vue profil / paramètres — adaptée selon le rôle (Coach, Élève, Admin)
struct ProfilView: View {
    @Environment(AuthService.self) private var authService
    @Environment(AbonnementService.self) private var abonnementService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.codeEquipeActif) private var codeEquipeActif

    @Query private var equipes: [Equipe]
    @Query private var profils: [ProfilCoach]

    private var estCoach: Bool {
        let role = authService.utilisateurConnecte?.role
        return role == .coach || role == .assistantCoach || role == .admin
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

                            // Mon abonnement (Pro / Club) — visible uniquement aux coachs payants
                            if abonnementService.estCoachPayant(utilisateur: utilisateur) {
                                sectionAbonnement
                            }

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

                        // Légal (politique confidentialité + conditions d'utilisation)
                        sectionLegal

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

    // MARK: - Mon abonnement

    private var sectionAbonnement: some View {
        NavigationLink {
            GestionAbonnementView()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Mon abonnement", systemImage: "creditcard.fill")
                        .font(.headline)
                        .foregroundStyle(PaletteMat.orange)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                HStack(spacing: 10) {
                    BadgeStatut(statut: abonnementService.statut)
                    if let jours = abonnementService.joursRestantsEssai {
                        Text("\(jours) j restants")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .padding(20)
            .glassCard()
        }
        .buttonStyle(.plain)
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
    @State private var afficherIdentifiantsEquipe = false

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
                boutonAction(icone: "key.fill", titre: "Identifiants de l'équipe",
                             couleur: PaletteMat.violet) {
                    afficherIdentifiantsEquipe = true
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
        .sheet(isPresented: $afficherIdentifiantsEquipe) {
            NavigationStack {
                IdentifiantsEquipeView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Fermer") { afficherIdentifiantsEquipe = false }
                        }
                    }
            }
            .environment(authService)
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

    // MARK: - Légal

    // TODO(lancement) : héberger les pages légales avant le lancement App Store.
    // Sources Markdown : docs/legal/privacy-policy-{fr,en}.md + terms-of-service-{fr,en}.md
    // Options d'hébergement :
    //   1. GitHub Pages depuis docs/
    //   2. Site Origo (sous-domaine playco.origotech.com)
    //   3. Page statique Vercel / Netlify
    // Une fois hébergé : remplacer les URLs ci-dessous puis valider dans App Store Connect.
    private let urlPolitiqueConfidentialite = URL(string: "https://origotech.com/playco/privacy")!
    private let urlConditionsUtilisation = URL(string: "https://origotech.com/playco/terms")!

    private var sectionLegal: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Légal", systemImage: "doc.text.fill")
                .font(.headline)
                .foregroundStyle(PaletteMat.violet)

            Link(destination: urlPolitiqueConfidentialite) {
                HStack(spacing: 12) {
                    Image(systemName: "hand.raised.fill")
                        .font(.body)
                        .foregroundStyle(PaletteMat.violet)
                        .frame(width: 24)
                    Text("Politique de confidentialité")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(PaletteMat.violet.opacity(0.06), in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMoyen))
            }

            Link(destination: urlConditionsUtilisation) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.plaintext.fill")
                        .font(.body)
                        .foregroundStyle(PaletteMat.violet)
                        .frame(width: 24)
                    Text("Conditions d'utilisation")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(PaletteMat.violet.opacity(0.06), in: RoundedRectangle(cornerRadius: LiquidGlassKit.rayonMoyen))
            }
        }
        .padding(20)
        .glassCard()
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
