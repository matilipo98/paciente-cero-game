class_name Projectiles
extends Node2D
## Proyectiles policiales (GFX-010) en un pool de arrays empaquetados.
## Chocan contra zombis (1 de daño) y se detienen en edificios, autos y árboles.
## Además lleva los proyectiles del tanque: vuelan en arco hacia un punto marcado en el
## suelo (aviso rojo) y explotan dañando a todos los zombis del radio.

const MAX := 120
const LIFE := 1.6

var gm  # GameManager
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _life := PackedFloat32Array()
var _dmg := PackedFloat32Array()
var _s_from := PackedVector2Array()
var _s_to := PackedVector2Array()
var _s_t := PackedFloat32Array()
var _buf: Array = []


func _ready() -> void:
	z_index = 15


func fire(from: Vector2, dir: Vector2, dmg: float = 1.0, life: float = LIFE, speed_mult: float = 1.0) -> void:
	if _pos.size() >= MAX:
		return
	_pos.append(from)
	_vel.append(dir * Balance.BULLET_SPEED * speed_mult)
	_life.append(life)
	_dmg.append(dmg)


## Cañonazo del tanque hacia `to` (llega en SHELL_FLIGHT segundos).
func fire_shell(from: Vector2, to: Vector2) -> void:
	_s_from.append(from)
	_s_to.append(to)
	_s_t.append(0.0)


func clear_all() -> void:
	_pos.clear(); _vel.clear(); _life.clear(); _dmg.clear()
	_s_from.clear(); _s_to.clear(); _s_t.clear()


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
					gm.damage_zombie(z, _dmg[i], p)
					dead = true
					break
		if dead:
			_remove(i)
		else:
			i += 1
	var k := 0
	while k < _s_t.size():
		_s_t[k] += delta
		if _s_t[k] >= Balance.SHELL_FLIGHT:
			_explode(_s_to[k])
			var last := _s_t.size() - 1
			_s_from[k] = _s_from[last]; _s_to[k] = _s_to[last]; _s_t[k] = _s_t[last]
			_s_from.resize(last); _s_to.resize(last); _s_t.resize(last)
		else:
			k += 1
	queue_redraw()


func _explode(p: Vector2) -> void:
	gm.effects.explosion(p, Balance.SHELL_BLAST)
	gm.shake(9.0)
	AudioManager.play("boom", 0.08, 0.0)
	gm.zombie_grid.query(p, Balance.SHELL_BLAST + 24.0, _buf)
	var hit: Array[Unit] = []
	for c in _buf:
		var z: Unit = c
		if z.state != Unit.State.ACTIVE:
			continue
		var rr := Balance.SHELL_BLAST + z.radius * 0.5
		if p.distance_squared_to(z.position) < rr * rr:
			hit.append(z)
	for z in hit:
		gm.damage_zombie(z, Balance.SHELL_DMG, z.position)


func _remove(i: int) -> void:
	var last := _pos.size() - 1
	_pos[i] = _pos[last]; _vel[i] = _vel[last]; _life[i] = _life[last]; _dmg[i] = _dmg[last]
	_pos.resize(last); _vel.resize(last); _life.resize(last); _dmg.resize(last)


func _draw() -> void:
	# Aviso en el suelo: círculo rojo que se va llenando hasta la explosión.
	for k in _s_t.size():
		var u := _s_t[k] / Balance.SHELL_FLIGHT
		var to := _s_to[k]
		draw_circle(to, Balance.SHELL_BLAST, Palette.with_alpha(Palette.DANGER, 0.10 + 0.12 * u))
		draw_circle(to, Balance.SHELL_BLAST * u, Palette.with_alpha(Palette.DANGER, 0.18))
		draw_arc(to, Balance.SHELL_BLAST, 0.0, TAU, 40, Palette.with_alpha(Palette.DANGER, 0.55 + 0.4 * u), 3.0, true)
		var g := _s_from[k].lerp(to, u)
		var h := sin(u * PI) * 90.0
		draw_circle(g, 7.0, Palette.SHADOW)
		draw_circle(g - Vector2(0, h), 8.5, Palette.INK)
		draw_circle(g - Vector2(0, h) + Vector2(-2, -2), 3.0, Palette.with_alpha(Palette.WHITE, 0.5))
	for i in _pos.size():
		var p := _pos[i]
		var back := -_vel[i].normalized()
		draw_line(p, p + back * 14.0, Palette.with_alpha(Palette.POLICE, 0.45), 4.0, true)
		draw_circle(p, Balance.BULLET_RADIUS + 1.0, Palette.WHITE)
		draw_circle(p, Balance.BULLET_RADIUS, Palette.POLICE_DARK)
