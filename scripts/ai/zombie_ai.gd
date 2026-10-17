class_name ZombieAI
extends RefCounted
## IA de zombis: el líder obedece al joystick; los aliados siguen al líder en una
## formación orgánica (espiral) y persiguen humanos/policías cercanos.
## La búsqueda de objetivos se hace cada ~0.2 s por zombi, no en cada frame.

static var _buf: Array = []


static func update(z: Unit, gm, delta: float) -> void:
	if z.state != Unit.State.ACTIVE:
		z.desired = Vector2.ZERO
		return
	if z.is_leader:
		z.desired = gm.player.direction * gm.zombie_speed(true)
		return

	z.think_timer -= delta
	if z.think_timer <= 0.0:
		z.think_timer = randf_range(0.16, 0.28)
		z.target = _find_target(z, gm)

	var speed: float = gm.zombie_speed(false)
	var leader: Unit = gm.leader
	var want := Vector2.ZERO
	var t := z.target
	if t != null and is_instance_valid(t) and t.state == Unit.State.ACTIVE and t.kind != ActorArt.Kind.ZOMBIE:
		var to := t.position - z.position
		var d := to.length()
		if d > 0.5:
			want = to / d * speed
	elif leader != null:
		z.target = null
		var slot := leader.position + z.formation_offset
		var to_slot := slot - z.position
		var dist := to_slot.length()
		if dist > 16.0:
			var s := speed * clampf(dist / 70.0, 0.25, 1.0)
			if z.position.distance_to(leader.position) > 150.0:
				s = speed * Balance.ALLY_CATCHUP_MULT
			want = to_slot / dist * s
	# Separación cada 3 frames (escalonado por zombi) para ahorrar CPU en hordas grandes.
	if (Engine.get_physics_frames() + z.get_instance_id()) % 3 == 0:
		z.sep_cache = gm.separation(z)
	want += z.sep_cache
	z.desired = want


static func _find_target(z: Unit, gm) -> Unit:
	var leader: Unit = gm.leader
	var detect: float = Balance.ALLY_DETECT_RADIUS * gm.upgrades.detect_mult
	var leash: float = Balance.ALLY_LEASH * (0.75 + 0.25 * gm.upgrades.detect_mult)
	var best: Unit = null
	var best_d := detect * detect
	gm.enemy_grid.query(z.position, detect, _buf)
	for c in _buf:
		var u: Unit = c
		if u.state != Unit.State.ACTIVE or u.kind == ActorArt.Kind.ZOMBIE:
			continue
		var d2 := z.position.distance_squared_to(u.position)
		if d2 < best_d:
			if leader != null and u.position.distance_squared_to(leader.position) > leash * leash:
				continue
			best_d = d2
			best = u
	return best
