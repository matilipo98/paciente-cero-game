extends Node
## Prueba automática: un bot juega la partida completa (persigue al humano más
## cercano, elige mejoras al azar) y reporta métricas. Ejecutar con:
## godot --headless --fixed-fps 60 res://tests/bot_runner.tscn

const GAME := preload("res://scenes/game/game.tscn")

var game: GameManager
var frames := 0
var last_wave := 0
var upgrades_taken: Array[String] = []
var max_zombies := 0
var saw_police := false
var t0 := 0
var phys_usec := 0
var phys_frames := 0
var done := false
var _end_frames := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	game = GAME.instantiate()
	add_child(game)
	t0 = Time.get_ticks_msec()
	print("[bot] start")


func _physics_process(_delta: float) -> void:
	if done:
		return
	frames += 1
	var t := Time.get_ticks_usec()
	_drive()
	phys_usec += Time.get_ticks_usec() - t
	phys_frames += 1
	max_zombies = maxi(max_zombies, game.zombies.size())
	if game.police.size() > 0:
		saw_police = true
	if game.waves.wave != last_wave and game.state == GameManager.GState.PLAYING:
		last_wave = game.waves.wave
		var f: float = maxf(1, game.perf.frames)
		print("[perf] ai=%.2fms move=%.2fms infect=%.2fms (avg/frame previous wave)" % [game.perf.ai / f / 1000.0, game.perf.move / f / 1000.0, game.perf.infect / f / 1000.0])
		game.perf = {"ai": 0, "move": 0, "infect": 0, "frames": 0}
		print("[bot] wave %d start  zombies=%d humans=%d score=%d t=%.1fs  phys=%.2fms proc=%.2fms" % [last_wave, game.zombies.size(), game.humans.size(), game.score, frames / 60.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
	if game.state == GameManager.GState.UPGRADE and game.ui._overlay != null and not game.ui._choosing:
		var ids := ["speed", "contagion", "resistance", "horde", "fury", "instinct"]
		var id: String = ids[randi() % ids.size()]
		upgrades_taken.append(id)
		game.ui._choosing = true
		game.ui._close_overlay()
		game.on_upgrade_chosen(id)
	if game.state == GameManager.GState.GAME_OVER or game.state == GameManager.GState.VICTORY:
		_end_frames += 1
		if _end_frames > 120:
			_finish()
	if frames > 60 * 60 * 9:
		print("[bot] timeout")
		_finish()


func _drive() -> void:
	if OS.get_environment("BOT_MODE") == "idle":
		game.player._touch_dir = Vector2.ZERO
		return
	var l: Unit = game.leader
	if l == null:
		game.player._touch_dir = Vector2.ZERO
		return
	var best: Unit = null
	var bd := INF
	for h in game.humans:
		if h.state != Unit.State.ACTIVE:
			continue
		var d := l.position.distance_squared_to(h.position)
		if d < bd:
			bd = d
			best = h
	if best == null:
		for p in game.police:
			var d := l.position.distance_squared_to(p.position)
			if d < bd:
				bd = d
				best = p
	if best == null:
		game.player._touch_dir = Vector2.ZERO
	else:
		game.player._touch_dir = (best.position - l.position).normalized()


func _finish() -> void:
	done = true
	var real := (Time.get_ticks_msec() - t0) / 1000.0
	print("[bot] RESULT state=%s wave=%d score=%d infected=%d max_zombies=%d police_defeated=%d lost=%d saw_police=%s" % [
		GameManager.GState.keys()[game.state], game.waves.wave, game.score, game.infected_total, max_zombies, game.police_defeated, game.zombies_lost, saw_police])
	print("[bot] upgrades=%s" % [upgrades_taken])
	print("[bot] simulated=%.1fs real=%.1fs avg_bot_frame=%.3fms" % [frames / 60.0, real, phys_usec / 1000.0 / maxf(1, phys_frames)])
	if game.ui._overlay != null:
		print("[bot] results overlay shown: %s" % game.ui._overlay.get_child_count())
	print("[bot] best_score_saved=%d best_wave=%d" % [SaveManager.best_score, SaveManager.best_wave])
	get_tree().quit()
