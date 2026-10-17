class_name LogoView
extends Control
## Logo PACIENTE CERO (GFX-052): texto redondeado en dos tonos pastel con borde
## oscuro y la cabeza de zombi ocupando la letra O. Pequeño rebote cada 1.8 s.

var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var font := UIKit.font()
	var w := size.x
	var bounce := absf(sin(_t * PI / 1.8)) * 6.0
	var line1 := "PACIENTE"
	var fs1 := 92
	var y1 := 100.0 - bounce
	_outlined(font, Vector2(0, y1), line1, w, fs1, Palette.ZOMBIE_SKIN, -0.03)

	var line2 := "CER"
	var fs2 := 104
	var tw := font.get_string_size(line2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
	var head_r := 46.0
	var total := tw + head_r * 2.0 + 6.0
	var x0 := (w - total) * 0.5
	var y2 := 205.0 - absf(sin((_t + 0.25) * PI / 1.8)) * 6.0
	_outlined(font, Vector2(x0, y2), line2, -1, fs2, Palette.VIOLET, 0.0)
	# Virus lila alrededor de la "O"
	var hc := Vector2(x0 + tw + head_r + 6.0, y2 - 36.0)
	for i in 9:
		var a := i * TAU / 9.0 + _t * 0.4
		var p := hc + Vector2.RIGHT.rotated(a) * (head_r + 14.0)
		draw_line(hc + Vector2.RIGHT.rotated(a) * head_r, p, Palette.VIOLET.darkened(0.35), 4.0, true)
		draw_circle(p, 6.0, Palette.VIOLET.darkened(0.35))
	draw_circle(hc, head_r + 10.0, Palette.WHITE)
	draw_circle(hc, head_r + 5.0, Palette.INK)
	ActorArt.zombie_head_icon(self, hc, head_r)


func _outlined(font: Font, pos: Vector2, text: String, width: float, fs: int, fill: Color, _skew: float) -> void:
	var align := HORIZONTAL_ALIGNMENT_CENTER if width > 0 else HORIZONTAL_ALIGNMENT_LEFT
	draw_string_outline(font, pos + Vector2(0, 6), text, align, width, fs, 26, Color(Palette.INK, 0.25))
	draw_string_outline(font, pos, text, align, width, fs, 26, Palette.WHITE)
	draw_string_outline(font, pos, text, align, width, fs, 14, Palette.INK)
	draw_string(font, pos, text, align, width, fs, fill)
	# Brillo superior suave
	draw_string(font, pos + Vector2(0, -3), text, align, width, fs, Color(fill.lightened(0.35), 0.35))
	draw_string(font, pos + Vector2(0, 0), text, align, width, fs, Color(fill, 0.75))
