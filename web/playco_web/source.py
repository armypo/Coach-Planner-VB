"""Source d'une analyse : lien YouTube (téléchargé avec yt-dlp) ou fichier
envoyé. Seuls les liens YouTube sont acceptés comme URL (pas de
téléchargement arbitraire depuis le serveur)."""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import parse_qs, urlparse

from .media import FFMPEG

HOTES_YOUTUBE = {"youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com", "youtu.be"}

MESSAGE_ANTI_ROBOT = (
    "YouTube bloque le téléchargement depuis cette machine (vérification anti-robot, systématique sur les "
    "serveurs d'hébergement). Lance le site sur ton Mac, ou donne-lui tes cookies YouTube : "
    "PLAYCO_YT_NAVIGATEUR=chrome (ou safari, firefox) ou PLAYCO_YT_COOKIES=/chemin/cookies.txt — voir web/README.md.")


@dataclass
class VideoSource:
    chemin: Path
    titre: str
    id_youtube: str | None


class ErreurSource(Exception):
    pass


def id_youtube(url: str) -> str | None:
    """Identifiant de la vidéo si `url` est un lien YouTube valide, sinon None."""
    try:
        u = urlparse(url.strip())
    except ValueError:
        return None
    if u.scheme not in ("http", "https") or (u.hostname or "").lower() not in HOTES_YOUTUBE:
        return None
    hote = (u.hostname or "").lower()
    if hote == "youtu.be":
        candidat = u.path.lstrip("/").split("/")[0]
    elif u.path.startswith(("/shorts/", "/live/", "/embed/")):
        candidat = u.path.split("/")[2] if len(u.path.split("/")) > 2 else ""
    else:
        candidat = parse_qs(u.query).get("v", [""])[0]
    return candidat if len(candidat) == 11 and all(c.isalnum() or c in "-_" for c in candidat) else None


def options_acces() -> dict:
    """Accès YouTube : moteur JavaScript pour yt-dlp-ejs (le premier trouvé
    parmi deno, node, bun) et cookies facultatifs (fichier ou navigateur)."""
    options: dict = {"js_runtimes": {"deno": {}, "node": {}, "bun": {}}}
    if fichier := os.environ.get("PLAYCO_YT_COOKIES"):
        options["cookiefile"] = fichier
    if navigateur := os.environ.get("PLAYCO_YT_NAVIGATEUR"):
        options["cookiesfrombrowser"] = (navigateur.lower(),)
    return options


def telecharger_youtube(url: str, dossier: Path, duree_max: float = 4 * 3600) -> VideoSource:
    import yt_dlp

    identifiant = id_youtube(url)
    if identifiant is None:
        raise ErreurSource("Lien YouTube invalide.")
    dossier.mkdir(parents=True, exist_ok=True)
    options = {
        # ≤ 720p : assez pour l'analyse, ~1 200 jetons par image envoyée à l'IA.
        "format": "bv*[height<=720][ext=mp4]+ba[ext=m4a]/b[height<=720][ext=mp4]/b[height<=720]/b",
        "outtmpl": str(dossier / "video.%(ext)s"),
        "merge_output_format": "mp4",
        "noplaylist": True,
        "quiet": True,
        "no_warnings": True,
        "ffmpeg_location": FFMPEG,
        "match_filter": lambda info, *_: (
            "Vidéo trop longue" if (info.get("duration") or 0) > duree_max else None),
    } | options_acces()
    try:
        with yt_dlp.YoutubeDL(options) as ydl:
            info = ydl.extract_info(f"https://www.youtube.com/watch?v={identifiant}", download=True)
    except Exception as erreur:  # yt-dlp lève des types variés
        if "confirm you" in str(erreur) and "not a bot" in str(erreur):
            raise ErreurSource(MESSAGE_ANTI_ROBOT) from erreur
        raise ErreurSource(f"Téléchargement YouTube impossible : {erreur}") from erreur
    fichiers = sorted(dossier.glob("video.*"), key=lambda p: p.stat().st_size, reverse=True)
    if not fichiers:
        raise ErreurSource("Téléchargement YouTube : aucun fichier produit (vidéo de plus de 4 h, privée ou indisponible).")
    return VideoSource(fichiers[0], (info or {}).get("title") or identifiant, identifiant)
