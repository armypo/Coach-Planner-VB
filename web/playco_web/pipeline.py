"""Chaîne complète : vidéo → échanges (image + son) → analyse IA de chaque
échange (en parallèle) → métriques et tendances → synthèse IA."""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Callable

from . import media
from .analyse_ia import AnalyseurIA
from .detection import (ParametresDetecteur, affiner_bornes, detecter_echanges,
                        detecter_sifflets, signal_activite)
from .metriques import calculer
from .source import VideoSource

Progression = Callable[[str, float], None]


@dataclass
class OptionsAnalyse:
    frequence: float = 10.0
    images_min: int = 4
    images_max: int = 10
    appels_ia_paralleles: int = 4
    echanges_ia_max: int | None = None
    compenser_camera: bool = True


def instants_echange(debut: float, fin: float, options: OptionsAnalyse) -> list[float]:
    """Images réparties du service (un peu avant) à la fin (un peu après) :
    ~1 image / 1,2 s, bornées à [images_min, images_max]."""
    a, b = max(0.0, debut - 0.5), fin + 0.3
    n = max(options.images_min, min(options.images_max, round((b - a) / 1.2) + 1))
    return [round(a + (b - a) * k / (n - 1), 2) for k in range(n)]


def analyser_video(video: VideoSource, ia: AnalyseurIA | None,
                   progression: Progression = lambda etape, part: None,
                   options: OptionsAnalyse | None = None) -> dict:
    options = options or OptionsAnalyse()
    info = media.infos(video.chemin)

    # 1. Activité visuelle → échanges.
    attendu = max(1, int(info.duree * options.frequence))
    compte = 0

    def images_suivies():
        nonlocal compte
        for image in media.images_grises(video.chemin, options.frequence):
            compte += 1
            if compte % 250 == 0:
                progression("Détection des échanges (image)", 0.05 + 0.35 * min(1.0, compte / attendu))
            yield image

    activite = signal_activite(images_suivies(), compenser_camera=options.compenser_camera)
    echanges = detecter_echanges(activite, options.frequence, ParametresDetecteur())

    # 2. Son → sifflets → fin des échanges recalée.
    sifflets = []
    if info.a_audio:
        progression("Détection des sifflets (son)", 0.42)
        sifflets = detecter_sifflets(media.audio_mono(video.chemin), 11_025)
        echanges = affiner_bornes(echanges, sifflets)
    lignes = [{"numero": k, **e.en_dict(), "analyse": None, "erreur": None}
              for k, e in enumerate(echanges, start=1)]

    # 3. Analyse IA de chaque échange.
    erreurs_ia: list[str] = []
    if ia is not None and lignes:
        cibles = lignes[:options.echanges_ia_max] if options.echanges_ia_max else lignes
        faits = 0

        def analyser(ligne: dict) -> dict:
            images = [(t, media.image_jpeg(video.chemin, t))
                      for t in instants_echange(ligne["debut"], ligne["fin"], options)]
            contexte = (f"Échange #{ligne['numero']} — de {ligne['debut']:.1f} s à {ligne['fin']:.1f} s "
                        f"(durée {ligne['duree']:.1f} s) ; vidéo « {video.titre} ».")
            return ia.analyser_echange(images, contexte).model_dump()

        with ThreadPoolExecutor(max_workers=options.appels_ia_paralleles) as pool:
            futurs = {pool.submit(analyser, ligne): ligne for ligne in cibles}
            for futur in as_completed(futurs):
                ligne = futurs[futur]
                try:
                    ligne["analyse"] = futur.result()
                except Exception as erreur:  # une erreur n'arrête pas le match
                    ligne["erreur"] = str(erreur)
                    erreurs_ia.append(f"Échange #{ligne['numero']} : {erreur}")
                faits += 1
                progression(f"Analyse IA des échanges ({faits}/{len(cibles)})", 0.45 + 0.45 * faits / len(cibles))

    # 4. Métriques et tendances (calculées), 5. synthèse IA (rédigée).
    progression("Calcul des métriques", 0.92)
    metriques = calculer(info.duree, lignes)
    synthese = None
    if ia is not None and metriques.get("ia"):
        progression("Synthèse IA", 0.95)
        resume_metriques = {k: v for k, v in metriques.items() if k != "ia"}
        resume_metriques["ia"] = {k: v for k, v in metriques["ia"].items() if k != "tendances"}
        resume_metriques["ia"]["duree_echange_pente_s_par_heure"] = \
            metriques["ia"]["tendances"]["duree_echange_pente_s_par_heure"]
        echantillon = [{"numero": l["numero"], "fin": l["analyse"]["fin"],
                        "camp_gagnant": l["analyse"]["camp_gagnant"],
                        "observations": l["analyse"]["observations"]}
                       for l in lignes if l["analyse"]][:30]
        try:
            synthese = ia.synthetiser(resume_metriques, echantillon).model_dump()
        except Exception as erreur:
            erreurs_ia.append(f"Synthèse : {erreur}")

    progression("Terminé", 1.0)
    return {
        "version": 1,
        "cree_le": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "source": {"titre": video.titre, "id_youtube": video.id_youtube},
        "video": {"duree": round(info.duree, 1), "largeur": info.largeur, "hauteur": info.hauteur,
                  "images_par_seconde": info.images_par_seconde, "audio": info.a_audio},
        "analyse_ia": {"moteur": ia.nom if ia else None,
                       "echanges_analyses": sum(1 for l in lignes if l["analyse"]),
                       "erreurs": erreurs_ia},
        "sifflets": len(sifflets),
        "echanges": lignes,
        "metriques": metriques,
        "synthese": synthese,
    }
