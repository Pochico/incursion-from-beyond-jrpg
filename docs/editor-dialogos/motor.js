/*
 * Motor del editor de diálogos: réplica en JavaScript del selector de
 * conversaciones del juego (src/autoload/story.gd).
 *
 * IMPORTANTE: debe comportarse exactamente igual que Story. Si cambias las
 * reglas en uno, cambia el otro y pasa la prueba de paridad:
 *   tools/editor_dialogos/paridad.sh   (ver CLAUDE.md)
 *
 * Funciona en el navegador (window.Motor) y en Node (module.exports).
 */
(function (root) {
	"use strict";

	// --- Configuración (se extrae del código del juego; esto son valores de respaldo) ---------

	const DEFAULT_CONFIG = {
		phases: ["rutina", "incursion_1"],
		tiers: ["hostil", "fria", "neutral", "cercana", "intima"],
		moods: ["alegre", "tranquilo", "curioso", "irritado", "ansioso", "triste"],
		dims: {
			afecto: [-100, 100], confianza: [-100, 100], respeto: [-100, 100],
			atraccion: [0, 100], miedo: [0, 100], asco: [0, 100], resentimiento: [0, 100],
		},
		weights: { once: 3, mood: 2 },
		actionMoments: { talk: "hablar", flirt: "ligar", fight: "luchar", message: "movil" },
		general: "general",
		protagonist: "ren",
		characters: [],
		// Gestos de los retratos (ConversationView.FACES) y su etiqueta de línea: [#cara=enfado].
		faces: ["enfado", "sorpresa", "incomodo"],
		faceTag: "cara",
		// Lo que los diálogos pueden usar de Story (funciones y variables públicas de story.gd).
		storyApi: ["tier", "mood", "knows", "tell", "phase", "flag", "set_flag", "present", "today", "value",
			"change", "set_mood", "text", "persona_name", "enemy_name", "seen", "speaker", "persona"],
	};

	/** Lee constantes del código fuente del juego (texto de los .gd). */
	function configFromSources(src) {
		const cfg = JSON.parse(JSON.stringify(DEFAULT_CONFIG));
		const strList = (text) => (text.match(/"([^"]*)"/g) || []).map((s) => s.slice(1, -1));
		const block = (text, re) => { const m = text && text.match(re); return m ? m[1] : null; };

		const phases = block(src.gameState, /const PHASES[^=]*=\s*\[([\s\S]*?)\]/);
		if (phases) {
			// Ignora los comentarios ## de cada línea.
			const clean = phases.split("\n").map((l) => l.replace(/##.*$/, "")).join("\n");
			const list = strList(clean);
			if (list.length) cfg.phases = list;
		}
		const moods = block(src.social, /const MOODS[^=]*=\s*\[([^\]]*)\]/);
		if (moods) cfg.moods = strList(moods);
		const dims = block(src.social, /const DIMENSIONS\s*:?=\s*\{([\s\S]*?)\n\}/);
		if (dims) {
			const out = {};
			for (const m of dims.matchAll(/"([a-z_]+)"\s*:\s*Vector2\(\s*(-?\d+)\s*,\s*(-?\d+)\s*\)/g)) out[m[1]] = [+m[2], +m[3]];
			if (Object.keys(out).length) cfg.dims = out;
		}
		const tiers = block(src.story, /const TIERS[^=]*=\s*\[([^\]]*)\]/);
		if (tiers) cfg.tiers = strList(tiers);
		const weights = block(src.story, /const CRITERION_WEIGHTS\s*:?=\s*\{([^}]*)\}/);
		if (weights) {
			const w = {};
			for (const m of weights.matchAll(/"([a-z_]+)"\s*:\s*(\d+)/g)) w[m[1]] = +m[2];
			cfg.weights = w;
		}
		const am = block(src.story, /const ACTION_MOMENTS\s*:?=\s*\{([^}]*)\}/);
		if (am) {
			const o = {};
			for (const m of am.matchAll(/"([a-z_]+)"\s*:\s*"([a-z_]+)"/g)) o[m[1]] = m[2];
			if (Object.keys(o).length) cfg.actionMoments = o;
		}
		if (src.story) {
			const api = [...src.story.matchAll(/^(?:func|var)\s+([a-z][a-z0-9_]*)/gm)].map((m) => m[1]);
			if (api.length) cfg.storyApi = api;
		}
		const general = block(src.story, /const GENERAL\s*:?=\s*"([^"]+)"/);
		if (general) cfg.general = general;
		if (src.characterDb) {
			const prot = block(src.characterDb, /const PROTAGONIST\s*:?=\s*"([^"]+)"/);
			if (prot) cfg.protagonist = prot;
			const chars = [];
			const re = /\n\t"([a-z0-9_]+)"\s*:\s*\{\s*\n?\s*"name"\s*:\s*"([^"]+)"\s*,\s*"color"\s*:\s*Color\("([0-9a-fA-F]+)"\)([^\n]*)/g;
			for (const m of src.characterDb.matchAll(re)) {
				// Bloque del personaje: hasta la siguiente entrada «\t"id": {».
				const rest = src.characterDb.slice(m.index + m[0].length);
				const end = rest.search(/\n\t(?:"[a-z0-9_]+"\s*:\s*\{|\})/);
				const body = m[4] + (end >= 0 ? rest.slice(0, end) : rest);
				const portrait = block(body, /"portrait"\s*:\s*"res:\/\/([^"]+)"/);
				const faces = {};
				const fb = block(body, /"faces"\s*:\s*\{([^}]*)\}/);
				if (fb) for (const f of fb.matchAll(/"([a-z_]+)"\s*:\s*"res:\/\/([^"]+)"/g)) faces[f[1]] = f[2];
				chars.push({ id: m[1], name: m[2], color: "#" + m[3], enemy: /"enemy"\s*:\s*true/.test(body),
					portrait: portrait || "", faces });
			}
			if (chars.length) cfg.characters = chars;
		}
		if (src.conversation) {
			const faces = block(src.conversation, /const FACES[^=]*=\s*\[([^\]]*)\]/);
			if (faces) cfg.faces = strList(faces);
			const tag = block(src.conversation, /const FACE_TAG\s*:?=\s*"([^"]+)"/);
			if (tag) cfg.faceTag = tag;
		}
		return cfg;
	}

	// --- Condiciones --------------------------------------------------------------------------

	const WORD_KINDS = { visto: "seen", sabe: "knows", flag: "flag", presente: "present" };
	const OPS = [">=", "<=", "!=", "=", ">", "<"];

	/** Igual que Story._parse_criterion. Devuelve {} si no es válida. */
	function parseCriterion(text, cfg) {
		cfg = cfg || DEFAULT_CONFIG;
		let negate = false;
		if (text.startsWith("no ")) {
			negate = true;
			text = text.substring(3).trim();
		}
		if (text === "una vez") return { kind: "once", negate };
		for (const word of ["visto", "sabe", "flag", "presente"]) {
			if (text.startsWith(word + " ")) {
				return { kind: WORD_KINDS[word], arg: text.substring(word.length + 1).trim(), negate };
			}
		}
		for (const op of OPS) {
			const i = text.indexOf(op);
			if (i < 0) continue;
			const key = text.substring(0, i).trim();
			const arg = text.substring(i + op.length).trim();
			switch (key) {
				case "fase": return { kind: "phase", op, arg, negate };
				case "tramo": return { kind: "tier", op, arg, negate };
				case "hoy": return { kind: "today", op, arg, negate };
				case "veces": return { kind: "times", op, arg, negate };
				case "ánimo": case "animo": return { kind: "mood", op, arg, negate };
				case "resultado": return { kind: "context", key: "resultado", op, arg, negate };
			}
			if (Object.prototype.hasOwnProperty.call(cfg.dims, key)) return { kind: "dim", dim: key, op, arg, negate };
			return {};
		}
		return {};
	}

	/** Texto de una condición, tal como se escribe en el .dialogue. */
	function criterionToText(c) {
		const no = c.negate ? "no " : "";
		switch (c.kind) {
			case "once": return no + "una vez";
			case "seen": return no + "visto " + c.arg;
			case "knows": return no + "sabe " + c.arg;
			case "flag": return no + "flag " + c.arg;
			case "present": return no + "presente " + c.arg;
			case "phase": return no + "fase " + c.op + " " + c.arg;
			case "tier": return no + "tramo " + c.op + " " + c.arg;
			case "today": return no + "hoy " + c.op + " " + c.arg;
			case "times": return no + "veces " + c.op + " " + c.arg;
			case "mood": return no + "ánimo " + c.op + " " + c.arg;
			case "context": return no + (c.key || "resultado") + " " + c.op + " " + c.arg;
			case "dim": return no + c.dim + " " + c.op + " " + c.arg;
		}
		return c.raw || "";
	}

	/** «# titulo: …»: nombre legible de la escena (solo lo usa el editor; el juego lo ignora). */
	const TITLE_PREFIX = "# titulo:";

	/** «# cuando: momento, cond, cond». Devuelve {moment, criteria, errors}. */
	function parseRuleLine(line, cfg) {
		const parts = line.trim().substring(9).split(",");
		const moment = parts[0].trim();
		const criteria = [];
		const errors = [];
		for (let i = 1; i < parts.length; i++) {
			const raw = parts[i].trim();
			const c = parseCriterion(raw, cfg);
			if (!c.kind) errors.push(raw);
			else { c.raw = raw; criteria.push(c); }
		}
		return { moment, criteria, errors };
	}

	function ruleToLine(rule) {
		const items = [rule.moment].concat(rule.criteria.map((c) => (c.raw && !c.dirty ? c.raw : criterionToText(c))));
		for (const e of rule.errors || []) items.push(e);
		return "# cuando: " + items.join(", ");
	}

	// --- Archivos .dialogue como bloques editables ---------------------------------------------

	/**
	 * Divide un .dialogue en cabecera y bloques de cue. Cada bloque guarda su
	 * texto original (`raw`) para reescribir solo lo que se haya editado.
	 */
	function parseFile(name, text, cfg) {
		const lines = text.split("\n");
		const file = { name, original: text, header: [], cues: [], trailingNewline: text.endsWith("\n") };
		let cur = null;
		const flush = () => { if (cur) { finishCue(cur, cfg); file.cues.push(cur); } };
		const body = lines[lines.length - 1] === "" ? lines.slice(0, -1) : lines;
		for (const raw of body) {
			const t = raw.trim();
			if (t.startsWith("~ ")) {
				flush();
				cur = { name: t.substring(2).trim(), file: name, lines: [raw] };
			} else if (cur) {
				cur.lines.push(raw);
			} else {
				file.header.push(raw);
			}
		}
		flush();
		return file;
	}

	function finishCue(cue, cfg) {
		cue.raw = cue.lines.join("\n");
		cue.rules = [];
		const bodyLines = [];
		for (let i = 1; i < cue.lines.length; i++) {
			const t = cue.lines[i].trim();
			if (t.startsWith("# cuando:")) {
				const r = parseRuleLine(t, cfg);
				r.rawLine = t;
				cue.rules.push(r);
			} else if (t.startsWith(TITLE_PREFIX) && !cue.title) {
				cue.title = t.slice(TITLE_PREFIX.length).trim();   // nombre legible (editor de escenas)
			} else {
				bodyLines.push(cue.lines[i]);
			}
		}
		cue.body = bodyLines.join("\n");
		cue.dirty = false;
		delete cue.lines;
	}

	function cueToText(cue) {
		if (!cue.dirty && cue.raw !== undefined) return cue.raw;
		const out = ["~ " + cue.name];
		if (cue.title) out.push(TITLE_PREFIX + " " + cue.title);
		for (const r of cue.rules) out.push(r.rawLine && !r.dirty ? r.rawLine : ruleToLine(r));
		if (cue.body !== "") out.push(cue.body);
		return out.join("\n");
	}

	function serializeFile(file) {
		const parts = [];
		if (file.header.length) parts.push(file.header.join("\n"));
		for (const c of file.cues) parts.push(cueToText(c));
		let text = parts.join("\n");
		if (file.trailingNewline || file.original === undefined) text += "\n";
		return text;
	}

	// --- Selector (igual que Story.candidates) ---------------------------------------------------

	/** Reglas por momento a partir de los archivos (ignora los que empiezan por «_»). */
	function buildRules(files) {
		const byMoment = {};
		const cueFiles = {};
		for (const f of files) {
			if (f.name.startsWith("_")) continue;
			for (const c of f.cues) {
				cueFiles[c.name] = f.name;
				for (const r of c.rules) {
					(byMoment[r.moment] = byMoment[r.moment] || []).push({ cue: c.name, file: f.name, criteria: r.criteria, ruleRef: r, cueRef: c });
				}
			}
		}
		return { byMoment, cueFiles };
	}

	function compare(a, op, b) {
		switch (op) {
			case ">=": return a >= b;
			case "<=": return a <= b;
			case ">": return a > b;
			case "<": return a < b;
			case "!=": return a !== b;
		}
		return a === b;
	}

	// int() de GDScript sobre un texto: 0 si no es un número entero.
	function gdInt(s) { const m = String(s).trim().match(/^[+-]?\d+/); return m ? parseInt(m[0], 10) : 0; }
	function gdFloat(s) { const v = parseFloat(String(s).trim()); return isNaN(v) ? 0 : v; }

	/** Igual que Story._check. `st` es el estado (ver simState). */
	function check(c, cueName, who, moment, context, st, cfg) {
		let ok = true;
		switch (c.kind) {
			case "once": ok = !st.seen(cueName); break;
			case "seen": ok = st.seen(c.arg); break;
			case "knows": ok = st.knows(who, c.arg); break;
			case "flag": ok = st.flag(c.arg); break;
			case "present": ok = st.present(c.arg); break;
			case "phase": ok = compare(st.phaseIndex(), c.op, cfg.phases.indexOf(c.arg)); break;
			case "tier": ok = compare(cfg.tiers.indexOf(st.tier(who)), c.op, cfg.tiers.indexOf(c.arg)); break;
			case "mood": {
				const list = c.arg.split("|");
				ok = c.op === "=" ? list.includes(st.mood(who)) : !list.includes(st.mood(who));
				break;
			}
			case "today": ok = compare(st.today(who), c.op, gdInt(c.arg)); break;
			case "times": ok = compare(st.timesToday(who, moment), c.op, gdInt(c.arg)); break;
			case "dim": ok = compare(st.value(who, c.dim), c.op, gdFloat(c.arg)); break;
			case "context": ok = c.arg.split("|").includes(String(context[c.key] !== undefined ? context[c.key] : "")); break;
		}
		return ok !== c.negate;
	}

	/** Puntuación de una regla: {score, failedIndex}. score = -1 si falla alguna condición. */
	function scoreRule(rule, who, moment, context, st, cfg) {
		let score = 0;
		for (let i = 0; i < rule.criteria.length; i++) {
			const c = rule.criteria[i];
			if (!check(c, rule.cue, who, moment, context, st, cfg)) return { score: -1, failedIndex: i };
			score += cfg.weights[c.kind] !== undefined ? cfg.weights[c.kind] : 1;
		}
		return { score, failedIndex: -1 };
	}

	/** Igual que Story.candidates: [{rule, raw, score, best, failedIndex}]. */
	function candidates(rules, who, moment, context, st, cfg) {
		const out = [];
		let best = -1;
		for (const rule of rules.byMoment[moment] || []) {
			if (rule.file !== who && rule.file !== cfg.general) continue;
			const r = scoreRule(rule, who, moment, context, st, cfg);
			let score = r.score;
			if (score >= 0) {
				score = score * 2 + (rule.file === who ? 1 : 0);
				best = Math.max(best, score);
			}
			out.push({ rule, raw: r.score, score, best: false, failedIndex: r.failedIndex });
		}
		for (const c of out) c.best = best >= 0 && c.score === best;
		return out;
	}

	// --- Estado simulado ------------------------------------------------------------------------

	/** Tramo a partir de las dimensiones (igual que Social.tier). */
	function tierFromDims(d) {
		const score = (d.afecto || 0) - (d.resentimiento || 0) - (d.asco || 0) * 0.5;
		if (score < -40) return "hostil";
		if (score < -10) return "fria";
		if (score < 25) return "neutral";
		if (score < 55) return "cercana";
		return "intima";
	}

	/**
	 * Estado simulado para un personaje. `s` es un objeto plano:
	 * {phase, mood, dims:{...}, today, times, knows:[], flags:[], present:[], seen:[]}
	 */
	function simState(s, cfg) {
		const has = (list, v) => (list || []).includes(v);
		return {
			seen: (cue) => has(s.seen, cue),
			knows: (_who, ev) => has(s.knows, ev),
			flag: (id) => has(s.flags, id),
			present: (id) => id === cfg.protagonist || has(s.present, id),
			phaseIndex: () => cfg.phases.indexOf(s.phase),
			tier: () => tierFromDims(s.dims || {}),
			mood: () => s.mood || "tranquilo",
			today: () => s.today || 0,
			timesToday: (_who, moment) => {
				let mapped = false;
				for (const a in cfg.actionMoments) if (moment.endsWith(cfg.actionMoments[a])) mapped = true;
				return mapped ? (s.times || 0) : 0;
			},
			value: (_who, dim) => ((s.dims || {})[dim] || 0),
		};
	}

	// --- Descripción en lenguaje natural ----------------------------------------------------

	const OP_TEXT = { "=": "es", "!=": "no es", ">=": "es al menos", "<=": "es como mucho", ">": "es más que", "<": "es menos que" };

	function describeCriterion(c, cfg, names) {
		const n = (id) => (names && names[id]) || id;
		const neg = c.negate;
		switch (c.kind) {
			case "once": return neg ? "ya se ha visto antes" : "la primera vez";
			case "seen": return (neg ? "sin haber visto " : "después de ver ") + c.arg;
			case "knows": return (neg ? "si no sabe " : "si sabe ") + c.arg;
			case "flag": return (neg ? "sin el indicador " : "con el indicador ") + c.arg;
			case "present": return (neg ? "si no está " : "si está ") + n(c.arg);
			case "phase": return (neg ? "salvo si " : "si ") + "la fase " + OP_TEXT[c.op] + " «" + c.arg + "»";
			case "tier": return (neg ? "salvo si " : "si ") + "la relación " + OP_TEXT[c.op] + " «" + c.arg + "»";
			case "mood": return (neg ? "salvo si " : "si ") + "su ánimo " + (c.op === "=" ? "es " : "no es ") + c.arg.split("|").join(" o ");
			case "today": return (neg ? "salvo si " : "si ") + "las interacciones de hoy " + OP_TEXT[c.op] + " " + c.arg;
			case "times": return (neg ? "salvo si " : "si ") + "las veces de hoy " + OP_TEXT[c.op] + " " + c.arg;
			case "dim": return (neg ? "salvo si " : "si ") + "su " + c.dim + " hacia Ren " + OP_TEXT[c.op] + " " + c.arg;
			case "context": return (neg ? "salvo si " : "si ") + "el resultado es " + c.arg.split("|").join(" o ");
		}
		return "?";
	}

	const api = {
		DEFAULT_CONFIG, configFromSources,
		parseCriterion, criterionToText, parseRuleLine, ruleToLine,
		parseFile, serializeFile, cueToText,
		buildRules, check, scoreRule, candidates,
		tierFromDims, simState, describeCriterion, OPS,
	};
	if (typeof module !== "undefined" && module.exports) module.exports = api;
	else root.Motor = api;
})(typeof window !== "undefined" ? window : globalThis);
