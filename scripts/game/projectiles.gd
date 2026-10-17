class_name Projectiles
extends Node2D
## Proyectiles policiales (GFX-010) en un pool de arrays empaquetados.
## Chocan contra zombis (1 de daño) y se detienen en edificios, autos y árboles.

const MAX := 120
const LIFE := 1.6

var gm  # GameManager
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _life := PackedFloat32Array()
var _buf: Array = []


func _ready() -> void:
	z_index = 15


func fire(from: Vector2, dir: Vector2) -> void:
	if _pos.size() >= MAX:
		return
	_pos.append(from)
	_vel.append(dir * Balance.BULLET_SPEED)
	_life.append(LIFE)


func clear_all() -> void:
	_pos.clear(); _vel.clear(); _life.clear()


func step(delta: float) -> void:
	var i := 0
	while i < _pos.size():
		_life[i] -= delta
		_pos[i] += _vel[i] * delta
		var p := _pos[i]
		var dead := _life[i] <= 0.0
		if not dead and gm.map.point_solid(p):
			dead = true
			gm.effects.poof(p, Palette.ASPHALT_LIGHT)
		if not dead:
			gm.zombie_grid.query(p, 24.0, _buf)
			for c in _buf:
				var z: Unit = c
				if z.state != Unit.State.ACTIVE:
					continue
				var rr := z.radius + Balance.BULLET_RADIUS
				if p.distance_squared_to(z.position) < rr * rr:
					gm.damage_zombie(z, float(gm.waves.current_cfg.get("p_dmg", 1.0)), p)
					dead = true
					break
		if dead:
			_remove(i)
		else:
			i += 1
	queue_redraw()


func _remove(i: int) -> void:
	var last := _pos.size() - 1
	_pos[i] = _pos[last]; _vel[i] = _vel[last]; _life[i] = _life[last]
	_pos.resize(last); _vel.resize(last); _life.resize(last)


func _draw() -> void:
	for i in _pos.size():
		var p := _pos[i]
		var back := -_vel[i].normalized()
		draw_line(p, p + back * 14.0, Palette.with_alpha(Palette.POLICE, 0.45), 4.0, true)
		draw_circle(p, Balance.BULLET_RADIUS + 1.0, Palette.WHITE)
		draw_circle(p, Balance.BULLET_RADIUS, Palette.POLICE_DARK)
