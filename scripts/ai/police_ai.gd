class_name PoliceAI
extends RefCounted
## IA de enemigos armados (policía y soldado): busca al zombi más cercano, mantiene
## distancia de tiro, dispara y retrocede si la horda se le acerca.
## El soldado (nivel 3) es más lento y resistente, tira desde más lejos y dispara ráfagas.
## El superviviente (nivel 4) se acerca más y dispara un abanico de perdigones.
## La moto (nivel 4) da vueltas alrededor de la horda y dispara sin frenar.
## El tanque (nivel 5) avanza lento, gira la torreta y tira cañonazos con aviso en el suelo.

static var _buf: Array = []


static func update(p: Unit, gm, delta: float) -> void:
	if p.state != Unit.State.ACTIVE:
		p.desired = Vector2.ZERO
		return
	var cfg: Dictionary = gm.waves.current_cfg
	if p.kind == ActorArt.Kind.BIKER:
		_update_biker(p, gm, cfg, delta)
		return
	if p.kind == ActorArt.Kind.TANK:
		_update_tank(p, gm, cfg, delta)
		return
	var soldier := p.kind == ActorArt.Kind.SOLDIER
	var survivor := p.kind == ActorArt.Kind.SURVIVOR
	var spd: float
	var pref: float
	var shoot_range: float
	if soldier:
		spd = Balance.SOLDIER_SPEED * float(cfg.get("p_speed", 1.0))
		pref = Balance.SOLDIER_PREFERRED_DIST
		shoot_range = Balance.SOLDIER_SHOOT_RANGE
	elif survivor:
		spd = Balance.SURVIVOR_SPEED * float(cfg.get("sv_speed", 1.0))
		pref = Balance.SURVIVOR_PREFERRED_DIST
		shoot_range = Balance.SURVIVOR_SHOOT_RANGE
	else:
		spd = Balance.POLICE_SPEED * float(cfg.get("p_speed", 1.0))
		pref = Balance.POLICE_PREFERRED_DIST
		shoot_range = Balance.POLICE_SHOOT_RANGE
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
		p.burst_left = 0
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
	if d > pref + 40.0:
		p.desired = dir * spd
	elif d < pref - 70.0:
		var back: Vector2 = -dir + gm.map.bounds_push(p.position, 90.0) * 1.5
		p.desired = back.normalized() * spd * 0.95
	else:
		p.desired = dir.orthogonal() * p.avoid_side * spd * 0.35

	if soldier:
		_soldier_fire(p, t, d, cfg, gm, delta, shoot_range)
	elif survivor:
		if d < shoot_range and p.fire_cd <= 0.0:
			p.fire_cd = Balance.SURVIVOR_FIRE_INTERVAL * float(cfg.get("sv_fire", 1.0)) * randf_range(0.85, 1.2)
			_shotgun(p, dir, float(cfg.get("sv_dmg", 1.0)), gm)
	elif d < shoot_range and p.fire_cd <= 0.0:
		p.fire_cd = Balance.POLICE_FIRE_INTERVAL * float(cfg.get("p_fire", 1.0)) * randf_range(0.85, 1.2)
		_shoot(p, t, d, float(cfg.get("p_aim", 0.0)), float(cfg.get("p_dmg", 1.0)), gm)


## Ráfagas de SOLDIER_BURST tiros; la ráfaga en curso termina aunque el blanco se aleje.
static func _soldier_fire(p: Unit, t: Unit, d: float, cfg: Dictionary, gm, delta: float, shoot_range: float) -> void:
	if p.burst_left > 0:
		p.burst_cd -= delta
		if p.burst_cd <= 0.0:
			p.burst_left -= 1
			p.burst_cd = Balance.SOLDIER_BURST_GAP
			_shoot(p, t, d, float(cfg.get("s_aim", 0.5)), Balance.SOLDIER_DMG, gm)
		return
	if d < shoot_range and p.fire_cd <= 0.0:
		p.fire_cd = Balance.SOLDIER_FIRE_INTERVAL * float(cfg.get("s_fire", 1.0)) * randf_range(0.85, 1.2)
		p.burst_left = Balance.SOLDIER_BURST
		p.burst_cd = 0.0


static func _shoot(p: Unit, t: Unit, d: float, lead: float, dmg: float, gm) -> void:
	# En oleadas altas anticipan el movimiento del zombi (más puntería).
	var aim_pos := t.position + t.velocity * (d / Balance.BULLET_SPEED) * lead
	var shot_dir := (aim_pos - p.position).normalized()
	var spread := shot_dir.rotated(randf_range(-0.06, 0.06))
	gm.projectiles.fire(p.position + spread * (p.radius + 8.0), spread, dmg)
	gm.effects.muzzle(p.position + spread * (p.radius + 10.0))
	p.velocity -= spread * 60.0  # retroceso mínimo (AN-11)
	AudioManager.play("shoot", 0.1, -8.0)


## Abanico de perdigones de corto alcance (daño sv_dmg cada uno).
static func _shotgun(p: Unit, dir: Vector2, dmg: float, gm) -> void:
	var n := Balance.SURVIVOR_PELLETS
	for i in n:
		var a := lerpf(-Balance.SURVIVOR_SPREAD, Balance.SURVIVOR_SPREAD, float(i) / (n - 1)) + randf_range(-0.05, 0.05)
		var d2 := dir.rotated(a)
		gm.projectiles.fire(p.position + d2 * (p.radius + 14.0), d2, dmg, Balance.PELLET_LIFE * randf_range(0.9, 1.1), randf_range(1.0, 1.15))
	gm.effects.blast_flash(p.position + dir * (p.radius + 16.0), 8.0)
	p.velocity -= dir * 110.0
	AudioManager.play("shotgun", 0.1, -5.0)


## Moto: orbita al zombi más cercano a BIKER_ORBIT de distancia, siempre en movimiento.
static func _update_biker(p: Unit, gm, cfg: Dictionary, delta: float) -> void:
	var spd := Balance.BIKER_SPEED * float(cfg.get("b_speed", 1.0))
	if p.under_attack > 0.0:
		spd *= 0.4
	p.aim_dir = Vector2.ZERO  # la moto mira hacia donde va
	p.think_timer -= delta
	if p.think_timer <= 0.0:
		p.think_timer = randf_range(0.3, 0.5)
		p.target = _nearest_zombie(p, gm, 900.0)
	# Si queda trabada contra algo, cambia el sentido de giro.
	if p.velocity.length_squared() < 50.0 * 50.0:
		p.wander_timer += delta
		if p.wander_timer > 0.5:
			p.wander_timer = 0.0
			p.avoid_side = -p.avoid_side
	else:
		p.wander_timer = 0.0
	var t := p.target
	p.fire_cd -= delta
	var push: Vector2 = gm.map.bounds_push(p.position, 110.0) * 1.6
	if t == null or not is_instance_valid(t) or t.state != Unit.State.ACTIVE:
		var c: Vector2 = Balance.PLAY_RECT.get_center()
		p.desired = ((c - p.position).normalized().orthogonal() * p.avoid_side + push).normalized() * spd * 0.7
		return
	var to := t.position - p.position
	var d := to.length()
	var dir := to / maxf(d, 0.001)
	var radial := clampf((d - Balance.BIKER_ORBIT) / Balance.BIKER_ORBIT, -1.0, 1.0)
	var want := dir.orthogonal() * p.avoid_side + dir * radial * 1.4 + push
	p.desired = want.normalized() * spd
	if d < Balance.BIKER_SHOOT_RANGE and p.fire_cd <= 0.0:
		p.fire_cd = Balance.BIKER_FIRE_INTERVAL * float(cfg.get("b_fire", 1.0)) * randf_range(0.8, 1.2)
		_shoot(p, t, d, float(cfg.get("b_aim", 0.5)), float(cfg.get("b_dmg", 1.0)), gm)
	if randf() < delta * 0.8:
		AudioManager.play("engine", 0.15, -14.0)


## Tanque: se mantiene a media distancia de la horda, gira la torreta y dispara cañonazos.
## No puede apuntar a zombis pegados (TANK_MIN_RANGE): la forma de ganarle es rodearlo.
static func _update_tank(p: Unit, gm, cfg: Dictionary, delta: float) -> void:
	var spd := Balance.TANK_SPEED * float(cfg.get("t_speed", 1.0))
	p.think_timer -= delta
	if p.think_timer <= 0.0:
		p.think_timer = randf_range(0.4, 0.6)
		p.target = _tank_target(p, gm)
	_push_zombies_out(p, gm)
	p.fire_cd -= delta
	var t := p.target
	var push: Vector2 = gm.map.bounds_push(p.position, 120.0) * 1.5
	if t == null or not is_instance_valid(t) or t.state != Unit.State.ACTIVE:
		var lead: Unit = gm.leader
		if lead != null:
			p.desired = ((lead.position - p.position).normalized() + push).normalized() * spd
		_turn_turret(p, p.facing, delta)
		return
	var to := t.position - p.position
	var d := to.length()
	var dir := to / maxf(d, 0.001)
	if d > 300.0:
		p.desired = (dir + push).normalized() * spd
	elif d < 200.0:
		p.desired = (-dir + push * 1.5).normalized() * spd * 0.8
	else:
		p.desired = (dir.orthogonal() * p.avoid_side * 0.6 + push).normalized() * spd * 0.5
	if p.under_attack > 0.0:
		p.desired *= 0.35
	# Apunta a donde va a estar el blanco cuando llegue el proyectil.
	var aim_pos := t.position + t.velocity * Balance.SHELL_FLIGHT * float(cfg.get("t_aim", 0.5))
	var want_dir := (aim_pos - p.position).normalized()
	var aligned := _turn_turret(p, want_dir, delta)
	if aligned and p.fire_cd <= 0.0 and d < Balance.TANK_RANGE and d > Balance.TANK_MIN_RANGE:
		p.fire_cd = Balance.TANK_FIRE_INTERVAL * float(cfg.get("t_fire", 1.0)) * randf_range(0.9, 1.15)
		var muzzle := p.position + p.turret * p.radius * 1.45
		gm.projectiles.fire_shell(muzzle, aim_pos)
		gm.effects.blast_flash(muzzle, 14.0)
		gm.effects.poof(muzzle, Color("#9A97A0"))
		p.recoil = 1.0
		gm.shake(3.0)
		AudioManager.play("cannon", 0.05, -2.0)


## Gira la torreta hacia `want` con velocidad limitada. Devuelve true si ya apunta.
static func _turn_turret(p: Unit, want: Vector2, delta: float) -> bool:
	var a := p.turret.angle_to(want)
	var step := 1.7 * delta
	p.turret = p.turret.rotated(clampf(a, -step, step))
	return absf(a) < 0.12


## Elige el zombi más "agrupado" a tiro (más vecinos cerca = más daño por cañonazo).
static func _tank_target(p: Unit, gm) -> Unit:
	gm.zombie_grid.query(p.position, Balance.TANK_RANGE, _buf)
	var best: Unit = null
	var best_score := -1.0
	var cand: Array = _buf.duplicate()
	var near: Array = []
	for c in cand:
		var z: Unit = c
		if z.state != Unit.State.ACTIVE:
			continue
		var d := p.position.distance_to(z.position)
		if d < Balance.TANK_MIN_RANGE:
			continue
		gm.zombie_grid.query(z.position, Balance.SHELL_BLAST, near)
		var sc := float(near.size()) + (2.0 if z.is_leader else 0.0) - d / 400.0
		if sc > best_score:
			best_score = sc
			best = z
	if best == null:
		best = _nearest_zombie(p, gm, 900.0)
	return best


## El tanque es sólido: empuja hacia afuera a los zombis que se le meten encima.
static func _push_zombies_out(p: Unit, gm) -> void:
	gm.zombie_grid.query(p.position, p.radius + 26.0, _buf)
	for c in _buf:
		var z: Unit = c
		if z.state != Unit.State.ACTIVE:
			continue
		var d := z.position - p.position
		var min_d := p.radius + z.radius * 0.6
		var l := d.length()
		if l < min_d:
			var n := d / l if l > 0.01 else Vector2.RIGHT.rotated(randf() * TAU)
			z.position = gm.map.resolve(p.position + n * min_d, z.radius)


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
