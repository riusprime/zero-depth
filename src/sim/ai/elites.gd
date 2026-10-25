class_name Elites
extends RefCounted
## v0.9.0 EL (owner Q24, Q25, Q26; G1 docs/roadmap/v0.9.0/ELITES.md, "ok go for those"): where elites come from and
## what a kill gives. The archetypes' behaviour is EliteAi's; World.elites holds the state (EliteState; null on a
## floor that never had one), World.elite_rules the numbers (EliteRules).
## - Elite rooms (Q24: "15 % / 25 %", floors 4-5 only): when a floor is built (FloorPlan.add_secrets, last: after the
##   Lockdowns), room_permille_on(floor) of its combat rooms (LockdownRooms.candidates: never the start hall, the boss
##   room, a shop, a secret, an arena, a Lockdown, an event's or a shrine's room; rounded half up) are drawn from the
##   `map:elites` sub-stream of the floor seed, each at least min_gap_rooms rooms (doorway hops - 1) from every other
##   elite room and Elite Lockdown, and each given an archetype (kind_weights, the same stream). Nothing else is drawn
##   from it, so every other room and draw stays as it was.
## - The first time the hero walks into an elite room while fewer than max_alive elites are alive, its elite arrives at
##   the room's spawn point farthest from the hero (a 0.7 s rise, the arrival burst and sigil in the views; no pause, no
##   banner: W67). The next pack the spawner sends is one smaller while it lives (ELITES.md E0, the escort).
## - The designed exceptions: an Elite Lockdown (Lockdowns: an elite and lockdown_escort enemies, floors 4-5) and the
##   Chaos shrine's challenge (Shrines: chaos_elite_permille, one elite more), drawing the archetype from their own
##   stream (draw_kind).
## - Every elite arrives scaled like any spawn (SpawnDirector.scale_arrival: the floor's tables, the danger tier, the
##   catch-up), never freezes (frost only slows it, as a boss) and carries a core (CoreTheft.on_elite: a card from the
##   pool, `ai:elite`). Killed, it drops that card with core_drop_permille (Q25: "you have a 30% chance of dropping the
##   core"; no stagger window), drawn on `ai:elite`; its shards are its table's (3 x a normal enemy's).
## Pure sim code: integers, BFS over the doorway graph, named streams.

enum Source { ROOM, LOCKDOWN, CHAOS, DEV }

const KINDS: Array[int] = [
	ActorStore.Kind.BREAKER,
	ActorStore.Kind.RIFT_HUNTER,
	ActorStore.Kind.CONDUIT,
]
const STREAM := "map:elites"


## Marks the floor's elite rooms (FloorPlan.add_secrets, after the Lockdowns): sets World.elite_rules, and World.elites
## when the floor has an elite room. `floor_index` is 1-based within the loop.
static func setup(w: World, rules: EliteRules, floor_index: int) -> void:
	w.elite_rules = rules
	var f := w.floor_layout
	if f == null or rules == null:
		return
	var marked := mark(f, rules, floor_index, Lockdowns.taken_rooms(w))
	var rooms: PackedInt32Array = marked[0]
	if rooms.is_empty():
		return
	var s := state(w)
	s.rooms = rooms
	s.room_kinds = marked[1]
	s.room_spawned = PackedInt32Array()
	s.room_spawned.resize(rooms.size())
	s.room_spawned.fill(0)


## [rooms, kinds]: floor `f`'s elite rooms and their archetypes (ActorStore.Kind), as setup() marks them. `taken`: the
## event and shrine rooms (never one).
static func mark(
	f: FloorLayout, rules: EliteRules, floor_index: int, taken: PackedInt32Array
) -> Array:
	var rooms := PackedInt32Array()
	var kinds := PackedInt32Array()
	var permille := rules.room_permille_on(floor_index)
	if permille <= 0 or f.room_count() == 0:
		return [rooms, kinds]
	var never := taken.duplicate()
	never.append_array(f.lockdown_rooms)
	var cands := LockdownRooms.candidates(f, never)
	var rng := RngStream.derive(f.seed_value, STREAM)
	for k in range(cands.size() - 1, 0, -1):
		var j := rng.range_int(0, k)
		var swap := cands[k]
		cands[k] = cands[j]
		cands[j] = swap
	var want := (cands.size() * permille + 500) / 1000
	var spaced := elite_lockdowns(f)
	for r in cands:
		if rooms.size() >= want:
			break
		if _far_from(f, r, spaced, rules.min_gap_rooms):
			rooms.append(r)
			spaced.append(r)
	for r in rooms:
		kinds.append(draw_kind(rng, rules))
	return [rooms, kinds]


## The floor's Elite Lockdown rooms.
static func elite_lockdowns(f: FloorLayout) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in f.lockdown_rooms.size():
		if k < f.lockdown_kinds.size() and f.lockdown_kinds[k] == LockdownTable.Kind.ELITE:
			out.append(f.lockdown_rooms[k])
	return out


## An archetype drawn from `rng` by the rules' weights (the Breaker without rules or weights).
static func draw_kind(rng: RngStream, rules: EliteRules) -> int:
	var weights := rules.kind_weights if rules != null else PackedInt32Array()
	var k := Offers.pick(rng, weights) if not weights.is_empty() else 0
	return KINDS[clampi(k, 0, KINDS.size() - 1)]


## Doorway hops from `from` to every room (-1 = not reached).
static func hops(f: FloorLayout, from: int) -> PackedInt32Array:
	var d := PackedInt32Array()
	d.resize(f.room_count())
	d.fill(-1)
	d[from] = 0
	var queue := PackedInt32Array([from])
	var head := 0
	while head < queue.size():
		var r := queue[head]
		head += 1
		for nb in f.neighbours(r):
			if d[nb] < 0:
				d[nb] = d[r] + 1
				queue.append(nb)
	return d


## Room r has at least `gap` rooms between it and each of `others` (hops > gap).
static func _far_from(f: FloorLayout, r: int, others: PackedInt32Array, gap: int) -> bool:
	if others.is_empty():
		return true
	var d := hops(f, r)
	for o in others:
		if d[o] >= 0 and d[o] <= gap:
			return false
	return true


## World.elites, made on first use (an Elite Lockdown's or the Chaos shrine's elite on a floor without elite rooms).
static func state(w: World) -> EliteState:
	if w.elites == null:
		w.elites = EliteState.new()
	return w.elites


static func alive(w: World) -> int:
	return w.elites.size() if w.elites != null else 0


static func max_alive(w: World) -> int:
	return w.elite_rules.max_alive if w.elite_rules != null else 1


## Elite `kind` arrives at `at` (from `source`): an enemy scaled like any spawn, freeze-immune, carrying a core, its
## ability and plain attack due half a cycle after it rises. Returns its actor id (-1 without the kind's table).
static func spawn(w: World, kind: int, at: Vector2, source: int) -> int:
	var t := w.enemy_table(kind)
	if t == null or t.elite == null:
		return -1
	var id := w.add_enemy(kind, at)
	var a := w.actors
	var i := a.size() - 1
	if w.spawner != null:
		SpawnDirector.scale_arrival(w, i, w.run_ticks)
	a.freeze_immune[i] = 1
	a.cd[i] = t.elite.every_ticks / 2
	a.fire_cd[i] = t.elite.basic_every_ticks / 2
	var s := state(w)
	s.add(id, kind, source)
	s.arrive_tick = w.tick
	s.arrive_id = id
	s.arrive_pos = at
	s.arrived += 1
	CoreTheft.on_elite(w, i)
	return id


## Tick phase 9 (World.step, after the Lockdowns and the shrines): the dead leave the list, and an elite room the hero
## just walked into brings its elite.
static func advance(w: World) -> void:
	var s := w.elites
	if s == null:
		return
	for k in range(s.size() - 1, -1, -1):
		if w.actors.index_of(s.ids[k]) < 0:
			s.remove_at(k)
	if s.size() == 0:
		s.escort_pending = 0
	if s.rooms.is_empty() or w.player_dead() or w.floor_layout == null:
		return
	var room := w.floor_layout.room_of(w.player_pos())
	var k := s.rooms.find(room) if room >= 0 else -1
	if k < 0 or s.room_spawned[k] == 1 or s.size() >= max_alive(w):
		return
	s.room_spawned[k] = 1
	if spawn(w, s.room_kinds[k], arrival_spot(w, room), Source.ROOM) >= 0:
		s.escort_pending = 1


## Where a room's elite arrives: its spawn point farthest from the hero, else the room's middle.
static func arrival_spot(w: World, room: int) -> Vector2:
	var f := w.floor_layout
	var p := w.player_pos()
	var best := f.rooms[room].get_center()
	var best_d := -1.0
	var pts: PackedVector2Array = (
		f.spawn_points[room] if room < f.spawn_points.size() else PackedVector2Array()
	)
	for q in pts:
		var d := Kin.length(q - p)
		if d > best_d:
			best = q
			best_d = d
	return best


## SpawnDirector: the pack arriving now, `size` strong, is one smaller while a room's elite waits for its escort.
static func escort_size(w: World, size: int) -> int:
	var s := w.elites
	if s == null or s.escort_pending == 0:
		return size
	s.escort_pending = 0
	return maxi(1, size - 1)


## World._remove_dead, as elite actor i leaves (after CoreTheft.on_death): with core_drop_permille (on `ai:elite`) its
## core's card drops as a free pick (redrawn from the pool if it no longer applies: the shop's rule).
static func on_death(w: World, i: int) -> void:
	var a := w.actors
	var s := state(w)
	s.kill_tick = w.tick
	s.kill_pos = a.pos(i)
	s.kill_dropped = 0
	var k := CoreTheft.entry_of(w, a.ids[i])
	if k < 0 or w.cores.boss[k] == 1 or not CoreTheft.enabled(w):
		return
	var chance := w.elite_rules.core_drop_permille if w.elite_rules != null else 300
	if not w.ev.rng_elite.chance_permille(chance):
		return
	var code := w.cores.card[k]
	if not Shop.can_apply(w, code):
		code = CoreTheft.draw_card(w, w.ev.rng, Stats.Rarity.RARE)
	if code < 0:
		return
	CoreTheft.grant(w, code, a.pos(i), CoreState.Drop.CORE)
	w.cores.steal_tick = w.tick
	w.cores.steal_card = code
	s.kill_dropped = 1
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, a.ids[0], a.ids[0], a.ids[0], a.pos(i))
	e.effect_id = CoreTheft.EFFECT_STEAL
	e.amount = code
