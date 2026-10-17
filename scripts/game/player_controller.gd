class_name PlayerController
extends Node2D
## Joystick virtual dinámico (GFX-046 / GFX-047 / AN-22): aparece donde se apoya el dedo,
## sigue un solo dedo (multitouch seguro) y entrega una dirección analógica.
## En PC: mouse (emulado como toque) o teclado WASD / flechas.

signal first_move

const BASE_RADIUS := 76.0
const THUMB_RADIUS := 31.0
const DEADZONE := 8.0

var direction := Vector2.ZERO
## Toques que empiecen por encima de esta Y (zona del HUD) no activan el joystick.
var blocked_top := 0.0
var enabled := true

var _index := -1
var _base := Vector2.ZERO
var _thumb := Vector2.ZERO
var _alpha := 0.0
var _moved := false
var _touch_dir := Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _index == -1:
			if t.position.y < blocked_top:
				return
			_index = t.index
			_base = t.position
			_thumb = t.position
			_touch_dir = Vector2.ZERO
			get_viewport().set_input_as_handled()
		elif not t.pressed and t.index == _index:
			release()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index != _index:
			return
		var off := d.position - _base
		if off.length() > BASE_RADIUS:
			# La base acompaña al dedo si se aleja demasiado (joystick dinámico).
			_base = d.position - off.normalized() * BASE_RADIUS
			off = d.position - _base
		_thumb = d.position
		var l := off.length()
		if l > DEADZONE:
			var mag := clampf((l - DEADZONE) / (BASE_RADIUS * 0.75 - DEADZONE), 0.0, 1.0)
			_touch_dir = off / l * mag
		else:
			_touch_dir = Vector2.ZERO
		get_viewport().set_input_as_handled()


func release() -> void:
	_index = -1
	_touch_dir = Vector2.ZERO
	direction = Vector2.ZERO


func _process(delta: float) -> void:
	var kb := Vector2.ZERO
	if enabled:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			kb.x -= 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			kb.x += 1
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			kb.y -= 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			kb.y += 1
	direction = kb.normalized() if kb != Vector2.ZERO else _touch_dir
	if not _moved and direction.length() > 0.3:
		_moved = true
		first_move.emit()
	var target_a := 1.0 if _index != -1 else 0.0
	_alpha = move_toward(_alpha, target_a, delta / 0.1)
	if _alpha > 0.0 or _index != -1:
		queue_redraw()


func _draw() -> void:
	if _alpha <= 0.0:
		return
	var a := _alpha
	draw_circle(_base, BASE_RADIUS, Palette.with_alpha(Palette.WHITE, 0.35 * a))
	draw_arc(_base, BASE_RADIUS, 0, TAU, 48, Palette.with_alpha(Palette.VIOLET, 0.75 * a), 4.0, true)
	draw_arc(_base, BASE_RADIUS - 14.0, 0, TAU, 48, Palette.with_alpha(Palette.VIOLET_LIGHT, 0.6 * a), 2.0, true)
	# Flechitas en las 4 direcciones
	for k in 4:
		var dir := Vector2.UP.rotated(k * PI * 0.5)
		var tip := _base + dir * (BASE_RADIUS - 8.0)
		var side := dir.orthogonal() * 7.0
		draw_colored_polygon(PackedVector2Array([tip, tip - dir * 10.0 + side, tip - dir * 10.0 - side]),
			Palette.with_alpha(Palette.VIOLET, 0.6 * a))
	var thumb := _base + (_thumb - _base).limit_length(BASE_RADIUS - THUMB_RADIUS * 0.4)
	draw_circle(thumb + Vector2(0, 3), THUMB_RADIUS, Palette.with_alpha(Palette.INK, 0.12 * a))
	draw_circle(thumb, THUMB_RADIUS, Palette.with_alpha(Palette.VIOLET, 0.92 * a))
	draw_circle(thumb + Vector2(-6, -7), THUMB_RADIUS * 0.55, Palette.with_alpha(Palette.VIOLET_LIGHT, 0.65 * a))
