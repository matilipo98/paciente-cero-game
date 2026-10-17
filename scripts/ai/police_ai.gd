class_name PoliceAI
extends RefCounted
## IA policial: busca al zombi más cercano, mantiene distancia de tiro,
## dispara proyectiles pequeños y retrocede si la horda se le acerca.

static var _buf: Array = []


static func update(p: Unit, gm, delta: float) -> void:
	if p.state != Unit.State.ACTIVE:
		p.desired = Vector2.ZERO
		return
	var cfg: Dictionary = gm.waves.current_cfg
	var spd: float = Balance.POLICE_SPEED * float(cfg.get("p_speed", 1.0))
	if p.under_attack > 0.0:
		spd *= 0.45  # mientras lo muerden queda aturdido

	p.think_timer -= delta
	if p.think_timer <= 0.0:
		p.think_timer = randf_range(0.25, 0.4)
		p.target = _nearest_zombie(p, gm, 700.0)

	var t := p.target
	p.fire_cd -= delta
	if t == null or not is_instance_valid(t) or t.state != Unit.State.ACTIVE:
		p.aim_dir = Vector2.ZERO
		p.wander_timer -= delta
		if p.wander_timer <= 0.0 or p.position.distance_squared_to(p.wander_point) < 400.0:
			p.wander_point = gm.map.random_free_point()
			p.wander_timer = randf_range(2.0, 4.0)
		p.desired = (p.wander_point - p.position).normalized() * spd * 0.6
		return

	var to := t.position - p.position
	var d := to.length()
	var dir := to / maxf(d, 0.001)
	p.aim_dir = dir
	if d > Balance.POLICE_PREFERRED_DIST + 40.0:
		p.desired = dir * spd
	elif d < Balance.POLICE_PREFERRED_DIST - 70.0:
		var back: Vector2 = -dir + gm.map.bounds_push(p.position, 90.0) * 1.5
		p.desired = back.normalized() * spd * 0.95
	else:
		p.desired = dir.orthogonal() * p.avoid_side * spd * 0.35

	if d < Balance.POLICE_SHOOT_RANGE and p.fire_cd <= 0.0:
		p.fire_cd = Balance.POLICE_FIRE_INTERVAL * float(cfg.get("p_fire", 1.0)) * randf_range(0.85, 1.2)
		# En oleadas altas anticipan el movimiento del zombi (más puntería).
		var lead: float = cfg.get("p_aim", 0.0)
		var aim_pos := t.position + t.velocity * (d / Balance.BULLET_SPEED) * lead
		var shot_dir := (aim_pos - p.position).normalized()
		var spread := shot_dir.rotated(randf_range(-0.06, 0.06))
		gm.projectiles.fire(p.position + spread * (p.radius + 8.0), spread)
		gm.effects.muzzle(p.position + spread * (p.radius + 10.0))
		p.velocity -= spread * 60.0  # retroceso mínimo (AN-11)
		AudioManager.play("shoot", 0.1, -8.0)


static func _nearest_zombie(p: Unit, gm, radius: float) -> Unit:
	gm.zombie_grid.query(p.position, radius, _buf)
	var best: Unit = null
	var best_d := radius * radius
	for c in _buf:
		var z: Unit = c
		if z.state != Unit.State.ACTIVE:
			continue
		var d2 := p.position.distance_squared_to(z.position)
		if d2 < best_d:
			best_d = d2
			best = z
	return best
