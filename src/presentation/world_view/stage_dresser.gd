class_name StageDresser
extends RefCounted
## Builds a floor out of the owner's kit pieces (v0.5.9 Step 4, owner L2: "we use those procedurally with some
## rules"). A pure function: the floor's geometry in, a list of placed pieces out, the same for the same seed. Its
## draws come from the cosmetic stream (a RandomNumberGenerator seeded from the floor seed), never from or into
## the sim (EI-05).
##
## Rules (starting values, tuned on screenshots):
## 1. Looks solid = is solid. Anything taller than DECOR_MAX_HEIGHT sits inside a sim wall's or slab's footprint
##    and never leaves it; open floor only gets low decoration.
## 2. Structural walls are tiled along their length with wall_2m / wall_1m (about BROKEN_CHANCE of them broken),
##    with wall_pillar at both ends of a long wall. Heights jitter by ±HEIGHT_JITTER.
## 3. Cover slabs: near-square blocks become crate stacks or large rocks (Night Rocks: rocks and dead trees); long
##    thin slabs are tiled with concrete slabs. A car wreck only where a footprint is deep enough for one.
## 4. Light props: 0-2 per room (the start hall always 1), set into a structural wall on the room's side, never
##    within DOOR_CLEAR of a doorway or LIGHT_SPACING of another light.
## 5. Decoration: grass tufts along the room's walls, rubble and debris on open floor, kept KEEP_CLEAR away from
##    doorways, rewards and the portal.

const DECOR_MAX_HEIGHT := 0.4
const BROKEN_CHANCE := 0.2
const HEIGHT_JITTER := 0.1
const PILLAR_MIN_WALL := 3.0
const LIGHT_SLOT := 0.9
const LIGHT_SPACING := 5.0
const DOOR_CLEAR := 1.8
const KEEP_CLEAR := 1.5
const GRASS_STEP := 1.1
const GRASS_CHANCE := 0.35
## Rubble and debris pieces per square metre of room interior.
const SCATTER_DENSITY := 0.03
## Heights of the walls the sim describes (StageView's EDGE_WALL_HEIGHT and SLAB_HEIGHT).
const WALL_HEIGHT := 1.0
const SLAB_HEIGHT := 1.8


## Places the kit over a floor. `f` keys:
## - "walls": [[center: Vector2, half: Vector2, yaw: float, kind: int]] (kind 0 structural, 1 cover slab), the
##   same order and yaw as StageView.wall_specs;
## - "rooms": [Rect2] interiors; "start_room": int; "doors": [Rect2]; "keep_clear": [Vector2];
## - "biome": StringName; "seed": int.
## Returns [{"piece": StringName, "xform": Transform3D (scales the unit-box piece), "wall": the wall index it
## belongs to (-1 for none), "kind": &"wall" | &"cover" | &"light" | &"decor"}].
static func dress(f: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f.get("seed", 0)) * 7919 + 4513  # the cosmetic stream: presentation only
	var out: Array = []
	var walls: Array = f.get("walls", [])
	var slots := _light_slots(f, rng)
	for i in walls.size():
		var w: Array = walls[i]
		if w[3] == 0:
			_dress_wall(out, i, w, slots.get(i, []), rng)
		else:
			_dress_slab(out, i, w, f.get("biome", &""), rng)
	_decorate(out, f, rng)
	return out


## The wall's long axis (unit, 3D), its length and thickness (m), and the yaw that turns a piece's +X onto it.
static func _frame(w: Array) -> Dictionary:
	var half: Vector2 = w[1]
	var yaw: float = w[2]
	if half.y > half.x:
		yaw += PI * 0.5
	var basis := Basis(Vector3.UP, yaw)
	return {
		"axis": basis * Vector3.RIGHT,
		"depth_axis": basis * Vector3.BACK,
		"length": maxf(half.x, half.y) * 2.0,
		"depth": minf(half.x, half.y) * 2.0,
		"yaw": yaw,
		"center": SimPlane.to_3d(w[0]),
	}


## A piece scaled to size (length along the frame's axis, height, depth), centred at `along` on the axis and
## `across` on the depth axis.
static func _place(fr: Dictionary, along: float, across: float, size: Vector3) -> Transform3D:
	var basis := Basis(Vector3.UP, fr["yaw"]) * Basis.from_scale(size)
	var origin: Vector3 = fr["center"] + fr["axis"] * along + fr["depth_axis"] * across
	return Transform3D(basis, origin)


static func _add(
	out: Array, piece: StringName, xform: Transform3D, wall: int, kind: StringName
) -> void:
	out.append({"piece": piece, "xform": xform, "wall": wall, "kind": kind})


static func _jitter(rng: RandomNumberGenerator, h: float) -> float:
	return h * rng.randf_range(1.0 - HEIGHT_JITTER, 1.0 + HEIGHT_JITTER)


static func _dress_wall(
	out: Array, i: int, w: Array, slots: Array, rng: RandomNumberGenerator
) -> void:
	var fr := _frame(w)
	var length: float = fr["length"]
	var depth: float = fr["depth"]
	var start := -length * 0.5
	var stop := length * 0.5
	if length >= PILLAR_MIN_WALL:
		var p := clampf(depth, 0.6, 1.4)
		for end in [start + p * 0.5, stop - p * 0.5]:
			_add(
				out,
				&"wall_pillar",
				_place(fr, end, 0.0, Vector3(p, _jitter(rng, 1.3), depth)),
				i,
				&"wall"
			)
		start += p
		stop -= p
	# Light slots cut the run into stretches; each slot holds a light prop on the room's side.
	var cuts: Array = []
	for s: Array in slots:
		cuts.append(s)
	cuts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var at := start
	for s: Array in cuts:
		var lo: float = s[0] - LIGHT_SLOT * 0.5
		_fill(out, i, fr, at, lo, rng)
		_light(out, i, fr, s[0], s[1], s[2])
		at = lo + LIGHT_SLOT
	_fill(out, i, fr, at, stop, rng)


## Wall pieces from a to b along the wall, the last one stretched to end exactly at b.
static func _fill(
	out: Array, i: int, fr: Dictionary, a: float, b: float, rng: RandomNumberGenerator
) -> void:
	var depth: float = fr["depth"]
	while b - a > 0.05:
		var rest := b - a
		var seg := 2.0 if rest >= 2.6 and rng.randf() < 0.6 else 1.0
		if rest - seg < 0.6:
			seg = rest
		var piece := &"wall_2m" if seg >= 1.6 else &"wall_1m"
		var h := _jitter(rng, WALL_HEIGHT)
		if rng.randf() < BROKEN_CHANCE:
			piece = &"wall_broken"
			h = _jitter(rng, 0.7)
		_add(out, piece, _place(fr, a + seg * 0.5, 0.0, Vector3(seg, h, depth)), i, &"wall")
		a += seg


## A light prop at `along`, on the side `side` (+1 or -1 along the depth axis), with a low broken wall behind it.
static func _light(
	out: Array, i: int, fr: Dictionary, along: float, side: float, piece: StringName
) -> void:
	var depth: float = fr["depth"]
	var foot := minf(0.6, depth)
	var across := side * (depth - foot) * 0.5
	var h := 0.9 if piece == &"fire_barrel" else 2.0
	var w := foot if piece == &"fire_barrel" else minf(foot, 0.3)
	_add(out, piece, _place(fr, along, across, Vector3(w, h, w)), i, &"light")
	var behind := depth - foot
	if behind > 0.15:
		var back := -side * foot * 0.5
		_add(
			out,
			&"wall_broken",
			_place(fr, along, back, Vector3(LIGHT_SLOT, 0.55, behind)),
			i,
			&"wall"
		)


static func _dress_slab(
	out: Array, i: int, w: Array, biome: StringName, rng: RandomNumberGenerator
) -> void:
	var fr := _frame(w)
	var length: float = fr["length"]
	var depth: float = fr["depth"]
	if length / depth < 1.6:
		var pick: StringName
		if biome == &"night_rocks":
			pick = &"dead_tree" if rng.randf() < 0.25 else &"rock_large"
		else:
			pick = &"crate_stack" if rng.randf() < 0.6 else &"rock_large"
		var h := _jitter(
			rng, 2.2 if pick == &"dead_tree" else (1.2 if pick != &"rock_large" else 1.1)
		)
		_add(out, pick, _place(fr, 0.0, 0.0, Vector3(length, h, depth)), i, &"cover")
		return
	if depth >= 1.2 and length >= 2.6 and length <= 5.0 and rng.randf() < 0.5:
		_add(
			out,
			&"car_wreck",
			_place(fr, 0.0, 0.0, Vector3(length, _jitter(rng, 1.4), depth)),
			i,
			&"cover"
		)
		return
	var a := -length * 0.5
	var b := length * 0.5
	while b - a > 0.05:
		var rest := b - a
		var seg := rng.randf_range(1.0, 1.6) if rest > 2.2 else rest
		var piece := &"slab_wide" if seg >= 1.3 else &"slab_concrete"
		var h := _jitter(rng, SLAB_HEIGHT)
		_add(out, piece, _place(fr, a + seg * 0.5, 0.0, Vector3(seg, h, depth)), i, &"cover")
		a += seg


## {wall index: [[along, side, piece]]}: where each room's light props go.
static func _light_slots(f: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var slots := {}
	var placed: Array[Vector2] = []
	var walls: Array = f.get("walls", [])
	var rooms: Array = f.get("rooms", [])
	var doors: Array = f.get("doors", [])
	for r in rooms.size():
		var room: Rect2 = rooms[r]
		var want := 1 if r == int(f.get("start_room", -1)) else _weighted(rng, [0.15, 0.5, 0.35])
		var candidates: Array = []
		for i in walls.size():
			var w: Array = walls[i]
			if w[3] != 0:
				continue
			var fr := _frame(w)
			if fr["length"] < 2.0 or fr["depth"] < 0.5:
				continue
			if _wall_rect(w).intersects(room.grow(0.05)):
				candidates.append(i)
		for k in want:
			for attempt in 8:
				if candidates.is_empty():
					break
				var i: int = candidates[rng.randi() % candidates.size()]
				var w: Array = walls[i]
				var fr := _frame(w)
				var axis2 := Vector2(fr["axis"].x, -fr["axis"].z)
				var c: Vector2 = w[0]
				# The stretch of the wall that faces this room, inset from the room's corners.
				var lo := INF
				var hi := -INF
				for corner in [
					room.position,
					room.end,
					Vector2(room.position.x, room.end.y),
					Vector2(room.end.x, room.position.y)
				]:
					var t: float = (corner - c).dot(axis2)
					lo = minf(lo, t)
					hi = maxf(hi, t)
				lo = maxf(lo + 1.0, -fr["length"] * 0.5 + 1.2)
				hi = minf(hi - 1.0, fr["length"] * 0.5 - 1.2)
				if hi <= lo:
					continue
				var along := rng.randf_range(lo, hi)
				var depth_axis2 := Vector2(fr["depth_axis"].x, -fr["depth_axis"].z)
				var side := signf((room.get_center() - c).dot(depth_axis2))
				var p: Vector2 = c + axis2 * along + depth_axis2 * side * (float(fr["depth"]) * 0.5)
				if not room.grow(0.2).has_point(p):
					continue
				if (
					_near_any_rect(p, doors, DOOR_CLEAR)
					or _near_any_point(p, placed, LIGHT_SPACING)
				):
					continue
				var piece := (
					&"fire_barrel" if fr["depth"] >= 0.6 and rng.randf() < 0.75 else &"brazier_pole"
				)
				if not slots.has(i):
					slots[i] = []
				slots[i].append([along, side if side != 0.0 else 1.0, piece])
				placed.append(p)
				break
	return slots


static func _decorate(out: Array, f: Dictionary, rng: RandomNumberGenerator) -> void:
	var doors: Array = f.get("doors", [])
	var keep: Array = f.get("keep_clear", [])
	for room: Rect2 in f.get("rooms", []):
		# Grass along the room's four walls.
		var inner := room.grow(-0.3)
		if inner.size.x <= 0.0 or inner.size.y <= 0.0:
			continue
		var edges := [
			[inner.position, Vector2(inner.end.x, inner.position.y)],
			[Vector2(inner.end.x, inner.position.y), inner.end],
			[inner.end, Vector2(inner.position.x, inner.end.y)],
			[Vector2(inner.position.x, inner.end.y), inner.position],
		]
		for e: Array in edges:
			var a: Vector2 = e[0]
			var b: Vector2 = e[1]
			var n := int(a.distance_to(b) / GRASS_STEP)
			for k in n:
				if rng.randf() >= GRASS_CHANCE:
					continue
				var p := a.lerp(b, (k + rng.randf()) / maxf(n, 1))
				if _near_any_rect(p, doors, KEEP_CLEAR) or _near_any_point(p, keep, KEEP_CLEAR):
					continue
				_decor(out, &"grass_tuft", p, rng.randf_range(0.6, 1.0), rng)
		# Rubble and debris on open floor.
		var count := int(room.get_area() * SCATTER_DENSITY)
		var open := room.grow(-1.0)
		if open.size.x <= 0.0 or open.size.y <= 0.0:
			continue
		for k in count:
			var p := Vector2(
				rng.randf_range(open.position.x, open.end.x),
				rng.randf_range(open.position.y, open.end.y)
			)
			if _near_any_rect(p, doors, KEEP_CLEAR) or _near_any_point(p, keep, KEEP_CLEAR):
				continue
			var piece := &"rubble_small" if rng.randf() < 0.65 else &"debris_low"
			_decor(out, piece, p, rng.randf_range(0.7, 1.2), rng)


## A low decoration piece at its natural size × s, turned at random; its height never passes DECOR_MAX_HEIGHT.
static func _decor(
	out: Array, piece: StringName, p: Vector2, s: float, rng: RandomNumberGenerator
) -> void:
	var spec: Dictionary = KitModels.SPECS[piece]
	var h := minf(float(spec["height"]) * s, DECOR_MAX_HEIGHT)
	# Footprints from KIT_REQUESTS (the loaded piece's own proportions replace these in StageView).
	var foot: Vector2 = (
		{
			&"grass_tuft": Vector2(0.5, 0.5),
			&"rubble_small": Vector2(0.6, 0.6),
			&"debris_low": Vector2(0.8, 0.4)
		}
		. get(piece, Vector2(0.5, 0.5))
	)
	var basis := (
		Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(foot.x * s, h, foot.y * s))
	)
	_add(out, piece, Transform3D(basis, SimPlane.to_3d(p)), -1, &"decor")


static func _wall_rect(w: Array) -> Rect2:
	var c: Vector2 = w[0]
	var half: Vector2 = w[1]
	var yaw: float = w[2]
	var ex := absf(half.x * cos(yaw)) + absf(half.y * sin(yaw))
	var ey := absf(half.x * sin(yaw)) + absf(half.y * cos(yaw))
	return Rect2(c - Vector2(ex, ey), Vector2(ex, ey) * 2.0)


static func _near_any_rect(p: Vector2, rects: Array, d: float) -> bool:
	for r: Rect2 in rects:
		if r.grow(d).has_point(p):
			return true
	return false


static func _near_any_point(p: Vector2, points: Array, d: float) -> bool:
	for q: Vector2 in points:
		if p.distance_to(q) < d:
			return true
	return false


static func _weighted(rng: RandomNumberGenerator, weights: Array) -> int:
	var x := rng.randf()
	for k in weights.size():
		x -= weights[k]
		if x < 0.0:
			return k
	return weights.size() - 1
