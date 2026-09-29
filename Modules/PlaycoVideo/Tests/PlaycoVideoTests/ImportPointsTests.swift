//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//

import Foundation
import Testing
@testable import PlaycoVideo

@Suite("ImportPoints — CSV de points")
struct ImportPointsTests {

    @Test("en-tête ignoré, « ; » ou « , », fractions de seconde, résultat et période")
    func lecture() throws {
        let csv = """
        horodatage;etiquette;resultat;periode
        2026-09-29T19:04:12.350-04:00;Kill;pourNous;2
        2026-09-29T19:03:00-04:00, Err. service, -
        2026-09-29T23:05:00Z;Ace;+

        pas-une-date;Kill
        2026-09-29T19:06:00Z;
        """
        let r = ImportPoints.depuisCSV(csv)
        #expect(r.lignesIgnorees == 3)
        #expect(r.evenements.map(\.etiquette) == ["Err. service", "Kill", "Ace"])
        #expect(r.evenements.map(\.resultat) == [.contreNous, .pourNous, .pourNous])
        #expect(r.evenements.map(\.periode) == [1, 2, 1])
        let attendu = try #require(ImportPoints.analyserDate("2026-09-29T23:04:12.350Z"))
        #expect(abs(r.evenements[1].horodatage.timeIntervalSince(attendu)) < 0.001)
    }

    @Test("résultat inconnu : jamais deviné")
    func resultatInconnu() {
        let r = ImportPoints.depuisCSV("2026-09-29T19:05:00Z;Bloc;peut-etre")
        #expect(r.evenements.first?.resultat == nil)
    }
}
