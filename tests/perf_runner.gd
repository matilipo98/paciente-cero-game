extends Node
## Banco de rendimiento: horda de 100 zombis + civiles + policías, mide ms por frame.
## xvfb-run godot --path . --rendering-driver opengl3 res://tests/perf_runner.tscn

const GAME := preload("res://scenes/game/game.tscn")
var game: GameManager
var frames := 0
var t_last := 0
var samples: Array[float] = []
var proc_samples: Array[float] = []
var _base := 0.0


func _ready() -> void:
	game = GAME.instantiate()
	add_child(game)
	SaveManager.tutorial_done = true


func _process(_d: float) -> void:
	frames += 1
	if frames == 90:
		# Armar el escenario de estrés
		game.waves.time_left = 9999.0
		game.waves.duration = 9999.0
		game.waves._humans_left = 0
		game.waves._police_times.clear()
		game.spawn_bonus_allies(99)
		for i in 30:
			game.spawn_human(game.map.random_free_point())
		for i in 6:
			game.spawn_police(game.map.spawn_points[i])
	if frames > 90:
		var a := frames * 0.02
		game.player._touch_dir = Vector2(cos(a), sin(a))
		# mantener población de civiles
		if game.humans.size() < 25:
			game.spawn_human(game.map.spawn_points[randi() % game.map.spawn_points.size()])
		if game.police.size() < 4:
			game.spawn_police(game.map.spawn_points[randi() % game.map.spawn_points.size()])
	var now := Time.get_ticks_usec()
	if frames > 20 and frames <= 80:
		_base += (now - t_last) / 1000.0
	if frames == 81:
		print("[perf] mapa casi vacío: %.2fms/frame" % (_base / 60.0))
	if frames > 150 and frames <= 750:
		samples.append((now - t_last) / 1000.0)
		proc_samples.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0 + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	t_last = now
	if frames == 751:
		samples.sort()
		var avg := 0.0
		for s in samples: avg += s
		avg /= samples.size()
		var pavg := 0.0
		for s in proc_samples: pavg += s
		pavg /= proc_samples.size()
		print("[perf] zombies=%d humans=%d police=%d  frame avg=%.2fms p50=%.2fms p95=%.2fms  script(proc+phys)=%.2fms  fps=%.1f  sim=%s" % [
			game.zombies.size(), game.humans.size(), game.police.size(), avg, samples[samples.size() / 2],
			samples[int(samples.size() * 0.95)], pavg, Engine.get_frames_per_second(), str(game.perf)])
		get_tree().quit()
