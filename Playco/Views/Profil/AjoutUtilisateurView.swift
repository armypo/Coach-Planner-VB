//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Vue pour ajouter un nouvel élève ou coach (accessible par le coach/admin)
struct AjoutUtilisateurView: View {
    let codeEcole: String
    var roleParDefaut: RoleUtilisateur = .etudiant

    @Environment(AuthService.self) private var authService
    @Environment(CloudKitSharingService.self) private var sharingService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var prenom = ""
    @State private var nom = ""
    @State private var identifiant = ""
    @State private var motDePasse = ""
    @State private var roleChoisi: RoleUtilisateur = .etudiant
    @State private var erreur: String?
    @State private var succes = false

    // Données physiques (pour élèves)
    @State private var numero = ""
    @State private var posteChoisi: PosteJoueur = .recepteur
    @State private var taillePieds = 5
    @State private var taillePouces = 10
    @State private var poids = ""
    @State private var jourNaissance = ""
    @State private var moisNaissance = ""
    @State private var anneeNaissance = ""

    private var formulaireValide: Bool {
        !prenom.trimmingCharacters(in: .whitespaces).isEmpty &&
        !nom.trimmingCharacters(in: .whitespaces).isEmpty &&
        !identifiant.trimmingCharacters(in: .whitespaces).isEmpty &&
        motDePasse.count >= 6
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Icône
                    ZStack {
                        Circle()
                            .fill(roleChoisi.couleur.opacity(0.08))
                            .frame(width: 70, height: 70)
                            .overlay(
                                Circle()
                                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                            )

                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 30))
                            .foregroundStyle(roleChoisi.couleur)
                    }

                    // Sélection du rôle
                    VStack(alignment: .leading, spacing: 8) {
                            Text("Type de compte")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            Picker("Rôle", selection: $roleChoisi) {
                                Text("Athlète").tag(RoleUtilisateur.etudiant)
                                Text("Coach").tag(RoleUtilisateur.coach)
                            }
                            .pickerStyle(.segmented)
                    }

                    // Formulaire
                    VStack(spacing: 14) {
                        champFormulaire(icone: "person.fill", label: "Prénom", texte: $prenom)
                        champFormulaire(icone: "person.fill", label: "Nom", texte: $nom)

                        VStack(alignment: .leading, spacing: 6) {
                                Text("Identifiant")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)

                                HStack(spacing: 12) {
                                    Image(systemName: "person.text.rectangle.fill")
                                        .foregroundStyle(roleChoisi.couleur)
                                        .frame(width: 20)

                                    TextField("Ex: A3F9K2", text: $identifiant)
                                        .textInputAutocapitalization(.characters)
                                        .autocorrectionDisabled()

                                    Button {
                                        identifiant = genererCode()
                                    } label: {
                                        Image(systemName: "dice.fill")
                                            .foregroundStyle(roleChoisi.couleur)
                                    }
                                }
                                .padding(14)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Mot de passe (min. 6 caractères)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)

                                HStack(spacing: 12) {
                                    Image(systemName: "lock.fill")
                                        .foregroundStyle(roleChoisi.couleur)
                                        .frame(width: 20)

                                    TextField("Mot de passe", text: $motDePasse)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)

                                    Button {
                                        motDePasse = genererMotDePasse()
                                    } label: {
                                        Image(systemName: "dice.fill")
                                            .foregroundStyle(roleChoisi.couleur)
                                    }
                                }
                                .padding(14)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                            }

                            // Info code école
                            HStack(spacing: 8) {
                                Image(systemName: "building.2.fill")
                                    .foregroundStyle(.secondary)
                                Text("École : \(codeEcole)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                    }

                    // Données physiques pour athlètes
                    if roleChoisi == .etudiant {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Données athlète")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(PaletteMat.orange)
                                .textCase(.uppercase)

                            // Poste et numéro
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("POSTE")
                                        .font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                                    Picker("Poste", selection: $posteChoisi) {
                                        ForEach(PosteJoueur.allCases, id: \.self) { poste in
                                            Text(poste.rawValue).tag(poste)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .padding(10)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("NUMÉRO")
                                        .font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                                    TextField("#", text: $numero)
                                        .keyboardType(.numberPad)
                                        .padding(10)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
                                }
                            }

                            // Taille
                            VStack(alignment: .leading, spacing: 6) {
                                Text("TAILLE")
                                    .font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                                HStack(spacing: 8) {
                                    Picker("Pieds", selection: $taillePieds) {
                                        ForEach(4...7, id: \.self) { p in
                                            Text("\(p)'").tag(p)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(width: 60, height: 80)
                                    .clipped()

                                    Picker("Pouces", selection: $taillePouces) {
                                        ForEach(0...11, id: \.self) { p in
                                            Text("\(p)\"").tag(p)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(width: 60, height: 80)
                                    .clipped()

                                    Text("\(taillePieds)'\(taillePouces)\"")
                                        .font(.headline)
                                        .foregroundStyle(roleChoisi.couleur)

                                    Spacer()

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("POIDS (LBS)")
                                            .font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                                        TextField("165", text: $poids)
                                            .keyboardType(.numberPad)
                                            .padding(10)
                                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
                                    }
                                    .frame(width: 100)
                                }
                            }

                            // Date de naissance
                            VStack(alignment: .leading, spacing: 6) {
                                Text("DATE DE NAISSANCE")
                                    .font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                                HStack(spacing: 8) {
                                    TextField("JJ", text: $jourNaissance)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 50)
                                        .padding(10)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
                                    Text("/")
                                        .foregroundStyle(.secondary)
                                    TextField("MM", text: $moisNaissance)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 50)
                                        .padding(10)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
                                    Text("/")
                                        .foregroundStyle(.secondary)
                                    TextField("AAAA", text: $anneeNaissance)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 70)
                                        .padding(10)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
                                }
                            }
                        }
                        .padding(16)
                        .glassSection()
                    }

                    // Erreur
                    if let erreur {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(erreur)
                        }
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 10).fill(.red))
                    }

                    // Succès
                    if succes {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Compte créé avec succès !")
                        }
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 10).fill(.green))
                    }

                    // Bouton créer
                    Button {
                        creerCompte()
                    } label: {
                        Text("Créer le compte")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(formulaireValide ? roleChoisi.couleur : Color.gray.opacity(0.4))
                            )
                            .foregroundStyle(.white)
                    }
                    .disabled(!formulaireValide)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .navigationTitle("Nouveau compte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
            .onAppear {
                roleChoisi = roleParDefaut
            }
        }
    }

    private func champFormulaire(icone: String, label: String, texte: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 12) {
                Image(systemName: icone)
                    .foregroundStyle(roleChoisi.couleur)
                    .frame(width: 20)

                TextField(label, text: texte)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
        }
    }

    private func creerCompte() {
        erreur = nil
        succes = false

        // Générer un identifiant unique si vide
        let idFinal = identifiant.trimmingCharacters(in: .whitespaces).isEmpty
            ? Utilisateur.genererIdentifiantUnique(prenom: prenom, nom: nom, context: modelContext)
            : identifiant.lowercased().trimmingCharacters(in: .whitespaces)

        let resultat = authService.creerCompte(
            identifiant: idFinal,
            motDePasse: motDePasse,
            prenom: prenom,
            nom: nom,
            role: roleChoisi,
            context: modelContext
        )

        if let messageErreur = resultat {
            erreur = messageErreur
        } else {
            // Assigner le codeEcole (code équipe) sur l'utilisateur créé
            let descriptor = FetchDescriptor<Utilisateur>(
                predicate: #Predicate { $0.identifiant == idFinal }
            )
            if let utilisateur = try? modelContext.fetch(descriptor).first {
                utilisateur.codeEcole = codeEcole
            }

            // Créer aussi un JoueurEquipe lié (pour les athlètes)
            if roleChoisi == .etudiant {
                let numJoueur = Int(numero) ?? 0
                let joueur = JoueurEquipe(nom: nom, prenom: prenom, numero: numJoueur, poste: posteChoisi)
                joueur.codeEquipe = codeEcole
                let tailleCm = Int(round(Double(taillePieds * 12 + taillePouces) * 2.54))
                joueur.taille = tailleCm
                if let dateN = construireDate() {
                    joueur.dateNaissance = dateN
                }
                modelContext.insert(joueur)

                // Lier l'utilisateur au joueur
                if let utilisateur = try? modelContext.fetch(descriptor).first {
                    utilisateur.joueurEquipeID = joueur.id
                    utilisateur.tailleCm = tailleCm
                    utilisateur.numero = numJoueur
                    utilisateur.posteRaw = posteChoisi.rawValue
                    if let p = Double(poids), p > 0 {
                        utilisateur.poidKg = p
                    }
                    if let dateN = construireDate() {
                        utilisateur.dateNaissance = dateN
                    }
                }
                try? modelContext.save()
            }

            // Publier vers CloudKit public DB
            let idRecherche = idFinal
            let descriptorPub = FetchDescriptor<Utilisateur>(
                predicate: #Predicate { $0.identifiant == idRecherche }
            )
            if let utilisateurPub = try? modelContext.fetch(descriptorPub).first {
                var joueurPub: JoueurEquipe?
                if let jID = utilisateurPub.joueurEquipeID {
                    let descJoueur = FetchDescriptor<JoueurEquipe>(
                        predicate: #Predicate { $0.id == jID }
                    )
                    joueurPub = try? modelContext.fetch(descJoueur).first
                }
                Task {
                    await sharingService.publierNouvelUtilisateur(utilisateurPub, joueur: joueurPub)
                }
            }

            succes = true
            // Reset le formulaire
            prenom = ""
            nom = ""
            identifiant = ""
            motDePasse = ""
            numero = ""
            poids = ""
            posteChoisi = .recepteur
            taillePieds = 5
            taillePouces = 10
            jourNaissance = ""
            moisNaissance = ""
            anneeNaissance = ""
        }
    }

    /// Construit une Date à partir des champs jour/mois/année
    private func construireDate() -> Date? {
        guard let jour = Int(jourNaissance), let mois = Int(moisNaissance), let annee = Int(anneeNaissance),
              jour >= 1, jour <= 31, mois >= 1, mois <= 12, annee >= 1900 else { return nil }
        var composants = DateComponents()
        composants.day = jour
        composants.month = mois
        composants.year = annee
        return Calendar.current.date(from: composants)
    }

    /// Génère un code aléatoire de 6 caractères (lettres + chiffres)
    private func genererCode() -> String {
        let caracteres = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).compactMap { _ in caracteres.randomElement() })
    }

    /// Génère un mot de passe aléatoire de 12 caractères (sans ambigus : 0/O, 1/l/I)
    private func genererMotDePasse() -> String {
        let caracteres = Array("abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789")
        return String((0..<12).compactMap { _ in caracteres.randomElement() })
    }
}
