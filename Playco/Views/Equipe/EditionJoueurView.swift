//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

/// Sheet d'édition rapide d'un joueur — extrait de JoueurDetailView
struct EditionJoueurView: View {
    @Bindable var joueur: JoueurEquipe
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var taillePieds: Int = 5
    @State private var taillePouces: Int = 10
    @State private var poids: String = ""
    @State private var jourNaissance: String = ""
    @State private var moisNaissance: String = ""
    @State private var anneeNaissance: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Identité") {
                    TextField("Prénom", text: $joueur.prenom)
                    TextField("Nom", text: $joueur.nom)
                    Stepper("Numéro : #\(joueur.numero)", value: $joueur.numero, in: 1...99)
                }
                Section("Poste") {
                    Picker("Poste", selection: Binding(
                        get: { joueur.poste },
                        set: { joueur.poste = $0 }
                    )) {
                        ForEach(PosteJoueur.allCases, id: \.self) { p in
                            Label(p.rawValue, systemImage: p.icone).tag(p)
                        }
                    }
                    .pickerStyle(.inline)
                }
                Section("Taille") {
                    HStack {
                        Picker("Pieds", selection: $taillePieds) {
                            ForEach(4...7, id: \.self) { p in
                                Text("\(p)'").tag(p)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80, height: 100)
                        .clipped()

                        Picker("Pouces", selection: $taillePouces) {
                            ForEach(0...11, id: \.self) { p in
                                Text("\(p)\"").tag(p)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80, height: 100)
                        .clipped()

                        Spacer()

                        Text("\(taillePieds)'\(taillePouces)\"")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.orange)
                    }
                }
                Section("Données supplémentaires") {
                    HStack {
                        Image(systemName: "scalemass")
                            .foregroundStyle(.orange)
                            .frame(width: 24)
                        TextField("Poids (lbs)", text: $poids)
                            .keyboardType(.numberPad)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("DATE DE NAISSANCE")
                            .font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            TextField("JJ", text: $jourNaissance)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .frame(width: 50)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5)))
                            Text("/").foregroundStyle(.secondary)
                            TextField("MM", text: $moisNaissance)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .frame(width: 50)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5)))
                            Text("/").foregroundStyle(.secondary)
                            TextField("AAAA", text: $anneeNaissance)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .frame(width: 70)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5)))
                        }
                    }
                }
            }
            .navigationTitle("Modifier joueur")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        sauvegarder()
                    }
                }
            }
            .onAppear {
                if joueur.taille > 0 {
                    let totalPouces = Int(round(Double(joueur.taille) / 2.54))
                    taillePieds = totalPouces / 12
                    taillePouces = totalPouces % 12
                }
                if let dn = joueur.dateNaissance {
                    let cal = Calendar.current
                    jourNaissance = "\(cal.component(.day, from: dn))"
                    moisNaissance = "\(cal.component(.month, from: dn))"
                    anneeNaissance = "\(cal.component(.year, from: dn))"
                }
                if let utilisateur = trouverUtilisateurLie(), utilisateur.poidKg > 0 {
                    poids = String(format: "%.0f", utilisateur.poidKg)
                }
            }
        }
    }

    private func sauvegarder() {
        // Convertir pieds → cm pour stockage
        let totalPouces = taillePieds * 12 + taillePouces
        joueur.taille = Int(round(Double(totalPouces) * 2.54))

        // Date de naissance
        if let jour = Int(jourNaissance), let mois = Int(moisNaissance), let annee = Int(anneeNaissance),
           jour >= 1, jour <= 31, mois >= 1, mois <= 12, annee >= 1900 {
            var composants = DateComponents()
            composants.day = jour
            composants.month = mois
            composants.year = annee
            joueur.dateNaissance = Calendar.current.date(from: composants)
        }

        // Synchroniser avec l'utilisateur lié
        if let utilisateur = trouverUtilisateurLie() {
            utilisateur.tailleCm = joueur.taille
            utilisateur.prenom = joueur.prenom
            utilisateur.nom = joueur.nom
            utilisateur.numero = joueur.numero
            utilisateur.posteRaw = joueur.poste.rawValue
            utilisateur.dateNaissance = joueur.dateNaissance
            if let p = Double(poids), p > 0 {
                utilisateur.poidKg = p
            }
        }

        try? modelContext.save()
        dismiss()
    }

    private func trouverUtilisateurLie() -> Utilisateur? {
        let joueurID = joueur.id
        let descriptor = FetchDescriptor<Utilisateur>(
            predicate: #Predicate { $0.joueurEquipeID == joueurID }
        )
        return try? modelContext.fetch(descriptor).first
    }
}
