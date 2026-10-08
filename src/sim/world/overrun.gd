class_name Overrun
extends RefCounted
## The Overrun threat branch in play (v0.4.0 AB; ROADMAP "Threat T branches"; OverrunDefinition, OverrunRooms).
## On a floor with an Overrun room (FloorLayout.overrun_room) and a loadout with its table (World.overrun_table):
## - you are inside while you stand in the room (FloorLayout.room_of) and it isn't cleared;
## - while inside, the spawn director's alive cap is x spawn_permille and its interval / spawn_permille, on top of
##   the floor and danger-tier values (SpawnTable.cap, interval); on_spawn runs for every pack member: every enemy that
##   arrives then is an Overrun enemy (World.overrun.boosted): its tier-scaled HP x hp_permille at once and its
##   tier power (ActorStore.power, which every enemy attack, bolt and mine goes through: EnemyAi.powered) x
##   damage_permille, for as long as it lives;
## - kills of Overrun enemies count (on_kill, from Rewards.on_kill, with the shards they paid) wherever they die;
##   kills_to_clear of them clear the room (tick phase 9, advance): an altar appears at the room's open spot nearest
##   its centre with ability cards already rolled from the loot stream (level-ups of abilities you own first, then new
##   ones; an altar with none rolls as usual on opening), and the shards those kills paid are paid again x
##   (shard_permille - 1000) / 1000 (a SHARDS event at the altar). A cleared room is a normal room.


static func enabled(w: World) -> bool:
	return w.overrun_table != null and w.floor_layout != null and w.floor_layout.overrun_room >= 0


## Tick phase 9, after the deaths: inside or not, and the clear.
static func advance(w: World) -> void:
	if not enabled(w) or w.player_dead():
		return
	var s := w.overrun
	var room := w.floor_layout.overrun_room
	s.inside = not s.cleared() and w.floor_layout.room_of(w.player_pos()) == room
	if s.inside and s.enter_tick < 0:
		s.enter_tick = w.tick
	if not s.cleared() and s.kills >= w.overrun_table.kills_to_clear:
		_clear(w)


## The spawn director's alive cap and interval now (raised while inside).
static func cap(w: World, base: int) -> int:
	return base * w.overrun_table.spawn_permille / 1000 if w.overrun.inside else base


static func interval(w: World, base: int) -> int:
	if not w.overrun.inside:
		return base
	return maxi(1, base * 1000 / w.overrun_table.spawn_permille)


## The spawn director added actor `i`: while inside, it is an Overrun enemy.
static func on_spawn(w: World, i: int) -> void:
	if not w.overrun.inside or w.overrun_table == null:
		return
	var a := w.actors
	var hp := maxi(1, a.hp[i] * w.overrun_table.hp_permille / 1000)
	a.hp[i] = hp
	a.max_hp[i] = hp
	a.power[i] = maxi(1, a.power[i]) * w.overrun_table.damage_permille / 1000
	w.overrun.boosted.append(a.ids[i])


## Rewards.on_kill: actor `i` died paying `shards`.
static func on_kill(w: World, i: int, shards: int) -> void:
	var s := w.overrun
	var k := s.boosted.find(w.actors.ids[i])
	if k < 0:
		return
	s.boosted.remove_at(k)
	if not s.cleared():
		s.kills += 1
		s.shards_in += maxi(0, shards)


static func _clear(w: World) -> void:
	var s := w.overrun
	s.clear_tick = w.tick
	s.inside = false
	var at := reward_spot(w.floor_layout)
	s.reward_id = w.add_reward(RewardStore.Kind.ALTAR, at, 0)
	var codes := offer(w)
	if not codes.is_empty():
		w.rewards.set_offer(w.rewards.index_of(s.reward_id), codes)
	s.bonus = s.shards_in * (w.overrun_table.shard_permille - 1000) / 1000
	if s.bonus > 0:
		w.shards += s.bonus
		var me := w.actors.ids[0]
		var e := w.emit_event(SimEvent.Kind.SHARDS, me, me, me, at)
		e.amount = s.bonus


## The clear's altar: the Overrun room's spawn point nearest its centre (spawn points keep clear of walls), or the
## centre.
static func reward_spot(f: FloorLayout) -> Vector2:
	var c := f.rooms[f.overrun_room].get_center()
	var best := c
	var best_d := INF
	for p in f.spawn_points[f.overrun_room]:
		var d := Kin.length(p - c)
		if d < best_d:
			best = p
			best_d = d
	return best


## Up to RewardStore.OFFER_SLOTS ability cards (Offers codes): level-ups of owned abilities first, then new ones,
## each group shuffled from the loot stream.
static func offer(w: World) -> PackedInt32Array:
	var ups := PackedInt32Array()
	var fresh := PackedInt32Array()
	for idx in w.ability_tables.size():
		if Abilities.can_take(w, idx):
			if Abilities.owned(w, idx):
				ups.append(idx)
			else:
				fresh.append(idx)
	var out := PackedInt32Array()
	for pool in [ups, fresh]:
		var p: PackedInt32Array = pool
		for k in p.size():
			var j := w.rng_loot.range_int(k, p.size() - 1)
			var swap := p[k]
			p[k] = p[j]
			p[j] = swap
		for idx in p:
			if out.size() < RewardStore.OFFER_SLOTS:
				out.append(Offers.ability_code(idx))
	return out


## What the HUD, minimap and door frames read (WorldReader.overrun).
static func read(w: World) -> Dictionary:
	var s := w.overrun
	var f := w.floor_layout
	return {
		"active": enabled(w),
		"room": f.overrun_room if f != null else -1,
		"center": f.rooms[f.overrun_room].get_center() if enabled(w) else Vector2.ZERO,
		"doors": f.overrun_doors if f != null else PackedInt32Array(),
		"inside": s.inside,
		"entered": s.enter_tick >= 0,
		"kills": s.kills,
		"needed": w.overrun_table.kills_to_clear if w.overrun_table != null else 0,
		"cleared": s.cleared(),
		"clear_tick": s.clear_tick,
		"bonus": s.bonus,
		"reward_id": s.reward_id,
		"boosted": s.boosted.size(),
	}
