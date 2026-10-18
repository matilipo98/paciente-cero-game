extends Node
## Atlas de personajes horneado al iniciar el juego (optimización de rendimiento).
## Cada "look" (combinación de ropa, pelo y peinado) se dibuja una vez en 4 cuadros
## de caminata mirando hacia abajo; en juego cada actor es un Sprite2D que rota y cambia
## de cuadro, sin recalcular formas. Si no hay GPU (pruebas headless), texture queda null.

const CELL := 128
const COLS := 16
const FRAMES := 4
## Radio con el que se hornea (el sprite se escala al radio real del actor).
const BAKE_R := 20.0
const BAKE_SCALE := 2.0

var texture: Texture2D = null
var dot: Texture2D = null
## Cada look: {kind, cloth, hair, skin, variant}
var looks: Array[Dictionary] = []
var human_looks: Array[int] = []
var zombie_looks: Array[int] = []
var leader_look := -1
var police_look := -1
var soldier_look := -1
var survivor_look := -1
var biker_look := -1

signal ready_baked


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	dot = _make_dot(32)
	_define_looks()
	_bake.call_deferred()


func _define_looks() -> void:
	var cloths := Palette.HUMAN_CLOTHES
	for ci in cloths.size():
		for style in 4:
			var skin := Palette.HUMAN_SKIN_LIGHT if (ci + style) % 4 == 0 else Palette.HUMAN_SKIN
			var hair: Color = Palette.HUMAN_HAIRS[(ci + style) % Palette.HUMAN_HAIRS.size()]
			human_looks.append(_add(ActorArt.Kind.HUMAN, cloths[ci], hair, skin, style))
	var zcloths: Array[Color] = [Palette.ZOMBIE_CLOTH, Palette.ZOMBIE_CLOTH.lerp(Palette.CLOTH_PINK, 0.35),
		Palette.ZOMBIE_CLOTH.lerp(Palette.CLOTH_BLUE, 0.35)]
	for zc in zcloths:
		zombie_looks.append(_add(ActorArt.Kind.ZOMBIE, zc, Palette.ZOMBIE_OUTLINE, Palette.ZOMBIE_SKIN, 0))
		zombie_looks.append(_add(ActorArt.Kind.ZOMBIE, zc, Palette.ZOMBIE_OUTLINE, Palette.ZOMBIE_SKIN, 1))
	leader_look = _add(ActorArt.Kind.ZOMBIE, Palette.ZOMBIE_CLOTH, Palette.ZOMBIE_OUTLINE, Palette.ZOMBIE_SKIN, 2)
	police_look = _add(ActorArt.Kind.POLICE, Palette.POLICE, Palette.POLICE_DARK, Palette.HUMAN_SKIN, 0)
	soldier_look = _add(ActorArt.Kind.SOLDIER, Palette.SOLDIER_UNIFORM, Palette.SOLDIER_HELMET, Palette.HUMAN_SKIN, 0)
	survivor_look = _add(ActorArt.Kind.SURVIVOR, Palette.SURV_SHIRT, Palette.SURV_HAIR, Palette.HUMAN_SKIN, 0)
	biker_look = _add(ActorArt.Kind.BIKER, Palette.SURV_SHIRT, Palette.BIKER_HELMET, Palette.HUMAN_SKIN, 0)


## Punto blanco suave (alfa normal) para partículas: 4 vértices en vez de un círculo de 64.
func _make_dot(sz: int) -> Texture2D:
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var c := (sz - 1) * 0.5
	for y in sz:
		for x in sz:
			var d := Vector2(x - c, y - c).length()
			var a := clampf(c - d + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _add(kind: int, cloth: Color, hair: Color, skin: Color, variant: int) -> int:
	looks.append({"kind": kind, "cloth": cloth, "hair": hair, "skin": skin, "variant": variant})
	return looks.size() - 1


func random_human_look() -> int:
	return human_looks[randi() % human_looks.size()]


func random_zombie_look() -> int:
	return zombie_looks[randi() % zombie_looks.size()]


## Rectángulo del cuadro `frame` del look `look` dentro del atlas.
func region(look: int, frame: int) -> Rect2:
	var idx := look * FRAMES + frame
	return Rect2((idx % COLS) * CELL, (idx / COLS) * CELL, CELL, CELL)


func _bake() -> void:
	var rows := int(ceil(float(looks.size() * FRAMES) / COLS))
	texture = await Baker.bake(self, Vector2i(COLS * CELL, rows * CELL), _paint_actors)
	ready_baked.emit()


func _paint_actors(ci: CanvasItem) -> void:
	for li in looks.size():
		var lk: Dictionary = looks[li]
		for f in FRAMES:
			var r := region(li, f)
			ci.draw_set_transform(r.get_center(), 0.0, Vector2.ONE * BAKE_SCALE)
			ActorArt.draw_actor(ci, lk.kind, Vector2.ZERO, BAKE_R, Vector2.DOWN, f * PI * 0.5, 1.0,
				lk.cloth, lk.hair, lk.skin, Color(0, 0, 0, 0), lk.variant, false)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
