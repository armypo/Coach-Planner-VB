//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//

import Foundation
import Testing
@testable import PlaycoVideo

@Suite("Outil playco-video — logique pure")
struct CommandesVideoPureTests {

    #if canImport(AVFoundation)
    @Test("plages condensées : marges ajoutées, chevauchements fusionnés")
    func plages() {
        let e = [EchangeDetecte(debut: 10, fin: 20, intensite: 1),
                 EchangeDetecte(debut: 22, fin: 30, intensite: 1),
                 EchangeDetecte(debut: 1, fin: 5, intensite: 1)]
        let p = CommandesVideo.plagesCondensees(e, avant: 2, apres: 1.5)
        #expect(p.map(\.0) == [0, 8])
        #expect(p.map(\.1) == [6.5, 31.5])
    }

    @Test("formats d'affichage")
    func formats() {
        #expect(CommandesVideo.horodatage(75.25) == "01:15.2")
        #expect(CommandesVideo.duree(42) == "42 s")
        #expect(CommandesVideo.duree(125) == "2 min 05 s")
    }

    @Test("sans commande, commande inconnue, fichier introuvable : aide + code 64")
    func erreursUsage() async {
        let vide = await CommandesVideo.executer([])
        let inconnue = await CommandesVideo.executer(["inconnue"])
        let introuvable = await CommandesVideo.executer(["infos", "/nulle/part.mov"])
        let aide = await CommandesVideo.executer(["aide"])
        #expect(vide.code == 64)
        #expect(inconnue.code == 64)
        #expect(introuvable.code == 64)
        #expect(introuvable.sortie.contains("introuvable"))
        #expect(aide.code == 0)
    }
    #endif
}

#if canImport(AVFoundation)
@Suite("Outil playco-video — sur vraie vidéo générée")
struct CommandesVideoMediaTests {

    @Test("infos : durée, taille et origine de la date")
    func infos() async throws {
        let url = try await FabriqueMedia.video(duree: 3, actives: [], dateCreation: "2026-09-29T10:00:00-0400")
        let r = await CommandesVideo.executer(["infos", url.path])
        #expect(r.code == 0)
        #expect(r.sortie.contains("\(FabriqueMedia.largeur)×\(FabriqueMedia.hauteur)"))
        #expect(r.sortie.contains("fiable"))
    }

    @Test("echanges : liste lisible et JSON décodable")
    func echanges() async throws {
        let url = try await FabriqueMedia.video(duree: 20, actives: [5...9, 13...16])
        let texte = await CommandesVideo.executer(["echanges", url.path])
        #expect(texte.code == 0)
        #expect(texte.sortie.contains("2 échange(s)"))

        let json = await CommandesVideo.executer(["echanges", url.path, "--json"])
        let relus = try JSONDecoder().decode([EchangeDetecte].self, from: Data(json.sortie.utf8))
        #expect(relus.count == 2)
    }

    @Test("condenser : MP4 sans les temps morts, de la bonne durée")
    func condenser() async throws {
        let url = try await FabriqueMedia.video(duree: 20, actives: [5...9, 13...16])
        let sortie = FabriqueMedia.fichierTemporaire("mp4")
        let r = await CommandesVideo.executer(["condenser", url.path, "-o", sortie.path, "--avant", "1", "--apres", "1"])
        #expect(r.code == 0)
        // Échanges ~[5, 9.2] et ~[13, 16.2] + 1 s de chaque côté ≈ 6,2 + 5,2 s.
        let duree = try await LecteurMetadonneesVideo.lire(sortie).duree
        #expect(abs(duree - 11.4) < 1.2)
    }

    /// Vidéo de 40 s à 4 échanges + CSV des points saisis 2 s après chaque
    /// fin, avec une horloge de caméra fausse de 30 s.
    private func matchAvecPoints() async throws -> (video: URL, points: URL, evenements: [EvenementMatch]) {
        let actives: [ClosedRange<Double>] = [3...7, 12...16, 21...26, 31...35]
        let url = try await FabriqueMedia.video(duree: 40, actives: actives, dateCreation: "2026-09-29T10:00:00-0400")
        let debut = try #require(ImportPoints.analyserDate("2026-09-29T14:00:00Z"))
        let lignes = actives.enumerated().map { i, a -> String in
            let tap = debut.addingTimeInterval(a.upperBound + 2 + 30)
            return "\(ISO8601DateFormatter().string(from: tap));\(i % 2 == 0 ? "Kill" : "Ace");pourNous;1"
        }
        let csv = FabriqueMedia.fichierTemporaire("csv")
        try ("horodatage;etiquette;resultat;periode\n" + lignes.joined(separator: "\n")).write(to: csv, atomically: true, encoding: .utf8)
        return (url, csv, ImportPoints.depuisCSV(try String(contentsOf: csv, encoding: .utf8)).evenements)
    }

    @Test("caler : retrouve l'horloge fausse de 30 s et situe les 4 points")
    func calerVideo() async throws {
        let m = try await matchAvecPoints()
        let r = try await CommandesVideo.calerVideo(m.video, evenements: m.evenements)
        #expect(abs(r.calage.decalage + 30) <= 4)
        #expect(r.calage.estFiable)
        #expect(r.chapitres.count == 4)
    }

    @Test("caler + montage des seuls « Kill »")
    func calerMontage() async throws {
        let m = try await matchAvecPoints()
        let sortie = FabriqueMedia.fichierTemporaire("mp4")
        let r = await CommandesVideo.executer(["caler", m.video.path, "--points", m.points.path,
                                               "--montage", sortie.path, "--etiquette", "Kill"])
        #expect(r.code == 0)
        #expect(r.sortie.contains("2 clip(s)"))
        let duree = try await LecteurMetadonneesVideo.lire(sortie).duree
        #expect(duree > 15 && duree < 25)
    }

    @Test("condenser sans -o : erreur d'usage")
    func condenserSansSortie() async throws {
        let url = try await FabriqueMedia.video(duree: 2, actives: [])
        let r = await CommandesVideo.executer(["condenser", url.path])
        #expect(r.code == 64)
    }
}
#endif
