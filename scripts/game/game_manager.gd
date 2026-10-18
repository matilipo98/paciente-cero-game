class_name GameManager
extends Node2D
## Estados generales de la partida y bucle principal de simulación.
## Orden por frame: grillas → IA → movimiento → contagios → proyectiles → oleadas.

enum GState { INTRO, PLAYING, INTERMISSION, UPGRADE, GAME_OVER, VICTORY }

const GAME_SCENE := "res://scenes/game/game.tscn"
const MENU_SCENE := "res://scenes/main/main_menu.tscn"

## Nivel que se juega al cargar la escena (lo fija el menú antes de entrar).
static var selected_level := 1
var level := 1

@onready var map: WorldMap = $WorldMap
@onready var units_root: Node2D = $Units
@onready var projectiles: Projectiles = $Projectiles
@onready var effects: Effects = $Effects
@onready var ground_fx: Effects = $GroundEffects
@onready var waves: WaveManager = $WaveManager
@onready var infection: InfectionSystem = $InfectionSystem
@onready var upgrades: UpgradeManager = $UpgradeManager
@onready var player: PlayerController = $Controls/PlayerController
@onready var ui: UIManager = $UIManager
@onready var camera: Camera2D = $Camera2D

var zombies: Array[Unit] = []
var humans: Array[Unit] = []
var police: Array[Unit] = []
var leader: Unit = null
var zombie_grid := SpatialGrid.new(64.0)
var enemy_grid := SpatialGrid.new(64.0)

var state: int = GState.INTRO
var score := 0
var infected_total := 0
var police_defeated := 0
## Enemigos armados derrotados por tipo (ActorArt.Kind → cantidad).
var defeated_by_kind: Dictionary = {}
## Enemigos armados que se sumaron a la horda.
var armed_infected := 0
var zombies_lost := 0
var combo := 0
var best_combo := 0
var combo_timer := 0.0
var fever_timer := 0.0
var max_horde := 1

## Métricas de rendimiento (µs acumulados por sección; útiles para pruebas).
var perf: Dictionary = {"ai": 0, "move": 0, "infect": 0, "frames": 0}
var _formation_dirty := true
var _shake := 0.0
var _trail_t := 0.0
var _pending: Array = []
var _buf: Array = []


func _ready() -> void:
	randomize()
	level = clampi(selected_level, 1, Levels.count())
	Unit.fever_active = false
	projectiles.gm = self
	infection.gm = self
	waves.gm = self
	upgrades.reset()
	waves.wave_cleared.connect(_on_wave_cleared)
	ui.setup(self)
	leader = _make_zombie(map.player_start, Balance.LEADER_HP, true)
	var carried := _apply_carry()
	ui.update_zombies(zombies.size())
	state = GState.INTRO
	ui.announce_level(level)
	if carried > 1:
		_schedule(0.6, ui.toast.bind("¡Tu horda de %d zombis sigue con vos!" % carried, Palette.ZOMBIE_OUTLINE))
	_schedule(1.2, ui.announce_wave.bind(1))
	_schedule(2.2, _start_wave.bind(1))


## Horda y mejoras con las que se ganó el nivel anterior. Devuelve el tamaño de la horda.
func _apply_carry() -> int:
	var c := SaveManager.carry_for(level)
	if c.is_empty():
		return 1
	upgrades.load_levels(c.get("upgrades", {}))
	var n := clampi(int(c.get("zombies", 1)), 1, Balance.MAX_ZOMBIES)
	for i in n - 1:
		# Misma espiral que la formación, alrededor del punto de partida
		var off := Vector2.RIGHT.rotated(i * 2.39996 + 0.7) * 36.0 * sqrt(i + 1.0)
		_make_zombie(map.player_start + off, Balance.ALLY_HP + upgrades.extra_hp, false)
	max_horde = zombies.size()
	return zombies.size()


# ---------------------------------------------------------------------------
# Bucle principal
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_run_pending(delta)
	if state == GState.UPGRADE:
		return
	var simulate := state == GState.INTRO or state == GState.PLAYING or state == GState.INTERMISSION
	if simulate:
		_rebuild_grids()
		if _formation_dirty:
			_update_formation()
		var t0 := Time.get_ticks_usec()
		for z in zombies:
			ZombieAI.update(z, self, delta)
		for h in humans:
			HumanAI.update(h, self, delta)
		for p in police:
			PoliceAI.update(p, self, delta)
		var t1 := Time.get_ticks_usec()
		for z in zombies:
			z.integrate(delta, map)
			z.tick_visual(delta)
		for h in humans:
			h.integrate(delta, map)
			h.tick_visual(delta)
		for p in police:
			p.integrate(delta, map)
			p.tick_visual(delta)
		var t2 := Time.get_ticks_usec()
		if state == GState.PLAYING:
			infection.step(delta)
			projectiles.step(delta)
			waves.step(delta)
		perf.ai += t1 - t0
		perf.move += t2 - t1
		perf.infect += Time.get_ticks_usec() - t2
		perf.frames += 1
		_update_combo(delta)
		_update_trail(delta)
	_update_shake(delta)


func _rebuild_grids() -> void:
	zombie_grid.clear()
	enemy_grid.clear()
	for z in zombies:
		zombie_grid.insert(z, z.position)
	for h in humans:
		enemy_grid.insert(h, h.position)
	for p in police:
		enemy_grid.insert(p, p.position)


## Formación orgánica en espiral (ángulo áureo) alrededor del líder.
func _update_formation() -> void:
	_formation_dirty = false
	var i := 0
	for z in zombies:
		if z.is_leader:
			continue
		var r := 36.0 * sqrt(i + 1.0) + randf_range(-4.0, 4.0)
		z.formation_offset = Vector2.RIGHT.rotated(i * 2.39996 + 0.7) * r
		i += 1


func separation(u: Unit) -> Vector2:
	zombie_grid.query(u.position, 42.0, _buf)
	var push := Vector2.ZERO
	var min_d := u.radius * 2.0 + 3.0
	for c in _buf:
		var o: Unit = c
		if o == u or o.state != Unit.State.ACTIVE:
			continue
		var d := u.position - o.position
		var l := d.length()
		if l < min_d:
			if l < 0.01:
				d = Vector2.RIGHT.rotated(randf() * TAU)
				l = 1.0
			var k := 12.0 if not o.is_leader else 18.0
			push += d / l * (min_d - l) * k
	return push.limit_length(170.0)


func zombie_speed(is_leader: bool) -> float:
	var base := Balance.LEADER_SPEED if is_leader else Balance.ALLY_SPEED
	var mult := upgrades.speed_mult
	if fever_timer > 0.0:
		mult *= Balance.FEVER_SPEED_MULT
	return base * mult


# ---------------------------------------------------------------------------
# Creación de actores
# ---------------------------------------------------------------------------

func _make_zombie(pos: Vector2, hp: float, is_leader: bool) -> Unit:
	var z := Unit.new()
	z.setup_zombie(map.resolve(pos, Balance.ZOMBIE_RADIUS), hp, is_leader)
	units_root.add_child(z)
	zombies.append(z)
	_formation_dirty = true
	return z


func spawn_human(pos: Vector2) -> void:
	var h := Unit.new()
	h.setup_human(map.resolve(pos, Balance.HUMAN_RADIUS), randf_range(0.9, 1.06))
	h.wander_point = map.random_free_point()
	h.wander_timer = randf_range(2.0, 4.0)
	units_root.add_child(h)
	humans.append(h)


func spawn_police(pos: Vector2) -> void:
	var p := Unit.new()
	p.setup_police(map.resolve(pos, Balance.POLICE_RADIUS))
	p.hp *= float(waves.current_cfg.get("p_tough", 1.0))
	p.max_hp = p.hp
	p.wander_point = map.random_free_point()
	units_root.add_child(p)
	police.append(p)
	ui.toast("¡LLEGÓ LA POLICÍA!", Palette.POLICE)


## Enemigos armados de los niveles 3 a 5: comparten la lista `police` con la policía.
func spawn_soldier(pos: Vector2) -> void:
	_spawn_armed(ActorArt.Kind.SOLDIER, pos, "s_tough", "¡LLEGÓ EL EJÉRCITO!", Palette.SOLDIER_UNIFORM)


func spawn_survivor(pos: Vector2) -> void:
	_spawn_armed(ActorArt.Kind.SURVIVOR, pos, "sv_tough", "¡SUPERVIVIENTES ARMADOS!", Palette.GUN_WOOD)


func spawn_biker(pos: Vector2) -> void:
	_spawn_armed(ActorArt.Kind.BIKER, pos, "b_tough", "¡MOTOS A LA VISTA!", Palette.MOTO_RED)


func spawn_tank(pos: Vector2) -> void:
	var t := _spawn_armed(ActorArt.Kind.TANK, pos, "t_tough", "", Palette.TANK_GREEN)
	ui.show_banner("¡TANQUE!", Palette.TANK_LIGHT, Palette.INK, 0.9)
	ui.toast("Rodealo con %d zombis o más" % Balance.TANK_MIN_ATTACKERS, Palette.TANK_GREEN)
	t.facing = (map.player_start - t.position).normalized()
	t.turret = t.facing
	shake(5.0)
	AudioManager.play("boom", 0.0, -8.0, 0.6)


func _spawn_armed(k: int, pos: Vector2, tough_key: String, msg: String, col: Color) -> Unit:
	var u := Unit.new()
	match k:
		ActorArt.Kind.SOLDIER:
			u.setup_soldier(map.resolve(pos, Balance.SOLDIER_RADIUS))
		ActorArt.Kind.SURVIVOR:
			u.setup_survivor(map.resolve(pos, Balance.SURVIVOR_RADIUS))
		ActorArt.Kind.BIKER:
			u.setup_biker(map.resolve(pos, Balance.BIKER_RADIUS))
		ActorArt.Kind.TANK:
			u.setup_tank(map.resolve(pos, Balance.TANK_RADIUS))
	u.hp *= float(waves.current_cfg.get(tough_key, 1.0))
	u.max_hp = u.hp
	u.wander_point = map.random_free_point()
	units_root.add_child(u)
	police.append(u)
	if msg != "":
		ui.toast(msg, col)
	return u


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func spawn_bonus_allies(n: int) -> void:
	if leader == null:
		return
	for i in n:
		if zombies.size() >= Balance.MAX_ZOMBIES:
			break
		var pos := leader.position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(30, 50)
		var z := _make_zombie(pos, Balance.ALLY_HP + upgrades.extra_hp, false)
		effects.infection(z.position, false)
	ui.update_zombies(zombies.size())
	max_horde = maxi(max_horde, zombies.size())


# ---------------------------------------------------------------------------
# Contagio, combo y fiebre
# ---------------------------------------------------------------------------

func on_human_infected(h: Unit) -> void:
	humans.erase(h)
	var intense := fever_timer > 0.0
	if zombies.size() >= Balance.MAX_ZOMBIES:
		effects.poof(h.position, Palette.ZOMBIE_SKIN)
		h.start_die()
	else:
		h.become_zombie(Balance.ALLY_HP + upgrades.extra_hp)
		zombies.append(h)
		_formation_dirty = true
	infected_total += 1
	max_horde = maxi(max_horde, zombies.size())

	combo += 1
	best_combo = maxi(best_combo, combo)
	combo_timer = Balance.COMBO_WINDOW
	var mult := 1.0 + minf((combo - 1) * Balance.COMBO_STEP_MULT, Balance.COMBO_MAX_MULT - 1.0)
	if intense:
		mult *= Balance.FEVER_SCORE_MULT
	var pts := int(round(Balance.SCORE_INFECT * mult))
	add_score(pts)

	effects.infection(h.position, intense)
	effects.popup(h.position, "+%d" % pts, Palette.GOLD if mult > 1.05 else Palette.WHITE, 26 if mult > 1.05 else 22)
	AudioManager.play("infect", 0.03, -2.0, 1.0 + minf(combo, 12) * 0.035)
	if combo % Balance.FEVER_COMBO == 0:
		_start_fever(h.position)
	ui.on_combo(combo)
	ui.update_zombies(zombies.size())


func _start_fever(pos: Vector2) -> void:
	var was_on := fever_timer > 0.0
	fever_timer = Balance.FEVER_DURATION
	Unit.fever_active = true
	effects.combo_burst(pos)
	AudioManager.play("combo", 0.0, 0.0)
	if not was_on:
		AudioManager.play("fever", 0.0, -2.0)
	ui.show_fever(true)


func _update_combo(delta: float) -> void:
	if combo > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 0
			ui.on_combo(0)
	if fever_timer > 0.0:
		fever_timer -= delta
		if fever_timer <= 0.0:
			fever_timer = 0.0
			Unit.fever_active = false
			ui.show_fever(false)


func add_score(pts: int) -> void:
	score += pts
	ui.update_score(score)


# ---------------------------------------------------------------------------
# Daño y combate
# ---------------------------------------------------------------------------

func damage_zombie(z: Unit, amount: float, hit_pos: Vector2) -> void:
	var was_leader := z.is_leader
	if z.invuln > 0.0:
		return
	var died := z.hurt(amount)
	effects.hit_star(hit_pos)
	if was_leader:
		_shake = 7.0
		SaveManager.vibrate(60)
		ui.update_leader_hp(z.hp)
	if died:
		kill_zombie(z)
	else:
		AudioManager.play("hurt", 0.08, -3.0)


func kill_zombie(z: Unit) -> void:
	var was_leader := z.is_leader
	zombies_lost += 1
	zombies.erase(z)
	_formation_dirty = true
	effects.poof(z.position, Palette.ZOMBIE_SKIN)
	z.start_die()
	AudioManager.play("zombie_die", 0.1, -3.0)
	ui.update_zombies(zombies.size())
	if was_leader:
		_transfer_leader(z.position)
	if zombies.is_empty():
		_game_over()


## Si cae el zombi principal, el control pasa al aliado más cercano.
func _transfer_leader(from: Vector2) -> void:
	leader = null
	var best_d := INF
	for z in zombies:
		if z.state != Unit.State.ACTIVE:
			continue
		var d := z.position.distance_squared_to(from)
		if d < best_d:
			best_d = d
			leader = z
	if leader != null:
		leader.set_leader(true)
		leader.target = null
		ui.toast("¡NUEVO PACIENTE CERO!", Palette.ZOMBIE_OUTLINE)
		ui.update_leader_hp(leader.hp)
		_formation_dirty = true


func on_police_defeated(p: Unit) -> void:
	police.erase(p)
	police_defeated += 1
	defeated_by_kind[p.kind] = int(defeated_by_kind.get(p.kind, 0)) + 1
	var pts := Balance.SCORE_POLICE
	var col := Palette.POLICE
	match p.kind:
		ActorArt.Kind.SOLDIER:
			pts = Balance.SCORE_SOLDIER; col = Palette.SOLDIER_UNIFORM
		ActorArt.Kind.SURVIVOR:
			pts = Balance.SCORE_SURVIVOR; col = Palette.SURV_PACK
		ActorArt.Kind.BIKER:
			pts = Balance.SCORE_BIKER; col = Palette.MOTO_RED
		ActorArt.Kind.TANK:
			pts = Balance.SCORE_TANK; col = Palette.TANK_GREEN
	add_score(pts)
	effects.hit_star(p.position)
	if p.kind == ActorArt.Kind.TANK:
		effects.explosion(p.position, 80.0)
		for i in 6:
			_schedule(0.35 + i * 0.4, effects.smoke.bind(p.position + Vector2(randf_range(-20, 20), -10)))
		effects.popup(p.position, "+%d" % pts, Palette.GOLD, 40)
		ui.show_banner("¡TANQUE DESTRUIDO!", Palette.GOLD, Palette.INK, 0.8)
		shake(12.0)
		SaveManager.vibrate(120)
		AudioManager.play("boom", 0.0, 2.0)
		spawn_bonus_allies(Balance.TANK_BONUS_ALLIES)
		p.start_die()
		return
	var need := Balance.infect_need(p.kind)
	if need > 0 and p.attackers >= need and zombies.size() < Balance.MAX_ZOMBIES:
		# Rodeado por la horda: se contagia y se suma como un zombi más.
		p.become_zombie(Balance.ALLY_HP + upgrades.extra_hp)
		zombies.append(p)
		_formation_dirty = true
		infected_total += 1
		armed_infected += 1
		max_horde = maxi(max_horde, zombies.size())
		effects.infection(p.position, true)
		effects.popup(p.position + Vector2(0, -22), "¡CONTAGIADO!", Palette.ZOMBIE_SKIN_LIGHT, 26)
		effects.popup(p.position, "+%d" % pts, Palette.GOLD, 28)
		ui.update_zombies(zombies.size())
		AudioManager.play("infect", 0.05, 0.0, 0.8)
		AudioManager.play("police_down", 0.05, -4.0)
		SaveManager.vibrate(40)
		return
	effects.poof(p.position, col)
	effects.popup(p.position, "+%d" % pts, Palette.GOLD, 28)
	AudioManager.play("police_down", 0.05, -1.0)
	p.start_die()


# ---------------------------------------------------------------------------
# Flujo de oleadas
# ---------------------------------------------------------------------------

func _start_wave(n: int) -> void:
	if state == GState.GAME_OVER:
		return
	state = GState.PLAYING
	waves.start_wave(n)
	ui.set_wave(n)
	AudioManager.play("wave_start", 0.0, -2.0)


func _on_wave_cleared() -> void:
	if state != GState.PLAYING:
		return
	state = GState.INTERMISSION
	add_score(Balance.SCORE_WAVE)
	if leader != null:
		effects.popup(leader.position + Vector2(0, -20), "+%d" % Balance.SCORE_WAVE, Palette.GOLD, 32)
	for h in humans:
		if h.state == Unit.State.BITTEN:
			# La mordida en curso se completa: premio por llegar justo.
			on_human_infected.call_deferred(h)
			continue
		h.start_leave()
	humans.clear()
	for p in police:
		p.start_leave()
	police.clear()
	projectiles.clear_all()
	AudioManager.play("wave_clear", 0.0, -1.0)
	ui.wave_cleared(waves.wave)
	if waves.wave >= waves.total_waves():
		_schedule(1.6, _victory)
	else:
		_schedule(1.5, _open_upgrades)


func _open_upgrades() -> void:
	if state != GState.INTERMISSION:
		return
	state = GState.UPGRADE
	player.release()
	get_tree().paused = true
	ui.show_upgrades(upgrades.roll_choices(3))


func on_upgrade_chosen(id: String) -> void:
	get_tree().paused = false
	upgrades.apply(id, self)
	AudioManager.play("select", 0.0, 0.0)
	state = GState.INTERMISSION
	var next := waves.wave + 1
	ui.announce_wave(next)
	_schedule(1.0, _start_wave.bind(next))


func _game_over() -> void:
	if state == GState.GAME_OVER or state == GState.VICTORY:
		return
	state = GState.GAME_OVER
	leader = null
	Unit.fever_active = false
	player.release()
	player.enabled = false
	AudioManager.play("lose", 0.0, 0.0)
	var stats := _finish_run(false)
	_schedule(1.1, ui.show_results.bind(stats))


func _victory() -> void:
	state = GState.VICTORY
	Unit.fever_active = false
	player.release()
	player.enabled = false
	AudioManager.play("win", 0.0, 0.0)
	ui.show_results(_finish_run(true))


func _finish_run(victory: bool) -> Dictionary:
	var reached := maxi(1, waves.wave)
	var carry := {}
	if victory and level < Levels.count():
		carry = {"zombies": maxi(1, zombies.size()), "upgrades": upgrades.levels.duplicate()}
	var rec := SaveManager.submit_run(score, reached, infected_total, victory, max_horde, level, carry)
	return {
		"victory": victory,
		"level": level,
		"total_waves": waves.total_waves(),
		"has_next": victory and level < Levels.count(),
		"wave": reached,
		"infected": infected_total,
		"police": police_defeated,
		"score": score,
		"best_score": SaveManager.best_score,
		"best_wave": SaveManager.best_wave,
		"new_record": rec,
		"max_horde": max_horde,
		"carry": int(carry.get("zombies", 0)),
	}


# ---------------------------------------------------------------------------
# Pausa, reinicio y ciclo de vida de la app
# ---------------------------------------------------------------------------

func can_pause() -> bool:
	return state == GState.INTRO or state == GState.PLAYING or state == GState.INTERMISSION


func pause_game() -> void:
	if not can_pause() or get_tree().paused:
		return
	player.release()
	get_tree().paused = true
	ui.show_pause()


func resume_game() -> void:
	get_tree().paused = false


func restart() -> void:
	get_tree().paused = false
	SceneTransition.change_scene(GAME_SCENE)


func next_level() -> void:
	selected_level = mini(level + 1, Levels.count())
	restart()


func go_to_menu() -> void:
	get_tree().paused = false
	SceneTransition.change_scene(MENU_SCENE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_node_ready():
			pause_game()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and (k.keycode == KEY_ESCAPE or k.keycode == KEY_P):
		pause_game()


# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------

func _schedule(t: float, c: Callable) -> void:
	_pending.append([t, c])


func _run_pending(delta: float) -> void:
	if _pending.is_empty():
		return
	var due: Array[Callable] = []
	for i in range(_pending.size() - 1, -1, -1):
		_pending[i][0] -= delta
		if _pending[i][0] <= 0.0:
			due.append(_pending[i][1])
			_pending.remove_at(i)
	for c in due:
		c.call()


func _update_trail(delta: float) -> void:
	if leader == null or leader.moving < 0.5:
		return
	_trail_t -= delta
	if _trail_t <= 0.0:
		_trail_t = 0.07
		ground_fx.trail(leader.position + Vector2(0, leader.radius * 0.4) - leader.facing * leader.radius * 0.6)


func _update_shake(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 30.0)
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	elif camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO
