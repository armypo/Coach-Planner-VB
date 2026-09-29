import numpy as np

from playco_web.detection import (Echange, ParametresDetecteur, Sifflet, affiner_bornes,
                                  detecter_echanges, detecter_sifflets, mesurer_mouvement)


def texture(l, h, ox=0.0, oy=0.0, clair=False):
    y, x = np.mgrid[0:h, 0:l].astype(np.float64)
    x, y = x + ox, y + oy
    base = 200.0 if clair else 120.0
    v = base + 40 * np.sin(x / 9) + 30 * np.cos(y / 7) + 20 * np.sin((x + y) / 13)
    return np.clip(v, 0, 255).astype(np.uint8)


def simuler_match(graine=1, n=40, f=10.0, amplitude_fin=1.0):
    """Même simulation que le package Swift : échanges, taps, activité bruitée."""
    rng = np.random.default_rng(graine)
    echanges, t = [], 5.0
    for _ in range(n):
        d = t + rng.uniform(8, 20)
        fi = d + rng.uniform(4, 14)
        echanges.append((d, fi))
        t = fi
    total = int((echanges[-1][1] + 15) * f)
    v = 0.1 + 0.1 * rng.random(total)
    for d, fi in echanges:
        a, b = int(d * f), min(total, int(fi * f))
        v[a:b] = 1.0 + 0.3 * rng.random(b - a)
        m = (a + b) // 2
        v[m:m + 4] = 0.15
    for k, (d, _) in enumerate(echanges):
        if k % 3 == 0:
            a = int((d - 5) * f)
            v[a:a + 5] = 0.9
    if amplitude_fin != 1.0:
        debut = int((echanges[n // 2][0] - 6) * f)
        zone = v[debut:] > 0.2
        v[debut:][zone] = 0.15 + (v[debut:][zone] - 0.15) * amplitude_fin
    return echanges, v


def rappel(detectes, verites, tolerance=1.0):
    restantes = list(detectes)
    trouves = 0
    for vraie in verites:
        proches = [x for x in restantes if abs(x - vraie) <= tolerance]
        if proches:
            restantes.remove(min(proches, key=lambda x: abs(x - vraie)))
            trouves += 1
    return trouves / len(verites), (len(detectes) - trouves)


def test_panoramique_compense():
    a = texture(64, 48)
    b = texture(64, 48, ox=3, oy=-2)
    m = mesurer_mouvement(a, b)
    assert (m.dx, m.dy) == (-3, 2)
    assert m.ecart_residuel < 0.001
    assert m.ecart_brut > 0.02
    assert not m.est_coupure


def test_coupure_detectee():
    assert mesurer_mouvement(texture(64, 48), texture(64, 48, clair=True)).est_coupure
    assert not mesurer_mouvement(texture(64, 48), texture(64, 48, ox=4)).est_coupure


def test_echanges_retrouves():
    for graine in (1, 7, 42):
        verites, signal = simuler_match(graine)
        detectes = detecter_echanges(signal, 10.0)
        r, faux = rappel([e.fin for e in detectes], [fi for _, fi in verites])
        assert r >= 0.95 and faux <= 2


def test_seuils_locaux_suivent_un_changement_de_plan():
    verites, signal = simuler_match(21, amplitude_fin=0.35)
    fins = [fi for _, fi in verites]
    r_global, _ = rappel([e.fin for e in detecter_echanges(signal, 10.0, ParametresDetecteur(fenetre_locale=None))], fins)
    r_local, faux = rappel([e.fin for e in detecter_echanges(signal, 10.0)], fins)
    assert r_global < 0.7
    assert r_local >= 0.9 and faux <= 4


def test_sifflets():
    fs = 11_025
    rng = np.random.default_rng(2026)
    t = np.arange(10 * fs) / fs
    x = rng.uniform(-0.1, 0.1, t.size)
    for a, b in ((2.0, 2.4), (6.0, 6.8)):
        zone = (t >= a) & (t < b)
        x[zone] += 0.5 * np.sin(2 * np.pi * 3150 * t[zone])
    voix = (t >= 4) & (t < 5)
    x[voix] += 0.8 * np.sin(2 * np.pi * 500 * t[voix])
    s = detecter_sifflets(x, fs)
    assert len(s) == 2
    assert abs(s[0].debut - 2.0) <= 0.05 and abs(s[1].fin - 6.8) <= 0.05
    assert abs(s[0].frequence - 3150) <= 50


def test_fin_recalee_sur_le_sifflet():
    e = affiner_bornes([Echange(10, 20.4, 1), Echange(40, 50, 1)], [Sifflet(20.0, 20.4, 3150, 0.9), Sifflet(9.0, 9.4, 3150, 0.9)])
    assert [x.fin for x in e] == [20.0, 50]
