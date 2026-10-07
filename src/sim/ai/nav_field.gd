class_name NavField
extends RefCounted
## A coarse flow field for enemy movement: a grid of CELL metres over the walls' bounds, cells blocked where a
## wall (grown by CLEARANCE) covers their centre, and an 8-way breadth-first distance from the player's cell.
## Rebuilt every PERIOD ticks, at ticks fixed by World.tick, from hashed state only, so it is deterministic.

const CELL := 0.5
const CLEARANCE := 0.6
const PERIOD := 10
const UNREACHED := 1 << 30
const STEPS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, 1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(-1, -1),
]

var origin := Vector2.ZERO
var size := Vector2i.ZERO
var blocked := PackedByteArray()
var dist := PackedInt32Array()
## Connected region per free cell (-1 for blocked), labelled once from the static walls. A blink may only land in
## the region the player stands in, so it never ends outside the room.
var region := PackedInt32Array()


func build(walls: Array[Obb]) -> void:
	if walls.is_empty():
		size = Vector2i.ZERO
		return
	var r := walls[0].bounds()
	for w in walls:
		r = r.merge(w.bounds())
	origin = r.position
	size = Vector2i(int(ceil(r.size.x / CELL)) + 1, int(ceil(r.size.y / CELL)) + 1)
	blocked.resize(size.x * size.y)
	for y in size.y:
		for x in size.x:
			var c := center(Vector2i(x, y))
			var hit := 0
			for w in walls:
				if Collide.circle_vs_obb(c, CLEARANCE, w) != Vector2.ZERO:
					hit = 1
					break
			blocked[y * size.x + x] = hit
	dist.resize(size.x * size.y)
	dist.fill(UNREACHED)
	_label_regions()


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor((p.x - origin.x) / CELL)), int(floor((p.y - origin.y) / CELL)))


func center(c: Vector2i) -> Vector2:
	return origin + (Vector2(c) + Vector2(0.5, 0.5)) * CELL


func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


func _label_regions() -> void:
	region.resize(size.x * size.y)
	region.fill(-1)
	var next := 0
	for start in size.x * size.y:
		if blocked[start] == 1 or region[start] != -1:
			continue
		var queue := PackedInt32Array([start])
		region[start] = next
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
					region[nk] = next
					queue.append(nk)
		next += 1


## The region of the free cell nearest p (searching up to 2 cells out), or -1. 0 when there's no field.
func region_near(p: Vector2) -> int:
	if size == Vector2i.ZERO:
		return 0
	var c := cell_of(p)
	for r in 3:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if inside(n) and region[n.y * size.x + n.x] >= 0:
					return region[n.y * size.x + n.x]
	return -1


## Breadth-first distances from the goal's cell (the player). Diagonals don't cut blocked corners.
func flood(goal: Vector2) -> void:
	if size == Vector2i.ZERO:
		return
	dist.fill(UNREACHED)
	var g := cell_of(goal)
	if not inside(g):
		return
	var queue := PackedInt32Array([g.y * size.x + g.x])
	dist[queue[0]] = 0
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
			if blocked[nk] == 1 or dist[nk] != UNREACHED:
				continue
			if s.x != 0 and s.y != 0:
				if blocked[c.y * size.x + n.x] == 1 or blocked[n.y * size.x + c.x] == 1:
					continue
			dist[nk] = dist[k] + 1
			queue.append(nk)


## The direction (unit) from p toward the neighbouring cell closest to the goal, or ZERO if none is better.
func direction(p: Vector2) -> Vector2:
	var c := cell_of(p)
	if not inside(c):
		return Vector2.ZERO
	var best := dist[c.y * size.x + c.x]
	var pick := Vector2i(-1, -1)
	for s in STEPS:
		var n := c + s
		if not inside(n):
			continue
		var d := dist[n.y * size.x + n.x]
		if d < best:
			best = d
			pick = n
	if pick.x < 0:
		return Vector2.ZERO
	var to := center(pick) - p
	var l := Kin.length(to)
	return to / l if l > 0.0001 else Vector2.ZERO
