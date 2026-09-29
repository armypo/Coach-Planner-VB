import time

import pytest
from fastapi.testclient import TestClient

from playco_web.source import id_youtube


@pytest.fixture()
def client(tmp_path, monkeypatch):
    monkeypatch.setenv("PLAYCO_IA", "factice")
    from playco_web import app as module
    from playco_web.stockage import Stockage
    monkeypatch.setattr(module, "stockage", Stockage(tmp_path / "donnees"))
    return TestClient(module.app)


def attendre(client, id_analyse, delai=120):
    fin = time.time() + delai
    while time.time() < fin:
        r = client.get(f"/api/analyses/{id_analyse}").json()
        if r["etat"]["statut"] in ("termine", "erreur"):
            return r
        time.sleep(0.2)
    raise TimeoutError


def test_liens_youtube():
    assert id_youtube("https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=30") == "dQw4w9WgXcQ"
    assert id_youtube("https://youtu.be/dQw4w9WgXcQ") == "dQw4w9WgXcQ"
    assert id_youtube("https://www.youtube.com/shorts/dQw4w9WgXcQ") == "dQw4w9WgXcQ"
    assert id_youtube("https://evil.example.com/watch?v=dQw4w9WgXcQ") is None
    assert id_youtube("file:///etc/passwd") is None
    assert id_youtube("https://www.youtube.com/watch?v=court") is None


def test_lien_refuse(client):
    assert client.post("/api/analyses", json={"url": "https://exemple.com/video.mp4"}).status_code == 400


def test_analyse_complete_d_un_fichier(client, video_match):
    with video_match.open("rb") as f:
        r = client.post("/api/analyses/fichier", files={"fichier": ("match.mp4", f, "video/mp4")})
    assert r.status_code == 202
    id_analyse = r.json()["id"]
    reponse = attendre(client, id_analyse)
    assert reponse["etat"]["statut"] == "termine", reponse["etat"].get("message")

    res = reponse["resultat"]
    echanges = res["echanges"]
    assert len(echanges) == 2
    # Fins recalées sur les sifflets (5,0 s et 11,0 s).
    assert abs(echanges[0]["fin"] - 5.0) <= 0.2 and abs(echanges[1]["fin"] - 11.0) <= 0.2
    assert abs(echanges[0]["debut"] - 2.0) <= 0.6
    assert res["sifflets"] == 2
    assert res["analyse_ia"]["moteur"] == "factice"
    assert all(e["analyse"] for e in echanges)
    assert res["metriques"]["ia"]["echanges_analyses"] == 2
    assert res["synthese"]["resume"]

    assert client.get(f"/api/analyses/{id_analyse}/video").status_code == 200
    historique = client.get("/api/analyses").json()
    assert historique[0]["id"] == id_analyse and historique[0]["resume"]["nombre_echanges"] == 2


def test_analyse_introuvable(client):
    assert client.get("/api/analyses/000000000000").status_code == 404
    assert client.get("/api/analyses/../../etc").status_code == 404
