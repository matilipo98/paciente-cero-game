class_name Baker
extends RefCounted
## "Hornea" dibujos procedurales en una textura una sola vez (SubViewport → ImageTexture).
## Así el mapa y los personajes se dibujan con un solo rectángulo texturizado por frame,
## en lugar de cientos de círculos y arcos recalculados.
## En modo headless (sin GPU) devuelve null y el juego sigue usando el dibujo procedural.

## El resultado viene con alfa premultiplicado: dibujarlo con premult_material().
static var _premult: CanvasItemMaterial = null


class BakeCanvas extends Node2D:
	var painter: Callable

	func _draw() -> void:
		painter.call(self)


static func premult_material() -> CanvasItemMaterial:
	if _premult == null:
		_premult = CanvasItemMaterial.new()
		_premult.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	return _premult


static func can_bake() -> bool:
	return DisplayServer.get_name() != "headless"


## painter: func(ci: CanvasItem) que dibuja en coordenadas de la textura (0..size).
static func bake(host: Node, size: Vector2i, painter: Callable, transparent: bool = true) -> Texture2D:
	if not can_bake():
		return null
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = transparent
	vp.disable_3d = true
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var canvas := BakeCanvas.new()
	canvas.painter = painter
	vp.add_child(canvas)
	host.add_child(vp)
	await RenderingServer.frame_post_draw
	if not is_instance_valid(vp):
		return null
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		return null
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Variante: hornea un nodo ya armado (por ejemplo, una copia del mapa con su transform).
static func bake_node(host: Node, size: Vector2i, node: Node, transparent: bool = false) -> Texture2D:
	if not can_bake():
		node.free()
		return null
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = transparent
	vp.disable_3d = true
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.add_child(node)
	host.add_child(vp)
	await RenderingServer.frame_post_draw
	if not is_instance_valid(vp):
		return null
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)
