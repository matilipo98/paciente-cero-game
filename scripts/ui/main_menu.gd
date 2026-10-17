extends Control
## Pantalla de inicio (GFX-051 a GFX-056): ciudad de fondo, logo, zombi animado,
## JUGAR, MEJORAS, RÉCORDS, AJUSTES, récord de oleada y botón de sonido.

const GAME_SCENE := "res://scenes/game/game.tscn"

@onready var world: WorldMap = $World/WorldMap
@onready var world_root: Node2D = $World

var _w := 720.0
var _h := 1280.0
var _oy := 0.0
var _sound_btn: Button
var _record_label: Label
var _overlay: Control = null


## Actores ilustrativos del menú: zombi con rastro verde y civiles asustados.
class MenuActors extends Node2D:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var z := Vector2(360, 540)
		# Rastro verde
		for i in 9:
			var p := z + Vector2(sin(i * 1.7 + _t) * 14.0 - i * 3.0, -40.0 - i * 16.0)
			draw_circle(p, 9.0 - i * 0.8, Color(Palette.ZOMBIE_OUTLINE, 0.5 - i * 0.045))
		var humans := [
			[Vector2(230, 690), Vector2(-0.6, 0.8), Palette.CLOTH_PINK, Palette.HAIR_BROWN, 1],
			[Vector2(480, 640), Vector2(0.7, 0.7), Palette.CLOTH_BLUE, Palette.HAIR_BLACK, 0],
			[Vector2(380, 740), Vector2(0.15, 1.0), Palette.VIOLET_LIGHT, Palette.HAIR_BLOND, 2],
		]
		for h in humans:
			var pos: Vector2 = h[0]
			var ph := _t * 9.0 + pos.x
			draw_set_transform(pos, 0.0, Vector2.ONE * 2.3)
			ActorArt.draw_actor(self, ActorArt.Kind.HUMAN, Vector2.ZERO, 14.0, (h[1] as Vector2).normalized(),
				ph, 1.0, h[2], h[3], Palette.HUMAN_SKIN, Color(0, 0, 0, 0), h[4])
			ActorArt.alert(self, Vector2(10, -24), 0.8 + 0.2 * sin(_t * 6.0))
		var bob := absf(sin(_t * PI / 1.2)) * 4.0
		draw_set_transform(z + Vector2(0, -bob), 0.0, Vector2.ONE * 3.2)
		ActorArt.draw_actor(self, ActorArt.Kind.ZOMBIE, Vector2.ZERO, 15.0, Vector2.DOWN, _t * 6.0, 0.6,
			Palette.ZOMBIE_CLOTH, Palette.ZOMBIE_OUTLINE, Palette.ZOMBIE_SKIN, Color(0, 0, 0, 0), 2)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ready() -> void:
	theme = UIKit.theme()
	var vs := get_viewport_rect().size
	_w = vs.x
	_h = vs.y
	_oy = (_h - 1280.0) * 0.5
	world_root.position = Vector2((_w - 720.0) * 0.5, _oy)
	var actors := MenuActors.new()
	world_root.add_child(actors)

	var veil := ColorRect.new()
	veil.color = Color(Palette.CREAM, 0.22)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	UIKit.full_rect(veil)

	var logo := LogoView.new()
	logo.position = Vector2(0, _oy + 70.0)
	logo.size = Vector2(_w, 260)
	add_child(logo)

	var cx := _w * 0.5
	var play := UIKit.button("JUGAR", Palette.POSITIVE, Palette.WHITE, Vector2(420, 112), 56, "play", true)
	play.position = Vector2(cx - 210, _oy + 790)
	play.pressed.connect(_on_play)
	add_child(play)
	# Pulso suave para destacar el botón principal
	var pt := play.create_tween().set_loops()
	pt.tween_property(play, "scale", Vector2.ONE * 1.04, 0.6).set_trans(Tween.TRANS_SINE)
	pt.tween_property(play, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)

	var y := _oy + 930.0
	var defs := [
		["MEJORAS", Palette.CLOTH_PINK, "arrow_up", _show_upgrades],
		["RÉCORDS", Palette.VIOLET, "trophy", _show_records],
		["AJUSTES", Palette.CLOTH_BLUE, "gear", _show_settings],
	]
	for d in defs:
		var b := UIKit.button(d[0], d[1], Palette.INK, Vector2(360, 66), 28, d[2])
		b.position = Vector2(cx - 180, y)
		b.pressed.connect(d[3])
		add_child(b)
		y += 80.0

	# Récord + sonido (pie, sobre el área segura)
	var by := minf(_h - 110.0 - UIKit.bottom_inset(get_viewport()), _oy + 1170.0)
	var card := UIKit.panel(Rect2(cx - 260, by, 520, 96), Palette.WHITE, 28, Palette.INK, 3, true)
	add_child(card)
	var tro := IconView.make("trophy", Vector2(64, 64))
	tro.position = Vector2(20, 16)
	card.add_child(tro)
	_record_label = UIKit.label("", 22, Palette.INK, 0, Palette.INK, HORIZONTAL_ALIGNMENT_LEFT)
	_record_label.position = Vector2(100, 8)
	_record_label.size = Vector2(300, 80)
	card.add_child(_record_label)
	var sep := ColorRect.new()
	sep.color = Color(Palette.INK, 0.15)
	sep.position = Vector2(412, 18)
	sep.size = Vector2(2, 60)
	card.add_child(sep)
	_sound_btn = UIKit.icon_button("sound_on", Palette.VIOLET, Vector2(68, 68))
	_sound_btn.position = Vector2(432, 14)
	_sound_btn.pressed.connect(_toggle_sound)
	card.add_child(_sound_btn)
	_refresh()


func _refresh() -> void:
	_record_label.text = "Récord de oleada: %d\nMáx. zombis: %d" % [SaveManager.best_wave, SaveManager.best_horde]
	(_sound_btn.get_node("Icon") as IconView).set_icon("sound_on" if SaveManager.sound_on else "sound_off")


func _on_play() -> void:
	AudioManager.play("select")
	SceneTransition.change_scene(GAME_SCENE)


func _toggle_sound() -> void:
	SaveManager.set_sound(not SaveManager.sound_on)
	_refresh()


# ---------------------------------------------------------------------------
# Sub-pantallas
# ---------------------------------------------------------------------------

func _open_card(title: String, height: float) -> Panel:
	_close()
	var o := Control.new()
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(o)
	UIKit.full_rect(o)
	var cur := ColorRect.new()
	cur.color = Color(Palette.INK, 0.55)
	cur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.add_child(cur)
	UIKit.full_rect(cur)
	var card := UIKit.panel(Rect2(_w * 0.5 - 320, _h * 0.5 - height * 0.5, 640, height), Palette.CREAM, 36,
		Palette.INK, 4, true)
	o.add_child(card)
	var t := UIKit.label(title, UIKit.H2, Palette.INK, 3, Palette.INK)
	t.position = Vector2(0, 22)
	t.size = Vector2(640, 60)
	card.add_child(t)
	var back := UIKit.button("VOLVER", Palette.VIOLET, Palette.INK, Vector2(240, 68), 26)
	back.position = Vector2(200, height - 92)
	back.pressed.connect(_close)
	card.add_child(back)
	o.modulate.a = 0.0
	o.create_tween().tween_property(o, "modulate:a", 1.0, 0.2)
	var fy := card.position.y
	card.position.y += 60
	card.create_tween().tween_property(card, "position:y", fy, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_overlay = o
	return card


func _close() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_refresh()


## MEJORAS: catálogo de las mejoras que aparecen entre oleadas + veces elegidas.
func _show_upgrades() -> void:
	var card := _open_card("MEJORAS", 900)
	var sub := UIKit.label("Al superar cada oleada elegís 1 de 3", 20, Palette.INK_SOFT)
	sub.position = Vector2(0, 80)
	sub.size = Vector2(640, 30)
	card.add_child(sub)
	var y := 124.0
	for d in UpgradeManager.DEFS:
		var row := UIKit.panel(Rect2(24, y, 592, 104), Palette.WHITE, 22, Color(Palette.INK, 0.15), 2)
		card.add_child(row)
		var ic := IconView.make(d.id, Vector2(84, 84))
		ic.position = Vector2(12, 10)
		row.add_child(ic)
		var tl := UIKit.label(d.title, 24, Palette.INK, 2, Palette.INK, HORIZONTAL_ALIGNMENT_LEFT)
		tl.position = Vector2(110, 10)
		tl.size = Vector2(320, 34)
		row.add_child(tl)
		var dl := UIKit.label(d.desc, 18, Palette.INK_SOFT, 0, Palette.INK, HORIZONTAL_ALIGNMENT_LEFT, 340)
		dl.position = Vector2(110, 44)
		dl.size = Vector2(340, 52)
		row.add_child(dl)
		var n := int(SaveManager.upgrade_counts.get(d.id, 0))
		var cl := UIKit.label("x%d" % n, 26, Palette.VIOLET.darkened(0.3), 0, Palette.INK, HORIZONTAL_ALIGNMENT_RIGHT)
		cl.position = Vector2(460, 14)
		cl.size = Vector2(110, 40)
		row.add_child(cl)
		var cl2 := UIKit.label("elegida", 16, Palette.INK_SOFT, 0, Palette.INK, HORIZONTAL_ALIGNMENT_RIGHT)
		cl2.position = Vector2(460, 54)
		cl2.size = Vector2(110, 26)
		row.add_child(cl2)
		y += 112.0


func _show_records() -> void:
	var card := _open_card("RÉCORDS", 640)
	var rows := [
		["coin", "Mejor puntuación", SaveManager.best_score],
		["wave", "Oleada máxima", SaveManager.best_wave],
		["horde_max", "Horda más grande", SaveManager.best_horde],
		["infections", "Humanos contagiados", SaveManager.total_infected],
		["trophy", "Partidas / victorias", "%d / %d" % [SaveManager.games_played, SaveManager.victories]],
	]
	var y := 100.0
	for r in rows:
		var ic := IconView.make(r[0], Vector2(48, 48))
		ic.position = Vector2(50, y + 4)
		card.add_child(ic)
		var l := UIKit.label(r[1], 24, Palette.INK_SOFT, 0, Palette.INK, HORIZONTAL_ALIGNMENT_LEFT)
		l.position = Vector2(116, y)
		l.size = Vector2(300, 56)
		card.add_child(l)
		var v := UIKit.label(str(r[2]), 32, Palette.INK, 2, Palette.INK, HORIZONTAL_ALIGNMENT_RIGHT)
		v.position = Vector2(400, y)
		v.size = Vector2(190, 56)
		card.add_child(v)
		y += 82.0


func _show_settings() -> void:
	var card := _open_card("AJUSTES", 560)
	var sb := UIKit.button(_onoff("SONIDO", SaveManager.sound_on), Palette.WHITE, Palette.INK, Vector2(420, 72), 26)
	sb.position = Vector2(110, 110)
	sb.pressed.connect(func() -> void:
		SaveManager.set_sound(not SaveManager.sound_on)
		sb.text = _onoff("SONIDO", SaveManager.sound_on))
	card.add_child(sb)
	var vb := UIKit.button(_onoff("VIBRACIÓN", SaveManager.vibration_on), Palette.WHITE, Palette.INK, Vector2(420, 72), 26)
	vb.position = Vector2(110, 200)
	vb.pressed.connect(func() -> void:
		SaveManager.set_vibration(not SaveManager.vibration_on)
		vb.text = _onoff("VIBRACIÓN", SaveManager.vibration_on))
	card.add_child(vb)
	var rb := UIKit.button("BORRAR RÉCORDS", Palette.DANGER_LIGHT, Palette.DANGER_DARK, Vector2(420, 72), 26)
	rb.position = Vector2(110, 290)
	var armed := [false]
	rb.pressed.connect(func() -> void:
		if not armed[0]:
			armed[0] = true
			rb.text = "¿SEGURO? TOCÁ OTRA VEZ"
		else:
			SaveManager.reset_records()
			rb.text = "RÉCORDS BORRADOS"
			rb.disabled = true)
	card.add_child(rb)
	var ver := UIKit.label("Paciente Cero v%s · sin conexión" % ProjectSettings.get_setting("application/config/version", "0.1"), 16, Palette.INK_SOFT)
	ver.position = Vector2(0, 380)
	ver.size = Vector2(640, 30)
	card.add_child(ver)


func _onoff(label: String, on: bool) -> String:
	return "%s: %s" % [label, "SÍ" if on else "NO"]
