/*
 * Flujo de una conversación: convierte el texto de un cue (sintaxis de
 * Dialogue Manager) en un árbol por sangría y lo vuelve a escribir.
 *
 * - Un archivo sin cambios se reescribe idéntico (cada línea guarda su texto
 *   original y solo las editadas se regeneran).
 * - Las líneas hijas son las que tienen más sangría (ramas de una opción,
 *   bloque de una variante «%», cuerpo de un «if»...).
 *
 * Funciona en el navegador (window.Flujo) y en Node (module.exports).
 */
(function (root) {
	"use strict";

	/** Árbol de un texto: {indent:-1, children:[{raw, text, indent, children}]} */
	function parse(body) {
		const tree = { indent: -1, children: [] };
		const stack = [tree];
		for (const raw of body.split("\n")) {
			const lead = raw.match(/^[\t ]*/)[0];
			const indent = (lead.match(/\t/g) || []).length + Math.floor(lead.replace(/\t/g, "").length / 4);
			const text = raw.trim();
			const node = { raw, text, indent, children: [] };
			if (text === "") {
				stack[stack.length - 1].children.push(node);
				continue;
			}
			while (stack.length > 1 && stack[stack.length - 1].indent >= indent) stack.pop();
			stack[stack.length - 1].children.push(node);
			stack.push(node);
		}
		return tree;
	}

	function serialize(tree) {
		const out = [];
		const walk = (n) => {
			for (const c of n.children) {
				out.push(c.dirty ? "\t".repeat(Math.max(c.indent, 0)) + c.text : c.raw);
				walk(c);
			}
		};
		walk(tree);
		return out.join("\n");
	}

	/** Tipo de una línea. */
	function kind(text) {
		if (text === "") return "blank";
		if (text.startsWith("#")) return "comment";
		if (text.startsWith("- ")) return "option";
		if (/^%\d*(\s|$)/.test(text)) return "variant";
		if (/^(if|elif|else|while|match|when)\b/.test(text)) return "cond";
		if (/^(\$>|do |do!|set )/.test(text)) return "mutation";
		if (/^=></.test(text) || /^=>/.test(text)) return "jump";
		return "line";
	}

	function tagsOf(t) { return (t.match(/\[#[^\]]*\]/g) || []).join(" "); }
	function stripTags(t) { return t.replace(/\s*\[#[^\]]*\]/g, "").trim(); }
	function unescape(t) { return t.replace(/\\:/g, ":"); }
	function escapeNarration(t) { return t.replace(/(^|[^\\]):(\s)/g, "$1\\:$2"); }

	/** «Nombre: texto [#tags]» o narración. {prefix, speaker, body, tags} */
	function parseLine(text) {
		let t = text, prefix = "";
		const pm = t.match(/^(%\d*)\s+/);
		if (pm) { prefix = pm[1]; t = t.slice(pm[0].length); }
		const tags = tagsOf(t);
		t = stripTags(t);
		const m = t.match(/^([^:\\]{1,40}?):\s([\s\S]*)$/);
		if (m) return { prefix, speaker: m[1].trim(), body: m[2], tags };
		return { prefix, speaker: "", body: unescape(t), tags };
	}

	function buildLine(p) {
		const body = p.speaker ? p.speaker + ": " + p.body.trim() : escapeNarration(p.body.trim());
		return (p.prefix ? p.prefix + " " : "") + body + (p.tags ? " " + p.tags.trim() : "");
	}

	/** «- texto [#tags] => cue». {body, tags, jump} */
	function parseOption(text) {
		let t = text.slice(2);
		let jump = "";
		const jm = t.match(/\s=>\s*(\S+)/);
		if (jm) { jump = jm[1]; t = t.replace(jm[0], ""); }
		return { body: unescape(stripTags(t)), tags: tagsOf(t), jump };
	}

	function buildOption(p) {
		return "- " + p.body.trim() + (p.tags ? " " + p.tags.trim() : "") + (p.jump ? " => " + p.jump : "");
	}

	/** Etiquetas sueltas de un texto «[#a, #b=c]» → ["a", "b=c"]. */
	function tagList(tags) {
		const out = [];
		for (const m of (tags || "").matchAll(/\[([^\]]*)\]/g)) {
			for (const part of m[1].split(",")) { const v = part.trim().replace(/^#/, ""); if (v) out.push(v); }
		}
		return out;
	}

	function tagsFromList(list) { return list.length ? "[" + list.map((t) => "#" + t).join(", ") + "]" : ""; }

	function nodeAt(tree, path) {
		let n = tree;
		for (const i of path) n = n.children[i];
		return n;
	}

	const api = { parse, serialize, kind, parseLine, buildLine, parseOption, buildOption, tagList, tagsFromList, unescape, nodeAt };
	if (typeof module !== "undefined" && module.exports) module.exports = api;
	else root.Flujo = api;
})(typeof window !== "undefined" ? window : globalThis);
