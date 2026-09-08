//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Tests 2.2.b : consentement mineurs (estMineur) et statut de disponibilité
//  et statut de disponibilité des joueurs.
//

import Testing
import Foundation
@testable import Playco

@Suite("Consentement mineurs & disponibilité (2.2.b)")
@MainActor
struct ConsentementDisponibiliteTests {

    private func joueur(anneesAge: Int? = nil) -> JoueurEquipe {
        let j = JoueurEquipe(nom: "Test", prenom: "Joueur", numero: 7, poste: .recepteur)
        if let anneesAge {
            j.dateNaissance = Calendar.current.date(byAdding: .year, value: -anneesAge, to: Date())
        }
        return j
    }

    // MARK: - estMineur

    @Test("un joueur de 15 ans est mineur, un joueur de 19 ans ne l'est pas")
    func estMineurSelonAge() {
        #expect(joueur(anneesAge: 15).estMineur)
        #expect(!joueur(anneesAge: 19).estMineur)
    }

    @Test("sans date de naissance, le joueur n'est pas traité comme mineur (pas de faux positif)")
    func estMineurSansDate() {
        #expect(!joueur().estMineur)
    }

    // MARK: - Statut de disponibilité

    @Test("le statut par défaut est disponible (raw vide — CloudKit-safe)")
    func statutParDefaut() {
        let j = joueur()
        #expect(j.statutDisponibiliteRaw.isEmpty)
        #expect(j.statutDisponibilite == .disponible)
        #expect(j.estDisponible)
    }

    @Test("poser un statut le persiste en raw, revenir à disponible vide le raw")
    func statutAllerRetour() {
        let j = joueur()

        j.statutDisponibilite = .blesse
        #expect(j.statutDisponibiliteRaw == "blesse")
        #expect(!j.estDisponible)

        j.statutDisponibilite = .disponible
        #expect(j.statutDisponibiliteRaw.isEmpty) // "" = défaut CloudKit-safe
        #expect(j.estDisponible)
    }

    @Test("un raw inconnu (donnée future/corrompue) retombe sur disponible")
    func statutRawInconnu() {
        let j = joueur()
        j.statutDisponibiliteRaw = "en_vacances"
        #expect(j.statutDisponibilite == .disponible)
    }
}
