class_name HumanAI
extends RefCounted
## IA de civiles: caminan al azar y, si detectan zombis cerca, escapan en sentido
## contrario (ponderando a los más cercanos) evitando quedar contra los bordes.

static var _buf: Array = []


static func update(h: Unit, gm, delta: float) -> void:
	match h.state:
		Unit.State.BITTEN:
			h.desired = Vector2.ZERO
			return
		Unit.State.LEAVING, Unit.State.DYING:
			h.desired = Vector2.ZERO
			return

	var cfg: Dictionary = gm.waves.current_cfg
	var spd_mult: float = cfg.get("speed", 1.0)
	var fear: float = Balance.HUMAN_FEAR_RADIUS * float(cfg.get("fear", 1.0))

	h.think_timer -= delta
	h.wander_timer -= delta
	if h.think_timer <= 0.0:
		h.think_timer = randf_range(0.12, 0.22)
		var threat := _threat(h, gm, fear)
		if threat != Vector2.ZERO:
			if not h.fleeing:
				h.alert_timer = 0.6  # AN-04: gira y acelera con gotitas de susto
			h.fleeing = true
			var dir := threat.normalized()
			dir += gm.map.bounds_push(h.position, 110.0) * 1.4
			h.flee_dir = dir.normalized() if dir.length_squared() > 0.001 else threat.normalized()
		else:
			h.fleeing = false

	if h.fleeing:
		h.desired = h.flee_dir * Balance.HUMAN_RUN_SPEED * spd_mult * h.speed_factor
	else:
		if h.wander_timer <= 0.0 or h.position.distance_squared_to(h.wander_point) < 400.0:
			h.wander_point = gm.map.random_free_point()
			h.wander_timer = randf_range(2.5, 5.0)
		var to := h.wander_point - h.position
		h.desired = to.normalized() * Balance.HUMAN_WALK_SPEED * h.speed_factor


static func _threat(h: Unit, gm, radius: float) -> Vector2:
	gm.zombie_grid.query(h.position, radius, _buf)
	var v := Vector2.ZERO
	var r2 := radius * radius
	for c in _buf:
		var z: Unit = c
		if z.state != Unit.State.ACTIVE:
			continue
		var d := h.position - z.position
		var l2 := d.length_squared()
		if l2 < r2 and l2 > 0.01:
			v += d / l2
	return v
