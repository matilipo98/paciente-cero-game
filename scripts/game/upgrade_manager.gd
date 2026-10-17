class_name UpgradeManager
extends Node
## Mejoras acumulables por partida (se eligen 1 de 3 al terminar cada oleada).

const DEFS: Array[Dictionary] = [
	{"id": "speed", "title": "VELOCIDAD", "desc": "Tus zombis se mueven un 10% más rápido."},
	{"id": "contagion", "title": "CONTAGIO", "desc": "+15% de alcance de mordida."},
	{"id": "resistance", "title": "RESISTENCIA", "desc": "Cada zombi nuevo aguanta +1 golpe."},
	{"id": "horde", "title": "HORDA", "desc": "Sumá 2 zombis aliados ahora mismo."},
	{"id": "fury", "title": "FURIA", "desc": "Derrotan policías un 30% más rápido."},
	{"id": "instinct", "title": "INSTINTO", "desc": "Los aliados detectan humanos más lejos."},
]

var levels: Dictionary = {}
var speed_mult := 1.0
var bite_mult := 1.0
var extra_hp := 0
var fury_mult := 1.0
var detect_mult := 1.0


static func get_def(id: String) -> Dictionary:
	for d in DEFS:
		if d.id == id:
			return d
	return {}


func reset() -> void:
	levels.clear()
	for d in DEFS:
		levels[d.id] = 0
	_recalc()


func level(id: String) -> int:
	return int(levels.get(id, 0))


func roll_choices(n: int = 3) -> Array[Dictionary]:
	var pool := DEFS.duplicate()
	pool.shuffle()
	var out: Array[Dictionary] = []
	for i in mini(n, pool.size()):
		out.append(pool[i])
	return out


func apply(id: String, gm) -> void:
	levels[id] = level(id) + 1
	_recalc()
	if id == "horde":
		gm.spawn_bonus_allies(2)
	SaveManager.register_upgrade(id)


func _recalc() -> void:
	speed_mult = pow(1.10, level("speed"))
	bite_mult = 1.0 + 0.15 * level("contagion")
	extra_hp = level("resistance")
	fury_mult = 1.0 / pow(0.7, level("fury"))
	detect_mult = 1.0 + 0.3 * level("instinct")
