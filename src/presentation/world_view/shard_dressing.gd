class_name ShardDressing
extends RefCounted
## Where the crystal-shard clusters go on a floor (v0.6.1 Step SD, owner R4: "we could also add to the generation
## map or the initial room the shard looks"; Step SD2, owner A3: "Very frequent on the starting room and be an
## element of all rooms, but disparity not all equally distributid some zones have more density than others,
## specially walls at smaller rooms"; Step SD3, owner A3b: "not on top of the walls it should be floor closed to the
## walls, corners of some rooms, and other obstacle like they grow from the ground"). A pure function like
## StageDresser: the floor's geometry in, the clusters' crystals out, the same for the same seed. Its draws come from
## its own cosmetic stream (a RandomNumberGenerator seeded from the floor seed, offset from the dresser's and the
## props'), never from or into the sim (EI-05). Presentation only: no cluster has collision.
##
## Rules (starting values, tuned on screenshots):
## 1. Crystals grow from the floor (SD3): every crystal's base disc is on open floor in its room (never in or on a
##    wall or obstacle) and hugs a structure: its far edge within HUG of the nearest wall or cover piece; a crystal
##    taller than StageDresser.DECOR_MAX_HEIGHT within TALL_HUG. Crystals lean away from what they grow against,
##    and get lower the further they stand from it. So the hero, who has no reason to scrape a wall, rarely walks
##    through one (they are decorative: no collision, the sim never sees them).
## 2. Where: at the base of the room's walls, in the corners of some rooms (a cluster with two arms along the
##    walls), and round the base of the cover pieces (rocks, crates, wrecks, slabs: the sim's cover boxes the kit
##    dresses).
## 3. Camera-side faces stay low: a face whose floor side looks away from the iso camera (TO_CAMERA) would put its
##    crystals between the camera and a hero standing beyond them, and the baked crystals can't fade with the wall,
##    so nothing there is taller than LOW_HEIGHT (MID_HEIGHT on faces side-on to the camera), and no fragments.
## 4. Clearances: every crystal's base keeps DOOR_CLEAR from doorways and arena barriers, KEEP_CLEAR from rewards,
##    gates, the shop, the shrine, events and light props, SPAWN_CLEAR from enemy spawn spots, START_CLEAR from the
##    hero's start. Paths: past a cluster's footprint, PATH_CLEAR of free floor (no structure, no other cluster)
##    straight out from what it grows against, so a passage never closes up. Cluster feet keep FOOT_SPACING apart.
## 5. Density is uneven (SD2): a smooth "vein" field over the floor (a few dense zones per floor, seeded on room
##    walls, plus weaker minor veins; `veins`/`vein_at`) drives the chance that a step along a wall or an obstacle,
##    or a corner, gets a cluster, and how big and bright it is. Smaller rooms get more (the chance scales with
##    REF_AREA / area, clamped); the room's theme nudges it. Every room but the boss arena gets at least one cluster.
##    The start room is crystal-rich: the hero cluster (the biggest, in its back corner, with a small cold light)
##    and most of its free wall and obstacle bases lined. Boss arenas get none (their look is the arena's: v0.6.0).

## The horizontal direction toward the iso camera on the sim plane (IsoRig.toward_camera_on_plane at yaw 45°).
const TO_CAMERA := Vector2(0.70710678, -0.70710678)
## Rule 1: how far from the structure a crystal's base disc may reach (its far edge), any crystal and tall ones.
const HUG := 0.7
const TALL_HUG := 0.55
## Rule 3: camera-side faces (floor side · TO_CAMERA below FACE_LOW) and side-on faces (below FACE_MID).
const FACE_LOW := -0.25
const FACE_MID := 0.25
const LOW_HEIGHT := 0.6
const MID_HEIGHT := 0.9
## Rule 4.
const DOOR_CLEAR := 1.8
const KEEP_CLEAR := 1.5
const SPAWN_CLEAR := 0.6
const START_CLEAR := 2.0
const PATH_CLEAR := 1.4
const FOOT_SPACING := 1.2
## The foot (a cluster's reference point for the spacing): this far out from its surface.
const FOOT_OFF := 0.35
## How far along its surface a cluster spreads (half), at no vein and the most; a corner's arms.
const SPREAD_MIN := 0.4
const SPREAD_VEIN := 0.45
const CORNER_ARM := 0.7
const CORNER_ARM_VEIN := 0.7
const HERO_ARM := 1.4
const HERO_ATTEMPTS := 30
## How far around a room anything can still matter to its clusters (a corner's arm plus HUG and PATH_CLEAR).
const NEAR := 3.5
## Floating fragments hover at least this high (above the hero's head).
const FRAGMENT_MIN_Y := 1.1
## Density (starting values). The walk along each wall and obstacle face: one candidate every WALK_STEP m
## (START_STEP in the start room). A wall candidate gets a cluster with chance
## (BASE_CHANCE + VEIN_CHANCE * vein) * room factor, an obstacle candidate with OBSTACLE_BASE instead of BASE_CHANCE,
## a corner with CORNER_BASE; at most MAX_CHANCE. The start room's chances are START_CHANCE (walls and corners) and
## START_OBSTACLE.
const WALK_STEP := 1.1
const START_STEP := 0.8
const BASE_CHANCE := 0.12
const OBSTACLE_BASE := 0.08
const CORNER_BASE := 0.4
const VEIN_CHANCE := 0.85
const MAX_CHANCE := 0.92
const START_CHANCE := 0.9
const START_OBSTACLE := 0.5
## The room factor: REF_AREA / room area, clamped (a median room is about 250 m²), times the theme's.
const REF_AREA := 250.0
const SIZE_MIN := 0.55
const SIZE_MAX := 2.5
const THEME_RICH := 1.25
const THEME_CAMP := 0.6
## Every room gets one: a finer walk for the fallback.
const FALLBACK_STEP := 0.5
## The veins: major ones (the dense zones) and minor ones, each [count min, count max, radius min, radius max,
## strength].
const MAJOR_VEINS: Array[float] = [3.0, 5.0, 6.0, 10.0, 1.0]
const MINOR_VEINS: Array[float] = [4.0, 7.0, 3.0, 5.0, 0.45]
## How much brighter a cluster at a vein's centre glows (its crystals' glow factor goes 1 .. 1 + VEIN_GLOW).
const VEIN_GLOW := 0.35
## The hero cluster's crystals glow this much more than the room's.
const HERO_GLOW := 1.55


## Places the clusters. `f` keys:
## - "walls": [[center: Vector2, half: Vector2, yaw: float, kind: int, ...]] (StageDresser's input: kind 0
##   structural, 1 cover);
## - "rooms": [Rect2]; "themes": [StringName] (each room's theme, WorldReader.floor_room_theme); "start_room": int;
##   "boss_room": int;
## - "doors": [Rect2] (doorways and arena barriers); "keep_clear": [Vector2]; "spawns": [Vector2];
##   "start": Vector2; "seed": int.
## Returns [{"room": int, "hero": bool, "kind": &"wall" | &"corner" | &"obstacle", "front": bool (a camera-side
## face, kept low), "cap": float (its height cap), "vein": float, "foot": Vector2, "radius": float (the circle round
## the foot holding every base disc), "inward": Vector2 (away from its surface), "crystals": [{"xform": Transform3D
## (scales the unit crystal), "base": Vector2, "radius": float, "height": float, "tall": bool, "variant": int,
## "glow": float}], "fragments": [Transform3D], "light": Vector3 (the hero's only; Vector3.INF for none)}].
static func place(f: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f.get("seed", 0)) * 7919 + 9241  # the cosmetic stream: presentation only
	var out: Array = []
	var rooms: Array = f.get("rooms", [])
	var themes: Array = f.get("themes", [])
	var start := int(f.get("start_room", -1))
	var boss := int(f.get("boss_room", -1))
	var field := veins(rooms, boss, rng)  # the stream's first draws: floor_veins(f) gives the same field
	for r in rooms.size():
		if r == boss:
			continue
		var room: Rect2 = rooms[r]
		var near := _local(f, room)
		var mine: Array = []
		var is_start := r == start
		if is_start:
			var hero := _try_hero(near, r, mine, rng)
			if not hero.is_empty():
				mine.append(hero)
		var t := StringName(themes[r]) if r < themes.size() else &""
		var scale := _chance_scale(room, t)
		var cands := _candidates(near, room, rng, START_STEP if is_start else WALK_STEP)
		for cand: Dictionary in cands:
			var v := vein_at(field, cand["anchor"])
			cand["vein"] = v
			var p := _chance(cand["kind"], v, scale, is_start)
			if rng.randf() >= p:
				continue
			var c := _cluster(near, r, cand, _spec(cand, v, is_start, false, rng), mine, rng)
			if not c.is_empty():
				mine.append(c)
		if mine.is_empty():
			# Every room gets one: a tight cluster at the best spot that fits, on a finer walk (the stronger vein
			# first).
			var fine := _candidates(near, room, rng, FALLBACK_STEP)
			for cand: Dictionary in fine:
				cand["vein"] = vein_at(field, cand["anchor"])
			fine.sort_custom(
				func(a: Dictionary, b: Dictionary) -> bool: return a["vein"] > b["vein"]
			)
			for cand: Dictionary in fine:
				var c := _cluster(
					near, r, cand, _spec(cand, cand["vein"], false, true, rng), mine, rng
				)
				if not c.is_empty():
					mine.append(c)
					break
		out.append_array(mine)
	return out


## The vein field place(f) uses (for tests and tools): the same stream, its first draws.
static func floor_veins(f: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f.get("seed", 0)) * 7919 + 9241
	return veins(f.get("rooms", []), int(f.get("boss_room", -1)), rng)


## The floor's vein field: [[centre: Vector2, radius: float, strength: float]]. Major veins sit on a room's wall
## (a dense stretch); minor ones anywhere on a room's floor. Drawn from the cosmetic stream.
static func veins(rooms: Array, boss: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var pool: Array[int] = []
	for r in rooms.size():
		if r != boss:
			pool.append(r)
	if pool.is_empty():
		return out
	for spec: Array in [MAJOR_VEINS, MINOR_VEINS]:
		var n := rng.randi_range(int(spec[0]), int(spec[1]))
		for k in n:
			var room: Rect2 = rooms[pool[rng.randi() % pool.size()]]
			var p := Vector2(
				rng.randf_range(room.position.x, room.end.x),
				rng.randf_range(room.position.y, room.end.y)
			)
			if spec[4] >= 1.0:
				# Onto the nearest wall of its room: a dense stretch of wall.
				var dl := p.x - room.position.x
				var dr := room.end.x - p.x
				var db := p.y - room.position.y
				var dt := room.end.y - p.y
				var m := minf(minf(dl, dr), minf(db, dt))
				if m == dl:
					p.x = room.position.x
				elif m == dr:
					p.x = room.end.x
				elif m == db:
					p.y = room.position.y
				else:
					p.y = room.end.y
			out.append([p, rng.randf_range(spec[2], spec[3]), spec[4]])
	return out


## The vein field's value at p, 0..1: each vein adds strength * (1 - (d / radius)²)² inside its radius (smooth).
static func vein_at(field: Array, p: Vector2) -> float:
	var v := 0.0
	for vein: Array in field:
		var x := p.distance_squared_to(vein[0]) / (float(vein[1]) * float(vein[1]))
		if x < 1.0:
			v += float(vein[2]) * (1.0 - x) * (1.0 - x)
	return clampf(v, 0.0, 1.0)


## The room's chance multiplier: its size factor times its theme factor.
static func _chance_scale(room: Rect2, theme: StringName) -> float:
	var size_f := clampf(REF_AREA / maxf(room.get_area(), 1.0), SIZE_MIN, SIZE_MAX)
	match theme:
		&"ruined_hall", &"overgrown":
			return size_f * THEME_RICH
		&"camp":
			return size_f * THEME_CAMP
	return size_f


static func _chance(kind: StringName, v: float, scale: float, start: bool) -> float:
	if start:
		return START_OBSTACLE if kind == &"obstacle" else START_CHANCE
	var base := BASE_CHANCE
	if kind == &"obstacle":
		base = OBSTACLE_BASE
	elif kind == &"corner":
		base = CORNER_BASE
	return minf((base + VEIN_CHANCE * v) * scale, MAX_CHANCE)


## The face's height cap (rule 3) for a floor side looking along n.
static func _cap(n: Vector2) -> float:
	var d := n.normalized().dot(TO_CAMERA)
	if d < FACE_LOW:
		return LOW_HEIGHT
	if d < FACE_MID:
		return MID_HEIGHT
	return INF


## The candidate spots of a room: its four corners, then its walls' bases every `step` m from a random offset
## (clear of the corners), then the faces of the cover pieces standing in it. Each {"kind", "anchor" (on the
## surface), "n" (away from it, over the floor), "t" (along it), "n2" (a corner's other wall's normal), "cap"}.
static func _candidates(
	f: Dictionary, room: Rect2, rng: RandomNumberGenerator, step: float
) -> Array:
	var out: Array = []
	var p0 := room.position
	var p1 := room.end
	for c: Array in [
		[Vector2(p0.x, p1.y), Vector2(1, 0), Vector2(0, -1)],
		[Vector2(p1.x, p1.y), Vector2(-1, 0), Vector2(0, -1)],
		[Vector2(p1.x, p0.y), Vector2(-1, 0), Vector2(0, 1)],
		[Vector2(p0.x, p0.y), Vector2(1, 0), Vector2(0, 1)],
	]:
		var bis := ((c[1] as Vector2) + (c[2] as Vector2)).normalized()
		(
			out
			. append(
				{
					"kind": &"corner",
					"anchor": c[0],
					"n": c[1],
					"n2": c[2],
					"t": Vector2.ZERO,
					"cap": _cap(bis),
				}
			)
		)
	# [origin, along, inward, length]: the room's four walls.
	var sides := [
		[p0, Vector2(0, 1), Vector2(1, 0), room.size.y],
		[Vector2(p0.x, p1.y), Vector2(1, 0), Vector2(0, -1), room.size.x],
		[Vector2(p1.x, p0.y), Vector2(0, 1), Vector2(-1, 0), room.size.y],
		[p0, Vector2(1, 0), Vector2(0, 1), room.size.x],
	]
	var end := HUG + 0.4
	for s: Array in sides:
		var length: float = s[3]
		var at := end + rng.randf() * step
		while at <= length - end:
			(
				out
				. append(
					{
						"kind": &"wall",
						"anchor": (s[0] as Vector2) + (s[1] as Vector2) * at,
						"n": s[2],
						"t": s[1],
						"cap": _cap(s[2]),
					}
				)
			)
			at += step
	# The cover pieces whose centre is in the room: each face, walked the same way.
	for w: Array in f.get("walls", []):
		if int(w[3]) != 1 or not room.has_point(w[0]):
			continue
		var c: Vector2 = w[0]
		var half: Vector2 = w[1]
		var yaw: float = w[2]
		for face: Array in [
			[Vector2(1, 0), Vector2(0, 1), half.x, half.y],
			[Vector2(-1, 0), Vector2(0, 1), half.x, half.y],
			[Vector2(0, 1), Vector2(1, 0), half.y, half.x],
			[Vector2(0, -1), Vector2(1, 0), half.y, half.x],
		]:
			var n := (face[0] as Vector2).rotated(yaw)
			var t := (face[1] as Vector2).rotated(yaw)
			var off: float = face[2]
			var reach: float = face[3]
			var at := -reach + rng.randf() * minf(step, 2.0 * reach)
			while at <= reach:
				(
					out
					. append(
						{
							"kind": &"obstacle",
							"anchor": c + n * off + t * at,
							"n": n,
							"t": t,
							"cap": _cap(n),
						}
					)
				)
				at += step
	return out


## The cluster's shape for a candidate at vein strength v (0..1): bigger, fuller and brighter toward a vein's
## centre; corners fuller still. `start`: the start room's mixed sizes and more fragments; `tight`: the fallback's
## small cluster.
static func _spec(
	cand: Dictionary, v: float, start: bool, tight: bool, rng: RandomNumberGenerator
) -> Dictionary:
	if start:
		v = maxf(v, rng.randf_range(0.3, 0.9))
	var corner: bool = cand["kind"] == &"corner"
	var k := 1.0 + 0.6 * v
	var w := 0.95 + 0.35 * v
	var spec := {
		"tall_n": 2 + roundi(3.0 * v) + rng.randi_range(0, 1) + (2 if corner else 0),
		"first": [1.2 * k, 1.6 * k] if corner else [1.0 * k, 1.4 * k],
		"rest": [0.6 * k, 1.1 * k],
		"rad": [0.1 * w, 0.17 * w],
		"spread": SPREAD_MIN + SPREAD_VEIN * v,
		"arm": CORNER_ARM + CORNER_ARM_VEIN * v,
		"low_n": 3 + roundi(3.0 * v) + rng.randi_range(0, 1) + (2 if start else 0),
		"frag_n": rng.randi_range(1, 2) + roundi(2.0 * v) + (2 if start else 0),
		"frag_y": [1.15, 1.6 + 0.3 * v],
		"cap": cand["cap"],
		"glow": 1.0 + VEIN_GLOW * v,
		"hero": false,
		"vein": v,
	}
	if tight:
		spec["tall_n"] = rng.randi_range(2, 3)
		spec["spread"] = 0.3
		spec["arm"] = 0.5
		spec["low_n"] = 2
	if spec["cap"] < INF:
		spec["frag_n"] = 0
	return spec


static func _hero_spec(cand: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	return {
		"tall_n": rng.randi_range(8, 10),
		"first": [2.3, 2.8],
		"rest": [1.1, 1.9],
		"rad": [0.14, 0.22],
		"spread": 1.0,
		"arm": HERO_ARM,
		"low_n": rng.randi_range(8, 10),
		"frag_n": rng.randi_range(5, 6),
		"frag_y": [FRAGMENT_MIN_Y + 0.2, 1.9],
		"cap": cand["cap"],
		"glow": HERO_GLOW,
		"hero": true,
		"vein": 1.0,
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
## clearance) or no crystal fits.
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
	if not _clear(f, foot, FOOT_OFF):
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
	c["vein"] = spec["vein"]
	c["foot"] = foot
	c["radius"] = radius
	c["inward"] = away
	return c


## The surface is there: a room wall behind the anchor all along the spread (not a doorway), both walls of a
## corner along its arms. An obstacle's face always is.
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


## Rule 4's paths: from the cluster's outer edge, PATH_CLEAR of free floor straight out (no structure, no other
## cluster's footprint), at its middle and both ends.
static func _path(f: Dictionary, cand: Dictionary, spec: Dictionary, placed: Array) -> bool:
	var a: Vector2 = cand["anchor"]
	var n: Vector2 = cand["n"]
	var starts: Array[Vector2] = []
	var dirs: Array[Vector2] = []
	if cand["kind"] == &"corner":
		var n2: Vector2 = cand["n2"]
		var arm: float = spec["arm"]
		var bis := (n + n2).normalized()
		starts.append_array([a + bis * HUG * 1.41, a + n2 * arm + n * HUG, a + n * arm + n2 * HUG])
		dirs.append_array([bis, n, n2])
	else:
		var t: Vector2 = cand["t"]
		var spread: float = spec["spread"]
		for s in [-spread, 0.0, spread]:
			starts.append(a + t * s + n * HUG)
			dirs.append(n)
	var reach := HUG + PATH_CLEAR + float(spec["arm"]) + 3.0
	var others: Array = placed.filter(
		func(c: Dictionary) -> bool: return a.distance_to(c["foot"]) < reach
	)
	for i in starts.size():
		var k := 0.0
		while k <= PATH_CLEAR:
			var p := starts[i] + dirs[i] * k
			if _in_any(f, p):
				return false
			for c: Dictionary in others:
				if p.distance_to(c["foot"]) < float(c["radius"]):
					return false
			k += 0.3
	return true


## True when a disc at p (radius rad) keeps every clearance of rule 4.
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


## A base disc on open floor: its centre and four rim points in the room, in no structure and no doorway gap.
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


## The cluster's crystals, all growing from the floor: tall ones tight against the surface (a corner's crook and
## arms), low shards a little further out, fragments above. Each base passes rule 1 and the clearances.
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
	var rads: Array = spec["rad"]
	var crystals: Array = []
	for pass_i in 2:
		var tall := pass_i == 0
		var want: int = spec["tall_n"] if tall else spec["low_n"]
		var made := 0
		var reach_max := TALL_HUG if tall else HUG
		for k in want * 4:
			if made >= want:
				break
			var rad := rng.randf_range(rads[0], rads[1]) if tall else rng.randf_range(0.05, 0.1)
			var lo := rad + 0.03
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
			var dist := near_structure(f, base)
			# The tapered base disc (ShardCluster.BASE_TAPER) clear of every structure, its far edge hugging one.
			if dist < rad * 0.8 or dist + rad > reach_max:
				continue
			var first := crystals.is_empty()
			var h: float
			var tilt: float
			if tall:
				var range_h: Array = spec["first"] if first else spec["rest"]
				h = rng.randf_range(range_h[0], range_h[1])
				# Lower the further from the surface it stands.
				h *= 1.0 - 0.45 * clampf((dist - rad) / TALL_HUG, 0.0, 1.0)
				h = minf(h, cap)
				h = maxf(h, StageDresser.DECOR_MAX_HEIGHT + 0.08)
				tilt = rng.randf_range(0.03, 0.14) if first else rng.randf_range(0.08, 0.24)
			else:
				h = rng.randf_range(0.16, StageDresser.DECOR_MAX_HEIGHT * 0.92)
				tilt = rng.randf_range(0.2, 0.5)
			var lean := away.rotated(rng.randf_range(-0.6, 0.6))
			crystals.append(_crystal(base, rad, h, lean, tilt, rng.randi() % 3, glow, rng))
			made += 1
		if tall and crystals.is_empty():
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
## a fraction of the work.
static func _local(f: Dictionary, room: Rect2) -> Dictionary:
	var zone := room.grow(NEAR)
	var near := f.duplicate()
	near["rooms"] = f.get("rooms", [])
	var walls: Array = []
	var boxes: Array[Rect2] = []
	for w: Array in f.get("walls", []):
		var box := _box_rect(w)
		if box.intersects(zone):
			walls.append(w)
			boxes.append(box)
	near["walls"] = walls
	near["boxes"] = boxes  # each wall's bounding rect: a cheap test before the exact one
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
