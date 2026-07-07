//  Playco
//  Copyright © 2025 Christopher Dionne. Tous droits réservés.
//

import SwiftUI
import SwiftData

// MARK: - Identifiant de conversation

enum ConversationID: Hashable {
    case equipe                 // fil d'équipe
    case prive(UUID)            // fil privé avec un utilisateur
}

// MARK: - Vue principale — sidebar conversations + detail chat

struct MessagerieView: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \MessageEquipe.dateEnvoi) private var tousMessages: [MessageEquipe]
    @Query(sort: \Utilisateur.nom) private var tousUtilisateurs: [Utilisateur]
    @Query private var tousJoueurs: [JoueurEquipe]

    @State private var conversationActive: ConversationID? = .equipe

    // Caches @State — recalculés via mettreAJourCaches() (pattern perfo projet)
    /// Membres de la même équipe (sauf moi)
    @State private var membresEquipe: [Utilisateur] = []
    /// Messages de mon équipe
    @State private var messagesEquipe: [MessageEquipe] = []
    /// Dernier message par conversation (fil d'équipe + fils privés)
    @State private var derniersMessages: [ConversationID: MessageEquipe] = [:]
    /// Nombre de non-lus par conversation
    @State private var nonLusParConversation: [ConversationID: Int] = [:]

    private var utilisateur: Utilisateur? { authService.utilisateurConnecte }
    private var codeEquipe: String { utilisateur?.codeEcole ?? "" }

    /// Signature légère de lecture : `lecteurIDsData` grandit quand un message est
    /// marqué lu SANS que le count des messages change — observer cette somme
    /// permet d'invalider le cache des non-lus.
    private var signatureLecture: Int {
        tousMessages.reduce(0) { $0 + ($1.lecteurIDsData?.count ?? 0) }
    }

    // MARK: - Consentement mineurs (2.2.b)

    /// Fiche roster liée à un compte — SCOPÉE à l'équipe courante (revue 2.2.b :
    /// un même compte peut avoir une fiche par équipe), lien direct prioritaire.
    private func ficheJoueur(_ compte: Utilisateur) -> JoueurEquipe? {
        let fiches = tousJoueurs.filter { $0.codeEquipe == codeEquipe }
        return fiches.first { $0.utilisateurID == compte.id }
            ?? fiches.first { compte.joueurEquipeID == $0.id }
    }

    /// Minorité et consentement d'un compte : la fiche roster (gérée par le
    /// coach) fait foi ; l'âge du compte sert de filet.
    private func infosConsentement(_ compte: Utilisateur) -> (estMineur: Bool, consentement: Bool) {
        let fiche = ficheJoueur(compte)
        let mineurCompte = (compte.age ?? JoueurEquipe.ageMajorite) < JoueurEquipe.ageMajorite
        return ((fiche?.estMineur ?? false) || mineurCompte, fiche?.consentementParentalAtteste ?? false)
    }

    /// Applique PolitiqueMessagerie à la paire (moi ↔ membre).
    private func dmAutorise(avec membre: Utilisateur) -> Bool {
        guard let moi = utilisateur else { return false }
        let infosMoi = infosConsentement(moi)
        let infosMembre = infosConsentement(membre)
        // Le consentement pertinent est celui du mineur de la paire.
        let consentementDuMineur = infosMembre.estMineur ? infosMembre.consentement : infosMoi.consentement
        return PolitiqueMessagerie.dmPriveAutorise(
            roleExpediteur: moi.role, expediteurEstMineur: infosMoi.estMineur,
            roleDestinataire: membre.role, destinataireEstMineur: infosMembre.estMineur,
            consentementAtteste: consentementDuMineur
        )
    }

    /// Nombre total de non-lus (dans mes conversations)
    var nbNonLus: Int {
        nonLusParConversation.values.reduce(0, +)
    }

    var body: some View {
        NavigationSplitView {
            sidebarConversations
        } detail: {
            NavigationStack {
                if let conv = conversationActive {
                    ChatView(
                        conversationID: conv,
                        tousMessages: messagesEquipe,
                        membresEquipe: membresEquipe,
                        envoiAutorise: {
                            // Revue 2.2.b : la politique s'applique au POINT
                            // D'ENVOI, pas seulement à la navigation.
                            if case .prive(let autreID) = conv,
                               let autre = membresEquipe.first(where: { $0.id == autreID }) {
                                return dmAutorise(avec: autre)
                            }
                            return true
                        }()
                    )
                } else {
                    etatVide
                }
            }
        }
        .navigationSplitViewStyle(.prominentDetail)
        .tint(PaletteMat.violet)
        .onAppear { mettreAJourCaches() }
        .onChange(of: tousMessages) { mettreAJourCaches() }
        .onChange(of: tousUtilisateurs) { mettreAJourCaches() }
        .onChange(of: signatureLecture) { mettreAJourCaches() }
        .onChange(of: codeEquipe) { mettreAJourCaches() }
    }

    // MARK: - Sidebar

    private var sidebarConversations: some View {
        List(selection: $conversationActive) {
            // Fil d'équipe
            Section {
                NavigationLink(value: ConversationID.equipe) {
                    ligneConversation(
                        icone: "person.3.fill",
                        nom: "Équipe",
                        couleur: PaletteMat.violet,
                        dernier: dernierMessage(pour: .equipe),
                        nonLus: nbNonLusPour(.equipe)
                    )
                }
            } header: {
                Text("Groupe")
                    .font(.caption.weight(.bold))
            }

            // Conversations privées
            if !membresEquipe.isEmpty {
                Section {
                    ForEach(membresEquipe) { membre in
                        // 2.2.b — DM privés adulte↔mineur désactivés tant que
                        // le consentement parental n'est pas attesté (fiche joueur).
                        let autorise = dmAutorise(avec: membre)
                        NavigationLink(value: ConversationID.prive(membre.id)) {
                            VStack(alignment: .leading, spacing: 2) {
                                ligneConversation(
                                    icone: membre.role == .coach || membre.role == .admin
                                        ? "figure.volleyball" : "figure.run",
                                    nom: membre.nomComplet,
                                    couleur: membre.role.couleur,
                                    dernier: dernierMessage(pour: .prive(membre.id)),
                                    nonLus: nbNonLusPour(.prive(membre.id))
                                )
                                if !autorise {
                                    Text("Consentement parental requis")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .disabled(!autorise)
                        .opacity(autorise ? 1 : 0.5)
                    }
                } header: {
                    Text("Individuel")
                        .font(.caption.weight(.bold))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Messages")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Fermer") { dismiss() }
            }
        }
    }

    // MARK: - Ligne conversation

    private func ligneConversation(icone: String, nom: String, couleur: Color,
                                    dernier: MessageEquipe?, nonLus: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icone)
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(couleur, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(nom)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Spacer()
                    if let d = dernier {
                        Text(d.dateEnvoi.formatHeure())
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                if let d = dernier {
                    Text(d.contenu)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Aucun message")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            if nonLus > 0 {
                Text("\(nonLus)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(PaletteMat.violet, in: Circle())
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func dernierMessage(pour conv: ConversationID) -> MessageEquipe? {
        derniersMessages[conv]
    }

    private func nbNonLusPour(_ conv: ConversationID) -> Int {
        nonLusParConversation[conv] ?? 0
    }

    // MARK: - Mise à jour des caches

    /// Recalcule membres, messages d'équipe, derniers messages et non-lus
    /// en une seule passe (évite les filter répétés par ligne de conversation
    /// et le décodage JSON de `estLuPar` à chaque render).
    private func mettreAJourCaches() {
        let uid = utilisateur?.id
        let nouveauxMembres = tousUtilisateurs.filter {
            $0.codeEcole == codeEquipe && $0.id != uid && $0.estActif
        }
        let nouveauxMessages = tousMessages.filter { $0.codeEquipe == codeEquipe }

        var derniers: [ConversationID: MessageEquipe] = [:]
        var nonLus: [ConversationID: Int] = [:]
        for message in nouveauxMessages {
            guard let conv = conversationID(pour: message, uid: uid) else { continue }
            derniers[conv] = message // tri croissant par dateEnvoi → le dernier gagne
            if let uid, !message.estLuPar(uid) {
                nonLus[conv, default: 0] += 1
            }
        }

        membresEquipe = nouveauxMembres
        messagesEquipe = nouveauxMessages
        derniersMessages = derniers
        nonLusParConversation = nonLus
    }

    /// Conversation à laquelle appartient un message, du point de vue de l'utilisateur courant.
    /// nil = message privé entre deux autres membres (invisible pour moi).
    private func conversationID(pour message: MessageEquipe, uid: UUID?) -> ConversationID? {
        if message.estGroupe { return .equipe }
        guard let uid else { return nil }
        if message.expediteurID == uid, let destinataire = message.destinataireID {
            return .prive(destinataire)
        }
        if message.destinataireID == uid {
            return .prive(message.expediteurID)
        }
        return nil
    }

    private var etatVide: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 56))
                .foregroundStyle(PaletteMat.violet.opacity(0.3))
            Text("Sélectionnez une conversation")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Vue Chat (détail d'une conversation)

struct ChatView: View {
    let conversationID: ConversationID
    let tousMessages: [MessageEquipe]
    let membresEquipe: [Utilisateur]
    /// Revue 2.2.b — défense en profondeur : faux si la politique de
    /// consentement (adulte↔mineur) interdit cette conversation privée.
    var envoiAutorise: Bool = true

    @Environment(AuthService.self) private var authService
    @Environment(\.modelContext) private var modelContext

    @State private var texteMessage = ""
    @State private var scrollProxy: ScrollViewProxy?

    private var utilisateur: Utilisateur? { authService.utilisateurConnecte }

    /// Messages filtrés pour cette conversation
    private var messages: [MessageEquipe] {
        guard let uid = utilisateur?.id else { return [] }
        switch conversationID {
        case .equipe:
            return tousMessages.filter { $0.estGroupe }
        case .prive(let autreID):
            return tousMessages.filter { msg in
                !msg.estGroupe &&
                ((msg.expediteurID == uid && msg.destinataireID == autreID) ||
                 (msg.expediteurID == autreID && msg.destinataireID == uid))
            }
        }
    }

    private var titreConversation: String {
        switch conversationID {
        case .equipe: return "Équipe"
        case .prive(let id):
            return membresEquipe.first { $0.id == id }?.nomComplet ?? "Conversation"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if messages.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: conversationID == .equipe ? "person.3.fill" : "bubble.left")
                        .font(.system(size: 48))
                        .foregroundStyle(PaletteMat.violet.opacity(0.3))
                    Text("Aucun message")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(conversationID == .equipe
                         ? "Envoyez le premier message à votre équipe !"
                         : "Démarrez la conversation")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                bulleMessage(message)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onAppear {
                        scrollProxy = proxy
                        marquerLus()
                        scrollToBottom(proxy)
                    }
                    .onChange(of: messages.count) {
                        scrollToBottom(proxy)
                    }
                }
            }

            Divider()
            barreSaisie
        }
        .navigationTitle(titreConversation)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Bulle

    private func bulleMessage(_ message: MessageEquipe) -> some View {
        let estMoi = message.expediteurID == utilisateur?.id
        let role = RoleUtilisateur(rawValue: message.expediteurRoleRaw)
        let couleur = role?.couleur ?? PaletteMat.orange

        return HStack(alignment: .bottom, spacing: 8) {
            if estMoi { Spacer(minLength: 60) }

            VStack(alignment: estMoi ? .trailing : .leading, spacing: 4) {
                if !estMoi {
                    HStack(spacing: 6) {
                        Text(message.expediteurNom)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(role?.label ?? "")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(couleur, in: Capsule())
                    }
                }

                Text(message.contenu)
                    .font(.subheadline)
                    .foregroundStyle(estMoi ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        estMoi ? couleur : Color(.systemGray5),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )

                Text(message.dateEnvoi.formatHeure())
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            if !estMoi { Spacer(minLength: 60) }
        }
    }

    // MARK: - Barre de saisie

    private var barreSaisie: some View {
        HStack(spacing: 10) {
            TextField("Message…", text: $texteMessage, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 20))

            Button { envoyer() } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        texteValide ? PaletteMat.violet : Color.gray.opacity(0.3),
                        in: Circle()
                    )
            }
            .disabled(!texteValide)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var texteValide: Bool {
        !texteMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    private func envoyer() {
        guard envoiAutorise else { return } // politique consentement (2.2.b)
        guard let user = utilisateur, texteValide else { return }
        let contenu = texteMessage.trimmingCharacters(in: .whitespacesAndNewlines)

        let msg: MessageEquipe
        switch conversationID {
        case .equipe:
            msg = MessageEquipe(contenu: contenu, expediteur: user, codeEquipe: user.codeEcole)
        case .prive(let destID):
            if let dest = membresEquipe.first(where: { $0.id == destID }) {
                msg = MessageEquipe(contenu: contenu, expediteur: user, destinataire: dest, codeEquipe: user.codeEcole)
            } else { return }
        }

        modelContext.insert(msg)
        try? modelContext.save()
        texteMessage = ""

        if let proxy = scrollProxy {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation { proxy.scrollTo(msg.id, anchor: .bottom) }
            }
        }
    }

    private func marquerLus() {
        guard let uid = utilisateur?.id else { return }
        var modifie = false
        for message in messages where !message.estLuPar(uid) {
            message.ajouterLecteur(uid)
            modifie = true
        }
        if modifie { try? modelContext.save() }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let dernier = messages.last {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(dernier.id, anchor: .bottom)
                }
            }
        }
    }
}
