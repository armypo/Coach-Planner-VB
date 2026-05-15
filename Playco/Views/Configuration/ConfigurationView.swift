//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData
import CryptoKit
import os

private let loggerConfig = Logger(subsystem: "com.origotech.playco", category: "Configuration")

/// Wizard de configuration au premier lancement — 6 étapes
struct ConfigurationView: View {
    var onRetour: (() -> Void)? = nil
    var onTermine: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Environment(CloudKitSharingService.self) private var sharingService
    @Environment(AnalyticsService.self) private var analyticsService

    /// Flag persistant : un wizard est en cours et n'a pas été finalisé.
    /// Permet à PlaycoApp de détecter un wizard interrompu et de proposer un choix à l'utilisateur.
    @AppStorage("playco_wizard_en_cours") private var wizardEnCours = false

    @State private var etapeCourante: Int = 1
    private let totalEtapes = 6

    // MARK: - Données collectées

    // Étape 1 — Établissement
    @State var nomEtablissement = ""
    @State var typeEtablissement: TypeEtablissement = .universite
    @State var villeEtablissement = ""
    @State var provinceEtablissement = "QC"
    @State var logoEtablissement: Data? = nil

    // Étape 2 — Sport
    @State var sportChoisi: SportType = .indoor

    // Étape 3 — Profil coach
    @State var prenomCoach = ""
    @State var nomCoach = ""
    @State var courrielCoach = ""
    @State var telephoneCoach = ""
    @State var roleCoach: RoleCoach = .entraineurChef
    @State var photoCoach: Data? = nil
    @State var identifiantCoach = ""
    @State var motDePasseCoach = ""
    @State var confirmerMotDePasseCoach = ""

    // Étape 4 — Équipe
    @State var nomEquipe = ""
    @State var categorieEquipe: CategorieEquipe = .masculin
    @State var divisionEquipe: DivisionEquipe = .division1
    @State var saisonEquipe = ""
    @State var couleurPrincipale: Color = .init(hex: "#FF6B35")
    @State var couleurSecondaire: Color = .init(hex: "#2563EB")

    // Étape 5 — Membres
    @State var assistants: [AssistantTemp] = []
    @State var joueursTemp: [JoueurTemp] = []

    // Étape 6 — Calendrier
    @State var creneaux: [CreneauTemp] = []
    @State var matchsTemp: [MatchTemp] = []
    @State var dateFinSaison: Date = Calendar.current.date(byAdding: .month, value: 4, to: Date()) ?? Date()

    // Sheet récap des identifiants créés à la finalisation
    @State private var afficherRecap = false
    @State private var credsRecap: [CredentialRecap] = []
    // Sheet de bienvenue paywall (après le récap)
    @State private var afficherBienvenuePaywall = false

    // MARK: - Validation

    private var etapeValide: Bool {
        switch etapeCourante {
        case 1: return !nomEtablissement.trimmingCharacters(in: .whitespaces).isEmpty
        case 2: return true // sélection par défaut
        case 3: return !prenomCoach.trimmingCharacters(in: .whitespaces).isEmpty &&
                       !nomCoach.trimmingCharacters(in: .whitespaces).isEmpty &&
                       !identifiantCoach.trimmingCharacters(in: .whitespaces).isEmpty &&
                       motDePasseCoach.count >= 6 &&
                       motDePasseCoach == confirmerMotDePasseCoach
        case 4: return !nomEquipe.trimmingCharacters(in: .whitespaces).isEmpty
        case 5: return true // optionnel
        case 6: return true // optionnel
        default: return true
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Barre de progression
            barreProgression
                .padding(.horizontal, 32)
                .padding(.top, 20)
                .padding(.bottom, 8)

            Divider().padding(.horizontal, 24)

            // Contenu étape
            contenuEtape
                .frame(maxWidth: 650)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .id(etapeCourante) // force transition
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            Divider().padding(.horizontal, 24)

            // Navigation bas
            barreNavigation
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .animation(LiquidGlassKit.springDefaut, value: etapeCourante)
        .onAppear {
            // Marque le wizard comme en cours dès l'entrée — sera effacé par finaliser() ou onRetour
            wizardEnCours = true
        }
        .sheet(isPresented: $afficherRecap) {
            IdentifiantsRecapSheet(creds: credsRecap) {
                afficherRecap = false
                // Après les identifiants → présenter le paywall de bienvenue
                afficherBienvenuePaywall = true
            }
            .interactiveDismissDisabled(true)
        }
        .fullScreenCover(isPresented: $afficherBienvenuePaywall) {
            BienvenuePaywallView {
                afficherBienvenuePaywall = false
                onTermine()
            }
            .interactiveDismissDisabled(true)
        }
    }

    // MARK: - Barre de progression

    private var barreProgression: some View {
        HStack(spacing: 8) {
            ForEach(1...totalEtapes, id: \.self) { etape in
                VStack(spacing: 4) {
                    Capsule()
                        .fill(etape <= etapeCourante ? PaletteMat.orange : Color.gray.opacity(0.2))
                        .frame(height: 4)

                    Text(labelEtape(etape))
                        .font(.system(size: 9, weight: etape == etapeCourante ? .bold : .regular))
                        .foregroundStyle(etape == etapeCourante ? PaletteMat.orange : .secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private func labelEtape(_ etape: Int) -> String {
        switch etape {
        case 1: return "École"
        case 2: return "Sport"
        case 3: return "Coach"
        case 4: return "Équipe"
        case 5: return "Membres"
        case 6: return "Calendrier"
        default: return ""
        }
    }

    // MARK: - Contenu

    @ViewBuilder
    private var contenuEtape: some View {
        switch etapeCourante {
        case 1:
            ConfigEtablissementView(
                nom: $nomEtablissement, type: $typeEtablissement,
                ville: $villeEtablissement, province: $provinceEtablissement,
                logo: $logoEtablissement
            )
        case 2:
            ConfigSportView(sportChoisi: $sportChoisi)
        case 3:
            ConfigProfilCoachView(
                prenom: $prenomCoach, nom: $nomCoach,
                courriel: $courrielCoach, telephone: $telephoneCoach,
                role: $roleCoach, photo: $photoCoach,
                identifiant: $identifiantCoach, motDePasse: $motDePasseCoach,
                confirmerMotDePasse: $confirmerMotDePasseCoach
            )
        case 4:
            ConfigEquipeView(
                nom: $nomEquipe, categorie: $categorieEquipe,
                division: $divisionEquipe, saison: $saisonEquipe,
                couleurPrincipale: $couleurPrincipale,
                couleurSecondaire: $couleurSecondaire
            )
        case 5:
            ConfigMembresView(
                assistants: $assistants,
                joueurs: $joueursTemp
            )
        case 6:
            ConfigCalendrierView(
                creneaux: $creneaux,
                matchs: $matchsTemp,
                dateFinSaison: $dateFinSaison,
                onPasser: { finaliser() }
            )
        default:
            EmptyView()
        }
    }

    // MARK: - Navigation

    private var barreNavigation: some View {
        HStack {
            if etapeCourante > 1 {
                Button {
                    withAnimation { etapeCourante -= 1 }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Précédent")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                }
            } else if let onRetour {
                Button {
                    onRetour()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Retour")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if etapeCourante < totalEtapes {
                Button {
                    withAnimation { etapeCourante += 1 }
                } label: {
                    HStack(spacing: 6) {
                        Text("Suivant")
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(etapeValide ? PaletteMat.orange : Color.gray.opacity(0.3),
                                in: Capsule())
                }
                .disabled(!etapeValide)
            } else {
                Button {
                    finaliser()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Terminer")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(PaletteMat.orange, in: Capsule())
                }
            }
        }
    }

    // MARK: - Finalisation

    private func finaliser() {
        // 1. Établissement
        let etablissement = Etablissement(
            nom: nomEtablissement, type: typeEtablissement,
            ville: villeEtablissement, province: provinceEtablissement
        )
        etablissement.logo = logoEtablissement
        modelContext.insert(etablissement)

        // 2. Profil coach
        let profil = ProfilCoach()
        profil.prenom = prenomCoach
        profil.nom = nomCoach
        profil.courriel = courrielCoach
        profil.telephone = telephoneCoach
        profil.sport = sportChoisi
        profil.roleCoach = roleCoach
        profil.photo = photoCoach
        profil.etablissement = etablissement
        profil.configurationCompletee = true
        modelContext.insert(profil)

        // 3. Équipe + code d'équipe
        let equipe = Equipe(nom: nomEquipe)
        equipe.categorie = categorieEquipe
        equipe.division = divisionEquipe
        equipe.saison = saisonEquipe
        equipe.couleurPrincipalHex = couleurPrincipale.toHex()
        equipe.couleurSecondaireHex = couleurSecondaire.toHex()
        equipe.etablissement = etablissement
        // Code équipe 8 caractères Base32 Crockford (voir Equipe.genererCodeEquipe).
        // Unicité locale : retry jusqu'à 5 fois sur collision en BD (très improbable
        // avec ~31^8 combinaisons, mais ceinture-bretelles).
        var codeEquipe = Equipe.genererCodeEquipe()
        var tentative = 0
        let descripteurCode = { (code: String) in
            FetchDescriptor<Equipe>(predicate: #Predicate { $0.codeEquipe == code })
        }
        while tentative < 5,
              let existants = try? modelContext.fetch(descripteurCode(codeEquipe)),
              !existants.isEmpty {
            codeEquipe = Equipe.genererCodeEquipe()
            tentative += 1
        }
        if tentative == 5 {
            loggerConfig.critical("Échec génération code équipe unique après 5 tentatives — collision persistante improbable")
        }
        equipe.codeEquipe = codeEquipe
        modelContext.insert(equipe)

        // Set des identifiants réservés dans la session (évite collisions en mémoire
        // car SwiftData ne voit pas les insertions non-committées)
        var idsCreesEnMemoire = Set<String>()

        // Accumulateur pour le sheet récap final
        var recaps: [CredentialRecap] = []

        // 4. Assistants → Utilisateur + CredentialAthlete
        for a in assistants {
            let sel = authService.genererSel()
            let hash = authService.hashMotDePasse(a.motDePasse, sel: sel)
            let idUnique = Utilisateur.genererIdentifiantUnique(
                prenom: a.prenom,
                nom: a.nom,
                context: modelContext,
                exclusions: idsCreesEnMemoire
            )
            idsCreesEnMemoire.insert(idUnique)
            let utilisateur = Utilisateur(
                identifiant: idUnique,
                motDePasseHash: hash,
                prenom: a.prenom,
                nom: a.nom,
                role: .assistantCoach,
                codeEcole: codeEquipe
            )
            utilisateur.sel = sel
            utilisateur.iterations = AuthService.iterationsParDefaut
            utilisateur.codeInvitation = Utilisateur.genererCodeUniqueInvitation(context: modelContext)
            modelContext.insert(utilisateur)

            let assistant = AssistantCoach(prenom: a.prenom, nom: a.nom)
            assistant.courriel = a.courriel
            assistant.roleAssistant = a.role
            assistant.identifiant = idUnique
            assistant.motDePasseHash = hash
            assistant.sel = sel
            assistant.equipe = equipe
            assistant.codeEquipe = codeEquipe
            modelContext.insert(assistant)

            // CredentialAthlete privé (mdp en clair pour récupération coach)
            let cred = CredentialAthlete(
                utilisateurID: utilisateur.id,
                joueurEquipeID: nil,
                identifiant: idUnique,
                motDePasseClair: a.motDePasse,
                codeEquipe: codeEquipe
            )
            modelContext.insert(cred)

            recaps.append(CredentialRecap(
                nomComplet: "\(a.prenom) \(a.nom)",
                identifiant: idUnique,
                motDePasse: a.motDePasse,
                role: "Assistant"
            ))
        }

        // 5. Joueurs → JoueurEquipe + Utilisateur + CredentialAthlete
        for j in joueursTemp {
            let joueur = JoueurEquipe(nom: j.nom, prenom: j.prenom, numero: j.numero, poste: j.poste)
            joueur.codeEquipe = codeEquipe
            joueur.equipe = equipe
            let sel = authService.genererSel()
            let hash = authService.hashMotDePasse(j.motDePasse, sel: sel)
            let idJoueur = Utilisateur.genererIdentifiantUnique(
                prenom: j.prenom,
                nom: j.nom,
                context: modelContext,
                exclusions: idsCreesEnMemoire
            )
            idsCreesEnMemoire.insert(idJoueur)
            joueur.identifiant = idJoueur
            joueur.motDePasseHash = hash
            joueur.sel = sel
            modelContext.insert(joueur)

            let utilisateur = Utilisateur(
                identifiant: idJoueur,
                motDePasseHash: hash,
                prenom: j.prenom,
                nom: j.nom,
                role: .etudiant,
                codeEcole: codeEquipe
            )
            utilisateur.sel = sel
            utilisateur.iterations = AuthService.iterationsParDefaut
            utilisateur.joueurEquipeID = joueur.id
            utilisateur.numero = j.numero
            utilisateur.posteRaw = j.poste.rawValue
            utilisateur.codeInvitation = Utilisateur.genererCodeUniqueInvitation(context: modelContext)
            modelContext.insert(utilisateur)

            joueur.utilisateurID = utilisateur.id

            // CredentialAthlete privé
            let cred = CredentialAthlete(
                utilisateurID: utilisateur.id,
                joueurEquipeID: joueur.id,
                identifiant: idJoueur,
                motDePasseClair: j.motDePasse,
                codeEquipe: codeEquipe
            )
            modelContext.insert(cred)

            recaps.append(CredentialRecap(
                nomComplet: "\(j.prenom) \(j.nom)",
                identifiant: idJoueur,
                motDePasse: j.motDePasse,
                role: "Athlète"
            ))
        }

        // 6. Créneaux récurrents → Séances pour 4 semaines
        let cal = Calendar.current
        let aujourdhui = Date()
        for c in creneaux {
            let creneau = CreneauRecurrent(jourSemaine: c.jourSemaine, dureeMinutes: c.dureeMinutes)
            creneau.heureDebut = c.heureDebut
            creneau.lieu = c.lieu
            creneau.equipe = equipe
            modelContext.insert(creneau)

            // Générer séances jusqu'à la fin de saison
            var semaine = 0
            while semaine < 200 { // sécurité max ~4 ans
                guard let dateSeance = prochaineDatePourJour(c.jourSemaine, depuis: aujourdhui, semaineOffset: semaine) else { break }
                if dateSeance > dateFinSaison { break }
                let composants = cal.dateComponents([.hour, .minute], from: c.heureDebut)
                let dateFinal = cal.date(bySettingHour: composants.hour ?? 18,
                                         minute: composants.minute ?? 0,
                                         second: 0, of: dateSeance) ?? dateSeance
                let seance = Seance(nom: "Pratique \(creneau.jourLabel)", date: dateFinal)
                seance.codeEquipe = codeEquipe
                modelContext.insert(seance)
                semaine += 1
            }
        }

        // 7. Matchs planifiés → Seance (type match)
        for m in matchsTemp {
            let seance = Seance(nom: "Match vs \(m.adversaire)", date: m.date, typeSeance: .match)
            seance.adversaire = m.adversaire
            seance.lieu = m.lieu
            seance.codeEquipe = codeEquipe
            modelContext.insert(seance)

            let matchCal = MatchCalendrier(date: m.date, adversaire: m.adversaire)
            matchCal.lieu = m.lieu
            matchCal.estDomicile = m.estDomicile
            matchCal.equipe = equipe
            modelContext.insert(matchCal)
        }

        // Sauvegarder et créer admin coach
        try? modelContext.save()

        // Créer l'utilisateur coach admin avec les identifiants choisis
        let sel = authService.genererSel()
        let hash = authService.hashMotDePasse(motDePasseCoach, sel: sel)
        let identifiantFinal = identifiantCoach.lowercased().trimmingCharacters(in: .whitespaces)
        let coachUser = Utilisateur(
            identifiant: identifiantFinal,
            motDePasseHash: hash,
            prenom: prenomCoach,
            nom: nomCoach,
            role: .coach,
            codeEcole: codeEquipe
        )
        coachUser.sel = sel
        coachUser.iterations = AuthService.iterationsParDefaut
        modelContext.insert(coachUser)
        try? modelContext.save()

        // Auto-login du coach
        authService.connexion(identifiant: identifiantFinal,
                              motDePasse: motDePasseCoach,
                              context: modelContext)

        // Publier les données d'équipe vers CloudKit public (async, ne bloque pas)
        let equipeAPublier = equipe
        let etabAPublier = etablissement
        let codeAPublier = codeEquipe
        Task {
            // Récupérer tous les utilisateurs et joueurs de cette équipe
            let descripteurUsers = FetchDescriptor<Utilisateur>(
                predicate: #Predicate { $0.codeEcole == codeAPublier }
            )
            let descripteurJoueurs = FetchDescriptor<JoueurEquipe>(
                predicate: #Predicate { $0.codeEquipe == codeAPublier }
            )
            let users = (try? modelContext.fetch(descripteurUsers)) ?? []
            let players = (try? modelContext.fetch(descripteurJoueurs)) ?? []

            await sharingService.publierEquipeComplete(
                equipe: equipeAPublier,
                etablissement: etabAPublier,
                utilisateurs: users,
                joueurs: players,
                context: modelContext
            )
        }

        analyticsService.suivre(
            evenement: EvenementAnalytics.equipeCreee,
            metadonnees: [
                "nb_joueurs": "\(joueursTemp.count)",
                "nb_assistants": "\(assistants.count)",
                "nb_creneaux": "\(creneaux.count)",
                "sport": sportChoisi.rawValue
            ]
        )
        analyticsService.suivre(evenement: EvenementAnalytics.configurationCompletee)

        // Wizard finalisé : lever le flag "en cours"
        wizardEnCours = false

        // Présenter le sheet récap si au moins un credential a été créé,
        // sinon aller directement au paywall de bienvenue.
        if !recaps.isEmpty {
            credsRecap = recaps
            afficherRecap = true
        } else {
            afficherBienvenuePaywall = true
        }
    }

    // MARK: - Helpers

    private func prochaineDatePourJour(_ jourCible: Int, depuis date: Date, semaineOffset: Int) -> Date? {
        let cal = Calendar.current
        let jourActuel = cal.component(.weekday, from: date)
        // Convertir : lundi=1 → weekday 2, etc.
        let weekdayCible = (jourCible % 7) + 1 // 1=lun→2, 7=dim→1
        var diff = weekdayCible - jourActuel
        if diff < 0 { diff += 7 }
        if diff == 0 && semaineOffset == 0 { diff = 0 }
        return cal.date(byAdding: .day, value: diff + (semaineOffset * 7), to: date)
    }
}

// MARK: - Structs temporaires (pas @Model, juste pour le wizard)

struct AssistantTemp: Identifiable {
    let id = UUID()
    var prenom = ""
    var nom = ""
    var courriel = ""
    var role: RoleAssistant = .assistantCoach
    var identifiant = ""
    // Mdp auto-généré dès la création — pas saisi par le coach.
    var motDePasse = Utilisateur.genererMotDePasseAthlete()
}

struct JoueurTemp: Identifiable {
    let id = UUID()
    var prenom = ""
    var nom = ""
    var numero: Int = 1
    var poste: PosteJoueur = .recepteur
    var identifiant = ""
    // Mdp auto-généré dès la création — pas saisi par le coach.
    var motDePasse = Utilisateur.genererMotDePasseAthlete()
}

struct CreneauTemp: Identifiable {
    let id = UUID()
    var jourSemaine: Int = 1
    var heureDebut: Date = {
        Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
    }()
    var dureeMinutes: Int = 120
    var lieu = ""
}

struct MatchTemp: Identifiable {
    let id = UUID()
    var date: Date = Date()
    var adversaire = ""
    var lieu = ""
    var estDomicile = true
}

// MARK: - Helper identifiant

func genererIdentifiant(prenom: String, nom: String) -> String {
    let p = prenom.lowercased()
        .folding(options: .diacriticInsensitive, locale: .current)
        .replacingOccurrences(of: " ", with: "-")
    let n = nom.lowercased()
        .folding(options: .diacriticInsensitive, locale: .current)
        .replacingOccurrences(of: " ", with: "-")
    return "\(p).\(n)"
}

// MARK: - Color → Hex

extension Color {
    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return "#FF6B35"
        }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
