class_name SpatialGrid
extends RefCounted
## Grilla espacial simple para consultas de vecindad (evita O(n²) en hordas grandes).
## Se reconstruye una vez por frame; las consultas devuelven candidatos (filtrar por distancia).

var cell_size: float
var _inv: float
var cells: Dictionary = {}


func _init(size: float = 64.0) -> void:
	cell_size = size
	_inv = 1.0 / size


func clear() -> void:
	cells.clear()


func insert(item: Object, pos: Vector2) -> void:
	var key := Vector2i(floori(pos.x * _inv), floori(pos.y * _inv))
	var bucket: Array = cells.get(key, [])
	if bucket.is_empty():
		cells[key] = bucket
	bucket.append(item)


## Llena `out` con los elementos de las celdas que tocan el círculo (pos, radius).
func query(pos: Vector2, radius: float, out: Array) -> void:
	out.clear()
	var x0 := floori((pos.x - radius) * _inv)
	var x1 := floori((pos.x + radius) * _inv)
	var y0 := floori((pos.y - radius) * _inv)
	var y1 := floori((pos.y + radius) * _inv)
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var bucket = cells.get(Vector2i(x, y))
			if bucket != null:
				out.append_array(bucket)
