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
	var lv_env := OS.get_environment("LEVEL")
	GameManager.selected_level = int(lv_env) if lv_env != "" else 1
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
		"menu_levels":
			if frames == 5:
				SaveManager.unlocked_level = 4
				SaveManager.best_wave_by_level = {1: 10, 2: 15, 3: 20, 4: 9}
				menu._show_levels()
			if frames == 40: _save()
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
		"game_at":
			_auto_upgrade()
			# STARTWAVE=n salta a esa oleada con ALLIES zombis extra (para capturar enemigos tardíos).
			var sw := int(OS.get_environment("STARTWAVE")) if OS.get_environment("STARTWAVE") != "" else 0
			if sw > 0 and frames == 150:
				game.spawn_bonus_allies(int(OS.get_environment("ALLIES")) if OS.get_environment("ALLIES") != "" else 30)
				for h in game.humans: h.queue_free()
				game.humans.clear()
				for p in game.police: p.queue_free()
				game.police.clear()
				game.waves.start_wave(sw)
				game.ui.set_wave(sw)
			if frames == int(OS.get_environment("SHOTFRAME")): _save()
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
				game.waves.wave = game.waves.total_waves()
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
	var fname := shot if OS.get_environment("SHOTNAME") == "" else OS.get_environment("SHOTNAME")
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + fname + ".png"))
	print("[shot] saved ", shot)
	get_tree().quit()
