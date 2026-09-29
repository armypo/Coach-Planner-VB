import json

from playco_web.__main__ import main


def test_cli_analyse_un_fichier(video_match, tmp_path, monkeypatch, capsys):
    monkeypatch.setenv("PLAYCO_IA", "factice")
    sortie = tmp_path / "rapport.json"
    assert main([str(video_match), "-o", str(sortie)]) == 0
    rapport = json.loads(sortie.read_text(encoding="utf-8"))
    assert len(rapport["echanges"]) == 2 and rapport["analyse_ia"]["moteur"] == "factice"
    assert "2 échanges" in capsys.readouterr().out


def test_resume_markdown(video_match, tmp_path, monkeypatch):
    from playco_web.resume import resume

    monkeypatch.setenv("PLAYCO_IA", "aucune")
    sortie = tmp_path / "rapport.json"
    main([str(video_match), "-o", str(sortie)])
    texte = resume(json.loads(sortie.read_text(encoding="utf-8")))
    assert "| Échanges | 2 |" in texte and "aucune (signal seul)" in texte and "ESTIMÉ" not in texte
