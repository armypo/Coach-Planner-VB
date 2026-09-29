"""Métriques et tendances d'un match, calculées par le code (jamais par le
modèle) :
- MESURÉ par le signal : échanges, durées, temps de jeu, rythme, sets estimés ;
- ESTIMÉ par l'IA échange par échange : points, service, réception, sideout,
  fins d'échange, attaques, séries, tendances.

Les équipes changent de camp à chaque set : les totaux « par équipe » font
l'hypothèse d'un changement de camp entre chaque set (équipe 1 = camp A aux
sets impairs)."""

from __future__ import annotations

import statistics
from collections import Counter

PAUSE_ENTRE_SETS = 120.0   # s — ESTIMÉ (un temps mort dure ~30-60 s)
FENETRE_TENDANCE = 10      # échanges


def _moyenne(v: list[float]) -> float | None:
    return round(statistics.fmean(v), 2) if v else None


def _pct(n: int, d: int) -> float | None:
    return round(100 * n / d, 1) if d else None


def decouper_sets(echanges: list[dict], pause: float = PAUSE_ENTRE_SETS) -> list[list[int]]:
    """Indices des échanges par set : une pause ≥ `pause` s sépare deux sets."""
    sets: list[list[int]] = []
    for i, e in enumerate(echanges):
        if not sets or e["debut"] - echanges[i - 1]["fin"] >= pause:
            sets.append([])
        sets[-1].append(i)
    return sets


def _stats_temps(duree_video: float, echanges: list[dict]) -> dict:
    durees = [e["duree"] for e in echanges]
    pauses = [b["debut"] - a["fin"] for a, b in zip(echanges, echanges[1:])]
    pauses_courtes = [p for p in pauses if p < PAUSE_ENTRE_SETS]
    jeu = sum(durees)
    return {
        "duree_video": round(duree_video, 1),
        "nombre_echanges": len(echanges),
        "duree_moyenne": _moyenne(durees),
        "duree_mediane": round(statistics.median(durees), 2) if durees else None,
        "duree_max": round(max(durees), 2) if durees else None,
        "temps_de_jeu": round(jeu, 1),
        "part_de_jeu_pct": _pct(jeu, duree_video) if duree_video else None,
        "temps_mort_moyen": _moyenne(pauses_courtes),
        "echanges_par_minute": round(len(echanges) / (duree_video / 60), 2) if duree_video else None,
    }


def _camp_vide() -> dict:
    return {"points": 0, "services": 0, "points_au_service": 0, "receptions": 0, "sideouts": 0,
            "aces": 0, "erreurs_service": 0, "kills": 0, "blocs_gagnants": 0, "erreurs_attaque": 0,
            "erreurs_reception": 0, "fautes": 0, "serie_max": 0,
            "types_service": Counter(), "zones_attaque": Counter(), "types_attaque": Counter(),
            "_receptions_qualite": []}


def _adversaire(camp: str) -> str | None:
    return {"A": "B", "B": "A"}.get(camp)


def _accumuler(stats: dict[str, dict], analyses: list[dict]) -> None:
    serie_camp, serie = None, 0
    for a in analyses:
        serveur, gagnant, fin = a["camp_au_service"], a["camp_gagnant"], a["fin"]
        if serveur in stats:
            s = stats[serveur]
            s["services"] += 1
            s["types_service"][a["type_service"]] += 1
            if fin == "ace" and gagnant == serveur:
                s["aces"] += 1
            if fin == "erreur_service":
                s["erreurs_service"] += 1
            receveur = _adversaire(serveur)
            stats[receveur]["receptions"] += 1
            if a.get("qualite_reception") is not None:
                stats[receveur]["_receptions_qualite"].append(a["qualite_reception"])
            if fin == "erreur_reception":
                stats[receveur]["erreurs_reception"] += 1
            if gagnant == serveur:
                s["points_au_service"] += 1
            elif gagnant == receveur:
                stats[receveur]["sideouts"] += 1
        if gagnant in stats:
            g = stats[gagnant]
            g["points"] += 1
            if fin == "kill":
                g["kills"] += 1
                g["zones_attaque"][a["zone_attaque_finale"]] += 1
                g["types_attaque"][a["type_attaque_finale"]] += 1
            elif fin == "bloc_gagnant":
                g["blocs_gagnants"] += 1
            perdant = _adversaire(gagnant)
            if fin == "erreur_attaque":
                stats[perdant]["erreurs_attaque"] += 1
                stats[perdant]["zones_attaque"][a["zone_attaque_finale"]] += 1
                stats[perdant]["types_attaque"][a["type_attaque_finale"]] += 1
            elif fin in ("faute", "ballon_hors"):
                stats[perdant]["fautes"] += 1
            serie = serie + 1 if gagnant == serie_camp else 1
            serie_camp = gagnant
            g["serie_max"] = max(g["serie_max"], serie)


def _finaliser(s: dict) -> dict:
    qualites = s.pop("_receptions_qualite")
    return s | {
        "sideout_pct": _pct(s["sideouts"], s["receptions"]),
        "pct_points_au_service": _pct(s["points_au_service"], s["services"]),
        "ace_pct": _pct(s["aces"], s["services"]),
        "erreur_service_pct": _pct(s["erreurs_service"], s["services"]),
        "qualite_reception_moyenne": _moyenne(qualites),
        "types_service": dict(s["types_service"]),
        "zones_attaque": dict(s["zones_attaque"]),
        "types_attaque": dict(s["types_attaque"]),
    }


def _stats_camps(analyses: list[dict]) -> dict:
    stats = {"A": _camp_vide(), "B": _camp_vide()}
    _accumuler(stats, analyses)
    return {camp: _finaliser(s) for camp, s in stats.items()}


def _pente_par_heure(x: list[float], y: list[float]) -> float | None:
    if len(x) < 3:
        return None
    mx, my = statistics.fmean(x), statistics.fmean(y)
    sxx = sum((a - mx) ** 2 for a in x)
    if sxx == 0:
        return None
    return round(sum((a - mx) * (b - my) for a, b in zip(x, y)) / sxx * 3600, 2)


def calculer(duree_video: float, echanges: list[dict]) -> dict:
    """`echanges` : dicts {debut, fin, duree, analyse (dict | None)} triés."""
    sets = decouper_sets(echanges)
    resultat: dict = {"temps": _stats_temps(duree_video, echanges), "sets": [], "ia": None}

    analyses_ok = [(i, e["analyse"]) for i, e in enumerate(echanges) if e.get("analyse")]
    for numero, indices in enumerate(sets, start=1):
        sous = [echanges[i] for i in indices]
        bloc = {"numero": numero, "debut": round(sous[0]["debut"], 1), "fin": round(sous[-1]["fin"], 1),
                "temps": _stats_temps(sous[-1]["fin"] - sous[0]["debut"], sous)}
        analyses_set = [e["analyse"] for e in sous if e.get("analyse")]
        if analyses_set:
            bloc["camps"] = _stats_camps(analyses_set)
            bloc["score"] = {c: bloc["camps"][c]["points"] for c in ("A", "B")}
        resultat["sets"].append(bloc)

    if not analyses_ok:
        return resultat

    analyses = [a for _, a in analyses_ok]
    ia: dict = {
        "echanges_analyses": len(analyses),
        "camps": _stats_camps(analyses),
        "fins": dict(Counter(a["fin"] for a in analyses)),
        "contacts_moyens": _moyenne([a["nombre_contacts"] for a in analyses]),
        "confiance": dict(Counter(a["confiance"] for a in analyses)),
    }

    # Hypothèse : changement de camp à chaque set (équipe 1 = camp A aux sets impairs).
    equipes = {"equipe_1": [], "equipe_2": []}
    set_de = {i: n for n, indices in enumerate(sets) for i in indices}
    renommees = []
    for i, a in analyses_ok:
        impair = set_de[i] % 2 == 0
        table = {"A": "A" if impair else "B", "B": "B" if impair else "A", "inconnu": "inconnu"}
        renommees.append(a | {"camp_au_service": table[a["camp_au_service"]],
                              "camp_gagnant": table[a["camp_gagnant"]]})
    par_equipe = _stats_camps(renommees)
    equipes["equipe_1"], equipes["equipe_2"] = par_equipe["A"], par_equipe["B"]
    ia["equipes_hypothese_changement_de_camp"] = equipes

    # Progression du score par set, sideout glissant, évolution de la durée.
    progression, glissant = [], []
    fenetre: list[tuple[str, str]] = []
    for n, indices in enumerate(sets, start=1):
        score = {"A": 0, "B": 0}
        for i in indices:
            a = echanges[i].get("analyse")
            if not a:
                continue
            if a["camp_gagnant"] in score:
                score[a["camp_gagnant"]] += 1
            progression.append({"set": n, "t": round(echanges[i]["fin"], 1),
                                "A": score["A"], "B": score["B"], "gagnant": a["camp_gagnant"]})
            fenetre.append((a["camp_au_service"], a["camp_gagnant"]))
            fenetre = fenetre[-FENETRE_TENDANCE:]
            point = {"t": round(echanges[i]["fin"], 1)}
            for camp in ("A", "B"):
                recus = [g for s, g in fenetre if _adversaire(s) == camp]
                point[f"sideout_{camp}"] = _pct(sum(g == camp for g in recus), len(recus))
            glissant.append(point)

    ia["tendances"] = {
        "progression_score": progression,
        "sideout_glissant": glissant,
        "duree_echange_pente_s_par_heure": _pente_par_heure(
            [e["debut"] for e in echanges], [e["duree"] for e in echanges]),
    }
    resultat["ia"] = ia
    return resultat
