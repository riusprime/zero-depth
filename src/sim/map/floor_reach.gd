class_name FloorReach
extends RefCounted
## A walkability grid over a rectangle: CELL-metre cells, blocked where a wall grown by a clearance covers the
## cell centre, labelled into 4-connected regions. The generator uses it per room; tests use it per floor.
## Walls are rasterised through their bounds only, so a whole floor builds quickly.

const CELL := 0.5
const STEPS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var origin := Vector2.ZERO
var size := Vector2i.ZERO
var blocked := PackedByteArray()
## Region id per cell, -1 where blocked.
var region := PackedInt32Array()
var region_count := 0


func build(rect: Rect2, walls: Array[Obb], clearance: float) -> void:
	origin = rect.position
	size = Vector2i(maxi(1, int(ceil(rect.size.x / CELL))), maxi(1, int(ceil(rect.size.y / CELL))))
	blocked.resize(size.x * size.y)
	blocked.fill(0)
	for w in walls:
		var b := w.bounds().grow(clearance)
		var c0 := cell_of(b.position)
		var c1 := cell_of(b.end)
		for y in range(maxi(c0.y, 0), mini(c1.y, size.y - 1) + 1):
			for x in range(maxi(c0.x, 0), mini(c1.x, size.x - 1) + 1):
				var k := y * size.x + x
				if blocked[k] == 0:
					if Collide.circle_vs_obb(center(Vector2i(x, y)), clearance, w) != Vector2.ZERO:
						blocked[k] = 1
	_label()


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor((p.x - origin.x) / CELL)), int(floor((p.y - origin.y) / CELL)))


func center(c: Vector2i) -> Vector2:
	return origin + (Vector2(c) + Vector2(0.5, 0.5)) * CELL


func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


## The region of p's cell, or -1 if that cell is blocked or outside the grid.
func region_at(p: Vector2) -> int:
	var c := cell_of(p)
	if not inside(c):
		return -1
	return region[c.y * size.x + c.x]


func free_cells() -> int:
	var n := 0
	for b in blocked:
		if b == 0:
			n += 1
	return n


func _label() -> void:
	region.resize(size.x * size.y)
	region.fill(-1)
	region_count = 0
	for start in size.x * size.y:
		if blocked[start] == 1 or region[start] != -1:
			continue
		var queue := PackedInt32Array([start])
		region[start] = region_count
		var head := 0
		while head < queue.size():
			var k := queue[head]
			head += 1
			var c := Vector2i(k % size.x, k / size.x)
			for s in STEPS:
				var n := c + s
				if not inside(n):
					continue
				var nk := n.y * size.x + n.x
				if blocked[nk] == 0 and region[nk] == -1:
					region[nk] = region_count
					queue.append(nk)
		region_count += 1
