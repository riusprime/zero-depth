class_name Rewards
extends RefCounted
## The economy and rewards (v0.3.0 PLAN, E; owner lines L6, L7, L9).
## - Shards: every enemy kill pays its kind's shards × (1 + bonus × danger tier), rounded half up; a kind marked
##   shards_by_floor (a boss) pays shards × the floor number instead. v0.5.5 EC (owner S4): every kill's shards are
##   then × shard_permille (−30 % in the data), rounded half up.
## - Altars (free) and chests (cost shards) stand on the layout's item spots, one per room while rooms last, never
##   in the start hall. Their counts and order come from the loot stream. v0.4.0 TU (D4): the first spot filled is
##   in a room next to the start hall (start_first) and always holds an altar. v0.5.5 EC (owner S1): at most
##   altars_cap altars; the altars rolled past it become chests (the same draws, the same spots).
## - The interact button within reach opens the nearest one. A chest you can't afford stays shut (the world
##   records the refusal for the view). Opening rolls the offer once: up to offer_size different items from the
##   pool (loot stream; chests weight rare items higher). The world then waits for the pick (World.choosing):
##   every gameplay phase is frozen while the tick count runs on. A pick takes that card (a chest's price is paid
##   then), consumes the reward and returns the other cards to the pool; a cancel keeps the reward and its
##   rolled offer for later, so reopening shows the same cards.


## Shards a kill of `kind` pays now (0 for kinds without a table or without shards).
static func shards_for_kill(w: World, kind: int) -> int:
	if BossAi.is_boss_kind(kind):
		return _scaled(w, w.reward_table.boss_shards * maxi(1, w.floor_index))
	var t := w.enemy_table(kind)
	if t == null or t.shards <= 0:
		return 0
	if t.shards_by_floor:
		return _scaled(w, t.shards * maxi(1, w.floor_index))
	# v0.4.0 TU (owner D7, "staying longer still pays more shards"): the floor's plain 30 s tier, not the curve's,
	# so shards keep growing after the curve peaks and holds.
	var tier := w.spawner.tier_at(w.run_ticks) if w.spawner != null else 0
	return _scaled(
		w, (t.shards * (1000 + w.reward_table.shard_tier_bonus_permille * tier) + 500) / 1000
	)


## v0.5.5 EC (owner S4): a kill's shards × the table's shard_permille, rounded half up.
static func _scaled(w: World, amount: int) -> int:
	var m := w.reward_table.shard_permille
	return amount if m == 1000 else (amount * m + 500) / 1000


## Tick phase 9: actor i died. Pays its shards and emits SHARDS (amount = shards, at the body).
static func on_kill(w: World, i: int) -> void:
	var amount := Gamble.shard_gain(w, shards_for_kill(w, w.actors.kinds[i]))  # the shrine's shard gain
	amount = Stats.shards(w, amount)  # v0.4.0 BS: the shard gain stat
	Overrun.on_kill(w, i, amount)  # v0.4.0 AB: an Overrun kill counts toward the clear
	HealOrbs.on_kill(w, i)  # v0.4.0 TU (D8): maybe a heal orb
	if amount <= 0:
		return
	w.shards += amount
	var me := w.actors.ids[0]
	var e := w.emit_event(SimEvent.Kind.SHARDS, w.actors.ids[i], me, me, w.actors.pos(i))
	e.amount = amount


## Places the floor's altars and chests on the layout's item spots (setup). Counts and the altar/chest order are
## drawn from the loot stream; chest prices follow chest order and World.floor_index.
static func place(w: World, layout: FloorLayout) -> void:
	var t := w.reward_table
	var order := start_first(layout, spot_order(layout))
	var kinds := PackedInt32Array()
	for k in w.rng_loot.range_int(t.altars_min, t.altars_max):
		kinds.append(RewardStore.Kind.ALTAR)
	for k in w.rng_loot.range_int(t.chests_min, t.chests_max):
		kinds.append(RewardStore.Kind.CHEST)
	if t.altars_cap > 0:  # v0.5.5 EC (S1): the altars past the cap become chests
		for k in range(t.altars_cap, kinds.size()):
			kinds[k] = RewardStore.Kind.CHEST
	for k in range(kinds.size() - 1, 0, -1):
		var j := w.rng_loot.range_int(0, k)
		var swap := kinds[k]
		kinds[k] = kinds[j]
		kinds[j] = swap
	var altar := kinds.find(RewardStore.Kind.ALTAR)  # v0.4.0 TU (D4): the first spot takes an altar
	if altar > 0:
		kinds[altar] = kinds[0]
		kinds[0] = RewardStore.Kind.ALTAR
	var chests := 0
	for k in mini(kinds.size(), order.size()):
		var price := 0
		if kinds[k] == RewardStore.Kind.CHEST:
			price = t.chest_price(chests, w.floor_index)
			chests += 1
		w.add_reward(kinds[k], layout.item_spots[order[k]], price)


## v0.4.0 TU (owner D4): `order` with the first spot of the room nearest the start hall (fewest hops; the first
## such in `order`) moved to the front, so the floor's first reward, an altar, is next to the start.
static func start_first(layout: FloorLayout, order: PackedInt32Array) -> PackedInt32Array:
	var best := -1
	for k in order.size():
		var hops := layout.hops[layout.item_rooms[order[k]]]
		if best < 0 or hops < layout.hops[layout.item_rooms[order[best]]]:
			best = k
	if best <= 0:
		return order
	var out := PackedInt32Array([order[best]])
	for k in order.size():
		if k != best:
			out.append(order[k])
	return out


## Item spot indices in fill order: each room's first spot (in room order), then the second spots.
static func spot_order(layout: FloorLayout) -> PackedInt32Array:
	var first := PackedInt32Array()
	var second := PackedInt32Array()
	for i in layout.item_spots.size():
		if i > 0 and layout.item_rooms[i - 1] == layout.item_rooms[i]:
			second.append(i)
		else:
			first.append(i)
	first.append_array(second)
	return first


## The reward within interact reach nearest the player (lowest index on a tie), or -1.
static func nearest(w: World) -> int:
	var best := -1
	var best_d := Stats.reach(w, w.reward_table.interact_radius_m)  # v0.4.0 BS: pickup range
	var p := w.player_pos()
	for i in w.rewards.size():
		var d := Kin.length(w.rewards.pos(i) - p)
		if d <= best_d and (best < 0 or d < best_d):
			best = i
			best_d = d
	return best


static func can_afford(w: World, i: int) -> bool:
	return w.shards >= price_of(w, i)


## Reward i's price now: its placed price under the prices curse (v0.5.0 EV).
static func price_of(w: World, i: int) -> int:
	return Curses.price(w, w.rewards.price[i])


## Tick phase 2b: a buffered interact press next to a reward opens it. True if the world is now choosing.
static func interact(w: World) -> bool:
	if w.player_dead() or w.buffered(InputFrame.INTERACT) == 0:
		return false
	var i := nearest(w)
	if i < 0:
		return false
	w.consume_buffered(InputFrame.INTERACT)
	if not can_afford(w, i):
		_deny(w, i)
		return false
	if w.rewards.rolled[i] == 0:
		w.rewards.set_offer(i, Offers.roll(w, i))  # v0.4.0 BS: abilities, stat cards and mods
		Curses.on_offer_rolled(w, i)  # v0.5.0 EV: a chest may turn cursed
	if w.rewards.offer_of(i).is_empty():
		_deny(w, i)
		return false
	w.choosing = w.rewards.ids[i]
	return true


## While choosing: a pick takes that card, a cancel closes the choice; anything else waits.
static func choose(w: World, frame: InputFrame) -> void:
	var i := w.rewards.index_of(w.choosing)
	if i < 0:
		_resume(w)
		return
	if frame.pick == InputFrame.PICK_CANCEL:
		_resume(w)
		return
	var offer := w.rewards.offer_of(i)
	var k := frame.pick - 1
	if k < 0 or k >= offer.size() or not can_afford(w, i):
		return
	w.shards -= price_of(w, i)
	var idx := offer[k]
	var at := w.rewards.pos(i)
	var e := w.emit_event(
		SimEvent.Kind.PICKUP, w.rewards.ids[i], w.actors.ids[0], w.actors.ids[0], at
	)
	e.amount = idx
	Offers.apply(w, idx)  # v0.4.0 BS: an item (mod), an ability or a stat card
	Curses.on_pick(w, w.rewards.ids[i], k)  # v0.5.0 EV: the cursed card brings its curse
	w.rewards.remove_at(i)
	_resume(w)


## Back to play: no choice open, and nothing pressed during the choice fires afterwards.
static func _resume(w: World) -> void:
	w.choosing = -1
	for s in w.input_buffer.size():
		w.input_buffer[s] = 0


static func _deny(w: World, i: int) -> void:
	w.reward_denied_id = w.rewards.ids[i]
	w.reward_denied_tick = w.tick
