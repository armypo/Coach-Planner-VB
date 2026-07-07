//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  2.3 — Lien universel d'invitation : https://playco.app/join/{codeEquipe}/{codeInvitation}
//  Construction, analyse (validation stricte — surface d'authentification) et QR.
//  ⚠️ Le lien n'ACCORDE rien : il pré-remplit la jonction SIWA existante
//  (rejoindreEquipe), qui reste seule juge. AASA + entitlement Associated
//  Domains + domaine = actions humaines (roadmap) ; le QR fonctionne dès
//  maintenant via l'appareil photo (ouverture Safari → app quand AASA prêt).

import Foundation
import CoreImage.CIFilterBuiltins
import UIKit

enum LienInvitation {

    static let hote = "playco.app"
    static let cheminJonction = "join"

    /// Jeu de caractères autorisé des codes (défense : jamais d'injection de
    /// chemin ni d'unicode exotique dans un lien scanné).
    private static let caracteresAutorises = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
    private static let longueurMax = 32

    private static func estCodeValide(_ code: String) -> Bool {
        !code.isEmpty && code.count <= longueurMax &&
        code.unicodeScalars.allSatisfy { caracteresAutorises.contains($0) }
    }

    /// Construit le lien d'invitation, ou nil si un code est invalide.
    static func construire(codeEquipe: String, codeInvitation: String) -> URL? {
        guard estCodeValide(codeEquipe), estCodeValide(codeInvitation) else { return nil }
        var composantes = URLComponents()
        composantes.scheme = "https"
        composantes.host = hote
        composantes.path = "/\(cheminJonction)/\(codeEquipe)/\(codeInvitation)"
        return composantes.url
    }

    /// Analyse un lien entrant. Validation stricte : hôte exact, chemin
    /// exactement /join/{code}/{code}, codes au jeu de caractères autorisé.
    static func analyser(_ url: URL) -> (codeEquipe: String, codeInvitation: String)? {
        guard url.scheme == "https" || url.scheme == "http",
              url.host()?.lowercased() == hote else { return nil }
        let segments = url.pathComponents.filter { $0 != "/" }
        guard segments.count == 3, segments[0] == cheminJonction else { return nil }
        let codeEquipe = segments[1], codeInvitation = segments[2]
        guard estCodeValide(codeEquipe), estCodeValide(codeInvitation) else { return nil }
        return (codeEquipe, codeInvitation)
    }

    /// QR du lien (CoreImage, mis à l'échelle sans lissage pour l'impression/projection).
    static func genererQR(codeEquipe: String, codeInvitation: String, echelle: CGFloat = 12) -> UIImage? {
        guard let url = construire(codeEquipe: codeEquipe, codeInvitation: codeInvitation) else { return nil }
        let filtre = CIFilter.qrCodeGenerator()
        filtre.message = Data(url.absoluteString.utf8)
        filtre.correctionLevel = "M"
        guard let sortie = filtre.outputImage else { return nil }
        let agrandie = sortie.transformed(by: CGAffineTransform(scaleX: echelle, y: echelle))
        guard let cg = CIContext().createCGImage(agrandie, from: agrandie.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

extension Notification.Name {
    /// Lien d'invitation reçu (onOpenURL) — userInfo : "codeEquipe", "codeInvitation".
    static let lienInvitationRecu = Notification.Name("lienInvitationRecu")
}
