/*
 * Editor de diálogos de Incursion From Beyond (app web, también para el móvil).
 *
 * - Lee los .dialogue de src/dialogue/ del repositorio en GitHub (o archivos locales).
 * - Edita las reglas «# cuando:» con controles y el texto de cada cue.
 * - Simula qué diálogo sale con el mismo selector que el juego (motor.js ≡ Story).
 * - Guarda en GitHub con un solo commit (token personal) o descarga los archivos.
 */
(function () {
	"use strict";
	const M = window.Motor;

	// --- Constantes ---------------------------------------------------------------------------

	const DEFAULT_REPO = { owner: "Pochico", repo: "incursion-from-beyond-jrpg", branch: "main" };
	const DIALOGUE_DIR = "src/dialogue";
	const LS = "editor-dialogos:";
	const MOMENTS = ["hablar", "ligar", "luchar", "luchar_fin", "harto_hablar", "harto_ligar", "harto_luchar",
		"no_quiere", "alarma", "tras_incursion", "movil"];
	const KINDS = [
		["once", "Primera vez (una vez)"], ["seen", "Ya vio otro cue (visto)"], ["knows", "Sabe un suceso (sabe)"],
		["flag", "Indicador (flag)"], ["present", "Está presente (presente)"], ["phase", "Fase de la historia"],
		["tier", "Tramo de relación"], ["mood", "Ánimo"], ["today", "Interacciones hoy (hoy)"],
		["times", "Veces hoy esta acción (veces)"], ["dim", "Dimensión de la relación"], ["context", "Resultado del combate"],
	];
	const KIND_NAME = Object.fromEntries(KINDS);
	const STORY_FUNCS = ["tier", "mood", "knows", "tell", "phase", "flag", "set_flag", "present", "today", "value",
		"change", "set_mood", "text", "enemy_name", "seen", "speaker"];

	// --- Estado -------------------------------------------------------------------------------

	const S = {
		cfg: M.DEFAULT_CONFIG, repo: loadJSON("repo", DEFAULT_REPO), token: loadStr("token"),
		source: "github",           // "github" | "local"
		files: [],                  // archivos parseados (+ sha, path)
		profiles: {},               // fichas de personajes (relación inicial, ánimo)
		rules: { byMoment: {}, cueFiles: {} },
		sel: null,                  // cue seleccionado
		filter: { file: "", moment: "", q: "" },
		bodyMode: "texto",
		view: "lista",
		sim: null,
		save: null,                 // partida importada (opcional)
	};

	// --- Utilidades ---------------------------------------------------------------------------

	function $(sel, el) { return (el || document).querySelector(sel); }
	function esc(s) { return String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])); }
	function loadStr(k) { try { return localStorage.getItem(LS + k) || ""; } catch (e) { return ""; } }
	function saveStr(k, v) { try { v ? localStorage.setItem(LS + k, v) : localStorage.removeItem(LS + k); } catch (e) { /* sin almacenamiento */ } }
	function loadJSON(k, def) { try { return JSON.parse(localStorage.getItem(LS + k)) || def; } catch (e) { return def; } }
	function saveJSON(k, v) { saveStr(k, v ? JSON.stringify(v) : ""); }
	function charInfo(id) { return S.cfg.characters.find((c) => c.id === id) || null; }
	function charName(id) { const c = charInfo(id); return c ? c.name : id; }
	function charColor(id) { const c = charInfo(id); return c ? c.color : "#8d8d96"; }
	function names() { return Object.fromEntries(S.cfg.characters.map((c) => [c.id, c.name])); }
	function allCues() { return S.files.flatMap((f) => f.cues); }
	function fileOf(cue) { return S.files.find((f) => f.name === cue.file); }
	function fileChanged(f) { return f.deleted || f.isNew || M.serializeFile(f) !== f.original; }
	function changedFiles() { return S.files.filter(fileChanged); }

	/** Cambios reales de un archivo respecto a GitHub: {added, removed, edited} (nombres de cue). */
	function cueChanges(f) {
		const base = f.original ? M.parseFile(f.name, f.original, S.cfg) : { cues: [] };
		const before = new Map(base.cues.map((c) => [c.name, M.cueToText(c)]));
		const after = new Map(f.deleted ? [] : f.cues.map((c) => [c.name, M.cueToText(c)]));
		return {
			added: [...after.keys()].filter((k) => !before.has(k)),
			removed: [...before.keys()].filter((k) => !after.has(k)),
			edited: [...after.keys()].filter((k) => before.has(k) && before.get(k) !== after.get(k)),
		};
	}

	let toastTimer = 0;
	function toast(msg, isErr) {
		const t = $("#toast");
		t.textContent = msg;
		t.className = isErr ? "err" : "";
		t.style.display = "block";
		clearTimeout(toastTimer);
		toastTimer = setTimeout(() => (t.style.display = "none"), isErr ? 6000 : 2600);
	}

	function b64decode(b64) {
		const bin = atob(b64.replace(/\n/g, ""));
		return new TextDecoder().decode(Uint8Array.from(bin, (c) => c.charCodeAt(0)));
	}

	// --- GitHub ------------------------------------------------------------------------------

	async function gh(path, opts) {
		opts = opts || {};
		const headers = { Accept: "application/vnd.github+json" };
		if (S.token) headers.Authorization = "Bearer " + S.token;
		if (opts.body) headers["Content-Type"] = "application/json";
		const res = await fetch("https://api.github.com/repos/" + S.repo.owner + "/" + S.repo.repo + path, {
			method: opts.method || "GET", headers, body: opts.body ? JSON.stringify(opts.body) : undefined, cache: "no-store",
		});
		if (!res.ok) {
			let msg = res.status + " " + res.statusText;
			try { const j = await res.json(); if (j.message) msg += " · " + j.message; } catch (e) { /* */ }
			const err = new Error(msg);
			err.status = res.status;
			throw err;
		}
		return res.json();
	}

	async function ghFile(path) {
		const j = await gh("/contents/" + path + "?ref=" + encodeURIComponent(S.repo.branch));
		return { text: b64decode(j.content), sha: j.sha };
	}

	async function loadFromGitHub() {
		setLoading("Leyendo el repositorio…");
		const list = await gh("/contents/" + DIALOGUE_DIR + "?ref=" + encodeURIComponent(S.repo.branch));
		const dialogueFiles = list.filter((e) => e.type === "file" && e.name.endsWith(".dialogue"));
		const src = {};
		const srcPaths = { gameState: "src/autoload/game_state.gd", social: "src/systems/social.gd",
			story: "src/autoload/story.gd", characterDb: "src/data/character_db.gd" };
		await Promise.all(Object.entries(srcPaths).map(async ([k, p]) => {
			try { src[k] = (await ghFile(p)).text; } catch (e) { src[k] = ""; }
		}));
		S.cfg = M.configFromSources(src);
		setLoading("Leyendo " + dialogueFiles.length + " diálogos…");
		const files = await Promise.all(dialogueFiles.map(async (e) => {
			const f = await ghFile(e.path);
			const parsed = M.parseFile(e.name.slice(0, -9), f.text, S.cfg);
			parsed.sha = f.sha;
			parsed.path = e.path;
			return parsed;
		}));
		S.profiles = {};
		try {
			const chars = await gh("/contents/src/data/characters?ref=" + encodeURIComponent(S.repo.branch));
			await Promise.all(chars.filter((e) => e.name.endsWith(".json")).map(async (e) => {
				try { S.profiles[e.name.slice(0, -5)] = JSON.parse((await ghFile(e.path)).text); } catch (err) { /* ficha ilegible */ }
			}));
		} catch (e) { /* sin fichas: valores neutros */ }
		S.files = files.sort((a, b) => a.name.localeCompare(b.name));
		S.source = "github";
		afterLoad();
		restoreDraft();
	}

	function loadLocal(fileList) {
		const read = Array.from(fileList).filter((f) => f.name.endsWith(".dialogue")).map((f) => f.text().then((text) => {
			const p = M.parseFile(f.name.slice(0, -9), text, S.cfg);
			p.path = DIALOGUE_DIR + "/" + f.name;
			return p;
		}));
		if (!read.length) { toast("Elige archivos .dialogue", true); return; }
		Promise.all(read).then((files) => {
			S.files = files.sort((a, b) => a.name.localeCompare(b.name));
			S.source = "local";
			if (!S.cfg.characters.length) {
				S.cfg = Object.assign({}, S.cfg, { characters: files.map((f) => ({ id: f.name, name: f.name, color: "#8d8d96" })) });
			}
			afterLoad();
			closeSheet();
			toast("Abiertos " + files.length + " archivos locales");
		});
	}

	function afterLoad() {
		S.sel = null;
		rebuildRules();
		initSim();
		$("#src-label").textContent = S.source === "github"
			? S.repo.owner + "/" + S.repo.repo + " · " + S.repo.branch
			: "Archivos locales";
		setLoading(null);
		renderAll();
	}

	function setLoading(text) {
		const el = $("#loading");
		if (text === null) { el.style.display = "none"; return; }
		el.style.display = "flex";
		$("#loading-text").textContent = text;
	}

	// --- Borrador automático (en este navegador) --------------------------------------------------

	function draftKey() { return "borrador:" + S.repo.owner + "/" + S.repo.repo + "@" + S.repo.branch; }
	let draftTimer = 0;
	function saveDraftSoon() {
		clearTimeout(draftTimer);
		draftTimer = setTimeout(() => {
			if (S.source !== "github") return;
			const changed = changedFiles();
			if (!changed.length) { saveJSON(draftKey(), null); return; }
			saveJSON(draftKey(), { at: Date.now(), files: changed.map((f) => ({ name: f.name, sha: f.sha || "", text: f.deleted ? null : M.serializeFile(f), isNew: !!f.isNew })) });
		}, 400);
	}

	function restoreDraft() {
		const d = loadJSON(draftKey(), null);
		if (!d || !d.files || !d.files.length) return;
		const stale = d.files.some((df) => { const f = S.files.find((x) => x.name === df.name); return f ? f.sha !== df.sha : !df.isNew; });
		const when = new Date(d.at).toLocaleString("es-ES");
		openSheet(`<h3>Hay cambios sin guardar</h3>
			<p>Quedó un borrador del ${esc(when)} con cambios en <b>${d.files.map((f) => esc(f.name)).join(", ")}</b>.</p>
			${stale ? '<p class="warn">⚠ Algún archivo ha cambiado en GitHub desde entonces. Si lo recuperas, revisa las diferencias antes de guardar: tu versión sustituiría a la nueva.</p>' : ""}
			<div class="row"><button class="btn lime" id="d-yes">Recuperar borrador</button><button class="btn ghost" id="d-no">Descartarlo</button></div>`);
		$("#d-yes").onclick = () => {
			for (const df of d.files) {
				let f = S.files.find((x) => x.name === df.name);
				if (df.text === null) { if (f) f.deleted = true; continue; }
				const p = M.parseFile(df.name, df.text, S.cfg);
				if (f) {
					// Conserva el original de GitHub para que se vea como cambio.
					p.original = f.original; p.sha = f.sha; p.path = f.path;
					const orig = new Map(M.parseFile(f.name, f.original, S.cfg).cues.map((c) => [c.name, c.raw]));
					for (const c of p.cues) c.dirty = orig.get(c.name) !== c.raw;
					S.files[S.files.indexOf(f)] = p;
				} else {
					p.original = ""; p.isNew = true; p.path = DIALOGUE_DIR + "/" + df.name + ".dialogue";
					S.files.push(p);
				}
			}
			rebuildRules(); closeSheet(); renderAll(); toast("Borrador recuperado");
		};
		$("#d-no").onclick = () => { saveJSON(draftKey(), null); closeSheet(); };
	}

	// --- Modelo -------------------------------------------------------------------------------

	function rebuildRules() {
		S.rules = M.buildRules(S.files.filter((f) => !f.deleted));
		saveDraftSoon();
	}

	function touch(cue, rule, crit) {
		if (crit) crit.dirty = true;
		if (rule) rule.dirty = true;
		cue.dirty = true;
		rebuildRules();
		renderBadges();
		renderList();
		renderSim();
	}

	function knownValues() {
		const cues = allCues();
		const used = (kind) => [...new Set(cues.flatMap((c) => c.rules.flatMap((r) => r.criteria.filter((x) => x.kind === kind).map((x) => x.arg))))].filter(Boolean).sort();
		const fromBodies = (re) => [...new Set(cues.flatMap((c) => [...c.body.matchAll(re)].map((m) => m[1])))];
		const moments = [...new Set(MOMENTS.concat(Object.keys(S.rules.byMoment)))];
		return {
			moments,
			cues: cues.map((c) => c.name).sort(),
			events: [...new Set(used("knows").concat(fromBodies(/Story\.tell\(\s*"[^"]*"\s*,\s*"([^"]+)"/g)))].sort(),
			flags: [...new Set(used("flag").concat(fromBodies(/Story\.set_flag\(\s*"([^"]+)"/g)))].sort(),
		};
	}

	// --- Validación ----------------------------------------------------------------------------

	function validateCue(cue) {
		const out = [];
		const cfg = S.cfg;
		const cueNames = new Set(allCues().map((c) => c.name));
		const speakers = new Set(cfg.characters.map((c) => c.name).concat(["Ren", "{{Story.speaker}}"]));
		const dup = allCues().filter((c) => c.name === cue.name).length;
		if (dup > 1) out.push(["err", "Hay " + dup + " cues con el nombre «" + cue.name + "»."]);
		if (!/^[a-z0-9_]+$/.test(cue.name)) out.push(["err", "El nombre solo puede tener minúsculas, números y _."]);
		if (!cue.rules.length) out.push(["info", "Sin reglas «cuando»: el selector nunca lo elige (solo sale si se llama desde el guion o con =>)."]);
		cue.rules.forEach((r, i) => {
			const n = cue.rules.length > 1 ? " (regla " + (i + 1) + ")" : "";
			for (const e of r.errors || []) out.push(["err", "Condición que el juego no entiende e ignora" + n + ": «" + e + "»."]);
			if (!r.moment) out.push(["err", "Regla sin momento" + n + "."]);
			else if (!MOMENTS.includes(r.moment)) out.push(["warn", "Momento «" + r.moment + "» poco habitual" + n + ": ¿lo usa el juego?"]);
			for (const c of r.criteria) {
				if (c.kind === "phase" && !cfg.phases.includes(c.arg)) out.push(["err", "Fase desconocida «" + c.arg + "»" + n + "."]);
				if (c.kind === "tier" && !cfg.tiers.includes(c.arg)) out.push(["err", "Tramo desconocido «" + c.arg + "»" + n + "."]);
				if (c.kind === "mood") {
					for (const m of c.arg.split("|")) if (!cfg.moods.includes(m)) out.push(["err", "Ánimo desconocido «" + m + "»" + n + "."]);
					if (c.op !== "=" && c.op !== "!=") out.push(["warn", "Con el ánimo solo valen = y != (el juego trata «" + c.op + "» como !=)" + n + "."]);
				}
				if (c.kind === "context" && c.op !== "=") out.push(["warn", "El juego ignora el operador «" + c.op + "» del resultado y lo trata como =" + n + "."]);
				if (c.kind === "present" && !charInfo(c.arg)) out.push(["err", "Personaje desconocido «" + c.arg + "»" + n + "."]);
				if (c.kind === "seen" && !cueNames.has(c.arg)) out.push(["warn", "No existe el cue «" + c.arg + "»" + n + "."]);
				if ((c.kind === "today" || c.kind === "times") && !/^\d+$/.test(c.arg)) out.push(["err", "«" + KIND_NAME[c.kind] + "» necesita un número" + n + "."]);
				if (c.kind === "dim" && isNaN(parseFloat(c.arg))) out.push(["err", "La dimensión necesita un número" + n + "."]);
			}
		});
		// Texto
		const lines = cue.body.split("\n");
		lines.forEach((raw, i) => {
			const t = raw.trim();
			const jump = t.match(/^=>\s*(\S+)/) || t.match(/^=><\s*(\S+)/);
			if (jump && !["END", "END!"].includes(jump[1]) && !cueNames.has(jump[1])) out.push(["err", "Línea " + (i + 1) + ": salta a «" + jump[1] + "», que no existe."]);
			for (const m of t.matchAll(/Story\.([a-z_]+)/g)) if (!STORY_FUNCS.includes(m[1])) out.push(["warn", "Línea " + (i + 1) + ": Story." + m[1] + " no existe."]);
			const sp = t.match(/^(?:%\s*)?([^:#\-=~$%\[\]{}][^:]{0,30}?):\s/);
			if (sp && !t.startsWith("if ") && !t.startsWith("elif") && !speakers.has(sp[1].trim())) out.push(["warn", "Línea " + (i + 1) + ": «" + sp[1].trim() + "» no es un personaje conocido."]);
		});
		if (!/=>\s*END/.test(cue.body) && cue.body.trim()) out.push(["info", "No termina con «=> END»."]);
		return out;
	}

	// --- Render: lista -------------------------------------------------------------------------

	function renderList() {
		const v = $("#v-lista");
		const known = knownValues();
		const fileNames = S.files.filter((f) => !f.deleted).map((f) => f.name);
		const q = S.filter.q.toLowerCase();
		const cues = allCues().filter((c) => !fileOf(c).deleted)
			.filter((c) => !S.filter.file || c.file === S.filter.file)
			.filter((c) => !S.filter.moment || c.rules.some((r) => r.moment === S.filter.moment))
			.filter((c) => !q || c.name.includes(q) || c.body.toLowerCase().includes(q));
		const fileChips = ['<span class="chip ' + (S.filter.file ? "" : "on") + '" data-file="">Todos</span>']
			.concat(fileNames.map((n) => `<span class="chip ${S.filter.file === n ? "on" : ""}" data-file="${esc(n)}" style="${S.filter.file === n ? "" : "border-color:" + charColor(n)}">${esc(charName(n))}</span>`)).join("");
		v.innerHTML = `
			<h2>Diálogos</h2>
			<input class="input" id="q" placeholder="Buscar por nombre o texto…" value="${esc(S.filter.q)}" autocomplete="off">
			<div class="chips" style="margin:10px 0">${fileChips}</div>
			<div class="row" style="margin-bottom:12px">
				<select class="input grow" id="f-moment"><option value="">Todos los momentos</option>${known.moments.map((m) => `<option ${S.filter.moment === m ? "selected" : ""}>${esc(m)}</option>`).join("")}</select>
				<button class="btn" id="new-cue">+ Nuevo</button>
			</div>
			<div class="muted small" style="margin-bottom:8px">${cues.length} cues</div>
			${cues.map(cueItem).join("") || '<div class="empty">Nada coincide con el filtro.</div>'}`;
		$("#q", v).oninput = (e) => { S.filter.q = e.target.value; renderListKeepFocus(); };
		v.querySelectorAll("[data-file]").forEach((el) => (el.onclick = () => { S.filter.file = el.dataset.file; renderList(); }));
		$("#f-moment", v).onchange = (e) => { S.filter.moment = e.target.value; renderList(); };
		$("#new-cue", v).onclick = newCueSheet;
		v.querySelectorAll(".cue-item").forEach((el) => (el.onclick = () => selectCue(el.dataset.cue, el.dataset.file, true)));
	}

	function renderListKeepFocus() {
		const pos = $("#q").selectionStart;
		renderList();
		const q = $("#q");
		q.focus();
		q.setSelectionRange(pos, pos);
	}

	function cueItem(c) {
		const issues = validateCue(c);
		const level = issues.some((i) => i[0] === "err") ? "err" : issues.some((i) => i[0] === "warn") ? "warn" : "";
		const rules = c.rules.map((r) => `<span class="tag">${esc(r.moment)}${r.criteria.length ? " · " + r.criteria.map((x) => esc(x.dirty || !x.raw ? M.criterionToText(x) : x.raw)).join(" · ") : ""}</span>`).join("") || '<span class="tag muted">sin reglas</span>';
		const sel = S.sel && S.sel.name === c.name && S.sel.file === c.file;
		return `<button class="cue-item ${sel ? "sel" : ""}" style="--c:${charColor(c.file)}" data-cue="${esc(c.name)}" data-file="${esc(c.file)}">
			<div class="row"><span class="name grow">${esc(c.name)}</span>${c.dirty ? '<span class="dot" title="Modificado"></span>' : ""}${level ? `<span class="${level}">${level === "err" ? "✕" : "⚠"}</span>` : ""}</div>
			<div class="meta"><span class="tag" style="color:${charColor(c.file)}">${esc(c.file)}</span>${rules}</div></button>`;
	}

	function selectCue(name, file, go) {
		S.sel = allCues().find((c) => c.name === name && c.file === file) || null;
		renderList();
		renderEditor();
		if (go) setView("editar");
	}

	// --- Render: editor ------------------------------------------------------------------------

	function renderEditor() {
		const v = $("#v-editar");
		const c = S.sel;
		if (!c) { v.innerHTML = '<h2>Editar</h2><div class="empty">Elige un diálogo de la lista.</div>'; return; }
		const known = knownValues();
		const issues = validateCue(c);
		const fileOpts = S.files.filter((f) => !f.deleted).map((f) => `<option ${f.name === c.file ? "selected" : ""}>${esc(f.name)}</option>`).join("");
		v.innerHTML = `
			<h2>Editar</h2>
			<div class="field"><label>Nombre del cue</label>
				<div class="row"><input class="input grow" id="e-name" value="${esc(c.name)}" autocapitalize="off" autocomplete="off" spellcheck="false">
				<select class="input" style="width:auto" id="e-file" title="Archivo">${fileOpts}</select></div></div>
			<div class="row" style="margin-bottom:6px">
				<button class="btn sm" id="e-sim">▶ Probar en el simulador</button>
				<button class="btn sm danger" id="e-del">Borrar</button>
			</div>
			<h2>Cuándo sale</h2>
			<div id="e-rules"></div>
			<button class="btn" id="e-add-rule">+ Otra regla</button>
			<h2>Texto</h2>
			<div class="row" style="margin-bottom:8px"><div class="seg"><button data-m="texto" class="${S.bodyMode === "texto" ? "on" : ""}">Texto</button><button data-m="vista" class="${S.bodyMode === "vista" ? "on" : ""}">Vista previa</button></div></div>
			<div id="e-body"></div>
			<h2>Revisión</h2>
			<div class="issues">${issues.length ? issues.map((i) => `<div class="${i[0] === "info" ? "muted" : i[0]}">${i[0] === "err" ? "✕" : i[0] === "warn" ? "⚠" : "ℹ"} ${esc(i[1])}</div>`).join("") : '<div class="ok">✓ Sin problemas.</div>'}</div>`;
		renderRules(known);
		renderBody();
		$("#e-name", v).onchange = (e) => renameCue(c, e.target.value.trim());
		$("#e-file", v).onchange = (e) => moveCue(c, e.target.value);
		$("#e-sim", v).onclick = () => simulateCue(c);
		$("#e-del", v).onclick = () => deleteCueSheet(c);
		$("#e-add-rule", v).onclick = () => {
			c.rules.push({ moment: c.rules[0] ? c.rules[0].moment : "hablar", criteria: [], errors: [], dirty: true });
			touch(c); renderEditor();
		};
		v.querySelectorAll(".seg [data-m]").forEach((b) => (b.onclick = () => { S.bodyMode = b.dataset.m; renderEditor(); }));
	}

	function renderRules(known) {
		const c = S.sel;
		const box = $("#e-rules");
		const nm = names();
		box.innerHTML = c.rules.map((r, ri) => {
			const weight = r.criteria.reduce((s, x) => s + (S.cfg.weights[x.kind] !== undefined ? S.cfg.weights[x.kind] : 1), 0);
			const sentence = `Al <b>${esc(r.moment || "?")}</b>${c.file !== S.cfg.general ? " con <b>" + esc(charName(c.file)) + "</b>" : " (con cualquiera)"}` +
				(r.criteria.length ? ", " + r.criteria.map((x) => esc(M.describeCriterion(x, S.cfg, nm))).join(", ") : "") + ".";
			return `<div class="rule" data-ri="${ri}">
				<div class="row" style="margin-bottom:8px">
					<select class="input grow" data-act="moment">${known.moments.map((m) => `<option ${m === r.moment ? "selected" : ""}>${esc(m)}</option>`).join("")}${known.moments.includes(r.moment) ? "" : `<option selected>${esc(r.moment)}</option>`}</select>
					${c.rules.length > 1 ? '<button class="btn sm ghost" data-act="del-rule">Quitar regla</button>' : ""}
				</div>
				<div class="sentence small" style="margin-bottom:6px">${sentence}</div>
				<div class="muted small" style="margin-bottom:6px">Peso ${weight}${c.file !== S.cfg.general ? " · puntuación " + (weight * 2 + 1) : " · puntuación " + weight * 2 + " (genérico)"}</div>
				${r.criteria.map((x, ci) => critRow(x, ci, known)).join("")}
				${(r.errors || []).map((e, ei) => `<div class="crit"><span class="err">✕</span><div class="err small">El juego ignora «${esc(e)}»</div><button class="x" data-act="del-err" data-ei="${ei}">×</button></div>`).join("")}
				<button class="btn sm" data-act="add-crit" style="margin-top:6px">+ Condición</button>
			</div>`;
		}).join("") || '<div class="muted small" style="margin-bottom:10px">Sin reglas: el selector no lo elige nunca.</div>';
		box.querySelectorAll(".rule").forEach((el) => {
			const r = c.rules[+el.dataset.ri];
			el.querySelector('[data-act="moment"]').onchange = (e) => { r.moment = e.target.value; touch(c, r); renderEditor(); };
			const del = el.querySelector('[data-act="del-rule"]');
			if (del) del.onclick = () => { c.rules.splice(c.rules.indexOf(r), 1); touch(c); renderEditor(); };
			el.querySelector('[data-act="add-crit"]').onclick = () => {
				r.criteria.push({ kind: "phase", op: ">=", arg: S.cfg.phases[0], negate: false, dirty: true });
				touch(c, r); renderEditor();
			};
			el.querySelectorAll('[data-act="del-err"]').forEach((b) => (b.onclick = () => { r.errors.splice(+b.dataset.ei, 1); touch(c, r); renderEditor(); }));
			el.querySelectorAll(".crit[data-ci]").forEach((ce) => bindCrit(ce, c, r, r.criteria[+ce.dataset.ci]));
		});
	}

	function opSelect(x, ops) {
		return `<select class="input op" data-f="op">${ops.map((o) => `<option ${o === x.op ? "selected" : ""}>${o}</option>`).join("")}</select>`;
	}

	function critRow(x, ci, known) {
		const kindSel = `<select class="input" data-f="kind">${KINDS.map(([k, n]) => `<option value="${k}" ${k === x.kind ? "selected" : ""}>${n}</option>`).join("")}</select>`;
		const list = (id, vals) => `<datalist id="${id}">${vals.map((v) => `<option value="${esc(v)}">`).join("")}</datalist>`;
		let fields = "";
		switch (x.kind) {
			case "once": fields = '<span class="muted small" style="padding:10px 0">No se ha visto este cue nunca.</span>'; break;
			case "seen": fields = `<input class="input" data-f="arg" value="${esc(x.arg || "")}" list="dl-cues" placeholder="cue">${list("dl-cues", known.cues)}`; break;
			case "knows": fields = `<input class="input" data-f="arg" value="${esc(x.arg || "")}" list="dl-ev" placeholder="suceso">${list("dl-ev", known.events)}`; break;
			case "flag": fields = `<input class="input" data-f="arg" value="${esc(x.arg || "")}" list="dl-flag" placeholder="indicador">${list("dl-flag", known.flags)}`; break;
			case "present": fields = `<select class="input" data-f="arg">${S.cfg.characters.filter((ch) => !ch.enemy).map((ch) => `<option value="${ch.id}" ${ch.id === x.arg ? "selected" : ""}>${esc(ch.name)}</option>`).join("")}</select>`; break;
			case "phase": fields = opSelect(x, M.OPS) + `<select class="input" data-f="arg">${S.cfg.phases.map((p) => `<option ${p === x.arg ? "selected" : ""}>${p}</option>`).join("")}</select>`; break;
			case "tier": fields = opSelect(x, M.OPS) + `<select class="input" data-f="arg">${S.cfg.tiers.map((p) => `<option ${p === x.arg ? "selected" : ""}>${p}</option>`).join("")}</select>`; break;
			case "mood": {
				const on = (x.arg || "").split("|");
				fields = opSelect(x, ["=", "!="]) + `<div class="chips" data-f="multi">${S.cfg.moods.map((m) => `<span class="chip small ${on.includes(m) ? "on" : ""}" data-v="${m}">${m}</span>`).join("")}</div>`;
				break;
			}
			case "today": case "times": fields = opSelect(x, M.OPS) + `<input class="input" type="number" inputmode="numeric" min="0" data-f="arg" value="${esc(x.arg || "0")}">`; break;
			case "dim": fields = `<select class="input" data-f="dim">${Object.keys(S.cfg.dims).map((d) => `<option ${d === x.dim ? "selected" : ""}>${d}</option>`).join("")}</select>` + opSelect(x, M.OPS) + `<input class="input" type="number" inputmode="numeric" data-f="arg" value="${esc(x.arg || "0")}">`; break;
			case "context": {
				const on = (x.arg || "").split("|");
				fields = `<div class="chips" data-f="multi">${["gana", "pierde"].map((m) => `<span class="chip small ${on.includes(m) ? "on" : ""}" data-v="${m}">${m}</span>`).join("")}</div>`;
				break;
			}
		}
		return `<div class="crit" data-ci="${ci}">
			<button class="neg ${x.negate ? "on" : ""}" data-f="neg" title="Negar (no)">no</button>
			<div class="fields">${kindSel}${fields}</div>
			<button class="x" data-f="del" title="Quitar">×</button></div>`;
	}

	function bindCrit(el, cue, rule, x) {
		const done = (rerender) => { touch(cue, rule, x); if (rerender) renderEditor(); else refreshSentence(); };
		el.querySelector('[data-f="neg"]').onclick = () => { x.negate = !x.negate; done(true); };
		el.querySelector('[data-f="del"]').onclick = () => { rule.criteria.splice(rule.criteria.indexOf(x), 1); done(true); };
		el.querySelector('[data-f="kind"]').onchange = (e) => {
			const k = e.target.value;
			const defaults = {
				once: {}, seen: { arg: "" }, knows: { arg: knownValues().events[0] || "" }, flag: { arg: "" },
				present: { arg: (S.cfg.characters.find((c) => !c.enemy && c.id !== S.cfg.protagonist) || {}).id || "" },
				phase: { op: ">=", arg: S.cfg.phases[0] }, tier: { op: ">=", arg: "neutral" }, mood: { op: "=", arg: S.cfg.moods[0] },
				today: { op: ">=", arg: "2" }, times: { op: ">=", arg: "2" }, dim: { dim: "afecto", op: ">=", arg: "20" },
				context: { key: "resultado", op: "=", arg: "gana" },
			};
			for (const key of ["op", "arg", "dim", "key"]) delete x[key];
			Object.assign(x, { kind: k }, defaults[k]);
			done(true);
		};
		const op = el.querySelector('[data-f="op"]');
		if (op) op.onchange = (e) => { x.op = e.target.value; done(false); };
		const dim = el.querySelector('[data-f="dim"]');
		if (dim) dim.onchange = (e) => { x.dim = e.target.value; done(false); };
		const arg = el.querySelector('[data-f="arg"]');
		if (arg) {
			const ev = arg.tagName === "SELECT" ? "change" : "input";
			arg.addEventListener(ev, (e) => { x.arg = e.target.value.trim(); touch(cue, rule, x); refreshSentence(); });
			if (ev === "input") arg.addEventListener("change", () => renderEditor());
		}
		const multi = el.querySelector('[data-f="multi"]');
		if (multi) multi.querySelectorAll(".chip").forEach((ch) => (ch.onclick = () => {
			const on = new Set((x.arg || "").split("|").filter(Boolean));
			on.has(ch.dataset.v) ? on.delete(ch.dataset.v) : on.add(ch.dataset.v);
			if (!on.size) { toast("Deja al menos uno marcado", true); return; }
			x.arg = [...on].join("|");
			done(true);
		}));
	}

	function refreshSentence() {
		// Actualiza frases y revisión sin perder el foco del campo que se edita.
		const c = S.sel;
		const nm = names();
		document.querySelectorAll("#e-rules .rule").forEach((el) => {
			const r = c.rules[+el.dataset.ri];
			const s = el.querySelector(".sentence");
			if (s) s.innerHTML = `Al <b>${esc(r.moment)}</b>${c.file !== S.cfg.general ? " con <b>" + esc(charName(c.file)) + "</b>" : " (con cualquiera)"}` +
				(r.criteria.length ? ", " + r.criteria.map((x) => esc(M.describeCriterion(x, S.cfg, nm))).join(", ") : "") + ".";
		});
	}

	function renderBody() {
		const c = S.sel;
		const box = $("#e-body");
		if (S.bodyMode === "vista") { box.innerHTML = `<div class="card preview">${previewHTML(c.body)}</div>`; return; }
		box.innerHTML = `
			<div class="toolbar">
				<button class="btn sm" data-ins="\t">⇥ Sangría</button>
				<button class="btn sm" data-ins="${esc(charName(c.file))}: ">${esc(charName(c.file))}:</button>
				<button class="btn sm" data-ins="Ren: ">Ren:</button>
				<button class="btn sm" data-ins="- ">- Opción</button>
				<button class="btn sm" data-ins=" [#franco]">[#estilo]</button>
				<button class="btn sm" data-ins="% ">% Variante</button>
				<button class="btn sm" data-ins="$> Story.change(&quot;${esc(c.file)}&quot;, &quot;afecto&quot;, 2)">$> cambio</button>
				<button class="btn sm" data-ins="=> END">=> END</button>
			</div>
			<textarea class="input code" id="e-text" spellcheck="false" autocapitalize="off" autocorrect="off">${esc(c.body)}</textarea>
			<div class="muted small" style="margin-top:6px">Sintaxis de Dialogue Manager. Las líneas sin «Nombre:» son del narrador; las respuestas empiezan por «- ». Sangría con tabulador.</div>`;
		const ta = $("#e-text");
		const commit = () => { c.body = ta.value; c.dirty = true; rebuildRules(); renderBadges(); renderList(); };
		ta.oninput = commit;
		ta.onchange = () => renderEditor();
		ta.onkeydown = (e) => {
			if (e.key === "Tab") { e.preventDefault(); insertAt(ta, "\t"); commit(); }
		};
		box.querySelectorAll("[data-ins]").forEach((b) => (b.onclick = () => { insertAt(ta, b.dataset.ins); commit(); }));
	}

	function insertAt(ta, text) {
		const s = ta.selectionStart, e = ta.selectionEnd;
		ta.value = ta.value.slice(0, s) + text + ta.value.slice(e);
		ta.selectionStart = ta.selectionEnd = s + text.length;
		ta.focus();
	}

	function previewHTML(body) {
		const byName = Object.fromEntries(S.cfg.characters.map((c) => [c.name, c.color]));
		return body.split("\n").map((raw) => {
			const ind = (raw.match(/^\t*/) || [""])[0].length;
			let t = raw.trim();
			if (!t) return "";
			let cls = "", html = esc(t);
			if (t.startsWith("#")) cls = "cmt";
			else if (/^(\$>|if |elif |else|=>|do |set |%\s*$)/.test(t)) cls = "code";
			else {
				const isOpt = t.startsWith("- ");
				if (isOpt) t = t.slice(2);
				if (t.startsWith("% ")) t = t.slice(2);
				const tags = (t.match(/\[#[^\]]*\]/g) || []).join(" ");
				t = t.replace(/\s*\[#[^\]]*\]/g, "");
				const m = t.match(/^([^:]{1,30}):\s(.*)$/);
				if (m && !isOpt) {
					const color = byName[m[1]] || (m[1].includes("speaker") ? "#c6f432" : "#f2f2f4");
					html = `<span class="sp" style="color:${color}">${esc(m[1])}:</span> ${esc(m[2].replace(/\\:/g, ":"))}`;
				} else {
					html = esc(t.replace(/\\:/g, ":"));
					cls = isOpt ? "opt" : "narr";
					if (isOpt) html = "▸ " + html;
				}
				if (tags) html += ` <span class="chip small" style="pointer-events:none">${esc(tags)}</span>`;
			}
			return `<div class="l ${cls}" style="--ind:${ind}">${html}</div>`;
		}).join("");
	}

	// --- Operaciones sobre cues ----------------------------------------------------------------

	function renameCue(c, name) {
		if (name === c.name) return;
		if (!/^[a-z0-9_]+$/.test(name)) { toast("Solo minúsculas, números y _", true); renderEditor(); return; }
		if (allCues().some((x) => x.name === name)) { toast("Ya existe un cue con ese nombre", true); renderEditor(); return; }
		const old = c.name;
		let refs = 0;
		for (const x of allCues()) {
			for (const r of x.rules) for (const cr of r.criteria) if (cr.kind === "seen" && cr.arg === old) { cr.arg = name; cr.dirty = true; r.dirty = true; x.dirty = true; refs++; }
			const nb = x.body.replace(new RegExp("(=><?\\s*)" + old + "\\b", "g"), (m, p) => { refs++; return p + name; });
			if (nb !== x.body) { x.body = nb; x.dirty = true; }
		}
		c.name = name;
		c.dirty = true;
		rebuildRules();
		renderAll();
		toast("Renombrado" + (refs ? " · " + refs + " referencias actualizadas" : "") + ". Si el código lo usa con Story.cue(\"" + old + "\"), cámbialo también.");
	}

	function moveCue(c, fileName) {
		const from = fileOf(c), to = S.files.find((f) => f.name === fileName);
		if (!to || from === to) return;
		from.cues.splice(from.cues.indexOf(c), 1);
		c.file = to.name;
		c.dirty = true;
		to.cues.push(c);
		rebuildRules();
		renderAll();
		toast("Movido a " + to.name);
	}

	function newCueSheet() {
		const files = S.files.filter((f) => !f.deleted);
		const def = S.filter.file || (S.sel ? S.sel.file : files[0].name);
		openSheet(`<h3>Nuevo diálogo</h3>
			<div class="field"><label>Archivo (personaje)</label><select class="input" id="n-file">${files.map((f) => `<option ${f.name === def ? "selected" : ""}>${esc(f.name)}</option>`).join("")}</select></div>
			<div class="field"><label>Nombre del cue</label><input class="input" id="n-name" placeholder="p. ej. kenji_hablar_lluvia" autocapitalize="off" spellcheck="false"></div>
			<div class="field"><label>Momento</label><select class="input" id="n-moment">${MOMENTS.map((m) => `<option>${m}</option>`).join("")}</select></div>
			<div class="row"><button class="btn lime" id="n-ok">Crear</button><button class="btn ghost" id="n-cancel">Cancelar</button></div>`);
		const upd = () => { const n = $("#n-name"); if (!n.value) n.placeholder = $("#n-file").value + "_" + $("#n-moment").value + "_"; };
		$("#n-file").onchange = upd; $("#n-moment").onchange = upd; upd();
		$("#n-cancel").onclick = closeSheet;
		$("#n-ok").onclick = () => {
			const name = $("#n-name").value.trim();
			const file = S.files.find((f) => f.name === $("#n-file").value);
			if (!/^[a-z0-9_]+$/.test(name)) { toast("Nombre: solo minúsculas, números y _", true); return; }
			if (allCues().some((x) => x.name === name)) { toast("Ya existe ese nombre", true); return; }
			const speaker = charInfo(file.name) ? charName(file.name) : "{{Story.speaker}}";
			const cue = { name, file: file.name, rules: [{ moment: $("#n-moment").value, criteria: [], errors: [], dirty: true }],
				body: speaker + ": ...\n=> END\n", dirty: true };
			file.cues.push(cue);
			rebuildRules();
			closeSheet();
			selectCue(name, file.name, true);
			toast("Creado " + name);
		};
	}

	function deleteCueSheet(c) {
		openSheet(`<h3>¿Borrar «${esc(c.name)}»?</h3><p class="muted">Se quita de ${esc(c.file)}.dialogue. No se sube nada hasta que guardes.</p>
			<div class="row"><button class="btn danger" id="x-ok">Borrar</button><button class="btn ghost" id="x-no">Cancelar</button></div>`);
		$("#x-no").onclick = closeSheet;
		$("#x-ok").onclick = () => {
			const f = fileOf(c);
			f.cues.splice(f.cues.indexOf(c), 1);
			S.sel = null;
			rebuildRules();
			closeSheet();
			renderAll();
			setView("lista");
			toast("Borrado " + c.name);
		};
	}

	// --- Simulador -----------------------------------------------------------------------------

	function initialFor(who) {
		const p = S.profiles[who] || {};
		const rel = ((p.relationships || {})[S.cfg.protagonist]) || {};
		const dims = {};
		for (const d in S.cfg.dims) dims[d] = rel[d] !== undefined ? Number(rel[d]) : 0;
		const mood = ((p.mood || {}).initial || {}).id || "tranquilo";
		return { dims, mood };
	}

	function initSim() {
		const who = (S.files.find((f) => charInfo(f.name) && f.name !== S.cfg.protagonist) || { name: "kenji" }).name;
		const ini = initialFor(who);
		S.sim = { who, moment: "hablar", phase: S.cfg.phases[0], mood: ini.mood, dims: ini.dims, today: 1, times: 1,
			resultado: "", knows: [], flags: [], present: [], seen: [] };
		S.save = null;
	}

	function simulateCue(c) {
		if (charInfo(c.file) && c.file !== S.cfg.general) setWho(c.file);
		if (c.rules[0]) S.sim.moment = c.rules[0].moment;
		renderSim();
		setView("simular");
	}

	function setWho(who) {
		S.sim.who = who;
		if (S.save) applySave();
		else { const ini = initialFor(who); S.sim.dims = ini.dims; S.sim.mood = ini.mood; }
	}

	function applySave() {
		const d = S.save, who = S.sim.who, ren = S.cfg.protagonist;
		S.sim.phase = d.phase || S.cfg.phases[0];
		const flags = Object.keys(d.flags || {}).filter((k) => d.flags[k]);
		S.sim.flags = flags.filter((k) => !k.startsWith("visto:"));
		S.sim.seen = flags.filter((k) => k.startsWith("visto:")).map((k) => k.slice(6));
		S.sim.mood = ((d.moods || {})[who] || {}).id || initialFor(who).mood;
		const rel = ((d.relations || {})[who] || {})[ren] || {};
		for (const k in S.cfg.dims) S.sim.dims[k] = rel[k] !== undefined ? Math.round(rel[k]) : initialFor(who).dims[k];
		const ev = (d.events || {});
		S.sim.knows = ((ev.knowledge || {})[who]) || [];
		const today = (ev.events || []).filter((e) => e.actor === ren && e.target === who && JSON.stringify(e.date) === JSON.stringify(d.date));
		S.sim.today = today.filter((e) => ["talk", "flirt", "fight"].includes(e.kind) && ((e.data || {}).result || "ok") === "ok").length;
		let action = "";
		for (const a in S.cfg.actionMoments) if (S.sim.moment.endsWith(S.cfg.actionMoments[a])) action = a;
		S.sim.times = today.filter((e) => e.kind === action).length;
	}

	function renderSim() {
		const v = $("#v-simular");
		if (!S.sim) { v.innerHTML = ""; return; }
		const sim = S.sim, cfg = S.cfg, known = knownValues();
		const whos = S.files.filter((f) => !f.deleted && charInfo(f.name) && f.name !== cfg.protagonist).map((f) => f.name);
		for (const c of cfg.characters) if (!c.enemy && c.id !== cfg.protagonist && !whos.includes(c.id)) whos.push(c.id);
		const ctx = sim.resultado ? { resultado: sim.resultado } : {};
		const st = M.simState(sim, cfg);
		const cands = M.candidates(S.rules, sim.who, sim.moment, ctx, st, cfg);
		const winners = cands.filter((x) => x.best);
		cands.sort((a, b) => (b.best - a.best) || (b.score - a.score) || a.rule.cue.localeCompare(b.rule.cue));
		const tier = M.tierFromDims(sim.dims);
		const relevantSeen = [...new Set(allCues().filter((c) => c.rules.some((r) => r.criteria.some((x) => x.kind === "once"))).map((c) => c.name)
			.concat(known.cues.filter((n) => allCues().some((c) => c.rules.some((r) => r.criteria.some((x) => x.kind === "seen" && x.arg === n))))))]
			.filter((n) => S.rules.byMoment[sim.moment] && S.rules.byMoment[sim.moment].some((r) => r.cue === n && (r.file === sim.who || r.file === cfg.general)) || sim.seen.includes(n));
		let mapped = false;
		for (const a in cfg.actionMoments) if (sim.moment.endsWith(cfg.actionMoments[a])) mapped = true;

		v.innerHTML = `
			<h2>¿Qué diálogo sale?</h2>
			<div class="param"><label>Personaje</label><select class="input" id="s-who">${whos.map((w) => `<option value="${w}" ${w === sim.who ? "selected" : ""}>${esc(charName(w))}</option>`).join("")}</select></div>
			<div class="param"><label>Momento</label><select class="input" id="s-moment">${known.moments.map((m) => `<option ${m === sim.moment ? "selected" : ""}>${m}</option>`).join("")}</select></div>
			${resultHTML(winners, cands)}
			<div id="s-cands">${cands.map((x) => candHTML(x)).join("") || '<div class="empty">No hay reglas para este momento.</div>'}</div>

			<h2>Situación</h2>
			<div class="row" style="margin-bottom:10px">
				<button class="btn sm" id="s-reset">Inicio de partida</button>
				<label class="btn sm" style="cursor:pointer">Cargar partida…<input type="file" id="s-save" accept=".json,application/json" hidden></label>
			</div>
			${S.save ? '<div class="small ok" style="margin-bottom:8px">Usando la partida cargada (fase, indicadores, ánimo, relación, lo que sabe e interacciones de ese día).</div>' : ""}
			<div class="param"><label>Fase</label><select class="input" id="s-phase">${cfg.phases.map((p) => `<option ${p === sim.phase ? "selected" : ""}>${p}</option>`).join("")}</select></div>
			<div class="param"><label>Ánimo</label><div class="chips" id="s-mood">${cfg.moods.map((m) => `<span class="chip small ${m === sim.mood ? "on" : ""}" data-v="${m}">${m}</span>`).join("")}</div></div>
			<div class="param"><label>Hoy</label><div class="stepper" data-k="today"><button>−</button><span>${sim.today}</span><button>+</button><span class="muted small">interacciones</span></div></div>
			<div class="param"><label>Veces</label><div class="stepper" data-k="times"><button>−</button><span>${sim.times}</span><button>+</button><span class="muted small">${mapped ? "esta acción hoy" : "no aplica a este momento"}</span></div></div>
			<div class="param"><label>Resultado</label><div class="chips" id="s-res">${["", "gana", "pierde"].map((r) => `<span class="chip small ${r === sim.resultado ? "on" : ""}" data-v="${r}">${r || "—"}</span>`).join("")}</div></div>

			<h2>Relación con Ren · <span style="color:var(--lime)">${tier}</span></h2>
			<div class="chips" style="margin-bottom:10px">${cfg.tiers.map((t) => `<span class="chip small ${t === tier ? "on" : ""}" data-tier="${t}">${t}</span>`).join("")}</div>
			${Object.keys(cfg.dims).map((d) => `<div class="param"><label>${d}</label><div class="slider"><input type="range" min="${cfg.dims[d][0]}" max="${cfg.dims[d][1]}" value="${sim.dims[d]}" data-dim="${d}"><input class="num" type="number" inputmode="numeric" value="${sim.dims[d]}" data-dimn="${d}"></div></div>`).join("")}

			<h2>Presentes</h2>
			<div class="chips">${cfg.characters.filter((c) => !c.enemy && c.id !== cfg.protagonist && c.id !== sim.who).map((c) => `<span class="chip small ${sim.present.includes(c.id) ? "on" : ""}" data-list="present" data-v="${c.id}">${esc(c.name)}</span>`).join("")}</div>
			<h2>Sabe (sucesos)</h2>
			<div class="chips">${known.events.map((e) => `<span class="chip small ${sim.knows.includes(e) ? "on" : ""}" data-list="knows" data-v="${esc(e)}">${esc(e)}</span>`).join("") || '<span class="muted small">Ninguna regla usa «sabe».</span>'}</div>
			<h2>Indicadores</h2>
			<div class="chips">${known.flags.map((e) => `<span class="chip small ${sim.flags.includes(e) ? "on" : ""}" data-list="flags" data-v="${esc(e)}">${esc(e)}</span>`).join("") || '<span class="muted small">Ninguno.</span>'}</div>
			<h2>Ya vistos</h2>
			<div class="muted small" style="margin-bottom:6px">Cues de este momento con «una vez» o que otras reglas exigen haber visto.</div>
			<div class="chips">${relevantSeen.map((e) => `<span class="chip small ${sim.seen.includes(e) ? "on" : ""}" data-list="seen" data-v="${esc(e)}">${esc(e)}</span>`).join("") || '<span class="muted small">Ninguno relevante.</span>'}</div>`;

		$("#s-who", v).onchange = (e) => { setWho(e.target.value); renderSim(); };
		$("#s-moment", v).onchange = (e) => { sim.moment = e.target.value; if (S.save) applySave(); renderSim(); };
		$("#s-phase", v).onchange = (e) => { sim.phase = e.target.value; renderSim(); };
		$("#s-reset", v).onclick = () => { S.save = null; const w = sim.who; initSim(); S.sim.who = w; setWho(w); S.sim.moment = sim.moment; renderSim(); toast("Situación de inicio de partida"); };
		$("#s-save", v).onchange = (e) => {
			const f = e.target.files[0];
			if (!f) return;
			f.text().then((t) => { S.save = JSON.parse(t); applySave(); renderSim(); toast("Partida cargada"); }).catch(() => toast("No es una partida válida", true));
		};
		v.querySelectorAll("#s-mood .chip").forEach((c) => (c.onclick = () => { sim.mood = c.dataset.v; renderSim(); }));
		v.querySelectorAll("#s-res .chip").forEach((c) => (c.onclick = () => { sim.resultado = c.dataset.v; renderSim(); }));
		v.querySelectorAll(".stepper").forEach((s) => {
			const k = s.dataset.k;
			const [minus, plus] = s.querySelectorAll("button");
			minus.onclick = () => { sim[k] = Math.max(0, sim[k] - 1); renderSim(); };
			plus.onclick = () => { sim[k] = sim[k] + 1; renderSim(); };
		});
		v.querySelectorAll("[data-tier]").forEach((c) => (c.onclick = () => {
			const mid = { hostil: -70, fria: -25, neutral: 5, cercana: 40, intima: 75 }[c.dataset.tier];
			sim.dims.afecto = mid; sim.dims.resentimiento = 0; sim.dims.asco = 0; renderSim();
		}));
		v.querySelectorAll("[data-dim]").forEach((r) => (r.oninput = () => {
			sim.dims[r.dataset.dim] = +r.value;
			v.querySelector(`[data-dimn="${r.dataset.dim}"]`).value = r.value;
			renderSimResults();
		}));
		v.querySelectorAll("[data-dim]").forEach((r) => (r.onchange = () => renderSim()));
		v.querySelectorAll("[data-dimn]").forEach((n) => (n.onchange = () => { sim.dims[n.dataset.dimn] = +n.value || 0; renderSim(); }));
		v.querySelectorAll("[data-list]").forEach((c) => (c.onclick = () => {
			const list = sim[c.dataset.list];
			const i = list.indexOf(c.dataset.v);
			i >= 0 ? list.splice(i, 1) : list.push(c.dataset.v);
			renderSim();
		}));
		bindCands(v);
	}

	// Solo resultados (al arrastrar un deslizador, sin redibujar los controles).
	function renderSimResults() {
		const sim = S.sim, cfg = S.cfg;
		const ctx = sim.resultado ? { resultado: sim.resultado } : {};
		const cands = M.candidates(S.rules, sim.who, sim.moment, ctx, M.simState(sim, cfg), cfg);
		const winners = cands.filter((x) => x.best);
		cands.sort((a, b) => (b.best - a.best) || (b.score - a.score) || a.rule.cue.localeCompare(b.rule.cue));
		const main = $("#v-simular .result-main, #v-simular .result-none");
		if (main) main.outerHTML = resultHTML(winners, cands);
		$("#s-cands").innerHTML = cands.map(candHTML).join("");
		bindCands($("#v-simular"));
	}

	function bindCands(v) {
		v.querySelectorAll(".cand, .result-main [data-cue]").forEach((el) => (el.onclick = () => selectCue(el.dataset.cue, el.dataset.file, true)));
	}

	function resultHTML(winners, cands) {
		if (!winners.length) return `<div class="card result-none"><b class="err">No sale ningún diálogo.</b><div class="muted small">Ninguna regla de este momento se cumple${cands.length ? "" : " (no hay reglas)"}. En el juego no se abriría conversación.</div></div>`;
		const names = winners.map((w) => `<div class="big" data-cue="${esc(w.rule.cue)}" data-file="${esc(w.rule.file)}" style="cursor:pointer">${esc(w.rule.cue)}</div>`).join("");
		return `<div class="result-main"><div class="muted small">${winners.length > 1 ? "Empate: el juego elige uno al azar entre " + winners.length : "Sale"}</div>${names}<div class="muted small">puntuación ${winners[0].score}</div></div>`;
	}

	function candHTML(x) {
		const sim = S.sim;
		let why = "";
		if (x.score < 0) {
			const c = x.rule.criteria[x.failedIndex];
			why = `<div class="small err">Falla: ${esc(c.raw && !c.dirty ? c.raw : M.criterionToText(c))}${esc(actualValue(c, x.rule))}</div>`;
		} else if (!x.best) {
			why = `<div class="small muted">Se cumple, pero otra regla es más específica.</div>`;
		}
		const crit = x.rule.criteria.map((c) => esc(c.raw && !c.dirty ? c.raw : M.criterionToText(c))).join(" · ") || "sin condiciones";
		return `<div class="cand ${x.best ? "win" : x.score < 0 ? "fail" : ""}" data-cue="${esc(x.rule.cue)}" data-file="${esc(x.rule.file)}">
			<span>${x.best ? "★" : x.score < 0 ? "✕" : "✓"}</span>
			<div style="min-width:0"><div class="nm" style="word-break:break-all">${esc(x.rule.cue)} ${x.rule.file === S.cfg.general ? '<span class="tag">general</span>' : ""}</div>
			<div class="small muted">${crit}</div>${why}</div>
			<span class="score">${x.score < 0 ? "—" : x.score}</span></div>`;
	}

	function actualValue(c, rule) {
		const sim = S.sim;
		switch (c.kind) {
			case "once": return " (ya visto)";
			case "seen": return " (no visto)";
			case "phase": return " (ahora: " + sim.phase + ")";
			case "tier": return " (ahora: " + M.tierFromDims(sim.dims) + ")";
			case "mood": return " (ahora: " + sim.mood + ")";
			case "today": return " (ahora: " + sim.today + ")";
			case "times": return " (ahora: " + M.simState(sim, S.cfg).timesToday(sim.who, sim.moment) + ")";
			case "dim": return " (ahora: " + sim.dims[c.dim] + ")";
			case "context": return " (ahora: " + (sim.resultado || "—") + ")";
			case "present": return c.negate ? " (está)" : " (no está)";
			case "knows": return c.negate ? " (lo sabe)" : " (no lo sabe)";
			case "flag": return c.negate ? " (activo)" : " (no activo)";
		}
		return "";
	}

	// --- Guardar --------------------------------------------------------------------------------

	function renderSave(target) {
		const v = target || $("#v-guardar");
		const changed = changedFiles();
		const summary = (f) => {
			if (f.deleted) return "archivo borrado";
			const { added, removed, edited } = cueChanges(f);
			return [added.length && "+" + added.join(", +"), removed.length && "−" + removed.join(", −"), edited.length && "editados: " + edited.join(", ")].filter(Boolean).join(" · ");
		};
		const canPush = S.source === "github" && S.token;
		v.innerHTML = `
			<h2>Guardar</h2>
			${changed.length ? "" : '<div class="empty">No hay cambios.</div>'}
			${changed.map((f) => `<div class="card"><div class="row"><b class="grow">${esc(f.name)}.dialogue</b><button class="btn sm ghost" data-diff="${esc(f.name)}">Ver cambios</button></div>
				<div class="small muted" style="margin-top:4px">${esc(summary(f))}</div><div class="diff" data-diffbox="${esc(f.name)}" style="display:none;margin-top:8px"></div></div>`).join("")}
			${changed.length ? `
			<div class="field"><label>Mensaje del commit</label><input class="input" id="g-msg" value="${esc(defaultMessage(changed))}"></div>
			<div class="row">
				${S.source === "github" ? `<button class="btn lime" id="g-push" ${canPush ? "" : "disabled"}>Guardar en GitHub</button>` : ""}
				<button class="btn" id="g-dl">Descargar archivos</button>
				<button class="btn ghost danger" id="g-discard">Descartar cambios</button>
			</div>
			${S.source === "github" && !S.token ? '<p class="small warn">Para guardar en GitHub hace falta un token: ⋯ → Ajustes.</p>' : ""}
			<p class="small muted">Se sube un solo commit a <b>${esc(S.repo.branch)}</b> con «[contexto-ok]» en el mensaje: editar diálogos no cambia el contexto del proyecto (CLAUDE.md).</p>` : ""}`;
		v.querySelectorAll("[data-diff]").forEach((b) => (b.onclick = () => {
			const box = v.querySelector(`[data-diffbox="${b.dataset.diff}"]`);
			const f = S.files.find((x) => x.name === b.dataset.diff);
			box.style.display = box.style.display === "none" ? "block" : "none";
			box.innerHTML = diffHTML(f.original || "", f.deleted ? "" : M.serializeFile(f));
		}));
		const push = $("#g-push", v);
		if (push) push.onclick = () => pushToGitHub($("#g-msg", v).value);
		const dl = $("#g-dl", v);
		if (dl) dl.onclick = () => downloadChanged();
		const dis = $("#g-discard", v);
		if (dis) dis.onclick = () => {
			openSheet(`<h3>¿Descartar todos los cambios?</h3><div class="row"><button class="btn danger" id="dd-ok">Descartar</button><button class="btn ghost" id="dd-no">Cancelar</button></div>`);
			$("#dd-no").onclick = closeSheet;
			$("#dd-ok").onclick = () => {
				S.files = S.files.filter((f) => !f.isNew).map((f) => { const p = M.parseFile(f.name, f.original, S.cfg); p.sha = f.sha; p.path = f.path; return p; });
				saveJSON(draftKey(), null);
				closeSheet(); afterLoad(); toast("Cambios descartados");
			};
		};
	}

	function defaultMessage(changed) {
		const edited = changed.flatMap((f) => { const c = cueChanges(f); return c.added.concat(c.edited, c.removed); });
		const list = edited.slice(0, 3).join(", ") + (edited.length > 3 ? "…" : "");
		return "Diálogos: " + (list || changed.map((f) => f.name).join(", ")) + " [contexto-ok]";
	}

	function diffHTML(a, b) {
		const A = a.split("\n"), B = b.split("\n");
		// LCS por filas (los archivos son pequeños).
		const n = A.length, m = B.length;
		const dp = Array.from({ length: n + 1 }, () => new Uint16Array(m + 1));
		for (let i = n - 1; i >= 0; i--) for (let j = m - 1; j >= 0; j--) dp[i][j] = A[i] === B[j] ? dp[i + 1][j + 1] + 1 : Math.max(dp[i + 1][j], dp[i][j + 1]);
		const out = [];
		let i = 0, j = 0;
		while (i < n || j < m) {
			if (i < n && j < m && A[i] === B[j]) { out.push([" ", A[i]]); i++; j++; }
			else if (j < m && (i >= n || dp[i][j + 1] >= dp[i + 1][j])) { out.push(["+", B[j]]); j++; }
			else { out.push(["-", A[i]]); i++; }
		}
		// Solo las zonas cambiadas con 2 líneas de contexto.
		const keep = out.map((x, k) => x[0] !== " " || out.slice(Math.max(0, k - 2), k + 3).some((y) => y[0] !== " "));
		let html = "", gap = false;
		out.forEach((x, k) => {
			if (!keep[k]) { if (!gap) html += '<div class="h">···</div>'; gap = true; return; }
			gap = false;
			html += `<div class="${x[0] === "+" ? "a" : x[0] === "-" ? "d" : ""}">${x[0]} ${esc(x[1].replace(/\t/g, "→ "))}</div>`;
		});
		return html || '<div class="muted">Sin diferencias.</div>';
	}

	function downloadChanged() {
		for (const f of changedFiles()) {
			if (f.deleted) continue;
			const blob = new Blob([M.serializeFile(f)], { type: "text/plain;charset=utf-8" });
			const a = document.createElement("a");
			a.href = URL.createObjectURL(blob);
			a.download = f.name + ".dialogue";
			document.body.appendChild(a);
			a.click();
			setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 1000);
		}
		toast("Descargados. Cópialos a src/dialogue/ del proyecto.");
	}

	async function pushToGitHub(message) {
		const changed = changedFiles();
		const issues = changed.flatMap((f) => f.cues.flatMap((c) => validateCue(c).filter((i) => i[0] === "err").map((i) => c.name + ": " + i[1])));
		if (issues.length && !confirmIssues(issues, message)) return;
		await doPush(changed, message);
	}

	let pendingPush = null;
	function confirmIssues(issues, message) {
		openSheet(`<h3>Hay errores</h3><div class="issues">${issues.slice(0, 12).map((i) => `<div class="err">✕ ${esc(i)}</div>`).join("")}</div>
			<p class="muted small">El juego ignorará las condiciones que no entiende y los saltos a cues que no existen fallarán.</p>
			<div class="row"><button class="btn danger" id="ci-ok">Guardar igualmente</button><button class="btn ghost" id="ci-no">Revisar</button></div>`);
		$("#ci-no").onclick = closeSheet;
		$("#ci-ok").onclick = () => { closeSheet(); doPush(changedFiles(), message); };
		return false;
	}

	async function doPush(changed, message) {
		if (!message.includes("[contexto-ok]")) message += " [contexto-ok]";
		setLoading("Comprobando la versión de GitHub…");
		try {
			const ref = await gh("/git/ref/heads/" + encodeURIComponent(S.repo.branch));
			const head = ref.object.sha;
			// ¿Alguien ha cambiado estos archivos desde que los abrimos?
			const conflicts = [];
			for (const f of changed) {
				try {
					const cur = await gh("/contents/" + f.path + "?ref=" + head);
					if (f.isNew || cur.sha !== f.sha) conflicts.push(f.name);
				} catch (e) {
					if (e.status !== 404) throw e;
					if (!f.isNew) conflicts.push(f.name); // lo han borrado en GitHub
				}
			}
			if (conflicts.length) {
				setLoading(null);
				openSheet(`<h3>Conflicto</h3><p>En GitHub han cambiado <b>${conflicts.map(esc).join(", ")}</b> desde que los abriste (¿un push desde el Mac?).</p>
					<p class="muted small">Para no pisar ese trabajo, no se ha subido nada. Descarga tus archivos como copia, recarga desde GitHub y vuelve a aplicar tus cambios.</p>
					<div class="row"><button class="btn" id="cf-dl">Descargar mis archivos</button><button class="btn lime" id="cf-reload">Recargar desde GitHub</button></div>`);
				$("#cf-dl").onclick = downloadChanged;
				$("#cf-reload").onclick = () => { closeSheet(); start(); };
				return;
			}
			setLoading("Subiendo…");
			const commit = await gh("/git/commits/" + head);
			const tree = await gh("/git/trees", { method: "POST", body: {
				base_tree: commit.tree.sha,
				tree: changed.map((f) => f.deleted
					? { path: f.path, mode: "100644", type: "blob", sha: null }
					: { path: f.path, mode: "100644", type: "blob", content: M.serializeFile(f) }),
			} });
			const nc = await gh("/git/commits", { method: "POST", body: {
				message: message + "\n\nEditado con el editor de diálogos (web).", tree: tree.sha, parents: [head],
			} });
			await gh("/git/refs/heads/" + encodeURIComponent(S.repo.branch), { method: "PATCH", body: { sha: nc.sha, force: false } });
			saveJSON(draftKey(), null);
			setLoading(null);
			toast("Guardado en GitHub · " + nc.sha.slice(0, 7));
			await loadFromGitHub();
			setView("lista");
		} catch (e) {
			setLoading(null);
			const hint = e.status === 401 ? " El token no es válido." : e.status === 403 || e.status === 404 ? " ¿El token tiene permiso de escritura (Contents: Read and write) en este repositorio?" : e.status === 422 ? " La rama ha cambiado mientras subías: recarga y vuelve a intentarlo." : "";
			toast("No se pudo guardar: " + e.message + "." + hint, true);
		}
	}

	// --- Ajustes ---------------------------------------------------------------------------------

	function settingsSheet() {
		openSheet(`<h3>Ajustes</h3>
			<div class="field"><label>Repositorio (usuario/nombre)</label><input class="input" id="a-repo" value="${esc(S.repo.owner + "/" + S.repo.repo)}" autocapitalize="off"></div>
			<div class="field"><label>Rama</label><input class="input" id="a-branch" value="${esc(S.repo.branch)}" autocapitalize="off"></div>
			<div class="field"><label>Token de GitHub (solo para guardar)</label>
				<input class="input" id="a-token" type="password" value="${esc(S.token)}" placeholder="github_pat_…" autocomplete="off">
				<div class="small muted" style="margin-top:6px">Créalo en <a href="https://github.com/settings/personal-access-tokens/new" target="_blank" rel="noopener">github.com → Fine-grained token</a>: <i>Repository access</i> → solo este repositorio; <i>Permissions</i> → <b>Contents: Read and write</b>. Se guarda solo en este navegador.</div></div>
			<div class="row" style="margin-bottom:16px"><button class="btn lime" id="a-ok">Guardar y recargar</button><button class="btn ghost" id="a-forget">Olvidar token</button></div>
			<h3>Sin conexión</h3>
			<p class="small muted">Abre .dialogue de tu ordenador o móvil y descarga los cambios al terminar.</p>
			<label class="btn" style="display:inline-block;cursor:pointer">Abrir archivos .dialogue…<input type="file" id="a-files" accept=".dialogue,text/plain" multiple hidden></label>
			<p class="small muted" style="margin-top:16px">Consejo: en el móvil, «Añadir a pantalla de inicio» lo abre como una app.</p>
			<div class="row"><button class="btn ghost" id="a-close">Cerrar</button></div>`);
		$("#a-close").onclick = closeSheet;
		$("#a-forget").onclick = () => { S.token = ""; saveStr("token", ""); $("#a-token").value = ""; renderSaveAll(); toast("Token olvidado"); };
		$("#a-ok").onclick = () => {
			const [owner, repo] = $("#a-repo").value.trim().split("/");
			if (!owner || !repo) { toast("Formato: usuario/repositorio", true); return; }
			S.repo = { owner, repo, branch: $("#a-branch").value.trim() || "main" };
			S.token = $("#a-token").value.trim();
			saveJSON("repo", S.repo);
			saveStr("token", S.token);
			closeSheet();
			start();
		};
		$("#a-files").onchange = (e) => loadLocal(e.target.files);
	}

	// --- Hojas, vistas y arranque ------------------------------------------------------------------

	function openSheet(html) { $("#sheet").innerHTML = html; $("#sheet-bg").classList.add("open"); }
	function closeSheet() { $("#sheet-bg").classList.remove("open"); }
	$("#sheet-bg").addEventListener("click", (e) => { if (e.target.id === "sheet-bg") closeSheet(); });

	function setView(name) {
		S.view = name;
		document.querySelectorAll(".view").forEach((v) => v.classList.toggle("active", v.id === "v-" + name));
		document.querySelectorAll("nav button").forEach((b) => b.classList.toggle("active", b.dataset.v === name));
		if (name === "guardar") renderSave();
		const v = $("#v-" + name);
		if (v) v.scrollTop = 0;
	}

	function renderBadges() {
		const n = changedFiles().length;
		const html = n ? `<span class="badge">${n}</span>` : "";
		$("#badge-nav").innerHTML = html;
		$("#badge-desk").innerHTML = html;
	}

	function renderSaveAll() { if (S.view === "guardar") renderSave(); renderBadges(); }

	function renderAll() {
		renderList();
		renderEditor();
		renderSim();
		renderBadges();
		if (S.view === "guardar") renderSave();
	}

	document.querySelectorAll("nav button").forEach((b) => (b.onclick = () => setView(b.dataset.v)));
	$("#btn-settings").onclick = settingsSheet;
	$("#btn-save-desk").onclick = () => {
		openSheet('<div id="save-sheet"></div><div class="row" style="margin-top:10px"><button class="btn ghost" id="ss-close">Cerrar</button></div>');
		renderSave($("#save-sheet"));
		$("#ss-close").onclick = closeSheet;
	};
	window.addEventListener("beforeunload", (e) => { if (changedFiles().length) { e.preventDefault(); e.returnValue = ""; } });

	async function start() {
		try {
			await loadFromGitHub();
		} catch (e) {
			setLoading(null);
			S.files = [];
			renderAll();
			openSheet(`<h3>No se pudo leer GitHub</h3><p class="err">${esc(e.message)}</p>
				<p class="muted small">Revisa la conexión, el repositorio y el token en Ajustes, o abre los archivos .dialogue a mano.</p>
				<div class="row"><button class="btn lime" id="r-retry">Reintentar</button><button class="btn" id="r-set">Ajustes</button></div>`);
			$("#r-retry").onclick = () => { closeSheet(); start(); };
			$("#r-set").onclick = settingsSheet;
		}
	}

	// Para pruebas automáticas.
	window.__editor = { S, M, start, selectCue, setView, renderAll, loadLocal, changedFiles, validateCue };

	if (!window.__EDITOR_NO_AUTOSTART) start();
})();
