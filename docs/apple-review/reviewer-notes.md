# Apple App Review — Notes for Reviewer · Playco v2.1.0

To be copy-pasted into **App Store Connect → App → App Review Information → Notes for the reviewer**.

---

## Notes (English — for Apple Review Team)

Dear Apple Review Team,

**Playco** is a volleyball coaching application designed primarily for iPad, targeting coaches in Québec, Canada. The app interface is **100% in French** as required by the Québec *Charter of the French Language* (Loi 96). English minimum is provided in StoreKit product descriptions and legal pages for international reviewers.

### Test Account

- **Identifier** : `reviewer.apple.2026`
- **Password** : `ReviewPlayco2026!` *(meets our PasswordPolicy: ≥ 12 chars, NIST 800-63B)*
- **Tier** : Playco Club (14-day trial pre-activated in TestFlight sandbox)
- **Role** : Coach (full permissions)

### How to Test the Main Flows

1. **Quick access** :
   Open the app → splash screen → **« Connexion »** button on the welcome screen → select the **« Coach »** tab → enter the credentials above → you land on the main AccueilView (home) with 5 section tiles.

2. **Onboarding flow (alternative)** :
   To test the complete first-run experience:
   - Tap **« Créer mon équipe »** (Create my team) instead of « Connexion »
   - Complete the 6-step wizard (establishment, sport, coach profile, team, members, calendar)
   - At step 5 (« Membres ») you can add players + 1 assistant. Their identifiers and passwords are auto-generated and shown on monospace badges with a dice icon to regenerate.
   - After « Finaliser », a **blocking sheet (IdentifiantsRecapSheet)** lists all newly created credentials with copy/share buttons. Dismiss with **« J'ai noté mes credentials »**.
   - Next, a **BienvenuePaywallView** blocking sheet offers the 14-day trial on Pro or Club tiers. You can pick either one, or skip via the « Plus tard » toolbar button → app opens in read-only mode.

3. **Live match stats (Pro/Club feature)** :
   AccueilView → **Matchs** → tap « + » (top right) → create a match → Composition (pick 6 starters) → « Démarrer match live » → saisie point-par-point in **StatsLiveView**. Toggle **courtside mode** for simplified UI (big buttons, score 72pt). PaveNumeriqueRapideView overlay for # → player → action quick entry.

4. **Drawing on court with Apple Pencil** :
   AccueilView → **Stratégies** → tap a strategy → draw with Apple Pencil on the volleyball court. Multi-step, formations 5-1/4-2/6-2, locked elements, auto-save every 3s.

5. **Paywall (gate architecture)** :
   The paywall uses StoreKit 2 native with 14-day free trial at the Subscription Group level. 4 products:
   - `com.origo.playco.pro.mensuel` · 14.99 CAD/month
   - `com.origo.playco.pro.annuel` · 149.99 CAD/year
   - `com.origo.playco.club.mensuel` · 25.00 CAD/month
   - `com.origo.playco.club.annuel` · 250.00 CAD/year

   The tier determines athlete access: `.club` required for students (`.etudiant` role) to log in via code. Pro tier is for coaches + assistants only.

### Subscription Architecture (for IAP Review)

- **Family Sharing**: DISABLED on all 4 products (explicit business choice — coaching tool, not consumer entertainment)
- **Free Trial**: 14 days, First-time only at Subscription Group level (a user who already trialed Pro cannot re-trial on Club)
- **Purchase Verification**: Strict `.verified` only — `.unverified` transactions are rejected with a dedicated error message
- **Transaction finish**: Called AFTER persistence (Apple best practice)
- **Observer**: `Transaction.updates` observed in background from app launch
- **Central tier gate**: Located in `PlaycoApp.appliquerGateTier()` — applied after LoginView.onConnecte and restaurerSession. Athletes without a Club coach are signed out immediately with a clear French message.

### Privacy & Data

- **Privacy Policy** : https://armypo.github.io/Coach-Planner-VB/legal/privacy-policy-fr/
- **Terms of Service** : https://armypo.github.io/Coach-Planner-VB/legal/terms-of-service-fr/
- **Data controller** : Origo Technologies, Québec, Canada
- **Data storage** : Apple iCloud (CloudKit private DB + public DB for shared team data). No third-party servers.
- **No tracking, no advertising SDK, no third-party analytics**. The only optional analytics is **TelemetryDeck** (privacy-first, Apple-native, RGPD/Loi 25 compliant) and it only sends non-PII events (app_launched, equipe_creee, etc.).
- **Compliance** : Loi 25 (Québec), Loi 96 (French language), LPRPDE (Canadian federal). Jurisdiction: courts of the judicial district of Québec.

### Passwords & Security

- PasswordPolicy NIST 800-63B: ≥ 12 chars, blacklist contextuelle (prenom/nom/identifiant), mots-de-passe communs rejetés
- Hashing: PBKDF2-HMAC-SHA256 with 600,000 iterations (OWASP 2024 guideline)
- Legacy SHA-256+salt migration transparent on successful login
- 5 failed attempts → 5-minute lockout, progressive up to 1 hour after 15 attempts
- Session expiry: 30 days from `sessionCreeeLe`

### Non-PII Athletes Credentials

A key UX choice: coaches create athlete/assistant accounts with auto-generated identifiers (`prenom.nom.XXXX`) and passwords (`LLLLL_DD` format, no ambiguous I/L/O/0/1). These plaintext passwords are stored in the coach's **private CloudKit DB only** (encrypted at transport + at-rest by Apple) in a `CredentialAthlete` model that is **never** published to the public DB via `CloudKitSharingService`. This lets coaches retrieve and share credentials without server-side storage.

### Known Limitations

- **French only** in v2.1.0. English is planned for v2.2. This is intentional for our Québec market launch per Loi 96 priority.
- **No Family Sharing** on subscriptions — coaching tool, not consumer entertainment.
- **No offline trial expiration** — sandbox durations are accelerated by Apple (14d ≈ 3 min) which is normal TestFlight behavior.

### Contact

- **Email** : support@playco.ca
- **Technical contact** : Christopher Dionne, Founder, Origo Technologies

Thank you for your review. The team is standing by to answer any clarification quickly via the contact email.

---

## Notes (French — for internal reference if Apple reviewer is francophone)

Cher membre de l'équipe App Review,

**Playco** est une application iPadOS de coaching volleyball destinée principalement au marché québécois. L'interface est **100 % en français** en conformité avec la **Loi 96 (Charte de la langue française)**. Une version anglaise minimale est fournie dans les descriptions StoreKit et pages légales pour les réviseurs internationaux.

### Compte test
Identifiant : `reviewer.apple.2026` · Mot de passe : `ReviewPlayco2026!` · Tier : Playco Club · Rôle : Coach

### Parcours rapide
1. Écran d'accueil → **« Connexion »** → onglet **« Coach »** → identifiants ci-dessus
2. Parcours alternatif : **« Créer mon équipe »** → wizard 6 étapes → sheet récap identifiants → sheet paywall bienvenue (essai 14 j Pro ou Club)
3. Stats live : AccueilView → Matchs → créer un match → composition → match live → mode bord de terrain
4. Apple Pencil : AccueilView → Stratégies → dessiner sur le terrain

### Conformité
- **Loi 25 (Québec)** : responsable du traitement, droits d'accès/rectification/effacement/portabilité, délai 30 jours, CAI comme recours
- **Loi 96 (QC)** : interface 100 % français
- **LPRPDE (fédéral)** : compatible
- **Juridiction** : tribunaux du district judiciaire de Québec
- **Stockage données** : Apple iCloud (privé + public pour partage équipe). Aucun serveur Origo.
- **Aucun tracker, aucun SDK publicitaire tiers**. TelemetryDeck (privacy-first, Loi 25 compat) pour crash + événements non-PII uniquement.

Merci de votre révision. Support : support@playco.ca

---

## Copy-paste snippet (ASC field)

The « Notes for the reviewer » field in ASC has a ~4,000 character limit. The recommended EN block above is optimized for this limit. Use the EN version primarily — include the French summary at the end if space allows.

For the **Contact Information** section of ASC:
- First name: Christopher
- Last name: Dionne
- Phone number: [À REMPLIR]
- Email: support@playco.ca

For the **Demo Account** section of ASC:
- Username: `reviewer.apple.2026`
- Password: `ReviewPlayco2026!`

For the **Attachment** field: attach a PDF version of this document if needed (convert via Pandoc or print-to-PDF from Preview).
