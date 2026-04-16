//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import Foundation
import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "MatchLiveVM")

/// ViewModel central pour la gestion du match live.
/// Gère : score, rotation, sideout, joueurs sur le terrain, substitutions, temps morts.
@MainActor
@Observable
final class MatchLiveViewModel {
    let seance: Seance
    let modelContext: ModelContext
    var syncService: CloudKitSyncService?

    // MARK: - État du match

    var setActuel: Int = 1
    var scoreNous: Int = 0
    var scoreAdv: Int = 0
    var rotationActuelle: Int = 1
    var rotationAdversaire: Int = 1
    /// true = notre équipe sert, false = adversaire sert
    var nousServons: Bool = true

    var dernierPoint: PointMatch?
    var afficherPanneauRallye: Bool = false
    var pointEnAttenteZone: PointMatch?
    var afficherSelecteurZone: Bool = false

    // MARK: - Joueurs

    private var tousJoueurs: [JoueurEquipe] = []
    private var codeEquipeActif: String = ""

    // MARK: - Init

    init(seance: Seance, modelContext: ModelContext, joueurs: [JoueurEquipe], codeEquipe: String) {
        self.seance = seance
        self.modelContext = modelContext
        self.tousJoueurs = joueurs
        self.codeEquipeActif = codeEquipe
        self.nousServons = seance.nousServonsEnPremier
        chargerSet()
    }

    // MARK: - Joueurs sur le terrain

    /// Retourne les 6 joueurs sur le terrain (tenant compte des substitutions du set actuel)
    var joueursActuellementSurTerrain: [JoueurSurTerrain] {
        let partants = seance.partants
        guard !partants.isEmpty else { return [] }

        // Construire le mapping poste → joueurID à partir des partants
        var mapping: [Int: UUID] = [:]
        for p in partants {
            mapping[p.poste] = p.joueurID
        }

        // Appliquer les substitutions du set actuel
        let subsSet = seance.substitutions.filter { $0.set == setActuel }
        for sub in subsSet {
            // Trouver le poste du joueur sortant et le remplacer
            if let poste = mapping.first(where: { $0.value == sub.joueurSortantID })?.key {
                mapping[poste] = sub.joueurEntrantID
            }
        }

        // Appliquer la rotation : décaler les postes selon la rotation actuelle
        // Rotation 1 = pas de décalage, Rotation 2 = tout le monde tourne d'un cran, etc.
        let decalage = rotationActuelle - 1
        var resultat: [JoueurSurTerrain] = []

        for posteOriginal in 1...6 {
            // Le poste affiché après rotation : poste i après N rotations
            // Rotation : 1→6→5→4→3→2 (sens horaire volleyball)
            let posteSource = ((posteOriginal - 1 + decalage) % 6) + 1
            guard let joueurID = mapping[posteSource],
                  let joueur = tousJoueurs.first(where: { $0.id == joueurID }) else { continue }

            resultat.append(JoueurSurTerrain(
                poste: posteOriginal,
                joueurID: joueur.id,
                numero: joueur.numero,
                prenom: joueur.prenom,
                nom: joueur.nom
            ))
        }

        // Ajouter le libéro s'il est défini
        if let liberoUUID = seance.liberoUUID,
           let libero = tousJoueurs.first(where: { $0.id == liberoUUID }) {
            // Le libéro n'est pas dans la rotation, il est sur le terrain en zone arrière
            // On l'ajoute avec poste = 0 pour le distinguer
            if !resultat.contains(where: { $0.joueurID == libero.id }) {
                resultat.append(JoueurSurTerrain(
                    poste: 0,
                    joueurID: libero.id,
                    numero: libero.numero,
                    prenom: libero.prenom,
                    nom: libero.nom,
                    estLibero: true
                ))
            }
        }

        return resultat.sorted { $0.poste < $1.poste }
    }

    /// Joueurs sur le banc (dans le roster mais pas sur le terrain)
    var joueursSurLeBanc: [JoueurEquipe] {
        let surTerrainIDs = Set(joueursActuellementSurTerrain.map(\.joueurID))
        return tousJoueurs.filter { !surTerrainIDs.contains($0.id) }
    }

    /// Nombre de substitutions utilisées dans le set actuel
    var subsUtiliseesDansSet: Int {
        seance.substitutions.filter { $0.set == setActuel }.count
    }

    /// Nombre max de subs par set
    var subsMaxParSet: Int {
        seance.configMatch.subsMaxParSet
    }

    // MARK: - Temps morts

    var tempsMortsNousRestants: Int {
        let maxTM = seance.configMatch.tempsMortsParSetParEquipe
        let utilises = seance.tempsMorts.filter { $0.set == setActuel && $0.equipe == "nous" }.count
        return Swift.max(0, maxTM - utilises)
    }

    var tempsMortsAdvRestants: Int {
        let maxTM = seance.configMatch.tempsMortsParSetParEquipe
        let utilises = seance.tempsMorts.filter { $0.set == setActuel && $0.equipe == "adversaire" }.count
        return Swift.max(0, maxTM - utilises)
    }

    var tempsMortsNousUtilises: Int {
        seance.tempsMorts.filter { $0.set == setActuel && $0.equipe == "nous" }.count
    }

    var tempsMortsAdvUtilises: Int {
        seance.tempsMorts.filter { $0.set == setActuel && $0.equipe == "adversaire" }.count
    }

    // MARK: - Enregistrer une statistique

    func enregistrerStat(action: TypeActionPoint, joueurID: UUID?) {
        // Fermer le panneau rallye précédent
        afficherPanneauRallye = false

        let estPointPourNous = action.estPointPourNous

        // Mettre à jour le score
        if estPointPourNous {
            scoreNous += 1
        } else {
            scoreAdv += 1
        }

        // Créer le PointMatch
        let point = PointMatch(seanceID: seance.id, set: setActuel, joueurID: joueurID, typeAction: action)
        point.scoreEquipeAuMoment = scoreNous
        point.scoreAdversaireAuMoment = scoreAdv
        point.rotationAuMoment = rotationActuelle
        point.rotationAdvAuMoment = rotationAdversaire
        point.codeEquipe = codeEquipeActif
        modelContext.insert(point)

        dernierPoint = point

        // Sauvegarder le set
        sauvegarderSet()

        // Zone heatmap
        if action.supportsZone {
            pointEnAttenteZone = point
            afficherSelecteurZone = true
        }

        // Afficher le panneau rallye
        afficherPanneauRallye = true

        // Détecter le sideout et gérer la rotation
        gererSideout(estPointPourNous: estPointPourNous)

        syncService?.enregistrerModificationLocale()
        logger.info("Stat enregistrée: \(action.rawValue) — \(self.scoreNous)-\(self.scoreAdv)")
    }

    // MARK: - Sideout & Rotation

    /// Gère la logique de sideout :
    /// Si l'équipe en réception marque le point → elle tourne et prend le service.
    private func gererSideout(estPointPourNous: Bool) {
        if estPointPourNous && !nousServons {
            // Sideout : on reçevait et on a marqué → on tourne et on prend le service
            nousServons = true
            tourner()
        } else if !estPointPourNous && nousServons {
            // Sideout adverse : on servait et l'adversaire a marqué → l'adversaire tourne et prend le service
            nousServons = false
            tournerAdversaire()
        }
        // Si l'équipe qui sert marque → pas de rotation (elle continue de servir)
    }

    /// Effectue une rotation (postes tournent : 1→6→5→4→3→2)
    private func tourner() {
        rotationActuelle = (rotationActuelle % 6) + 1
        enregistrerRotationHistorique()
        logger.info("Rotation → R\(self.rotationActuelle)")
    }

    /// Effectue une rotation adversaire
    private func tournerAdversaire() {
        rotationAdversaire = (rotationAdversaire % 6) + 1
        enregistrerRotationHistoriqueAdv()
        logger.info("Rotation adversaire → R\(self.rotationAdversaire)")
    }

    /// Modification manuelle de la rotation adversaire
    func modifierRotationAdversaire(nouvelleRotation: Int) {
        guard nouvelleRotation >= 1 && nouvelleRotation <= 6 else { return }
        rotationAdversaire = nouvelleRotation
        enregistrerRotationHistoriqueAdv()
        logger.info("Rotation adversaire modifiée manuellement → R\(nouvelleRotation)")
    }

    // MARK: - Annuler dernier point

    func annulerDernierPoint(actionsRallye: [ActionRallye]) {
        guard let point = dernierPoint else { return }

        // Supprimer les actions rallye liées
        let actionsLiees = actionsRallye.filter { $0.pointMatchID == point.id }
        for action in actionsLiees {
            modelContext.delete(action)
        }

        let estPointPourNous = point.estPointPourNous

        // Détecter si un sideout avait eu lieu lors de ce point en analysant l'état actuel.
        // Après sideout nous → nousServons == true, rotation a changé
        // Après sideout adv  → nousServons == false, rotationAdv a changé
        let avaitSideoutNous = estPointPourNous && nousServons
        let avaitSideoutAdv = !estPointPourNous && !nousServons

        // Restaurer la rotation depuis les données du point enregistré
        if avaitSideoutNous {
            // Annuler la rotation de notre équipe et rendre le service à l'adversaire
            rotationActuelle = point.rotationAuMoment
            nousServons = false
            // Nettoyer l'historique de rotation (retirer l'entrée fantôme)
            var hist = seance.rotationsHistorique
            if var setHist = hist[setActuel], !setHist.isEmpty {
                setHist.removeLast()
                hist[setActuel] = setHist
            }
            seance.rotationsHistorique = hist
            logger.info("Undo sideout nous — retour R\(point.rotationAuMoment)")
        } else if avaitSideoutAdv {
            // Annuler la rotation adverse et rendre le service à notre équipe
            rotationAdversaire = point.rotationAdvAuMoment
            nousServons = true
            // Nettoyer l'historique de rotation adversaire
            var histAdv = seance.rotationsHistoriqueAdv
            if var setHistAdv = histAdv[setActuel], !setHistAdv.isEmpty {
                setHistAdv.removeLast()
                histAdv[setActuel] = setHistAdv
            }
            seance.rotationsHistoriqueAdv = histAdv
            logger.info("Undo sideout adv — retour R\(point.rotationAdvAuMoment)")
        }
        // Sinon (pas de sideout) : les rotations et le service ne changent pas

        if estPointPourNous {
            scoreNous = Swift.max(0, scoreNous - 1)
        } else {
            scoreAdv = Swift.max(0, scoreAdv - 1)
        }

        modelContext.delete(point)
        dernierPoint = nil
        afficherPanneauRallye = false
        sauvegarderSet()
    }

    // MARK: - Substitutions

    func effectuerSubstitution(sortantID: UUID, entrantID: UUID) {
        var sub = SubstitutionRecord(set: setActuel, joueurSortantID: sortantID, joueurEntrantID: entrantID)
        sub.scoreNousAuMoment = scoreNous
        sub.scoreAdvAuMoment = scoreAdv

        var subs = seance.substitutions
        subs.append(sub)
        seance.substitutions = subs

        syncService?.enregistrerModificationLocale()
        logger.info("Substitution: \(sortantID) → \(entrantID) (set \(self.setActuel))")
    }

    // MARK: - Temps morts

    func prendreTempsMort(equipe: String) {
        var tm = TempsMortRecord(set: setActuel, equipe: equipe)
        tm.scoreNousAuMoment = scoreNous
        tm.scoreAdvAuMoment = scoreAdv

        var tms = seance.tempsMorts
        tms.append(tm)
        seance.tempsMorts = tms

        syncService?.enregistrerModificationLocale()
        logger.info("Temps mort: \(equipe) (set \(self.setActuel))")
    }

    /// Vérifie si un TTO doit être déclenché (8 ou 16 points, sets 1-4)
    func verifierTTO() -> Bool {
        guard seance.configMatch.ttoActifs else { return false }
        guard setActuel <= 4 else { return false }

        let scoreMeneur = Swift.max(scoreNous, scoreAdv)
        return scoreMeneur == 8 || scoreMeneur == 16
    }

    // MARK: - Gestion des sets

    func changerSet(vers: Int) {
        sauvegarderSet()
        setActuel = vers
        chargerSet()
    }

    func sauvegarderSet() {
        var sets = seance.sets
        if let index = sets.firstIndex(where: { $0.numero == setActuel }) {
            sets[index].scoreEquipe = scoreNous
            sets[index].scoreAdversaire = scoreAdv
        } else {
            sets.append(SetScore(numero: setActuel, scoreEquipe: scoreNous, scoreAdversaire: scoreAdv))
        }
        seance.sets = sets
        syncService?.enregistrerModificationLocale()
    }

    func chargerSet() {
        if let set = seance.sets.first(where: { $0.numero == setActuel }) {
            scoreNous = set.scoreEquipe
            scoreAdv = set.scoreAdversaire
        } else {
            scoreNous = 0
            scoreAdv = 0
        }

        // Tenter de restaurer l'état (rotation, service) depuis le dernier point du set
        // pour gérer correctement la navigation vers un set avec des points existants.
        let seanceIDCapture = seance.id
        let setCapture = setActuel
        let pointsDuSet = (try? modelContext.fetch(
            FetchDescriptor<PointMatch>(
                predicate: #Predicate { $0.seanceID == seanceIDCapture && $0.set == setCapture },
                sortBy: [SortDescriptor(\.horodatage)]
            )
        )) ?? []
        if let dernierPointSauvegarde = pointsDuSet.last {
            // Restaurer depuis le dernier point enregistré
            rotationActuelle = dernierPointSauvegarde.rotationAuMoment
            rotationAdversaire = dernierPointSauvegarde.rotationAdvAuMoment
            // Reconstituer qui sert : si le dernier point était un sideout, le service a changé
            let estPointPourNous = dernierPointSauvegarde.estPointPourNous
            // Après le dernier point, le service est déterminé par l'état résultant :
            // - point pour nous sans sideout (on servait) → on sert toujours
            // - point pour nous avec sideout (on recevait) → on sert maintenant
            // - point pour eux sans sideout (ils servaient) → ils servent toujours
            // - point pour eux avec sideout (on servait) → ils servent maintenant
            // La règle volleyball : après chaque point, l'équipe qui a marqué sert.
            nousServons = estPointPourNous
            dernierPoint = dernierPointSauvegarde
            logger.info("chargerSet \(self.setActuel) — restauré depuis dernier point : R\(self.rotationActuelle), service=\(self.nousServons)")
        } else {
            // Set vide → état initial
            rotationActuelle = 1
            rotationAdversaire = 1
            // Déterminer qui sert au début du set
            // Set impair → même que le début du match, set pair → inversé
            if setActuel == 1 {
                nousServons = seance.nousServonsEnPremier
            } else {
                nousServons = (setActuel % 2 == 1) == seance.nousServonsEnPremier
            }
            dernierPoint = nil
            logger.info("chargerSet \(self.setActuel) — set vide, rotation=1, service=\(self.nousServons)")
        }

        afficherPanneauRallye = false
    }

    // MARK: - Modification de rotation manuelle

    func modifierRotation(nouvelleRotation: Int) {
        guard nouvelleRotation >= 1 && nouvelleRotation <= 6 else { return }
        rotationActuelle = nouvelleRotation
        enregistrerRotationHistorique()
        logger.info("Rotation modifiée manuellement → R\(nouvelleRotation)")
    }

    /// Enregistre la rotation actuelle dans l'historique du set
    private func enregistrerRotationHistorique() {
        var historique = seance.rotationsHistorique
        var rotationsSet = historique[setActuel] ?? []
        rotationsSet.append(rotationActuelle)
        historique[setActuel] = rotationsSet
        seance.rotationsHistorique = historique
    }

    /// Enregistre la rotation adversaire dans l'historique du set
    private func enregistrerRotationHistoriqueAdv() {
        var historique = seance.rotationsHistoriqueAdv
        var rotationsSet = historique[setActuel] ?? []
        rotationsSet.append(rotationAdversaire)
        historique[setActuel] = rotationsSet
        seance.rotationsHistoriqueAdv = historique
    }

    // MARK: - Mise à jour des joueurs

    func mettreAJourJoueurs(_ joueurs: [JoueurEquipe], codeEquipe: String) {
        self.tousJoueurs = joueurs
        self.codeEquipeActif = codeEquipe
    }
}
