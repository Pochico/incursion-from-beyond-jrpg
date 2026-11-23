extends Node
## Prueba de paridad del editor de diálogos (lado Godot): evalúa los casos con
## el selector real (Story.candidates) y escribe el resultado en JSON.
##   godot --headless --path . res://src/tools/editor_dialogos/paridad.tscn -- casos.json godot.json
## Lo lanza tools/editor_dialogos/paridad.sh. Es una escena (no un script -s)
## para que los autoloads existan al compilar.
## Se usa el código real del juego para tramo, ánimo, dimensiones (Social sobre
## GameState), «hoy» y «veces» (eventos en EventLog), fases, indicadores y vistos.
## Solo los presentes se simulan (dependen de la ubicación).

class CaseState:
	var story: Node
	var present_ids: Array
	func seen(c: String) -> bool: return story.seen(c)
	func knows(w: String, e: String) -> bool: return story.knows(w, e)
	func flag(id: String) -> bool: return story.flag(id)
	func present(id: String) -> bool: return id == CharacterDB.PROTAGONIST or id in present_ids
	func phase_index() -> int: return story.phase_index()
	func tier(w: String) -> String: return story.tier(w)
	func mood(w: String) -> String: return story.mood(w)
	func today(w: String) -> int: return story.today(w)
	func times_today(w: String, m: String) -> int: return story.times_today(w, m)
	func value(w: String, d: String) -> float: return story.value(w, d)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var story: Node = Story
	var gs: Node = GameState
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var out := []
	for c: Dictionary in cases:
		var who: String = c.who
		gs.events = EventLog.new()
		gs.phase = c.phase
		gs.flags = {}
		for f in c.flags:
			gs.set_flag(f)
		for cue in c.seen:
			gs.set_flag(story.SEEN_PREFIX + cue)
		gs.moods[who] = {"id": c.mood, "intensity": 50}
		gs.relations[who] = {CharacterDB.PROTAGONIST: c.dims}
		for ev in c.knows:
			gs.events.record("suceso", "nadie", "", {}, [], ev)
			gs.events.tell(who, ev)
		# «veces»: eventos de la acción del momento; «hoy»: interacciones.
		var interactions := ["talk", "flirt", "fight"]
		var times := int(c.times) if c.action != "" else 0
		for i in times:
			gs.events.record(c.action, CharacterDB.PROTAGONIST, who)
		var counted := times if c.action in interactions else 0
		var other := "talk" if c.action != "talk" else "flirt"
		for i in int(c.today) - counted:
			gs.events.record(other, CharacterDB.PROTAGONIST, who)
		var st := CaseState.new()
		st.story = story
		st.present_ids = c.present
		var res := []
		for x: Dictionary in story.candidates(who, c.moment, c.context, st):
			res.append({"cue": x.rule.cue, "score": x.score, "best": x.best})
		res.sort_custom(func(p, q): return (p.cue + str(p.score)) < (q.cue + str(q.score)))
		out.append(res)
	var f := FileAccess.open(args[1], FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	get_tree().quit()
