class_name Lockdowns
extends RefCounted
## v0.9.0 LK (owner Q21: "a new room type"; "1-2 a floor, short"; W20-W26; SIM_CONTRACTS §2 phase 9): the floor's
## Lockdowns in play. Today's Arenas (Arenas) stay as they were, the longer wave fights; a Lockdown is one short
## contained encounter. World.lockdown holds the state (LockdownState; null on a floor without any); the rooms and
## kinds are FloorLayout.lockdown_* (LockdownRooms.mark, at setup).
## - Seal: the tick the hero stands inside a Lockdown room that isn't open yet, bars stand in each of its doorways
##   (World.add_barrier, as an arena's: collision, shots and sight, never the flow field), the room's stream
##   `combat:lockdown:k` is derived, its first formation drawn, and the first formation is due first_wave_ticks later.
##   While sealed the open floor's horde waits (the clock runs on), a blink never lands outside the room.
## - The encounter: `waves` formations of size_on(floor) enemies each, kinds weighted as the spawn director's at the
##   curve's level now (SpawnDirector.unlocked), scaled on arrival like any spawn. A formation is a set shape round the
##   room's middle, turned to face the hero (Formation: a ring, a line across the far side, a pincer from both flanks,
##   a wedge); a spot off the floor or against a wall falls back to the room's nearest spawn point. The next formation
##   (the next shape) is due wave_gap_ticks after no fighter is left: an encounter enemy alive anywhere, or any enemy
##   alive in the room (Splitlings still waiting to arrive count too).
## - The stuck-enemy safety (W26): a fighter outside the room, or on a cell the flow field doesn't reach, for
##   stuck_ticks in a row (3 s) is pulled back to the room's spawn point nearest its middle (clear of the hero). And
##   cap_ticks (90 s) after the seal the exits open whatever is left (`forced`).
## - Hazard Lockdowns: every hazard_every_ticks a strike is marked on the ground where the hero stands (the warning,
##   hazard_warn_ticks long, at least the telegraph minimum); it lands on its tick and hurts the hero within
##   hazard_radius_m (HAZARD_EFFECT; the recap's KILL_CAUSE). The look is the biome's (cables, rocks, vents, ice,
##   stars: the views); the mechanic is shared.
## - Open: on the clear (or the cap) the bars leave the walls, the room joins `cleared` (it stays open) and a free
##   altar stands at its spawn point nearest the middle (the reward).
## Saves: the seal is at the first tick in the room, the room's entry save (RunSaver), so a resume replays the
## Lockdown from its seal; its stream is derived fresh at each seal. Pure sim code.

enum Formation { RING, LINE, PINCER, WEDGE }

## A body counts as in the room within this margin of its interior (m), as Arenas'.
const ROOM_MARGIN_M := 0.1
## A formation spot keeps this clear of walls and this far from the hero (m); its members stand this far apart.
const CLEARANCE_M := 0.8
const MIN_HERO_M := 2.5
const STEP_M := 1.3
## The ring's radius: this share of the room's smaller half-extent, within RADIUS_MIN_M..RADIUS_MAX_M.
const RADIUS_SHARE := 0.6
const RADIUS_MIN_M := 1.6
const RADIUS_MAX_M := 4.5
const STREAM := "combat:lockdown:%d"
const HAZARD_EFFECT := &"lockdown_hazard"
## World.killer_attack when a hazard strike killed the hero (no actor's attack; below Breakables.KILL_CAUSE).
const KILL_CAUSE := -7002
const CAUSE_KEY := &"CAUSE_LOCKDOWN_HAZARD"


## Sets up `w`'s Lockdowns (FloorPlan.add_secrets, last: after the purple-rune room): marks the layout for floor
## `floor_index` and drops the rooms' horde spawn points (a Lockdown room holds only its encounter). No-op without a
## table or a room that fits.
static func setup(w: World, t: LockdownTable, floor_index: int) -> void:
	var f := w.floor_layout
	if f == null or t == null:
		return
	if LockdownRooms.mark(f, t, floor_index, taken_rooms(w)).is_empty():
		return
	var s := LockdownState.new()
	s.table = t
	w.lockdown = s
	for r in f.lockdown_rooms:
		Secrets.drop_spawns(w, r)


## The rooms already holding an event's pedestal or the gamble shrine.
static func taken_rooms(w: World) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in w.ev.ids.size():
		out.append(w.ev.room[k])
	if w.gamble_id >= 0:
		out.append(w.floor_layout.room_of(w.gamble_pos))
	return out


static func is_open(w: World, room: int) -> bool:
	return w.lockdown != null and w.lockdown.cleared.has(room)


## The open floor's spawning waits while a Lockdown is sealed (World.step; the clock runs on).
static func holds_spawns(w: World) -> bool:
	return w.lockdown != null and w.lockdown.sealed()


## Blink (World.blink_may_land): while sealed, only within the sealed room.
static func blink_may_land(w: World, at: Vector2) -> bool:
	var s := w.lockdown
	return s == null or not s.sealed() or w.floor_layout.rooms[s.room].has_point(at)


## Tick phase 9, after the deaths (after Arenas): the seal, the cap, the hazard, the safety, the formations, the clear.
static func advance(w: World) -> void:
	var s := w.lockdown
	if s == null or w.player_dead():
		return
	var f := w.floor_layout
	if not s.sealed():
		var room := f.room_of(w.player_pos())
		if room >= 0 and f.lockdown_rooms.has(room) and not s.cleared.has(room):
			_seal(w, room)
		return
	if w.tick - s.sealed_tick >= s.table.cap_ticks:
		_open(w, true)
		return
	if s.kind == LockdownTable.Kind.HAZARD:
		_hazard(w)
	_unstick(w)
	if s.next_wave_tick >= 0:
		if w.tick >= s.next_wave_tick:
			_spawn_wave(w)
		return
	if fighters(w).size() > 0 or w.has_pending_enemies():
		return
	if s.wave < s.waves:
		s.next_wave_tick = w.tick + s.table.wave_gap_ticks
	else:
		_open(w, false)


static func _seal(w: World, room: int) -> void:
	var s := w.lockdown
	var t := s.table
	s.room = room
	s.kind = LockdownRooms.kind_of(w.floor_layout, room)
	s.sealed_tick = w.tick
	s.wave = 0
	s.waves = maxi(1, t.waves)
	s.members = PackedInt32Array()
	s.stuck_ids = PackedInt32Array()
	s.stuck_ticks = PackedInt32Array()
	s.rng = RngStream.derive(w.seed_value, STREAM % room)
	s.formation = s.rng.range_int(0, Formation.size() - 1)
	s.next_wave_tick = w.tick + t.first_wave_ticks
	s.strike_pos = PackedVector2Array()
	s.strike_tick = PackedInt32Array()
	s.next_strike_tick = (
		w.tick + t.first_wave_ticks + t.hazard_every_ticks / 2
		if s.kind == LockdownTable.Kind.HAZARD
		else -1
	)
	s.barriers.clear()
	for d in ArenaRooms.doors_of(w.floor_layout, room):
		var o := ArenaRooms.barrier(w.floor_layout, d)
		s.barriers.append(o)
		w.add_barrier(o)


static func _spawn_wave(w: World) -> void:
	var s := w.lockdown
	s.wave += 1
	s.next_wave_tick = -1
	if w.spawner == null:
		return
	var ticks := w.run_ticks
	var open := SpawnDirector.unlocked(w, w.spawner, ticks)
	if open.is_empty():
		return
	var weights := PackedInt32Array()
	for k in open:
		weights.append(w.spawner.weights[k])
	var shape := (s.formation + s.wave - 1) % Formation.size()
	for q in formation_spots(w, shape, s.table.size_on(w.floor_index)):
		var pick := Offers.pick(s.rng, weights)
		if pick < 0:
			break
		var id := w.add_enemy(w.spawner.kinds[open[pick]], q)
		SpawnDirector.scale_arrival(w, w.actors.size() - 1, ticks)
		s.members.append(id)


## `count` spots of formation `shape` in the sealed room, turned to face the hero (the room's middle `c`, the way from
## the hero to it `away`, the ring's radius `r`); each off the floor, against a wall or near the hero falls back to the
## room's spawn point nearest it.
static func formation_spots(w: World, shape: int, count: int) -> PackedVector2Array:
	var s := w.lockdown
	var rect := w.floor_layout.rooms[s.room]
	var c := rect.get_center()
	var r := clampf(minf(rect.size.x, rect.size.y) * 0.5 * RADIUS_SHARE, RADIUS_MIN_M, RADIUS_MAX_M)
	var away := Kin.angle_of(c - w.player_pos())
	var out := PackedVector2Array()
	for k in count:
		var q := c
		match shape:
			Formation.RING:
				q = c + Kin.dir(away + k * 4096 / maxi(1, count)) * r
			Formation.LINE:
				q = (
					c
					+ Kin.dir(away) * (r * 0.7)
					+ Kin.dir(away + 1024) * (_offset(k, count) * STEP_M)
				)
			Formation.PINCER:
				var side := 1.0 if k % 2 == 0 else -1.0
				q = c + Kin.dir(away + 1024) * (r * side) + Kin.dir(away) * ((k / 2) * STEP_M * 0.8)
			_:  # WEDGE: a V opening away from the hero, its tip at the middle
				var row := (k + 1) / 2
				var side := 0.0 if k == 0 else (1.0 if k % 2 == 1 else -1.0)
				q = (
					c
					+ Kin.dir(away) * (row * STEP_M * 0.8)
					+ Kin.dir(away + 1024) * (side * row * STEP_M)
				)
		out.append(_fit(w, q))
	return out


## Member k's place along a line of `count` (centred).
static func _offset(k: int, count: int) -> float:
	return float(k) - float(count - 1) * 0.5


static func _fit(w: World, q: Vector2) -> Vector2:
	var s := w.lockdown
	var f := w.floor_layout
	if f.room_of(q) == s.room and _open_spot(w, q) and Kin.length(q - w.player_pos()) >= MIN_HERO_M:
		return q
	var best := f.rooms[s.room].get_center()
	var best_d := -1.0
	for p in f.spawn_points[s.room]:
		if Kin.length(p - w.player_pos()) < MIN_HERO_M:
			continue
		var d := Kin.length(p - q)
		if best_d < 0.0 or d < best_d:
			best = p
			best_d = d
	return best


static func _open_spot(w: World, q: Vector2) -> bool:
	var r := CLEARANCE_M
	for k in w.walls_near(Rect2(q.x - r, q.y - r, r * 2.0, r * 2.0)):
		if Collide.circle_vs_obb(q, r, w.walls[k]) != Vector2.ZERO:
			return false
	return true


## The fighters now (actor indices): the encounter's living enemies anywhere, and any living enemy in the room.
static func fighters(w: World) -> PackedInt32Array:
	var s := w.lockdown
	var out := PackedInt32Array()
	if s == null or not s.sealed():
		return out
	var rect := w.floor_layout.rooms[s.room].grow(ROOM_MARGIN_M)
	var a := w.actors
	for i in range(1, a.size()):
		if a.dead[i] != 0 or a.teams[i] == ActorStore.TEAM_PLAYER:
			continue
		if not EnemyAi.is_enemy_kind(a.kinds[i]):
			continue
		if s.members.has(a.ids[i]) or rect.has_point(a.pos(i)):
			out.append(i)
	return out


## Whether fighter i can't be fought: outside the room, or on a cell the hero's flow field doesn't reach.
static func unreachable(w: World, i: int) -> bool:
	var p := w.actors.pos(i)
	if not w.floor_layout.rooms[w.lockdown.room].grow(ROOM_MARGIN_M).has_point(p):
		return true
	if w.nav.dist.is_empty() or w.nav.never_flooded():
		return false
	var k := w.nav.target_cell(p)
	return k < 0 or w.nav.dist[k] >= NavField.UNREACHED


## The stuck-enemy safety: counts each fighter's ticks unreachable in a row; one that reaches stuck_ticks is pulled
## back into the room.
static func _unstick(w: World) -> void:
	var s := w.lockdown
	var ids := PackedInt32Array()
	var ticks := PackedInt32Array()
	for i in fighters(w):
		if not unreachable(w, i):
			continue
		var id := w.actors.ids[i]
		var k := s.stuck_ids.find(id)
		var n := (s.stuck_ticks[k] if k >= 0 else 0) + 1
		if n >= s.table.stuck_ticks:
			w.actors.set_pos(i, pull_spot(w))
			s.pulled += 1
			s.pull_tick = w.tick
			continue
		ids.append(id)
		ticks.append(n)
	s.stuck_ids = ids
	s.stuck_ticks = ticks


## Where a stuck enemy comes back: the room's spawn point nearest its middle at least MIN_HERO_M from the hero, else
## the middle.
static func pull_spot(w: World) -> Vector2:
	return _middle_spawn(w.floor_layout, w.lockdown.room, w.player_pos(), MIN_HERO_M)


## Hazard Lockdowns: marks the next strike where the hero stands, and lands the strikes due.
static func _hazard(w: World) -> void:
	var s := w.lockdown
	var t := s.table
	if s.next_strike_tick >= 0 and w.tick >= s.next_strike_tick:
		s.strike_pos.append(w.player_pos())
		s.strike_tick.append(w.tick + t.hazard_warn_ticks)
		s.next_strike_tick = w.tick + t.hazard_every_ticks
	var k := 0
	while k < s.strike_tick.size():
		if w.tick < s.strike_tick[k]:
			k += 1
			continue
		var at := s.strike_pos[k]
		s.strike_pos.remove_at(k)
		s.strike_tick.remove_at(k)
		s.landed_pos = at
		s.landed_tick = w.tick
		s.landed_hit = 0
		var a := w.actors
		if a.dead[0] == 0 and Kin.length(a.pos(0) - at) <= t.hazard_radius_m + a.radius[0]:
			var hurt := Damage.hit(
				w, 0, t.hazard_damage, 0, 0, w.take_root(), 0, at, a.pos(0), HAZARD_EFFECT
			)
			s.landed_hit = 1 if hurt > 0 else 0
			if a.dead[0] == 1:
				w.killer_attack = KILL_CAUSE  # the recap names the hazard (BossCauses.key)


static func _open(w: World, forced: bool) -> void:
	var s := w.lockdown
	var room := s.room
	w.remove_barriers(s.barriers)
	s.barriers.clear()
	s.cleared.append(room)
	if forced:
		s.forced.append(room)
	s.clear_tick = w.tick
	s.room = -1
	s.kind = -1
	s.next_wave_tick = -1
	s.next_strike_tick = -1
	s.strike_pos = PackedVector2Array()
	s.strike_tick = PackedInt32Array()
	s.stuck_ids = PackedInt32Array()
	s.stuck_ticks = PackedInt32Array()
	s.rng = null
	s.reward_ids.append(w.add_reward(RewardStore.Kind.ALTAR, reward_spot(w.floor_layout, room), 0))


## The reward's spot: the room's spawn point nearest its middle (spawn points keep clear of walls), or the middle.
static func reward_spot(f: FloorLayout, room: int) -> Vector2:
	return _middle_spawn(f, room, Vector2.ZERO, 0.0)


## Room `room`'s spawn point nearest its middle at least `gap` m from `keep_from`, else the middle.
static func _middle_spawn(f: FloorLayout, room: int, keep_from: Vector2, gap: float) -> Vector2:
	var c := f.rooms[room].get_center()
	var best := c
	var best_d := -1.0
	for p in f.spawn_points[room]:
		if gap > 0.0 and Kin.length(p - keep_from) < gap:
			continue
		var d := Kin.length(p - c)
		if best_d < 0.0 or d < best_d:
			best = p
			best_d = d
	return best


## What the HUD, the bars, the hazard views and the sounds read (WorldReader.lockdown).
static func read(w: World) -> Dictionary:
	var s := w.lockdown
	var f := w.floor_layout
	if s == null or f == null:
		return {"active": false}
	return {
		"active": true,
		"rooms": f.lockdown_rooms.duplicate(),
		"kinds": f.lockdown_kinds.duplicate(),
		"sealed": s.room,
		"kind": s.kind,
		"sealed_tick": s.sealed_tick,
		"wave": s.wave,
		"waves": s.waves,
		"alive": fighters(w).size(),
		"cleared": s.cleared.duplicate(),
		"forced": s.forced.duplicate(),
		"clear_tick": s.clear_tick,
		"cap_ticks": s.table.cap_ticks,
		"pulled": s.pulled,
		"strike_pos": s.strike_pos.duplicate(),
		"strike_tick": s.strike_tick.duplicate(),
		"warn_ticks": s.table.hazard_warn_ticks,
		"radius": s.table.hazard_radius_m,
		"landed_pos": s.landed_pos,
		"landed_tick": s.landed_tick,
	}
