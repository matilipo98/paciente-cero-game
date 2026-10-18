class_name Unit
extends Node2D
## Actor genérico (humano, zombi o enemigo armado: policía, soldado, superviviente, moto o tanque). Un mismo nodo puede pasar de humano
## a zombi al contagiarse: así se reutiliza el objeto y la transformación es instantánea.
## La IA vive en HumanAI / ZombieAI / PoliceAI; acá sólo hay datos, movimiento y dibujo.

enum State { ACTIVE, BITTEN, DYING, LEAVING }

const STEER_ANGLES: Array[float] = [0.55, 1.1, 1.65, 2.3]

## Fiebre activa: los zombis dibujan su aura. Lo maneja GameManager.
static var fever_active := false

var kind: int = ActorArt.Kind.HUMAN
var state: int = State.ACTIVE
var radius := 13.5
var velocity := Vector2.ZERO
var desired := Vector2.ZERO
var accel := 1500.0
var facing := Vector2.DOWN
var aim_dir := Vector2.ZERO
var phase := 0.0
var moving := 0.0

var hp := 1.0
var max_hp := 1.0
var is_leader := false
var invuln := 0.0
var hurt_flash := 0.0
var infect_flash := 0.0
var bar_timer := 0.0

# --- IA ---
var think_timer := 0.0
var target: Unit = null
var wander_point := Vector2.ZERO
var wander_timer := 0.0
var avoid_side := 1.0
var formation_offset := Vector2.ZERO
var speed_factor := 1.0
var fleeing := false
var flee_dir := Vector2.ZERO
var alert_timer := 0.0
var leave_dir := Vector2.ZERO
var bite_timer := 0.0
var toughness := 1.0
var fire_cd := 0.0
var under_attack := 0.0
var burst_left := 0
var burst_cd := 0.0
var sep_cache := Vector2.ZERO
# --- Tanque ---
var turret := Vector2.DOWN
var recoil := 0.0
var wrecked := false
var tank_attackers := 0

# --- Aspecto ---
var cloth := Palette.CLOTH_BLUE
var hair := Palette.HAIR_BROWN
var skin := Palette.HUMAN_SKIN
var variant := 0
## Índice del look en el atlas horneado (ActorAtlas). -1 = dibujo procedural.
var look := -1
var sprite: Sprite2D = null
var _t := 0.0
var _needs_draw := true
var _last_fever := false
var _spr_key := -1
var _spr_radius := -1.0
var _steer_cache := Vector2.ZERO
var _steer_in := Vector2.ZERO


func _init() -> void:
	avoid_side = 1.0 if randf() < 0.5 else -1.0
	phase = randf() * TAU  # desfase por instancia: la horda no camina sincronizada (AN-02)


func setup_human(pos: Vector2, spd: float) -> void:
	kind = ActorArt.Kind.HUMAN
	position = pos
	radius = Balance.HUMAN_RADIUS
	speed_factor = spd
	_apply_look(ActorAtlas.random_human_look())
	hp = 1.0
	max_hp = 1.0
	_spawn_pop()


func setup_zombie(pos: Vector2, hit_points: float, leader: bool) -> void:
	kind = ActorArt.Kind.ZOMBIE
	position = pos
	is_leader = leader
	radius = Balance.ZOMBIE_RADIUS if leader else Balance.ALLY_RADIUS
	_apply_look(ActorAtlas.leader_look if leader else ActorAtlas.random_zombie_look())
	hp = hit_points
	max_hp = hit_points
	_spawn_pop()


func setup_police(pos: Vector2) -> void:
	kind = ActorArt.Kind.POLICE
	position = pos
	radius = Balance.POLICE_RADIUS
	_apply_look(ActorAtlas.police_look)
	toughness = Balance.POLICE_TOUGHNESS
	hp = toughness
	max_hp = toughness
	fire_cd = randf_range(0.8, 1.6)
	_spawn_pop()


func setup_soldier(pos: Vector2) -> void:
	kind = ActorArt.Kind.SOLDIER
	position = pos
	radius = Balance.SOLDIER_RADIUS
	_apply_look(ActorAtlas.soldier_look)
	toughness = Balance.SOLDIER_TOUGHNESS
	hp = toughness
	max_hp = toughness
	fire_cd = randf_range(1.0, 2.0)
	_spawn_pop()


func setup_survivor(pos: Vector2) -> void:
	_setup_armed(ActorArt.Kind.SURVIVOR, pos, Balance.SURVIVOR_RADIUS, Balance.SURVIVOR_TOUGHNESS, ActorAtlas.survivor_look)
	fire_cd = randf_range(0.8, 1.5)


func setup_biker(pos: Vector2) -> void:
	_setup_armed(ActorArt.Kind.BIKER, pos, Balance.BIKER_RADIUS, Balance.BIKER_TOUGHNESS, ActorAtlas.biker_look)
	accel = Balance.BIKER_ACCEL
	fire_cd = randf_range(0.6, 1.2)


## El tanque no usa el atlas: se dibuja a mano (casco, orugas y torreta que gira aparte).
func setup_tank(pos: Vector2) -> void:
	_setup_armed(ActorArt.Kind.TANK, pos, Balance.TANK_RADIUS, Balance.TANK_TOUGHNESS, ActorAtlas.soldier_look)
	accel = 260.0
	fire_cd = 2.0
	turret = facing


func _setup_armed(k: int, pos: Vector2, r: float, tough: float, lk: int) -> void:
	kind = k
	position = pos
	radius = r
	_apply_look(lk)
	toughness = tough
	hp = tough
	max_hp = tough
	_spawn_pop()


## Contagio (AN-05): pasa de civil a zombi con destello verde y rebote 1.08 → 1.
func become_zombie(hit_points: float) -> void:
	kind = ActorArt.Kind.ZOMBIE
	state = State.ACTIVE
	radius = Balance.ALLY_RADIUS
	_apply_look(ActorAtlas.random_zombie_look())
	hp = hit_points
	max_hp = hit_points
	fleeing = false
	target = null
	velocity *= 0.3
	think_timer = 0.0
	infect_flash = 1.0
	var tw := create_tween()
	scale = Vector2.ONE * 1.25
	tw.tween_property(self, "scale", Vector2.ONE * 1.08, 0.08)
	tw.tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_leader(on: bool) -> void:
	is_leader = on
	if on:
		radius = Balance.ZOMBIE_RADIUS
		_apply_look(ActorAtlas.leader_look)
		invuln = 0.8
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2.ONE * 1.25, 0.1)
		tw.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)


## Toma ropa, pelo y peinado de un look del atlas (también sirve para el dibujo procedural).
func _apply_look(idx: int) -> void:
	look = idx
	var lk: Dictionary = ActorAtlas.looks[idx]
	cloth = lk.cloth
	hair = lk.hair
	skin = lk.skin
	variant = lk.variant
	_needs_draw = true


func is_active() -> bool:
	return state == State.ACTIVE


## Aplica daño. Devuelve true si murió.
func hurt(amount: float) -> bool:
	if invuln > 0.0 or state != State.ACTIVE:
		return false
	hp -= amount
	hurt_flash = 1.0
	bar_timer = 1.4
	invuln = Balance.LEADER_INVULN if is_leader else Balance.ALLY_INVULN
	return hp <= 0.0


## Eliminación sin sangre: se encoge y se desvanece (AN-13 / AN-14).
func start_die() -> void:
	state = State.DYING
	is_leader = false
	queue_redraw()
	if kind == ActorArt.Kind.TANK:
		# Queda la carcasa humeante unos segundos y después se desvanece.
		wrecked = true
		var tw2 := create_tween()
		tw2.tween_interval(2.6)
		tw2.tween_property(self, "modulate:a", 0.0, 0.8)
		tw2.tween_callback(queue_free)
		return
	var tw := create_tween().set_parallel(true)
	var armed := ActorArt.is_armed(kind)
	var dur := 0.35 if armed else 0.3
	tw.tween_property(self, "scale", Vector2.ONE * 0.35, dur).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, dur)
	if armed:
		tw.tween_property(self, "rotation", PI * 0.5, dur)
	tw.chain().tween_callback(queue_free)


## Al terminar una oleada, civiles y policías restantes se van.
func start_leave() -> void:
	state = State.LEAVING
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)


func _spawn_pop() -> void:
	scale = Vector2.ONE * 0.4
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------------------
# Movimiento con evasión local de obstáculos
# ---------------------------------------------------------------------------

func integrate(delta: float, map: WorldMap) -> void:
	var d := desired
	var spd := d.length()
	if spd > 1.0:
		var want := d / spd
		# El sondeo de obstáculos se recalcula cada 2 frames o si cambió mucho el rumbo.
		if (Engine.get_physics_frames() + get_instance_id()) % 2 == 0 or want.dot(_steer_in) < 0.95:
			_steer_in = want
			_steer_cache = _steer(want, map)
		d = _steer_cache * spd
	velocity = velocity.move_toward(d, accel * delta)
	position = map.resolve(position + velocity * delta, radius)
	var v2 := velocity.length_squared()
	if v2 > 36.0:
		var vn := velocity / sqrt(v2)
		var nf := facing.lerp(vn, minf(1.0, delta * 12.0))
		facing = nf.normalized() if nf.length_squared() > 0.01 else vn
		phase += delta * (7.0 + sqrt(v2) * 0.045)
		moving = minf(1.0, moving + delta * 6.0)
	else:
		moving = maxf(0.0, moving - delta * 5.0)
		phase += delta * 2.0
	if aim_dir != Vector2.ZERO and kind != ActorArt.Kind.TANK:
		facing = facing.lerp(aim_dir, minf(1.0, delta * 14.0)).normalized()


func _steer(dir: Vector2, map: WorldMap) -> Vector2:
	var probe := radius + 14.0
	if not map.is_blocked(position + dir * probe, radius):
		return dir
	for a in STEER_ANGLES:
		var d1 := dir.rotated(a * avoid_side)
		if not map.is_blocked(position + d1 * probe, radius):
			return d1
		var d2 := dir.rotated(-a * avoid_side)
		if not map.is_blocked(position + d2 * probe, radius):
			avoid_side = -avoid_side
			return d2
	return dir


# ---------------------------------------------------------------------------
# Animación y dibujo
# ---------------------------------------------------------------------------

## Lo llama GameManager en su bucle: actualiza timers visuales y sólo redibuja
## cuando algo cambia (los aliados quietos no se redibujan cada frame).
func tick_visual(delta: float) -> void:
	_t += delta
	if invuln > 0.0:
		invuln -= delta
	if hurt_flash > 0.0:
		hurt_flash = maxf(0.0, hurt_flash - delta / 0.15)
	if infect_flash > 0.0:
		infect_flash = maxf(0.0, infect_flash - delta / 0.22)
	if bar_timer > 0.0:
		bar_timer -= delta
	if alert_timer > 0.0:
		alert_timer -= delta
	if under_attack > 0.0:
		under_attack -= delta
	if recoil > 0.0:
		recoil = maxf(0.0, recoil - delta * 3.0)
	if sprite == null and ActorAtlas.texture != null and kind != ActorArt.Kind.TANK:
		_make_sprite()
	if sprite != null:
		_update_sprite()
		# Con sprites, el nodo sólo redibuja sombra y superposiciones cuando cambian.
		var dynamic := is_leader or alert_timer > 0.0 or bar_timer > 0.0 \
			or (ActorArt.is_armed(kind) and hp < max_hp)
		if fever_active != _last_fever:
			_last_fever = fever_active
			_needs_draw = true
		if dynamic or _needs_draw:
			_needs_draw = dynamic
			queue_redraw()
		return
	var animating := moving > 0.0 or is_leader or fever_active or state != State.ACTIVE \
		or hurt_flash > 0.0 or infect_flash > 0.0 or bar_timer > 0.0 or alert_timer > 0.0 \
		or under_attack > 0.0 or invuln > 0.0 or ActorArt.is_armed(kind)
	if animating or _needs_draw:
		_needs_draw = animating
		queue_redraw()


func _make_sprite() -> void:
	sprite = Sprite2D.new()
	sprite.texture = ActorAtlas.texture
	sprite.region_enabled = true
	sprite.material = Baker.premult_material()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(sprite)
	_needs_draw = true


func _update_sprite() -> void:
	# Sólo se tocan las propiedades que cambiaron (cada cambio invalida el canvas item).
	var frame := 0
	if moving > 0.3:
		frame = int(fposmod(phase, TAU) / (PI * 0.5)) % ActorAtlas.FRAMES
	var key := look * 8 + frame
	if key != _spr_key:
		_spr_key = key
		sprite.region_rect = ActorAtlas.region(look, frame)
	var rot := facing.angle() - PI * 0.5
	if absf(rot - sprite.rotation) > 0.02:
		sprite.rotation = rot
	if radius != _spr_radius:
		_spr_radius = radius
		sprite.scale = Vector2.ONE * (radius / (ActorAtlas.BAKE_R * ActorAtlas.BAKE_SCALE))
	var col := Color.WHITE
	var off := Vector2.ZERO
	if hurt_flash > 0.0:
		col = Color.WHITE.lerp(Color(1.0, 0.5, 0.5), hurt_flash)
	elif infect_flash > 0.0:
		col = Color.WHITE.lerp(Color(0.8, 1.0, 0.75), infect_flash)
	if state == State.BITTEN:
		var k := 1.0 - clampf(bite_timer / Balance.BITE_TIME, 0.0, 1.0)
		col = Color.WHITE.lerp(Color(0.6, 1.0, 0.55), k)
		off = Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
	elif under_attack > 0.0 and ActorArt.is_armed(kind):
		col = Color(1.0, 0.8, 0.8)
		off = Vector2(randf_range(-1.2, 1.2), randf_range(-1.2, 1.2))
	if col != sprite.modulate:
		sprite.modulate = col
	if off != sprite.position:
		sprite.position = off
	var vis := not (is_leader and invuln > 0.0 and fmod(_t, 0.16) < 0.06)
	if vis != sprite.visible:
		sprite.visible = vis


func _draw() -> void:
	if sprite != null:
		_draw_overlays_sprite()
		return
	var tint := Color(0, 0, 0, 0)
	var ground := Vector2.ZERO
	if hurt_flash > 0.0:
		tint = Color(Palette.DANGER, hurt_flash * 0.85)
	elif infect_flash > 0.0:
		tint = Color(Palette.ZOMBIE_SKIN_LIGHT, infect_flash * 0.8)
	if state == State.BITTEN:
		var k := 1.0 - clampf(bite_timer / Balance.BITE_TIME, 0.0, 1.0)
		tint = Color(Palette.ZOMBIE_SKIN, k * 0.8)
		ground = Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
	if under_attack > 0.0 and ActorArt.is_armed(kind):
		ground = Vector2(randf_range(-1.2, 1.2), randf_range(-1.2, 1.2))
		tint = Color(Palette.DANGER_LIGHT, 0.35)

	if is_leader and state == State.ACTIVE:
		ActorArt.player_ring(self, ground, radius, _t)
	if fever_active and kind == ActorArt.Kind.ZOMBIE and state == State.ACTIVE:
		ActorArt.fever_aura(self, ground, radius, _t + phase)

	# Parpadeo durante invulnerabilidad del líder
	if is_leader and invuln > 0.0 and fmod(_t, 0.16) < 0.06:
		tint = Color(Palette.WHITE, 0.6)

	if kind == ActorArt.Kind.TANK:
		ActorArt.draw_tank(self, ground, radius, facing, turret, phase, tint, wrecked, recoil)
	else:
		ActorArt.draw_actor(self, kind, ground, radius, facing, phase, moving, cloth, hair, skin, tint, variant)

	_draw_status(ground)


func _draw_overlays_sprite() -> void:
	if is_leader and state == State.ACTIVE:
		ActorArt.player_ring(self, Vector2.ZERO, radius, _t)
	if fever_active and kind == ActorArt.Kind.ZOMBIE and state == State.ACTIVE:
		ActorArt.fever_aura(self, Vector2.ZERO, radius, 0.0)
	ActorArt.shadow(self, Vector2(0, radius * 0.55), radius * 1.05)
	_draw_status(Vector2.ZERO)


func _draw_status(ground: Vector2) -> void:
	if kind == ActorArt.Kind.HUMAN and alert_timer > 0.0:
		ActorArt.alert(self, ground + Vector2(radius * 0.6, -radius - 8.0), clampf(alert_timer / 0.6, 0.0, 1.0))
	if kind == ActorArt.Kind.TANK and state == State.ACTIVE:
		_draw_tank_status(ground)
	elif ActorArt.is_armed(kind) and hp < max_hp and state == State.ACTIVE:
		ActorArt.health_bar(self, ground + Vector2(0, -radius - 12.0), hp / max_hp, 1.0)
	elif kind == ActorArt.Kind.ZOMBIE and bar_timer > 0.0 and state == State.ACTIVE:
		ActorArt.health_bar(self, ground + Vector2(0, -radius - 12.0), hp / max_hp, clampf(bar_timer / 0.4, 0.0, 1.0))
	if is_leader and state == State.ACTIVE:
		var n := int(ceil(hp))
		var w := (n - 1) * 9.0
		for i in n:
			draw_circle(ground + Vector2(-w * 0.5 + i * 9.0, radius + 12.0), 3.2, Palette.with_alpha(Palette.DANGER, 0.9))


## Barra de vida grande y marcas de "rodealo": una por cada zombi que hace falta
## mordiéndolo a la vez; se pintan de verde a medida que se suman atacantes.
func _draw_tank_status(ground: Vector2) -> void:
	var w := 92.0
	var p := ground + Vector2(-w * 0.5, -radius - 22.0)
	draw_rect(Rect2(p - Vector2(2, 2), Vector2(w + 4, 12)), Palette.with_alpha(Palette.INK, 0.75))
	draw_rect(Rect2(p, Vector2(w * clampf(hp / max_hp, 0.0, 1.0), 8)), Palette.DANGER)
	var need := Balance.TANK_MIN_ATTACKERS
	var ok := tank_attackers >= need
	for i in need:
		var a := -PI * 0.5 + (i - (need - 1) * 0.5) * 0.32
		var c := ground + Vector2.RIGHT.rotated(a) * (radius + 30.0)
		var col := Palette.ZOMBIE_SKIN if i < tank_attackers else Palette.with_alpha(Palette.WHITE, 0.55)
		draw_circle(c, 6.0 if ok else 5.0, Palette.with_alpha(Palette.INK, 0.6))
		draw_circle(c, 4.5 if ok else 3.6, col)
