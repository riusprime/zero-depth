class_name Arenas
extends RefCounted
## Sealed arenas in play (v0.5.5 AR; PLAN D2, S8, X1 "open floor, sealed arenas"; SIM_CONTRACTS §2 phase 9).
## The floor's arenas are FloorLayout.arena_rooms (ArenaRooms, with an arena table) and the Overrun room (with an
## Overrun table: the hardest arena, OverrunTable's waves and its x1.5 enemies, Overrun).
## - Seal: the tick the player stands in an arena that isn't cleared (FloorLayout.room_of), a barrier joins the walls
##   in each of its doorways (World.add_barrier: collision only, the flow field never sees it), the room's streams are
##   derived (`combat:room:k`, `ai:room:k`), its wave count is drawn from `combat:room:k` and the first wave is due
##   first_wave_ticks later. While sealed the open floor's horde spawning pauses (the floor clock runs on: holds_spawns,
##   count_time), a blink never lands outside the room, and the room's rewards stay locked.
## - Waves: each spawns wave_size(floor) enemies inside the room: kinds weighted as the spawn director's at the curve's
##   current level (SpawnDirector.unlocked; `ai:room:k`), spots among the room's spawn points at least
##   min_spawn_distance_m from the player (shuffled from `combat:room:k`; rings around them when the room has fewer
##   spots), each scaled on arrival like any spawn (SpawnDirector.scale_arrival: tier HP and power, the Overrun's x1.5),
##   and an elite roll under an elite curse. The next wave is due wave_gap_ticks after no enemy is left alive in the
##   room (Splitlings still waiting to arrive count as alive).
## - Clear: after the last wave, the barriers leave the walls, the room joins `cleared` (it stays open), its rewards
##   unlock; the Overrun's clear also leaves its altar and its shard bonus (Overrun.on_clear).
## Saves: the seal is at the first tick in the room, which is the room's entry save (RunSaver), so a resume replays the
## arena from its entry state; the room's streams are derived fresh at each seal.

## A body counts as in the room within this margin of its interior (m): enemies pushed against a barrier from
## inside stay counted, those outside never are.
const ROOM_MARGIN_M := 0.1
## Ring spacing (m) when a wave has more members than the room has spots, and the clearance a ring spot keeps.
const RING_STEP_M := 1.1
const CLEARANCE_M := 0.9


static func enabled(w: World) -> bool:
	return (
		w.floor_layout != null and (not w.floor_layout.arena_rooms.is_empty() or Overrun.enabled(w))
	)


## Whether `room` is an arena on this floor (a regular one, or the Overrun with its table).
static func is_arena(w: World, room: int) -> bool:
	var f := w.floor_layout
	if f == null or room < 0:
		return false
	return f.arena_rooms.has(room) or (room == f.overrun_room and Overrun.enabled(w))


static func is_cleared(w: World, room: int) -> bool:
	return w.arenas.cleared.has(room)


static func sealed(w: World) -> bool:
	return w.arenas.sealed()


## The open floor's spawning waits while an arena is sealed (World.step; the clock runs on with count_time).
static func holds_spawns(w: World) -> bool:
	return w.arenas.sealed()


static func count_time(w: World) -> void:
	if not w.player_dead():
		w.run_ticks += 1


## Tick phase 9, after the deaths: seal, waves, clear.
static func advance(w: World) -> void:
	if not enabled(w) or w.player_dead():
		return
	var s := w.arenas
	var f := w.floor_layout
	if not s.sealed():
		var room := f.room_of(w.player_pos())
		if is_arena(w, room) and not is_cleared(w, room):
			_seal(w, room)
		return
	if s.next_wave_tick >= 0:
		if w.tick >= s.next_wave_tick:
			_spawn_wave(w)
		return
	if alive_in_room(w) > 0 or w.has_pending_enemies():
		return
	if s.wave < s.waves:
		s.next_wave_tick = w.tick + _table(w).wave_gap_ticks
	else:
		_clear(w)


## Living enemies inside the sealed room.
static func alive_in_room(w: World) -> int:
	var s := w.arenas
	if not s.sealed():
		return 0
	var rect := w.floor_layout.rooms[s.room].grow(ROOM_MARGIN_M)
	var n := 0
	for i in range(1, w.actors.size()):
		if w.actors.dead[i] != 0 or w.actors.teams[i] == ActorStore.TEAM_PLAYER:
			continue
		if not EnemyAi.is_enemy_kind(w.actors.kinds[i]):
			continue
		if rect.has_point(w.actors.pos(i)):
			n += 1
	return n


## Whether reward i is locked: it stands in an arena that isn't cleared (Rewards.nearest skips it).
static func locked(w: World, i: int) -> bool:
	if w.floor_layout == null:
		return false
	var room := w.floor_layout.room_of(w.rewards.pos(i))
	return is_arena(w, room) and not is_cleared(w, room)


## Blink (World.blink_may_land): while sealed, only within the sealed room.
static func blink_may_land(w: World, at: Vector2) -> bool:
	var s := w.arenas
	return not s.sealed() or w.floor_layout.rooms[s.room].has_point(at)


static func _table(w: World) -> ArenaTable:
	return w.arena_table if w.arena_table != null else ArenaTable.new()


static func _is_overrun(w: World, room: int) -> bool:
	return room == w.floor_layout.overrun_room and Overrun.enabled(w)


static func _seal(w: World, room: int) -> void:
	var s := w.arenas
	var f := w.floor_layout
	var t := _table(w)
	s.room = room
	s.sealed_tick = w.tick
	s.wave = 0
	s.spawned = 0
	s.rng_combat = RngStream.derive(w.seed_value, "combat:room:%d" % room)
	s.rng_ai = RngStream.derive(w.seed_value, "ai:room:%d" % room)
	var lo := t.waves_min
	var hi := t.waves_max
	if _is_overrun(w, room):
		lo = w.overrun_table.waves_min
		hi = w.overrun_table.waves_max
	s.waves = s.rng_combat.range_int(mini(lo, hi), maxi(lo, hi))
	s.next_wave_tick = w.tick + t.first_wave_ticks
	s.barriers.clear()
	for d in ArenaRooms.doors_of(f, room):
		var o := ArenaRooms.barrier(f, d)
		s.barriers.append(o)
		w.add_barrier(o)
	if _is_overrun(w, room):
		Overrun.on_seal(w)


static func wave_size(w: World) -> int:
	var s := w.arenas
	if s.sealed() and _is_overrun(w, s.room):
		return ArenaTable.size_on(w.overrun_table.wave_sizes, w.floor_index)
	return ArenaTable.size_on(_table(w).wave_sizes, w.floor_index)


static func _spawn_wave(w: World) -> void:
	var s := w.arenas
	s.wave += 1
	s.next_wave_tick = -1
	if w.spawner == null:
		return
	var ticks := w.run_ticks  # the floor time so far: the curve's level now
	var open := SpawnDirector.unlocked(w, w.spawner, ticks)
	if open.is_empty():
		return
	var weights := PackedInt32Array()
	for k in open:
		weights.append(w.spawner.weights[k])
	var spots := wave_spots(w, wave_size(w))
	for q in spots:
		var pick := Offers.pick(s.rng_ai, weights)
		if pick < 0:
			break
		w.add_enemy(w.spawner.kinds[open[pick]], q)
		var i := w.actors.size() - 1
		SpawnDirector.scale_arrival(w, i, ticks)
		Curses.maybe_elite(w, i)
		s.spawned += 1


## `count` spots in the sealed room: its spawn points (those at least min_spawn_distance_m from the player, or all
## when none is), shuffled from `combat:room:k`; past their number, rings of 6 around them, each clear of walls and in
## the room, else the spot itself (collision spreads them).
static func wave_spots(w: World, count: int) -> PackedVector2Array:
	var s := w.arenas
	var f := w.floor_layout
	var pts := PackedVector2Array()
	var all: PackedVector2Array = (
		f.spawn_points[s.room] if s.room < f.spawn_points.size() else PackedVector2Array()
	)
	var p := w.player_pos()
	for q in all:
		if Kin.length(q - p) >= _table(w).min_spawn_distance_m:
			pts.append(q)
	if pts.is_empty():
		pts = all.duplicate()
	if pts.is_empty():
		pts.append(f.rooms[s.room].get_center())
	for k in pts.size():
		var j := s.rng_combat.range_int(k, pts.size() - 1)
		var t := pts[k]
		pts[k] = pts[j]
		pts[j] = t
	var out := PackedVector2Array()
	var n := pts.size()
	for m in count:
		var anchor := pts[m % n]
		var q := anchor
		if m >= n:
			var ring := (m - n) / (n * 6) + 1
			var slot := ((m - n) / n) % 6
			var cand := anchor + Kin.dir(slot * 4096 / 6 + ring * 256) * (RING_STEP_M * ring)
			if f.room_of(cand) == s.room and _open_spot(w, cand):
				q = cand
		out.append(q)
	return out


static func _open_spot(w: World, q: Vector2) -> bool:
	var r := CLEARANCE_M
	for k in w.walls_near(Rect2(q.x - r, q.y - r, r * 2.0, r * 2.0)):
		if Collide.circle_vs_obb(q, r, w.walls[k]) != Vector2.ZERO:
			return false
	return true


static func _clear(w: World) -> void:
	var s := w.arenas
	var room := s.room
	for o in s.barriers:
		w.remove_barrier(o)
	s.barriers.clear()
	s.cleared.append(room)
	s.clear_tick = w.tick
	s.room = -1
	s.next_wave_tick = -1
	s.rng_combat = null
	s.rng_ai = null
	if _is_overrun(w, room):
		Overrun.on_clear(w)


## What the HUD, minimap, door views and the shroud read (WorldReader.arenas).
static func read(w: World) -> Dictionary:
	var s := w.arenas
	var f := w.floor_layout
	var rooms := PackedInt32Array()
	if f != null:
		rooms = f.arena_rooms.duplicate()
		if Overrun.enabled(w):
			rooms.append(f.overrun_room)
	return {
		"active": enabled(w),
		"rooms": rooms,
		"overrun": f.overrun_room if f != null and Overrun.enabled(w) else -1,
		"cleared": s.cleared.duplicate(),
		"sealed": s.room,
		"overrun_sealed": s.sealed() and _is_overrun(w, s.room),
		"wave": s.wave,
		"waves": s.waves,
		"alive": alive_in_room(w),
		"next_wave_tick": s.next_wave_tick,
		"sealed_tick": s.sealed_tick,
		"clear_tick": s.clear_tick,
		"last_cleared": s.cleared[s.cleared.size() - 1] if not s.cleared.is_empty() else -1,
	}
