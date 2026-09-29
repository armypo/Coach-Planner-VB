"use strict";

// ---------------------------------------------------------------------------
// Outils

const $ = (s) => document.querySelector(s);
const esc = (v) => String(v ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const nb = (v, d = 1) => (v === null || v === undefined ? "—" : Number(v).toLocaleString("fr-CA", { maximumFractionDigits: d }));
const pct = (v) => (v === null || v === undefined ? "—" : `${nb(v)} %`);
const horloge = (s) => { s = Math.max(0, Math.floor(s)); return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`; };

const COULEUR = { A: "#3987e5", B: "#d95926", inconnu: "#6b6a64" };
const FINS = {
  kill: "Attaque gagnante", ace: "Ace", erreur_service: "Erreur de service", erreur_reception: "Erreur de réception",
  erreur_attaque: "Erreur d'attaque", bloc_gagnant: "Bloc gagnant", faute: "Faute", ballon_hors: "Ballon hors",
  autre: "Autre", inconnue: "Inconnue",
};
const ZONES = { poste_4: "Poste 4", poste_3: "Poste 3", poste_2: "Poste 2", arriere: "Arrière", aucune: "Aucune", inconnue: "Inconnue" };
const SERVICES = { flottant: "Flottant", smash: "Smashé", saute_flottant: "Sauté-flottant", sous_la_main: "Sous la main", inconnu: "Inconnu" };
const ATTAQUES = { puissante: "Puissante", placee: "Placée", feinte: "Feinte", aucune: "Aucune", inconnue: "Inconnue" };

let graphiques = [];
let suivi = null;

function detruireGraphiques() { graphiques.forEach((g) => g.destroy()); graphiques = []; }

function graphique(canvas, config) {
  if (!window.Chart) return;
  Chart.defaults.color = "#c3c2b7";
  Chart.defaults.borderColor = "rgba(255,255,255,0.08)";
  Chart.defaults.font.family = "system-ui, -apple-system, 'Segoe UI', sans-serif";
  graphiques.push(new Chart(canvas, config));
}

async function api(url, options) {
  const r = await fetch(url, options);
  const corps = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(corps.detail || `Erreur ${r.status}`);
  return corps;
}

// ---------------------------------------------------------------------------
// Lancer et suivre une analyse

function erreurFormulaire(message) {
  const p = $("#erreur-form");
  p.textContent = message || "";
  p.hidden = !message;
}

$("#form-lien").addEventListener("submit", async (e) => {
  e.preventDefault();
  erreurFormulaire();
  try {
    const { id } = await api("/api/analyses", {
      method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ url: $("#lien").value }),
    });
    suivre(id);
  } catch (err) { erreurFormulaire(err.message); }
});

$("#fichier").addEventListener("change", async (e) => {
  const fichier = e.target.files[0];
  if (!fichier) return;
  erreurFormulaire();
  const donnees = new FormData();
  donnees.append("fichier", fichier);
  try {
    $("#progression").hidden = false;
    $("#prog-etape").textContent = "Envoi de la vidéo…";
    const { id } = await api("/api/analyses/fichier", { method: "POST", body: donnees });
    suivre(id);
  } catch (err) { erreurFormulaire(err.message); $("#progression").hidden = true; }
});

function suivre(id) {
  clearTimeout(suivi);
  location.hash = `analyse=${id}`;
  $("#rapport").hidden = true;
  const tour = async () => {
    try {
      const { etat, resultat } = await api(`/api/analyses/${id}`);
      if (etat.statut === "termine") {
        $("#progression").hidden = true;
        afficherRapport(id, etat, resultat);
        chargerHistorique();
        return;
      }
      $("#progression").hidden = false;
      if (etat.statut === "erreur") {
        $("#prog-titre").textContent = "Analyse impossible";
        $("#prog-etape").textContent = etat.message || "";
        $("#prog-barre").style.width = "0";
        chargerHistorique();
        return;
      }
      $("#prog-titre").textContent = "Analyse en cours";
      $("#prog-etape").textContent = etat.etape || "";
      $("#prog-barre").style.width = `${Math.round((etat.progression || 0) * 100)}%`;
      suivi = setTimeout(tour, 1500);
    } catch (err) { erreurFormulaire(err.message); }
  };
  tour();
}

// ---------------------------------------------------------------------------
// Rapport

function lecteur(id, resultat) {
  const yt = resultat.source.id_youtube;
  return yt
    ? `<div class="lecteur"><iframe id="lecteur" allow="autoplay; encrypted-media" allowfullscreen
         src="https://www.youtube-nocookie.com/embed/${esc(yt)}?rel=0"></iframe></div>`
    : `<div class="lecteur"><video id="lecteur" controls preload="metadata" src="/api/analyses/${esc(id)}/video"></video></div>`;
}

function allerA(resultat, t) {
  const el = $("#lecteur");
  if (!el) return;
  if (el.tagName === "VIDEO") { el.currentTime = t; el.play().catch(() => {}); }
  else el.src = `https://www.youtube-nocookie.com/embed/${encodeURIComponent(resultat.source.id_youtube)}?rel=0&autoplay=1&start=${Math.floor(t)}`;
  el.scrollIntoView({ behavior: "smooth", block: "center" });
}

function tuiles(t) {
  const liste = [
    [t.nombre_echanges, "Échanges"], [nb(t.duree_moyenne), "Durée moyenne (s)"], [nb(t.duree_max), "Plus long (s)"],
    [pct(t.part_de_jeu_pct), "Temps de jeu"], [nb(t.echanges_par_minute, 2), "Échanges / minute"],
    [nb(t.temps_mort_moyen), "Temps mort moyen (s)"],
  ];
  return `<div class="tuiles">${liste.map(([v, l]) => `<div class="tuile"><div class="valeur">${esc(v)}</div><div class="libelle">${esc(l)}</div></div>`).join("")}</div>`;
}

const LIGNES_STATS = [
  ["Points", "points", nb], ["Sideout", "sideout_pct", pct], ["Points au service", "pct_points_au_service", pct],
  ["Services", "services", nb], ["Aces", "aces", nb], ["Erreurs de service", "erreurs_service", nb],
  ["Attaques gagnantes", "kills", nb], ["Blocs gagnants", "blocs_gagnants", nb], ["Erreurs d'attaque", "erreurs_attaque", nb],
  ["Erreurs de réception", "erreurs_reception", nb], ["Fautes / ballons hors", "fautes", nb],
  ["Réception moyenne (0-3)", "qualite_reception_moyenne", (v) => nb(v, 2)], ["Plus longue série", "serie_max", nb],
];

function tableauStats(stats, libelles) {
  const [a, b] = libelles;
  return `<div class="tableau-defilant"><table><thead><tr><th></th>
      <th class="nombre"><span class="pastille A"></span>${esc(a)}</th><th class="nombre"><span class="pastille B"></span>${esc(b)}</th></tr></thead>
    <tbody>${LIGNES_STATS.map(([l, k, f]) => `<tr><td>${esc(l)}</td><td class="nombre">${esc(f(stats[0][k]))}</td><td class="nombre">${esc(f(stats[1][k]))}</td></tr>`).join("")}</tbody></table></div>`;
}

function tableauRepartition(titre, libelles, cle, camps) {
  const cles = Object.keys(libelles).filter((k) => camps.some((c) => c[cle][k]));
  if (!cles.length) return "";
  const total = (c) => Object.values(c[cle]).reduce((a, b) => a + b, 0) || 1;
  const cellule = (c, k) => (c[cle][k] ? `${c[cle][k]} (${nb((100 * c[cle][k]) / total(c), 0)} %)` : "—");
  return `<div class="tableau-defilant"><table><thead><tr><th>${esc(titre)}</th>
      <th class="nombre"><span class="pastille A"></span>Camp A</th><th class="nombre"><span class="pastille B"></span>Camp B</th></tr></thead>
    <tbody>${cles.map((k) => `<tr><td>${esc(libelles[k])}</td><td class="nombre">${cellule(camps[0], k)}</td><td class="nombre">${cellule(camps[1], k)}</td></tr>`).join("")}</tbody></table></div>`;
}

function listeTexte(items) {
  return items && items.length ? `<ul class="puces">${items.map((i) => `<li>${esc(i)}</li>`).join("")}</ul>` : `<p class="discret">—</p>`;
}

function synthese(s) {
  if (!s) return "";
  const camp = (nom, c, cle) => `<div><h3><span class="pastille ${cle}"></span>${esc(nom)}</h3>
      <p class="discret">Forces</p>${listeTexte(c.forces)}<p class="discret">Faiblesses</p>${listeTexte(c.faiblesses)}
      <p class="discret">Recommandations</p>${listeTexte(c.recommandations)}</div>`;
  return `<section class="carte"><h2>Synthèse IA</h2><p>${esc(s.resume)}</p>
    <div class="grille-2">${camp("Camp A", s.camp_A, "A")}${camp("Camp B", s.camp_B, "B")}</div>
    <div class="grille-2"><div><h3>Tendances</h3>${listeTexte(s.tendances)}</div><div><h3>Points clés</h3>${listeTexte(s.points_cles)}</div></div></section>`;
}

function tableauEchanges(echanges) {
  const lignes = echanges.map((e) => {
    const a = e.analyse;
    const gagnant = a ? `<span class="pastille ${esc(a.camp_gagnant)}"></span>${esc(a.camp_gagnant)}` : "—";
    return `<tr class="cliquable" data-t="${e.debut}">
      <td class="lien-temps">${horloge(e.debut)}</td><td class="nombre">${nb(e.duree)}</td>
      <td>${a ? esc(a.camp_au_service) + " · " + esc(SERVICES[a.type_service] || a.type_service) : "—"}</td>
      <td>${a ? esc(FINS[a.fin] || a.fin) : esc(e.erreur ? "IA : erreur" : "—")}</td><td>${gagnant}</td>
      <td class="nombre">${a && a.qualite_reception !== null ? esc(a.qualite_reception) : "—"}</td>
      <td>${a ? esc(a.observations.join(" · ")) : ""}</td></tr>`;
  }).join("");
  return `<section class="carte"><h2>Échanges</h2><p class="discret">Touche une ligne pour revoir l'échange.</p>
    <div class="tableau-defilant"><table id="table-echanges"><thead><tr><th>Début</th><th class="nombre">Durée (s)</th><th>Service</th>
    <th>Fin</th><th>Gagnant</th><th class="nombre">Réc.</th><th>Observations IA</th></tr></thead><tbody>${lignes}</tbody></table></div></section>`;
}

function afficherRapport(id, etat, r) {
  detruireGraphiques();
  const m = r.metriques;
  const ia = m.ia;
  const moteur = r.analyse_ia.moteur;
  const badgeIA = moteur
    ? `<span class="badge">Actions et points : ESTIMÉ par IA (${esc(moteur)})</span>`
    : `<span class="badge">Analyse IA indisponible : aucune clé API configurée sur le serveur</span>`;

  const sets = m.sets.map((s) => `<tr><td>Set ${s.numero} (estimé)</td><td>${horloge(s.debut)} – ${horloge(s.fin)}</td>
      <td class="nombre">${s.temps.nombre_echanges}</td><td class="nombre">${nb(s.temps.duree_moyenne)}</td>
      <td class="nombre">${s.score ? `${s.score.A} – ${s.score.B}` : "—"}</td></tr>`).join("");

  let blocIA = "";
  if (ia) {
    blocIA = `
      <section class="carte"><h2>Statistiques (ESTIMÉ par IA)</h2>
        <div class="controles"><label for="vue-stats" class="secondaire">Vue</label>
          <select id="vue-stats"><option value="camps">Par camp (A / B à l'image)</option>
          <option value="equipes">Par équipe (hypothèse : changement de camp à chaque set)</option></select></div>
        <div id="stats"></div>
        <p class="discret">${ia.echanges_analyses} échanges analysés · contacts moyens par échange : ${nb(ia.contacts_moyens)} · pente de la durée des échanges : ${nb(ia.tendances.duree_echange_pente_s_par_heure, 2)} s/heure</p>
      </section>
      <div class="grille-2">
        <section class="carte"><h2>Progression du score</h2>
          <div class="controles"><label for="choix-set" class="secondaire">Set</label><select id="choix-set">${m.sets.map((s) => `<option value="${s.numero}">Set ${s.numero}</option>`).join("")}</select></div>
          <div class="graphique"><canvas id="g-score"></canvas></div></section>
        <section class="carte"><h2>Sideout sur les 10 derniers échanges</h2><div class="graphique"><canvas id="g-sideout"></canvas></div></section>
        <section class="carte"><h2>Comment finissent les échanges</h2><div class="graphique"><canvas id="g-fins"></canvas></div></section>
        <section class="carte"><h2>Zones d'attaque (gagnantes + erreurs)</h2><div class="graphique"><canvas id="g-zones"></canvas></div></section>
      </div>
      <section class="carte"><h2>Service et attaque (ESTIMÉ par IA)</h2><div class="grille-2">
        ${tableauRepartition("Type de service", SERVICES, "types_service", [ia.camps.A, ia.camps.B])}
        ${tableauRepartition("Dernière attaque", ATTAQUES, "types_attaque", [ia.camps.A, ia.camps.B])}</div></section>`;
  }

  $("#rapport").innerHTML = `
    <section class="carte"><h2>${esc(r.source.titre)}</h2>
      <div class="badges"><span class="badge">Durée ${horloge(r.video.duree)}</span>
        <span class="badge">Échanges et temps : MESURÉ par le signal vidéo</span>${badgeIA}
        <span class="badge">${r.sifflets} coups de sifflet détectés</span></div>
      ${r.analyse_ia.erreurs.length ? `<p class="erreur">${esc(r.analyse_ia.erreurs.length)} erreur(s) IA — ${esc(r.analyse_ia.erreurs[0])}</p>` : ""}
    </section>
    <section class="carte">${lecteur(id, r)}</section>
    <section class="carte"><h2>Le match en chiffres (MESURÉ)</h2>${tuiles(m.temps)}</section>
    <section class="carte"><h2>Sets</h2><div class="tableau-defilant"><table><thead><tr><th>Set</th><th>Période</th>
      <th class="nombre">Échanges</th><th class="nombre">Durée moy. (s)</th><th class="nombre">Score A – B</th></tr></thead><tbody>${sets}</tbody></table></div>
      <p class="discret">Sets estimés par les pauses de plus de 2 minutes.</p></section>
    ${blocIA}
    ${synthese(r.synthese)}
    <section class="carte"><h2>Durée des échanges</h2><div class="graphique"><canvas id="g-durees"></canvas></div></section>
    ${tableauEchanges(r.echanges)}`;
  $("#rapport").hidden = false;

  $("#table-echanges").addEventListener("click", (e) => {
    const tr = e.target.closest("tr[data-t]");
    if (tr) allerA(r, Number(tr.dataset.t));
  });

  graphiqueDurees(r);
  if (ia) {
    const vue = () => {
      const equipes = $("#vue-stats").value === "equipes";
      const s = equipes ? ia.equipes_hypothese_changement_de_camp : ia.camps;
      $("#stats").innerHTML = equipes ? tableauStats([s.equipe_1, s.equipe_2], ["Équipe 1", "Équipe 2"])
        : tableauStats([s.A, s.B], ["Camp A", "Camp B"]);
    };
    $("#vue-stats").addEventListener("change", vue);
    vue();
    const score = () => graphiqueScore(ia, Number($("#choix-set").value));
    $("#choix-set").addEventListener("change", score);
    score();
    graphiqueSideout(ia);
    graphiqueFins(r.echanges);
    graphiqueZones(ia);
  }
}

// ---------------------------------------------------------------------------
// Graphiques (bleu = camp A, orange = camp B ; palette validée sur fond sombre)

const axeTemps = { type: "linear", title: { display: true, text: "Temps (min)" }, ticks: { callback: (v) => nb(v, 0) } };

function graphiqueScore(ia, numeroSet) {
  const g = graphiques.find((x) => x.canvas.id === "g-score");
  if (g) { g.destroy(); graphiques = graphiques.filter((x) => x !== g); }
  const points = ia.tendances.progression_score.filter((p) => p.set === numeroSet);
  const serie = (camp) => ({
    label: `Camp ${camp}`, data: points.map((p, i) => ({ x: i + 1, y: p[camp] })), borderColor: COULEUR[camp],
    backgroundColor: COULEUR[camp], borderWidth: 2, pointRadius: 0, pointHoverRadius: 5, stepped: true,
  });
  graphique($("#g-score"), {
    type: "line", data: { datasets: [serie("A"), serie("B")] },
    options: {
      maintainAspectRatio: false, interaction: { mode: "index", intersect: false },
      scales: { x: { type: "linear", title: { display: true, text: "Échange" } }, y: { beginAtZero: true, title: { display: true, text: "Points" } } },
    },
  });
}

function graphiqueSideout(ia) {
  const pts = ia.tendances.sideout_glissant;
  const serie = (camp) => ({
    label: `Camp ${camp}`, data: pts.filter((p) => p[`sideout_${camp}`] !== null).map((p) => ({ x: p.t / 60, y: p[`sideout_${camp}`] })),
    borderColor: COULEUR[camp], backgroundColor: COULEUR[camp], borderWidth: 2, pointRadius: 0, pointHoverRadius: 5, tension: 0.2,
  });
  graphique($("#g-sideout"), {
    type: "line", data: { datasets: [serie("A"), serie("B")] },
    options: {
      maintainAspectRatio: false, interaction: { mode: "nearest", intersect: false },
      scales: { x: axeTemps, y: { min: 0, max: 100, title: { display: true, text: "Sideout (%)" } } },
    },
  });
}

function graphiqueFins(echanges) {
  const compte = {};
  echanges.filter((e) => e.analyse).forEach(({ analyse: a }) => {
    compte[a.fin] ??= { A: 0, B: 0, inconnu: 0 };
    compte[a.fin][a.camp_gagnant] += 1;
  });
  const fins = Object.keys(compte).sort((x, y) => Object.values(compte[y]).reduce((a, b) => a + b) - Object.values(compte[x]).reduce((a, b) => a + b));
  const serie = (camp, label) => ({
    label, data: fins.map((f) => compte[f][camp]), backgroundColor: COULEUR[camp],
    borderColor: "#1a1a19", borderWidth: { left: 0, right: 2, top: 0, bottom: 0 }, borderSkipped: false, maxBarThickness: 22,
  });
  const series = [serie("A", "Point du camp A"), serie("B", "Point du camp B")];
  if (fins.some((f) => compte[f].inconnu)) series.push(serie("inconnu", "Gagnant inconnu"));
  graphique($("#g-fins"), {
    type: "bar", data: { labels: fins.map((k) => FINS[k] || k), datasets: series },
    options: { indexAxis: "y", maintainAspectRatio: false, scales: { x: { stacked: true, beginAtZero: true, ticks: { precision: 0 } }, y: { stacked: true } } },
  });
}

function graphiqueZones(ia) {
  const zones = ["poste_4", "poste_3", "poste_2", "arriere"];
  const serie = (camp) => ({
    label: `Camp ${camp}`, data: zones.map((z) => ia.camps[camp].zones_attaque[z] || 0),
    backgroundColor: COULEUR[camp], borderRadius: 4, maxBarThickness: 28,
  });
  graphique($("#g-zones"), {
    type: "bar", data: { labels: zones.map((z) => ZONES[z]), datasets: [serie("A"), serie("B")] },
    options: { maintainAspectRatio: false, scales: { y: { beginAtZero: true, ticks: { precision: 0 } } } },
  });
}

function graphiqueDurees(r) {
  const echanges = r.echanges;
  const gagnant = (e) => (e.analyse && COULEUR[e.analyse.camp_gagnant] ? e.analyse.camp_gagnant : "inconnu");
  const serie = (camp, label) => ({
    label, data: echanges.map((e) => (gagnant(e) === camp ? e.duree : null)),
    backgroundColor: COULEUR[camp], borderRadius: 4, maxBarThickness: 14,
  });
  const analyse = echanges.some((e) => e.analyse);
  const series = analyse
    ? [serie("A", "Gagné par le camp A"), serie("B", "Gagné par le camp B")].concat(echanges.some((e) => gagnant(e) === "inconnu") ? [serie("inconnu", "Non analysé")] : [])
    : [serie("inconnu", "Durée (s)")];
  graphique($("#g-durees"), {
    type: "bar",
    data: { labels: echanges.map((e) => `#${e.numero} · ${horloge(e.debut)}`), datasets: series },
    options: {
      maintainAspectRatio: false,
      plugins: { legend: { display: analyse } },
      scales: { x: { stacked: true, ticks: { maxTicksLimit: 12 } }, y: { stacked: true, beginAtZero: true, title: { display: true, text: "Secondes" } } },
      onClick: (_, elements) => { if (elements.length) allerA(r, echanges[elements[0].index].debut); },
    },
  });
}

// ---------------------------------------------------------------------------
// Historique (tendances d'un match à l'autre)

async function chargerHistorique() {
  let liste = [];
  try { liste = await api("/api/analyses"); } catch { return; }
  if (!liste.length) { $("#liste").innerHTML = `<p class="discret">Aucun match analysé pour l'instant.</p>`; return; }
  const statut = { termine: "Terminé", en_cours: "En cours", en_attente: "En attente", erreur: "Erreur" };
  $("#liste").innerHTML = `<table><thead><tr><th>Match</th><th>Statut</th><th class="nombre">Échanges</th>
      <th class="nombre">Durée moy. (s)</th><th class="nombre">Temps de jeu</th><th class="nombre">Sideout éq. 1 / éq. 2</th></tr></thead><tbody>${
    liste.map((a) => {
      const r = a.resume || {};
      const so = r.equipe_1 ? `${pct(r.equipe_1.sideout_pct)} / ${pct(r.equipe_2.sideout_pct)}` : "—";
      return `<tr class="cliquable" data-id="${esc(a.id)}"><td>${esc(a.titre || a.source?.url || a.source?.nom || a.id)}</td>
        <td>${esc(statut[a.statut] || a.statut)}</td><td class="nombre">${nb(r.nombre_echanges, 0)}</td>
        <td class="nombre">${nb(r.duree_moyenne)}</td><td class="nombre">${pct(r.part_de_jeu_pct)}</td><td class="nombre">${so}</td></tr>`;
    }).join("")}</tbody></table>`;
}

$("#liste").addEventListener("click", (e) => {
  const tr = e.target.closest("tr[data-id]");
  if (tr) suivre(tr.dataset.id);
});

chargerHistorique();
const depart = location.hash.match(/analyse=([0-9a-f]{12})/);
if (depart) suivre(depart[1]);
