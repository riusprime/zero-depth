class_name SpawnDirector
extends RefCounted
## Continuous, controlled spawning in tick phase 9 (PLAN v0.2.0 L6; PD-05 flipped; hordes v0.4.0 SC, F7/F10). Run
## time counts while the player lives; every tier_ticks of it is a new danger tier. While fewer enemies than
## cap(floor, tier) are alive, a pack arrives every interval(tier) ticks:
## - its kind is a weighted pick (ai stream) among the kinds unlocked at this tier;
## - its anchor a pick (map stream) among the spawn points at least min_distance_m from the player, in the player's
##   room or a neighbouring one (never the boss room), preferring those within edge_band_m of their room's walls;
## - its size the kind's fixed pack (SpawnMixEntry.pack > 0: a Swarmer pack of 8), or a draw (map stream) from
##   the floor's range, never past the cap;
## - its members stand on a ring around the anchor (anchor first, then 6 spots at PACK_STEP_M, then 12 at twice
##   that), each in the anchor's room, clear of walls and at least min_distance_m from the player;
## - each arrives with its max HP and damage scaled by the tier (SpawnTable; the floor scaling is already in the
##   compiled enemy tables, RunState.scale_enemies).
## With no anchor far enough, that pack is skipped and the interval starts again.

## Distance between the rings of a pack's spots, and their count per ring.
const PACK_STEP_M := 1.1
const RING_SPOTS: Array[int] = [1, 6, 12]
## Clearance a pack spot keeps from every wall (as FloorParams.spawn_clearance).
const PACK_CLEARANCE_M := 0.9


static func advance(w: World) -> void:
	var t := w.spawner
	if t == null or w.player_dead():
		return
	var tier := t.tier_at(w.run_ticks)
	if w.run_ticks == 0:
		w.spawn_cd = t.interval(tier)
	w.run_ticks += 1
	if w.spawn_cd > 0:
		w.spawn_cd -= 1
	if w.spawn_cd > 0:
		return
	var room := t.cap(w.floor_index, tier) - WaveDirector.enemies_alive(w)
	if room <= 0:
		return
	w.spawn_cd = t.interval(tier)
	_spawn_pack(w, t, tier, room)


## Spawn points at least min_distance_m from the player, in their stored order. On a floor, only in the player's
## room or a neighbouring one (PLAN v0.2.0 "Spawning"), never the boss room; in a doorway (no room), any room
## qualifies.
static func far_points(w: World) -> PackedVector2Array:
	var out := PackedVector2Array()
	var p := w.player_pos()
	var near := PackedInt32Array()
	var boss_room := -1
	if w.floor_layout != null:
		boss_room = w.floor_layout.boss_room
		var room := w.floor_layout.room_of(p)
		if room >= 0:
			near = w.floor_layout.neighbours(room)
			near.append(room)
	for q in w.spawn_points:
		if Kin.length(q - p) < w.spawner.min_distance_m:
			continue
		if w.floor_layout != null:
			var qr := w.floor_layout.room_of(q)
			if qr == boss_room or (not near.is_empty() and not near.has(qr)):
				continue
		out.append(q)
	return out


## The far points within edge_band_m of their room's walls (all of them off a floor), or every far point when none
## is that close to an edge.
static func anchor_points(w: World) -> PackedVector2Array:
	var far := far_points(w)
	if w.floor_layout == null:
		return far
	var edge := PackedVector2Array()
	for q in far:
		var r := w.floor_layout.room_of(q)
		if r < 0:
			continue
		var rect := w.floor_layout.rooms[r]
		var to_edge := minf(
			minf(q.x - rect.position.x, rect.end.x - q.x),
			minf(q.y - rect.position.y, rect.end.y - q.y)
		)
		if to_edge <= w.spawner.edge_band_m:
			edge.append(q)
	return edge if not edge.is_empty() else far


## Indices into the mix that may spawn at this tier (unlocked, with a compiled enemy table).
static func unlocked(w: World, t: SpawnTable, tier: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in t.kinds.size():
		if t.unlock_tiers[k] <= tier and w.enemy_table(t.kinds[k]) != null:
			out.append(k)
	return out


## Up to `count` spots for a pack around `anchor`, in ring order (the anchor first): each in the anchor's room (on a
## floor), clear of walls by PACK_CLEARANCE_M and at least min_distance_m from the player.
static func pack_spots(w: World, anchor: Vector2, count: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var p := w.player_pos()
	var home := w.floor_layout.room_of(anchor) if w.floor_layout != null else -1
	for ring in RING_SPOTS.size():
		var n: int = RING_SPOTS[ring]
		for k in n:
			if out.size() >= count:
				return out
			var q := anchor
			if ring > 0:
				q = anchor + Kin.dir(k * 4096 / n + ring * 256) * (PACK_STEP_M * ring)
			if Kin.length(q - p) < w.spawner.min_distance_m:
				continue
			if home >= 0 and w.floor_layout.room_of(q) != home:
				continue
			if not _clear(w, q):
				continue
			out.append(q)
	return out


static func _clear(w: World, q: Vector2) -> bool:
	var r := PACK_CLEARANCE_M
	for k in w.walls_near(Rect2(q.x - r, q.y - r, r * 2.0, r * 2.0)):
		if Collide.circle_vs_obb(q, r, w.walls[k]) != Vector2.ZERO:
			return false
	return true


static func _spawn_pack(w: World, t: SpawnTable, tier: int, room: int) -> void:
	var pts := anchor_points(w)
	var open := unlocked(w, t, tier)
	if pts.is_empty() or open.is_empty():
		return
	var weights := PackedInt32Array()
	for k in open:
		weights.append(t.weights[k])
	var pick := w.rng_ai.pick_weighted(weights)
	if pick < 0:
		return
	var entry := open[pick]
	var kind := t.kinds[entry]
	var anchor := pts[w.rng_map.range_int(0, pts.size() - 1)]
	var size := t.packs[entry] if entry < t.packs.size() else 0
	if size <= 0:
		size = w.rng_map.range_int(t.pack_min(w.floor_index), t.pack_max(w.floor_index))
	var hp := t.scaled_hp(w.enemy_table(kind).hp, tier)
	var power := t.damage_permille(tier)
	for q in pack_spots(w, anchor, mini(size, room)):
		w.add_enemy(kind, q)
		var i := w.actors.size() - 1
		w.actors.hp[i] = hp
		w.actors.max_hp[i] = hp
		w.actors.power[i] = power
