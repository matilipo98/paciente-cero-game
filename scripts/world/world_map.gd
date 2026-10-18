class_name WorldMap
extends Node2D
## Mapas del juego en vista cenital, con colisiones simples (rectángulos y círculos)
## y una grilla para consultas rápidas.
##  · "city": la ciudad, dibujada con primitivas 2D (GFX-012 a GFX-036).
##  · "station" / "field" / "ruins" / "desert": comisaría, campo, ciudad en ruinas y desierto,
##    a partir de las ilustraciones del juego
##    (assets/maps/), con los obstáculos calibrados sobre cada imagen.

const CELL := 80.0
## Margen con el que cada obstáculo se registra en la grilla (≥ radio máximo de actor).
const INFLATE := 50.0

enum Shape { RECT, CIRCLE }

const V_STREET := Rect2(285, -700, 150, 2680)
const H_STREETS: Array[Rect2] = [Rect2(-600, 420, 1920, 140), Rect2(-600, 860, 1920, 140)]
## Área total que se pinta (cubre pantallas más altas o anchas que 9:16).
const DRAW_AREA := Rect2(-600, -700, 1920, 2680)

var bounds: Rect2 = Balance.PLAY_RECT
var obstacles: Array[Dictionary] = []
var spawn_points: Array[Vector2] = [
	Vector2(22, 505), Vector2(22, 905), Vector2(698, 470), Vector2(698, 950),
	Vector2(310, 144), Vector2(410, 144), Vector2(200, 144), Vector2(520, 144),
	Vector2(310, 1262), Vector2(410, 1262), Vector2(170, 1262), Vector2(550, 1262),
]
var player_start := Vector2(330, 780)

## Mapa a cargar. Vacío = el del nivel elegido (GameManager.selected_level).
@export var map_id := ""
var _image: Texture2D = null
var _image_rect := Rect2()
var _fill := Palette.SIDEWALK

## Optimización: el mapa estático se hornea en 2 texturas (mitad superior e inferior)
## a 1.5× de resolución y luego se dibuja con 2 rectángulos por frame.
const BAKE_RECT := Rect2(-200, -300, 1120, 1880)
const BAKE_SCALE := 1.5
const BAKE_TILES := 2
## true en la copia que se usa para hornear (evita hornear recursivamente).
var baking_copy := false
var _tiles: Array = []

var _grid: Dictionary = {}
var _empty: Array = []

# Decorado (sólo visual) generado una vez
var _buildings: Array[Dictionary] = []
var _cars: Array[Dictionary] = []
var _trees: Array[Dictionary] = []
var _benches: Array[Rect2] = []
var _planters: Array[Rect2] = []
var _bushes: Array[Vector2] = []
var _lamps: Array[Vector2] = []
var _hydrants: Array[Vector2] = []
var _bins: Array[Vector2] = []
var _cones: Array[Vector2] = []
var _barricades: Array[Rect2] = []


func _ready() -> void:
	if map_id == "":
		map_id = Levels.map_id(GameManager.selected_level)
	match map_id:
		"station":
			_layout_station()
		"field":
			_layout_field()
		"ruins":
			_layout_ruins()
		"desert":
			_layout_desert()
		_:
			_layout_city()
	_build_grid()
	queue_redraw()
	if not baking_copy and _image == null:
		_bake.call_deferred()


func _bake() -> void:
	if not Baker.can_bake():
		return
	var tiles: Array = []
	var th := BAKE_RECT.size.y / BAKE_TILES
	for i in BAKE_TILES:
		var wr := Rect2(BAKE_RECT.position + Vector2(0, i * th), Vector2(BAKE_RECT.size.x, th))
		var copy: WorldMap = (get_script() as GDScript).new()
		copy.baking_copy = true
		copy.map_id = map_id
		copy.scale = Vector2.ONE * BAKE_SCALE
		copy.position = -wr.position * BAKE_SCALE
		var tex: Texture2D = await Baker.bake_node(self, Vector2i(wr.size * BAKE_SCALE), copy)
		if tex == null:
			return
		tiles.append([wr, tex])
	_tiles = tiles
	queue_redraw()


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

func _layout_city() -> void:
	# Edificios en los extremos (azoteas: GFX-019 a GFX-022)
	_add_building(Rect2(-80, -600, 190, 990), Palette.BUILDING_CORAL, Palette.BUILDING_CORAL_LIGHT)
	_add_building(Rect2(610, -600, 190, 990), Palette.BUILDING_BLUE, Palette.BUILDING_BLUE_LIGHT)
	_add_building(Rect2(-80, 590, 190, 240), Palette.BUILDING_LILAC, Palette.BUILDING_LILAC_LIGHT)
	_add_building(Rect2(610, 590, 190, 240), Palette.BUILDING_CREAM, Palette.BUILDING_CREAM_LIGHT)
	_add_building(Rect2(-80, 1030, 190, 1000), Palette.BUILDING_BLUE, Palette.BUILDING_BLUE_LIGHT)
	_add_building(Rect2(610, 1030, 190, 1000), Palette.BUILDING_CORAL, Palette.BUILDING_CORAL_LIGHT)

	# Autos estacionados (GFX-027 a GFX-029: una sola forma, distintos colores)
	_add_car(Rect2(291, 170, 54, 100), Palette.CAR_PINK, true, false)
	_add_car(Rect2(291, 1080, 54, 100), Palette.CAR_YELLOW, true, false)
	_add_car(Rect2(375, 640, 54, 100), Palette.CAR_BLUE, true, true)
	_add_car(Rect2(120, 426, 100, 54), Palette.CAR_BLUE, false, true)
	_add_car(Rect2(480, 500, 100, 54), Palette.CAR_PINK, false, false)
	_add_car(Rect2(490, 866, 100, 54), Palette.CAR_YELLOW, false, true)
	_add_car(Rect2(140, 940, 100, 54), Palette.CAR_PINK, false, false)

	# Árboles (GFX-023)
	_add_tree(Vector2(195, 215), 28.0)
	_add_tree(Vector2(240, 345), 20.0)
	_add_tree(Vector2(520, 230), 28.0)
	_add_tree(Vector2(200, 705), 28.0)
	_add_tree(Vector2(525, 665), 26.0)
	_add_tree(Vector2(190, 1110), 28.0)
	_add_tree(Vector2(530, 1185), 26.0)

	# Bancos, jardineras, arbustos (GFX-024 a GFX-026)
	_add_rect_obstacle(Rect2(126, 270, 24, 62))
	_benches.append(Rect2(126, 270, 24, 62))
	_add_rect_obstacle(Rect2(560, 760, 24, 62))
	_benches.append(Rect2(560, 760, 24, 62))
	_add_rect_obstacle(Rect2(200, 1200, 62, 24))
	_benches.append(Rect2(200, 1200, 62, 24))
	_add_rect_obstacle(Rect2(560, 150, 26, 52))
	_planters.append(Rect2(560, 150, 26, 52))
	_add_rect_obstacle(Rect2(130, 612, 52, 26))
	_planters.append(Rect2(130, 612, 52, 26))
	for b in [Vector2(588, 392), Vector2(462, 1052), Vector2(140, 800)]:
		_bushes.append(b)
		_add_circle_obstacle(b, 17.0)

	# Mobiliario urbano pequeño (GFX-030 a GFX-034)
	for l in [Vector2(270, 402), Vector2(450, 402), Vector2(270, 578), Vector2(450, 578),
			Vector2(270, 842), Vector2(450, 842), Vector2(270, 1018), Vector2(450, 1018)]:
		_lamps.append(l)
		_add_circle_obstacle(l, 6.0)
	for h in [Vector2(130, 404), Vector2(592, 576)]:
		_hydrants.append(h)
		_add_circle_obstacle(h, 7.0)
	for b in [Vector2(266, 760), Vector2(456, 1240)]:
		_bins.append(b)
		_add_circle_obstacle(b, 11.0)
	_barricades.append(Rect2(470, 1118, 96, 22))
	_add_rect_obstacle(Rect2(470, 1118, 96, 22))
	for c in [Vector2(452, 1150), Vector2(584, 1104)]:
		_cones.append(c)
		_add_circle_obstacle(c, 8.0)


## Comisaría: imagen 900×1600 escalada a 720×1280 (factor 0.8).
func _layout_station() -> void:
	_image = load("res://assets/maps/station.jpg")
	_image_rect = Rect2(0, 0, 720, 1280)
	_fill = Color8(135, 150, 183)
	player_start = Vector2(360, 640)
	spawn_points = [
		Vector2(360, 150), Vector2(30, 180), Vector2(695, 185),
		Vector2(30, 600), Vector2(30, 820), Vector2(692, 560), Vector2(692, 900),
		Vector2(360, 1250), Vector2(230, 1150), Vector2(500, 1150),
	]
	# Árboles, canteros y veredas con plantas
	for c in [Vector3(22, 205, 38), Vector3(668, 262, 42), Vector3(35, 935, 40), Vector3(682, 935, 40),
			Vector3(40, 1195, 42), Vector3(660, 1195, 48)]:
		_add_circle_obstacle(Vector2(c.x, c.y), c.z)
	for r in [Rect2(0, 232, 128, 70), Rect2(605, 235, 115, 115),
			Rect2(0, 955, 132, 55), Rect2(588, 955, 132, 55),
			Rect2(50, 1072, 120, 45), Rect2(548, 1072, 122, 45),
			Rect2(95, 1225, 100, 55), Rect2(585, 1235, 60, 45)]:
		_add_rect_obstacle(r)
	# Patrulleros estacionados y edificio de la comisaría
	_add_rect_obstacle(Rect2(102, 408, 82, 140))
	_add_rect_obstacle(Rect2(540, 742, 90, 142))
	_add_rect_obstacle(Rect2(170, 1035, 380, 135))


## Campo: imagen 1024×1536 escalada para cubrir 720×1280 (factor 0.833, recorte lateral).
func _layout_field() -> void:
	_image = load("res://assets/maps/field.jpg")
	var sc := 1280.0 / 1536.0
	_image_rect = Rect2((720.0 - 1024.0 * sc) * 0.5, 0, 1024.0 * sc, 1280)
	_fill = Color8(214, 168, 128)
	player_start = Vector2(360, 640)
	spawn_points = [
		Vector2(480, 150), Vector2(250, 150), Vector2(25, 380), Vector2(25, 620),
		Vector2(695, 460), Vector2(695, 980), Vector2(330, 1255), Vector2(450, 1255),
		Vector2(25, 1120), Vector2(695, 740),
	]
	# Árboles, rocas y arbustos (círculos: x, y, radio)
	for c in [Vector3(35, 110, 50), Vector3(150, 190, 36), Vector3(105, 212, 28), Vector3(325, 118, 28),
			Vector3(680, 90, 55), Vector3(603, 240, 32), Vector3(690, 305, 42), Vector3(668, 345, 24),
			Vector3(440, 388, 40), Vector3(15, 500, 45), Vector3(42, 545, 32), Vector3(665, 620, 60),
			Vector3(80, 765, 18), Vector3(115, 735, 18), Vector3(150, 705, 18), Vector3(178, 680, 18),
			Vector3(68, 722, 26), Vector3(42, 800, 24), Vector3(165, 765, 15), Vector3(705, 880, 16),
			Vector3(515, 905, 42), Vector3(35, 930, 55), Vector3(90, 1025, 24), Vector3(485, 1115, 48),
			Vector3(412, 1150, 26), Vector3(185, 1215, 28), Vector3(690, 1215, 58), Vector3(648, 1252, 30),
			Vector3(540, 1220, 18)]:
		_add_circle_obstacle(Vector2(c.x, c.y), c.z)
	# Cajones de madera
	_add_rect_obstacle(Rect2(605, 268, 60, 80))
	_add_rect_obstacle(Rect2(700, 780, 20, 55))


## Ciudad en ruinas: imagen 1024×1536 escalada para cubrir 720×1280 (como el campo).
func _layout_ruins() -> void:
	_image = load("res://assets/maps/ruins.jpg")
	var sc := 1280.0 / 1536.0
	_image_rect = Rect2((720.0 - 1024.0 * sc) * 0.5, 0, 1024.0 * sc, 1280)
	_fill = Color8(150, 138, 128)
	player_start = Vector2(420, 730)
	spawn_points = [
		Vector2(230, 20), Vector2(450, 20), Vector2(630, 20), Vector2(20, 345), Vector2(20, 600),
		Vector2(20, 700), Vector2(700, 450), Vector2(700, 990), Vector2(420, 1260), Vector2(560, 1260),
	]
	# Paredes de casas derrumbadas, autos quemados, cajones, barreras y tambores
	for r in [Rect2(0, 30, 22, 110), Rect2(65, 100, 75, 58),
			Rect2(268, 0, 22, 130), Rect2(290, 62, 110, 20), Rect2(392, 0, 20, 200),
			Rect2(495, 5, 65, 60), Rect2(558, 125, 18, 110), Rect2(518, 165, 42, 70),
			Rect2(660, 205, 60, 165), Rect2(40, 235, 25, 75), Rect2(0, 240, 40, 20),
			Rect2(285, 370, 25, 130), Rect2(285, 455, 100, 45), Rect2(285, 370, 60, 20),
			Rect2(0, 405, 95, 22), Rect2(72, 405, 22, 95), Rect2(0, 470, 40, 90),
			Rect2(520, 405, 48, 65), Rect2(655, 505, 65, 30), Rect2(662, 590, 58, 60),
			Rect2(315, 605, 75, 75), Rect2(628, 700, 25, 160), Rect2(628, 700, 92, 25),
			Rect2(625, 915, 55, 40), Rect2(0, 780, 95, 22), Rect2(70, 785, 25, 180),
			Rect2(0, 925, 95, 50), Rect2(135, 820, 50, 48), Rect2(278, 930, 72, 45),
			Rect2(330, 950, 18, 70), Rect2(320, 1015, 30, 65), Rect2(15, 1052, 85, 70),
			Rect2(150, 1085, 170, 195), Rect2(485, 1030, 35, 90), Rect2(622, 1068, 78, 60),
			Rect2(645, 1140, 75, 140)]:
		_add_rect_obstacle(r)
	for c in [Vector3(425, 120, 14), Vector3(455, 450, 15), Vector3(120, 610, 9), Vector3(420, 690, 22),
			Vector3(470, 680, 22), Vector3(165, 1025, 15), Vector3(190, 1000, 15), Vector3(528, 1200, 10)]:
		_add_circle_obstacle(Vector2(c.x, c.y), c.z)


## Desierto: imagen 900×1600, misma proporción que la pantalla (escala 0.8).
func _layout_desert() -> void:
	_image = load("res://assets/maps/desert.jpg")
	_image_rect = Rect2(0, 0, 720, 1280)
	_fill = Color8(222, 166, 120)
	player_start = Vector2(360, 640)
	spawn_points = [
		Vector2(250, 20), Vector2(420, 20), Vector2(20, 600), Vector2(20, 800), Vector2(700, 350),
		Vector2(700, 600), Vector2(700, 820), Vector2(320, 1260), Vector2(470, 1260), Vector2(20, 300),
	]
	# Rocas (los cráteres se pueden cruzar)
	for c in [Vector3(65, 95, 55), Vector3(145, 110, 25), Vector3(115, 145, 18), Vector3(25, 175, 15),
			Vector3(650, 235, 38), Vector3(680, 180, 28), Vector3(610, 195, 16), Vector3(665, 70, 16),
			Vector3(100, 445, 32), Vector3(45, 478, 22), Vector3(65, 508, 14), Vector3(635, 475, 38),
			Vector3(590, 508, 18), Vector3(680, 730, 20), Vector3(75, 955, 58), Vector3(60, 1045, 25),
			Vector3(190, 880, 22), Vector3(665, 1090, 55), Vector3(680, 1155, 22), Vector3(560, 1195, 22),
			Vector3(215, 1185, 22), Vector3(20, 370, 16), Vector3(680, 925, 18), Vector3(630, 975, 16)]:
		_add_circle_obstacle(Vector2(c.x, c.y), c.z)


func _add_building(r: Rect2, col: Color, light: Color) -> void:
	_buildings.append({"rect": r, "col": col, "light": light})
	_add_rect_obstacle(r)


func _add_car(r: Rect2, col: Color, vertical: bool, flip: bool) -> void:
	_cars.append({"rect": r, "col": col, "v": vertical, "flip": flip})
	_add_rect_obstacle(r.grow(-2.0))


func _add_tree(c: Vector2, r: float) -> void:
	_trees.append({"c": c, "r": r})
	_add_circle_obstacle(c, r * 0.72)


func _add_rect_obstacle(r: Rect2) -> void:
	obstacles.append({"t": Shape.RECT, "rect": r})


func _add_circle_obstacle(c: Vector2, r: float) -> void:
	obstacles.append({"t": Shape.CIRCLE, "c": c, "r": r})


func _build_grid() -> void:
	_grid.clear()
	for i in obstacles.size():
		var ob: Dictionary = obstacles[i]
		var bb: Rect2
		if ob.t == Shape.RECT:
			bb = ob.rect
		else:
			var rr: float = ob.r
			bb = Rect2(ob.c - Vector2(rr, rr), Vector2(rr, rr) * 2.0)
		bb = bb.grow(INFLATE).intersection(DRAW_AREA)
		for x in range(floori(bb.position.x / CELL), floori(bb.end.x / CELL) + 1):
			for y in range(floori(bb.position.y / CELL), floori(bb.end.y / CELL) + 1):
				var key := Vector2i(x, y)
				if not _grid.has(key):
					_grid[key] = []
				_grid[key].append(i)


func _cell(p: Vector2) -> Array:
	return _grid.get(Vector2i(floori(p.x / CELL), floori(p.y / CELL)), _empty)


# ---------------------------------------------------------------------------
# Consultas de colisión
# ---------------------------------------------------------------------------

## Empuja un círculo fuera de obstáculos y lo mantiene dentro del área jugable.
func resolve(pos: Vector2, r: float) -> Vector2:
	for idx in _cell(pos):
		var ob: Dictionary = obstacles[idx]
		if ob.t == Shape.RECT:
			var rc: Rect2 = ob.rect
			var cx := clampf(pos.x, rc.position.x, rc.end.x)
			var cy := clampf(pos.y, rc.position.y, rc.end.y)
			var dx := pos.x - cx
			var dy := pos.y - cy
			var d2 := dx * dx + dy * dy
			if d2 < r * r:
				if d2 > 0.0001:
					var d := sqrt(d2)
					pos += Vector2(dx, dy) / d * (r - d)
				else:
					var left := pos.x - rc.position.x
					var right := rc.end.x - pos.x
					var top := pos.y - rc.position.y
					var bottom := rc.end.y - pos.y
					var m := minf(minf(left, right), minf(top, bottom))
					if m == left:
						pos.x = rc.position.x - r
					elif m == right:
						pos.x = rc.end.x + r
					elif m == top:
						pos.y = rc.position.y - r
					else:
						pos.y = rc.end.y + r
		else:
			var c: Vector2 = ob.c
			var rr: float = ob.r + r
			var dv := pos - c
			var d2c := dv.length_squared()
			if d2c < rr * rr:
				if d2c > 0.0001:
					pos = c + dv / sqrt(d2c) * rr
				else:
					pos = c + Vector2(rr, 0)
	pos.x = clampf(pos.x, bounds.position.x + r, bounds.end.x - r)
	pos.y = clampf(pos.y, bounds.position.y + r, bounds.end.y - r)
	return pos


## ¿Un círculo en `p` choca contra algo (incluye los bordes del área)?
func is_blocked(p: Vector2, r: float) -> bool:
	if p.x < bounds.position.x + r or p.x > bounds.end.x - r:
		return true
	if p.y < bounds.position.y + r or p.y > bounds.end.y - r:
		return true
	for idx in _cell(p):
		var ob: Dictionary = obstacles[idx]
		if ob.t == Shape.RECT:
			var rc: Rect2 = ob.rect
			var cx := clampf(p.x, rc.position.x, rc.end.x)
			var cy := clampf(p.y, rc.position.y, rc.end.y)
			if (p.x - cx) * (p.x - cx) + (p.y - cy) * (p.y - cy) < r * r:
				return true
		else:
			var rr: float = ob.r + r
			if p.distance_squared_to(ob.c) < rr * rr:
				return true
	return false


## Para proyectiles: ¿el punto está dentro de un obstáculo sólido?
func point_solid(p: Vector2) -> bool:
	if not bounds.grow(30.0).has_point(p):
		return true
	return is_blocked_no_bounds(p, 1.0)


func is_blocked_no_bounds(p: Vector2, r: float) -> bool:
	for idx in _cell(p):
		var ob: Dictionary = obstacles[idx]
		if ob.t == Shape.RECT:
			if (ob.rect as Rect2).grow(r).has_point(p):
				return true
		else:
			var rr: float = ob.r + r
			if p.distance_squared_to(ob.c) < rr * rr:
				return true
	return false


## Vector que empuja hacia adentro cuando un actor se acerca a los bordes.
func bounds_push(p: Vector2, margin: float) -> Vector2:
	var v := Vector2.ZERO
	var b := bounds
	if p.x < b.position.x + margin:
		v.x += 1.0 - (p.x - b.position.x) / margin
	elif p.x > b.end.x - margin:
		v.x -= 1.0 - (b.end.x - p.x) / margin
	if p.y < b.position.y + margin:
		v.y += 1.0 - (p.y - b.position.y) / margin
	elif p.y > b.end.y - margin:
		v.y -= 1.0 - (b.end.y - p.y) / margin
	return v


func random_free_point(r: float = 20.0) -> Vector2:
	var area := bounds.grow(-40.0)
	for i in 40:
		var p := Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
		if not is_blocked(p, r):
			return p
	return player_start


# ---------------------------------------------------------------------------
# Dibujo (se ejecuta una sola vez: el mapa es estático)
# ---------------------------------------------------------------------------

func _draw() -> void:
	if _image != null:
		draw_rect(DRAW_AREA, _fill)
		draw_texture_rect(_image, _image_rect, false)
		return
	if not _tiles.is_empty():
		# Fuera del área horneada (pantallas muy altas o anchas): vereda y calles lisas.
		draw_rect(DRAW_AREA, Palette.SIDEWALK)
		for r in _street_rects():
			draw_rect(r.grow(9.0), Palette.CURB)
			draw_rect(r, Palette.ASPHALT)
		for t in _tiles:
			draw_texture_rect(t[1], t[0], false)
		return
	# Vereda base con juntas finas (GFX-013)
	draw_rect(DRAW_AREA, Palette.SIDEWALK)
	var joint := Palette.SIDEWALK.darkened(0.035)
	var x := DRAW_AREA.position.x
	while x < DRAW_AREA.end.x:
		draw_line(Vector2(x, DRAW_AREA.position.y), Vector2(x, DRAW_AREA.end.y), joint, 1.0)
		x += 64.0
	var y := DRAW_AREA.position.y
	while y < DRAW_AREA.end.y:
		draw_line(Vector2(DRAW_AREA.position.x, y), Vector2(DRAW_AREA.end.x, y), joint, 1.0)
		y += 64.0

	# Cordones (GFX-014) y asfalto (GFX-012)
	for r in _street_rects():
		draw_rect(r.grow(9.0), Palette.CURB)
	for r in _street_rects():
		draw_rect(r, Palette.ASPHALT)

	_draw_lane_markings()
	_draw_crosswalks()

	for b in _bushes:
		_draw_bush(b)
	for p in _planters:
		_draw_planter(p)
	for b in _benches:
		_draw_bench(b)
	for c in _cars:
		_draw_car(c)
	for b in _barricades:
		_draw_barricade(b)
	for c in _cones:
		_draw_cone(c)
	for h in _hydrants:
		_draw_hydrant(h)
	for b in _bins:
		_draw_bin(b)
	for b in _buildings:
		_draw_building(b)
	for t in _trees:
		_draw_tree(t.c, t.r)
	for l in _lamps:
		_draw_lamp(l)


func _street_rects() -> Array[Rect2]:
	var arr: Array[Rect2] = [V_STREET]
	arr.append_array(H_STREETS)
	return arr


func _rr(rect: Rect2, col: Color, rad: float, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(rad))
	sb.anti_aliasing = true
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	sb.draw(get_canvas_item(), rect)


func _soft_shadow(rect: Rect2, rad: float, offset: Vector2 = Vector2(6, 8)) -> void:
	_rr(Rect2(rect.position + offset, rect.size), Color(Palette.INK, 0.1), rad)


func _in_intersection(p: Vector2) -> bool:
	if p.x > V_STREET.position.x - 10 and p.x < V_STREET.end.x + 10:
		for h in H_STREETS:
			if p.y > h.position.y - 60 and p.y < h.end.y + 60:
				return true
	return false


func _draw_lane_markings() -> void:
	var cx := V_STREET.get_center().x
	var yy := DRAW_AREA.position.y
	while yy < DRAW_AREA.end.y:
		var p := Vector2(cx, yy + 20)
		if not _in_intersection(p):
			_rr(Rect2(cx - 4, yy, 8, 40), Palette.LANE, 3)
		yy += 80.0
	for h in H_STREETS:
		var cy := h.get_center().y
		var xx := DRAW_AREA.position.x
		while xx < DRAW_AREA.end.x:
			if xx + 40 < V_STREET.position.x - 70 or xx > V_STREET.end.x + 70:
				_rr(Rect2(xx, cy - 4, 40, 8), Palette.LANE, 3)
			xx += 80.0


func _draw_crosswalks() -> void:
	var col := Palette.CROSSWALK
	for h in H_STREETS:
		# Cruces sobre la calle vertical (arriba y abajo del cruce)
		for yy in [h.position.y - 52.0, h.end.y + 10.0]:
			var xx := V_STREET.position.x + 8.0
			while xx < V_STREET.end.x - 12.0:
				_rr(Rect2(xx, yy, 13, 42), col, 3)
				xx += 24.0
		# Cruces sobre la calle horizontal (izquierda y derecha)
		for xx2 in [V_STREET.position.x - 52.0, V_STREET.end.x + 10.0]:
			var y2 := h.position.y + 8.0
			while y2 < h.end.y - 12.0:
				_rr(Rect2(xx2, y2, 42, 13), col, 3)
				y2 += 24.0


func _draw_building(b: Dictionary) -> void:
	var r: Rect2 = b.rect
	var col: Color = b.col
	var light: Color = b.light
	_soft_shadow(r, 16, Vector2(8, 10))
	_rr(r, col, 16, light, 7)
	# Detalles de azotea: 1–2 elementos grandes por tramo visible
	var vis := r.intersection(Rect2(0, -400, 720, 2100))
	if vis.size.x <= 0:
		return
	var cx := vis.get_center().x
	var yy := vis.position.y + 60.0
	var i := 0
	while yy < vis.end.y - 60.0:
		if i % 2 == 0:
			# Equipo de aire acondicionado
			var ac := Rect2(cx - 22, yy - 16, 44, 32)
			_rr(Rect2(ac.position + Vector2(3, 4), ac.size), Color(Palette.INK, 0.08), 6)
			_rr(ac, light, 6, col.darkened(0.08), 2)
			for k in 3:
				draw_line(Vector2(ac.position.x + 9, ac.position.y + 9 + k * 7), Vector2(ac.end.x - 9, ac.position.y + 9 + k * 7), col.darkened(0.12), 2.0, true)
		else:
			# Tanque de agua circular
			draw_circle(Vector2(cx + 3, yy + 4), 20, Color(Palette.INK, 0.08))
			draw_circle(Vector2(cx, yy), 20, light)
			draw_arc(Vector2(cx, yy), 20, 0, TAU, 32, col.darkened(0.1), 2.5, true)
			draw_circle(Vector2(cx, yy), 7, col.darkened(0.06))
		yy += 130.0
		i += 1


func _draw_tree(c: Vector2, r: float) -> void:
	draw_set_transform(c + Vector2(4, r * 0.5), 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, r * 1.02, Color(Palette.INK, 0.1))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(c, r, Palette.TREE_DARK)
	draw_arc(c, r, 0, TAU, 32, Palette.TREE_DARK.darkened(0.08), 1.5, true)
	draw_circle(c + Vector2(-r * 0.12, -r * 0.14), r * 0.8, Palette.TREE)
	draw_arc(c + Vector2(-r * 0.12, -r * 0.14), r * 0.8, 0, TAU, 32, Palette.TREE, 1.0, true)
	draw_circle(c + Vector2(-r * 0.34, -r * 0.36), r * 0.26, Palette.TREE.lightened(0.18))


func _draw_bush(p: Vector2) -> void:
	draw_circle(p + Vector2(3, 6), 18, Color(Palette.INK, 0.08))
	for o in [Vector2(-9, 3), Vector2(9, 3), Vector2(0, -7)]:
		draw_circle(p + o, 11, Palette.TREE_DARK)
	for o in [Vector2(-9, 2), Vector2(9, 2), Vector2(0, -8)]:
		draw_circle(p + o + Vector2(-1, -1), 8.5, Palette.TREE)


func _draw_planter(r: Rect2) -> void:
	_soft_shadow(r, 6, Vector2(3, 4))
	_rr(r, Palette.PLANTER, 6, Palette.PLANTER.darkened(0.12), 2)
	var c := r.get_center()
	var along := Vector2(1, 0) if r.size.x > r.size.y else Vector2(0, 1)
	for k in [-1, 0, 1]:
		draw_circle(c + along * k * 13.0, 8.0, Palette.TREE_DARK)
		draw_circle(c + along * k * 13.0 + Vector2(-1, -1), 5.5, Palette.TREE)


func _draw_bench(r: Rect2) -> void:
	_soft_shadow(r, 5, Vector2(3, 4))
	_rr(r, Palette.WOOD, 5, Palette.WOOD.darkened(0.15), 2)
	var horizontal := r.size.x > r.size.y
	for k in 2:
		if horizontal:
			var yy := r.position.y + r.size.y * (k + 1) / 3.0
			draw_line(Vector2(r.position.x + 4, yy), Vector2(r.end.x - 4, yy), Palette.WOOD.darkened(0.15), 1.5)
		else:
			var xx := r.position.x + r.size.x * (k + 1) / 3.0
			draw_line(Vector2(xx, r.position.y + 4), Vector2(xx, r.end.y - 4), Palette.WOOD.darkened(0.15), 1.5)


func _draw_car(c: Dictionary) -> void:
	var r: Rect2 = c.rect
	var col: Color = c.col
	var vertical: bool = c.v
	var flip: bool = c.flip
	var wheel := Palette.BIN
	# Ruedas mínimas
	var wl := Vector2(8, 16) if vertical else Vector2(16, 8)
	var wpos: Array[Vector2] = []
	if vertical:
		wpos = [Vector2(r.position.x - 3, r.position.y + 14), Vector2(r.end.x - 5, r.position.y + 14),
			Vector2(r.position.x - 3, r.end.y - 30), Vector2(r.end.x - 5, r.end.y - 30)]
	else:
		wpos = [Vector2(r.position.x + 14, r.position.y - 3), Vector2(r.position.x + 14, r.end.y - 5),
			Vector2(r.end.x - 30, r.position.y - 3), Vector2(r.end.x - 30, r.end.y - 5)]
	_soft_shadow(r, 14, Vector2(5, 7))
	for w in wpos:
		_rr(Rect2(w, wl), wheel, 3)
	_rr(r, col, 14, col.darkened(0.1), 2)
	# Techo, parabrisas y luneta
	var glass := Palette.ASPHALT_LIGHT
	if vertical:
		var front := r.position.y + 16 if not flip else r.end.y - 34
		var back := r.end.y - 26 if not flip else r.position.y + 10
		_rr(Rect2(r.position.x + 7, front, r.size.x - 14, 18), glass, 6)
		_rr(Rect2(r.position.x + 9, back, r.size.x - 18, 14), glass, 5)
		_rr(Rect2(r.position.x + 9, r.position.y + 36, r.size.x - 18, r.size.y - 64), col.lightened(0.22), 6)
		var hy := r.position.y + 5 if not flip else r.end.y - 9
		draw_circle(Vector2(r.position.x + 12, hy + 2), 3, Palette.CREAM)
		draw_circle(Vector2(r.end.x - 12, hy + 2), 3, Palette.CREAM)
	else:
		var front2 := r.end.x - 34 if not flip else r.position.x + 16
		var back2 := r.position.x + 10 if not flip else r.end.x - 26
		_rr(Rect2(front2, r.position.y + 7, 18, r.size.y - 14), glass, 6)
		_rr(Rect2(back2, r.position.y + 9, 14, r.size.y - 18), glass, 5)
		_rr(Rect2(r.position.x + 30, r.position.y + 9, r.size.x - 64, r.size.y - 18), col.lightened(0.22), 6)
		var hx := r.end.x - 7 if not flip else r.position.x + 5
		draw_circle(Vector2(hx, r.position.y + 12), 3, Palette.CREAM)
		draw_circle(Vector2(hx, r.end.y - 12), 3, Palette.CREAM)


func _draw_lamp(p: Vector2) -> void:
	draw_circle(p + Vector2(2, 3), 7, Color(Palette.INK, 0.12))
	draw_circle(p, 6, Palette.LAMP_POLE)
	draw_circle(p, 3.5, Palette.GOLD)


func _draw_hydrant(p: Vector2) -> void:
	draw_circle(p + Vector2(2, 3), 8, Color(Palette.INK, 0.1))
	draw_circle(p, 7.5, Palette.HYDRANT)
	draw_circle(p, 3.5, Palette.HYDRANT.darkened(0.15))
	draw_circle(p + Vector2(-8, 0), 2.5, Palette.HYDRANT)
	draw_circle(p + Vector2(8, 0), 2.5, Palette.HYDRANT)


func _draw_bin(p: Vector2) -> void:
	var r := Rect2(p - Vector2(12, 12), Vector2(24, 24))
	_soft_shadow(r, 6, Vector2(2, 3))
	_rr(r, Palette.BIN, 6)
	_rr(r.grow(-5), Palette.BIN.lightened(0.15), 4)


func _draw_cone(p: Vector2) -> void:
	draw_circle(p + Vector2(2, 3), 9, Color(Palette.INK, 0.1))
	draw_circle(p, 9, Palette.CONE)
	draw_arc(p, 5.5, 0, TAU, 20, Palette.CREAM, 2.5, true)
	draw_circle(p, 2.2, Palette.CONE.darkened(0.1))


func _draw_barricade(r: Rect2) -> void:
	_soft_shadow(r, 4, Vector2(3, 4))
	_rr(Rect2(r.position.x + 4, r.position.y - 2, 8, r.size.y + 4), Palette.INK_SOFT, 3)
	_rr(Rect2(r.end.x - 12, r.position.y - 2, 8, r.size.y + 4), Palette.INK_SOFT, 3)
	_rr(r.grow_individual(0, -4, 0, -4), Palette.CREAM, 4)
	var xx := r.position.x + 8
	while xx < r.end.x - 12:
		draw_colored_polygon(PackedVector2Array([
			Vector2(xx, r.end.y - 4), Vector2(xx + 10, r.position.y + 4),
			Vector2(xx + 20, r.position.y + 4), Vector2(xx + 10, r.end.y - 4)]), Palette.CONE)
		xx += 22
