//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//

import Testing
import Foundation
@testable import Playco

@Suite("JoueurEquipe — calculs statistiques NCAA/FIVB")
struct JoueurEquipeStatsTests {

    private func joueur() -> JoueurEquipe {
        JoueurEquipe(nom: "Test", prenom: "J", numero: 1, poste: .recepteur)
    }

    @Test("pourcentageAttaque = (kills - errAttaque) / totales")
    func hittingPercent() {
        let j = joueur()
        j.attaquesReussies = 20
        j.erreursAttaque = 5
        j.attaquesTotales = 50
        // (20 - 5) / 50 = 0.30
        #expect(abs(j.pourcentageAttaque - 0.30) < 0.0001)
    }

    @Test("pourcentageAttaque = 0 quand 0 tentatives (no divide by zero)")
    func hittingPercentZero() {
        let j = joueur()
        j.attaquesTotales = 0
        #expect(j.pourcentageAttaque == 0)
    }

    @Test("pourcentageAttaque peut être négatif (plus d'erreurs que de kills)")
    func hittingPercentNegatif() {
        let j = joueur()
        j.attaquesReussies = 2
        j.erreursAttaque = 8
        j.attaquesTotales = 20
        // (2 - 8) / 20 = -0.30
        #expect(j.pourcentageAttaque < 0)
        #expect(abs(j.pourcentageAttaque - (-0.30)) < 0.0001)
    }

    @Test("efficaciteReception = (réussies - erreurs) / totales × 100")
    func efficaciteReception() {
        let j = joueur()
        j.receptionsReussies = 30
        j.erreursReception = 5
        j.receptionsTotales = 40
        // (30 - 5) / 40 × 100 = 62.5
        #expect(abs(j.efficaciteReception - 62.5) < 0.01)
    }

    @Test("blocsTotaux = blocsSeuls + 0.5 × blocsAssistes")
    func blocsTotaux() {
        let j = joueur()
        j.blocsSeuls = 4
        j.blocsAssistes = 6
        // 4 + 6×0.5 = 7
        #expect(j.blocsTotaux == 7.0)
    }

    @Test("pointsCalcules = kills + aces + blocsSeuls + round(blocsAssistes×0.5)")
    func pointsCalcules() {
        let j = joueur()
        j.attaquesReussies = 10
        j.aces = 3
        j.blocsSeuls = 2
        j.blocsAssistes = 4
        // 10 + 3 + 2 + round(2) = 17
        #expect(j.pointsCalcules == 17)
    }

    @Test("killsParSet, acesParSet, blocsParSet : 0 si 0 sets joués")
    func parSetSansSets() {
        let j = joueur()
        j.attaquesReussies = 10
        j.aces = 3
        j.setsJoues = 0
        #expect(j.killsParSet == 0)
        #expect(j.acesParSet == 0)
        #expect(j.blocsParSet == 0)
    }

    @Test("killsParSet correct avec 5 sets")
    func killsParSetAvec5Sets() {
        let j = joueur()
        j.attaquesReussies = 15
        j.setsJoues = 5
        #expect(j.killsParSet == 3.0)
    }

    @Test("pointsPerdus = somme erreurs (attaque + service + bloc + réception)")
    func pointsPerdus() {
        let j = joueur()
        j.erreursAttaque = 3
        j.erreursService = 2
        j.erreursBloc = 1
        j.erreursReception = 4
        #expect(j.pointsPerdus == 10)
    }

    @Test("estValide : refuse erreurs > totales")
    func estValideIncoherence() {
        let j = joueur()
        j.attaquesReussies = 10
        j.erreursAttaque = 20
        j.attaquesTotales = 15
        #expect(!j.estValide, "erreurs > totales doit être invalide")
    }

    @Test("estValide : refuse nom vide")
    func estValideNomVide() {
        let j = JoueurEquipe(nom: "  ", prenom: "Bob", numero: 1, poste: .recepteur)
        #expect(!j.estValide)
    }

    @Test("estValide : accepte joueur normal")
    func estValideJoueurNormal() {
        let j = JoueurEquipe(nom: "Smith", prenom: "John", numero: 7, poste: .passeur)
        j.attaquesReussies = 5
        j.attaquesTotales = 10
        #expect(j.estValide)
    }

    @Test("init clampe numéro négatif à 0")
    func initClampeNumero() {
        let j = JoueurEquipe(nom: "X", prenom: "Y", numero: -5, poste: .libero)
        #expect(j.numero == 0)
    }
}
