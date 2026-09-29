"""Analyse en ligne de commande, sans le site :

    python -m playco_web "https://www.youtube.com/watch?v=…" -o rapport.json
    python -m playco_web match.mp4 -o rapport.json

Même moteur que le site (Claude si ANTHROPIC_API_KEY est défini,
PLAYCO_IA=factice pour une démonstration, sinon signal seul)."""

from __future__ import annotations

import argparse
import json
import sys
import tempfile
from pathlib import Path

from .analyse_ia import analyseur_par_defaut
from .pipeline import OptionsAnalyse, analyser_video
from .source import ErreurSource, VideoSource, id_youtube, telecharger_youtube


def main(argv: list[str] | None = None) -> int:
    parseur = argparse.ArgumentParser(prog="python -m playco_web",
                                      description="Analyse IA d'un match de volleyball (lien YouTube ou fichier).")
    parseur.add_argument("source", help="lien YouTube ou chemin d'un fichier vidéo")
    parseur.add_argument("-o", "--sortie", type=Path, default=Path("rapport.json"))
    parseur.add_argument("--echanges-ia-max", type=int, default=None,
                         help="n'envoie à l'IA que les N premiers échanges (plafond de coût)")
    args = parseur.parse_args(argv)

    ia = analyseur_par_defaut()
    derniere_etape = ""

    def progression(etape: str, part: float) -> None:
        nonlocal derniere_etape
        if etape != derniere_etape:
            derniere_etape = etape
            print(f"[{part:4.0%}] {etape}", file=sys.stderr, flush=True)

    with tempfile.TemporaryDirectory() as temporaire:
        if id_youtube(args.source):
            print("Téléchargement YouTube…", file=sys.stderr, flush=True)
            try:
                video = telecharger_youtube(args.source, Path(temporaire))
            except ErreurSource as erreur:
                print(f"Erreur : {erreur}", file=sys.stderr)
                return 1
        else:
            chemin = Path(args.source)
            if not chemin.is_file():
                parseur.error(f"ni un lien YouTube, ni un fichier : {args.source}")
            video = VideoSource(chemin, chemin.stem, None)
        resultat = analyser_video(video, ia, progression, OptionsAnalyse(echanges_ia_max=args.echanges_ia_max))

    args.sortie.write_text(json.dumps(resultat, ensure_ascii=False, indent=2), encoding="utf-8")
    t = resultat["metriques"]["temps"]
    print(f"{resultat['source']['titre']} : {t['nombre_echanges']} échanges, "
          f"{len(resultat['metriques']['sets'])} set(s) estimé(s), {resultat['sifflets']} sifflets, "
          f"IA : {resultat['analyse_ia']['moteur'] or 'aucune'} ({resultat['analyse_ia']['echanges_analyses']} échanges, "
          f"{len(resultat['analyse_ia']['erreurs'])} erreur(s)) → {args.sortie}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
