//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  Tests du modèle ScoutingReport (Phase 6 refonte scouting) :
//  - round-trip des tendances zonales (encode/decode JSONCoderCache) ;
//  - persistance du lien au match (seanceID) ;
//  - duplication d'un rapport (contenu copié, identité et lien réinitialisés).
//

import Testing
import Foundation
import SwiftData
@testable import Playco

@Suite("ScoutingReport — tendances zonales, lien match et duplication")
@MainActor
struct ScoutingReportTests {

    private static let codeEquipe = "EQ_SCOUT"
    /// Décalage « hier » pour vérifier le rafraîchissement des dates à la duplication.
    private static let unJour: TimeInterval = 86_400

    /// ScoutingReport n'a aucune relation SwiftData : le schéma réduit à ce
    /// seul modèle est sa propre fermeture transitive.
    private func creerContexte() throws -> ModelContext {
        let schema = Schema([ScoutingReport.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true,
                                        allowsSave: true, groupContainer: .none,
                                        cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    // MARK: - Tendances zonales

    @Test("tendancesZonales — round-trip encode/decode et persistance")
    func tendancesZonalesRoundTrip() throws {
        let contexte = try creerContexte()

        let rapport = ScoutingReport()
        rapport.codeEquipe = Self.codeEquipe
        var tendances = TendancesZonales()
        tendances.service = [1: 3, 5: 2, 6: 1]
        tendances.attaque = [4: 3, 2: 1]
        rapport.tendancesZonales = tendances
        contexte.insert(rapport)
        try contexte.save()

        let releves = try contexte.fetch(FetchDescriptor<ScoutingReport>())
        #expect(releves.count == 1)
        let relu = try #require(releves.first)
        #expect(relu.tendancesZonales == tendances)
        #expect(relu.tendancesZonales.service[1] == 3)
        #expect(relu.tendancesZonales.attaque[4] == 3)
    }

    @Test("tendancesZonales — Data() par défaut décode en tendances vides")
    func tendancesZonalesDefautVide() throws {
        let rapport = ScoutingReport()

        #expect(rapport.tendancesZonalesData == Data())
        #expect(rapport.tendancesZonales == TendancesZonales())
        #expect(rapport.tendancesZonales.service.isEmpty)
        #expect(rapport.tendancesZonales.attaque.isEmpty)
    }

    @Test("niveauSuivant — cycle 0 → 1 → 2 → 3 → 0")
    func niveauSuivantCycle() {
        #expect(TendancesZonales.niveauSuivant(0) == 1)
        #expect(TendancesZonales.niveauSuivant(1) == 2)
        #expect(TendancesZonales.niveauSuivant(2) == 3)
        #expect(TendancesZonales.niveauSuivant(3) == 0)
        // Valeur hors bornes (donnée corrompue) : retombe au minimum.
        #expect(TendancesZonales.niveauSuivant(9) == 0)
    }

    // MARK: - Lien au match

    @Test("seanceID — persisté et relu tel quel")
    func seanceIDPersiste() throws {
        let contexte = try creerContexte()
        let idMatch = UUID()

        let rapport = ScoutingReport()
        rapport.codeEquipe = Self.codeEquipe
        rapport.seanceID = idMatch
        contexte.insert(rapport)
        try contexte.save()

        let relu = try #require(try contexte.fetch(FetchDescriptor<ScoutingReport>()).first)
        #expect(relu.seanceID == idMatch)
    }

    @Test("seanceID — nil par défaut (rapport non lié)")
    func seanceIDNilParDefaut() {
        #expect(ScoutingReport().seanceID == nil)
    }

    // MARK: - Duplication

    private func creerRapportComplet() -> ScoutingReport {
        let source = ScoutingReport()
        source.adversaire = "Les Élans"
        source.codeEquipe = Self.codeEquipe
        source.systemJeu = "5-1"
        source.styleJeu = "Offensif"
        source.notes = "Notes générales"
        source.adversaireObserve = "Élans vs Titans"
        source.seanceID = UUID()
        source.dateMatch = Date(timeIntervalSinceNow: -Self.unJour)
        source.dateCreation = Date(timeIntervalSinceNow: -Self.unJour)
        source.joueurs = [JoueurAdverse(numero: 7, nom: "Tremblay", poste: "Attaquant",
                                        pointsForts: "Diagonale", pointsFaibles: "Bloc", menaceNiveau: 4)]
        source.forces = ["Service flottant"]
        source.faiblesses = ["Réception zone 6"]
        source.strategies = [StrategieRecommandee(titre: "Servir zone 6", description: "Cibler le libéro",
                                                  priorite: 1, categorie: "Service")]
        var tendances = TendancesZonales()
        tendances.service = [1: 2]
        tendances.attaque = [4: 3]
        source.tendancesZonales = tendances
        return source
    }

    @Test("dupliquer — copie le contenu d'analyse (joueurs, stratégies, tendances)")
    func dupliquerCopieContenu() {
        let source = creerRapportComplet()

        let copie = ScoutingReport.dupliquer(source)

        #expect(copie.adversaire == source.adversaire)
        #expect(copie.codeEquipe == source.codeEquipe)
        #expect(copie.systemJeu == source.systemJeu)
        #expect(copie.styleJeu == source.styleJeu)
        #expect(copie.notes == source.notes)
        #expect(copie.adversaireObserve == source.adversaireObserve)
        #expect(copie.joueursData == source.joueursData)
        #expect(copie.forcesData == source.forcesData)
        #expect(copie.faiblessesData == source.faiblessesData)
        #expect(copie.strategiesData == source.strategiesData)
        #expect(copie.tendanceService == source.tendanceService)
        #expect(copie.tendanceAttaque == source.tendanceAttaque)
        #expect(copie.tendanceReception == source.tendanceReception)
        #expect(copie.tendanceBloc == source.tendanceBloc)
        #expect(copie.tendancesZonales == source.tendancesZonales)
    }

    @Test("dupliquer — nouvelle identité : id différent, dates du jour, seanceID nil")
    func dupliquerReinitialiseIdentite() {
        let source = creerRapportComplet()

        let copie = ScoutingReport.dupliquer(source)

        #expect(copie.id != source.id)
        #expect(copie.seanceID == nil)
        #expect(copie.dateCreation > source.dateCreation)
        #expect(copie.dateMatch > source.dateMatch)
        #expect(copie.estArchive == false)
        // L'original n'est pas muté.
        #expect(source.seanceID != nil)
    }

    @Test("dupliquer — la copie est persistable indépendamment de la source")
    func dupliquerPersistable() throws {
        let contexte = try creerContexte()
        let source = creerRapportComplet()
        contexte.insert(source)

        let copie = ScoutingReport.dupliquer(source)
        contexte.insert(copie)
        try contexte.save()

        let releves = try contexte.fetch(FetchDescriptor<ScoutingReport>())
        #expect(releves.count == 2)
        let ids = Set(releves.map(\.id))
        #expect(ids.count == 2)
    }
}
