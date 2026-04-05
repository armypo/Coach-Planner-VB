//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Création / ajout de joueur à l'équipe — 3 modes :
/// 1. Inviter par code d'invitation
/// 2. Lier un athlète existant dans la base
/// 3. Créer un nouveau profil (Utilisateur + JoueurEquipe)
struct NouveauJoueurView: View {
    var onCreate: (JoueurEquipe) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Environment(\.codeEquipeActif) private var codeEquipeActif

    @Query(filter: #Predicate<Utilisateur> { $0.roleRaw == "etudiant" && $0.estActif == true })
    private var tousAthletes: [Utilisateur]
    @Query private var tousJoueurs: [JoueurEquipe]

    @State private var mode: ModeAjout = .menu
    @State private var recherche = ""

    // Invitation par code
    @State private var codeInvitation = ""
    @State private var erreurCode: String?
    @State private var athleteTrouve: Utilisateur?

    // Création manuelle
    @State private var nom = ""
    @State private var prenom = ""
    @State private var numero = 1
    @State private var poste: PosteJoueur = .recepteur
    @State private var taille = 0
    @State private var identifiant = ""
    @State private var motDePasse = ""

    enum ModeAjout {
        case menu, code, listeAthletes, manuel
    }

    /// Athlètes non encore liés à un joueur de cette équipe
    private var athletesDisponibles: [Utilisateur] {
        let idsLies = Set(
            tousJoueurs
                .filter { $0.codeEquipe == codeEquipeActif }
                .compactMap(\.utilisateurID)
        )
        return tousAthletes.filter { athlete in
            !idsLies.contains(athlete.id) &&
            (recherche.isEmpty ||
             athlete.nomComplet.localizedCaseInsensitiveContains(recherche) ||
             athlete.codeInvitation.localizedCaseInsensitiveContains(recherche))
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .menu:
                    menuPrincipal
                case .code:
                    vueInvitationCode
                case .listeAthletes:
                    listeAthletes
                case .manuel:
                    formulaireManuel
                }
            }
            .navigationTitle(titreNavigation)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(mode == .menu ? "Annuler" : "Retour") {
                        if mode == .menu { dismiss() }
                        else { withAnimation { mode = .menu; reinitialiserChamps() } }
                    }
                }
            }
        }
    }

    private var titreNavigation: String {
        switch mode {
        case .menu: return "Ajouter un joueur"
        case .code: return "Inviter par code"
        case .listeAthletes: return "Athlètes existants"
        case .manuel: return "Nouveau joueur"
        }
    }

    // MARK: - Menu principal (3 options)

    private var menuPrincipal: some View {
        List {
            Section {
                // Option 1 : Inviter par code
                Button {
                    withAnimation { mode = .code }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "ticket.fill")
                            .font(.title3)
                            .foregroundStyle(.orange)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Inviter par code")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Text("Entrez le code d'un joueur existant")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)

                // Option 2 : Lier un athlète existant
                Button {
                    withAnimation { mode = .listeAthletes }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.title3)
                            .foregroundStyle(.green)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Athlètes inscrits")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Text("\(athletesDisponibles.count) disponible\(athletesDisponibles.count > 1 ? "s" : "")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)

                // Option 3 : Créer un nouveau
                Button {
                    withAnimation { mode = .manuel }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "person.badge.plus")
                            .font(.title3)
                            .foregroundStyle(.blue)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Créer un joueur")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Text("Crée le profil et le compte automatiquement")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            } header: {
                Text("Mode d'ajout")
                    .font(.caption.weight(.semibold))
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Invitation par code

    private var vueInvitationCode: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "ticket.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange.opacity(0.6))

            Text("Entrez le code d'invitation du joueur")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Code (6 caractères)", text: $codeInvitation)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(16)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 60)
                .onChange(of: codeInvitation) { _, newValue in
                    codeInvitation = String(newValue.uppercased().prefix(6))
                    erreurCode = nil
                    athleteTrouve = nil
                    if codeInvitation.count == 6 {
                        rechercherParCode()
                    }
                }

            // Résultat
            if let erreur = erreurCode {
                Text(erreur)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let athlete = athleteTrouve {
                carteAthleteTrouve(athlete)
            }

            Spacer()
            Spacer()
        }
        .padding()
    }

    private func carteAthleteTrouve(_ athlete: Utilisateur) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill((athlete.poste?.couleur ?? .gray).opacity(0.15))
                        .frame(width: 50, height: 50)
                    Text(athlete.numero > 0 ? "#\(athlete.numero)" : "?")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(athlete.poste?.couleur ?? .gray)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(athlete.nomComplet)
                        .font(.headline)
                    if let p = athlete.poste {
                        Text(p.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(p.couleur)
                    }
                }
                Spacer()
            }
            .padding()
            .background(.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

            Button {
                creerDepuisAthlete(athlete)
            } label: {
                Label("Ajouter à l'équipe", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.green, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 40)
    }

    private func rechercherParCode() {
        let code = codeInvitation.trimmingCharacters(in: .whitespaces).uppercased()
        let descriptor = FetchDescriptor<Utilisateur>(
            predicate: #Predicate<Utilisateur> { $0.codeInvitation == code && $0.estActif == true }
        )
        guard let resultats = try? modelContext.fetch(descriptor),
              let athlete = resultats.first else {
            erreurCode = "Aucun joueur trouvé avec ce code"
            athleteTrouve = nil
            return
        }

        // Vérifier s'il est déjà dans l'équipe
        let dejaPresent = tousJoueurs.contains {
            $0.utilisateurID == athlete.id && $0.codeEquipe == codeEquipeActif
        }
        if dejaPresent {
            erreurCode = "Ce joueur fait déjà partie de l'équipe"
            athleteTrouve = nil
            return
        }

        athleteTrouve = athlete
    }

    // MARK: - Liste athlètes inscrits

    private var listeAthletes: some View {
        List {
            if !athletesDisponibles.isEmpty {
                Section {
                    ForEach(athletesDisponibles, id: \.id) { athlete in
                        Button {
                            creerDepuisAthlete(athlete)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill((athlete.poste?.couleur ?? .gray).opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    if athlete.numero > 0 {
                                        Text("#\(athlete.numero)")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(athlete.poste?.couleur ?? .gray)
                                    } else {
                                        Image(systemName: "person.fill")
                                            .foregroundStyle(athlete.poste?.couleur ?? .gray)
                                    }
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(athlete.nomComplet)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                    HStack(spacing: 6) {
                                        if let p = athlete.poste {
                                            Text(p.rawValue)
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(p.couleur)
                                        }
                                        Text(athlete.codeInvitation)
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(.orange)
                                    }
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.title3)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Label("Athlètes disponibles", systemImage: "person.crop.circle.badge.checkmark")
                }
            }

            if athletesDisponibles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: recherche.isEmpty ? "person.3" : "magnifyingglass")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text(recherche.isEmpty ? "Aucun athlète disponible" : "Aucun résultat")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .searchable(text: $recherche, prompt: "Rechercher un athlète")
    }

    // MARK: - Formulaire création manuelle

    private var formulaireManuel: some View {
        Form {
            Section("Identité") {
                TextField("Prénom", text: $prenom)
                    .autocorrectionDisabled()
                TextField("Nom", text: $nom)
                    .autocorrectionDisabled()
                Stepper("Numéro : #\(numero)", value: $numero, in: 1...99)
            }

            Section("Poste") {
                Picker("Poste", selection: $poste) {
                    ForEach(PosteJoueur.allCases, id: \.self) { p in
                        Label(p.rawValue, systemImage: p.icone).tag(p)
                    }
                }
                .pickerStyle(.inline)
            }

            Section("Physique (optionnel)") {
                Stepper("Taille : \(taille > 0 ? "\(taille) cm" : "—")",
                        value: $taille, in: 0...250, step: 1)
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("IDENTIFIANT")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("prenom.nom", text: $identifiant)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("MOT DE PASSE (min 6 car.)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    SecureField("Mot de passe", text: $motDePasse)
                }
            } footer: {
                Text("Un profil global sera créé avec un code d'invitation unique.")
                    .font(.caption2)
            }

            Section {
                Button("Créer le joueur") {
                    creerJoueurComplet()
                }
                .disabled(!formulaireValide)
                .frame(maxWidth: .infinity)
                .fontWeight(.semibold)
            }
        }
        .onChange(of: prenom) { _, _ in genererIdentifiantAuto() }
        .onChange(of: nom) { _, _ in genererIdentifiantAuto() }
    }

    private var formulaireValide: Bool {
        !prenom.trimmingCharacters(in: .whitespaces).isEmpty &&
        !nom.trimmingCharacters(in: .whitespaces).isEmpty &&
        !identifiant.trimmingCharacters(in: .whitespaces).isEmpty &&
        motDePasse.count >= 6
    }

    private func genererIdentifiantAuto() {
        let p = prenom.trimmingCharacters(in: .whitespaces).lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: " ", with: "-")
        let n = nom.trimmingCharacters(in: .whitespaces).lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: " ", with: "-")
        if !p.isEmpty && !n.isEmpty {
            identifiant = "\(p).\(n)"
        }
    }

    // MARK: - Actions

    /// Crée un joueur complet : Utilisateur global + JoueurEquipe lié
    private func creerJoueurComplet() {
        let codeEcole = authService.utilisateurConnecte?.codeEcole ?? codeEquipeActif
        let sel = authService.genererSel()
        let hash = authService.hashMotDePasse(motDePasse, sel: sel)

        // 1. Créer le profil Utilisateur global
        let idUnique = Utilisateur.genererIdentifiantUnique(prenom: prenom, nom: nom, context: modelContext)
        let utilisateur = Utilisateur(
            identifiant: idUnique,
            motDePasseHash: hash,
            prenom: prenom,
            nom: nom,
            role: .etudiant,
            codeEcole: codeEcole
        )
        utilisateur.sel = sel
        utilisateur.numero = numero
        utilisateur.posteRaw = poste.rawValue
        utilisateur.codeInvitation = Utilisateur.genererCodeUniqueInvitation(context: modelContext)
        if taille > 0 { utilisateur.tailleCm = taille }
        modelContext.insert(utilisateur)

        // 2. Créer le JoueurEquipe lié
        let joueur = JoueurEquipe(nom: nom, prenom: prenom, numero: numero, poste: poste)
        joueur.utilisateurID = utilisateur.id
        joueur.identifiant = identifiant.uppercased()
        joueur.motDePasseHash = hash
        joueur.sel = sel
        if taille > 0 { joueur.taille = taille }

        // Lien bidirectionnel
        utilisateur.joueurEquipeID = joueur.id

        onCreate(joueur)
        dismiss()
    }

    /// Ajoute un athlète existant à l'équipe (crée un JoueurEquipe lié)
    private func creerDepuisAthlete(_ athlete: Utilisateur) {
        let joueur = JoueurEquipe(
            nom: athlete.nom,
            prenom: athlete.prenom,
            numero: athlete.numero > 0 ? athlete.numero : 1,
            poste: athlete.poste ?? .recepteur
        )
        joueur.utilisateurID = athlete.id
        joueur.identifiant = athlete.identifiant
        joueur.motDePasseHash = athlete.motDePasseHash
        joueur.sel = athlete.sel ?? ""
        if athlete.tailleCm > 0 { joueur.taille = athlete.tailleCm }
        if let dn = athlete.dateNaissance { joueur.dateNaissance = dn }

        // Lien bidirectionnel
        athlete.joueurEquipeID = joueur.id

        onCreate(joueur)
        dismiss()
    }

    private func reinitialiserChamps() {
        codeInvitation = ""
        erreurCode = nil
        athleteTrouve = nil
        recherche = ""
        nom = ""
        prenom = ""
        numero = 1
        poste = .recepteur
        taille = 0
        identifiant = ""
        motDePasse = ""
    }
}
