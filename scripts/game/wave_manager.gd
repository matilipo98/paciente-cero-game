class_name WaveManager
extends Node
## Generación y progresión de oleadas. Los valores están en Balance.WAVES.

signal wave_cleared

var gm  # GameManager
var wave := 0
var current_cfg: Dictionary = Balance.WAVES[0]
var duration := 35.0
var time_left := 0.0
var running := false

var _humans_left := 0
var _spawn_interval := 1.0
var _spawn_timer := 0.0
var _police_times: Array[float] = []
var _elapsed := 0.0


func start_wave(n: int) -> void:
	wave = n
	current_cfg = Balance.get_wave(n)
	duration = float(current_cfg.duration)
	time_left = duration
	_elapsed = 0.0
	var total := int(current_cfg.humans)
	var initial := ceili(total * Balance.WAVE_INITIAL_FRACTION)
	var points := _spawn_candidates()
	for i in initial:
		gm.spawn_human(points[i % points.size()] + _jitter())
	_humans_left = total - initial
	var batches := maxi(1, ceili(_humans_left / 2.5))
	_spawn_interval = duration * Balance.WAVE_SPAWN_WINDOW / batches
	_spawn_timer = _spawn_interval * 0.6
	_police_times.clear()
	# La policía llega en patrullas (grupos) repartidas en la primera mitad de la oleada.
	var np := int(current_cfg.police)
	var squad := int(current_cfg.get("p_squad", 1))
	var groups := ceili(float(np) / squad)
	for i in np:
		var g := i / squad
		_police_times.append(duration * (0.06 + 0.5 * float(g) / maxf(1.0, groups)))
	running = true


func step(delta: float) -> void:
	if not running:
		return
	_elapsed += delta
	time_left -= delta
	if _humans_left > 0:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = _spawn_interval
			var batch := mini(2 + randi() % 2, _humans_left)
			var sp := pick_spawn()
			for i in batch:
				gm.spawn_human(sp + _jitter())
			_humans_left -= batch
	var squad_point := Vector2.INF
	while not _police_times.is_empty() and _elapsed >= _police_times[0]:
		_police_times.pop_front()
		if squad_point == Vector2.INF:
			squad_point = pick_spawn()
		gm.spawn_police(squad_point + _jitter() * 2.0)
	var all_spawned := _humans_left == 0 and _police_times.is_empty()
	if time_left <= 0.0 or (all_spawned and gm.humans.is_empty() and gm.police.is_empty()):
		running = false
		time_left = maxf(time_left, 0.0)
		wave_cleared.emit()


func progress() -> float:
	return clampf(time_left / duration, 0.0, 1.0)


## Puntos de aparición en los bordes, lejos del líder (nunca encima del jugador).
func _spawn_candidates() -> Array[Vector2]:
	var leader_pos: Vector2 = gm.leader.position if gm.leader != null else gm.map.player_start
	var far: Array[Vector2] = []
	for p in gm.map.spawn_points:
		if p.distance_to(leader_pos) > Balance.SPAWN_MIN_DIST_TO_LEADER:
			far.append(p)
	if far.is_empty():
		far = gm.map.spawn_points.duplicate()
	far.shuffle()
	return far


func pick_spawn() -> Vector2:
	return _spawn_candidates()[0]


func _jitter() -> Vector2:
	return Vector2(randf_range(-14, 14), randf_range(-14, 14))
