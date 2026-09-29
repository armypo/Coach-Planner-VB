from playco_web.metriques import calculer, decouper_sets


def echange(debut, duree, service, gagnant, fin="kill", reception=2, zone="poste_4"):
    return {"debut": debut, "fin": debut + duree, "duree": duree, "analyse": {
        "camp_au_service": service, "camp_gagnant": gagnant, "fin": fin, "type_service": "flottant",
        "nombre_contacts": 4, "zone_attaque_finale": zone, "type_attaque_finale": "puissante",
        "qualite_reception": reception, "observations": [], "confiance": "moyenne", "actions": []}}


def match():
    return [
        # Set 1
        echange(10, 8, "A", "A", fin="ace"),              # point au service A
        echange(30, 6, "A", "B", fin="kill"),             # sideout B
        echange(50, 9, "B", "B", fin="erreur_attaque"),   # point au service B (A rate)
        echange(70, 7, "B", "A", fin="kill", zone="poste_2"),  # sideout A
        # Set 2 (après une pause de 3 min)
        echange(260, 5, "A", "A", fin="bloc_gagnant"),
        echange(280, 5, "A", "A", fin="erreur_service"),  # incohérent volontaire : erreur_service gagnée par A → compte l'erreur au serveur A
    ]


def test_sets_decoupes_par_les_longues_pauses():
    assert decouper_sets(match()) == [[0, 1, 2, 3], [4, 5]]


def test_temps_mesures():
    m = calculer(300, match())
    t = m["temps"]
    assert t["nombre_echanges"] == 6
    assert t["temps_de_jeu"] == 40
    assert t["part_de_jeu_pct"] == 13.3
    assert t["duree_max"] == 9


def test_points_service_sideout_par_camp():
    ia = calculer(300, match())["ia"]
    a, b = ia["camps"]["A"], ia["camps"]["B"]
    assert (a["points"], b["points"]) == (4, 2)
    assert a["services"] == 4 and b["services"] == 2
    assert a["aces"] == 1 and a["erreurs_service"] == 1
    # A reçoit 2 fois (services de B), gagne 1 fois ; B reçoit 4 fois, gagne 1 fois.
    assert a["sideout_pct"] == 50.0
    assert b["sideout_pct"] == 25.0
    assert a["erreurs_attaque"] == 1 and b["kills"] == 1 and a["kills"] == 1
    assert a["zones_attaque"] == {"poste_2": 1, "poste_4": 1}  # kill poste 2 + erreur d'attaque poste 4
    assert a["serie_max"] == 3
    assert ia["fins"]["kill"] == 2


def test_equipes_avec_changement_de_camp():
    ia = calculer(300, match())["ia"]
    e1, e2 = ia["equipes_hypothese_changement_de_camp"].values()
    # Set 1 : équipe 1 = A (2 points) ; set 2 : équipe 1 = B (0 point).
    assert e1["points"] == 2 and e2["points"] == 4


def test_progression_et_sideout_glissant():
    ia = calculer(300, match())["ia"]
    prog = ia["tendances"]["progression_score"]
    assert [(p["set"], p["A"], p["B"]) for p in prog] == [(1, 1, 0), (1, 1, 1), (1, 1, 2), (1, 2, 2), (2, 1, 0), (2, 2, 0)]
    assert len(ia["tendances"]["sideout_glissant"]) == 6


def test_sans_ia():
    lignes = [{"debut": 0, "fin": 5, "duree": 5, "analyse": None}]
    m = calculer(10, lignes)
    assert m["ia"] is None and m["temps"]["nombre_echanges"] == 1
