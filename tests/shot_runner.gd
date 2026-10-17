extends Node
## Genera capturas de cada pantalla. Uso (con display / xvfb):
## SHOT=<nombre> godot --path . res://tests/shot_runner.tscn
## Nombres: menu, menu_upgrades, menu_records, menu_settings, game_start, game_horde,
##          upgrade, pause, defeat, victory

const OUT_DIR := "res://docs/screenshots/"
var shot := ""
var frames := 0
var game: GameManager = null
var menu: Node = null
var _done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	shot = OS.get_environment("SHOT")
	seed(7)
	if shot.begins_with("menu"):
		menu = load("res://scenes/main/main_menu.tscn").instantiate()
		add_child(menu)
	else:
		SaveManager.tutorial_done = shot != "game_start"
		game = load("res://scenes/game/game.tscn").instantiate()
		add_child(game)


func _physics_process(_d: float) -> void:
	frames += 1
	if game != null:
		_bot()
	match shot:
		"menu":
			if frames == 50: _save()
		"menu_upgrades":
			if frames == 5: menu._show_upgrades()
			if frames == 40: _save()
		"menu_records":
			if frames == 5: menu._show_records()
			if frames == 40: _save()
		"menu_settings":
			if frames == 5: menu._show_settings()
			if frames == 40: _save()
		"game_start":
			if frames == 100: _save()
		"game_horde":
			_auto_upgrade()
			if game.waves.wave >= 5 and game.police.size() >= 2 and game.zombies.size() > 30 and frames % 20 == 0 and not _done:
				_save()
		"upgrade":
			if game.state == GameManager.GState.UPGRADE and not _done:
				frames = 0
				_done = true
			if _done and frames == 30: _save()
		"pause":
			if frames == 600: game.pause_game()
			if frames == 640: _save()
		"defeat":
			_auto_upgrade()
			if frames == 30:
				for z in game.zombies.duplicate():
					game.kill_zombie(z)
			if frames == 200: _save()
		"victory":
			_auto_upgrade()
			if frames == 300:
				game.waves.wave = 10
				game.waves.running = false
				game._on_wave_cleared()
			if frames == 460: _save()
	if frames > 60 * 400:
		get_tree().quit()


func _auto_upgrade() -> void:
	if game.state == GameManager.GState.UPGRADE and game.ui._overlay != null and not game.ui._choosing:
		game.ui._choosing = true
		game.ui._close_overlay()
		game.on_upgrade_chosen(["speed", "contagion", "horde", "fury"][randi() % 4])


func _bot() -> void:
	var l: Unit = game.leader
	if l == null or shot == "defeat":
		return
	var best: Unit = null
	var bd := INF
	for h in game.humans:
		if h.state != Unit.State.ACTIVE:
			continue
		var d := l.position.distance_squared_to(h.position)
		if d < bd:
			bd = d
			best = h
	game.player._touch_dir = Vector2.ZERO if best == null else (best.position - l.position).normalized()
	if shot == "game_start":
		game.player._touch_dir = Vector2.ZERO
	if shot == "game_horde":
		# Muestra el joystick dinámico en pantalla
		game.player._index = 0
		game.player._base = Vector2(360, 1050)
		game.player._thumb = game.player._base + game.player._touch_dir * 50.0


func _save() -> void:
	_done = true
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + shot + ".png"))
	print("[shot] saved ", shot)
	get_tree().quit()
