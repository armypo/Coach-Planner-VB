//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI

/// Étape 6 — Définir le calendrier (optionnelle)
struct ConfigCalendrierView: View {
    @Binding var creneaux: [CreneauTemp]
    @Binding var matchs: [MatchTemp]
    @Binding var dateFinSaison: Date
    var onPasser: () -> Void

    @State private var onglet: Int = 0 // 0 = pratiques, 1 = matchs

    private let durees = [60, 90, 120, 150, 180]
    private let jours = ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"]

    /// Nombre de semaines entre aujourd'hui et la fin de saison
    private var nbSemaines: Int {
        let jours = Calendar.current.dateComponents([.day], from: Date(), to: dateFinSaison).day ?? 0
        return max(0, jours / 7)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                titreEtape(numero: 6, titre: "Calendrier",
                           description: "Planifiez vos créneaux récurrents et vos matchs à venir. Cette étape est optionnelle.")

                // Date de fin de saison
                VStack(alignment: .leading, spacing: 8) {
                    Text("FIN DE SAISON")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)

                    HStack {
                        DatePicker("", selection: $dateFinSaison,
                                   in: Date()...,
                                   displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "fr_FR"))
                            .tint(PaletteMat.orange)

                        Spacer()

                        Text("\(nbSemaines) semaines")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(PaletteMat.orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(PaletteMat.orange.opacity(0.1), in: Capsule())
                    }

                    Text("Les séances récurrentes seront générées jusqu'à cette date.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))

                Picker("Section", selection: $onglet) {
                    Text("Pratiques (\(creneaux.count))").tag(0)
                    Text("Matchs (\(matchs.count))").tag(1)
                }
                .pickerStyle(.segmented)

                if onglet == 0 {
                    sectionPratiques
                } else {
                    sectionMatchs
                }

                // Aperçu
                if !creneaux.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("APERÇU")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)
                        Text(apercu)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 10))
                    }
                }

                // Bouton passer
                Button {
                    onPasser()
                } label: {
                    Text("Passer — je configurerai le calendrier plus tard")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }

                Spacer(minLength: 20)
            }
            .padding(.vertical, 24)
        }
    }

    // MARK: - Pratiques récurrentes

    private var sectionPratiques: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach($creneaux) { $creneau in
                carteCreneau(creneau: $creneau)
            }

            Button {
                creneaux.append(CreneauTemp())
            } label: {
                Label("Ajouter un créneau récurrent", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PaletteMat.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(PaletteMat.orange.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func carteCreneau(creneau: Binding<CreneauTemp>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Créneau")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PaletteMat.orange)
                Spacer()
                Button {
                    creneaux.removeAll { $0.id == creneau.wrappedValue.id }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Picker("Jour", selection: creneau.jourSemaine) {
                        ForEach(1...7, id: \.self) { j in
                            Text(jours[j - 1]).tag(j)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(PaletteMat.orange)

                    Spacer()

                    Picker("Durée", selection: creneau.dureeMinutes) {
                        ForEach(durees, id: \.self) { d in
                            Text(dureLabel(d)).tag(d)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(PaletteMat.orange)
                }

                DatePicker("Heure de début", selection: creneau.heureDebut, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .environment(\.locale, Locale(identifier: "fr_FR"))
                    .tint(PaletteMat.orange)
            }

            TextField("Lieu (optionnel)", text: creneau.lieu)
                .font(.subheadline)
                .padding(10)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Matchs

    private var sectionMatchs: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach($matchs) { $match in
                carteMatch(match: $match)
            }

            Button {
                matchs.append(MatchTemp())
            } label: {
                Label("Ajouter un match", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func carteMatch(match: Binding<MatchTemp>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Match")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.red)
                Spacer()
                Button {
                    matchs.removeAll { $0.id == match.wrappedValue.id }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            DatePicker("Date", selection: match.date, displayedComponents: [.date, .hourAndMinute])
                .environment(\.locale, Locale(identifier: "fr_FR"))

            HStack(spacing: 12) {
                TextField("Adversaire", text: match.adversaire)
                    .padding(10)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                TextField("Lieu", text: match.lieu)
                    .padding(10)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
            }

            Picker("", selection: match.estDomicile) {
                Text("Domicile").tag(true)
                Text("Extérieur").tag(false)
            }
            .pickerStyle(.segmented)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Helpers

    private var apercu: String {
        creneaux.map { c in
            let jour = c.jourSemaine >= 1 && c.jourSemaine <= 7 ? jours[c.jourSemaine - 1] : "?"
            let heure = c.heureDebut.formatHeure()
            return "\(jour) \(heure) (\(dureLabel(c.dureeMinutes)))"
        }.joined(separator: ", ")
    }

    private func dureLabel(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if m == 0 { return "\(h)h" }
        return "\(h)h\(m)"
    }
}
