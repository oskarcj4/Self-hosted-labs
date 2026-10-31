/* TerminalCero Lab — frontend (JS vanilla). SPA mínima: lista + detalle. */
"use strict";

const view = document.getElementById("view");
const TRACKS = { A: "Detección / respuesta", B: "Hardening / operaciones", C: "30 días de DevSecOps (Linux + Docker)", D: "Operaciones / SRE (producción)", E: "Defensa anti-DDoS / DoS (lado azul)", F: "Pipeline CI y runtime Docker", G: "AppSec web (red / blue)", H: "Máquinas HTB (red / blue)", I: "Defensa del host", J: "Monitoreo, SOC y redes", K: "Hardening web" };
let STATE = { labs: [], cursos: [], filter: "all", view: "home" };
const POLL_MS = 8000; // refresco de "labs en ejecución"

/* ---------- utilidades ---------- */
const esc = (s) => s.replace(/[&<>"']/g, (c) => (
  { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

async function api(path, method = "GET", body) {
  const opt = { method };
  if (body !== undefined) {
    opt.headers = { "Content-Type": "application/json" };
    opt.body = JSON.stringify(body);
  }
  const r = await fetch(path, opt);
  if (!r.ok && r.status >= 500) throw new Error("backend " + r.status);
  return r.json();
}

/* 75 -> "1 min 15 s", 7300 -> "2 h 1 min" */
function fmtSecs(s) {
  if (s == null) return "";
  if (s < 60) return `${s} s`;
  const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), r = s % 60;
  if (h) return `${h} h ${m} min`;
  return r ? `${m} min ${r} s` : `${m} min`;
}

let toastTimer;
function toast(msg) {
  let el = document.querySelector(".toast");
  if (!el) { el = document.createElement("div"); el.className = "toast"; document.body.appendChild(el); }
  el.textContent = msg;
  el.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.remove("show"), 2600);
}

/* ---------- markdown mínimo ---------- */
const mdInline = (t) => esc(t)
  .replace(/`([^`]+)`/g, "<code>$1</code>")
  .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
  .replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_, txt, href) => href.startsWith("#")
    ? `<a href="${href}">${txt}</a>`   // enlace interno (#curso/NN, #lab/NN)
    : `<a href="${href}" target="_blank" rel="noopener">${txt}</a>`);

/* Además del markdown básico: bloques ":::tipo Título" … ":::" (solucion y
   pista se pliegan, ojo es un aviso, piensa una pregunta para razonar) y "\|"
   para una barra dentro de una celda. */
function md(src) {
  const blocks = [];
  src = src.replace(/\r\n?/g, "\n"); // los .md del repo pueden venir con CRLF
  // extrae fenced code primero
  src = src.replace(/```(\w*)\n([\s\S]*?)```/g, (_, lang, code) => {
    blocks.push(`<pre><code>${esc(code.replace(/\n$/, ""))}</code></pre>`);
    return `\u0000${blocks.length - 1}\u0000`;
  });
  const inline = mdInline;

  const render = (lines) => {
    let out = [], i = 0;
    while (i < lines.length) {
      let ln = lines[i];
      const ph = ln.match(/^\u0000(\d+)\u0000$/);
      if (ph) { out.push(blocks[+ph[1]]); i++; continue; }
      const fence = ln.match(/^:::(\w+)\s*(.*)$/);
      if (fence) {
        const inner = []; i++;
        while (i < lines.length && !/^:::\s*$/.test(lines[i])) inner.push(lines[i++]);
        i++;
        const [, kind, title] = fence;
        const body = render(inner);
        out.push(kind === "ojo" || kind === "piensa"
          ? `<div class="callout${kind === "piensa" ? " callout--think" : ""}">${title ? `<strong>${inline(title)}</strong>` : ""}${body}</div>`
          : `<details class="fold"><summary>${inline(title || (kind === "pista" ? "Pista" : "Ver solución"))}</summary><div class="fold__body">${body}</div></details>`);
        continue;
      }
      if (/^#{1,3}\s/.test(ln)) {
        const lvl = ln.match(/^#+/)[0].length;
        out.push(`<h${lvl}>${inline(ln.replace(/^#+\s/, ""))}</h${lvl}>`); i++; continue;
      }
      if (/^>\s?/.test(ln)) {
        let buf = [];
        while (i < lines.length && /^>\s?/.test(lines[i])) { buf.push(inline(lines[i].replace(/^>\s?/, ""))); i++; }
        out.push(`<blockquote>${buf.join("<br>")}</blockquote>`); continue;
      }
      if (/^\s*\|.*\|\s*$/.test(ln) && i + 1 < lines.length && /^\s*\|[-:\s|]+\|\s*$/.test(lines[i + 1])) {
        const row = (l) => l.trim().replace(/\\\|/g, "\u0001").replace(/^\||\|$/g, "").split("|")
          .map((c) => c.trim().replace(/\u0001/g, "|"));
        const head = row(ln); i += 2;
        let body = [];
        while (i < lines.length && /^\s*\|.*\|\s*$/.test(lines[i])) { body.push(row(lines[i])); i++; }
        out.push(`<table><thead><tr>${head.map((c) => `<th>${inline(c)}</th>`).join("")}</tr></thead>`
          + `<tbody>${body.map((r) => `<tr>${r.map((c) => `<td>${inline(c)}</td>`).join("")}</tr>`).join("")}</tbody></table>`);
        continue;
      }
      // Listas: una línea sangrada bajo un ítem (texto partido en el .md) sigue
      // perteneciendo a ese ítem, en vez de cortar la lista y reiniciar la numeración.
      const list = (marker) => {
        const buf = [];
        while (i < lines.length && marker.test(lines[i])) {
          let item = lines[i++].replace(marker, "");
          while (i < lines.length && /^\s{2,}\S/.test(lines[i]) && !/^\s*([-*]|\d+\.)\s/.test(lines[i])) item += " " + lines[i++].trim();
          buf.push(`<li>${inline(item)}</li>`);
        }
        return buf.join("");
      };
      if (/^\s*[-*]\s/.test(ln)) { out.push(`<ul>${list(/^\s*[-*]\s/)}</ul>`); continue; }
      if (/^\s*\d+\.\s/.test(ln)) {
        const start = parseInt(ln, 10);
        out.push(`<ol${start > 1 ? ` start="${start}"` : ""}>${list(/^\s*\d+\.\s/)}</ol>`); continue;
      }
      if (ln.trim() === "") { i++; continue; }
      // la primera línea se consume siempre: una línea que ningún bloque reconoce
      // (p.ej. "|" suelto o ":::" sin abrir) no puede dejar el bucle parado
      let buf = [inline(lines[i++])];
      while (i < lines.length && lines[i].trim() !== "" && !/^(#{1,3}\s|>|:::|\s*[-*]\s|\s*\d+\.\s|\s*\|)/.test(lines[i]) && !/^\u0000\d+\u0000$/.test(lines[i])) {
        buf.push(inline(lines[i])); i++;
      }
      if (buf.length) out.push(`<p>${buf.join(" ")}</p>`);
    }
    return out.join("\n");
  };
  return render(src.split("\n"));
}

/* ---------- componentes ---------- */
function diffDots(n) {
  return `<span class="diff" title="dificultad ${n}/3">`
    + [1, 2, 3].map((k) => `<i class="${k <= n ? "on" : ""}"></i>`).join("") + "</span>";
}

const catsHTML = (l) => (l.categories || [])
  .map((c) => `<span class="cat cat-${c.toLowerCase()}">${esc(c)}</span>`).join("");

const liveBadge = '<span class="badge live"><span class="dot"></span>activo</span>';

function cardHTML(l) {
  return `<article class="card" tabindex="0" role="button" data-id="${l.id}" aria-label="Abrir lab ${l.id}: ${esc(l.name)}">
    <div class="card__top">
      <span class="card__id">LAB ${l.id}</span>
      <span class="card__state">${l.running ? liveBadge : diffDots(l.difficulty)}</span>
    </div>
    <div class="card__cats">${catsHTML(l)}</div>
    <h3 class="card__title">${esc(l.name)}</h3>
    ${l.description ? `<p class="card__desc">${esc(l.description)}</p>` : ""}
    <div class="card__skills">
      ${l.skills.slice(0, 4).map((s) => `<span class="tag">${esc(s)}</span>`).join("")}
    </div>
  </article>`;
}

/* ---------- labs en ejecución ---------- */
const runningLabs = () => STATE.labs.filter((l) => l.running);

function runningPanelHTML() {
  const rl = runningLabs();
  if (!rl.length) {
    return `<div class="running running--empty">Ningún lab en ejecución. Abre uno y pulsa <strong>▶ Iniciar</strong>.</div>`;
  }
  return `<div class="running">
    ${rl.map((l) => `<div class="running__row">
      <span class="badge live"><span class="dot"></span>LAB ${l.id}</span>
      <span class="running__name">${esc(l.name)}</span>
      ${l.destroyIn != null ? `<span class="badge warn" data-countdown="${l.id}">se destruye en ${fmtSecs(l.destroyIn)}</span>` : ""}
      <span class="running__cats">${catsHTML(l)}</span>
      <span class="running__actions">
        <button class="btn btn--sm" data-open="${l.id}">Abrir</button>
        <button class="btn btn--sm" data-popout="${l.id}">Terminal ↗</button>
        <button class="btn btn--sm btn--danger" data-stop="${l.id}">■ Detener</button>
      </span>
    </div>`).join("")}
    ${rl.length > 1 ? '<div class="running__warn">⚠ Hay varios labs corriendo a la vez: consumen más RAM y CPU. Detén los que no uses.</div>' : ""}
  </div>`;
}

function bindRunningPanel(root) {
  root.querySelectorAll("[data-open]").forEach((b) => b.addEventListener("click", () => renderDetail(b.dataset.open)));
  root.querySelectorAll("[data-popout]").forEach((b) => b.addEventListener("click", () =>
    popOut(STATE.labs.find((x) => x.id === b.dataset.popout))));
  root.querySelectorAll("[data-stop]").forEach((b) => b.addEventListener("click", async () => {
    b.disabled = true;
    b.innerHTML = '<span class="spinner"></span> Deteniendo…';
    await stopLab(b.dataset.stop);
    toast(`Lab ${b.dataset.stop} detenido`);
  }));
}

async function stopLab(id) {
  const l = STATE.labs.find((x) => x.id === id);
  if (l) l.stopping = true;
  closePopout(id, true); // stopLab siempre viene de un clic
  try { await api(`/api/labs/${id}/stop`, "POST"); } catch (e) { toast("Error: " + e.message); }
  await refreshRunning();
  if (l) l.stopping = false;
}

/* ---------- autodestrucción ---------- */
/* Banner en el detalle: cuenta atrás tras resolver + aviso de TTL. */
function renderLifeBanner() {
  const slot = view.querySelector("#lifeBanner");
  if (!slot) return;
  const l = STATE.labs.find((x) => x.id === STATE.view);
  if (!l || !l.running) { slot.innerHTML = ""; return; }
  if (l.destroyIn != null) {
    slot.innerHTML = `<div class="notice notice--ok" role="status">
      <span>✓ Lab resuelto. Se autodestruirá en <strong data-countdown="${l.id}">${fmtSecs(l.destroyIn)}</strong> (contenedores, red y volúmenes).</span>
      <span class="notice__actions">
        <button class="btn btn--sm" id="btnKeep">Mantener abierto</button>
        <button class="btn btn--sm btn--danger" id="btnDestroyNow">Destruir ahora</button>
      </span>
    </div>`;
    slot.querySelector("#btnKeep").addEventListener("click", async () => {
      try { await api(`/api/labs/${l.id}/keep`, "POST"); } catch (_) {}
      l.destroyIn = null;
      toast("Se mantiene abierto (el tiempo máximo sigue corriendo)");
      renderLifeBanner(); updateRunningUI(true);
    });
    slot.querySelector("#btnDestroyNow").addEventListener("click", async (e) => {
      e.target.disabled = true;
      e.target.innerHTML = '<span class="spinner"></span> Destruyendo…';
      await stopLab(l.id);
      toast(`Lab ${l.id} destruido`);
      const t = view.querySelector("#termSlot"); if (t) { t.dataset.url = ""; mountTerminal(l); }
      refreshStatus(l);
    });
    return;
  }
  if (l.expiresIn != null && l.expiresIn <= 15 * 60) {
    slot.innerHTML = `<div class="notice" role="status">⏱ Este lab alcanza su tiempo máximo y se autodestruirá en <strong data-countdown-ttl="${l.id}">${fmtSecs(l.expiresIn)}</strong>.</div>`;
    return;
  }
  slot.innerHTML = "";
}

/* Reloj local de 1 s para las cuentas atrás (el backend manda la verdad cada POLL_MS). */
function tick() {
  STATE.labs.forEach((l) => {
    if (l.destroyIn != null && l.destroyIn > 0) l.destroyIn--;
    if (l.expiresIn != null && l.expiresIn > 0) l.expiresIn--;
  });
  document.querySelectorAll("[data-countdown]").forEach((el) => {
    const l = STATE.labs.find((x) => x.id === el.dataset.countdown);
    if (l && l.destroyIn != null) el.textContent = (el.classList.contains("badge") ? "se destruye en " : "") + fmtSecs(l.destroyIn);
  });
  document.querySelectorAll("[data-countdown-ttl]").forEach((el) => {
    const l = STATE.labs.find((x) => x.id === el.dataset.countdownTtl);
    if (l && l.expiresIn != null) el.textContent = fmtSecs(l.expiresIn);
  });
  if (STATE.labs.some((l) => l.destroyIn === 0)) refreshRunning();
  // El usuario cerró la pestaña de la terminal: la shell vuelve a esta página.
  Object.keys(POPOUTS).forEach((id) => {
    if (!POPOUTS[id].closed) return;
    delete POPOUTS[id];
    const l = STATE.labs.find((x) => x.id === id);
    if (l && STATE.view === id && termVisible()) mountTerminal(l);
  });
}

/* Pide los labs activos al backend y actualiza toda la UI que depende de ello. */
async function refreshRunning() {
  let d;
  try { d = await api("/api/running"); } catch (_) { return; }
  const set = new Set(d.running);
  const life = d.lifecycle || {};
  let changed = false;
  STATE.labs.forEach((l) => {
    const r = set.has(l.id);
    if (l.running !== r) {
      // Estaba corriendo y desapareció sin pulsar Detener: lo destruyó el backend.
      if (l.running && !r && !l.stopping) toast(`Lab ${l.id} autodestruido`);
      if (!r) closePopout(l.id);
      l.running = r; changed = true;
    }
    const lc = life[l.id] || {};
    const dIn = r ? (lc.destroyIn ?? null) : null;
    if ((l.destroyIn == null) !== (dIn == null)) changed = true;
    l.destroyIn = dIn;
    l.expiresIn = r ? (lc.expiresIn ?? null) : null;
  });
  updateRunningUI(changed);
  renderLifeBanner();
}

function updateRunningUI(changed = true) {
  const n = runningLabs().length;
  const ind = document.getElementById("runIndicator");
  if (ind) {
    ind.hidden = n === 0;
    ind.innerHTML = `<span class="dot"></span>${n} en ejecución`;
  }
  if (!changed) return;
  if (STATE.view === "home") {
    const slot = view.querySelector("#runningSlot");
    if (slot) { slot.innerHTML = runningPanelHTML(); bindRunningPanel(slot); }
    view.querySelectorAll(".card").forEach((c) => {
      const l = STATE.labs.find((x) => x.id === c.dataset.id);
      c.querySelector(".card__state").innerHTML = l.running ? liveBadge : diffDots(l.difficulty);
    });
  } else {
    renderOthersBanner();
  }
}

/* En la vista de detalle: aviso si hay OTROS labs corriendo. */
function renderOthersBanner() {
  const slot = view.querySelector("#othersBanner");
  if (!slot) return;
  const others = runningLabs().filter((l) => l.id !== STATE.view);
  if (!others.length) { slot.innerHTML = ""; return; }
  slot.innerHTML = `<div class="notice">
    <span>⚠ También en ejecución: ${others.map((l) => `<a href="#" data-open="${l.id}">LAB ${l.id} · ${esc(l.name)}</a>`).join(", ")}</span>
  </div>`;
  slot.querySelectorAll("[data-open]").forEach((a) => a.addEventListener("click", (e) => { e.preventDefault(); renderDetail(a.dataset.open); }));
}

/* Diálogo de conflicto. Resuelve "stop" | "force" | null (cancelar). */
function askConflict(l, ids) {
  const others = ids.map((id) => STATE.labs.find((x) => x.id === id)).filter(Boolean);
  let dlg = document.getElementById("conflictDialog");
  if (!dlg) {
    dlg = document.createElement("dialog");
    dlg.id = "conflictDialog";
    dlg.className = "dialog";
    document.body.appendChild(dlg);
  }
  dlg.innerHTML = `<form method="dialog">
    <h2 class="dialog__title">Ya hay ${others.length > 1 ? "labs corriendo" : "un lab corriendo"}</h2>
    <p class="dialog__text">Vas a iniciar <strong>LAB ${l.id} · ${esc(l.name)}</strong>, pero ya está en ejecución:</p>
    <ul class="dialog__list">${others.map((o) => `<li><span class="badge live"><span class="dot"></span>LAB ${o.id}</span> ${esc(o.name)}</li>`).join("")}</ul>
    <p class="dialog__text dialog__muted">Correr varios labs a la vez consume más RAM y CPU. Lo recomendable es detener ${others.length > 1 ? "los otros" : "el otro"} antes.</p>
    <div class="dialog__actions">
      <button class="btn" value="cancel">Cancelar</button>
      <button class="btn" value="force">Iniciar de todos modos</button>
      <button class="btn btn--primary" value="stop" autofocus>Detener y continuar</button>
    </div>
  </form>`;
  return new Promise((resolve) => {
    dlg.addEventListener("close", () => {
      const v = dlg.returnValue;
      resolve(v === "stop" || v === "force" ? v : null);
    }, { once: true });
    dlg.returnValue = "";
    dlg.showModal();
  });
}

/* start/reset con aviso: si el backend responde conflicto, pregunta al usuario. */
async function guardedAction(l, action, extra = "") {
  let r = await api(`/api/labs/${l.id}/${action}${extra}`, "POST");
  if (!r.conflict) return r;
  const choice = await askConflict(l, r.running);
  if (!choice) return null;
  if (choice === "stop") {
    for (const id of r.running) {
      try { await api(`/api/labs/${id}/stop`, "POST"); } catch (_) {}
    }
    await refreshRunning();
  }
  const q = extra ? `${extra}&force=1` : "?force=1";
  return api(`/api/labs/${l.id}/${action}${q}`, "POST");
}

/* Popup red/blue para labs con contenedor atacante (estilo HTB). */
function askMode(l) {
  let dlg = document.getElementById("modeDialog");
  if (!dlg) {
    dlg = document.createElement("dialog");
    dlg.id = "modeDialog";
    dlg.className = "dialog";
    document.body.appendChild(dlg);
  }
  dlg.innerHTML = `<form method="dialog">
    <h2 class="dialog__title">¿Cómo quieres jugar LAB ${l.id}?</h2>
    <p class="dialog__text">Este lab se puede resolver de dos formas.</p>
    <div class="modepick">
      <button class="modecard modecard--red" value="red" autofocus>
        <span class="modecard__tag">🔴 RED · atacar</span>
        <span class="modecard__t">Capturar las banderas</span>
        <span class="modecard__d">Sin acceso al servidor. Trabajas desde una caja
        atacante y llegas al target por la red. Entregas las banderas
        <strong>user</strong> y <strong>root</strong>.</span>
      </button>
      <button class="modecard modecard--blue" value="blue">
        <span class="modecard__tag">🔵 BLUE · defender</span>
        <span class="modecard__t">Arreglar la vulnerabilidad</span>
        <span class="modecard__d">Acceso total al target (shell). Cierras el fallo y
        un validador comprueba que ya no se puede explotar.</span>
      </button>
    </div>
    <div class="dialog__actions">
      <button class="btn" value="cancel">Cancelar</button>
    </div>
  </form>`;
  return new Promise((resolve) => {
    dlg.addEventListener("close", () => {
      const v = dlg.returnValue;
      resolve(v === "red" || v === "blue" ? v : null);
    }, { once: true });
    dlg.returnValue = "";
    dlg.showModal();
  });
}

/* ---------- cursos ---------- */
const cursoById = (id) => STATE.cursos.find((c) => c.id === id);
const labsForCurso = (id) => STATE.labs.filter((l) => (l.cursos || []).includes(id));

/* La URL refleja la vista (#cursos, #curso/NN, #lab/NN) para poder enlazarla,
   recargar sin perderla y usar atrás/adelante. pushState no dispara hashchange. */
function setHash(h) {
  if ((location.hash || "") === h) return;
  history.pushState(null, "", h || location.pathname + location.search);
}

function route() {
  const h = location.hash;
  let m;
  if (h === "#cursos") renderCourses();
  else if ((m = h.match(/^#curso\/(\d{2})$/))) renderCourse(m[1]);
  else if ((m = h.match(/^#lab\/(\d{2,3})$/))) renderDetail(m[1]);
  else renderHome();
}

/* Resalta en el nav "Cursos" o el filtro de pista activo. */
function setNav(section) {
  view.classList.remove("container--wide"); // solo la pestaña Terminal usa el ancho completo
  document.querySelectorAll(".chip[data-filter]").forEach((x) =>
    x.setAttribute("aria-pressed", section !== "cursos" && x.dataset.filter === STATE.filter));
  const c = document.querySelector('.chip[data-route="cursos"]');
  if (c) c.setAttribute("aria-pressed", section === "cursos");
}

/* Aviso del detalle de un lab: "¿Dificultad? Lee 04 · … y 05 · … para mejorar." */
function helpHTML(l) {
  const links = (l.cursos || []).map(cursoById).filter(Boolean)
    .map((c) => `<a href="#curso/${c.id}">${c.id} · ${esc(c.title)}</a>`);
  if (!links.length) return "";
  const list = links.length > 1 ? `${links.slice(0, -1).join(", ")} y ${links[links.length - 1]}` : links[0];
  return `<div class="help" role="note"><span class="help__q">¿Dificultad?</span> Lee ${list} para mejorar.</div>`;
}

function renderCourses() {
  STATE.view = "cursos";
  setHash("#cursos");
  setNav("cursos");
  window.scrollTo(0, 0);
  const cards = STATE.cursos.map((c) => {
    const labs = labsForCurso(c.id);
    const tags = labs.length
      ? labs.map((l) => `<span class="tag" title="${esc(l.name)}">LAB ${l.id}</span>`).join("")
      : `<span class="tag">${c.id === "00" ? "Empieza aquí" : "Base para todos los labs"}</span>`;
    return `<article class="card" tabindex="0" role="button" data-curso="${c.id}" aria-label="Abrir módulo ${c.id}: ${esc(c.title)}">
      <div class="card__top"><span class="card__id">MÓDULO ${c.id}</span></div>
      <h3 class="card__title">${esc(c.title)}</h3>
      ${c.summary ? `<p class="card__desc">${mdInline(c.summary)}</p>` : ""}
      <div class="card__skills">${tags}</div>
    </article>`;
  }).join("");

  view.innerHTML = `
    <section class="hero">
      <h1>Cursos</h1>
      <p>Módulos para entender lo que ejecutas en los labs 01 a 23. No dan la respuesta de ningún lab: explican los conceptos, las herramientas y cómo leer su salida. Si empiezas de cero, abre el 00.</p>
    </section>
    <div class="section-label">Módulos</div>
    <div class="grid">${cards || '<p class="empty">No hay cursos disponibles.</p>'}</div>
  `;
  view.querySelectorAll(".card[data-curso]").forEach((c) => {
    const open = () => renderCourse(c.dataset.curso);
    c.addEventListener("click", open);
    c.addEventListener("keydown", (e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); open(); } });
  });
}

async function renderCourse(id) {
  const c = cursoById(id);
  if (!c) return renderCourses();
  STATE.view = "curso:" + id;
  setHash("#curso/" + id);
  setNav("cursos");
  window.scrollTo(0, 0);
  const i = STATE.cursos.indexOf(c);
  const prev = STATE.cursos[i - 1], next = STATE.cursos[i + 1];
  const labs = labsForCurso(id);

  view.innerHTML = `
    <a class="detail__back" href="#cursos">← Todos los cursos</a>
    ${labs.length ? `<div class="course__labs"><span class="muted">Se aplica en</span>
      ${labs.map((l) => `<a class="tag" href="#lab/${l.id}" title="${esc(l.name)}">LAB ${l.id}</a>`).join("")}</div>` : ""}
    <article class="md course__body" id="mdCurso">Cargando…</article>
    <nav class="course__pager" aria-label="Módulos">
      ${prev ? `<a class="btn" href="#curso/${prev.id}">← ${prev.id} · ${esc(prev.title)}</a>` : "<span></span>"}
      ${next ? `<a class="btn" href="#curso/${next.id}">${next.id} · ${esc(next.title)} →</a>` : ""}
    </nav>
  `;
  let txt = null;
  try { txt = (await api(`/api/cursos/${id}`)).markdown; } catch (_) {}
  if (STATE.view !== "curso:" + id) return; // el usuario ya navegó a otra vista
  view.querySelector("#mdCurso").innerHTML = txt ? md(txt) : "No disponible.";
}

function renderHome() {
  STATE.view = "home";
  setHash("");
  setNav("home");
  const labs = STATE.labs.filter((l) => STATE.filter === "all" || l.track === STATE.filter);
  const byTrack = { A: [], B: [], C: [], D: [], E: [], F: [], G: [], H: [], I: [], J: [], K: [] };
  labs.forEach((l) => byTrack[l.track].push(l));
  const trackHTML = (t) => (STATE.filter === "all" || STATE.filter === t)
    ? `<div class="section-label">${TRACKS[t]}</div>
    <div class="grid">${byTrack[t].map(cardHTML).join("") || '<p class="empty">Sin labs en esta pista.</p>'}</div>` : "";

  view.innerHTML = `
    <section class="hero">
      <h1>Laboratorio de defensa en Linux</h1>
      <p>Escenarios reales de detección, respuesta a incidentes y hardening. Levanta un contenedor con un botón, abre la terminal en el navegador y valida tu solución. Todo local e inofensivo.</p>
    </section>
    <div class="section-label" id="runningLabel">En ejecución</div>
    <div id="runningSlot">${runningPanelHTML()}</div>
    ${trackHTML("A")}
    ${trackHTML("B")}
    ${trackHTML("C")}
    ${trackHTML("D")}
    ${trackHTML("E")}
    ${trackHTML("F")}
    ${trackHTML("G")}
    ${trackHTML("H")}
    ${trackHTML("I")}
    ${trackHTML("J")}
    ${trackHTML("K")}
  `;

  bindRunningPanel(view.querySelector("#runningSlot"));
  updateRunningUI(false);
  view.querySelectorAll(".card").forEach((c) => {
    const open = () => renderDetail(c.dataset.id);
    c.addEventListener("click", open);
    c.addEventListener("keydown", (e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); open(); } });
  });
}

async function renderDetail(id) {
  const l = STATE.labs.find((x) => x.id === id);
  if (!l) return renderHome();
  STATE.view = id;
  setHash("#lab/" + id);
  setNav("home");
  window.scrollTo(0, 0);

  view.innerHTML = `
    <a class="detail__back" href="#" id="back">← Todos los labs</a>
    <div class="detail__head">
      <div>
        <div class="card__id">LAB ${l.id} · ${TRACKS[l.track]}</div>
        <h1 class="detail__title">${esc(l.name)}</h1>
        ${l.description ? `<p class="detail__desc">${esc(l.description)}</p>` : ""}
        <div class="detail__meta">${catsHTML(l)} ${diffDots(l.difficulty)} <span id="modeBadge"></span> <span id="statusText">comprobando…</span></div>
      </div>
    </div>
    ${helpHTML(l)}
    <div id="lifeBanner"></div>
    <div id="othersBanner"></div>
    <div class="toolbar">
      <button class="btn btn--primary" id="btnStart">▶ Iniciar</button>
      <button class="btn" id="btnCheck">✓ Validar</button>
      <button class="btn" id="btnReset">↻ Reiniciar</button>
      <button class="btn btn--danger" id="btnStop">■ Detener</button>
    </div>
    <div class="tabs" role="tablist">
      <button class="tab" role="tab" data-panel="reto" aria-selected="true">Reto</button>
      <button class="tab" role="tab" data-panel="term">Terminal</button>
      <button class="tab" role="tab" data-panel="check">Validación</button>
      <button class="tab" role="tab" data-panel="sol">Solución</button>
    </div>
    <div class="panel active" data-panel="reto"><div class="md" id="mdReto">Cargando…</div></div>
    <div class="panel" data-panel="term">
      <div class="workspace${briefHidden() ? " workspace--nobrief" : ""}" id="workspace">
        <aside class="brief" aria-label="Enunciado del reto">
          <div class="brief__head">
            <div class="brief__tabs" role="tablist" aria-label="Lateral del LAB ${l.id}">
              <button class="brief__tab" role="tab" data-brief-tab="reto" aria-selected="true">Enunciado</button>
              <button class="brief__tab" role="tab" data-brief-tab="guia" aria-selected="false" title="Paso a paso explicado: cómo pensar y actuar">Guiada</button>
            </div>
            <button class="linkbtn" data-brief-check title="Validar la solución">✓ Validar</button>
            <button class="linkbtn" data-brief-toggle title="Ocultar lateral">Ocultar ⇤</button>
          </div>
          <div class="brief__scroll">
            <pre class="output" id="briefCheck" hidden></pre>
            <div class="md brief__body" id="mdBrief" data-brief-pane="reto">Cargando…</div>
            <div class="md brief__body" id="mdGuia" data-brief-pane="guia" hidden>Cargando…</div>
          </div>
        </aside>
        <div class="workspace__term" id="termSlot"></div>
      </div>
    </div>
    <div class="panel" data-panel="check"><p class="empty" id="checkEmpty">Pulsa <strong>Validar</strong> con el lab activo para ver el resultado.</p><pre class="output" id="checkOut" style="display:none"></pre></div>
    <div class="panel" data-panel="sol"><div class="md" id="mdSol">Cargando…</div></div>
  `;

  view.querySelector("#back").addEventListener("click", (e) => { e.preventDefault(); renderHome(); });

  // tabs
  const tabs = [...view.querySelectorAll(".tab")];
  tabs.forEach((t) => t.addEventListener("click", () => {
    tabs.forEach((x) => x.setAttribute("aria-selected", x === t));
    view.querySelectorAll(".panel").forEach((p) => p.classList.toggle("active", p.dataset.panel === t.dataset.panel));
    view.classList.toggle("container--wide", t.dataset.panel === "term");
    if (t.dataset.panel === "term") mountTerminal(l);
  }));
  view.querySelector("[data-brief-toggle]").addEventListener("click", () => toggleBrief(false));
  view.querySelector("[data-brief-check]").addEventListener("click", () => view.querySelector("#btnCheck").click());
  view.querySelectorAll("[data-brief-tab]").forEach((b) => b.addEventListener("click", () => showBriefTab(b.dataset.briefTab)));
  showBriefTab(briefTab());

  // contenido markdown (el enunciado va también al lateral de la pestaña Terminal)
  api(`/api/labs/${id}/reto`).then((d) => {
    const html = d.markdown ? md(d.markdown) : "No disponible.";
    view.querySelector("#mdReto").innerHTML = html;
    view.querySelector("#mdBrief").innerHTML = html;
  });
  api(`/api/labs/${id}/solucion`).then((d) => { view.querySelector("#mdSol").innerHTML = d.markdown ? md(d.markdown) : "No disponible."; })
    .catch(() => { view.querySelector("#mdSol").textContent = "No disponible."; });
  api(`/api/labs/${id}/guia`).then((d) => { view.querySelector("#mdGuia").innerHTML = d.markdown ? md(d.markdown) : "No disponible."; })
    .catch(() => { view.querySelector("#mdGuia").textContent = "Este lab aún no tiene resolución guiada."; });

  // acciones
  const setBusy = (btn, busy, label) => {
    btn.disabled = busy;
    btn.innerHTML = busy ? `<span class="spinner"></span> ${label}` : btn.dataset.label;
  };
  const bind = (sel, label, action, after, pre) => {
    const b = view.querySelector(sel); b.dataset.label = b.innerHTML;
    b.addEventListener("click", async () => {
      let extra = "";
      if (pre) {
        const v = await pre();
        if (v === null) { toast("Cancelado"); return; }
        if (v === false) return;   // manejado por el propio pre (sin toast)
        extra = v;
      }
      setBusy(b, true, label);
      try {
        const r = (action === "start" || action === "reset")
          ? await guardedAction(l, action, extra)
          : await api(`/api/labs/${id}/${action}`, "POST");
        if (r) after(r); else toast("Cancelado");
      } catch (e) { toast("Error: " + e.message); }
      setBusy(b, false);
      refreshStatus(l);
      refreshRunning();
    });
  };

  // Elección de modo (solo labs red-capaces). Se recuerda para reiniciar.
  const preStart = async () => {
    if (!l.redCapable) return "";
    const m = await askMode(l);
    if (!m) return null;
    l.chosenMode = m;
    return m === "red" ? "?mode=red" : "";
  };
  const preReset = async () =>
    (l.redCapable && l.chosenMode === "red") ? "?mode=red" : "";

  bind("#btnStart", "Iniciando…", "start", (r) => {
    toast(r.ok ? "Lab iniciado" : "Fallo al iniciar");
    if (r.ok) { l.mode = r.mode; applyMode(l); switchTab("term"); mountTerminal(l); }
    else showCheck(r.output, false);
  }, preStart);
  bind("#btnReset", "Reiniciando…", "reset", (r) => {
    if (r.ok) { l.mode = r.mode; applyMode(l); }
    toast(r.ok ? "Escenario re-plantado" : "Fallo al reiniciar");
  }, preReset);
  bind("#btnStop", "Deteniendo…", "stop", (r) => { toast("Lab detenido y destruido"); closePopout(l.id); l.running = false; l.mode = null; applyMode(l); l.destroyIn = null; clearTerminal(l); });
  const preCheck = async () => {
    // En red no se ejecuta check.sh: se entregan banderas en el panel de captura.
    if (l.mode === "red") { switchTab("check"); renderCapture(l); return false; }
    return "";
  };
  bind("#btnCheck", "Validando…", "check", (r) => {
    // Desde la terminal no se cambia de pestaña: el resultado sale encima del enunciado.
    if (!termVisible()) switchTab("check");
    showCheck(r.output || "(sin salida)", r.ok);
    toast(r.ok ? "¡Resuelto! 🎉" : "Aún faltan objetivos");
    if (r.ok) { l.destroyIn = r.destroyIn; renderLifeBanner(); updateRunningUI(true); }
  }, preCheck);

  renderOthersBanner();
  renderLifeBanner();
  refreshStatus(l);
}

function switchTab(panel) {
  const t = view.querySelector(`.tab[data-panel="${panel}"]`);
  if (t) t.click();
}

function showCheck(text, ok) {
  const out = view.querySelector("#checkOut");
  const empty = view.querySelector("#checkEmpty");
  if (!out) return;
  empty.style.display = "none";
  out.style.display = "block";
  out.textContent = text;
  out.className = "output " + (ok ? "ok" : "fail");
  const brief = view.querySelector("#briefCheck");
  if (brief) {
    brief.hidden = false;
    brief.textContent = text;
    brief.className = out.className;
    brief.parentElement.scrollTop = 0; // el resultado está arriba del lateral
  }
}

async function refreshStatus(l) {
  try {
    const s = await api(`/api/labs/${l.id}/status`);
    l.running = s.running;
    l.destroyIn = s.running ? s.destroyIn : null;
    l.expiresIn = s.running ? s.expiresIn : null;
    if (s.redCapable != null) l.redCapable = s.redCapable;
    l.mode = s.running ? s.mode : null;
    const st = view.querySelector("#statusText");
    if (st) st.innerHTML = s.running
      ? '<span class="badge live"><span class="dot"></span>activo</span>'
        + (l.expiresIn != null ? ` <span class="muted">· autodestrucción como máximo en <span data-countdown-ttl="${l.id}">${fmtSecs(l.expiresIn)}</span></span>` : "")
      : '<span class="badge"><span class="dot"></span>detenido</span>';
    applyMode(l);
    renderLifeBanner();
    const term = view.querySelector(".panel[data-panel='term']");
    if (term && term.classList.contains("active")) mountTerminal(l);
  } catch (_) {}
}

/* Ajusta la vista al modo activo (red = captura de banderas; blue = validar). */
function applyMode(l) {
  const red = l.mode === "red";
  const mb = view.querySelector("#modeBadge");
  if (mb) mb.innerHTML = l.mode
    ? `<span class="mbadge mbadge--${l.mode}">${red ? "🔴 RED" : "🔵 BLUE"}</span>` : "";
  const checkTab = view.querySelector('.tab[data-panel="check"]');
  if (checkTab) checkTab.textContent = red ? "Capturar" : "Validación";
  const solTab = view.querySelector('.tab[data-panel="sol"]');
  if (solTab) solTab.style.display = red ? "none" : "";  // red no muestra el fix
  const bc = view.querySelector("#btnCheck");
  if (bc) {
    const t = red ? "⚑ Entregar banderas" : "✓ Validar";
    bc.dataset.label = t;
    if (!bc.disabled) bc.innerHTML = t;
  }
  const cap = view.querySelector("#capture");
  if (red && l.running) renderCapture(l);
  else if (cap) cap.remove();
}

/* Panel de entrega de banderas (modo red). */
async function renderCapture(l) {
  const panel = view.querySelector('.panel[data-panel="check"]');
  if (!panel) return;
  let s;
  try { s = await api(`/api/labs/${l.id}/status`); } catch (_) { return; }
  if (s.mode !== "red") return;
  const kinds = (s.flagKinds && s.flagKinds.length) ? s.flagKinds : ["user", "root"];
  const done = new Set(s.captured || []);
  const rows = kinds.map((k) => `
    <div class="cap-row" data-row="${k}">
      <span class="cap-k">${esc(k)}</span>
      <input class="cap-in" data-flag="${k}" placeholder="TCLAB{…}"
             ${done.has(k) ? 'disabled value="✓ capturada"' : ""}>
      <button class="btn btn--sm" data-cap="${k}" ${done.has(k) ? "disabled" : ""}>Entregar</button>
      <span class="cap-st" data-capst="${k}">${done.has(k) ? "✓ capturada" : ""}</span>
    </div>`).join("");
  const empty = panel.querySelector("#checkEmpty"); if (empty) empty.style.display = "none";
  const out = panel.querySelector("#checkOut"); if (out) out.style.display = "none";
  let box = panel.querySelector("#capture");
  if (!box) { box = document.createElement("div"); box.id = "capture"; panel.prepend(box); }
  box.innerHTML = `
    <div class="cap-head">
      <strong>Entrega de banderas</strong>
      <p class="muted">Target: <code>target</code>. Desde la <strong>caja atacante</strong>
      (pestaña Terminal) resuélvelo con <code>getent hosts target</code> y alcánzalo por la red.</p>
    </div>${rows}`;
  box.querySelectorAll("[data-cap]").forEach((btn) => btn.addEventListener("click", async () => {
    const k = btn.dataset.cap;
    const inp = box.querySelector(`[data-flag="${k}"]`);
    const stt = box.querySelector(`[data-capst="${k}"]`);
    const val = (inp.value || "").trim();
    if (!val) { stt.textContent = "pega la bandera"; return; }
    btn.disabled = true;
    try {
      const r = await api(`/api/labs/${l.id}/flag`, "POST", { kind: k, value: val });
      if (r.correct) {
        stt.textContent = "✓ capturada"; inp.disabled = true; inp.value = "✓ capturada";
        toast(`Bandera ${k} correcta`);
        if (r.solved) { l.destroyIn = r.destroyIn; renderLifeBanner(); updateRunningUI(true); toast("¡Todas las banderas! 🎉"); }
      } else {
        stt.textContent = "✗ incorrecta"; btn.disabled = false;
        toast(r.error || "Bandera incorrecta");
      }
    } catch (e) { stt.textContent = "error"; btn.disabled = false; }
  }));
}

/* ---------- terminal ---------- */
const termVisible = () => !!view.querySelector(".panel[data-panel='term'].active");

/* Lateral con el enunciado: se puede ocultar para dar todo el ancho a la shell. */
function briefHidden() {
  try { return localStorage.getItem("tc-brief") === "hidden"; } catch { return false; }
}
/* Pestañas del lateral: Enunciado o resolución Guiada. Se recuerda la última
   elegida, así quien va con la guía no tiene que reabrirla en cada lab. */
function briefTab() {
  try { return localStorage.getItem("tc-brief-tab") === "guia" ? "guia" : "reto"; } catch { return "reto"; }
}
function showBriefTab(tab) {
  view.querySelectorAll("[data-brief-tab]").forEach((b) => b.setAttribute("aria-selected", b.dataset.briefTab === tab));
  view.querySelectorAll("[data-brief-pane]").forEach((p) => { p.hidden = p.dataset.briefPane !== tab; });
  const scroll = view.querySelector(".brief__scroll");
  if (scroll) scroll.scrollTop = 0;
  try { localStorage.setItem("tc-brief-tab", tab); } catch {}
}
function toggleBrief(show) {
  const ws = view.querySelector("#workspace");
  if (!ws) return;
  ws.classList.toggle("workspace--nobrief", !show);
  try { localStorage.setItem("tc-brief", show ? "shown" : "hidden"); } catch {}
}

/* Terminal abierta en otra pestaña del navegador, por lab. Mientras esa pestaña
   exista no se monta el iframe: la shell está en un solo sitio, nunca en los dos.
   Valor: la ventana, o "lost" si se recargó esta página y aún no se recuperó la referencia. */
const POPOUTS = {};

function savePopouts() {
  try { sessionStorage.setItem("tc-popouts", Object.keys(POPOUTS).join(",")); } catch {}
}
function loadPopouts() {
  let ids = "";
  try { ids = sessionStorage.getItem("tc-popouts") || ""; } catch {}
  // solo las de labs que siguen activos: la de un lab destruido ya no tiene shell
  ids.split(",").filter((id) => STATE.labs.some((l) => l.id === id && l.running))
    .forEach((id) => { POPOUTS[id] = "lost"; });
  savePopouts();
}

function popoutOf(id) {
  const w = POPOUTS[id];
  if (w === "lost" || (w && !w.closed)) return w;
  if (w) { delete POPOUTS[id]; savePopouts(); }
  return null;
}

/* Recupera la pestaña por su nombre (solo con un clic: si no, el navegador lo bloquea).
   Si ya no existía, window.open crea una en blanco: se cierra y se devuelve null. */
function reattach(id) {
  const w = window.open("", `tc-term-${id}`);
  if (!w) return null;
  let blank = false;
  try { blank = w.location.href === "about:blank"; } catch { /* origen de ttyd: la pestaña existía */ }
  if (blank) { w.close(); return null; }
  return w;
}

function popOut(l) {
  let w = popoutOf(l.id);
  if (w === "lost") w = reattach(l.id);
  // window.open con el mismo nombre trae al frente la pestaña ya abierta sin recargarla
  if (w) { if (w !== POPOUTS[l.id]) POPOUTS[l.id] = w; window.open("", `tc-term-${l.id}`); return; }
  w = window.open(`http://localhost:${l.ttydPort}`, `tc-term-${l.id}`);
  if (!w) { toast("El navegador bloqueó la pestaña nueva"); delete POPOUTS[l.id]; savePopouts(); return; }
  POPOUTS[l.id] = w;
  savePopouts();
  if (STATE.view === l.id) mountTerminal(l); // quita el iframe de esta página
}

/* gesture: se llama desde un clic, así que se puede recuperar una pestaña "lost". */
function closePopout(id, gesture = false) {
  let w = popoutOf(id);
  if (w === "lost") w = gesture ? reattach(id) : null;
  if (w) w.close();
  delete POPOUTS[id];
  savePopouts();
}

function termBarHTML(l, right) {
  return `<div class="term-bar">
    <button class="linkbtn" data-brief-toggle title="Mostrar enunciado">⇥ Enunciado</button>
    <span>● analista@lab-${l.id}</span><span style="flex:1"></span>${right}
  </div>`;
}

function mountTerminal(l) {
  const slot = view.querySelector("#termSlot");
  if (!slot) return;
  if (!l.running) {
    slot.dataset.url = "";
    slot.innerHTML = `<div class="term-wrap">${termBarHTML(l, "")}<div class="term-off">El contenedor no está activo.<br>Pulsa <strong>▶ Iniciar</strong> para abrir la terminal.</div></div>`;
  } else {
    const url = `http://localhost:${l.ttydPort}`;
    const popped = !!popoutOf(l.id);
    const key = popped ? "popout" : url;
    if (slot.dataset.url === key) return; // ya montado
    slot.dataset.url = key;
    slot.innerHTML = popped
      ? `<div class="term-wrap">${termBarHTML(l, "")}<div class="term-off">
          <p class="term-off__msg"><strong>La terminal está abierta en otra pestaña del navegador.</strong><br>
          Sigue el enunciado aquí y trabaja allí. Para volver a tenerla en esta página, cierra esa pestaña o pulsa <strong>Traer aquí</strong>.</p>
          <div class="term-off__actions">
            <button class="btn btn--sm" data-term="focus">Ir a la pestaña ↗</button>
            <button class="btn btn--sm btn--primary" data-term="back">⇤ Traer aquí</button>
          </div>
          <p class="term-off__note">Al traerla se cierra esa pestaña y se abre una sesión nueva: los ficheros del lab se conservan, el historial y las variables de la shell no.</p>
        </div></div>`
      : `<div class="term-wrap">${termBarHTML(l, `<button class="linkbtn" data-term="popout">abrir en pestaña ↗</button>`)}
          <iframe src="${url}" title="Terminal del lab ${l.id}" allow="clipboard-read; clipboard-write"></iframe>
        </div>`;
    const act = (name, fn) => { const b = slot.querySelector(`[data-term="${name}"]`); if (b) b.addEventListener("click", fn); };
    act("popout", () => popOut(l));
    act("focus", () => popOut(l));
    act("back", () => { closePopout(l.id, true); mountTerminal(l); });
  }
  slot.querySelector("[data-brief-toggle]").addEventListener("click", () => toggleBrief(true));
}

function clearTerminal(l) {
  const slot = view.querySelector("#termSlot");
  if (slot) { slot.dataset.url = ""; mountTerminal(l); }
}

/* ---------- arranque ---------- */
function initTheme() {
  const saved = (() => { try { return localStorage.getItem("tc-theme"); } catch { return null; } })();
  if (saved) document.documentElement.dataset.theme = saved;
  document.getElementById("themeToggle").addEventListener("click", () => {
    const next = document.documentElement.dataset.theme === "dark" ? "light" : "dark";
    document.documentElement.dataset.theme = next;
    try { localStorage.setItem("tc-theme", next); } catch {}
  });
}

function initFilters() {
  document.querySelectorAll(".chip[data-filter]").forEach((c) => c.addEventListener("click", () => {
    STATE.filter = c.dataset.filter;
    renderHome();
  }));
  document.querySelector('.chip[data-route="cursos"]').addEventListener("click", renderCourses);
  // Enlaces internos (#cursos, #curso/NN, #lab/NN) y botones atrás/adelante.
  window.addEventListener("hashchange", route);
  document.querySelector(".brand").addEventListener("click", (e) => { e.preventDefault(); renderHome(); });
  document.getElementById("runIndicator").addEventListener("click", () => {
    if (STATE.view !== "home") renderHome();
    view.querySelector("#runningLabel").scrollIntoView({ behavior: "smooth", block: "start" });
  });
}

function initPolling() {
  setInterval(() => { if (document.visibilityState === "visible") refreshRunning(); }, POLL_MS);
  setInterval(tick, 1000);
  document.addEventListener("visibilitychange", () => { if (document.visibilityState === "visible") refreshRunning(); });
}

async function boot() {
  initTheme();
  initFilters();
  try {
    const [d, c] = await Promise.all([
      api("/api/labs"),
      api("/api/cursos").catch(() => ({ cursos: [] })), // sin cursos la web sigue funcionando
    ]);
    STATE.labs = d.labs;
    STATE.cursos = c.cursos || [];
    loadPopouts(); // pestañas de terminal abiertas antes de recargar
    route(); // abre directamente la vista de la URL (p.ej. /#cursos)
    initPolling();
  } catch (e) {
    view.innerHTML = `<div class="empty">No se pudo contactar el backend. ¿Corriste <code>python3 server.py</code>?<br><small>${esc(e.message)}</small></div>`;
  }
}

boot();
