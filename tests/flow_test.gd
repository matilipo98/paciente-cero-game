extends Node
## Recorre el flujo de pantallas: menú → JUGAR → pausa → REINTENTAR → MENÚ.
## godot --headless --fixed-fps 60 --path . res://tests/flow_test.tscn

var step := 0
var t := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_move_to_root.call_deferred()


func _move_to_root() -> void:
	var tree := get_tree()
	get_parent().remove_child(self)
	tree.root.add_child(self)
	tree.change_scene_to_file("res://scenes/main/main_menu.tscn")


func _physics_process(_d: float) -> void:
	t += 1
	var cs := get_tree().current_scene
	if cs == null:
		return
	match step:
		0:
			if t > 30 and cs.name == "MainMenu":
				print("[flow] menu ok"); cs._on_play(); step = 1; t = 0
		1:
			if t > 60 and cs.name == "Game":
				print("[flow] game ok"); cs.pause_game(); step = 2; t = 0
		2:
			if t > 10:
				print("[flow] paused=", get_tree().paused); cs.restart(); step = 3; t = 0
		3:
			if t > 60 and cs.name == "Game" and not get_tree().paused:
				print("[flow] restart ok, wave state=", cs.state); cs.go_to_menu(); step = 4; t = 0
		4:
			if t > 60 and cs.name == "MainMenu":
				print("[flow] back to menu ok"); cs._show_records(); cs._close(); cs._show_settings(); cs._close()
				print("[flow] ALL OK"); get_tree().quit()
	if t > 600:
		print("[flow] FAIL at step ", step); get_tree().quit()
