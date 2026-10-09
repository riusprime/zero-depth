class_name ShardDressing
extends RefCounted
## Where the crystal-shard clusters go on a floor (v0.6.1 Step SD, owner R4: "we could also add to the generation
## map or the initial room the shard looks"; SD2, A3: "Very frequent on the starting room and be an element of all
## rooms, but disparity..."; SD3, A3b: "not on top of the walls it should be floor closed to the walls, corners of
## some rooms, and other obstacle like they grow from the ground"; SD4, A3c: "only about a 20% of the room should
## have, and mostly corners, the only items that should be touching these are rock materials, no cars, barrels, or
## wood, just stone, the small room I was talking about was a themed one, where there is a noticable higher
## percentage with bigger cristals, size of the 1x1 rock stones that are in some rooms as walls and smaller ones, but
## always close to the walls"). A pure function like StageDresser: the floor's geometry in, the clusters' crystals
## out, the same for the same seed. Its draws come from its own cosmetic stream (a RandomNumberGenerator seeded from
## the floor seed, offset from the dresser's), never from or into the sim (EI-05). Presentation only: no collision.
##
## Rules (starting values, tuned on screenshots):
## 1. Crystals grow from the floor: every crystal's base disc is on open floor in its room (never in or on a wall
##    or an obstacle) and hugs stone: its far edge within HUG of the nearest wall or stone piece (TALL_HUG for a
##    crystal taller than StageDresser.DECOR_MAX_HEIGHT, BIG_HUG for a crystal room's big ones). They lean away from
##    what they grow against and get lower the further from it they stand.
## 2. Only stone (A3c): walls and the kit's stone pieces (STONE: wall blocks, pillars, slabs, rocks). Nothing grows
##    against a crate, a car wreck, a dead tree or a light prop: every crystal keeps NON_STONE_CLEAR from them.
## 3. A share of the wall base (A3c): an ordinary room (the start room too) gets crystals on about ORDINARY_SHARE
##    (± ORDINARY_JITTER) of its free wall base, `coverage`; a crystal room on CRYSTAL_SHARE. The free wall base is
##    `wall_spots`: spots every SPOT_STEP m, SPOT_IN m in from a wall, where a crystal could stand by every rule.
##    Mostly corners: the room's corners in a random order first, each with short runs along its two walls, then
##    longer runs only if the share is still short. Every room but the boss arena gets at least one cluster. A few
##    stone obstacles in a room get a cluster at their foot (not counted in the share).
## 4. Crystal rooms (A3c): 1-2 rooms per floor (`floor_crystal_rooms`; smaller rooms more likely; never the start,
##    the boss arena, or a room with the shop, the shrine or an event) get the high share and big crystals, about the
##    size of the 1 x 1 m stone blocks, with smaller ones round them.
## 5. Camera-side faces stay low: a face whose floor side looks away from the iso camera (TO_CAMERA) would put its
##    crystals between the camera and a hero standing beyond them, and the baked crystals can't fade with the wall,
##    so nothing there is taller than LOW_HEIGHT (MID_HEIGHT side-on), and no fragments.
## 6. Clearances: every crystal's base keeps DOOR_CLEAR from doorways and arena barriers, KEEP_CLEAR from rewards,
##    gates, the shop, the shrine, events and light props, SPAWN_CLEAR from spawn spots, START_CLEAR from the hero's
##    start. Paths: past a cluster's footprint, PATH_CLEAR of free floor straight out (no structure, no other
##    cluster). Cluster feet keep FOOT_SPACING apart.

## The horizontal direction toward the iso camera on the sim plane (IsoRig.toward_camera_on_plane at yaw 45°).
const TO_CAMERA := Vector2(0.70710678, -0.70710678)
## Rule 1.
const HUG := 0.7
const TALL_HUG := 0.55
const BIG_HUG := 1.0
## Rule 2: the kit's stone pieces (KitModels.SPECS ids); everything else that stands is not stone.
const STONE: Array[StringName] = [
	&"wall_1m",
	&"wall_2m",
	&"wall_broken",
	&"wall_pillar",
	&"slab_concrete",
	&"slab_wide",
	&"rock_large"
]
const NON_STONE_CLEAR := 0.5
## Rule 3 (the share of the free wall base) and rule 4.
const ORDINARY_SHARE := 0.2
const ORDINARY_JITTER := 0.05
const CRYSTAL_SHARE := 0.7
const CRYSTAL_JITTER := 0.1
const SPOT_STEP := 0.5
const SPOT_IN := 0.35
## A spot is covered when a tall crystal stands within this of it.
const COVER_R := 0.6
## Runs from a corner: one cluster every RUN_STEP m (CRYSTAL_RUN_STEP in a crystal room), each run at most
## RUN_MAX m on the first pass, RUN_MAX * 2 on the second, the whole wall on the third (only while the share is
## short: big rooms).
const RUN_STEP := 1.1
const CRYSTAL_RUN_STEP := 0.9
const RUN_MAX := 3.0
## Chance that a stone obstacle in the room gets a cluster at its foot (ordinary room, crystal room).
const OBSTACLE_CHANCE := 0.25
const CRYSTAL_OBSTACLE_CHANCE := 0.6
## Crystal rooms per floor: 1, or 2 with this chance.
const SECOND_CRYSTAL_ROOM := 0.5
const CRYSTAL_MIN_BASE := 8.0
## Rule 5: camera-side faces (floor side · TO_CAMERA below FACE_LOW) and side-on faces (below FACE_MID).
const FACE_LOW := -0.25
const FACE_MID := 0.25
const LOW_HEIGHT := 0.6
const MID_HEIGHT := 0.9
## Rule 6.
const DOOR_CLEAR := 1.8
const KEEP_CLEAR := 1.5
const SPAWN_CLEAR := 0.6
const START_CLEAR := 2.0
const PATH_CLEAR := 1.4
const FOOT_SPACING := 1.0
## The foot (a cluster's reference point for the spacing): this far out from its surface.
const FOOT_OFF := 0.35
const HERO_ATTEMPTS := 30
## How far around a room anything can still matter to its clusters.
const NEAR := 3.5
## Floating fragments hover at least this high (above the hero's head).
const FRAGMENT_MIN_Y := 1.1
## The hero cluster's crystals glow this much more than the room's; a crystal room's a little more.
const HERO_GLOW := 1.55
const CRYSTAL_GLOW := 1.2


## Places the clusters. `f` keys:
## - "walls": [[center: Vector2, half: Vector2, yaw: float, kind: int, ...]] (StageDresser's input: kind 0
##   structural, 1 cover);
## - "pieces": StageDresser.dress's placements for those walls (to tell stone from wood and metal);
## - "rooms": [Rect2]; "start_room": int; "boss_room": int; "special": [Vector2] (the shop, the shrine, events: their
##   rooms are never crystal rooms);
## - "doors": [Rect2] (doorways and arena barriers); "keep_clear": [Vector2]; "spawns": [Vector2];
##   "start": Vector2; "seed": int.
## Returns [{"room": int, "hero": bool, "crystal_room": bool, "kind": &"wall" | &"corner" | &"obstacle",
## "front": bool (a camera-side face, kept low), "cap": float, "foot": Vector2, "radius": float (the circle round
## the foot holding every base disc), "inward": Vector2 (away from its surface), "crystals": [{"xform": Transform3D
## (scales the unit crystal), "base": Vector2, "radius": float, "height": float, "tall": bool, "big": bool,
## "variant": int, "glow": float}], "fragments": [Transform3D], "light": Vector3 (the hero's; Vector3.INF for none)}].
static func place(f: Dictionary) -> Array:
	var rng := _stream(f)
	var g := _with_stone(f)
	var rooms: Array = g.get("rooms", [])
	var start := int(g.get("start_room", -1))
	var boss := int(g.get("boss_room", -1))
	var nears := {}
	var spots := {}
	for r in rooms.size():
		if r != boss:
			nears[r] = _local(g, rooms[r])
			spots[r] = wall_spots(nears[r], rooms[r])
	# The stream's first draws: floor_crystal_rooms(f) gives the same rooms.
	var crystal := crystal_rooms(f, spots, rng)
	var out: Array = []
	for r in rooms.size():
		if r == boss:
			continue
		out.append_array(_dress_room(nears[r], r, r == start, crystal.has(r), spots[r], rng))
	return out


## The crystal rooms place(f) picks (for tests and tools): the same stream, its first draws.
static func floor_crystal_rooms(f: Dictionary) -> Array[int]:
	var g := _with_stone(f)
	var spots := {}
	var rooms: Array = g.get("rooms", [])
	for r in rooms.size():
		if r != int(g.get("boss_room", -1)):
			spots[r] = wall_spots(_local(g, rooms[r]), rooms[r])
	return crystal_rooms(f, spots, _stream(f))


static func _stream(f: Dictionary) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f.get("seed", 0)) * 7919 + 9241  # the cosmetic stream: presentation only
	return rng


## Rule 4's pick: 1-2 rooms, weighted by their free wall base (wall_spots, `spots` per room) per m² of floor, so
## smaller rooms with bare stone walls come first; never the start, the boss arena, a special room or a room with
## less than CRYSTAL_MIN_BASE m of free wall base.
static func crystal_rooms(
	f: Dictionary, spots: Dictionary, rng: RandomNumberGenerator
) -> Array[int]:
	var rooms: Array = f.get("rooms", [])
	var pool: Array[int] = []
	var weights: Array[float] = []
	for r in rooms.size():
		if r == int(f.get("start_room", -1)) or r == int(f.get("boss_room", -1)):
			continue
		var room: Rect2 = rooms[r]
		var special := false
		for p: Vector2 in f.get("special", []):
			special = special or room.has_point(p)
		var free: int = (spots.get(r, []) as Array).size()
		if special or float(free) * SPOT_STEP < CRYSTAL_MIN_BASE:
			continue
		pool.append(r)
		# Free stone wall base per m² of floor: small rooms with bare stone walls first.
		weights.append(float(free) * SPOT_STEP / maxf(room.get_area(), 1.0))
	var want := 2 if rng.randf() < SECOND_CRYSTAL_ROOM else 1
	var out: Array[int] = []
	while out.size() < want and not pool.is_empty():
		var total := 0.0
		for w in weights:
			total += w
		var x := rng.randf() * total
		var k := 0
		while k < pool.size() - 1 and x >= weights[k]:
			x -= weights[k]
			k += 1
		out.append(pool[k])
		pool.remove_at(k)
		weights.remove_at(k)
	return out


## f plus "soft": the not-stone things crystals keep clear of (rule 2): [[centre, half, yaw]] boxes of the cover
## pieces the kit dresses in wood or metal, and of the light props; and "stone_cover": the indices of cover walls
## dressed in stone only.
static func _with_stone(f: Dictionary) -> Dictionary:
	var g := f.duplicate()
	var walls: Array = f.get("walls", [])
	var soft_wall := {}
	var soft: Array = []
	for p: Dictionary in f.get("pieces", []):
		var piece: StringName = p["piece"]
		if piece in STONE or not (p["kind"] in [&"cover", &"light", &"wall"]):
			continue
		var wi := int(p["wall"])
		if p["kind"] == &"cover" and wi >= 0 and wi < walls.size():
			soft_wall[wi] = true
		else:
			var x: Transform3D = p["xform"]
			var half := Vector2(x.basis.x.length(), x.basis.z.length()) * 0.5
			soft.append([SimPlane.to_sim(x.origin), half, 0.0, -1])
	for wi: int in soft_wall:
		var w: Array = walls[wi]
		soft.append([w[0], w[1], w[2], -1])
	g["soft"] = soft
	var stone_cover := {}
	for i in walls.size():
		if int(walls[i][3]) == 1 and not soft_wall.has(i):
			stone_cover[i] = true
	g["stone_cover"] = stone_cover
	return g


## One room's clusters (rule 3): the hero (the start room), the corners and their runs up to the room's share, a
## few stone obstacles, and the fallback.
static func _dress_room(
	f: Dictionary, r: int, is_start: bool, crystal: bool, spots: Array, rng: RandomNumberGenerator
) -> Array:
	var room: Rect2 = f["rooms"][r]
	var mine: Array = []
	var covered := PackedByteArray()
	covered.resize(spots.size())
	var share := (
		CRYSTAL_SHARE + rng.randf_range(-CRYSTAL_JITTER, CRYSTAL_JITTER)
		if crystal
		else ORDINARY_SHARE + rng.randf_range(-ORDINARY_JITTER, ORDINARY_JITTER)
	)
	var target := int(ceil(share * float(spots.size())))
	var got := [0]
	if is_start:
		var hero := _try_hero(f, r, mine, rng)
		if not hero.is_empty():
			_add(mine, hero, spots, covered, got)
	var corners := _corners(room)
	# A random corner order (a shuffle on the stream).
	for k in range(corners.size() - 1, 0, -1):
		var j := rng.randi() % (k + 1)
		var tmp: Dictionary = corners[k]
		corners[k] = corners[j]
		corners[j] = tmp
	var step := CRYSTAL_RUN_STEP if crystal else RUN_STEP
	for pass_i in 3:
		if got[0] >= target:
			break
		var run_max: float = [RUN_MAX, RUN_MAX * 2.0, INF][pass_i] if not crystal else INF
		for c: Dictionary in corners:
			if got[0] >= target:
				break
			if pass_i == 0:
				var cc := _cluster(f, r, c, _spec(c, crystal, false, rng), mine, rng)
				if not cc.is_empty():
					_add(mine, cc, spots, covered, got)
			for run: Array in c["runs"]:
				var dist := step
				var limit := run_max
				while dist <= limit and got[0] < target:
					var cand := _run_candidate(run, dist)
					if cand.is_empty():
						break
					var wc := _cluster(f, r, cand, _spec(cand, crystal, false, rng), mine, rng)
					if not wc.is_empty():
						_add(mine, wc, spots, covered, got)
					dist += step
	# A few stone obstacles get a cluster at their foot.
	var chance := CRYSTAL_OBSTACLE_CHANCE if crystal else OBSTACLE_CHANCE
	var stone: Dictionary = f.get("stone_cover", {})
	var walls: Array = f.get("walls", [])
	var all: Array = f.get("all_walls", walls)
	for i in all.size():
		if not stone.has(i) or not room.has_point(all[i][0]) or rng.randf() >= chance:
			continue
		for cand: Dictionary in _obstacle_faces(all[i], rng):
			var oc := _cluster(f, r, cand, _spec(cand, crystal, false, rng), mine, rng)
			if not oc.is_empty():
				_add(mine, oc, spots, covered, got)
				break
	if mine.is_empty():
		# Every room gets one: a tight cluster at the first spot that fits.
		for k in spots.size():
			var s: Dictionary = spots[k]
			var cand := {
				"kind": &"wall",
				"anchor": (s["p"] as Vector2) - (s["n"] as Vector2) * SPOT_IN,
				"n": s["n"],
				"t": s["t"],
				"cap": _cap(s["n"]),
			}
			var tc := _cluster(f, r, cand, _spec(cand, crystal, true, rng), mine, rng)
			if not tc.is_empty():
				_add(mine, tc, spots, covered, got)
				break
	for c: Dictionary in mine:
		c["crystal_room"] = crystal
	return mine


## Adds a cluster and marks the spots its tall crystals cover.
static func _add(
	mine: Array, c: Dictionary, spots: Array, covered: PackedByteArray, got: Array
) -> void:
	mine.append(c)
	for k in spots.size():
		if covered[k] == 1:
			continue
		var p: Vector2 = spots[k]["p"]
		for x: Dictionary in c["crystals"]:
			if x["tall"] and p.distance_to(x["base"]) <= COVER_R:
				covered[k] = 1
				got[0] += 1
				break


## Rule 3's free wall base of a room: [{"p": the spot, SPOT_IN in from its wall, "n": away from the wall, "t": along
## it}], every SPOT_STEP m where a wall stands behind it (no doorway) and a crystal could stand: on open floor,
## keeping every clearance, clear of non-stone, with a free path out.
static func wall_spots(f: Dictionary, room: Rect2) -> Array:
	var out: Array = []
	for s: Array in _sides(room):
		var o: Vector2 = s[0]
		var t: Vector2 = s[1]
		var n: Vector2 = s[2]
		var length: float = s[3]
		var at := SPOT_STEP
		while at < length - SPOT_STEP * 0.5:
			var face := o + t * at
			at += SPOT_STEP
			if not _in_wall(f, face - n * 0.15):
				continue
			var p := face + n * SPOT_IN
			if _in_any(f, p) or not _clear(f, p, 0.15) or not _off_soft(f, p, 0.15):
				continue
			var out_p := face + n * HUG
			if _in_any(f, out_p + n * (PATH_CLEAR * 0.5)) or _in_any(f, out_p + n * PATH_CLEAR):
				continue
			out.append({"p": p, "n": n, "t": t})
	return out


## The covered share of a room's free wall base: the spots (wall_spots) with a tall crystal of `placed` within
## COVER_R.
static func coverage(f: Dictionary, room: Rect2, placed: Array) -> float:
	var spots := wall_spots(_with_stone(f), room)
	if spots.is_empty():
		return 0.0
	var tall: Array[Vector2] = []
	for c: Dictionary in placed:
		for x: Dictionary in c["crystals"]:
			if x["tall"] and room.grow(0.5).has_point(x["base"]):
				tall.append(x["base"])
	var n := 0
	for s: Dictionary in spots:
		for b in tall:
			if (s["p"] as Vector2).distance_to(b) <= COVER_R:
				n += 1
				break
	return float(n) / float(spots.size())


## [origin, along, inward, length] of the room's four walls.
static func _sides(room: Rect2) -> Array:
	var p0 := room.position
	var p1 := room.end
	return [
		[p0, Vector2(0, 1), Vector2(1, 0), room.size.y],
		[Vector2(p0.x, p1.y), Vector2(1, 0), Vector2(0, -1), room.size.x],
		[Vector2(p1.x, p0.y), Vector2(0, 1), Vector2(-1, 0), room.size.y],
		[p0, Vector2(1, 0), Vector2(0, 1), room.size.x],
	]


## The room's four corners as candidates, each with its two runs [side origin, along, inward, length, start, dir].
static func _corners(room: Rect2) -> Array:
	var sides := _sides(room)
	var sy := room.size.y
	var sx := room.size.x
	var out: Array = []
	for c: Array in [
		[Vector2(room.position.x, room.end.y), 0, sy, -1.0, 1, 0.0, 1.0],
		[room.end, 1, sx, -1.0, 2, sy, -1.0],
		[Vector2(room.end.x, room.position.y), 2, 0.0, 1.0, 3, sx, -1.0],
		[room.position, 3, 0.0, 1.0, 0, 0.0, 1.0],
	]:
		var s1: Array = sides[c[1]]
		var s2: Array = sides[c[4]]
		var n: Vector2 = s1[2]
		var n2: Vector2 = s2[2]
		(
			out
			. append(
				{
					"kind": &"corner",
					"anchor": c[0],
					"n": n,
					"n2": n2,
					"t": Vector2.ZERO,
					"cap": _cap((n + n2).normalized()),
					"runs": [s1 + [c[2], c[3]], s2 + [c[5], c[6]]],
				}
			)
		)
	return out


## A wall candidate `dist` m along a corner's run, or {} past the wall's end.
static func _run_candidate(run: Array, dist: float) -> Dictionary:
	var length: float = run[3]
	var at: float = run[4] + run[5] * dist
	if at < HUG or at > length - HUG:
		return {}
	var n: Vector2 = run[2]
	return {
		"kind": &"wall",
		"anchor": (run[0] as Vector2) + (run[1] as Vector2) * at,
		"n": n,
		"t": run[1],
		"cap": _cap(n),
	}


## A stone obstacle's four face middles as candidates, in a random order.
static func _obstacle_faces(w: Array, rng: RandomNumberGenerator) -> Array:
	var c: Vector2 = w[0]
	var half: Vector2 = w[1]
	var yaw: float = w[2]
	var out: Array = []
	for face: Array in [
		[Vector2(1, 0), Vector2(0, 1), half.x, half.y],
		[Vector2(-1, 0), Vector2(0, 1), half.x, half.y],
		[Vector2(0, 1), Vector2(1, 0), half.y, half.x],
		[Vector2(0, -1), Vector2(1, 0), half.y, half.x],
	]:
		var n := (face[0] as Vector2).rotated(yaw)
		var t := (face[1] as Vector2).rotated(yaw)
		var at := rng.randf_range(-0.5, 0.5) * float(face[3])
		out.append(
			{
				"kind": &"obstacle",
				"anchor": c + n * float(face[2]) + t * at,
				"n": n,
				"t": t,
				"cap": _cap(n)
			}
		)
	for k in range(out.size() - 1, 0, -1):
		var j := rng.randi() % (k + 1)
		var tmp: Dictionary = out[k]
		out[k] = out[j]
		out[j] = tmp
	return out


## The face's height cap (rule 5) for a floor side looking along n.
static func _cap(n: Vector2) -> float:
	var d := n.normalized().dot(TO_CAMERA)
	if d < FACE_LOW:
		return LOW_HEIGHT
	if d < FACE_MID:
		return MID_HEIGHT
	return INF


## The cluster's shape: an ordinary room's modest clusters (corners fuller), a crystal room's big crystals with
## smaller ones round them; `tight`: the fallback's small one.
static func _spec(
	cand: Dictionary, crystal: bool, tight: bool, rng: RandomNumberGenerator
) -> Dictionary:
	var corner: bool = cand["kind"] == &"corner"
	var spec := {
		"big_n": 0,
		"big_rad": [0.3, 0.45],
		"big_h": [1.2, 1.8],
		"tall_n": rng.randi_range(2, 4) + (2 if corner else 0),
		"first": [1.1, 1.7] if corner else [0.9, 1.4],
		"rest": [0.5, 1.0],
		"rad": [0.09, 0.16],
		"spread": 0.45,
		"arm": 0.8,
		"low_n": rng.randi_range(2, 4),
		"frag_n": rng.randi_range(1, 2),
		"frag_y": [1.15, 1.7],
		"cap": cand["cap"],
		"glow": 1.0,
		"hero": false,
	}
	if crystal:
		spec["big_n"] = rng.randi_range(1, 2) + (1 if corner else 0)
		spec["tall_n"] = rng.randi_range(2, 4) + (2 if corner else 0)
		spec["first"] = [1.0, 1.5]
		spec["rest"] = [0.6, 1.1]
		spec["rad"] = [0.12, 0.22]
		spec["spread"] = 0.7
		spec["arm"] = 1.2
		spec["low_n"] = rng.randi_range(4, 6)
		spec["frag_n"] = rng.randi_range(2, 3)
		spec["glow"] = CRYSTAL_GLOW
	if tight:
		spec["big_n"] = 0
		spec["tall_n"] = rng.randi_range(2, 3)
		spec["spread"] = 0.3
		spec["arm"] = 0.5
		spec["low_n"] = 2
	if spec["cap"] < INF:
		spec["frag_n"] = 0
	return spec


static func _hero_spec(cand: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	return {
		"big_n": 0,
		"big_rad": [0.3, 0.45],
		"big_h": [1.2, 1.8],
		"tall_n": rng.randi_range(8, 10),
		"first": [2.3, 2.8],
		"rest": [1.1, 1.9],
		"rad": [0.14, 0.22],
		"spread": 1.0,
		"arm": 1.4,
		"low_n": rng.randi_range(8, 10),
		"frag_n": rng.randi_range(5, 6),
		"frag_y": [FRAGMENT_MIN_Y + 0.2, 1.9],
		"cap": cand["cap"],
		"glow": HERO_GLOW,
		"hero": true,
	}


## The start room's hero cluster: its back corner (both walls face the camera) first, else a back wall.
static func _try_hero(
	f: Dictionary, r: int, placed: Array, rng: RandomNumberGenerator
) -> Dictionary:
	var room: Rect2 = f["rooms"][r]
	for attempt in HERO_ATTEMPTS:
		var cand: Dictionary
		if attempt == 0:
			cand = {
				"kind": &"corner",
				"anchor": Vector2(room.position.x, room.end.y),
				"n": Vector2(1, 0),
				"n2": Vector2(0, -1),
				"t": Vector2.ZERO,
				"cap": INF,
			}
		else:
			var left := rng.randf() < room.size.y / (room.size.x + room.size.y)
			var lo := 1.4
			var length := room.size.y if left else room.size.x
			if length - lo <= lo:
				continue
			var at := rng.randf_range(lo, length - lo)
			cand = {
				"kind": &"wall",
				"anchor":
				(
					Vector2(room.position.x, room.position.y + at)
					if left
					else Vector2(room.position.x + at, room.end.y)
				),
				"n": Vector2(1, 0) if left else Vector2(0, -1),
				"t": Vector2(0, 1) if left else Vector2(1, 0),
				"cap": INF,
			}
		var c := _cluster(f, r, cand, _hero_spec(cand, rng), placed, rng)
		if not c.is_empty():
			return c
	return {}


## A cluster at `cand` with `spec`, or {} when its spot breaks a rule (no surface, the path, the spacing, a
## clearance) or no tall crystal fits.
static func _cluster(
	f: Dictionary,
	r: int,
	cand: Dictionary,
	spec: Dictionary,
	placed: Array,
	rng: RandomNumberGenerator
) -> Dictionary:
	var room: Rect2 = f["rooms"][r]
	var corner: bool = cand["kind"] == &"corner"
	var a: Vector2 = cand["anchor"]
	var n: Vector2 = cand["n"]
	var away := (n + (cand["n2"] as Vector2)).normalized() if corner else n
	var foot := a + away * (FOOT_OFF * (1.4 if corner else 1.0))
	if not room.has_point(foot):
		return {}
	for c: Dictionary in placed:
		if foot.distance_to(c["foot"]) < FOOT_SPACING:
			return {}
	if not _clear(f, foot, FOOT_OFF) or not _off_soft(f, foot, FOOT_OFF):
		return {}
	if not _surface(f, cand, spec):
		return {}
	if not _path(f, cand, spec, placed):
		return {}
	var c := _grow(f, room, cand, spec, rng)
	if c["crystals"].is_empty():
		return {}
	var tall := false
	var radius := 0.0
	for x: Dictionary in c["crystals"]:
		tall = tall or x["tall"]
		radius = maxf(radius, foot.distance_to(x["base"]) + float(x["radius"]))
	if not tall:
		return {}
	c["room"] = r
	c["hero"] = spec["hero"]
	c["kind"] = cand["kind"]
	c["front"] = spec["cap"] < INF
	c["cap"] = spec["cap"]
	c["foot"] = foot
	c["radius"] = radius
	c["inward"] = away
	return c


## The surface is there and is stone: a room wall behind the anchor all along the spread (not a doorway), both
## walls of a corner along its arms; an obstacle's face is stone by construction (only stone cover is offered).
static func _surface(f: Dictionary, cand: Dictionary, spec: Dictionary) -> bool:
	var a: Vector2 = cand["anchor"]
	var n: Vector2 = cand["n"]
	match cand["kind"]:
		&"obstacle":
			return true
		&"corner":
			var n2: Vector2 = cand["n2"]
			var arm: float = spec["arm"]
			for s in [0.15, arm * 0.5, arm]:
				if not _in_wall(f, a - n * 0.15 + n2 * s) or not _in_wall(f, a - n2 * 0.15 + n * s):
					return false
			return true
	var t: Vector2 = cand["t"]
	var spread: float = spec["spread"]
	for s in [-spread, 0.0, spread]:
		if not _in_wall(f, a - n * 0.15 + t * s):
			return false
	return true


## Rule 6's paths: from the cluster's outer edge, PATH_CLEAR of free floor straight out (no structure, no other
## cluster's footprint), at its middle and both ends (a corner: its diagonal and both arms' ends).
static func _path(f: Dictionary, cand: Dictionary, spec: Dictionary, placed: Array) -> bool:
	var a: Vector2 = cand["anchor"]
	var n: Vector2 = cand["n"]
	var reach := HUG + PATH_CLEAR + float(spec["arm"]) + 3.0
	var others: Array = placed.filter(
		func(c: Dictionary) -> bool: return a.distance_to(c["foot"]) < reach
	)
	var hug := BIG_HUG if int(spec["big_n"]) > 0 else HUG
	if cand["kind"] == &"corner":
		var n2: Vector2 = cand["n2"]
		var arm: float = spec["arm"]
		var bis := (n + n2).normalized()
		return (
			_ray_free(f, a + bis * hug * 1.41, bis, others)
			and _ray_free(f, a + n2 * arm + n * hug, n, others)
			and _ray_free(f, a + n * arm + n2 * hug, n2, others)
		)
	var t: Vector2 = cand["t"]
	var spread: float = spec["spread"]
	for s in [-spread, 0.0, spread]:
		if not _ray_free(f, a + t * s + n * hug, n, others):
			return false
	return true


static func _ray_free(f: Dictionary, from: Vector2, dir: Vector2, others: Array) -> bool:
	var k := 0.0
	while k <= PATH_CLEAR:
		var p := from + dir * k
		if _in_any(f, p):
			return false
		for c: Dictionary in others:
			if p.distance_to(c["foot"]) < float(c["radius"]):
				return false
		k += 0.3
	return true


## True when a disc at p (radius rad) keeps every clearance of rule 6.
static func _clear(f: Dictionary, p: Vector2, rad: float) -> bool:
	for d: Rect2 in f.get("doors", []):
		if d.grow(DOOR_CLEAR + rad).has_point(p):
			return false
	for q: Vector2 in f.get("keep_clear", []):
		if p.distance_to(q) < KEEP_CLEAR + rad:
			return false
	for q: Vector2 in f.get("spawns", []):
		if p.distance_to(q) < SPAWN_CLEAR + rad:
			return false
	if f.has("start") and p.distance_to(f["start"]) < START_CLEAR + rad:
		return false
	return true


## Rule 2: a disc at p (radius rad) keeps NON_STONE_CLEAR from every wood or metal piece.
static func _off_soft(f: Dictionary, p: Vector2, rad: float) -> bool:
	for w: Array in f.get("soft", []):
		if _dist_to_box(p, w) < NON_STONE_CLEAR + rad:
			return false
	return true


## The distance from p to the nearest structure (a wall or a cover piece), up to NEAR.
static func near_structure(f: Dictionary, p: Vector2) -> float:
	var best := NEAR
	var walls: Array = f.get("walls", [])
	var boxes: Array = f.get("boxes", [])
	for i in walls.size():
		if i < boxes.size():
			var b: Rect2 = boxes[i]
			var dx := maxf(maxf(b.position.x - p.x, p.x - b.end.x), 0.0)
			var dy := maxf(maxf(b.position.y - p.y, p.y - b.end.y), 0.0)
			if dx >= best or dy >= best:
				continue
		best = minf(best, _dist_to_box(p, walls[i]))
	return best


## The distance from p to the nearest wood or metal piece (rule 2), up to NEAR.
static func near_soft(f: Dictionary, p: Vector2) -> float:
	var best := NEAR
	for w: Array in f.get("soft", []):
		best = minf(best, _dist_to_box(p, w))
	return best


## A base disc on open floor: its centre and four rim points in the room, in no structure.
static func _on_floor(f: Dictionary, room: Rect2, base: Vector2, rad: float) -> bool:
	for p in [
		base,
		base + Vector2(rad, 0),
		base - Vector2(rad, 0),
		base + Vector2(0, rad),
		base - Vector2(0, rad)
	]:
		if not room.has_point(p) or _in_any(f, p):
			return false
	return true


static func _in_wall(f: Dictionary, p: Vector2) -> bool:
	for d: Rect2 in f.get("doors", []):
		if d.has_point(p):
			return false
	return _in_box(f, p, 0)


static func _in_any(f: Dictionary, p: Vector2) -> bool:
	return _in_box(f, p, -1)


## p inside a wall of `kind` (-1: any kind).
static func _in_box(f: Dictionary, p: Vector2, kind: int) -> bool:
	var walls: Array = f.get("walls", [])
	var boxes: Array = f.get("boxes", [])
	for i in walls.size():
		var w: Array = walls[i]
		if kind >= 0 and int(w[3]) != kind:
			continue
		if i < boxes.size() and not (boxes[i] as Rect2).has_point(p):
			continue
		if _inside(p, w, 0.0):
			return true
	return false


## The cluster's crystals, all growing from the floor: big ones (a crystal room's), tall ones tight against the
## surface (a corner's crook and arms), low shards a little further out, fragments above. Each base passes rules
## 1, 2 and 6.
static func _grow(
	f: Dictionary, room: Rect2, cand: Dictionary, spec: Dictionary, rng: RandomNumberGenerator
) -> Dictionary:
	var corner: bool = cand["kind"] == &"corner"
	var a: Vector2 = cand["anchor"]
	var n: Vector2 = cand["n"]
	var n2: Vector2 = cand["n2"] if corner else Vector2.ZERO
	var t: Vector2 = cand["t"]
	var away := (n + n2).normalized() if corner else n
	var spread: float = spec["spread"]
	var arm: float = spec["arm"]
	var glow: float = spec["glow"]
	var cap: float = spec["cap"]
	var crystals: Array = []
	# Pass 0: big crystals; 1: tall ones; 2: low shards.
	for pass_i in 3:
		var want: int = [spec["big_n"], spec["tall_n"], spec["low_n"]][pass_i]
		var made := 0
		var reach_max: float = [BIG_HUG, TALL_HUG, HUG][pass_i]
		for k in want * 4:
			if made >= want:
				break
			var rad: float
			match pass_i:
				0:
					rad = rng.randf_range(spec["big_rad"][0], spec["big_rad"][1])
				1:
					rad = rng.randf_range(spec["rad"][0], spec["rad"][1])
				_:
					rad = rng.randf_range(0.05, 0.1)
			var lo := rad * 0.8 + 0.03
			var hi := maxf(lo, reach_max - rad - 0.02)
			var base: Vector2
			if corner:
				var pick := rng.randf()
				if pick < 0.4:
					base = a + n * rng.randf_range(lo, hi) + n2 * rng.randf_range(lo, hi)
				elif pick < 0.7:
					base = a + n * rng.randf_range(lo, hi) + n2 * rng.randf_range(lo, arm)
				else:
					base = a + n2 * rng.randf_range(lo, hi) + n * rng.randf_range(lo, arm)
			else:
				base = a + n * rng.randf_range(lo, hi) + t * rng.randf_range(-spread, spread)
			if not _on_floor(f, room, base, rad) or not _clear(f, base, rad):
				continue
			if not _off_soft(f, base, rad):
				continue
			var dist := near_structure(f, base)
			# The tapered base disc (ShardCluster.BASE_TAPER) clear of every structure, its far edge hugging one.
			if dist < rad * 0.8 or dist + rad > reach_max:
				continue
			var first := crystals.is_empty()
			var h: float
			var tilt: float
			if pass_i < 2:
				var range_h: Array = (
					spec["big_h"] if pass_i == 0 else (spec["first"] if first else spec["rest"])
				)
				h = rng.randf_range(range_h[0], range_h[1])
				# Lower the further from the surface it stands.
				h *= 1.0 - 0.45 * clampf((dist - rad) / reach_max, 0.0, 1.0)
				h = minf(h, cap)
				h = maxf(h, StageDresser.DECOR_MAX_HEIGHT + 0.08)
				tilt = rng.randf_range(0.03, 0.14) if first else rng.randf_range(0.08, 0.24)
			else:
				h = rng.randf_range(0.16, StageDresser.DECOR_MAX_HEIGHT * 0.92)
				tilt = rng.randf_range(0.2, 0.5)
			var lean := away.rotated(rng.randf_range(-0.6, 0.6))
			var x := _crystal(base, rad, h, lean, tilt, rng.randi() % 3, glow, rng)
			x["big"] = pass_i == 0
			crystals.append(x)
			made += 1
		if pass_i == 1 and crystals.is_empty():
			return {"crystals": []}
	# Floating fragments over the cluster (none on a camera-side face).
	var frags: Array = []
	var frag_y: Array = spec["frag_y"]
	var frag_n: int = spec["frag_n"]
	for k in frag_n:
		var p := a + away * rng.randf_range(0.2, 0.8)
		if corner:
			p += (n if rng.randf() < 0.5 else n2) * rng.randf_range(0.0, arm)
		else:
			p += t * rng.randf_range(-spread, spread)
		var y := rng.randf_range(frag_y[0], frag_y[1])
		var s := rng.randf_range(0.05, 0.09)
		var basis := (
			Basis(Vector3.UP, rng.randf() * TAU)
			* Basis(Vector3.RIGHT, rng.randf_range(-0.5, 0.5))
			* Basis.from_scale(Vector3(s, s * 3.4, s))
		)
		frags.append(Transform3D(basis, SimPlane.to_3d(p, y)))
	var light := Vector3.INF
	if spec["hero"]:
		light = SimPlane.to_3d(a + away * 1.2, 1.1)
	return {"crystals": crystals, "fragments": frags, "light": light}


## f with only what can matter near `room` (its walls, doorways and spots within NEAR of it): the same answers,
## a fraction of the work. "all_walls" keeps the whole list (stone_cover's indices refer to it).
static func _local(f: Dictionary, room: Rect2) -> Dictionary:
	var zone := room.grow(NEAR)
	var near := f.duplicate()
	near["rooms"] = f.get("rooms", [])
	near["all_walls"] = f.get("walls", [])
	var walls: Array = []
	var boxes: Array[Rect2] = []
	for w: Array in f.get("walls", []):
		var box := _box_rect(w)
		if box.intersects(zone):
			walls.append(w)
			boxes.append(box)
	near["walls"] = walls
	near["boxes"] = boxes  # each wall's bounding rect: a cheap test before the exact one
	var soft: Array = []
	for w: Array in f.get("soft", []):
		if _box_rect(w).intersects(zone):
			soft.append(w)
	near["soft"] = soft
	var doors: Array = []
	for d: Rect2 in f.get("doors", []):
		if d.intersects(zone):
			doors.append(d)
	near["doors"] = doors
	for key in ["keep_clear", "spawns"]:
		var pts: Array = []
		for q: Vector2 in f.get(key, []):
			if zone.has_point(q):
				pts.append(q)
		near[key] = pts
	return near


static func _box_rect(w: Array) -> Rect2:
	var c: Vector2 = w[0]
	var half: Vector2 = w[1]
	var yaw: float = w[2]
	var ex := absf(half.x * cos(yaw)) + absf(half.y * sin(yaw))
	var ey := absf(half.x * sin(yaw)) + absf(half.y * cos(yaw))
	return Rect2(c - Vector2(ex, ey), Vector2(ex, ey) * 2.0)


## One crystal: the unit crystal (radius 1, height 1, base at y = 0) scaled to rad × h, tilted by `tilt` radians
## toward `lean` (a sim-plane direction), turned at random about its own axis. `glow`: its glow factor.
static func _crystal(
	base: Vector2,
	rad: float,
	h: float,
	lean: Vector2,
	tilt: float,
	variant: int,
	glow: float,
	rng: RandomNumberGenerator
) -> Dictionary:
	var lean3 := SimPlane.to_3d(lean).normalized()
	var axis := Vector3.UP.cross(lean3).normalized()
	var basis := Basis(Vector3.UP, rng.randf() * TAU)
	if axis.length() > 0.5 and tilt > 0.0:
		basis = Basis(axis, tilt) * basis
	basis = basis * Basis.from_scale(Vector3(rad, h, rad))
	return {
		"xform": Transform3D(basis, SimPlane.to_3d(base)),
		"base": base,
		"radius": rad,
		"height": h * cos(tilt),
		"tall": h * cos(tilt) > StageDresser.DECOR_MAX_HEIGHT,
		"big": false,
		"variant": variant,
		"glow": glow,
	}


## The distance from p to a wall's box (0 inside).
static func _dist_to_box(p: Vector2, w: Array) -> float:
	var local := (p - (w[0] as Vector2)).rotated(-(w[2] as float))
	var half: Vector2 = w[1]
	var q := Vector2(maxf(absf(local.x) - half.x, 0.0), maxf(absf(local.y) - half.y, 0.0))
	return q.length()


static func _inside(p: Vector2, w: Array, slack: float) -> bool:
	var local := (p - (w[0] as Vector2)).rotated(-(w[2] as float))
	var half: Vector2 = w[1]
	return absf(local.x) <= half.x + slack and absf(local.y) <= half.y + slack
