# gdlint: disable=max-public-methods
class_name Events
extends RefCounted
## Event rooms (v0.5.0 EV, PLAN R3; SIM_CONTRACTS §2 phases 1c, 2c and 9, §5 streams).
## - Rooms: 1-2 side rooms per floor (pick_rooms: never the start hall, the boss room or the room before the boss
##   door; a pure function of the layout and the seed, from the `map:event` stream, so other room kinds can be kept
##   out with `taken`). Each gets a lit pedestal at a clear spot (spot) and an event drawn from `loot:event` among
##   the events whose floor and requirement fit, no event twice on a floor.
## - Interact by a ready pedestal (after the altars and chests, before the gamble shrine) opens its panel; the world
##   then waits for the choice like a 3-card pick (World.ev.open). On the first open each choice's reward card and
##   curse are rolled once (loot:event), so the panel shows exactly what you get and reopening shows the same.
## - A pick (InputFrame.pick 1..n) pays the cost, adds the curse (Curses) and gives the reward; "Leave" (the cancel)
##   closes the panel and keeps the event for later. A choice whose cost can't be paid or whose reward can't apply
##   is refused (the view greys it out and names why). The pedestal goes dark once a choice is taken.
## - Wandering Drone (cost DEFEND) counts the ticks you stand within the ring, spawns arriving twice as fast
##   meanwhile, and pays its shards when done. (v0.9.0 EL, owner Q25 "Remove it": the Ambush Cache and its cost FIGHT
##   are gone; a retired event keeps its place in the tables, EventCompiler, and a save's pedestal of it closes on
##   load: drop_retired.)
## - v0.8.0 N17 (owner O75: "we need to create a room for this that looks dark and uses the glyphs symbols around it
##   with a new model, and they need to appear once max per floor and 40% of floors not all the time"): the curse room.
##   On rules.curse_room_floor_chance_permille of floors (`map:curse_room`, from the floor seed: curse_site) one combat
##   room (not the start hall, the boss room or its host, the portal room, the Overrun room, the shop's room, an arena
##   or the shrine's room) holds the curse altar: a pedestal like the others (World.ev.curse_k), whose event is drawn
##   from the curse events (EventTable.curse_room) after the common rooms' draws; the common rooms never draw a curse
##   event. A floor saved before N17 (`legacy`) keeps its event rooms as they were.
## - v0.8.0 N19 (owner O80: "The curse room should be a fixed unique small room in every biome like the store"): the
##   curse room is a room type of its own (CurseRoom.furnish: its interior cleared, the altar centred and solid, crystal
##   clusters round the walls, no enemy spawns). The room: small rooms and rooms holding no reward first (curse_site);
##   on a Deep floor always one (rules.curse_room_deep_chance_permille), whose altar holds Whispering Deep (S5: the
##   draw takes a deep_only event first). Echo Mirror needs a raised stat (Need.STAT_RAISED) to be drawn at all. A floor
##   built under N17's rules (floor rules 7, CURSE_RULES_N17) keeps N17's room, draw and look.

enum Cost { NONE, HP, MAX_HP, SHARDS, OVERHEAT, FIGHT, DEFEND }
enum Reward { STAT_EPIC, STAT_ECHO, MOD, CHEST, OVERCLOCK, ABILITY_LEVEL, SHARDS, CLEANSE }
enum Need { ANY, CURSE, HEAT, STAT_CARD, ABILITY, STAT_RAISED }
enum State { READY, ACTIVE, DONE }

const MAX_CHOICES := 2
const CURSE_NONE := -1
const CURSE_RANDOM := -2
## Why a choice can't be taken now (WorldReader.event_choice_block; the view names it).
const OK := 0
const NEED_SHARDS := 1
const NEED_NOTHING_TO_GAIN := 2
const NEED_BUSY := 3
## v0.8.0 N17: the curse room's draw (does the floor have one, and which room).
const CURSE_STREAM := "map:curse_room"
## v0.8.0 N17: which events a draw takes (draw_event).
const POOL_ANY := 0
const POOL_COMMON := 1
const POOL_CURSE := 2
## v0.8.0 N19: the curse-room rules a floor was built under (FloorScenario.curse_room_rules_of): before N17 (no curse
## room), N17's (a combat room keeps its interior; Whispering Deep in the common draw; Echo Mirror needs only stat
## cards) and today's.
const CURSE_RULES_BEFORE_N17 := 0
const CURSE_RULES_N17 := 1
const CURSE_RULES_N19 := 2
## v0.8.0 N19: a room this small (interior, m²) is a small room (a one-cell room is about 10-14 m by 9-11 m).
const SMALL_ROOM_M2 := 170.0


## Sets up the floor's event rooms (setup, after FloorScenario.build and the run's carry): the loadout and its
## streams, then the pedestals. A world without event tables gets none and keeps its hash.
static func setup(
	w: World,
	events: Array[EventTable],
	curses: Array[CurseTable],
	rules: EventRules,
	curse_rules: int = CURSE_RULES_N19
) -> void:
	var s := w.ev
	s.events = events
	s.curses = curses
	Curses.invalidate(w)  # the curse sums follow the floor's curse tables
	if rules != null:
		s.rules = rules
	if events.is_empty() and curses.is_empty():
		return
	s.rng = RngStream.derive(w.seed_value, "loot:event")
	s.rng_elite = RngStream.derive(w.seed_value, "ai:elite")
	Curses.drop_retired(w)  # v0.9.0 EL: a carried Marked curse (owner Q25) is gone
	Curses.after_setup(w)  # v0.6.0 CU: a held Glass Heart cuts the fresh floor's max HP
	if w.floor_layout != null and not events.is_empty():
		place(w, w.floor_layout, PackedInt32Array(), curse_rules)


## Places one pedestal per picked room with an event drawn for it; v0.8.0 N17: then the curse room's altar (unless
## CURSE_RULES_BEFORE_N17: a floor saved before N17, whose rooms draw every event as before); v0.8.0 N19: in a room
## of its own (CurseRoom.furnish), its solids added to the world's walls and no enemy spawning inside.
static func place(
	w: World,
	layout: FloorLayout,
	taken: PackedInt32Array = PackedInt32Array(),
	curse_rules: int = CURSE_RULES_N19
) -> void:
	var placed := PackedInt32Array()
	var rare := w.ev.rules.events_max_per_run > 0  # v0.9.5 AQ
	if rare:
		placed = w.events_seen.duplicate()  # never the same event twice in a run
	var shut := taken.duplicate()
	if Gamble.present(w):  # v0.8.0 N14: the shrine's room (a no-op for the start hall, never a candidate)
		shut.append(layout.room_of(w.gamble_pos))
	var curse_room := -1
	if curse_rules == CURSE_RULES_N17:
		curse_room = curse_site_n17(layout, w.seed_value, w.ev.rules, shut)
	elif curse_rules == CURSE_RULES_N19:
		curse_room = curse_site(
			layout, w.seed_value, w.ev.rules, shut, Routes.is_deep(w), reward_rooms(w, layout)
		)
	if curse_room >= 0:
		shut.append(curse_room)
	var pool := POOL_ANY if curse_rules == CURSE_RULES_BEFORE_N17 else POOL_COMMON
	for r in pick_rooms(layout, w.seed_value, w.ev.rules, shut, w.events_seen.size()):
		var e := draw_event(w, placed, pool, curse_rules)
		if e < 0:
			break
		placed.append(e)
		if rare:
			w.events_seen.append(e)
		_add(w, spot(layout, r, w.ev.rules)[0], r, e)
	if curse_room < 0:
		return
	var c := draw_event(w, placed, POOL_CURSE, curse_rules)  # after the common draws: they stay as drawn
	if c < 0:
		return
	w.ev.curse_k = w.ev.size()
	if curse_rules == CURSE_RULES_N17:
		_add(w, spot(layout, curse_room, w.ev.rules)[0], curse_room, c)
		return
	var at := curse_spot(layout, curse_room, w.ev.rules)[0]
	_furnish(w, layout, curse_room, at)
	_add(w, at, curse_room, c, false)


## v0.8.0 N19: the curse room becomes its own room (CurseRoom.furnish); the world's walls follow the layout's (the
## gate, the Deep gate, the shrine and the shop's solids kept after them, then the altar and the crystals) and no enemy
## spawns inside it.
static func _furnish(w: World, layout: FloorLayout, room: int, at: Vector2) -> void:
	var extra: Array[Obb] = w.walls.slice(layout.walls.size())
	var solids := CurseRoom.furnish(layout, room, at)
	var walls: Array[Obb] = layout.walls.duplicate()
	walls.append_array(extra)
	walls.append_array(solids)
	w.set_walls(walls)
	w.prepare_wall(layout.boss_door_wall)
	var spawns := PackedVector2Array()
	for q in w.spawn_points:
		if layout.room_of(q) != room:
			spawns.append(q)
	w.spawn_points = spawns


static func _add(w: World, at: Vector2, room: int, e: int, solid: bool = true) -> void:
	var id := w.take_root()
	w.ev.add(id, at, room, e)
	if solid:  # v0.9.5 SB: a pedestal is solid (the furnished curse altar already is)
		w.solids.add_square(Solids.Kind.EVENT, id, at)
	w.emit_event(SimEvent.Kind.SPAWN, id, id, id, at)


## v0.8.0 N17 (O75): the floor's curse room, or -1 for a floor without one. A draw on CURSE_STREAM from the floor seed
## (its first output dropped, as Gamble.stream): a curse room with rules.curse_room_floor_chance_permille; then the
## candidate rooms (curse_rooms, minus `shut`) in an order drawn from the same stream, the first with a clear altar spot
## (spot) wins. Pure: a function of the layout, the rules and the floor seed (property-tested over many seeds).
## Kept for a floor built under N17's rules (CURSE_RULES_N17); today's is curse_site.
static func curse_site_n17(
	layout: FloorLayout, seed_value: int, rules: EventRules, shut: PackedInt32Array
) -> int:
	var rng := Gamble.stream(seed_value, CURSE_STREAM)
	if not rng.chance_permille(rules.curse_room_floor_chance_permille):
		return -1
	for r in _shuffled(rng, curse_rooms(layout)):
		if not shut.has(r) and not spot(layout, r, rules).is_empty():
			return r
	return -1


## v0.8.0 N19 (O80): today's curse room, or -1. The same draws as N17's (the chance, then the candidates' order, on
## CURSE_STREAM), with rules.curse_room_deep_chance_permille on a Deep floor (`deep`); then, keeping the drawn order
## within each group: small rooms (SMALL_ROOM_M2) holding no reward (`rewarded`: the rooms that hold one), other rooms
## holding none, small rooms holding one, the rest. The first not in `shut` and not the shop's room (layout.shop_room:
## curse_rooms leaves out the room ShopPlacement would pick now, which can differ from the one it picked once the shop
## room is furnished) with an altar spot (curse_spot, on the room as CurseRoom.furnish will clear it) wins. Pure: a
## function of the layout, the rules, the floor seed and `rewarded`.
static func curse_site(
	layout: FloorLayout,
	seed_value: int,
	rules: EventRules,
	shut: PackedInt32Array,
	deep: bool = false,
	rewarded: PackedInt32Array = PackedInt32Array()
) -> int:
	var rng := Gamble.stream(seed_value, CURSE_STREAM)
	var chance := (
		rules.curse_room_deep_chance_permille if deep else rules.curse_room_floor_chance_permille
	)
	if not rng.chance_permille(chance):
		return -1
	var order := _shuffled(rng, curse_rooms(layout))
	for group in 4:
		for r in order:
			if _group_of(layout, r, rewarded) != group or shut.has(r) or r == layout.shop_room:
				continue  # N19 fix: the shop's real room (curse_rooms' guess can differ once it is furnished)
			if not curse_spot(layout, r, rules).is_empty():
				return r
	return -1


static func _group_of(layout: FloorLayout, r: int, rewarded: PackedInt32Array) -> int:
	var big := 0 if layout.rooms[r].get_area() <= SMALL_ROOM_M2 else 1
	return big + (2 if rewarded.has(r) else 0)


static func _shuffled(rng: RngStream, rooms: PackedInt32Array) -> PackedInt32Array:
	var order := rooms.duplicate()
	for k in range(order.size() - 1, 0, -1):
		var j := rng.range_int(0, k)
		var swap := order[k]
		order[k] = order[j]
		order[j] = swap
	return order


## v0.8.0 N19: the rooms holding one of the floor's rewards (an altar or a chest), ascending.
static func reward_rooms(w: World, layout: FloorLayout) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in w.rewards.size():
		var r := layout.room_of(w.rewards.pos(i))
		if r >= 0 and not out.has(r):
			out.append(r)
	out.sort()
	return out


## v0.8.0 N19: the curse altar's spot in `room` ([] when none), on the room as CurseRoom.furnish leaves it (its
## interior pieces gone): the room's centre, else its spawn points nearest the centre first; the first far enough in
## from the room's walls (the crystals' gap) and at least reward_gap_m from every item spot. Pure: no stream.
static func curse_spot(layout: FloorLayout, room: int, rules: EventRules) -> PackedVector2Array:
	var centre := layout.rooms[room].get_center()
	var tries := [centre]
	var pts := (
		layout.spawn_points[room] if room < layout.spawn_points.size() else PackedVector2Array()
	)
	var order := Array(pts)
	order.sort_custom(
		func(a: Vector2, b: Vector2) -> bool:
			var da := Kin.length(a - centre)
			var db := Kin.length(b - centre)
			return da < db or (da == db and (a.x < b.x or (a.x == b.x and a.y < b.y)))
	)
	tries.append_array(order)
	var margin := maxf(rules.clear_radius_m, CurseRoom.CRYSTAL_ALTAR_GAP_M * 0.5)
	for p: Vector2 in tries:
		if not layout.rooms[room].grow(-margin).has_point(p):
			continue
		var ok := true
		for s in layout.item_spots:
			if Kin.length(s - p) < rules.reward_gap_m:
				ok = false
				break
		if ok:
			return PackedVector2Array([p])
	return PackedVector2Array()


## v0.8.0 N17: the rooms a curse room may be, ascending: the combat rooms a shrine may stand in (Gamble.rooms: not the
## start hall, the boss room or its host, the portal room, the Overrun room, the shop's room or an arena).
static func curse_rooms(layout: FloorLayout) -> PackedInt32Array:
	return Gamble.rooms(layout)


## v0.8.0 N17: whether pedestal k is the curse room's altar.
static func is_curse_altar(w: World, k: int) -> bool:
	return k >= 0 and k == w.ev.curse_k


## The floor's event rooms, ascending (the generator side; property-tested over 1,000 seeds). Candidates are side
## rooms: not the start hall, not the boss room, not the boss door's host room, not the portal room, not the
## Overrun room (AB) or the shop room (SH; both marked on the layout before this runs), not an arena (AR), not in
## `taken` (any other side-room kind), and with a clear pedestal spot. The count is drawn in
## rules.rooms_min..rooms_max from `map:event`, then that many rooms by a partial shuffle of the candidates from the
## same stream. v0.9.5 AQ: under rules.events_max_per_run > 0 the count is instead 0 or rooms_max: none once the run
## has `done` event rooms, else rooms_max on event_floor_chance_permille of floors (the stream's first draw).
static func pick_rooms(
	layout: FloorLayout, seed_value: int, rules: EventRules, taken: PackedInt32Array, done: int = 0
) -> PackedInt32Array:
	var rare := rules.events_max_per_run > 0
	if rare and done >= rules.events_max_per_run:
		return PackedInt32Array()
	var cands := PackedInt32Array()
	for r in layout.room_count():
		if r == layout.start_room or r == layout.boss_room or r == layout.boss_host_room:
			continue
		if (
			r == layout.portal_room
			or r == layout.overrun_room
			or r == layout.shop_room
			or layout.arena_rooms.has(r)  # v0.5.5 AR: arenas are combat rooms
			or layout.lockdown_rooms.has(r)  # v0.9.0 CF2: marked first from floor rules 17
			or taken.has(r)
		):
			continue
		if spot(layout, r, rules).is_empty():
			continue
		cands.append(r)
	var rng := RngStream.derive(seed_value, "map:event")
	var n := 0
	if rare:
		n = rules.rooms_max if rng.chance_permille(rules.event_floor_chance_permille) else 0
		n = mini(n, mini(rules.events_max_per_run - done, cands.size()))
	else:
		n = mini(rng.range_int(rules.rooms_min, rules.rooms_max), cands.size())
	for k in n:
		var j := rng.range_int(k, cands.size() - 1)
		var t := cands[k]
		cands[k] = cands[j]
		cands[j] = t
	var out := cands.slice(0, n)
	out.sort()
	return out


## The pedestal's spot in `room` ([] when there is none): the room's centre, else its spawn points in order; the
## first that is clear of every wall by clear_radius_m and at least reward_gap_m from every item spot (where the
## altars and chests stand). Pure: no stream.
static func spot(layout: FloorLayout, room: int, rules: EventRules) -> PackedVector2Array:
	var tries := PackedVector2Array([layout.rooms[room].get_center()])
	if room < layout.spawn_points.size():
		tries.append_array(layout.spawn_points[room])
	for p in tries:
		if _clear(layout, room, p, rules):
			return PackedVector2Array([p])
	return PackedVector2Array()


static func _clear(layout: FloorLayout, room: int, p: Vector2, rules: EventRules) -> bool:
	if not layout.rooms[room].grow(-rules.clear_radius_m).has_point(p):
		return false
	for s in layout.item_spots:
		if Kin.length(s - p) < rules.reward_gap_m:
			return false
	for o in layout.walls:
		if Collide.circle_vs_obb(p, rules.clear_radius_m, o) != Vector2.ZERO:
			return false
	return true


## An event index for the next pedestal (loot:event): weighted among the events allowed on this floor, whose
## requirement holds and that aren't in `placed`; -1 when none is left. v0.5.5 DS (S5): a Deep-only event is allowed
## only on a Deep floor, and there the draw takes one first while one is left (so every Deep floor has one).
## v0.8.0 N17: `pool` POOL_COMMON (a common event room) leaves the curse events out, POOL_CURSE (the curse room) takes
## only them, POOL_ANY (a floor saved before N17) takes every event.
## v0.8.0 N19: under CURSE_RULES_N19 Whispering Deep (deep_only) is a curse event and Need.STAT_RAISED holds Echo
## Mirror back; older `curse_rules` keep a deep_only event common and read STAT_RAISED as STAT_CARD (needs_met).
static func draw_event(
	w: World, placed: PackedInt32Array, pool: int = POOL_ANY, curse_rules: int = CURSE_RULES_N19
) -> int:
	var deep := Routes.is_deep(w)
	var weights := PackedInt32Array()
	var deep_weights := PackedInt32Array()
	var any_deep := false
	for e in w.ev.events.size():
		var t := w.ev.events[e]
		var ok := t.min_floor <= w.floor_index and not placed.has(e)
		ok = ok and needs_met(w, t.requires, curse_rules)
		ok = ok and (deep or not t.deep_only)
		var curse := t.curse_room and (curse_rules == CURSE_RULES_N19 or not t.deep_only)
		ok = ok and (pool == POOL_ANY or curse == (pool == POOL_CURSE))
		weights.append(t.weight if ok else 0)
		deep_weights.append(t.weight if ok and t.deep_only else 0)
		any_deep = any_deep or (ok and t.deep_only and t.weight > 0)
	return Offers.pick(w.ev.rng, deep_weights if any_deep else weights)


static func needs_met(w: World, need: int, curse_rules: int = CURSE_RULES_N19) -> bool:
	if need == Need.STAT_RAISED and curse_rules != CURSE_RULES_N19:
		need = Need.STAT_CARD  # v0.8.0 N19: a floor built before it drew Echo Mirror on stat cards alone
	match need:
		Need.CURSE:
			return not w.curses_owned.is_empty()
		Need.HEAT:
			return w.heat != null
		Need.STAT_CARD:
			return Stats.enabled(w)
		Need.ABILITY:
			return not w.ability_tables.is_empty()
		Need.STAT_RAISED:  # v0.8.0 N19 (O80): the stat Echo Mirror would echo exists (its choice's own rule)
			return Stats.enabled(w) and strongest_stat(w) >= 0
	return true


static func table(w: World, k: int) -> EventTable:
	return w.ev.events[w.ev.event[k]]


## The ready pedestal within interact reach nearest the player (lowest index on a tie), or -1.
static func nearest(w: World) -> int:
	var best := -1
	var best_d := Stats.reach(w, w.ev.rules.interact_radius_m)
	var p := w.player_pos()
	for k in w.ev.size():
		if w.ev.state[k] != State.READY:
			continue
		var d := Kin.length(w.ev.pos(k) - p) - Solids.reach_bonus(w, Solids.Kind.EVENT, w.ev.ids[k])
		if d <= best_d and (best < 0 or d < best_d):
			best = k
			best_d = d
	return best


## Tick phase 2c, after Rewards.interact: a buffered interact press by a ready pedestal opens its panel. True if
## the world is now waiting on it.
static func interact(w: World) -> bool:
	if w.player_dead() or w.buffered(InputFrame.INTERACT) == 0:
		return false
	var k := nearest(w)
	if k < 0:
		return false
	w.consume_buffered(InputFrame.INTERACT)
	if w.ev.rolled[k] == 0:
		roll(w, k)
	w.ev.open = k
	return true


## Rolls pedestal k's choices once: each choice's reward card (a card code, or -1) and curse (loot:event).
static func roll(w: World, k: int) -> void:
	var t := table(w, k)
	w.ev.rolled[k] = 1
	var cursed := PackedInt32Array()
	for c in t.choice_count():
		var code := -1
		match t.reward[c]:
			Reward.STAT_EPIC:
				code = _stat_card(w, Stats.Rarity.EPIC)
			Reward.STAT_ECHO:
				var s := strongest_stat(w)
				code = Offers.stat_code(s, Stats.Rarity.RARE) if s >= 0 else -1
			Reward.MOD:
				code = _mod(w)
			Reward.ABILITY_LEVEL:
				code = _level_up(w)
		w.ev.roll_card[k * MAX_CHOICES + c] = code
		var curse := t.curse[c]
		if curse == CURSE_RANDOM:
			curse = Curses.roll(w, cursed, Curses.Pool.PLAIN)  # v0.6.0 CU: an event's price is a plain curse
		elif curse >= 0 and Curses.owned(w, curse):
			curse = CURSE_NONE  # the panel shows the choice blocked (curse_block)
		if curse >= 0:
			cursed.append(curse)
		w.ev.roll_curse[k * MAX_CHOICES + c] = curse


static func _stat_card(w: World, rarity: int) -> int:
	var ids := PackedInt32Array()
	var weights := PackedInt32Array()
	for s in w.stat_tables.size():
		var st := w.stat_tables[s]
		if st != null and st.weight > 0 and not Stats.at_cap(w, s):
			ids.append(s)
			weights.append(st.weight)
	var pick := Offers.pick(w.ev.rng, weights)
	return Offers.stat_code(ids[pick], rarity) if pick >= 0 else -1


## The stat card you raised most (the largest move from its base, in per mille; lowest index on a tie) and can
## still raise, or -1 (Echo Mirror).
static func strongest_stat(w: World) -> int:
	var best := -1
	var best_v := 0
	for s in mini(w.stat_tables.size(), w.stat_values.size()):
		var st := w.stat_tables[s]
		if st == null or st.weight <= 0 or Stats.at_cap(w, s):
			continue
		var v := absi(w.stat_values[s] - Stats.BASE[s])
		if v > best_v:
			best = s
			best_v = v
	return best


static func _mod(w: World) -> int:
	var pool := ItemPool.available(w)
	var weights := PackedInt32Array()
	for idx in pool:
		var rare := w.item_tables[idx].tier() >= ItemTable.TIER_RARE  # v0.8.0 RR: an epic one too
		# v0.8.0 FL: × the floor stage's category multiplier (per mille of the old weight; × 1 without pacing)
		var base := w.reward_table.rare_weight_chest if rare else 1
		weights.append(base if w.loot_pacing == null else LootPacing.weigh(w, idx, base * 1000))
	var pick := Offers.pick(w.ev.rng, weights)
	return pool[pick] if pick >= 0 else -1


static func _level_up(w: World) -> int:
	var left := PackedInt32Array()
	for idx in w.ability_owned:
		if Abilities.level_of(w, idx) < AbilityTable.MAX_LEVEL:
			left.append(idx)
	if left.is_empty():
		return -1
	return Offers.ability_code(left[w.ev.rng.range_int(0, left.size() - 1)])


## The shards choice c of pedestal k costs now (its amount x the floor, under the prices curse).
static func shard_cost(w: World, k: int, c: int) -> int:
	var t := table(w, k)
	if t.cost[c] != Cost.SHARDS:
		return 0
	return Curses.price(w, t.cost_amount[c] * maxi(1, w.floor_index))


## Why choice c of pedestal k can't be taken now (OK when it can): its cost, then its reward, then its curse.
static func block(w: World, k: int, c: int) -> int:
	var t := table(w, k)
	if c < 0 or c >= t.choice_count():
		return NEED_NOTHING_TO_GAIN
	var why := _cost_block(w, k, c)
	if why == OK and not _reward_applies(w, k, c):
		why = NEED_NOTHING_TO_GAIN
	if why == OK and t.curse[c] != CURSE_NONE and w.ev.roll_curse[k * MAX_CHOICES + c] < 0:
		why = NEED_NOTHING_TO_GAIN  # every curse is already held: the price can't be paid
	return why


static func _cost_block(w: World, k: int, c: int) -> int:
	var why := OK
	match table(w, k).cost[c]:
		Cost.SHARDS:
			why = NEED_SHARDS if w.shards < shard_cost(w, k, c) else OK
		Cost.MAX_HP:
			why = OK if Stats.enabled(w) else NEED_NOTHING_TO_GAIN
		Cost.OVERHEAT:
			why = NEED_BUSY if w.heat == null or Heat.stalled(w) else OK
		Cost.FIGHT:  # v0.9.0 EL: retired with the Ambush Cache
			why = NEED_BUSY
		Cost.DEFEND:
			why = NEED_BUSY if w.ev.defend >= 0 else OK
	return why


static func _reward_applies(w: World, k: int, c: int) -> bool:
	var code := w.ev.roll_card[k * MAX_CHOICES + c]
	match table(w, k).reward[c]:
		Reward.STAT_EPIC, Reward.STAT_ECHO, Reward.MOD, Reward.ABILITY_LEVEL:
			return Shop.can_apply(w, code)  # the shop's rule, the one rule (audit G-6)
		Reward.CLEANSE:
			return not w.curses_owned.is_empty()
		Reward.OVERCLOCK:
			return w.heat != null
	return true


## While a panel is open (tick phase 1c): a pick takes that choice, a cancel leaves; anything else waits.
static func choose(w: World, frame: InputFrame) -> void:
	var k := w.ev.open
	if k < 0 or k >= w.ev.size() or frame.pick == InputFrame.PICK_CANCEL:
		_resume(w)
		return
	if frame.pick == InputFrame.PICK_NONE:
		return
	var c := frame.pick - 1
	if block(w, k, c) != OK:
		w.ev.denied_tick = w.tick
		return
	take(w, k, c)
	_resume(w)


## Takes choice c of pedestal k (choose, after its checks; tests call it directly): the cost, then the curse, then
## the reward (or, for a fight or a defence, the pedestal stays active until it is done).
static func take(w: World, k: int, c: int) -> void:
	var t := table(w, k)
	var s := w.ev
	s.state[k] = State.DONE
	var amount := t.cost_amount[c]
	match t.cost[c]:
		Cost.HP:
			var loss := w.actors.max_hp[0] * amount / 1000
			w.actors.hp[0] = maxi(1, w.actors.hp[0] - loss)
		Cost.MAX_HP:
			cut_max_hp(w, amount)
		Cost.SHARDS:
			w.shards -= shard_cost(w, k, c)
		Cost.OVERHEAT:
			Heat.add(w, w.heat.table.max_milli() * 4)  # past any shrine heat capacity: the overheat
		Cost.DEFEND:
			s.defend = k
			s.defend_ticks = 0
			s.defend_total = amount
			s.defend_reward = t.reward_amount[c]
			s.state[k] = State.ACTIVE
	var curse := s.roll_curse[k * MAX_CHOICES + c]
	if curse >= 0:
		Curses.add(w, curse)
	var code := s.roll_card[k * MAX_CHOICES + c]
	match t.reward[c]:
		Reward.STAT_EPIC, Reward.STAT_ECHO, Reward.MOD, Reward.ABILITY_LEVEL:
			var me := w.actors.ids[0]
			var e := w.emit_event(SimEvent.Kind.PICKUP, s.ids[k], me, me, s.pos(k))
			e.amount = code
			Offers.apply(w, code)
		Reward.OVERCLOCK:
			s.overclock_bonus += t.reward_amount[c]
		Reward.SHARDS:
			if t.cost[c] != Cost.DEFEND:
				pay_shards(w, k, t.reward_amount[c])
		Reward.CLEANSE:
			Curses.cleanse(w)
	s.result_tick = w.tick
	s.result_pedestal = k
	s.result_choice = c


## The max HP stat falls by `permille` for the run (Blood Price); HP stays at most the new max.
static func cut_max_hp(w: World, permille: int) -> void:
	if w.stat_values.size() < Stats.COUNT:
		var old := w.stat_values
		w.stat_values = PackedInt32Array(Stats.BASE)
		for k in old.size():
			w.stat_values[k] = old[k]
	var v := w.stat_values[Stats.Stat.MAX_HP]
	w.stat_values[Stats.Stat.MAX_HP] = maxi(1, (v * (1000 - permille) + 500) / 1000)
	w.actors.max_hp[0] = maxi(1, Stats.max_hp(w))
	w.actors.hp[0] = clampi(w.actors.hp[0], 1, w.actors.max_hp[0])


## Tick phase 9, after the dead are removed: a defence held (its shards).
static func advance(w: World) -> void:
	var s := w.ev
	if s.rng == null:
		return
	if s.defend >= 0 and not w.player_dead():
		if Kin.length(w.player_pos() - s.pos(s.defend)) <= s.rules.defend_radius_m:
			s.defend_ticks += 1
		if s.defend_ticks >= s.defend_total:
			var k := s.defend
			pay_shards(w, k, s.defend_reward)
			_finish(w, k)
			s.defend = -1


## v0.9.0 EL (owner Q25): a restored floor's pedestal of a retired event (the Ambush Cache) is closed; the curses a
## save still holds that are retired go (Curses.drop_retired). WorldSnapshot.apply calls it.
static func drop_retired(w: World) -> void:
	var s := w.ev
	for k in s.size():
		var e := s.event[k]
		if e >= 0 and e < s.events.size() and s.events[e].retired and s.state[k] != State.DONE:
			s.state[k] = State.DONE
	Curses.drop_retired(w)


## Pays `per_floor` x the floor number shards (under the shard gain stat) from pedestal k, with a SHARDS event.
static func pay_shards(w: World, k: int, per_floor: int) -> void:
	var pay := Stats.shards(w, per_floor * maxi(1, w.floor_index))
	w.shards += pay
	var me := w.actors.ids[0]
	var e := w.emit_event(SimEvent.Kind.SHARDS, w.ev.ids[k], me, me, w.ev.pos(k))
	e.amount = pay


static func _finish(w: World, k: int) -> void:
	w.ev.state[k] = State.DONE
	w.ev.done_tick = w.tick
	w.ev.done_pedestal = k


## Wandering Drone: while a defence runs, the spawn director's clock runs this many ticks extra per tick.
static func spawn_haste(w: World) -> int:
	return 1 if w.ev.defend >= 0 else 0


## Overclock Vent's reward: extra Overclock damage this floor (per mille; Heat.attacker_mult).
static func overclock_bonus(w: World) -> int:
	return w.ev.overclock_bonus


static func waiting(w: World) -> bool:
	return w.ev.open >= 0


## Back to play: no panel open, and nothing pressed during it fires afterwards.
static func _resume(w: World) -> void:
	w.ev.open = -1
	for b in w.input_buffer.size():
		w.input_buffer[b] = 0


## World.state_hash: only worlds with events or curses carry the block, so older goldens keep their hash.
static func hash_into(w: World, h: StateHasher) -> void:
	if not w.ev.touched(w):
		return
	h.add_ints(w.curses_owned)
	h.add_int(w.threat_peak)
	h.add_int(w.deep_threat)
	w.ev.hash_into(h)
	if w.cs.touched():  # v0.6.0 CU: the trade-off curses' state and core theft, once touched
		w.cs.hash_into(h)
	if w.cores.touched():
		w.cores.hash_into(h)
