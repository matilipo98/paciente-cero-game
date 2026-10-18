class_name InfectionSystem
extends Node
## Mecánica central: contactos zombi ↔ humano (mordida automática breve y
## transformación) y zombi ↔ policía (ataque automático por contacto).

var gm  # GameManager
var _buf: Array = []
var _to_convert: Array[Unit] = []
var _defeated: Array[Unit] = []


func step(delta: float) -> void:
	_process_humans(delta)
	_process_police(delta)


func _process_humans(delta: float) -> void:
	var mult: float = gm.upgrades.bite_mult
	_to_convert.clear()
	for h: Unit in gm.humans:
		if h.state == Unit.State.BITTEN:
			h.bite_timer -= delta
			if h.bite_timer <= 0.0:
				_to_convert.append(h)
			continue
		if h.state != Unit.State.ACTIVE:
			continue
		gm.zombie_grid.query(h.position, 50.0 * mult, _buf)
		for c in _buf:
			var z: Unit = c
			if z.state != Unit.State.ACTIVE:
				continue
			var reach: float = (h.radius + z.radius + Balance.BITE_EXTRA) * mult
			if h.position.distance_squared_to(z.position) <= reach * reach:
				_start_bite(h, z)
				break
	for h in _to_convert:
		_transform(h)


## 1–2: entra en el radio de contagio y comienza una mordida muy breve.
func _start_bite(h: Unit, z: Unit) -> void:
	h.state = Unit.State.BITTEN
	h.bite_timer = Balance.BITE_TIME
	h.velocity *= 0.15
	h.fleeing = false
	var dir := (h.position - z.position).normalized()
	z.velocity += dir * 90.0  # pequeño impulso de "ñam"
	z.facing = dir
	AudioManager.play("bite", 0.08, -4.0)


## 3–6: cambio visual a zombi, partículas, suma a la horda (lo resuelve GameManager).
func _transform(h: Unit) -> void:
	gm.on_human_infected(h)


func _process_police(delta: float) -> void:
	var fury: float = gm.upgrades.fury_mult
	_defeated.clear()
	for p: Unit in gm.police:
		if p.state != Unit.State.ACTIVE:
			continue
		var tank := p.kind == ActorArt.Kind.TANK
		gm.zombie_grid.query(p.position, p.radius + 36.0, _buf)
		var attackers := 0
		for c in _buf:
			var z: Unit = c
			if z.state != Unit.State.ACTIVE:
				continue
			var reach: float = p.radius + z.radius + (12.0 if tank else 7.0)
			if p.position.distance_squared_to(z.position) <= reach * reach:
				attackers += 1
				z.facing = (p.position - z.position).normalized()
		if tank:
			# El tanque sólo cede si lo muerden varios a la vez.
			p.tank_attackers = attackers
			if attackers < Balance.TANK_MIN_ATTACKERS:
				if attackers > 0:
					p.under_attack = 0.1
				continue
			attackers = mini(attackers, Balance.TANK_MAX_ATTACKERS)
			p.hp -= delta * attackers * fury
			p.under_attack = 0.15
			if randf() < delta * 14.0:
				gm.effects.hit_star(p.position + Vector2(randf_range(-40, 40), randf_range(-40, 30)))
			if p.hp <= 0.0:
				_defeated.append(p)
			continue
		if attackers > 0:
			attackers = mini(attackers, Balance.POLICE_MAX_ATTACKERS)
			p.hp -= delta * attackers * fury
			p.under_attack = 0.15
			if randf() < delta * 7.0:
				gm.effects.hit_star(p.position + Vector2(randf_range(-12, 12), randf_range(-14, 6)))
			if p.hp <= 0.0:
				_defeated.append(p)
	for p in _defeated:
		gm.on_police_defeated(p)
