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
			var list: Array = _cells.get(key, [])
			if list.is_empty():
				_cells[key] = list
			list.append(index)


## Indices in cells overlapping rect, ascending, without duplicates.
func query_rect(rect: Rect2) -> PackedInt32Array:
	var c0 := cell_of(rect.position)
	var c1 := cell_of(rect.end)
	var out := PackedInt32Array()
	var cells_hit := 0
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var list: Array = _cells.get(Vector2i(cx, cy), [])
			if not list.is_empty():
				cells_hit += 1
				out.append_array(PackedInt32Array(list))
	if cells_hit > 1:
		out.sort()
		var dedup := PackedInt32Array()
		var last := -1
		for v in out:
			if v != last:
				dedup.append(v)
				last = v
		out = dedup
	return out
