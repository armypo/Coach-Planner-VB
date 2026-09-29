"""Site Playco — Analyse IA de volleyball.

Lancer : `uvicorn playco_web.app:app --port 8000` depuis `web/`, avec
ANTHROPIC_API_KEY dans l'environnement pour l'analyse IA (sans clé : analyse
du signal seulement ; PLAYCO_IA=factice pour une démonstration)."""

from __future__ import annotations

import shutil
import threading
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from .analyse_ia import analyseur_par_defaut
from .pipeline import analyser_video
from .source import VideoSource, id_youtube, telecharger_youtube
from .stockage import Stockage

STATIQUE = Path(__file__).parent / "static"
EXTENSIONS_VIDEO = {".mp4", ".mov", ".m4v", ".mkv", ".webm", ".avi"}

app = FastAPI(title="Playco — Analyse IA volleyball")
stockage = Stockage()


class DemandeLien(BaseModel):
    url: str


def _resume(resultat: dict) -> dict:
    """Quelques chiffres par match, pour l'historique et les tendances multi-matchs."""
    m = resultat["metriques"]
    resume = {"nombre_echanges": m["temps"]["nombre_echanges"], "duree_moyenne": m["temps"]["duree_moyenne"],
              "part_de_jeu_pct": m["temps"]["part_de_jeu_pct"], "sets": len(m["sets"])}
    if m.get("ia"):
        for equipe, s in m["ia"]["equipes_hypothese_changement_de_camp"].items():
            resume[equipe] = {k: s[k] for k in ("points", "sideout_pct", "pct_points_au_service",
                                                "ace_pct", "erreur_service_pct", "qualite_reception_moyenne")}
    return resume


def _lancer(id_analyse: str, obtenir_video: Callable[[Path], VideoSource], supprimer_apres: bool) -> None:
    def travail():
        dossier = stockage.dossier(id_analyse)
        video = None
        try:
            stockage.maj_etat(id_analyse, statut="en_cours", etape="Préparation de la vidéo", progression=0.01)
            video = obtenir_video(dossier)
            resultat = analyser_video(
                video, analyseur_par_defaut(),
                progression=lambda etape, part: stockage.maj_etat(id_analyse, etape=etape, progression=round(part, 3)))
            stockage.ecrire_resultat(id_analyse, resultat)
            stockage.maj_etat(id_analyse, statut="termine", etape="Terminé", progression=1.0,
                              titre=video.titre, resume=_resume(resultat),
                              termine_le=datetime.now(timezone.utc).isoformat(timespec="seconds"))
        except Exception as erreur:
            stockage.maj_etat(id_analyse, statut="erreur", message=str(erreur))
        finally:
            # La vidéo YouTube n'est pas conservée : le rapport la relit par le lecteur YouTube.
            if supprimer_apres and video is not None:
                video.chemin.unlink(missing_ok=True)

    threading.Thread(target=travail, daemon=True).start()


@app.post("/api/analyses", status_code=202)
def analyser_lien(demande: DemandeLien) -> dict:
    identifiant = id_youtube(demande.url)
    if identifiant is None:
        raise HTTPException(400, "Colle un lien YouTube (youtube.com/watch?v=…, youtu.be/…).")
    id_analyse = stockage.creer({"type": "youtube", "url": demande.url, "id_youtube": identifiant})
    _lancer(id_analyse, lambda dossier: telecharger_youtube(demande.url, dossier), supprimer_apres=True)
    return {"id": id_analyse}


@app.post("/api/analyses/fichier", status_code=202)
def analyser_fichier(fichier: UploadFile = File(...)) -> dict:
    extension = Path(fichier.filename or "").suffix.lower()
    if extension not in EXTENSIONS_VIDEO:
        raise HTTPException(400, "Format vidéo non pris en charge.")
    id_analyse = stockage.creer({"type": "fichier", "nom": fichier.filename})
    chemin = stockage.dossier(id_analyse) / f"video{extension}"
    with chemin.open("wb") as sortie:
        shutil.copyfileobj(fichier.file, sortie)
    titre = Path(fichier.filename or "vidéo").stem
    _lancer(id_analyse, lambda dossier: VideoSource(chemin, titre, None), supprimer_apres=False)
    return {"id": id_analyse}


@app.get("/api/analyses")
def lister() -> list[dict]:
    return stockage.lister()


def _etat_ou_404(id_analyse: str) -> dict:
    try:
        etat = stockage.lire_etat(id_analyse)
    except KeyError:
        etat = None
    if etat is None:
        raise HTTPException(404, "Analyse introuvable.")
    return etat


@app.get("/api/analyses/{id_analyse}")
def lire(id_analyse: str) -> dict:
    etat = _etat_ou_404(id_analyse)
    return {"etat": etat, "resultat": stockage.lire_resultat(id_analyse) if etat["statut"] == "termine" else None}


@app.get("/api/analyses/{id_analyse}/video")
def video(id_analyse: str):
    _etat_ou_404(id_analyse)
    fichiers = [f for f in stockage.dossier(id_analyse).glob("video.*") if f.suffix.lower() in EXTENSIONS_VIDEO]
    if not fichiers:
        raise HTTPException(404, "Vidéo non conservée.")
    return FileResponse(fichiers[0])


@app.get("/")
def accueil():
    return FileResponse(STATIQUE / "index.html")


app.mount("/static", StaticFiles(directory=STATIQUE), name="static")
