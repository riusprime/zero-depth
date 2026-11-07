class_name Surges
extends RefCounted
## v0.11.0 O9 (PLAN H1, M4; ENEMIES.md H1-H5; owner Q15: "Surges but not during an overrun or lockdown": once or twice a
## floor, 30-60 over 10 s with a sound; Q16: the alive cap is the performance gate): the horde surges. On a floor whose
## biome has a critter (World.critter_kind, set by FloorPlan) and whose spawner has the numbers (SpawnTable.surge):
## - the plan: on the first tick ordinary spawning runs, surges_min..surges_max surges are drawn from the `ai:surge`
##   stream (derived from the world's seed, so no other stream moves): the first begins first_min..first_max ticks of
##   floor time in, each next one gap_min..gap_max ticks after the last one's window; each one's size is drawn from
##   size_min..size_max (World.surge_at, surge_sizes);
## - its start: once the floor time reaches it and the hero is not held (held()), a SURGE event (amount: its size) is
##   the cue for its sound and its HUD line; a surge due while held waits;
## - its window: over duration_ticks (counted only while not held, so a Lockdown or an Overrun pauses it) its members
##   arrive evenly, each a critter at a spot around an anchor the ordinary spawner would take (SpawnDirector:
##   anchor_points, pack_spots: min_distance_m from the hero, near its room's edges, never the boss room), but never in
##   an Overrun room, an arena or a Lockdown room; each member's anchor and spot are drawn from its own stream,
##   `ai:surge:<surge>:<member>`. While enemies alive reach alive_cap (above the floor's normal cap, never above the
##   spawner's hard cap_max) a member waits; members still missing when the window ends are dropped (never forced);
## - each arrives scaled like any spawn (SpawnDirector.scale_arrival).
## Runs inside SpawnDirector.advance (tick phase 9), so never in a sealed arena or Lockdown, nor in the boss fight; the
## intensity director does not gate it (a surge is the floor's event, not a pack).

const STREAM := "ai:surge"
## The spots a member may take around its anchor (the anchor and the first ring: SpawnDirector.RING_SPOTS).
const MEMBER_SPOTS := 7


static func table(w: World) -> SurgeTable:
	return w.spawner.surge if w.spawner != null else null


## Whether this floor has surges (the numbers, and a biome critter with its table).
static func enabled(w: World) -> bool:
	return table(w) != null and w.critter_kind >= 0 and w.enemy_table(w.critter_kind) != null


## True while a surge is running (its window open).
static func running(w: World) -> bool:
	return w.surge_t >= 0


## Surges begun on this floor (the HUD's line counts them).
static func started(w: World) -> int:
	return w.surge_next + (1 if running(w) else 0)


## SpawnDirector.advance, every tick ordinary spawning runs (after the floor clock counted).
static func advance(w: World) -> void:
	if not enabled(w):
		return
	var t := table(w)
	if w.surge_at.is_empty():
		plan(w, t)
	if not running(w):
		if w.surge_next >= w.surge_at.size() or w.run_ticks < w.surge_at[w.surge_next]:
			return
		if held(w):
			return
		w.surge_t = 0
		w.surge_spawned = 0
		var e := w.emit_event(SimEvent.Kind.SURGE, 0, 0, 0, w.player_pos())
		e.amount = w.surge_sizes[w.surge_next]
	elif held(w):
		return
	else:
		w.surge_t += 1
	var size := w.surge_sizes[w.surge_next]
	var due := mini(size, size * (w.surge_t + 1) / t.duration_ticks)
	var cap := mini(t.alive_cap, w.spawner.cap_max)
	while w.surge_spawned < due and WaveDirector.enemies_alive(w) < cap:
		if not _spawn_member(w, w.surge_next, w.surge_spawned):
			break
		w.surge_spawned += 1
	if w.surge_t >= t.duration_ticks - 1:
		w.surge_t = -1
		w.surge_next += 1


## The floor's surges (World.surge_at in floor ticks, surge_sizes), from the `ai:surge` stream.
static func plan(w: World, t: SurgeTable) -> void:
	var rng := RngStream.derive(w.seed_value, STREAM)
	var n := rng.range_int(t.surges_min, t.surges_max)
	var at := rng.range_int(t.first_min_ticks, t.first_max_ticks)
	w.surge_at = PackedInt32Array()
	w.surge_sizes = PackedInt32Array()
	for k in n:
		w.surge_at.append(at)
		w.surge_sizes.append(rng.range_int(t.size_min, t.size_max))
		at += t.duration_ticks + rng.range_int(t.gap_min_ticks, t.gap_max_ticks)
	if n == 0:
		w.surge_at.append(-1)  # planned: none (never reached: surge_next stops at the size)
		w.surge_sizes.append(0)
		w.surge_next = 1


## Whether a surge must wait (or pause): the hero in an Overrun room, an arena, a Lockdown room or the boss room
## (sealed or not), the Overrun or a Lockdown sealed, or the calm antechamber (SpawnDirector).
static func held(w: World) -> bool:
	if w.overrun.inside or Arenas.holds_spawns(w) or Lockdowns.holds_spawns(w):
		return true
	if SpawnDirector.calm_antechamber(w, w.spawner):
		return true
	var f := w.floor_layout
	return f != null and barred_room(f, f.room_of(w.player_pos()))


## A room no surge enters (nor sends from): the Overrun room, an arena, a Lockdown room, the boss room.
static func barred_room(f: FloorLayout, r: int) -> bool:
	return (
		r >= 0
		and (
			r == f.overrun_room
			or r == f.boss_room
			or f.arena_rooms.has(r)
			or f.lockdown_rooms.has(r)
		)
	)


## Member `n` of surge `k` arrives (false when no anchor or spot is free now; it tries again next tick).
static func _spawn_member(w: World, k: int, n: int) -> bool:
	var pts := PackedVector2Array()
	for q in SpawnDirector.anchor_points(w):
		if w.floor_layout == null or not barred_room(w.floor_layout, w.floor_layout.room_of(q)):
			pts.append(q)
	if pts.is_empty():
		return false
	var rng := RngStream.derive(w.seed_value, "%s:%d:%d" % [STREAM, k, n])
	var spots := SpawnDirector.pack_spots(w, pts[rng.range_int(0, pts.size() - 1)], MEMBER_SPOTS)
	if spots.is_empty():
		return false
	w.add_enemy(w.critter_kind, spots[rng.range_int(0, spots.size() - 1)])
	SpawnDirector.scale_arrival(w, w.actors.size() - 1, w.run_ticks - 1)
	return true
