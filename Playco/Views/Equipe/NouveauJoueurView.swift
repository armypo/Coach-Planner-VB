//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Création d'un joueur du roster — donnée pure (`JoueurEquipe`), sans compte.
/// Pivot coach-first : les athlètes ne sont plus des utilisateurs de l'app ;
/// les anciens modes « inviter par code » et « lier un athlète » ont disparu
/// avec les comptes athlètes.
struct NouveauJoueurView: View {
    var onCreate: (JoueurEquipe) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var nom = ""
    @State private var prenom = ""
    @State private var numero = 1
    @State private var poste: PosteJoueur = .recepteur
    @State private var taille = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Identité") {
                    TextField("Prénom", text: $prenom)
                        .autocorrectionDisabled()
                    TextField("Nom", text: $nom)
                        .autocorrectionDisabled()
                    Stepper("Numéro : #\(numero)", value: $numero, in: 1...99)
                }

                Section("Poste") {
                    Picker("Poste", selection: $poste) {
                        ForEach(PosteJoueur.allCases, id: \.self) { p in
                            Label(p.rawValue, systemImage: p.icone).tag(p)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section("Physique (optionnel)") {
                    Stepper("Taille : \(taille > 0 ? "\(taille) cm" : "—")",
                            value: $taille, in: 0...250, step: 1)
                }

                Section {
                    Button("Créer le joueur") {
                        creerJoueur()
                    }
                    .disabled(!formulaireValide)
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
                }
            }
            .navigationTitle("Nouveau joueur")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }

    private var formulaireValide: Bool {
        !prenom.trimmingCharacters(in: .whitespaces).isEmpty &&
        !nom.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func creerJoueur() {
        let joueur = JoueurEquipe(nom: nom, prenom: prenom, numero: numero, poste: poste)
        if taille > 0 { joueur.taille = taille }
        onCreate(joueur)
        dismiss()
    }
}
