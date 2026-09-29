import subprocess
import sys
from pathlib import Path

import numpy as np
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from playco_web.media import FFMPEG  # noqa: E402


def generer_match(chemin: Path, duree: float = 14.0, fps: int = 10,
                  actifs=((2.0, 5.0), (8.0, 11.0)), sifflets=((5.0, 5.4), (11.0, 11.4)),
                  panoramique: float = 0.0) -> Path:
    """Vidéo H.264 + audio AAC : fond texturé fixe (ou qui défile), carré
    blanc mobile pendant les échanges, coups de sifflet à 3 150 Hz."""
    rng = np.random.default_rng(7)
    largeur, hauteur = 320, 180
    fond = rng.integers(60, 91, size=(hauteur, largeur * 3), dtype=np.uint8)
    images = []
    for i in range(int(duree * fps)):
        t = i / fps
        x0 = int(i * panoramique) % (largeur * 2)
        image = fond[:, x0:x0 + largeur].copy()
        if any(a <= t <= b for a, b in actifs):
            cx, cy = (i * 14) % (largeur - 40), (i * 10) % (hauteur - 40)
            image[cy:cy + 40, cx:cx + 40] = 255
        images.append(image)
    brut_video = chemin.with_suffix(".gray")
    brut_video.write_bytes(np.stack(images).tobytes())

    fs = 11_025
    t = np.arange(int(duree * fs)) / fs
    audio = rng.uniform(-0.05, 0.05, size=t.size)
    for a, b in sifflets:
        zone = (t >= a) & (t < b)
        audio[zone] += 0.5 * np.sin(2 * np.pi * 3150 * t[zone])
    brut_audio = chemin.with_suffix(".f32")
    brut_audio.write_bytes(audio.astype(np.float32).tobytes())

    base = [FFMPEG, "-hide_banner", "-loglevel", "error", "-y",
            "-f", "rawvideo", "-pix_fmt", "gray", "-s", f"{largeur}x{hauteur}", "-r", str(fps), "-i", str(brut_video),
            "-f", "f32le", "-ar", str(fs), "-ac", "1", "-i", str(brut_audio)]
    for codecs in (["-c:v", "libx264", "-pix_fmt", "yuv420p"], ["-c:v", "mpeg4", "-q:v", "3"]):
        if subprocess.run(base + codecs + ["-c:a", "aac", "-shortest", str(chemin)]).returncode == 0:
            return chemin
    raise RuntimeError("ffmpeg n'a pas pu générer la vidéo de test")


@pytest.fixture(scope="session")
def video_match(tmp_path_factory) -> Path:
    return generer_match(tmp_path_factory.mktemp("media") / "match.mp4")
