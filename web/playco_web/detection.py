"""Détection des échanges (image) et des coups de sifflet (son).

Portage numpy des algorithmes du package Swift `Modules/PlaycoVideo`
(mêmes principes, mêmes seuils ESTIMÉS) :
- activité = écart RÉSIDUEL entre images successives une fois le mouvement de
  la caméra retiré ; les coupures de montage ne comptent pas ;
- échanges = hystérésis sur l'activité lissée, seuils LOCAUX (fenêtre
  glissante) avec un plancher ;
- sifflets = pic tonal étroit dans la bande 2-4,5 kHz ;
- la fin d'un échange est recalée sur le sifflet le plus proche.
"""

from __future__ import annotations

import math
from dataclasses import dataclass

import numpy as np

# ---------------------------------------------------------------------------
# Types


@dataclass
class Echange:
    debut: float
    fin: float
    intensite: float

    @property
    def duree(self) -> float:
        return self.fin - self.debut

    def en_dict(self) -> dict:
        return {"debut": round(self.debut, 2), "fin": round(self.fin, 2),
                "intensite": round(self.intensite, 4), "duree": round(self.duree, 2)}


@dataclass
class Sifflet:
    debut: float
    fin: float
    frequence: float
    tonalite: float

    @property
    def duree(self) -> float:
        return self.fin - self.debut


@dataclass
class MesureMouvement:
    ecart_residuel: float
    ecart_brut: float
    dx: int
    dy: int
    est_coupure: bool


@dataclass
class ParametresDetecteur:
    """Valeurs ESTIMÉES — à régler au banc d'essai sur vraie vidéo."""

    lissage: float = 0.5
    quantile_repos: float = 0.3
    quantile_actif: float = 0.97
    fraction_bas: float = 0.25
    fraction_haut: float = 0.6
    duree_minimale: float = 2.0
    fusion_ecart: float = 1.5
    fenetre_locale: float | None = 60.0
    plancher_actif: float = 0.25


SEUIL_COUPURE = 0.4

# ---------------------------------------------------------------------------
# Compensation de caméra


def _ecart(a: np.ndarray, b: np.ndarray, dx: int, dy: int) -> float:
    """Écart absolu moyen (0-1) entre b(x, y) et a(x − dx, y − dy) sur la zone
    commune ; +inf si elle couvre moins de la moitié de l'image."""
    h, w = b.shape
    x0, x1 = max(0, dx), min(w, w + dx)
    y0, y1 = max(0, dy), min(h, h + dy)
    if x1 <= x0 or y1 <= y0:
        return math.inf
    n = (x1 - x0) * (y1 - y0)
    if 2 * n < w * h:
        return math.inf
    zone_b = b[y0:y1, x0:x1]
    zone_a = a[y0 - dy:y1 - dy, x0 - dx:x1 - dx]
    return float(np.abs(zone_b - zone_a).mean()) / 255.0


def reduire(g: np.ndarray) -> np.ndarray:
    """Moitié de la résolution (moyenne entière de blocs 2×2)."""
    h, w = (g.shape[0] // 2) * 2, (g.shape[1] // 2) * 2
    g = g[:h, :w].astype(np.int32)
    return (g[0::2, 0::2] + g[1::2, 0::2] + g[0::2, 1::2] + g[1::2, 1::2]) // 4


def distance_histogrammes(a: np.ndarray, b: np.ndarray) -> float:
    ha = np.bincount((a.astype(np.int32) >> 3).ravel(), minlength=32) / max(1, a.size)
    hb = np.bincount((b.astype(np.int32) >> 3).ravel(), minlength=32) / max(1, b.size)
    return float(np.abs(ha - hb).sum() / 2)


def mesurer_mouvement(a: np.ndarray, b: np.ndarray, rayon: int = 3) -> MesureMouvement | None:
    if a.shape != b.shape or a.shape[0] < 8 or a.shape[1] < 8:
        return None
    a = a.astype(np.int32)
    b = b.astype(np.int32)
    brut = _ecart(a, b, 0, 0)
    coupure = distance_histogrammes(a, b) > SEUIL_COUPURE

    ra, rb = reduire(a), reduire(b)
    meilleur = (0, 0, math.inf)
    for dy in range(-rayon, rayon + 1):
        for dx in range(-rayon, rayon + 1):
            e = _ecart(ra, rb, dx, dy)
            if e < meilleur[2]:
                meilleur = (dx, dy, e)
    cx, cy = 2 * meilleur[0], 2 * meilleur[1]
    fin = (cx, cy, math.inf)
    for dy in range(cy - 1, cy + 2):
        for dx in range(cx - 1, cx + 2):
            e = _ecart(a, b, dx, dy)
            if e < fin[2]:
                fin = (dx, dy, e)
    residuel = min(fin[2], brut)
    compense = residuel < brut
    return MesureMouvement(residuel, brut, fin[0] if compense else 0, fin[1] if compense else 0, coupure)


def signal_activite(images, compenser_camera: bool = True) -> np.ndarray:
    """Activité (0-1) par image à partir d'images en niveaux de gris
    successives. La première valeur et les coupures sont comblées par la
    valeur précédente."""
    valeurs: list[float] = []
    precedente = None
    for image in images:
        valeur = math.nan
        if precedente is not None:
            m = mesurer_mouvement(precedente, image)
            if m is not None:
                if compenser_camera:
                    valeur = math.nan if m.est_coupure else m.ecart_residuel
                else:
                    valeur = m.ecart_brut
        valeurs.append(valeur)
        precedente = image
    return combler(np.array(valeurs, dtype=np.float64))


def combler(v: np.ndarray) -> np.ndarray:
    sortie = v.copy()
    derniere = 0.0
    for i, x in enumerate(sortie):
        if math.isnan(x):
            sortie[i] = derniere
        else:
            derniere = x
    return sortie


# ---------------------------------------------------------------------------
# Échanges


def moyenne_mobile(v: np.ndarray, fenetre: int) -> np.ndarray:
    """Moyenne mobile centrée, fenêtre tronquée aux bords."""
    n = len(v)
    if fenetre <= 1 or n == 0:
        return v.astype(np.float64)
    cumul = np.concatenate([[0.0], np.cumsum(v, dtype=np.float64)])
    demi = fenetre // 2
    i = np.arange(n)
    a = np.maximum(0, i - demi)
    b = np.minimum(n, i - demi + fenetre)
    return (cumul[b] - cumul[a]) / (b - a)


def _seuils(lisse: np.ndarray, frequence: float, p: ParametresDetecteur):
    n = len(lisse)
    repos_g = float(np.quantile(lisse, p.quantile_repos))
    actif_g = float(np.quantile(lisse, p.quantile_actif))
    if actif_g <= repos_g:
        return None

    def niveaux(repos: float, actif: float) -> tuple[float, float]:
        return repos + p.fraction_bas * (actif - repos), repos + p.fraction_haut * (actif - repos)

    if not p.fenetre_locale or p.fenetre_locale <= 0:
        b, h = niveaux(repos_g, actif_g)
        return np.full(n, b), np.full(n, h)

    largeur = max(2, int(p.fenetre_locale * frequence))
    bloc = max(1, largeur // 4)
    plancher = repos_g + p.plancher_actif * (actif_g - repos_g)
    bas, haut = np.empty(n), np.empty(n)
    for debut in range(0, n, bloc):
        fin = min(n, debut + bloc)
        centre = (debut + fin) // 2
        tranche = lisse[max(0, centre - largeur // 2):min(n, centre + largeur // 2 + 1)]
        repos = min(float(np.quantile(tranche, p.quantile_repos)), plancher)
        actif = max(float(np.quantile(tranche, p.quantile_actif)), plancher)
        b, h = niveaux(repos, max(actif, repos + 1e-9))
        bas[debut:fin], haut[debut:fin] = b, h
    return bas, haut


def detecter_echanges(valeurs: np.ndarray, frequence: float,
                      p: ParametresDetecteur | None = None) -> list[Echange]:
    p = p or ParametresDetecteur()
    if frequence <= 0 or len(valeurs) == 0:
        return []
    lisse = moyenne_mobile(np.asarray(valeurs, dtype=np.float64), max(1, round(p.lissage * frequence)))
    seuils = _seuils(lisse, frequence, p)
    if seuils is None:
        return []
    bas, haut = seuils

    plages: list[list[int]] = []
    debut = None
    for i, v in enumerate(lisse):
        if debut is not None:
            if v < bas[i]:
                plages.append([debut, i])
                debut = None
        elif v >= haut[i]:
            d = i
            while d > 0 and lisse[d - 1] >= bas[d - 1]:
                d -= 1
            if plages and d < plages[-1][1]:
                d = plages[-1][1]
            debut = d
    if debut is not None:
        plages.append([debut, len(lisse)])

    ecart = round(p.fusion_ecart * frequence)
    fusionnees: list[list[int]] = []
    for plage in plages:
        if fusionnees and plage[0] - fusionnees[-1][1] < ecart:
            fusionnees[-1][1] = plage[1]
        else:
            fusionnees.append(plage)

    resultat = []
    for a, b in fusionnees:
        d, f = a / frequence, b / frequence
        if f - d >= p.duree_minimale:
            resultat.append(Echange(d, f, float(lisse[a:b].mean())))
    return resultat


# ---------------------------------------------------------------------------
# Sifflets


def detecter_sifflets(x: np.ndarray, fs: float, bande: tuple[float, float] = (2000, 4500),
                      trame: float = 0.023, seuil_tonalite: float = 0.35,
                      energie_minimale: float = 0.01, duree_minimale: float = 0.12,
                      fusion_ecart: float = 0.1, lot: int = 20_000) -> list[Sifflet]:
    if fs <= 0 or bande[1] >= fs / 2:
        return []
    taille = 1
    while taille < max(1, int(trame * fs)):
        taille <<= 1
    pas = taille // 2
    x = np.asarray(x, dtype=np.float64)
    if len(x) < taille:
        return []
    resolution = fs / taille
    case_basse = max(1, int(bande[0] / resolution))
    case_haute = min(taille // 2 - 2, math.ceil(bande[1] / resolution))
    if case_basse >= case_haute:
        return []
    hann = 0.5 - 0.5 * np.cos(2 * np.pi * np.arange(taille) / taille)
    n_trames = 1 + (len(x) - taille) // pas
    trames = np.lib.stride_tricks.sliding_window_view(x, taille)[::pas][:n_trames]

    positives: list[tuple[int, float, float]] = []
    for depart in range(0, n_trames, lot):
        bloc = trames[depart:depart + lot]
        rms = np.sqrt((bloc ** 2).mean(axis=1))
        puissance = np.abs(np.fft.rfft(bloc * hann, axis=1)) ** 2
        total = puissance[:, 1:taille // 2].sum(axis=1)
        pic = np.argmax(puissance[:, case_basse:case_haute + 1], axis=1) + case_basse
        lignes = np.arange(len(bloc))
        concentree = puissance[lignes, pic - 1] + puissance[lignes, pic] + puissance[lignes, pic + 1]
        tonalite = np.divide(concentree, total, out=np.zeros_like(total), where=total > 0)
        ok = (rms >= energie_minimale) & (tonalite >= seuil_tonalite)
        for i in np.nonzero(ok)[0]:
            positives.append((depart + int(i), float(tonalite[i]), float(pic[i] * resolution)))

    duree_trame = taille / fs
    sifflets: list[Sifflet] = []
    courant: list[tuple[int, float, float]] = []

    def clore():
        if not courant:
            return
        nouveau = Sifflet(courant[0][0] * pas / fs, courant[-1][0] * pas / fs + duree_trame,
                          float(np.mean([c[2] for c in courant])), float(np.mean([c[1] for c in courant])))
        if sifflets and nouveau.debut - sifflets[-1].fin <= fusion_ecart:
            sifflets[-1].fin = nouveau.fin
        else:
            sifflets.append(nouveau)
        courant.clear()

    for trame_positive in positives:
        if courant and trame_positive[0] != courant[-1][0] + 1:
            clore()
        courant.append(trame_positive)
    clore()
    return [s for s in sifflets if s.duree >= duree_minimale]


def affiner_bornes(echanges: list[Echange], sifflets: list[Sifflet], tolerance: float = 1.5) -> list[Echange]:
    """Recale la fin de chaque échange sur le début du sifflet le plus proche."""
    disponibles = sorted(sifflets, key=lambda s: s.debut)
    resultat = []
    for e in sorted(echanges, key=lambda e: e.debut):
        candidats = [(abs(s.debut - e.fin), i) for i, s in enumerate(disponibles)
                     if s.debut > e.debut and abs(s.debut - e.fin) <= tolerance]
        if not candidats:
            resultat.append(e)
            continue
        _, i = min(candidats)
        resultat.append(Echange(e.debut, disponibles.pop(i).debut, e.intensite))
    return resultat
