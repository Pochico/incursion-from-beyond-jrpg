class_name SkillDB
extends RefCounted
## Catálogo de habilidades, estados y fórmulas de combate.
##
## Fuentes de diseño (propuestas, pendientes de prueba de combate):
##  - docs/diseno/habilidades_tiers.md: las 32 habilidades por tipo (PSY, ARQ,
##    BIO, CYBER, MECH) con tier 1–5. Sus ID son los estables del documento
##    («PSY-01»…); si cambia un nombre, se migra por ID.
##  - docs/diseno/habilidades_1.md: fórmulas comunes y las habilidades
##    intrínsecas iniciales (ID en minúsculas, «bio_impulso_organico»…).
##
## Todo se calcula con la fórmula para el nivel exacto (1..60): no hay tablas
## por nivel ni interpolación. El tier no multiplica nada por sí mismo.
##
## Campos de una habilidad:
##   name, nature, tier (0 = sin tier), role, icon, desc
##   role    : "attack", "heal", "buff", "debuff" o "utility" (lo usa la IA)
##   cost    : [C0, k]  →  CostePM(L) = C0 + ceil(k × (L − 1))
##   cd      : turnos propios de espera tras usarla (0 = sin espera)
##   target  : "enemy" (uno), "enemies" (área), "self", "ally" (el compañero en
##             pie, o uno mismo si no hay), "allies" (todo el grupo) o "link"
##             (vincula a los dos miembros del grupo)
##   requires        : el objetivo debe tener alguna de estas etiquetas (TAGS)
##   caster_requires : quien la usa debe tener alguna de estas etiquetas
##   caster_natures  : quien la usa debe ser de alguna de estas naturalezas
##   ops     : operaciones que se resuelven en orden:
##     {op: "damage", mult, attr, defense, kind}      → mult × B(L,A) × 100/(100+R)
##     {op: "heal", mult, attr}                       → mult × H(L,A)
##     {op: "status", status, turns, [turns_from], [chance, attr, resist],
##        [requires], [on: "self"], + valores del estado (ver STATUSES)}
##     {op: "self_damage", pct}                       → ceil(pct % de PVmáx); deja 1 PV
##     {op: "recover_pm", base, per_level, per_attr, attr}
##     {op: "cleanse", count, [count_from], [origin]} → quita estados negativos
##     {op: "reveal"}                                 → como Analizar
##
## Atributos: FUE, TEC, INT, VOL, RES (+ AGI, sin uso en fórmulas). "ARQ" en
## `attr` significa max(INT, VOL). Un valor escalable puede ser un número o
## [base, cada, paso] → base + floor((L − 1) / cada) × paso.

const ALL := {
	# === PSY — Psíquico =============================================================
	"PSY-01": {
		"name": "Proyección astral", "nature": "psychic", "tier": 5, "role": "buff", "icon": "sparkle",
		"desc": "Te proyectas fuera del cuerpo hasta el final de tu próximo turno: no recibes daño. Mientras, solo puedes usar habilidades psíquicas, al 60 % de potencia.",
		"cost": [36, 0.60], "cd": 6, "target": "self", "exclusive": ["excorporado"],
		"ops": [{"op": "status", "status": "proyeccion", "turns": 1, "psy_mult": 0.60}],
	},
	"PSY-02": {
		"name": "Manifestar", "nature": "psychic", "tier": 4, "role": "buff", "icon": "sparkle",
		"desc": "Tu próxima habilidad de daño o curación (antes de que acabe tu siguiente turno) gana potencia: +30 %, que crece con el nivel.",
		"cost": [23, 0.33], "cd": 4, "target": "self",
		"ops": [{"op": "status", "status": "manifestar", "turns": 1, "bonus": [30, 5, 2]}],
	},
	"PSY-03": {
		"name": "Meditación", "nature": "psychic", "tier": 2, "role": "utility", "icon": "heart",
		"desc": "Gastas el turno en concentrarte y recuperas PM (VOL).",
		"cost": [0, 0.0], "cd": 3, "target": "self",
		"ops": [{"op": "recover_pm", "base": 10.0, "per_level": 0.55, "per_attr": 0.60, "attr": "VOL"}],
	},
	"PSY-04": {
		"name": "Adivinación", "nature": "psychic", "tier": 1, "role": "utility", "icon": "sparkle",
		"desc": "Te dejas llevar: en tu siguiente turno haces una acción al azar entre las que puedas hacer.",
		"cost": [5, 0.06], "cd": 2, "target": "self",
		"ops": [{"op": "status", "status": "adivinacion", "turns": 1}],
	},
	"PSY-05": {
		"name": "Euforia", "nature": "psychic", "tier": 1, "role": "buff", "icon": "plus",
		"desc": "+1 a todos los atributos (FUE, RES, INT, VOL, TEC y AGI) durante 1 turno. No crece con el nivel.",
		"cost": [6, 0.0], "cd": 2, "target": "self",
		"ops": [{"op": "status", "status": "euforia", "turns": 1,
			"stat_add": {"FUE": 1, "RES": 1, "INT": 1, "VOL": 1, "TEC": 1, "AGI": 1}}],
	},
	"PSY-06": {
		"name": "Empatía", "nature": "psychic", "tier": 3, "role": "buff", "icon": "heart",
		"desc": "Vincula a los dos miembros del grupo durante 2 turnos: el daño que recibe uno se reparte a medias con el otro.",
		"cost": [19, 0.33], "cd": 4, "target": "link", "requires": ["mente"],
		"ops": [{"op": "status", "status": "empatia", "turns": 2}],
	},
	"PSY-07": {
		"name": "Excorporar", "nature": "psychic", "tier": 3, "role": "buff", "icon": "shield",
		"desc": "Sales de tu cuerpo: pierdes tu siguiente turno, pero hasta que acabe no recibes daño.",
		"cost": [18, 0.30], "cd": 4, "target": "self", "exclusive": ["proyeccion"],
		"ops": [{"op": "status", "status": "excorporado", "turns": 1}],
	},
	# === ARQ — Arcano / místico (id interno «mystic») ===================================
	"ARQ-01": {
		"name": "Pacto", "nature": "mystic", "tier": 3, "role": "buff", "icon": "alert",
		"desc": "Pagas el 10 % de tus PV máximos: durante 3 turnos haces +25 % de daño (crece con el nivel) y recibes un 15 % menos.",
		"cost": [20, 0.30], "cd": 5, "target": "self",
		"ops": [
			{"op": "self_damage", "pct": 10.0},
			{"op": "status", "status": "pacto", "turns": 3, "dmg_out": [25, 10, 2], "dmg_in": 15},
		],
	},
	"ARQ-02": {
		"name": "Dominio", "nature": "mystic", "tier": 5, "role": "buff", "icon": "sparkle",
		"desc": "Durante 3 turnos tu bando hace +25 % de daño y el contrario un 15 % menos. Solo un Dominio por bando.",
		"cost": [43, 0.60], "cd": 7, "target": "self",
		"ops": [{"op": "status", "status": "dominio", "turns": 3, "field_out": 25, "field_in": 15}],
	},
	"ARQ-03": {
		"name": "Ascensión", "nature": "mystic", "tier": 5, "role": "buff", "icon": "sparkle",
		"desc": "Durante 2 turnos haces +45 % de daño (crece con el nivel), pero recibes un 20 % más y tus habilidades cuestan un 20 % más de PM.",
		"cost": [38, 0.55], "cd": 7, "target": "self",
		"ops": [{"op": "status", "status": "ascension", "turns": 2, "dmg_out": [45, 10, 2], "dmg_in": -20, "cost_mult": 1.20}],
	},
	"ARQ-04": {
		"name": "Sacrificio", "nature": "mystic", "tier": 3, "role": "buff", "icon": "alert",
		"desc": "Pagas el 12 % de tus PV máximos: tu próxima habilidad ofensiva (antes de que acabe tu siguiente turno) hace +75 % de daño (crece con el nivel).",
		"cost": [13, 0.22], "cd": 4, "target": "self",
		"ops": [
			{"op": "self_damage", "pct": 12.0},
			{"op": "status", "status": "sacrificio", "turns": 1, "bonus": [75, 10, 3]},
		],
	},
	"ARQ-05": {
		"name": "Maldecir", "nature": "mystic", "tier": 2, "role": "debuff", "icon": "alert",
		"desc": "75 % base de maldecir al rival: hace un 20 % menos de daño durante 3 turnos.",
		"cost": [12, 0.20], "cd": 3, "target": "enemy",
		"ops": [{"op": "status", "status": "maldito", "turns": 3, "chance": 75.0, "attr": "ARQ", "resist": "VOL", "dmg_out": -20}],
	},
	"ARQ-06": {
		"name": "Bendecir", "nature": "mystic", "tier": 2, "role": "buff", "icon": "plus",
		"desc": "Tu compañero (o tú, si luchas solo) hace +15 % de daño y recibe un 10 % menos durante 2 turnos.",
		"cost": [14, 0.21], "cd": 3, "target": "ally",
		"ops": [{"op": "status", "status": "bendecido", "turns": 2, "dmg_out": 15, "dmg_in": 10}],
	},
	"ARQ-07": {
		"name": "Lluvia de sangre", "nature": "mystic", "tier": 4, "role": "attack", "icon": "slash",
		"desc": "Daño en área ×0,70 (INT/VOL contra RES) y 70 % base de sangrado durante 2 turnos (solo con tejido vivo).",
		"cost": [30, 0.48], "cd": 4, "target": "enemies",
		"ops": [
			{"op": "damage", "mult": 0.70, "attr": "ARQ", "defense": "RES", "kind": "arcano"},
			{"op": "status", "status": "sangrado", "turns": 2, "chance": 70.0, "attr": "ARQ", "resist": "RES",
				"requires": ["tejido"], "tick": {"mult": 0.20, "attr": "ARQ", "defense": "RES"}},
		],
	},
	"ARQ-08": {
		"name": "Voz celestial", "nature": "mystic", "tier": 4, "role": "heal", "icon": "heart",
		"desc": "Cura a todo el grupo ×0,70 (INT/VOL) y quita un estado negativo a cada uno. No revive.",
		"cost": [29, 0.45], "cd": 5, "target": "allies",
		"ops": [
			{"op": "heal", "mult": 0.70, "attr": "ARQ"},
			{"op": "cleanse", "count": 1},
		],
	},
	# === BIO — Biológico ================================================================
	"BIO-01": {
		"name": "Corrosión", "nature": "biological", "tier": 3, "role": "attack", "icon": "flask",
		"desc": "Daño ×0,60 (FUE), daño residual ×0,12 durante 2 turnos y 80 % base de bajar su RES un 20 % durante 2 turnos. Corroe tejido y metal.",
		"cost": [18, 0.30], "cd": 3, "target": "enemy", "requires": ["materia"],
		"ops": [
			{"op": "damage", "mult": 0.60, "attr": "FUE", "defense": "RES", "kind": "corrosivo"},
			{"op": "status", "status": "acido", "turns": 2, "tick": {"mult": 0.12, "attr": "FUE", "defense": "RES"}},
			{"op": "status", "status": "corrosion", "turns": 2, "chance": 80.0, "attr": "FUE", "resist": "RES",
				"stat_mult": {"RES": 0.80}},
		],
	},
	"BIO-02": {
		"name": "Aliento tóxico", "nature": "biological", "tier": 3, "role": "attack", "icon": "flask",
		"desc": "Nube en área: daño ×0,30 (FUE) y 70 % base de veneno ×0,18 durante 3 turnos. No envenena máquinas ni datos.",
		"cost": [22, 0.32], "cd": 3, "target": "enemies",
		"ops": [
			{"op": "damage", "mult": 0.30, "attr": "FUE", "defense": "RES", "kind": "toxico"},
			{"op": "status", "status": "veneno", "turns": 3, "chance": 70.0, "attr": "FUE", "resist": "RES",
				"requires": ["tejido"], "tick": {"mult": 0.18, "attr": "FUE", "defense": "RES"}},
		],
	},
	"BIO-03": {
		"name": "Puñete", "nature": "biological", "tier": 1, "role": "attack", "icon": "swords",
		"desc": "Golpe contundente ×0,90 (FUE) con un 10 % base de aturdir (pierde su siguiente acción).",
		"cost": [5, 0.10], "cd": 0, "target": "enemy", "requires": ["materia"],
		"ops": [
			{"op": "damage", "mult": 0.90, "attr": "FUE", "defense": "RES", "kind": "fisico"},
			{"op": "status", "status": "aturdido", "turns": 1, "chance": 10.0, "attr": "FUE", "resist": "RES"},
		],
	},
	"BIO-04": {
		"name": "Regeneración celular", "nature": "biological", "tier": 4, "role": "heal", "icon": "heart",
		"desc": "Tus tejidos se reparan: recuperas PV ×0,40 (RES) al final de cada uno de tus 3 próximos turnos. Necesita tejido vivo.",
		"cost": [23, 0.38], "cd": 5, "target": "self", "caster_requires": ["tejido"],
		"ops": [{"op": "status", "status": "regeneracion", "turns": 3, "regen": {"mult": 0.40, "attr": "RES"}}],
	},
	"BIO-05": {
		"name": "Resiliencia", "nature": "biological", "tier": 2, "role": "buff", "icon": "shield",
		"desc": "Durante 2 turnos recibes un 20 % menos de daño y resistes mejor los estados (+15 puntos).",
		"cost": [12, 0.20], "cd": 3, "target": "self",
		"ops": [{"op": "status", "status": "resiliencia", "turns": 2, "dmg_in": 20, "status_res": 15}],
	},
	"BIO-06": {
		"name": "Improvisación ofensiva", "nature": "biological", "tier": 2, "role": "attack", "icon": "slash",
		"desc": "Adaptas tu cuerpo o lo que tengas a mano para improvisar un ataque: daño ×1,15 (FUE) y 20 % base de sangrado ×0,12 durante 1 turno. Solo seres biológicos (humanos incluidos).",
		"cost": [15, 0.24], "cd": 2, "target": "enemy",
		# Alude al libre albedrío de los seres vivos comunes: solo naturaleza biológica.
		"caster_natures": ["biological"],
		"ops": [
			{"op": "damage", "mult": 1.15, "attr": "FUE", "defense": "RES", "kind": "fisico"},
			{"op": "status", "status": "sangrado", "turns": 1, "chance": 20.0, "attr": "FUE", "resist": "RES",
				"requires": ["tejido"], "tick": {"mult": 0.12, "attr": "FUE", "defense": "RES"}},
		],
	},
	# === CYBER — Digital ================================================================
	"CYBER-01": {
		"name": "Explosión de bolsillo", "nature": "digital", "tier": 3, "role": "attack", "icon": "alert",
		"desc": "Haces estallar un dispositivo: daño ×1,15 (TEC contra RES). Necesita un soporte físico.",
		"cost": [24, 0.38], "cd": 3, "target": "enemy", "caster_requires": ["materia"],
		"ops": [{"op": "damage", "mult": 1.15, "attr": "TEC", "defense": "RES", "kind": "explosivo"}],
	},
	"CYBER-02": {
		"name": "Deslumbrar", "nature": "digital", "tier": 2, "role": "debuff", "icon": "sparkle",
		"desc": "Destello: 80 % base de bajar su precisión un 30 % durante 2 turnos. Sin vista, no le afecta.",
		"cost": [13, 0.22], "cd": 3, "target": "enemy", "requires": ["vision"],
		"ops": [{"op": "status", "status": "deslumbrado", "turns": 2, "chance": 80.0, "attr": "TEC", "resist": "TEC", "acc": -30}],
	},
	"CYBER-03": {
		"name": "Ultrasónico", "nature": "digital", "tier": 3, "role": "attack", "icon": "antenna",
		"desc": "Pulso en área: daño ×0,40 (TEC contra RES) y 70 % base de bajar su precisión un 20 % durante 2 turnos (si oye).",
		"cost": [19, 0.29], "cd": 3, "target": "enemies",
		"ops": [
			{"op": "damage", "mult": 0.40, "attr": "TEC", "defense": "RES", "kind": "sonico"},
			{"op": "status", "status": "desorientado", "turns": 2, "chance": 70.0, "attr": "TEC", "resist": "VOL",
				"requires": ["oido"], "acc": -20},
		],
	},
	"CYBER-04": {
		"name": "Inutilizar dispositivo", "nature": "digital", "tier": 4, "role": "debuff", "icon": "lock",
		"desc": "55 % base (TEC contra TEC) de desactivar sus sistemas: pierde 1 turno (2 desde el nivel 40). Solo contra electrónica.",
		"cost": [29, 0.45], "cd": 5, "target": "enemy", "requires": ["electronica"],
		"ops": [{"op": "status", "status": "desactivado", "turns": 1, "turns_from": {40: 2},
			"chance": 55.0, "attr": "TEC", "resist": "TEC"}],
	},
	"CYBER-05": {
		"name": "Robo de datos", "nature": "digital", "tier": 2, "role": "debuff", "icon": "antenna",
		"desc": "Revela al rival como Analizar y, con un 85 % base, tu siguiente habilidad ofensiva contra él en 2 turnos hace +10 %.",
		"cost": [12, 0.18], "cd": 2, "target": "enemy", "requires": ["datos", "electronica"],
		"ops": [
			{"op": "reveal"},
			{"op": "status", "status": "expuesto", "turns": 2, "chance": 85.0, "attr": "TEC", "resist": "TEC", "bonus": 10},
		],
	},
	# === MECH — Mecánico ================================================================
	"MECH-01": {
		"name": "Sobrecarga", "nature": "mechanical", "tier": 4, "role": "buff", "icon": "alert",
		"desc": "Durante 2 turnos tus habilidades mecánicas hacen +35 % de daño (crece con el nivel). Al acabar, el calor te quita el 6 % de tus PV máximos.",
		"cost": [25, 0.35], "cd": 5, "target": "self",
		"ops": [{"op": "status", "status": "sobrecarga", "turns": 2, "mech_out": [35, 10, 3], "end_self_pct": 6.0}],
	},
	"MECH-02": {
		"name": "Latigazo de cable", "nature": "mechanical", "tier": 2, "role": "attack", "icon": "slash",
		"desc": "Daño ×0,85 (FUE) y 55 % base de inmovilizar 1 turno: no puede dar golpes físicos.",
		"cost": [11, 0.18], "cd": 2, "target": "enemy", "requires": ["materia"],
		"ops": [
			{"op": "damage", "mult": 0.85, "attr": "FUE", "defense": "RES", "kind": "fisico"},
			{"op": "status", "status": "inmovilizado", "turns": 1, "chance": 55.0, "attr": "FUE", "resist": "RES"},
		],
	},
	"MECH-03": {
		"name": "Servopatada", "nature": "mechanical", "tier": 2, "role": "attack", "icon": "swords",
		"desc": "Patada mecánica ×1,10 (FUE). El empuje necesita una casilla libre detrás: en este combate no la hay.",
		"cost": [13, 0.20], "cd": 2, "target": "enemy", "requires": ["materia"],
		# Empuje (P0 40 %): sin casillas en el combate, no hay destino válido.
		"ops": [{"op": "damage", "mult": 1.10, "attr": "FUE", "defense": "RES", "kind": "fisico"}],
	},
	"MECH-04": {
		"name": "Chispazo", "nature": "mechanical", "tier": 1, "role": "attack", "icon": "antenna",
		"desc": "Descarga ×0,65 (TEC contra RES) con un 15 % base de interrumpir su siguiente acción. Necesita algo que conduzca.",
		"cost": [7, 0.11], "cd": 1, "target": "enemy", "requires": ["electronica", "tejido"],
		"ops": [
			{"op": "damage", "mult": 0.65, "attr": "TEC", "defense": "RES", "kind": "electrico"},
			{"op": "status", "status": "interrumpido", "turns": 1, "chance": 15.0, "attr": "TEC", "resist": "RES"},
		],
	},
	"MECH-05": {
		"name": "Reset", "nature": "mechanical", "tier": 3, "role": "utility", "icon": "plus",
		"desc": "Reinicias tus sistemas: quitas 1 estado negativo de origen tecnológico (2 desde el nivel 31). No cura PV.",
		"cost": [22, 0.33], "cd": 4, "target": "self",
		"ops": [{"op": "cleanse", "count": 1, "count_from": {31: 2}, "origin": "tech"}],
	},
	"MECH-06": {
		"name": "Camuflaje óptico", "nature": "mechanical", "tier": 4, "role": "buff", "icon": "shield",
		"desc": "Durante 2 turnos esquivas +50 puntos (crece con el nivel; máximo 85 %) los ataques que dependen de la vista. Atacar lo rompe; no protege de ataques en área.",
		"cost": [32, 0.40], "cd": 5, "target": "self",
		"ops": [{"op": "status", "status": "camuflaje", "turns": 2, "eva": [50, 10, 3]}],
	},
	# === Intrínsecas iniciales (habilidades_1.md) =========================================
	"bio_impulso_organico": {
		"name": "Impulso orgánico", "nature": "biological", "role": "attack", "icon": "slash",
		"desc": "Golpe cuerpo a cuerpo con toda la fuerza muscular. Daño físico ×1,10 (FUE).",
		"cost": [7, 0.22], "cd": 0, "target": "enemy", "requires": ["materia"],
		"ops": [{"op": "damage", "mult": 1.10, "attr": "FUE", "defense": "RES", "kind": "fisico"}],
	},
	"bio_secrecion_caustica": {
		"name": "Secreción cáustica", "nature": "biological", "role": "attack", "icon": "flask",
		"desc": "Escupe una sustancia corrosiva. Daño ×0,82 (RES) y 60 % base de corrosión: RES −8 % durante 2 turnos.",
		"cost": [10, 0.27], "cd": 0, "target": "enemy", "requires": ["materia"],
		"ops": [
			{"op": "damage", "mult": 0.82, "attr": "RES", "defense": "RES", "kind": "corrosivo"},
			{"op": "status", "status": "corrosion", "turns": 2, "chance": 60.0, "attr": "RES", "resist": "RES",
				"stat_mult": {"RES": 0.92}},
		],
	},
	"mec_impacto_cinetico": {
		"name": "Impacto cinético", "nature": "mechanical", "role": "attack", "icon": "swords",
		"desc": "Acumula energía y la libera en un golpe. Daño físico ×1,18 (FUE).",
		"cost": [8, 0.25], "cd": 0, "target": "enemy", "requires": ["materia"],
		"ops": [{"op": "damage", "mult": 1.18, "attr": "FUE", "defense": "RES", "kind": "fisico"}],
	},
	"mec_proyeccion_fragmentos": {
		"name": "Proyección de fragmentos", "nature": "mechanical", "role": "attack", "icon": "slash",
		"desc": "Dispara metralla a distancia. Daño ×0,90 (TEC contra RES).",
		"cost": [9, 0.24], "cd": 0, "target": "enemy", "requires": ["materia"],
		"ops": [{"op": "damage", "mult": 0.90, "attr": "TEC", "defense": "RES", "kind": "metralla"}],
	},
	"dig_corrupcion_datos": {
		"name": "Corrupción de datos", "nature": "digital", "role": "attack", "icon": "antenna",
		"desc": "Inyecta datos corruptos en el objetivo. Daño informático ×1,03 (INT contra TEC).",
		"cost": [8, 0.24], "cd": 0, "target": "enemy",
		"ops": [{"op": "damage", "mult": 1.03, "attr": "INT", "defense": "TEC", "kind": "informatico"}],
	},
	"dig_depuracion": {
		"name": "Depuración", "nature": "digital", "role": "heal", "icon": "sparkle",
		"desc": "Restaura la integridad de sus propios sistemas. Restaura PV ×0,90 (INT).",
		"cost": [11, 0.30], "cd": 2, "target": "self", "caster_requires": ["datos", "electronica"],
		"ops": [{"op": "heal", "mult": 0.90, "attr": "INT"}],
	},
	"psi_choque_mental": {
		"name": "Choque mental", "nature": "psychic", "role": "attack", "icon": "sparkle",
		"desc": "Golpea directamente la mente del objetivo. Daño psíquico ×1,02 (VOL contra VOL). Necesita una conciencia.",
		"cost": [9, 0.25], "cd": 0, "target": "enemy", "requires": ["mente"],
		"ops": [{"op": "damage", "mult": 1.02, "attr": "VOL", "defense": "VOL", "kind": "psiquico"}],
	},
	"psi_disonancia": {
		"name": "Disonancia", "nature": "psychic", "role": "attack", "icon": "antenna",
		"desc": "Siembra ruido en sus pensamientos. Daño psíquico ×0,78 (VOL contra VOL) y 65 % base de bajar su precisión 12 puntos durante 2 turnos.",
		"cost": [12, 0.28], "cd": 2, "target": "enemy", "requires": ["mente"],
		"ops": [
			{"op": "damage", "mult": 0.78, "attr": "VOL", "defense": "VOL", "kind": "psiquico"},
			{"op": "status", "status": "disonancia", "turns": 2, "chance": 65.0, "attr": "VOL", "resist": "VOL", "acc": -12},
		],
	},
	"mis_manifestacion_arcana": {
		"name": "Manifestación arcana", "nature": "mystic", "role": "attack", "icon": "sparkle",
		"desc": "Una fuerza sobrenatural golpea el cuerpo del objetivo. Daño ×1,00 (VOL contra RES).",
		"cost": [11, 0.27], "cd": 0, "target": "enemy",
		# Modo material: la defensa queda fijada en RES.
		"ops": [{"op": "damage", "mult": 1.00, "attr": "VOL", "defense": "RES", "kind": "arcano"}],
	},
	"mis_marca_funesta": {
		"name": "Marca funesta", "nature": "mystic", "role": "attack", "icon": "alert",
		"desc": "Marca al objetivo con una maldición. Daño ×0,55 y 65 % base de maldición: ×0,30 por turno durante 3 turnos.",
		"cost": [14, 0.35], "cd": 2, "target": "enemy",
		# Actúa sobre la voluntad: defensa VOL tanto para el daño como para resistir el estado.
		"ops": [
			{"op": "damage", "mult": 0.55, "attr": "VOL", "defense": "VOL", "kind": "arcano"},
			{"op": "status", "status": "curse", "turns": 3, "chance": 65.0, "attr": "VOL", "resist": "VOL",
				"tick": {"mult": 0.30, "attr": "VOL", "defense": "VOL"}},
		],
	},
}

## Ataque básico (gratis, sin recarga): 0,75 × D con FUE contra RES (habilidades_1.md, 4).
const BASIC_ATTACK := {"mult": 0.75, "attr": "FUE", "defense": "RES", "kind": "fisico"}
## Tipos de daño que son golpes físicos (no se pueden dar inmovilizado ni proyectado).
const PHYSICAL_KINDS := ["fisico"]

## Etiquetas de compatibilidad (material, soporte, sentidos):
##   tejido (vivo y sangrable), materia (cuerpo físico), metal, electronica,
##   datos (proceso digital accesible), mente, vision, oido.
## Por defecto según la naturaleza; cada personaje puede declarar las suyas
## en `combat.tags` (CharacterDB).
const NATURE_TAGS := {
	"biological": ["tejido", "materia", "mente", "vision", "oido"],
	"mechanical": ["metal", "electronica", "materia", "vision", "oido"],
	"digital": ["datos", "electronica", "vision"],
	"psychic": ["mente", "vision", "oido"],
	"mystic": ["materia", "mente", "vision", "oido"],
}

## Estados. `debuff`: negativo (se puede limpiar). `origin`: "tech", "bio",
## "arcane" o "psy" (Reset solo quita los "tech"). Banderas:
##   skip_turn: pierde su acción · immune: no recibe daño · no_physical: sin
##   golpes físicos · psy_only: solo habilidades psíquicas · consume: se gasta
##   con la siguiente habilidad "any" (daño o cura) u "offensive".
## Valores que lleva cada aplicación (los pone la habilidad): dmg_out, dmg_in
## (% de reducción; negativo = recibe más), mech_out, acc, eva, status_res,
## stat_mult, stat_add, cost_mult, psy_mult, bonus, field_out/field_in,
## tick (daño por turno), regen (cura por turno), end_self_pct.
const STATUSES := {
	"curse": {"name": "Maldición", "debuff": true, "origin": "arcane",
		"desc": "Una fuerza arquetípica se aferra a tu voluntad. Al final de cada uno de tus turnos pierdes PV. Cuanta más VOL tengas, menos daño hace."},
	"corrosion": {"name": "Corrosión", "debuff": true, "origin": "bio",
		"desc": "Una sustancia cáustica debilita tu defensa: tu RES baja mientras dure."},
	"acido": {"name": "Ácido", "debuff": true, "origin": "bio",
		"desc": "Restos corrosivos siguen comiéndose la superficie: pierdes PV al final de cada turno."},
	"veneno": {"name": "Veneno", "debuff": true, "origin": "bio",
		"desc": "Toxinas en la sangre: pierdes PV al final de cada turno."},
	"sangrado": {"name": "Sangrado", "debuff": true, "origin": "bio",
		"desc": "Una herida abierta: pierdes PV al final de cada turno."},
	"aturdido": {"name": "Aturdido", "debuff": true, "origin": "bio", "skip_turn": true,
		"desc": "El golpe te ha dejado grogui: pierdes tu siguiente acción."},
	"interrumpido": {"name": "Interrumpido", "debuff": true, "origin": "tech", "skip_turn": true,
		"desc": "La descarga te bloquea: pierdes tu siguiente acción."},
	"desactivado": {"name": "Desactivado", "debuff": true, "origin": "tech", "skip_turn": true,
		"desc": "Tus sistemas están apagados: pierdes tus acciones mientras dure."},
	"inmovilizado": {"name": "Inmovilizado", "debuff": true, "origin": "tech", "no_physical": true,
		"desc": "Un cable te sujeta: no puedes dar golpes físicos, pero sí usar otras habilidades."},
	"deslumbrado": {"name": "Deslumbrado", "debuff": true, "origin": "tech",
		"desc": "Ves manchas de luz: tu precisión baja un 30 %."},
	"desorientado": {"name": "Desorientado", "debuff": true, "origin": "tech",
		"desc": "Un pitido te taladra la cabeza: tu precisión baja un 20 %."},
	"expuesto": {"name": "Datos expuestos", "debuff": true, "origin": "tech",
		"desc": "Te han leído por dentro: la siguiente habilidad ofensiva contra ti hace un 10 % más."},
	"disonancia": {"name": "Disonancia", "debuff": true, "origin": "psy",
		"desc": "Ruido en la cabeza: tu precisión baja 12 puntos."},
	"maldito": {"name": "Maldecido", "debuff": true, "origin": "arcane",
		"desc": "Una maldición te pesa: haces un 20 % menos de daño."},
	"proyeccion": {"name": "Proyección astral", "origin": "psy", "immune": true, "psy_only": true,
		"desc": "Estás fuera de tu cuerpo: no recibes daño y solo puedes usar habilidades psíquicas, al 60 %."},
	"excorporado": {"name": "Excorporado", "origin": "psy", "immune": true, "skip_turn": true,
		"desc": "Has salido de tu cuerpo: no recibes daño, pero pierdes tu siguiente acción."},
	"manifestar": {"name": "Manifestar", "origin": "psy", "consume": "any",
		"desc": "Tu próxima habilidad de daño o curación gana potencia."},
	"adivinacion": {"name": "Adivinación", "origin": "psy",
		"desc": "En tu siguiente turno harás una acción al azar."},
	"euforia": {"name": "Euforia", "origin": "psy",
		"desc": "+1 a todos los atributos."},
	"empatia": {"name": "Empatía", "origin": "psy",
		"desc": "Estás vinculado a tu compañero: el daño que recibe uno se reparte a medias entre los dos."},
	"pacto": {"name": "Pacto", "origin": "arcane",
		"desc": "Haces más daño y recibes un 15 % menos."},
	"dominio": {"name": "Dominio", "origin": "arcane",
		"desc": "Tu bando hace un 25 % más de daño y el contrario un 15 % menos."},
	"ascension": {"name": "Ascensión", "origin": "arcane",
		"desc": "Haces mucho más daño, pero recibes un 20 % más y tus habilidades cuestan un 20 % más de PM."},
	"sacrificio": {"name": "Sacrificio", "origin": "arcane", "consume": "offensive",
		"desc": "Tu próxima habilidad ofensiva hace mucho más daño."},
	"bendecido": {"name": "Bendición", "origin": "arcane",
		"desc": "Haces un 15 % más de daño y recibes un 10 % menos."},
	"regeneracion": {"name": "Regeneración", "origin": "bio",
		"desc": "Recuperas PV al final de cada turno."},
	"resiliencia": {"name": "Resiliencia", "origin": "bio",
		"desc": "Recibes un 20 % menos de daño y resistes mejor los estados."},
	"sobrecarga": {"name": "Sobrecarga", "origin": "tech",
		"desc": "Tus habilidades mecánicas hacen más daño. Al acabar, el calor te quita PV."},
	"camuflaje": {"name": "Camuflaje óptico", "origin": "tech",
		"desc": "Es difícil verte: esquivas los ataques que dependen de la vista. Atacar lo rompe."},
}

## Límites de acumulación (sección 2 del documento de tiers).
const MAX_DAMAGE_MULT := 2.5       ## potencia de daño combinada
const MAX_DAMAGE_REDUCTION := 70.0 ## % de reducción de daño recibido combinada
const MAX_EVASION := 85.0          ## % de esquiva efectiva
## La guardia cuenta como reducción de daño (dentro del límite combinado).
const GUARD_REDUCTION := 50.0

const NATURE_NAMES := {
	"biological": "Biológico", "mechanical": "Mecánico", "digital": "Digital",
	# «mystic» se muestra como ARQ (arquetípico): mitos, símbolos y leyendas encarnados.
	"psychic": "Psíquico", "mystic": "ARQ",
}

const NATURE_COLORS := {
	"biological": Color("c6f432"), "mechanical": Color("f5a623"), "digital": Color("27b4f5"),
	"psychic": Color("ff7ad9"), "mystic": Color("9b5cf0"),
}

const TARGET_NAMES := {
	"enemy": "1 rival", "enemies": "Área", "self": "Uno mismo", "ally": "Aliado",
	"allies": "Grupo", "link": "Los dos",
}

## Nombre y descripción de cada estado (para la interfaz).
static var STATUS_NAMES := _status_field("name")
static var STATUS_DESC := _status_field("desc")


static func _status_field(field: String) -> Dictionary:
	var out := {}
	for id: String in STATUSES:
		out[id] = STATUSES[id][field]
	return out


static func get_skill(id: String) -> Dictionary:
	return ALL.get(id, {})


static func display_name(id: String) -> String:
	return get_skill(id).get("name", id)


static func nature_color(nature: String) -> Color:
	return NATURE_COLORS.get(nature, UIStyle.WHITE)


static func status(id: String) -> Dictionary:
	return STATUSES.get(id, {})


## Etiquetas de compatibilidad de un personaje (las suyas o las de su naturaleza).
static func tags_for(combat: Dictionary, nature: String) -> Array:
	return combat.get("tags", NATURE_TAGS.get(nature, ["materia", "mente", "vision", "oido"]))


# --- Fórmulas (sección 2 de habilidades_tiers.md / 2.2 de habilidades_1.md) ----------------

## PV_MAX = 100 + 10L + 5·RES
static func pv_max(level: int, res: float) -> int:
	return 100 + 10 * level + roundi(5.0 * res)


## PM_MAX = 35 + 3L + 2·max(INT, VOL)
static func pm_max(level: int, int_: float, vol: float) -> int:
	return 35 + 3 * level + roundi(2.0 * maxf(int_, vol))


## Daño: B(L, A) × 100 / (100 + R), con B = 18 + 2L + 2,6A.
static func base_damage(level: int, attr: float, defense: float) -> float:
	return (18.0 + 2.0 * level + 2.6 * attr) * 100.0 / (100.0 + maxf(defense, 0.0))


## Curación: H(L, A) = 18 + 1,6L + 2,2A
static func base_restore(level: int, attr: float) -> float:
	return 18.0 + 1.6 * level + 2.2 * attr


## CostePM(L) = C0 + ceil(k × (L − 1)), calculado directamente desde el nivel.
static func cost(id: String, level: int) -> int:
	var c: Array = get_skill(id).get("cost", [0, 0.0])
	return int(c[0]) + ceili(float(c[1]) * (maxi(level, 1) - 1))


## P_estado = clamp(P0 + 0,35 × (A − R) − E, 5, 90), en %. Solo para objetivos compatibles.
static func status_chance(p0: float, attr: float, resist: float, extra_resist: float = 0.0) -> float:
	return clampf(p0 + 0.35 * (attr - resist) - extra_resist, 5.0, 90.0)


## Valor escalable: número fijo o [base, cada, paso] → base + floor((L − 1) / cada) × paso.
static func scaled(spec: Variant, level: int) -> float:
	if spec is Array:
		return float(spec[0]) + floori((maxi(level, 1) - 1) / float(spec[1])) * float(spec[2])
	return float(spec)


## `base`, o el valor de `from` ({nivel_mínimo: valor}) con el nivel mínimo más alto alcanzado.
static func by_level(base: int, from: Dictionary, level: int) -> int:
	var best := 0
	var out := base
	for min_level: int in from:
		if level >= min_level and min_level > best:
			best = min_level
			out = int(from[min_level])
	return out


## PM que recupera Meditación (y cualquier `recover_pm`): ceil(base + a·L + b·A).
static func pm_recovery(op: Dictionary, level: int, attr: float) -> int:
	return ceili(op.base + op.per_level * level + op.per_attr * attr)


## ¿Tiene `tags` alguna de las etiquetas de `required`? (Vacío = sin requisito.)
static func compatible(tags: Array, required: Array) -> bool:
	if required.is_empty():
		return true
	for t in required:
		if t in tags:
			return true
	return false


## ¿La habilidad hace daño? (Lo que cuenta como «ofensiva».)
static func is_offensive(id: String) -> bool:
	for op: Dictionary in get_skill(id).get("ops", []):
		if op.op == "damage":
			return true
	return false


## ¿Hace daño o cura? (Lo que potencia Manifestar.)
static func is_damage_or_heal(id: String) -> bool:
	for op: Dictionary in get_skill(id).get("ops", []):
		if op.op in ["damage", "heal"] or op.has("regen"):
			return true
	return false


## ¿Es un golpe físico? (No se puede inmovilizado.)
static func is_physical(id: String) -> bool:
	for op: Dictionary in get_skill(id).get("ops", []):
		if op.op == "damage" and op.kind in PHYSICAL_KINDS:
			return true
	return false


## ¿Puede usarla alguien con estas etiquetas y esta naturaleza?
static func usable_by(id: String, tags: Array, nature: String) -> bool:
	var skill := get_skill(id)
	var natures: Array = skill.get("caster_natures", [])
	return compatible(tags, skill.get("caster_requires", [])) and (natures.is_empty() or nature in natures)


## `n` habilidades distintas al azar de todo el catálogo, sin mirar la naturaleza
## (solo las que puede usar alguien con etiquetas `tags` y naturaleza `nature`, si se dan).
static func random_skills(n: int, tags: Array = [], nature: String = "") -> Array[String]:
	var ids: Array[String] = []
	for id: String in ALL:
		if tags.is_empty() or usable_by(id, tags, nature):
			ids.append(id)
	ids.shuffle()
	return ids.slice(0, mini(n, ids.size()))


## Redondeo al entero más cercano con mitades hacia arriba.
static func round_half_up(x: float) -> int:
	return floori(x + 0.5)
