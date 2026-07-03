//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  Tests du flux multi-utilisateur coach/athlète en SIWA strict (v2.1) :
//  le coach crée les membres via MembreFactory (aucun secret), l'athlète
//  rejoint par code d'équipe + code d'invitation (reclamerMembreLocal) puis
//  se connecte par Sign in with Apple.
//

import Testing
import Foundation
import SwiftData
@testable import Playco

/// Tests sérialisés : partage de Keychain global iOS (session).
@Suite("Multi-utilisateur — Coach / Athlète", .serialized)
@MainActor
struct MultiUtilisateurTests {

    private func creerAuthIsole() -> AuthService {
        // Purger le Keychain de session partagé iOS pour garantir l'isolation
        // entre tests sérialisés.
        KeychainService.supprimer(cle: SessionManager.cleKeychain)
        let suite = UserDefaults(suiteName: "playco-test-\(UUID().uuidString)")!
        return AuthService(userDefaults: suite)
    }

    private func creerContexteEnMemoire() throws -> ModelContext {
        let schema = Schema([
            Utilisateur.self, JoueurEquipe.self, Equipe.self,
            Etablissement.self, ProfilCoach.self, AssistantCoach.self,
            CreneauRecurrent.self, MatchCalendrier.self, Seance.self,
            Exercice.self, MessageEquipe.self, PointMatch.self,
            StatsMatch.self, StrategieCollective.self,
            FormationPersonnalisee.self, Presence.self, Evaluation.self,
            ProgrammeMuscu.self, ExerciceMuscu.self, SeanceMuscu.self,
            TestPhysique.self, ExerciceBibliotheque.self,
            ScoutingReport.self, PhaseSaison.self, ObjectifJoueur.self,
            CredentialAthlete.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    // MARK: - Simulation complète du flux SIWA

    @Test("Flux complet SIWA : coach crée l'équipe, athlète rejoint par code d'invitation, permissions correctes")
    func fluxCompletCoachAthlete() throws {
        let auth = creerAuthIsole()
        let context = try creerContexteEnMemoire()

        // ── 1. Coach crée son compte (lié à son Apple ID) ──
        let coach = Utilisateur(
            identifiant: "chris.dionne",
            motDePasseHash: "",   // SIWA strict : aucun secret
            prenom: "Christopher",
            nom: "Dionne",
            role: .admin,
            codeEcole: "ELANS01"
        )
        coach.appleUserID = "001.coach.apple"
        coach.codeEquipe = "ELANS01"
        context.insert(coach)

        // ── 2. Coach crée l'équipe ──
        let equipe = Equipe(nom: "Élans")
        equipe.codeEquipe = "ELANS01"
        equipe.categorieRaw = CategorieEquipe.masculin.rawValue
        context.insert(equipe)

        // ── 3. Coach crée un joueur + membre athlète via MembreFactory ──
        let joueur = JoueurEquipe(nom: "Tremblay", prenom: "Jean", numero: 7, poste: .passeur)
        joueur.codeEquipe = "ELANS01"
        context.insert(joueur)

        var exclusions: Set<String> = []
        let membre = MembreFactory.creerMembre(
            prenom: "Jean", nom: "Tremblay", role: .etudiant,
            codeEquipe: "ELANS01", joueur: joueur,
            context: context, exclusions: &exclusions
        )
        try context.save()

        // ── 4. Connexion coach via SIWA → vérifier permissions ──
        let etatCoach = auth.connexionApple(appleUserID: "001.coach.apple", prenom: "", nom: "", context: context)
        guard case .connecte = etatCoach else {
            Issue.record("Le coach doit être connecté via SIWA")
            return
        }
        #expect(auth.utilisateurConnecte?.role == .admin)
        #expect(auth.utilisateurConnecte?.role.peutModifierSeances == true)
        #expect(auth.utilisateurConnecte?.role.peutGererEquipe == true)
        #expect(auth.utilisateurConnecte?.role.peutModifierStrategies == true)
        #expect(auth.utilisateurConnecte?.role.peutGererProgrammes == true)
        #expect(auth.utilisateurConnecte?.role.peutExporter == true)
        #expect(auth.utilisateurConnecte?.role.peutCreerComptes == true)
        auth.deconnexion()

        // ── 5. Athlète rejoint depuis SON Apple ID : code équipe + code d'invitation ──
        let sharing = CloudKitSharingService()
        let reclame = sharing.reclamerMembreLocal(
            codeEquipe: "ELANS01",
            codeInvitation: membre.recap.codeInvitation,
            appleUserID: "002.athlete.apple",
            context: context
        )
        #expect(reclame?.id == membre.utilisateur.id, "La jonction doit réclamer la ligne roster de l'athlète")
        #expect(reclame?.appleUserID == "002.athlete.apple")

        // ── 6. Connexion athlète via SIWA → vérifier permissions restreintes ──
        let etatAthlete = auth.connexionApple(appleUserID: "002.athlete.apple", prenom: "", nom: "", context: context)
        guard case .connecte = etatAthlete else {
            Issue.record("L'athlète doit être connecté via SIWA après jonction")
            return
        }
        #expect(auth.utilisateurConnecte?.role == .etudiant)
        #expect(auth.utilisateurConnecte?.role.peutModifierSeances == false)
        #expect(auth.utilisateurConnecte?.role.peutGererEquipe == false)
        #expect(auth.utilisateurConnecte?.role.peutModifierStrategies == false)
        #expect(auth.utilisateurConnecte?.role.peutGererProgrammes == false)
        #expect(auth.utilisateurConnecte?.role.peutExporter == false)
        #expect(auth.utilisateurConnecte?.role.peutCreerComptes == false)

        // Vérifier que le lien joueur est correct
        #expect(auth.utilisateurConnecte?.joueurEquipeID == joueur.id)
        #expect(joueur.utilisateurID == membre.utilisateur.id)
        #expect(auth.utilisateurConnecte?.codeEcole == "ELANS01")
        auth.deconnexion()
    }

    // MARK: - Identifiants uniques

    @Test("Génération identifiants uniques — format prenom.nom.XXXX")
    func identifiantsUniques() throws {
        let context = try creerContexteEnMemoire()

        let id1 = Utilisateur.genererIdentifiantUnique(prenom: "Jean", nom: "Tremblay", context: context)
        #expect(id1.hasPrefix("jean.tremblay."), "Format attendu : prenom.nom.XXXX")
        #expect(id1.count == "jean.tremblay.".count + 4, "Suffixe 4 chiffres")

        // Créer un utilisateur avec cet identifiant
        let user = Utilisateur(identifiant: id1, motDePasseHash: "", prenom: "Jean", nom: "Tremblay", role: .etudiant)
        context.insert(user)
        try context.save()

        // Le deuxième doit avoir un suffixe différent
        let id2 = Utilisateur.genererIdentifiantUnique(prenom: "Jean", nom: "Tremblay", context: context)
        #expect(id2.hasPrefix("jean.tremblay."))
        #expect(id1 != id2, "Les identifiants doivent être différents (entropie 10⁴)")
    }

    @Test("Identifiant sans accents et espaces")
    func identifiantSansAccents() throws {
        let context = try creerContexteEnMemoire()

        let id = Utilisateur.genererIdentifiantUnique(prenom: "José María", nom: "Côté", context: context)
        #expect(id.hasPrefix("jose-maria.cote."), "Accents retirés, espaces → tirets, format prenom.nom.XXXX")
    }

    // MARK: - Scoping données par équipe

    @Test("FiltreParEquipe — données scopées correctement")
    func filtreParEquipe() throws {
        let context = try creerContexteEnMemoire()

        let j1 = JoueurEquipe(nom: "A", prenom: "X", numero: 1, poste: .passeur)
        j1.codeEquipe = "EQUIPE_A"
        let j2 = JoueurEquipe(nom: "B", prenom: "Y", numero: 2, poste: .central)
        j2.codeEquipe = "EQUIPE_B"
        let j3 = JoueurEquipe(nom: "C", prenom: "Z", numero: 3, poste: .libero)
        j3.codeEquipe = "" // Pas d'équipe → visible partout

        context.insert(j1)
        context.insert(j2)
        context.insert(j3)
        try context.save()

        let desc = FetchDescriptor<JoueurEquipe>()
        let tous = try context.fetch(desc)

        let filtreA = tous.filtreEquipe("EQUIPE_A")
        #expect(filtreA.count == 2, "Équipe A : 1 joueur assigné + 1 sans équipe")
        #expect(filtreA.contains(where: { $0.nom == "A" }))
        #expect(filtreA.contains(where: { $0.nom == "C" }))

        let filtreB = tous.filtreEquipe("EQUIPE_B")
        #expect(filtreB.count == 2, "Équipe B : 1 joueur assigné + 1 sans équipe")
        #expect(filtreB.contains(where: { $0.nom == "B" }))
        #expect(filtreB.contains(where: { $0.nom == "C" }))
    }

    // MARK: - Séances filtrées par équipe

    @Test("Séances filtrées par équipe et non archivées")
    func seancesFiltrees() throws {
        let context = try creerContexteEnMemoire()

        let s1 = Seance(nom: "Pratique 1")
        s1.codeEquipe = "ELANS01"
        let s2 = Seance(nom: "Pratique 2")
        s2.codeEquipe = "AUTRE"
        let s3 = Seance(nom: "Archivée")
        s3.codeEquipe = "ELANS01"
        s3.estArchivee = true

        context.insert(s1)
        context.insert(s2)
        context.insert(s3)
        try context.save()

        let desc = FetchDescriptor<Seance>()
        let toutes = try context.fetch(desc)

        let actives = toutes.filter { !$0.estArchivee }
        let filtrees = actives.filtreEquipe("ELANS01")
        #expect(filtrees.count == 1, "Seule la séance active de l'équipe doit apparaître")
        #expect(filtrees.first?.nom == "Pratique 1")
    }

    // MARK: - Multi-équipes coach

    @Test("Coach avec plusieurs équipes — changement d'équipe")
    func coachMultiEquipes() throws {
        let auth = creerAuthIsole()
        let context = try creerContexteEnMemoire()

        // Coach (SIWA)
        let coach = Utilisateur(identifiant: "coach.multi", motDePasseHash: "",
                                prenom: "Coach", nom: "Multi", role: .admin, codeEcole: "EQ1")
        coach.appleUserID = "010.coach.multi"
        context.insert(coach)

        // Deux équipes
        let eq1 = Equipe(nom: "Équipe 1")
        eq1.codeEquipe = "EQ1"
        let eq2 = Equipe(nom: "Équipe 2")
        eq2.codeEquipe = "EQ2"
        context.insert(eq1)
        context.insert(eq2)

        // Joueurs dans chaque équipe
        let j1 = JoueurEquipe(nom: "Joueur1", prenom: "A", numero: 1, poste: .passeur)
        j1.codeEquipe = "EQ1"
        let j2 = JoueurEquipe(nom: "Joueur2", prenom: "B", numero: 2, poste: .central)
        j2.codeEquipe = "EQ2"
        context.insert(j1)
        context.insert(j2)
        try context.save()

        let etat = auth.connexionApple(appleUserID: "010.coach.multi", prenom: "", nom: "", context: context)
        guard case .connecte = etat else {
            Issue.record("Le coach doit être connecté via SIWA")
            return
        }

        // Vérifier le filtrage par équipe
        let desc = FetchDescriptor<JoueurEquipe>()
        let tous = try context.fetch(desc)

        let equipe1 = tous.filtreEquipe("EQ1")
        #expect(equipe1.count == 1)
        #expect(equipe1.first?.nom == "Joueur1")

        let equipe2 = tous.filtreEquipe("EQ2")
        #expect(equipe2.count == 1)
        #expect(equipe2.first?.nom == "Joueur2")

        auth.deconnexion()
    }

    // MARK: - Matchs et score

    @Test("Score par set — calcul résultat automatique")
    func scoreParSet() {
        let match = Seance(nom: "Test match", typeSeance: .match)
        match.adversaire = "Adversaire"

        // 3-1 : Victoire
        match.sets = [
            SetScore(numero: 1, scoreEquipe: 25, scoreAdversaire: 20),
            SetScore(numero: 2, scoreEquipe: 18, scoreAdversaire: 25),
            SetScore(numero: 3, scoreEquipe: 25, scoreAdversaire: 22),
            SetScore(numero: 4, scoreEquipe: 25, scoreAdversaire: 19),
        ]

        #expect(match.scoreEquipe == 3, "3 sets gagnés")
        #expect(match.scoreAdversaire == 1, "1 set perdu")
        #expect(match.resultat == .victoire)
        #expect(match.estMatch)
        #expect(match.scoreEntre)
    }

    // MARK: - Stats joueur

    @Test("Statistiques joueur — calculs corrects")
    func statsJoueur() {
        let joueur = JoueurEquipe(nom: "Test", prenom: "Stats", numero: 10, poste: .oppose)
        joueur.matchsJoues = 5
        joueur.setsJoues = 15
        joueur.attaquesReussies = 40  // kills
        joueur.erreursAttaque = 10
        joueur.attaquesTotales = 100

        // Hitting % = (40 - 10) / 100 = 0.30
        #expect(joueur.pourcentageAttaque == 0.30, "Hitting % doit être 0.30")

        // Kills par set = 40 / 15 ≈ 2.67
        #expect(abs(joueur.killsParSet - 2.667) < 0.01)

        joueur.aces = 8
        joueur.blocsSeuls = 5
        joueur.blocsAssistes = 10

        // Points = kills + aces + blocs seuls + blocsAssistes*0.5 = 40 + 8 + 5 + 5 = 58
        #expect(joueur.pointsCalcules == 58)

        // Points par set = 58 / 15 ≈ 3.87
        #expect(abs(joueur.pointsParSet - 3.867) < 0.01)
    }

    // MARK: - Code invitation unique

    @Test("Code invitation unique — 6 caractères alphanumériques")
    func codeInvitation() throws {
        let context = try creerContexteEnMemoire()

        let code1 = Utilisateur.genererCodeUniqueInvitation(context: context)
        #expect(code1.count == 6)

        // Vérifier que les caractères sont valides (pas de I/O/1/0)
        let interdits = Set("IO10")
        for char in code1 {
            #expect(!interdits.contains(char), "Le code ne doit pas contenir \(char)")
        }

        // Deux codes doivent être différents (statistiquement)
        let code2 = Utilisateur.genererCodeUniqueInvitation(context: context)
        #expect(code1 != code2, "Deux codes générés doivent être différents")
    }
}
