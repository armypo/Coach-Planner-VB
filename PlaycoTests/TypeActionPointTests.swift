//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//

import Testing
import Foundation
@testable import Playco

@Suite("TypeActionPoint — classification stats match")
struct TypeActionPointTests {

    @Test("estPointPourNous : kills, aces et blocs comptent pour nous")
    func pointsPourNousScoring() {
        #expect(TypeActionPoint.kill.estPointPourNous)
        #expect(TypeActionPoint.ace.estPointPourNous)
        #expect(TypeActionPoint.blocSeul.estPointPourNous)
        #expect(TypeActionPoint.blocAssiste.estPointPourNous)
        #expect(TypeActionPoint.bloc.estPointPourNous, "legacy")
    }

    @Test("estPointPourNous : erreurs adverses comptent pour nous")
    func pointsPourNousErreursAdv() {
        #expect(TypeActionPoint.erreurAdversaire.estPointPourNous)
        #expect(TypeActionPoint.erreurAttaqueAdversaire.estPointPourNous)
        #expect(TypeActionPoint.erreurServiceAdversaire.estPointPourNous)
    }

    @Test("estPointPourNous : nos erreurs comptent contre nous")
    func pointsContreNousErreurs() {
        #expect(!TypeActionPoint.erreurAttaque.estPointPourNous)
        #expect(!TypeActionPoint.erreurService.estPointPourNous)
        #expect(!TypeActionPoint.erreurBloc.estPointPourNous)
        #expect(!TypeActionPoint.erreurReception.estPointPourNous)
        #expect(!TypeActionPoint.fauteJeu.estPointPourNous)
        #expect(!TypeActionPoint.erreurEquipe.estPointPourNous, "legacy")
    }

    @Test("estPointPourNous : scoring adversaire compte contre nous")
    func pointsContreNousAdv() {
        #expect(!TypeActionPoint.killAdversaire.estPointPourNous)
        #expect(!TypeActionPoint.aceAdversaire.estPointPourNous)
        #expect(!TypeActionPoint.blocAdversaire.estPointPourNous)
    }

    @Test("estBloc : seuls les 3 types de bloc renvoient vrai")
    func estBloc() {
        #expect(TypeActionPoint.blocSeul.estBloc)
        #expect(TypeActionPoint.blocAssiste.estBloc)
        #expect(TypeActionPoint.bloc.estBloc, "legacy")

        #expect(!TypeActionPoint.kill.estBloc)
        #expect(!TypeActionPoint.ace.estBloc)
        #expect(!TypeActionPoint.blocAdversaire.estBloc, "bloc adv n'est pas un de nos blocs")
        #expect(!TypeActionPoint.erreurBloc.estBloc, "err bloc n'est pas un bloc réussi")
    }

    @Test("estErreurEquipe : nos 6 erreurs uniquement")
    func estErreurEquipe() {
        #expect(TypeActionPoint.erreurAttaque.estErreurEquipe)
        #expect(TypeActionPoint.erreurService.estErreurEquipe)
        #expect(TypeActionPoint.erreurBloc.estErreurEquipe)
        #expect(TypeActionPoint.erreurReception.estErreurEquipe)
        #expect(TypeActionPoint.fauteJeu.estErreurEquipe)
        #expect(TypeActionPoint.erreurEquipe.estErreurEquipe, "legacy")

        #expect(!TypeActionPoint.kill.estErreurEquipe)
        #expect(!TypeActionPoint.erreurAdversaire.estErreurEquipe, "leur erreur n'est pas la nôtre")
    }

    @Test("estStatAdversaire : stats adverses ne sont pas liées à un joueur de notre équipe")
    func estStatAdversaire() {
        #expect(TypeActionPoint.killAdversaire.estStatAdversaire)
        #expect(TypeActionPoint.aceAdversaire.estStatAdversaire)
        #expect(TypeActionPoint.blocAdversaire.estStatAdversaire)
        #expect(TypeActionPoint.erreurAttaqueAdversaire.estStatAdversaire)
        #expect(TypeActionPoint.erreurServiceAdversaire.estStatAdversaire)
        #expect(TypeActionPoint.erreurAdversaire.estStatAdversaire)

        #expect(!TypeActionPoint.kill.estStatAdversaire)
        #expect(!TypeActionPoint.erreurAttaque.estStatAdversaire)
    }

    @Test("supportsZone : catégorie heatmap = supporte zone")
    func supportsZone() {
        #expect(TypeActionPoint.kill.supportsZone)
        #expect(TypeActionPoint.ace.supportsZone)
        #expect(TypeActionPoint.blocSeul.supportsZone)
        #expect(TypeActionPoint.erreurReception.supportsZone)

        // 3.7 refonte : les actions MARQUANTES adverses supportent la zone
        // (scouting « prédictions vs réalité ») — pas les erreurs adverses.
        #expect(TypeActionPoint.killAdversaire.supportsZone)
        #expect(TypeActionPoint.aceAdversaire.supportsZone)
        #expect(TypeActionPoint.blocAdversaire.supportsZone)

        #expect(!TypeActionPoint.erreurAdversaire.supportsZone)
        #expect(!TypeActionPoint.erreurAttaqueAdversaire.supportsZone)
        #expect(!TypeActionPoint.erreurServiceAdversaire.supportsZone)
        #expect(!TypeActionPoint.fauteJeu.supportsZone)
    }

    @Test("Cohérence : actionsPointPourNous toutes estPointPourNous == true")
    func coherencePointPourNous() {
        for action in TypeActionPoint.actionsPointPourNous {
            #expect(action.estPointPourNous, "\(action.rawValue) doit être un point pour nous")
        }
    }

    @Test("Cohérence : actionsPointContre toutes estPointPourNous == false")
    func coherencePointContre() {
        for action in TypeActionPoint.actionsPointContre {
            #expect(!action.estPointPourNous, "\(action.rawValue) doit être un point contre nous")
        }
    }

    @Test("Round-trip raw value preserve l'enum")
    func roundTrip() {
        for action in TypeActionPoint.allCases {
            let raw = action.rawValue
            let restored = TypeActionPoint(rawValue: raw)
            #expect(restored == action, "Round-trip cassé pour \(action.rawValue)")
        }
    }

    @Test("PointMatch utilise typeAction.estPointPourNous")
    func pointMatchEstPointPourNous() {
        let p1 = PointMatch(seanceID: UUID(), set: 1, typeAction: .kill)
        let p2 = PointMatch(seanceID: UUID(), set: 1, typeAction: .killAdversaire)
        #expect(p1.estPointPourNous)
        #expect(!p2.estPointPourNous)
    }
}
