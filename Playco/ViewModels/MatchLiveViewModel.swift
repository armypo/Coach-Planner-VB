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
            // Sideout adverse : on servait et l'adversaire a marqué → pas de rotation pour nous
            // L'adversaire tourne (pas géré côté adversaire)
            nousServons = false
        }
        // Si l'équipe qui sert marque → pas de rotation (elle continue de servir)
    }

    /// Effectue une rotation (postes tournent : 1→6→5→4→3→2)
    private func tourner() {
        rotationActuelle = (rotationActuelle % 6) + 1
        enregistrerRotationHistorique()
        logger.info("Rotation → R\(self.rotationActuelle)")
    }

    // MARK: - Annuler dernier point

    func annulerDernierPoint(actionsRallye: [ActionRallye]) {
        guard let point = dernierPoint else { return }

        // Supprimer les actions rallye liées
        let actionsLiees = actionsRallye.filter { $0.pointMatchID == point.id }
        for action in actionsLiees {
            modelContext.delete(action)
        }

        // Inverser le sideout si nécessaire
        let estPointPourNous = point.estPointPourNous
        if estPointPourNous && nousServons && rotationActuelle > 1 {
            // On avait tourné → annuler la rotation
            rotationActuelle = rotationActuelle == 1 ? 6 : rotationActuelle - 1
            nousServons = false
        } else if !estPointPourNous && !nousServons {
            nousServons = true
        }

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
        // Déterminer qui sert au début du set
        // Set impair → même que le début du match, set pair → inversé
        if setActuel == 1 {
            nousServons = seance.nousServonsEnPremier
        } else {
            // Alterner chaque set
            nousServons = (setActuel % 2 == 1) == seance.nousServonsEnPremier
        }
        rotationActuelle = 1
        dernierPoint = nil
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

    // MARK: - Mise à jour des joueurs

    func mettreAJourJoueurs(_ joueurs: [JoueurEquipe], codeEquipe: String) {
        self.tousJoueurs = joueurs
        self.codeEquipeActif = codeEquipe
    }
}
