//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Points d'un match en CSV — le pont vers de vraies stats sans passer par
//  l'app : une ligne par point, séparateur « ; » (convention Playco) ou « , ».
//
//    horodatage;etiquette;resultat;periode
//    2026-09-29T19:04:12.350-04:00;Kill;pourNous;1
//
//  horodatage (ISO 8601) et etiquette obligatoires ; resultat ∈ pourNous |
//  contreNous | + | - | vide ; periode entière (1 par défaut). Les lignes
//  illisibles (dont l'en-tête) sont comptées, jamais devinées.
//

import Foundation

public enum ImportPoints {

    public struct Resultat: Sendable {
        public var evenements: [EvenementMatch]
        public var lignesIgnorees: Int
    }

    public static func depuisCSV(_ texte: String) -> Resultat {
        var evenements: [EvenementMatch] = []
        var ignorees = 0
        for ligneBrute in texte.split(whereSeparator: \.isNewline) {
            let ligne = ligneBrute.trimmingCharacters(in: .whitespaces)
            guard !ligne.isEmpty else { continue }
            let separateur: Character = ligne.contains(";") ? ";" : ","
            let champs = ligne.split(separator: separateur, omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard champs.count >= 2, let date = analyserDate(champs[0]), !champs[1].isEmpty else {
                ignorees += 1
                continue
            }
            evenements.append(EvenementMatch(
                horodatage: date,
                etiquette: champs[1],
                resultat: champs.count > 2 ? resultat(champs[2]) : nil,
                periode: champs.count > 3 ? Int(champs[3]) ?? 1 : 1))
        }
        return Resultat(evenements: evenements.sorted { $0.horodatage < $1.horodatage }, lignesIgnorees: ignorees)
    }

    static func resultat(_ texte: String) -> ResultatEvenement? {
        switch texte.lowercased() {
        case "pournous", "+", "pour": return .pourNous
        case "contrenous", "-", "contre": return .contreNous
        default: return nil
        }
    }

    static func analyserDate(_ texte: String) -> Date? {
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: texte) { return date }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: texte)
    }
}
