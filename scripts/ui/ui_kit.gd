class_name UIKit
extends RefCounted
## Componentes de interfaz reutilizables (tema, botones cápsula, pastillas, etiquetas).
## Escala tipográfica (GFX-087): H1 54, H2 40, H3 30, cuerpo 24, HUD 28–36.

const H1 := 54
const H2 := 40
const H3 := 30
const BODY := 24
const SMALL := 20

static var _font: Font = null
static var _theme: Theme = null


## Fuente del sistema redondeada/gruesa si existe; si no, la fuente por defecto de Godot.
static func font() -> Font:
	if _font == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Nunito", "Varela Round", "Quicksand", "Baloo 2",
			"Arial Rounded MT Bold", "Roboto", "Noto Sans", "Helvetica Neue", "Segoe UI",
			"DejaVu Sans", "sans-serif"])
		sf.font_weight = 800
		sf.allow_system_fallback = true
		_font = sf
	return _font


static func theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		_theme.default_font = font()
		_theme.default_font_size = BODY
	return _theme


static func label(text: String, size: int, color: Color, outline: int = 0,
		outline_color: Color = Palette.INK, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER,
		wrap_width: float = 0.0) -> Label:
	var l := Label.new()
	if wrap_width > 0.0:
		# El autowrap debe activarse antes del texto para que el ancho mínimo no crezca.
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(wrap_width, 0)
	l.text = text
	var ls := LabelSettings.new()
	ls.font = font()
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = outline_color
	l.label_settings = ls
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func box(bg: Color, radius: float, border: Color = Color(0, 0, 0, 0), bw: int = 0,
		shadow: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	if shadow:
		sb.shadow_color = Color(Palette.INK, 0.14)
		sb.shadow_size = 10
		sb.shadow_offset = Vector2(0, 6)
	return sb


static func panel(rect: Rect2, bg: Color, radius: float, border: Color = Color(0, 0, 0, 0),
		bw: int = 0, shadow: bool = false) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", box(bg, radius, border, bw, shadow))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Botón cápsula con borde oscuro, sombra inferior y rebote al tocar (AN-23).
static func button(text: String, bg: Color, fg: Color, sz: Vector2, font_size: int = 30,
		icon_id: String = "", outline_text: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = sz
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	var r := sz.y * 0.5
	var normal := box(bg, r, Palette.INK, 4)
	normal.shadow_color = Color(Palette.INK, 0.9)
	normal.shadow_size = 0
	normal.shadow_offset = Vector2(0, 5)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.08)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.darkened(0.08)
	pressed.shadow_offset = Vector2(0, 2)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", normal)
	b.add_theme_font_override("font", font())
	b.add_theme_font_size_override("font_size", font_size)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, fg)
	if outline_text:
		b.add_theme_constant_override("outline_size", 10)
		b.add_theme_color_override("font_outline_color", Palette.INK)
	if icon_id != "":
		var ic := IconView.make(icon_id, Vector2(sz.y * 0.55, sz.y * 0.55))
		b.add_child(ic)
		ic.position = Vector2(sz.y * 0.42, sz.y * 0.22)
		# Desplaza el texto para dejar lugar al ícono
		b.add_theme_constant_override("h_separation", 0)
		normal.content_margin_left = sz.y * 0.75
		hover.content_margin_left = sz.y * 0.75
		pressed.content_margin_left = sz.y * 0.75
	add_press_feedback(b)
	return b


## Botón cuadrado de ícono (pausa, sonido).
static func icon_button(icon_id: String, bg: Color, sz: Vector2) -> Button:
	var b := Button.new()
	b.custom_minimum_size = sz
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	var normal := box(bg, sz.x * 0.28, Palette.INK, 3)
	normal.shadow_color = Color(Palette.INK, 0.9)
	normal.shadow_offset = Vector2(0, 4)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.darkened(0.1)
	pressed.shadow_offset = Vector2(0, 1)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ic := IconView.make(icon_id, sz * 0.7)
	ic.position = sz * 0.15
	ic.name = "Icon"
	b.add_child(ic)
	add_press_feedback(b)
	return b


static func add_press_feedback(b: Control) -> void:
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.pivot_offset = b.size * 0.5
	if b is BaseButton:
		var bb := b as BaseButton
		bb.button_down.connect(func() -> void:
			var tw := b.create_tween()
			tw.tween_property(b, "scale", Vector2.ONE * 0.95, 0.06))
		bb.button_up.connect(func() -> void:
			var tw := b.create_tween()
			tw.tween_property(b, "scale", Vector2.ONE, 0.06))
		bb.pressed.connect(func() -> void: AudioManager.play("tap", 0.05, -6.0))


## Rebote de escala para contadores (AN-15 / AN-16).
static func bounce(c: Control, amount: float = 1.15, dur: float = 0.15) -> void:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2.ONE * amount
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func full_rect(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0


## Margen superior seguro (notch) en coordenadas del viewport. Sólo en móviles.
static func top_inset(vp: Viewport) -> float:
	if not OS.has_feature("mobile"):
		return 0.0
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return 0.0
	return float(safe.position.y) * vp.get_visible_rect().size.y / float(win.y)


static func bottom_inset(vp: Viewport) -> float:
	if not OS.has_feature("mobile"):
		return 0.0
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return 0.0
	return maxf(0.0, float(win.y - safe.end.y)) * vp.get_visible_rect().size.y / float(win.y)
