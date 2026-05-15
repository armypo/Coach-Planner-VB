//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Testing
import Foundation
@testable import Playco

/// Tests de la politique de mot de passe NIST 800-63B.
/// Pure fonctionnel, pas d'actor ni de Keychain → peut tourner en parallèle.
@Suite("PasswordPolicy — NIST 800-63B")
struct PasswordPolicyTests {

    @Test("Refuse mot de passe < 12 caractères")
    func mdpTropCourt() {
        let erreur = PasswordPolicy.valider("court12345",
                                            identifiant: "user",
                                            prenom: "Jean",
                                            nom: "Tremblay")
        #expect(erreur?.contains("12 caractères") == true)
    }

    @Test("Refuse mot de passe commun exactement dans la blacklist")
    func mdpCommunRefuse() {
        let erreur = PasswordPolicy.valider("motdepasse12",
                                            identifiant: "user",
                                            prenom: "Jean",
                                            nom: "Tremblay")
        #expect(erreur?.contains("trop commun") == true)
    }

    @Test("Refuse contournement par suffixe (.contains, pas .==)")
    func mdpBlacklistContournementRefuse() {
        // "volleyball123!" contient "volleyball123" de la blacklist
        let erreur = PasswordPolicy.valider("volleyball123!",
                                            identifiant: "user",
                                            prenom: "Jean",
                                            nom: "Tremblay")
        #expect(erreur?.contains("trop commun") == true)
    }

    @Test("Refuse contournement par préfixe")
    func mdpBlacklistPrefixeRefuse() {
        // "xyzplayco999" contient "playco" de la blacklist
        let erreur = PasswordPolicy.valider("xyzplayco999",
                                            identifiant: "user",
                                            prenom: "Jean",
                                            nom: "Tremblay")
        #expect(erreur?.contains("trop commun") == true)
    }

    @Test("Refuse si contient identifiant/prénom/nom (insensible casse)")
    func mdpContientPII() {
        // Contient "tremblay" (nom insensible casse)
        let erreur = PasswordPolicy.valider("SuperTremblay9!",
                                            identifiant: "jean.tremblay",
                                            prenom: "Jean",
                                            nom: "Tremblay")
        #expect(erreur?.contains("identifiant") == true)
    }

    @Test("Refuse si contient identifiant complet")
    func mdpContientIdentifiant() {
        let erreur = PasswordPolicy.valider("MonPassJean.Tremblay1",
                                            identifiant: "jean.tremblay",
                                            prenom: "Jean",
                                            nom: "Tremblay")
        #expect(erreur?.contains("identifiant") == true)
    }

    @Test("Accepte mot de passe valide unique ≥ 12 chars")
    func mdpValideAccepte() {
        let erreur = PasswordPolicy.valider("Cheval-Sauvage-2026!",
                                            identifiant: "jean.tremblay",
                                            prenom: "Jean",
                                            nom: "Tremblay")
        #expect(erreur == nil)
    }

    @Test("Ignore les noms de moins de 3 caractères")
    func mdpIgnoreNomCourt() {
        // Prénom "Al" fait 2 chars → ignoré pour la vérif contextuelle,
        // mais "al" ferait trop de faux positifs si pris en compte
        let erreur = PasswordPolicy.valider("PassSuperSolide!",
                                            identifiant: "al.bernard",
                                            prenom: "Al",
                                            nom: "Bernard")
        // "bernard" est présent dans "PassSuperSolide!" ? Non — accepte
        #expect(erreur == nil)
    }
}
