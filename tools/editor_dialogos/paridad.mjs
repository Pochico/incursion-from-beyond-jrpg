// Prueba de paridad del editor de diálogos (lado JavaScript).
//   node paridad.mjs generar N SEMILLA > casos.json   → situaciones al azar
//   node paridad.mjs evaluar casos.json > js.json      → candidatos según motor.js
//   node paridad.mjs comparar js.json godot.json      → diferencias (código 1 si hay)
// Se ejecuta desde la raíz del proyecto (lo hace paridad.sh).
import { createRequire } from "module";
import fs from "fs";
const require = createRequire(import.meta.url);
const M = require("../../docs/editor-dialogos/motor.js");

const read = (p) => fs.readFileSync(p, "utf8");
const cfg = M.configFromSources({
	gameState: read("src/autoload/game_state.gd"), social: read("src/systems/social.gd"),
	story: read("src/autoload/story.gd"), characterDb: read("src/data/character_db.gd"),
});
const files = fs.readdirSync("src/dialogue").filter((f) => f.endsWith(".dialogue"))
	.map((f) => M.parseFile(f.slice(0, -9), read("src/dialogue/" + f), cfg));
const rules = M.buildRules(files);

const [mode, a, b] = process.argv.slice(2);

if (mode === "generar") {
	let seed = Number(b || 1);
	const rnd = () => ((seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648);
	const pick = (list) => list[Math.floor(rnd() * list.length)];
	const some = (list, p) => list.filter(() => rnd() < p);
	const whos = files.map((f) => f.name).filter((n) => n !== cfg.general && cfg.characters.some((c) => c.id === n));
	const moments = Object.keys(rules.byMoment);
	const cueNames = Object.keys(rules.cueFiles);
	const used = (kind) => [...new Set(files.flatMap((f) => f.cues.flatMap((c) => c.rules.flatMap((r) => r.criteria.filter((x) => x.kind === kind).map((x) => x.arg)))))];
	const events = used("knows"), flags = used("flag");
	const chars = cfg.characters.filter((c) => !c.enemy).map((c) => c.id);
	const cases = [];
	for (let i = 0; i < Number(a || 300); i++) {
		const moment = pick(moments);
		let action = "";
		for (const k in cfg.actionMoments) if (moment.endsWith(cfg.actionMoments[k])) action = k;
		const dims = {};
		for (const d in cfg.dims) dims[d] = Math.round(cfg.dims[d][0] + rnd() * (cfg.dims[d][1] - cfg.dims[d][0]));
		let times = Math.floor(rnd() * 4), today = Math.floor(rnd() * 4);
		if (["talk", "flirt", "fight"].includes(action)) today = Math.max(today, times);
		cases.push({
			who: pick(whos), moment, action,
			context: rnd() < 0.5 ? { resultado: pick(["gana", "pierde", ""]) } : {},
			phase: pick(cfg.phases), mood: pick(cfg.moods), dims, today, times,
			knows: some(events, 0.5), flags: some(flags, 0.5), present: some(chars, 0.3),
			seen: some(cueNames, 0.3),
		});
	}
	process.stdout.write(JSON.stringify(cases));
} else if (mode === "evaluar") {
	const cases = JSON.parse(read(a));
	const out = cases.map((c) => {
		const st = M.simState(c, cfg);
		return M.candidates(rules, c.who, c.moment, c.context, st, cfg)
			.map((x) => ({ cue: x.rule.cue, score: x.score, best: x.best }))
			.sort((p, q) => (p.cue + p.score).localeCompare(q.cue + q.score));
	});
	process.stdout.write(JSON.stringify(out));
} else if (mode === "comparar") {
	// Forma canónica (Godot ordena las claves del JSON a su manera).
	const canon = (list) => list.map((x) => `${x.cue}:${Number(x.score)}:${x.best}`).sort();
	const js = JSON.parse(read(a)).map(canon), gd = JSON.parse(read(b)).map(canon);
	let diff = 0;
	js.forEach((r, i) => {
		if (JSON.stringify(r) !== JSON.stringify(gd[i])) {
			if (diff < 5) console.log(`Caso ${i}:\n  JS:    ${JSON.stringify(r)}\n  Godot: ${JSON.stringify(gd[i])}`);
			diff++;
		}
	});
	const winners = js.filter((r) => r.some((x) => x.endsWith(":true"))).length;
	console.log(`${js.length} casos, ${winners} con algún diálogo elegido · diferencias: ${diff}`);
	process.exit(diff ? 1 : 0);
}
