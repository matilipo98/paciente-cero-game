class_name Levels
extends RefCounted
## Niveles del juego: cada uno es un mapa con su propia tabla de oleadas.
## Nivel 1: la ciudad (10 oleadas) · Nivel 2: la comisaría (15) · Nivel 3: el campo (20)
## Nivel 4: la ciudad en ruinas (25) · Nivel 5: el desierto (30).
## Cada nivel arranca con 1 zombi; superarlo desbloquea el siguiente.
## Para ajustar el balance, editar las tablas (mismas claves que Balance.WAVES).
## soldiers / s_*: soldados (niveles 3 y 5). s_tough, s_fire, s_aim, s_squad: como p_* pero para soldados.
## survivors / sv_*: supervivientes con escopeta. bikers / b_*: motos. tanks / t_*: tanques (jefes).
## Las tablas de los niveles 4 y 5 se generan con curvas (ver _gen_ruins y _gen_desert).

const NAMES := ["LA CIUDAD", "LA COMISARÍA", "EL CAMPO", "LAS RUINAS", "EL DESIERTO"]
const MAPS := ["city", "station", "field", "ruins", "desert"]
## Texto corto de enemigos para el selector de niveles.
const FOES := ["Civiles y policías", "Más policías, en patrullas", "Llega el ejército",
	"Supervivientes y motos", "Tanques cada 5 oleadas"]

static var _cache: Dictionary = {}

const WAVES_2: Array[Dictionary] = [
	{"humans": 13, "police": 0, "speed": 0.90, "fear": 0.85, "duration": 35.00, "p_tough": 1.00, "p_fire": 1.10, "p_aim": 0.00, "p_speed": 0.95, "p_squad": 1, "p_dmg": 1},
	{"humans": 14, "police": 1, "speed": 0.92, "fear": 0.88, "duration": 36.00, "p_tough": 1.09, "p_fire": 1.05, "p_aim": 0.04, "p_speed": 0.99, "p_squad": 1, "p_dmg": 1},
	{"humans": 16, "police": 1, "speed": 0.94, "fear": 0.90, "duration": 37.00, "p_tough": 1.26, "p_fire": 1.00, "p_aim": 0.10, "p_speed": 1.02, "p_squad": 2, "p_dmg": 1},
	{"humans": 18, "police": 2, "speed": 0.96, "fear": 0.92, "duration": 37.00, "p_tough": 1.48, "p_fire": 0.95, "p_aim": 0.16, "p_speed": 1.06, "p_squad": 2, "p_dmg": 1},
	{"humans": 19, "police": 2, "speed": 0.99, "fear": 0.95, "duration": 38.00, "p_tough": 1.73, "p_fire": 0.90, "p_aim": 0.22, "p_speed": 1.09, "p_squad": 2, "p_dmg": 1},
	{"humans": 20, "police": 3, "speed": 1.01, "fear": 0.97, "duration": 39.00, "p_tough": 2.02, "p_fire": 0.85, "p_aim": 0.29, "p_speed": 1.13, "p_squad": 2, "p_dmg": 2},
	{"humans": 22, "police": 4, "speed": 1.03, "fear": 1.00, "duration": 40.00, "p_tough": 2.35, "p_fire": 0.80, "p_aim": 0.36, "p_speed": 1.16, "p_squad": 3, "p_dmg": 2},
	{"humans": 24, "police": 6, "speed": 1.05, "fear": 1.02, "duration": 40.00, "p_tough": 2.70, "p_fire": 0.75, "p_aim": 0.44, "p_speed": 1.20, "p_squad": 3, "p_dmg": 2},
	{"humans": 25, "police": 7, "speed": 1.07, "fear": 1.05, "duration": 41.00, "p_tough": 3.07, "p_fire": 0.70, "p_aim": 0.51, "p_speed": 1.24, "p_squad": 3, "p_dmg": 2},
	{"humans": 26, "police": 8, "speed": 1.09, "fear": 1.07, "duration": 42.00, "p_tough": 3.47, "p_fire": 0.65, "p_aim": 0.59, "p_speed": 1.27, "p_squad": 4, "p_dmg": 2},
	{"humans": 28, "police": 10, "speed": 1.11, "fear": 1.10, "duration": 43.00, "p_tough": 3.90, "p_fire": 0.60, "p_aim": 0.67, "p_speed": 1.31, "p_squad": 4, "p_dmg": 2},
	{"humans": 30, "police": 12, "speed": 1.14, "fear": 1.12, "duration": 44.00, "p_tough": 4.34, "p_fire": 0.55, "p_aim": 0.75, "p_speed": 1.34, "p_squad": 4, "p_dmg": 2},
	{"humans": 31, "police": 14, "speed": 1.16, "fear": 1.15, "duration": 44.00, "p_tough": 4.81, "p_fire": 0.50, "p_aim": 0.83, "p_speed": 1.38, "p_squad": 4, "p_dmg": 2},
	{"humans": 32, "police": 16, "speed": 1.18, "fear": 1.18, "duration": 45.00, "p_tough": 5.30, "p_fire": 0.45, "p_aim": 0.91, "p_speed": 1.41, "p_squad": 5, "p_dmg": 2},
	{"humans": 34, "police": 18, "speed": 1.20, "fear": 1.20, "duration": 46.00, "p_tough": 5.80, "p_fire": 0.40, "p_aim": 1.00, "p_speed": 1.45, "p_squad": 5, "p_dmg": 2},
]

const WAVES_3: Array[Dictionary] = [
	{"humans": 12, "police": 0, "soldiers": 0, "speed": 0.95, "fear": 0.90, "duration": 36.00, "p_tough": 1.30, "p_fire": 0.90, "p_aim": 0.20, "p_speed": 1.05, "p_squad": 1, "p_dmg": 1, "s_tough": 1.00, "s_fire": 1.00, "s_aim": 0.30, "s_squad": 1},
	{"humans": 13, "police": 1, "soldiers": 0, "speed": 0.96, "fear": 0.92, "duration": 37.00, "p_tough": 1.42, "p_fire": 0.87, "p_aim": 0.24, "p_speed": 1.07, "p_squad": 1, "p_dmg": 1, "s_tough": 1.06, "s_fire": 0.97, "s_aim": 0.34, "s_squad": 1},
	{"humans": 15, "police": 1, "soldiers": 1, "speed": 0.98, "fear": 0.93, "duration": 37.00, "p_tough": 1.58, "p_fire": 0.85, "p_aim": 0.28, "p_speed": 1.09, "p_squad": 1, "p_dmg": 1, "s_tough": 1.13, "s_fire": 0.94, "s_aim": 0.37, "s_squad": 1},
	{"humans": 16, "police": 2, "soldiers": 1, "speed": 0.99, "fear": 0.95, "duration": 38.00, "p_tough": 1.76, "p_fire": 0.82, "p_aim": 0.33, "p_speed": 1.11, "p_squad": 1, "p_dmg": 1, "s_tough": 1.22, "s_fire": 0.91, "s_aim": 0.41, "s_squad": 1},
	{"humans": 17, "police": 2, "soldiers": 2, "speed": 1.01, "fear": 0.96, "duration": 39.00, "p_tough": 1.95, "p_fire": 0.80, "p_aim": 0.37, "p_speed": 1.13, "p_squad": 2, "p_dmg": 2, "s_tough": 1.31, "s_fire": 0.88, "s_aim": 0.45, "s_squad": 2},
	{"humans": 18, "police": 2, "soldiers": 3, "speed": 1.02, "fear": 0.98, "duration": 39.00, "p_tough": 2.15, "p_fire": 0.77, "p_aim": 0.41, "p_speed": 1.16, "p_squad": 2, "p_dmg": 2, "s_tough": 1.40, "s_fire": 0.86, "s_aim": 0.48, "s_squad": 2},
	{"humans": 20, "police": 3, "soldiers": 3, "speed": 1.04, "fear": 0.99, "duration": 40.00, "p_tough": 2.35, "p_fire": 0.75, "p_aim": 0.45, "p_speed": 1.18, "p_squad": 2, "p_dmg": 2, "s_tough": 1.50, "s_fire": 0.83, "s_aim": 0.52, "s_squad": 2},
	{"humans": 21, "police": 3, "soldiers": 4, "speed": 1.05, "fear": 1.01, "duration": 40.00, "p_tough": 2.57, "p_fire": 0.72, "p_aim": 0.49, "p_speed": 1.20, "p_squad": 2, "p_dmg": 2, "s_tough": 1.60, "s_fire": 0.80, "s_aim": 0.56, "s_squad": 2},
	{"humans": 22, "police": 4, "soldiers": 5, "speed": 1.06, "fear": 1.03, "duration": 41.00, "p_tough": 2.79, "p_fire": 0.70, "p_aim": 0.54, "p_speed": 1.22, "p_squad": 2, "p_dmg": 2, "s_tough": 1.71, "s_fire": 0.77, "s_aim": 0.59, "s_squad": 2},
	{"humans": 23, "police": 4, "soldiers": 6, "speed": 1.08, "fear": 1.04, "duration": 42.00, "p_tough": 3.01, "p_fire": 0.67, "p_aim": 0.58, "p_speed": 1.24, "p_squad": 2, "p_dmg": 2, "s_tough": 1.82, "s_fire": 0.74, "s_aim": 0.63, "s_squad": 2},
	{"humans": 25, "police": 5, "soldiers": 7, "speed": 1.09, "fear": 1.06, "duration": 42.00, "p_tough": 3.24, "p_fire": 0.65, "p_aim": 0.62, "p_speed": 1.26, "p_squad": 3, "p_dmg": 2, "s_tough": 1.93, "s_fire": 0.71, "s_aim": 0.67, "s_squad": 3},
	{"humans": 26, "police": 5, "soldiers": 8, "speed": 1.11, "fear": 1.07, "duration": 43.00, "p_tough": 3.48, "p_fire": 0.62, "p_aim": 0.66, "p_speed": 1.28, "p_squad": 3, "p_dmg": 2, "s_tough": 2.04, "s_fire": 0.68, "s_aim": 0.71, "s_squad": 3},
	{"humans": 27, "police": 6, "soldiers": 9, "speed": 1.12, "fear": 1.09, "duration": 44.00, "p_tough": 3.72, "p_fire": 0.60, "p_aim": 0.71, "p_speed": 1.30, "p_squad": 3, "p_dmg": 2, "s_tough": 2.15, "s_fire": 0.65, "s_aim": 0.74, "s_squad": 3},
	{"humans": 28, "police": 6, "soldiers": 10, "speed": 1.13, "fear": 1.11, "duration": 44.00, "p_tough": 3.96, "p_fire": 0.57, "p_aim": 0.75, "p_speed": 1.32, "p_squad": 3, "p_dmg": 2, "s_tough": 2.27, "s_fire": 0.62, "s_aim": 0.78, "s_squad": 3},
	{"humans": 30, "police": 7, "soldiers": 11, "speed": 1.15, "fear": 1.12, "duration": 45.00, "p_tough": 4.21, "p_fire": 0.55, "p_aim": 0.79, "p_speed": 1.34, "p_squad": 3, "p_dmg": 2, "s_tough": 2.39, "s_fire": 0.59, "s_aim": 0.82, "s_squad": 3},
	{"humans": 31, "police": 7, "soldiers": 12, "speed": 1.16, "fear": 1.14, "duration": 45.00, "p_tough": 4.46, "p_fire": 0.52, "p_aim": 0.83, "p_speed": 1.37, "p_squad": 3, "p_dmg": 2, "s_tough": 2.51, "s_fire": 0.57, "s_aim": 0.85, "s_squad": 3},
	{"humans": 32, "police": 8, "soldiers": 13, "speed": 1.18, "fear": 1.15, "duration": 46.00, "p_tough": 4.72, "p_fire": 0.50, "p_aim": 0.87, "p_speed": 1.39, "p_squad": 4, "p_dmg": 2, "s_tough": 2.63, "s_fire": 0.54, "s_aim": 0.89, "s_squad": 4},
	{"humans": 33, "police": 9, "soldiers": 14, "speed": 1.19, "fear": 1.17, "duration": 47.00, "p_tough": 4.98, "p_fire": 0.47, "p_aim": 0.92, "p_speed": 1.41, "p_squad": 4, "p_dmg": 2, "s_tough": 2.75, "s_fire": 0.51, "s_aim": 0.93, "s_squad": 4},
	{"humans": 35, "police": 9, "soldiers": 15, "speed": 1.21, "fear": 1.18, "duration": 47.00, "p_tough": 5.24, "p_fire": 0.45, "p_aim": 0.96, "p_speed": 1.43, "p_squad": 4, "p_dmg": 2, "s_tough": 2.87, "s_fire": 0.48, "s_aim": 0.96, "s_squad": 4},
	{"humans": 36, "police": 10, "soldiers": 16, "speed": 1.22, "fear": 1.20, "duration": 48.00, "p_tough": 5.50, "p_fire": 0.42, "p_aim": 1.00, "p_speed": 1.45, "p_squad": 4, "p_dmg": 2, "s_tough": 3.00, "s_fire": 0.45, "s_aim": 1.00, "s_squad": 4},
]


static func count() -> int:
	return MAPS.size()


static func waves(level: int) -> Array[Dictionary]:
	match level:
		2:
			return WAVES_2
		3:
			return WAVES_3
		4:
			if not _cache.has(4):
				_cache[4] = _gen_ruins()
			return _cache[4]
		5:
			if not _cache.has(5):
				_cache[5] = _gen_desert()
			return _cache[5]
		_:
			return Balance.WAVES


static func map_id(level: int) -> String:
	return MAPS[clampi(level, 1, count()) - 1]


static func level_name(level: int) -> String:
	return NAMES[clampi(level, 1, count()) - 1]


static func _lerp(a: float, b: float, t: float) -> float:
	return snappedf(lerpf(a, b, t), 0.01)


## Nivel 4 (25 oleadas): supervivientes con escopeta desde el arranque y motos desde la oleada 3.
static func _gen_ruins() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var n := 25
	for i in n:
		var w := i + 1
		var t := float(i) / (n - 1)
		var u := float(maxi(0, w - 2)) / (n - 2)
		var v := float(maxi(0, w - 4)) / (n - 4)
		out.append({
			"humans": roundi(lerpf(11, 36, t)), "speed": _lerp(0.95, 1.24, t), "fear": _lerp(0.9, 1.22, t),
			"duration": roundf(lerpf(36, 50, t)),
			"police": 0 if w < 3 else roundi(1 + 6 * t),
			"p_tough": _lerp(1.3, 5.0, pow(t, 1.1)), "p_fire": _lerp(0.9, 0.45, t), "p_aim": _lerp(0.2, 1.0, t),
			"p_speed": _lerp(1.05, 1.42, t), "p_squad": 1 + roundi(2 * t), "p_dmg": 1 if w < 6 else 2,
			"survivors": 0 if w < 2 else roundi(1 + 17 * pow(u, 1.35)), "sv_squad": 1 + roundi(4 * u),
			"sv_tough": _lerp(1.0, 3.2, pow(t, 1.1)), "sv_fire": _lerp(1.05, 0.48, t), "sv_speed": _lerp(0.95, 1.25, t),
			"sv_dmg": 1 if w < 10 else 2,
			"bikers": 0 if w < 4 else roundi(1 + 10 * pow(v, 1.3)), "b_squad": 1 + roundi(3 * v),
			"b_tough": _lerp(1.0, 2.6, t), "b_fire": _lerp(1.1, 0.5, t), "b_aim": _lerp(0.25, 0.95, t),
			"b_speed": _lerp(0.9, 1.15, t), "b_dmg": 1 if w < 12 else 2,
		})
	return out


## Nivel 5 (30 oleadas): soldados, supervivientes y motos; un tanque cada 5 oleadas
## (dos en la última). En las oleadas con tanque llegan menos enemigos a pie.
static func _gen_desert() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var n := 30
	for i in n:
		var w := i + 1
		var t := float(i) / (n - 1)
		var u := float(maxi(0, w - 2)) / (n - 2)
		var tanks := 0
		if w % 5 == 0:
			tanks = 2 if w == n else 1
		var k := 0.6 if tanks > 0 else 1.0
		out.append({
			"humans": roundi(lerpf(13, 40, t)), "speed": _lerp(1.0, 1.26, t), "fear": _lerp(0.92, 1.24, t),
			"duration": roundf(lerpf(38, 52, t)) + (6.0 if tanks > 0 else 0.0),
			"police": 0 if w < 3 else roundi((1 + 6 * t) * k),
			"p_tough": _lerp(1.5, 5.5, t), "p_fire": _lerp(0.85, 0.42, t), "p_aim": _lerp(0.3, 1.0, t),
			"p_speed": _lerp(1.1, 1.45, t), "p_squad": 1 + roundi(2 * t), "p_dmg": 1 if w < 8 else 2,
			"soldiers": 0 if w < 3 else roundi((1 + 15 * pow(u, 1.6)) * k), "s_squad": 1 + roundi(4 * u),
			"s_tough": _lerp(1.0, 3.2, t), "s_fire": _lerp(1.1, 0.45, t), "s_aim": _lerp(0.2, 1.0, t),
			"survivors": 0 if w < 4 else roundi((1 + 9 * t) * k), "sv_squad": 1 + roundi(3 * t),
			"sv_tough": _lerp(1.2, 3.2, t), "sv_fire": _lerp(1.0, 0.48, t), "sv_speed": _lerp(1.0, 1.25, t),
			"sv_dmg": 1 if w < 10 else 2,
			"bikers": 0 if w < 7 else roundi((1 + 8 * t) * k), "b_squad": 1 + roundi(3 * t),
			"b_tough": _lerp(1.2, 2.7, t), "b_fire": _lerp(1.0, 0.5, t), "b_aim": _lerp(0.3, 0.95, t),
			"b_speed": _lerp(0.95, 1.15, t), "b_dmg": 1 if w < 12 else 2,
			"tanks": tanks, "t_tough": _lerp(0.85, 2.2, t), "t_fire": _lerp(1.1, 0.6, t),
			"t_aim": _lerp(0.3, 0.9, t), "t_speed": _lerp(1.0, 1.3, t),
		})
	return out
