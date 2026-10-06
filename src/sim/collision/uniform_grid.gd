class_name UniformGrid
extends RefCounted
## Broadphase over 1 m cells. Each cell holds entity indices in insertion (id) order.
## Dictionaries are only looked up by key, never iterated (SIM_CONTRACTS §4).

var cell_size := 1.0
var _cells := {}


func clear() -> void:
	_cells.clear()


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / cell_size)), int(floor(p.y / cell_size)))


func insert_rect(index: int, rect: Rect2) -> void:
	var c0 := cell_of(rect.position)
	var c1 := cell_of(rect.end)
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var key := Vector2i(cx, cy)
			if not _cells.has(key):
				_cells[key] = PackedInt32Array()
			var list: PackedInt32Array = _cells[key]
			list.append(index)
			_cells[key] = list


## Indices in cells overlapping rect, ascending, without duplicates.
func query_rect(rect: Rect2) -> PackedInt32Array:
	var c0 := cell_of(rect.position)
	var c1 := cell_of(rect.end)
	var out := PackedInt32Array()
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var key := Vector2i(cx, cy)
			if _cells.has(key):
				out.append_array(_cells[key])
	if out.size() > 1:
		out.sort()
		var dedup := PackedInt32Array()
		var last := -1
		for v in out:
			if v != last:
				dedup.append(v)
				last = v
		out = dedup
	return out
