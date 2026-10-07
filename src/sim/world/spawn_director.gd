class_name SpawnDirector
extends RefCounted
## Continuous, controlled spawning in tick phase 9 (PLAN v0.2.0 L6; PD-05 flipped). Run time counts while the
## player lives; every tier_ticks of it is a new tier. While fewer enemies than cap(tier) are alive, one
## arrives every interval(tier) ticks: its kind is a weighted pick (ai stream) among the kinds unlocked at this
## tier, its spot a pick (map stream) among the spawn points at least min_distance_m from the player, and its HP
## is scaled by tier. With no spot far enough, that spawn is skipped and the interval starts again.

## v0.4.0 EN: a pack spreads on a ring this wide around its spawn point (starting value).
const PACK_RING_M := 0.8


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
	if w.spawn_cd > 0 or WaveDirector.enemies_alive(w) >= t.cap(tier):
		return
	w.spawn_cd = t.interval(tier)
	_spawn_one(w, t, tier)


## Spawn points at least min_distance_m from the player, in their stored order. On a floor, only in the player's
## room or a neighbouring one (PLAN v0.2.0 "Spawning"); in a doorway (no room), any room qualifies.
static func far_points(w: World) -> PackedVector2Array:
	var out := PackedVector2Array()
	var p := w.player_pos()
	var near := PackedInt32Array()
	if w.floor_layout != null:
		var room := w.floor_layout.room_of(p)
		if room >= 0:
			near = w.floor_layout.neighbours(room)
			near.append(room)
	for q in w.spawn_points:
		if Kin.length(q - p) < w.spawner.min_distance_m:
			continue
		if not near.is_empty() and not near.has(w.floor_layout.room_of(q)):
			continue
		out.append(q)
	return out


## Indices into the mix that may spawn at this tier (unlocked, with a compiled enemy table).
static func unlocked(w: World, t: SpawnTable, tier: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in t.kinds.size():
		if t.unlock_tiers[k] <= tier and w.enemy_table(t.kinds[k]) != null:
			out.append(k)
	return out


static func _spawn_one(w: World, t: SpawnTable, tier: int) -> void:
	var pts := far_points(w)
	var open := unlocked(w, t, tier)
	if pts.is_empty() or open.is_empty():
		return
	var weights := PackedInt32Array()
	for k in open:
		weights.append(t.weights[k])
	var pick := w.rng_ai.pick_weighted(weights)
	if pick < 0:
		return
	var kind := t.kinds[open[pick]]
	var at := pts[w.rng_map.range_int(0, pts.size() - 1)]
	# v0.4.0 EN: a pack (Swarmers) arrives in a ring around the spot, never past the alive cap.
	var n := 1
	if open[pick] < t.packs.size():
		n = clampi(t.packs[open[pick]], 1, t.cap(tier) - WaveDirector.enemies_alive(w))
	for k in n:
		var off := Kin.dir(k * 4096 / n) * PACK_RING_M if n > 1 else Vector2.ZERO
		w.add_enemy(kind, at + off)
		var i := w.actors.size() - 1
		var hp := t.scaled_hp(w.enemy_table(kind).hp, tier)
		w.actors.hp[i] = hp
		w.actors.max_hp[i] = hp
