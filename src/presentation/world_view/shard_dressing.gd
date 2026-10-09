class_name ShardDressing
extends RefCounted
## Where the crystal-shard clusters go on a floor (v0.6.1 Step SD, owner R4: "we could also add to the generation
## map or the initial room the shard looks"). A pure function like StageDresser: the floor's geometry in, the
## clusters' crystals out, the same for the same seed. Its draws come from its own cosmetic stream (a
## RandomNumberGenerator seeded from the floor seed, offset from the dresser's and the props'), never from or into
## the sim (EI-05). Presentation only: no cluster has collision, so none may look like it needs it.
##
## Rules (starting values, tuned on screenshots):
## 1. Looks solid = is solid (StageDresser rule 1). A crystal taller than StageDresser.DECOR_MAX_HEIGHT grows out
##    of a structural wall: its base sits inside the wall's footprint. On open floor only low shards (no taller than
##    the decoration limit) spill from the cluster's foot, and floating fragments hover above head height.
## 2. Clusters hug the room's back walls (the -X and +Y sides, which face the iso camera and are never faded by
##    occlusion), mostly at the back corner, so they never hide the floor or stand in front of a fight.
## 3. Spacing (v0.5.9 "everything touches a wall or leaves a 2.2 m gap"): every cluster touches its wall; its foot
##    keeps SLAB_GAP from every cover piece and CLUSTER_SPACING from other clusters; DOOR_CLEAR from doorways and
##    arena barriers; KEEP_CLEAR from rewards, gates, the shop, the shrine, events and light props; SPAWN_CLEAR from
##    enemy spawn spots; START_CLEAR from the hero's start.
## 4. Density by the room's theme: Ruined hall and Overgrown 0-3, Camp 0-1, any other room 0-2. The start room
##    gets the hero cluster (bigger, at its back corner, with a small cold light) and no small ones. Boss arenas
##    get none.

## The v0.5.9 slab gap (the floor generator's gap between groups; the vignettes' spacing).
const SLAB_GAP := 2.2
const CLUSTER_SPACING := 3.0
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
const ATTEMPTS := 14
const HERO_ATTEMPTS := 30
## How far around a room anything can still matter to its clusters (the widest clearance plus the deepest wall).
const NEAR := 5.0
## Density weights per theme (index = clusters in the room).
const WEIGHTS_RICH: Array[float] = [0.1, 0.35, 0.35, 0.2]
const WEIGHTS_CAMP: Array[float] = [0.6, 0.4]
const WEIGHTS_PLAIN: Array[float] = [0.35, 0.45, 0.2]
## Floating fragments hover at least this high (above the hero's head).
const FRAGMENT_MIN_Y := 1.1


## Places the clusters. `f` keys:
## - "walls": [[center: Vector2, half: Vector2, yaw: float, kind: int, ...]] (StageDresser's input: kind 0
##   structural, 1 cover);
## - "rooms": [Rect2]; "themes": [StringName] (each room's theme, WorldReader.floor_room_theme); "start_room": int;
##   "boss_room": int;
## - "doors": [Rect2] (doorways and arena barriers); "keep_clear": [Vector2]; "spawns": [Vector2];
##   "start": Vector2; "seed": int.
## Returns [{"room": int, "hero": bool, "foot": Vector2 (the foot's centre), "radius": float, "inward": Vector2,
## "crystals": [{"xform": Transform3D (scales the unit crystal), "base": Vector2, "radius": float,
## "height": float, "tall": bool, "variant": int}], "fragments": [Transform3D], "light": Vector3 (the hero's only;
## Vector3.INF for none)}].
static func place(f: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f.get("seed", 0)) * 7919 + 9241  # the cosmetic stream: presentation only
	var out: Array = []
	var rooms: Array = f.get("rooms", [])
	var themes: Array = f.get("themes", [])
	var start := int(f.get("start_room", -1))
	var boss := int(f.get("boss_room", -1))
	for r in rooms.size():
		if r == boss:
			continue
		var near := _local(f, rooms[r])
		if r == start:
			var hero := _try_cluster(near, r, true, out, rng)
			if not hero.is_empty():
				out.append(hero)
			continue
		var t := StringName(themes[r]) if r < themes.size() else &""
		var want := _weighted(rng, _weights(t))
		for k in want:
			var c := _try_cluster(near, r, false, out, rng)
			if not c.is_empty():
				out.append(c)
	return out


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


static func _weights(theme: StringName) -> Array[float]:
	match theme:
		&"ruined_hall", &"overgrown":
			return WEIGHTS_RICH
		&"camp":
			return WEIGHTS_CAMP
	return WEIGHTS_PLAIN


## A cluster in room r on a back wall, or {} when no spot passes the rules within ATTEMPTS.
static func _try_cluster(
	f: Dictionary, r: int, hero: bool, placed: Array, rng: RandomNumberGenerator
) -> Dictionary:
	var room: Rect2 = f["rooms"][r]
	var foot_r := HERO_FOOT if hero else SMALL_FOOT
	var reach := HERO_REACH if hero else SMALL_REACH
	var spread := HERO_SPREAD if hero else SMALL_SPREAD
	var corner := Vector2(room.position.x, room.end.y)
	for attempt in HERO_ATTEMPTS if hero else ATTEMPTS:
		# The back corner first (the hero's first try), else a stretch of a back wall.
		var at_corner := (hero and attempt == 0) or (not hero and rng.randf() < 0.35)
		var anchor: Vector2
		var outward: Vector2
		var along: Vector2
		if at_corner:
			anchor = corner
			outward = Vector2(-1, 1).normalized()
			along = Vector2(1, 1).normalized()
		else:
			var left := rng.randf() < room.size.y / (room.size.x + room.size.y)
			var lo := spread + 0.3
			if left:
				var hi := room.size.y - lo
				if hi <= lo:
					continue
				anchor = Vector2(room.position.x, room.position.y + rng.randf_range(lo, hi))
				outward = Vector2(-1, 0)
				along = Vector2(0, 1)
			else:
				var hi := room.size.x - lo
				if hi <= lo:
					continue
				anchor = Vector2(room.position.x + rng.randf_range(lo, hi), room.end.y)
				outward = Vector2(0, 1)
				along = Vector2(1, 0)
		var inward := -outward
		var foot := anchor + inward * (reach * (1.4 if at_corner else 1.0))
		if not _clear(f, room, foot, foot_r, placed):
			continue
		var depth := _wall_depth(f, anchor, outward, along, spread, at_corner)
		if depth <= 0.0:
			continue
		var c := _grow(f, [anchor, outward, along, foot, foot_r, room], depth, at_corner, hero, rng)
		if c["crystals"].is_empty():
			continue
		c["room"] = r
		c["hero"] = hero
		c["foot"] = foot
		c["radius"] = foot_r
		c["inward"] = inward
		return c
	return {}


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
		if p.distance_to(c["foot"]) < CLUSTER_SPACING + rad + float(c["radius"]):
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
## `frame`: [anchor, outward, along, foot centre, foot radius, room].
static func _grow(
	f: Dictionary, frame: Array, depth: float, corner: bool, hero: bool, rng: RandomNumberGenerator
) -> Dictionary:
	var anchor: Vector2 = frame[0]
	var outward: Vector2 = frame[1]
	var along: Vector2 = frame[2]
	var foot: Vector2 = frame[3]
	var foot_r: float = frame[4]
	var room: Rect2 = frame[5]
	var crystals: Array = []
	var inward := -outward
	var spread := HERO_SPREAD if hero else SMALL_SPREAD
	var tall_n := rng.randi_range(6, 8) if hero else rng.randi_range(3, 4)
	for k in tall_n * 3:
		if crystals.size() >= tall_n:
			break
		var rad := rng.randf_range(0.12, 0.2) if hero else rng.randf_range(0.11, 0.17)
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
		var h: float
		if hero:
			h = rng.randf_range(1.6, 2.2) if first else rng.randf_range(0.8, 1.5)
		else:
			h = rng.randf_range(1.3, 1.7) if first else rng.randf_range(0.9, 1.35)
		var lean := inward.rotated(rng.randf_range(-0.6, 0.6))
		var tilt := rng.randf_range(0.05, 0.22) if first else rng.randf_range(0.15, 0.45)
		crystals.append(_crystal(base, rad, h, lean, tilt, rng.randi() % 3, rng))
	if crystals.is_empty():
		return {"crystals": []}
	# Low shards on the floor at the foot, leaning away from the wall; each stays in the room and the foot.
	var low_n := rng.randi_range(6, 8) if hero else rng.randi_range(3, 4)
	var reach := (HERO_REACH if hero else SMALL_REACH) * 2.2
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
			_crystal(base, rad, h, lean, rng.randf_range(0.2, 0.5), rng.randi() % 3, rng)
		)
		low += 1
	# Floating fragments above the cluster, over the wall and its foot.
	var frags: Array = []
	var frag_n := rng.randi_range(4, 5) if hero else rng.randi_range(2, 3)
	for k in frag_n:
		var p := (
			anchor
			+ floor_dir * rng.randf_range(-0.3, 0.6)
			+ along * rng.randf_range(-spread, spread)
		)
		var y := rng.randf_range(FRAGMENT_MIN_Y + 0.2, 1.9) if hero else rng.randf_range(1.15, 1.6)
		var s := rng.randf_range(0.05, 0.09)
		var basis := (
			Basis(Vector3.UP, rng.randf() * TAU)
			* Basis(Vector3.RIGHT, rng.randf_range(-0.5, 0.5))
			* Basis.from_scale(Vector3(s, s * 3.4, s))
		)
		frags.append(Transform3D(basis, SimPlane.to_3d(p, y)))
	var light := Vector3.INF
	if hero:
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
## toward `lean` (a sim-plane direction), turned at random about its own axis.
static func _crystal(
	base: Vector2,
	rad: float,
	h: float,
	lean: Vector2,
	tilt: float,
	variant: int,
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


static func _weighted(rng: RandomNumberGenerator, weights: Array[float]) -> int:
	var x := rng.randf()
	for k in weights.size():
		x -= weights[k]
		if x < 0.0:
			return k
	return weights.size() - 1
