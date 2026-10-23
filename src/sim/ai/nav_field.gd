class_name NavField
extends RefCounted
## A coarse flow field for enemy movement: a grid of CELL metres over the walls' bounds, cells blocked where a
## wall (grown by CLEARANCE) covers their centre, and a distance from the player's cell over the free cells.
## Rebuilt every PERIOD ticks, at ticks fixed by World.tick, from hashed state only, so it is deterministic.
## v0.8.0 P1 (owner O23: enemies "sometimes getting stuck behind walls or in adjacent rooms"): the distance is the
## shortest path in integer octile steps (ORTHO a side, DIAG a diagonal: 5 and 7, about 1 : 1.4) by a bucketed
## Dijkstra, not an 8-way breadth-first count (where a diagonal cost the same as a side, so a door off at 45 degrees
## looked as near as one straight ahead and the field could pick the longer way). A player standing in a blocked
## cell (within CLEARANCE of a wall: along a wall or in a doorway) seeds the free cells it can reach within SEED_CELLS
## instead (the old flood started from the blocked cell, which has no steps, and reached nothing, so every enemy
## out of sight walked straight into the walls). And the world's flood stops TARGET_MARGIN past the farthest enemy
## (O32: a whole floor's flood was ~11 ms; the enemies stand in the player's room or a neighbour).

const CELL := 0.5
const CLEARANCE := 0.6
const PERIOD := 10
const UNREACHED := 1 << 30
## v0.4.0 SC: the world's floods stop this many steps (half-metre cells) from the player, about 80 m of path: a whole
## floor's flood cost up to ~11 ms every PERIOD ticks, while enemies spawn in the player's room or a neighbour. An
## enemy past it has no flow and walks straight until it is back in reach. v0.8.0 P1: a bound in sides (ORTHO each).
const WORLD_FLOOD_STEPS := 160
## v0.8.0 P1: a side's and a diagonal's cost (integers: the flood is exact and the same on every machine).
const ORTHO := 5
const DIAG := 7
## The bucket ring of the flood: one bucket per distance modulo RING (more than DIAG, the largest step).
const RING := 8
## v0.8.0 P1: a flood given targets (the enemies' cells) stops this far past the last of them to settle: 8 sides
## (4 m), more than any enemy walks in PERIOD ticks, so each keeps a field under it until the next flood.
const TARGET_MARGIN := 8 * ORTHO
## v0.8.0 P1: a player in a blocked cell seeds the free cells within this many cells that it reaches without
## crossing a wall (side steps through cells whose centre is SEED_CLEARANCE clear of every wall).
const SEED_CELLS := 2
const SEED_CLEARANCE := 0.25
## v0.8.0 NF (owner O90, "A then"): the world's periodic flood is built over this many ticks (begin_build, advance),
## at least SLICE_MIN cells of work a slice before the last.
const SLICES := 3
const SLICE_MIN := 64
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

## v0.8.0 P1: the flood's scratch (one flood runs at a time): the bucket ring (RING buckets of a field's cell count;
## a bucket holds one distance, and a cell enters it at most once) and the target marks. Derived, never hashed.
static var _ring := PackedInt32Array()
static var _want := PackedByteArray()
## v0.9.0 RG: for the floor censuses only (the special-room property tests and scripts/balance/room_pacing.gd, which
## build thousands of floors and never step them): true makes build() leave an empty field, as with no walls. No
## placement reads the field (test_special_room_rules proves the rooms match with it on). Never set by the game.
static var skip_build := false

var origin := Vector2.ZERO
var size := Vector2i.ZERO
var blocked := PackedByteArray()
var dist := PackedInt32Array()
## Connected region per free cell (-1 for blocked), labelled once from the static walls. A blink may only land in
## the region the player stands in, so it never ends in the void outside the floor.
var region := PackedInt32Array()
## v0.8.0 BS1 (owner O5, S1): cells blocked for a while on top of the walls (the Gatekeeper's standing pillars), by
## the same clearance rule; the flood goes round them. Empty = none. set_extra sets it; a build clears it.
var extra := PackedByteArray()
## v0.8.0 NF (owner O90): the work (cells taken from the buckets) of the last flood; a build's budget per slice is a
## SLICES-th of it. Copied in a snapshot, carried when the world swaps fields.
var last_work := 0
var _adj_start := PackedInt32Array()
var _adj := PackedInt32Array()
## v0.8.0 P1: each step's cost (ORTHO or DIAG), beside _adj.
var _adj_w := PackedByteArray()
## v0.8.0 P1: the walls the field was built from (the blocked-goal seeds check they don't cross one).
var _walls: Array[Obb] = []
## v0.4.0 SC: the goal cell and step bound of the last flood (x = -1: none since the last build). A flood from the
## same cell with the same bound gives the same distances (the walls don't change between builds), so it is skipped.
## v0.8.0 P1: z is -1 - the bound when that flood stopped early at its targets: it is skipped again only while every
## target it is given is still reached.
var _flooded := Vector3i(-1, -1, -1)
## v0.8.0 NF: the build in progress (begin_build .. advance): whether there is one, its slices run, budget, bound and
## targets (with its goal, in _f_key, all a snapshot needs: restore_build runs its slices again), and the back field's
## buffers while none runs (a build moves them into the fill's).
var _b_on := false
var _b_slices := 0
var _b_budget := 0
var _b_max := 0
var _b_targets := PackedInt32Array()
var _back := PackedInt32Array()
var _b_ring := PackedInt32Array()
var _b_want := PackedByteArray()
## v0.8.0 NF: the fill's state (flood() runs one to the end at once; a build runs one a slice a tick): its distances,
## bucket ring, target marks, bucket lengths, seeds and targets, and where its loop stands. Derived, never hashed.
var _f_d := PackedInt32Array()
var _f_ring := PackedInt32Array()
var _f_want := PackedByteArray()
var _f_lens := PackedInt32Array()
var _f_seeds := PackedInt32Array()
var _f_targets := PackedInt32Array()
var _f_key := Vector3i(-1, -1, -1)
var _f_last_seed := -1
var _f_bound := 0
var _f_open := true
var _f_cur := 0
var _f_queued := 0
var _f_left := 0
var _f_stop := 0
var _f_work := 0


func build(walls: Array[Obb]) -> void:
	cancel_build()  # v0.8.0 NF: the walls or extra cells change: a build in progress is dropped
	_flooded = Vector3i(-1, -1, -1)
	extra = PackedByteArray()
	_walls = walls.duplicate()
	if walls.is_empty() or skip_build:
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


## v0.8.0 BS1 (S1): blocks the cells these boxes cover (grown by CLEARANCE, as build) on top of the walls, replacing
## the last set (empty: none). The next flood runs again. v0.8.0 BS2 (S6): also the cells of each meltdown in
## `melts` (BossLava.melt_shapes: the outer ring of a room, a cool bridge left open), grown the same way.
func set_extra(boxes: Array[Obb], melts: Array = []) -> void:
	cancel_build()  # v0.8.0 NF: the walls or extra cells change: a build in progress is dropped
	_flooded = Vector3i(-1, -1, -1)
	if (boxes.is_empty() and melts.is_empty()) or size == Vector2i.ZERO:
		extra = PackedByteArray()
		return
	extra.resize(size.x * size.y)
	extra.fill(0)
	for m: Array in melts:
		var r: Rect2 = m[BossLava.MELT_BOUND]
		var c0 := cell_of(r.position)
		var c1 := cell_of(r.end)
		for y in range(maxi(c0.y, 0), mini(c1.y, size.y - 1) + 1):
			for x in range(maxi(c0.x, 0), mini(c1.x, size.x - 1) + 1):
				if BossLava.melt_covers(m, center(Vector2i(x, y)), CLEARANCE):
					extra[y * size.x + x] = 1
	for w in boxes:
		var b := w.bounds().grow(CLEARANCE)
		var c0 := cell_of(b.position)
		var c1 := cell_of(b.end)
		for y in range(maxi(c0.y, 0), mini(c1.y, size.y - 1) + 1):
			for x in range(maxi(c0.x, 0), mini(c1.x, size.x - 1) + 1):
				var k := y * size.x + x
				if extra[k] == 0:
					if Collide.circle_vs_obb(center(Vector2i(x, y)), CLEARANCE, w) != Vector2.ZERO:
						extra[k] = 1


## The reference build (every wall at every cell), kept for the test that the fast build matches it. Kept on
## purpose as the parity oracle for build (owner keeps safety nets; audit G-22): change it with build, never drop it.
func build_reference(walls: Array[Obb]) -> void:
	cancel_build()  # v0.8.0 NF: the walls or extra cells change: a build in progress is dropped
	_flooded = Vector3i(-1, -1, -1)
	_walls = walls.duplicate()
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


## Shortest-path distances from the goal's cell (the player), in ORTHO / DIAG steps; diagonals don't cut blocked
## corners. A bucketed Dijkstra over the adjacency built with the field: each distance's bucket is emptied in turn,
## and a cell's distance is final when its bucket comes round, so the result doesn't depend on the order neighbours
## are visited in and is exactly what flood_reference gives. Cells more than `max_steps` sides (ORTHO each) from the
## goal stay UNREACHED (v0.4.0 SC). A blocked goal cell seeds the free cells next to it (_seeds).
## v0.8.0 P1 (O32): `targets` (cell indices, target_cell's; -1 skipped) lets the flood stop TARGET_MARGIN past the
## last of them to settle; cells past that keep UNREACHED or a not-yet-final distance (an upper bound) that no enemy
## stands on. A target that is never reached (another region, past the bound) leaves the flood whole.
## v0.8.0 NF: floods at once (the walls changed: add_wall_now, remove_wall_now, set_nav_extra; or the first flood);
## a build in progress (begin_build) is dropped.
func flood(goal: Vector2, max_steps: int = UNREACHED, targets := PackedInt32Array()) -> void:
	cancel_build()
	if size == Vector2i.ZERO:
		return
	var g := cell_of(goal)
	if _skips(g, max_steps, targets):
		return
	_flooded = Vector3i(g.x, g.y, max_steps)
	if not inside(g):
		dist.fill(UNREACHED)
		return
	var n := size.x * size.y
	if _ring.size() < RING * n:
		_ring.resize(RING * n)
	if not targets.is_empty() and _want.size() < n:
		_want.resize(n)
		_want.fill(0)
	# The arrays the fill writes are held by it only while it runs (no copy on write; members get them back).
	_f_d = dist
	dist = PackedInt32Array()
	_f_ring = _ring
	_ring = PackedInt32Array()
	_f_want = _want
	_want = PackedByteArray()
	_begin(g, max_steps, targets)
	_run(UNREACHED)
	_flooded = _f_key
	last_work = _f_work
	dist = _f_d
	_ring = _f_ring
	_want = _f_want
	_f_d = PackedInt32Array()
	_f_ring = PackedInt32Array()
	_f_want = PackedByteArray()


## v0.4.0 SC / v0.8.0 P1: a flood from cell g with this bound would give the distances already there: the last flood
## was from the same cell with the same bound, or it stopped at its targets and every target given is still reached.
func _skips(g: Vector2i, max_steps: int, targets: PackedInt32Array) -> bool:
	if g.x != _flooded.x or g.y != _flooded.y:
		return false
	if _flooded.z == max_steps:
		return true
	return _flooded.z == -1 - max_steps and not targets.is_empty() and _all_reached(targets)


## v0.8.0 NF (owner O90, "A then"): the world's periodic flood, built over SLICES ticks into the back field and
## swapped in whole when it is done (advance); until then every reader sees the live field (dist). The build is the
## flood() from this goal, bound and targets, run in slices: skipped by the same rule, and its result (distances and
## key) is exactly flood()'s. A field never flooded since its build floods at once instead (World).
func begin_build(goal: Vector2, max_steps: int, targets: PackedInt32Array) -> void:
	cancel_build()
	if size == Vector2i.ZERO:
		return
	var g := cell_of(goal)
	if _skips(g, max_steps, targets):
		return
	if not inside(g):
		flood(goal, max_steps, targets)  # nothing to build: no distances at all
		return
	_start_build(g, max_steps, targets, maxi(SLICE_MIN, (last_work + SLICES - 1) / SLICES))


func _start_build(g: Vector2i, max_steps: int, targets: PackedInt32Array, budget: int) -> void:
	var n := size.x * size.y
	_back.resize(n)
	if _b_ring.size() < RING * n:
		_b_ring.resize(RING * n)
	_b_want.resize(n)
	_b_want.fill(0)
	_f_d = _back
	_back = PackedInt32Array()
	_f_ring = _b_ring
	_b_ring = PackedInt32Array()
	_f_want = _b_want
	_b_want = PackedByteArray()
	_b_on = true
	_b_slices = 0
	_b_budget = budget
	_b_max = max_steps
	_b_targets = targets.duplicate()
	_begin(g, max_steps, targets)


## v0.8.0 NF: whether a build is in progress (begin_build; advance runs its next slice).
func building() -> bool:
	return _b_on


## v0.8.0 NF: the build's next slice. Slices before the last stop once the build's work (cells taken from the
## buckets) reaches the budget times their number; the last (the SLICES-th) runs to the end. A build that is done
## swaps in as the live field (its key too), and the old field becomes the next back buffer.
func advance() -> void:
	if not _b_on:
		return
	var limit := UNREACHED if _b_slices >= SLICES - 1 else _b_budget * (_b_slices + 1)
	var done := _run(limit)
	_b_slices += 1
	if not done:
		return
	_flooded = _f_key
	last_work = _f_work
	_back = dist
	dist = _f_d
	_b_ring = _f_ring
	_b_want = _f_want
	_f_d = PackedInt32Array()
	_f_ring = PackedInt32Array()
	_f_want = PackedByteArray()
	_b_on = false


## v0.8.0 NF: drops a build in progress (the walls or extra cells changed, or a flood ran at once); the live field
## stays as it is.
func cancel_build() -> void:
	if not _b_on:
		return
	_back = _f_d
	_b_ring = _f_ring
	_b_want = _f_want
	_f_d = PackedInt32Array()
	_f_ring = PackedInt32Array()
	_f_want = PackedByteArray()
	_b_on = false


## v0.8.0 NF: a build in progress as plain data (a save: WorldSnapshot), {} with none: its goal cell, bound, targets,
## budget and slices run. The rest is derived: restore_build runs the same slices again.
func build_state() -> Dictionary:
	if not _b_on:
		return {}
	return {
		"g": Vector2i(_f_key.x, _f_key.y),
		"max": _b_max,
		"targets": _b_targets.duplicate(),
		"budget": _b_budget,
		"slices": _b_slices,
	}


## v0.8.0 NF: restores build_state's build ({} = none) on this field (its walls and extra cells set as they were):
## starts it again and runs the slices it had run, so it stands where it stood.
func restore_build(state: Dictionary) -> void:
	cancel_build()
	if state.is_empty() or size == Vector2i.ZERO:
		return
	_start_build(
		state["g"], int(state["max"]), state["targets"] as PackedInt32Array, int(state["budget"])
	)
	for i in int(state["slices"]):
		advance()


## v0.8.0 NF: whether the field was never flooded since its build (or since its extra cells changed).
func never_flooded() -> bool:
	return _flooded == Vector3i(-1, -1, -1)


## v0.8.0 NF: a fill's start (flood() and begin_build); _f_d, _f_ring and _f_want hold its arrays (moved in).
func _begin(g: Vector2i, max_steps: int, targets: PackedInt32Array) -> void:
	var n := size.x * size.y
	var d := _f_d
	_f_d = PackedInt32Array()
	d.fill(UNREACHED)
	_f_d = d
	_f_lens = PackedInt32Array()
	_f_lens.resize(RING)
	_f_lens.fill(0)
	_f_open = extra.is_empty()  # v0.8.0 BS1: no standing pillars (the common case: no extra test)
	_f_bound = mini(max_steps, UNREACHED / ORTHO - 1) * ORTHO
	_f_queued = 0
	_f_cur = 0
	_f_work = 0
	_f_key = Vector3i(g.x, g.y, max_steps)
	# The seeds go in as their distance comes round (one goes past RING when the goal cell is blocked).
	_f_seeds = _seeds(g, _f_open)
	_f_last_seed = -1
	for s in range(1, _f_seeds.size(), 2):
		_f_last_seed = maxi(_f_last_seed, _f_seeds[s])
	# Targets: marked in want (cleared again when the fill ends); `left` counts the marked cells not yet settled.
	_f_targets = targets
	_f_left = 0
	if not targets.is_empty():
		var want := _f_want
		_f_want = PackedByteArray()
		for k in targets:
			if k >= 0 and k < n and want[k] == 0:
				want[k] = 1
				_f_left += 1
		_f_want = want
	_f_stop = UNREACHED


## v0.8.0 NF: runs the fill until it ends or its work (cells taken from the buckets) reaches `limit` (checked between
## buckets, so the same slices every run). Returns whether it ended; an ended fill's key says if it stopped early.
func _run(limit: int) -> bool:
	var n := size.x * size.y
	# The arrays the loop writes are held in locals only while it runs (no copy on write; members get them back).
	var d := _f_d
	_f_d = PackedInt32Array()
	var ring := _f_ring
	_f_ring = PackedInt32Array()
	var want := _f_want
	_f_want = PackedByteArray()
	var lens := _f_lens
	_f_lens = PackedInt32Array()
	var seeds := _f_seeds
	var last_seed := _f_last_seed
	var bound := _f_bound
	var open := _f_open
	var cur := _f_cur
	var queued := _f_queued
	var left := _f_left
	var stop := _f_stop
	var work := _f_work
	var adj := _adj
	var adj_w := _adj_w
	var adj_start := _adj_start
	while (queued > 0 or cur <= last_seed) and cur <= bound and cur <= stop:
		if work >= limit:
			break
		var b := cur % RING
		var base := b * n
		if cur <= last_seed:
			for s in range(0, seeds.size(), 2):
				var sk := seeds[s]
				if seeds[s + 1] == cur and cur < d[sk]:
					d[sk] = cur
					ring[base + lens[b]] = sk
					lens[b] += 1
					queued += 1
		var count := lens[b]
		work += count
		# Far from the bound and with no extra cells, the step test is the distance alone (the common case).
		var plain := open and cur + DIAG <= bound
		for q in count:
			var k := ring[base + q]
			if d[k] != cur:
				continue  # a stale entry: the cell was reached shorter after it was queued
			if left > 0 and want[k] == 1:
				want[k] = 0
				left -= 1
				if left == 0:
					stop = cur + TARGET_MARGIN
			if plain:
				for j in range(adj_start[k], adj_start[k + 1]):
					var nk := adj[j]
					var nd := cur + adj_w[j]
					if nd < d[nk]:
						d[nk] = nd
						var nb := nd % RING
						ring[nb * n + lens[nb]] = nk
						lens[nb] += 1
						queued += 1
			else:
				for j in range(adj_start[k], adj_start[k + 1]):
					var nk := adj[j]
					var nd := cur + adj_w[j]
					if nd < d[nk] and nd <= bound and (open or extra[nk] == 0):
						d[nk] = nd
						var nb := nd % RING
						ring[nb * n + lens[nb]] = nk
						lens[nb] += 1
						queued += 1
		queued -= count
		lens[b] = 0
		cur += 1
	var done := not ((queued > 0 or cur <= last_seed) and cur <= bound and cur <= stop)
	if done:
		if left > 0:
			for k in _f_targets:
				if k >= 0 and k < n:
					want[k] = 0
			left = 0
		elif stop < UNREACHED and queued > 0 and cur <= bound:
			_f_key.z = -1 - _f_key.z  # stopped at its targets: the cells past them aren't finished
	_f_d = d
	_f_ring = ring
	_f_want = want
	_f_lens = lens
	_f_cur = cur
	_f_queued = queued
	_f_left = left
	_f_stop = stop
	_f_work = work
	return done


## v0.8.0 P1: whether every target cell (-1 skipped) has a distance.
func _all_reached(targets: PackedInt32Array) -> bool:
	for k in targets:
		if k >= 0 and k < dist.size() and dist[k] == UNREACHED:
			return false
	return true


## v0.8.0 P1: the flood's start cells as flat [cell, distance] pairs: the goal cell at 0 when it is free, or else
## every free cell within SEED_CELLS that the goal reaches by side steps through cells SEED_CLEARANCE clear of the
## walls (so never through one), at its octile distance from the goal cell. Empty when there is none.
func _seeds(g: Vector2i, open: bool) -> PackedInt32Array:
	var gk := g.y * size.x + g.x
	if blocked[gk] == 0 and (open or extra[gk] == 0):
		return PackedInt32Array([gk, 0])
	var r := SEED_CELLS
	var span := 2 * r + 1
	var lo := center(g) - Vector2.ONE * (CELL * r + SEED_CLEARANCE)
	var area := Rect2(lo, Vector2.ONE * (CELL * (span - 1) + 2.0 * SEED_CLEARANCE))
	var near: Array[Obb] = []
	for w in _walls:
		if w.bounds().intersects(area):
			near.append(w)
	# 0 = not yet seen, 1 = passable and seen, 2 = inside a wall (grown by SEED_CLEARANCE).
	var seen := PackedByteArray()
	seen.resize(span * span)
	seen.fill(0)
	var out := PackedInt32Array()
	var queue := PackedInt32Array([r * span + r])
	seen[r * span + r] = 1
	var head := 0
	while head < queue.size():
		var q := queue[head]
		head += 1
		var c := g + Vector2i(q % span - r, q / span - r)
		var ck := c.y * size.x + c.x
		if blocked[ck] == 0 and (open or extra[ck] == 0):
			var dx := absi(c.x - g.x)
			var dy := absi(c.y - g.y)
			out.append(ck)
			out.append(ORTHO * absi(dx - dy) + DIAG * mini(dx, dy))
		for s in 4:
			var st: Vector2i = STEPS[s]
			var lx := q % span + st.x
			var ly := q / span + st.y
			if lx < 0 or ly < 0 or lx >= span or ly >= span or seen[ly * span + lx] != 0:
				continue
			var nc := g + Vector2i(lx - r, ly - r)
			if not inside(nc):
				continue
			var p := center(nc)
			var clear := 1
			for w in near:
				if Collide.circle_vs_obb(p, SEED_CLEARANCE, w) != Vector2.ZERO:
					clear = 2
					break
			seen[ly * span + lx] = clear
			if clear == 1:
				queue.append(ly * span + lx)
	return out


## v0.8.0 P1: the cell an enemy at p reads the field from, as a flood target (cell index): its own when free, else
## the first free one of its neighbours (STEPS order) a step can reach; -1 outside the field or with none.
func target_cell(p: Vector2) -> int:
	var c := cell_of(p)
	if not inside(c):
		return -1
	var k := c.y * size.x + c.x
	if blocked[k] == 0:
		return k
	for s in STEPS:
		var nc := c + s
		if inside(nc) and blocked[nc.y * size.x + nc.x] == 0:
			return nc.y * size.x + nc.x
	return -1


## v0.8.0 BS2 (S6): the free cells reachable from `starts` (cell indices) by the field's steps without entering a
## cell `avoid` marks (1) or leaving `bound` (cells), as a mask over the grid (1 = reached). The fairness check of
## the Foundry's lava (BossSignatures: a way to the boss and to an exit always stays).
func reach(starts: PackedInt32Array, avoid: PackedByteArray, bound: Rect2i) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(size.x * size.y)
	seen.fill(0)
	var queue := PackedInt32Array()
	queue.resize(size.x * size.y)
	var tail := 0
	for k in starts:
		if k >= 0 and k < seen.size() and seen[k] == 0 and blocked[k] == 0 and avoid[k] == 0:
			seen[k] = 1
			queue[tail] = k
			tail += 1
	var head := 0
	while head < tail:
		var k := queue[head]
		head += 1
		for j in range(_adj_start[k], _adj_start[k + 1]):
			var nk := _adj[j]
			if seen[nk] == 1 or avoid[nk] == 1:
				continue
			if not bound.has_point(Vector2i(nk % size.x, nk / size.x)):
				continue
			seen[nk] = 1
			queue[tail] = nk
			tail += 1
	return seen


## Each free cell's steps (8-way, no diagonal past a blocked or missing orthogonal cell), as one flat list:
## cell k's neighbours are _adj[_adj_start[k] .. _adj_start[k + 1] - 1]. Blocked cells have none.
func _build_adjacency() -> void:
	var sx := size.x
	var sy := size.y
	_adj_start.resize(sx * sy + 1)
	_adj.resize(0)
	var out := PackedInt32Array()
	out.resize(sx * sy * 8)
	var wts := PackedByteArray()  # v0.8.0 P1: each step's cost
	wts.resize(sx * sy * 8)
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
			wts[n] = ORTHO
			n += 1
		if e_ok:
			out[n] = k + 1
			wts[n] = ORTHO
			n += 1
		if n_ok:
			out[n] = k - sx
			wts[n] = ORTHO
			n += 1
		if s_ok:
			out[n] = k + sx
			wts[n] = ORTHO
			n += 1
		if n_ok and w_ok and blocked[k - sx - 1] == 0:
			out[n] = k - sx - 1
			wts[n] = DIAG
			n += 1
		if n_ok and e_ok and blocked[k - sx + 1] == 0:
			out[n] = k - sx + 1
			wts[n] = DIAG
			n += 1
		if s_ok and w_ok and blocked[k + sx - 1] == 0:
			out[n] = k + sx - 1
			wts[n] = DIAG
			n += 1
		if s_ok and e_ok and blocked[k + sx + 1] == 0:
			out[n] = k + sx + 1
			wts[n] = DIAG
			n += 1
	_adj_start[sx * sy] = n
	out.resize(n)
	_adj = out
	wts.resize(n)
	_adj_w = wts


## The reference flood (a loop over STEPS), kept for the test that the fast flood matches it. Kept on purpose as the
## parity oracle for flood (owner keeps safety nets; audit G-22). v0.8.0 P1: the octile distances by plain
## label-correcting (a cell goes back in the queue whenever it gets shorter), from the same seeds, no bound.
func flood_reference(goal: Vector2) -> void:
	cancel_build()  # v0.8.0 NF: a build in progress is dropped
	_flooded = Vector3i(-1, -1, -1)
	if size == Vector2i.ZERO:
		return
	dist.fill(UNREACHED)
	var g := cell_of(goal)
	if not inside(g):
		return
	var open := extra.is_empty()
	var seeds := _seeds(g, open)
	var queue := PackedInt32Array()
	for s in range(0, seeds.size(), 2):
		if seeds[s + 1] < dist[seeds[s]]:
			dist[seeds[s]] = seeds[s + 1]
			queue.append(seeds[s])
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
			if blocked[nk] == 1 or not (open or extra[nk] == 0):
				continue
			var step := ORTHO
			if s.x != 0 and s.y != 0:
				if blocked[c.y * size.x + n.x] == 1 or blocked[n.y * size.x + c.x] == 1:
					continue
				step = DIAG
			if dist[k] + step < dist[nk]:
				dist[nk] = dist[k] + step
				queue.append(nk)


## The direction (unit) from p toward the neighbouring cell closest to the goal, or ZERO if none is better.
## v0.8.0 P1: from a free cell, along its own steps (no corner cut) to the one on a shortest way (the least distance
## plus step cost; on a tie the one nearer the goal, then STEPS order); from a blocked cell (a body pressed to a
## wall), to the nearest-to-the-goal neighbour as before.
func direction(p: Vector2) -> Vector2:
	var c := cell_of(p)
	if not inside(c):
		return Vector2.ZERO
	var k := c.y * size.x + c.x
	var here := dist[k]
	var pick := -1
	if blocked[k] == 0:
		var best := UNREACHED
		var best_d := UNREACHED
		for j in range(_adj_start[k], _adj_start[k + 1]):
			var nk := _adj[j]
			var d := dist[nk]
			if d >= here:
				continue
			var via := d + _adj_w[j]
			if via < best or (via == best and d < best_d):
				best = via
				best_d = d
				pick = nk
	else:
		var best := here
		for s in STEPS:
			var n := c + s
			if not inside(n):
				continue
			var d := dist[n.y * size.x + n.x]
			if d < best:
				best = d
				pick = n.y * size.x + n.x
	if pick < 0:
		return Vector2.ZERO
	var to := center(Vector2i(pick % size.x, pick / size.x)) - p
	var l := Kin.length(to)
	return to / l if l > 0.0001 else Vector2.ZERO
