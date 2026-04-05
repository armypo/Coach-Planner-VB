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

    @State private var conversationActive: ConversationID? = .equipe

    private var utilisateur: Utilisateur? { authService.utilisateurConnecte }
    private var codeEquipe: String { utilisateur?.codeEcole ?? "" }

    /// Membres de la même équipe (sauf moi)
    private var membresEquipe: [Utilisateur] {
        tousUtilisateurs.filter {
            $0.codeEcole == codeEquipe && $0.id != utilisateur?.id && $0.estActif
        }
    }

    /// Messages de mon équipe
    private var messagesEquipe: [MessageEquipe] {
        tousMessages.filter { $0.codeEquipe == codeEquipe }
    }

    /// Nombre total de non-lus
    var nbNonLus: Int {
        guard let uid = utilisateur?.id else { return 0 }
        return messagesEquipe.filter { !$0.estLuPar(uid) }.count
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
                        membresEquipe: membresEquipe
                    )
                } else {
                    etatVide
                }
            }
        }
        .navigationSplitViewStyle(.prominentDetail)
        .tint(PaletteMat.violet)
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
                        NavigationLink(value: ConversationID.prive(membre.id)) {
                            ligneConversation(
                                icone: membre.role == .coach || membre.role == .admin
                                    ? "figure.volleyball" : "figure.run",
                                nom: membre.nomComplet,
                                couleur: membre.role.couleur,
                                dernier: dernierMessage(pour: .prive(membre.id)),
                                nonLus: nbNonLusPour(.prive(membre.id))
                            )
                        }
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

    private func messagesPour(_ conv: ConversationID) -> [MessageEquipe] {
        guard let uid = utilisateur?.id else { return [] }
        switch conv {
        case .equipe:
            return messagesEquipe.filter { $0.estGroupe }
        case .prive(let autreID):
            return messagesEquipe.filter { msg in
                !msg.estGroupe &&
                ((msg.expediteurID == uid && msg.destinataireID == autreID) ||
                 (msg.expediteurID == autreID && msg.destinataireID == uid))
            }
        }
    }

    private func dernierMessage(pour conv: ConversationID) -> MessageEquipe? {
        messagesPour(conv).last
    }

    private func nbNonLusPour(_ conv: ConversationID) -> Int {
        guard let uid = utilisateur?.id else { return 0 }
        return messagesPour(conv).filter { !$0.estLuPar(uid) }.count
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
