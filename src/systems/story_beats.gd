class_name StoryBeats
extends RefCounted
## Sucesos de guion (ChapterDB.BEATS): momentos de la historia que saltan solos
## cuando se cumplen sus condiciones, en vez de en un sitio fijo del código.
## La pantalla pregunta en cada ocasión (`check`) y, si toca uno, lo reproduce
## (WorldScreen._run_beat). Cada suceso pasa una vez (flag `suceso:<id>`).
##
## Condiciones de un suceso (todas opcionales):
##   phase / before_phase  desde esa fase / antes de esa fase
##   min_day               desde ese día de la partida
##   on                    en qué ocasión se mira: "talk" (al hablar con
##                         alguien) o "plan_end" (al terminar un plan)
##   alone                 Ren y una sola persona en escena (ni uno más)
##   with                  esa persona tiene que ser una de estas (y amiga de Ren)

const DONE := "suceso:"


static func done(id: String) -> bool:
	return GameState.get_flag(DONE + id)


static func mark_done(id: String) -> void:
	GameState.set_flag(DONE + id)


## Suceso que toca ahora ("" si ninguno). `occasion`: "talk" | "plan_end";
## `npc`: con quién se está; `present`: quién hay en escena (sin Ren).
static func check(occasion: String, npc: String, present: Array) -> String:
	if GameState.story_step != "":
		return ""
	for id: String in ChapterDB.BEATS:
		if not done(id) and _matches(ChapterDB.BEATS[id], occasion, npc, present):
			return id
	return ""


static func _matches(b: Dictionary, occasion: String, npc: String, present: Array) -> bool:
	if b.has("on") and occasion not in b.on:
		return false
	if b.has("phase") and not GameState.phase_at_least(b.phase):
		return false
	if b.has("before_phase") and GameState.phase_at_least(b.before_phase):
		return false
	if b.has("min_day") and GameState.day_number() < int(b.min_day):
		return false
	if b.get("alone", false) and (present.size() != 1 or not present.has(npc)):
		return false
	if b.has("with") and (npc not in b.with or not Acquaintance.is_friend(npc)):
		return false
	return true
