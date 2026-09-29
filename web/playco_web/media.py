"""Lecture des vidéos avec ffmpeg (binaire fourni par imageio-ffmpeg) :
métadonnées, images en niveaux de gris réduites, piste audio mono, images
clés JPEG pour l'analyse IA."""

from __future__ import annotations

import re
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Iterator

import imageio_ffmpeg
import numpy as np

FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()


@dataclass
class InfosVideo:
    duree: float
    largeur: int
    hauteur: int
    images_par_seconde: float
    a_audio: bool


class ErreurMedia(Exception):
    pass


def infos(chemin: Path) -> InfosVideo:
    sortie = subprocess.run([FFMPEG, "-hide_banner", "-i", str(chemin)],
                            capture_output=True, text=True).stderr
    duree = re.search(r"Duration: (\d+):(\d+):(\d+(?:\.\d+)?)", sortie)
    video = re.search(r"Stream #.*?Video:.*?(\d{2,5})x(\d{2,5})", sortie)
    if not duree or not video:
        raise ErreurMedia("Fichier illisible ou sans piste vidéo.")
    fps = re.search(r"(\d+(?:\.\d+)?) fps", sortie)
    h, m, s = duree.groups()
    return InfosVideo(
        duree=int(h) * 3600 + int(m) * 60 + float(s),
        largeur=int(video.group(1)),
        hauteur=int(video.group(2)),
        images_par_seconde=float(fps.group(1)) if fps else 0.0,
        a_audio=bool(re.search(r"Stream #.*?Audio:", sortie)),
    )


def dimensions_reduites(largeur: int, hauteur: int, cible: int = 192) -> tuple[int, int]:
    h = max(8, round(cible * hauteur / max(1, largeur) / 2) * 2)
    return cible, h


def images_grises(chemin: Path, frequence: float = 10, largeur_cible: int = 192) -> Iterator[np.ndarray]:
    """Images en niveaux de gris, réduites, à `frequence` images/s."""
    info = infos(chemin)
    w, h = dimensions_reduites(info.largeur, info.hauteur, largeur_cible)
    commande = [FFMPEG, "-hide_banner", "-loglevel", "error", "-i", str(chemin), "-an",
                "-vf", f"fps={frequence},scale={w}:{h},format=gray",
                "-f", "rawvideo", "-pix_fmt", "gray", "-"]
    processus = subprocess.Popen(commande, stdout=subprocess.PIPE)
    taille = w * h
    try:
        while True:
            brut = processus.stdout.read(taille)
            if len(brut) < taille:
                break
            yield np.frombuffer(brut, dtype=np.uint8).reshape(h, w)
    finally:
        processus.stdout.close()
        processus.wait()


def audio_mono(chemin: Path, frequence: int = 11_025) -> np.ndarray:
    """Piste audio mixée en mono, flottants 32 bits (~2,6 Mo par minute)."""
    commande = [FFMPEG, "-hide_banner", "-loglevel", "error", "-i", str(chemin), "-vn",
                "-ac", "1", "-ar", str(frequence), "-f", "f32le", "-"]
    resultat = subprocess.run(commande, capture_output=True)
    if resultat.returncode != 0:
        return np.zeros(0, dtype=np.float32)
    return np.frombuffer(resultat.stdout, dtype=np.float32)


def image_jpeg(chemin: Path, instant: float, largeur: int = 1280) -> bytes:
    """Image à `instant` (s), en JPEG, largeur plafonnée (~1 200 jetons en 1280×720)."""
    commande = [FFMPEG, "-hide_banner", "-loglevel", "error", "-ss", f"{max(0.0, instant):.3f}",
                "-i", str(chemin), "-frames:v", "1", "-vf", f"scale='min({largeur},iw)':-2",
                "-q:v", "3", "-f", "image2pipe", "-vcodec", "mjpeg", "-"]
    resultat = subprocess.run(commande, capture_output=True)
    if resultat.returncode != 0 or not resultat.stdout:
        raise ErreurMedia(f"Image introuvable à {instant:.1f} s.")
    return resultat.stdout
