extends CanvasLayer
## Transición rápida entre pantallas (GFX-085): fundido crema de 0.2–0.3 s.

var _rect: ColorRect
var _busy := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Palette.CREAM
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	add_child(_rect)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)


func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_rect, "modulate:a", 1.0, 0.2)
	tw.tween_callback(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file(path))
	tw.tween_interval(0.05)
	tw.tween_property(_rect, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func() -> void:
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_busy = false)
