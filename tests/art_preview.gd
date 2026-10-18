extends SceneTree
## Renderiza una lámina con los enemigos armados en 3 direcciones (revisión de arte).
## Uso (con display / xvfb): godot --path . -s res://tests/art_preview.gd

class Sheet extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 720, 1280), Color("#D9B48C"))
		var kinds := [ActorArt.Kind.SURVIVOR, ActorArt.Kind.BIKER, ActorArt.Kind.SOLDIER, ActorArt.Kind.POLICE]
		var dirs := [Vector2.DOWN, Vector2.RIGHT, Vector2(1, -1).normalized()]
		for i in kinds.size():
			for j in dirs.size():
				var cloths := [Palette.SURV_SHIRT, Palette.SURV_SHIRT, Palette.SOLDIER_UNIFORM, Palette.POLICE]
				var lk := {"kind": kinds[i], "cloth": cloths[i], "hair": Palette.SURV_HAIR, "skin": Palette.HUMAN_SKIN, "variant": 0}
				var c := Vector2(130 + j * 230, 110 + i * 200)
				draw_set_transform(c, 0.0, Vector2.ONE * 2.6)
				ActorArt.draw_actor(self, lk.kind, Vector2.ZERO, 20.0, dirs[j], 0.6, 1.0, lk.cloth, lk.hair, lk.skin, Color(0, 0, 0, 0), lk.variant)
		for j in 3:
			draw_set_transform(Vector2(130 + j * 230, 1020), 0.0, Vector2.ONE * 1.5)
			ActorArt.draw_tank(self, Vector2.ZERO, 46.0, dirs[j], dirs[(j + 1) % 3], 0.3, Color(0, 0, 0, 0), j == 2, 0.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

var _f := 0

func _initialize() -> void:
	root.add_child(Sheet.new())

func _process(_d: float) -> bool:
	_f += 1
	if _f == 10:
		var img := root.get_texture().get_image()
		img.save_png("/tmp/claude-0/art_v4.png")
		print("[art] saved")
		return true
	return false
