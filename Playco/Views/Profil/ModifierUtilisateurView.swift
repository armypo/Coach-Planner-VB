//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData
import PhotosUI

/// Vue pour modifier les informations d'un élève (accessible par le coach)
struct ModifierUtilisateurView: View {
    @Bindable var utilisateur: Utilisateur

    @Environment(AuthService.self) private var authService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var prenom: String = ""
    @State private var nom: String = ""
    @State private var identifiant: String = ""
    @State private var nouveauMotDePasse: String = ""
    @State private var succes = false
    @State private var erreur: String?
    @State private var photoItem: PhotosPickerItem?

    // Données physiques — taille en pieds
    @State private var taillePieds: Int = 5
    @State private var taillePouces: Int = 10
    @State private var poidKg: String = ""
    @State private var allongeBras: String = ""
    @State private var hauteurSaut: String = ""
    @State private var numero: String = ""
    @State private var posteChoisi: PosteJoueur = .recepteur
    @State private var jourNaissance: String = ""
    @State private var moisNaissance: String = ""
    @State private var anneeNaissance: String = ""

    // Statistiques
    @State private var matchsJoues: String = ""
    @State private var setsJoues: String = ""
    @State private var attaquesReussies: String = ""
    @State private var erreursAttaque: String = ""
    @State private var attaquesTotales: String = ""
    @State private var aces: String = ""
    @State private var erreursService: String = ""
    @State private var servicesTotaux: String = ""
    @State private var blocsSeuls: String = ""
    @State private var blocsAssistes: String = ""
    @State private var erreursBloc: String = ""
    @State private var receptionsReussies: String = ""
    @State private var erreursReception: String = ""
    @State private var receptionsTotales: String = ""
    @State private var passesDecisives: String = ""
    @State private var manchettes: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Avatar modifiable
                    AvatarEditableView(utilisateur: utilisateur, taille: 80, editable: true)

                    Text("Modifier \(utilisateur.prenom)")
                        .font(.headline)

                    // Formulaire
                    VStack(spacing: 14) {
                        champModif(icone: "person.fill", label: "Prénom", texte: $prenom)
                        champModif(icone: "person.fill", label: "Nom", texte: $nom)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Identifiant")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            HStack(spacing: 12) {
                                Image(systemName: "person.text.rectangle.fill")
                                    .foregroundStyle(utilisateur.role.couleur)
                                    .frame(width: 20)

                                TextField("Identifiant", text: $identifiant)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Nouveau mot de passe (laisser vide pour garder l'ancien)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            HStack(spacing: 12) {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(utilisateur.role.couleur)
                                    .frame(width: 20)

                                TextField("Nouveau mot de passe", text: $nouveauMotDePasse)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                        }
                    }

                    // Section données physiques (élèves seulement)
                    if utilisateur.role == .etudiant {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Données physiques", systemImage: "figure.stand")
                                .font(.headline)
                                .foregroundStyle(PaletteMat.orange)

                            // Poste et numéro
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("POSTE")
                                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                                    Picker("Poste", selection: $posteChoisi) {
                                        ForEach(PosteJoueur.allCases, id: \.self) { poste in
                                            Text(poste.rawValue).tag(poste)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .padding(10)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
                                }

                                champChiffre(label: "NUMÉRO", texte: $numero, placeholder: "#")
                            }

                            // Mesures — Taille en pieds
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
                                        .foregroundStyle(PaletteMat.orange)

                                    Spacer()

                                    // Poids
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("POIDS (LBS)")
                                            .font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                                        TextField("165", text: $poidKg)
                                            .keyboardType(.numberPad)
                                            .padding(10)
                                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
                                    }
                                    .frame(width: 100)
                                }
                            }

                            HStack(spacing: 12) {
                                champChiffre(label: "ALLONGE (CM)", texte: $allongeBras, placeholder: "185")
                                champChiffre(label: "DÉTENTE (CM)", texte: $hauteurSaut, placeholder: "45")
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

                        // Section statistiques
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Statistiques", systemImage: "chart.bar.fill")
                                .font(.headline)
                                .foregroundStyle(PaletteMat.bleu)

                            // Général
                            Text("Général").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            HStack(spacing: 12) {
                                champChiffre(label: "MATCHS", texte: $matchsJoues, placeholder: "0")
                                champChiffre(label: "SETS", texte: $setsJoues, placeholder: "0")
                            }

                            // Attaque
                            Text("Attaque").font(.caption.weight(.semibold)).foregroundStyle(.green)
                            HStack(spacing: 12) {
                                champChiffre(label: "KILLS", texte: $attaquesReussies, placeholder: "0")
                                champChiffre(label: "ERR. ATT.", texte: $erreursAttaque, placeholder: "0")
                                champChiffre(label: "TENT. ATT.", texte: $attaquesTotales, placeholder: "0")
                            }

                            // Service
                            Text("Service").font(.caption.weight(.semibold)).foregroundStyle(.yellow)
                            HStack(spacing: 12) {
                                champChiffre(label: "ACES", texte: $aces, placeholder: "0")
                                champChiffre(label: "ERR. SERV.", texte: $erreursService, placeholder: "0")
                                champChiffre(label: "TENT. SERV.", texte: $servicesTotaux, placeholder: "0")
                            }

                            // Bloc
                            Text("Bloc").font(.caption.weight(.semibold)).foregroundStyle(.red)
                            HStack(spacing: 12) {
                                champChiffre(label: "BLOCS SEULS", texte: $blocsSeuls, placeholder: "0")
                                champChiffre(label: "BLOCS ASS.", texte: $blocsAssistes, placeholder: "0")
                                champChiffre(label: "ERR. BLOC", texte: $erreursBloc, placeholder: "0")
                            }

                            // Réception
                            Text("Réception").font(.caption.weight(.semibold)).foregroundStyle(.purple)
                            HStack(spacing: 12) {
                                champChiffre(label: "RÉC. +", texte: $receptionsReussies, placeholder: "0")
                                champChiffre(label: "ERR. RÉC.", texte: $erreursReception, placeholder: "0")
                                champChiffre(label: "RÉC. TOT.", texte: $receptionsTotales, placeholder: "0")
                            }

                            // Jeu
                            Text("Jeu").font(.caption.weight(.semibold)).foregroundStyle(.cyan)
                            HStack(spacing: 12) {
                                champChiffre(label: "PASSES DÉC.", texte: $passesDecisives, placeholder: "0")
                                champChiffre(label: "MANCHETTES", texte: $manchettes, placeholder: "0")
                            }
                        }
                        .padding(16)
                        .glassSection()
                    }

                    // Messages
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

                    if succes {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Modifications enregistrées !")
                        }
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 10).fill(.green))
                    }

                    // Bouton sauvegarder
                    Button {
                        sauvegarder()
                    } label: {
                        Text("Enregistrer")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(utilisateur.role.couleur)
                            )
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .navigationTitle("Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
            .onAppear {
                prenom = utilisateur.prenom
                nom = utilisateur.nom
                identifiant = utilisateur.identifiant
                // Données physiques — convertir cm → pieds/pouces
                if utilisateur.tailleCm > 0 {
                    let totalPouces = Int(round(Double(utilisateur.tailleCm) / 2.54))
                    taillePieds = totalPouces / 12
                    taillePouces = totalPouces % 12
                }
                poidKg = utilisateur.poidKg > 0 ? String(format: "%.0f", utilisateur.poidKg) : ""
                allongeBras = utilisateur.allongeBras > 0 ? "\(utilisateur.allongeBras)" : ""
                hauteurSaut = utilisateur.hauteurSaut > 0 ? "\(utilisateur.hauteurSaut)" : ""
                numero = utilisateur.numero > 0 ? "\(utilisateur.numero)" : ""
                posteChoisi = utilisateur.poste ?? .recepteur
                if let dn = utilisateur.dateNaissance {
                    let cal = Calendar.current
                    jourNaissance = "\(cal.component(.day, from: dn))"
                    moisNaissance = "\(cal.component(.month, from: dn))"
                    anneeNaissance = "\(cal.component(.year, from: dn))"
                }
                // Statistiques
                matchsJoues = utilisateur.matchsJoues > 0 ? "\(utilisateur.matchsJoues)" : ""
                setsJoues = utilisateur.setsJoues > 0 ? "\(utilisateur.setsJoues)" : ""
                attaquesReussies = utilisateur.attaquesReussies > 0 ? "\(utilisateur.attaquesReussies)" : ""
                erreursAttaque = utilisateur.erreursAttaque > 0 ? "\(utilisateur.erreursAttaque)" : ""
                attaquesTotales = utilisateur.attaquesTotales > 0 ? "\(utilisateur.attaquesTotales)" : ""
                aces = utilisateur.aces > 0 ? "\(utilisateur.aces)" : ""
                erreursService = utilisateur.erreursService > 0 ? "\(utilisateur.erreursService)" : ""
                servicesTotaux = utilisateur.servicesTotaux > 0 ? "\(utilisateur.servicesTotaux)" : ""
                blocsSeuls = utilisateur.blocsSeuls > 0 ? "\(utilisateur.blocsSeuls)" : ""
                blocsAssistes = utilisateur.blocsAssistes > 0 ? "\(utilisateur.blocsAssistes)" : ""
                erreursBloc = utilisateur.erreursBloc > 0 ? "\(utilisateur.erreursBloc)" : ""
                receptionsReussies = utilisateur.receptionsReussies > 0 ? "\(utilisateur.receptionsReussies)" : ""
                erreursReception = utilisateur.erreursReception > 0 ? "\(utilisateur.erreursReception)" : ""
                receptionsTotales = utilisateur.receptionsTotales > 0 ? "\(utilisateur.receptionsTotales)" : ""
                passesDecisives = utilisateur.passesDecisives > 0 ? "\(utilisateur.passesDecisives)" : ""
                manchettes = utilisateur.manchettes > 0 ? "\(utilisateur.manchettes)" : ""
            }
        }
    }

    private func champChiffre(label: String, texte: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: texte)
                .keyboardType(.numberPad)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
        }
    }

    private func champModif(icone: String, label: String, texte: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 12) {
                Image(systemName: icone)
                    .foregroundStyle(utilisateur.role.couleur)
                    .frame(width: 20)

                TextField(label, text: texte)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
        }
    }

    private func sauvegarder() {
        erreur = nil
        succes = false

        guard !prenom.trimmingCharacters(in: .whitespaces).isEmpty,
              !nom.trimmingCharacters(in: .whitespaces).isEmpty else {
            erreur = "Le prénom et le nom sont obligatoires."
            return
        }

        guard !identifiant.trimmingCharacters(in: .whitespaces).isEmpty else {
            erreur = "L'identifiant est obligatoire."
            return
        }

        if !nouveauMotDePasse.isEmpty && nouveauMotDePasse.count < 6 {
            erreur = "Le mot de passe doit contenir au moins 6 caractères."
            return
        }

        utilisateur.prenom = prenom.trimmingCharacters(in: .whitespaces)
        utilisateur.nom = nom.trimmingCharacters(in: .whitespaces)
        utilisateur.identifiant = identifiant.uppercased().trimmingCharacters(in: .whitespaces)

        if !nouveauMotDePasse.isEmpty {
            utilisateur.motDePasseHash = authService.hashMotDePasse(nouveauMotDePasse)
        }

        // Données physiques — convertir pieds/pouces → cm pour stockage
        let totalPouces = taillePieds * 12 + taillePouces
        utilisateur.tailleCm = Int(round(Double(totalPouces) * 2.54))
        utilisateur.poidKg = Double(poidKg) ?? 0
        utilisateur.allongeBras = Int(allongeBras) ?? 0
        utilisateur.hauteurSaut = Int(hauteurSaut) ?? 0
        utilisateur.numero = Int(numero) ?? 0
        utilisateur.poste = posteChoisi
        utilisateur.dateNaissance = construireDate()

        // Statistiques
        utilisateur.matchsJoues = Int(matchsJoues) ?? 0
        utilisateur.setsJoues = Int(setsJoues) ?? 0
        utilisateur.attaquesReussies = Int(attaquesReussies) ?? 0
        utilisateur.erreursAttaque = Int(erreursAttaque) ?? 0
        utilisateur.attaquesTotales = Int(attaquesTotales) ?? 0
        utilisateur.aces = Int(aces) ?? 0
        utilisateur.erreursService = Int(erreursService) ?? 0
        utilisateur.servicesTotaux = Int(servicesTotaux) ?? 0
        utilisateur.blocsSeuls = Int(blocsSeuls) ?? 0
        utilisateur.blocsAssistes = Int(blocsAssistes) ?? 0
        utilisateur.erreursBloc = Int(erreursBloc) ?? 0
        utilisateur.receptionsReussies = Int(receptionsReussies) ?? 0
        utilisateur.erreursReception = Int(erreursReception) ?? 0
        utilisateur.receptionsTotales = Int(receptionsTotales) ?? 0
        utilisateur.passesDecisives = Int(passesDecisives) ?? 0
        utilisateur.manchettes = Int(manchettes) ?? 0

        // Synchroniser avec JoueurEquipe si lié
        if let joueurID = utilisateur.joueurEquipeID {
            let descriptor = FetchDescriptor<JoueurEquipe>(
                predicate: #Predicate { $0.id == joueurID }
            )
            if let joueur = try? modelContext.fetch(descriptor).first {
                joueur.prenom = utilisateur.prenom
                joueur.nom = utilisateur.nom
                joueur.numero = utilisateur.numero
                joueur.poste = posteChoisi
                joueur.taille = utilisateur.tailleCm
                joueur.matchsJoues = utilisateur.matchsJoues
                joueur.setsJoues = utilisateur.setsJoues
                joueur.attaquesReussies = utilisateur.attaquesReussies
                joueur.erreursAttaque = utilisateur.erreursAttaque
                joueur.attaquesTotales = utilisateur.attaquesTotales
                joueur.aces = utilisateur.aces
                joueur.erreursService = utilisateur.erreursService
                joueur.servicesTotaux = utilisateur.servicesTotaux
                joueur.blocsSeuls = utilisateur.blocsSeuls
                joueur.blocsAssistes = utilisateur.blocsAssistes
                joueur.erreursBloc = utilisateur.erreursBloc
                joueur.receptionsReussies = utilisateur.receptionsReussies
                joueur.erreursReception = utilisateur.erreursReception
                joueur.receptionsTotales = utilisateur.receptionsTotales
                joueur.passesDecisives = utilisateur.passesDecisives
                joueur.manchettes = utilisateur.manchettes
                joueur.photoData = utilisateur.photoData
                joueur.dateNaissance = utilisateur.dateNaissance
            }
        }

        do {
            try modelContext.save()
            succes = true
            nouveauMotDePasse = ""
        } catch {
            self.erreur = "Erreur lors de la sauvegarde."
        }
    }

    private func construireDate() -> Date? {
        guard let jour = Int(jourNaissance), let mois = Int(moisNaissance), let annee = Int(anneeNaissance),
              jour >= 1, jour <= 31, mois >= 1, mois <= 12, annee >= 1900 else { return nil }
        var composants = DateComponents()
        composants.day = jour
        composants.month = mois
        composants.year = annee
        return Calendar.current.date(from: composants)
    }

    private var initiales: String {
        let p = utilisateur.prenom.prefix(1).uppercased()
        let n = utilisateur.nom.prefix(1).uppercased()
        return "\(p)\(n)"
    }
}
