class_name ShardDressing
extends RefCounted
## Where the crystal-shard clusters go on a floor (v0.6.1 Step SD, owner R4: "we could also add to the generation
## map or the initial room the shard looks"; Step SD2, owner A3: "Very frequent on the starting room and be an
## element of all rooms, but disparity not all equally distributid some zones have more density than others,
## specially walls at smaller rooms"). A pure function like StageDresser: the floor's geometry in, the clusters'
## crystals out, the same for the same seed. Its draws come from its own cosmetic stream (a RandomNumberGenerator
## seeded from the floor seed, offset from the dresser's and the props'), never from or into the sim (EI-05).
## Presentation only: no cluster has collision, so none may look like it needs it.
##
## Rules (starting values, tuned on screenshots):
## 1. Looks solid = is solid (StageDresser rule 1). A crystal taller than StageDresser.DECOR_MAX_HEIGHT grows out
##    of a structural wall: its base sits inside the wall's footprint. On open floor only low shards (no taller than
##    the decoration limit) spill from the cluster's foot, and floating fragments hover above head height.
## 2. Clusters line the room's walls. The back walls (-X and +Y faces, never faded by occlusion) take full-size
##    clusters and the back corner. The front walls (+X and -Y faces, between the room and the camera, faded when
##    they hide the hero) take only low clusters: no crystal over FRONT_MAX_HEIGHT (just over the 1 m wall top),
##    leaning away from the room, and no floating fragments, so a faded front wall never leaves a crystal in front
##    of the fight.
## 3. Spacing (v0.5.9 "everything touches a wall or leaves a 2.2 m gap"): every cluster touches its wall; its foot
##    keeps SLAB_GAP from every cover piece; DOOR_CLEAR from doorways and arena barriers; KEEP_CLEAR from rewards,
##    gates, the shop, the shrine, events and light props; SPAWN_CLEAR from enemy spawn spots; START_CLEAR from the
##    hero's start; CLUSTER_GAP between two clusters' feet (SD2: clusters may line a wall, so this is a gap, not
##    SD's 3 m spacing).
## 4. Density (SD2) is uneven: a smooth "vein" field over the floor (a few dense zones per floor, seeded on room
##    walls, plus weaker minor veins; `veins`/`vein_at`) drives the chance that a step along a wall gets a cluster
##    and how big and bright it is. Smaller rooms get more per wall metre (the chance scales with
##    REF_AREA / area, clamped); the room's theme nudges it (Ruined hall and Overgrown richer, Camp poorer). Every room
##    but the boss arena gets at least one cluster (the best spot that fits). The start room is crystal-rich: the
##    hero cluster (bigger, at its back corner, with a small cold light) and most of its free wall length lined with
##    mixed sizes, more low shards and fragments. Boss arenas get none (their look is the arena's: v0.6.0).

## The v0.5.9 slab gap (the floor generator's gap between groups; the vignettes' spacing).
const SLAB_GAP := 2.2
## SD2: the gap between two clusters' feet (SD kept 3 m between them; lining a wall needs them closer).
const CLUSTER_GAP := 0.3
const DOOR_CLEAR := 1.8
const KEEP_CLEAR := 1.5
const SPAWN_CLEAR := 0.6
const START_CLEAR := 2.0
## The foot's radius on the floor (the low shards stay inside it) and how far its centre stands off the wall.
const SMALL_FOOT := 0.7
const HERO_FOOT := 1.0
const SMALL_REACH := 0.35
const HERO_REACH := 0.6
## How far along the wall the cluster's crystals spread (half), small and hero.
const SMALL_SPREAD := 0.45
const HERO_SPREAD := 1.0
## Wall depth probes (m from the face) and the depth used at most.
const DEPTH_PROBES: Array[float] = [0.3, 0.45, 0.6]
const HERO_ATTEMPTS := 30
## The fallback (a room with no cluster after its walk): a finer walk and a tighter cluster.
const FALLBACK_STEP := 0.5
const FALLBACK_END := 0.55
const TIGHT_FOOT := 0.42
const TIGHT_REACH := 0.22
const TIGHT_SPREAD := 0.3
## How far around a room anything can still matter to its clusters (the widest clearance plus the deepest wall).
const NEAR := 5.0
## Floating fragments hover at least this high (above the hero's head).
const FRAGMENT_MIN_Y := 1.1
## SD2: no crystal on a front (camera-side) wall stands taller than this: its tip just shows over the 1 m wall.
const FRONT_MAX_HEIGHT := 1.4
## SD2 density (starting values). The walk along each wall: one candidate every WALK_STEP m (START_STEP in the
## start room). A candidate gets a
## cluster with chance (BASE_CHANCE + VEIN_CHANCE * vein) * size factor * theme factor, at most MAX_CHANCE; the
## start room's chance is START_CHANCE everywhere.
const WALK_STEP := 1.1
const START_STEP := 0.8
const BASE_CHANCE := 0.12
const VEIN_CHANCE := 0.85
const MAX_CHANCE := 0.92
const START_CHANCE := 0.9
## The size factor: REF_AREA / room area, clamped (a median room is about 250 m²).
const REF_AREA := 250.0
const SIZE_MIN := 0.55
const SIZE_MAX := 2.5
const THEME_RICH := 1.25
const THEME_CAMP := 0.6
## The veins: major ones (the dense zones) and minor ones, each [count min, count max, radius min, radius max,
## strength].
const MAJOR_VEINS: Array[float] = [3.0, 5.0, 6.0, 10.0, 1.0]
const MINOR_VEINS: Array[float] = [4.0, 7.0, 3.0, 5.0, 0.45]
## How much brighter a cluster at a vein's centre glows (its crystals' glow factor goes 1 .. 1 + VEIN_GLOW).
const VEIN_GLOW := 0.35
## The hero cluster's crystals glow this much more than the room's (SD's hero room energy 0.7 over 0.45).
const HERO_GLOW := 1.55


## Places the clusters. `f` keys:
## - "walls": [[center: Vector2, half: Vector2, yaw: float, kind: int, ...]] (StageDresser's input: kind 0
##   structural, 1 cover);
## - "rooms": [Rect2]; "themes": [StringName] (each room's theme, WorldReader.floor_room_theme); "start_room": int;
##   "boss_room": int;
## - "doors": [Rect2] (doorways and arena barriers); "keep_clear": [Vector2]; "spawns": [Vector2];
##   "start": Vector2; "seed": int.
## Returns [{"room": int, "hero": bool, "front": bool, "vein": float, "foot": Vector2 (the foot's centre),
## "radius": float, "inward": Vector2, "crystals": [{"xform": Transform3D (scales the unit crystal),
## "base": Vector2, "radius": float, "height": float, "tall": bool, "variant": int, "glow": float}],
## "fragments": [Transform3D], "light": Vector3 (the hero's only; Vector3.INF for none)}].
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
		var near := _local(f, rooms[r])
		var mine: Array = []
		if r == start:
			var hero := _try_hero(near, r, out, rng)
			if not hero.is_empty():
				out.append(hero)
				mine.append(hero)
		var t := StringName(themes[r]) if r < themes.size() else &""
		var chance := _chance_scale(rooms[r], t)
		var candidates := _walk(rooms[r], rng, START_STEP if r == start else WALK_STEP)
		for cand: Array in candidates:
			var v := vein_at(field, cand[0])
			cand.append(v)
			var p := (
				START_CHANCE
				if r == start
				else minf((BASE_CHANCE + VEIN_CHANCE * v) * chance, MAX_CHANCE)
			)
			if rng.randf() >= p:
				continue
			var c := _try_at(near, r, cand, r == start, out, rng)
			if c.is_empty():
				# Where a foot on the floor breaks a rule (mostly the slab gap), crystals only in the wall top.
				c = _cluster(
					near, r, cand, _wall_only(_spec(v, r == start, cand[3], rng)), out, rng
				)
			if not c.is_empty():
				out.append(c)
				mine.append(c)
		if mine.is_empty():
			# Every room gets one: a tight cluster at the best spot that fits, on a finer walk (back walls first,
			# then the stronger vein).
			var fine := _walk(rooms[r], rng, FALLBACK_STEP, FALLBACK_END)
			for cand: Array in fine:
				cand.append(vein_at(field, cand[0]))
			fine.sort_custom(_better)
			# A tight cluster first; where none fits (a small room crowded with cover and doorways), crystals
			# only in the wall top: no foot on the floor (radius 0 at the wall face), no low shards.
			for wall_only in [false, true]:
				var done := false
				for cand: Array in fine:
					var spec := _tight_spec(cand[3], cand[5], wall_only, rng)
					var c := _cluster(near, r, cand, spec, out, rng)
					if not c.is_empty():
						out.append(c)
						done = true
						break
				if done:
					break
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


## The candidate spots along the room's walls: [[anchor, outward, along, front, corner]], the back corner first,
## then each wall from a random offset every `step` m, `end` m clear of the room's corners.
static func _walk(
	room: Rect2, rng: RandomNumberGenerator, step := WALK_STEP, end := SMALL_SPREAD + 0.6
) -> Array:
	var out: Array = [
		[
			Vector2(room.position.x, room.end.y),
			Vector2(-1, 1).normalized(),
			Vector2(1, 1).normalized(),
			false,
			true
		]
	]
	# [origin, along, outward, length, front]: -X and +Y are the back walls, +X and -Y the front ones.
	var sides := [
		[room.position, Vector2(0, 1), Vector2(-1, 0), room.size.y, false],
		[Vector2(room.position.x, room.end.y), Vector2(1, 0), Vector2(0, 1), room.size.x, false],
		[Vector2(room.end.x, room.position.y), Vector2(0, 1), Vector2(1, 0), room.size.y, true],
		[room.position, Vector2(1, 0), Vector2(0, -1), room.size.x, true],
	]
	for s: Array in sides:
		var length: float = s[3]
		var t := end + rng.randf() * step
		while t <= length - end:
			out.append([(s[0] as Vector2) + (s[1] as Vector2) * t, s[2], s[1], s[4], false])
			t += step
	return out


## Sort order for the fallback: back walls before front ones, then the stronger vein.
static func _better(a: Array, b: Array) -> bool:
	if a[3] != b[3]:
		return not a[3]
	return float(a[5]) > float(b[5])


## f with only what can matter near `room` (its walls, doorways and spots within NEAR of it): the same answers,
## a fraction of the work.
static func _local(f: Dictionary, room: Rect2) -> Dictionary:
	var zone := room.grow(NEAR)
	var near := f.duplicate()
	near["rooms"] = f.get("rooms", [])
	var walls: Array = []
	for w: Array in f.get("walls", []):
		if _box_rect(w).intersects(zone):
			walls.append(w)
	near["walls"] = walls
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


## The cluster's shape for a vein strength v (0..1): bigger, fuller and brighter toward a vein's centre. `start`:
## the start room's mixed sizes (never the smallest) with more low shards and fragments. `front`: low and no
## fragments (rule 2).
static func _spec(v: float, start: bool, front: bool, rng: RandomNumberGenerator) -> Dictionary:
	if start:
		v = maxf(v, rng.randf_range(0.3, 0.9))
	var k := 1.0 + 0.7 * v
	var w := 0.95 + 0.45 * v
	return {
		"tall_n": 3 + roundi(3.0 * v) + rng.randi_range(0, 1),
		"first": [1.45 * k, 1.8 * k],
		"rest": [1.05 * k, 1.4 * k],
		"rad": [0.13 * w, 0.2 * w],
		"spread": SMALL_SPREAD * (0.9 + 0.9 * v),
		"foot": SMALL_FOOT * (0.85 + 0.3 * v),
		"reach": SMALL_REACH,
		"low_n": 2 + roundi(2.0 * v) + rng.randi_range(0, 1) + (2 if start else 0),
		"frag_n": 0 if front else rng.randi_range(1, 2) + roundi(2.0 * v) + (2 if start else 0),
		"frag_y": [1.15, 1.6 + 0.3 * v],
		"cap": FRONT_MAX_HEIGHT if front else INF,
		"glow": 1.0 + VEIN_GLOW * v,
		"hero": false,
		"front": front,
		"vein": v,
	}


## The fallback's tight cluster (a room where no ordinary cluster fits): a smaller foot closer to the wall, a
## narrower spread, two or three crystals; still every spacing rule.
## `wall_only`: no foot on the floor at all (the crystals stay in the wall top, leaning away from the room).
static func _tight_spec(
	front: bool, v: float, wall_only: bool, rng: RandomNumberGenerator
) -> Dictionary:
	var spec := _spec(0.0, false, front, rng)
	spec["tall_n"] = rng.randi_range(2, 3)
	spec["spread"] = TIGHT_SPREAD
	spec["foot"] = TIGHT_FOOT
	spec["reach"] = TIGHT_REACH
	spec["low_n"] = rng.randi_range(1, 2)
	spec["glow"] = 1.0 + VEIN_GLOW * v
	spec["vein"] = v
	return _wall_only(spec) if wall_only else spec


## A spec without a foot on the floor: the crystals stay in the wall top and lean away from the room, no low
## shards (radius 0 at the wall face, so every spacing rule is measured from the wall itself).
static func _wall_only(spec: Dictionary) -> Dictionary:
	spec["foot"] = 0.0
	spec["reach"] = 0.0
	spec["low_n"] = 0
	spec["lean_out"] = true
	return spec


static func _hero_spec(rng: RandomNumberGenerator) -> Dictionary:
	return {
		"tall_n": rng.randi_range(7, 9),
		"first": [2.3, 2.8],
		"rest": [1.2, 2.0],
		"rad": [0.16, 0.26],
		"spread": HERO_SPREAD,
		"foot": HERO_FOOT,
		"reach": HERO_REACH,
		"low_n": rng.randi_range(6, 8),
		"frag_n": rng.randi_range(4, 5),
		"frag_y": [FRAGMENT_MIN_Y + 0.2, 1.9],
		"cap": INF,
		"glow": HERO_GLOW,
		"hero": true,
		"front": false,
		"vein": 1.0,
	}


## The start room's hero cluster on a back wall (the back corner first), or {} when no spot passes the rules.
static func _try_hero(
	f: Dictionary, r: int, placed: Array, rng: RandomNumberGenerator
) -> Dictionary:
	var room: Rect2 = f["rooms"][r]
	var spec := _hero_spec(rng)
	var spread := HERO_SPREAD
	for attempt in HERO_ATTEMPTS:
		var cand: Array
		if attempt == 0:
			cand = [
				Vector2(room.position.x, room.end.y),
				Vector2(-1, 1).normalized(),
				Vector2(1, 1).normalized(),
				false,
				true
			]
		else:
			var left := rng.randf() < room.size.y / (room.size.x + room.size.y)
			var lo := spread + 0.3
			if left:
				var hi := room.size.y - lo
				if hi <= lo:
					continue
				cand = [
					Vector2(room.position.x, room.position.y + rng.randf_range(lo, hi)),
					Vector2(-1, 0),
					Vector2(0, 1),
					false,
					false
				]
			else:
				var hi := room.size.x - lo
				if hi <= lo:
					continue
				cand = [
					Vector2(room.position.x + rng.randf_range(lo, hi), room.end.y),
					Vector2(0, 1),
					Vector2(1, 0),
					false,
					false
				]
		var c := _cluster(f, r, cand, spec, placed, rng)
		if not c.is_empty():
			return c
	return {}


## A cluster at the candidate `cand` ([anchor, outward, along, front, corner, vein]), or {} when it breaks a rule.
static func _try_at(
	f: Dictionary, r: int, cand: Array, start: bool, placed: Array, rng: RandomNumberGenerator
) -> Dictionary:
	var v: float = cand[5] if cand.size() > 5 else 0.0
	return _cluster(f, r, cand, _spec(v, start, cand[3], rng), placed, rng)


static func _cluster(
	f: Dictionary, r: int, cand: Array, spec: Dictionary, placed: Array, rng: RandomNumberGenerator
) -> Dictionary:
	var room: Rect2 = f["rooms"][r]
	var anchor: Vector2 = cand[0]
	var outward: Vector2 = cand[1]
	var along: Vector2 = cand[2]
	var at_corner: bool = cand[4]
	var inward := -outward
	var foot_r: float = spec["foot"]
	var foot := anchor + inward * (float(spec["reach"]) * (1.4 if at_corner else 1.0))
	if not _clear(f, room, foot, foot_r, placed):
		return {}
	var depth := _wall_depth(f, anchor, outward, along, spec["spread"], at_corner)
	if depth <= 0.0:
		return {}
	var c := _grow(f, [anchor, outward, along, foot, foot_r, room], depth, at_corner, spec, rng)
	if c["crystals"].is_empty():
		return {}
	c["room"] = r
	c["hero"] = spec["hero"]
	c["front"] = spec["front"]
	c["vein"] = spec["vein"]
	c["foot"] = foot
	c["radius"] = foot_r
	c["inward"] = inward
	return c


## True when a foot at p (radius rad) breaks no spacing rule.
static func _clear(f: Dictionary, room: Rect2, p: Vector2, rad: float, placed: Array) -> bool:
	if not room.grow(0.05).has_point(p):
		return false
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
	for w: Array in f.get("walls", []):
		if int(w[3]) != 1:
			continue
		if _dist_to_box(p, w) < SLAB_GAP + rad:
			return false
	for c: Dictionary in placed:
		var foot: Vector2 = c["foot"]
		var gap := CLUSTER_GAP + rad + float(c["radius"])
		if absf(p.x - foot.x) < gap and absf(p.y - foot.y) < gap and p.distance_to(foot) < gap:
			return false
	return true


## How deep the structural wall behind the anchor goes (the largest probe that stays in a wall all along the
## cluster's spread), or 0 when there is no wall (a doorway, the void).
static func _wall_depth(
	f: Dictionary, anchor: Vector2, outward: Vector2, along: Vector2, spread: float, corner: bool
) -> float:
	var best := 0.0
	for d in DEPTH_PROBES:
		var ok := true
		var probes: Array[Vector2] = []
		if corner:
			# Both walls of the corner, out along each.
			var ox := Vector2(outward.x, 0).normalized()
			var oy := Vector2(0, outward.y).normalized()
			for s in [0.0, spread]:
				probes.append(anchor + ox * (d - 0.05) + Vector2(0, -1) * s * oy.y)
				probes.append(anchor + oy * (d - 0.05) + Vector2(1, 0) * s * -ox.x)
		else:
			for s in [-spread, 0.0, spread]:
				probes.append(anchor + outward * (d - 0.05) + along * s)
		for p in probes:
			if not _in_structure(f, p):
				ok = false
				break
		if not ok:
			break
		best = d
	return best


static func _in_structure(f: Dictionary, p: Vector2) -> bool:
	for d: Rect2 in f.get("doors", []):
		if d.has_point(p):
			return false
	for w: Array in f.get("walls", []):
		if int(w[3]) == 0 and _inside(p, w, 0.0):
			return true
	return false


## The cluster's crystals: tall ones grown from inside the wall, low shards at its foot, fragments above.
## `frame`: [anchor, outward, along, foot centre, foot radius, room]. `spec`: _spec / _hero_spec.
static func _grow(
	f: Dictionary,
	frame: Array,
	depth: float,
	corner: bool,
	spec: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var anchor: Vector2 = frame[0]
	var outward: Vector2 = frame[1]
	var along: Vector2 = frame[2]
	var foot: Vector2 = frame[3]
	var foot_r: float = frame[4]
	var room: Rect2 = frame[5]
	var crystals: Array = []
	var inward := -outward
	var spread: float = spec["spread"]
	var glow: float = spec["glow"]
	var cap: float = spec["cap"]
	var front: bool = spec["front"]
	var tall_n: int = spec["tall_n"]
	var rads: Array = spec["rad"]
	var first_h: Array = spec["first"]
	var rest_h: Array = spec["rest"]
	for k in tall_n * 3:
		if crystals.size() >= tall_n:
			break
		var rad := rng.randf_range(rads[0], rads[1])
		rad = minf(rad, depth * 0.45)
		var base: Vector2
		if corner:
			var ox := Vector2(outward.x, 0).normalized()
			var oy := Vector2(0, outward.y).normalized()
			var dx := rng.randf_range(rad, maxf(rad, depth - rad))
			var dy := rng.randf_range(rad, maxf(rad, depth - rad))
			var arm := rng.randf()
			if arm < 0.4:
				base = anchor + ox * dx + oy * dy  # in the corner block
			elif arm < 0.7:
				base = anchor + ox * dx - oy * rng.randf_range(0.0, spread)  # along the side wall
			else:
				base = anchor + oy * dy - ox * rng.randf_range(0.0, spread)  # along the back wall
		else:
			var d := rng.randf_range(rad, maxf(rad, depth - rad))
			base = anchor + outward * d + along * rng.randf_range(-spread, spread)
		if not _base_in_structure(f, base, rad):
			continue
		var first := crystals.is_empty()
		var h := (
			rng.randf_range(first_h[0], first_h[1])
			if first
			else rng.randf_range(rest_h[0], rest_h[1])
		)
		h = minf(h, cap)
		# A front wall's crystals lean away from the room (over the wall), the rest into it.
		var out_lean := front or bool(spec.get("lean_out", false))
		var lean := (outward if out_lean else inward).rotated(rng.randf_range(-0.6, 0.6))
		var tilt := rng.randf_range(0.05, 0.22) if first else rng.randf_range(0.15, 0.45)
		if front:
			tilt *= 0.5
		crystals.append(_crystal(base, rad, h, lean, tilt, rng.randi() % 3, glow, rng))
	if crystals.is_empty():
		return {"crystals": []}
	# Low shards on the floor at the foot, leaning away from the wall; each stays in the room and the foot.
	var low_n: int = spec["low_n"]
	var reach := float(spec["reach"]) * 2.2
	var floor_dir := -outward
	var low := 0
	for k in low_n * 4:
		if low >= low_n:
			break
		var base := (
			anchor
			+ floor_dir * rng.randf_range(0.12, reach)
			+ along * rng.randf_range(-spread, spread)
		)
		if not room.grow(-0.08).has_point(base) or base.distance_to(foot) > foot_r:
			continue
		var h := rng.randf_range(0.18, StageDresser.DECOR_MAX_HEIGHT * 0.92)
		var rad := rng.randf_range(0.05, 0.1)
		var lean := floor_dir.rotated(rng.randf_range(-0.9, 0.9))
		crystals.append(
			_crystal(base, rad, h, lean, rng.randf_range(0.2, 0.5), rng.randi() % 3, glow, rng)
		)
		low += 1
	# Floating fragments above the cluster, over the wall and its foot.
	var frags: Array = []
	var frag_y: Array = spec["frag_y"]
	var frag_n: int = spec["frag_n"]
	for k in frag_n:
		var p := (
			anchor
			+ floor_dir * rng.randf_range(-0.3, 0.6)
			+ along * rng.randf_range(-spread, spread)
		)
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
		light = SimPlane.to_3d(anchor + floor_dir * 0.9, 1.1)
	return {"crystals": crystals, "fragments": frags, "light": light}


## The base disc (centre and four rim points) inside a structural wall, out of every doorway.
static func _base_in_structure(f: Dictionary, base: Vector2, rad: float) -> bool:
	for p in [
		base,
		base + Vector2(rad, 0),
		base - Vector2(rad, 0),
		base + Vector2(0, rad),
		base - Vector2(0, rad)
	]:
		if not _in_structure(f, p):
			return false
	return true


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
