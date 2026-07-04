//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Tests du MatchLiveViewModel : chargement de set (rotation/service),
//  enregistrement de stats (score, sideout, rotation), annulation du dernier
//  point, modification manuelle des rotations et joueurs sur le terrain.
//

import Testing
import Foundation
import SwiftData
@testable import Playco

@Suite("MatchLiveViewModel — match live")
@MainActor
struct MatchLiveViewModelTests {

    private static let codeEquipeTest = "EQ_TEST"

    // MARK: - Helpers

    /// Schéma réduit : fermeture transitive des relations de Seance et JoueurEquipe.
    private func creerContexteEnMemoire() throws -> ModelContext {
        let schema = Schema([
            Seance.self, Exercice.self, PointMatch.self, JoueurEquipe.self,
            Equipe.self, Etablissement.self, ProfilCoach.self,
            AssistantCoach.self, CreneauRecurrent.self, MatchCalendrier.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    /// Crée un match avec 7 joueurs (6 partants aux postes 1-6 + 1 sur le banc).
    private func creerMatch(
        nousServonsEnPremier: Bool = true
    ) throws -> (context: ModelContext, seance: Seance, joueurs: [JoueurEquipe]) {
        let context = try creerContexteEnMemoire()

        let seance = Seance(nom: "Match test", typeSeance: .match)
        seance.codeEquipe = Self.codeEquipeTest
        seance.nousServonsEnPremier = nousServonsEnPremier
        context.insert(seance)

        var joueurs: [JoueurEquipe] = []
        for numero in 1...7 {
            let joueur = JoueurEquipe(nom: "Nom\(numero)", prenom: "Prenom\(numero)",
                                      numero: numero, poste: .recepteur)
            joueur.codeEquipe = Self.codeEquipeTest
            context.insert(joueur)
            joueurs.append(joueur)
        }

        seance.partants = (1...6).map { PartantMatch(poste: $0, joueurID: joueurs[$0 - 1].id) }
        try context.save()
        return (context, seance, joueurs)
    }

    private func creerVM(
        seance: Seance, context: ModelContext, joueurs: [JoueurEquipe]
    ) -> MatchLiveViewModel {
        MatchLiveViewModel(seance: seance, modelContext: context,
                           joueurs: joueurs, codeEquipe: Self.codeEquipeTest)
    }

    private func compterPoints(_ context: ModelContext) throws -> Int {
        try context.fetch(FetchDescriptor<PointMatch>()).count
    }

    // MARK: - chargerSet : set vide

    @Test("chargerSet — set 1 vide : rotations à 1 et service à nous si nousServonsEnPremier")
    func chargerSetVideServiceNous() throws {
        // Arrange / Act
        let (context, seance, joueurs) = try creerMatch(nousServonsEnPremier: true)
        let vm = creerVM(seance: seance, context: context, joueurs: joueurs)

        // Assert
        #expect(vm.setActuel == 1)
        #expect(vm.scoreNous == 0)
        #expect(vm.scoreAdv == 0)
        #expect(vm.rotationActuelle == 1)
        #expect(vm.rotationAdversaire == 1)
        #expect(vm.nousServons == true, "Set 1 : le service suit nousServonsEnPremier")
        #expect(vm.dernierPoint == nil)
    }

    @Test("chargerSet — set 1 vide : service à l'adversaire si nousServonsEnPremier == false")
    func chargerSetVideServiceAdversaire() throws {
        // Arrange / Act
        let (context, seance, joueurs) = try creerMatch(nousServonsEnPremier: false)
        let vm = creerVM(seance: seance, context: context, joueurs: joueurs)

        // Assert
        #expect(vm.rotationActuelle == 1)
        #expect(vm.rotationAdversaire == 1)
        #expect(vm.nousServons == false)
    }

    @Test("chargerSet — alternance du service : sets pairs inversés, sets impairs identiques au set 1")
    func chargerSetAlternanceService() throws {
        // Arrange
        let (context, seance, joueurs) = try creerMatch(nousServonsEnPremier: true)
        let vm = creerVM(seance: seance, context: context, joueurs: joueurs)

        // Act / Assert — formule : nousServons = (set % 2 == 1) == nousServonsEnPremier
        vm.changerSet(vers: 2)
        #expect(vm.nousServons == false, "Set pair : service inversé")
        #expect(vm.rotationActuelle == 1, "Nouveau set : rotation réinitialisée")

        vm.changerSet(vers: 3)
        #expect(vm.nousServons == true, "Set impair : même service qu'au début du match")

        vm.changerSet(vers: 4)
        #expect(vm.nousServons == false)

        vm.changerSet(vers: 5)
        #expect(vm.nousServons == true)
    }

    // MARK: - chargerSet : restauration depuis points persistés

    @Test("chargerSet — restauration depuis le dernier point : rotations et service (point pour nous)")
    func chargerSetRestaurationPointNous() throws {
        // Arrange — un set en cours 7-5 avec un dernier point 'kill' en R3/R2
        let (context, seance, joueurs) = try creerMatch(nousServonsEnPremier: true)
        seance.sets = [SetScore(numero: 1, scoreEquipe: 7, scoreAdversaire: 5)]

        let point = PointMatch(seanceID: seance.id, set: 1, joueurID: joueurs[0].id, typeAction: .kill)
        point.rotationAuMoment = 3
        point.rotationAdvAuMoment = 2
        point.horodatage = Date(timeIntervalSince1970: 1_000)
        context.insert(point)
        try context.save()

        // Act — l'init du VM appelle chargerSet()
        let vm = creerVM(seance: seance, context: context, joueurs: joueurs)

        // Assert
        #expect(vm.scoreNous == 7)
        #expect(vm.scoreAdv == 5)
        #expect(vm.rotationActuelle == 3, "rotationAuMoment du dernier point restaurée")
        #expect(vm.rotationAdversaire == 2, "rotationAdvAuMoment du dernier point restaurée")
        #expect(vm.nousServons == true, "L'équipe qui a marqué le dernier point sert")
        #expect(vm.dernierPoint?.id == point.id)
    }

    @Test("chargerSet — restauration : le dernier point (horodatage max) gagne et donne le service à l'adversaire")
    func chargerSetRestaurationDernierPointAdversaire() throws {
        // Arrange — deux points persistés, le plus récent est un point adverse
        let (context, seance, joueurs) = try creerMatch(nousServonsEnPremier: true)
        seance.sets = [SetScore(numero: 1, scoreEquipe: 4, scoreAdversaire: 6)]

        let pointAncien = PointMatch(seanceID: seance.id, set: 1, joueurID: joueurs[0].id, typeAction: .kill)
        pointAncien.rotationAuMoment = 1
        pointAncien.rotationAdvAuMoment = 1
        pointAncien.horodatage = Date(timeIntervalSince1970: 1_000)
        context.insert(pointAncien)

        let pointRecent = PointMatch(seanceID: seance.id, set: 1, joueurID: nil, typeAction: .killAdversaire)
        pointRecent.rotationAuMoment = 4
        pointRecent.rotationAdvAuMoment = 5
        pointRecent.horodatage = Date(timeIntervalSince1970: 2_000)
        context.insert(pointRecent)
        try context.save()

        // Act
        let vm = creerVM(seance: seance, context: context, joueurs: joueurs)

        // Assert — restauré depuis pointRecent (trié par horodatage)
        #expect(vm.rotationActuelle == 4)
        #expect(vm.rotationAdversaire == 5)
        #expect(vm.nousServons == false, "nousServons == estPointPourNous du dernier point")
        #expect(vm.dernierPoint?.id == pointRecent.id)
    }

    // MARK: - enregistrerStat

    @Test("enregistrerStat — kill sur notre service : score incrémenté, PointMatch créé, pas de rotation")
    func enregistrerStatKillSurNotreService() throws {
        // Arrange
        let (context, seance, joueurs) = try creerMatch(nousServonsEnPremier: true)
        let vm = creerVM(seance: seance, context: context, joueurs: joueurs)

        // Act
        vm.enregistrerStat(action: .kill, joueurID: joueurs[0].id)

        // Assert — score et service
        #expect(vm.scoreNous == 1)
        #expect(vm.scoreAdv == 0)
        #expect(vm.nousServons == true, "On servait et on a marqué : on garde le service")
        #expect(vm.rotationActuelle == 1, "Pas de sideout : pas de rotation")
        #expect(vm.rotationAdversaire == 1)

        // Assert — PointMatch persisté avec le contexte du moment
        let points = try context.fetch(FetchDescriptor<PointMatch>())
        let point = try #require(points.first)
        #expect(points.count == 1)
        #expect(point.codeEquipe == Self.codeEquipeTest)
        #expect(point.joueurID == joueurs[0].id)
        #expect(point.rotationAuMoment == 1)
        #expect(point.rotationAdvAuMoment == 1)
        #expect(point.scoreEquipeAuMoment == 1)
        #expect(point.scoreAdversaireAuMoment == 0)
        #expect(vm.dernierPoint?.id == point.id)

        // Assert — le set est sauvegardé sur la séance
        let setSauvegarde = try #require(seance.sets.first(where: { $0.numero == 1 }))
        #expect(setSauvegarde.scoreEquipe == 1)
        #expect(setSauvegarde.scoreAdversaire == 0)
    }

    @Test("enregistrerStat — sideout NOUS : point gagné en réception → rotation avance et prise de service")
    func enregistrerStatSideoutNous() throws {
        // Arrange — l'adversaire sert
        let (context, seance, joueurs) = try creerMatch(nousServonsEnPremier: false)
        let vm = creerVM(seance: seance, context: context, joueurs: joueurs)
        #expect(vm.nousServons == false)

        // Act
        vm.enregistrerStat(action: .kill, joueurID: joueurs[1].id)

        // Assert
        #expect(vm.scoreNous == 1)
        #expect(vm.nousServons == true, "Sideout : on prend le service")
        #expect(vm.rotationActuelle == 2, "Sideout : notre rotation avance")
        #expect(vm.rotationAdversaire == 1, "La rotation adverse ne bouge pas")
        #expect(seance.rotationsHistorique[1] == [2], "La nouvelle rotation est historisée")

        // Le point enregistre la rotation AVANT le sideout
        let point = try #require(context.fetch(FetchDescriptor<PointMatch>()).first)
        #expect(point.rotationAuMoment == 1)
    }

    @Test("enregistrerStat — sideout ADVERSE : point perdu sur notre service → rotationAdversaire avance")
    func enregistrerStatSideoutAdverse() throws {
        // Arrange — nous servons
        let (context, seance, joueurs) = try creerMatch(nousServonsEnPremier: true)
        let vm = creerVM(seance: seance, context: context, joueurs: joueurs)

        // Act
        vm.enregistrerStat(action: .killAdversaire, joueurID: nil)

        // Assert
        #expect(vm.scoreAdv == 1)
        #expect(vm.scoreNous == 0)
        #expect(vm.nousServons == false, "Sideout adverse : l'adversaire prend le service")
        #expect(vm.rotationAdversaire == 2, "Sideout adverse : la rotation adverse avance")
        #expect(vm.rotationActuelle == 1, "Notre rotation ne bouge pas")
        #expect(seance.rotationsHistoriqueAdv[1] == [2])

        let point = try #require(context.fetch(FetchDescriptor<PointMatch>()).first)
        #expect(point.rotationAdvAuMoment == 1, "Le point enregistre la rotation adverse AVANT le sideout")
    }

    // MARK: - annulerDernierPoint

    @Test("annulerDernierPoint — avec sideout nous : score, rotation et service restaurés, PointMatch supprimé")
    func annulerDernierPointAvecSideoutNous() throws {
        // Arrange — sideout nous : réception + kill
        let (context, seance, joueurs) = try creerMatch(nousServonsEnPremier: false)
        let vm = creerVM(seance: seance, context: context, joueurs: joueurs)
        vm.enregistrerStat(action: .kill, joueurID: joueurs[0].id)
        #expect(vm.rotationActuelle == 2)

        // Act
        vm.annulerDernierPoint(actionsRallye: [])

        // Assert
        #expect(vm.scoreNous == 0)
        #expect(vm.scoreAdv == 0)
        #expect(vm.rotationActuelle == 1, "Rotation restaurée depuis rotationAuMoment")
        #expect(vm.nousServons == false, "Le service revient à l'adversaire")
        #expect(vm.dernierPoint == nil)
        #expect(try compterPoints(context) == 0, "Le PointMatch est supprimé")
        #expect((seance.rotationsHistorique[1] ?? []).isEmpty, "L'entrée d'historique du sideout annulé est retirée")
    }

    @Test("annulerDernierPoint — avec sideout adverse : rotation adverse et service restaurés")
    func annulerDernierPointAvecSideoutAdverse() throws {
        // Arrange — sideout adverse : nous servions, point adverse
        let (context, seance, joueurs) = try creerMatch(nousServonsEnPremier: true)
        let vm = creerVM(seance: seance, context: context, joueurs: joueurs)
        vm.enregistrerStat(action: .aceAdversaire, joueurID: nil)
        #expect(vm.rotationAdversaire == 2)

        // Act
        vm.annulerDernierPoint(actionsRallye: [])

        // Assert
        #expect(vm.scoreAdv == 0)
        #expect(vm.rotationAdversaire == 1, "Rotation adverse restaurée depuis rotationAdvAuMoment")
        #expect(vm.nousServons == true, "Le service nous revient")
        #expect(try compterPoints(context) == 0)
        #expect((seance.rotationsHistoriqueAdv[1] ?? []).isEmpty)
    }

    @Test("annulerDernierPoint — sans sideout (kill sur notre service) : le service nous reste")
    func annulerDernierPointSansSideout() throws {
        // Arrange — nous servons et marquons : aucun sideout n'a eu lieu
        let (context, seance, joueurs) = try creerMatch(nousServonsEnPremier: true)
        let vm = creerVM(seance: seance, context: context, joueurs: joueurs)
        vm.enregistrerStat(action: .kill, joueurID: joueurs[0].id)
        #expect(vm.rotationActuelle == 1)
        #expect(vm.nousServons == true)

        // Act
        vm.annulerDernierPoint(actionsRallye: [])

        // Assert — score et rotation correctement restaurés, point supprimé
        #expect(vm.scoreNous == 0)
        #expect(vm.rotationActuelle == 1, "rotationAuMoment == rotation courante : restauration sans effet")
        #expect(try compterPoints(context) == 0)
        #expect(vm.dernierPoint == nil)

        // Règle volleyball : qui a marqué le point précédent sert — pas de point
        // précédent ici, donc le serveur du début de set (nous) est restauré.
        #expect(vm.nousServons == true,
                "Pas de sideout : nous servions avant ce point, le service nous reste")
    }

    // MARK: - Modification manuelle des rotations

    @Test("modifierRotation — accepte 1-6 et rejette les valeurs hors bornes")
    func modifierRotationBornes() throws {
        // Arrange
        let (context, seance, joueurs) = try creerMatch()
        let vm = creerVM(seance: seance, context: context, joueurs: joueurs)

        // Act / Assert — valeurs valides
        vm.modifierRotation(nouvelleRotation: 4)
        #expect(vm.rotationActuelle == 4)
        vm.modifierRotation(nouvelleRotation: 6)
        #expect(vm.rotationActuelle == 6)
        vm.modifierRotation(nouvelleRotation: 1)
        #expect(vm.rotationActuelle == 1)

        // Act / Assert — hors bornes : ignoré
        vm.modifierRotation(nouvelleRotation: 0)
        #expect(vm.rotationActuelle == 1)
        vm.modifierRotation(nouvelleRotation: 7)
        #expect(vm.rotationActuelle == 1)

        // Seules les modifications valides sont historisées
        #expect(seance.rotationsHistorique[1] == [4, 6, 1])
    }

    @Test("modifierRotationAdversaire — accepte 1-6 et rejette les valeurs hors bornes")
    func modifierRotationAdversaireBornes() throws {
        // Arrange
        let (context, seance, joueurs) = try creerMatch()
        let vm = creerVM(seance: seance, context: context, joueurs: joueurs)

        // Act / Assert
        vm.modifierRotationAdversaire(nouvelleRotation: 5)
        #expect(vm.rotationAdversaire == 5)

        vm.modifierRotationAdversaire(nouvelleRotation: 0)
        #expect(vm.rotationAdversaire == 5)
        vm.modifierRotationAdversaire(nouvelleRotation: 7)
        #expect(vm.rotationAdversaire == 5)

        #expect(seance.rotationsHistoriqueAdv[1] == [5])
    }

    // MARK: - Joueurs sur le terrain

    @Test("joueursActuellementSurTerrain — 6 de départ aux postes 1-6, 7e joueur sur le banc")
    func joueursSurTerrainSixDeDepart() throws {
        // Arrange
        let (context, seance, joueurs) = try creerMatch()
        let vm = creerVM(seance: seance, context: context, joueurs: joueurs)

        // Act
        let surTerrain = vm.joueursActuellementSurTerrain

        // Assert
        #expect(surTerrain.count == 6)
        #expect(surTerrain.map(\.poste) == [1, 2, 3, 4, 5, 6])
        for joueur in surTerrain {
            #expect(joueur.numero == joueur.poste, "R1 sans décalage : le partant du poste N y reste")
        }
        #expect(vm.joueursSurLeBanc.map(\.id) == [joueurs[6].id], "Le 7e joueur est sur le banc")
    }

    @Test("joueursActuellementSurTerrain — après substitution : l'entrant remplace le sortant")
    func joueursSurTerrainApresSubstitution() throws {
        // Arrange
        let (context, seance, joueurs) = try creerMatch()
        let vm = creerVM(seance: seance, context: context, joueurs: joueurs)
        let sortant = joueurs[0]
        let entrant = joueurs[6]

        // Act
        vm.effectuerSubstitution(sortantID: sortant.id, entrantID: entrant.id)
        let surTerrain = vm.joueursActuellementSurTerrain

        // Assert
        #expect(surTerrain.count == 6)
        #expect(surTerrain.contains(where: { $0.joueurID == entrant.id }), "L'entrant est sur le terrain")
        #expect(!surTerrain.contains(where: { $0.joueurID == sortant.id }), "Le sortant n'y est plus")
        #expect(surTerrain.first(where: { $0.joueurID == entrant.id })?.poste == 1,
                "L'entrant occupe le poste du sortant")
        #expect(vm.joueursSurLeBanc.map(\.id) == [sortant.id], "Le sortant est sur le banc")
        #expect(vm.subsUtiliseesDansSet == 1)
    }
}
