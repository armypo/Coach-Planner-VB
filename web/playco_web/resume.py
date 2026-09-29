"""Résumé Markdown d'un rapport JSON (terminal, résumé de job CI) :

    python -m playco_web.resume rapport.json"""

from __future__ import annotations

import json
import sys
from pathlib import Path


def horloge(s: float) -> str:
    s = max(0, int(s))
    return f"{s // 60}:{s % 60:02d}"


def resume(rapport: dict) -> str:
    t = rapport["metriques"]["temps"]
    ia = rapport["metriques"].get("ia")
    lignes = [
        f"### {rapport['source']['titre']}",
        "",
        f"Durée {horloge(rapport['video']['duree'])} · {rapport['video']['largeur']}×{rapport['video']['hauteur']} · "
        f"{rapport['sifflets']} sifflets · IA : {rapport['analyse_ia']['moteur'] or 'aucune (signal seul)'}",
        "",
        "| MESURÉ (signal) | Valeur |",
        "|---|---|",
        f"| Échanges | {t['nombre_echanges']} |",
        f"| Durée moyenne / max (s) | {t['duree_moyenne']} / {t['duree_max']} |",
        f"| Temps de jeu | {t['part_de_jeu_pct']} % |",
        f"| Échanges / minute | {t['echanges_par_minute']} |",
        f"| Sets estimés | {len(rapport['metriques']['sets'])} |",
        "",
    ]
    if ia:
        a, b = ia["camps"]["A"], ia["camps"]["B"]
        lignes += ["| ESTIMÉ (IA) | Camp A | Camp B |", "|---|---|---|"]
        for libelle, cle in (("Points", "points"), ("Sideout %", "sideout_pct"), ("Points au service %", "pct_points_au_service"),
                             ("Aces", "aces"), ("Erreurs de service", "erreurs_service"), ("Attaques gagnantes", "kills"),
                             ("Blocs gagnants", "blocs_gagnants"), ("Erreurs d'attaque", "erreurs_attaque")):
            lignes.append(f"| {libelle} | {a[cle] if a[cle] is not None else '—'} | {b[cle] if b[cle] is not None else '—'} |")
        lignes.append("")
    if rapport["analyse_ia"]["erreurs"]:
        lignes += [f"Erreurs IA : {len(rapport['analyse_ia']['erreurs'])} — {rapport['analyse_ia']['erreurs'][0]}", ""]
    lignes += ["| # | Début | Fin | Durée (s) | Fin d'échange (IA) |", "|---|---|---|---|---|"]
    for e in rapport["echanges"]:
        fin = f"{e['analyse']['fin']} → {e['analyse']['camp_gagnant']}" if e["analyse"] else "—"
        lignes.append(f"| {e['numero']} | {horloge(e['debut'])} | {horloge(e['fin'])} | {e['duree']} | {fin} |")
    return "\n".join(lignes) + "\n"


def main(argv: list[str] | None = None) -> int:
    for chemin in (argv if argv is not None else sys.argv[1:]):
        print(resume(json.loads(Path(chemin).read_text(encoding="utf-8"))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
