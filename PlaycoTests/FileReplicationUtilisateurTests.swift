//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Testing
import Foundation
@testable import Playco

@Suite("FileReplicationUtilisateur", .serialized)
struct FileReplicationUtilisateurTests {

    /// Reset l'actor partagé entre les tests (UserDefaults global).
    private func reset() async {
        await FileReplicationUtilisateur.shared.reinitialiserPourTests()
    }

    @Test("enregistrer est idempotent sur utilisateurID")
    func enregistrerIdempotent() async {
        await reset()
        let id = UUID()

        await FileReplicationUtilisateur.shared.enregistrer(id)
        await FileReplicationUtilisateur.shared.enregistrer(id)
        await FileReplicationUtilisateur.shared.enregistrer(id)

        let taille = await FileReplicationUtilisateur.shared.taille()
        #expect(taille == 1, "Appels répétés avec le même ID ne doivent créer qu'une seule entrée")
    }

    @Test("marquerPublie retire l'entrée")
    func marquerPublieRetire() async {
        await reset()
        let id1 = UUID()
        let id2 = UUID()

        await FileReplicationUtilisateur.shared.enregistrer(id1)
        await FileReplicationUtilisateur.shared.enregistrer(id2)

        await FileReplicationUtilisateur.shared.marquerPublie(id1)

        let taille = await FileReplicationUtilisateur.shared.taille()
        #expect(taille == 1, "Doit rester 1 entrée après marquerPublie d'un seul ID")

        let prets = await FileReplicationUtilisateur.shared.listerPrets()
        #expect(prets == [id2], "Seul id2 doit rester dans la file")
    }

    @Test("planifierRetry incrémente tentatives et applique le backoff")
    func planifierRetryBackoff() async {
        await reset()
        let id = UUID()

        await FileReplicationUtilisateur.shared.enregistrer(id)
        // Tentative 1 → délai 30s ; prochainEssai dans le futur
        await FileReplicationUtilisateur.shared.planifierRetry(id)

        // Juste après planifierRetry, prochainEssai > now → ID non prêt
        let pretsMaintenant = await FileReplicationUtilisateur.shared.listerPrets(maintenant: Date())
        #expect(pretsMaintenant.isEmpty, "Après planifierRetry tentative 1, ID ne doit pas être prêt avant 30s")

        // En simulant une date future (+ 31s), ID doit être prêt
        let futur = Date().addingTimeInterval(31)
        let pretsFutur = await FileReplicationUtilisateur.shared.listerPrets(maintenant: futur)
        #expect(pretsFutur == [id], "ID doit être prêt après 31s (délai tentative 1 = 30s)")
    }

    @Test("PolitiqueRetry délai exponentiel plafonné")
    func politiqueRetryDelais() {
        #expect(PolitiqueRetry.delaiApresTentative(1) == 30)
        #expect(PolitiqueRetry.delaiApresTentative(2) == 120)
        #expect(PolitiqueRetry.delaiApresTentative(3) == 600)
        #expect(PolitiqueRetry.delaiApresTentative(4) == 3600)
        #expect(PolitiqueRetry.delaiApresTentative(100) == 3600, "Cap au dernier délai")
        #expect(PolitiqueRetry.delaiApresTentative(0) == 30, "Tentative 0 clampée à l'index 0")
    }

    @Test("listerPrets limite à la taille du batch")
    func batchLimit() async {
        await reset()
        // Enregistrer 30 utilisateurs (tous prêts immédiatement, tentatives=0, prochainEssai=now)
        for _ in 0..<30 {
            await FileReplicationUtilisateur.shared.enregistrer(UUID())
        }

        let taille = await FileReplicationUtilisateur.shared.taille()
        #expect(taille == 30, "30 entrées enregistrées")

        let prets = await FileReplicationUtilisateur.shared.listerPrets()
        #expect(prets.count == 20, "listerPrets limite à tailleBatchRejeu=20")
    }

    @Test("planifierRetry sur ID absent est no-op (idempotent)")
    func planifierRetryIDAbsent() async {
        await reset()
        let idInexistant = UUID()
        // Ne doit pas crasher ni créer une entrée fantôme
        await FileReplicationUtilisateur.shared.planifierRetry(idInexistant)
        let taille = await FileReplicationUtilisateur.shared.taille()
        #expect(taille == 0, "Aucune entrée ne doit être créée par un retry sur ID inconnu")
    }

    @Test("marquerPublie sur ID absent est no-op")
    func marquerPublieIDAbsent() async {
        await reset()
        let id = UUID()
        await FileReplicationUtilisateur.shared.enregistrer(id)

        // Marquer un autre ID publié ne doit pas affecter l'entrée existante
        await FileReplicationUtilisateur.shared.marquerPublie(UUID())
        let taille = await FileReplicationUtilisateur.shared.taille()
        #expect(taille == 1, "L'entrée originale doit rester intacte")
    }

    @Test("Abandon après tentativesMax retries infructueux")
    func abandonApresTentativesMax() async {
        await reset()
        let id = UUID()
        await FileReplicationUtilisateur.shared.enregistrer(id)

        // Déclencher tentativesMax retries — à la dernière, l'entrée est abandonnée
        for _ in 0..<PolitiqueRetry.tentativesMax {
            await FileReplicationUtilisateur.shared.planifierRetry(id)
        }
        // Encore présent après `tentativesMax` retries (tentatives == tentativesMax)
        var taille = await FileReplicationUtilisateur.shared.taille()
        #expect(taille == 1, "Entrée toujours présente à la limite")

        // Un retry de plus → abandon
        await FileReplicationUtilisateur.shared.planifierRetry(id)
        taille = await FileReplicationUtilisateur.shared.taille()
        #expect(taille == 0, "Entrée retirée après dépassement tentativesMax")
    }
}
