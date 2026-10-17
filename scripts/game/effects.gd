class_name Effects
extends Node2D
## Efectos visuales con pool propio (sin crear nodos por partícula):
## chispas de contagio, anillos, nubecitas, estrellas de golpe y puntajes flotantes.
## Todo se dibuja en un único _draw() para que 100+ contagios no tiren los FPS.

const MAX_PARTICLES := 700

var _p_pos := PackedVector2Array()
var _p_vel := PackedVector2Array()
var _p_life := PackedFloat32Array()
var _p_max := PackedFloat32Array()
var _p_size := PackedFloat32Array()
var _p_grow := PackedFloat32Array()
var _p_col := PackedColorArray()

## [pos, life, max_life, max_radius, color, width]
var _rings: Array = []
## [pos, life, max_life, color, size]
var _stars: Array = []
## [pos, text, life, max_life, color, size]
var _popups: Array = []

var _font: Font
## Capa de dibujo: 20 = por encima de los actores; 0 = a nivel del suelo (rastros).
@export var layer_z := 20


func _ready() -> void:
	_font = ThemeDB.fallback_font
	z_index = layer_z


func clear_all() -> void:
	_p_pos.clear(); _p_vel.clear(); _p_life.clear(); _p_max.clear()
	_p_size.clear(); _p_grow.clear(); _p_col.clear()
	_rings.clear(); _stars.clear(); _popups.clear()


func _add_particle(pos: Vector2, vel: Vector2, life: float, size: float, col: Color, grow: float = 0.0) -> void:
	if _p_pos.size() >= MAX_PARTICLES:
		return
	_p_pos.append(pos); _p_vel.append(vel); _p_life.append(life); _p_max.append(life)
	_p_size.append(size); _p_grow.append(grow); _p_col.append(col)


# --- API -----------------------------------------------------------------------

## Contagio: chispas menta radiales (GFX-074) + anillo que crece hasta 88 px (GFX-075).
func infection(pos: Vector2, intense: bool) -> void:
	var n := randi_range(5, 7) if not intense else randi_range(11, 14)
	for i in n:
		var a := randf() * TAU
		var spd := randf_range(70.0, 150.0) * (1.35 if intense else 1.0)
		var col := Palette.ZOMBIE_SKIN if randf() < 0.6 else Palette.ZOMBIE_SKIN_LIGHT
		if intense and randf() < 0.3:
			col = Palette.VIOLET
		_add_particle(pos, Vector2.RIGHT.rotated(a) * spd, randf_range(0.3, 0.45), randf_range(3.0, 5.5), col)
	_rings.append([pos, 0.25, 0.25, 44.0 if not intense else 56.0, Palette.ZOMBIE_SKIN, 4.0])
	# Mancha verde suave en el área de contagio (lámina: "contagio área verde")
	for i in 3:
		_add_particle(pos + Vector2(randf_range(-8, 8), randf_range(-8, 8)), Vector2.ZERO, 0.4, 9.0,
			Palette.with_alpha(Palette.ZOMBIE_SKIN, 0.35), 40.0)


## Rastro verde suave detrás del zombi controlado (lámina de referencia).
func trail(pos: Vector2) -> void:
	_add_particle(pos + Vector2(randf_range(-5, 5), randf_range(-3, 3)), Vector2.ZERO, 0.55,
		randf_range(3.0, 5.0), Palette.with_alpha(Palette.ZOMBIE_OUTLINE, 0.45), -4.0)


## Ráfaga de combo x5 (GFX-080): burbujas verde/lila.
func combo_burst(pos: Vector2) -> void:
	for i in 16:
		var a := randf() * TAU
		var col := Palette.ZOMBIE_SKIN if i % 2 == 0 else Palette.VIOLET
		_add_particle(pos + Vector2.RIGHT.rotated(a) * 10.0, Vector2.RIGHT.rotated(a) * randf_range(90, 170),
			0.5, randf_range(4, 7), Palette.with_alpha(col, 0.85), 6.0)
	_rings.append([pos, 0.35, 0.35, 70.0, Palette.VIOLET, 5.0])


## Nube suave al eliminar un zombi (GFX-078) o civil sobrante.
func poof(pos: Vector2, col: Color) -> void:
	for i in 7:
		var a := randf() * TAU
		_add_particle(pos + Vector2.RIGHT.rotated(a) * 6.0, Vector2.RIGHT.rotated(a) * randf_range(25, 60),
			0.35, randf_range(5, 8), Palette.with_alpha(col.lightened(0.2), 0.8), 14.0)


## Estrellita de impacto (GFX-077).
func hit_star(pos: Vector2) -> void:
	_stars.append([pos, 0.22, 0.22, Palette.GOLD, 12.0])


func muzzle(pos: Vector2) -> void:
	_add_particle(pos, Vector2.ZERO, 0.1, 6.0, Palette.with_alpha(Palette.POLICE, 0.9), 30.0)


## Puntaje flotante (GFX-050): sube 30 px y se desvanece en 0.6 s.
func popup(pos: Vector2, text: String, col: Color = Palette.WHITE, size: int = 24) -> void:
	if _popups.size() > 30:
		_popups.pop_front()
	_popups.append([pos + Vector2(randf_range(-6, 6), -18), text, 0.6, 0.6, col, size])


# --- Simulación -------------------------------------------------------------------

func _process(delta: float) -> void:
	var i := 0
	while i < _p_pos.size():
		_p_life[i] -= delta
		if _p_life[i] <= 0.0:
			var last := _p_pos.size() - 1
			_p_pos[i] = _p_pos[last]; _p_vel[i] = _p_vel[last]; _p_life[i] = _p_life[last]
			_p_max[i] = _p_max[last]; _p_size[i] = _p_size[last]; _p_grow[i] = _p_grow[last]
			_p_col[i] = _p_col[last]
			_p_pos.resize(last); _p_vel.resize(last); _p_life.resize(last); _p_max.resize(last)
			_p_size.resize(last); _p_grow.resize(last); _p_col.resize(last)
			continue
		_p_pos[i] += _p_vel[i] * delta
		_p_vel[i] *= maxf(0.0, 1.0 - 4.0 * delta)
		_p_size[i] += _p_grow[i] * delta
		i += 1
	_tick(_rings, 1, delta)
	_tick(_stars, 1, delta)
	_tick(_popups, 2, delta)
	for e in _popups:
		e[0] += Vector2(0, -50.0 * delta)
	queue_redraw()


func _tick(arr: Array, life_idx: int, delta: float) -> void:
	for k in range(arr.size() - 1, -1, -1):
		var e: Array = arr[k]
		e[life_idx] = float(e[life_idx]) - delta
		if float(e[life_idx]) <= 0.0:
			arr.remove_at(k)


func _draw() -> void:
	var dot: Texture2D = ActorAtlas.dot
	for i in _p_pos.size():
		var k := _p_life[i] / _p_max[i]
		var c := _p_col[i]
		c.a *= clampf(k * 1.6, 0.0, 1.0)
		var rr := _p_size[i] * (0.6 + 0.4 * k)
		if dot != null:
			draw_texture_rect(dot, Rect2(_p_pos[i] - Vector2(rr, rr), Vector2(rr, rr) * 2.0), false, c)
		else:
			draw_circle(_p_pos[i], rr, c)
	for e in _rings:
		var k2: float = 1.0 - float(e[1]) / float(e[2])
		var col: Color = e[4]
		col.a = (1.0 - k2) * 0.85
		draw_arc(e[0], 6.0 + k2 * float(e[3]), 0.0, TAU, 36, col, float(e[5]) * (1.0 - k2 * 0.6), true)
	for e in _stars:
		var k3: float = float(e[1]) / float(e[2])
		var p: Vector2 = e[0]
		var r: float = float(e[4]) * (1.3 - k3 * 0.5)
		var pts := PackedVector2Array()
		for j in 10:
			var rr := r if j % 2 == 0 else r * 0.45
			pts.append(p + Vector2.UP.rotated(j * TAU / 10.0) * rr)
		var sc: Color = Palette.GOLD if k3 > 0.5 else Palette.DANGER
		sc.a = clampf(k3 * 1.5, 0.0, 1.0)
		draw_colored_polygon(pts, sc)
	for e in _popups:
		var k4: float = float(e[2]) / float(e[3])
		var pc: Color = e[4]
		pc.a = clampf(k4 * 2.0, 0.0, 1.0)
		var sz: int = e[5]
		var txt: String = e[1]
		var w := 160.0
		var pos: Vector2 = e[0] - Vector2(w * 0.5, 0)
		draw_string_outline(_font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, w, sz, 6, Palette.with_alpha(Palette.INK, pc.a * 0.85))
		draw_string(_font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, w, sz, pc)
