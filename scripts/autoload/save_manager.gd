extends Node
## Guardado local (sin servidores): récords, estadísticas, mejoras elegidas y ajustes.

const PATH := "user://paciente_cero.cfg"

var best_score := 0
var best_wave := 0
var best_horde := 0
var total_infected := 0
var games_played := 0
var victories := 0
var sound_on := true
var vibration_on := true
var tutorial_done := false
var upgrade_counts: Dictionary = {}


func _ready() -> void:
	load_data()
	_apply_audio()


func load_data() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	best_score = int(cf.get_value("records", "best_score", 0))
	best_wave = int(cf.get_value("records", "best_wave", 0))
	best_horde = int(cf.get_value("records", "best_horde", 0))
	total_infected = int(cf.get_value("stats", "total_infected", 0))
	games_played = int(cf.get_value("stats", "games_played", 0))
	victories = int(cf.get_value("stats", "victories", 0))
	upgrade_counts = cf.get_value("stats", "upgrade_counts", {})
	sound_on = bool(cf.get_value("settings", "sound_on", true))
	vibration_on = bool(cf.get_value("settings", "vibration_on", true))
	tutorial_done = bool(cf.get_value("settings", "tutorial_done", false))


func save_data() -> void:
	var cf := ConfigFile.new()
	cf.set_value("records", "best_score", best_score)
	cf.set_value("records", "best_wave", best_wave)
	cf.set_value("records", "best_horde", best_horde)
	cf.set_value("stats", "total_infected", total_infected)
	cf.set_value("stats", "games_played", games_played)
	cf.set_value("stats", "victories", victories)
	cf.set_value("stats", "upgrade_counts", upgrade_counts)
	cf.set_value("settings", "sound_on", sound_on)
	cf.set_value("settings", "vibration_on", vibration_on)
	cf.set_value("settings", "tutorial_done", tutorial_done)
	cf.save(PATH)


## Registra una partida terminada. Devuelve true si hubo nuevo récord de puntaje.
func submit_run(score: int, wave: int, infected: int, victory: bool, horde: int = 0) -> bool:
	var record := score > best_score
	best_score = maxi(best_score, score)
	best_wave = maxi(best_wave, wave)
	best_horde = maxi(best_horde, horde)
	total_infected += infected
	games_played += 1
	if victory:
		victories += 1
	save_data()
	return record


func register_upgrade(id: String) -> void:
	upgrade_counts[id] = int(upgrade_counts.get(id, 0)) + 1
	save_data()


func set_tutorial_done() -> void:
	if not tutorial_done:
		tutorial_done = true
		save_data()


func set_sound(on: bool) -> void:
	sound_on = on
	_apply_audio()
	save_data()


func set_vibration(on: bool) -> void:
	vibration_on = on
	save_data()


func reset_records() -> void:
	best_score = 0
	best_wave = 0
	best_horde = 0
	total_infected = 0
	games_played = 0
	victories = 0
	upgrade_counts = {}
	tutorial_done = false
	save_data()


func vibrate(ms: int) -> void:
	if vibration_on and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


func _apply_audio() -> void:
	AudioServer.set_bus_mute(0, not sound_on)
