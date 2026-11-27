class_name Training
## Entrenar estadísticas (datos en TrainingDB). Devuelve resultados; la vista
## (WorldScreen._run_training) reproduce la escena y los avisos.
##
## Flags: `entreno_visto:<actividad>` (ya la descubrió) y
## `entreno_semana:<estadística>` = semana en la que se entrenó por última vez.

const SEEN := "entreno_visto:"
const WEEK := "entreno_semana:"


## Semana de la partida (0 la primera): el día 1 es lunes.
static func week() -> int:
	return (GameState.day_number() - 1) / 7


static func discovered(activity_id: String) -> bool:
	return GameState.get_flag(SEEN + activity_id)


static func trained_this_week(stat: String) -> bool:
	return int(GameState.get_flag(WEEK + stat, -1)) == week()


## Actividad que se puede hacer ahora en `location_id` ("" si ninguna).
static func available_at(location_id: String) -> String:
	if not GameState.phase_at_least(TrainingDB.FROM_PHASE) or GameState.story_step != "":
		return ""
	for id: String in TrainingDB.ACTIVITIES:
		var a: Dictionary = TrainingDB.ACTIVITIES[id]
		if a.target == location_id and GameState.slot_id() in a.slots:
			return id
	return ""


## Quién puede entrenar con Ren: amigos que suben de nivel (los del grupo).
static func can_partner(id: String) -> bool:
	return id != CharacterDB.PROTAGONIST and Acquaintance.is_friend(id) and id in GameState.levelled_ids()


## Hace la actividad. Devuelve {first: bool, gained: {id: puntos}, repeated: bool}.
## La primera vez no sube nada; si esa estadística ya se entrenó esta semana, tampoco.
static func perform(activity_id: String, partner: String = "") -> Dictionary:
	var a := TrainingDB.activity(activity_id)
	var out := {"first": not discovered(activity_id), "gained": {}, "repeated": false}
	if out.first:
		GameState.set_flag(SEEN + activity_id)
		return out
	if trained_this_week(a.stat):
		out.repeated = true
		return out
	GameState.set_flag(WEEK + a.stat, week())
	var who: Array[String] = [CharacterDB.PROTAGONIST]
	if partner != "":
		who.append(partner)
		Social.change(partner, CharacterDB.PROTAGONIST, {"afecto": TrainingDB.PARTNER_AFFECTION}, 1.0, "entreno")
	for id in who:
		var bonus: Dictionary = GameState.stat_bonus.get(id, {})
		bonus[a.stat] = int(bonus.get(a.stat, 0)) + TrainingDB.STAT_GAIN
		GameState.stat_bonus[id] = bonus
		out.gained[id] = TrainingDB.STAT_GAIN
	GameState.record("entreno", CharacterDB.PROTAGONIST, activity_id, {}, who)
	return out
