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
		bodyMode: "flujo",
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
		// Por persona
		for (const m of cue.body.matchAll(/^\s*- (.*)$/gm)) {
			const o = F.parseOption("- " + m[1]);
			const per = F.tagList(o.tags).includes(PERSON);
			if (per && !o.body.includes(PERSON_PH)) out.push(["warn", "Opción por persona sin {persona}: «" + o.body + "»."]);
			if (!per && o.body.includes(PERSON_PH)) out.push(["info", "«" + o.body + "» usa {persona} sin ser por persona: dirá la última persona elegida."]);
		}
		// Menciones
		for (const m of cue.body.matchAll(/#alude=([^\],\s]+)/g)) for (const w of m[1].split("|")) if (!charInfo(w)) out.push(["warn", "Menciona a «" + w + "», que no es un personaje."]);
		for (const m of cue.body.matchAll(/Story\.present\("([^"]+)"\)/g)) if (!charInfo(m[1])) out.push(["warn", "Story.present(\"" + m[1] + "\"): no es un personaje."]);
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
			<div class="row" style="margin-bottom:8px"><div class="seg"><button data-m="flujo" class="${S.bodyMode === "flujo" ? "on" : ""}">Conversación</button><button data-m="texto" class="${S.bodyMode === "texto" ? "on" : ""}">Texto</button></div>
				<span class="muted small">${S.bodyMode === "flujo" ? "Toca una línea para editarla; elige opción para ver su rama." : ""}</span></div>
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
		if (S.bodyMode === "flujo") { box.innerHTML = flowHTML(c); bindFlow(box, c, renderEditor); return; }
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


	// --- Flujo de la conversación (diagrama editable) -------------------------------------------

	const F = window.Flujo;
	const MENTION = "alude";   // [#alude=rika|kenji]: Ren menciona a alguien (Social.MENTION_TAG)

	/** Etiquetas de una opción separadas en {tags: [...], mentions: [...]}. */
	function splitMentions(list) {
		const tags = [], mentions = [];
		for (const t of list) {
			if (t.startsWith(MENTION + "=")) for (const w of t.slice(MENTION.length + 1).split("|")) { if (w && !mentions.includes(w)) mentions.push(w); }
			else tags.push(t);
		}
		return { tags, mentions };
	}
	const people = () => S.cfg.characters.filter((c) => !c.enemy && c.id !== S.cfg.protagonist);

	// Opciones «por persona» ([#persona] + filtros): réplica de Social.person_candidates.
	const PERSON = "persona", PERSON_PH = "{persona}";
	const PERSON_WORDS = ["joven", "adulto", "presente", "ausente"], PERSON_KEYS = ["genero", "entre", "tramo"];
	function isPersonFilter(t) {
		if (PERSON_WORDS.includes(t)) return true;
		for (const op of M.OPS) { const i = t.indexOf(op); if (i > 0) { const k = t.slice(0, i); return PERSON_KEYS.includes(k) || Object.prototype.hasOwnProperty.call(S.cfg.dims, k); } }
		return false;
	}
	/** Etiquetas de una opción → {per, filters, rest}. */
	function splitPerson(list) {
		const per = list.includes(PERSON);
		const filters = [], rest = [];
		for (const t of list) { if (t === PERSON) continue; (per && isPersonFilter(t) ? filters : rest).push(t); }
		return { per, filters, rest };
	}
	/** Lo que `id` siente por Ren: simulador, partida cargada o ficha. */
	function dimsOf(id, sim) {
		if (sim && id === sim.who) return sim.dims;
		const rel = S.save && (((S.save.relations || {})[id] || {})[S.cfg.protagonist]);
		if (rel) { const d = {}; for (const k in S.cfg.dims) d[k] = rel[k] !== undefined ? rel[k] : 0; return d; }
		return initialFor(id).dims;
	}
	function personCandidates(filters, exclude, sim) {
		const cmp = (a, op, b) => ({ ">=": a >= b, "<=": a <= b, ">": a > b, "<": a < b, "!=": a !== b }[op] ?? a === b);
		const out = [];
		for (const id of Object.keys(S.profiles)) {
			if (id === S.cfg.protagonist || exclude.includes(id) || !charInfo(id)) continue;
			const idt = S.profiles[id].identity || {}, d = dimsOf(id, sim);
			const present = sim ? id === sim.who || sim.present.includes(id) : true;
			const ok = filters.every((f) => {
				if (f === "joven" || f === "adulto") return idt.generation === f;
				if (f === "presente") return present;
				if (f === "ausente") return !present;
				for (const op of M.OPS) {
					const i = f.indexOf(op);
					if (i <= 0) continue;
					const k = f.slice(0, i), arg = f.slice(i + op.length);
					if (k === "genero") return arg.split("|").includes(idt.gender || "") !== (op === "!=");
					if (k === "entre") return arg.split("|").includes(id) !== (op === "!=");
					if (k === "tramo") return cmp(S.cfg.tiers.indexOf(M.tierFromDims(d)), op, S.cfg.tiers.indexOf(arg));
					return cmp(d[k] || 0, op, parseFloat(arg) || 0);
				}
				return true;
			});
			if (ok) out.push(id);
		}
		return out.sort((a, b) => (dimsOf(b, sim).afecto || 0) - (dimsOf(a, sim).afecto || 0));
	}
	function filterText(f) {
		const m = f.match(/^(genero|entre)(!?=)(.*)$/);
		if (m) return (m[1] === "genero" ? "" : "solo ") + (m[2] === "!=" ? "no " : "") + m[3].split("|").map((x) => m[1] === "entre" ? charName(x) : x).join(" o ");
		return f.replace(">=", " ≥ ").replace("<=", " ≤ ").replace("!=", " ≠ ");
	}
	/** Personajes cuyo nombre aparece en un texto. */
	function namesIn(text) {
		const t = (text || "").toLowerCase();
		return people().filter((c) => new RegExp("(^|[^\\p{L}])" + c.name.toLowerCase().replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "($|[^\\p{L}])", "u").test(t)).map((c) => c.id);
	}

	/**
	 * Evalúa una condición de un bloque «if» con la situación del simulador.
	 * Entiende Story.present/flag/knows/seen/phase y Story.mood/tier == del
	 * personaje simulado, con and/or/not. Devuelve null si no puede saberlo.
	 */
	function evalCond(text, sim) {
		if (!sim) return null;
		if (/^else\b/.test(text)) return true;
		const st = M.simState(sim, S.cfg);
		const pres = (id) => id === sim.who || st.present(id);
		const who = (w, f) => (w === sim.who ? String(f()) : "?");
		let e = text.replace(/^(if|elif)\s+/, "")
			.replace(/Story\.persona\s*(==|!=)\s*"([^"]+)"/g, (a, op, id) => (sim.persona === undefined ? "?" : String((sim.persona === id) === (op === "=="))))
			.replace(/Story\.present\("([^"]+)"\)/g, (a, id) => String(pres(id)))
			.replace(/Story\.flag\("([^"]+)"\)/g, (a, f) => String(st.flag(f)))
			.replace(/Story\.seen\("([^"]+)"\)/g, (a, c) => String(st.seen(c)))
			.replace(/Story\.phase\("([^"]+)"\)/g, (a, p) => String(st.phaseIndex() >= S.cfg.phases.indexOf(p)))
			.replace(/Story\.knows\("([^"]+)",\s*"([^"]+)"\)/g, (a, w, ev) => who(w, () => st.knows(w, ev)))
			.replace(/Story\.mood\("([^"]+)"\)\s*(==|!=)\s*"([^"]+)"/g, (a, w, op, m) => who(w, () => (sim.mood === m) === (op === "==")))
			.replace(/Story\.tier\("([^"]+)"\)\s*(==|!=)\s*"([^"]+)"/g, (a, w, op, t) => who(w, () => (M.tierFromDims(sim.dims) === t) === (op === "==")));
		if (!/^(true|false|and|or|not|\(|\)|\s)+$/.test(e)) return null;
		e = e.replace(/\band\b/g, "&&").replace(/\bor\b/g, "||").replace(/\bnot\b/g, "!");
		try { return !!Function('"use strict"; return (' + e + ");")(); } catch (err) { return null; }
	}
	S.flow = {};   // "archivo/cue" -> {choices: {ruta: índice}, edit: ruta|null, confirm: ruta|null}

	function flowState(cue) {
		const k = cue.file + "/" + cue.name;
		return S.flow[k] || (S.flow[k] = { choices: {}, edit: null, confirm: null });
	}

	const pkey = (path) => path.join(".");
	const speakerNames = () => [...new Set(S.cfg.characters.map((c) => c.name).concat(["{{Story.speaker}}"]))];
	function colorOfName(name) {
		const c = S.cfg.characters.find((x) => x.name === name);
		return c ? c.color : (name.includes("speaker") ? "#c6f432" : "#f2f2f4");
	}
	const renName = () => charName(S.cfg.protagonist);
	function npcName(cue) { return charInfo(cue.file) ? charName(cue.file) : "{{Story.speaker}}"; }

	/** Etiquetas de estilo usadas en las opciones de todos los diálogos (las más frecuentes primero). */
	function styleTags() {
		const count = {};
		for (const c of allCues()) for (const m of c.body.matchAll(/^\s*- .*?(\[#[^\]]*\])/gm)) for (const t of F.tagList(m[1])) count[t] = (count[t] || 0) + 1;
		return Object.keys(count).filter((t) => !t.startsWith(MENTION + "=") && t !== PERSON && !isPersonFilter(t)).sort((a, b) => (a.includes("=") - b.includes("=")) || count[b] - count[a]);
	}

	function humanMutation(t) {
		const s = t.replace(/^\$>\s*/, "");
		let m;
		if ((m = s.match(/Story\.change\("([^"]+)",\s*"([^"]+)",\s*(-?[\d.]+)\)/))) return charName(m[1]) + " · " + m[2] + " " + (+m[3] > 0 ? "+" : "") + m[3];
		if ((m = s.match(/Story\.set_mood\("([^"]+)",\s*"([^"]+)"/))) return charName(m[1]) + " · ánimo: " + m[2];
		if ((m = s.match(/Story\.set_flag\("([^"]+)"/))) return "Indicador «" + m[1] + "»";
		if ((m = s.match(/Story\.tell\("([^"]+)",\s*"([^"]+)"/))) return charName(m[1]) + " se entera de «" + m[2] + "»";
		if ((m = s.match(/Story\.text\("([^"]+)"/))) return "Mensaje de " + charName(m[1]) + " al móvil";
		return s;
	}

	function humanCond(t) {
		if (t.startsWith("else")) return "Si no";
		return t.replace(/^(if|elif)\s+/, "Si ")
			.replace(/not\s+Story\.present\("([^"]+)"\)/g, (a, w) => charName(w) + " no está")
			.replace(/Story\.present\("([^"]+)"\)/g, (a, w) => charName(w) + " está presente")
			.replace(/Story\.persona\s*==\s*"([^"]+)"/g, (a, w) => "eligió a " + charName(w))
			.replace(/Story\.persona\s*!=\s*"([^"]+)"/g, (a, w) => "no eligió a " + charName(w))
			.replace(/\band\b/g, "y").replace(/\bor\b/g, "o").replace(/Story\.mood\("([^"]+)"\)\s*==\s*"([^"]+)"/g, (a, w, m) => "ánimo de " + charName(w) + " = " + m)
			.replace(/Story\.tier\("([^"]+)"\)\s*==\s*"([^"]+)"/g, (a, w, m) => "relación de " + charName(w) + " = " + m)
			.replace(/Story\.knows\("([^"]+)",\s*"([^"]+)"\)/g, (a, w, e) => charName(w) + " sabe «" + e + "»")
			.replace(/Story\.flag\("([^"]+)"\)/g, (a, f) => "indicador «" + f + "»");
	}

	/** HTML del diagrama de un cue. */
	function flowHTML(cue, sim) {
		const st = flowState(cue);
		const tree = F.parse(cue.body);
		const ctx = { st, cue, step: 0, sim: sim || null, persona: null, lastSpeaker: "" };
		const body = seqHTML(tree.children, [], ctx);
		return `<div class="flow">${body || '<div class="empty">Este diálogo está vacío.</div>'}
			<div class="fadd"><button class="btn sm" data-op="add-end">+ Línea al final</button></div></div>`;
	}

	function seqHTML(nodes, path, ctx) {
		let html = "";
		let i = 0;
		while (i < nodes.length) {
			const n = nodes[i];
			const k = F.kind(n.text);
			if (k === "blank") { i++; continue; }
			if (k === "option" || k === "variant" || k === "cond") {
				const grp = [];
				let j = i;
				while (j < nodes.length) {
					const kk = F.kind(nodes[j].text);
					if (kk === "blank" || kk === "comment") { j++; continue; }
					if (kk !== k) break;
					if (k === "cond" && grp.length && (/^if\b/.test(nodes[j].text) || grp[grp.length - 1].n.text.startsWith("else"))) break;
					grp.push({ n: nodes[j], idx: j });
					j++;
				}
				html += groupHTML(k, grp, path, ctx);
				i = j;
				continue;
			}
			html += nodeHTML(n, path.concat(i), k, ctx);
			i++;
		}
		return html;
	}

	function nodeHTML(n, path, k, ctx) {
		const key = pkey(path);
		if (ctx.st.edit === key) return formHTML(n, key, k, ctx) + seqHTML(n.children, path, ctx);
		let html = "";
		switch (k) {
			case "line": html = lineCard(n, key, ctx); break;
			case "mutation": html = `<div class="fmut" data-path="${key}">⚙ ${esc(humanMutation(n.text))}</div>`; break;
			case "comment": html = `<div class="fcmt" data-path="${key}">${esc(n.text)}</div>`; break;
			case "jump": {
				const target = n.text.replace(/^=><?\s*/, "");
				html = /^END/.test(target)
					? `<div class="fend" data-path="${key}">■ Fin de la conversación</div>`
					: `<div class="fend goto" data-path="${key}">→ Sigue en <b>${esc(target)}</b> <button class="btn sm" data-op="goto" data-cue="${esc(target)}">Abrir</button></div>`;
				break;
			}
			default: html = `<div class="fmut" data-path="${key}">${esc(n.text)}</div>`;
		}
		return html + seqHTML(n.children, path, ctx);
	}

	const withPersona = (t, ctx) => (ctx.persona ? t.split(PERSON_PH).join(charName(ctx.persona)) : t);

	function lineCard(n, key, ctx, asVariant) {
		const p = F.parseLine(n.text);
		ctx.step++;
		if (p.speaker) ctx.lastSpeaker = p.speaker;
		const cls = !p.speaker ? "narr" : p.speaker === renName() ? "ren" : "npc";
		const tags = F.tagList(p.tags).map((t) => `<span class="ftag">${esc(t)}</span>`).join("");
		return `<div class="fcard ${cls}" data-path="${key}" style="--c:${colorOfName(p.speaker)}">
			<div class="fhead"><span class="fstep">${ctx.step}</span><span class="fname">${esc(p.speaker || "Narración")}</span>${tags}</div>
			<div class="ftext">${esc(withPersona(F.unescape(p.body), ctx))}</div></div>`;
	}

	function groupHTML(k, grp, path, ctx) {
		const savedPersona = ctx.persona;
		const key = pkey(path.concat(grp[0].idx));
		let sel = ctx.st.choices[key] || 0;
		if (k !== "option" && sel >= grp.length) sel = 0;   // las opciones se ajustan tras desplegar «por persona»
		// En el simulador, las condiciones que se pueden evaluar eligen su rama solas.
		let auto = false;
		if (k === "cond" && ctx.sim) {
			const simP = Object.assign({}, ctx.sim, { persona: ctx.persona || "" });
			const vals = grp.map((g) => evalCond(g.n.text, simP));
			const hit = vals.findIndex((v) => v === true);
			if (vals.every((v) => v !== null) || hit >= 0 && vals.slice(0, hit).every((v) => v === false)) { auto = true; sel = hit; }
		}
		const labels = { option: renName() + " responde · elige una opción", variant: "Al azar · sale una de estas",
			cond: auto ? "Según la situación · la de la simulación" : "Según la situación" };
		// Las opciones «por persona» se despliegan: una pestaña por persona que cumple.
		if (k === "option") {
			const speakerId = (S.cfg.characters.find((c) => c.name === ctx.lastSpeaker) || {}).id;
			const exclude = [speakerId, charInfo(ctx.cue.file) ? ctx.cue.file : null, ctx.sim ? ctx.sim.who : null].filter(Boolean);
			const items = [];
			for (const g of grp) {
				const sp = splitPerson(F.tagList(F.parseOption(g.n.text).tags));
				if (!sp.per) { items.push({ n: g.n, idx: g.idx }); continue; }
				const cands = personCandidates(sp.filters, exclude, ctx.sim);
				if (!cands.length) items.push({ n: g.n, idx: g.idx, persona: "", filters: sp.filters });
				for (const c of cands) items.push({ n: g.n, idx: g.idx, persona: c, filters: sp.filters });
			}
			grp = items;
			if (sel >= grp.length) sel = 0;
		}
		const tabLabel = (g, i) => {
			if (k !== "option") return k === "variant" ? "Variante " + (i + 1) : humanCond(g.n.text);
			const body = F.parseOption(g.n.text).body;
			if (g.persona === undefined) return withPersona(body, ctx);
			return g.persona ? "👤 " + body.split(PERSON_PH).join(charName(g.persona)) : "👤 nadie cumple los filtros";
		};
		const tabs = grp.map((g, i) => `<button class="ftab ${i === sel ? "on" : ""} ${g.persona === "" ? "add" : ""}" data-op="choose" data-key="${key}" data-i="${i}" ${auto ? 'data-auto="1"' : ""}>${esc(tabLabel(g, i))}</button>`).join("");
		if (auto && sel < 0) {
			return `<div class="fgroup cond"><div class="fglabel">${esc(labels.cond)}</div><div class="ftabs">${tabs}</div>
				<div class="fbranch"><div class="fmut cond">Con esta situación no se cumple ninguna: no se dice nada aquí.</div></div></div>`;
		}
		const add = k === "option" ? `<button class="ftab add" data-op="add-option" data-path="${pkey(path.concat(grp[grp.length - 1].idx))}">+ Opción</button>`
			: k === "variant" ? `<button class="ftab add" data-op="add-variant" data-path="${pkey(path.concat(grp[grp.length - 1].idx))}">+ Variante</button>` : "";
		const chosen = grp[sel];
		const cpath = path.concat(chosen.idx);
		const ckey = pkey(cpath);
		let inner = "";
		if (ctx.st.edit === ckey) {
			inner = formHTML(chosen.n, ckey, k === "variant" && chosen.n.text.replace(/^%\d*\s*/, "") ? "line" : k, ctx);
		} else if (k === "option") {
			const o = F.parseOption(chosen.n.text);
			ctx.step++;
			const sm = splitMentions(F.tagList(o.tags));
			const sp = splitPerson(sm.tags);
			if (chosen.persona !== undefined) ctx.persona = chosen.persona || null;
			const ment = sm.mentions.concat(chosen.persona && !sm.mentions.includes(chosen.persona) ? [chosen.persona] : []);
			const tags = sp.rest.map((t) => `<span class="ftag">${esc(t)}</span>`).join("") +
				ment.map((w) => `<span class="ftag mention" style="--c:${charColor(w)}">@${esc(charName(w))}</span>`).join("") +
				(sp.per ? `<span class="ftag mention" style="--c:var(--lime)">👤 por persona: ${esc(sp.filters.map(filterText).join(" · ") || "cualquiera")}</span>` : "");
			inner = `<div class="fcard ren opt" data-path="${ckey}"><div class="fhead">${tags}<span class="fname">${esc(renName())}</span><span class="fstep">${ctx.step}</span></div>
				<div class="ftext">${esc(withPersona(o.body, ctx))}</div></div>` + (o.jump ? `<div class="fend goto">→ Sigue en <b>${esc(o.jump)}</b></div>` : "");
		} else if (k === "variant") {
			inner = chosen.n.text.replace(/^%\d*\s*/, "") ? lineCard(chosen.n, ckey, ctx) : `<div class="fmut" data-path="${ckey}">% ${esc(chosen.n.text.slice(1).trim() || "bloque al azar")}</div>`;
		} else {
			inner = `<div class="fmut cond" data-path="${ckey}">❓ ${esc(humanCond(chosen.n.text))}</div>`;
		}
		inner += seqHTML(chosen.n.children, cpath, ctx);
		ctx.persona = savedPersona;
		return `<div class="fgroup ${k}"><div class="fglabel">${esc(labels[k])}</div><div class="ftabs">${tabs}${add}</div><div class="fbranch">${inner}</div></div>`;
	}

	function formHTML(n, key, k, ctx) {
		const cue = ctx.cue;
		const confirm = ctx.st.confirm === key;
		const hasKids = n.children.some((c) => c.text !== "");
		const buttons = (extra) => `<div class="row">
			<button class="btn lime sm" data-op="apply">Aplicar</button>
			<button class="btn sm ghost" data-op="cancel">Cancelar</button>
			<button class="btn sm" data-op="up" title="Subir">↑</button><button class="btn sm" data-op="down" title="Bajar">↓</button>
			<button class="btn sm danger" data-op="del">${confirm ? "¿Seguro?" + (hasKids ? " Se borra su rama" : "") : "Borrar"}</button></div>
			<div class="row">${extra}</div>`;
		let fields = "";
		if (k === "line") {
			const p = F.parseLine(n.text);
			const names = speakerNames();
			if (p.speaker && !names.includes(p.speaker)) names.push(p.speaker);
			fields = `<select class="input" name="speaker"><option value="">Narración</option>${names.map((nm) => `<option ${nm === p.speaker ? "selected" : ""}>${esc(nm)}</option>`).join("")}</select>
				<textarea class="input" name="body" placeholder="Lo que se dice…">${esc(F.unescape(p.body))}</textarea>
				<input class="input" name="tags" value="${esc(p.tags)}" placeholder="Etiquetas (opcional) [#…]">`;
			return `<div class="fform" data-path="${key}" data-kind="line">${fields}${reactHTML(p.body, false)}${buttons(
				`<button class="btn sm" data-op="add-after">+ Línea debajo</button><button class="btn sm" data-op="add-options">+ Respuestas de ${esc(renName())}</button>`)}</div>`;
		}
		if (k === "option") {
			const o = F.parseOption(n.text);
			const sm = splitMentions(F.tagList(o.tags));
			const sp = splitPerson(sm.tags);
			const on = sp.rest;
			const chips = styleTags().slice(0, 24).map((t) => `<span class="chip small ${on.includes(t) ? "on" : ""}" data-op="tag" data-v="${esc(t)}">${esc(t)}</span>`).join("");
			const found = namesIn(o.body);
			const ppl = people().slice().sort((a, b) => found.includes(b.id) - found.includes(a.id));
			const mentionChips = ppl.map((c) => `<span class="chip small ${sm.mentions.includes(c.id) ? "on" : ""}" data-op="mention" data-v="${c.id}" style="${sm.mentions.includes(c.id) ? "" : "border-color:" + c.color}">${found.includes(c.id) ? "• " : ""}${esc(c.name)}</span>`).join("");
			fields = `<div class="small muted">Lo que responde ${esc(renName())}</div>
				<textarea class="input" name="body">${esc(o.body)}</textarea>
				<div class="small muted">Estilo y postura (los personajes reaccionan según esto)</div>
				<div class="chips">${chips}</div>
				<input class="input" name="tags" value="${esc(on.join(", "))}" placeholder="franco, criaturas=acoger…">
				${personFormHTML(sp)}
				<div class="small muted">Menciona a… (si está presente, se da por aludido: reacciona como si le hablaras a él o ella). «•» = sale su nombre en el texto.</div>
				<div class="chips">${mentionChips}</div>
				<input type="hidden" name="mentions" value="${esc(sm.mentions.join("|"))}">
				<div class="small muted">Al elegirla, ¿salta a otro diálogo?</div>
				<select class="input" name="jump"><option value="">No, sigue aquí</option>${["END"].concat(allCues().map((c) => c.name)).map((c) => `<option ${c === o.jump ? "selected" : ""}>${esc(c)}</option>`).join("")}</select>`;
			return `<div class="fform" data-path="${key}" data-kind="option">${fields}${reactHTML(o.body, true)}${buttons(
				`<button class="btn sm" data-op="add-option">+ Otra opción</button><button class="btn sm" data-op="add-child">+ Línea en esta rama</button>`)}</div>`;
		}
		const help = { mutation: "Efecto (código, p. ej. $> Story.change(\"kenji\", \"afecto\", 2))", jump: "Salto: => END o => nombre_de_cue", cond: "Condición (if …, elif …, else)", variant: "Variante al azar (% …)", comment: "Comentario (# …)" }[k] || "Línea";
		return `<div class="fform" data-path="${key}" data-kind="raw"><div class="small muted">${esc(help)}</div>
			<input class="input" name="raw" value="${esc(n.text)}" spellcheck="false" autocapitalize="off">${buttons(
			k === "cond" || k === "variant" ? '<button class="btn sm" data-op="add-child">+ Línea dentro</button>' : '<button class="btn sm" data-op="add-after">+ Línea debajo</button>')}</div>`;
	}

	/** Bloque del formulario para opciones «por persona». */
	function personFormHTML(sp) {
		const get = (key) => { const f = sp.filters.find((x) => x.startsWith(key + "=") || x.startsWith(key + "!=")); return f ? f.split(/!?=/)[1].split("|") : []; };
		const dimF = sp.filters.find((f) => { const k = f.split(/[<>=!]/)[0]; return Object.prototype.hasOwnProperty.call(S.cfg.dims, k); }) || "afecto>=15";
		const dm = dimF.match(/^([a-z_]+)(>=|<=|!=|=|>|<)(.*)$/) || ["", "afecto", ">=", "15"];
		const tramo = (sp.filters.find((f) => f.startsWith("tramo")) || "").match(/^tramo(>=|<=|!=|=|>|<)(.*)$/);
		const chip = (grp, v, label, on) => `<span class="chip small ${on ? "on" : ""}" data-op="pf" data-g="${grp}" data-v="${esc(v)}">${esc(label)}</span>`;
		const gen = get("genero"), entre = get("entre");
		const age = sp.filters.find((f) => f === "joven" || f === "adulto") || "";
		const pres = sp.filters.find((f) => f === "presente" || f === "ausente") || "";
		return `<label class="row small" style="gap:8px;cursor:pointer"><input type="checkbox" name="per" ${sp.per ? "checked" : ""}> <b>Una opción por cada persona</b> que cumpla esto (pon <b>{persona}</b> donde va el nombre)</label>
			<div class="pbox" style="${sp.per ? "" : "display:none"};border:1px dashed var(--line2);border-radius:10px;padding:8px;display:${sp.per ? "flex" : "none"};flex-direction:column;gap:6px">
				<div class="row"><button class="btn sm" data-op="ph">Insertar {persona}</button><span class="small muted">Nunca sale quien pregunta ni el interlocutor.</span></div>
				<div class="small muted">Lo que siente por ${esc(renName())}</div>
				<div class="row"><select class="input" name="pdim" style="flex:1">${Object.keys(S.cfg.dims).map((d) => `<option ${d === dm[1] ? "selected" : ""}>${d}</option>`).join("")}<option value="" ${sp.per && !sp.filters.some((f) => /^[a-z_]+(>=|<=|!=|=|>|<)/.test(f) && Object.prototype.hasOwnProperty.call(S.cfg.dims, f.split(/[<>=!]/)[0])) ? "selected" : ""}>(sin filtro)</option></select>
					<select class="input" name="pop" style="width:76px">${M.OPS.map((op) => `<option ${op === dm[2] ? "selected" : ""}>${op}</option>`).join("")}</select>
					<input class="input" name="pval" type="number" inputmode="numeric" value="${esc(dm[3])}" style="width:84px"></div>
				<div class="row"><span class="small muted">Relación</span><select class="input" name="ptier" style="flex:1"><option value="">(cualquiera)</option>${S.cfg.tiers.map((t) => `<option ${tramo && tramo[2] === t ? "selected" : ""}>${t}</option>`).join("")}</select>
					<select class="input" name="ptierop" style="width:76px">${M.OPS.map((op) => `<option ${tramo ? (op === tramo[1] ? "selected" : "") : (op === ">=" ? "selected" : "")}>${op}</option>`).join("")}</select></div>
				<div class="chips"><span class="small muted">Género</span>${chip("genero", "mujer", "mujer", gen.includes("mujer"))}${chip("genero", "hombre", "hombre", gen.includes("hombre"))}
					<span class="small muted" style="margin-left:8px">Edad</span>${chip("edad", "joven", "joven", age === "joven")}${chip("edad", "adulto", "adulto", age === "adulto")}
					<span class="small muted" style="margin-left:8px">Ahora</span>${chip("pres", "presente", "presente", pres === "presente")}${chip("pres", "ausente", "ausente", pres === "ausente")}</div>
				<div class="chips"><span class="small muted">Solo entre</span>${people().filter((c) => S.profiles[c.id]).map((c) => chip("entre", c.id, c.name, entre.includes(c.id))).join("")}</div>
			</div>`;
	}

	/** Botones «si está presente, contesta»: añaden un bloque if Story.present(...). */
	function reactHTML(text, inBranch) {
		const found = namesIn(text);
		const ppl = people().slice().sort((a, b) => found.includes(b.id) - found.includes(a.id));
		return `<div class="small muted">${inBranch ? "Tras esta respuesta" : "Tras esta línea"}, si está presente, contesta… ${found.length ? "(«•» = sale en el texto)" : ""}</div>
			<div class="chips">${ppl.map((c) => `<span class="chip small" data-op="react" data-v="${c.id}" style="border-color:${c.color}">${found.includes(c.id) ? "• " : ""}+ ${esc(c.name)}</span>`).join("")}</div>`;
	}

	/** Conecta los clics de un diagrama. `rerender` vuelve a dibujar la vista que lo contiene. */
	function bindFlow(container, cue, rerender) {
		const st = flowState(cue);
		container.onchange = (e) => {
			if (e.target.name === "per") { const box = e.target.closest(".fform").querySelector(".pbox"); box.style.display = e.target.checked ? "flex" : "none"; }
		};
		container.onclick = (e) => {
			const op = e.target.closest("[data-op]");
			if (op && container.contains(op)) { flowOp(op, cue, st, rerender, container); return; }
			if (e.target.closest(".fform")) return;
			const card = e.target.closest("[data-path]");
			if (card) { st.edit = card.dataset.path; st.confirm = null; rerender(); }
		};
	}

	function flowOp(el, cue, st, rerender, container) {
		const op = el.dataset.op;
		if (op === "choose") {
			if (el.dataset.auto) { toast("En el simulador esta rama sale de la situación: cambia los presentes, el ánimo… más abajo"); return; }
			st.choices[el.dataset.key] = +el.dataset.i; st.edit = null; rerender(); return;
		}
		if (op === "pf") {
			const single = el.dataset.g === "edad" || el.dataset.g === "pres";
			if (single && !el.classList.contains("on")) el.parentElement.querySelectorAll(`[data-g="${el.dataset.g}"]`).forEach((x) => x.classList.remove("on"));
			el.classList.toggle("on");
			return;
		}
		if (op === "ph") {
			const ta = el.closest(".fform").querySelector('[name="body"]');
			const s0 = ta.selectionStart ?? ta.value.length;
			ta.value = ta.value.slice(0, s0) + PERSON_PH + ta.value.slice(ta.selectionEnd ?? s0);
			ta.focus();
			return;
		}
		if (op === "mention") {
			const form = el.closest(".fform");
			const input = form.querySelector('[name="mentions"]');
			const list = input.value.split("|").filter(Boolean);
			const i = list.indexOf(el.dataset.v);
			i >= 0 ? list.splice(i, 1) : list.push(el.dataset.v);
			input.value = list.join("|");
			el.classList.toggle("on");
			el.style.borderColor = el.classList.contains("on") ? "" : charColor(el.dataset.v);
			return;
		}
		if (op === "goto") { const c = allCues().find((x) => x.name === el.dataset.cue); if (c) selectCue(c.name, c.file, true); else toast("No existe ese diálogo", true); return; }
		if (op === "tag") {
			const form = el.closest(".fform");
			el.classList.toggle("on");
			const input = form.querySelector('[name="tags"]');
			const list = input.value.split(",").map((t) => t.trim()).filter(Boolean);
			const i = list.indexOf(el.dataset.v);
			i >= 0 ? list.splice(i, 1) : list.push(el.dataset.v);
			input.value = list.join(", ");
			return;
		}
		if (op === "cancel") { st.edit = null; st.confirm = null; rerender(); return; }

		const tree = F.parse(cue.body);
		const path = (el.dataset.path || (el.closest(".fform") || {}).dataset?.path || "").split(".").filter((x) => x !== "").map(Number);
		const node = path.length ? F.nodeAt(tree, path) : tree;
		const parent = path.length ? F.nodeAt(tree, path.slice(0, -1)) : null;
		const idx = path[path.length - 1];
		const mk = (text, indent, children) => ({ text, indent, dirty: true, children: children || [] });
		const npcLine = (indent) => mk(npcName(cue) + ": …", indent);
		let focus = null;

		// Pasa lo escrito en el formulario al nodo (para «Aplicar» y antes de añadir reacciones).
		const applyForm = () => {
			const form = el.closest(".fform");
			if (!form) return true;
			const val = (n) => { const f = form.querySelector(`[name="${n}"]`); return f ? f.value.replace(/\s*\n\s*/g, " ").trim() : ""; };
			let text;
			if (form.dataset.kind === "line") {
				const prev = F.parseLine(node.text);
				text = F.buildLine({ prefix: prev.prefix, speaker: val("speaker"), body: val("body") || "…", tags: val("tags") });
			} else if (form.dataset.kind === "option") {
				const tags = val("tags").split(",").map((t) => t.trim()).filter(Boolean);
				const per = form.querySelector('[name="per"]');
				if (per && per.checked) {
					const pf = [PERSON];
					if (val("pdim") && val("pval") !== "") pf.push(val("pdim") + val("pop") + val("pval"));
					if (val("ptier")) pf.push("tramo" + val("ptierop") + val("ptier"));
					const on = (g) => [...form.querySelectorAll(`[data-op="pf"][data-g="${g}"].on`)].map((x) => x.dataset.v);
					if (on("genero").length) pf.push("genero=" + on("genero").join("|"));
					pf.push(...on("edad"), ...on("pres"));
					if (on("entre").length) pf.push("entre=" + on("entre").join("|"));
					tags.unshift(...pf);
					if (!val("body").includes(PERSON_PH)) toast("Ojo: el texto no lleva {persona}; todas las copias dirán lo mismo");
				}
				const mentions = val("mentions").split("|").filter(Boolean);
				if (mentions.length) tags.push(MENTION + "=" + mentions.join("|"));
				text = F.buildOption({ body: val("body") || "…", tags: F.tagsFromList(tags), jump: val("jump") });
			} else {
				text = val("raw");
			}
			if (!text) { toast("La línea no puede quedar vacía", true); return false; }
			if (text !== node.text) { node.text = text; node.dirty = true; }
			return true;
		};

		switch (op) {
			case "apply": {
				if (!applyForm()) return;
				st.edit = null;
				break;
			}
			case "react": {
				if (!applyForm()) return;
				const who = el.dataset.v;
				const isOption = F.kind(node.text) === "option";
				const base = isOption ? node.indent + 1 : node.indent;
				const block = mk(`if Story.present("${who}")`, base, [mk(charName(who) + ": …", base + 1)]);
				if (isOption) {
					node.children.unshift(block);
					focus = path.concat(0, 0);
				} else {
					parent.children.splice(idx + 1, 0, block);
					focus = path.slice(0, -1).concat(idx + 1, 0);
				}
				toast(charName(who) + " contestará solo si está presente");
				break;
			}
			case "del": {
				if (st.confirm !== pkey(path)) { st.confirm = pkey(path); rerender(); return; }
				parent.children.splice(idx, 1);
				st.edit = null; st.confirm = null;
				break;
			}
			case "up": case "down": {
				const sib = parent.children;
				let j = idx;
				do { j += op === "up" ? -1 : 1; } while (j >= 0 && j < sib.length && sib[j].text === "");
				if (j < 0 || j >= sib.length) { toast("No se puede mover más"); return; }
				[sib[idx], sib[j]] = [sib[j], sib[idx]];
				sib[idx].dirty = sib[j].dirty = true;
				focus = path.slice(0, -1).concat(j);
				break;
			}
			case "add-after":
				parent.children.splice(idx + 1, 0, npcLine(node.indent));
				focus = path.slice(0, -1).concat(idx + 1);
				break;
			case "add-options":
				parent.children.splice(idx + 1, 0,
					mk("- Respuesta 1", node.indent, [npcLine(node.indent + 1)]),
					mk("- Respuesta 2", node.indent, [npcLine(node.indent + 1)]));
				focus = path.slice(0, -1).concat(idx + 1);
				break;
			case "add-option":
				parent.children.splice(idx + 1, 0, mk("- Nueva respuesta", node.indent, [npcLine(node.indent + 1)]));
				focus = path.slice(0, -1).concat(idx + 1);
				st.choices[groupKeyFor(parent, path, idx)] = countGroupIndex(parent, idx + 1);
				break;
			case "add-variant":
				parent.children.splice(idx + 1, 0, mk("% " + npcName(cue) + ": …", node.indent));
				focus = path.slice(0, -1).concat(idx + 1);
				st.choices[groupKeyFor(parent, path, idx)] = countGroupIndex(parent, idx + 1);
				break;
			case "add-child":
				node.children.push(npcLine(node.indent + 1));
				focus = path.concat(node.children.length - 1);
				break;
			case "add-end": {
				const kids = tree.children;
				let at = kids.length;
				while (at > 0 && kids[at - 1].text === "") at--;
				if (at > 0 && F.kind(kids[at - 1].text) === "jump") at--;
				kids.splice(at, 0, npcLine(0));
				focus = [at];
				break;
			}
			default: return;
		}
		if (focus) { st.edit = pkey(focus); st.confirm = null; }
		cue.body = F.serialize(tree);
		cue.dirty = true;
		rebuildRules();
		renderBadges();
		renderList();
		rerender();
		const f = container.querySelector(".fform");
		if (f) f.scrollIntoView({ block: "center", behavior: "smooth" });
	}

	// Clave del grupo (ruta del primer elemento del grupo) que contiene la posición idx.
	function groupKeyFor(parent, path, idx) {
		const k = F.kind(parent.children[idx].text);
		let first = idx;
		for (let j = idx - 1; j >= 0; j--) {
			const kk = F.kind(parent.children[j].text);
			if (kk === "blank" || kk === "comment") continue;
			if (kk !== k) break;
			first = j;
		}
		return pkey(path.slice(0, -1).concat(first));
	}

	function countGroupIndex(parent, idx) {
		const k = F.kind(parent.children[idx].text);
		let n = 0;
		for (let j = idx - 1; j >= 0; j--) {
			const kk = F.kind(parent.children[j].text);
			if (kk === "blank" || kk === "comment") continue;
			if (kk !== k) break;
			n++;
		}
		return n;
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
			<div id="s-flow-wrap">${simFlowHTML(winners)}</div>
			<h2>Todas las reglas de este momento</h2>
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
		bindSimFlow(winners);
	}

	function simFlowHTML(winners) {
		if (!winners.length) return "";
		const pick = Math.min(S.simPick || 0, winners.length - 1);
		const cue = winners[pick].rule.cueRef;
		const tabs = winners.length > 1 ? `<div class="ftabs" style="margin-bottom:8px">${winners.map((w, i) => `<button class="ftab ${i === pick ? "on" : ""}" data-pick="${i}">${esc(w.rule.cue)}</button>`).join("")}</div>` : "";
		return `<h2>Conversación · ${esc(cue.name)}</h2>${tabs}<div id="s-flow">${flowHTML(cue, S.sim)}</div>`;
	}

	function bindSimFlow(winners) {
		const wrap = $("#s-flow-wrap");
		if (!wrap || !winners.length) return;
		wrap.querySelectorAll("[data-pick]").forEach((b) => (b.onclick = () => { S.simPick = +b.dataset.pick; renderSim(); }));
		const cue = winners[Math.min(S.simPick || 0, winners.length - 1)].rule.cueRef;
		bindFlow($("#s-flow"), cue, renderSim);
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
		const fw = $("#s-flow-wrap");
		if (fw) { fw.innerHTML = simFlowHTML(winners); bindSimFlow(winners); }
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
				<div class="small muted" style="margin-top:6px">Créalo en <a href="https://github.com/settings/personal-access-tokens/new" target="_blank" rel="noopener">github.com → Fine-grained token</a>: <i>Repository access</i> → <i>Only select repositories</i> → este repositorio. En <i>Permissions</i>, pulsa <b>+</b>, marca <b>Contents</b> y cierra la lista; luego cambia su acceso de <i>Read-only</i> a <b>Read and write</b>. <i>Metadata</i> (solo lectura) se añade sola. No hace falta ningún otro permiso. Se guarda solo en este navegador.</div></div>
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

	// Las hojas también entran en el historial: «atrás» en el móvil las cierra.
	function openSheet(html) {
		$("#sheet").innerHTML = html;
		if (!$("#sheet-bg").classList.contains("open")) history.pushState({ sheet: true }, "", location.hash || "#" + S.view);
		$("#sheet-bg").classList.add("open");
	}
	function closeSheet(fromHistory) {
		if (!$("#sheet-bg").classList.contains("open")) return;
		$("#sheet-bg").classList.remove("open");
		if (fromHistory !== true && history.state && history.state.sheet) history.back();
	}
	$("#sheet-bg").addEventListener("click", (e) => { if (e.target.id === "sheet-bg") closeSheet(); });

	// Cada pantalla es una entrada del historial (#lista, #editar...): el botón
	// «atrás» del móvil vuelve a la anterior en vez de cerrar la app.
	const VIEWS = ["lista", "editar", "simular", "guardar"];
	function setView(name, fromHistory) {
		if (!VIEWS.includes(name)) name = "lista";
		if (name === "editar" && !S.sel && fromHistory) name = "lista";
		if (!fromHistory && name !== S.view) history.pushState({ view: name }, "", "#" + name);
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
	window.addEventListener("popstate", (e) => {
		if ($("#sheet-bg").classList.contains("open")) { closeSheet(true); if (e.state && e.state.sheet) return; }
		setView(location.hash.slice(1) || "lista", true);
	});
	// Título: vuelve a la pantalla principal.
	const brand = $(".brand");
	brand.style.cursor = "pointer";
	brand.setAttribute("role", "button");
	brand.title = "Ir a la lista de diálogos";
	brand.onclick = () => {
		closeSheet();
		S.filter = { file: "", moment: "", q: "" };
		renderList();
		setView("lista");
		$("#v-lista").scrollTop = 0;
	};
	history.replaceState({ view: "lista" }, "", "#lista");
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
