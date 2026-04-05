//  Playco
//  Copyright (c) 2025 Christopher Dionne. Tous droits reserves.
//

import Foundation
import SwiftData

/// Bibliothèque d'exercices de musculation par défaut — orientés volleyball
enum ExercicesMusculationDefauts {

    /// Peuple la base si vide
    static func peuplerSiVide(context: ModelContext) {
        let descriptor = FetchDescriptor<ExerciceMuscu>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        for def in exercicesDefaut {
            let ex = ExerciceMuscu(nom: def.nom, categorie: def.categorie, notes: def.notes)

            context.insert(ex)
        }
        try? context.save()
    }

    private struct Def {
        let nom: String
        let categorie: CategorieMuscu
        let notes: String
    }

    private static let exercicesDefaut: [Def] = [
        // Jambes
        Def(nom: "Squat", categorie: .jambes, notes: "Fondamental pour la puissance du saut"),
        Def(nom: "Squat bulgare", categorie: .jambes, notes: "Unilatéral, stabilité + force"),
        Def(nom: "Presse à cuisses", categorie: .jambes, notes: "Force concentrique des quadriceps"),
        Def(nom: "Fentes marchées", categorie: .jambes, notes: "Équilibre et force fonctionnelle"),
        Def(nom: "Leg extension", categorie: .jambes, notes: "Isolation des quadriceps"),
        Def(nom: "Leg curl", categorie: .jambes, notes: "Ischio-jambiers, prévention blessures"),
        Def(nom: "Mollets debout", categorie: .jambes, notes: "Explosivité du saut"),
        Def(nom: "Mollets assis", categorie: .jambes, notes: "Soléaire, endurance du mollet"),
        Def(nom: "Deadlift roumain", categorie: .jambes, notes: "Chaîne postérieure, ischio-jambiers"),
        Def(nom: "Hip thrust", categorie: .jambes, notes: "Extension de hanche, puissance du saut"),
        Def(nom: "Goblet squat", categorie: .jambes, notes: "Mobilité et force"),

        // Poitrine
        Def(nom: "Développé couché", categorie: .poitrine, notes: "Force de poussée horizontale"),
        Def(nom: "Développé incliné", categorie: .poitrine, notes: "Haut de la poitrine"),
        Def(nom: "Développé haltères", categorie: .poitrine, notes: "Stabilisation + amplitude"),
        Def(nom: "Push-ups", categorie: .poitrine, notes: "Endurance musculaire, stabilisation du tronc"),
        Def(nom: "Dips", categorie: .poitrine, notes: "Poitrine et triceps"),
        Def(nom: "Chest fly haltères", categorie: .poitrine, notes: "Amplitude pectorale"),

        // Dos
        Def(nom: "Tractions (Pull-ups)", categorie: .dos, notes: "Force de tirage vertical, essentiel volleyball"),
        Def(nom: "Rowing barre", categorie: .dos, notes: "Épaisseur du dos"),
        Def(nom: "Rowing haltère", categorie: .dos, notes: "Unilatéral, correction déséquilibres"),
        Def(nom: "Lat pulldown", categorie: .dos, notes: "Alternative aux tractions"),
        Def(nom: "Face pull", categorie: .dos, notes: "Santé des épaules, coiffe des rotateurs"),
        Def(nom: "Rowing câble assis", categorie: .dos, notes: "Rétraction scapulaire"),
        Def(nom: "Deadlift", categorie: .dos, notes: "Force globale de la chaîne postérieure"),

        // Épaules
        Def(nom: "Développé militaire", categorie: .epaules, notes: "Force de frappe aérienne"),
        Def(nom: "Développé haltères assis", categorie: .epaules, notes: "Stabilisation + force d'épaule"),
        Def(nom: "Élévations latérales", categorie: .epaules, notes: "Deltoïde moyen"),
        Def(nom: "Élévations frontales", categorie: .epaules, notes: "Deltoïde antérieur"),
        Def(nom: "Rotation externe bande", categorie: .epaules, notes: "Prévention blessures épaule, coiffe rotateurs"),
        Def(nom: "Rotation interne bande", categorie: .epaules, notes: "Stabilité articulaire épaule"),
        Def(nom: "Y-T-W prone", categorie: .epaules, notes: "Renforcement scapulaire complet"),
        Def(nom: "Shrugs", categorie: .epaules, notes: "Trapèzes supérieurs"),

        // Bras
        Def(nom: "Curl biceps barre", categorie: .bras, notes: "Force de préhension"),
        Def(nom: "Curl haltères", categorie: .bras, notes: "Supination complète"),
        Def(nom: "Curl marteau", categorie: .bras, notes: "Brachioradial + biceps"),
        Def(nom: "Extension triceps poulie", categorie: .bras, notes: "Isolation triceps"),
        Def(nom: "Extension triceps overhead", categorie: .bras, notes: "Long chef du triceps"),
        Def(nom: "Dips triceps (banc)", categorie: .bras, notes: "Triceps bodyweight"),
        Def(nom: "Poignets curl", categorie: .bras, notes: "Force de poignet pour setting/passing"),

        // Abdominaux
        Def(nom: "Planche (plank)", categorie: .abdos, notes: "Stabilité du tronc, fondamental"),
        Def(nom: "Planche latérale", categorie: .abdos, notes: "Obliques, stabilité latérale"),
        Def(nom: "Russian twist", categorie: .abdos, notes: "Rotation du tronc, puissance de frappe"),
        Def(nom: "Crunch câble", categorie: .abdos, notes: "Flexion du tronc avec charge"),
        Def(nom: "Ab wheel rollout", categorie: .abdos, notes: "Anti-extension, core profond"),
        Def(nom: "Pallof press", categorie: .abdos, notes: "Anti-rotation, stabilité de frappe"),
        Def(nom: "Dead bug", categorie: .abdos, notes: "Coordination + stabilité du tronc"),
        Def(nom: "Hanging leg raise", categorie: .abdos, notes: "Abdominaux inférieurs + grip"),

        // Pliométrie
        Def(nom: "Box jump", categorie: .complet, notes: "Puissance verticale du saut"),
        Def(nom: "Depth jump", categorie: .complet, notes: "Réactivité, cycle étirement-raccourcissement"),
        Def(nom: "Jump squat", categorie: .complet, notes: "Explosivité sans charge ou charge légère"),
        Def(nom: "Broad jump", categorie: .complet, notes: "Puissance horizontale"),
        Def(nom: "Lateral bound", categorie: .complet, notes: "Puissance latérale, déplacements défensifs"),
        Def(nom: "Tuck jump", categorie: .complet, notes: "Explosivité + coordination aérienne"),
        Def(nom: "Single leg hop", categorie: .complet, notes: "Puissance unilatérale, atterrissage"),
        Def(nom: "Approach jump (volleyball)", categorie: .complet, notes: "Simule l'approche d'attaque"),

        // Cardio
        Def(nom: "Sprint 20m", categorie: .cardio, notes: "Vitesse courte distance, transition volleyball"),
        Def(nom: "Shuttle run (navette)", categorie: .cardio, notes: "Changements de direction rapides"),
        Def(nom: "Corde à sauter", categorie: .cardio, notes: "Coordination pieds, endurance"),
        Def(nom: "Rameur (rowing machine)", categorie: .cardio, notes: "Cardio faible impact, force du dos"),
        Def(nom: "Vélo stationnaire", categorie: .cardio, notes: "Récupération active"),
        Def(nom: "Burpees", categorie: .cardio, notes: "Conditionnement complet"),
    ]
}
