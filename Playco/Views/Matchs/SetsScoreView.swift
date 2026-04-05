//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI

/// Saisie et affichage du score par set (1 à 5 sets)
struct SetsScoreView: View {
    @Bindable var seance: Seance

    @State private var setsLocaux: [SetScore] = []

    var body: some View {
        VStack(spacing: 12) {
            // En-tête
            HStack {
                Text("SCORE PAR SET")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Spacer()
                if setsLocaux.count < 5 {
                    Button {
                        let nouveau = SetScore(numero: setsLocaux.count + 1)
                        setsLocaux.append(nouveau)
                        seance.sets = setsLocaux
                    } label: {
                        Label("Set \(setsLocaux.count + 1)", systemImage: "plus.circle.fill")
                            .font(.caption.weight(.medium))
                    }
                    .tint(.red)
                }
            }

            if setsLocaux.isEmpty {
                Text("Aucun set enregistré")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                // Grille des sets
                ForEach(setsLocaux.indices, id: \.self) { index in
                    ligneSet(index: index)
                }

                // Résumé
                resumeSets
            }
        }
        .onAppear {
            setsLocaux = seance.sets
        }
    }

    private func ligneSet(index: Int) -> some View {
        let set = setsLocaux[index]
        let estDecisif = set.numero >= 5

        return HStack(spacing: 12) {
            // Label set
            Text("Set \(set.numero)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(estDecisif ? .red : .primary)
                .frame(width: 50, alignment: .leading)

            // Score nous
            HStack(spacing: 6) {
                Button {
                    if setsLocaux[index].scoreEquipe > 0 {
                        setsLocaux[index].scoreEquipe -= 1
                        seance.sets = setsLocaux
                    }
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Text("\(set.scoreEquipe)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(set.scoreEquipe > set.scoreAdversaire ? .green : .primary)
                    .frame(width: 36)
                    .contentTransition(.numericText())

                Button {
                    setsLocaux[index].scoreEquipe += 1
                    seance.sets = setsLocaux
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }

            Text("—")
                .font(.caption)
                .foregroundStyle(.tertiary)

            // Score adversaire
            HStack(spacing: 6) {
                Button {
                    if setsLocaux[index].scoreAdversaire > 0 {
                        setsLocaux[index].scoreAdversaire -= 1
                        seance.sets = setsLocaux
                    }
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Text("\(set.scoreAdversaire)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(set.scoreAdversaire > set.scoreEquipe ? .red : .primary)
                    .frame(width: 36)
                    .contentTransition(.numericText())

                Button {
                    setsLocaux[index].scoreAdversaire += 1
                    seance.sets = setsLocaux
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Indicateur set terminé
            if set.estTermine {
                Image(systemName: set.gagnant == "equipe" ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(set.gagnant == "equipe" ? .green : .red)
                    .font(.caption)
            }

            // Supprimer
            if index == setsLocaux.count - 1 {
                Button {
                    setsLocaux.removeLast()
                    seance.sets = setsLocaux
                } label: {
                    Image(systemName: "trash")
                        .font(.caption2)
                        .foregroundStyle(.red.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: setsLocaux.count)
    }

    private var resumeSets: some View {
        let gagnes = setsLocaux.filter { $0.scoreEquipe > $0.scoreAdversaire }.count
        let perdus = setsLocaux.filter { $0.scoreAdversaire > $0.scoreEquipe }.count

        return HStack {
            Text("Sets :")
                .font(.caption.weight(.medium))
            Text("\(gagnes)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.green)
            Text("-")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(perdus)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.red)
            Spacer()
            if let resultat = seance.resultat {
                Text(resultat.label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(resultat.couleur, in: Capsule())
            }
        }
        .padding(.top, 4)
    }
}
