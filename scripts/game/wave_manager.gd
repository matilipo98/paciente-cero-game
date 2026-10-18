class_name WaveManager
extends Node
## Generación y progresión de oleadas. Las tablas están en Balance.WAVES (nivel 1) y Levels.
## Los enemigos armados llegan en grupos repartidos en la primera mitad de la oleada.

## [clave de cantidad, clave de tamaño de grupo, inicio (fracción de la oleada), función de GameManager]
const ARMED_SPAWNS := [
	["police", "p_squad", 0.06, "spawn_police"],
	["soldiers", "s_squad", 0.12, "spawn_soldier"],
	["survivors", "sv_squad", 0.08, "spawn_survivor"],
	["bikers", "b_squad", 0.16, "spawn_biker"],
	["tanks", "", 0.14, "spawn_tank"],
]

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
## Llegadas pendientes ordenadas por tiempo: [segundo, función, grupo]
var _arrivals: Array = []
var _elapsed := 0.0


func start_wave(n: int) -> void:
	wave = n
	var table := Levels.waves(gm.level)
	current_cfg = table[clampi(n - 1, 0, table.size() - 1)]
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
	_arrivals.clear()
	for spec in ARMED_SPAWNS:
		var count := int(current_cfg.get(spec[0], 0))
		if count <= 0:
			continue
		var squad := int(current_cfg.get(spec[1], 1)) if spec[1] != "" else 1
		var groups := ceili(float(count) / squad)
		for i in count:
			var g := i / squad
			var start: float = spec[2]
			_arrivals.append([duration * (start + 0.5 * float(g) / maxf(1.0, groups)), spec[3], "%s%d" % [spec[3], g]])
	_arrivals.sort_custom(func(a, b): return a[0] < b[0])
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
	# Cada grupo aparece junto en un mismo punto del borde.
	var group_points := {}
	while not _arrivals.is_empty() and _elapsed >= _arrivals[0][0]:
		var a: Array = _arrivals.pop_front()
		if not group_points.has(a[2]):
			group_points[a[2]] = pick_spawn()
		gm.call(a[1], group_points[a[2]] + _jitter() * 2.0)
	var all_spawned := _humans_left == 0 and _arrivals.is_empty()
	if time_left <= 0.0 or (all_spawned and gm.humans.is_empty() and gm.police.is_empty()):
		running = false
		time_left = maxf(time_left, 0.0)
		wave_cleared.emit()


func total_waves() -> int:
	return Levels.waves(gm.level).size()


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
