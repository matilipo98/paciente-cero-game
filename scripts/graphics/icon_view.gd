class_name IconView
extends Control
## Íconos vectoriales dibujados con primitivas (GFX-038, 044, 055, 066–073).
## Uso: IconView.make("coin", Vector2(36, 36))

@export var icon := "zombie"
var tint := Color(1, 1, 1, 1)


static func make(id: String, sz: Vector2) -> IconView:
	var v := IconView.new()
	v.icon = id
	v.custom_minimum_size = sz
	v.size = sz
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.pivot_offset = sz * 0.5
	return v


func set_icon(id: String) -> void:
	icon = id
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	match icon:
		"zombie": ActorArt.zombie_head_icon(self, c, s * 0.44)
		"coin": _coin(c, s * 0.46)
		"pause": _pause(c, s)
		"sound_on": _speaker(c, s, true)
		"sound_off": _speaker(c, s, false)
		"play": _play(c, s)
		"arrow_up": _arrow_up(c, s)
		"trophy": _trophy(c, s)
		"gear": _gear(c, s)
		"wave": _flag(c, s)
		"infections": _infections(c, s)
		"horde_max": _horde(c, s)
		"vibration": _vibration(c, s)
		"finger": _finger(c, s)
		"speed":
			_badge(c, s, Palette.CLOTH_BLUE, Palette.POLICE_DARK)
			_runner(c, s * 0.8, Palette.WHITE)
		"contagion":
			_badge(c, s, Palette.VIOLET, Palette.VIOLET.darkened(0.25))
			_mouth(c, s * 0.8)
		"resistance":
			_badge(c, s, Palette.HUMAN_SKIN, Palette.DANGER)
			_shield(c, s * 0.8)
		"horde":
			_badge(c, s, Palette.POSITIVE_LIGHT, Palette.ZOMBIE_OUTLINE)
			_horde(c, s * 0.82)
		"fury":
			_badge(c, s, Palette.GOLD, Palette.GOLD.darkened(0.25))
			_bolt(c, s * 0.8)
		"instinct":
			_badge(c, s, Palette.POLICE, Palette.POLICE_DARK)
			_eye(c, s * 0.8)


func _badge(c: Vector2, s: float, fill: Color, ring: Color) -> void:
	draw_circle(c + Vector2(0, s * 0.03), s * 0.47, Palette.with_alpha(Palette.INK, 0.12))
	draw_circle(c, s * 0.46, ring)
	draw_circle(c, s * 0.4, fill)
	draw_arc(c, s * 0.4, 0, TAU, 40, fill, 1.5, true)


func _coin(c: Vector2, r: float) -> void:
	draw_circle(c, r, Palette.GOLD.darkened(0.18))
	draw_arc(c, r, 0, TAU, 32, Palette.GOLD.darkened(0.25), 1.5, true)
	draw_circle(c + Vector2(-r * 0.06, -r * 0.08), r * 0.84, Palette.GOLD)
	draw_arc(c, r * 0.62, 0, TAU, 32, Palette.GOLD.darkened(0.12), maxf(1.5, r * 0.09), true)
	_star(c, r * 0.4, Palette.GOLD_LIGHT)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for j in 10:
		var rr := r if j % 2 == 0 else r * 0.45
		pts.append(c + Vector2.UP.rotated(j * TAU / 10.0) * rr)
	draw_colored_polygon(pts, col)


func _pause(c: Vector2, s: float) -> void:
	var w := s * 0.14
	var h := s * 0.42
	for dx in [-s * 0.12, s * 0.12]:
		var r := Rect2(c + Vector2(dx - w * 0.5, -h * 0.5), Vector2(w, h))
		draw_rect(r, Palette.WHITE)


func _speaker(c: Vector2, s: float, on: bool) -> void:
	var col := Palette.WHITE * tint
	var k := s * 0.5
	var pts := PackedVector2Array([
		c + Vector2(-0.55, -0.18) * k, c + Vector2(-0.25, -0.18) * k, c + Vector2(0.08, -0.5) * k,
		c + Vector2(0.08, 0.5) * k, c + Vector2(-0.25, 0.18) * k, c + Vector2(-0.55, 0.18) * k])
	draw_colored_polygon(pts, col)
	if on:
		draw_arc(c + Vector2(0.1, 0) * k, k * 0.3, -0.9, 0.9, 12, col, k * 0.11, true)
		draw_arc(c + Vector2(0.1, 0) * k, k * 0.55, -0.9, 0.9, 16, col, k * 0.11, true)
	else:
		draw_line(c + Vector2(0.25, -0.25) * k, c + Vector2(0.65, 0.25) * k, col, k * 0.12, true)
		draw_line(c + Vector2(0.25, 0.25) * k, c + Vector2(0.65, -0.25) * k, col, k * 0.12, true)


func _play(c: Vector2, s: float) -> void:
	var k := s * 0.42
	var pts := PackedVector2Array([c + Vector2(-0.55, -0.7) * k, c + Vector2(0.8, 0) * k, c + Vector2(-0.55, 0.7) * k])
	draw_colored_polygon(pts, Palette.WHITE)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Palette.INK, maxf(2.0, s * 0.06), true)


func _arrow_up(c: Vector2, s: float) -> void:
	var k := s * 0.45
	var pts := PackedVector2Array([
		c + Vector2(0, -0.85) * k, c + Vector2(0.8, 0) * k, c + Vector2(0.32, 0) * k, c + Vector2(0.32, 0.8) * k,
		c + Vector2(-0.32, 0.8) * k, c + Vector2(-0.32, 0) * k, c + Vector2(-0.8, 0) * k])
	draw_colored_polygon(pts, Palette.POSITIVE.darkened(0.08))
	pts.append(pts[0])
	draw_polyline(pts, Palette.INK, maxf(2.0, s * 0.05), true)


func _trophy(c: Vector2, s: float) -> void:
	var k := s * 0.5
	var gold := Palette.GOLD.darkened(0.05)
	draw_arc(c + Vector2(-0.52, -0.38) * k, k * 0.24, PI * 0.5, PI * 1.5, 12, gold.darkened(0.15), k * 0.1, true)
	draw_arc(c + Vector2(0.52, -0.38) * k, k * 0.24, -PI * 0.5, PI * 0.5, 12, gold.darkened(0.15), k * 0.1, true)
	var cup := PackedVector2Array()
	cup.append(c + Vector2(-0.55, -0.7) * k)
	cup.append(c + Vector2(0.55, -0.7) * k)
	for i in 9:
		var a := float(i) / 8.0 * PI
		cup.append(c + Vector2(cos(a) * 0.55, -0.3 + sin(a) * 0.5) * k)
	draw_colored_polygon(cup, gold)
	draw_rect(Rect2(c + Vector2(-0.1, 0.18) * k, Vector2(0.2, 0.3) * k), gold.darkened(0.12))
	draw_rect(Rect2(c + Vector2(-0.4, 0.48) * k, Vector2(0.8, 0.22) * k), gold.darkened(0.2))
	draw_circle(c + Vector2(-0.2, -0.45) * k, k * 0.1, Palette.GOLD_LIGHT)


func _gear(c: Vector2, s: float) -> void:
	var k := s * 0.45
	var col := Palette.INK
	for i in 8:
		var d := Vector2.RIGHT.rotated(i * TAU / 8.0)
		draw_line(c + d * k * 0.5, c + d * k * 0.92, col, k * 0.32)
	draw_circle(c, k * 0.68, col)
	draw_circle(c, k * 0.28, Palette.CLOTH_BLUE)


func _flag(c: Vector2, s: float) -> void:
	var k := s * 0.45
	draw_line(c + Vector2(-0.5, -0.85) * k, c + Vector2(-0.5, 0.9) * k, Palette.INK_SOFT, k * 0.14, true)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-0.45, -0.85) * k, c + Vector2(0.75, -0.55) * k, c + Vector2(-0.45, -0.1) * k]), Palette.VIOLET)
	draw_circle(c + Vector2(0.3, 0.45) * k, k * 0.3, Palette.POSITIVE)
	draw_line(c + Vector2(0.15, 0.45) * k, c + Vector2(0.27, 0.58) * k, Palette.WHITE, k * 0.1, true)
	draw_line(c + Vector2(0.27, 0.58) * k, c + Vector2(0.48, 0.32) * k, Palette.WHITE, k * 0.1, true)


func _infections(c: Vector2, s: float) -> void:
	var k := s * 0.45
	ActorArt.disc(self, c + Vector2(-0.1, 0.1) * k, k * 0.7, Palette.HUMAN_SKIN, Palette.OUTLINE)
	draw_circle(c + Vector2(-0.15, -0.05) * k, k * 0.58, Palette.HAIR_BROWN)
	_star(c + Vector2(0.6, -0.55) * k, k * 0.42, Palette.POSITIVE.darkened(0.1))
	draw_circle(c + Vector2(0.75, 0.1) * k, k * 0.12, Palette.POSITIVE)


func _horde(c: Vector2, s: float) -> void:
	var r := s * 0.2
	ActorArt.zombie_head_icon(self, c + Vector2(-s * 0.19, s * 0.08), r)
	ActorArt.zombie_head_icon(self, c + Vector2(s * 0.19, s * 0.08), r)
	ActorArt.zombie_head_icon(self, c + Vector2(0, -s * 0.12), r * 1.05)


func _vibration(c: Vector2, s: float) -> void:
	var k := s * 0.45
	var r := Rect2(c + Vector2(-0.35, -0.7) * k, Vector2(0.7, 1.4) * k)
	draw_rect(r, Palette.WHITE)
	draw_rect(r.grow(-k * 0.1), Palette.INK_SOFT)
	for sx in [-1.0, 1.0]:
		draw_arc(c, k * 0.62, -0.5 + (PI if sx < 0 else 0.0), 0.5 + (PI if sx < 0 else 0.0), 8, Palette.WHITE, k * 0.1, true)
		draw_arc(c, k * 0.85, -0.5 + (PI if sx < 0 else 0.0), 0.5 + (PI if sx < 0 else 0.0), 8, Palette.WHITE, k * 0.1, true)


func _finger(c: Vector2, s: float) -> void:
	var k := s * 0.45
	# Flechas de arrastre
	for sx in [-1.0, 1.0]:
		var tip := c + Vector2(sx * 0.95, -0.35) * k
		draw_line(c + Vector2(sx * 0.45, -0.35) * k, tip, Palette.VIOLET, k * 0.12, true)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(sx * 0.12, 0) * k,
			tip + Vector2(-sx * 0.15, -0.2) * k, tip + Vector2(-sx * 0.15, 0.2) * k]), Palette.VIOLET)
	# Dedo
	var fr := Rect2(c + Vector2(-0.2, -0.55) * k, Vector2(0.4, 1.1) * k)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.HUMAN_SKIN
	sb.set_corner_radius_all(int(k * 0.2))
	sb.border_color = Palette.INK
	sb.set_border_width_all(2)
	sb.anti_aliasing = true
	draw_style_box(sb, fr)
	draw_circle(c + Vector2(0, -0.35) * k, k * 0.1, Palette.HUMAN_SKIN_LIGHT)


func _runner(c: Vector2, s: float, col: Color) -> void:
	var k := s * 0.42
	var w := k * 0.16
	var head := c + Vector2(0.18, -0.62) * k
	draw_circle(head, k * 0.17, col)
	var hip := c + Vector2(-0.08, 0.12) * k
	var neck := c + Vector2(0.08, -0.38) * k
	draw_line(neck, hip, col, w, true)
	draw_line(neck + Vector2(0, 0.08) * k, c + Vector2(0.45, -0.1) * k, col, w, true)
	draw_line(neck + Vector2(0, 0.08) * k, c + Vector2(-0.35, -0.25) * k, col, w, true)
	draw_line(hip, c + Vector2(0.35, 0.45) * k, col, w, true)
	draw_line(c + Vector2(0.35, 0.45) * k, c + Vector2(0.25, 0.8) * k, col, w, true)
	draw_line(hip, c + Vector2(-0.4, 0.75) * k, col, w, true)
	for i in 2:
		var y := -0.15 + i * 0.3
		draw_line(c + Vector2(-0.95, y) * k, c + Vector2(-0.6, y) * k, col, w * 0.7, true)


func _mouth(c: Vector2, s: float) -> void:
	var k := s * 0.42
	var pts := PackedVector2Array()
	for i in 17:
		var a := float(i) / 16.0 * PI
		pts.append(c + Vector2(cos(a) * 0.75, -0.15 + sin(a) * 0.65) * k)
	draw_colored_polygon(pts, Palette.INK)
	draw_rect(Rect2(c + Vector2(-0.75, -0.25) * k, Vector2(1.5, 0.12) * k), Palette.INK)
	# Dos dientes amigables
	for dx in [-0.3, 0.12]:
		var r := Rect2(c + Vector2(dx, -0.15) * k, Vector2(0.22, 0.26) * k)
		draw_rect(r, Palette.WHITE)
	draw_circle(c + Vector2(0, 0.32) * k, k * 0.22, Palette.CLOTH_PINK)


func _shield(c: Vector2, s: float) -> void:
	var k := s * 0.45
	var pts := PackedVector2Array()
	pts.append(c + Vector2(-0.7, -0.6) * k)
	pts.append(c + Vector2(0.7, -0.6) * k)
	for i in 11:
		var a := float(i) / 10.0 * PI
		pts.append(c + Vector2(cos(a) * 0.7, -0.15 + sin(a) * 0.95) * k)
	draw_colored_polygon(pts, Palette.WHITE)
	pts.append(pts[0])
	draw_polyline(pts, Palette.DANGER.darkened(0.1), k * 0.1, true)
	# Corazón
	var hc := c + Vector2(0, 0.05) * k
	draw_circle(hc + Vector2(-0.18, -0.1) * k, k * 0.2, Palette.DANGER)
	draw_circle(hc + Vector2(0.18, -0.1) * k, k * 0.2, Palette.DANGER)
	draw_colored_polygon(PackedVector2Array([hc + Vector2(-0.37, -0.03) * k, hc + Vector2(0.37, -0.03) * k, hc + Vector2(0, 0.4) * k]), Palette.DANGER)


func _bolt(c: Vector2, s: float) -> void:
	var k := s * 0.45
	var pts := PackedVector2Array([
		c + Vector2(0.15, -0.9) * k, c + Vector2(-0.5, 0.1) * k, c + Vector2(-0.05, 0.1) * k,
		c + Vector2(-0.2, 0.9) * k, c + Vector2(0.5, -0.15) * k, c + Vector2(0.05, -0.15) * k])
	draw_colored_polygon(pts, Palette.WHITE)
	pts.append(pts[0])
	draw_polyline(pts, Palette.GOLD.darkened(0.35), k * 0.09, true)
	_star(c + Vector2(0.6, -0.6) * k, k * 0.22, Palette.WHITE)


func _eye(c: Vector2, s: float) -> void:
	var k := s * 0.42
	var pts := PackedVector2Array()
	for i in 13:
		var a := float(i) / 12.0 * PI
		pts.append(c + Vector2(-cos(a) * 0.7, -sin(a) * 0.42) * k)
	for i in range(1, 12):
		var a := float(i) / 12.0 * PI
		pts.append(c + Vector2(cos(a) * 0.7, sin(a) * 0.42) * k)
	draw_colored_polygon(pts, Palette.WHITE)
	draw_circle(c, k * 0.26, Palette.INK)
	draw_circle(c + Vector2(-0.08, -0.08) * k, k * 0.08, Palette.WHITE)
	# Ondas de radar
	draw_arc(c, k * 0.95, -0.5, 0.5, 10, Palette.WHITE, k * 0.09, true)
	draw_arc(c, k * 0.95, PI - 0.5, PI + 0.5, 10, Palette.WHITE, k * 0.09, true)
