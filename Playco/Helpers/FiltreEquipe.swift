//  Playco
//  Copyright (c) 2025 Christopher Dionne. Tous droits reserves.
//

import Foundation

/// Protocole pour les modèles filtrables par code équipe
protocol FiltreParEquipe {
    var codeEquipe: String { get }
}

extension Array where Element: FiltreParEquipe {
    /// Filtre les éléments appartenant à l'équipe active (ou sans équipe assignée)
    func filtreEquipe(_ codeActif: String) -> [Element] {
        filter { $0.codeEquipe == codeActif || $0.codeEquipe.isEmpty }
    }
}

// MARK: - Conformances

extension Seance: FiltreParEquipe {}
extension JoueurEquipe: FiltreParEquipe {}
extension StrategieCollective: FiltreParEquipe {}
extension ProgrammeMuscu: FiltreParEquipe {}
extension SeanceMuscu: FiltreParEquipe {}
extension StatsMatch: FiltreParEquipe {}
extension MessageEquipe: FiltreParEquipe {}
extension FormationPersonnalisee: FiltreParEquipe {}
extension AssistantCoach: FiltreParEquipe {}
extension PointMatch: FiltreParEquipe {}
extension Equipe: FiltreParEquipe {}
extension CategorieExercice: FiltreParEquipe {}
extension ActionRallye: FiltreParEquipe {}
