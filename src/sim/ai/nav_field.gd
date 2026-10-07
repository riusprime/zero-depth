class_name NavField
extends RefCounted
## A coarse flow field for enemy movement: a grid of CELL metres over the walls' bounds, cells blocked where a
## wall (grown by CLEARANCE) covers their centre, and an 8-way breadth-first distance from the player's cell.
## Rebuilt every PERIOD ticks, at ticks fixed by World.tick, from hashed state only, so it is deterministic.

const CELL := 0.5
const CLEARANCE := 0.6
const PERIOD := 10
const UNREACHED := 1 << 30
## v0.4.0 SC: the world's floods stop this many steps (half-metre cells, diagonals counted as one) from the player,
## about 80 m of path: a whole floor's flood cost up to ~11 ms every PERIOD ticks, while enemies spawn in the
## player's room or a neighbour. An enemy past it has no flow and walks straight until it is back in reach.
const WORLD_FLOOD_STEPS := 160
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
## the region the player stands in, so it never ends in the void outside the floor.
var region := PackedInt32Array()
var _adj_start := PackedInt32Array()
var _adj := PackedInt32Array()
## v0.4.0 SC: the goal cell and step bound of the last flood (x = -1: none since the last build). A flood from the
## same cell with the same bound gives the same distances (the walls don't change between builds), so it is skipped.
var _flooded := Vector3i(-1, -1, -1)


func build(walls: Array[Obb]) -> void:
	_flooded = Vector3i(-1, -1, -1)
	if walls.is_empty():
		size = Vector2i.ZERO
		return
	var r := walls[0].bounds()
	for w in walls:
		r = r.merge(w.bounds())
	origin = r.position
	size = Vector2i(int(ceil(r.size.x / CELL)) + 1, int(ceil(r.size.y / CELL)) + 1)
	blocked.resize(size.x * size.y)
	blocked.fill(0)
	# Each wall is tested only over the cells inside its bounds grown by CLEARANCE: a centre the grown circle
	# touches lies inside them, so the result is the same as testing every wall at every cell.
	for w in walls:
		var b := w.bounds().grow(CLEARANCE)
		var c0 := cell_of(b.position)
		var c1 := cell_of(b.end)
		for y in range(maxi(c0.y, 0), mini(c1.y, size.y - 1) + 1):
			for x in range(maxi(c0.x, 0), mini(c1.x, size.x - 1) + 1):
				var k := y * size.x + x
				if blocked[k] == 0:
					if Collide.circle_vs_obb(center(Vector2i(x, y)), CLEARANCE, w) != Vector2.ZERO:
						blocked[k] = 1
	dist.resize(size.x * size.y)
	dist.fill(UNREACHED)
	_label_regions()
	_build_adjacency()


## The reference build (every wall at every cell), kept for the test that the fast build matches it.
func build_reference(walls: Array[Obb]) -> void:
	_flooded = Vector3i(-1, -1, -1)
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
	_build_adjacency()


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor((p.x - origin.x) / CELL)), int(floor((p.y - origin.y) / CELL)))


func center(c: Vector2i) -> Vector2:
	return origin + (Vector2(c) + Vector2(0.5, 0.5)) * CELL


func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


func _label_regions() -> void:
	region.resize(size.x * size.y)
	region.fill(-1)
	var sx := size.x
	var sy := size.y
	var next := 0
	for start in sx * sy:
		if blocked[start] == 1 or region[start] != -1:
			continue
		var queue := PackedInt32Array([start])
		region[start] = next
		var head := 0
		while head < queue.size():
			var k := queue[head]
			head += 1
			var cx := k % sx
			var cy := k / sx
			for dy in range(-1, 2):
				var ny := cy + dy
				if ny < 0 or ny >= sy:
					continue
				for dx in range(-1, 2):
					var nx := cx + dx
					if nx < 0 or nx >= sx or (dx == 0 and dy == 0):
						continue
					var nk := ny * sx + nx
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


## Breadth-first distances from the goal's cell (the player). Diagonals don't cut blocked corners. Walks the
## adjacency built with the field; distances don't depend on the order neighbours are visited in, so this gives
## exactly what flood_reference gives. Cells more than `max_steps` from the goal stay UNREACHED (v0.4.0 SC).
func flood(goal: Vector2, max_steps: int = UNREACHED) -> void:
	if size == Vector2i.ZERO:
		return
	var g := cell_of(goal)
	var key := Vector3i(g.x, g.y, max_steps)
	if key == _flooded:
		return
	_flooded = key
	dist.fill(UNREACHED)
	if not inside(g):
		return
	var queue := PackedInt32Array()
	queue.resize(size.x * size.y)
	queue[0] = g.y * size.x + g.x
	dist[queue[0]] = 0
	var tail := 1
	var head := 0
	while head < tail:
		var k := queue[head]
		head += 1
		var nd := dist[k] + 1
		if nd > max_steps:
			break
		for j in range(_adj_start[k], _adj_start[k + 1]):
			var nk := _adj[j]
			if dist[nk] == UNREACHED:
				dist[nk] = nd
				queue[tail] = nk
				tail += 1


## Each free cell's steps (8-way, no diagonal past a blocked or missing orthogonal cell), as one flat list:
## cell k's neighbours are _adj[_adj_start[k] .. _adj_start[k + 1] - 1]. Blocked cells have none.
func _build_adjacency() -> void:
	var sx := size.x
	var sy := size.y
	_adj_start.resize(sx * sy + 1)
	_adj.resize(0)
	var out := PackedInt32Array()
	out.resize(sx * sy * 8)
	var n := 0
	for k in sx * sy:
		_adj_start[k] = n
		if blocked[k] == 1:
			continue
		var cx := k % sx
		var cy := k / sx
		var w_ok := cx > 0 and blocked[k - 1] == 0
		var e_ok := cx < sx - 1 and blocked[k + 1] == 0
		var n_ok := cy > 0 and blocked[k - sx] == 0
		var s_ok := cy < sy - 1 and blocked[k + sx] == 0
		# Orthogonal steps are free cells by the checks above; a diagonal also needs its own cell free.
		if w_ok:
			out[n] = k - 1
			n += 1
		if e_ok:
			out[n] = k + 1
			n += 1
		if n_ok:
			out[n] = k - sx
			n += 1
		if s_ok:
			out[n] = k + sx
			n += 1
		if n_ok and w_ok and blocked[k - sx - 1] == 0:
			out[n] = k - sx - 1
			n += 1
		if n_ok and e_ok and blocked[k - sx + 1] == 0:
			out[n] = k - sx + 1
			n += 1
		if s_ok and w_ok and blocked[k + sx - 1] == 0:
			out[n] = k + sx - 1
			n += 1
		if s_ok and e_ok and blocked[k + sx + 1] == 0:
			out[n] = k + sx + 1
			n += 1
	_adj_start[sx * sy] = n
	out.resize(n)
	_adj = out


## The reference flood (the original loop over STEPS), kept for the test that the fast flood matches it.
func flood_reference(goal: Vector2) -> void:
	_flooded = Vector3i(-1, -1, -1)
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
