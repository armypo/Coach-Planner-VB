//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//
//  CloudKitSharingService+Import — Récupération et import des données d'équipe
//  depuis la CloudKit Public Database (côté athlète/assistant).

import Foundation
import CloudKit
import SwiftData
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "CloudKitSharing")

extension CloudKitSharingService {

    // MARK: - Récupération (côté Athlète)

    /// Vérifie si un code d'équipe existe dans le CloudKit public.
    /// - Throws: `SharingError.reseauIndisponible` si la vérification n'a pas pu
    ///   aboutir (hors-ligne, quota…) — à distinguer d'un code réellement inconnu,
    ///   sinon l'utilisateur hors-ligne voit « code invalide » à tort.
    func equipeExiste(codeEquipe: String) async throws -> Bool {
        let predicate = NSPredicate(format: "codeEquipe == %@", codeEquipe)
        let query = CKQuery(recordType: RecordType.equipe, predicate: predicate)

        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)
            return !results.isEmpty
        } catch {
            logger.error("Erreur vérification équipe: \(error.localizedDescription)")
            throw SharingError.reseauIndisponible
        }
    }

    /// Nom PUBLIC de l'équipe (lecture seule, sanitisé) — affiché à l'athlète
    /// AVANT le rattachement de son Apple ID (revue 2.3 : anti-phishing QR).
    func nomEquipePublique(codeEquipe: String) async throws -> String? {
        let predicate = NSPredicate(format: "codeEquipe == %@", codeEquipe)
        let query = CKQuery(recordType: RecordType.equipe, predicate: predicate)
        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)
            guard let record = try results.first?.1.get() else { return nil }
            return record.chaineSecurisee("nom")
        } catch {
            logger.error("Erreur lecture nom équipe: \(error.localizedDescription)")
            throw SharingError.reseauIndisponible
        }
    }

    /// Récupère et importe toutes les données d'une équipe dans le SwiftData local
    func recupererEtImporterEquipe(codeEquipe: String, context: ModelContext) async throws {
        estEnCoursDeRecuperation = true
        erreur = nil

        defer { estEnCoursDeRecuperation = false }

        // 1. Récupérer l'équipe
        let equipeRecords = try await fetchRecords(type: RecordType.equipe, codeEquipe: codeEquipe)
        guard let equipeRecord = equipeRecords.first else {
            throw SharingError.equipeNonTrouvee
        }

        // Vérifier si l'équipe existe déjà en local
        let codeRecherche = codeEquipe
        let descripteurEquipe = FetchDescriptor<Equipe>(
            predicate: #Predicate { $0.codeEquipe == codeRecherche }
        )
        let equipesLocales = (try? context.fetch(descripteurEquipe)) ?? []

        if equipesLocales.isEmpty {
            // 2. Récupérer l'établissement
            let etabRecords = try await fetchRecords(type: RecordType.etablissement, codeEquipe: codeEquipe)

            // 3. Créer l'établissement local
            var etablissementLocal: Etablissement?
            if let etabRecord = etabRecords.first {
                etablissementLocal = importerEtablissement(from: etabRecord, context: context)
            }

            // 4. Créer l'équipe locale
            importerEquipe(from: equipeRecord, etablissement: etablissementLocal, context: context)

            // 5. Créer un ProfilCoach minimal (pour que configurationCompletee = true)
            let profilDescriptor = FetchDescriptor<ProfilCoach>(
                predicate: #Predicate { $0.configurationCompletee == true }
            )
            let profilsExistants = (try? context.fetch(profilDescriptor)) ?? []
            if profilsExistants.isEmpty {
                let profil = ProfilCoach()
                profil.configurationCompletee = true
                context.insert(profil)
            }
        }

        // 6. Importer les Utilisateur de mapping d'équipe (SANS secret — cf.
        // `champsPublicsUtilisateur`). Requis pour la jointure SIWA : `reclamerMembreLocal`
        // retrouve la ligne de roster par code d'invitation puis y rattache l'appleUserID.
        let utilisateurRecords = try await fetchRecords(type: RecordType.utilisateur, codeEquipe: codeEquipe)
        for record in utilisateurRecords {
            importerUtilisateur(from: record, context: context)
        }

        // 7. Récupérer et importer les joueurs
        let joueurRecords = try await fetchRecords(type: RecordType.joueur, codeEquipe: codeEquipe)
        for record in joueurRecords {
            importerJoueur(from: record, context: context)
        }

        // 7b. Importer les séances (incl. matchs type=.match — lecture seule athlète).
        let seanceRecords = try await fetchRecords(type: RecordType.seance, codeEquipe: codeEquipe)
        for record in seanceRecords { importerSeance(from: record, context: context) }

        // 8. Tier d'équipe INFORMATIONNEL depuis AbonnementPartage (Public DB).
        // SÉCURITÉ : cette valeur (non signée) ne sert QU'À l'affichage — elle
        // n'accorde aucun accès et ne bloque aucune connexion (cf. appliquerGateTier
        // role-aware, et paywallDoitBloquer côté coach uniquement).
        if let snap = await CloudKitPublicSyncAbonnement.shared.lireStatut(codeEquipe: codeEquipe),
           let tier = Tier(rawValue: snap.tierRaw) {
            let codeRech = codeEquipe
            let descEq = FetchDescriptor<Equipe>(predicate: #Predicate { $0.codeEquipe == codeRech })
            if let eqLocale = try? context.fetch(descEq).first, eqLocale.tierAbonnement != tier {
                eqLocale.tierAbonnement = tier
                logger.info("Tier équipe (informationnel) pour \(codeEquipe, privacy: .private): \(tier.rawValue, privacy: .public)")
            }
        }

        do {
            try context.save()
        } catch {
            logger.error("importerEquipeDepuisPublic: échec sauvegarde SwiftData: \(error.localizedDescription)")
            throw SharingError.sauvegardeEchouee
        }

        logger.info("Équipe \(codeEquipe, privacy: .private) importée: \(joueurRecords.count) joueurs (comptes non répliqués)")
    }


    // MARK: - Sync incrémentale

    /// Synchronise les nouvelles données depuis le public DB (appel périodique)
    func syncDepuisPublic(codeEquipe: String, context: ModelContext) async {
        do {
            // SÉCURITÉ : pas d'import de comptes Utilisateur (credentials). On ne
            // rafraîchit que les données non sensibles (roster, séances, calendrier).
            let joueurRecords = try await fetchRecords(type: RecordType.joueur, codeEquipe: codeEquipe)
            for record in joueurRecords {
                importerJoueur(from: record, context: context)
            }

            let seanceRecords = try await fetchRecords(type: RecordType.seance, codeEquipe: codeEquipe)
            for record in seanceRecords { importerSeance(from: record, context: context) }

            do {
                try context.save()
                logger.info("Sync incrémentale terminée pour \(codeEquipe, privacy: .private)")
            } catch {
                logger.error("syncDepuisPublic: échec sauvegarde SwiftData: \(error.localizedDescription)")
                // Ne pas relancer — la sync échouée sera retentée au prochain cycle
            }
        } catch {
            logger.error("Erreur sync incrémentale: \(error.localizedDescription)")
        }
    }



    // MARK: - Import vers SwiftData

    func importerEquipe(from record: CKRecord, etablissement: Etablissement?, context: ModelContext) {
        let equipe = Equipe(nom: record.chaineSecurisee("nom") ?? "")
        equipe.codeEquipe = record.chaineSecurisee("codeEquipe") ?? ""
        equipe.categorieRaw = record.chaineSecurisee("categorieRaw") ?? ""
        equipe.divisionRaw = record.chaineSecurisee("divisionRaw") ?? ""
        equipe.saison = record.chaineSecurisee("saison") ?? ""
        equipe.couleurPrincipalHex = record.chaineSecurisee("couleurPrincipalHex") ?? "#E8734A"
        equipe.couleurSecondaireHex = record.chaineSecurisee("couleurSecondaireHex") ?? "#4A8AF4"
        equipe.etablissement = etablissement
        context.insert(equipe)
    }

    func importerEtablissement(from record: CKRecord, context: ModelContext) -> Etablissement {
        let etab = Etablissement(
            nom: record.chaineSecurisee("nom") ?? "",
            type: TypeEtablissement(rawValue: record.chaineSecurisee("typeRaw") ?? "") ?? .universite,
            ville: record.chaineSecurisee("ville") ?? "",
            province: record.chaineSecurisee("province") ?? ""
        )
        context.insert(etab)
        return etab
    }

    func importerUtilisateur(from record: CKRecord, context: ModelContext) {
        guard let idString = record.chaineSecurisee("utilisateurID"),
              let uuid = UUID(uuidString: idString) else { return }

        // Vérifier si cet utilisateur existe déjà
        let descripteur = FetchDescriptor<Utilisateur>(
            predicate: #Predicate { $0.id == uuid }
        )
        if let existant = try? context.fetch(descripteur).first {
            // Comparer dateModification — ne mettre à jour que si le remote est plus récent
            let remoteDateMod = record["dateModification"] as? Date ?? .distantPast
            guard remoteDateMod > existant.dateModification else { return }

            // Mettre à jour les champs mutables
            existant.estActif = (record["estActif"] as? Int ?? 1) == 1
            existant.dateModification = remoteDateMod
            // SÉCURITÉ : plus aucun secret (hash/sel/iterations) en base publique.
            // L'auth passe par Sign in with Apple ; ces champs ne transitent plus.
            // Mapping SIWA : ne JAMAIS écraser ces champs sur une ligne DÉJÀ réclamée
            // (appleUserID non vide) — sinon un record public pourrait corrompre
            // l'identité/le code d'un membre déjà rattaché.
            if existant.appleUserID.isEmpty {
                if let appleID = record.chaineSecurisee("appleUserID") {
                    existant.appleUserID = appleID
                }
                if let invite = record.chaineSecurisee("codeInvitation"), !invite.isEmpty {
                    existant.codeInvitation = invite
                }
            }
            if let code = record.chaineSecurisee("codeEquipe"), !code.isEmpty {
                existant.codeEquipe = code
            }
            if let prenom = record.chaineSecurisee("prenom") {
                existant.prenom = prenom
            }
            if let nom = record.chaineSecurisee("nom") {
                existant.nom = nom
            }
            if let numero = record["numero"] as? Int {
                existant.numero = numero
            }
            if let posteRaw = record.chaineSecurisee("posteRaw") {
                existant.posteRaw = posteRaw
            }
            return
        }

        // Créer le nouvel utilisateur de mapping d'équipe. SÉCURITÉ : aucun secret
        // n'est importé depuis la base publique — l'authentification est déléguée à
        // Sign in with Apple (motDePasseHash reste vide ; le rattachement se fait
        // via appleUserID lors du flux « Rejoindre une équipe »).
        let utilisateur = Utilisateur(
            identifiant: record.chaineSecurisee("identifiant") ?? "",
            motDePasseHash: "",
            prenom: record.chaineSecurisee("prenom") ?? "",
            nom: record.chaineSecurisee("nom") ?? "",
            role: RoleUtilisateur(rawValue: record.chaineSecurisee("roleRaw") ?? "Étudiant") ?? .etudiant,
            codeEcole: record.chaineSecurisee("codeEcole") ?? ""
        )
        // Forcer le même UUID que la source
        utilisateur.id = uuid
        utilisateur.estActif = (record["estActif"] as? Int ?? 1) == 1
        // Mapping SIWA / jointure d'équipe (jeton non secret).
        utilisateur.appleUserID = record.chaineSecurisee("appleUserID") ?? ""
        utilisateur.codeEquipe = record.chaineSecurisee("codeEquipe") ?? ""
        utilisateur.codeInvitation = record.chaineSecurisee("codeInvitation") ?? ""

        if let joueurIDStr = record.chaineSecurisee("joueurEquipeID") {
            utilisateur.joueurEquipeID = UUID(uuidString: joueurIDStr)
        }
        if let numero = record["numero"] as? Int {
            utilisateur.numero = numero
        }
        if let posteRaw = record.chaineSecurisee("posteRaw") {
            utilisateur.posteRaw = posteRaw
        }

        context.insert(utilisateur)
    }

    func importerJoueur(from record: CKRecord, context: ModelContext) {
        guard let idString = record.chaineSecurisee("joueurID"),
              let uuid = UUID(uuidString: idString) else { return }

        // Vérifier si ce joueur existe déjà
        let descripteur = FetchDescriptor<JoueurEquipe>(
            predicate: #Predicate { $0.id == uuid }
        )
        if let existant = try? context.fetch(descripteur).first {
            // Comparer dateModification — ne mettre à jour que si le remote est plus récent
            let remoteDateMod = record["dateModification"] as? Date ?? .distantPast
            guard remoteDateMod > existant.dateModification else { return }
            existant.nom = record.chaineSecurisee("nom") ?? existant.nom
            existant.prenom = record.chaineSecurisee("prenom") ?? existant.prenom
            existant.numero = record["numero"] as? Int ?? existant.numero
            existant.posteRaw = record.chaineSecurisee("posteRaw") ?? existant.posteRaw
            appliquerStats(record, sur: existant)
            existant.dateModification = remoteDateMod
            return
        }

        let joueur = JoueurEquipe(
            nom: record.chaineSecurisee("nom") ?? "",
            prenom: record.chaineSecurisee("prenom") ?? "",
            numero: record["numero"] as? Int ?? 0,
            poste: PosteJoueur(rawValue: record.chaineSecurisee("posteRaw") ?? "") ?? .recepteur
        )
        joueur.id = uuid
        joueur.codeEquipe = record.chaineSecurisee("codeEquipe") ?? ""
        joueur.identifiant = record.chaineSecurisee("identifiant") ?? ""

        if let utilisateurIDStr = record.chaineSecurisee("utilisateurID") {
            joueur.utilisateurID = UUID(uuidString: utilisateurIDStr)
        }
        appliquerStats(record, sur: joueur)

        context.insert(joueur)
    }
    /// DRY — partagé par les branches update + création de `importerJoueur`.
    private func appliquerStats(_ record: CKRecord, sur joueur: JoueurEquipe) {
        joueur.matchsJoues = record["matchsJoues"] as? Int ?? joueur.matchsJoues
        joueur.setsJoues = record["setsJoues"] as? Int ?? joueur.setsJoues
        joueur.attaquesReussies = record["attaquesReussies"] as? Int ?? joueur.attaquesReussies
        joueur.erreursAttaque = record["erreursAttaque"] as? Int ?? joueur.erreursAttaque
        joueur.attaquesTotales = record["attaquesTotales"] as? Int ?? joueur.attaquesTotales
        joueur.aces = record["aces"] as? Int ?? joueur.aces
        joueur.erreursService = record["erreursService"] as? Int ?? joueur.erreursService
        joueur.servicesTotaux = record["servicesTotaux"] as? Int ?? joueur.servicesTotaux
        joueur.blocsSeuls = record["blocsSeuls"] as? Int ?? joueur.blocsSeuls
        joueur.blocsAssistes = record["blocsAssistes"] as? Int ?? joueur.blocsAssistes
        joueur.erreursBloc = record["erreursBloc"] as? Int ?? joueur.erreursBloc
        joueur.receptionsReussies = record["receptionsReussies"] as? Int ?? joueur.receptionsReussies
        joueur.erreursReception = record["erreursReception"] as? Int ?? joueur.erreursReception
        joueur.receptionsTotales = record["receptionsTotales"] as? Int ?? joueur.receptionsTotales
        joueur.passesDecisives = record["passesDecisives"] as? Int ?? joueur.passesDecisives
        joueur.manchettes = record["manchettes"] as? Int ?? joueur.manchettes
    }

    /// Importe une séance (merge `dateModification`). Lecture seule athlète.
    func importerSeance(from record: CKRecord, context: ModelContext) {
        guard let idString = record.chaineSecurisee("seanceID"),
              let uuid = UUID(uuidString: idString) else { return }
        let remoteDateMod = record["dateModification"] as? Date ?? .distantPast
        let desc = FetchDescriptor<Seance>(predicate: #Predicate { $0.id == uuid })
        if let existant = try? context.fetch(desc).first {
            guard remoteDateMod > existant.dateModification else { return }
            existant.nom = record.chaineSecurisee("nom") ?? existant.nom
            existant.date = record["date"] as? Date ?? existant.date
            existant.typeSeanceRaw = record.chaineSecurisee("typeSeanceRaw") ?? existant.typeSeanceRaw
            existant.lieu = record.chaineSecurisee("lieu") ?? existant.lieu
            existant.adversaire = record.chaineSecurisee("adversaire") ?? existant.adversaire
            existant.scoreEquipe = record["scoreEquipe"] as? Int ?? existant.scoreEquipe
            existant.scoreAdversaire = record["scoreAdversaire"] as? Int ?? existant.scoreAdversaire
            existant.resultatRaw = record.chaineSecurisee("resultatRaw") ?? existant.resultatRaw
            existant.estArchivee = (record["estArchivee"] as? Int ?? 0) == 1
            existant.dateModification = remoteDateMod
            return
        }
        let seance = Seance(nom: record.chaineSecurisee("nom") ?? "",
                            date: record["date"] as? Date ?? Date(),
                            typeSeance: TypeSeance(rawValue: record.chaineSecurisee("typeSeanceRaw") ?? "") ?? .pratique)
        seance.id = uuid
        seance.codeEquipe = record.chaineSecurisee("codeEquipe") ?? ""
        seance.lieu = record.chaineSecurisee("lieu") ?? ""
        seance.adversaire = record.chaineSecurisee("adversaire") ?? ""
        seance.scoreEquipe = record["scoreEquipe"] as? Int ?? 0
        seance.scoreAdversaire = record["scoreAdversaire"] as? Int ?? 0
        seance.resultatRaw = record.chaineSecurisee("resultatRaw") ?? ""
        seance.estArchivee = (record["estArchivee"] as? Int ?? 0) == 1
        seance.dateModification = remoteDateMod
        context.insert(seance)
    }

    // MARK: - Helpers CloudKit

    /// Prédicat de recherche public (extrait pour test du backward-compat OR).
    /// UtilisateurPartage : `codeEquipe OR codeEcole` (records v<2.0.1 indexés par
    /// codeEcole). Les autres types : `codeEquipe` uniquement.
    static func predicatRecherche(estUtilisateur: Bool, codeEquipe: String) -> NSPredicate {
        estUtilisateur
            ? NSPredicate(format: "codeEquipe == %@ OR codeEcole == %@", codeEquipe, codeEquipe)
            : NSPredicate(format: "%K == %@", "codeEquipe", codeEquipe)
    }

    /// Nombre max de pages suivies par curseur (25 × 200 = 5 000 records) —
    /// garde-fou contre une requête dégénérée, jamais atteint en usage normal.
    private static let maxPagesFetch = 25

    private func fetchRecords(type: String, codeEquipe: String) async throws -> [CKRecord] {
        // Les deux champs (codeEquipe ET codeEcole) doivent être QUERYABLE dans le
        // schéma CloudKit public pour UtilisateurPartage (action humaine ASC).
        let predicate = Self.predicatRecherche(estUtilisateur: type == RecordType.utilisateur, codeEquipe: codeEquipe)
        let query = CKQuery(recordType: type, predicate: predicate)

        var allRecords: [CKRecord] = []
        var (results, curseur) = try await publicDB.records(matching: query, resultsLimit: 200)
        var pages = 1

        while true {
            for (_, result) in results {
                if case .success(let record) = result {
                    allRecords.append(record)
                }
            }
            guard let suite = curseur else { break }
            guard pages < Self.maxPagesFetch else {
                logger.warning("fetchRecords \(type): plafond de \(Self.maxPagesFetch) pages atteint — résultats tronqués")
                break
            }
            (results, curseur) = try await publicDB.records(continuingMatchFrom: suite, resultsLimit: 200)
            pages += 1
        }

        return allRecords
    }

}
