class_name Shrines
extends RefCounted
## v0.9.0 SH, HF (owner Q29b: "Today's gamble shrine becomes the Fortune Shrine; Blood and Chaos shrines are added (at
## most one shrine a floor, costs shown first; the Chaos challenge may bring an elite, a designed exception). Healing
## fountains (rare, one use)"; W36: "Blood (health for a reward), Chaos (a challenge for an extra upgrade), Fortune (a
## resource for a random reward)"). World.shrine holds the state (ShrineState; null on a floor with neither a Blood
## or Chaos shrine nor a fountain).
## - The floor's one shrine: the gamble shrine's site (Gamble.site: its chance, its room, its spot and footprint,
##   unchanged) is drawn as before; then its kind, from the `map:shrine_kind` sub-stream of the floor seed by the
##   kinds' weights among those allowed on the floor (setup). Fortune is the gamble shrine as it was (Gamble: shards
##   for a stat, 30 % fail, 3 wins); a Blood or Chaos shrine stands on the same spot instead (Gamble.present is then
##   false, and World.gamble_pos stays the site every other kind of room keeps away from).
## - Blood: one press within reach pays blood_cost(): a share of current HP, rounded up, never below 1 HP left; under
##   blood_min_permille of max HP it refuses (denied_tick) and stays. Paid, it raises blood_altars free altars beside
##   it (reward_spots) and is spent.
## - Chaos: one press begins the challenge: chaos_size(floor) enemies at once on the room's spawn points (kinds
##   weighted as the spawn director's at the curve's level now, scaled on arrival like any spawn, from the
##   `combat:chaos` stream of the floor seed). When none of them is left alive (advance), it raises chaos_altars free
##   altars. v0.9.0 EL: with chaos_elite_permille (then drawn on the same stream, after the enemies) the challenge
##   also brings one elite archetype (Elites.spawn), unless as many elites as the rules allow are already alive.
## - The healing fountain: on fountain_permille of floors from fountain_floor_min (the `map:fountain` sub-stream), in
##   a free spot of a combat room (Gamble.room_spot, as the shrine), never the shrine's room, an event's or the curse
##   room; the secrets and Lockdowns placed after keep out of its room (taken_rooms). Its footprint is a wall. One
##   press heals fountain_heal_permille of max HP (a HEAL event); then it is dry. At full HP it refuses and stays.
## - Both use the shared interactable (Interactables: Kind.SHRINE, Kind.FOUNTAIN), so the HUD's one prompt shows the
##   cost or the effect before the press (prompt_key, prompt_args).
## Saves: the floor's entry save rebuilds the same shrine and fountain; their state is snapshotted. Pure sim code.

const KIND_STREAM := "map:shrine_kind"
const FOUNTAIN_STREAM := "map:fountain"
const CHAOS_STREAM := "combat:chaos"
## A reward altar stands this far from the shrine at least (m), and the challenge's enemies this far from the hero.
const REWARD_GAP_M := 2.0
const MIN_HERO_M := 2.5
const EFFECT_FOUNTAIN := &"fountain_heal"
const PROMPT_BLOOD := &"SHRINE_BLOOD_PROMPT"
const PROMPT_BLOOD_LOW := &"SHRINE_BLOOD_LOW"
const PROMPT_CHAOS := &"SHRINE_CHAOS_PROMPT"
const PROMPT_FOUNTAIN := &"FOUNTAIN_PROMPT"
const PROMPT_FOUNTAIN_FULL := &"FOUNTAIN_FULL"


## Sets up the floor's Blood or Chaos shrine and its fountain (setup, before the secrets: FloorPlan.add_secrets).
## `map` is the generator's rules (null: FloorParams' defaults). No-op without a table.
static func setup(w: World, t: ShrineTable, floor_index: int, map: FloorParams = null) -> void:
	var f := w.floor_layout
	if t == null or f == null:
		return
	var kind: int = ShrineTable.Kind.FORTUNE
	if w.gamble_id >= 0:
		kind = draw_kind(f.seed_value, t, floor_index)
	var gt := w.gamble_table if w.gamble_table != null else GambleTable.new()
	var at := fountain_site(w, t, floor_index, gt, map)
	if kind == ShrineTable.Kind.FORTUNE and at.is_empty():
		return
	var s := ShrineState.new()
	s.table = t
	w.shrine = s
	if kind != ShrineTable.Kind.FORTUNE:
		s.kind = kind
		s.pos = w.gamble_pos
		s.entry = w.interactables.add(Interactables.Kind.SHRINE, s.pos, t.reach_m, kind)
	if not at.is_empty():
		s.fountain_pos = at[0]
		s.fountain_entry = w.interactables.add(Interactables.Kind.FOUNTAIN, at[0], t.reach_m, 0)
		var walls: Array[Obb] = w.walls.duplicate()
		walls.append(fountain_collider(at[0]))
		w.set_walls(walls)
		w.prepare_wall(f.boss_door_wall)
		w.spawn_points = Gamble.free_spawns(w.spawn_points, at[0], gt)


## The floor's shrine kind (ShrineTable.Kind): one weighted draw on KIND_STREAM of the floor seed (its first draw
## dropped, as Gamble.stream), among the kinds allowed on floor `floor_index`; FORTUNE when none has a weight.
static func draw_kind(seed_value: int, t: ShrineTable, floor_index: int) -> int:
	var k := Offers.pick(Gamble.stream(seed_value, KIND_STREAM), kind_weights(t, floor_index))
	return k if k >= 0 else ShrineTable.Kind.FORTUNE


## The kinds' weights on floor `floor_index`: each kind's data weight from its first floor, else 0.
static func kind_weights(t: ShrineTable, floor_index: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in ShrineTable.Kind.size():
		var wt := t.kind_weights[k] if k < t.kind_weights.size() else 0
		var lo := t.kind_floor_min[k] if k < t.kind_floor_min.size() else 1
		out.append(wt if floor_index >= lo else 0)
	return out


## Where the floor's fountain stands, or [] for a floor without one: a chance on FOUNTAIN_STREAM, then the fountain
## rooms (fountain_rooms) in an order drawn from the same stream, the first with a free spot (Gamble.room_spot) wins.
static func fountain_site(
	w: World, t: ShrineTable, floor_index: int, gt: GambleTable, map: FloorParams
) -> PackedVector2Array:
	var f := w.floor_layout
	if floor_index < t.fountain_floor_min:
		return PackedVector2Array()
	var rng := Gamble.stream(f.seed_value, FOUNTAIN_STREAM)
	if not rng.chance_permille(t.fountain_permille):
		return PackedVector2Array()
	var order := fountain_rooms(w)
	for k in range(order.size() - 1, 0, -1):
		var j := rng.range_int(0, k)
		var swap := order[k]
		order[k] = order[j]
		order[j] = swap
	var p := map if map != null else FloorParams.defaults()
	for room in order:
		var at := Gamble.room_spot(f, room, gt, p)
		if not at.is_empty():
			return at
	return PackedVector2Array()


## The rooms a fountain may stand in, ascending: a shrine's rooms (Gamble.rooms: combat rooms, never the start hall,
## the boss room or its host, the portal, Overrun or shop room, nor an arena), without the shrine's room, an event's
## room or the curse room. The secrets, the purple room and the Lockdowns come later and keep out of it.
static func fountain_rooms(w: World) -> PackedInt32Array:
	var f := w.floor_layout
	var never := PackedInt32Array([f.curse_room])
	if w.gamble_id >= 0:
		never.append(f.room_of(w.gamble_pos))
	for k in w.ev.ids.size():
		never.append(w.ev.room[k])
	var out := PackedInt32Array()
	for r in Gamble.rooms(f):
		if not never.has(r):
			out.append(r)
	return out


## The fountain's footprint as a wall: the shrine's (Gamble.collider, a 1 m square turned 45 degrees, under its 1.2 m
## basin), so the spot Gamble.room_spot checked is the spot it stands on.
static func fountain_collider(at: Vector2) -> Obb:
	return Gamble.collider(at)


## The rooms the later setups keep out of (the fountain's), for Secrets, TimedDoor and Lockdowns.
static func taken_rooms(w: World) -> PackedInt32Array:
	var out := PackedInt32Array()
	if w.shrine != null and w.shrine.has_fountain():
		out.append(w.floor_layout.room_of(w.shrine.fountain_pos))
	return out


## The shrine's room (any kind) and the fountain's: the purple-rune room keeps out of both (FloorPlan, from SH on).
static func site_rooms(w: World) -> PackedInt32Array:
	var out := taken_rooms(w)
	if w.gamble_id >= 0:
		out.append(w.floor_layout.room_of(w.gamble_pos))
	return out


## The spots the later setups keep clear of (the fountain's).
static func avoid_spots(w: World) -> PackedVector2Array:
	var out := PackedVector2Array()
	if w.shrine != null and w.shrine.has_fountain():
		out.append(w.shrine.fountain_pos)
	return out


## The floor's shrine kind now (ShrineTable.Kind; FORTUNE when the shrine is the gamble shrine or there is none).
static func kind_of(w: World) -> int:
	return w.shrine.kind if w.shrine != null else ShrineTable.Kind.FORTUNE


# --- Blood ---------------------------------------------------------------------------------------------------
## The HP Blood would take now: current HP x blood_cost_permille, rounded up, at most HP - 1; 0 when it refuses
## (under blood_min_permille of max HP, or nothing to give).
static func blood_cost(w: World) -> int:
	var t := w.shrine.table
	var hp := w.actors.hp[0]
	var top := w.actors.max_hp[0]
	if hp * 1000 < top * t.blood_min_permille:
		return 0
	var cost := mini((hp * t.blood_cost_permille + 999) / 1000, hp - 1)
	return maxi(0, cost)


## The least HP Blood takes a price from (blood_min_permille of max HP, rounded up; at least 2).
static func blood_min_hp(w: World) -> int:
	return maxi(2, (w.actors.max_hp[0] * w.shrine.table.blood_min_permille + 999) / 1000)


# --- The press (Interactables.handle) ------------------------------------------------------------------------
## Entry i (Kind.SHRINE) was pressed.
static func press_shrine(w: World, i: int) -> void:
	var s := w.shrine
	if s == null or s.used_tick >= 0:
		return
	if s.kind == ShrineTable.Kind.BLOOD:
		var cost := blood_cost(w)
		if cost <= 0:
			s.denied_tick = w.tick
			return
		w.actors.hp[0] -= cost
		s.paid = cost
		_spend(w, i)
		_raise_rewards(w, s.table.blood_altars)
	elif s.kind == ShrineTable.Kind.CHAOS:
		_spend(w, i)
		s.chaos_phase = 1
		_spawn_challenge(w)
		if alive(w) == 0:  # nothing could spawn: the challenge is won at once
			_clear(w)


## Entry i (Kind.FOUNTAIN) was pressed: heals, then the fountain is dry; at full HP it refuses.
static func press_fountain(w: World, i: int) -> void:
	var s := w.shrine
	if s == null or s.fountain_tick >= 0:
		return
	var add := fountain_heal(w)
	if add <= 0:
		s.fountain_denied_tick = w.tick
		return
	var a := w.actors
	a.hp[0] += add
	s.fountain_tick = w.tick
	s.fountain_healed = add
	w.interactables.enabled[i] = 0
	w.interactables.state[i] = 1
	var e := w.emit_event(SimEvent.Kind.HEAL, a.ids[0], a.ids[0], a.ids[0], w.player_pos())
	e.amount = add
	e.amount_applied = add
	e.effect_id = EFFECT_FOUNTAIN


## HP the fountain would restore now (fountain_heal_permille of max HP, rounded half up, to full at most).
static func fountain_heal(w: World) -> int:
	var a := w.actors
	var add := (a.max_hp[0] * w.shrine.table.fountain_heal_permille + 500) / 1000
	return maxi(0, mini(add, a.max_hp[0] - a.hp[0]))


static func _spend(w: World, i: int) -> void:
	w.shrine.used_tick = w.tick
	w.interactables.enabled[i] = 0
	w.interactables.state[i] = 1


# --- Chaos ---------------------------------------------------------------------------------------------------
## Tick phase 9b (World.step, after the Lockdowns): a Chaos challenge whose enemies are all down is cleared.
static func advance(w: World) -> void:
	var s := w.shrine
	if s.chaos_phase == 1 and alive(w) == 0 and not w.has_pending_enemies():
		_clear(w)


## The challenge's enemies still alive.
static func alive(w: World) -> int:
	var n := 0
	for id in w.shrine.members:
		var i := w.actors.index_of(id)
		if i >= 0 and w.actors.dead[i] == 0:
			n += 1
	return n


static func _spawn_challenge(w: World) -> void:
	var s := w.shrine
	if w.spawner == null:
		return
	var ticks := w.run_ticks
	var open := SpawnDirector.unlocked(w, w.spawner, ticks)
	if open.is_empty():
		return
	var weights := PackedInt32Array()
	for k in open:
		weights.append(w.spawner.weights[k])
	var rng := RngStream.derive(w.seed_value, CHAOS_STREAM)
	for q in challenge_spots(w, rng, s.table.chaos_size(w.floor_index)):
		var pick := Offers.pick(rng, weights)
		if pick < 0:
			break
		var id := w.add_enemy(w.spawner.kinds[open[pick]], q)
		SpawnDirector.scale_arrival(w, w.actors.size() - 1, ticks)
		s.members.append(id)
	# v0.9.0 EL (owner Q29b: "the Chaos challenge may bring an elite, a designed exception"): drawn last from the same
	# stream (no draw above moves), and only while no elite is out of the rooms' limit.
	var chance := s.table.chaos_elite_permille
	if chance <= 0 or Elites.alive(w) >= Elites.max_alive(w) or not rng.chance_permille(chance):
		return
	var at := challenge_spots(w, rng, 1)
	if not at.is_empty():
		var eid := Elites.spawn(w, Elites.draw_kind(rng, w.elite_rules), at[0], Elites.Source.CHAOS)
		if eid >= 0:
			s.members.append(eid)


## `count` spots for the challenge: the shrine room's spawn points clear of its footprint and MIN_HERO_M from the
## hero, in an order drawn from `rng`, taken in turn (again from the first when there are fewer).
static func challenge_spots(w: World, rng: RngStream, count: int) -> PackedVector2Array:
	var f := w.floor_layout
	var room := f.room_of(w.shrine.pos)
	var out := PackedVector2Array()
	if room < 0 or room >= f.spawn_points.size() or count <= 0:
		return out
	var gt := w.gamble_table if w.gamble_table != null else GambleTable.new()
	var pts := Gamble.free_spawns(f.spawn_points[room], w.shrine.pos, gt)
	var spots := PackedVector2Array()
	for q in pts:
		if Kin.length(q - w.player_pos()) >= MIN_HERO_M:
			spots.append(q)
	if spots.is_empty():
		spots = pts
	if spots.is_empty():
		return out
	for k in range(spots.size() - 1, 0, -1):
		var j := rng.range_int(0, k)
		var swap := spots[k]
		spots[k] = spots[j]
		spots[j] = swap
	for k in count:
		out.append(spots[k % spots.size()])
	return out


static func _clear(w: World) -> void:
	var s := w.shrine
	s.chaos_phase = 2
	s.clear_tick = w.tick
	_raise_rewards(w, s.table.chaos_altars)


# --- Rewards -------------------------------------------------------------------------------------------------
static func _raise_rewards(w: World, count: int) -> void:
	for q in reward_spots(w, count):
		w.shrine.reward_ids.append(w.add_reward(RewardStore.Kind.ALTAR, q, 0))


## `count` spots for the shrine's free altars: the room's spawn points at least REWARD_GAP_M from the shrine and from
## each other, nearest the shrine first; without enough, the shrine's front (Gamble.front, toward the room's first
## doorway approach) pushed out to REWARD_GAP_M.
static func reward_spots(w: World, count: int) -> PackedVector2Array:
	var f := w.floor_layout
	var at := w.shrine.pos
	var room := f.room_of(at) if f != null else -1
	var out := PackedVector2Array()
	var pts := Array(f.spawn_points[room]) if room >= 0 and room < f.spawn_points.size() else []
	pts.sort_custom(
		func(a: Vector2, b: Vector2) -> bool:
			var da := Kin.length(a - at)
			var db := Kin.length(b - at)
			return da < db or (da == db and (a.x < b.x or (a.x == b.x and a.y < b.y)))
	)
	for q: Vector2 in pts:
		if out.size() >= count:
			break
		if Kin.length(q - at) < REWARD_GAP_M:
			continue
		var near := false
		for o in out:
			near = near or Kin.length(o - q) < REWARD_GAP_M
		if not near:
			out.append(q)
	while out.size() < count:
		var toward := at + Vector2(1.0, 0.0)
		if room >= 0:
			var ap := f.door_approaches(room, 1.0)
			if not ap.is_empty():
				toward = ap[0]
		var front := Gamble.front(at, toward)
		out.append(at + (front - at) * (REWARD_GAP_M / Gamble.FRONT_M))
	return out


# --- What the views read -------------------------------------------------------------------------------------
## The prompt's string key for entry i (Kind.SHRINE or Kind.FOUNTAIN): the cost or the effect, shown before the press.
static func prompt_key(w: World, i: int) -> StringName:
	if w.interactables.kind[i] == Interactables.Kind.FOUNTAIN:
		return PROMPT_FOUNTAIN if fountain_heal(w) > 0 else PROMPT_FOUNTAIN_FULL
	if w.shrine.kind == ShrineTable.Kind.BLOOD:
		return PROMPT_BLOOD if blood_cost(w) > 0 else PROMPT_BLOOD_LOW
	return PROMPT_CHAOS


## The prompt's numbers (formatted into its string): Blood's HP price (or the HP it needs), Chaos's enemy count, the
## fountain's heal.
static func prompt_args(w: World, i: int) -> Array:
	if w.interactables.kind[i] == Interactables.Kind.FOUNTAIN:
		var add := fountain_heal(w)
		return [add] if add > 0 else []
	if w.shrine.kind == ShrineTable.Kind.BLOOD:
		var cost := blood_cost(w)
		return [cost] if cost > 0 else [blood_min_hp(w)]
	return [w.shrine.table.chaos_size(w.floor_index)]


## What the views, the HUD and the sounds read (WorldReader.shrine).
static func read(w: World) -> Dictionary:
	var s := w.shrine
	return {
		"kind": s.kind,
		"has_shrine": s.has_shrine(),
		"pos": s.pos,
		"used_tick": s.used_tick,
		"denied_tick": s.denied_tick,
		"paid": s.paid,
		"chaos_phase": s.chaos_phase,
		"chaos_alive": alive(w) if s.chaos_phase == 1 else 0,
		"chaos_count": s.members.size(),
		"clear_tick": s.clear_tick,
		"has_fountain": s.has_fountain(),
		"fountain_pos": s.fountain_pos,
		"fountain_tick": s.fountain_tick,
		"fountain_healed": s.fountain_healed,
		"fountain_denied_tick": s.fountain_denied_tick,
	}
