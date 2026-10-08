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
## - Ambush Cache (cost FIGHT) brings an elite pack into the room (each a normal enemy kind with its own telegraphs,
##   spawning in like any enemy); the chest appears when the last one falls. Wandering Drone (cost DEFEND) counts
##   the ticks you stand within the ring, spawns arriving twice as fast meanwhile, and pays its shards when done.

enum Cost { NONE, HP, MAX_HP, SHARDS, OVERHEAT, FIGHT, DEFEND }
enum Reward { STAT_EPIC, STAT_ECHO, MOD, CHEST, OVERCLOCK, ABILITY_LEVEL, SHARDS, CLEANSE }
enum Need { ANY, CURSE, HEAT, STAT_CARD, ABILITY }
enum State { READY, ACTIVE, DONE }

const MAX_CHOICES := 2
const CURSE_NONE := -1
const CURSE_RANDOM := -2
## Why a choice can't be taken now (WorldReader.event_choice_block; the view names it).
const OK := 0
const NEED_SHARDS := 1
const NEED_NOTHING_TO_GAIN := 2
const NEED_BUSY := 3
## The chest an ambush leaves stands this far from the pedestal, toward the room's centre.
const CHEST_OFFSET_M := 1.4


## Sets up the floor's event rooms (setup, after FloorScenario.build and the run's carry): the loadout and its
## streams, then the pedestals. A world without event tables gets none and keeps its hash.
static func setup(
	w: World, events: Array[EventTable], curses: Array[CurseTable], rules: EventRules
) -> void:
	var s := w.ev
	s.events = events
	s.curses = curses
	if rules != null:
		s.rules = rules
	if events.is_empty() and curses.is_empty():
		return
	s.rng = RngStream.derive(w.seed_value, "loot:event")
	s.rng_elite = RngStream.derive(w.seed_value, "ai:elite")
	if w.floor_layout != null and not events.is_empty():
		place(w, w.floor_layout)


## Places one pedestal per picked room with an event drawn for it.
static func place(
	w: World, layout: FloorLayout, taken: PackedInt32Array = PackedInt32Array()
) -> void:
	var placed := PackedInt32Array()
	for r in pick_rooms(layout, w.seed_value, w.ev.rules, taken):
		var e := draw_event(w, placed)
		if e < 0:
			break
		placed.append(e)
		var at := spot(layout, r, w.ev.rules)[0]
		var id := w.take_root()
		w.ev.add(id, at, r, e)
		w.emit_event(SimEvent.Kind.SPAWN, id, id, id, at)


## The floor's event rooms, ascending (the generator side; property-tested over 1,000 seeds). Candidates are side
## rooms: not the start hall, not the boss room, not the boss door's host room, not in `taken` (other side-room
## kinds), and with a clear pedestal spot. The count is drawn in rules.rooms_min..rooms_max from `map:event`, then
## that many rooms by a partial shuffle of the candidates from the same stream.
static func pick_rooms(
	layout: FloorLayout, seed_value: int, rules: EventRules, taken: PackedInt32Array
) -> PackedInt32Array:
	var cands := PackedInt32Array()
	for r in layout.room_count():
		if r == layout.start_room or r == layout.boss_room or r == layout.boss_host_room:
			continue
		if r == layout.portal_room or taken.has(r):
			continue
		if spot(layout, r, rules).is_empty():
			continue
		cands.append(r)
	var rng := RngStream.derive(seed_value, "map:event")
	var n := mini(rng.range_int(rules.rooms_min, rules.rooms_max), cands.size())
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
## requirement holds and that aren't in `placed`; -1 when none is left.
static func draw_event(w: World, placed: PackedInt32Array) -> int:
	var weights := PackedInt32Array()
	for e in w.ev.events.size():
		var t := w.ev.events[e]
		var ok := t.min_floor <= w.floor_index and not placed.has(e) and needs_met(w, t.requires)
		weights.append(t.weight if ok else 0)
	return Offers.pick(w.ev.rng, weights)


static func needs_met(w: World, need: int) -> bool:
	match need:
		Need.CURSE:
			return not w.curses_owned.is_empty()
		Need.HEAT:
			return w.heat != null
		Need.STAT_CARD:
			return Stats.enabled(w)
		Need.ABILITY:
			return not w.ability_tables.is_empty()
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
		var d := Kin.length(w.ev.pos(k) - p)
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
			curse = Curses.roll(w, cursed)
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
		var rare := w.item_tables[idx].rarity == ItemTable.RARE
		weights.append(w.reward_table.rare_weight_chest if rare else 1)
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
		Cost.FIGHT:
			var cant := w.ev.ambush >= 0 or w.spawner == null or w.floor_layout == null
			why = NEED_BUSY if cant else OK
		Cost.DEFEND:
			why = NEED_BUSY if w.ev.defend >= 0 else OK
	return why


static func _reward_applies(w: World, k: int, c: int) -> bool:
	var code := w.ev.roll_card[k * MAX_CHOICES + c]
	match table(w, k).reward[c]:
		Reward.STAT_EPIC, Reward.STAT_ECHO, Reward.MOD, Reward.ABILITY_LEVEL:
			return code >= 0 and _card_applies(w, code)
		Reward.CLEANSE:
			return not w.curses_owned.is_empty()
		Reward.OVERCLOCK:
			return w.heat != null
	return true


## A rolled card still does something (a stat under its cap, a mod not owned, an ability below its top level).
static func _card_applies(w: World, code: int) -> bool:
	match Offers.type_of(code):
		Offers.STAT:
			return not Stats.at_cap(w, Offers.stat_of(code))
		Offers.ABILITY:
			return Abilities.can_take(w, Offers.ability_of(code))
	return not w.items_owned.has(code)


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
		Cost.FIGHT:
			_ambush(w, k, amount)
			s.state[k] = State.ACTIVE
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


## Ambush Cache: `n` elites of the kinds the floor spawns now (loot:event picks kind and spot), at the room's spawn
## points at least ambush_min_distance_m from you (else any of the room's), HP scaled to the danger tier like the
## spawn director's, then raised as elites.
static func _ambush(w: World, k: int, n: int) -> void:
	var s := w.ev
	var t := w.spawner
	var tier := t.tier_at(w.run_ticks)
	var open := SpawnDirector.unlocked(w, t, tier)
	var pts := PackedVector2Array()
	var all: PackedVector2Array = (
		w.floor_layout.spawn_points[s.room[k]]
		if s.room[k] < w.floor_layout.spawn_points.size()
		else PackedVector2Array()
	)
	for p in all:
		if Kin.length(p - w.player_pos()) >= s.rules.ambush_min_distance_m:
			pts.append(p)
	if pts.is_empty():
		pts = all
	if pts.is_empty() or open.is_empty():
		pts = PackedVector2Array([s.pos(k) + Vector2(s.rules.ambush_min_distance_m, 0)])
	s.ambush = k
	s.ambush_ids = PackedInt32Array()
	var first := s.rng.range_int(0, pts.size() - 1)
	for m in n:
		var kind := ActorStore.Kind.CHARGER
		if not open.is_empty():
			var weights := PackedInt32Array()
			for j in open:
				weights.append(t.weights[j])
			var pick := Offers.pick(s.rng, weights)
			kind = t.kinds[open[maxi(pick, 0)]]
		if w.enemy_table(kind) == null:
			continue
		var id := w.add_enemy(kind, pts[(first + m) % pts.size()])
		var i := w.actors.size() - 1
		var hp := t.scaled_hp(w.enemy_table(kind).hp, tier)
		w.actors.hp[i] = hp
		w.actors.max_hp[i] = hp
		Curses.make_elite(w, i)
		s.ambush_ids.append(id)


## Tick phase 9, after the dead are removed: the elites still alive, an ambush cleared (its chest), a defence held
## (its shards).
static func advance(w: World) -> void:
	var s := w.ev
	if s.rng == null:
		return
	if not s.elite_ids.is_empty():
		var alive := PackedInt32Array()
		for id in s.elite_ids:
			if w.actors.index_of(id) >= 0:
				alive.append(id)
		s.elite_ids = alive
	if s.ambush >= 0:
		var left := 0
		for id in s.ambush_ids:
			if w.actors.index_of(id) >= 0:
				left += 1
		if left == 0:
			_finish(w, s.ambush)
			w.add_reward(RewardStore.Kind.CHEST, chest_spot(w, s.ambush), 0)
			s.ambush = -1
			s.ambush_ids = PackedInt32Array()
	if s.defend >= 0 and not w.player_dead():
		if Kin.length(w.player_pos() - s.pos(s.defend)) <= s.rules.defend_radius_m:
			s.defend_ticks += 1
		if s.defend_ticks >= s.defend_total:
			var k := s.defend
			pay_shards(w, k, s.defend_reward)
			_finish(w, k)
			s.defend = -1


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


## Where an ambush's chest appears: CHEST_OFFSET_M from the pedestal toward its room's centre (the pedestal itself
## when it is the centre).
static func chest_spot(w: World, k: int) -> Vector2:
	var at := w.ev.pos(k)
	var c := w.floor_layout.rooms[w.ev.room[k]].get_center() if w.floor_layout != null else at
	var d := Kin.length(c - at)
	if d < 0.01:
		return at + Vector2(CHEST_OFFSET_M, 0)
	return at + (c - at) * (CHEST_OFFSET_M / d)


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
	w.ev.hash_into(h)
