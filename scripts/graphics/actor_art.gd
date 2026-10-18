class_name ActorArt
extends RefCounted
## Dibujo procedural de los actores (vista cenital estricta).
## Una sola silueta base para todos: cabeza + torso + brazos + pies + sombra.
## Las variantes se logran por color (GFX-001 a GFX-008).

enum Kind { HUMAN, ZOMBIE, POLICE, SOLDIER, SURVIVOR, BIKER, TANK }


## Enemigos armados (todo lo que no es civil ni zombi).
static func is_armed(kind: int) -> bool:
	return kind >= Kind.POLICE


static var _ellipse: PackedVector2Array = PackedVector2Array()


## Sombra ovalada (GFX-007). Polígono precalculado: no toca la transformación de dibujo.
static func shadow(ci: CanvasItem, center: Vector2, rx: float) -> void:
	if _ellipse.is_empty():
		for i in 18:
			var a := i * TAU / 18.0
			_ellipse.append(Vector2(cos(a), sin(a) * 0.42))
	var pts := PackedVector2Array()
	pts.resize(_ellipse.size())
	for i in _ellipse.size():
		pts[i] = center + _ellipse[i] * rx
	ci.draw_colored_polygon(pts, Palette.SHADOW)


static func disc(ci: CanvasItem, p: Vector2, r: float, fill: Color, outline: Color = Color(0, 0, 0, 0), width: float = 1.5) -> void:
	ci.draw_circle(p, r, fill)
	if outline.a > 0.0:
		ci.draw_arc(p, r, 0.0, TAU, 20, outline, width, true)
	else:
		# Borde antialias del mismo color para suavizar el círculo.
		ci.draw_arc(p, r - 0.3, 0.0, TAU, 20, fill, 1.0, true)


## Mezcla un color con el destello (daño / transformación). tint.a = intensidad.
static func _t(c: Color, tint: Color) -> Color:
	if tint.a <= 0.0:
		return c
	return c.lerp(Color(tint.r, tint.g, tint.b, c.a), tint.a)


## Dibuja un actor centrado en `ground` (punto de apoyo).
## phase: fase de caminata (radianes). moving: 0..1 cuánto se está moviendo.
## variant: estilo de pelo del civil (0 corto, 1 coletas, 2 rodete, 3 canoso)
## o accesorio del zombi (0 mechón, 1 flor rosa, 2 líder con mancha).
static func draw_actor(ci: CanvasItem, kind: int, ground: Vector2, r: float, facing: Vector2,
		phase: float, moving: float, cloth: Color, hair: Color, skin: Color, tint: Color, variant: int = 0,
		with_shadow: bool = true) -> void:
	var f := facing
	var s := f.orthogonal()
	var step := sin(phase) * moving
	var bob := absf(sin(phase)) * 2.2 * moving
	var o := ground + Vector2(0, -bob)
	var outline := Palette.OUTLINE
	if kind == Kind.ZOMBIE:
		outline = Palette.with_alpha(Palette.ZOMBIE_OUTLINE, 0.9)

	if with_shadow:
		shadow(ci, ground + Vector2(0, r * 0.55), r * 1.05)
	if kind == Kind.BIKER:
		_draw_biker(ci, ground, r, f, s, phase, moving, skin, tint)
		return

	# Pies (asoman al caminar)
	var foot_col := _t(cloth.darkened(0.28), tint)
	if kind == Kind.POLICE:
		foot_col = _t(Palette.POLICE_DARK.darkened(0.15), tint)
	elif kind == Kind.SOLDIER or kind == Kind.SURVIVOR:
		foot_col = _t(Palette.SOLDIER_BOOTS, tint)
	var foot_r := r * 0.26
	disc(ci, o + s * r * 0.36 + f * (step * r * 0.45), foot_r, foot_col)
	disc(ci, o - s * r * 0.36 - f * (step * r * 0.45), foot_r, foot_col)

	# Brazos
	var skin_t := _t(skin, tint)
	var arm_r := r * 0.25
	match kind:
		Kind.ZOMBIE:
			var reach := r * 0.92 + sin(phase * 0.5) * 1.5
			disc(ci, o + s * r * 0.5 + f * reach, arm_r, skin_t, outline, 1.2)
			disc(ci, o - s * r * 0.5 + f * (reach - 2.0), arm_r, skin_t, outline, 1.2)
		Kind.SOLDIER:
			# Fusil sostenido con las dos manos, apuntando al frente.
			var gun_a := o + s * r * 0.22 + f * r * 0.35
			ci.draw_line(gun_a, gun_a + f * r * 1.15, _t(Palette.SOLDIER_GUN, tint), 5.0, true)
			ci.draw_line(gun_a, gun_a + f * r * 1.15, _t(Palette.SOLDIER_GUN.darkened(0.3), tint), 1.5, true)
			var glove := _t(Palette.SOLDIER_BOOTS.darkened(0.1), tint)
			disc(ci, o + s * r * 0.5 + f * r * 0.55, arm_r, glove, outline, 1.2)
			disc(ci, o + s * r * 0.05 + f * r * 0.82, arm_r * 0.9, glove, outline, 1.2)
		Kind.SURVIVOR:
			pass  # la escopeta y las manos se dibujan encima de la cabeza (ver abajo)
		Kind.POLICE:
			# Brazo derecho al frente con el arma (línea corta), izquierdo oscila.
			var hand := o + s * r * 0.55 + f * r * 0.72
			ci.draw_line(hand, hand + f * r * 0.62, _t(Palette.POLICE_DARK.darkened(0.25), tint), 3.5, true)
			disc(ci, hand, arm_r, skin_t, outline, 1.2)
			disc(ci, o - s * r * 0.82 - f * step * r * 0.3, arm_r, skin_t, outline, 1.2)
		_:
			disc(ci, o + s * r * 0.82 + f * step * r * 0.32, arm_r, skin_t, outline, 1.2)
			disc(ci, o - s * r * 0.82 - f * step * r * 0.32, arm_r, skin_t, outline, 1.2)

	# Torso (asoma detrás de la cabeza)
	disc(ci, o - f * r * 0.14, r * 0.74, _t(cloth, tint), outline, 1.5)
	if kind == Kind.SOLDIER:
		disc(ci, o - f * r * 0.02, r * 0.52, _t(Palette.SOLDIER_VEST, tint))
	elif kind == Kind.SURVIVOR:
		# Mochila verde oliva en la espalda y tiradores sobre la remera
		disc(ci, o - f * r * 0.62, r * 0.5, _t(Palette.SURV_PACK, tint), outline, 1.5)
		ci.draw_line(o - f * r * 0.5 + s * r * 0.42, o + f * r * 0.15 + s * r * 0.42, _t(Palette.SURV_PACK, tint), 3.0, true)
		ci.draw_line(o - f * r * 0.5 - s * r * 0.42, o + f * r * 0.15 - s * r * 0.42, _t(Palette.SURV_PACK, tint), 3.0, true)

	# Cabeza grande (proporción chibi de la lámina de referencia)
	var head := o + f * r * 0.12
	var head_r := r * 0.7
	disc(ci, head, head_r, skin_t, outline, 1.5)

	match kind:
		Kind.HUMAN:
			# Cabello visto desde arriba (variantes por forma y color)
			var hc := _t(hair, tint)
			match variant:
				1: # coletas
					disc(ci, head - f * r * 0.2, head_r * 0.78, hc)
					disc(ci, head + s * head_r * 0.98 - f * r * 0.1, head_r * 0.36, hc)
					disc(ci, head - s * head_r * 0.98 - f * r * 0.1, head_r * 0.36, hc)
				2: # rodete
					disc(ci, head - f * r * 0.2, head_r * 0.78, hc)
					disc(ci, head - f * head_r * 0.62, head_r * 0.38, hc.darkened(0.06))
				3: # canoso (anciano)
					disc(ci, head - f * r * 0.18, head_r * 0.78, _t(Color("#E4E0DC"), tint))
				_:
					disc(ci, head - f * r * 0.2, head_r * 0.78, hc)
					disc(ci, head - f * r * 0.08 + s * r * 0.24, head_r * 0.4, hc)
			# Ojitos mínimos en el borde frontal: indican hacia dónde mira
			ci.draw_circle(head + f * r * 0.44 + s * r * 0.2, r * 0.075, Palette.INK)
			ci.draw_circle(head + f * r * 0.44 - s * r * 0.2, r * 0.075, Palette.INK)
		Kind.SURVIVOR:
			# Pelo castaño despeinado hacia atrás: asoma la cara con los ojitos
			var hc2 := _t(Palette.SURV_HAIR, tint)
			disc(ci, head - f * r * 0.24, head_r * 0.8, hc2)
			disc(ci, head - f * r * 0.08 + s * r * 0.38, head_r * 0.34, hc2)
			disc(ci, head - f * r * 0.12 - s * r * 0.4, head_r * 0.3, hc2)
			disc(ci, head - f * r * 0.66 + s * r * 0.08, head_r * 0.34, hc2)
			disc(ci, head + f * r * 0.1 + s * r * 0.16, head_r * 0.26, hc2.lightened(0.08))
			ci.draw_circle(head + f * r * 0.5 + s * r * 0.2, r * 0.075, Palette.INK)
			ci.draw_circle(head + f * r * 0.5 - s * r * 0.2, r * 0.075, Palette.INK)
			# Escopeta cruzada al frente: caño oscuro, guardamanos de madera y culata.
			var butt := o + s * r * 0.62 - f * r * 0.05
			var tip := o - s * r * 0.12 + f * r * 1.4
			ci.draw_line(butt, tip, _t(Palette.SHOTGUN, tint), 5.5, true)
			ci.draw_line(butt, butt.lerp(tip, 0.26), _t(Palette.GUN_WOOD, tint), 6.5, true)
			ci.draw_line(butt.lerp(tip, 0.58), butt.lerp(tip, 0.8), _t(Palette.GUN_WOOD, tint), 7.0, true)
			disc(ci, butt.lerp(tip, 0.22), arm_r, skin_t, outline, 1.2)
			disc(ci, butt.lerp(tip, 0.69), arm_r, skin_t, outline, 1.2)
		Kind.SOLDIER:
			# Casco grande con brillo; asoma la cara con dos ojitos hacia adelante.
			var face := head + f * r * 0.36
			disc(ci, face, head_r * 0.62, skin_t, outline, 1.2)
			var hc := head - f * r * 0.2
			disc(ci, hc, head_r * 0.9, _t(Palette.SOLDIER_HELMET, tint), outline, 1.5)
			disc(ci, hc + s * head_r * 0.86, head_r * 0.22, _t(Palette.SOLDIER_HELMET.darkened(0.15), tint))
			disc(ci, hc - s * head_r * 0.86, head_r * 0.22, _t(Palette.SOLDIER_HELMET.darkened(0.15), tint))
			disc(ci, hc - f * r * 0.12 + s * r * 0.18, head_r * 0.28, _t(Palette.SOLDIER_HELMET_LIGHT, tint))
			# Ojitos en la franja de cara que asoma bajo el casco
			ci.draw_circle(head + f * r * 0.62 + s * r * 0.17, r * 0.075, Palette.INK)
			ci.draw_circle(head + f * r * 0.62 - s * r * 0.17, r * 0.075, Palette.INK)
		Kind.POLICE:
			var cap := _t(Palette.POLICE_DARK, tint)
			disc(ci, head - f * r * 0.06, head_r * 0.88, cap)
			disc(ci, head + f * r * 0.42, head_r * 0.4, cap)
			disc(ci, head + f * r * 0.12, head_r * 0.24, _t(Palette.GOLD, tint))
		Kind.ZOMBIE:
			match variant:
				1: # florcita rosa (aliado)
					var fp := head - f * r * 0.2 + s * r * 0.34
					for k in 5:
						ci.draw_circle(fp + Vector2.RIGHT.rotated(k * TAU / 5.0) * r * 0.17, r * 0.15, _t(Palette.CLOTH_PINK, tint))
					ci.draw_circle(fp, r * 0.1, _t(Palette.GOLD, tint))
				2: # líder: mancha más oscura en la cabeza
					disc(ci, head - f * r * 0.22 + s * r * 0.16, head_r * 0.36, _t(Palette.ZOMBIE_OUTLINE, tint))
					ci.draw_circle(head - f * r * 0.28 + s * r * 0.24, head_r * 0.14, _t(Palette.ZOMBIE_OUTLINE.darkened(0.12), tint))
				_:
					disc(ci, head - f * r * 0.26 + s * r * 0.1, head_r * 0.34, _t(Palette.ZOMBIE_OUTLINE, tint))
			# Dos ojitos simples hacia donde mira
			var eye := Palette.INK
			ci.draw_circle(head + f * r * 0.34 + s * r * 0.24, r * 0.12, eye)
			ci.draw_circle(head + f * r * 0.34 - s * r * 0.22, r * 0.095, eye)


## Motociclista visto desde arriba: moto roja a lo largo de la marcha, piloto con casco
## verde de franja crema, antiparras y pañuelo rojo.
static func _draw_biker(ci: CanvasItem, o: Vector2, r: float, f: Vector2, s: Vector2,
		phase: float, moving: float, skin: Color, tint: Color) -> void:
	var outline := Palette.OUTLINE
	var dark := _t(Palette.MOTO_DARK, tint)
	var red := _t(Palette.MOTO_RED, tint)
	# Ruedas, chasis (guardabarros y carenado), asiento y faro
	_orect(ci, o - f * r * 1.18, f, s, r * 0.36, r * 0.18, dark, outline)
	_orect(ci, o + f * r * 1.18, f, s, r * 0.34, r * 0.17, dark, outline)
	_orect(ci, o - f * r * 0.05, f, s, r * 1.0, r * 0.3, red, outline)
	_orect(ci, o + f * r * 0.98, f, s, r * 0.26, r * 0.26, red, outline)
	_orect(ci, o - f * r * 1.02, f, s, r * 0.24, r * 0.22, red, outline)
	ci.draw_line(o + f * r * 0.62 + s * r * 0.62, o + f * r * 0.62 - s * r * 0.62, _t(Palette.SHOTGUN, tint), 3.0, true)
	disc(ci, o + f * r * 1.32, r * 0.17, _t(Palette.HEADLIGHT, tint), outline, 1.2)
	# Piloto: mochila, torso, manos con guantes en el manubrio y escopeta corta
	disc(ci, o - f * r * 0.6, r * 0.36, _t(Palette.SURV_PACK, tint), outline, 1.5)
	disc(ci, o - f * r * 0.2, r * 0.5, _t(Palette.SURV_SHIRT, tint), outline, 1.5)
	var glove := _t(Palette.MOTO_DARK.lightened(0.1), tint)
	ci.draw_line(o + s * r * 0.5 + f * r * 0.45, o + s * r * 0.5 + f * r * 1.15, _t(Palette.SHOTGUN, tint), 4.0, true)
	disc(ci, o + f * r * 0.6 + s * r * 0.55, r * 0.2, glove, outline, 1.2)
	disc(ci, o + f * r * 0.6 - s * r * 0.55, r * 0.2, glove, outline, 1.2)
	# Pañuelo rojo, casco con franja y antiparras al frente
	var head := o + f * r * 0.02
	var hr := r * 0.52
	disc(ci, head + f * r * 0.12, hr * 0.8, _t(Palette.BANDANA, tint))
	disc(ci, head, hr, _t(Palette.BIKER_HELMET, tint), outline, 1.5)
	ci.draw_line(head - f * hr * 0.92, head + f * hr * 0.55, _t(Palette.BIKER_STRIPE, tint), hr * 0.42, true)
	var g := head + f * hr * 0.62
	ci.draw_line(g + s * hr * 0.75, g - s * hr * 0.75, _t(Palette.MOTO_DARK, tint), hr * 0.42, true)
	disc(ci, g + s * hr * 0.35, hr * 0.24, _t(Palette.BIKER_GOGGLES, tint))
	disc(ci, g - s * hr * 0.35, hr * 0.24, _t(Palette.BIKER_GOGGLES, tint))


## Tanque: casco y orugas siguen la marcha (facing) y la torreta gira sola (turret).
static func draw_tank(ci: CanvasItem, ground: Vector2, r: float, facing: Vector2, turret: Vector2,
		phase: float, tint: Color, wrecked: bool, recoil: float) -> void:
	var f := facing
	var s := f.orthogonal()
	var outline := Palette.OUTLINE
	var green := Palette.TANK_GREEN
	var light := Palette.TANK_LIGHT
	var dark := Palette.TANK_DARK
	if wrecked:
		green = green.lerp(Palette.TANK_WRECK, 0.6)
		light = light.lerp(Palette.TANK_WRECK, 0.6)
		dark = dark.lerp(Palette.TANK_WRECK, 0.5)
	green = _t(green, tint); light = _t(light, tint); dark = _t(dark, tint)
	var track := _t(Palette.TANK_TRACK, tint)
	shadow(ci, ground + Vector2(0, r * 0.45), r * 1.3)
	var o := ground
	# Orugas con eslabones que corren con la marcha
	for side in [-1.0, 1.0]:
		var tc: Vector2 = o + s * side * r * 0.74
		_orect(ci, tc, f, s, r * 0.98, r * 0.24, track, outline)
		var off := fposmod(phase * 3.0, 1.0)
		for k in 7:
			var t := -0.9 + (k + off) * 0.27
			if t > 0.92:
				continue
			var p: Vector2 = tc + f * r * t
			ci.draw_line(p + s * r * 0.2, p - s * r * 0.2, track.darkened(0.3), 2.0, true)
	# Casco
	_orect(ci, o, f, s, r * 0.9, r * 0.56, green, outline)
	_orect(ci, o + f * r * 0.62, f, s, r * 0.18, r * 0.46, light)
	_orect(ci, o - f * r * 0.7, f, s, r * 0.12, r * 0.3, dark)
	disc(ci, o - f * r * 0.5 + s * r * 0.38, r * 0.06, dark)
	disc(ci, o - f * r * 0.5 - s * r * 0.38, r * 0.06, dark)
	# Torreta con cañón (retrocede al disparar)
	var tf := turret
	var ts := tf.orthogonal()
	var tcen := o - f * r * 0.04
	if wrecked:
		tcen += s * r * 0.15
	var barrel_start := tcen + tf * r * (0.32 - recoil * 0.2)
	_orect(ci, barrel_start + tf * r * 0.55, tf, ts, r * 0.55, r * 0.1, green, outline)
	_orect(ci, barrel_start + tf * r * 1.08, tf, ts, r * 0.1, r * 0.14, dark, outline)
	disc(ci, tcen, r * 0.46, light, outline, 1.8)
	disc(ci, tcen - tf * r * 0.04, r * 0.3, green)
	_orect(ci, tcen - tf * r * 0.05, tf, ts, r * 0.09, r * 0.11, dark)
	_orect(ci, tcen - tf * r * 0.3 + ts * r * 0.24, tf, ts, r * 0.08, r * 0.08, dark)
	if wrecked:
		disc(ci, o + f * r * 0.35 - s * r * 0.25, r * 0.2, Color("#2E2A2A"))
		disc(ci, o + f * r * 0.35 - s * r * 0.25, r * 0.11, Color("#151212"))


## Rectángulo orientado (centro, eje f, mitades hl a lo largo y hw a lo ancho).
static func _orect(ci: CanvasItem, c: Vector2, f: Vector2, s: Vector2, hl: float, hw: float,
		col: Color, outline: Color = Color(0, 0, 0, 0)) -> void:
	var pts := PackedVector2Array([c + f * hl + s * hw, c + f * hl - s * hw, c - f * hl - s * hw, c - f * hl + s * hw])
	ci.draw_colored_polygon(pts, col)
	if outline.a > 0.0:
		pts.append(pts[0])
		ci.draw_polyline(pts, outline, 1.5, true)


## Anillo del zombi controlado (GFX-008 / AN-09): pulso de alfa 45–65 % cada 1.1 s.
static func player_ring(ci: CanvasItem, ground: Vector2, r: float, t: float) -> void:
	var pulse := 0.5 + 0.5 * sin(t * TAU / 1.1)
	var a := lerpf(0.45, 0.65, pulse)
	var rad := r + 16.0 + pulse * 2.0
	ci.draw_circle(ground, rad, Palette.with_alpha(Palette.ZOMBIE_SKIN, 0.16))
	ci.draw_arc(ground, rad, 0.0, TAU, 40, Palette.with_alpha(Palette.ZOMBIE_OUTLINE, a), 3.0, true)


## Aura de Fiebre Zombi (GFX-081 / AN-21): contorno verde-lila pulsante (0.8 s).
static func fever_aura(ci: CanvasItem, ground: Vector2, r: float, t: float) -> void:
	var pulse := 0.5 + 0.5 * sin(t * TAU / 0.8)
	var col := Palette.ZOMBIE_SKIN.lerp(Palette.VIOLET, pulse)
	ci.draw_circle(ground, r * (1.25 + pulse * 0.15), Palette.with_alpha(col, 0.28))


## Alerta del civil al detectar zombis (GFX-009): gotitas de susto celestes.
static func alert(ci: CanvasItem, p: Vector2, k: float) -> void:
	var col := Palette.with_alpha(Palette.HUMAN_ALERT, clampf(k * 1.5, 0.0, 1.0))
	var sc := 0.85 + 0.3 * k
	_drop(ci, p + Vector2(-7, 2) * sc, 4.2 * sc, -0.5, col)
	_drop(ci, p + Vector2(6, -3) * sc, 3.4 * sc, 0.5, col)


static func _drop(ci: CanvasItem, c: Vector2, r: float, tilt: float, col: Color) -> void:
	var up := Vector2.UP.rotated(tilt)
	ci.draw_circle(c, r, col)
	ci.draw_colored_polygon(PackedVector2Array([c + up * r * 2.3, c + up.orthogonal() * r, c - up.orthogonal() * r]), col)


## Minibarra de vida (GFX-011).
static func health_bar(ci: CanvasItem, p: Vector2, ratio: float, alpha: float) -> void:
	var w := 34.0
	var h := 5.0
	var rect := Rect2(p - Vector2(w * 0.5, h * 0.5), Vector2(w, h))
	ci.draw_rect(rect.grow(1.0), Palette.with_alpha(Palette.INK, 0.25 * alpha))
	ci.draw_rect(rect, Palette.with_alpha(Palette.DANGER, alpha))
	rect.size.x = w * clampf(ratio, 0.0, 1.0)
	ci.draw_rect(rect, Palette.with_alpha(Palette.POSITIVE, alpha))


## Cabeza de zombi para íconos de interfaz (GFX-038).
static func zombie_head_icon(ci: CanvasItem, c: Vector2, r: float) -> void:
	disc(ci, c, r, Palette.ZOMBIE_SKIN, Palette.ZOMBIE_OUTLINE, maxf(1.5, r * 0.1))
	disc(ci, c + Vector2(r * 0.15, -r * 0.62), r * 0.32, Palette.ZOMBIE_OUTLINE)
	ci.draw_circle(c + Vector2(-r * 0.36, r * 0.02), r * 0.17, Palette.INK)
	ci.draw_circle(c + Vector2(r * 0.36, -r * 0.02), r * 0.13, Palette.INK)
	ci.draw_arc(c + Vector2(0, r * 0.32), r * 0.28, 0.3, PI - 0.3, 10, Palette.INK, maxf(1.5, r * 0.09), true)
