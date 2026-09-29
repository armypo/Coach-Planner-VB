"""Analyse IA technique : Claude (vision) regarde les images de chaque échange
et renvoie une description STRUCTURÉE (JSON validé) ; une synthèse finale
rédige forces, faiblesses, tendances et recommandations à partir des chiffres
calculés par le code (le modèle narre, il ne calcule pas).

Deux analyseurs : `AnalyseurClaude` (API Anthropic, clé dans
ANTHROPIC_API_KEY) et `AnalyseurFactice` (déterministe, pour les tests et la
démonstration sans clé)."""

from __future__ import annotations

import base64
import json
import os
from typing import Literal, Protocol

from pydantic import BaseModel, Field

Camp = Literal["A", "B", "inconnu"]

# ---------------------------------------------------------------------------
# Schémas de sortie


class Action(BaseModel):
    type: Literal["service", "reception", "passe", "attaque", "bloc", "defense", "autre"]
    camp: Camp
    qualite: Literal[0, 1, 2, 3] | None = Field(
        description="0 = faute/ratée, 1 = mauvaise, 2 = correcte, 3 = parfaite ; null si impossible à juger")
    description: str = Field(description="Une phrase courte, en français")


class AnalyseEchange(BaseModel):
    camp_au_service: Camp
    type_service: Literal["flottant", "smash", "saute_flottant", "sous_la_main", "inconnu"]
    actions: list[Action]
    nombre_contacts: int = Field(description="Nombre total de touches de balle estimé dans l'échange")
    fin: Literal["kill", "ace", "erreur_service", "erreur_reception", "erreur_attaque",
                 "bloc_gagnant", "faute", "ballon_hors", "autre", "inconnue"]
    camp_gagnant: Camp
    zone_attaque_finale: Literal["poste_4", "poste_3", "poste_2", "arriere", "aucune", "inconnue"]
    type_attaque_finale: Literal["puissante", "placee", "feinte", "aucune", "inconnue"]
    qualite_reception: Literal[0, 1, 2, 3] | None = Field(
        description="Qualité de la première touche du camp en réception (0-3), null si non visible")
    observations: list[str] = Field(description="2 à 4 observations techniques précises, en français")
    confiance: Literal["faible", "moyenne", "elevee"]


class SyntheseCamp(BaseModel):
    forces: list[str]
    faiblesses: list[str]
    recommandations: list[str]


class SyntheseMatch(BaseModel):
    resume: str
    camp_A: SyntheseCamp
    camp_B: SyntheseCamp
    tendances: list[str]
    points_cles: list[str]


# ---------------------------------------------------------------------------
# Consignes

SYSTEME_ECHANGE = """Tu es analyste vidéo de volleyball (niveau entraîneur universitaire).
On te montre des images successives d'UN échange, horodatées, tirées d'une vidéo de match.

Convention des camps (garde-la identique pour tout le match) :
- si le filet apparaît vertical dans l'image, le camp A est celui de GAUCHE ;
- si le filet apparaît horizontal (caméra derrière une ligne de fond), le camp A est le plus PROCHE de la caméra.

Décris ce que les images montrent réellement : service, réception, passe, attaque, bloc, défense,
qui gagne l'échange et comment il se termine. Qualités sur l'échelle 0-3 du volleyball
(0 faute, 1 mauvaise, 2 correcte, 3 parfaite). Quand une information n'est pas visible,
réponds « inconnu(e) » ou null plutôt que de deviner, et baisse la confiance.
Les observations doivent être techniques et utiles à un entraîneur (placement, timing,
choix d'attaque, couverture, lecture du bloc…), en français."""

SYSTEME_SYNTHESE = """Tu es analyste vidéo de volleyball. On te donne les statistiques d'un match,
CALCULÉES par un programme à partir d'une analyse IA échange par échange (donc estimées),
et un échantillon de descriptions d'échanges.

Rédige en français une synthèse technique pour un entraîneur : résumé, forces, faiblesses et
recommandations par camp (A et B), tendances au fil du match, points clés.
N'utilise QUE les chiffres fournis (ne recalcule pas, n'invente aucun chiffre) et cite-les.
Rappelle-toi que les équipes changent de camp entre les sets : raisonne par set quand c'est pertinent."""


# ---------------------------------------------------------------------------
# Analyseurs


class ErreurIA(Exception):
    pass


class AnalyseurIA(Protocol):
    nom: str

    def analyser_echange(self, images: list[tuple[float, bytes]], contexte: str) -> AnalyseEchange: ...

    def synthetiser(self, metriques: dict, echantillon: list[dict]) -> SyntheseMatch: ...


class AnalyseurClaude:
    """Claude en vision. Le modèle par défaut est claude-opus-5-5 (modifiable
    par PLAYCO_MODELE). Les refus de sécurité passent par le repli serveur
    `fallbacks: "default"`."""

    def __init__(self, modele: str | None = None):
        import anthropic

        self.modele = modele or os.environ.get("PLAYCO_MODELE", "claude-opus-5-5")
        self.nom = f"claude:{self.modele}"
        self._client = anthropic.Anthropic()

    def _parse(self, systeme: str, contenu: list[dict], format_sortie):
        reponse = self._client.beta.messages.parse(
            model=self.modele,
            max_tokens=16_000,
            betas=["server-side-fallback-2026-07-01"],
            fallbacks="default",
            system=systeme,
            messages=[{"role": "user", "content": contenu}],
            output_format=format_sortie,
        )
        if reponse.stop_reason == "refusal":
            raise ErreurIA("Analyse refusée par le modèle.")
        if reponse.parsed_output is None:
            raise ErreurIA(f"Réponse inexploitable (arrêt : {reponse.stop_reason}).")
        return reponse.parsed_output

    def analyser_echange(self, images: list[tuple[float, bytes]], contexte: str) -> AnalyseEchange:
        contenu: list[dict] = [{"type": "text", "text": contexte}]
        for i, (instant, jpeg) in enumerate(images, start=1):
            contenu.append({"type": "text", "text": f"Image {i} — t = {instant:.1f} s"})
            contenu.append({"type": "image", "source": {
                "type": "base64", "media_type": "image/jpeg",
                "data": base64.standard_b64encode(jpeg).decode("ascii")}})
        contenu.append({"type": "text", "text": "Analyse cet échange selon le schéma demandé."})
        return self._parse(SYSTEME_ECHANGE, contenu, AnalyseEchange)

    def synthetiser(self, metriques: dict, echantillon: list[dict]) -> SyntheseMatch:
        texte = ("Statistiques du match (JSON) :\n" + json.dumps(metriques, ensure_ascii=False)
                 + "\n\nÉchantillon d'échanges analysés (JSON) :\n" + json.dumps(echantillon, ensure_ascii=False))
        return self._parse(SYSTEME_SYNTHESE, [{"type": "text", "text": texte}], SyntheseMatch)


class AnalyseurFactice:
    """Réponses déterministes (tests, démonstration sans clé API). Les
    résultats sont marqués « factice » dans le rapport."""

    nom = "factice"

    def analyser_echange(self, images: list[tuple[float, bytes]], contexte: str) -> AnalyseEchange:
        k = int(contexte.split("#")[1].split()[0]) if "#" in contexte else len(images)
        fins = ["kill", "erreur_service", "kill", "ace", "bloc_gagnant", "erreur_attaque"]
        service = "A" if k % 3 else "B"
        gagnant = "A" if k % 5 in (0, 1, 3) else "B"
        return AnalyseEchange(
            camp_au_service=service, type_service="saute_flottant" if k % 2 else "flottant",
            actions=[Action(type="service", camp=service, qualite=2, description="Service dans la zone 1."),
                     Action(type="attaque", camp=gagnant, qualite=3, description="Attaque en poste 4.")],
            nombre_contacts=3 + k % 4, fin=fins[k % len(fins)], camp_gagnant=gagnant,
            zone_attaque_finale=["poste_4", "poste_2", "poste_3", "arriere"][k % 4],
            type_attaque_finale=["puissante", "placee", "feinte"][k % 3],
            qualite_reception=[1, 2, 3][k % 3], observations=["Observation factice."], confiance="moyenne")

    def synthetiser(self, metriques: dict, echantillon: list[dict]) -> SyntheseMatch:
        camp = SyntheseCamp(forces=["(factice)"], faiblesses=["(factice)"], recommandations=["(factice)"])
        return SyntheseMatch(resume="Synthèse factice (aucune clé API).", camp_A=camp, camp_B=camp,
                             tendances=[], points_cles=[])


def analyseur_par_defaut() -> AnalyseurIA | None:
    """Claude si une clé est configurée ; le factice si PLAYCO_IA=factice ;
    sinon aucune analyse IA (le rapport le dit)."""
    choix = os.environ.get("PLAYCO_IA", "auto")
    if choix == "factice":
        return AnalyseurFactice()
    if choix == "aucune":
        return None
    if os.environ.get("ANTHROPIC_API_KEY") or os.environ.get("ANTHROPIC_AUTH_TOKEN"):
        return AnalyseurClaude()
    return None
