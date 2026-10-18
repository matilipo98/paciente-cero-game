class_name UIManager
extends CanvasLayer
## Interfaz de la partida: HUD, anuncios, combo, fiebre, tutorial,
## pantalla de mejoras, pausa y resultados (victoria / derrota).

var gm  # GameManager

var root: Control
var hud: Control
var _top := 0.0
var _w := 720.0
var _h := 1280.0

# HUD
var _zombie_pill: Panel
var _zombie_label: Label
var _wave_pill: Panel
var _wave_label: Label
var _wave_bar: WaveBar
var _timer_label: Label
var _score_pill: Panel
var _score_label: Label
var _pause_btn: Button
var _combo_label: Label
var _fever_box: Panel
var _fever_bar: WaveBar
var _banner: Label
var _toast: Label
var _tutorial: Control
var _fever_tint: ColorRect

var _overlay: Control = null
var _last_second := -1
var _choosing := false


# ---------------------------------------------------------------------------
# Barras simples dibujadas a mano (oleada / fiebre)
# ---------------------------------------------------------------------------

class WaveBar extends Control:
	var value := 1.0
	var fill := Palette.POSITIVE
	var track := Palette.VIOLET_LIGHT
	var knob := true

	func _draw() -> void:
		var r := size.y * 0.5
		var sb := UIKit.box(track, r, Color(Palette.INK, 0.6), 2)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var w := maxf(size.y, size.x * clampf(value, 0.0, 1.0))
		if value > 0.0:
			draw_style_box(UIKit.box(fill, r), Rect2(Vector2(2, 2), Vector2(w - 4, size.y - 4)))
			draw_line(Vector2(r, size.y * 0.32), Vector2(maxf(r, w - r), size.y * 0.32), Color(1, 1, 1, 0.45), 3.0, true)
		if knob:
			ActorArt.zombie_head_icon(self, Vector2(r, r), r * 0.95)


class Confetti extends Control:
	var _p: Array = []
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cols := [Palette.POSITIVE, Palette.VIOLET, Palette.GOLD, Palette.CLOTH_PINK, Palette.CLOTH_BLUE]
		for i in 90:
			_p.append({
				"pos": Vector2(randf() * size.x, randf_range(-size.y * 0.5, -10)),
				"vel": Vector2(randf_range(-40, 40), randf_range(160, 320)),
				"rot": randf() * TAU, "spin": randf_range(-6, 6),
				"col": cols[i % cols.size()], "sq": randf() < 0.5, "s": randf_range(6, 11)})

	func _process(delta: float) -> void:
		_t += delta
		for p in _p:
			p.pos += p.vel * delta
			p.rot += p.spin * delta
		modulate.a = clampf(3.0 - _t, 0.0, 1.0)
		if _t > 3.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		for p in _p:
			var s: float = p.s
			if p.sq:
				draw_set_transform(p.pos, p.rot, Vector2.ONE)
				draw_rect(Rect2(-s * 0.5, -s * 0.5, s, s * 0.6), p.col)
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			else:
				draw_circle(p.pos, s * 0.45, p.col)


# ---------------------------------------------------------------------------
# Construcción
# ---------------------------------------------------------------------------

func setup(game) -> void:
	gm = game
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var vs := get_viewport().get_visible_rect().size
	_w = vs.x
	_h = vs.y
	_top = UIKit.top_inset(get_viewport()) + 14.0

	root = Control.new()
	root.theme = UIKit.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	UIKit.full_rect(root)

	_fever_tint = ColorRect.new()
	_fever_tint.color = Color(Palette.VIOLET, 0.0)
	_fever_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fever_tint)
	UIKit.full_rect(_fever_tint)

	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	UIKit.full_rect(hud)
	_build_hud()

	gm.player.blocked_top = _top + 128.0
	gm.player.first_move.connect(_on_first_move)
	if not SaveManager.tutorial_done:
		_build_tutorial()


func _build_hud() -> void:
	var dark := Color(Palette.INK, 0.88)
	# Contador de zombis (GFX-037 a GFX-039)
	_zombie_pill = UIKit.panel(Rect2(22, _top, 160, 68), dark, 34)
	hud.add_child(_zombie_pill)
	var zi := IconView.make("zombie", Vector2(48, 48))
	zi.position = Vector2(10, 10)
	_zombie_pill.add_child(zi)
	_zombie_label = UIKit.label("x 1", 34, Palette.WHITE, 0, Palette.INK, HORIZONTAL_ALIGNMENT_LEFT)
	_zombie_label.position = Vector2(66, 8)
	_zombie_label.size = Vector2(90, 52)
	_zombie_pill.add_child(_zombie_label)

	# Oleada + barra + reloj (GFX-040 a GFX-042)
	_wave_pill = UIKit.panel(Rect2(_w * 0.5 - 125, _top, 250, 85), dark, 24)
	hud.add_child(_wave_pill)
	_wave_label = UIKit.label("OLEADA 1/%d" % gm.waves.total_waves(), 26, Palette.WHITE)
	_wave_label.position = Vector2(0, 4)
	_wave_label.size = Vector2(250, 36)
	_wave_pill.add_child(_wave_label)
	_wave_bar = WaveBar.new()
	_wave_bar.position = Vector2(20, 46)
	_wave_bar.size = Vector2(210, 24)
	_wave_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_pill.add_child(_wave_bar)
	_timer_label = UIKit.label("00:35", 22, Palette.INK, 6, Palette.CREAM)
	_timer_label.position = Vector2(_w * 0.5 - 60, _top + 86)
	_timer_label.size = Vector2(120, 30)
	hud.add_child(_timer_label)

	# Pausa (GFX-045)
	_pause_btn = UIKit.icon_button("pause", Palette.VIOLET, Vector2(58, 58))
	_pause_btn.position = Vector2(_w - 22 - 58, _top + 4)
	_pause_btn.pressed.connect(func() -> void: gm.pause_game())
	hud.add_child(_pause_btn)

	# Puntuación (GFX-043 / GFX-044)
	_score_pill = UIKit.panel(Rect2(_w - 22 - 150, _top + 72, 150, 52), dark, 26)
	hud.add_child(_score_pill)
	var coin := IconView.make("coin", Vector2(38, 38))
	coin.position = Vector2(8, 7)
	_score_pill.add_child(coin)
	_score_label = UIKit.label("0", 28, Palette.WHITE, 0, Palette.INK, HORIZONTAL_ALIGNMENT_LEFT)
	_score_label.position = Vector2(52, 4)
	_score_label.size = Vector2(94, 44)
	_score_pill.add_child(_score_label)

	# Combo (GFX-048)
	_combo_label = UIKit.label("", 36, Palette.WHITE, 12, Palette.VIOLET)
	_combo_label.position = Vector2(_w * 0.5 - 150, _top + 124)
	_combo_label.size = Vector2(300, 48)
	_combo_label.modulate.a = 0.0
	hud.add_child(_combo_label)

	# Fiebre Zombi (GFX-049)
	_fever_box = UIKit.panel(Rect2(_w * 0.5 - 110, _top + 176, 220, 50), Color(Palette.INK, 0.9), 25,
		Palette.VIOLET, 3)
	_fever_box.visible = false
	hud.add_child(_fever_box)
	var fl := UIKit.label("FIEBRE ZOMBI", 22, Palette.ZOMBIE_SKIN)
	fl.position = Vector2(0, 2)
	fl.size = Vector2(220, 28)
	_fever_box.add_child(fl)
	_fever_bar = WaveBar.new()
	_fever_bar.knob = false
	_fever_bar.fill = Palette.VIOLET
	_fever_bar.track = Color(Palette.WHITE, 0.2)
	_fever_bar.position = Vector2(24, 31)
	_fever_bar.size = Vector2(172, 12)
	_fever_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fever_box.add_child(_fever_bar)

	# Anuncios (GFX-064 / GFX-065) y mensajes cortos
	_banner = UIKit.label("", UIKit.H1, Palette.WHITE, 16, Palette.INK)
	_banner.position = Vector2(0, _h * 0.40)
	_banner.size = Vector2(_w, 90)
	_banner.modulate.a = 0.0
	hud.add_child(_banner)
	_toast = UIKit.label("", 28, Palette.WHITE, 10, Palette.INK)
	_toast.position = Vector2(0, _h * 0.40 + 92)
	_toast.size = Vector2(_w, 44)
	_toast.modulate.a = 0.0
	hud.add_child(_toast)


func _build_tutorial() -> void:
	# GFX-063: "ARRASTRÁ PARA MOVERTE" con dibujo de dedo; desaparece al moverse.
	_tutorial = UIKit.panel(Rect2(_w * 0.5 - 225, _h * 0.70, 450, 170), Color(Palette.CREAM, 0.95), 28,
		Palette.INK, 3, true)
	hud.add_child(_tutorial)
	var fing := IconView.make("finger", Vector2(96, 96))
	fing.position = Vector2(177, 8)
	_tutorial.add_child(fing)
	var t := UIKit.label("ARRASTRÁ PARA MOVERTE", 28, Palette.INK)
	t.position = Vector2(0, 104)
	t.size = Vector2(450, 40)
	_tutorial.add_child(t)
	var s := UIKit.label("Alcanzá humanos para contagiarlos", 18, Palette.INK_SOFT)
	s.position = Vector2(0, 136)
	s.size = Vector2(450, 26)
	_tutorial.add_child(s)
	var tw := fing.create_tween().set_loops()
	tw.tween_property(fing, "position:x", 205.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(fing, "position:x", 149.0, 0.6).set_trans(Tween.TRANS_SINE)


func _on_first_move() -> void:
	SaveManager.set_tutorial_done()
	if _tutorial != null and is_instance_valid(_tutorial):
		var t := _tutorial
		_tutorial = null
		var tw := t.create_tween()
		tw.tween_property(t, "modulate:a", 0.0, 0.3)
		tw.tween_callback(t.queue_free)


# ---------------------------------------------------------------------------
# Actualizaciones del HUD
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if gm == null:
		return
	if gm.waves.running:
		_wave_bar.value = gm.waves.progress()
		_wave_bar.queue_redraw()
		var secs := int(ceil(gm.waves.time_left))
		if secs != _last_second:
			_last_second = secs
			_timer_label.text = "00:%02d" % secs
	if _fever_box.visible:
		_fever_bar.value = gm.fever_timer / Balance.FEVER_DURATION
		_fever_bar.queue_redraw()
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU / 0.8)
		_fever_box.scale = Vector2.ONE * (1.0 + pulse * 0.05)
		_fever_tint.color = Color(Palette.VIOLET, 0.05 + pulse * 0.04)


func update_zombies(n: int) -> void:
	_zombie_label.text = "x %d" % n
	UIKit.bounce(_zombie_label)


func update_score(s: int) -> void:
	_score_label.text = str(s)
	UIKit.bounce(_score_label, 1.12)


func update_leader_hp(_hp: float) -> void:
	_zombie_pill.modulate = Palette.DANGER
	var tw := _zombie_pill.create_tween()
	tw.tween_property(_zombie_pill, "modulate", Color.WHITE, 0.25)


func set_wave(n: int) -> void:
	_wave_label.text = "OLEADA %d/%d" % [n, gm.waves.total_waves()]
	_wave_bar.value = 1.0
	_wave_bar.queue_redraw()
	UIKit.bounce(_wave_pill, 1.08, 0.3)


func on_combo(c: int) -> void:
	if c < 2:
		var tw := _combo_label.create_tween()
		tw.tween_property(_combo_label, "modulate:a", 0.0, 0.3)
		return
	_combo_label.text = "COMBO x%d" % c
	_combo_label.modulate.a = 1.0
	_combo_label.pivot_offset = _combo_label.size * 0.5
	var big := 1.35 if c % Balance.FEVER_COMBO == 0 else 1.18
	_combo_label.scale = Vector2.ONE * big
	var tw2 := _combo_label.create_tween()
	tw2.tween_property(_combo_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_fever(on: bool) -> void:
	if on:
		if not _fever_box.visible:
			_fever_box.visible = true
			_fever_box.pivot_offset = _fever_box.size * 0.5
			show_banner("¡FIEBRE ZOMBI!", Palette.ZOMBIE_SKIN, Palette.VIOLET.darkened(0.3), 0.9)
		_combo_label.label_settings.outline_color = Palette.ZOMBIE_OUTLINE
	else:
		_fever_box.visible = false
		_fever_tint.color = Color(Palette.VIOLET, 0.0)
		_combo_label.label_settings.outline_color = Palette.VIOLET


## Rótulo central: escala y fade en menos de 1 s (AN-17).
func show_banner(text: String, col: Color = Palette.WHITE, outline: Color = Palette.INK, hold: float = 0.6) -> void:
	_banner.text = text
	_banner.label_settings.font_color = col
	_banner.label_settings.outline_color = outline
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2.ONE * 0.6
	_banner.modulate.a = 0.0
	var tw := _banner.create_tween()
	tw.set_parallel(true)
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_banner, "modulate:a", 1.0, 0.15)
	tw.chain().tween_interval(hold)
	tw.chain().tween_property(_banner, "modulate:a", 0.0, 0.25)


## Presentación del nivel al entrar: "NIVEL 2" y el nombre del mapa.
func announce_level(lv: int) -> void:
	show_banner("NIVEL %d" % lv, Palette.GOLD, Palette.INK, 0.6)
	toast(Levels.level_name(lv), Palette.WHITE)


func announce_wave(n: int) -> void:
	var txt := "OLEADA %d" % n
	if n == gm.waves.total_waves():
		txt = "¡OLEADA FINAL!"
	show_banner(txt, Palette.WHITE, Palette.INK, 0.5)


func wave_cleared(_n: int) -> void:
	show_banner("¡OLEADA SUPERADA!", Palette.ZOMBIE_SKIN, Palette.INK, 0.8)


func toast(text: String, col: Color) -> void:
	_toast.text = text
	_toast.label_settings.font_color = col.lightened(0.35)
	_toast.modulate.a = 1.0
	_toast.position.y = _h * 0.40 + 92
	var tw := _toast.create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


# ---------------------------------------------------------------------------
# Overlays
# ---------------------------------------------------------------------------

func _open_overlay(curtain_alpha: float) -> Control:
	_close_overlay()
	var o := Control.new()
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(o)
	UIKit.full_rect(o)
	var cur := ColorRect.new()
	cur.color = Color(Palette.INK, curtain_alpha)
	cur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.add_child(cur)
	UIKit.full_rect(cur)
	o.modulate.a = 0.0
	var tw := o.create_tween()
	tw.tween_property(o, "modulate:a", 1.0, 0.2)
	_overlay = o
	return o


func _close_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


## Pausa (GFX-057): cortina 55 % + tarjeta crema con acciones.
func show_pause() -> void:
	var o := _open_overlay(0.55)
	var card := UIKit.panel(Rect2(_w * 0.5 - 260, _h * 0.5 - 250, 520, 480), Palette.CREAM, 36,
		Palette.INK, 4, true)
	o.add_child(card)
	var t := UIKit.label("PAUSA", UIKit.H1, Palette.INK, 4, Palette.INK)
	t.position = Vector2(0, 30)
	t.size = Vector2(520, 70)
	card.add_child(t)
	var y := 130.0
	var btns := [
		["CONTINUAR", Palette.POSITIVE, _on_continue],
		["REINTENTAR", Palette.VIOLET, _on_restart],
		["MENÚ", Palette.CLOTH_BLUE, _on_menu],
	]
	for b in btns:
		var btn := UIKit.button(b[0], b[1], Palette.INK, Vector2(340, 80), 30)
		btn.position = Vector2(90, y)
		btn.pressed.connect(b[2])
		card.add_child(btn)
		y += 104.0


func _on_continue() -> void:
	_close_overlay()
	gm.resume_game()


func _on_restart() -> void:
	gm.restart()


func _on_menu() -> void:
	gm.go_to_menu()


## Selección de mejora (GFX-058 / GFX-059): 3 cartas, se elige sólo una.
func show_upgrades(choices: Array[Dictionary]) -> void:
	_choosing = false
	var o := _open_overlay(0.55)
	var panel := UIKit.panel(Rect2(_w * 0.5 - 325, _h * 0.5 - 285, 650, 570), Palette.CREAM, 40,
		Palette.INK, 4, true)
	o.add_child(panel)
	# Slide up 0.25 s (AN-18)
	var final_y := panel.position.y
	panel.position.y += 80
	var tw := panel.create_tween()
	tw.tween_property(panel, "position:y", final_y, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var t := UIKit.label("¡OLEADA SUPERADA!", UIKit.H2, Palette.ZOMBIE_SKIN, 12, Palette.INK)
	t.position = Vector2(0, 34)
	t.size = Vector2(650, 60)
	panel.add_child(t)
	var st := UIKit.label("Elegí una mejora", UIKit.BODY, Palette.INK_SOFT)
	st.position = Vector2(0, 100)
	st.size = Vector2(650, 36)
	panel.add_child(st)

	for i in choices.size():
		var d: Dictionary = choices[i]
		var card := _upgrade_card(d)
		card.position = Vector2(20 + i * 210, 170)
		panel.add_child(card)
		# Entrada escalonada
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2.ONE * 0.7
		card.modulate.a = 0.0
		var ct := card.create_tween().set_parallel(true)
		ct.tween_property(card, "scale", Vector2.ONE, 0.25).set_delay(0.1 + i * 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ct.tween_property(card, "modulate:a", 1.0, 0.15).set_delay(0.1 + i * 0.07)

	var lv := UIKit.label(_levels_text(), 18, Palette.INK_SOFT, 0, Palette.INK, HORIZONTAL_ALIGNMENT_CENTER, 610)
	lv.position = Vector2(20, 470)
	lv.size = Vector2(610, 80)
	panel.add_child(lv)


const CARD_COLORS := {
	"speed": [Color("#D4EAF8"), Color("#8EAEE0")],
	"contagion": [Color("#EDE5FB"), Color("#B9A1E8")],
	"resistance": [Color("#FAE9E2"), Color("#E69E9E")],
	"horde": [Color("#E6F5DD"), Color("#A8D98A")],
	"fury": [Color("#FFF4D4"), Color("#F6D47A")],
	"instinct": [Color("#DFEBFC"), Color("#8EAEE0")],
}


func _upgrade_card(d: Dictionary) -> Button:
	var id: String = d.id
	var cols: Array = CARD_COLORS.get(id, [Palette.VIOLET_LIGHT, Palette.VIOLET])
	var b := Button.new()
	b.size = Vector2(190, 280)
	b.custom_minimum_size = b.size
	b.focus_mode = Control.FOCUS_NONE
	var normal := UIKit.box(cols[0], 26, cols[1].darkened(0.1), 4)
	normal.shadow_color = Color(Palette.INK, 0.18)
	normal.shadow_offset = Vector2(0, 6)
	normal.shadow_size = 4
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = Palette.INK
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.border_color = Palette.ZOMBIE_OUTLINE
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var icon := IconView.make(id, Vector2(110, 110))
	icon.position = Vector2(40, 18)
	b.add_child(icon)
	var title := UIKit.label(d.title, 21, Palette.INK, 2, Palette.INK)
	title.position = Vector2(0, 136)
	title.size = Vector2(190, 34)
	b.add_child(title)
	var desc := UIKit.label(d.desc, 17, Palette.INK_SOFT, 0, Palette.INK, HORIZONTAL_ALIGNMENT_CENTER, 174)
	desc.position = Vector2(8, 172)
	desc.size = Vector2(174, 96)
	desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_child(desc)
	var lvl: int = gm.upgrades.level(id)
	if lvl > 0:
		var badge := UIKit.panel(Rect2(130, 12, 48, 30), Palette.INK, 15)
		b.add_child(badge)
		var bl := UIKit.label("+%d" % lvl, 18, Palette.WHITE)
		bl.size = badge.size
		badge.add_child(bl)
	b.pressed.connect(_on_card_pressed.bind(b, icon, id))
	return b


func _on_card_pressed(card: Button, icon: IconView, id: String) -> void:
	if _choosing:
		return
	_choosing = true
	AudioManager.play("select", 0.0, 0.0)
	card.pivot_offset = card.size * 0.5
	icon.pivot_offset = icon.size * 0.5
	# AN-19: escala 1 → 1.06 → 1 y rebote del ícono
	var tw := card.create_tween()
	tw.tween_property(card, "scale", Vector2.ONE * 1.06, 0.1)
	tw.tween_property(card, "scale", Vector2.ONE, 0.1)
	var it := icon.create_tween()
	it.tween_property(icon, "scale", Vector2.ONE * 1.2, 0.1)
	it.tween_property(icon, "scale", Vector2.ONE, 0.12)
	tw.tween_interval(0.12)
	tw.tween_callback(func() -> void:
		_close_overlay()
		gm.on_upgrade_chosen(id))


func _levels_text() -> String:
	var parts: PackedStringArray = []
	for d in UpgradeManager.DEFS:
		var l: int = gm.upgrades.level(d.id)
		if l > 0:
			parts.append("%s %d" % [String(d.title).capitalize(), l])
	if parts.is_empty():
		return "Las mejoras se acumulan hasta el final de la partida."
	return "Tus mejoras: " + " · ".join(parts)


## Victoria / derrota (GFX-060 a GFX-062).
func show_results(stats: Dictionary) -> void:
	hud.visible = false
	var victory: bool = stats.victory
	var o := _open_overlay(0.0)
	var bg := ColorRect.new()
	bg.color = Color(Palette.CREAM, 0.96)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.add_child(bg)
	UIKit.full_rect(bg)
	o.create_tween().tween_property(o, "modulate:a", 1.0, 0.35)

	var cy := _h * 0.5
	var has_next: bool = stats.get("has_next", false)
	var lv: int = stats.get("level", 1)
	var title_text := "LA HUMANIDAD RESISTIÓ"
	if victory:
		title_text = "¡NIVEL SUPERADO!" if has_next else "¡INVASIÓN COMPLETA!"
	var title_col := Palette.ZOMBIE_SKIN if victory else Palette.DANGER
	var title := UIKit.label(title_text, 46, title_col, 14, Palette.INK)
	title.position = Vector2(0, cy - 330)
	title.size = Vector2(_w, 95)
	o.add_child(title)
	UIKit.bounce(title, 1.25, 0.4)
	var sub_text := "Nivel %d · %s · tu horda fue eliminada" % [lv, Levels.level_name(lv).capitalize()]
	if victory:
		sub_text = "Superaste las %d oleadas de %s" % [int(stats.get("total_waves", 10)), Levels.level_name(lv).capitalize()]
		if has_next:
			sub_text += " · ¡Nivel %d desbloqueado!" % (lv + 1)
	var sub := UIKit.label(sub_text, 22, Palette.INK_SOFT, 0, Palette.INK, HORIZONTAL_ALIGNMENT_CENTER, _w - 40)
	sub.position = Vector2(20, cy - 248)
	sub.size = Vector2(_w - 40, 50)
	o.add_child(sub)

	var card := UIKit.panel(Rect2(_w * 0.5 - 250, cy - 190, 500, 330), Palette.WHITE, 30, Palette.INK, 3, true)
	o.add_child(card)
	var rows := [
		["wave", "Oleada (nivel %d)" % lv, int(stats.wave)],
		["infections", "Humanos contagiados", int(stats.infected)],
		["horde_max", "Horda máxima", int(stats.max_horde)],
		["coin", "Puntuación", int(stats.score)],
		["trophy", "Récord personal", int(stats.best_score)],
	]
	for i in rows.size():
		var r: Array = rows[i]
		var y := 22.0 + i * 60.0
		var ic := IconView.make(r[0], Vector2(42, 42))
		ic.position = Vector2(30, y + 2)
		card.add_child(ic)
		var l := UIKit.label(r[1], 23, Palette.INK_SOFT, 0, Palette.INK, HORIZONTAL_ALIGNMENT_LEFT)
		l.position = Vector2(88, y)
		l.size = Vector2(260, 46)
		card.add_child(l)
		var v := UIKit.label("0", 32, Palette.INK, 2, Palette.INK, HORIZONTAL_ALIGNMENT_RIGHT)
		v.position = Vector2(300, y)
		v.size = Vector2(170, 46)
		card.add_child(v)
		var target: int = r[2]
		var tw := v.create_tween()
		tw.tween_interval(0.2 + i * 0.1)
		tw.tween_method(func(x: float) -> void: v.text = str(int(x)), 0.0, float(target), 0.7)
	if stats.new_record:
		var badge := UIKit.panel(Rect2(_w * 0.5 - 130, cy + 152, 260, 48), Palette.GOLD, 24, Palette.INK, 3)
		o.add_child(badge)
		var bl := UIKit.label("¡NUEVO RÉCORD!", 24, Palette.INK, 2, Palette.INK)
		bl.size = badge.size
		badge.add_child(bl)
		UIKit.bounce(badge, 1.3, 0.5)

	var retry_text := "SIGUIENTE" if has_next else "REINTENTAR"
	var retry := UIKit.button(retry_text, Palette.POSITIVE, Palette.INK, Vector2(250, 76), 28)
	retry.position = Vector2(_w * 0.5 - 262, cy + 230)
	if has_next:
		retry.pressed.connect(func() -> void: gm.next_level())
	else:
		retry.pressed.connect(func() -> void: gm.restart())
	o.add_child(retry)
	var menu := UIKit.button("MENÚ", Palette.VIOLET, Palette.INK, Vector2(250, 76), 28)
	menu.position = Vector2(_w * 0.5 + 12, cy + 230)
	menu.pressed.connect(func() -> void: gm.go_to_menu())
	o.add_child(menu)

	if victory:
		var conf := Confetti.new()
		conf.size = Vector2(_w, _h)
		o.add_child(conf)
