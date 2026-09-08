//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Tests E′ — mécaniques de la sync corrigée (docs/Architecture_SyncEPrime.md) :
//  nommage par écrivain, chaîne de confiance par créateur, filigranes anti-écho,
//  tombstones, bornes de domaine, statut de disponibilité générique.
//

import Testing
import Foundation
@testable import Playco

@Suite("E′ — records par écrivain & confiance")
@MainActor
struct SyncEPrimeConfianceTests {

    @Test("nomRecord suffixe l'écrivain — deux coachs n'écrivent jamais le même record")
    func nomRecordParEcrivain() {
        let id = "ABC-123"
        let coachA = CloudKitSharingService.nomRecord("exercice", id: id, ecrivain: "AAA")
        let coachB = CloudKitSharingService.nomRecord("exercice", id: id, ecrivain: "BBB")
        #expect(coachA == "exercice-ABC-123-wAAA")
        #expect(coachA != coachB, "ACL Public DB : l'écriture d'un record existant est réservée à son créateur")
    }

    @Test("construireConfiance : racine + assistants revendiquant un couple émis par la racine")
    func confianceRacineEtAssistants() {
        let confiance = CloudKitSharingService.construireConfiance(
            racine: "CK-ROOT",
            lignes: [
                // Lignes créées par la racine (le head coach a émis ces invitations).
                (createur: "CK-ROOT", utilisateurID: "U1", codeInvitation: "INV1"),
                (createur: "CK-ROOT", utilisateurID: "U2", codeInvitation: "INV2"),
                // Copie de l'assistant U1 : couple valide → écrivain de confiance.
                (createur: "CK-ASSIST", utilisateurID: "U1", codeInvitation: "INV1"),
                // Attaquant : revendique un utilisateurID connu mais un code faux.
                (createur: "CK-ATTAQUANT", utilisateurID: "U2", codeInvitation: "FAUX"),
                // Attaquant : couple entièrement inventé.
                (createur: "CK-ATTAQUANT2", utilisateurID: "UX", codeInvitation: "INVX"),
            ])
        #expect(confiance.accepte(createur: "CK-ROOT"))
        #expect(confiance.accepte(createur: "CK-ASSIST"))
        #expect(!confiance.accepte(createur: "CK-ATTAQUANT"),
                "Un couple (utilisateurID, codeInvitation) non émis par la racine ne donne aucune confiance")
        #expect(!confiance.accepte(createur: "CK-ATTAQUANT2"))
        #expect(!confiance.accepte(createur: nil))
        // Mes propres records (placeholder CloudKit) : toujours acceptés.
        #expect(confiance.accepte(createur: "__defaultOwner__"))
    }

    @Test("construireConfiance sans racine (équipe introuvable) : tout est rejeté sauf le local")
    func confianceSansRacine() {
        let confiance = CloudKitSharingService.construireConfiance(
            racine: nil,
            lignes: [(createur: "CK-X", utilisateurID: "U1", codeInvitation: "INV1")])
        #expect(!confiance.accepte(createur: "CK-X"))
        #expect(confiance.accepte(createur: "__defaultOwner__"))
    }

    @Test("confiance TRANSITIVE (D6) : un assistant ajouté par un assistant déjà de confiance est accepté")
    func confianceTransitive() {
        // Racine émet le couple de B ; B (créateur de la ligne de C) émet le
        // couple de C ; C revendique son couple → tous de confiance.
        let confiance = CloudKitSharingService.construireConfiance(
            racine: "CK-ROOT",
            lignes: [
                (createur: "CK-ROOT",  utilisateurID: "B", codeInvitation: "INVB"),
                (createur: "CK-B",     utilisateurID: "B", codeInvitation: "INVB"), // B rejoint
                (createur: "CK-B",     utilisateurID: "C", codeInvitation: "INVC"), // B ajoute C
                (createur: "CK-C",     utilisateurID: "C", codeInvitation: "INVC"), // C rejoint
                (createur: "CK-EVIL",  utilisateurID: "Z", codeInvitation: "INVZ"), // inconnu
            ])
        #expect(confiance.accepte(createur: "CK-ROOT"))
        #expect(confiance.accepte(createur: "CK-B"))
        #expect(confiance.accepte(createur: "CK-C"), "Chaîne racine→B→C")
        #expect(!confiance.accepte(createur: "CK-EVIL"))
    }

    @Test("une invitation vide n'inscrit personne dans la chaîne de confiance")
    func invitationVideRejetee() {
        let confiance = CloudKitSharingService.construireConfiance(
            racine: "CK-ROOT",
            lignes: [
                (createur: "CK-ROOT", utilisateurID: "U1", codeInvitation: ""),
                (createur: "CK-TIERS", utilisateurID: "U1", codeInvitation: ""),
            ])
        #expect(!confiance.accepte(createur: "CK-TIERS"),
                "Un couple au code vide serait trivial à forger")
    }
}

@Suite("E′ — filigranes anti-écho & tombstones")
@MainActor
struct SyncEPrimeEtatTests {

    @Test("doitPublier : jamais ce qu'on vient d'importer (anti-écho), toujours ses propres éditions")
    func filigraneAntiEcho() {
        let seuil = Date(timeIntervalSince1970: 1_000)
        let importee = Date(timeIntervalSince1970: 2_000)

        // Version locale == version importée → écho interdit.
        #expect(!EtatSyncEquipe.doitPublier(dateModification: importee, seuil: seuil, filigrane: importee))
        // Édition locale POSTÉRIEURE à l'import → publiée.
        let editee = Date(timeIntervalSince1970: 3_000)
        #expect(EtatSyncEquipe.doitPublier(dateModification: editee, seuil: seuil, filigrane: importee))
        // Rien de neuf depuis le seuil → rien.
        #expect(!EtatSyncEquipe.doitPublier(dateModification: Date(timeIntervalSince1970: 500),
                                            seuil: seuil, filigrane: nil))
        // Jamais importée + modifiée depuis le seuil → publiée.
        #expect(EtatSyncEquipe.doitPublier(dateModification: importee, seuil: seuil, filigrane: nil))
    }

    @Test("tombstoneGagne : une suppression au moins aussi récente que l'édition locale l'emporte")
    func tombstoneLww() {
        let edition = Date(timeIntervalSince1970: 2_000)
        #expect(EtatSyncEquipe.tombstoneGagne(horodatageTombstone: Date(timeIntervalSince1970: 2_000),
                                              dateModificationLocale: edition))
        #expect(EtatSyncEquipe.tombstoneGagne(horodatageTombstone: Date(timeIntervalSince1970: 3_000),
                                              dateModificationLocale: edition))
        #expect(!EtatSyncEquipe.tombstoneGagne(horodatageTombstone: Date(timeIntervalSince1970: 1_000),
                                               dateModificationLocale: edition),
                "Une re-création POSTÉRIEURE au tombstone gagne")
    }

    @Test("EtatSyncEquipe : filigranes et tombstones persistent et se répondent")
    func etatPersistant() {
        let etat = EtatSyncEquipe()
        let code = "TEST-\(UUID().uuidString.prefix(8))"
        let entite = UUID()
        let date = Date(timeIntervalSince1970: 5_000)

        etat.poserFiligrane(code, entiteID: entite, date: date)
        #expect(!etat.doitPublier(code, entiteID: entite, dateModification: date, seuil: .distantPast))

        // Le tombstone efface le filigrane et marque l'entité supprimée.
        etat.enregistrerTombstone(code, entiteID: entite, horodatage: Date(timeIntervalSince1970: 6_000))
        #expect(etat.estSupprimee(code, entiteID: entite, dateModification: date))
        // Une re-création postérieure au tombstone n'est PAS supprimée.
        #expect(!etat.estSupprimee(code, entiteID: entite,
                                   dateModification: Date(timeIntervalSince1970: 7_000)))
        // Un tombstone plus VIEUX n'écrase pas le plus récent.
        etat.enregistrerTombstone(code, entiteID: entite, horodatage: Date(timeIntervalSince1970: 100))
        #expect(etat.estSupprimee(code, entiteID: entite,
                                  dateModification: Date(timeIntervalSince1970: 5_500)))
    }
}

@Suite("E′ — bornes de domaine & disponibilité générique")
struct SyncEPrimeDomaineTests {

    @Test("borner clamp les entiers importés au domaine attendu")
    func bornesEntiers() {
        #expect(CloudKitSharingService.borner(3, 1...5) == 3)
        #expect(CloudKitSharingService.borner(-4, 0...99) == 0)
        #expect(CloudKitSharingService.borner(1_000_000, 1...6) == 6)
    }

    @Test("StatutDisponibilite.indisponible : jamais proposé au coach, rawValue stable")
    func statutGenerique() {
        #expect(!StatutDisponibilite.casSelectionnables.contains(.indisponible),
                "Le statut générique est posé par l'import E′, pas choisi à la main")
        #expect(StatutDisponibilite.casSelectionnables.contains(.blesse))
        #expect(StatutDisponibilite(rawValue: "Indisponible") == .indisponible,
                "rawValue = contrat de persistance")
        let joueur = JoueurEquipe(nom: "T", prenom: "T", numero: 1, poste: .passeur)
        joueur.statutDisponibilite = .indisponible
        #expect(!joueur.estDisponible)
    }
}
