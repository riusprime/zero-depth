# gdlint: disable=max-public-methods
class_name Shop
extends RefCounted
## The shop (v0.5.0 PLAN R1, R2; ROADMAP "Shops"). One terminal per floor in a side room
## (ShopPlacement). The interact button within reach opens it; while it is open the world waits (like an altar's
## pick: only the shop's actions run, the tick still counts), and every action is an InputFrame.pick value.
## - Stock: ShopTable.offer_size cards drawn on the first open from the loot stream by a chest's rules
##   (Offers.draw: the same pools, ability cards only while they can apply, mods only with their ability). A card
##   costs its rarity's price x the floor step (30 / 55 / 90 x 1, 1.5, 2) and applies exactly as a picked card does
##   (Offers.apply); its slot is then sold out. A card that can no longer apply (a slot filled since, a stat at its
##   cap) can't be bought.
## - Heal: heal_permille of max HP, once per shop, for heal_price x the floor step; refused at full HP.
## - Reroll: a new card in every unsold slot for reroll_price, x (1 + step) per use at this shop. v0.5.5 EC (owner
##   S2): a bought slot stays SOLD for the floor; a reroll with no unsold slot, or with no buys left, is refused.
## - Buy limit: at most ShopTable.max_buys cards bought at the floor's shop (the heal and
##   rerolls don't count); a buy past it is refused with ShopState.Deny.LIMIT for the view's message.
## - Prices: floors 2-3 multiply the floor step by late_floor_permille (ShopTable).
## - Refusals (unaffordable, nothing to do) change nothing but ShopState.denied_tick, for the view.
## - v0.10.5 W3-O9 (owner, 2026-11-04: "it should only show the heal, reroll and the 4 cards, lifting the curse and
##   selling is too broken"): the shop sells only those. Salvage (selling a card back) and the paid curse lift are
##   gone; their old pick values (22, 100 and up) are refused like any other unknown pick, and ShopState.Action keeps
##   their numbers so an old save's last action still reads.
## Every purchase emits SHOP_BUY; a bought card also emits PICKUP, the heal HEAL.

## Spawn points this close to the terminal are dropped, so no enemy appears inside it.
const SPAWN_CLEAR_M := 1.6
const EFFECT_HEAL := &"shop_heal"
const EFFECT_REROLL := &"shop_reroll"


static func present(w: World) -> bool:
	return w.shop.present()


## Places the floor's terminal at the layout's shop spot (setup, after ShopPlacement.pick). Returns its id.
static func place(w: World, layout: FloorLayout) -> int:
	w.shop = ShopState.new()
	if layout.shop_room < 0:
		return -1
	w.shop.pos = layout.shop_pos
	w.shop.room = layout.shop_room
	w.shop.id = w.take_root()
	w.emit_event(SimEvent.Kind.SPAWN, w.shop.id, w.shop.id, w.shop.id, w.shop.pos)
	var kept := PackedVector2Array()
	for q in w.spawn_points:
		if Kin.length(q - w.shop.pos) >= SPAWN_CLEAR_M:
			kept.append(q)
	w.spawn_points = kept
	return w.shop.id


static func in_reach(w: World) -> bool:
	if not present(w) or w.shop_table == null:
		return false
	var reach := Stats.reach(w, w.shop_table.interact_radius_m)
	return Kin.length(w.shop.pos - w.player_pos()) <= reach


## Tick phase 2b, after Rewards.interact and before the gamble shrine: a buffered interact press by the terminal
## opens the shop (drawing the stock on the first open). True if it opened.
static func interact(w: World) -> bool:
	if w.player_dead() or w.buffered(InputFrame.INTERACT) == 0 or not in_reach(w):
		return false
	w.consume_buffered(InputFrame.INTERACT)
	if not w.shop.rolled:
		restock(w)
	w.shop.open = true
	_note(w, ShopState.Action.OPEN, 0)
	return true


static func restock(w: World) -> void:
	w.shop.offer = PackedInt32Array()  # out of the pool while drawing
	w.shop.offer = Offers.draw(w, true, w.shop_table.offer_size)
	w.shop.rolled = true


## A new card in every unsold slot; the sold slots stay SOLD. The unsold cards go back to the
## pool while drawing (as a full restock does); a slot the draw can't fill reads SOLD.
static func restock_unsold(w: World) -> void:
	var open_slots := PackedInt32Array()
	for k in w.shop.offer.size():
		if w.shop.offer[k] != ShopState.SOLD:
			open_slots.append(k)
	var kept := w.shop.offer.duplicate()
	for k in open_slots:
		kept[k] = ShopState.SOLD
	w.shop.offer = kept  # the unsold cards are out of the stock (back in the pool) while drawing
	var fresh := Offers.draw(w, true, open_slots.size())
	for n in open_slots.size():
		kept[open_slots[n]] = fresh[n] if n < fresh.size() else ShopState.SOLD
	w.shop.offer = kept


## Unsold slots in the stock now.
static func unsold(w: World) -> int:
	var n := 0
	for code in w.shop.offer:
		if code != ShopState.SOLD:
			n += 1
	return n


## Cards still buyable at this floor's shop (-1 = no limit).
static func buys_left(w: World) -> int:
	var cap := w.shop_table.max_buys
	return -1 if cap <= 0 else maxi(0, cap - w.shop.bought)


## While open: one action per pick value (InputFrame.PICK_*); anything else waits.
static func choose(w: World, frame: InputFrame) -> void:
	var v := frame.pick
	if v == InputFrame.PICK_NONE:
		return
	if BuildSlots.swapping(w) and w.swap_source == BuildSlots.Source.SHOP:  # The swap's answer
		var s := BuildSlots.swap_answer(w, frame)
		if s == -2:
			return
		var k := w.swap_ref
		BuildSlots.close_swap(w)
		if s >= 0:
			buy(w, k, s)
		return
	if v == InputFrame.PICK_CANCEL:
		close(w)
	elif v >= 1 and v <= w.shop.offer.size():
		buy(w, v - 1)
	elif v == InputFrame.PICK_SHOP_HEAL:
		heal(w)
	elif v == InputFrame.PICK_SHOP_REROLL:
		reroll(w)
	else:
		_deny(w)


## Back to play: nothing pressed while the shop was open fires afterwards.
static func close(w: World) -> void:
	w.shop.open = false
	for s in w.input_buffer.size():
		w.input_buffer[s] = 0
	_note(w, ShopState.Action.CLOSE, 0)


# --- Prices ------------------------------------------------------------------------------------------------------
## The rarity a card is priced by (0 common, 1 rare, 2 epic; Offers.info).
static func rarity(w: World, code: int) -> int:
	return int(Offers.info(w, code)["rarity"])


## Every shop price goes through the prices curse (Curses.price).
static func price(w: World, code: int) -> int:
	return w.shop_table.card_price(rarity(w, code), w.floor_index)


static func heal_price(w: World) -> int:
	return w.shop_table.heal_cost(w.floor_index)


static func reroll_price(w: World) -> int:
	return w.shop_table.reroll_cost(w.shop.rerolls)


## HP the heal would restore now.
static func heal_amount(w: World) -> int:
	var a := w.actors
	var add := (a.max_hp[0] * w.shop_table.heal_permille + 500) / 1000
	return maxi(0, mini(add, a.max_hp[0] - a.hp[0]))


## Card `code` would do something if taken now: the one rule for the shop, an event's cards and a core's drop
## (Events.block, CoreTheft.on_death; audit G-6).
static func can_apply(w: World, code: int) -> bool:
	if code < 0:
		return false
	match Offers.type_of(code):
		Offers.ABILITY:
			return Abilities.can_take(w, Offers.ability_of(code))
		Offers.STAT:
			return not Stats.at_cap(w, Offers.stat_of(code))
	return CardLevels.can_take(w, code) and ItemPool.usable(w, code)  # A level-up


# --- Actions -----------------------------------------------------------------------------------------------------
## Buys stock slot k. True if bought. a new modifier with the six slots full opens the swap first
## (BuildSlots; the answer comes back here with the slot it replaces, `replace`), and nothing is paid until then.
static func buy(w: World, k: int, replace: int = -1) -> bool:
	if k < 0 or k >= w.shop.offer.size():
		return _deny(w)
	var code := w.shop.offer[k]
	if code == ShopState.SOLD:
		return _deny(w)
	if buys_left(w) == 0:
		return _deny(w, ShopState.Deny.LIMIT)  # v0.5.5 EC
	if not can_apply(w, code):
		return _deny(w)
	var cost := price(w, code)  # once (audit G-16)
	if w.shards < cost:
		return _deny(w)
	if replace < 0 and BuildSlots.needs_swap(w, code):
		BuildSlots.open_swap(w, code, BuildSlots.Source.SHOP, k)
		return false
	w.shards -= cost
	w.shop.offer[k] = ShopState.SOLD
	w.shop.bought += 1
	_spend(w, cost, Offers.info(w, code)["id"])
	var pid := w.actors.ids[0]
	var e := w.emit_event(SimEvent.Kind.PICKUP, w.shop.id, pid, pid, w.shop.pos)
	e.amount = code
	Offers.apply(w, code, replace)
	_note(w, ShopState.Action.BUY, code)
	return true


static func heal(w: World) -> bool:
	var add := heal_amount(w)
	var cost := heal_price(w)
	if w.shop.heal_used or add <= 0 or w.shards < cost or w.player_dead():
		return _deny(w)
	w.shards -= cost
	w.shop.heal_used = true
	_spend(w, cost, EFFECT_HEAL)
	var a := w.actors
	a.hp[0] += add
	var e := w.emit_event(SimEvent.Kind.HEAL, w.shop.id, a.ids[0], a.ids[0], w.player_pos())
	e.amount = add
	e.amount_applied = add
	e.effect_id = EFFECT_HEAL
	_note(w, ShopState.Action.HEAL, add)
	return true


static func reroll(w: World) -> bool:
	var cost := reroll_price(w)
	if buys_left(w) == 0:
		return _deny(w, ShopState.Deny.LIMIT)  # Nothing more to buy here
	if unsold(w) == 0 or w.shards < cost:
		return _deny(w)  # Every slot sold, nothing to reroll
	w.shards -= cost
	w.shop.rerolls += 1
	_spend(w, cost, EFFECT_REROLL)
	restock_unsold(w)
	_note(w, ShopState.Action.REROLL, cost)
	return true


## Drops owned item `idx`: its modifiers go, and so does every combo it completed.
static func remove_item(w: World, idx: int) -> void:
	var owned := w.items_owned.duplicate()
	owned.remove_at(owned.find(idx))
	var still := Engines.combos_for(w.combo_tables, owned)
	var keep := PackedInt32Array()
	for c in w.combos_owned:
		if still.has(c):
			keep.append(c)
	w.combos_owned = keep
	w.set_items_owned(owned)


## Drops the last-taken card `code` and rebuilds the stat values from the cards left (in the order taken), then the
## gamble shrine's wins that pay into stats. Max HP follows; HP stays, at most the new max.
static func remove_stat_card(w: World, code: int) -> void:
	var cards := w.stat_cards.duplicate()
	for k in range(cards.size() - 1, -1, -1):
		if cards[k] == code:
			cards.remove_at(k)
			break
	rebuild_stats(w, cards)


static func rebuild_stats(w: World, cards: PackedInt32Array) -> void:
	var hp := w.actors.hp[0]
	w.stat_values = PackedInt32Array()
	w.stat_cards = PackedInt32Array()
	for c in cards:
		Stats.add_card(w, Offers.stat_of(c), Offers.rarity_of(c))
	for s in w.gamble_stacks.size():
		var stat := Stats.from_gamble(w, s)
		if stat < 0:
			continue
		for k in w.gamble_stacks[s]:
			Stats.add_amount(w, stat, Gamble.gamble_permille(w, s))
	w.actors.max_hp[0] = maxi(1, Stats.max_hp(w))
	w.actors.hp[0] = clampi(hp, 1, w.actors.max_hp[0])


# --- Read (WorldReader.shop) ------------------------------------------------------------------------------------
## Plain data for the views: the terminal, the stock with prices, the heal and the reroll.
static func read(w: World) -> Dictionary:
	var stock: Array[Dictionary] = []
	for code in w.shop.offer:
		var c := {
			"code": code, "sold": code < 0, "price": 0, "can_apply": false, "affordable": false
		}
		if code >= 0:
			c["price"] = price(w, code)
			c["can_apply"] = can_apply(w, code)
			c["affordable"] = w.shards >= c["price"]
		stock.append(c)
	return {
		"open": w.shop.open,
		"stock": stock,
		"heal_price": heal_price(w),
		"heal_amount": heal_amount(w),
		"heal_used": w.shop.heal_used,
		"reroll_price": reroll_price(w),
		"rerolls": w.shop.rerolls,
		"unsold": unsold(w),  # v0.5.5 EC
		"bought": w.shop.bought,  # v0.5.5 EC
		"max_buys": w.shop_table.max_buys,
		"buys_left": buys_left(w),
		"denied_reason": w.shop.denied_reason,
		"last_action": w.shop.last_action,
		"last_tick": w.shop.last_tick,
		"last_value": w.shop.last_value,
		"denied_tick": w.shop.denied_tick,
	}


static func _spend(w: World, cost: int, what: StringName) -> void:
	var pid := w.actors.ids[0]
	var e := w.emit_event(SimEvent.Kind.SHOP_BUY, w.shop.id, pid, pid, w.shop.pos)
	e.amount = cost
	e.effect_id = what


static func _note(w: World, action: int, value: int) -> void:
	w.shop.last_action = action
	w.shop.last_tick = w.tick
	w.shop.last_value = value


static func _deny(w: World, reason: int = ShopState.Deny.OTHER) -> bool:
	w.shop.denied_tick = w.tick
	w.shop.denied_reason = reason
	return false
