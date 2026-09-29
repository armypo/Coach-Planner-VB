"""Persistance des analyses : un dossier par analyse avec `etat.json`
(progression) et `resultat.json` (rapport complet)."""

from __future__ import annotations

import json
import os
import re
import uuid
from datetime import datetime, timezone
from pathlib import Path

ID_VALIDE = re.compile(r"^[0-9a-f]{12}$")


class Stockage:
    def __init__(self, racine: Path | None = None):
        self.racine = Path(racine or os.environ.get("PLAYCO_DONNEES", Path(__file__).parent.parent / "donnees"))
        self.racine.mkdir(parents=True, exist_ok=True)

    def nouvel_id(self) -> str:
        return uuid.uuid4().hex[:12]

    def dossier(self, id_analyse: str) -> Path:
        if not ID_VALIDE.match(id_analyse):
            raise KeyError(id_analyse)
        return self.racine / id_analyse

    def _ecrire(self, chemin: Path, contenu: dict) -> None:
        chemin.parent.mkdir(parents=True, exist_ok=True)
        temporaire = chemin.with_suffix(".tmp")
        temporaire.write_text(json.dumps(contenu, ensure_ascii=False), encoding="utf-8")
        temporaire.replace(chemin)

    def _lire(self, chemin: Path) -> dict | None:
        try:
            return json.loads(chemin.read_text(encoding="utf-8"))
        except (FileNotFoundError, json.JSONDecodeError):
            return None

    def creer(self, source: dict) -> str:
        id_analyse = self.nouvel_id()
        self._ecrire(self.dossier(id_analyse) / "etat.json", {
            "id": id_analyse, "statut": "en_attente", "etape": "En attente", "progression": 0.0,
            "message": None, "source": source,
            "cree_le": datetime.now(timezone.utc).isoformat(timespec="seconds")})
        return id_analyse

    def maj_etat(self, id_analyse: str, **champs) -> None:
        etat = self.lire_etat(id_analyse) or {"id": id_analyse}
        self._ecrire(self.dossier(id_analyse) / "etat.json", etat | champs)

    def lire_etat(self, id_analyse: str) -> dict | None:
        return self._lire(self.dossier(id_analyse) / "etat.json")

    def ecrire_resultat(self, id_analyse: str, resultat: dict) -> None:
        self._ecrire(self.dossier(id_analyse) / "resultat.json", resultat)

    def lire_resultat(self, id_analyse: str) -> dict | None:
        return self._lire(self.dossier(id_analyse) / "resultat.json")

    def lister(self) -> list[dict]:
        etats = [self._lire(d / "etat.json") for d in self.racine.iterdir()
                 if d.is_dir() and ID_VALIDE.match(d.name)]
        return sorted((e for e in etats if e), key=lambda e: e.get("cree_le", ""), reverse=True)
