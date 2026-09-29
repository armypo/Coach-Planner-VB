//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Logique de l'outil `playco-video` (dans la bibliothèque pour être testée).
//  Premier contact avec de VRAIES vidéos de match, sans l'app : infos du
//  fichier, échanges détectés, sifflets, et match CONDENSÉ (temps morts
//  coupés) exporté en MP4.
//

#if canImport(AVFoundation)
import Foundation

public enum CommandesVideo {

    public static let aide = """
    playco-video — outils vidéo Playco (hors de l'app)

    Usage :
      playco-video infos <video>
      playco-video echanges <video> [--json]
      playco-video sifflets <video>
      playco-video condenser <video> -o <sortie.mp4> [--avant 2] [--apres 1.5]

    condenser : garde seulement les échanges (plus une marge avant/après,
    en secondes) et les met bout à bout — le match sans les temps morts.
    """

    /// Exécute une commande ; renvoie le code de sortie et le texte à afficher.
    public static func executer(_ arguments: [String]) async -> (code: Int32, sortie: String) {
        guard let commande = arguments.first else { return (64, aide) }
        let options = Array(arguments.dropFirst())
        do {
            switch commande {
            case "infos": return try await infos(options)
            case "echanges": return try await echanges(options)
            case "sifflets": return try await sifflets(options)
            case "condenser": return try await condenser(options)
            case "aide", "--help", "-h": return (0, aide)
            default: return (64, "Commande inconnue : \(commande)\n\n\(aide)")
            }
        } catch let erreur as ErreurCommande {
            return (64, "\(erreur.message)\n\n\(aide)")
        } catch {
            return (1, "Erreur : \(error)")
        }
    }

    // MARK: - Commandes

    static func infos(_ options: [String]) async throws -> (code: Int32, sortie: String) {
        let url = try video(options)
        let m = try await LecteurMetadonneesVideo.lire(url)
        var lignes = [
            "Fichier   : \(url.lastPathComponent)",
            "Durée     : \(duree(m.duree))",
            "Image     : \(m.largeur)×\(m.hauteur) à \(String(format: "%.1f", m.imagesParSeconde)) img/s",
            "Audio     : \(m.aUnePisteAudio ? "oui" : "non")"
        ]
        if let date = m.dateCreation {
            let origine = m.dateFiable ? "clé caméra — fiable" : "en-tête du fichier — NON fiable (ré-encodé ?)"
            lignes.append("Création  : \(ISO8601DateFormatter().string(from: date)) (\(origine))")
        } else {
            lignes.append("Création  : inconnue (calage par ancres ou automatique requis)")
        }
        return (0, lignes.joined(separator: "\n"))
    }

    static func echanges(_ options: [String]) async throws -> (code: Int32, sortie: String) {
        let url = try video(options)
        let trouves = try await AnalyseurEchanges().echanges(video: url)
        if options.contains("--json") {
            let encodeur = JSONEncoder()
            encodeur.outputFormatting = [.prettyPrinted, .sortedKeys]
            return (0, String(decoding: try encodeur.encode(trouves), as: UTF8.self))
        }
        let total = try await LecteurMetadonneesVideo.lire(url).duree
        var lignes = trouves.enumerated().map { i, e in
            "\(String(format: "%3d", i + 1))  \(horodatage(e.debut)) → \(horodatage(e.fin))  (\(String(format: "%.1f", e.duree)) s)"
        }
        lignes.append(resume(trouves, total: total))
        return (0, lignes.joined(separator: "\n"))
    }

    static func sifflets(_ options: [String]) async throws -> (code: Int32, sortie: String) {
        let url = try video(options)
        let trouves = try await ExtracteurSignaux.sifflets(video: url)
        var lignes = trouves.map {
            "\(horodatage($0.debut))  \(String(format: "%.2f", $0.duree)) s  \(Int($0.frequence)) Hz"
        }
        lignes.append("\(trouves.count) coup(s) de sifflet")
        return (0, lignes.joined(separator: "\n"))
    }

    static func condenser(_ options: [String]) async throws -> (code: Int32, sortie: String) {
        let url = try video(options)
        guard let chemin = valeur("-o", options) else { throw ErreurCommande(message: "Sortie manquante : -o <sortie.mp4>") }
        let avant = Double(valeur("--avant", options) ?? "") ?? 2
        let apres = Double(valeur("--apres", options) ?? "") ?? 1.5

        let trouves = try await AnalyseurEchanges().echanges(video: url)
        guard !trouves.isEmpty else { return (1, "Aucun échange détecté : rien à condenser.") }
        let plages = plagesCondensees(trouves, avant: avant, apres: apres)
        let sortie = URL(fileURLWithPath: chemin)
        try await ExporteurClip.exporterMontage(sources: [url], plages: plages.map { (0, $0.0, $0.1) }, vers: sortie)

        let total = try await LecteurMetadonneesVideo.lire(url).duree
        let condense = plages.reduce(0) { $0 + $1.1 - $1.0 }
        return (0, """
        \(resume(trouves, total: total))
        Vidéo condensée : \(duree(condense)) → \(sortie.path)
        """)
    }

    // MARK: - Outils

    struct ErreurCommande: Error {
        let message: String
    }

    /// Premier argument qui n'est ni une option ni la valeur d'une option.
    static func video(_ options: [String]) throws -> URL {
        let avecValeur: Set<String> = ["-o", "--avant", "--apres"]
        var i = 0
        while i < options.count {
            let o = options[i]
            if avecValeur.contains(o) { i += 2; continue }
            if o.hasPrefix("-") { i += 1; continue }
            guard FileManager.default.fileExists(atPath: o) else {
                throw ErreurCommande(message: "Fichier introuvable : \(o)")
            }
            return URL(fileURLWithPath: o)
        }
        throw ErreurCommande(message: "Vidéo manquante.")
    }

    static func valeur(_ nom: String, _ options: [String]) -> String? {
        guard let i = options.firstIndex(of: nom), i + 1 < options.count else { return nil }
        return options[i + 1]
    }

    /// Échanges élargis de la marge, puis fusionnés s'ils se chevauchent.
    static func plagesCondensees(_ echanges: [EchangeDetecte], avant: Double, apres: Double) -> [(Double, Double)] {
        var plages: [(Double, Double)] = []
        for e in echanges.sorted(by: { $0.debut < $1.debut }) {
            let a = max(0, e.debut - avant), b = e.fin + apres
            if let derniere = plages.last, a <= derniere.1 {
                plages[plages.count - 1].1 = max(derniere.1, b)
            } else {
                plages.append((a, b))
            }
        }
        return plages
    }

    static func resume(_ echanges: [EchangeDetecte], total: Double) -> String {
        let jeu = echanges.reduce(0) { $0 + $1.duree }
        let part = total > 0 ? Int((jeu / total * 100).rounded()) : 0
        return "\(echanges.count) échange(s) — \(duree(jeu)) de jeu sur \(duree(total)) (\(part) %)"
    }

    static func horodatage(_ secondes: Double) -> String {
        let s = max(0, secondes)
        return String(format: "%02d:%04.1f", Int(s) / 60, s.truncatingRemainder(dividingBy: 60))
    }

    static func duree(_ secondes: Double) -> String {
        let s = Int(max(0, secondes).rounded())
        return s >= 60 ? "\(s / 60) min \(String(format: "%02d", s % 60)) s" : "\(s) s"
    }
}
#endif
