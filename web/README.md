# Playco Analyse — site d'analyse IA de volleyball

Colle un lien YouTube (ou importe une vidéo) → rapport complet du match :
échanges, sets, temps de jeu, statistiques par camp, tendances, synthèse IA,
chaque échange cliquable pour le revoir.

Hors de l'app iOS, par décision (piège 29 de `CLAUDE.md`) : l'app n'importe
jamais depuis YouTube (App Store 5.2.3).

## Ce que le rapport contient

| Bloc | Source | Étiquette |
|---|---|---|
| Échanges (début/fin), durées, temps de jeu, échanges/minute, temps mort moyen | signal image (mouvement, caméra compensée) + son (sifflets 2-4,5 kHz) | MESURÉ |
| Sets | pauses de plus de 2 minutes | ESTIMÉ |
| Par échange : camp au service, type de service, contacts, fin (kill, ace, bloc, erreurs…), camp gagnant, zone et type de la dernière attaque, qualité de réception 0-3, observations | Claude (vision) sur ~1 image / 1,2 s de l'échange, JSON validé | ESTIMÉ |
| Par camp : points, sideout %, points au service %, aces, erreurs, kills, blocs, réception moyenne, plus longue série, répartitions service/attaque/zones | calculé par le code à partir des échanges | CALCULÉ sur ESTIMÉ |
| Tendances : progression du score par set, sideout glissant (10 échanges), pente de la durée des échanges | calculé | CALCULÉ |
| Synthèse : forces, faiblesses, recommandations, tendances, points clés | Claude, à partir des chiffres calculés (il narre, il ne calcule pas) | ESTIMÉ |

Camp A = à gauche si le filet est vertical à l'image, sinon le plus proche de
la caméra. La vue « Par équipe » suppose un changement de camp à chaque set.

## Lancer (Mac)

```bash
cd web
python3.11 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
export ANTHROPIC_API_KEY=sk-ant-...        # sans clé : signal seul (pas d'analyse IA)
uvicorn playco_web.app:app --port 8000
# → http://localhost:8000
```

Sans le site, même moteur :

```bash
python -m playco_web "https://www.youtube.com/watch?v=…" -o rapport.json
python -m playco_web.resume rapport.json     # résumé Markdown
```

| Variable | Rôle | Défaut |
|---|---|---|
| `ANTHROPIC_API_KEY` | active l'analyse IA (Claude) | absente → signal seul |
| `PLAYCO_IA` | `auto` · `factice` (démo sans clé, réponses fixes) · `aucune` | `auto` |
| `PLAYCO_MODELE` | modèle Claude | `claude-opus-5-5` |
| `PLAYCO_DONNEES` | dossier des analyses | `web/donnees/` |

La vidéo YouTube est supprimée après l'analyse (le rapport la relit par le
lecteur YouTube intégré) ; une vidéo importée est conservée pour la relecture.

## Coût IA (ESTIMÉ)

~8 images × ~1 200 jetons par échange + réponse structurée → **~2 à 3 $ par
match de ~50 échanges** avec le modèle par défaut. Plafond :
`--echanges-ia-max N` (CLI).

## Tests

```bash
pip install -r requirements-dev.txt && python -m pytest -q
```

Vidéos de match générées (H.264 + sifflets à 3 150 Hz), IA factice, aucun appel
réseau. CI : `.github/workflows/playco-web.yml` — le job `youtube` analyse un vrai
lien sur un runner GitHub (Actions → PlaycoWeb → Run workflow, ou modifier
`essais/youtube.txt`, signal seul).
