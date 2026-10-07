class_name FloorReach
extends RefCounted
## A walkability grid over a rectangle: CELL-metre cells, blocked where a wall grown by a clearance covers the
## cell centre, labelled into 4-connected regions. The generator uses it per room; tests use it per floor.
## Walls are rasterised through their bounds only, so a whole floor builds quickly.

const CELL := 0.5

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
	var sx := size.x
	var sy := size.y
	region.resize(sx * sy)
	region.fill(-1)
	region_count = 0
	var queue := PackedInt32Array()
	queue.resize(sx * sy)
	for start in sx * sy:
		if blocked[start] == 1 or region[start] != -1:
			continue
		queue[0] = start
		var tail := 1
		region[start] = region_count
		var head := 0
		while head < tail:
			var k := queue[head]
			head += 1
			var cx := k % sx
			if cx > 0 and blocked[k - 1] == 0 and region[k - 1] == -1:
				region[k - 1] = region_count
				queue[tail] = k - 1
				tail += 1
			if cx < sx - 1 and blocked[k + 1] == 0 and region[k + 1] == -1:
				region[k + 1] = region_count
				queue[tail] = k + 1
				tail += 1
			if k >= sx and blocked[k - sx] == 0 and region[k - sx] == -1:
				region[k - sx] = region_count
				queue[tail] = k - sx
				tail += 1
			if k + sx < sx * sy and blocked[k + sx] == 0 and region[k + sx] == -1:
				region[k + sx] = region_count
				queue[tail] = k + sx
				tail += 1
		region_count += 1
